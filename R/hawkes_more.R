# SPDX-License-Identifier: AGPL-3.0-or-later A fitted Hawkes process put to use:
# its conditional intensity, its time-rescaling check, the most likely branching
# structure of the events, and new event times simulated from it.

#' Simulate event times from a fitted Hawkes process
#'
#' Draws a new event history from a [chwkfit()] result by its cluster
#' representation: immigrant events from the baseline (a Poisson process,
#' thinned from its upper bound for a sinusoidal baseline), then each event's
#' offspring, a Poisson number with mean the branching ratio, at delays drawn
#' from the fitted kernel, generation after generation, until none fall before
#' the horizon.
#' @param fit A [chwkfit()] result.
#' @param hor Number, the end of the window; default the fit's horizon.
#' @param seed Whole number, default 1, for this call only (the session's stream
#'   is left as it was).
#' @return The sorted event times (numeric), with the attribute `generation` (0
#'   for an immigrant, 1 for its children, ...).
#' @seealso [plothwk()], [chwkfit()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' times <- sort(stats::runif(300, 0, 100))
#' fit <- chwkfit(times, 100)
#' sim <- chwksim(fit, seed = 2)
#' length(sim)
#' table(attr(sim, "generation"))
#' try(chwksim(list(a = 1)))
#' @export
chwksim <- function(fit, hor = NULL, seed = 1L) {
  .hk_fit_check(fit)
  hor <- if (is.null(hor)) {
    fit$horizon
  } else {
    .rmbl_scalar(hor, "hor", .Machine$double.eps, 1e9)
  }
  .rmbl_local_seed(seed)
  a <- fit$basepar
  numax <- exp(a[[1L]] + if (length(a) > 1L) sum(abs(a[-1L])) else 0)
  n0 <- stats::rpois(1L, numax * hor)
  t <- stats::runif(n0, 0, hor)
  t <- t[stats::runif(n0) <= .hk_nu(fit, t) / numax]
  gen <- rep(0L, length(t))
  k <- unname(fit$kerpar)
  delay <- function(n) {
    switch(
      fit$kernel,
      exponential = stats::rexp(n, k[[1L]]),
      weibull = stats::rweibull(n, k[[1L]], k[[2L]]),
      gamma = stats::rgamma(n, k[[1L]], k[[2L]]),
      lomax = k[[2L]] * (stats::runif(n)^(-1 / k[[1L]]) - 1)
    )
  }
  cur <- t
  g <- 0L
  while (length(cur)) {
    m <- stats::rpois(length(cur), fit$braratio)
    kid <- rep(cur, m) + delay(sum(m))
    kid <- kid[kid <= hor]
    g <- g + 1L
    t <- c(t, kid)
    gen <- c(gen, rep(g, length(kid)))
    cur <- kid
  }
  o <- order(t)
  structure(t[o], generation = gen[o])
}

#' Plot a fitted Hawkes process
#'
#' Three views of a [chwkfit()] result against its events: \describe{
#' \item{`"intensity"`}{the conditional intensity \eqn{\lambda(t) = \nu(t) +
#' \eta \sum_{t_j < t} g(t - t_j)} over the window, the baseline dashed and the
#' events as ticks along the axis.} \item{`"qq"`}{the time-rescaling residuals
#' of [chwkres()] against the uniform quantiles: a correct model puts
#' them on the diagonal (the Kolmogorov-Smirnov p-value of the fit in the
#' title).} \item{`"tree"`}{the most probable branching structure: each event
#' drawn at its time and generation, linked to the earlier event (or the
#' baseline) most likely to have triggered it, the probabilities \eqn{\eta g(t_i
#' - t_j)} and \eqn{\nu(t_i)} in proportion. At most 5,000 events.} }
#' @param times The event times the fit was made on.
#' @param what One of `"intensity"`, `"qq"` or `"tree"`.
#' @param ngrid Whole number, default 600: points of the intensity curve.
#' @param ... Further arguments to the `plot()` call that opens the panel.
#' @param main,col,pal The title, colours, and a [blpal()] name.
#' @return The data drawn, invisibly: `t` and `lambda` (intensity),
#'   `uniform` and `residual` (a Q-Q plot), or `t`, `parent` (the
#'   index of the parent event, 0 for the baseline), `prob` and
#'   `generation` (tree).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' times <- sort(stats::runif(200, 0, 100))
#' fit <- chwkfit(times, 100)
#' plothwk(fit, times)
#' plothwk(fit, times, "qq")
#' tr <- plothwk(fit, times, "tree")
#' table(tr$generation)
#' @export
#' @inheritParams chwksim
plothwk <- function(
  fit,
  times,
  what = c("intensity", "qq", "tree"),
  ngrid = 600L,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  .hk_fit_check(fit)
  what <- .rmbl_arg(what)
  times <- .rmbl_num(times, "times")
  if (!length(times) || anyNA(times) || !all(is.finite(times)) ||
        any(abs(times) > 1e12)) {
    stop(
      "plothwk: `times` must be the event times, finite and none missing",
      call. = FALSE
    )
  }
  if (any(times < 0 | times > fit$horizon)) {
    stop(sprintf(
      "plothwk: `times` must lie in the fit's window, 0 to %s",
      format(fit$horizon)), call. = FALSE)
  }
  times <- sort(times)
  cols <- .bl_cols(3L, col, pal)
  op <- .bl_par(NULL)
  on.exit(graphics::par(op), add = TRUE)
  if (what == "qq") {
    return(.hk_plot_qq(fit, times, cols, main, ...))
  }
  if (what == "tree") {
    return(.hk_plot_tree(fit, times, cols, main, ...))
  }
  .hk_plot_intensity(fit, times, ngrid, cols, main, ...)
}

#' Checks a chwkfit() result.
#' @param fit The value passed.
#' @return `fit`, invisibly.
#' @noRd
.hk_fit_check <- function(fit) {
  if (
    !is.list(fit) ||
      !all(
        c(
          "kernel",
          "baseline",
          "basepar",
          "braratio",
          "kerpar",
          "horizon",
          "theta"
        ) %in%
          names(fit)
      )
  ) {
    stop(.rmbl_fn(), "`fit` must be a chwkfit() result", call. = FALSE)
  }
  invisible(fit)
}

#' The baseline intensity of a fit at times t.
#' @param fit A chwkfit() result.
#' @param t The times.
#' @return The baseline at `t`.
#' @noRd
.hk_nu <- function(fit, t) {
  a <- fit$basepar
  if (fit$baseline == "constant") {
    return(rep(exp(a[[1L]]), length(t)))
  }
  exp(
    a[[1L]] +
      a[[2L]] * t / fit$horizon +
      a[[3L]] * sin(2 * pi * t / 365.25) +
      a[[4L]] * cos(2 * pi * t / 365.25)
  )
}

#' The normalised kernel density of a fit at lags u.
#' @param fit A chwkfit() result.
#' @param u The lags (positive).
#' @return The density at `u`.
#' @noRd
.hk_g <- function(fit, u) {
  k <- unname(fit$kerpar)
  switch(
    fit$kernel,
    exponential = stats::dexp(u, k[[1L]]),
    weibull = stats::dweibull(u, k[[1L]], k[[2L]]),
    gamma = stats::dgamma(u, k[[1L]], k[[2L]]),
    lomax = k[[1L]] / k[[2L]] * (1 + u / k[[2L]])^(-k[[1L]] - 1)
  )
}

#' Draws the time-rescaling Q-Q view of plothwk().
#' @param fit A chwkfit() result.
#' @param times The sorted event times, turned into residuals.
#' @param cols The colours; the first fills the points.
#' @param main The title, or NULL for the Q-Q plot's default.
#' @param ... Further arguments to the first plot() call.
#' @return The data drawn, invisibly.
#' @noRd
.hk_plot_qq <- function(fit, times, cols, main, ...) {
  hor <- fit$horizon
  u <- sort(chwkres(times, hor, fit$kernel, fit$theta, base = fit$baseline))
  q <- stats::qunif(stats::ppoints(length(u)))
  graphics::plot(
    c(0, 1),
    c(0, 1),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  graphics::points(q, u, pch = 21, bg = cols[1L], col = "white", cex = 0.8)
  .bl_xlab("Uniform quantile")
  .bl_ylab("Rescaled residual")
  .bl_title(.bl_main(
    main,
    sprintf("Time-rescaling check (KS p = %.3g)", fit$kspva)
  ))
  invisible(data.frame(uniform = q, residual = u))
}

#' The most probable parent of each event, for plothwk()'s tree view (at
#' most 5,000 events).
#' @param fit A chwkfit() result.
#' @param times The sorted event times, each linked to an earlier one.
#' @return A list of `parent` (0 for the baseline), `prob` and `generation`.
#' @noRd
.hk_tree_links <- function(fit, times) {
  n <- length(times)
  if (n > 5000L) {
    stop("plothwk: the tree view takes at most 5,000 events", call. = FALSE)
  }
  par0 <- integer(n)
  prob <- numeric(n)
  gen <- integer(n)
  for (i in seq_len(n)) {
    j <- which(times < times[i])
    w <- c(
      .hk_nu(fit, times[i]),
      fit$braratio * .hk_g(fit, times[i] - times[j])
    )
    k <- which.max(w)
    par0[i] <- if (k == 1L) 0L else j[k - 1L]
    prob[i] <- w[k] / sum(w)
    gen[i] <- if (par0[i] == 0L) 0L else gen[par0[i]] + 1L
  }
  list(parent = par0, prob = prob, generation = gen)
}

#' Draws the branching-tree view of plothwk().
#' @param fit A chwkfit() result.
#' @param times The sorted event times, drawn by generation.
#' @param cols The colours of baseline events and of their offspring.
#' @param main The title, or NULL for the tree's default.
#' @param ... Further arguments to the first plot() call.
#' @return The data drawn, invisibly.
#' @noRd
.hk_plot_tree <- function(fit, times, cols, main, ...) {
  hor <- fit$horizon
  ln <- .hk_tree_links(fit, times)
  par0 <- ln$parent
  prob <- ln$prob
  gen <- ln$generation
  graphics::plot(
    c(0, hor),
    c(-0.3, max(gen) + 0.3),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  kid <- par0 > 0L
  graphics::segments(
    times[par0[kid]],
    gen[par0[kid]],
    times[kid],
    gen[kid],
    col = grDevices::adjustcolor(cols[2L], 0.6)
  )
  graphics::points(
    times,
    gen,
    pch = 21,
    bg = ifelse(gen == 0L, cols[1L], cols[2L]),
    col = "white",
    cex = 0.6 + prob
  )
  .bl_xlab("Time")
  .bl_ylab("Generation")
  .bl_title(.bl_main(
    main,
    sprintf(
      "Most probable branching: %d immigrants, %d triggered",
      sum(!kid),
      sum(kid)
    )
  ))
  invisible(data.frame(
    t = times,
    parent = par0,
    prob = prob,
    generation = gen
  ))
}

#' Draws the conditional-intensity view of plothwk().
#' @param fit A chwkfit() result.
#' @param times The sorted event times, marked as a rug.
#' @param ngrid Points of the intensity curve, as passed.
#' @param cols The colours of the intensity, the rug and the baseline.
#' @param main The title, or NULL for the intensity plot's default.
#' @param ... Further arguments to the first plot() call.
#' @return The data drawn, invisibly.
#' @noRd
.hk_plot_intensity <- function(fit, times, ngrid, cols, main, ...) {
  hor <- fit$horizon
  ngrid <- .rmbl_scalar(ngrid, "ngrid", 10, 1e5, integer = TRUE)
  tg <- seq(0, hor, length.out = ngrid)
  lam <- .hk_nu(fit, tg) +
    fit$braratio *
      vapply(
        tg,
        function(t) {
          u <- t - times[times < t]
          sum(.hk_g(fit, u))
        },
        1
      )
  graphics::plot(
    c(0, hor),
    c(0, max(lam)),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  graphics::lines(tg, .hk_nu(fit, tg), col = cols[3L], lty = 2, lwd = 1.5)
  graphics::lines(tg, lam, col = cols[1L], lwd = 1.6)
  graphics::rug(times, col = cols[2L], ticksize = 0.03)
  .bl_xlab("Time")
  .bl_ylab("Conditional intensity")
  .bl_title(.bl_main(
    main,
    sprintf(
      "Intensity: branching ratio %.3f, %s kernel",
      fit$braratio,
      fit$kernel
    )
  ))
  invisible(data.frame(t = tg, lambda = lam))
}
