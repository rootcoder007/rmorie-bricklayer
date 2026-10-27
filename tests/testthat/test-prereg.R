# SPDX-License-Identifier: AGPL-3.0-or-later
# Pre-registration, families of falsification tests and E-values.

test_that("prrgchk() finds outcome switching", {
  plan <- prrgdecl(c(ate = "higher in the exposed", nrows = "the row count"))
  expect_s3_class(plan, "bricklayer_prereg")
  expect_true(prrgchk(plan, c("ate", "nrows"))$ok)
  ch <- prrgchk(plan, c("ate", "extra"))
  expect_false(ch$ok)
  expect_identical(ch$decnotrep, "nrows")
  expect_identical(ch$repnotdec, "extra")
  expect_match(paste(format(ch), collapse = "\n"), "nrows", fixed = TRUE)
  expect_error(prrgdecl("unnamed"), "named character vector")
  expect_error(
    prrgdecl(stats::setNames(c("x", "y"), c("a", "a"))),
    "duplicate names"
  )
  expect_error(prrgchk(list(), "a"), "must come from prrgdecl")
})

test_that("falsfam() corrects a family of p-values", {
  p <- c(a = 0.01, b = 0.04, c = 0.2, d = 0.5)
  h <- falsfam(p)
  expect_s3_class(h, "bricklayer_falsify_family")
  expect_identical(h$results$name, c("a", "b", "c", "d"))
  expect_equal(h$results$adjusted, c(0.04, 0.12, 0.4, 0.5), tolerance = 1e-12)
  expect_identical(h$results$survives, c(TRUE, FALSE, FALSE, FALSE))
  bh <- falsfam(p, meth = "bh")
  expect_equal(
    bh$results$adjusted,
    c(0.04, 0.08, 4 / 15, 0.5),
    tolerance = 1e-12
  )
  expect_equal(
    falsfam(p, meth = "bonferroni")$results$adjusted,
    c(0.04, 0.16, 0.8, 1),
    tolerance = 1e-12
  )
  expect_identical(falsfam(unname(p))$results$name[[1L]], "p1")
  expect_error(falsfam(numeric()), "at least one")
  expect_error(falsfam(c(a = 0.01, b = 1.2)), "must lie in")
  expect_error(falsfam(c(a = NA_real_)), "needs a p-value")
  expect_error(falsfam("x"), "numeric vector of p-values")
})

test_that("evlrr() gives the E-value of a ratio and its limit", {
  expect_equal(evlrr(2)[["evlpoint"]], 2 + sqrt(2), tolerance = 1e-12)
  expect_identical(evlrr(0.5), evlrr(2))
  e <- evlrr(3, lo = 2.1, hi = 4.3)
  expect_named(e, c("evlpoint", "evllimit"))
  expect_equal(e[["evllimit"]], 2.1 + sqrt(2.1 * 1.1), tolerance = 1e-12)
  expect_identical(evlrr(2, lo = 0.9, hi = 4.4)[["evllimit"]], 1)
  expect_equal(
    evlrr(0.5, lo = 0.3, hi = 0.8)[["evllimit"]],
    1.25 + sqrt(1.25 * 0.25),
    tolerance = 1e-12
  )
  expect_error(evlrr(-1), "finite and positive")
  expect_true(is.na(.rmbl_evl_limit(NA_real_, NA_real_)))
})

test_that("evlrr names each ratio and takes one value", {
  expect_error(evlrr(c(2, 3)), "evlrr: `rr` must be one risk ratio")
  expect_error(evlrr(2, true = c(1, 2)), "`true` must be one risk ratio")
  expect_error(evlrr(2, lo = -1), "`lo` must be one risk ratio")
  expect_error(evlrr(2, lo = 1.1, hi = Inf), "`hi` must be one risk ratio")
  expect_error(prrgchk(NULL, function() 1), "prrgchk: `rptd` must be data")
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("declarations, their checks and families print as boxes", {
  plan <- prrgdecl(c(ate = "higher in the exposed", nrows = "the row count"))
  o1_expect_box(o1_box(plan), plan, "Pre-registration", c("ate", "Declared"))
  ch <- prrgchk(plan, c("ate", "extra"))
  b <- o1_box(ch)
  o1_expect_box(b, ch, "Against the declaration of", "NOT VERIFIED")
  expect_true(any(grepl("outcome switching", b$out, fixed = TRUE)))
  fam <- falsfam(c(a = 0.01, b = 0.5), meth = "holm")
  o1_expect_box(o1_box(fam), fam, "Family of 2", c("survives", "holm"))
})

test_that("a report as declared says so", {
  plan <- prrgdecl(c(ate = "higher in the exposed", nrows = "the row count"))
  ok <- prrgchk(plan, c("ate", "nrows"))
  expect_match(box_text(ok),
    "The report gives exactly the statistics declared, and no others.",
    fixed = TRUE)
})
