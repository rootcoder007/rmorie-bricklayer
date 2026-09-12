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
    got <- drift_ks(a, b)
    want <- suppressWarnings(stats::ks.test(a, b))
    expect_equal(got[["statistic"]], as.numeric(want$statistic))
  }
  expect_named(drift_ks(1:10, 2:11), c("statistic", "p_value", "n_eff"))
  # the effective size is the harmonic-style combination
  k <- drift_ks(stats::rnorm(70), stats::rnorm(50))
  expect_equal(k[["n_eff"]], 70 * 50 / (70 + 50))

  # a sample against itself has nowhere to differ
  x <- stats::rnorm(100)
  expect_equal(drift_ks(x, x)[["statistic"]], 0)
  expect_equal(drift_ks(x, x)[["p_value"]], 1)
  # completely separated samples are the maximum statistic
  expect_equal(drift_ks(1:10, 101:110)[["statistic"]], 1)
  expect_lt(drift_ks(1:50, 101:150)[["p_value"]], 1e-6)
  # a real shift is detected and a null one is not
  expect_lt(drift_ks(stats::rnorm(300), stats::rnorm(300, 1))[["p_value"]],
            0.01)
  expect_gt(drift_ks(stats::rnorm(300), stats::rnorm(300))[["p_value"]], 0.01)
  # a change in spread alone is caught, which comparing means would miss
  expect_lt(drift_ks(stats::rnorm(400), stats::rnorm(400, 0, 3))[["p_value"]],
            0.01)
  # p-values are probabilities, and the statistic is a proportion
  expect_true(k[["p_value"]] >= 0 && k[["p_value"]] <= 1)
  expect_true(k[["statistic"]] >= 0 && k[["statistic"]] <= 1)
  # ties are handled by comparing the EDFs, without a warning
  expect_silent(drift_ks(c(1, 1, 2, 2, 3), c(1, 2, 2, 3, 3)))
  # NA is dropped rather than poisoning the statistic
  expect_equal(drift_ks(c(x, NA), x)[["statistic"]],
               drift_ks(x, x)[["statistic"]])

  expect_error(drift_ks(numeric(0), 1:5), "at least one non-missing")
  expect_error(drift_ks(c(NA, NA), 1:5), "at least one non-missing")
})

test_that("PSI and Jensen-Shannon divergence are their closed forms", {
  set.seed(12)
  ref <- stats::rnorm(800)

  # identical inputs have moved nowhere
  same <- drift_psi(ref, ref)
  expect_named(same, c("psi", "js_divergence"))
  expect_equal(same[["psi"]], 0, tolerance = 1e-9)
  expect_equal(same[["js_divergence"]], 0, tolerance = 1e-9)

  # a shift registers on both, and a bigger shift registers more
  mild <- drift_psi(ref, stats::rnorm(800, 0.3))
  hard <- drift_psi(ref, stats::rnorm(800, 1.5))
  expect_gt(hard[["psi"]], mild[["psi"]])
  expect_gt(hard[["js_divergence"]], mild[["js_divergence"]])
  expect_gt(hard[["psi"]], 0.25)
  # both are non-negative
  expect_true(all(c(mild, hard) >= 0))
  # the Jensen-Shannon divergence is bounded by log 2 in nats, however
  # far apart the two samples are -- that bound is what makes it
  # comparable between columns with different bin counts
  expect_lte(drift_psi(rep(1, 50), rep(99, 50))[["js_divergence"]], log(2))
  expect_lte(hard[["js_divergence"]], log(2))
  # more bins resolves a shift more finely
  expect_true(is.finite(drift_psi(ref, stats::rnorm(800, 1), bins = 25)[["psi"]]))
  # a constant reference column still returns a finite answer instead of
  # dividing by a zero-width bin
  expect_true(is.finite(drift_psi(rep(3, 40), rep(3, 40))[["psi"]]))
  expect_true(is.finite(drift_psi(rep(3, 40), rep(9, 40))[["psi"]]))

  expect_error(drift_psi(ref, numeric(0)), "at least one non-missing")
  expect_error(drift_psi(ref, ref, bins = 1), "at least 2")
})

test_that("the chi-square drift statistic matches stats::chisq.test", {
  ref <- c(a = 50, b = 30, c = 20)
  obs <- c(a = 40, b = 60, c = 100)
  got <- drift_chisq(obs, ref)
  want <- stats::chisq.test(obs, p = ref / sum(ref))
  expect_equal(got[["statistic"]], as.numeric(want$statistic))
  expect_equal(got[["df"]], as.numeric(want$parameter))
  expect_equal(got[["p_value"]], want$p.value)
  expect_named(got, c("statistic", "df", "p_value"))

  # counts in the reference proportions have nothing to explain
  expect_equal(drift_chisq(c(a = 100, b = 60, c = 40), ref)[["statistic"]], 0)
  expect_equal(drift_chisq(c(a = 100, b = 60, c = 40), ref)[["p_value"]], 1)
  # the reference may be given as proportions or as counts alike
  expect_equal(drift_chisq(obs, ref)[["statistic"]],
               drift_chisq(obs, ref / sum(ref))[["statistic"]])
  # raw vectors are tabulated
  t1 <- drift_chisq(c("a", "a", "b", "b"), c("a", "b"))
  expect_equal(t1[["statistic"]], 0)
  # a category the reference rules out, but which occurs, contradicts the
  # pinned distribution outright rather than being dropped from the sum
  newcat <- drift_chisq(c("a", "a", "b", "d"), c("a", "a", "b", "b"))
  expect_equal(newcat[["statistic"]], Inf)
  expect_equal(newcat[["p_value"]], 0)
  # whereas a category with a positive expectation contributes finitely
  fin <- drift_chisq(c(a = 1, b = 99), c(a = 50, b = 50))
  expect_true(is.finite(fin[["statistic"]]))
  expect_gt(fin[["statistic"]], 0)
  # and so is a vanished one
  gone <- drift_chisq(c("a", "a", "a", "a"), c("a", "a", "b", "b"))
  expect_gt(gone[["statistic"]], 0)
  # a bigger reallocation gives a bigger statistic
  expect_gt(drift_chisq(c(a = 10, b = 10, c = 180), ref)[["statistic"]],
            drift_chisq(c(a = 60, b = 80, c = 60), ref)[["statistic"]])
  # the p-value is the chi-square tail
  expect_equal(got[["p_value"]],
               stats::pchisq(got[["statistic"]], got[["df"]],
                             lower.tail = FALSE))

  expect_error(drift_chisq(c(1, 2, 3), ref), "must be named")
  expect_error(drift_chisq(c(a = 0, b = 0), c(a = 1, b = 1)), "no counts")
})

test_that("the Benford screen is the log10 law", {
  set.seed(13)
  # a quantity spanning several orders of magnitude follows the law
  ok <- benford_test(10^stats::runif(4000, 0, 6))
  expect_s3_class(ok, "bricklayer_benford")
  expect_gt(ok$p_value, 0.01)
  # the expected proportions ARE the closed form
  expect_equal(ok$expected / ok$n, log10(1 + 1 / (1:9)), ignore_attr = TRUE)
  expect_equal(sum(ok$expected), ok$n)
  expect_equal(names(ok$counts), as.character(1:9))
  expect_equal(sum(ok$counts), ok$n)
  expect_equal(ok$df, 8L)
  expect_equal(ok$proportion, ok$counts / ok$n)
  # leading 1s are the most common digit under the law
  expect_equal(which.max(ok$counts), 1L, ignore_attr = TRUE)

  # a column whose leading digits are uniform does not follow it
  flat <- benford_test(as.numeric(paste0(rep(1:9, each = 400), "000")))
  expect_lt(flat$p_value, 1e-6)
  # nor does one pinned to a single digit
  expect_lt(benford_test(rep(5000, 500))$p_value, 1e-6)

  # the sign is irrelevant and zeros carry no leading digit
  expect_equal(benford_test(c(-19, 19))$counts[["1"]], 2)
  expect_equal(benford_test(c(0, 0, 1, 2, 3))$n, 3)
  expect_equal(benford_test(c(0.00023, 2.3, 230))$counts[["2"]], 3)
  # non-finite values are excluded
  expect_equal(benford_test(c(1, 2, NA, Inf, -Inf))$n, 2)
  # the p-value is the chi-square tail on 8 df
  expect_equal(ok$p_value,
               stats::pchisq(ok$statistic, 8, lower.tail = FALSE))
  expect_equal(summary(ok)[["n"]], ok$n)

  expect_error(benford_test(c(0, 0, 0)), "no finite non-zero")
  expect_error(benford_test(numeric(0)), "no finite non-zero")
})

test_that("capsule_drift tests every shared column and flags the movers", {
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

  d <- capsule_drift(ref, same)
  expect_s3_class(d, "bricklayer_drift")
  expect_false(d$any_drift)
  expect_equal(nrow(d$columns), 3L)
  expect_equal(sort(d$columns$column), c("grade", "size", "value"))
  expect_equal(d$columns$type[d$columns$column == "grade"], "categorical")
  expect_equal(d$columns$type[d$columns$column == "value"], "numeric")
  expect_equal(d$n_reference, n)
  expect_equal(d$n_current, n)
  expect_length(d$added, 0L)
  expect_length(d$removed, 0L)
  expect_true(all(!d$columns$drifted))
  # a numeric column reports PSI; a categorical one has none to report
  expect_true(all(is.finite(d$columns$psi[d$columns$type == "numeric"])))
  expect_true(all(is.na(d$columns$psi[d$columns$type == "categorical"])))

  # a rescaled numeric column and a new category are both caught
  moved <- same
  moved$size <- moved$size * 3
  moved$grade[1:150] <- "z"
  m <- capsule_drift(ref, moved)
  expect_true(m$any_drift)
  expect_true(m$columns$drifted[m$columns$column == "size"])
  expect_true(m$columns$drifted[m$columns$column == "grade"])
  # the untouched column is not flagged
  expect_false(m$columns$drifted[m$columns$column == "value"])

  # structural changes are reported rather than tested
  fewer <- capsule_drift(ref, same[, c("value", "grade")])
  expect_equal(fewer$removed, "size")
  expect_equal(nrow(fewer$columns), 2L)
  expect_true(fewer$any_drift)
  extra <- same
  extra$brand_new <- 1
  expect_equal(capsule_drift(ref, extra)$added, "brand_new")
  expect_true(capsule_drift(ref, extra)$any_drift)
  # no shared columns at all is an empty table, not an error
  none <- capsule_drift(ref, data.frame(q = 1:3))
  expect_equal(nrow(none$columns), 0L)
  expect_true(none$any_drift)

  # a stricter alpha flags fewer columns
  mild <- same
  mild$value <- mild$value + 0.22
  expect_true(sum(capsule_drift(ref, mild, alpha = 0.2)$columns$drifted) >=
                sum(capsule_drift(ref, mild, alpha = 1e-8)$columns$drifted))
  # the PSI threshold can flag a column on its own, but only once both
  # samples are large enough for the band to mean anything
  expect_true(capsule_drift(ref, moved, alpha = 1e-12, psi_threshold = 0.05,
                            psi_min_n = 10L)$any_drift)
  # with the default minimum it is reported but does not raise the flag
  noise <- capsule_drift(data.frame(v = stats::rnorm(80)),
                         data.frame(v = stats::rnorm(80)))
  expect_true(is.finite(noise$columns$psi))
  expect_false(noise$any_drift)
  # a binning-noise PSI on a small sample would clear 0.25 on its own,
  # which is exactly what the gate is there to stop
  expect_false(capsule_drift(data.frame(v = stats::rnorm(80)),
                             data.frame(v = stats::rnorm(80)),
                             psi_threshold = 0.01)$any_drift)
  expect_true(capsule_drift(data.frame(v = stats::rnorm(80)),
                            data.frame(v = stats::rnorm(80)),
                            psi_threshold = 0.01,
                            psi_min_n = 1L)$any_drift)
  expect_error(capsule_drift(ref, same, psi_min_n = -1),
               "non-negative integer")
  # an all-missing column is reported as untestable rather than guessed
  gap <- same
  gap$size <- NA_real_
  expect_true(is.na(capsule_drift(ref, gap)$columns$drifted[
    capsule_drift(ref, gap)$columns$column == "size"]))

  # the summary condenses the same verdict
  s <- summary(m)
  expect_true(s$any_drift)
  expect_equal(s$n_tested, 3L)
  expect_true(all(c("size", "grade") %in% s$drifted))

  expect_error(capsule_drift(ref, 1:5), "data frames")
  expect_error(capsule_drift(ref, same, alpha = 0), "strictly inside")
  expect_error(capsule_drift(ref, same, alpha = 1), "strictly inside")
})
