# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The 0.5.x names in the command line: the map rows, the notes, the run verb's
# arguments and the migrate rewrite, called directly.

test_that("a 0.5.x name has a map row; a 1.0.0 name has none", {
  r <- .bl_old_row("crf_pm25")
  expect_identical(r$new, "crfpm25")
  expect_identical(r$args[["exposure"]], "expo")
  expect_identical(r$values$outcome[["all_cause_mortality"]], "allcause")
  expect_null(.bl_old_row("crfpm25"))
  expect_match(
    .bl_old_note(r),
    "crf_pm25() is the 0.5.x name of crfpm25()",
    fixed = TRUE
  )
  expect_identical(.bl_old_arg_name(r, "exposure"), "expo")
  expect_identical(.bl_old_arg_name(r, "not_an_arg"), "not_an_arg")
})

test_that("migrate renames the call, its arguments and its allowed values", {
  r <- .bl_migrate_text(c(
    "y <- crf_pm25(exposure = 10, outcome = 'all_cause_mortality')",
    "z <- other::crf_pm25(1)"
  ))
  expect_identical(
    r$lines,
    c(
      "y <- crfpm25(expo = 10, y = 'allcause')",
      "z <- other::crf_pm25(1)"
    )
  )
  expect_identical(r$n, 4L)
  expect_identical(.bl_migrate_text("x <- 1")$n, 0L)
  expect_identical(.bl_migrate_apply("abc", list()), "abc")
  expect_error(.bl_migrate_text("x <- ("))
})

test_that("the run verb's words become named and positional arguments", {
  r <- .bl_old_row("crf_pm25")
  a <- .bl_run_args(
    c("--exposure", "10", "--outcome", "all_cause_mortality"),
    r
  )
  expect_identical(a, list(expo = 10L, y = "allcause"))
  expect_identical(
    .bl_run_args(c("1,2,3", "--flag"), NULL),
    list(1:3, flag = TRUE)
  )
  expect_null(.bl_run_value("NULL"))
  expect_identical(.bl_run_value("TRUE,NA"), c(TRUE, NA))
})
