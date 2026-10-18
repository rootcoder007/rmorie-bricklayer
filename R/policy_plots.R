# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The figures of policy-evaluation papers, in base graphics: event studies for several outcomes in one
# grid, the Goodman-Bacon scatter, randomization-inference distributions, leave-one-out estimates, and
# raw outcome trends by adoption cohort.

# The corner of the plotting region with the fewest of the plotted points, for a legend that hides
# nothing
.bl_free_corner <- function(x, y) {
  u <- graphics::par("usr")
  mx <- (u[1L] + u[2L]) / 2
  my <- (u[3L] + u[4L]) / 2
  ok <- is.finite(x) & is.finite(y)
  n <- c(topleft = sum(x[ok] < mx & y[ok] > my), topright = sum(x[ok] >= mx & y[ok] > my),
         bottomleft = sum(x[ok] < mx & y[ok] <= my), bottomright = sum(x[ok] >= mx & y[ok] <= my))
  names(n)[which.min(n)]
}

#' Event studies for several outcomes in one grid
#'
#' Draws a list of \code{\link{event_study}} (or \code{\link{staggered_att}}) results
#' in a grid of panels, one per outcome, with the same style, the way papers show an
#' effect on several crimes or several groups at once.
#'
#' @param x A named list of \code{\link{event_study}} or \code{\link{staggered_att}}
#'   results; the names title the panels.
#' @param ncol Panels per row (default up to 3).
#' @param main Optional overall title.
#' @param ... Passed to each panel's \code{plot()} (for example
#'   \code{style = "stata"}, \code{shade_post = TRUE}, \code{ref_line = 0}).
#' @return Invisibly, a data frame of every panel's estimates with a column
#'   \code{panel}.
#' @seealso \code{\link{event_study}}, \code{\link{plot-methods}}.
#' @examples
#' p <- policy_example()
#' es <- list(
#'   "Crime rate" = event_study(p, "district", "month", "crime_rate", "reform_month",
#'                              leads = 3, lags = 4),
#'   "Arrest rate" = event_study(p, "district", "month", "arrest_rate", "reform_month",
#'                               leads = 3, lags = 4))
#' plot_event_grid(es, style = "stata")
#' @export
plot_event_grid <- function(x, ncol = NULL, main = NULL, ...) {
  if (!is.list(x) || !length(x) || is.null(names(x)) || any(!nzchar(names(x))) ||
      !all(vapply(x, function(e) inherits(e, c("rmbl_event_study", "rmbl_staggered_att")), NA))) {
    stop("`x` must be a named list of event_study() or staggered_att() results", call. = FALSE)
  }
  n <- length(x)
  if (is.null(ncol)) ncol <- min(3L, n)
  ncol <- .rmbl_scalar(ncol, "ncol", 1, 20, integer = TRUE)
  nrow <- ceiling(n / ncol)
  op <- graphics::par(mfrow = c(nrow, ncol), oma = c(0, 0, if (is.null(main)) 0 else 2, 0),
                      mar = c(4, 4, 2.5, 1))
  on.exit(graphics::par(op), add = TRUE)
  out <- lapply(names(x), function(nm) {
    d <- graphics::plot(x[[nm]], main = nm, ...)
    if (is.data.frame(d)) cbind(panel = nm, d[c("event_time", "estimate", "lower", "upper")]) else NULL
  })
  if (!is.null(main)) graphics::mtext(main, outer = TRUE, font = 2, cex = 1.2)
  invisible(do.call(rbind, out))
}

#' @rdname plot-methods
#' @export
plot.rmbl_bacon <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_bacon")
  d <- as.data.frame(x)
  types <- c("treated vs never", "earlier vs later", "later vs earlier")
  cl <- .bl_cols(3L, col, palette)
  k <- match(d$type, types)
  graphics::plot(d$weight, d$estimate, pch = c(17, 1, 4)[k], col = cl[k], xlab = "Weight",
                 ylab = "2 x 2 difference-in-differences estimate",
                 main = .bl_main(main, "Goodman-Bacon decomposition"), ...)
  graphics::abline(h = attr(x, "twfe"), lwd = 1.5)
  used <- sort(unique(k))
  graphics::legend(.bl_free_corner(d$weight, d$estimate), types[used], pch = c(17, 1, 4)[used], col = cl[used],
                   bty = "n", cex = 0.85)
  graphics::mtext(sprintf("Two-way estimate (line) = %.4g", attr(x, "twfe")), side = 3, line = 0.2, cex = 0.8)
  invisible(d)
}

#' @rdname plot-methods
#' @param type For a permutation test: \code{"density"} (a kernel density of the
#'   permuted statistics, their 5th and 95th percentiles dashed, the observed one in
#'   red; the default) or \code{"histogram"}. For a cross-fitted AIPW result:
#'   \code{"overlap"} (the weighted distribution of the out-of-fold propensity in each
#'   arm with the clipping bounds; the default) or \code{"estimate"} (the effect with
#'   its confidence interval).
#' @export
plot.rmbl_permutation <- function(x, ..., main = NULL, col = NULL, palette = NULL, type = c("density", "histogram")) {
  .rmbl_plot_check(x, "rmbl_permutation")
  type <- .rmbl_arg(type)
  null <- attr(x, "null")
  d <- as.data.frame(x)
  n <- nrow(d)
  op <- graphics::par(mfrow = c(ceiling(n / min(3L, n)), min(3L, n)), mar = c(4, 4, 3, 1))
  on.exit(graphics::par(op), add = TRUE)
  cl <- .bl_cols(1L, col, palette)
  for (j in seq_len(n)) {
    z <- null[, j]
    z <- z[is.finite(z)]
    ttl <- sprintf("%s (p = %.3g)", d$outcome[j], d$p_value[j])
    rng <- range(c(z, d$statistic[j]))
    if (type == "density" && length(unique(z)) > 1L) {
      k <- stats::density(z)
      graphics::plot(k, xlim = range(c(k$x, rng)), main = .bl_main(main, ttl), xlab = "Permuted statistic",
                     ylab = "Density", col = cl, ...)
      graphics::abline(v = stats::quantile(z, c(0.05, 0.95)), lty = 2)
    } else {
      graphics::hist(z, breaks = min(30L, max(5L, length(z) %/% 3L)), xlim = rng, col = "#D5D5D5",
                     border = "white", main = .bl_main(main, ttl), xlab = "Permuted statistic", ylab = "Count", ...)
    }
    graphics::abline(v = d$statistic[j], col = "#C0392B", lwd = 2)
  }
  invisible(d)
}

#' Leave-one-out estimates of a difference in differences
#'
#' Re-estimates \code{\link{did_panel}} leaving out one treated unit at a time, to
#' show that no single unit drives the result.
#'
#' @inheritParams did_panel
#' @param units Which units to leave out (default every treated unit).
#' @return A data frame of class \code{rmbl_loo}: \code{dropped}, \code{estimate},
#'   \code{se}; attribute \code{full} (the estimate with every unit). \code{plot()}
#'   draws the histogram with the full-sample estimate and a summary.
#' @examples
#' p <- policy_example()
#' l <- leave_one_out(p, "district", "month", "crime_rate", "reformed")
#' range(l$estimate)
#' plot(l)
#' @export
leave_one_out <- function(data, unit, time, outcome, treated, covariates = NULL, cluster = NULL, units = NULL) {
  full <- did_panel(data, unit, time, outcome, treated, covariates = covariates, cluster = cluster)
  ever <- tapply(data[[treated]], data[[unit]], max) > 0
  if (is.null(units)) units <- names(ever)[ever]
  units <- as.character(units)
  if (!length(units) || !all(units %in% as.character(data[[unit]]))) {
    stop("`units` must be units of `data`", call. = FALSE)
  }
  rows <- lapply(units, function(u) {
    r <- tryCatch(did_panel(data[as.character(data[[unit]]) != u, , drop = FALSE], unit, time, outcome, treated,
                            covariates = covariates, cluster = cluster), error = function(e) NULL)
    data.frame(dropped = u, estimate = if (is.null(r)) NA_real_ else r$estimate[1L],
               se = if (is.null(r)) NA_real_ else r$se[1L], stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  attr(out, "full") <- full$estimate[1L]
  class(out) <- c("rmbl_loo", "data.frame")
  out
}

#' @rdname plot-methods
#' @export
plot.rmbl_loo <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_loo")
  d <- as.data.frame(x)
  e <- d$estimate[is.finite(d$estimate)]
  f <- attr(x, "full")
  h <- graphics::hist(e, breaks = min(30L, max(5L, length(e) %/% 2L)), plot = FALSE)
  graphics::plot(h, xlim = range(c(e, f)), ylim = c(0, max(h$counts) * 1.35), col = "#D5D5D5", border = "white",
                 xlab = "Estimate leaving one unit out", ylab = "Count",
                 main = .bl_main(main, "Leave-one-out sensitivity"), ...)
  graphics::abline(v = f, col = "#C0392B", lwd = 2)
  # the summary goes above the bars, on the side with less of them
  side <- if (sum(h$counts[h$mids < mean(range(h$breaks))]) <= sum(h$counts[h$mids >= mean(range(h$breaks))]))
    "topleft" else "topright"
  graphics::legend(side, bty = "n", cex = 0.8,
                   legend = c(sprintf("N = %d", length(e)), sprintf("Range: [%.3g, %.3g]", min(e), max(e)),
                              sprintf("Mean %.3g, SD %.2g", mean(e), stats::sd(e)), sprintf("Full sample = %.3g", f)))
  invisible(d)
}

#' Raw outcome trends by adoption cohort
#'
#' The mean outcome of each adoption cohort by time since adoption, smoothed by a
#' moving average and scaled to 1 in the period before adoption: a check, before any
#' model, that the cohorts moved together before the policy.
#'
#' @inheritParams event_study
#' @param window Periods before and after adoption to show (default -12 to 12).
#' @param ma Width of the trailing moving average (default 3; 1 for none).
#' @param normalise Scale each cohort to 1 at period -1 (default \code{TRUE}).
#' @return A data frame of class \code{rmbl_cohort_trends}: \code{cohort},
#'   \code{event_time}, \code{value}. \code{plot()} draws one line per cohort, with
#'   the period before adoption marked.
#' @examples
#' p <- policy_example()
#' ct <- cohort_trends(p, "district", "month", "crime_rate", "reform_month",
#'                     window = c(-10, 10))
#' plot(ct)
#' @export
cohort_trends <- function(data, unit, time, outcome, first_treated, window = c(-12, 12), ma = 3L, normalise = TRUE) {
  p <- .rmbl_panel(data, unit, time, outcome)
  g <- .rmbl_first_treated(data, first_treated, p)
  window <- .rmbl_num(window, "window")
  if (length(window) != 2L || window[1L] >= -1 || window[2L] < 0) {
    stop("`window` must be two numbers, the first below -1 and the second 0 or more", call. = FALSE)
  }
  ma <- .rmbl_scalar(ma, "ma", 1, 100, integer = TRUE)
  cohorts <- sort(unique(g[is.finite(g)]))
  if (!length(cohorts)) stop("no unit is ever treated", call. = FALSE)
  rows <- lapply(cohorts, function(cg) {
    k <- g == cg
    m <- tapply(p$y[k], p$t[k], mean)
    tt <- as.numeric(names(m))
    v <- as.vector(m)
    if (ma > 1L) v <- as.vector(stats::filter(v, rep(1 / ma, ma), sides = 1))
    e <- tt - cg
    keep <- e >= window[1L] & e <= window[2L]
    out <- data.frame(cohort = cg, event_time = e[keep], value = v[keep])
    if (isTRUE(normalise)) {
      b <- out$value[out$event_time == -1]
      out$value <- if (length(b) && is.finite(b) && b != 0) out$value / b else NA_real_
    }
    out
  })
  out <- do.call(rbind, rows)
  attr(out, "normalised") <- isTRUE(normalise)
  attr(out, "ma") <- ma
  class(out) <- c("rmbl_cohort_trends", "data.frame")
  out
}

#' @rdname plot-methods
#' @export
plot.rmbl_cohort_trends <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_cohort_trends")
  d <- as.data.frame(x)
  co <- unique(d$cohort)
  cl <- .bl_cols(length(co), col, palette)
  graphics::plot(range(d$event_time), range(d$value, na.rm = TRUE), type = "n", xlab = "Periods since adoption",
                 ylab = if (isTRUE(attr(x, "normalised"))) "Mean outcome (1 = period before adoption)" else
                   "Mean outcome",
                 main = .bl_main(main, "Outcome by adoption cohort"), ...)
  u <- graphics::par("usr")
  graphics::rect(-1.5, u[3L], -0.5, u[4L], col = grDevices::adjustcolor("#9A9A9A", 0.25), border = NA)
  for (i in seq_along(co)) {
    s <- d[d$cohort == co[i], ]
    graphics::lines(s$event_time, s$value, col = cl[i], lwd = 2)
  }
  graphics::legend(.bl_free_corner(d$event_time, d$value), paste("Adopted at", co), col = cl, lwd = 2, bty = "n",
                   cex = 0.85, bg = "white")
  invisible(d)
}
