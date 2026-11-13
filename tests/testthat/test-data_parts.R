# Large curated tables come down in byte-range parts: kept once whole, resumed
# from the first missing part, joined in order. No network: the transport is a
# stub that serves the range asked for from a local file.

test_that("a large table comes in parts, resumed and joined in order", {
  st <- new.env()
  src <- withr::local_tempfile()
  set.seed(1)
  bytes <- as.raw(sample(0:255, 5000, replace = TRUE))
  writeBin(bytes, src)
  st$seen <- character()
  testthat::local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    bldl = function(url, dest, headers = NULL, maxbytes = 2^31, ...) {
      rng <- sub("^bytes=", "", headers[["Range"]])
      r <- as.numeric(strsplit(rng, "-", fixed = TRUE)[[1]])
      st$seen <- c(st$seen, headers[["Range"]])
      writeBin(bytes[(r[1] + 1):(r[2] + 1)], dest)
      invisible(dest)
    }
  )
  dest <- withr::local_tempfile()
  ns <- asNamespace("rmoriebricklayer")
  ns$.bl_data_get_parts("/db/t.csv.gz", dest, c(`User-Agent` = "x"), "db/t",
                        5000, 1024, 60)
  expect_identical(readBin(dest, "raw", 6000), bytes)
  expect_identical(st$seen, c(
    "bytes=0-1023", "bytes=1024-2047", "bytes=2048-3071",
    "bytes=3072-4095", "bytes=4096-4999"
  ))
  expect_false(dir.exists(paste0(dest, ".parts")))
  # a broken earlier run: parts 1 and 2 whole, part 3 short; 3-5 are fetched
  unlink(dest)
  pd <- paste0(dest, ".parts")
  dir.create(pd)
  writeBin(bytes[1:1024], file.path(pd, "00001"))
  writeBin(bytes[1025:2048], file.path(pd, "00002"))
  writeBin(bytes[2049:2100], file.path(pd, "00003"))
  st$seen <- character()
  ns$.bl_data_get_parts("/db/t.csv.gz", dest, c(`User-Agent` = "x"), "db/t",
                        5000, 1024, 60)
  expect_identical(readBin(dest, "raw", 6000), bytes)
  expect_identical(
    st$seen,
    c("bytes=2048-3071", "bytes=3072-4095", "bytes=4096-4999")
  )
})

test_that("a short part is refused and dropped, to resume later", {
  testthat::local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    bldl = function(url, dest, ...) {
      writeBin(as.raw(1:10), dest)
      invisible(dest)
    }
  )
  dest <- withr::local_tempfile()
  ns <- asNamespace("rmoriebricklayer")
  expect_error(
    ns$.bl_data_get_parts(
      "/db/t.csv.gz", dest, character(), "db/t", 5000, 1024, 60
    ),
    "part 1 of db/t came back with 10 bytes, not 1024; run again to resume"
  )
  expect_false(file.exists(file.path(paste0(dest, ".parts"), "00001")))
})

test_that("only a table more than twice the part size goes in parts", {
  st <- new.env()
  ns <- asNamespace("rmoriebricklayer")
  withr::local_options(rmoriebricklayer.dpart = 2^20)
  expect_identical(ns$.bl_data_part_bytes(), 2^20)
  withr::local_options(rmoriebricklayer.dpart = 10)
  expect_error(ns$.bl_data_part_bytes(), "at least 1 MB")
  withr::local_options(rmoriebricklayer.dpart = NULL)
  expect_identical(ns$.bl_data_part_bytes(), 90 * 2^20)
  st$called <- NULL
  testthat::local_mocked_bindings(
    .bl_data_label = function(path) list(label = "db/t", size = 300 * 2^20),
    .bl_data_get_parts = function(path, dest, hdr, label, size, part, timeout) {
      st$called <- c(size, part)
      invisible(dest)
    }
  )
  ns$.bl_data_get("/db/t.csv.gz", withr::local_tempfile())
  expect_identical(st$called, c(300 * 2^20, 90 * 2^20))
})

test_that("a refused table says why: ICPSR, or a key asked for", {
  ns <- asNamespace("rmoriebricklayer")
  fail <- "bldl: https://data.example.org/x answered HTTP 410"
  testthat::local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    .bl_data_label = function(path) list(label = "icpsr_9/t", size = NULL),
    bldl = function(...) stop(fail, call. = FALSE)
  )
  dest <- withr::local_tempfile()
  expect_error(
    ns$.bl_data_get("/icpsr_9/t.csv.gz", dest),
    "icpsr_9/t is not served by data.rmorie.com: ICPSR's terms"
  )
  fail <- "bldl: https://data.example.org/x answered HTTP 401"
  expect_error(
    ns$.bl_data_get("/icpsr_9/t.csv.gz", dest),
    "data.rmorie.com asked for a key for icpsr_9/t"
  )
})

test_that("a part whose download fails says why, as a whole download does", {
  testthat::local_mocked_bindings(
    .bl_data_url = function() "https://data.example.org",
    bldl = function(...) {
      stop("bldl: https://data.example.org/x answered HTTP 410", call. = FALSE)
    }
  )
  ns <- asNamespace("rmoriebricklayer")
  expect_error(
    ns$.bl_data_get_parts(
      "/icpsr_9/t.csv.gz", withr::local_tempfile(), character(), "icpsr_9/t",
      5000, 1024, 60
    ),
    "icpsr_9/t is not served by data.rmorie.com"
  )
})
