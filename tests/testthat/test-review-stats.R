# The statistical defects of the 0.5.5 review, each pinned against an
# independent base-R computation (the review's own reproducers).

test_that("chi-square p-values are the upper tail, never a hard zero", {
  r <- drift_chisq(c(a = 40, b = 60, c = 100), c(a = 50, b = 30, c = 20))
  expect_equal(r[["statistic"]], 126)
  expect_equal(r[["p_value"]], stats::pchisq(126, 2, lower.tail = FALSE))
  expect_gt(r[["p_value"]], 0)
  r2 <- drift_homogeneity(c(x = 500, y = 500), c(x = 200, y = 800))
  expect_equal(r2[["p_value"]],
               stats::pchisq(r2[["statistic"]], 1, lower.tail = FALSE))
  expect_gt(r2[["p_value"]], 0)
  # a one-category table has no test: df 0 and NA, not df 1 and p 1
  one <- drift_chisq(c(a = 10), c(a = 7))
  expect_equal(one[["df"]], 0)
  expect_true(is.na(one[["p_value"]]))
})

test_that("the KS p-value does not grow more significant with n on near-identical columns", {
  for (n in c(5e4, 2e5, 1e6)) {
    x <- as.numeric(seq_len(n))
    y <- x
    y[n / 2] <- n / 2 + 0.5
    expect_equal(drift_ks(x, y)[["p_value"]], 1, tolerance = 1e-12)
  }
  set.seed(3)
  x <- stats::rnorm(200)
  y <- stats::rnorm(200, 0.3)
  expect_equal(drift_ks(x, y)[["p_value"]],
               suppressWarnings(stats::ks.test(x, y, exact = FALSE))$p.value,
               tolerance = 1e-10)
})

test_that("PSI sees a rescaled constant column and a rescaled zero-heavy tail", {
  p1 <- drift_psi(rep(5, 500), rep(500, 500))
  expect_gt(p1[["psi"]], 1)
  expect_equal(p1[["js_divergence"]], log(2), tolerance = 1e-6)
  p2 <- drift_psi(c(rep(0, 950), 1:50), c(rep(0, 950), (1:50) * 1000))
  expect_gt(p2[["psi"]], 0.1)
  expect_gt(p2[["js_divergence"]], 0)
  # unchanged behaviour where the reference has spread
  set.seed(1)
  ref <- stats::rnorm(800)
  expect_lt(drift_psi(ref, ref)[["psi"]], 1e-12)
})

test_that("drift_homogeneity has power on a high-cardinality column", {
  ref <- data.frame(d = as.character(as.Date("2020-01-01") + 1:400))
  cur <- data.frame(d = as.character(as.Date("2024-06-01") + 1:400))
  set.seed(1)
  cd <- capsule_drift(ref, cur)$columns
  expect_true(isTRUE(cd$drifted[1]))
  expect_gt(cd$psi[1], 0.25)
  # the chi-square of homogeneity conditions on the margins and has no
  # power here (every value occurs once): it is reported as a Monte Carlo
  # p-value, and the flag comes from the PSI and the unseen-category share
  h <- drift_homogeneity(ref$d, cur$d)
  expect_match(attr(h, "method"), "Monte Carlo")
  # half the current values in never-seen categories: still flagged
  half <- data.frame(d = c(ref$d[1:200], cur$d[1:200]))
  expect_true(isTRUE(capsule_drift(ref, half)$columns$drifted[1]) ||
                capsule_drift(ref, half)$columns$psi[1] > 0.25)
})

test_that("morans_i honours the magnitudes of a weight matrix", {
  n <- 6
  W <- matrix(0, n, n)
  W[1, 2] <- W[2, 1] <- 100
  W[2, 3] <- W[3, 2] <- 1
  W[3, 4] <- W[4, 3] <- 1
  W[4, 5] <- W[5, 4] <- 1
  W[5, 6] <- W[6, 5] <- 100
  x <- c(1, 2, 10, 11, 3, 4)
  z <- x - mean(x)
  m <- morans_i(x, W, style = "B", n_perm = 99L)
  expect_equal(m$W, sum(W))
  expect_equal(m$I, (n / sum(W)) * sum(outer(z, z) * W) / sum(z^2),
               tolerance = 1e-10)
  # row-standardised: each row's weights sum to one
  mw <- morans_i(x, W, style = "W", n_perm = 99L)
  expect_equal(mw$W, n)
  Ws <- W / rowSums(W)
  expect_equal(mw$I, (n / sum(Ws)) * sum(outer(z, z) * Ws) / sum(z^2),
               tolerance = 1e-10)
  # a binary matrix still agrees with the equivalent neighbour list
  nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)
  B <- (W != 0) * 1
  set.seed(1)
  a <- morans_i(x, nb, n_perm = 99L)$I
  set.seed(1)
  b <- morans_i(x, B, n_perm = 99L)$I
  expect_equal(a, b)
})

test_that("the exact Mann-Kendall p-value keeps ties", {
  Sfun <- function(v) {
    k <- length(v)
    s <- 0
    for (i in 1:(k - 1)) for (j in (i + 1):k) s <- s + sign(v[j] - v[i])
    s
  }
  for (v in list(c(1, 1, 2, 2, 3, 3), c(1, 1, 1, 2, 2, 2))) {
    idx <- as.matrix(expand.grid(rep(list(seq_along(v)), length(v))))
    idx <- idx[apply(idx, 1, function(r) length(unique(r)) == length(v)), ,
               drop = FALSE]
    pex <- mean(abs(apply(idx, 1, function(r) Sfun(v[r]))) >= abs(Sfun(v)))
    r <- trend_test(v)
    expect_equal(as.numeric(r["p_value"]), pex, tolerance = 1e-9)
    expect_match(r[["method"]], "ties kept")
  }
  # untied series: the distinct-rank enumeration as before
  expect_match(trend_test(c(3, 1, 4, 1.5, 5))[["method"]], "all 120 orderings$")
})

test_that("eb_rates refuses negative, missing and infinite counts", {
  expect_error(eb_rates(c(-5, 20), c(10, 20)), "non-negative")
  expect_error(eb_rates(c(NA, 20, 30), c(10, 20, 30)), "non-negative")
  expect_error(eb_rates(c(Inf, 20), c(10, 20)), "non-negative")
  expect_error(eb_rates(c(5, 20), c(NA, 20)), "finite")
})

test_that("parse_bands reads the common published forms and refuses the ambiguous ones", {
  b <- parse_bands(c("1,000 to 2,499", "ages 18-24", "18 to 24 years", "2 to 5",
                     "-10 to -5", "50+", "<5"))
  expect_equal(b$lower, c(1000, 18, 18, 2, -10, 50, NA))
  expect_equal(b$upper, c(2499, 24, 24, 5, -5, NA, 4))
  bad <- parse_bands(c("-5", "24 to 18", "100-200-300", "15 to 19 and over"))
  expect_true(all(is.na(bad$lower)))
  expect_true(all(is.na(bad$upper)))
})

test_that("expand_bands never drops units in silence", {
  expect_error(
    expand_bands(c("1", "2 to 5", "unknown", "Greater than 5"),
                 counts = c(10, 4, 99, 2), open_upper_cap = 12),
    "99 unit\\(s\\) in 1 band\\(s\\).*'unknown'")
  expect_warning(
    e <- expand_bands(c("1", "2 to 5", "unknown", "Greater than 5"),
                      counts = c(10, 4, 99, 2), open_upper_cap = 12,
                      drop_unparsed = TRUE),
    "could not be placed")
  expect_length(e, 16L)
  # a cap below the band's own lower bound is refused
  expect_error(band_values(parse_bands("50+"), open_upper_cap = 10),
               "below the band's own lower bound")
})

test_that("count_trend's quasi-Poisson interval uses t quantiles", {
  r <- count_trend(c(0, 0, 5, 0))
  expect_true(r$overdispersed)
  z <- stats::qt(0.975, df = 2)
  expect_equal(log(r$upper) - log(r$lower), 2 * z * r$se, tolerance = 1e-10)
})

test_that("the Sen interval says when a bound is a clamp", {
  expect_true(trend_test(c(1, 5, 2))$slope_ci_clamped)
  expect_false(trend_test(c(1, 3, 2, 5, 4, 6, 8, 7, 9, 11))$slope_ci_clamped)
})
