# Distributional drift tests.
#
# Anchors outside the package: stats::ks.test for the KS statistic,
# stats::chisq.test for the chi-square statistic, the closed forms of the
# population stability index and the Jensen-Shannon divergence written
# out by hand, and Benford's law itself, P(d) = log10(1 + 1/d).

test_that("the KS statistic matches stats::ks.test", {
  set.seed(11)
  for (i in 1:6) {
    a <- stats::rnorm(70)
    b <- stats::rnorm(50, mean = i / 4)
    got <- drftks(a, b)
    want <- suppressWarnings(stats::ks.test(a, b))
    expect_equal(
      got[["statistic"]],
      as.numeric(want$statistic),
      tolerance = testthat::testthat_tolerance()
    )
  }
  expect_named(drftks(1:10, 2:11), c("statistic", "p_value", "neff"))
  # the effective size is the harmonic-style combination
  k <- drftks(stats::rnorm(70), stats::rnorm(50))
  expect_identical(k[["neff"]], 70 * 50 / (70 + 50))

  # a sample against itself has nowhere to differ
  x <- stats::rnorm(100)
  expect_identical(drftks(x, x)[["statistic"]], 0)
  expect_identical(drftks(x, x)[["p_value"]], 1)
  # completely separated samples are the maximum statistic
  expect_identical(drftks(1:10, 101:110)[["statistic"]], 1)
  expect_lt(drftks(1:50, 101:150)[["p_value"]], 1e-6)
  # a real shift is detected and a null one is not
  expect_lt(drftks(stats::rnorm(300), stats::rnorm(300, 1))[["p_value"]], 0.01)
  expect_gt(drftks(stats::rnorm(300), stats::rnorm(300))[["p_value"]], 0.01)
  # a change in spread alone is caught, which comparing means would miss
  expect_lt(
    drftks(stats::rnorm(400), stats::rnorm(400, 0, 3))[["p_value"]],
    0.01
  )
  # p-values are probabilities, and the statistic is a proportion
  expect_gte(k[["p_value"]], 0)
  expect_lte(k[["p_value"]], 1)
  expect_gte(k[["statistic"]], 0)
  expect_lte(k[["statistic"]], 1)
  # ties are handled by comparing the EDFs, without a warning
  expect_silent(drftks(c(1, 1, 2, 2, 3), c(1, 2, 2, 3, 3)))
  # NA is dropped rather than poisoning the statistic
  expect_identical(
    drftks(c(x, NA), x)[["statistic"]],
    drftks(x, x)[["statistic"]]
  )

  expect_error(drftks(numeric(0), 1:5), "at least one non-missing")
  expect_error(drftks(c(NA, NA), 1:5), "at least one non-missing")
})

test_that("PSI and Jensen-Shannon divergence are their closed forms", {
  set.seed(12)
  ref <- stats::rnorm(800)

  # identical inputs have moved nowhere
  same <- drftpsi(ref, ref)
  expect_named(same, c("psi", "jsdiv"))
  expect_equal(same[["psi"]], 0, tolerance = 1e-9)
  expect_equal(same[["jsdiv"]], 0, tolerance = 1e-9)

  # a shift registers on both, and a bigger shift registers more
  mild <- drftpsi(ref, stats::rnorm(800, 0.3))
  hard <- drftpsi(ref, stats::rnorm(800, 1.5))
  expect_gt(hard[["psi"]], mild[["psi"]])
  expect_gt(hard[["jsdiv"]], mild[["jsdiv"]])
  expect_gt(hard[["psi"]], 0.25)
  # both are non-negative
  expect_true(all(c(mild, hard) >= 0))
  # the Jensen-Shannon divergence is bounded by log 2 in nats, however
  # far apart the two samples are -- that bound is what makes it
  # comparable between columns with different bin counts
  expect_lte(drftpsi(rep(1, 50), rep(99, 50))[["jsdiv"]], log(2))
  expect_lte(hard[["jsdiv"]], log(2))
  # more bins resolves a shift more finely
  expect_true(is.finite(drftpsi(ref, stats::rnorm(800, 1), bins = 25)[["psi"]]))
  # a constant reference column still returns a finite answer instead of
  # dividing by a zero-width bin
  expect_true(is.finite(drftpsi(rep(3, 40), rep(3, 40))[["psi"]]))
  expect_true(is.finite(drftpsi(rep(3, 40), rep(9, 40))[["psi"]]))

  expect_error(drftpsi(ref, numeric(0)), "at least one non-missing")
  expect_error(drftpsi(ref, ref, bins = 1), "at least 2")
})

test_that("the chi-square drift statistic matches stats::chisq.test", {
  ref <- c(a = 50, b = 30, c = 20)
  obs <- c(a = 40, b = 60, c = 100)
  got <- drftchisq(obs, ref)
  want <- stats::chisq.test(obs, p = ref / sum(ref))
  expect_identical(got[["statistic"]], as.numeric(want$statistic))
  expect_identical(got[["df"]], as.numeric(want$parameter))
  expect_identical(got[["p_value"]], want$p.value)
  expect_named(got, c("statistic", "df", "p_value", "logpvalue"))
  expect_identical(exp(got[["logpvalue"]]), got[["p_value"]])

  # counts in the reference proportions have nothing to explain
  expect_identical(drftchisq(c(a = 100, b = 60, c = 40), ref)[["statistic"]], 0)
  expect_identical(drftchisq(c(a = 100, b = 60, c = 40), ref)[["p_value"]], 1)
  # the reference may be given as proportions or as counts alike
  expect_identical(
    drftchisq(obs, ref)[["statistic"]],
    drftchisq(obs, ref / sum(ref))[["statistic"]]
  )
  # raw vectors are tabulated
  t1 <- drftchisq(c("a", "a", "b", "b"), c("a", "b"))
  expect_identical(t1[["statistic"]], 0)
  # a category the reference rules out, but which occurs, contradicts the
  # pinned distribution outright rather than being dropped from the sum
  newcat <- drftchisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
  expect_identical(newcat[["statistic"]], Inf)
  expect_identical(newcat[["p_value"]], 0)
  # whereas a category with a positive expectation contributes finitely
  fin <- drftchisq(c(a = 1, b = 99), c(a = 50, b = 50))
  expect_true(is.finite(fin[["statistic"]]))
  expect_gt(fin[["statistic"]], 0)
  # and so is a vanished one
  gone <- drftchisq(c("a", "a", "a", "a"), c("a", "a", "b", "b"))
  expect_gt(gone[["statistic"]], 0)
  # a bigger reallocation gives a bigger statistic
  expect_gt(
    drftchisq(c(a = 10, b = 10, c = 180), ref)[["statistic"]],
    drftchisq(c(a = 60, b = 80, c = 60), ref)[["statistic"]]
  )
  # the p-value is the chi-square tail
  expect_identical(
    got[["p_value"]],
    stats::pchisq(got[["statistic"]], got[["df"]], lower.tail = FALSE)
  )

  expect_error(drftchisq(c(1, 2, 3), ref), "must be named")
  expect_error(drftchisq(c(a = 0, b = 0), c(a = 1, b = 1)), "no counts")
})

test_that("the Benford screen is the log10 law", {
  set.seed(13)
  # a quantity spanning several orders of magnitude follows the law
  ok <- benfordtst(10^stats::runif(4000, 0, 6))
  expect_s3_class(ok, "bricklayer_benford")
  expect_gt(ok$p_value, 0.01)
  # the expected proportions ARE the closed form
  expect_equal(ok$expected / ok$n, log10(1 + 1 / (1:9)), ignore_attr = TRUE)
  expect_equal(sum(ok$expected), ok$n, tolerance = 1e-12)
  expect_named(ok$counts, as.character(1:9))
  expect_identical(sum(ok$counts), ok$n)
  expect_identical(ok$df, 8L)
  expect_identical(ok$proportion, ok$counts / ok$n)
  # leading 1s are the most common digit under the law
  expect_equal(which.max(ok$counts), 1L, ignore_attr = TRUE)

  # a column whose leading digits are uniform does not follow it
  flat <- benfordtst(as.numeric(paste0(rep(1:9, each = 400), "000")))
  expect_lt(flat$p_value, 1e-6)
  # nor does one pinned to a single digit
  expect_lt(benfordtst(rep(5000, 500))$p_value, 1e-6)

  # the sign is irrelevant and zeros carry no leading digit
  expect_identical(benfordtst(c(-19, 19))$counts[["1"]], 2)
  expect_identical(benfordtst(c(0, 0, 1, 2, 3))$n, 3)
  expect_identical(benfordtst(c(0.00023, 2.3, 230))$counts[["2"]], 3)
  # non-finite values are excluded
  expect_identical(benfordtst(c(1, 2, NA, Inf, -Inf))$n, 2)
  # the p-value is the chi-square tail on 8 df
  expect_identical(
    ok$p_value,
    stats::pchisq(ok$statistic, 8, lower.tail = FALSE)
  )
  expect_identical(summary(ok)[["n"]], ok$n)

  expect_error(benfordtst(c(0, 0, 0)), "no finite non-zero")
  expect_error(benfordtst(numeric(0)), "no finite non-zero")
})

test_that("cpsdrft tests every shared column and flags the movers", {
  set.seed(14)
  n <- 400
  ref <- data.frame(
    value = stats::rnorm(n),
    size = stats::runif(n, 1, 10),
    grade = sample(c("a", "b", "c"), n, TRUE),
    stringsAsFactors = FALSE
  )
  same <- data.frame(
    value = stats::rnorm(n),
    size = stats::runif(n, 1, 10),
    grade = sample(c("a", "b", "c"), n, TRUE),
    stringsAsFactors = FALSE
  )

  d <- cpsdrft(ref, same)
  expect_s3_class(d, "bricklayer_drift")
  expect_false(d$anydrft)
  expect_identical(nrow(d$columns), 3L)
  expect_identical(sort(d$columns$column), c("grade", "size", "value"))
  expect_identical(d$columns$type[d$columns$column == "grade"], "categorical")
  expect_identical(d$columns$type[d$columns$column == "value"], "numeric")
  expect_equal(d$nref, n, tolerance = testthat::testthat_tolerance())
  expect_equal(d$ncur, n, tolerance = testthat::testthat_tolerance())
  expect_length(d$added, 0L)
  expect_length(d$removed, 0L)
  expect_false(any(d$columns$drifted))
  # every column reports a PSI: binned for a numeric one, over the union
  # of categories for a categorical one (which is what sees a disjoint
  # high-cardinality column the homogeneity test has no power against)
  expect_true(all(is.finite(d$columns$psi)))

  # a rescaled numeric column and a new category are both caught
  moved <- same
  moved$size <- moved$size * 3
  moved$grade[1:150] <- "z"
  m <- cpsdrft(ref, moved)
  expect_true(m$anydrft)
  expect_true(m$columns$drifted[m$columns$column == "size"])
  expect_true(m$columns$drifted[m$columns$column == "grade"])
  # the untouched column is not flagged
  expect_false(m$columns$drifted[m$columns$column == "value"])

  # structural changes are reported rather than tested
  fewer <- cpsdrft(ref, same[, c("value", "grade")])
  expect_identical(fewer$removed, "size")
  expect_identical(nrow(fewer$columns), 2L)
  expect_true(fewer$anydrft)
  extra <- same
  extra$brand_new <- 1
  expect_identical(cpsdrft(ref, extra)$added, "brand_new")
  expect_true(cpsdrft(ref, extra)$anydrft)
  # no shared columns at all is an empty table, not an error
  none <- cpsdrft(ref, data.frame(q = 1:3))
  expect_identical(nrow(none$columns), 0L)
  expect_true(none$anydrft)

  # a stricter alpha flags fewer columns
  mild <- same
  mild$value <- mild$value + 0.22
  expect_gte(
    sum(cpsdrft(ref, mild, alpha = 0.2)$columns$drifted),
    sum(cpsdrft(ref, mild, alpha = 1e-8)$columns$drifted)
  )
  # the PSI threshold can flag a column on its own, but only once both
  # samples are large enough for the band to mean anything
  expect_true(
    cpsdrft(ref, moved, alpha = 1e-12, psithr = 0.05, psiminn = 10L)$anydrft
  )
  # with the default minimum it is reported but does not raise the flag
  noise <- cpsdrft(
    data.frame(v = stats::rnorm(80)),
    data.frame(v = stats::rnorm(80))
  )
  expect_true(is.finite(noise$columns$psi))
  expect_false(noise$anydrft)
  # a binning-noise PSI on a small sample would clear 0.25 on its own,
  # which is exactly what the gate is there to stop
  expect_false(
    cpsdrft(
      data.frame(v = stats::rnorm(80)),
      data.frame(v = stats::rnorm(80)),
      psithr = 0.01
    )$anydrft
  )
  expect_true(
    cpsdrft(
      data.frame(v = stats::rnorm(80)),
      data.frame(v = stats::rnorm(80)),
      psithr = 0.01,
      psiminn = 1L
    )$anydrft
  )
  expect_error(cpsdrft(ref, same, psiminn = -1), "non-negative integer")
  # an all-missing column is reported as untestable rather than guessed
  gap <- same
  gap$size <- NA_real_
  expect_true(is.na(cpsdrft(ref, gap)$columns$drifted[
    cpsdrft(ref, gap)$columns$column == "size"
  ]))

  # the summary condenses the same verdict
  s <- summary(m)
  expect_true(s$anydrft)
  expect_identical(s$ntes, 3L)
  expect_true(all(c("size", "grade") %in% s$drifted))

  expect_error(cpsdrft(ref, 1:5), "data frames")
  expect_error(cpsdrft(ref, same, alpha = 0), "strictly inside")
  expect_error(cpsdrft(ref, same, alpha = 1), "strictly inside")
})

# ---- the drift tests print as boxes and stay numbers -------------------------

test_that("drftks() and drftpsi() are boxed measures with readings", {
  set.seed(1)
  ref <- stats::rnorm(200)
  same <- drftks(ref, stats::rnorm(200))
  moved <- drftks(ref, stats::rnorm(200, mean = 0.8))
  expect_s3_class(same, c("rmbl_drftks", "rmbl_measure", "numeric"))
  expect_type(same[["statistic"]], "double")
  expect_null(attributes(same["p_value"])$class)
  expect_box2(same, "Kolmogorov-Smirnov", "No difference in distribution")
  expect_box2(moved, "Kolmogorov-Smirnov", "The two samples differ")
  p0 <- drftpsi(ref, ref)
  p1 <- drftpsi(ref, stats::rnorm(200, mean = 2))
  expect_box2(p0, "Population stability index", "stable")
  expect_box2(p1, "Population stability index", "a material shift")
})

test_that("drftchisq() and drfthomog() are boxed measures with readings", {
  ref <- c(a = 50, b = 30, c = 20)
  ok <- drftchisq(c(a = 100, b = 60, c = 40), ref)
  bad <- drftchisq(c(a = 40, b = 60, c = 100), ref)
  expect_s3_class(ok, c("rmbl_drftchisq", "rmbl_measure", "numeric"))
  expect_box2(ok, "Chi-square test against", "agree with the reference")
  expect_box2(bad, "Chi-square test against", "depart from the reference")
  inf <- drftchisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
  expect_box2(inf, "Chi-square test against", "flat contradiction")
  h <- drfthomog(c(a = 30, b = 20), c(a = 25, b = 25))
  expect_s3_class(h, c("rmbl_drfthomog", "rmbl_measure", "numeric"))
  expect_identical(attr(h, "method"), "chi-square approximation")
  expect_box2(h, "Chi-square test of homogeneity", "mixes of categories agree")
  h2 <- drfthomog(c(a = 80, b = 20), c(a = 20, b = 80))
  expect_box2(h2, "Chi-square test of homogeneity",
    "mixes of categories differ")
})

test_that("a drift test without its record formats as its numbers", {
  for (cls in c("rmbl_drftks", "rmbl_drftpsi", "rmbl_drftchisq",
    "rmbl_drfthomog")) {
    expect_plain_measure(cls)
  }
})
