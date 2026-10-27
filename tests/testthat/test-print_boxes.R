# SPDX-License-Identifier: AGPL-3.0-or-later
# The boxed print() methods: each draws its format() lines and returns its
# argument invisibly.

test_that("every boxed print method is the one registered for its class", {
  ns <- asNamespace("rmoriebricklayer")
  # match the two statements, not the whole deparsed body: covr rewrites
  # every body to count hits, so an exact comparison finds nothing there
  nm <- grep("^print[.]", ls(ns, all.names = TRUE), value = TRUE)
  is_box <- vapply(nm, function(n) {
    b <- deparse1(body(get(n, envir = ns)), collapse = " ")
    grepl(".rmbl_cat(format(x, ...), x)", b, fixed = TRUE) &&
      grepl("invisible(x)", b, fixed = TRUE)
  }, NA)
  expect_gt(sum(is_box), 100L)
  # each one is the registered S3 method for its class
  for (n in nm[is_box]) {
    cls <- sub("^print[.]", "", n)
    expect_identical(
      utils::getS3method("print", cls, envir = ns),
      get(n, envir = ns),
      info = n
    )
  }
})

test_that("a boxed result prints its format() lines, invisibly", {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  r <- rtcalc(5, 1000)
  expect_s3_class(r, "rmbl_rate")
  out <- utils::capture.output({
    v <- withVisible(print(r))
  })
  expect_false(v$visible)
  expect_identical(v$value, r)
  expect_identical(out, utils::capture.output(.rmbl_cat(format(r), r)))
})

# The helpers behind the results that gained a class to print as a box.

test_that(".rmbl_cls() puts a class first and keeps the values", {
  x <- list(a = 1, b = "two")
  y <- .rmbl_cls(x, "rmbl_try")
  expect_s3_class(y, c("rmbl_try", "list"), exact = TRUE)
  expect_identical(unclass(y), x)
  d <- .rmbl_cls(data.frame(v = 1:3), "rmbl_try")
  expect_s3_class(d, c("rmbl_try", "data.frame"), exact = TRUE)
  expect_identical(nrow(d), 3L)
  expect_identical(d$v, 1:3)
})

test_that(".rmbl_p_fact() shows a p-value as one fact", {
  expect_identical(.rmbl_p_fact(0.01734), "0.017")
  expect_identical(.rmbl_p_fact(1e-6), "< 0.001")
  expect_identical(.rmbl_p_fact(NA_real_), "not available")
  expect_identical(.rmbl_p_fact(NULL), "not available")
})

# print() of the results that gained a class in the restore round: each
# draws its box and returns the result invisibly (expect_box2() checks both).

test_that("the new classes print as boxes and return themselves", {
  expect_box2(ginicoef(c(1, 2, 3, 10)), "Gini coefficient")
  expect_box2(attrfrac(1.5, 0.4), "Population attributable fraction")
  expect_box2(drftks(1:20, 3:22), "Kolmogorov-Smirnov")
  expect_box2(drftpsi(1:50, 5:54), "Population stability index")
  expect_box2(
    drftchisq(c(a = 10, b = 12), c(a = 1, b = 1)),
    "Chi-square test against"
  )
  expect_box2(
    drfthomog(c(a = 10, b = 12), c(a = 12, b = 10)),
    "Chi-square test of homogeneity"
  )
  expect_box2(mkmnf(list(project = "p"), env = FALSE), "Run manifest")
  expect_box2(capenv("stats"), "Computing environment")
  expect_box2(
    citecps(list(dataset = list(publisher = "P"))),
    "Data citation"
  )
  expect_box2(
    structure(list(name = "n"), class = c("rmbl_provenance", "list")),
    "Provenance record"
  )
})
