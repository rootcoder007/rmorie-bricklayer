# The boundary defects of the 0.5.5 review: what the tool does when a check
# cannot be made, and when the bytes are hostile.

make_capsule <- function() {
  d <- file.path(tempfile("rmbl-cap-"), "caps")
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(d, "data.csv")
  write.csv(
    data.frame(
      region = c("A", "B"),
      count = c(10, 20),
      stringsAsFactors = FALSE
    ),
    f,
    row.names = FALSE
  )
  list(dir = d, file = f, sha = sha256file(f))
}
write_prov <- function(d, txt) {
  writeLines(txt, file.path(d, "data_provenance.json"))
}

test_that("vrfcps fails when it cannot check, not only when a check fails", {
  cp <- make_capsule()
  write_prov(
    cp$dir,
    sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha)
  )
  honest <- vrfcps(cp$dir)
  expect_s3_class(honest, "bricklayer_capsule_check")
  expect_true(honest$ok)
  expect_output(print(honest), "intact")

  # alter the data, then delete one field at a time: every one must FAIL
  write.csv(
    data.frame(
      region = c("A", "B"),
      count = c(10, 999),
      stringsAsFactors = FALSE
    ),
    cp$file,
    row.names = FALSE
  )
  write_prov(
    cp$dir,
    sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha)
  )
  expect_false(vrfcps(cp$dir)$ok)
  write_prov(cp$dir, '{"resource":{"filename":"data.csv"}}')
  r <- vrfcps(cp$dir)
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "data_sha256"])
  expect_match(
    r$checks$detail[r$checks$check == "data_sha256"],
    "no sha256 recorded"
  )
  write_prov(cp$dir, '{"resource":{"other":"x"}}')
  expect_false(vrfcps(cp$dir)$ok)
  write_prov(cp$dir, '{"meta":{"note":"none"}}')
  expect_false(vrfcps(cp$dir)$ok)
  write_prov(cp$dir, "{}")
  r <- vrfcps(cp$dir)
  expect_false(r$ok)
  expect_output(print(r), "NOT VERIFIED")
})

test_that("vrfcps refuses a path that escapes the capsule", {
  cp <- make_capsule()
  outside <- file.path(dirname(cp$dir), "outside.csv")
  writeLines("content outside the capsule", outside)
  write_prov(
    cp$dir,
    sprintf(
      '{"resource":{"filename":"../outside.csv","sha256":"%s"}}',
      sha256file(outside)
    )
  )
  r <- vrfcps(cp$dir)
  expect_false(r$ok)
  expect_false(r$checks$ok[r$checks$check == "data_present"])
  expect_null(.rmbl_safe_rel("../x", cp$dir))
  expect_null(.rmbl_safe_rel("/etc/passwd", cp$dir))
  expect_null(.rmbl_safe_rel("C:/x", cp$dir))
  expect_null(.rmbl_safe_rel("~/x", cp$dir))
  expect_type(
    .rmbl_safe_rel("sub/data.csv", cp$dir),
    "character"
  )
})

test_that(
  paste0(
    "vrfcps treats a pinned script digest ",
    "and a synthetic sidecar as checks"
  ),
  {
    cp <- make_capsule()
    write_prov(
      cp$dir,
      sprintf(
        paste0(
          '{"resource":{"filename":"data.csv","sha256":"%s"},"script":{"sha25',
          '6":"%s"}}'
        ),
        cp$sha,
        strrep("0", 64)
      )
    )
    r <- vrfcps(cp$dir)
    expect_false(r$ok)
    expect_match(
      r$checks$detail[r$checks$check == "script_sha256"],
      "no script file is named"
    )
    write_prov(
      cp$dir,
      sprintf('{"resource":{"filename":"data.csv","sha256":"%s"}}', cp$sha)
    )
    writeLines('{"synthetic":true}', paste0(cp$file, ".synthetic"))
    r <- vrfcps(cp$dir)
    expect_false(r$ok)
    expect_true("data_not_synthetic" %in% r$checks$check)
  }
)

test_that(
  paste0(
    "the JSON parser refuses duplicate keys, ",
    "deep nesting and lone surrogates"
  ),
  {
    expect_error(fromjs('{"sha256":"aaaa","sha256":"bbbb"}'), "duplicate key")
    kept <- fromjs(
      '{"a":1,"a":2}',
      duplicate_keys = "keep",
      simplifyVector = FALSE
    )
    expect_length(kept, 2L)
    deep <- paste0(strrep("[", 20000), strrep("]", 20000))
    expect_error(fromjs(deep), "nesting deeper than 100")
    expect_error(fromjs('{"k":"\\ud800"}'), "lone surrogate")
    expect_identical(fromjs('{"k":"\\ud83d\\ude00"}')$k, "\U0001F600")
    expect_warning(
      assign("v", fromjs("[12345678901234567890]")),
      "exceeds 2\\^53"
    )
    expect_identical(
      fromjs("[12345678901234567890]", bigint_as_char = TRUE),
      "12345678901234567890"
    )
  }
)

test_that("jsunser rebuilds data, not code, unless trusted", {
  f <- factor(c("b", "a"), levels = c("a", "b", "c"))
  expect_identical(jsunser(jsser(f)), f)
  expect_error(jsunser(jsser(sum)), "refuses to rebuild a 'builtin'")
  expect_error(
    jsunser(jsser(quote(system("true")))),
    "refuses to rebuild a 'language'"
  )
  expect_error(
    jsunser(jsser(function(x) x + 1)),
    "refuses to rebuild a 'closure'"
  )
  expect_identical(jsunser(jsser(sum), trusted = TRUE), sum)
})

test_that("canonicalisation sorts a level with an empty-string key", {
  a <- stats::setNames(list(1, 2, 3), c("b", "", "a"))
  b <- stats::setNames(list(3, 1, 2), c("a", "b", ""))
  expect_identical(
    mnfcanon(list(meta = a, results = list())),
    mnfcanon(list(meta = b, results = list()))
  )
})

test_that("public URLs are https, public and never file://", {
  chk <- .rmbl_check_public_url
  expect_identical(
    chk("https://data.ontario.ca/x.csv"),
    "https://data.ontario.ca/x.csv"
  )
  expect_error(chk("file:///etc/passwd"), "https://")
  expect_error(chk("http://data.ontario.ca/x.csv"), "https://")
  expect_error(chk("https://localhost:8080/"), "local or private")
  expect_error(chk("https://127.0.0.1/"), "local or private")
  expect_error(
    chk("https://169.254.169.254/latest/meta-data/"),
    "local or private"
  )
  expect_error(chk("https://10.0.0.5/"), "local or private")
  expect_error(chk("https://192.168.1.1/"), "local or private")
  expect_error(chk("https://172.16.0.1/"), "local or private")
  expect_error(chk("https://[::1]/"), "local or private")
  expect_error(chk("https://user@[fe80::1]/"), "local or private|refused")
  expect_identical(chk("https://172.32.0.1/"), "https://172.32.0.1/")
  withr::local_options(rmoriebricklayer.allowhttp = TRUE)
  expect_identical(chk("http://data.ontario.ca/"), "http://data.ontario.ca/")
  tf <- tempfile()
  writeLines("LOCAL", tf)
  expect_error(bldl(paste0("file://", tf), tempfile()), "https://")
  dest <- tempfile()
  bldl(paste0("file://", tf), dest, quiet = TRUE, allowfile = TRUE)
  expect_identical(readLines(dest), "LOCAL")
})

test_that("a capsule bundle covers dotfiles and refuses escaping paths", {
  d <- tempfile("bundle-")
  dir.create(d)
  writeLines("x", file.path(d, "a.txt"))
  writeLines("setwd('/')", file.path(d, ".Rprofile"))
  key <- pqckg(height = 2L)
  man <- mkmnf(list(project = "p"), env = FALSE)
  b <- cpsbndl(d, man, key)
  expect_true(".Rprofile" %in% vapply(b$files, function(e) e$path, ""))
  chk <- cpsbndlvrf(file.path(d, "capsule_bundle.json"), d, man = man)
  expect_true(chk$ok)
  writeLines("y", file.path(d, ".hidden"))
  chk2 <- cpsbndlvrf(file.path(d, "capsule_bundle.json"), d, man = man)
  expect_false(chk2$checks$ok[chk2$checks$check == "no_unlisted_files"])
})

test_that("gzip JSON refuses a bomb by its ISIZE trailer", {
  g <- jsgzenc(list(a = 1))
  expect_identical(jsgzdec(g)$a, 1L)
  bytes <- jsb64dec(g)
  bytes[(length(bytes) - 3L):length(bytes)] <- as.raw(c(0xff, 0xff, 0xff, 0xff))
  expect_error(jsgzdec(bytes), "ISIZE")
})

test_that(
  paste0(
    "the synthetic flag belongs to the package, and synthetic data carry a ",
    "sidecar"
  ),
  {
    withr::local_envvar(BRICKLAYER_SYNTHETIC = "1")
    m <- mkmnf(list(project = "p"), env = FALSE)
    expect_true(m$meta$synthetic)
    m <- recrd(m, "n", obs = 5, expd = 5)
    expect_identical(m$results$n$status, "INFO")
    p <- wrmnfjs(
      list(meta = list(project = "q"), results = list()),
      tempfile(fileext = ".json")
    )
    expect_true(fromjs(p, simplifyVector = FALSE)$meta$synthetic)
    withr::local_envvar(BRICKLAYER_SYNTHETIC = NA)
    schema <- list(
      seed = 3L,
      n_rows = 5L,
      columns = list(region = list(type = "sample", values = list("E", "W")))
    )
    f <- tempfile(fileext = ".csv")
    info <- mksyncsv(schema, f)
    expect_s3_class(info, "bricklayer_synthetic")
    expect_true(file.exists(paste0(f, ".synthetic")))
    expect_output(print(info), "SYNTHETIC")
  }
)

test_that("hostile DER is an error, not an abort", {
  h <- "301405000488fffffffffffffff40000000000000000"
  b <- as.raw(strtoi(
    substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)),
    16L
  ))
  expect_error(
    .Call(C_rmbl_der_parse, b),
    "not well-formed DER"
  )
  h2 <- "300c0488ffffffffffffffff0100"
  b2 <- as.raw(strtoi(
    substring(h2, seq(1, nchar(h2), 2), seq(2, nchar(h2), 2)),
    16L
  ))
  expect_error(
    .Call(C_rmbl_der_parse, b2),
    "not well-formed DER"
  )
})

test_that("a DRBG reseeds itself in a new process", {
  skip_on_os("windows")
  skip_if_not_installed("parallel")
  d <- drbgnew(as.raw(0:47))
  expect_identical(d$pid, Sys.getpid())
  parent <- drbggen(d, 16)
  # the SAME generator object, used in a forked child: the child's pid
  # differs, so it must reseed and produce other bytes than the parent's
  # deterministic continuation would
  d2 <- drbgnew(as.raw(0:47))
  job <- parallel::mcparallel(drbggen(d2, 16))
  child <- parallel::mccollect(job)[[1L]]
  expect_false(identical(child, parent))
  expect_false(identical(child, drbggen(drbgnew(as.raw(0:47)), 16)))
  # while two generators in one process from one seed agree
  expect_identical(
    drbggen(drbgnew(as.raw(0:47)), 16),
    drbggen(drbgnew(as.raw(0:47)), 16)
  )
})
