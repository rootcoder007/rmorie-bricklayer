# The last lines of the coverage pass of 1.0.0: guards that only a direct call reaches, and the
# refusals whose order changed so that they can be reached at all.

test_that(".rmbl_utf8() leaves what is not text alone", {
  expect_identical(rmoriebricklayer:::.rmbl_utf8(1:3), 1:3)
  expect_identical(rmoriebricklayer:::.rmbl_utf8(NULL), NULL)
})

test_that(".bl_check_email() names what is not an address", {
  expect_error(rmoriebricklayer:::.bl_check_email("not an address"), "'not an address' is not an email address")
  expect_error(rmoriebricklayer:::.bl_check_email(""), "an email address is required")
  expect_identical(rmoriebricklayer:::.bl_check_email("  A@b.ca "), "a@b.ca")
})

test_that("sprd() says that an empty x has no values before it looks at the weights", {
  expect_error(sprd(numeric(0)), "`x` has no values")
})

test_that("mcartst() refuses an infinite value in its own words", {
  x <- data.frame(a = c(1, 2, Inf, 4, 5, 6), b = c(2, NA, 3, 5, 4, 7))
  expect_error(mcartst(x), "infinite values")
})

test_that("blpal() refuses a count that is not one positive whole number", {
  expect_error(blpal("okabe", 0), "`n` must be a single positive whole number")
  expect_error(blpal("okabe", c(2, 3)), "`n` must be a single positive whole number")
  expect_length(blpal("okabe", 3), 3L)
})

test_that("perdays() refuses two dates in one argument", {
  expect_error(perdays(as.Date(c("2024-01-01", "2024-01-02")), as.Date("2024-01-03")),
               "must each be a single date")
})

test_that("fromjs() reads a sixteen-digit integer as a double", {
  v <- fromjs("1234567890123456")
  expect_type(v, "double")
  expect_identical(v, 1234567890123456)
})

test_that("bldl() takes the size the server announces for its progress line", {
  # reaches the progress callback's size-from-the-server line. The transport refuses loopback and
  # private addresses on its own, so no local server can stand in: live, where the coverage
  # workflow runs (RMBL_LIVE_TESTS=1), against a small public file
  skip_if_not(identical(Sys.getenv("RMBL_LIVE_TESTS"), "1"), "set RMBL_LIVE_TESTS=1 for the live fetch checks")
  ok <- !inherits(try(suppressWarnings(readLines("https://cloud.r-project.org/", n = 1L, warn = FALSE)),
                      silent = TRUE), "try-error")
  skip_if_not(ok, "no internet")
  dest <- withr::local_tempfile()
  msgs <- capture.output(bldl("https://cloud.r-project.org/CRAN_mirrors.csv", dest, quiet = FALSE, tty = FALSE),
                         type = "message")
  expect_gt(file.size(dest), 1000)
  expect_true(any(grepl("downloading", msgs)))
})

test_that(".bl_rate_sample() smooths the transfer rate once half a second has passed", {
  a <- list(done = 50, rd = 0, rt = 0, rn = 0L, rate = NA_real_)
  b <- rmoriebricklayer:::.bl_rate_sample(a, 2)
  expect_equal(b$rate, 25)
  expect_identical(b$rn, 1L)
  expect_identical(c(b$rt, b$rd), c(2, 50))
  # too soon: nothing changes
  expect_identical(rmoriebricklayer:::.bl_rate_sample(b, 2.1), b)
  b$done <- 150
  d <- rmoriebricklayer:::.bl_rate_sample(b, 3)
  expect_equal(d$rate, 25 + 0.3 * (100 - 25))
})

test_that(".bl_login_email() refuses what is not an address before anything is sent", {
  local_mocked_bindings(.bl_hosted_auth = function() list(url = "https://auth.invalid"),
                        .package = "rmoriebricklayer")
  expect_error(rmoriebricklayer:::.bl_login_email("nope"), "'nope' is not an email address")
  expect_error(rmoriebricklayer:::.bl_login_email(" "), "an email address is required")
})
