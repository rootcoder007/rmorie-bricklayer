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

test_that("migrate skips $ and @ members, rewrites references (BL-M1)", {
  mig <- function(...) .bl_migrate_text(c(...))
  # a list element or method named like an old function is not that function
  r <- mig("obj$rate(1)", "s4@yoy(d)", "obj$share", "x$yoy <- 2")
  expect_identical(
    r$lines,
    c("obj$rate(1)", "s4@yoy(d)", "obj$share", "x$yoy <- 2")
  )
  expect_identical(r$n, 0L)
  # passed by name as a function value, bare or qualified with this package
  r <- mig(
    "x <- lapply(list(d), yoy, value = 'n')",
    "y <- Map(rmoriebricklayer::share, a, b)",
    "z <- vapply(l, foo::share, 1)"
  )
  expect_identical(
    r$lines,
    c(
      "x <- lapply(list(d), yoychg, value = 'n')",
      "y <- Map(rmoriebricklayer::shrs, a, b)",
      "z <- vapply(l, foo::share, 1)"
    )
  )
  expect_identical(r$n, 2L)
  # a string naming the function in do.call(), match.fun(), get()
  r <- mig(
    "do.call('anltab', list(d, 'n', 'y'))",
    "do.call(what = \"rate\", args = list(d))",
    "f <- match.fun(\"yoy\")",
    "g <- get('share', mode = 'function')",
    "do.call(list, list('anltab'))",
    "paste('anltab', 'yoy')"
  )
  expect_identical(
    r$lines,
    c(
      "do.call('anytab', list(d, 'n', 'y'))",
      "do.call(what = \"rtcalc\", args = list(d))",
      "f <- match.fun(\"yoychg\")",
      "g <- get('shrs', mode = 'function')",
      "do.call(list, list('anltab'))",
      "paste('anltab', 'yoy')"
    )
  )
  expect_identical(r$n, 4L)
  # strings, comments, argument names and the script's own variables stay
  src <- c(
    "msg <- 'call anltab() or yoy() here'  # anltab(d) in a comment",
    "f <- function(share = 0.5) share * 2",
    "f(share = 0.2)",
    "yoy <- 3",
    "print(yoy + 1)",
    "h <- sapply(1:3, yoy)",
    "for (rate in 1:2) print(rate)",
    "10 -> share; identity(share)",
    "nm <- 'anltab'"
  )
  r <- mig(src)
  expect_identical(r$lines, src)
  expect_identical(r$n, 0L)
  # calls qualified with this package are rewritten, another package's are not
  r <- mig("rmoriebricklayer::yoy(d, value = 'n')", "foo::share(1)")
  expect_identical(
    r$lines,
    c("rmoriebricklayer::yoychg(d, value = 'n')", "foo::share(1)")
  )
  # the old call with its arguments still works as before
  r <- mig("rate(d, count = 'n', population = 'p', conf_level = 0.9)")
  expect_identical(r$lines, "rtcalc(d, count = 'n', pop = 'p', conflvl = 0.9)")
  # a function body or an if is not an argument
  expect_identical(mig("g <- function() yoy", "if (TRUE) share")$n, 0L)
})
