# The capsule checks of the rmbl GitHub Action, in the package: schemapath(),
# mnfdiff(), cpsrfrsh(), explerr() on check rows, and the verbs verify, drift,
# refresh and report. Nothing here reads standard input: the prompt reader is
# mocked to fail.

# the test secret of fixtures/morie-hmac, recorded on purpose
fx_secret <- "rmbl-test-secret-hmac"
fx_key_id <- "1c28aab2838d16e632796fc899e5c4724117a19b60a66eb70f0a5b9bf55afe5b"

run_cli <- function(args) {
  rec <- new.env()
  rec$txt <- character()
  st <- blcli(args, out = function(s) rec$txt <- c(rec$txt, s))
  list(status = st, out = paste(rec$txt, collapse = ""))
}

no_stdin <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    .bl_readline = function(...) stop("a test read standard input"),
    .package = "rmoriebricklayer",
    .env = env
  )
}

# a capsule whose source is a local CSV the test controls
src_capsule <- function(
  df = data.frame(
    id = 1:40,
    v = rep(c("a", "b"), 20),
    stringsAsFactors = FALSE
  ),
  env = parent.frame()
) {
  d <- withr::local_tempdir(.local_envir = env)
  # a local source is read only inside its capsule
  src <- file.path(d, "source.csv")
  utils::write.csv(df, src, row.names = FALSE)
  prov <- list(
    name = "t",
    source = list(url = "source.csv", sha256 = "TODO: pinned later"),
    resource = list(filename = "data.csv", row_count_data_rows = 0),
    table = list(rounding = 5, suppression_limit = 10)
  )
  writeLines(
    tojs(prov, auto_unbox = TRUE),
    file.path(d, "data_provenance.json")
  )
  list(dir = d, src = src)
}

hmac_capsule <- function(env = parent.frame()) {
  d <- withr::local_tempdir(.local_envir = env)
  file.copy(
    list.files(test_path("fixtures", "morie-hmac"), full.names = TRUE),
    d
  )
  d
}

test_that(
  paste0(
    "schemapath() finds the three schemas, the same files as the action's ",
    "spec/"
  ),
  {
    for (n in c("capsule", "bundle", "manifest")) {
      expect_true(file.exists(schemapath(n)))
      expect_identical(schemapath(paste0(n, ".schema.json")), schemapath(n))
    }
    expect_error(
      schemapath("nope"),
      paste0(
        "schemapath: `name` must be capsule, bundle, manifest or ledger, ",
        "not 'nope'"
      )
    )
    expect_error(
      schemapath(1),
      "schemapath: `name` must be a single non-empty string"
    )
    spec <- Sys.getenv(
      "RMBL_ACTION_DIR",
      file.path(path.expand("~"), "work", "rmbl-action")
    )
    skip_if_not(
      dir.exists(file.path(spec, "spec")),
      "the rmbl-action clone is not here"
    )
    for (n in c("capsule", "bundle", "manifest")) {
      f <- paste0(n, ".schema.json")
      expect_identical(
        unname(tools::md5sum(schemapath(n))),
        unname(tools::md5sum(file.path(spec, "spec", f))),
        info = f
      )
    }
  }
)

test_that(
  paste0(
    "the schema subset reports type, enum, pattern, length, minimum, ",
    "required and items"
  ),
  {
    s <- list(
      type = "object",
      required = list("a", "b"),
      properties = list(
        a = list(type = "string", pattern = "^x", minLength = 3),
        n = list(type = "integer", minimum = 0),
        e = list(enum = list("P", "Q")),
        l = list(type = "array", items = list(type = "number"))
      ),
      additionalProperties = list(type = "boolean")
    )
    x <- list(a = "yz", n = -1, e = "R", l = list(1, "s"), z = 1.5)
    err <- .bl_schema_errors(x, s)
    expect_true(any(grepl("missing required b", err, fixed = TRUE)))
    expect_true(any(grepl("\\$.a: does not match", err)))
    expect_true(any(grepl("\\$.a: shorter than 3", err)))
    expect_true(any(grepl("\\$.n: below 0", err)))
    expect_true(any(grepl("\\$.e: must be one of P, Q", err)))
    expect_true(any(grepl("\\$.l\\[1\\]: expected number, got string", err)))
    expect_true(any(grepl("\\$.z: expected boolean, got number", err)))
    expect_identical(
      .bl_schema_errors(list(), list(type = "object", required = list("r"))),
      "$: missing required r"
    )
    expect_length(
      .bl_schema_errors(list(a = "xyz"), list(type = c("object", "null"))),
      0L
    )
    expect_identical(
      vapply(
        list(NULL, TRUE, 1L, 1.5, c(1, 2), list(1), sin),
        .bl_json_type,
        ""
      ),
      c("null", "boolean", "integer", "number", "array", "array", "unknown")
    )
  }
)

test_that(
  paste0(
    "mnfdiff() lists added, removed and changed resources of any manifest ",
    "form"
  ),
  {
    a <- data.frame(
      path = c("a.csv", "b.csv", "s.csv"),
      sha256 = c("01", "02", "AA"),
      size_bytes = c(10, 20, 5),
      stringsAsFactors = FALSE
    )
    b <- data.frame(
      path = c("a.csv", "c.csv", "s.csv"),
      sha256 = c("09", "03", "aa"),
      size_bytes = c(12, 30, 5),
      stringsAsFactors = FALSE
    )
    d <- mnfdiff(a, b)
    expect_s3_class(d, "rmbl_mnfdiff")
    expect_identical(d$resource, c("a.csv", "b.csv", "s.csv", "c.csv"))
    expect_identical(d$change, c("changed", "removed", "unchanged", "added"))
    expect_named(
      d,
      c(
        "resource",
        "change",
        "old_sha256",
        "new_sha256",
        "old_size",
        "new_size"
      )
    )
    # the same digest with another size is a change; no size recorded is no
    # change
    expect_identical(
      mnfdiff(
        a[1, ],
        data.frame(
          path = "a.csv",
          sha256 = "01",
          size_bytes = 11,
          stringsAsFactors = FALSE
        )
      )$change,
      "changed"
    )
    expect_identical(
      mnfdiff(
        a[1, ],
        data.frame(path = "a.csv", sha256 = "01", stringsAsFactors = FALSE)
      )$change,
      "unchanged"
    )
    out <- capture.output(print(d))
    expect_match(out[1L], "Manifest diff", fixed = TRUE)
    expect_true(any(grepl(
      "1 changed, 1 added, 1 removed, 1 unchanged",
      out,
      fixed = TRUE
    )))
    expect_identical(
      .bl_mnfdiff_text(d)[1L],
      "Manifest diff: 1 changed, 1 added, 1 removed, 1 unchanged"
    )
    expect_true(any(grepl(
      "changed   a.csv  sha256 01 -> 09, 10 -> 12 bytes",
      out,
      fixed = TRUE
    )))
    expect_true(any(grepl(
      "added     c.csv  sha256 - -> 03, - -> 30 bytes",
      out,
      fixed = TRUE
    )))
    # a provenance record, a bundle file and a provenance file
    fx <- test_path("fixtures", "morie-hmac")
    m <- mnfdiff(
      file.path(fx, "data_provenance.json"),
      file.path(fx, "capsule_bundle.json")
    )
    expect_identical(m$change[m$resource == "d.csv"], "unchanged")
    expect_identical(m$change[m$resource == "data_provenance.json"], "added")
    expect_identical(nrow(mnfdiff(list(), list(name = "no resource"))), 0L)
    expect_error(mnfdiff(1, b), "mnfdiff: `old` must be a provenance record")
    expect_error(
      mnfdiff(a, data.frame(file = "a", stringsAsFactors = FALSE)),
      "mnfdiff: `new`: a data frame needs the columns path and sha256"
    )
    expect_error(mnfdiff(tempfile(), b), "mnfdiff: `old`: no such file")
  }
)

test_that(
  paste0(
    "cpsrfrsh() pins a source, leaves an unchanged one alone and pins new ",
    "bytes"
  ),
  {
    cp <- src_capsule()
    d1 <- cpsrfrsh(cp$dir)
    expect_identical(d1$change, "changed")
    p <- loadprov(file.path(cp$dir, "data_provenance.json"))
    expect_identical(p$resource$sha256, sha256file(cp$src))
    expect_identical(p$source$sha256, p$resource$sha256)
    expect_equal(p$resource$size_bytes, file.size(cp$src), tolerance = 1e-8)
    expect_equal(p$resource$row_count_data_rows, 40, tolerance = 1e-8)
    expect_true(vrfcps(cp$dir)$ok)
    before <- file.mtime(file.path(cp$dir, "data_provenance.json"))
    expect_identical(cpsrfrsh(cp$dir)$change, "unchanged")
    expect_identical(
      file.mtime(file.path(cp$dir, "data_provenance.json")),
      before
    )
    utils::write.csv(
      data.frame(id = 1:41, v = "a", stringsAsFactors = FALSE),
      cp$src,
      row.names = FALSE
    )
    expect_identical(cpsrfrsh(cp$dir)$change, "changed")
    expect_true(vrfcps(cp$dir)$ok)
    expect_equal(
      loadprov(file.path(
        cp$dir,
        "data_provenance.json"
      ))$resource$row_count_data_rows,
      41,
      tolerance = 1e-8
    )
    # the template capsule: the first pin adds the data file
    t <- usecpstmpl(withr::local_tempfile(), ex = TRUE)
    expect_identical(cpsrfrsh(t)$change, "added")
    expect_true(vrfcps(t)$ok)
  }
)

test_that(
  paste0(
    "cpsrfrsh() fetches a URL with fdl() ",
    "and refuses what it cannot pin"
  ),
  {
    cp <- src_capsule()
    prov <- loadprov(file.path(cp$dir, "data_provenance.json"))
    prov$resource$direct_url <- "https://example.org/data.csv"
    prov$wayback$csv_snapshot <- paste0(
      "https://web.archive.org/web/2020/http",
      "s://example.org/data.csv"
    )
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cp$dir, "data_provenance.json")
    )
    rec <- new.env()
    rec$seen <- NULL
    testthat::local_mocked_bindings(fdl = function(
      url,
      tpath,
      attwb = NULL,
      allowfile = FALSE
    ) {
      rec$seen <- c(url, attwb)
      file.copy(cp$src, tpath)
    })
    expect_identical(cpsrfrsh(cp$dir)$change, "changed")
    expect_identical(
      rec$seen,
      c(prov$resource$direct_url, prov$wayback$csv_snapshot)
    )
    testthat::local_mocked_bindings(fdl = function(...) FALSE)
    utils::write.csv(data.frame(id = 1), cp$src, row.names = FALSE)
    expect_error(
      cpsrfrsh(cp$dir),
      "cpsrfrsh: the source could not be fetched: https://example.org/data.csv"
    )
    prov$resource$direct_url <- NULL
    prov$source$url <- "TODO: https://example.org/x.csv"
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cp$dir, "data_provenance.json")
    )
    expect_error(
      cpsrfrsh(cp$dir),
      "cpsrfrsh: the provenance names no source to fetch"
    )
    prov$source$url <- cp$src
    prov$resource$filename <- "../out.csv"
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cp$dir, "data_provenance.json")
    )
    expect_error(
      cpsrfrsh(cp$dir),
      paste0(
        "cpsrfrsh: resource\\$filename is not a plain relative path inside ",
        "the capsule"
      )
    )
    expect_error(
      cpsrfrsh(withr::local_tempdir()),
      "cpsrfrsh: no data_provenance.json in"
    )
    expect_error(
      cpsrfrsh(tempfile()),
      "cpsrfrsh: `dir` is not an existing directory"
    )
  }
)

test_that(
  paste0(
    "rmbl verify checks every capsule, the hmac secret from RMBL_KEY, and ",
    "exits by --fail-on"
  ),
  {
    no_stdin()
    root <- withr::local_tempdir()
    hm <- hmac_capsule()
    file.copy(hm, root, recursive = TRUE)
    cp <- src_capsule()
    cpsrfrsh(cp$dir)
    file.copy(cp$dir, root, recursive = TRUE)
    withr::local_envvar(RMBL_KEY = fx_secret)
    r <- run_cli(c("verify", root, "--public-key", fx_key_id))
    # the key is pinned: the unsigned capsule beside the signed one fails, or
    # deleting a capsule's bundle would pass the check
    expect_identical(r$status, 1L)
    expect_match(r$out, "no signed bundle", fixed = TRUE)
    expect_identical(Sys.getenv("RMBL_KEY"), "")
    expect_match(
      r$out,
      "## rmbl capsule verify with [rmoriebricklayer",
      fixed = TRUE
    )
    expect_match(r$out, "2 capsules under", fixed = TRUE)
    expect_match(
      r$out,
      "| Capsule | Source | SHA-256 | Size | Rows | Bounds | Result |",
      fixed = TRUE
    )
    expect_match(r$out, .rmbl_sym("round 5 \u00b7 supp 10"), fixed = TRUE)
    expect_match(r$out, "| example.org |", fixed = TRUE)
    expect_match(r$out, "bundle: attestation:signature", fixed = TRUE)
    expect_match(r$out, "schema: capsule_bundle.json", fixed = TRUE)
    # without the secret the hmac signature fails: an error, exit 1
    r <- run_cli(c("verify", root, "--json"))
    expect_identical(r$status, 1L)
    j <- fromjs(r$out)
    expect_identical(j$status, "error")
    expect_identical(j$mode, "verify")
    expect_true("attestation:signature" %in% j$checks$check[!j$checks$ok])
    expect_setequal(j$capsules$result, c("ok", "error"))
    # report prints the same and never fails; --format json too
    r <- run_cli(c("report", root))
    expect_identical(r$status, 0L)
    expect_match(r$out, "rmbl capsule report", fixed = TRUE)
    expect_identical(
      fromjs(run_cli(c("report", root, "--format", "json"))$out)$status,
      "error"
    )
  }
)

test_that("the capsule verbs refuse a usage error with exit status 2", {
  no_stdin()
  root <- withr::local_tempdir()
  expect_identical(run_cli(c("verify", root, "--fail-on", "never"))$status, 2L)
  r <- run_cli(c("verify", root, "--fail-on", "never"))
  expect_match(
    r$out,
    "--fail-on takes error, drift or warn, not 'never'",
    fixed = TRUE
  )
  expect_match(
    run_cli(c("report", root, "--format", "xml"))$out,
    "--format takes md or json, not 'xml'",
    fixed = TRUE
  )
  expect_match(
    run_cli(c("verify", file.path(root, "nope")))$out,
    "is not a directory",
    fixed = TRUE
  )
  r <- run_cli("verify")
  expect_identical(r$status, 2L)
  expect_match(r$out, "usage: rmoriebricklayer verify PATH", fixed = TRUE)
  expect_identical(run_cli(c("verify", root, root))$status, 2L)
  expect_identical(run_cli(c("refresh", root, "--json"))$status, 2L)
  expect_identical(run_cli(c("report", root, "--json"))$status, 2L)
  r <- run_cli(c("drift", "--help"))
  expect_identical(r$status, 0L)
  expect_match(r$out, "usage: rmoriebricklayer drift PATH", fixed = TRUE)
  expect_match(
    run_cli("help")$out,
    "Capsules (the checks of the rmbl GitHub Action)",
    fixed = TRUE
  )
  # nothing under the path: ok, and nothing to refresh
  r <- run_cli(c("verify", root))
  expect_identical(r$status, 0L)
  expect_match(r$out, "No manifests found under", fixed = TRUE)
  r <- run_cli(c("refresh", root))
  expect_identical(r$status, 0L)
  expect_match(r$out, "nothing to refresh", fixed = TRUE)
})

test_that("a capsule whose checks stop is one failed row", {
  no_stdin()
  root <- withr::local_tempdir()
  writeLines('{"files": []}', file.path(root, "capsule_bundle.json"))
  r <- run_cli(c("verify", root, "--json"))
  expect_identical(r$status, 1L)
  j <- fromjs(r$out)
  expect_identical(j$checks$check, "check_stopped")
  expect_match(j$checks$detail, "not a capsule bundle", fixed = TRUE)
  # a source given as file:// shows as a local file in the table
  writeLines(
    '{"source": {"url": "file:///tmp/x.csv"}}',
    file.path(root, "data_provenance.json")
  )
  unlink(file.path(root, "capsule_bundle.json"))
  expect_match(run_cli(c("report", root))$out, "| local file |", fixed = TRUE)
})

test_that(
  paste0(
    "rmbl drift: new bytes are a warning, drifting columns are drift, a ",
    "failed fetch an error"
  ),
  {
    no_stdin()
    cp <- src_capsule(data.frame(
      id = 1:200,
      v = rep(c("a", "b"), 100),
      stringsAsFactors = FALSE
    ))
    cpsrfrsh(cp$dir)
    r <- run_cli(c("drift", cp$dir, "--json"))
    expect_equal(r$status, 0L, tolerance = testthat::testthat_tolerance())
    j <- fromjs(r$out)
    expect_true(j$checks$ok[j$checks$check == "source_digest"])
    # other bytes, the same distribution: the digest row is a note, the columns
    # are within the bands
    utils::write.csv(
      data.frame(
        id = 1:200,
        v = rep(c("b", "a"), 100),
        stringsAsFactors = FALSE
      ),
      cp$src,
      row.names = FALSE
    )
    r <- run_cli(c("drift", cp$dir, "--json"))
    expect_equal(r$status, 0L, tolerance = testthat::testthat_tolerance())
    j <- fromjs(r$out)
    expect_equal(j$status, "ok", tolerance = testthat::testthat_tolerance())
    expect_equal(
      j$checks$severity[j$checks$check == "source_digest"],
      "note",
      tolerance = testthat::testthat_tolerance()
    )
    expect_true(j$checks$ok[j$checks$check == "source_columns"])
    expect_equal(
      run_cli(c("drift", cp$dir, "--fail-on", "warn"))$status,
      0L,
      tolerance = testthat::testthat_tolerance()
    )
    # a warn band at zero puts every column with any PSI past it
    r <- run_cli(c(
      "drift",
      cp$dir,
      "--json",
      "--psi-warn",
      "0",
      "--fail-on",
      "warn"
    ))
    expect_equal(r$status, 0L, tolerance = testthat::testthat_tolerance())
    expect_match(r$out, '"verdict": "ok"', fixed = TRUE)
    # a column that drifts, and one added: drift
    utils::write.csv(
      data.frame(id = 1:200 * 50, v = "a", w = 1, stringsAsFactors = FALSE),
      cp$src,
      row.names = FALSE
    )
    r <- run_cli(c("drift", cp$dir, "--json"))
    j <- fromjs(r$out)
    expect_equal(j$status, "drift", tolerance = testthat::testthat_tolerance())
    expect_equal(r$status, 0L, tolerance = testthat::testthat_tolerance())
    expect_identical(
      run_cli(c("drift", cp$dir, "--fail-on", "drift"))$status,
      1L
    )
    det <- j$checks$detail[j$checks$check == "source_columns"]
    expect_match(det, "added w", fixed = TRUE)
    utils::write.csv(data.frame(id = 1:200), cp$src, row.names = FALSE)
    j <- fromjs(run_cli(c("drift", cp$dir, "--json"))$out)
    expect_match(
      j$checks$detail[j$checks$check == "source_columns"],
      "removed v",
      fixed = TRUE
    )
    # a source that cannot be fetched
    unlink(cp$src)
    prov <- loadprov(file.path(cp$dir, "data_provenance.json"))
    prov$source$url <- "TODO"
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(cp$dir, "data_provenance.json")
    )
    j <- fromjs(run_cli(c("drift", cp$dir, "--json"))$out)
    expect_identical(j$status, "error")
    expect_identical(j$checks$check[nrow(j$checks)], "source_fetched")
    # a bundle-only capsule has nothing to fetch
    d <- withr::local_tempdir()
    file.copy(
      file.path(
        test_path("fixtures", "morie-hmac"),
        c("capsule_bundle.json", "d.csv")
      ),
      d
    )
    j <- fromjs(run_cli(c("drift", d, "--json"))$out)
    expect_false(any(j$checks$part == "drift"))
  }
)

test_that(
  paste0(
    "rmbl refresh pins each capsule and says when a bundle needs signing ",
    "again"
  ),
  {
    no_stdin()
    root <- withr::local_tempdir()
    cp <- src_capsule()
    file.copy(cp$dir, root, recursive = TRUE)
    sub <- file.path(root, basename(cp$dir))
    writeLines("{}", file.path(sub, "capsule_bundle.json"))
    r <- run_cli(c("refresh", root))
    expect_identical(r$status, 0L)
    expect_match(r$out, "Manifest diff: 1 changed", fixed = TRUE)
    expect_match(
      r$out,
      paste0(
        "capsule_bundle.json no longer matches the data: sign it again with ",
        "cpsbndl()"
      ),
      fixed = TRUE
    )
    prov <- loadprov(file.path(sub, "data_provenance.json"))
    prov$source$url <- "TODO"
    writeLines(
      tojs(prov, auto_unbox = TRUE),
      file.path(sub, "data_provenance.json")
    )
    r <- run_cli(c("refresh", root))
    expect_identical(r$status, 1L)
    expect_match(r$out, "the provenance names no source to fetch", fixed = TRUE)
  }
)

test_that("explerr() explains each failed check row", {
  rows <- data.frame(
    check = c(
      "data_present",
      "data_sha256",
      "file:d.csv",
      "schema: x.json",
      "odd",
      "check_stopped"
    ),
    ok = c(TRUE, FALSE, FALSE, FALSE, NA, FALSE),
    detail = c(
      "d.csv",
      "expected 01, got 02",
      "",
      "",
      "x",
      "cpsrfrsh: `dir` is not an existing directory: /nowhere"
    ),
    stringsAsFactors = FALSE
  )
  e <- explerr(rows)
  expect_identical(e$check, rows$check[-1L])
  expect_match(
    e$explanation[1L],
    "pin the new bytes with cpsrfrsh()",
    fixed = TRUE
  )
  expect_match(e$explanation[2L], "a bundled file is missing", fixed = TRUE)
  expect_match(e$explanation[3L], "JSON Schema", fixed = TRUE)
  expect_identical(e$explanation[4L], "a failed check: see the detail")
  expect_identical(e$raised_by[5L], "rmoriebricklayer::cpsrfrsh")
  expect_true(is.na(e$raised_by[2L]))
  expect_identical(nrow(explerr(rows[1L, ])), 0L)
  expect_error(
    explerr(data.frame(check = "x", stringsAsFactors = FALSE)),
    "explerr: a data frame of check rows needs the columns check, ok"
  )
})

test_that("the capsule verbs take the options of the rmbl action", {
  no_stdin()
  cp <- src_capsule(data.frame(
    id = 1:200,
    v = rep(c("a", "b"), 100),
    stringsAsFactors = FALSE
  ))
  cpsrfrsh(cp$dir)
  utils::write.csv(
    data.frame(
      id = 1:200 * 3,
      v = rep(c("a", "b"), 100),
      stringsAsFactors = FALSE
    ),
    cp$src,
    row.names = FALSE
  )
  r <- run_cli(c("drift", cp$dir, "--json"))
  expect_equal(
    fromjs(r$out)$status,
    "drift",
    tolerance = testthat::testthat_tolerance()
  )
  # a wide fail band makes the same change a warning
  r <- run_cli(c(
    "drift",
    cp$dir,
    "--json",
    "--psi-fail",
    "50",
    "--psi-warn",
    "0.2"
  ))
  expect_equal(
    fromjs(r$out)$status,
    "warn",
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(
    run_cli(c("drift", cp$dir, "--psi-fail", "50", "--fail-on", "warn"))$status,
    1L
  )
  r <- run_cli(c("drift", cp$dir, "--psi-warn", "x"))
  expect_identical(r$status, 2L)
  expect_match(r$out, "`psiwarn` must be", fixed = TRUE)
  r <- run_cli(c("drift", cp$dir, "--psi-warn", "0.5", "--psi-fail", "0.2"))
  expect_identical(r$status, 2L)
  expect_match(
    r$out,
    "`psiwarn` (0.5) must not exceed `psifail` (0.2)",
    fixed = TRUE
  )
  # the Markdown report carries the column table and, unless asked not to, the
  # footprint
  r <- run_cli(c("drift", cp$dir))
  expect_match(
    r$out,
    paste0(
      "| Verdict | Column | Type | Statistic | p | PSI (band) | JS | ",
      "Benford p (pinned / new) |"
    ),
    fixed = TRUE
  )
  expect_match(r$out, "Footprint of these checks (co2fp()", fixed = TRUE)
  expect_match(r$out, "fail-on `error`", fixed = TRUE)
  expect_false(grepl(
    "Footprint",
    run_cli(c("drift", cp$dir, "--no-footprint"))$out,
    fixed = TRUE
  ))
  expect_false(grepl("fail-on", run_cli(c("report", cp$dir))$out, fixed = TRUE))
  # file:// sources with --allow-file, --cache, --snapshot, --manifests, --base
  prov <- loadprov(file.path(cp$dir, "data_provenance.json"))
  prov$source$url <- paste0("file://", cp$src)
  writeLines(
    tojs(prov, auto_unbox = TRUE),
    file.path(cp$dir, "data_provenance.json")
  )
  expect_identical(
    fromjs(run_cli(c("drift", cp$dir, "--json"))$out)$status,
    "error"
  )
  cache <- withr::local_tempdir()
  r <- run_cli(c(
    "drift",
    cp$dir,
    "--json",
    "--allow-file",
    "--cache",
    cache,
    "--snapshot"
  ))
  j <- fromjs(r$out)
  expect_equal(j$status, "drift", tolerance = testthat::testthat_tolerance())
  # a local source is read in place, never cached
  expect_length(list.files(cache), 0L)
  expect_true(
    "snapshot: not looked up (not an http(s) source)" %in%
      unlist(j$capsules$notes)
  )
  r <- run_cli(c("verify", dirname(cp$dir), "--manifests", "nothing/*"))
  expect_match(r$out, "No manifests found under", fixed = TRUE)
  m <- withr::local_tempfile(fileext = ".json")
  writeLines('{"resource": {"filename": "data.csv", "sha256": "01"}}', m)
  writeLines(
    '{"resource": {"filename": "data.csv", "sha256": "02"}}',
    file.path(cp$dir, "manifest.json")
  )
  r <- run_cli(c("report", cp$dir, "--base", m))
  expect_identical(r$status, 0L)
  expect_match(
    r$out,
    sprintf("### Manifests against `%s`: changed", m),
    fixed = TRUE
  )
  r <- run_cli(c("verify", cp$dir, "--base", file.path(cp$dir, "nope")))
  expect_identical(r$status, 2L)
  expect_match(
    r$out,
    "`base` is not an existing manifest file or folder",
    fixed = TRUE
  )
  expect_match(run_cli(c("drift", "--help"))$out, "--psi-warn", fixed = TRUE)
  expect_identical(run_cli(c("refresh", cp$dir, "--allow-file"))$status, 2L)
})

test_that(
  paste0(
    "rmbl sign pins and signs each capsule with RMBL_KEY or a key file, ",
    "then verifies"
  ),
  {
    no_stdin()
    root <- withr::local_tempdir()
    d <- file.path(root, "one")
    dir.create(d)
    utils::write.csv(
      data.frame(x = 1:5),
      file.path(d, "data.csv"),
      row.names = FALSE
    )
    writeLines(
      '{"resource": {"filename": "data.csv"}}',
      file.path(d, "data_provenance.json")
    )
    r <- run_cli(c("sign", root))
    expect_identical(r$status, 2L)
    expect_match(
      r$out,
      "sign needs a key: RMBL_KEY in the environment, or --key-file FILE",
      fixed = TRUE
    )
    withr::local_envvar(RMBL_KEY = "the shared secret")
    r <- run_cli(c("sign", root))
    expect_identical(r$status, 0L)
    expect_identical(Sys.getenv("RMBL_KEY"), "")
    expect_match(
      r$out,
      "signed .*one: 2 files, hmac key id [0-9a-f]{16} \\(provenance pinned\\)"
    )
    expect_false(grepl("the shared secret", r$out, fixed = TRUE))
    expect_match(
      r$out,
      .rmbl_sym("| \u2714 pass | bundle: attestation:signature | - |"),
      fixed = TRUE
    )
    # a bundle is there: refused without --overwrite
    withr::local_envvar(RMBL_KEY = "the shared secret")
    r <- run_cli(c("sign", root))
    expect_identical(r$status, 1L)
    expect_match(r$out, "capsule_bundle.json already exists in", fixed = TRUE)
    # a key file: the secret, or a post-quantum key as JSON, or its secret hex
    # with --public-key
    kf <- withr::local_tempfile()
    writeLines("the shared secret", kf)
    r <- run_cli(c("sign", root, "--key-file", kf, "--overwrite", "--json"))
    expect_identical(r$status, 0L)
    expect_identical(fromjs(sub("^[^{]*", "", r$out))$status, "ok")
    key <- fipskg("ML-DSA-44")
    writeLines(tojs(unclass(key), auto_unbox = TRUE), kf)
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--scheme",
      "ML-DSA-44",
      "--overwrite"
    ))
    expect_identical(r$status, 0L)
    expect_match(
      r$out,
      sprintf("public key %s", substr(key$public, 1, 16)),
      fixed = TRUE
    )
    writeLines(key$secret, kf)
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--scheme",
      "ML-DSA-44",
      "--public-key",
      key$public,
      "--overwrite",
      "--manifests",
      "*"
    ))
    expect_identical(r$status, 0L)
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--scheme",
      "ML-DSA-44",
      "--overwrite"
    ))
    expect_identical(r$status, 2L)
    expect_match(
      r$out,
      "--scheme ML-DSA-44 with a bare secret key needs --public-key HEX",
      fixed = TRUE
    )
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--scheme",
      "ML-DSA-65",
      "--public-key",
      key$public,
      "--overwrite"
    ))
    expect_identical(r$status, 2L)
    expect_match(r$out, "the key: ", fixed = TRUE)
    # an xmss-sha256 key must be the JSON of a pqckg() key (test-xmss-cli.R
    # signs with one)
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--scheme",
      "xmss-sha256",
      "--overwrite"
    ))
    expect_identical(r$status, 1L)
    expect_match(r$out, "the key is not an xmss-sha256 key", fixed = TRUE)
    expect_identical(
      run_cli(c("sign", root, "--key-file", file.path(root, "nope")))$status,
      2L
    )
    # signed with one key, verified against another: fails by --fail-on
    writeLines("the shared secret", kf)
    r <- run_cli(c(
      "sign",
      root,
      "--key-file",
      kf,
      "--overwrite",
      "--public-key",
      strrep("00ff", 8)
    ))
    expect_identical(r$status, 1L)
    expect_match(
      run_cli(c("sign", "--help"))$out,
      "usage: rmoriebricklayer sign PATH",
      fixed = TRUE
    )
  }
)

test_that("the gunzip copy refuses a directory by name", {
  d <- withr::local_tempdir()
  expect_error(
    .bl_gunzip_copy(d, tempfile()),
    "is a directory, not a file"
  )
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("a manifest diff prints as a box", {
  a <- data.frame(path = "a.csv", sha256 = "01", stringsAsFactors = FALSE)
  b <- data.frame(path = "a.csv", sha256 = "02", stringsAsFactors = FALSE)
  d <- mnfdiff(a, b)
  o1_expect_box(
    o1_box(d),
    d,
    "Manifest diff",
    c("1 changed, 0 added", "sha256 01 -> 02")
  )
  same <- mnfdiff(a, a)
  expect_true(any(grepl("same bytes", format(same), fixed = TRUE)))
  expect_true(any(grepl(
    "change",
    format(d[, "change", drop = FALSE]),
    fixed = TRUE
  )))
})

test_that("a pinned public key is checked, never dropped in silence", {
  no_stdin()
  cp <- hmac_capsule()
  unlink(file.path(cp, "capsule_bundle.json"))
  # blank, not hex, or too short: a usage error
  for (k in c(" ", "x", "abcd", "zz00zz00zz00zz00")) {
    expect_identical(run_cli(c("verify", cp, "--public-key", k))$status, 2L,
                     info = k)
  }
  # a key pinned against a capsule with no signature fails it
  base <- run_cli(c("verify", cp))$status
  r <- run_cli(c("verify", cp, "--public-key", fx_key_id))
  expect_identical(r$status, 1L)
  expect_match(r$out, "no signed bundle", fixed = TRUE)
  expect_identical(cpschk(cp, "verify", pubkey = fx_key_id, fp = FALSE)$status,
                   "error")
  expect_identical(cpschk(cp, "verify", fp = FALSE)$status == "error",
                   base != 0L)
  expect_error(cpschk(cp, "verify", pubkey = "x", fp = FALSE), "hexadecimal")
})

test_that("verify refuses a local source that refresh and drift refuse", {
  no_stdin()
  outside <- withr::local_tempfile(fileext = ".csv")
  writeLines("a,b\n1,2", outside)
  for (src in c(outside, paste0("file://", outside), "../elsewhere.csv")) {
    cp <- src_capsule()
    pf <- file.path(cp$dir, "data_provenance.json")
    prov <- fromjs(paste(readLines(pf), collapse = "\n"))
    prov$source$url <- src
    writeLines(tojs(prov, auto_unbox = TRUE), pf)
    r <- run_cli(c("verify", cp$dir))
    expect_identical(r$status, 1L, info = src)
    x <- cpschk(cp$dir, "verify", fp = FALSE)
    expect_true("source: local path" %in% x$rows$check[!x$rows$ok],
                info = src)
  }
  # a source inside the capsule stays fine
  cp <- src_capsule()
  x <- cpschk(cp$dir, "verify", fp = FALSE)
  expect_false("source: local path" %in% x$rows$check)
})
