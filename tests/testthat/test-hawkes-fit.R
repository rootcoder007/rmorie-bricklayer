# Hawkes fitting on the shared C++ core: the same splitmix64 events and the same reference fits
# as morie's Python tests (tests/test_hawkes_fast_1_4_0.py), so each check is also a
# cross-language parity check.

hk_events <- function(n = 400L) {
  u <- core_uniforms(n, 7)
  v <- core_uniforms(n, 8)
  # sequential double additions, as Python's loop (cumsum accumulates in long double)
  t <- Reduce(`+`, -log(1 - u) * ifelse(v < 0.4, 0.05, 1), accumulate = TRUE)
  list(t = t, T = t[[n]] + 0.5)
}

hk_theta <- function(kernel, baseline) {
  a <- if (baseline == "constant") 0.1 else c(0.1, -0.3, 0.1, -0.2)
  psi <- switch(kernel, exponential = 8, weibull = c(0.9, 0.2), gamma = c(1.4, 6), lomax = c(2.5, 0.3))
  c(a, 0.35, psi)
}

hk_nll <- function(t, horizon, kernel, baseline, th, method = 0L, eps = 1e-12) {
  nb <- if (baseline == "constant") 1L else 4L
  kind <- c(exponential = 0L, weibull = 1L, gamma = 2L, lomax = 3L)[[kernel]]
  soe <- if (kernel == "lomax") {
    c(horizon + 100, 1e-3 / (horizon + 100))
  } else {
    c(horizon, max(min(diff(t)[diff(t) > 0]), 1e-12) / horizon)
  }
  .Call(rmoriebricklayer:::C_rmbl_hawkes_nll_grad, t, horizon, if (baseline == "constant") 0L else 1L,
        th[seq_len(nb)], th[[nb + 1L]], kind, th[-seq_len(nb + 1L)], method, eps, soe[[1]], soe[[2]], TRUE)
}

test_that("splitmix64 is the stream morie's Python draws", {
  expect_identical(core_uniforms(3, 42), c(0.7415648787718233, 0.1599103928769201, 0.27860113025513866))
  e <- hk_events()
  expect_identical(e$t[1:3], c(0.49401725975830246, 0.5109480750755095, 2.82116905344865))
  expect_identical(e$T, 261.98663489850486)
  expect_error(core_uniforms(-1, 1), "non-negative")
  expect_error(core_uniforms(2, 2^60), "seed")
})

test_that("the analytic gradient matches finite differences for every kernel and baseline", {
  e <- hk_events(250L)
  for (k in c("exponential", "weibull", "gamma", "lomax")) for (b in c("constant", "sinusoidal")) {
    th <- hk_theta(k, b)
    g <- hk_nll(e$t, e$T, k, b, th)[[2]]
    for (i in seq_along(th)) {
      h <- 1e-6 * max(1, abs(th[[i]]))
      up <- th
      dn <- th
      up[[i]] <- up[[i]] + h
      dn[[i]] <- dn[[i]] - h
      fd <- (hk_nll(e$t, e$T, k, b, up)[[1]] - hk_nll(e$t, e$T, k, b, dn)[[1]]) / (2 * h)
      expect_lt(abs(g[[i]] - fd), 1e-5 * max(1, abs(fd)))
    }
  }
})

test_that("fits reproduce the reference morie's Python reaches (same core, same optimum)", {
  e <- hk_events()
  ref <- list(
    "exponential/constant" = list(118.69858088105596, c(-0.018591937991204354, 0.3570981557350094, 17.45814437003573)),
    "exponential/sinusoidal" = list(116.36039351077994, c(0.1401679237176167, -0.41637456168187165,
                                                            -0.09236260967814879, -0.3202571656173522,
                                                            0.35328832763395485, 17.76625382246286)),
    "weibull/constant" = list(116.70074310550106, c(0.005222397486131046, 0.3416039447382219, 1.2237668778195339,
                                                    0.05153286699576664)),
    "gamma/constant" = list(116.00586580075705, c(-0.007363356926464604, 0.34983843433834755, 1.3153317779470712, 25)),
    "lomax/constant" = list(118.7462762190834, c(-0.021698915606398167, 0.3590927995717976, 30, 1.7084589308626537))
  )
  for (key in names(ref)) {
    kb <- strsplit(key, "/")[[1]]
    f <- core_hawkes_fit(e$t, e$T, kb[[1]], kb[[2]])
    expect_equal(f$nll, ref[[key]][[1]], tolerance = 1e-10)
    expect_lt(max(abs(f$theta - ref[[key]][[2]])), 1e-6)
    expect_true(f$ks_pvalue >= 0 && f$ks_pvalue <= 1 && isTRUE(f$converged))
  }
})

test_that("the sum of exponentials stays within n * eps of the exact likelihood", {
  e <- hk_events(1200L)
  for (k in c("lomax", "gamma")) {
    th <- c(0.1, 0.35, if (k == "gamma") c(0.6, 3) else c(1.8, 0.4))
    ex <- hk_nll(e$t, e$T, k, "constant", th, 0L)[[1]]
    for (eps in c(1e-6, 1e-9)) {
      expect_lte(abs(hk_nll(e$t, e$T, k, "constant", th, 1L, eps)[[1]] - ex), length(e$t) * eps)
    }
  }
})

test_that("EM reaches the direct maximum; INAR is close; truncation is close; bad routes are refused", {
  e <- hk_events(250L)
  direct <- core_hawkes_fit(e$t, e$T, "exponential")
  em <- core_hawkes_fit(e$t, e$T, "exponential", method = "em")
  expect_lt(abs(em$nll - direct$nll), 1e-4)
  inar <- core_hawkes_fit(e$t, e$T, "exponential", method = "inar")
  expect_identical(inar$method, "inar")
  expect_lt(abs(inar$branching_ratio - direct$branching_ratio), 0.25)
  tr <- core_hawkes_fit(e$t, e$T, "gamma", method = "truncate", eps = 1e-10)
  expect_identical(tr$method, "truncate")
  expect_identical(tr$n, length(e$t[e$t <= e$T]))  # an event at the horizon is part of the record
  expect_identical(core_hawkes_fit(e$t, e$T, "weibull")$method, "truncate")
  expect_lt(abs(tr$nll - core_hawkes_fit(e$t, e$T, "gamma", method = "exact")$nll), 1e-3)
  expect_error(core_hawkes_fit(e$t, e$T, "exponential", "sinusoidal", method = "inar"), "stationary")
  expect_error(core_hawkes_fit(e$t, e$T, "weibull", method = "soe"), "completely monotone")
  expect_error(core_hawkes_fit(e$t, e$T, "exponential", method = "newton"), "should be one of")
  expect_error(core_hawkes_fit(e$t[1:10], e$T, "exponential"), "too few events")
  expect_error(core_hawkes_fit(rev(e$t), e$T, "exponential"), "sorted")
  expect_error(core_hawkes_fit(e$t, e$T, "exponential", eps = 2), "eps")
})

test_that("residuals are uniform-range and refuse a wrong parameter count", {
  e <- hk_events(150L)
  U <- core_hawkes_residuals(e$t, e$T, "gamma", hk_theta("gamma", "sinusoidal"), baseline = "sinusoidal")
  expect_length(U, 150L)
  expect_true(all(U > 0 & U < 1))
  expect_error(core_hawkes_residuals(e$t, e$T, "gamma", c(1, 2)), "length")
})
