# Proof ledgers: the schema, the reader's refusals, every row type of ldgrchk(),
# the sandbox, and the capsule rows `rmbl verify` adds.

smp <- function() {
  system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer")
}
write_ledger <- function(x, path = tempfile(fileext = ".json")) {
  writeLines(tojs(x, auto_unbox = TRUE, pretty = TRUE), path)
  path
}

test_that("the sample ledger validates against the schema and prints", {
  l <- ldgrread(smp())
  expect_s3_class(l, "rmbl_ledger")
  expect_length(l$theorems, 3L)
  expect_output(print(l), "3 theorems \\(1 proved, 1 sorry, 1 axiom\\)")
  s <- fromjs(paste(readLines(schemapath("ledger")), collapse = "\n"))
  expect_setequal(s$required, c("name", "toolchain", "source", "theorems"))
})

test_that("the reader refuses what is not a ledger", {
  expect_error(
    ldgrread(write_ledger(list(name = "x"))),
    "is not a ledger: \\$: missing required"
  )
  bad <- tempfile(fileext = ".json")
  writeLines("{not json", bad)
  expect_error(ldgrread(bad), "is not valid JSON")
  l <- fromjs(paste(readLines(smp()), collapse = "\n"), simplifyVector = FALSE)
  l$theorems[[2L]]$id <- l$theorems[[1L]]$id
  expect_error(ldgrread(write_ledger(l)), "theorem id gini-equal is repeated")
  l <- fromjs(paste(readLines(smp()), collapse = "\n"), simplifyVector = FALSE)
  l$theorems[[1L]]$status <- "done"
  expect_error(ldgrread(write_ledger(l)), "must be one of proved, sorry, axiom")
  expect_error(ldgrread(tempfile()))
})

test_that("ldgrchk() gives every row type", {
  r <- ldgrchk(smp())
  row <- function(chk) r[r$check == chk, ]
  expect_true(row("proved: gini-equal")$ok)
  expect_false(row("proved: lorenz-monotone")$ok)
  expect_identical(row("proved: lorenz-monotone")$severity, "error")
  expect_identical(row("proved: float-round")$severity, "warn")
  expect_true(row("covered: gini-equal rmoriebricklayer::ginicoef")$ok)
  expect_true(row("check: gini-equal")$ok)
  expect_match(
    row("check: gini-equal")$detail,
    "ginicoef(c(5, 5, 5, 5)) = 0",
    fixed = TRUE
  )
  expect_identical(
    names(r),
    c("capsule", "part", "file", "check", "ok", "detail", "severity", "line")
  )
  l <- fromjs(paste(readLines(smp()), collapse = "\n"), simplifyVector = FALSE)
  l$theorems[[1L]]$covers <- list(
    list(package = "rmoriebricklayer", `function` = "nosuchfn", language = "R"),
    list(package = "notapkg123", `function` = "f", language = "R"),
    list(package = "morie", `function` = "f", language = "Python")
  )
  l$theorems[[1L]]$check$expect <- 1
  l$theorems[[2L]]$check <- list(expr = "1 + 1", expect = 2)
  l$theorems[[2L]]$covers <- list()
  l$theorems[[3L]]$covers <- list(list(
    package = "notapkg123",
    `function` = "f",
    language = "R"
  ))
  l$theorems[[3L]]$check <- list(expr = "f(1)", expect = 1)
  r <- ldgrchk(write_ledger(l))
  expect_false(row("covered: gini-equal rmoriebricklayer::nosuchfn")$ok)
  expect_identical(row("covered: gini-equal notapkg123::f")$severity, "note")
  expect_match(row("covered: gini-equal morie::f")$detail, "Python")
  expect_false(row("check: gini-equal")$ok)
  expect_match(row("check: lorenz-monotone")$detail, "needs an R package")
  expect_identical(row("check: float-round")$severity, "note")
  # a check the sandbox refuses is a failed row with the refusal, not an error
  l2 <- l
  l2$theorems[[1L]]$check$expr <- "system('echo hi')"
  r2 <- ldgrchk(write_ledger(l2))
  expect_match(
    r2$detail[r2$check == "check: gini-equal"],
    "must be a call to a function of rmoriebricklayer"
  )
  l2$theorems[[1L]]$check$expr <- "lorenzc(c(1, 2))"
  r2 <- ldgrchk(write_ledger(l2))
  expect_match(
    r2$detail[r2$check == "check: gini-equal"],
    "a data.frame of length"
  )
  # only the packages asked for
  r <- ldgrchk(write_ledger(l), pkgs = "rmoriebricklayer")
  expect_false(any(grepl("notapkg123", r$check)))
  expect_false("check: float-round" %in% r$check)
  expect_error(ldgrchk(1), "ldgrchk: `ledger` must be a ldgrread\\(\\) result")
  expect_error(ldgrchk(smp(), pkgs = NA), "`pkgs` must be package names")
})

test_that("the sandbox runs only the package's functions and base arithmetic", {
  ev <- asNamespace("rmoriebricklayer")$.bl_ldgr_eval
  expect_identical(ev("ginicoef(c(1, 1, 1))", "rmoriebricklayer"), 0)
  expect_equal(
    ev("rmoriebricklayer::ginicoef(rep(2, 4))", "rmoriebricklayer"),
    0
  )
  expect_error(
    ev("ginicoef(rep(2, 4)) + 1", "rmoriebricklayer"),
    "must be a call to a function"
  )
  expect_equal(
    ev("lorenzc(c(1, 2, 3))$value[3]", "rmoriebricklayer"),
    lorenzc(c(1, 2, 3))$value[3]
  )
  expect_equal(
    ev("ginicoef(seq(1, pi, length.out = 3))", "rmoriebricklayer"),
    ginicoef(seq(1, pi, length.out = 3))
  )
  expect_error(
    ev("system('echo hi')", "rmoriebricklayer"),
    "must be a call to a function of rmoriebricklayer"
  )
  expect_error(
    ev("ginicoef(system('echo hi'))", "rmoriebricklayer"),
    "not system\\(\\)"
  )
  expect_error(
    ev("ginicoef(base::readLines('x'))", "rmoriebricklayer"),
    "not base::readLines"
  )
  expect_error(ev("ginicoef(x)", "rmoriebricklayer"), "refers to `x`")
  expect_error(
    ev("ginicoef((function() 1)())", "rmoriebricklayer"),
    "not a function name"
  )
  expect_error(ev("ginicoef(c(1, 2", "rmoriebricklayer"), "not R code")
  expect_error(
    ev("ginicoef(1); ginicoef(2)", "rmoriebricklayer"),
    "one expression"
  )
  expect_error(ev("1 + 1", "rmoriebricklayer"), "must be a call to a function")
  expect_identical(ev("ginicoef(c(1, 1))[]", "rmoriebricklayer"), 0)
})

test_that(
  paste0(
    "a ledger in a capsule adds the pin rows, and rmbl verify adds the ",
    "ledger rows"
  ),
  {
    cap <- tempfile("ledger-capsule-")
    dir.create(cap)
    file.copy(smp(), file.path(cap, "ledger.json"))
    l <- ldgrread(smp())
    prov <- list(
      kind = "ledger",
      source = list(commit = l$source$commit, build_digest = "00"),
      resource = list(
        filename = "ledger.json",
        sha256 = sha256file(file.path(cap, "ledger.json"))
      )
    )
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cap, "data_provenance.json")
    )
    r <- ldgrchk(file.path(cap, "ledger.json"))
    expect_true(r$ok[r$check == "ledger_commit_pinned"])
    expect_false(r$ok[r$check == "ledger_build_pinned"])
    expect_match(
      r$detail[r$check == "ledger_build_pinned"],
      "the provenance pins build_digest 00"
    )
    expect_true(r$ok[r$check == "data_sha256"])
    k <- cpschk(cap, fp = FALSE)
    expect_true("proved: gini-equal" %in% k$rows$check)
    buf <- character()
    blcli(c("verify", cap), out = function(s) buf <<- c(buf, s))
    expect_match(
      paste(buf, collapse = ""),
      "ledger_commit_pinned",
      fixed = TRUE
    )
    # a ledger file that does not read is one failed row
    writeLines("{}", file.path(cap, "ledger.json"))
    prov$resource$sha256 <- sha256file(file.path(cap, "ledger.json"))
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cap, "data_provenance.json")
    )
    k <- cpschk(cap, fp = FALSE)
    expect_false(k$rows$ok[k$rows$check == "ledger_readable"])
    # the ledger names no pins: nothing is pinned
    rows <- asNamespace("rmoriebricklayer")$.bl_ldgr_capsule_rows
    file.copy(smp(), file.path(cap, "ledger.json"), overwrite = TRUE)
    out <- rows(
      cap,
      list(resource = list(filename = "ledger.json"), source = list())
    )
    expect_match(
      out$detail[out$check == "ledger_commit_pinned"],
      "pins commit nothing"
    )
  }
)
