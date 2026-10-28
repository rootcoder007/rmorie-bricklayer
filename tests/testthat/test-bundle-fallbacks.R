# The capsule bundle sources R/ files standalone with no family package
# installed; these helpers then take their base-R branch. Each fallback
# must agree with the compiled kernel it stands in for.

test_that(".rmbl_column_stats base-R branch matches the compiled kernels", {
  set.seed(7)
  ok <- c(rnorm(40), 5, -6, 0.5)
  a <- .rmbl_column_stats(ok, native = TRUE)
  b <- .rmbl_column_stats(ok, native = FALSE)
  for (nm in c("mean", "sd", "skewness", "median", "mad", "lower", "upper")) {
    expect_equal(b[[nm]], a[[nm]], tolerance = 1e-10, label = nm)
  }
  expect_type(a$hist, "character")
  expect_identical(b$hist, NA_character_)
  # degenerate: one value has no sd or skewness
  one <- .rmbl_column_stats(3, native = FALSE)
  expect_true(is.nan(one$sd))
  expect_true(is.nan(one$skewness))
  expect_equal(one$median, 3, tolerance = 1e-8)
})

test_that(".rmbl_sha256_bytes pure-R branch matches csha256", {
  bytes <- charToRaw("{\"a\":1,\"b\":[1,2,3]}")
  expect_identical(
    .rmbl_sha256_bytes(bytes, native = FALSE),
    .rmbl_sha256_bytes(bytes, native = TRUE)
  )
  expect_identical(.rmbl_sha256_bytes(bytes, native = FALSE), csha256(bytes))
  m <- list(name = "x", version = "1", files = list())
  expect_identical(
    mnfdgst(m),
    .rmbl_sha256_bytes(charToRaw(mnfcanon(m)), native = FALSE)
  )
})

test_that(".rmbl_fetch_url's bundle branch uses the bundle fetcher", {
  # the base-R branch is the bundle fetcher, with the URL policy and a
  # 16 MiB cap (download.file() fetched any address, 1.0.3 recheck #13)
  got <- new.env()
  local_mocked_bindings(.rmbl_bfetch = function(url, dest, cap, ...) {
    got$url <- url
    got$cap <- cap
    writeLines("{\"k\": 1}", dest)
    invisible(dest)
  })
  dest <- withr::local_tempfile(fileext = ".json")
  expect_invisible(
    .rmbl_fetch_url("https://example.org/m.json", dest, native = FALSE)
  )
  expect_identical(readLines(dest), "{\"k\": 1}")
  expect_identical(got$url, "https://example.org/m.json")
  expect_identical(got$cap, 16777216)
})
