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


test_that("a bad horizon, events outside the window and a start outside the model are refused", {
  e <- hk_events(100L)
  expect_error(core_hawkes_fit(e$t, 0), "single positive finite number")
  expect_error(core_hawkes_fit(e$t, -1), "single positive finite number")
  expect_error(core_hawkes_fit(e$t, Inf), "single positive finite number")
  expect_error(core_hawkes_nll(e$t, Inf, "exponential", c(0, 0.3, 1)), "single positive finite number")
  expect_error(core_hawkes_residuals(e$t, Inf, "exponential", c(0, 0.3, 1)), "single positive finite number")
  expect_error(core_hawkes_fit(c(e$t, e$T + 1), e$T), "within \\[0, horizon\\]")
  expect_error(core_hawkes_fit(c(-1, e$t), e$T), "within \\[0, horizon\\]")
  # exp(15) events a day over 10^5 days: a compensator past 10^11, where the core reports no likelihood
  far <- seq(1, 1e5, length.out = 100L)
  expect_error(core_hawkes_fit(far, 1e5 + 1, start = c(15, 0.5, 1)), "not finite at `start`")
  # the core checks parameter counts itself
  expect_error(.Call(C_rmbl_hawkes_nll_grad, e$t, e$T, 0L, c(0, 1), 0.5, 0L, 1, 0L, 1e-9, 1, 1e-3, TRUE),
               "wrong number of baseline or kernel parameters")
  expect_error(.Call(C_rmbl_hawkes_fit_pbfgs, e$t, e$T, 0L, 0L, 0L, 1e-9, 1, 1e-3, c(-5, 0), c(5, 1),
                     c(0, 0.5), 100L, 1e-6), "wrong number of parameters")
})

test_that("EM reaches the direct maximum for every kernel and for the sinusoidal baseline", {
  e <- hk_events(300L)
  for (k in c("weibull", "gamma", "lomax")) {
    em <- core_hawkes_fit(e$t, e$T, k, method = "em")
    expect_identical(em$method, "em")
    expect_lt(abs(em$nll - core_hawkes_fit(e$t, e$T, k)$nll), 1e-6)  # measured: at most 8e-12
    expect_true(em$converged)
  }
  em <- core_hawkes_fit(e$t, e$T, "exponential", "sinusoidal", method = "em")
  expect_lt(abs(em$nll - core_hawkes_fit(e$t, e$T, "exponential", "sinusoidal")$nll), 1e-6)  # measured 2.1e-8
})

test_that("truncation at a tiny eps equals the exact likelihood for the exponential and Lomax kernels", {
  e <- hk_events(300L)
  expect_lt(abs(core_hawkes_fit(e$t, e$T, "exponential", method = "truncate", eps = 1e-12)$nll -
                  core_hawkes_fit(e$t, e$T, "exponential")$nll), 1e-9)
  expect_lt(abs(core_hawkes_fit(e$t, e$T, "lomax", method = "truncate", eps = 1e-12)$nll -
                  core_hawkes_fit(e$t, e$T, "lomax", method = "soe")$nll), 1e-9)
})

test_that("an event at the horizon is part of the record and adds no compensator", {
  e <- hk_events(200L)
  f <- core_hawkes_fit(e$t, max(e$t), "weibull")
  expect_identical(f$n, length(e$t))
  expect_true(is.finite(f$nll))
})

test_that("INAR fits every kernel without straying outside the parameter box", {
  # Nelder-Mead is unbounded; a point outside the box is scored invalid before any CDF is
  # evaluated, so no "NaNs produced" warning reaches the caller
  e <- hk_events(300L)
  for (k in c("weibull", "gamma", "lomax")) {
    expect_no_warning(i <- core_hawkes_fit(e$t, e$T, k, method = "inar"))
    expect_identical(i$method, "inar")
    expect_true(is.finite(i$nll))
    expect_lt(abs(i$branching_ratio - core_hawkes_fit(e$t, e$T, k)$branching_ratio), 0.25)
  }
})

# the documented likelihood, written out: lambda(t_i) = nu + eta * sum over t_j < t_i
# (strictly earlier: an event does not excite one at the same instant)
hk_ref_nll <- function(t, horizon, kernel, par) {
  nu <- exp(par[[1]])
  eta <- par[[2]]
  psi <- par[-(1:2)]
  g <- switch(kernel,
    exponential = function(u) psi[[1]] * exp(-psi[[1]] * u),
    weibull = function(u) stats::dweibull(u, psi[[1]], psi[[2]]),
    gamma = function(u) stats::dgamma(u, psi[[1]], psi[[2]]),
    lomax = function(u) psi[[1]] * psi[[2]]^psi[[1]] / (u + psi[[2]])^(psi[[1]] + 1))
  G <- switch(kernel,
    exponential = function(u) stats::pexp(u, psi[[1]]),
    weibull = function(u) stats::pweibull(u, psi[[1]], psi[[2]]),
    gamma = function(u) stats::pgamma(u, psi[[1]], psi[[2]]),
    lomax = function(u) 1 - (psi[[2]] / (u + psi[[2]]))^psi[[1]])
  lam <- vapply(seq_along(t), function(i) {
    u <- t[i] - t[t < t[i]]
    nu + eta * sum(g(u))
  }, numeric(1))
  -(sum(log(lam)) - nu * horizon - eta * sum(G(horizon - t)))
}

test_that("core_hawkes_nll is the likelihood core_hawkes_fit maximises, for every kernel", {
  set.seed(4)
  x <- sort(stats::runif(40, 0, 10))
  pars <- list(exponential = c(-0.5, 0.3, 1.2), weibull = c(-0.5, 0.3, 0.9, 1.5),
               gamma = c(-0.5, 0.3, 2, 1.5), lomax = c(-0.5, 0.3, 2, 1.5))
  for (k in names(pars)) {
    expect_equal(core_hawkes_nll(x, 10, k, pars[[k]]), hk_ref_nll(x, 10, k, pars[[k]]), tolerance = 1e-10, info = k)
  }
  # the Lomax is the shape-alpha Lomax the fit reports: its fitted theta gives back its nll
  e <- hk_events(300L)
  f <- core_hawkes_fit(e$t, e$T, "lomax")
  expect_equal(core_hawkes_nll(e$t, e$T, "lomax", f$theta), f$nll, tolerance = 1e-9)
  # the documented sentinel outside the stationary region or the kernel's domain
  expect_identical(core_hawkes_nll(x, 10, "exponential", c(-0.5, 1.5, 1.2)), 1e12)
  expect_identical(core_hawkes_nll(x, 10, "lomax", c(-0.5, 0.3, -2, 1.5)), 1e12)
})

test_that("events at the same instant do not excite each other, on every route", {
  set.seed(9)
  x <- sort(c(stats::runif(34, 0, 10), rep(c(2, 5, 7.5), each = 3)))  # three triples of tied times
  pars <- list(exponential = c(-0.5, 0.3, 1.2), weibull = c(-0.5, 0.3, 0.9, 1.5),
               gamma = c(-0.5, 0.3, 2, 1.5), lomax = c(-0.5, 0.3, 2, 1.5))
  for (k in names(pars)) {
    expect_equal(core_hawkes_nll(x, 10, k, pars[[k]]), hk_ref_nll(x, 10, k, pars[[k]]), tolerance = 1e-10, info = k)
  }
  # the sum-of-exponentials route (Lomax; gamma with shape < 1) and its recursion
  ns <- asNamespace("rmoriebricklayer")
  for (k in c("lomax", "gamma")) {
    p <- if (k == "lomax") c(-0.5, 0.3, 2, 1.5) else c(-0.5, 0.3, 0.6, 1.5)
    soe <- ns$.rmbl_hk_call(x, 10, k, "constant", p, "soe", 1e-12, FALSE)[[1]]
    expect_equal(soe, hk_ref_nll(x, 10, k, p), tolerance = 1e-9, info = k)
  }
  # enough events that the sum-of-exponentials recursion itself runs (not its exact fallback)
  set.seed(10)
  y <- sort(c(stats::runif(560, 0, 100), rep(c(10, 20, 30, 40), each = 10)))
  for (k in c("lomax", "gamma")) {
    p <- if (k == "lomax") c(-0.5, 0.3, 2, 1.5) else c(-0.5, 0.3, 0.6, 1.5)
    expect_equal(ns$.rmbl_hk_call(y, 100, k, "constant", p, "soe", 1e-12, FALSE)[[1]],
                 hk_ref_nll(y, 100, k, p), tolerance = 1e-8, info = k)
  }
  # 100 events at one instant: no self-excitation to reward, so no steep kernel and no
  # likelihood above the Poisson one
  expect_warning(f <- core_hawkes_fit(rep(5, 100), 200), "99 event\\(s\\) share their time")
  expect_equal(f$nll, hk_ref_nll(rep(5, 100), 200, "exponential", f$theta), tolerance = 1e-9)
  expect_gte(f$nll, -(100 * log(100 / 200) - 100) - 1e-6)
})

test_that("core_hawkes_jitter spreads recorded times across their interval, as rmorie and morie do", {
  days <- c(3, 0, 0, 1, 3, 0)
  j <- core_hawkes_jitter(days)
  # rmorie's TPS conversion: sorted days plus core_uniforms(n, 42), sorted
  expect_identical(j, sort(sort(days) + core_uniforms(6, 42)))
  expect_false(anyDuplicated(j) > 0)
  expect_true(all(floor(j) %in% days))  # each time stays inside its own day
  expect_identical(core_hawkes_jitter(days, 0.5, seed = 7), sort(sort(days) + 0.5 * core_uniforms(6, 7)))
  expect_identical(core_hawkes_jitter(numeric()), numeric())
  expect_error(core_hawkes_jitter(c(1, NA)), "finite")
  expect_error(core_hawkes_jitter(c(1, Inf)), "finite")
  expect_error(core_hawkes_jitter(1, 0), "single positive finite number")
  expect_error(core_hawkes_jitter(1, c(1, 2)), "single positive finite number")
  # daily data: the jittered times fit without the tie warning
  set.seed(3)
  d <- sort(floor(stats::runif(300, 0, 120)))
  expect_warning(core_hawkes_fit(d, 121), "share their time")
  expect_no_warning(core_hawkes_fit(core_hawkes_jitter(d), 121))
})

test_that("auto fits a gamma kernel by soe, which reaches the exact route's maximum", {
  ns <- asNamespace("rmoriebricklayer")
  expect_identical(ns$.rmbl_hk_method("auto", "gamma"), "soe")
  expect_identical(ns$.rmbl_hk_method("auto", "lomax"), "soe")
  expect_identical(ns$.rmbl_hk_method("exact", "gamma"), "exact")
  e <- hk_events(300L)
  f <- core_hawkes_fit(e$t, e$T, "gamma")
  x <- core_hawkes_fit(e$t, e$T, "gamma", method = "exact")
  expect_identical(f$method, "soe")
  expect_true(f$converged)
  expect_lt(abs(f$nll - x$nll), 1e-6)
})
