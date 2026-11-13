test_that("jsgzdec refuses a damaged gzip member at once", {
  enc <- jsgzenc(list(a = seq_len(5000)), raw = TRUE)
  bad <- enc
  mid <- 11:(length(bad) - 8L)
  bad[mid] <- rev(bad[mid])
  expect_error(jsgzdec(bad), "jsgzdec: `txt` is")
  expect_identical(jsgzdec(enc)$a, seq_len(5000))
})

test_that("jsunser says an object without a type is not jsser's", {
  msg <- "not JSON written by jsser"
  expect_error(jsunser("{\"a\":1}"), msg)
  expect_error(jsunser("{\"type\":null}"), msg)
  expect_error(jsunser("{\"type\":[\"a\",\"b\"]}"), msg)
  expect_error(jsunser("{\"type\":\"list\",\"value\":[1]}"), msg)
  expect_identical(jsunser(jsser(list(a = 1, b = NULL))), list(a = 1, b = NULL))
})

test_that("bldl does not wait past tmout between attempts", {
  slept <- numeric()
  n <- 0L
  local_mocked_bindings(
    .bl_sleep = function(s) slept <<- c(slept, s),
    .bl_http_download = function(...) {
      n <<- n + 1L
      list(status = 503L, retry_after = "99999", bytes = 0, error = "")
    }
  )
  a <- list(tmout = 30, hdr_lines = character(), maxbytes = 1e6)
  expect_error(
    .bl_dl_net("https://example.org/x", tempfile(), a, NULL, TRUE, "x"),
    "answered HTTP 503"
  )
  expect_identical(n, 1L)
  expect_length(slept, 0L)
  # a wait that fits is still taken
  a$tmout <- 3600
  expect_error(
    .bl_dl_net("https://example.org/x", tempfile(), a, NULL, TRUE, "x"),
    "answered HTTP 503"
  )
  expect_identical(slept, c(60, 60, 60))
})

test_that("migrate leaves calls of a name the script defines", {
  src <- c(
    "rate <- function(x) x",
    "rate(2)",
    "y <- rate(3)",
    "rmoriebricklayer::rate(d)",
    "share(d)"
  )
  r <- .bl_migrate_text(src)
  expect_identical(r$lines[1:3], src[1:3])
  expect_identical(r$lines[4], "rmoriebricklayer::rtcalc(d)")
  expect_identical(r$lines[5], "shrs(d)")
})

test_that("svydes takes a replicate column with no positive entry", {
  d <- data.frame(y = 1:4, w = 1, r1 = 0, r2 = c(2, 2, 0, 0))
  expect_no_error(
    suppressWarnings(svydes(d, w = "w", reps = c("r1", "r2"), type = "jk1"))
  )
})
