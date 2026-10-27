# SPDX-License-Identifier: AGPL-3.0-or-later
# Plot branches no other test reached: a title or colours given by the caller,
# a panel with nothing to draw.

local_null_device <- function(env = parent.frame()) {
  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off(), envir = env)
}

test_that("plot.bricklayer_cortable passes the caller's title on", {
  local_null_device()
  ct <- cortbl(data.frame(
    a = 1:10,
    b = c(2, 1, 4, 3, 6, 5, 8, 7, 10, 9),
    c = (1:10)^2
  ))
  got <- new.env()
  local_mocked_bindings(.bl_corr_bars = function(label, r, main, ...) {
    got$main <- main
  })
  plot(ct, main = "My title")
  expect_identical(got$main, "My title")
})

test_that("plot.rmbl_bounds passes the caller's title on", {
  local_null_device()
  b <- pubbnd(c(120, 35, 0), rnd = 5)
  got <- new.env()
  local_mocked_bindings(.bl_dot_interval = function(l, v, lo, up, main, ...) {
    got$main <- main
  })
  plot(b, main = "Bounds")
  expect_identical(got$main, "Bounds")
})

test_that("an analysis with no rates draws the caller's empty title", {
  local_null_device()
  a <- anltab(data.frame(year = 2019:2022, n = c(10, 12, 9, 15)), "n", "year")
  r <- withVisible(plot(a, which = "rates", main = "none here"))
  expect_false(r$visible)
  expect_identical(r$value, list())
})

test_that("plothex() and plotcal() take colours instead of a palette", {
  local_null_device()
  # the palette is never asked for when colours are given
  local_mocked_bindings(blpal = function(...) stop("the palette was used"))
  set.seed(1)
  h <- plothex(rnorm(50), rnorm(50), col = "red")
  expect_identical(sum(h$count), 50L)
  cal <- plotcal(as.Date("2024-01-01") + 0:40, 1:41, col = "#336699")
  expect_identical(nrow(cal), 41L)
  expect_identical(cal$y, as.numeric(1:41))
})

test_that("the year-on-year title given is kept", {
  nf <- data.frame(flag = "x", stringsAsFactors = FALSE)
  expect_identical(.bl_yoy_nopct_main(nf, "Given"), "Given")
})

test_that("plot.rmbl_loo puts the summary right when the bars sit left", {
  local_null_device()
  l <- structure(
    data.frame(dropped = letters[1:11], estimate = c(rep(1, 10), 5), se = 1),
    full = 2,
    class = c("rmbl_loo", "data.frame")
  )
  r <- withVisible(plot(l))
  expect_false(r$visible)
  expect_identical(r$value$estimate, c(rep(1, 10), 5))
})

test_that("cohort trends not normalised are drawn as mean outcomes", {
  local_null_device()
  ct <- cohtrnd(
    polex(),
    "district",
    "month",
    "crmrate",
    "refmonth",
    norm = FALSE
  )
  expect_false(attr(ct, "normalised"))
  r <- plot(ct)
  expect_identical(sort(unique(r$cohort)), c(13, 19, 25))
})

test_that("the search maps take colours instead of a palette", {
  local_null_device()
  m <- datumpmap(seq(-3, 3), seq(-3, 3))
  al <- opteffort(m, W = 1, effort = 30)
  local_mocked_bindings(blpal = function(...) stop("the palette was used"))
  r <- plot(m, col = c("white", "black"))
  expect_equal(
    sum(r$poc), sum(m$poc),
    tolerance = testthat::testthat_tolerance()
  )
  r2 <- plot(al, col = c("white", "black"))
  expect_equal(sum(r2$effort), 30, tolerance = testthat::testthat_tolerance())
})

test_that("plot.rmbl_ordinal_compare takes colours instead of a palette", {
  local_null_device()
  mh <- indiex("mentalhealth")
  mh <- mh[mh$region == "Canada", ]
  oc <- ordcmp(
    mh,
    "group",
    "rating",
    "estimate",
    "lower",
    "upper",
    lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
    ref = "Métis",
    qual = "quality"
  )
  local_mocked_bindings(blpal = function(...) stop("the palette was used"))
  r <- plot(oc, col = c("red", "orange", "green", "blue"))
  expect_named(r, c("Fair or poor", "Good", "Very good", "Excellent"))
  expect_equal(unname(rowSums(r)), rep(1, nrow(r)), tolerance = 0.01)
})

test_that("a wellness profile with no finite value gets the 0-100 axis", {
  d <- data.frame(lower = NA_real_, upper = NA_real_, estimate = NA_real_)
  expect_identical(.imh_wp_range(d), c(0, 100))
})

test_that("the drift heatmap of no runs draws only its frame", {
  local_null_device()
  h0 <- data.frame(
    column = character(),
    run = integer(),
    psi = numeric(),
    stringsAsFactors = FALSE
  )
  r <- .bl_drift_heat_plot(h0, list(warn = 0.1, fail = 0.25))
  expect_identical(nrow(r), 0L)
  expect_true("band" %in% names(r))
})

test_that("a drift note writes a missing p-value as none", {
  expect_identical(
    .bl_drift_note(
      list(verdict = "ok", column = "v", psi = 0.01, p_value = NA),
      list(warn = 0.1, fail = 0.25),
      0.05
    ),
    "v looks the same in both: PSI 0.01, below the warn band 0.1, and p = none."
  )
})
