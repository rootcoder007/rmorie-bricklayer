# SPDX-License-Identifier: AGPL-3.0-or-later
# Branches of the argument guards, the 0.5.x compatibility layer, the JSON
# writer/parser and .onLoad that no other test reached.

test_that("an error names the function when it was called as pkg::fn", {
  expect_error(
    rmoriebricklayer::plothex(1:3, 1:3, bins = 1),
    "^plothex: `bins` must be one whole number from 2 to 500$"
  )
})

test_that("a factor or a function is no number, said in words", {
  expect_error(
    .rmbl_scalar(factor("a"), "n"),
    "`n` must be a number, not a factor"
  )
  expect_error(
    .rmbl_scalar(function() 1, "n"),
    "`n` must be a number, not a function"
  )
})

test_that("the range in a scalar's error follows the bounds given", {
  expect_error(
    .rmbl_scalar(5, "n", max = 3),
    "`n` must be one number of at most 3$"
  )
  expect_error(.rmbl_scalar(c(1, 2), "n"), "`n` must be one number$")
})

test_that("orchk() without a reference group says ref is missing", {
  cnts <- matrix(1:4, 2, dimnames = list(c("a", "b"), NULL))
  expect_error(
    orchk(cnts, rptd = c(b = 1)),
    "argument \"ref\" is missing, with no default",
    fixed = TRUE
  )
})

test_that("the run verb reads an .rds file as its value", {
  f <- tempfile(fileext = ".rds")
  on.exit(unlink(f))
  saveRDS(list(a = 1, b = "x"), f)
  expect_identical(.bl_run_value(f), list(a = 1, b = "x"))
})

test_that("an old argument passed through the dots gets its new name", {
  r <- .bl_old_row("drift_calibrate")
  expect_identical(.bl_old_arg_name(r, "reference"), "ref")
  expect_identical(.bl_old_arg_name(r, "nothing_like_it"), "nothing_like_it")
  m <- .bl_migrate_text("drift_calibrate(d, reference = r)")
  expect_identical(m$lines, "drftcal(d, ref = r)")
})

test_that("migrate leaves a value that is not a renamed string literal", {
  m <- .bl_migrate_text(c(
    "analyse_table(d, direction = dd)",
    "analyse_table(d, direction = \"neutral\")",
    "analyse_table(d, direction = \"higher_is_better\")"
  ))
  expect_identical(
    m$lines,
    c(
      "anltab(d, dir = dd)",
      "anltab(d, dir = \"neutral\")",
      "anltab(d, dir = \"higher\")"
    )
  )
})

test_that("an old-named result's own summary method runs, visible", {
  d <- data.frame(id = 1:40, v = c(1:20, 1:20))
  dr <- cpsdrft(d, d)
  expect_s3_class(dr, "bricklayer_drift")
  old <- dr
  class(old) <- c("rmbl_old", class(dr))
  attr(old, "rmbl_names") <- c(anydrft = "any_drift")
  r <- withVisible(.rmbl_old_call("summary", old))
  expect_true(r$visible)
  expect_identical(r$value$any_drift, dr$anydrft)
  expect_null(r$value$anydrft)
})

test_that("a drift summary with no columns lists no drifted column", {
  d <- data.frame(id = 1:40, v = c(1:20, 1:20))
  dr <- cpsdrft(d, d)
  dr$columns <- dr$columns[0, , drop = FALSE]
  s <- summary(dr)
  expect_identical(s$drifted, character(0))
  expect_identical(s$ntes, 0L)
})

test_that("JSON: an hms time is written as text, not seconds", {
  h <- structure(c(3661, NA), class = c("hms", "difftime"), units = "secs")
  expect_identical(as.character(tojs(h)), "[\"3661\",null]")
  expect_identical(as.character(tojs(h, hms = "secs")), "[3661,\"NA\"]")
})

test_that("JSON: the special-class writer refuses a plain number", {
  expect_error(
    .rmbl_json_as_special(1, list(), ",", NULL, NULL, FALSE, NULL, FALSE),
    "not a special class"
  )
})

test_that("JSON: ISO 8601 times without UTC carry no zone letter", {
  t <- as.POSIXct("2024-01-02 03:04:05", tz = "UTC")
  expect_identical(
    as.character(tojs(t, POSIXt = "ISO8601")),
    "[\"2024-01-02T03:04:05\"]"
  )
})

test_that("JSON: use_signif given explicitly is honoured", {
  expect_true(.rmbl_json_use_signif(TRUE, 4))
  expect_false(.rmbl_json_use_signif(FALSE, I(4)))
  expect_identical(
    as.character(tojs(pi, use_signif = TRUE, digits = 3)),
    "[3.14]"
  )
})

test_that("JSON: the R parser reads every short escape", {
  # the R parser, as a staged bundle without the native code runs it
  old <- .rmbl_native$json
  .rmbl_native$json <- FALSE
  withr::defer({
    .rmbl_native$json <- old
  })
  expect_warning(
    {
      x <- fromjs("{\"a\":\"x\\ty\\rz\\b\\f\\/\",\"b\":9007199254740993}")
    },
    "integer 9007199254740993 exceeds 2^53",
    fixed = TRUE
  )
  expect_identical(utf8ToInt(x$a), c(120L, 9L, 121L, 13L, 122L, 8L, 12L, 47L))
  expect_identical(x$b, 9007199254740992)
  # an exact one past 2^53 is read without a word
  expect_no_warning({
    y <- fromjs("[9007199254740994]")
  })
  expect_identical(y, 9007199254740994)
})

test_that("JSON: a string with no byte-order mark is kept as it is", {
  expect_identical(.rmbl_strip_bom("abc"), "abc")
})

test_that("JSON: an external pointer serialises with no value", {
  j <- jsser(new("externalptr"))
  expect_identical(
    as.character(j),
    "{\"type\":\"externalptr\",\"attributes\":{},\"value\":{}}"
  )
})

test_that(".onLoad sets rmbl.examples only when unset", {
  withr::local_options(rmbl.examples = NULL)
  withr::local_envvar(NOT_CRAN = "true")
  .rmbl_examples_default("lib", "rmoriebricklayer")
  expect_true(getOption("rmbl.examples"))
  withr::local_options(rmbl.examples = FALSE)
  .rmbl_examples_default("lib", "rmoriebricklayer")
  expect_false(getOption("rmbl.examples"))
  withr::local_options(rmbl.examples = NULL)
  withr::local_envvar(NOT_CRAN = "", MY_UNIVERSE = "", IN_PKGDOWN = "")
  .rmbl_examples_default("lib", "rmoriebricklayer")
  expect_identical(getOption("rmbl.examples"), interactive())
})
