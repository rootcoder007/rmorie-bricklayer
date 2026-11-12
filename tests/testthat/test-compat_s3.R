# SPDX-License-Identifier: AGPL-3.0-or-later

test_that("1.1.1 no longer exports rate(), rate_change() or share()", {
  ex <- getNamespaceExports("rmoriebricklayer")
  expect_false(any(c("rate", "rate_change", "share") %in% ex))
  expect_true(all(c("rtcalc", "ratechg", "shrs", "yoy_summary") %in% ex))
})

test_that("the command line translates rate(), rate_change() and share()", {
  f <- withr::local_tempfile(fileext = ".R")
  writeLines(c(
    'r <- rate(d, count = "n", population = "p", conf_level = 0.9)',
    's <- share(d, count = "n")',
    'g <- rate_change(d, count = "n", population = "p", period = "y")',
    'a <- anltab(d, "n", "y")',
    "plotecdf(x)",
    'plotsm(y, "p")'
  ), f)
  got <- new.env()
  got$o <- character()
  keep <- function(...) got$o <- c(got$o, paste0(...))
  blcli(c("migrate", f), out = keep)
  o <- paste(got$o, collapse = "")
  expect_match(o, 'rtcalc(d, count = "n", pop = "p", conflvl = 0.9)',
               fixed = TRUE)
  expect_match(o, 'shrs(d, count = "n")', fixed = TRUE)
  expect_match(o, 'ratechg(d, count = "n", pop = "p", prd = "y")',
               fixed = TRUE)
  expect_match(o, 'anytab(d, "n", "y")', fixed = TRUE)
  expect_match(o, "plotcdfs(x)", fixed = TRUE)
  expect_match(o, 'plotmult(y, "p")', fixed = TRUE)
  got$o <- character()
  blcli(c("describe", "rate_change"), out = keep)
  expect_match(
    paste(got$o, collapse = ""),
    "0.5.x name of ratechg()",
    fixed = TRUE
  )
})

test_that("the old generics refuse what their methods do not take", {
  expect_error(yoy_summary(1), "yoy")
})

test_that("an old-named result prints, formats and summarises", {
  y <- yoychg(
    data.frame(year = 2019:2022, n = c(10, 12, 9, 15)),
    value = "n",
    prd = "year"
  )
  s <- yoy_summary(y)
  expect_identical(.rmbl_new_names(s), yoysmry(y))
  expect_output(print(s))
  expect_type(format(s), "character")
})
