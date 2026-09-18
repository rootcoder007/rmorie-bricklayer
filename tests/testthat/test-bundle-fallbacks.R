# The capsule bundle sources R/ files standalone with no family package
# installed; these helpers then take their base-R branch. Each fallback
# must agree with the compiled kernel it stands in for.

test_that(".rmbl_column_stats base-R branch matches the compiled kernels", {
  set.seed(7)
  ok <- c(rnorm(40), 5, -6, 0.5)
  a <- .rmbl_column_stats(ok, native = TRUE)
  b <- .rmbl_column_stats(ok, native = FALSE)
  for (nm in c("mean", "sd", "skewness", "median", "mad", "lower", "upper"))
    expect_equal(b[[nm]], a[[nm]], tolerance = 1e-10, label = nm)
  expect_true(is.character(a$hist))
  expect_identical(b$hist, NA_character_)
  # degenerate: one value has no sd or skewness
  one <- .rmbl_column_stats(3, native = FALSE)
  expect_true(is.nan(one$sd))
  expect_true(is.nan(one$skewness))
  expect_equal(one$median, 3)
})

test_that(".rmbl_sha256_bytes pure-R branch matches core_sha256", {
  bytes <- charToRaw("{\"a\":1,\"b\":[1,2,3]}")
  expect_identical(.rmbl_sha256_bytes(bytes, native = FALSE),
                   .rmbl_sha256_bytes(bytes, native = TRUE))
  expect_identical(.rmbl_sha256_bytes(bytes, native = FALSE),
                   core_sha256(bytes))
  m <- list(name = "x", version = "1", files = list())
  expect_identical(manifest_digest(m),
                   .rmbl_sha256_bytes(charToRaw(manifest_canonical(m)),
                                      native = FALSE))
})

test_that(".rmbl_fetch_url download.file branch fetches a file URL", {
  src <- tempfile(fileext = ".json")
  writeLines("{\"k\": 1}", src)
  dest <- tempfile(fileext = ".json")
  on.exit(unlink(c(src, dest)), add = TRUE)
  url <- paste0("file://", normalizePath(src, winslash = "/"))
  expect_invisible(.rmbl_fetch_url(url, dest, native = FALSE))
  expect_identical(readLines(dest), "{\"k\": 1}")
})
