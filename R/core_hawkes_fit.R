# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Hawkes processes with a constant or sinusoidal baseline and four kernels,
# fitted by maximum likelihood with the analytic gradient of the shared C++
# core (morie_core.h: hawkes_nll_grad, hawkes_rescaled, hawkes_intensity,
# hawkes_em_pass, hawkes_cdf_sum) -- the same code morie's Python arm calls.

.rmbl_hk_kind <- c(exponential = 0L, weibull = 1L, gamma = 2L, lomax = 3L)
.rmbl_hk_bkind <- c(constant = 0L, sinusoidal = 1L)
.rmbl_hk_methods <- c("auto", "exact", "soe", "truncate", "em", "inar")

#' Resolves the fitting route for a kernel, turning \code{"auto"} into a concrete one.
#' @param method The route asked for: one of \code{"auto"}, \code{"exact"}, \code{"soe"},
#' \code{"truncate"}, \code{"em"}, \code{"inar"}.
#' @param kernel The kernel name.
#' @return The route name.
#' @noRd
.rmbl_hk_method <- function(method, kernel) {
  method <- .rmbl_arg(method, .rmbl_hk_methods)
  # Weibull's exact window is where the kernel underflows: for shape < 1 the whole record, so
  # "auto" truncates. Lomax and gamma use the sum of exponentials ("soe"; a gamma kernel with
  # shape >= 1 is truncated at eps). The gamma stall on that route (2,000 iterations to a worse
  # optimum on 2,118 tied events) ended when the projected BFGS began restarting its curvature
  # estimate at the bounds; it now reaches the exact route's maximum in 2.8 s.
  if (method == "auto") return(switch(kernel, exponential = "exact", weibull = "truncate", "soe"))
  if (method == "soe" && !kernel %in% c("lomax", "gamma")) {
    stop("method = \"soe\" applies to completely monotone kernels: \"lomax\", and \"gamma\" with shape < 1 ",
         "(a gamma kernel with shape >= 1 is truncated at eps); use \"exact\" or \"truncate\"", call. = FALSE)
  }
  method
}

#' Gives the sum-of-exponentials window for a kernel.
#'
#' The sum-of-exponentials window: r = (u + c)/R in \[delta, 1\] (Lomax, c <= 100 in the
#' fit), r = u/R from the smallest gap (gamma)
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @return A length-two vector: the scale and the lower end delta of the window.
#' @noRd
.rmbl_hk_soe <- function(times, horizon, kernel) {
  if (kernel == "lomax") return(c(horizon + 100, 1e-3 / (horizon + 100)))
  g <- diff(times)
  g <- g[g > 0]
  c(horizon, max(if (length(g)) min(g) else 1e-9, 1e-12) / horizon)
}

#' Evaluates the negative log-likelihood (and its gradient) in the shared C++ core.
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param theta The parameters: the baseline terms, the branching ratio and the kernel parameters.
#' @param method The route: \code{"exact"}, \code{"soe"} or \code{"truncate"}.
#' @param eps The tolerance of the \code{"soe"} and \code{"truncate"} routes.
#' @param gradient Whether the gradient is computed too.
#' @return The negative log-likelihood, followed by the gradient when asked for.
#' @noRd
.rmbl_hk_call <- function(times, horizon, kernel, baseline, theta, method, eps, gradient) {
  nb <- if (baseline == "constant") 1L else 4L
  soe <- .rmbl_hk_soe(times, horizon, kernel)
  code <- c(exact = 0L, soe = 1L, truncate = 2L)[[method]]
  .Call(C_rmbl_hawkes_nll_grad, times, horizon, .rmbl_hk_bkind[[baseline]], theta[seq_len(nb)], theta[[nb + 1L]],
        .rmbl_hk_kind[[kernel]], theta[-seq_len(nb + 1L)], code, eps, soe[[1]], soe[[2]], gradient)
}

#' Checks event times and the horizon of a Hawkes fit.
#' @param times The event times passed by the user.
#' @param horizon The horizon passed by the user (the `hor` argument).
#' @param baseline \code{"constant"} or \code{"sinusoidal"}; the sinusoidal one caps the
#' horizon.
#' @return A list with the checked `times` and `horizon`.
#' @noRd
.rmbl_hk_check_times <- function(times, horizon, baseline = "constant") {
  times <- .rmbl_num(times, "times")
  if (anyNA(times)) stop(.rmbl_fn(), "`times` must not contain NA", call. = FALSE)
  if (length(times) > 1L && any(diff(times) < 0)) stop(.rmbl_fn(), "`times` must be sorted in increasing order",
                                                       call. = FALSE)
  horizon <- .rmbl_num(horizon, "hor")
  if (length(horizon) != 1L || !is.finite(horizon) || horizon <= 0) {
    stop(.rmbl_fn(), "`hor` must be a single positive finite number", call. = FALSE)
  }
  if (baseline != "constant" && horizon > 4194304) {
    stop("a sinusoidal baseline is integrated day by day: `hor` must be at most 4194304 days", call. = FALSE)
  }
  if (length(times) > 0L && (min(times) < 0 || max(times) > horizon)) {
    stop(sprintf(paste0("`times` must lie within [0, hor] (they span %g to %g)",
                        if (max(times) > horizon) "; chwkjit(times, hor = ) keeps them inside" else ""),
                 min(times), max(times)), call. = FALSE)
  }
  list(times = times, horizon = horizon)
}

#' Gives the starting parameters for the optimiser.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param n The number of events.
#' @param horizon The end of the observation window.
#' @param mean_dt The mean gap between events.
#' @return The starting parameter vector.
#' @noRd
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

#' Gives the parameter box the optimiser stays inside.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @return A list with the `lower` and `upper` bounds.
#' @noRd
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
#' Fits a self-exciting (Hawkes) point process to a series of event times,
#' such as the times of shootings, break-ins or calls for service, and
#' returns the estimated background rate, the branching ratio (the share of
#' events triggered by earlier events) and the shape of the triggering
#' kernel, with AIC, BIC and a goodness-of-fit test. Use it to ask whether
#' events cluster in time beyond what a steady or seasonal rate explains.
#'
#' @details
#' The model is the univariate Hawkes process
#' \deqn{\lambda(t) = \nu(t) + \eta \sum_{t_j < t} g(t - t_j)}
#' with a constant baseline (\eqn{\nu = e^{a_0}}) or a sinusoidal one
#' (\eqn{\nu(t) = \exp(a_0 + a_1 t/T + a_2 \sin(2\pi t/365.25) + a_3 \cos(2\pi t/365.25))},
#' a trend plus a yearly cycle when times are in days, its integral by the
#' trapezoid rule on \code{max(64, floor(T) + 1)} points), branching ratio
#' \eqn{\eta \in [0.001, 0.99]} and one of four normalised kernels \eqn{g}:
#' exponential (decay \code{beta}), Weibull (shape \code{alpha}, scale
#' \code{lambda}), gamma (shape \code{alpha}, rate \code{beta}) or Lomax
#' (shape \code{alpha}, scale \code{c}). The log-likelihood is
#' \eqn{\sum_i \log \lambda(t_i) - \int_0^T \lambda(t)\,dt}. Every route uses
#' the analytic gradient of the shared C++ core (the code morie's Python arm
#' calls), so one likelihood evaluation per point instead of one per
#' parameter. The optimiser is a projected BFGS inside a fixed parameter box
#' (\eqn{a_0 \in [-15, 15]}, the other baseline terms in \eqn{[-5, 5]},
#' kernel parameters bounded as listed in the source), at most 2000
#' iterations.
#'
#' \describe{
#'   \item{\code{"exact"}}{Ozaki's O(n) recursion for the exponential kernel; for Weibull
#'     and
#'     gamma the double sum stops where the kernel underflows to exactly 0 (the same
#'     value as
#'     the full sum); Lomax the full O(n^2) sum.}
#'   \item{\code{"soe"}}{the completely monotone kernels (Lomax; gamma with shape < 1) as
#'     a
#'     sum of exponentials (Beylkin & Monzon 2010): relative error \code{eps} on every
#'     intensity, O(n K); a gamma kernel with shape >= 1 is truncated at \code{eps}.}
#'   \item{\code{"truncate"}}{each event excites only lags with kernel tail mass above
#'     \code{eps}: an approximation for light-tailed kernels, O(n w).}
#'   \item{\code{"em"}}{the EM algorithm (Veen & Schoenberg 2008), finished by the
#'     projected BFGS on the exact likelihood from EM's point (EM's steps shrink before
#'     it
#'     reaches the maximum). It is an R loop of up to 500 iterations and much slower than
#'     the
#'     other routes (tens of seconds for a few hundred events); because it starts from
#'     the
#'     same point but moves differently, it can end at a different local maximum.}
#'   \item{\code{"inar"}}{Kirchner's (2017) INAR(p) least-squares estimator on binned
#'     counts
#'     (constant baseline only): a different, fast, approximate estimator.}
#'   \item{\code{"auto"}}{\code{"exact"} for the exponential kernel, \code{"truncate"}
#'     for
#'     Weibull, \code{"soe"} for gamma and Lomax.}
#' }
#' For the Weibull, gamma and Lomax kernels without \code{start}, a second
#' deterministic start at the exponential fit (the shape-1 member) is also
#' run and the better optimum kept, because the likelihood is multimodal.
#' The exponential kernel without \code{start} is also run from a second
#' start (branching ratio 0.1 and a decay a quarter of the reciprocal mean
#' gap), and the better optimum kept: on data with little clustering its
#' likelihood can have more than one maximum, one of them with the decay on
#' its bound. A parameter on its bound (see \code{atbound}) is still a
#' reason to refit from another \code{start} and compare \code{nll}.
#'
#' The reported \code{nll} is the exact likelihood at the estimate whatever
#' the route, so AIC is comparable across routes. An event exactly at
#' \code{hor} is part of the record and counted, as in morie's Python
#' fit. The Kolmogorov-Smirnov test compares the time-rescaling residuals of
#' [chwkres()] with the uniform
#' distribution (exact p-value up
#' to 10,000 events without ties, asymptotic otherwise).
#'
#' Events at the same instant do not excite each other: the intensity sums
#' over strictly earlier events, as the definition of a Hawkes process (a
#' simple point process, with no two events at one time) has it. Tied times
#' are fitted that way, with a warning: data recorded to a resolution, such
#' as daily dates, carry ties the process itself never makes, and treating
#' them as exact biases the fit (Filimonov & Sornette 2015), so spread them
#' uniformly across their interval first with
#' [chwkjit()].
#'
#' Errors: \code{times} with \code{NA}, unsorted, or outside
#' \code{[0, horizon]}; \code{hor} not one positive finite number; fewer
#' than 50 events; an event rate \code{n / horizon} outside
#' \eqn{[e^{-15}, 100 e^{15}]} per unit time (rescale the times);
#' \code{eps} not in (0, 1); \code{start} of the wrong length or with a
#' non-finite likelihood; \code{method = "soe"} with a kernel other than
#' Lomax or gamma; \code{method = "inar"} with the sinusoidal baseline.
#' Long fits show a progress spinner (EM a bar) on stderr unless
#' \code{options(morie.quiet = TRUE)}.
#'
#' @param times Numeric vector of event times, sorted increasingly, all in
#'   \code{[0, horizon]}, in any time unit (days are the natural unit for the
#'   sinusoidal baseline's yearly cycle). At least 50 events.
#' @param hor End of the observation window, one positive number in the
#'   same unit as \code{times}; the window is \code{[0, horizon]}. With the
#'   sinusoidal baseline (an annual cycle, \code{times} in days) at most
#'   4194304 days: that baseline is integrated a day at a time.
#' @param kernel The triggering kernel: \code{"exponential"} (the default),
#'   \code{"weibull"}, \code{"gamma"} or \code{"lomax"}.
#' @param base \code{"constant"} (the default) or \code{"sinusoidal"}
#'   (trend plus a 365.25-unit cycle).
#' @param meth One of \code{"auto"} (the default), \code{"exact"}, \code{"soe"},
#'   \code{"truncate"}, \code{"em"}, \code{"inar"}. \code{"auto"} is
#'   \code{"exact"} for the exponential kernel, \code{"truncate"} for Weibull
#'   and \code{"soe"} for Lomax and gamma.
#' @param eps Error level, one number in (0, 1), default \code{1e-9}: the
#'   relative error per intensity of \code{"soe"} and the kernel tail mass
#'   dropped by \code{"truncate"}. Ignored by the other routes.
#' @param start Optional numeric vector of starting values in the order of
#'   \code{theta}: the baseline terms (\code{a0}, or \code{a0..a3}), then
#'   \code{eta}, then the kernel parameters. Values outside the parameter box
#'   are moved onto it. \code{NULL} (the default) uses a start from the data.
#' @return A list:
#'   \describe{
#'     \item{\code{theta}}{numeric, all estimates in the order baseline, \code{eta},
#'       kernel.}
#'     \item{\code{basepar}}{numeric, \code{a0} (constant) or \code{a0..a3}
#'       (sinusoidal), on the log scale.}
#'     \item{\code{braratio}}{numeric, \eqn{\eta}, the expected number of events
#'       each
#'       event triggers.}
#'     \item{\code{kerpar}}{numeric, the kernel parameters (\code{beta};
#'       \code{alpha, lambda}; \code{alpha, beta}; or \code{alpha, c}).}
#'     \item{\code{nll}, \code{aic}, \code{bic}}{numeric: the exact negative
#'       log-likelihood,
#'       \eqn{2k + 2\,nll} and \eqn{k \log n + 2\,nll}.}
#'     \item{\code{n}, \code{horizon}, \code{kpar}}{the number of events (integer),
#'       the
#'       window end and the number of parameters (integer).}
#'     \item{\code{ksstat}, \code{kspva}}{numeric, the Kolmogorov-Smirnov test of
#'       the
#'       time-rescaling residuals against the uniform.}
#'     \item{\code{kernel}, \code{baseline}, \code{method}}{character, the choices used
#'       (\code{method} after \code{"auto"} is resolved).}
#'     \item{\code{eps}}{numeric, \code{eps} for \code{"soe"} and \code{"truncate"},
#'       \code{NA} otherwise.}
#'     \item{\code{converged}}{logical, the optimiser stopped at a maximum within the
#'       parameter box (before its iteration limit, at a finite likelihood). A maximum
#'       on the box counts: \code{atbound} names the parameters that lie on it.}
#'     \item{\code{atbound}}{character, the names of parameters that lie on the box
#'       (\code{character(0)} for an interior maximum).}
#'   }
#'   A warning is given when \eqn{\eta} reaches its upper bound 0.99 (a near-critical,
#'   probably non-stationary fit).
#'   An estimate on the box is not an interior maximum of the likelihood:
#'   day-dated (tied) times drive a shape or decay to its wall, and a Lomax
#'   fitted to exponential data runs to its exponential limit.
#'
#' @references Ozaki T (1979). Maximum likelihood estimation of Hawkes' self-exciting
#'   point
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
#'
#'   Filimonov V, Sornette D (2015). Apparent criticality and calibration issues in the
#'   Hawkes self-excited point process model: application to high-frequency financial
#'   data.
#'   \emph{Quant. Finance} 15(8), 1293--1314. \doi{10.1080/14697688.2015.1032544}
#' @seealso [chwkjit()], for times recorded
#'   to a
#'   resolution; [chwkres()] for the
#'   residuals.
#' @examples
#' set.seed(1)
#' times <- sort(stats::runif(400, 0, 100))
#' fit <- chwkfit(times, 100, "exponential")
#' fit$braratio
#' fit$atbound # an interior maximum: the better of two starts
#' # one start alone can stop with the decay on its bound, at a worse nll
#' chwkfit(times, 100, "exponential", start = c(log(2.4), 0.4, 4))$atbound
#' fit$nll
#' chwkfit(times, 100, "lomax", meth = "soe", eps = 1e-8)$nll
#' chwkfit(times, 100, "exponential", base = "sinusoidal")$aic
#'
#' # the fast approximate INAR estimator
#' chwkfit(times, 100, meth = "inar")$braratio
#'
#' # daily dates: spread the ties across each day first
#' days <- floor(times)
#' jit <- chwkjit(days, hor = 100)
#' chwkfit(jit, 100)$converged
#'
#' # too few events, or times past the horizon, are refused
#' try(chwkfit(times[1:20], 100))
#' try(chwkfit(times, 50))
#' @export
#' @srrstats {TS2.1a} NA event times are an error ("must not contain NA"), tested in test-round8.R:237; stkflow and
#'   perdays also refuse NA.
#' @srrstats {TS2.2} The constant baseline with eta bounded at 0.99 is the stationary Hawkes; base = "sinusoidal"
#'   lets the mean intensity trend and cycle.
#' @srrstats {TS2.4} Stationarity is enforced by the eta bound; meth = "inar" refuses the non-stationary baseline
#'   (test-hawkes-fit.R:102); the sinusoidal baseline models the trend.
#' @srrstats {TS2.4b} base = "sinusoidal" models the trend and yearly cycle, so the triggering part stays
#'   stationary; the docs point day-dated ties to chwkjit().
#' @srrstats {TS2.4a} A fit with eta on its 0.99 upper bound (near-critical) warns, naming base = "sinusoidal";
#'   test-srr.R.
chwkfit <- function(times, hor, kernel = c("exponential", "weibull", "gamma", "lomax"),
                            base = c("constant", "sinusoidal"), meth = "auto", eps = 1e-9,
                            start = NULL) {
  kernel <- .rmbl_arg(kernel)
  base <- .rmbl_arg(base)
  meth <- .rmbl_hk_method(meth, kernel)
  chk <- .rmbl_hk_check_times(times, hor, base)
  hor <- chk$horizon
  times <- chk$times[chk$times >= 0 & chk$times <= hor]
  n <- length(times)
  if (n < 50L) stop(sprintf("too few events (%d) for the fit", n), call. = FALSE)
  # the baseline is bounded (a0 in [-15, 15], eta <= 0.99), so the event rate it can reach is
  # [e^-15, 100 e^15] per unit time; outside that the optimiser can only return its start
  rate <- n / hor
  if (!(rate >= exp(-15)) || !(rate <= 100 * exp(15))) {
    stop(sprintf(paste0("the event rate n / horizon = %g is outside what the fit can represent ",
                        "(%g to %g per unit time): express the times in another unit"),
                 rate, exp(-15), 100 * exp(15)), call. = FALSE)
  }
  ties <- sum(diff(times) == 0)
  if (ties) {
    warning(sprintf(paste0("%d event(s) share their time with an earlier one: they do not excite each ",
                           "other (the intensity sums over strictly earlier events). Times rounded to a ",
                           "resolution (daily dates) should first be spread across it: chwkjit()"),
                    ties), call. = FALSE)
  }
  if (!is.numeric(eps) || length(eps) != 1L || is.na(eps) || !(eps > 0) || eps >= 1) {
    stop("`eps` must be a single number in (0, 1)", call. = FALSE)
  }
  nb <- if (base == "constant") 1L else 4L
  b <- .rmbl_hk_bounds(kernel, base)
  x0 <- if (is.null(start)) .rmbl_hk_x0(kernel, base, n, hor, mean(diff(times))) else .rmbl_num(start, "start")
  if (length(x0) != length(b$lower)) stop(sprintf("`start` must have length %d", length(b$lower)), call. = FALSE)
  x0 <- pmin(pmax(x0, b$lower), b$upper)
  exact_nll <- function(th) .rmbl_hk_call(times, hor, kernel, base, th, "exact", 1e-12, FALSE)[[1]]
  converged <- TRUE
  # EM is an R loop: a bar with its iterations; the other routes are long native calls: a spinner
  # with the stage
  stage <- function(what, expr) {
    .bl_busy(sprintf("Hawkes fit (%s, %s events): %s", kernel, format(n, big.mark = ","), what), expr)
  }
  if (meth == "em") {
    pg <- blprog(sprintf("Hawkes fit (%s)", kernel), 0)
    on.exit(pg$done(), add = TRUE)
    pg$update(info = sprintf("fitting %s events", format(n, big.mark = ",")))
    em <- .rmbl_hk_em(times, hor, kernel, base, x0, b, pg = pg)
    # EM converges linearly: its steps shrink long before it reaches the maximum, so a small step
    # is not a stop (it ended 1.4e-5 short on macOS x86_64). Finish with the projected BFGS on the
    # exact likelihood from EM's point; it only moves uphill.
    pg$update(info = "polishing the EM point")
    pol <- .rmbl_hk_pbfgs(times, hor, kernel, base, "exact", 1e-12, b, em$theta)
    theta <- if (pol$value <= exact_nll(em$theta)) pol$par else em$theta
    converged <- pol$iterations < 2000
  } else if (meth == "inar") {
    theta <- stage("INAR approximation", .rmbl_hk_inar(times, hor, kernel, base, b))
  } else {
    run <- function(st) .rmbl_hk_pbfgs(times, hor, kernel, base, meth, eps, b, st)
    fit <- stage("first start", run(x0))
    if (!is.null(start) && fit$value >= 1e11) {
      # the optimizer cannot move from a point where the likelihood is not finite (it returned
      # the start itself, reported as converged)
      stop("the likelihood is not finite at `start` (no intensity, or an overflowing baseline): ",
           "give a start inside the model", call. = FALSE)
    }
    if (kernel == "exponential" && is.null(start)) {
      # a second start with little excitation and a slow decay: on weakly clustered data the
      # likelihood has a second maximum with the decay on its bound, and the data-driven start
      # can stop there (nll -155.02 against -156.46 for runif(400) with seed 1)
      x1 <- .rmbl_hk_x0(kernel, base, n, hor, mean(diff(times)))
      x1[[1L]] <- log(max(n / hor, 1e-3) * 0.9)
      x1[[nb + 1L]] <- 0.1
      x1[[length(x1)]] <- x1[[length(x1)]] / 4
      fit2 <- stage("second start", run(pmin(pmax(x1, b$lower), b$upper)))
      if (fit2$value < fit$value) fit <- fit2
    }
    if (kernel != "exponential" && is.null(start)) {
      # a second, deterministic start at the exponential fit (the shape-1 member of Weibull and
      # gamma), as morie's Python fit: the likelihood is multimodal
      fit2 <- stage("second start, from the exponential fit",
                    run(.rmbl_hk_warm(times, hor, kernel, base, b)))
      if (fit2$value < fit$value) fit <- fit2
    }
    theta <- fit$par
    converged <- fit$iterations < 2000 && fit$value < 1e11
  }
  nll <- exact_nll(theta)
  k <- length(theta)
  pnames <- c(if (base == "constant") "a0" else paste0("a", 0:3), "eta",
              switch(kernel, exponential = "beta", weibull = c("alpha", "lambda"), gamma = c("alpha", "beta"),
                     lomax = c("alpha", "c")))
  on_box <- abs(theta - b$lower) <= 1e-6 * pmax(1, abs(b$lower)) |
    abs(theta - b$upper) <= 1e-6 * pmax(1, abs(b$upper))
  # reported, not warned: a Lomax fitted to exponential-like data reaching its exponential limit is
  # an ordinary result; a shape at its wall on day-dated times is the case to look at
  at_bound <- pnames[on_box]
  if (abs(theta[[nb + 1L]] - b$upper[[nb + 1L]]) <= 1e-6) {
    warning(sprintf(paste0("the branching ratio eta sits on its upper bound %g: the process is near critical ",
                           "and the fit is not an interior maximum (often an unmodelled trend; try ",
                           "base = \"sinusoidal\")"), b$upper[[nb + 1L]]), call. = FALSE)
  }
  U <- chwkres(times, hor, kernel, theta, base = base)
  # the exact distribution up to n = 10,000, as morie's Python (and scipy's "auto"); with
  # tied residuals (tied event times) the exact computation is extremely slow and memory-hungry
  # and its distribution does not hold, so the asymptotic one
  ks <- suppressWarnings(stats::ks.test(U, "punif", exact = length(U) <= 10000L && !anyDuplicated(U)))
  list(theta = theta, basepar = theta[seq_len(nb)], braratio = theta[[nb + 1L]],
       kerpar = theta[-seq_len(nb + 1L)], nll = nll, aic = 2 * k + 2 * nll, bic = k * log(n) + 2 * nll,
       n = n, horizon = hor, kpar = k, ksstat = unname(ks$statistic), kspva = ks$p.value,
       kernel = kernel, baseline = base, method = meth,
       eps = if (meth %in% c("soe", "truncate")) eps else NA_real_, converged = converged,
       atbound = at_bound)
}

#' Runs the whole projected BFGS fit in the shared C++ core.
#'
#' The whole fit in the shared C++ core (projected BFGS, morie_core.h hawkes_fit_pbfgs): the routine
#' morie's Python fit calls, so both reach the same optimum from the same start
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param method The route: \code{"exact"}, \code{"soe"} or \code{"truncate"}.
#' @param eps The tolerance of the \code{"soe"} and \code{"truncate"} routes.
#' @param b The parameter box, from .rmbl_hk_bounds().
#' @param start The starting parameters.
#' @return A list with the parameters `par`, the minimum `value` and the number of `iterations`.
#' @noRd
.rmbl_hk_pbfgs <- function(times, horizon, kernel, baseline, method, eps, b, start) {
  soe <- .rmbl_hk_soe(times, horizon, kernel)
  code <- c(exact = 0L, soe = 1L, truncate = 2L)[[method]]
  r <- .Call(C_rmbl_hawkes_fit_pbfgs, times, horizon, .rmbl_hk_bkind[[baseline]], .rmbl_hk_kind[[kernel]], code,
             eps, soe[[1]], soe[[2]], b$lower, b$upper, as.numeric(start), 2000L, 1e-6)
  d <- length(start)
  list(par = r[seq_len(d)], value = r[[d + 1L]], iterations = r[[d + 2L]])
}

#' Starts a kernel's fit from the fitted exponential model.
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param b The parameter box, from .rmbl_hk_bounds().
#' @return Starting parameters for `kernel`, inside the box.
#' @noRd
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
#' Transforms the event times into residuals that are independent and
#' uniform on (0, 1) when the fitted Hawkes model is right, by the
#' time-rescaling theorem. Plot them, or test them against the uniform with
#' \code{stats::ks.test()}, to check the fit of
#' [chwkfit()];
#' departures show where the model misses clustering or a trend.
#'
#' @details
#' With the compensator \eqn{\Lambda(t) = \int_0^t \lambda(s)\,ds}, the
#' residual of event \eqn{i} is
#' \deqn{U_i = 1 - \exp(-(\Lambda(t_i) - \Lambda(t_{i-1})))}
#' with \eqn{t_0 = 0} (Brown et al. 2002). The rescaled gaps
#' \eqn{\Lambda(t_i) - \Lambda(t_{i-1})} are unit-rate exponential under the
#' model, so the \eqn{U_i} are uniform. The model and kernels are those of
#' [chwkfit()]; the shared C++ core computes the
#' residuals in O(n)
#' for the exponential kernel and O(n w) for the others. Tied times give
#' tied residuals.
#'
#' Errors: \code{times} with \code{NA}, unsorted or outside
#' \code{[0, horizon]}; \code{par} of the wrong length (2 + kernel
#' parameters for the constant baseline, 5 + kernel parameters for the
#' sinusoidal one).
#'
#' @inheritParams chwkfit
#' @param par Numeric vector of parameters, as \code{chwkfit()} returns them in
#'   \code{theta}: the baseline terms, \code{eta} and the kernel parameters.
#'   Its length is 3 for the exponential kernel with a constant
#'   baseline, one more for a two-parameter kernel, three more for the
#'   sinusoidal baseline.
#' @return A numeric vector of length \code{length(times)}, values in
#'   (0, 1).
#' @references Brown EN, Barbieri R, Ventura V, Kass RE, Frank LM (2002). The
#'   time-rescaling
#'   theorem and its application to neural spike train data analysis.
#'   \emph{Neural Comput.}
#'   14, 325--346. \doi{10.1162/08997660252741149}
#' @examples
#' set.seed(2)
#' times <- sort(stats::runif(200, 0, 50))
#' U <- chwkres(times, 50, "exponential", c(log(3), 0.2, 2))
#' stats::ks.test(U, "punif")$p.value
#'
#' # residuals of a fitted model, and a quick uniform Q-Q check
#' fit <- chwkfit(times, 50, "weibull")
#' U2 <- chwkres(times, 50, "weibull", fit$theta)
#' summary(U2)
#' plot(stats::ppoints(length(U2)), sort(U2), xlab = "uniform quantile", ylab = "residual")
#' abline(0, 1)
#'
#' # par must match the kernel and baseline
#' try(chwkres(times, 50, "weibull", c(log(3), 0.2, 2)))
#' @export
chwkres <- function(times, hor, kernel = c("exponential", "weibull", "gamma", "lomax"), par,
                                  base = c("constant", "sinusoidal")) {
  kernel <- .rmbl_arg(kernel)
  base <- .rmbl_arg(base)
  chk <- .rmbl_hk_check_times(times, hor, base)
  nb <- if (base == "constant") 1L else 4L
  np <- if (kernel == "exponential") 1L else 2L
  par <- .rmbl_num(par, "par")
  if (length(par) != nb + 1L + np) stop(sprintf("`par` must have length %d", nb + 1L + np), call. = FALSE)
  .Call(C_rmbl_hawkes_rescaled, chk$times, chk$horizon, .rmbl_hk_bkind[[base]], par[seq_len(nb)],
        par[[nb + 1L]], .rmbl_hk_kind[[kernel]], par[-seq_len(nb + 1L)])
}

#' Builds the baseline design matrix at a set of times.
#' @param x The times.
#' @param horizon The end of the observation window.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @return A matrix with one column for the constant baseline, four for the sinusoidal one.
#' @noRd
.rmbl_hk_feats <- function(x, horizon, baseline) {
  if (baseline == "constant") return(matrix(1, length(x), 1L))
  cbind(1, x / max(horizon, 1), sin(2 * pi * x / 365.25), cos(2 * pi * x / 365.25))
}

#' EM (Veen & Schoenberg 2008), as morie's Python hawkes_em
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @param baseline \code{"constant"} or \code{"sinusoidal"}.
#' @param x0 The starting parameters.
#' @param b The parameter box, from .rmbl_hk_bounds().
#' @param max_iter The largest number of EM iterations.
#' @param tol The relative change in the negative log-likelihood that ends the iterations.
#' @param pg A progress bar to update, or NULL.
#' @return A list with the parameters `theta` and whether the iterations `converged`.
#' @noRd
.rmbl_hk_em <- function(times, horizon, kernel, baseline, x0, b, max_iter = 500L, tol = 1e-9, pg = NULL) {
  kind <- .rmbl_hk_kind[[kernel]]
  bk <- .rmbl_hk_bkind[[baseline]]
  nb <- if (baseline == "constant") 1L else 4L
  theta <- x0
  Fx <- .rmbl_hk_feats(times, horizon, baseline)
  # a constant baseline is exact on any grid (a point a time unit was 2^31 of them for a horizon of
  # 2^31; CRAN stress test of 0.5.14); the sinusoidal one keeps a point a day
  m <- if (baseline == "constant") 64L else max(64L, floor(horizon) + 1L)
  grid <- seq(0, horizon, length.out = m)
  Fg <- .rmbl_hk_feats(grid, horizon, baseline)
  wq <- c(0.5, rep(1, m - 2L), 0.5) * horizon / (m - 1L)
  nll_of <- function(th) .rmbl_hk_call(times, horizon, kernel, baseline, th, "exact", 1e-12, FALSE)[[1]]
  cur <- nll_of(theta)
  for (it in seq_len(max_iter)) {
    if (!is.null(pg)) pg$update(info = sprintf("EM iteration %d", it))
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
    # no event can have been triggered when every event sits at the horizon (the kernel's
    # CDF sums to zero): the branching ratio goes to its lower bound rather than 0/0
    eta_new <- if (s[[1]] > 0) e[[2]] / s[[1]] else b$lower[[nb + 1L]]
    eta_new <- min(max(eta_new, b$lower[[nb + 1L]]), b$upper[[nb + 1L]])
    theta <- c(a_new, eta_new, psi_new)
    new <- nll_of(theta)
    done <- abs(cur - new) <= tol * max(1, abs(cur))
    cur <- new
    if (done) break
  }
  list(theta = theta, converged = done)
}

#' Evaluates a kernel's cumulative distribution function.
#' @param u The lags.
#' @param kernel The kernel name.
#' @param psi The kernel parameters.
#' @return The CDF at `u`.
#' @noRd
.rmbl_hk_cdf <- function(u, kernel, psi) {
  switch(kernel,
    exponential = stats::pexp(u, psi[[1]]),
    weibull = stats::pweibull(u, psi[[1]], psi[[2]]),
    gamma = stats::pgamma(u, psi[[1]], psi[[2]]),
    lomax = 1 - (psi[[2]] / (u + psi[[2]]))^psi[[1]]
  )
}

#' Kirchner's INAR(p) estimator, as morie's Python hawkes_inar
#' @param times The sorted event times.
#' @param horizon The end of the observation window.
#' @param kernel The kernel name.
#' @param baseline Must be \code{"constant"}.
#' @param b The parameter box, from .rmbl_hk_bounds().
#' @return The parameter vector: the log baseline, the branching ratio and the kernel parameters.
#' @noRd
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
    # Nelder-Mead is unbounded: a point outside the parameter box scores as invalid before any
    # CDF is evaluated (a negative shape made pweibull / pgamma warn "NaNs produced"), as Python
    if (any(par < b$lower[-1] | par > b$upper[-1])) return(1e12)
    cdf <- tryCatch(.rmbl_hk_cdf(edges, kernel, par[-1]), error = function(e) NULL)
    if (is.null(cdf) || any(!is.finite(cdf))) return(1e12)
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
#' Returns \code{n} pseudo-random numbers on [0, 1) from a 64-bit seed with
#' the splitmix64 generator, the same numbers morie's Python computes for
#' the same seed. Use it where the R and Python arms must draw identical
#' \code{"random"} values so that their results agree: the within-day jitter of
#' tied event dates in the TPS Hawkes fits, or a subsample.
#'
#' @details
#' splitmix64 (Steele, Lea & Flood 2014) advances a 64-bit state by the
#' constant \code{0x9E3779B97F4A7C15} and mixes it with two
#' multiply-xorshift rounds; the top 53 bits of each output divided by
#' \eqn{2^{53}} give a double in [0, 1). The stream depends only on
#' \code{seed}: R's own generator and \code{set.seed()} are neither used nor
#' changed. It is not a statistical replacement for R's generators.
#'
#' Errors: \code{n} not one non-negative whole number; \code{seed} not one
#' whole number in \eqn{[0, 2^{53})}.
#'
#' @param n Number of uniforms, one non-negative whole number (0 gives
#'   \code{numeric(0)}).
#' @param seed The seed, one whole number in \eqn{[0, 2^{53})} (so that it is
#'   exact as an R double).
#' @return A numeric vector of length \code{n}, values in [0, 1).
#' @references Steele GL, Lea D, Flood CH (2014). Fast splittable pseudorandom number
#'   generators. \emph{OOPSLA 2014}, 453--472. \doi{10.1145/2660193.2660195}
#' @examples
#' cunif(3, 42)
#' identical(cunif(5, 1), cunif(5, 1))
#'
#' # a stream is a prefix of a longer one with the same seed
#' all.equal(cunif(3, 7), cunif(10, 7)[1:3])
#'
#' # R's own generator is left alone
#' set.seed(1); a <- runif(1)
#' set.seed(1); invisible(cunif(100, 9)); b <- runif(1)
#' identical(a, b)
#'
#' # negative counts and seeds past 2^53 are refused
#' try(cunif(-1, 1))
#' try(cunif(2, 2^53))
#' @export
cunif <- function(n, seed) {
  n <- .rmbl_num(n, "n")
  if (length(n) != 1L || is.na(n) || !is.finite(n) || n < 0 || n != floor(n)) {
    stop("`n` must be a non-negative whole number", call. = FALSE)
  }
  if (n > .Machine$integer.max) stop("`n` must be at most 2147483647", call. = FALSE)
  seed <- .rmbl_seed(seed)
  .Call(C_rmbl_uniforms, n, seed)
}

#' Spread event times recorded to a resolution across their interval
#'
#' Daily (or hourly, or second) timestamps put every event of an interval at
#' one time, but a Hawkes process never has two events at one instant, and
#' fitting the rounded times as exact biases the estimates (Filimonov &
#' Sornette 2015). This function spreads each recorded time uniformly over
#' the interval it stands for, so the times can be passed to
#' [chwkfit()].
#'
#' @details
#' Each time becomes \code{t + w * U}, with
#' \code{w = min(resolution, horizon - t)} and \code{U} uniform on [0, 1),
#' and the result is sorted; this is the remedy Filimonov and Sornette use.
#' The times are sorted (radix order) before the uniforms are assigned, so
#' the result does not depend on the input order. The uniforms are the
#' splitmix64 stream of [cunif()], so the result is
#' reproducible
#' and, on daily dates with \code{seed = 42}, the same as the jitter rmorie
#' and morie (Python) apply before their TPS Hawkes fits. R's random number
#' generator is not used.
#'
#' Errors: \code{times} with \code{NA} or non-finite values; \code{res}
#' not one positive finite number; \code{hor} not one number; a time
#' past \code{hor}.
#'
#' @param times Numeric event times, each the start of its resolution
#'   interval (for example whole days since an origin).
#' @param res The width of the interval a recorded time stands for,
#'   one positive number in the unit of \code{times}: 1 (the default) for
#'   daily dates in days, \code{1/24} for hourly times in days.
#' @param seed Seed of the uniforms, as in
#'   [cunif()]; default 42.
#' @param hor End of the observation window, when it cuts an interval short: an
#'   event
#'   recorded at \code{t} is spread over \code{[t, min(t + resolution, horizon)]},
#'   so a
#'   time dated on the horizon itself stays there (\code{Inf}, the default: no window).
#' @return A numeric vector of the jittered times, the same length as
#'   \code{times}, sorted increasingly.
#' @references Filimonov V, Sornette D (2015). Apparent criticality and
#'   calibration issues in the Hawkes self-excited point process model:
#'   application to high-frequency financial data. \emph{Quant. Finance}
#'   15(8), 1293--1314. \doi{10.1080/14697688.2015.1032544}
#' @seealso [chwkfit()],
#'   [cunif()]
#' @examples
#' days <- c(0, 0, 0, 1, 3, 3)
#' chwkjit(days)
#' anyDuplicated(chwkjit(days))
#'
#' # a horizon keeps the last day inside the window
#' chwkjit(c(0, 1, 2), hor = 2)
#'
#' # hourly resolution, in days, and another seed
#' chwkjit(c(0, 0, 0), res = 1 / 24, seed = 7)
#'
#' # times past the horizon are refused
#' try(chwkjit(c(0, 5), hor = 3))
#' @export
chwkjit <- function(times, res = 1, seed = 42, hor = Inf) {
  times <- .rmbl_num(times, "times")
  if (anyNA(times) || any(!is.finite(times))) stop("`times` must be finite numbers", call. = FALSE)
  res <- .rmbl_num(res, "res")
  if (length(res) != 1L || !is.finite(res) || res <= 0) {
    stop("`res` must be a single positive finite number", call. = FALSE)
  }
  hor <- .rmbl_num(hor, "hor")
  if (length(hor) != 1L || is.na(hor)) stop("`hor` must be a single number", call. = FALSE)
  if (any(times > hor)) stop("`times` must not exceed `hor`", call. = FALSE)
  times <- times[order(times, method = "radix")]
  width <- pmin(res, hor - times)
  sort(times + width * cunif(length(times), seed))
}
