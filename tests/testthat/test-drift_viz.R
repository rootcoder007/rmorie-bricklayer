# SPDX-License-Identifier: AGPL-3.0-or-later
# The drift report's pieces: bands, verdicts, tables, the heatmap's bands, the
# capsule chain and the one-file HTML page.

viz_drift <- function() {
  withr::with_seed(5, {
    ref <- data.frame(
      value = stats::rnorm(300),
      grade = sample(c("a", "b", "c"), 300, TRUE),
      stringsAsFactors = FALSE
    )
    cur <- data.frame(
      value = stats::rnorm(300, 0.8),
      grade = sample(c("a", "b", "c"), 300, TRUE),
      stringsAsFactors = FALSE
    )
  })
  cpsdrft(ref, cur)
}

test_that("the bands default to the object's and refuse warn above fail", {
  d <- viz_drift()
  b <- .bl_drift_bands(d)
  expect_named(b, c("warn", "fail"))
  expect_lte(b$warn, b$fail)
  expect_identical(.bl_drift_bands(d, 0.05, 0.2), list(warn = 0.05, fail = 0.2))
  expect_error(.bl_drift_bands(d, 0.5, 0.2), "must not be above")
})

test_that("the column table puts the worst verdicts first", {
  d <- viz_drift()
  t <- .bl_drift_table(d, 0.1, 0.25)
  expect_s3_class(t, "data.frame")
  expect_setequal(t$column, c("value", "grade"))
  expect_identical(t$verdict[1L], "fail")
  expect_true(all(t$verdict %in% c("ok", "warn", "fail", "untested")))
  expect_match(.bl_drift_md(d, list(warn = 0.1, fail = 0.25)), "## Drift")
})

test_that("the history heatmap puts each PSI in its band", {
  h <- data.frame(psi = c(NA, 0.05, 0.15, 0.4))
  hb <- .bl_drift_heat(h, list(warn = 0.1, fail = 0.25))
  expect_identical(hb$band, c("none", "ok", "warn", "fail"))
  expect_identical(
    .bl_drift_test(c("numeric", "categorical", "identifier")),
    c("KS", "chi-square homogeneity", "none")
  )
})

test_that("the capsule chain without checks comes from the object", {
  d <- viz_drift()
  ch <- .bl_drift_chain(d)
  expect_identical(
    ch$link,
    c("provenance", "bytes", "manifest", "attestation")
  )
  expect_identical(ch$status, c("none", "none", "none", "none"))
})

test_that("drfthtml() writes one page and refuses what is not a drift", {
  d <- viz_drift()
  f <- withr::local_tempfile(fileext = ".html")
  expect_identical(drfthtml(d, f, title = "A <b> test"), f)
  page <- paste(readLines(f, warn = FALSE), collapse = "\n")
  expect_match(page, "<!DOCTYPE html>", fixed = TRUE)
  expect_match(page, "drift-data", fixed = TRUE)
  expect_false(grepl("A <b> test", page, fixed = TRUE))
  expect_error(drfthtml(list(), f), "bricklayer_drift object")
  expect_error(drfthtml(d, f, warn = 0.5, fail = 0.2), "must not be above")
})

test_that("the drift history plots leave par() as it was (B1, B2)", {
  h <- data.frame(
    column = rep(c("a", "b"), each = 3),
    run = rep(1:3, 2),
    psi = c(0.05, 0.12, 0.3, 0.01, 0.02, 0.2),
    stringsAsFactors = FALSE
  )
  b <- list(warn = 0.1, fail = 0.25)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  keys <- c("col", "fg", "mar", "cex", "mfrow", "las")
  p0 <- graphics::par(keys)
  .bl_drift_heat_plot(h, b)
  expect_identical(graphics::par(keys), p0)
  .bl_drift_history_plot(h, b)
  expect_identical(graphics::par(keys), p0)
})
