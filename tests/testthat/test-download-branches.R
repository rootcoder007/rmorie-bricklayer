# The branches of the download helper, the data hub transport and the CLI that the
# happy-path tests do not reach: terminal rendering, unknown sizes, rejected keys,
# the manifest size lookup, the staged-bundle fallback, the data verbs, R 4.6's --args.

test_that("bricklayer_download draws a live bar on a terminal and a spinner without a size", {
  src <- withr::local_tempfile(fileext = ".bin")
  writeBin(as.raw(rep(66L, 2 * 1048576 + 3)), src)
  dest <- withr::local_tempfile(fileext = ".bin")
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL)
  bar <- utils::capture.output(
    bricklayer_download(paste0("file://", src), dest, label = "two-mb", size = file.size(src), tty = TRUE),
    type = "message"
  )
  expect_true(any(grepl("\r", bar, fixed = TRUE)) || any(grepl("%", bar, fixed = TRUE)))
  expect_true(any(grepl("two-mb: 2.0 MB in", bar, fixed = TRUE)))
  expect_identical(file.size(dest), file.size(src))
  spin <- utils::capture.output(
    bricklayer_download(paste0("file://", src), dest, label = "nosize", tty = TRUE),
    type = "message"
  )
  expect_identical(.bl_fmt_bytes(Inf), "?")
  expect_true(any(grepl("nosize: 2.0 MB in", spin, fixed = TRUE)))
})

test_that("off a terminal and without a size the helper prints a plain header and the total", {
  src <- withr::local_tempfile(fileext = ".bin")
  writeBin(as.raw(rep(67L, 1024)), src)
  dest <- withr::local_tempfile(fileext = ".bin")
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL)
  msgs <- utils::capture.output(
    bricklayer_download(paste0("file://", src), dest, label = "small", tty = FALSE),
    type = "message"
  )
  expect_true(any(grepl("small: downloading", msgs, fixed = TRUE)))
  expect_true(any(grepl("small: 1.0 KB in", msgs, fixed = TRUE)))
  expect_error(bricklayer_download(paste0("file://", src), dest, size = "x", quiet = TRUE), NA)
})

test_that(".bl_data_get maps a refused key and other transport errors to words", {
  cfg <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = cfg, MORIE_HOSTED_KEY = "sk-test")
  withr::local_options(rmoriebricklayer.data_cache = withr::local_tempdir())
  testthat::local_mocked_bindings(
    bricklayer_download = function(url, dest, ...) stop("cannot open URL: HTTP status was '401 Unauthorized'")
  )
  expect_error(.bl_data_get("/manifest.json", tempfile()), "rejected the stored key")
  testthat::local_mocked_bindings(
    bricklayer_download = function(url, dest, ...) stop("Could not resolve host")
  )
  expect_error(.bl_data_get("/manifest.json", tempfile()), "data.rmorie.com")
})

test_that(".bl_data_get passes the manifest's compressed size for a table", {
  cfg <- withr::local_tempdir()
  withr::local_envvar(XDG_CONFIG_HOME = cfg, MORIE_HOSTED_KEY = "sk-test")
  withr::local_options(rmoriebricklayer.data_cache = withr::local_tempdir())
  seen <- NULL
  testthat::local_mocked_bindings(
    bricklayer_data_manifest = function(...) list(datasets = list(list(key = "db/tbl", bytes_gz = 4321))),
    bricklayer_download = function(url, dest, headers = NULL, label = NULL, size = NULL, ...) {
      seen <<- list(url = url, label = label, size = size, auth = headers[["Authorization"]])
      writeLines("x", dest)
      invisible(dest)
    }
  )
  .bl_data_get("/db/tbl.csv.gz", tempfile())
  expect_identical(seen$size, 4321)
  expect_identical(seen$label, "db/tbl")
  expect_identical(seen$auth, "Bearer sk-test")
})

test_that("a staged bundle without bricklayer_download falls back to base R", {
  called <- NULL
  testthat::local_mocked_bindings(exists = function(x, ...) FALSE, .package = "base")
  testthat::local_mocked_bindings(
    download.file = function(url, destfile, ...) {
      called <<- url
      writeLines("ok", destfile)
      0L
    },
    .package = "utils"
  )
  dest <- withr::local_tempfile()
  .bl_fetch_file("https://example.org/x.csv", dest)
  expect_identical(called, "https://example.org/x.csv")
  expect_identical(readLines(dest), "ok")
})

test_that("the CLI strips R 4.6's --args and serves the data verbs", {
  out <- character()
  st <- bricklayer_cli(c("--args", "version"), out = function(s) out <<- c(out, s))
  expect_identical(st, 0L)
  expect_true(any(grepl("rmoriebricklayer", out)))
  testthat::local_mocked_bindings(
    bricklayer_data_tables = function(...) {
      data.frame(key = c("db/a", "db/b"), rows = c(1L, 2L), name = c("A", "B"),
                 source = c("s", "s"), stringsAsFactors = FALSE)
    },
    bricklayer_data_load = function(key, ...) data.frame(x = 1:3, y = c("a", "b", "c"))
  )
  out <- character()
  expect_identical(bricklayer_cli(c("data", "list"), out = function(s) out <<- c(out, s)), 0L)
  expect_true(any(grepl("db/a", out, fixed = TRUE)))
  dest <- withr::local_tempfile(fileext = ".csv")
  out <- character()
  expect_identical(bricklayer_cli(c("data", "pull", "db/a", "--out", dest), out = function(s) out <<- c(out, s)), 0L)
  expect_identical(nrow(utils::read.csv(dest)), 3L)
  out <- character()
  expect_identical(bricklayer_cli(c("data", "nonsense"), out = function(s) out <<- c(out, s)), 2L)
})

test_that("the data cache directory defaults to tempdir and an empty manifest lists no tables", {
  withr::local_options(rmoriebricklayer.data_cache = NULL)
  expect_true(startsWith(.bl_data_cache_dir(), tempdir()))
  testthat::local_mocked_bindings(bricklayer_data_manifest = function(...) list(datasets = list()))
  expect_identical(nrow(bricklayer_data_tables()), 0L)
})
