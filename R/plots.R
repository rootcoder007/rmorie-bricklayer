# SPDX-License-Identifier: AGPL-3.0-or-later
# One plot() method per result the package returns, on base graphics only (no
# new dependency), with one shared look and the same customisation everywhere:
# `main`, `col` or `palette`, `grid`, and `...` handed to the base call. Every
# method returns, invisibly, the data frame it drew, so a test can check the
# numbers on the page and a user can redraw them any other way.

#' Plot styling for the package's plot methods
#'
#' Every \code{plot()} method in the package draws with base graphics and
#' the same small set of style choices, which these functions expose.
#' \code{bricklayer_palette()} returns colour-blind-safe palettes:
#' \code{"okabe"} (the Okabe-Ito categorical set), \code{"diverging"}
#' (blue, grey, orange), \code{"sequential"} (light to dark blue) and
#' \code{"grey"}. \code{bricklayer_plot_options()} sets the defaults every
#' method uses, for the session: \code{palette}, \code{grid}, \code{cex},
#' \code{las} and \code{bg}. Each method also takes \code{main},
#' \code{col} (which overrides the palette), \code{palette} and \code{...}
#' passed to the underlying base-graphics call, so a single plot can be
#' changed without changing the session.
#'
#' @param name Palette name.
#' @param n Number of colours; the categorical palettes recycle, the
#'   sequential and diverging ones interpolate.
#' @param ... For \code{bricklayer_plot_options()}, named options to set
#'   (\code{palette}, \code{grid}, \code{cex}, \code{las}, \code{bg});
#'   none to read the current values.
#' @return \code{bricklayer_palette()}: a character vector of colours.
#'   \code{bricklayer_plot_options()}: the options in force, invisibly when
#'   setting.
#' @examples
#' bricklayer_palette("okabe", 3)
#' old <- bricklayer_plot_options(palette = "grey", grid = FALSE)
#' bricklayer_plot_options()
#' bricklayer_plot_options(palette = old$palette, grid = old$grid)
#' @export
bricklayer_palette <- function(name = c("okabe", "diverging", "sequential", "grey"), n = NULL) {
  name <- match.arg(name)
  base <- switch(name,
    okabe = c("#0072B2", "#D55E00", "#009E73", "#E69F00", "#CC79A7", "#56B4E9", "#F0E442", "#000000"),
    diverging = c("#2166AC", "#8C8C8C", "#D6604D"),
    sequential = c("#DEEBF7", "#9ECAE1", "#4292C6", "#08519C"),
    grey = c("#252525", "#636363", "#969696", "#BDBDBD", "#D9D9D9"))
  if (is.null(n)) return(base)
  n <- as.integer(n)[1L]
  if (is.na(n) || n < 1L) stop("`n` must be a positive whole number", call. = FALSE)
  if (name %in% c("okabe", "grey")) return(rep_len(base, n))
  if (n == 1L) return(base[1L])
  grDevices::colorRampPalette(base)(n)
}

#' @rdname bricklayer_palette
#' @export
bricklayer_plot_options <- function(...) {
  current <- .bl_plot_opts()
  new <- list(...)
  if (!length(new)) return(current)
  bad <- setdiff(names(new), names(current))
  if (is.null(names(new)) || any(!nzchar(names(new))) || length(bad)) {
    stop(sprintf("plot options are %s", paste(names(current), collapse = ", ")), call. = FALSE)
  }
  if (!is.null(new$palette)) new$palette <- match.arg(new$palette, c("okabe", "diverging", "sequential", "grey"))
  current[names(new)] <- new
  options(rmoriebricklayer.plot = current)
  invisible(current)
}

.bl_plot_opts <- function() {
  d <- list(palette = "okabe", grid = TRUE, cex = 1, las = 1, bg = "white")
  o <- getOption("rmoriebricklayer.plot")
  if (is.list(o)) d[names(o)] <- o
  d
}

# colours for n series: `col` wins, then the palette argument, then the option
.bl_cols <- function(n, col = NULL, palette = NULL) {
  if (!is.null(col)) return(rep_len(col, n))
  bricklayer_palette(if (is.null(palette)) .bl_plot_opts()$palette else palette, n)
}

# a horizontal reference grid behind the data, when the option says so
.bl_grid <- function(grid = NULL, side = "y") {
  on <- if (is.null(grid)) .bl_plot_opts()$grid else isTRUE(grid)
  if (on) graphics::grid(nx = if (side == "y") NA else NULL, ny = if (side == "y") NULL else NA,
                         col = "#DDDDDD", lty = 1)
  invisible(on)
}

.bl_par <- function(y = NULL, labels = NULL) {
  o <- .bl_plot_opts()
  left <- if (is.null(y) && is.null(labels)) 4.5 else .bl_left_margin(y, labels)
  op <- graphics::par(las = o$las, cex = o$cex, bg = o$bg, mar = c(4.2, left, 3, 1))
  op
}

.bl_label <- function(x, digits = 3) format(x, digits = digits, big.mark = ",")

# the title: the caller's, or the method's default
.bl_main <- function(main, default) if (is.null(main)) default else main

# Panel state: while a multi-panel method runs, titles that do not fit their panel become
# letters, and the key (A: full title ...) is printed under the panels at the end.
.bl_state <- new.env(parent = emptyenv())
.bl_state$active <- FALSE

.bl_panels_begin <- function(n) {
  .bl_state$active <- TRUE
  .bl_state$n <- n
  .bl_state$next_letter <- 1L
  .bl_state$keys <- character()
  graphics::par(mfrow = c(1, n), oma = c(1.4, 0, 0, 0))
}

.bl_panels_end <- function() {
  keys <- .bl_state$keys
  .bl_state$active <- FALSE
  if (length(keys)) .bl_panel_key(keys)
  invisible(keys)
}

# the width of a string in inches on the open device, with a fallback before any
# plot exists (0.55 of a character height per character)
.bl_strwidth <- function(x, cex = 1, font = 1) {
  w <- tryCatch(graphics::strwidth(x, units = "inches", cex = cex, font = font), error = function(e) NULL)
  if (is.null(w) || any(!is.finite(w))) w <- nchar(x) * 0.55 * graphics::par("csi") * cex
  w
}

# Draw a title that fits the current panel: full size, then two smaller steps; a title
# that still does not fit becomes a letter inside a panel set (the key goes under the
# panels) or is wrapped onto two lines in a single plot.
.bl_title <- function(title) {
  if (is.null(title) || !nzchar(title)) return(invisible(title))
  width <- graphics::par("pin")[1L] * 0.98
  for (cex in c(1.2, 1, 0.85)) {
    if (.bl_strwidth(title, cex = cex, font = 2) <= width) {
      graphics::title(main = title, cex.main = cex)
      return(invisible(title))
    }
  }
  if (isTRUE(.bl_state$active)) {
    letter <- LETTERS[((.bl_state$next_letter - 1L) %% 26L) + 1L]
    .bl_state$next_letter <- .bl_state$next_letter + 1L
    .bl_state$keys <- c(.bl_state$keys, sprintf("%s: %s", letter, title))
    graphics::title(main = letter, cex.main = 1.2)
    return(invisible(letter))
  }
  words <- strsplit(title, " ", fixed = TRUE)[[1L]]
  lines <- character()
  cur <- ""
  for (w in words) {
    cand <- if (nzchar(cur)) paste(cur, w) else w
    if (nzchar(cur) && .bl_strwidth(cand, cex = 0.85, font = 2) > width) {
      lines <- c(lines, cur)
      cur <- w
    } else {
      cur <- cand
    }
  }
  lines <- c(lines, cur)
  graphics::title(main = paste(utils::head(lines, 2L), collapse = "\n"), cex.main = 0.85)
  invisible(paste(lines, collapse = " "))
}

# An axis title that fits the plot width: full size, then smaller, then two lines.
.bl_xlab <- function(xlab) {
  if (is.null(xlab) || !nzchar(xlab)) return(invisible(xlab))
  width <- graphics::par("pin")[1L] * 0.98
  for (cex in c(1, 0.85)) {
    if (.bl_strwidth(xlab, cex = cex) <= width) {
      graphics::title(xlab = xlab, cex.lab = cex)
      return(invisible(xlab))
    }
  }
  words <- strsplit(xlab, " ", fixed = TRUE)[[1L]]
  lines <- character()
  cur <- ""
  for (w in words) {
    cand <- if (nzchar(cur)) paste(cur, w) else w
    if (nzchar(cur) && .bl_strwidth(cand, cex = 0.85) > width) {
      lines <- c(lines, cur)
      cur <- w
    } else {
      cur <- cand
    }
  }
  lines <- c(lines, cur)
  graphics::title(xlab = paste(utils::head(lines, 2L), collapse = "\n"), cex.lab = 0.85, line = 3.2)
  invisible(xlab)
}

# the key under lettered panels, wrapped to the device width
.bl_panel_key <- function(keys) {
  width <- graphics::par("din")[1L] * 0.96
  lines <- character()
  cur <- ""
  for (k in keys) {
    cand <- if (nzchar(cur)) paste(cur, k, sep = "    ") else k
    if (nzchar(cur) && .bl_strwidth(cand, cex = 0.8) > width) {
      lines <- c(lines, cur)
      cur <- k
    } else {
      cur <- cand
    }
  }
  lines <- c(lines, cur)
  for (i in seq_along(lines)) {
    graphics::mtext(lines[i], side = 1, outer = TRUE, line = i - 1, cex = 0.8, adj = 0)
  }
  invisible(lines)
}

# a left margin (in lines) wide enough for the tick labels of `y`, or for `labels`,
# plus the axis title
.bl_left_margin <- function(y = NULL, labels = NULL) {
  if (!is.null(labels)) {
    txt <- as.character(labels)
  } else {
    y <- y[is.finite(y)]
    if (!length(y)) return(4.5)
    txt <- format(pretty(y), trim = TRUE)
  }
  w <- max(.bl_strwidth(txt, cex = 0.9), 0)
  lines <- w / graphics::par("csi")
  min(1.6 + lines + (if (is.null(labels)) 2.2 else 0.6), 14)
}

# dots with an interval per row: the chart most of the tabular results want
.bl_dot_interval <- function(label, est, lower, upper, main, xlab, cols, ref = NULL, ...) {
  n <- length(est)
  op <- .bl_par(labels = label)
  on.exit(graphics::par(op), add = TRUE)
  vals <- c(est, lower, upper, ref)
  vals <- vals[is.finite(vals)]
  rng <- if (length(vals)) range(vals) else c(0, 1)
  if (diff(rng) == 0) rng <- rng + c(-1, 1)
  graphics::plot(est, seq_len(n), xlim = rng, ylim = c(0.5, n + 0.5), yaxt = "n",
                 ylab = "", xlab = "", main = "", type = "n", ...)
  .bl_title(main)
  .bl_xlab(xlab)
  .bl_grid(NULL, side = "x")
  if (!is.null(ref)) graphics::abline(v = ref, col = "#8C8C8C", lty = 2)
  ok <- is.finite(lower) & is.finite(upper)
  graphics::segments(lower[ok], seq_len(n)[ok], upper[ok], seq_len(n)[ok], col = cols[ok], lwd = 2)
  graphics::points(est, seq_len(n), pch = 19, col = cols, cex = 1.2)
  graphics::axis(2, at = seq_len(n), labels = label, tick = FALSE, cex.axis = 0.85)
  invisible(NULL)
}

# ---- stock and flow -----------------------------------------------------------

#' Plot methods for the package's results
#'
#' Every result the package returns draws itself with \code{plot()}: no
#' arguments beyond the object are needed, and every method takes the same
#' customisation (\code{main}, \code{col} or \code{palette}, \code{...} for
#' the base-graphics call, the grid from the session option; see
#' \code{\link{bricklayer_plot_options}}). Titles fit their panel: a title
#' too wide for it is drawn a step smaller, and in a panel set one that still
#' does not fit becomes a letter with the key printed under the panels (the
#' returned data carry it as the \code{panel_key} attribute); the left margin
#' is sized from the widest tick label, so an axis title never overlaps the
#' numbers. (Session defaults: see
#' \code{\link{bricklayer_plot_options}} for the session defaults). Each
#' method returns the data it drew, invisibly, as a data frame.
#'
#' \describe{
#'   \item{\code{rmbl_stock_flow}}{(\code{\link{stock_flow}}) the average
#'     daily population, length of stay, people and person-days over the
#'     periods, one panel per measure in \code{what}; with an exposure,
#'     the flow and stock rates too.}
#'   \item{\code{rmbl_yoy}}{(\code{\link{yoy}}) the period-over-period
#'     percent change with its interval, one row per period (and group),
#'     coloured by verdict; \code{what = "value"} draws the values instead.}
#'   \item{\code{rmbl_rate}, \code{rmbl_share}, \code{rmbl_rate_change}}{
#'     (\code{\link{rate}}) the rate, share or percent change per group with
#'     its interval.}
#'   \item{\code{rmbl_band_sensitivity}}{(\code{\link{band_sensitivity}})
#'     the statistic against the cap applied to the open band.}
#'   \item{\code{rmbl_drift_calibration}, \code{bricklayer_drift}}{
#'     (\code{\link{drift_calibrate}}, \code{\link{capsule_drift}}) the
#'     false-alarm rate per column against alpha; the population stability
#'     index per column with the drifted columns marked.}
#'   \item{\code{bricklayer_benford}}{(\code{\link{benford_test}}) observed
#'     first-digit proportions against Benford's law.}
#'   \item{\code{bricklayer_power}}{(\code{\link{capsule_power}}) the power
#'     curve: detection rate against injected effect size, with the 0.8
#'     line.}
#'   \item{\code{bricklayer_freq}, \code{bricklayer_missingness},
#'     \code{rmbl_region_coverage}}{(\code{\link{frequency_table}},
#'     \code{\link{missingness_pattern}}, \code{\link{region_coverage}})
#'     horizontal bars.}
#'   \item{\code{bricklayer_outliers}}{(\code{\link{mahalanobis_outliers}})
#'     the distance of every row, outliers marked.}
#'   \item{\code{bricklayer_correlations}, \code{bricklayer_cortable}}{
#'     (\code{\link{top_correlations}}, \code{\link{correlation_table}}) the
#'     correlation of every pair as a diverging bar.}
#'   \item{\code{bricklayer_falsification}}{(\code{\link{capsule_falsify}})
#'     the permutation null distribution with the observed statistic.}
#'   \item{\code{rmbl_bounds}}{(\code{\link{published_bounds}}) each value
#'     inside its published-rounding envelope.}
#'   \item{\code{rmbl_crf}, \code{rmbl_burden}, \code{rmbl_equity},
#'     \code{rmbl_pollution_report}}{(\code{\link{crf_pm25}},
#'     \code{\link{pollution_burden}},
#'     \code{\link{exposure_concentration_index}},
#'     \code{\link{verify_pollution}}) the concentration-response curve with
#'     the exposure marked; baseline against attributable cases; the
#'     concentration curve of exposure over income rank; and, for a report,
#'     all three on one page.}
#'   \item{\code{rmbl_footprint}}{(\code{\link{compute_footprint}}) the
#'     emission with its car-kilometre and tree-month equivalents.}
#'   \item{\code{rmbl_field}, \code{rmbl_particles}}{
#'     (\code{\link{plume_field}}, \code{\link{advection_diffusion_2d}},
#'     \code{\link{lagrangian_particles}}) a concentration field as an
#'     image with contours; particle positions, with the counting grid
#'     behind them when one was given.}
#'   \item{\code{rmbl_count_trend}}{(\code{\link{count_trend}}) the counts
#'     with the fitted trend.}
#'   \item{\code{bricklayer_analysis}}{(\code{\link{analyse_table}}) the
#'     change, rates and rate change of a published table, one panel each.}
#' }
#'
#' @param x The result.
#' @param ... Passed to the base-graphics call (\code{plot}, \code{barplot}
#'   or \code{image}); for \code{bricklayer_analysis}, passed on to each
#'   panel's method.
#' @param main Title; each method has a default.
#' @param col Colours, overriding the palette.
#' @param palette A \code{\link{bricklayer_palette}} name, overriding the
#'   session option.
#' @param what For \code{rmbl_stock_flow}, the measures to draw (one panel
#'   each): any of \code{"adp"}, \code{"alos"}, \code{"people"},
#'   \code{"days"}, \code{"flow_rate"}, \code{"stock_rate"}. For
#'   \code{rmbl_yoy}, \code{"pct_change"} or \code{"value"}.
#' @param exposure For \code{rmbl_crf} and \code{rmbl_burden}, the exposure
#'   range to draw the curve over; the default runs from 0 to 1.5 times the
#'   exposure in the object.
#' @param which For \code{bricklayer_analysis}, the panels: any of
#'   \code{"change"}, \code{"rates"}, \code{"rate_change"}; \code{NULL} draws
#'   every panel the analysis has.
#' @param contours Number of contour lines over a field image (0 for none).
#' @return The data drawn, invisibly.
#' @examples
#' sf <- stock_flow(days = c(13500, 14600, 15100), people = c(300, 320, 310),
#'                  period = 2021:2023)
#' plot(sf)
#' plot(sf, what = "alos", col = "firebrick", main = "Length of stay")
#' y <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n",
#'          period = "year")
#' plot(y)
#' plot(benford_test(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9)))
#' plot(crf_no2(25))
#' plot(compute_footprint(sum(1:10), location = "CA", cpu_power_w = 45, memory_gb = 8))
#' plot(plume_field(q = 100, u = 5, h = 50, x = seq(100, 2000, by = 100),
#'                  y = seq(-300, 300, by = 50)))
#' @name plot-methods
#' @aliases plot.rmbl_stock_flow
#' @export
plot.rmbl_stock_flow <- function(x, ..., what = c("adp", "alos", "people", "days"),
                                 main = NULL, col = NULL, palette = NULL) {
  avail <- intersect(c("adp", "alos", "people", "days", "flow_rate", "stock_rate"), names(x))
  what <- match.arg(what, avail, several.ok = TRUE)
  labs <- c(adp = "Average daily population", alos = "Average length of stay (days)",
            people = "People", days = "Person-days", flow_rate = "Flow rate",
            stock_rate = "Stock rate")
  cols <- .bl_cols(length(what), col, palette)
  op <- graphics::par(las = .bl_plot_opts()$las, cex = .bl_plot_opts()$cex, bg = .bl_plot_opts()$bg,
                      mar = c(4.2, 4.5, 3, 1))
  op2 <- .bl_panels_begin(length(what))
  on.exit(graphics::par(op2), add = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  xs <- seq_len(nrow(x))
  for (i in seq_along(what)) {
    v <- x[[what[i]]]
    graphics::par(mar = c(4.2, .bl_left_margin(v), 3, 1))
    graphics::plot(xs, v, type = "n", xaxt = "n", xlab = "Period", ylab = labs[[what[i]]],
                   main = "", ...)
    .bl_title(.bl_main(main, labs[[what[i]]]))
    .bl_grid(NULL)
    graphics::lines(xs, v, col = cols[i], lwd = 2)
    graphics::points(xs, v, pch = 19, col = cols[i], cex = 1.2)
    graphics::axis(1, at = xs, labels = x$period)
  }
  key <- .bl_panels_end()
  out <- as.data.frame(x)[c("period", what)]
  attr(out, "panel_key") <- key
  invisible(out)
}

# ---- period-over-period ---------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_yoy <- function(x, ..., what = c("pct_change", "value"), main = NULL, col = NULL,
                          palette = NULL) {
  what <- match.arg(what)
  d <- as.data.frame(x)
  meta <- attr(x, "yoy")
  period <- if (!is.null(meta$period)) meta$period else names(d)[1L]
  by <- meta$by
  label <- as.character(d[[period]])
  if (length(by)) label <- paste(do.call(paste, c(d[by], sep = " / ")), label, sep = ": ")
  verdict <- as.character(d$verdict)
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(verdict %in% c("better", "up"), pal[3L],
                 ifelse(verdict %in% c("worse", "down"), pal[1L], pal[2L]))
  if (!is.null(col)) cols <- rep_len(col, nrow(d))
  if (what == "pct_change") {
    .bl_dot_interval(label, d$pct_change, d$pct_lower, d$pct_upper,
                     if (is.null(main)) "Period-over-period change (%)" else main,
                     "Percent change, with interval", cols, ref = 0, ...)
    invisible(data.frame(label = label, pct_change = d$pct_change, lower = d$pct_lower,
                         upper = d$pct_upper, verdict = verdict, stringsAsFactors = FALSE))
  } else {
    op <- .bl_par(d$value)
    on.exit(graphics::par(op), add = TRUE)
    xs <- seq_len(nrow(d))
    graphics::plot(xs, d$value, type = "n", xaxt = "n", xlab = "", ylab = "Value",
                   main = if (is.null(main)) "Value by period" else main, ...)
    .bl_grid(NULL)
    if (length(by)) {
      g <- do.call(paste, c(d[by], sep = " / "))
      gc <- .bl_cols(length(unique(g)), col, palette)
      for (k in seq_along(unique(g))) {
        idx <- g == unique(g)[k]
        graphics::lines(xs[idx], d$value[idx], col = gc[k], lwd = 2)
        graphics::points(xs[idx], d$value[idx], col = gc[k], pch = 19)
      }
      graphics::legend("topleft", legend = unique(g), col = gc, lwd = 2, bty = "n", cex = 0.8)
    } else {
      graphics::lines(xs, d$value, col = pal[1L], lwd = 2)
      graphics::points(xs, d$value, col = pal[1L], pch = 19)
    }
    graphics::axis(1, at = xs, labels = label, cex.axis = 0.8)
    invisible(data.frame(label = label, value = d$value, stringsAsFactors = FALSE))
  }
}

# ---- rates, shares, rate change --------------------------------------------------

.bl_group_label <- function(d, by) {
  if (!length(by)) return("all")
  do.call(paste, c(d[by], sep = " / "))
}

#' @rdname plot-methods
#' @export
plot.rmbl_rate <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  meta <- attr(x, "rate")
  label <- .bl_group_label(d, meta$by)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(label, d$rate, d$lower, d$upper,
                   if (is.null(main)) sprintf("Rate %s", meta$per_label %||% "") else main,
                   sprintf("Rate %s, with interval", meta$per_label %||% ""), cols, ...)
  invisible(data.frame(label = label, rate = d$rate, lower = d$lower, upper = d$upper,
                       stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.rmbl_share <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  meta <- attr(x, "share")
  label <- .bl_group_label(d, meta$by)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(label, 100 * d$share, 100 * d$lower, 100 * d$upper,
                   if (is.null(main)) "Share of the total (%)" else main,
                   "Percent of the total, with interval", cols, ...)
  invisible(data.frame(label = label, share = d$share, lower = d$lower, upper = d$upper,
                       stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.rmbl_rate_change <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  meta <- attr(x, "rate_change")
  label <- paste(.bl_group_label(d, meta$by), as.character(d[[meta$period]]), sep = ": ")
  if (!length(meta$by)) label <- as.character(d[[meta$period]])
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(is.na(d$pct_change), pal[2L], ifelse(d$pct_change > 0, pal[3L], pal[1L]))
  if (!is.null(col)) cols <- rep_len(col, nrow(d))
  .bl_dot_interval(label, d$pct_change, d$pct_lower, d$pct_upper,
                   if (is.null(main)) "Change in the rate (%)" else main,
                   "Percent change in the rate, with interval", cols, ref = 0, ...)
  invisible(data.frame(label = label, pct_change = d$pct_change, lower = d$pct_lower,
                       upper = d$pct_upper, stringsAsFactors = FALSE))
}

# ---- banded tables, drift, Benford, power ------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_band_sensitivity <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(d$value)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$cap, d$value, type = "n", xlab = "",
                 ylab = "Statistic", main = if (is.null(main)) "Sensitivity to the open band's cap" else main, ...)
  .bl_xlab("Cap applied to the open band")
  .bl_grid(NULL)
  graphics::lines(d$cap, d$value, col = cols, lwd = 2)
  graphics::points(d$cap, d$value, col = cols, pch = 19)
  invisible(d[c("cap", "value")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_drift_calibration <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- x$columns
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(d$false_alarm_rate)
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(d$false_alarm_rate, names.arg = d$column, col = cols, border = NA,
                    ylab = "False-alarm rate", ylim = c(0, max(c(d$false_alarm_rate, x$alpha * 2), na.rm = TRUE)),
                    main = if (is.null(main)) sprintf("Drift false alarms over %d random splits", x$n) else main, ...)
  .bl_grid(NULL)
  graphics::abline(h = x$alpha, col = "#8C8C8C", lty = 2)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_drift <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- x$columns
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(!is.na(d$drifted) & d$drifted, pal[3L], pal[1L])
  if (!is.null(col)) cols <- rep_len(col, nrow(d))
  op <- .bl_par(d$psi)
  on.exit(graphics::par(op), add = TRUE)
  psi <- ifelse(is.finite(d$psi), d$psi, 0)
  graphics::barplot(psi, names.arg = d$column, col = cols, border = NA,
                    ylab = "Population stability index",
                    main = "",
                    ...)
  .bl_title(.bl_main(main, sprintf("Drift by column (%d drifted)", sum(d$drifted, na.rm = TRUE))))
  .bl_grid(NULL)
  invisible(d[c("column", "psi", "p_value", "drifted")])
}

#' @rdname plot-methods
#' @export
plot.bricklayer_benford <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(0, max(c(x$proportion, x$expected / x$n), na.rm = TRUE)))
  on.exit(graphics::par(op), add = TRUE)
  obs <- as.numeric(x$proportion)
  exp_ <- as.numeric(x$expected) / x$n
  mids <- graphics::barplot(obs, names.arg = 1:9, col = cols[1L], border = NA,
                            ylim = c(0, max(c(obs, exp_), na.rm = TRUE) * 1.15),
                            xlab = "First digit", ylab = "Proportion",
                            main = "",
                            ...)
  .bl_title(.bl_main(main, sprintf("First digits against Benford (p = %.3g)", x$p_value)))
  .bl_grid(NULL)
  graphics::lines(mids, exp_, col = cols[2L], lwd = 2)
  graphics::points(mids, exp_, col = cols[2L], pch = 19)
  graphics::legend("topright", legend = c("observed", "Benford"), fill = c(cols[1L], NA),
                   border = NA, col = c(NA, cols[2L]), lwd = c(NA, 2), bty = "n", cex = 0.8)
  invisible(data.frame(digit = 1:9, observed = obs, expected = exp_))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_power <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- x$curve
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$size, d$rate, type = "n", ylim = c(0, 1), xlab = "",
                 ylab = "Detection rate",
                 main = if (is.null(main)) sprintf("Power curve (alpha = %s)", format(x$alpha)) else main, ...)
  .bl_xlab("Injected effect size")
  .bl_grid(NULL)
  graphics::abline(h = c(x$alpha, 0.8), col = "#8C8C8C", lty = 2)
  graphics::lines(d$size, d$rate, col = cols, lwd = 2)
  graphics::points(d$size, d$rate, col = cols, pch = 19)
  invisible(d)
}

# ---- bars: frequencies, missingness, coverage ----------------------------------------

.bl_hbars <- function(values, labels, xlab, main, cols, ...) {
  op <- graphics::par(las = 1, cex = .bl_plot_opts()$cex, bg = .bl_plot_opts()$bg,
                      mar = c(4.2, max(4.5, 0.55 * max(nchar(labels), 4) + 1), 3, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(rev(values), names.arg = rev(labels), horiz = TRUE, col = rev(cols),
                    border = NA, xlab = xlab, main = main, ...)
  .bl_grid(NULL, side = "x")
  invisible(NULL)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_freq <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  cols <- .bl_cols(nrow(d), col, if (is.null(palette) && is.null(col)) "sequential" else palette)
  if (is.null(col) && is.null(palette)) cols <- rev(cols)
  .bl_hbars(d$n, as.character(d$value), "Count",
            if (is.null(main)) "Frequency" else main, cols, ...)
  invisible(d[c("value", "n", "pct")])
}

#' @rdname plot-methods
#' @export
plot.bricklayer_missingness <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_hbars(d$n_rows, as.character(d$pattern), "Rows",
            if (is.null(main)) "Missingness patterns" else main, cols, ...)
  invisible(d[c("pattern", "n_rows", "pct_rows")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_region_coverage <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(d$has_unit, pal[1L], pal[3L])
  if (!is.null(col)) cols <- rep_len(col, nrow(d))
  .bl_hbars(d$pop_share, as.character(d$region), "Share of population (%)",
            if (is.null(main)) "Region coverage (no units: highlighted)" else main, cols, ...)
  invisible(d[c("region", "pop_share", "units", "has_unit")])
}

# ---- outliers, correlations, falsification, bounds ---------------------------------------

#' @rdname plot-methods
#' @export
plot.bricklayer_outliers <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(!is.na(d$outlier) & d$outlier, pal[3L], pal[1L])
  if (!is.null(col)) cols <- rep_len(col, nrow(d))
  op <- .bl_par(d$distance)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$row, d$distance, type = "n", xlab = "Row", ylab = "Mahalanobis distance",
                 main = "",
                 ...)
  .bl_title(.bl_main(main, sprintf("Outliers: %d of %d rows", sum(d$outlier, na.rm = TRUE), nrow(d))))
  .bl_grid(NULL)
  graphics::points(d$row, d$distance, col = cols, pch = ifelse(!is.na(d$outlier) & d$outlier, 17, 19))
  invisible(d[c("row", "distance", "outlier")])
}

.bl_corr_bars <- function(label, r, main, col, palette, ...) {
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(is.na(r), pal[2L], ifelse(r > 0, pal[3L], pal[1L]))
  if (!is.null(col)) cols <- rep_len(col, length(r))
  op <- graphics::par(las = 1, cex = .bl_plot_opts()$cex, bg = .bl_plot_opts()$bg,
                      mar = c(4.2, max(4.5, 0.55 * max(nchar(label), 4) + 1), 3, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(rev(ifelse(is.na(r), 0, r)), names.arg = rev(label), horiz = TRUE, col = rev(cols),
                    border = NA, xlim = c(-1, 1), xlab = "Correlation", main = main, ...)
  .bl_grid(NULL, side = "x")
  graphics::abline(v = 0, col = "#8C8C8C")
  invisible(NULL)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_correlations <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  label <- paste(d$x, d$y, sep = " ~ ")
  .bl_corr_bars(label, d$correlation, if (is.null(main)) "Strongest correlations" else main,
                col, palette, ...)
  invisible(data.frame(pair = label, correlation = d$correlation, stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_cortable <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  d <- d[order(-abs(d$correlation), na.last = TRUE), , drop = FALSE]
  label <- paste(d$x, d$y, sep = " ~ ")
  .bl_corr_bars(label, d$correlation,
                if (is.null(main)) sprintf("Pairwise correlations (%s)", attr(x, "method") %||% "pearson") else main,
                col, palette, ...)
  invisible(data.frame(pair = label, correlation = d$correlation, stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_falsification <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  null <- as.numeric(x$permutation)
  null <- null[is.finite(null)]
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par()
  on.exit(graphics::par(op), add = TRUE)
  if (!length(null)) {
    graphics::plot.new()
    graphics::title(main = if (is.null(main)) "No finite permutation statistics" else main)
    return(invisible(data.frame(statistic = numeric(0))))
  }
  graphics::hist(null, breaks = "FD", col = cols[1L], border = "white",
                 xlim = range(c(null, x$observed), finite = TRUE), xlab = "",
                 main = "",
                 ...)
  .bl_xlab("Statistic under permutation")
  .bl_title(.bl_main(main, sprintf("Permutation null (n = %d) and the observed value", length(null))))
  .bl_grid(NULL)
  graphics::abline(v = x$observed, col = cols[2L], lwd = 2)
  invisible(data.frame(statistic = null, observed = x$observed))
}

#' @rdname plot-methods
#' @export
plot.rmbl_bounds <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- as.data.frame(x)
  idx <- as.character(seq_len(nrow(d)))
  label <- if (!is.null(rownames(d)) && !identical(rownames(d), idx)) rownames(d) else idx
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(label, d$value, d$lower, d$upper,
                   if (is.null(main)) "Published values and their rounding envelopes" else main,
                   "Value, with the envelope the published rounding allows", cols, ...)
  invisible(d[c("value", "lower", "upper", "status")])
}

# ---- air pollution ---------------------------------------------------------------------

# the relative-risk curve of a CRF object over a range of exposures
.bl_crf_curve <- function(crf, exposure = NULL) {
  ref <- crf$reference_conc
  z <- if (is.null(exposure)) {
    seq(0, max(1.5 * crf$exposure_conc, ref * 2, 1), length.out = 200)
  } else {
    as.numeric(exposure)
  }
  excess <- pmax(z - ref, 0)
  e <- crf$extra
  rr <- if (identical(e$form, "IER")) {
    1 + e$alpha * (1 - exp(-e$gamma * excess^e$delta))
  } else {
    exp(e$beta_per_10 * excess / 10)
  }
  data.frame(exposure = z, rr = rr)
}

#' @rdname plot-methods
#' @export
plot.rmbl_crf <- function(x, ..., exposure = NULL, main = NULL, col = NULL, palette = NULL) {
  d <- .bl_crf_curve(x, exposure)
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(d$rr)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$exposure, d$rr, type = "n", xlab = sprintf("%s (micrograms per cubic metre)", x$pollutant),
                 ylab = "Relative risk",
                 main = "",
                 ...)
  .bl_title(.bl_main(main, sprintf("Concentration-response, %s (%s)", x$pollutant,
                                               x$extra$outcome %||% "")))
  .bl_grid(NULL)
  graphics::abline(v = x$reference_conc, col = "#8C8C8C", lty = 2)
  graphics::lines(d$exposure, d$rr, col = cols[1L], lwd = 2)
  graphics::points(x$exposure_conc, x$rr, col = cols[2L], pch = 19, cex = 1.3)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.rmbl_burden <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(x$baseline_cases, x$attributable_cases))
  on.exit(graphics::par(op), add = TRUE)
  vals <- c(baseline = x$baseline_cases, attributable = x$attributable_cases)
  unit <- x$extra$unit %||% "cases"
  graphics::barplot(vals, col = cols, border = NA, ylab = paste("Annual", unit),
                    main = "",
                    ...)
  .bl_title(.bl_main(main, sprintf("%s: PAF %.1f%%, %s attributable", x$pollutant,
                                                  100 * x$paf, .bl_label(x$attributable_cases, 3))))
  .bl_grid(NULL)
  invisible(data.frame(quantity = names(vals), value = unname(vals), stringsAsFactors = FALSE))
}

#' @rdname plot-methods
#' @export
plot.rmbl_equity <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  cv <- x$extra$curve
  if (is.null(cv)) stop("this equity result carries no concentration curve (older object)", call. = FALSE)
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(c(0, cv$population), c(0, cv$exposure), type = "n", xlim = c(0, 1), ylim = c(0, 1),
                 xlab = "", ylab = "Cumulative share of exposure",
                 main = "",
                 ...)
  .bl_xlab("Cumulative share of people, poorest first")
  .bl_title(.bl_main(main, sprintf("Concentration curve (index %.3f)", x$concentration_index)))
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  graphics::lines(c(0, cv$population), c(0, cv$exposure), col = cols, lwd = 2)
  invisible(cv)
}

#' @rdname plot-methods
#' @export
plot.rmbl_pollution_report <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  if (!identical(x$status, "ok")) {
    graphics::plot.new()
    graphics::title(main = if (is.null(main)) sprintf("verify_pollution: %s", x$status) else main)
    msg <- if (identical(x$status, "error")) {
      x$error
    } else {
      row <- function(a) sprintf("[%s] %s", if (a$ok) "PASS" else "FAIL", a$assumption)
      paste(vapply(x$assumptions, row, ""), collapse = "\n")
    }
    graphics::text(0.5, 0.5, msg, cex = 0.8)
    return(invisible(data.frame(status = x$status, stringsAsFactors = FALSE)))
  }
  p <- x$pipeline
  n <- if (is.null(p$equity)) 2L else 3L
  op <- .bl_panels_begin(n)
  graphics::par(oma = c(1.4, 0, 2, 0))
  on.exit(graphics::par(op), add = TRUE)
  crf <- structure(p$crf, class = "rmbl_crf")
  d1 <- plot(crf, col = col, palette = palette, ...)
  burden <- structure(p$burden, class = "rmbl_burden")
  d2 <- plot(burden, col = col, palette = palette, ...)
  if (n == 3L) plot(structure(p$equity, class = "rmbl_equity"), col = col, palette = palette, ...)
  graphics::mtext(if (is.null(main)) sprintf("%s, %s: %s", toupper(x$pollutant), x$outcome, x$data_source) else main,
                  outer = TRUE, cex = 1.1, font = 2)
  key <- .bl_panels_end()
  invisible(list(crf = d1, burden = d2, panel_key = key))
}

# ---- the footprint ---------------------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_footprint <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  eq <- footprint_equivalents(x$co2e_g)
  cols <- .bl_cols(3, col, palette)
  op <- .bl_par(c(x$co2e_g, 1000 * eq$car_km, 24 * 30 * eq$tree_months))
  on.exit(graphics::par(op), add = TRUE)
  vals <- c("gCO2e" = x$co2e_g, "car metres" = 1000 * eq$car_km, "tree hours" = 24 * 30 * eq$tree_months)
  graphics::barplot(vals, col = cols, border = NA, ylab = "",
                    main = "",
                    ...)
  kwh <- x$energy_kwh
  kwh <- if (!is.null(names(kwh)) && "total" %in% names(kwh)) kwh[["total"]] else sum(kwh)
  .bl_title(.bl_main(main, sprintf("%.3g gCO2e (%s, %s, %.3g kWh, %s)", x$co2e_g,
                                   x$carbon_intensity$location %||% "", x$method, kwh,
                                   x$usage_mode)))
  .bl_grid(NULL)
  invisible(data.frame(quantity = names(vals), value = unname(vals), stringsAsFactors = FALSE))
}

# ---- dispersion ------------------------------------------------------------------------

#' A Gaussian-plume concentration field on a grid
#'
#' Evaluates \code{\link{gaussian_plume}} at every point of an \code{x} by
#' \code{y} ground-level grid (or at height \code{z}) and returns the field
#' as a matrix with the axes, ready for \code{plot()}.
#'
#' @param q,u,h,stability,setting,mixing_height,n_images As in
#'   \code{\link{gaussian_plume}}.
#' @param x,y Downwind and crosswind coordinates of the grid (metres).
#' @param z Receptor height (metres).
#' @return A list of class \code{rmbl_field}: \code{field} (a matrix,
#'   rows along \code{x}, columns along \code{y}), \code{x}, \code{y},
#'   \code{dx}, \code{dy}, \code{units} and \code{title}.
#' @examples
#' f <- plume_field(100, 5, 50, x = seq(100, 3000, by = 100), y = seq(-500, 500, by = 50))
#' dim(f$field)
#' plot(f)
#' @export
plume_field <- function(q, u, h, x, y, z = 0, stability = "D", setting = "rural",
                        mixing_height = NULL, n_images = 3) {
  x <- .ad_num(x, "x", scalar = FALSE)
  y <- .ad_num(y, "y", scalar = FALSE)
  z <- .ad_num(z, "z", min = 0)
  rc <- expand.grid(x = x, y = y)
  rc$z <- z
  v <- gaussian_plume(q, u, h, rc, stability = stability, setting = setting,
                      mixing_height = mixing_height, n_images = n_images)
  structure(list(field = matrix(v, nrow = length(x), ncol = length(y)), x = x, y = y,
                 dx = if (length(x) > 1L) stats::median(diff(x)) else NA_real_,
                 dy = if (length(y) > 1L) stats::median(diff(y)) else NA_real_,
                 units = "concentration", title = sprintf("Gaussian plume, class %s, h = %s m", stability, format(h))),
            class = "rmbl_field")
}

#' @rdname plot-methods
#' @export
plot.rmbl_field <- function(x, ..., contours = 8L, main = NULL, col = NULL, palette = NULL) {
  f <- x$field
  xs <- if (!is.null(x$x)) x$x else seq_len(nrow(f)) * (x$dx %||% 1)
  ys <- if (!is.null(x$y)) x$y else seq_len(ncol(f)) * (x$dy %||% 1)
  cols <- if (!is.null(col)) col else bricklayer_palette(if (is.null(palette)) "sequential" else palette, 64)
  op <- .bl_par(ys)
  on.exit(graphics::par(op), add = TRUE)
  ff <- f
  ff[!is.finite(ff)] <- NA
  graphics::image(xs, ys, ff, col = cols, xlab = "x (m)", ylab = "y (m)",
                  main = if (is.null(main)) x$title %||% "Concentration field" else main, ...)
  if (contours > 0 && any(is.finite(ff)) && diff(range(ff, na.rm = TRUE)) > 0) {
    graphics::contour(xs, ys, ff, nlevels = contours, add = TRUE, col = "#333333", labcex = 0.7)
  }
  invisible(data.frame(x = rep(xs, times = length(ys)), y = rep(ys, each = length(xs)), value = as.vector(f)))
}

#' @rdname plot-methods
#' @export
plot.rmbl_particles <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(x$y)
  on.exit(graphics::par(op), add = TRUE)
  g <- x$grid
  if (!is.null(x$concentration) && !is.null(g)) {
    xs <- seq(g[1L], g[2L], length.out = g[5L] + 1L)
    ys <- seq(g[3L], g[4L], length.out = g[6L] + 1L)
    graphics::image(xs[-1L] - diff(xs) / 2, ys[-1L] - diff(ys) / 2, x$concentration,
                    col = bricklayer_palette(if (is.null(palette)) "sequential" else palette, 64),
                    xlab = "x", ylab = "y", main = if (is.null(main)) "Particles over the counting grid" else main, ...)
    graphics::points(x$x, x$y, pch = 16, cex = 0.4, col = grDevices::adjustcolor(cols, 0.5))
  } else {
    graphics::plot(x$x, x$y, pch = 16, cex = 0.5, col = grDevices::adjustcolor(cols, 0.5),
                   xlab = "x", ylab = "y", main = "", ...)
    .bl_title(.bl_main(main, sprintf("%d particles", length(x$x))))
    .bl_grid(NULL)
  }
  graphics::points(x$mean_x, x$mean_y, pch = 3, cex = 1.5, lwd = 2, col = "#D55E00")
  invisible(data.frame(x = x$x, y = x$y))
}

# ---- trend and the whole-table analysis ----------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_count_trend <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- x$data
  if (is.null(d)) stop("this trend result carries no data (older object)", call. = FALSE)
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(0, d$y, x$fitted))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$x, d$y, type = "n", xlab = "Period", ylab = "Count",
                 ylim = range(c(0, d$y, x$fitted), finite = TRUE),
                 main = "",
                 ...)
  .bl_title(.bl_main(main, sprintf("Trend: rate ratio %.3f per period (%.3f to %.3f)",
                                               x$rate_ratio, x$lower, x$upper)))
  .bl_grid(NULL)
  graphics::points(d$x, d$y, pch = 19, col = cols[1L])
  graphics::lines(d$x, x$fitted, col = cols[2L], lwd = 2)
  invisible(data.frame(x = d$x, y = d$y, fitted = x$fitted))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_analysis <- function(x, ..., which = NULL, main = NULL) {
  panels <- c("change", "rates", "rate_change")
  which <- if (is.null(which)) panels else match.arg(which, panels, several.ok = TRUE)
  parts <- Filter(Negate(is.null), list(change = x$change, rates = x$rates, rate_change = x$rate_change)[which])
  if (!length(parts)) {
    graphics::plot.new()
    graphics::title(main = if (is.null(main)) "Nothing to draw: no rates in this analysis" else main)
    return(invisible(list()))
  }
  op <- .bl_panels_begin(length(parts))
  on.exit(graphics::par(op), add = TRUE)
  out <- lapply(parts, function(p) plot(p, ..., main = main))
  attr(out, "panel_key") <- .bl_panels_end()
  invisible(out)
}

# ---- helpers for results that are plain data frames ------------------------------------------

#' Lorenz and funnel plots
#'
#' Two plots for results that are plain data frames rather than classed
#' objects. \code{plot_lorenz()} draws the Lorenz curve of a vector (or of
#' \code{\link{lorenz}}'s output) with the Gini coefficient in the title.
#' \code{plot_funnel()} draws every area's ratio of observed to expected
#' against its expected count, inside the control limits of
#' \code{\link{funnel_limits}}, the standard small-area funnel plot.
#'
#' @param x For \code{plot_lorenz()}, a numeric vector or the data frame
#'   \code{lorenz()} returns.
#' @param observed,expected Observed and expected counts per area.
#' @param area Optional labels, drawn for the areas outside the limits.
#' @param levels Control-limit levels, as in \code{\link{funnel_limits}}.
#' @param target The ratio the limits are drawn around.
#' @param main,col,palette,... As in \code{\link{plot-methods}}.
#' @return The data drawn, invisibly.
#' @examples
#' plot_lorenz(c(1, 1, 2, 3, 5, 8, 13))
#' plot_funnel(observed = c(4, 20, 50, 9), expected = c(5, 22, 40, 20),
#'             area = c("a", "b", "c", "d"))
#' @export
plot_lorenz <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  d <- if (is.data.frame(x) && all(c("population", "value") %in% names(x))) x else lorenz(x)
  g <- if (is.data.frame(x)) NA_real_ else gini(x)
  # lorenz() starts its curve at the origin; a hand-made frame may not
  if (!nrow(d) || d$population[1L] != 0 || d$value[1L] != 0) {
    d <- rbind(data.frame(population = 0, value = 0), d)
  }
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$population, d$value, type = "n", xlim = c(0, 1), ylim = c(0, 1),
                 xlab = "", ylab = "Cumulative share of the total",
                 main = "",
                 ...)
  .bl_xlab("Cumulative share of units, smallest first")
  .bl_title(.bl_main(main, if (is.na(g)) "Lorenz curve" else sprintf("Lorenz curve (Gini %.3f)", g)))
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  graphics::lines(d$population, d$value, col = cols, lwd = 2)
  invisible(d)
}

#' @rdname plot_lorenz
#' @export
plot_funnel <- function(observed, expected, area = NULL, levels = c(0.95, 0.998), target = 1, ...,
                        main = NULL, col = NULL, palette = NULL) {
  observed <- .rmbl_finite_input(observed, "observed", nonneg = TRUE, min_n = 1L)
  expected <- .rmbl_finite_input(expected, "expected", min_n = 1L)
  if (length(observed) != length(expected)) stop("`observed` and `expected` must be the same length", call. = FALSE)
  lim <- funnel_limits(sort(unique(expected)), target = target, levels = levels)
  ratio <- observed / expected
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  outer <- lim[lim$level == max(lim$level), ]
  lo <- outer$lower[match(expected, outer$expected)]
  hi <- outer$upper[match(expected, outer$expected)]
  out <- ratio > hi | ratio < lo
  cols <- ifelse(out, pal[3L], pal[1L])
  if (!is.null(col)) cols <- rep_len(col, length(ratio))
  op <- .bl_par(ratio)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(expected, ratio, type = "n", xlab = "Expected count", ylab = "Observed / expected",
                 ylim = range(c(ratio, lim$lower, lim$upper), finite = TRUE),
                 main = if (is.null(main)) "Funnel plot" else main, ...)
  .bl_grid(NULL)
  graphics::abline(h = target, col = "#8C8C8C")
  for (lv in unique(lim$level)) {
    l <- lim[lim$level == lv, ]
    l <- l[order(l$expected), ]
    graphics::lines(l$expected, l$lower, col = "#8C8C8C", lty = if (lv == max(lim$level)) 1 else 2)
    graphics::lines(l$expected, l$upper, col = "#8C8C8C", lty = if (lv == max(lim$level)) 1 else 2)
  }
  graphics::points(expected, ratio, pch = 19, col = cols)
  if (!is.null(area) && any(out)) {
    graphics::text(expected[out], ratio[out], labels = as.character(area)[out], pos = 3, cex = 0.75)
  }
  invisible(data.frame(area = if (is.null(area)) NA_character_ else as.character(area), observed = observed,
                       expected = expected, ratio = ratio, outside = out, stringsAsFactors = FALSE))
}
