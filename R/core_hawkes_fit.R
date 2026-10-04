# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hawkes processes with a constant or sinusoidal baseline and four kernels,
# fitted by maximum likelihood with the analytic gradient of the shared C++
# core (morie_core.h: hawkes_nll_grad, hawkes_rescaled, hawkes_intensity,
# hawkes_em_pass, hawkes_cdf_sum) -- the same code morie's Python arm calls.

.rmbl_hk_kind <- c(exponential = 0L, weibull = 1L, gamma = 2L, lomax = 3L)
.rmbl_hk_bkind <- c(constant = 0L, sinusoidal = 1L)
.rmbl_hk_methods <- c("auto", "exact", "soe", "truncate", "em", "inar")

.rmbl_hk_method <- function(method, kernel) {
  method <- match.arg(method, .rmbl_hk_methods)
  # Weibull's exact window is where the kernel underflows: for shape < 1 the whole record
  if (method == "auto") return(switch(kernel, exponential = "exact", weibull = "truncate", "soe"))
  if (method == "soe" && !kernel %in% c("lomax", "gamma")) {
    stop("method = \"soe\" applies to completely monotone kernels: \"lomax\", and \"gamma\" with shape < 1 ",
         "(a gamma kernel with shape >= 1 is truncated at eps); use \"exact\" or \"truncate\"", call. = FALSE)
  }
  method
}

# the sum-of-exponentials window: r = (u + c)/R in [delta, 1] (Lomax, c <= 100 in the
# fit), r = u/R from the smallest gap (gamma)
.rmbl_hk_soe <- function(times, horizon, kernel) {
  if (kernel == "lomax") return(c(horizon + 100, 1e-3 / (horizon + 100)))
  g <- diff(times)
  g <- g[g > 0]
  c(horizon, max(if (length(g)) min(g) else 1e-9, 1e-12) / horizon)
}

.rmbl_hk_call <- function(times, horizon, kernel, baseline, theta, method, eps, gradient) {
  nb <- if (baseline == "constant") 1L else 4L
  soe <- .rmbl_hk_soe(times, horizon, kernel)
  code <- c(exact = 0L, soe = 1L, truncate = 2L)[[method]]
  .Call(C_rmbl_hawkes_nll_grad, times, horizon, .rmbl_hk_bkind[[baseline]], theta[seq_len(nb)], theta[[nb + 1L]],
        .rmbl_hk_kind[[kernel]], theta[-seq_len(nb + 1L)], code, eps, soe[[1]], soe[[2]], gradient)
}

.rmbl_hk_check_times <- function(times, horizon) {
  times <- .rmbl_num(times, "times")
  if (anyNA(times)) stop("`times` must not contain NA", call. = FALSE)
  if (length(times) > 1L && any(diff(times) < 0)) stop("`times` must be sorted in increasing order", call. = FALSE)
  horizon <- .rmbl_num(horizon, "horizon")
  if (length(horizon) != 1L || is.na(horizon) || horizon <= 0) {
    stop("`horizon` must be a single positive number", call. = FALSE)
  }
  if (length(times) > 0L && (min(times) < 0 || max(times) > horizon)) {
    stop("`times` must lie within [0, horizon]", call. = FALSE)
  }
  list(times = times, horizon = horizon)
}

.rmbl_hk_x0 <- function(kernel, baseline, n, horizon, mean_dt) {
  rate <- max(n / horizon, 1e-3)
  a <- if (baseline == "constant") log(rate * 0.6) else c(log(rate * 0.6), 0, 0, 0)
  psi <- switch(kernel,
    exponential = 1 / max(mean_dt, 1e-3),
    gamma = c(1.5, 1 / max(mean_dt, 1e-3)),
    weibull = c(1.5, max(mean_dt, 1e-3) * 1.2),
    lomax = c(2.5, max(mean_dt, 1e-3) * 5)
  )
  c(a, 0.4, psi)
}

.rmbl_hk_bounds <- function(kernel, baseline) {
  nb <- if (baseline == "constant") 1L else 4L
  lo <- c(-15, rep(-5, nb - 1L), 1e-3)
  hi <- c(15, rep(5, nb - 1L), 0.99)
  k <- switch(kernel,
    exponential = list(0.1, 25),
    weibull = list(c(0.1, 1e-3), c(15, 100)),
    gamma = list(c(0.1, 0.05), c(15, 25)),
    lomax = list(c(1.05, 1e-3), c(30, 100))
  )
  list(lower = c(lo, k[[1]]), upper = c(hi, k[[2]]))
}

#' Fit a Hawkes process by maximum likelihood (analytic gradient, fast routes)
#'
#' Maximum-likelihood fit of a univariate Hawkes process
#' \eqn{\lambda(t) = \nu(t) + \eta \sum_{t_j < t} g(t - t_j)} with a
#' constant baseline (\eqn{\nu = e^{a_0}}) or a sinusoidal one
#' (\eqn{\nu(t) = \exp(a_0 + a_1 t/T + a_2 \sin(2\pi t/365.25) + a_3 \cos(2\pi t/365.25))},
#' its integral by the trapezoid rule on \code{max(64, floor(T) + 1)} points) and one of four
#' normalised kernels: exponential (decay \code{beta}), Weibull (\code{alpha, lambda}),
#' gamma (\code{alpha, beta}) or Lomax (\code{alpha, c}). Every route uses the analytic
#' gradient, so one likelihood evaluation per point instead of one per parameter.
#'
#' \describe{
#'   \item{\code{"exact"}}{Ozaki's O(n) recursion for the exponential kernel; for Weibull and
#'     gamma the double sum stops where the kernel underflows to exactly 0 (the same value as
#'     the full sum); Lomax the full O(n^2) sum.}
#'   \item{\code{"soe"}}{the completely monotone kernels (Lomax; gamma with shape < 1) as a
#'     sum of exponentials (Beylkin & Monzon 2010): relative error \code{eps} on every
#'     intensity, O(n K); a gamma kernel with shape >= 1 is truncated at \code{eps}.}
#'   \item{\code{"truncate"}}{each event excites only lags with kernel tail mass above
#'     \code{eps}: an approximation for light-tailed kernels, O(n w).}
#'   \item{\code{"em"}}{the EM algorithm (Veen & Schoenberg 2008): the same maximum, a
#'     different route.}
#'   \item{\code{"inar"}}{Kirchner's (2017) INAR(p) least-squares estimator on binned counts
#'     (constant baseline only): a different, fast, approximate estimator.}
#'   \item{\code{"auto"}}{\code{"exact"} for the exponential kernel, \code{"truncate"} for
#'     Weibull, \code{"soe"} for Lomax and gamma.}
#' }
#' The reported \code{nll} is the exact likelihood at the estimate whatever the route, so AIC
#' is comparable across routes. An event exactly at \code{horizon} is left out, as in morie's
#' Python fit.
#'
#' @param times Sorted event times in \code{[0, horizon]}.
#' @param horizon End of the observation window.
#' @param kernel One of \code{"exponential"}, \code{"weibull"},
#'   \code{"gamma"}, \code{"lomax"}.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param method One of \code{"auto"}, \code{"exact"}, \code{"soe"}, \code{"truncate"},
#'   \code{"em"}, \code{"inar"}.
#' @param eps Error level of \code{"soe"} (relative, per intensity) and \code{"truncate"}
#'   (kernel tail mass).
#' @param start Optional starting values (baseline, eta, kernel).
#' @return A list: \code{theta}, \code{baseline_params}, \code{branching_ratio},
#'   \code{kernel_params}, \code{nll}, \code{aic}, \code{bic}, \code{n}, \code{horizon},
#'   \code{k_params}, \code{ks_stat}, \code{ks_pvalue} (time-rescaling residuals against the
#'   uniform), \code{method}, \code{eps}, \code{converged}.
#' @references Ozaki T (1979). Maximum likelihood estimation of Hawkes' self-exciting point
#'   processes. \emph{Ann. Inst. Statist. Math.} 31, 145--155. \doi{10.1007/BF02480272}
#'
#'   Beylkin G, Monzon L (2010). Approximation by exponential sums revisited.
#'   \emph{Appl. Comput. Harmon. Anal.} 28, 131--149. \doi{10.1016/j.acha.2009.08.011}
#'
#'   Veen A, Schoenberg FP (2008). Estimation of space-time branching process models in
#'   seismology using an EM-type algorithm. \emph{JASA} 103, 614--624.
#'   \doi{10.1198/016214508000000148}
#'
#'   Kirchner M (2017). An estimation procedure for the Hawkes process.
#'   \emph{Quant. Finance} 17, 571--595. \doi{10.1080/14697688.2016.1211312}
#' @examples
#' set.seed(1)
#' times <- sort(stats::runif(400, 0, 100))
#' fit <- core_hawkes_fit(times, 100, "exponential")
#' fit$branching_ratio
#' core_hawkes_fit(times, 100, "lomax", method = "soe", eps = 1e-8)$nll
#' core_hawkes_fit(times, 100, "exponential", baseline = "sinusoidal")$aic
#' @export
core_hawkes_fit <- function(times, horizon, kernel = c("exponential", "weibull", "gamma", "lomax"),
                            baseline = c("constant", "sinusoidal"), method = "auto", eps = 1e-9,
                            start = NULL) {
  kernel <- match.arg(kernel)
  baseline <- match.arg(baseline)
  method <- .rmbl_hk_method(method, kernel)
  chk <- .rmbl_hk_check_times(times, horizon)
  horizon <- chk$horizon
  times <- chk$times[chk$times >= 0 & chk$times <= horizon]
  n <- length(times)
  if (n < 50L) stop(sprintf("too few events (%d) for the fit", n), call. = FALSE)
  if (!is.numeric(eps) || length(eps) != 1L || !(eps > 0) || eps >= 1) {
    stop("`eps` must be a single number in (0, 1)", call. = FALSE)
  }
  nb <- if (baseline == "constant") 1L else 4L
  b <- .rmbl_hk_bounds(kernel, baseline)
  x0 <- if (is.null(start)) .rmbl_hk_x0(kernel, baseline, n, horizon, mean(diff(times))) else as.numeric(start)
  if (length(x0) != length(b$lower)) stop(sprintf("`start` must have length %d", length(b$lower)), call. = FALSE)
  x0 <- pmin(pmax(x0, b$lower), b$upper)
  exact_nll <- function(th) .rmbl_hk_call(times, horizon, kernel, baseline, th, "exact", 1e-12, FALSE)[[1]]
  converged <- TRUE
  if (method == "em") {
    theta <- .rmbl_hk_em(times, horizon, kernel, baseline, x0, b)
  } else if (method == "inar") {
    theta <- .rmbl_hk_inar(times, horizon, kernel, baseline, b)
  } else {
    run <- function(st) .rmbl_hk_pbfgs(times, horizon, kernel, baseline, method, eps, b, st)
    fit <- run(x0)
    if (kernel != "exponential" && is.null(start)) {
      # a second, deterministic start at the exponential fit (the shape-1 member of Weibull and
      # gamma), as morie's Python fit: the likelihood is multimodal
      fit2 <- run(.rmbl_hk_warm(times, horizon, kernel, baseline, b))
      if (fit2$value < fit$value) fit <- fit2
    }
    theta <- fit$par
    converged <- fit$iterations < 2000
  }
  nll <- exact_nll(theta)
  k <- length(theta)
  U <- core_hawkes_residuals(times, horizon, kernel, theta, baseline = baseline)
  # the exact distribution up to n = 10,000, as morie's Python (and scipy's "auto")
  ks <- suppressWarnings(stats::ks.test(U, "punif", exact = length(U) <= 10000L))
  list(theta = theta, baseline_params = theta[seq_len(nb)], branching_ratio = theta[[nb + 1L]],
       kernel_params = theta[-seq_len(nb + 1L)], nll = nll, aic = 2 * k + 2 * nll, bic = k * log(n) + 2 * nll,
       n = n, horizon = horizon, k_params = k, ks_stat = unname(ks$statistic), ks_pvalue = ks$p.value,
       kernel = kernel, baseline = baseline, method = method,
       eps = if (method %in% c("soe", "truncate")) eps else NA_real_, converged = converged)
}

# the whole fit in the shared C++ core (projected BFGS, morie_core.h hawkes_fit_pbfgs): the routine
# morie's Python fit calls, so both reach the same optimum from the same start
.rmbl_hk_pbfgs <- function(times, horizon, kernel, baseline, method, eps, b, start) {
  soe <- .rmbl_hk_soe(times, horizon, kernel)
  code <- c(exact = 0L, soe = 1L, truncate = 2L)[[method]]
  r <- .Call(C_rmbl_hawkes_fit_pbfgs, times, horizon, .rmbl_hk_bkind[[baseline]], .rmbl_hk_kind[[kernel]], code,
             eps, soe[[1]], soe[[2]], b$lower, b$upper, as.numeric(start), 2000L, 1e-6)
  d <- length(start)
  list(par = r[seq_len(d)], value = r[[d + 1L]], iterations = r[[d + 2L]])
}

.rmbl_hk_warm <- function(times, horizon, kernel, baseline, b) {
  nb <- if (baseline == "constant") 1L else 4L
  eb <- list(lower = c(b$lower[seq_len(nb + 1L)], 0.1), upper = c(b$upper[seq_len(nb + 1L)], 25))
  x0 <- .rmbl_hk_x0("exponential", baseline, length(times), horizon, mean(diff(times)))
  f <- .rmbl_hk_pbfgs(times, horizon, "exponential", baseline, "exact", 1e-9, eb, x0)$par
  beta <- f[[length(f)]]
  psi <- switch(kernel, weibull = c(1, 1 / beta), gamma = c(1, beta), lomax = c(30, 30 / beta))
  pmin(pmax(c(f[-length(f)], psi), b$lower), b$upper)
}

#' Time-rescaling residuals of a Hawkes process
#'
#' \eqn{U_i = 1 - \exp(-(\Lambda(t_i) - \Lambda(t_{i-1})))}, uniform on (0, 1) when the model
#' is right (Brown et al. 2002); computed in O(n) or O(n w) by the shared C++ core.
#'
#' @inheritParams core_hawkes_fit
#' @param par Parameters (baseline, eta, kernel), as \code{core_hawkes_fit()} returns them in
#'   \code{theta}.
#' @return A numeric vector of length \code{length(times)}.
#' @references Brown EN, Barbieri R, Ventura V, Kass RE, Frank LM (2002). The time-rescaling
#'   theorem and its application to neural spike train data analysis. \emph{Neural Comput.}
#'   14, 325--346. \doi{10.1162/08997660252741149}
#' @examples
#' set.seed(2)
#' times <- sort(stats::runif(200, 0, 50))
#' U <- core_hawkes_residuals(times, 50, "exponential", c(log(3), 0.2, 2))
#' stats::ks.test(U, "punif")$p.value
#' @export
core_hawkes_residuals <- function(times, horizon, kernel = c("exponential", "weibull", "gamma", "lomax"), par,
                                  baseline = c("constant", "sinusoidal")) {
  kernel <- match.arg(kernel)
  baseline <- match.arg(baseline)
  chk <- .rmbl_hk_check_times(times, horizon)
  nb <- if (baseline == "constant") 1L else 4L
  np <- if (kernel == "exponential") 1L else 2L
  par <- .rmbl_num(par, "par")
  if (length(par) != nb + 1L + np) stop(sprintf("`par` must have length %d", nb + 1L + np), call. = FALSE)
  .Call(C_rmbl_hawkes_rescaled, chk$times, chk$horizon, .rmbl_hk_bkind[[baseline]], par[seq_len(nb)],
        par[[nb + 1L]], .rmbl_hk_kind[[kernel]], par[-seq_len(nb + 1L)])
}

.rmbl_hk_feats <- function(x, horizon, baseline) {
  if (baseline == "constant") return(matrix(1, length(x), 1L))
  cbind(1, x / max(horizon, 1), sin(2 * pi * x / 365.25), cos(2 * pi * x / 365.25))
}

# EM (Veen & Schoenberg 2008), as morie's Python hawkes_em
.rmbl_hk_em <- function(times, horizon, kernel, baseline, x0, b, max_iter = 500L, tol = 1e-9) {
  kind <- .rmbl_hk_kind[[kernel]]
  bk <- .rmbl_hk_bkind[[baseline]]
  nb <- if (baseline == "constant") 1L else 4L
  theta <- x0
  Fx <- .rmbl_hk_feats(times, horizon, baseline)
  m <- max(64L, floor(horizon) + 1L)
  grid <- seq(0, horizon, length.out = m)
  Fg <- .rmbl_hk_feats(grid, horizon, baseline)
  wq <- c(0.5, rep(1, m - 2L), 0.5) * horizon / (m - 1L)
  nll_of <- function(th) .rmbl_hk_call(times, horizon, kernel, baseline, th, "exact", 1e-12, FALSE)[[1]]
  cur <- nll_of(theta)
  for (it in seq_len(max_iter)) {
    a <- theta[seq_len(nb)]
    eta <- theta[[nb + 1L]]
    psi <- theta[-seq_len(nb + 1L)]
    lam <- .Call(C_rmbl_hawkes_intensity, times, horizon, bk, a, eta, kind, psi)
    p0 <- exp(drop(Fx %*% a)) / lam
    if (baseline == "constant") {
      a_new <- min(max(log(max(sum(p0), 1e-300) / horizon), b$lower[[1]]), b$upper[[1]])
    } else {
      sp <- colSums(p0 * Fx)
      fb <- function(av) {
        v <- exp(drop(Fg %*% av)) * wq
        -(sum(sp * av) - sum(v))
      }
      gb <- function(av) {
        v <- exp(drop(Fg %*% av)) * wq
        -(sp - colSums(v * Fg))
      }
      a_new <- stats::optim(a, fb, gb, method = "L-BFGS-B", lower = b$lower[seq_len(nb)],
                            upper = b$upper[seq_len(nb)])$par
    }
    kidx <- -seq_len(nb + 1L)
    fk <- function(ps) {
      e <- .Call(C_rmbl_hawkes_em_pass, times, lam, eta, kind, psi, ps)
      s <- .Call(C_rmbl_hawkes_cdf_sum, times, horizon, kind, ps)
      if (!is.finite(e[[1]]) || s[[1]] <= 0) return(1e12)
      -(e[[1]] - e[[2]] * log(s[[1]]))
    }
    gk <- function(ps) {
      e <- .Call(C_rmbl_hawkes_em_pass, times, lam, eta, kind, psi, ps)
      s <- .Call(C_rmbl_hawkes_cdf_sum, times, horizon, kind, ps)
      if (!is.finite(e[[1]]) || s[[1]] <= 0) return(rep(0, length(ps)))
      -(e[-(1:2)] - e[[2]] * s[-1] / s[[1]])
    }
    psi_new <- stats::optim(psi, fk, gk, method = "L-BFGS-B", lower = b$lower[kidx], upper = b$upper[kidx])$par
    e <- .Call(C_rmbl_hawkes_em_pass, times, lam, eta, kind, psi, psi_new)
    s <- .Call(C_rmbl_hawkes_cdf_sum, times, horizon, kind, psi_new)
    eta_new <- min(max(e[[2]] / s[[1]], b$lower[[nb + 1L]]), b$upper[[nb + 1L]])
    theta <- c(a_new, eta_new, psi_new)
    new <- nll_of(theta)
    done <- abs(cur - new) <= tol * max(1, abs(cur))
    cur <- new
    if (done) break
  }
  theta
}

.rmbl_hk_cdf <- function(u, kernel, psi) {
  switch(kernel,
    exponential = stats::pexp(u, psi[[1]]),
    weibull = stats::pweibull(u, psi[[1]], psi[[2]]),
    gamma = stats::pgamma(u, psi[[1]], psi[[2]]),
    lomax = 1 - (psi[[2]] / (u + psi[[2]]))^psi[[1]]
  )
}

# Kirchner's INAR(p) estimator, as morie's Python hawkes_inar
.rmbl_hk_inar <- function(times, horizon, kernel, baseline, b) {
  if (baseline != "constant") {
    stop("method = \"inar\" assumes a stationary process: use baseline = \"constant\"", call. = FALSE)
  }
  n <- length(times)
  rate <- n / horizon
  # bins narrow against the clustering (a quarter of the median gap), at most 20,000, as Python
  gaps <- sort(diff(times))
  med <- if (length(gaps)) gaps[[length(gaps) %/% 2L + 1L]] else horizon / max(n, 1L)
  delta <- max(horizon / 20000, min(0.25 / rate, med / 4))
  support <- min(horizon / 10, 200 * delta)
  p <- max(2L, as.integer(ceiling(support / delta)))
  B <- as.integer(ceiling(horizon / delta))
  X <- tabulate(pmin(floor(times / delta), B - 1L) + 1L, nbins = B)
  xc <- X - mean(X)
  gam <- vapply(0:p, function(h) sum(xc[(h + 1L):B] * xc[1:(B - h)]) / B, numeric(1))
  # Levinson-Durbin on the Yule-Walker system
  a <- numeric(p)
  e <- gam[[1]]
  for (k in seq_len(p)) {
    acc <- gam[[k + 1L]] - if (k > 1L) sum(a[seq_len(k - 1L)] * gam[k:2]) else 0
    kap <- acc / e
    a_new <- a
    a_new[[k]] <- kap
    if (k > 1L) a_new[seq_len(k - 1L)] <- a[seq_len(k - 1L)] - kap * a[(k - 1L):1]
    a <- a_new
    e <- e * (1 - kap^2)
  }
  alpha0 <- mean(X) * (1 - sum(a))
  nu <- max(alpha0 / delta, 1e-12)
  edges <- delta * (0:p)
  fk <- function(par) {
    cdf <- tryCatch(.rmbl_hk_cdf(edges, kernel, par[-1]), error = function(e) NULL)
    if (is.null(cdf) || anyNA(cdf)) return(1e12)
    sum((a - par[[1]] * diff(cdf))^2)
  }
  mean_dt <- horizon / n
  psi0 <- switch(kernel, exponential = 1 / max(mean_dt, 1e-3), gamma = c(1.5, 1 / max(mean_dt, 1e-3)),
                 weibull = c(1.5, max(mean_dt, 1e-3) * 1.2), lomax = c(2.5, max(mean_dt, 1e-3) * 5))
  x0 <- pmin(pmax(c(sum(a), psi0), b$lower[-1]), b$upper[-1])
  par <- stats::optim(x0, fk, method = "Nelder-Mead")$par
  c(min(max(log(nu), b$lower[[1]]), b$upper[[1]]), pmin(pmax(par, b$lower[-1]), b$upper[-1]))
}

#' Reproducible uniforms shared with morie's Python arm (splitmix64)
#'
#' The splitmix64 generator (Steele, Lea & Flood 2014): \code{n} uniforms on
#' [0, 1) from a 64-bit \code{seed}, the same numbers morie's Python computes,
#' so the R and Python arms can draw identical "random" values where their
#' results must agree (the within-day jitter of tied event dates in the TPS
#' Hawkes fits, a subsample). Not a statistical replacement for R's own
#' generators.
#'
#' @param n Number of uniforms.
#' @param seed A non-negative whole number below 2^53.
#' @return A numeric vector of length \code{n}.
#' @references Steele GL, Lea D, Flood CH (2014). Fast splittable pseudorandom number
#'   generators. \emph{OOPSLA 2014}, 453--472. \doi{10.1145/2660193.2660195}
#' @examples
#' core_uniforms(3, 42)
#' identical(core_uniforms(5, 1), core_uniforms(5, 1))
#' @export
core_uniforms <- function(n, seed) {
  n <- .rmbl_num(n, "n")
  seed <- .rmbl_num(seed, "seed")
  if (length(n) != 1L || is.na(n) || n < 0 || n != floor(n)) {
    stop("`n` must be a non-negative whole number", call. = FALSE)
  }
  if (length(seed) != 1L || is.na(seed) || seed < 0 || seed != floor(seed) || seed >= 2^53) {
    stop("`seed` must be a whole number in [0, 2^53)", call. = FALSE)
  }
  .Call(C_rmbl_uniforms, n, seed)
}
