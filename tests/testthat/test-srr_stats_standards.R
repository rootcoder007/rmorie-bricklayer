# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("each package-level standard tag names a standard and says why", {
  f <- test_path("..", "..", "R", "srr_stats_standards.R")
  skip_if_not(file.exists(f), "the R sources are not beside the tests")
  x <- readLines(f, warn = FALSE)
  tags <- grep("^#' @srrstats(NA|TODO)? ", x, value = TRUE)
  expect_gt(length(tags), 10L)
  ids <- sub("^#' @srrstats(NA|TODO)? \\{([^}]+)\\}.*$", "\\2", tags)
  expect_true(all(grepl("^[A-Z]+[0-9]+(\\.[0-9]+[a-z]?)*$", ids)))
  expect_false(anyDuplicated(ids) > 0L)
  why <- sub("^#' @srrstats(NA|TODO)? \\{[^}]+\\} *", "", tags)
  expect_true(all(nzchar(why)))
  expect_identical(utils::tail(x, 1L), "NULL")
})
