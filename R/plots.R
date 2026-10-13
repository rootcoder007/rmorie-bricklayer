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
  op <- graphics::par(las = o$las, cex = o$cex, bg = o$bg, mar = .bl_safe_mar(c(4.2, left, 3, 1), o$cex))
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
  graphics::par(mfrow = .bl_panel_grid(n), oma = c(2.4, 0, 0, 0))
}

# Rows and columns for n panels on the device as it is: always one row squeezed four panels into
# a 3.5-inch device, each too narrow for its tick labels. The grid chosen gives each panel's plot
# region -- the cell less its margins (about 5.5 lines across, 7.2 down, and the key's 2.4) --
# the largest 4:3 box, fewer rows on a tie: a wide device keeps one row, a tall one stacks.
.bl_panel_grid <- function(n) {
  din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
  line <- 0.2 * .bl_plot_opts()$cex
  best <- c(1L, n)
  size <- -Inf
  for (r in seq_len(n)) {
    k <- ceiling(n / r)
    if (r > 1L && (r - 1L) * k >= n) next
    s <- min(din[1L] / k - 5.5 * line, ((din[2L] - 2.4 * line) / r - 7.2 * line) * 4 / 3)
    # no grid leaves room for the margins (four panels on a 3.5-inch device): the squarest
    # cells, where R's own smaller text in a 2 x 2 grid does the rest
    if (s <= 0) s <- -1 / min(din[1L] / k, din[2L] / r * 4 / 3)
    if (s > size + 1e-9) {
      size <- s
      best <- c(r, k)
    }
  }
  as.integer(best)
}

.bl_panels_end <- function() {
  keys <- .bl_state$keys
  .bl_state$active <- FALSE
  if (length(keys)) .bl_panel_key(keys)
  invisible(keys)
}

# an error inside a panel set must not leave the next single plot titled "A"
.bl_panels_abort <- function() {
  .bl_state$active <- FALSE
  .bl_state$keys <- character()
  invisible(NULL)
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
  # wrapped onto two lines, a step smaller each time until both fit: keeping only the first two
  # lines cut "Percent change, with interval" to "Percent change, with", and a word wider than
  # the panel ("NO2 (micrograms per cubic metre)") ran past the panel's edge
  words <- strsplit(xlab, " ", fixed = TRUE)[[1L]]
  for (cex in c(0.85, 0.75, 0.65, 0.55)) {
    lines <- character()
    cur <- ""
    for (w in words) {
      cand <- if (nzchar(cur)) paste(cur, w) else w
      if (nzchar(cur) && .bl_strwidth(cand, cex = cex) > width) {
        lines <- c(lines, cur)
        cur <- w
      } else {
        cur <- cand
      }
    }
    lines <- c(lines, cur)
    if (length(lines) <= 2L && all(.bl_strwidth(lines, cex = cex) <= width)) break
  }
  graphics::title(xlab = paste(lines, collapse = "\n"), cex.lab = cex, line = 3.2)
  invisible(xlab)
}

# The y-axis title, placed outside the tick labels actually drawn. plot()'s fixed line 3 sits
# inside a five-digit tick label ("25000"), so the two overprinted; the line is now the measured
# label width plus a gap, kept inside the margin, and the title is fitted to the plot height.
.bl_ylab <- function(ylab) {
  if (is.null(ylab) || !nzchar(ylab)) return(invisible(ylab))
  op <- graphics::par(c("cex.axis", "csi", "mar", "mgp", "pin", "las"))
  at <- graphics::axTicks(2)
  labs <- if (isTRUE(graphics::par("ylog"))) format(at) else format(at, trim = TRUE)
  # strwidth() scales its cex by par("cex"), as axis() and title() scale theirs, so the
  # relative sizes are passed as they are
  w <- if (op$las %in% c(1, 2)) max(.bl_strwidth(labs, cex = op$cex.axis), 0) else
    graphics::strheight("0", units = "inches", cex = op$cex.axis)
  need <- op$mgp[2L] + w / op$csi + 0.7
  # no room outside the tick labels (a panel on a small device, where the margins were scaled
  # down): leave the title off rather than print it over the labels; each panel's own title
  # names what is plotted
  if (need + 0.8 > op$mar[2L]) return(invisible(NULL))
  line <- need
  height <- op$pin[2L] * 0.98
  # full size, smaller, then cut with an ellipsis: a title longer than the plot is tall ran off
  # the panel
  fit <- NULL
  for (cex in c(1, 0.85, 0.7)) {
    if (.bl_strwidth(ylab, cex = cex) <= height) {
      fit <- cex
      break
    }
  }
  if (is.null(fit)) {
    fit <- 0.7
    for (k in seq(nchar(ylab) - 1L, 6L)) {
      cut <- .bl_short_label(ylab, k)
      if (.bl_strwidth(cut, cex = fit) <= height || k == 6L) {
        ylab <- cut
        break
      }
    }
  }
  graphics::title(ylab = ylab, line = max(line, 0.2), cex.lab = fit)
  invisible(ylab)
}

# the key under lettered panels, wrapped to the device width
.bl_panel_key <- function(keys) {
  width <- graphics::par("din")[1L] * 0.96
  # mtext()'s cex is absolute and strwidth()'s is scaled by par("cex"), which a panel grid
  # lowers to 0.83 or 0.66: measured at 0.8 the key was drawn wider than measured and ran off
  # the device
  # a key that wraps to more lines than the outer margin holds is drawn smaller: a third line
  # fell below the device
  room <- graphics::par("oma")[1L]
  for (cex in c(0.8, 0.7, 0.6, 0.5)) {
    rel <- cex / graphics::par("cex")
    lines <- character()
    cur <- ""
    for (k in keys) {
      cand <- if (nzchar(cur)) paste(cur, k, sep = "    ") else k
      if (nzchar(cur) && .bl_strwidth(cand, cex = rel) > width) {
        lines <- c(lines, cur)
        cur <- k
      } else {
        cur <- cand
      }
    }
    lines <- c(lines, cur)
    # an outer-margin line is scaled by the panel grid's lower par("cex") and the key's cex is
    # absolute, so one line of key text takes cex / par("cex") margin lines
    step <- 1.1 * cex / graphics::par("cex")
    if (length(lines) == 1L || length(lines) * step <= room - 0.2) break
  }
  for (i in seq_along(lines)) {
    graphics::mtext(lines[i], side = 1, outer = TRUE, line = (i - 1) * step, cex = cex, adj = 0)
  }
  invisible(lines)
}

# a left margin (in lines) wide enough for the tick labels of `y`, or for `labels`,
# plus the axis title
# A bar label longer than 28 characters is cut with an ellipsis: the margin it would ask for
# does not fit a figure ("figure margins too large"), and a label that long is not read anyway.
.bl_short_label <- function(x, max_chars = 28L) {
  x <- as.character(x)
  max_chars <- max(8L, as.integer(max_chars))
  out <- x
  long <- !is.na(x) & nchar(x) > max_chars
  out[long] <- paste0(substr(x[long], 1L, max_chars - 3L), "...")
  # distinct levels the cut made identical are told apart by a number: a 40-column missingness
  # pattern collapsed four patterns into one label (review of 52a8883)
  for (lab in unique(out[!is.na(out) & duplicated(out)])) {
    w <- which(out == lab)
    orig <- unique(x[w])
    if (length(orig) < 2L) next
    k <- match(x[w], orig)
    out[w] <- paste0(substr(x[w], 1L, max_chars - 4L - nchar(k)), "...#", k)
  }
  out
}

# Labels and the left margin they need, on the device as it is: a margin wider than the device
# failed with "figure margins too large" on a 2-3 inch plot, so long labels are cut to fit.
# The longest cut (28 characters down to 8) whose measured width fits 45% of the figure at the
# text size in use: the margin was sized at cex 1 and floored at 4.5 lines, so cex = 2 on a
# 2-3 inch device failed and a 4-inch plot cut labels to 14 characters it had room for (review
# of 02a38be). The margins are then fitted to the figure by .bl_safe_mar().
.bl_label_fit <- function(labels, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin")[1L], error = function(e) 7)
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) * cex
  room <- 0.45 * fin - csi
  fit <- NULL
  for (k in max(28L, nchar(labels), na.rm = TRUE):8) {
    cand <- .bl_short_label(labels, k)
    w <- max(.bl_strwidth(cand[!is.na(cand)], cex = cex), 0)
    fit <- list(labels = cand, w = w)
    if (w <= room) break
  }
  list(labels = fit$labels, mar = max(1, fit$w / csi + 1))
}

# Row labels that do not fit are broken onto two lines at the space nearest their middle before
# .bl_label_fit() cuts them: "Crimes Against the Person" read "Crimes Against the Pe..." on a
# 9-inch device. Returns the labels and the margin, as .bl_label_fit() does.
.bl_label_wrap <- function(labels, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin")[1L], error = function(e) 7)
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) * cex
  room <- 0.45 * fin - csi
  out <- as.character(labels)
  for (i in seq_along(out)) {
    lab <- out[i]
    if (is.na(lab) || .bl_strwidth(lab, cex = cex) <= room) next
    sp <- gregexpr(" ", lab, fixed = TRUE)[[1L]]
    if (sp[1L] < 0) next
    cut <- sp[which.min(abs(sp - nchar(lab) / 2))]
    two <- c(substr(lab, 1L, cut - 1L), substr(lab, cut + 1L, nchar(lab)))
    if (max(.bl_strwidth(two, cex = cex)) <= room) out[i] <- paste(two, collapse = "\n")
  }
  one <- !grepl("\n", out, fixed = TRUE)
  fit <- .bl_label_fit(out[one], cex = cex)
  out[one] <- fit$labels
  w <- max(vapply(strsplit(out, "\n", fixed = TRUE), function(p) max(.bl_strwidth(p, cex = cex)), 0), 0)
  list(labels = out, mar = max(1, w / csi + 1))
}

# Margins (in lines, as par("mar")) scaled down so that the left and right together, and the top
# and bottom together, take at most three quarters of the figure at the text size in use:
# "figure margins too large" on a small device or a panel otherwise.
.bl_safe_mar <- function(mar, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin"), error = function(e) c(7, 7))
  csi <- tryCatch(graphics::par("cin")[2L] * graphics::par("mex"), error = function(e) 0.2) * cex
  lim_w <- 0.75 * fin[1L] / csi
  lim_h <- 0.75 * fin[2L] / csi
  if (mar[2L] + mar[4L] > lim_w) mar[c(2L, 4L)] <- mar[c(2L, 4L)] * lim_w / (mar[2L] + mar[4L])
  if (mar[1L] + mar[3L] > lim_h) mar[c(1L, 3L)] <- mar[c(1L, 3L)] * lim_h / (mar[1L] + mar[3L])
  mar
}

.bl_left_margin <- function(y = NULL, labels = NULL) {
  if (!is.null(labels)) {
    txt <- as.character(labels)
  } else {
    y <- y[is.finite(y)]
    if (!length(y)) return(4.5)
    txt <- format(pretty(y), trim = TRUE)
  }
  txt <- txt[!is.na(txt)]
  w <- max(.bl_strwidth(txt, cex = 0.9), 0)
  lines <- w / graphics::par("csi")
  min(1.6 + lines + (if (is.null(labels)) 2.2 else 0.6), 14)
}

# dots with an interval per row: the chart most of the tabular results want
.bl_dot_interval <- function(label, est, lower, upper, main, xlab, cols, ref = NULL, note = NULL, ...) {
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
  # a row with no estimate says why (a suppressed percentage, the first period), so an empty
  # row never reads as a missing drawing
  if (!is.null(note)) {
    say <- !is.finite(est) & !is.na(note) & nzchar(note)
    if (any(say)) {
      # from the left edge and sized to the plot: centred on the reference line, a long note
      # ran off the panel ("othing to compare")
      usr <- graphics::par("usr")
      room <- graphics::par("pin")[1L] * 0.9
      txt <- note[say]
      cex <- min(0.8, 0.8 * room / max(.bl_strwidth(txt, cex = 0.8, font = 3)))
      # too small to read in a narrow panel: the part before the colon ("first period")
      if (cex < 0.6) {
        txt <- sub(":.*$", "", txt)
        cex <- min(0.8, 0.8 * room / max(.bl_strwidth(txt, cex = 0.8, font = 3)))
      }
      graphics::text(usr[1L] + 0.02 * (usr[2L] - usr[1L]), seq_len(n)[say], txt, col = "#6E6E6E",
                     cex = cex, font = 3, adj = c(0, 0.5))
    }
  }
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
#'     CPU, memory and total emission in one unit chosen to fit, with the
#'     car-kilometre and tree-month equivalents as a caption; "Too short to
#'     measure" when the work took no measurable time.}
#'   \item{\code{rmbl_field}, \code{rmbl_particles}}{
#'     (\code{\link{plume_field}}, \code{\link{advection_diffusion_2d}},
#'     \code{\link{lagrangian_particles}}) a concentration field as an
#'     image with contours; particle positions, with the counting grid
#'     behind them when one was given.}
#'   \item{\code{rmbl_count_trend}}{(\code{\link{count_trend}}) the counts
#'     with the fitted trend.}
#'   \item{\code{bricklayer_analysis}}{(\code{\link{analyse_table}}) the
#'     change, rates and rate change of a published table, one panel each.}
#'   \item{\code{rmbl_case_flow}}{(\code{\link{case_flow}}) cases received
#'     and disposed, shaded where the inventory grew or fell, and the
#'     clearance rate with its interval and rolling value.}
#'   \item{\code{rmbl_life_table}}{(\code{\link{life_table}}) the share of
#'     cases still open at each band edge with its interval, and the median.}
#'   \item{\code{rmbl_disposition_mix}}{(\code{\link{disposition_mix}}) the
#'     shares of each outcome over the periods, stacked.}
#'   \item{\code{rmbl_density}}{(\code{\link{crime_density}}) the density of
#'     incidents as a heat map, with the highest-density regions outlined.}
#'   \item{\code{rmbl_knox}}{(\code{\link{knox_test}}) the Knox ratio of each
#'     distance-by-time cell, coloured on a log scale around 1.}
#'   \item{\code{rmbl_clearance_decomposition}}{(\code{\link{clearance_decomposition}})
#'     the parts' rates in both comparisons with the aggregate on top, where the
#'     workload moved (coloured by whether a part clears above or below the
#'     average), and the change as a waterfall of rate and mix effects: the
#'     pictures that show a Simpson's-paradox reversal and why it happened.}
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
#'   \code{rmbl_yoy}, \code{"pct_change"} or \code{"value"}. For
#'   \code{rmbl_case_flow}, \code{"flow"} and/or \code{"clearance"}; for
#'   \code{rmbl_clearance_decomposition}, any of \code{"rates"}, \code{"mix"} and
#'   \code{"effects"} (the default fits the device).
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
#' y <- yoy(data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)), value = "n",
#'          period = "year")
#' plot(y)
#' # small counts: each percentage carries its exact interval
#' plot(yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n",
#'          period = "year"))
#' plot(benford_test(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9)))
#' plot(crf_no2(25))
#' plot(compute_footprint(for (i in 1:20) sum(sqrt(seq_len(2e5))), location = "CA",
#'                        cpu_power_w = 45, memory_gb = 8))
#' # the courts and crime data shipped with the package
#' ext <- function(f) {
#'   read.csv(system.file("extdata", f, package = "rmoriebricklayer"))
#' }
#' fl <- ext("ocj_flow_ontario.csv")
#' plot(case_flow(fl$received, fl$disposed, pending = fl$pending, period = fl$month))
#' td <- ext("ocj_time_to_disposition.csv")
#' open <- unlist(td[nrow(td), 2:5]) * fl$disposed[nrow(fl)]
#' plot(life_table(c(0, 10, 15, 18, Inf), open))
#' dm <- ext("ocj_dispositions.csv")
#' plot(disposition_mix(dm[, -(1:2)], period = dm$year))
#' og <- ext("ocj_offence_groups.csv")
#' og <- og[og$year %in% c(2014, 2022), ]
#' plot(clearance_decomposition(og$disposed, og$received, og$offence_group, og$year))
#' be <- ext("tps_break_enter_d14_2024.csv")
#' be <- be[!is.na(be$lon), ]
#' plot(crime_density(be$lon, be$lat, n_grid = 60))
#' \donttest{
#' plot(knox_test(be$lon, be$lat, as.Date(be$occ_date), c(100, 200, 400), c(7, 14, 28),
#'                nsim = 99, seed = 1))
#' }
#' # rates, shares and the change in a rate
#' rt <- data.frame(division = rep(c("n", "e", "w"), 2), year = rep(2022:2023, each = 3),
#'                  stops = c(120, 90, 60, 150, 85, 70),
#'                  residents = rep(c(1e4, 8e3, 5e3), 2))
#' r23 <- rt[rt$year == 2023, ]
#' plot(rate(r23, count = "stops", population = "residents", by = "division"))
#' plot(share(r23, count = "stops", by = "division"))
#' plot(rate_change(rt, count = "stops", population = "residents", period = "year",
#'                  by = "division"))
#' # a published table in one call: change, rates and rate change
#' tab <- data.frame(year = rep(2020:2023, each = 2), g = rep(c("a", "b"), 4),
#'                   n = c(10, 20, 12, 22, 11, 25, 15, 24), pop = rep(c(1000, 2000), 4))
#' plot(analyse_table(tab, value = "n", period = "year", by = "g", population = "pop"))
#' plot(count_trend(c(21000, 23000, 22000, 25000, 24000)))
#' # banded tables
#' plot(band_sensitivity(parse_bands(c("0-17", "18-24", "25-44", "45+")), c(10, 20, 30, 40),
#'                       caps = c(60, 70, 80, 90)))
#' plot(published_bounds(c(10, 20), rounding = 5))
#' plot(region_coverage(c("a", "b", "c"), c(100, 200, 300), c(1L, 0L, 2L)))
#' # drift between two extracts, and how often the test cries wolf
#' set.seed(1)
#' dd <- data.frame(a = rnorm(400), b = sample(letters[1:3], 400, TRUE))
#' plot(capsule_drift(dd, transform(dd, a = a + 3)))
#' plot(drift_calibrate(dd, n = 3L))
#' # describing a table
#' plot(frequency_table(data.frame(g = c("a", "b", "b", "c", "c", "c")), "g"))
#' plot(missingness_pattern(data.frame(a = c(1, NA, 3, NA), b = c(NA, NA, 1, 2))))
#' hw <- data.frame(h = rnorm(100), w = rnorm(100))
#' hw$h[1] <- 15
#' plot(mahalanobis_outliers(hw))
#' sq <- data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20))
#' plot(top_correlations(sq))
#' plot(correlation_table(sq))
#' # power and falsification of a statistic
#' xy <- data.frame(x = rnorm(60), y = rnorm(60))
#' shift <- function(z, s) {
#'   z$y <- z$y + s * z$x
#'   z
#' }
#' plot(capsule_power(xy, function(z) cor(z$x, z$y), inject = shift, treatment = "x",
#'                    sizes = c(0, 0.25, 0.5), n = 19, reps = 3, seed = 1))
#' plot(capsule_falsify(xy, function(z) cor(z$x, z$y), treatment = "x", n = 29, seed = 1))
#' # air pollution: burden, equity, and the full report
#' plot(pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2"))
#' plot(exposure_concentration_index(data.frame(exposure = c(4, 1, 8, 2),
#'                                              income = c(2, 1, 4, 3)),
#'                                   "exposure", "income"))
#' plot(verify_pollution("no2", demo = TRUE))
#' plot(lagrangian_particles(200, 0, 0, 1, 0.5, 1, 1, 1, 20,
#'                           grid = c(-10, 40, -15, 25, 10, 8)))
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
                      mar = .bl_safe_mar(c(4.2, 4.5, 3, 1)))
  op2 <- .bl_panels_begin(length(what))
  on.exit(graphics::par(op2), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  xs <- seq_len(nrow(x))
  for (i in seq_along(what)) {
    v <- x[[what[i]]]
    graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(v), 3, 1)))
    graphics::plot(xs, v, type = "n", xaxt = "n", xlab = "Period", ylab = "",
                   main = "", ...)
    .bl_ylab(labs[[what[i]]])
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
  # no percentage anywhere (zero bases, or one period): the counts are drawn instead, and the title says why,
  # rather than an empty frame of notes
  if (what == "pct_change" && !any(is.finite(d$pct_change))) {
    why <- unique(stats::na.omit(as.character(d$flag)))
    why <- why[nzchar(why)]
    what <- "value"
    if (is.null(main)) {
      main <- sprintf("Counts by period (no percentage change: %s)",
                      if (length(why)) paste(why, collapse = "; ") else "nothing to compare")
    }
  }
  if (what == "pct_change") {
    why <- ifelse(is.na(d$previous), "first period: nothing to compare with",
                  ifelse(!is.na(d$flag) & nzchar(as.character(d$flag)),
                         paste("no percentage:", as.character(d$flag)), "no percentage"))
    .bl_dot_interval(label, d$pct_change, d$pct_lower, d$pct_upper,
                     if (is.null(main)) "Period-over-period change (%)" else main,
                     "Percent change, with interval", cols, ref = 0, note = why, ...)
    invisible(data.frame(label = label, pct_change = d$pct_change, lower = d$pct_lower,
                         upper = d$pct_upper, verdict = verdict, stringsAsFactors = FALSE))
  } else {
    op <- .bl_par(d$value)
    on.exit(graphics::par(op), add = TRUE)
    xs <- seq_len(nrow(d))
    graphics::plot(xs, d$value, type = "n", xaxt = "n", xlab = "", ylab = "", main = "", ...)
    .bl_title(.bl_main(main, "Value by period"))
    .bl_ylab("Value")
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
                 ylab = "", main = if (is.null(main)) "Sensitivity to the open band's cap" else main, ...)
  .bl_ylab("Statistic")
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
  bp <- graphics::barplot(d$false_alarm_rate, names.arg = d$column, col = cols, border = NA,
                          ylab = "", ylim = c(0, max(c(d$false_alarm_rate, x$alpha * 2), na.rm = TRUE)),
                          main = if (is.null(main)) sprintf("Drift false alarms over %d random splits", x$n) else main,
                          ...)
  # each rate printed over its bar: a rate of 0 (the test never cried wolf) drew no bar at all
  graphics::text(bp, d$false_alarm_rate, sprintf("%.3g", d$false_alarm_rate), pos = 3, cex = 0.85, xpd = NA)
  .bl_ylab("False-alarm rate")
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
                    ylab = "",
                    main = "",
                    ...)
  .bl_ylab("Population stability index")
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
                            xlab = "First digit", ylab = "",
                            main = "",
                            ...)
  .bl_ylab("Proportion")
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
                 ylab = "",
                 main = if (is.null(main)) sprintf("Power curve (alpha = %s)", format(x$alpha)) else main, ...)
  .bl_ylab("Detection rate")
  .bl_xlab("Injected effect size")
  .bl_grid(NULL)
  graphics::abline(h = c(x$alpha, 0.8), col = "#8C8C8C", lty = 2)
  graphics::lines(d$size, d$rate, col = cols, lwd = 2)
  graphics::points(d$size, d$rate, col = cols, pch = 19)
  invisible(d)
}

# ---- bars: frequencies, missingness, coverage ----------------------------------------

.bl_hbars <- function(values, labels, xlab, main, cols, ...) {
  labels <- as.character(labels)
  # a frequency table counts NA as a level of its own; a real level called "(missing)" keeps
  # its name and the NA level is told apart
  # the first of "(missing)", "(NA)", "(NA 2)", ... that no real level uses: "(NA)" was taken when
  # "(missing)" was, and a real "(NA)" level then shared its bar (review of 02a38be)
  na_lab <- "(missing)"
  k <- 1L
  while (na_lab %in% labels) {
    na_lab <- if (k == 1L) "(NA)" else sprintf("(NA %d)", k)
    k <- k + 1L
  }
  labels[is.na(labels)] <- na_lab
  fit <- .bl_label_fit(labels)
  labels <- fit$labels
  op <- graphics::par(las = 1, cex = .bl_plot_opts()$cex, bg = .bl_plot_opts()$bg,
                      mar = .bl_safe_mar(c(4.2, fit$mar, 3, 1)))
  on.exit(graphics::par(op), add = TRUE)
  graphics::barplot(rev(values), names.arg = rev(labels), horiz = TRUE, col = rev(cols),
                    border = NA, xlab = xlab, main = main, ...)
  .bl_grid(NULL, side = "x")
  invisible(NULL)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_freq <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  if (!nrow(x)) {
    graphics::plot.new()
    graphics::title(main = if (is.null(main)) "Nothing to draw: no values" else main)
    return(invisible(x))
  }
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
  graphics::plot(d$row, d$distance, type = "n", xlab = "Row", ylab = "",
                 main = "",
                 ...)
  .bl_ylab("Mahalanobis distance")
  .bl_title(.bl_main(main, sprintf("Outliers: %d of %d rows", sum(d$outlier, na.rm = TRUE), nrow(d))))
  .bl_grid(NULL)
  graphics::points(d$row, d$distance, col = cols, pch = ifelse(!is.na(d$outlier) & d$outlier, 17, 19))
  invisible(d[c("row", "distance", "outlier")])
}

.bl_corr_bars <- function(label, r, main, col, palette, ...) {
  pal <- .bl_cols(3, col, if (is.null(palette) && is.null(col)) "diverging" else palette)
  cols <- ifelse(is.na(r), pal[2L], ifelse(r > 0, pal[3L], pal[1L]))
  if (!is.null(col)) cols <- rep_len(col, length(r))
  fit <- .bl_label_fit(label)
  label <- fit$labels
  op <- graphics::par(las = 1, cex = .bl_plot_opts()$cex, bg = .bl_plot_opts()$bg,
                      mar = .bl_safe_mar(c(4.2, fit$mar, 3, 1)))
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
  graphics::plot(d$exposure, d$rr, type = "n", xlab = "",
                 ylab = "",
                 main = "",
                 ...)
  .bl_ylab("Relative risk")
  .bl_xlab(sprintf("%s (micrograms per cubic metre)", x$pollutant))
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
  graphics::barplot(vals, col = cols, border = NA, ylab = "",
                    main = "",
                    ...)
  .bl_ylab(paste("Annual", unit))
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
                 xlab = "", ylab = "",
                 main = "",
                 ...)
  .bl_ylab("Cumulative share of exposure")
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
  # one clear error for what is not a report (a string, an empty list, an "ok" without its pipeline
  # died in 15 different ways inside the drawing; review of 02a38be)
  if (!is.list(x) || !is.character(x$status) || length(x$status) != 1L ||
        (identical(x$status, "ok") && !is.list(x$pipeline))) {
    stop("`x` must be a report from verify_pollution()", call. = FALSE)
  }
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
  graphics::par(oma = c(2.4, 0, 2, 0))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  crf <- structure(p$crf, class = "rmbl_crf")
  d1 <- plot(crf, col = col, palette = palette, ...)
  burden <- structure(p$burden, class = "rmbl_burden")
  d2 <- plot(burden, col = col, palette = palette, ...)
  if (n == 3L) plot(structure(p$equity, class = "rmbl_equity"), col = col, palette = palette, ...)
  graphics::mtext(if (is.null(main)) sprintf("%s, %s", toupper(x$pollutant), gsub("_", " ", x$outcome)) else main,
                  outer = TRUE, cex = 1.1, font = 2)
  key <- .bl_panels_end()
  invisible(list(crf = d1, burden = d2, panel_key = key))
}

# ---- the footprint ---------------------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_footprint <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  # one quantity in one unit: the emission of the CPU, of the memory and in all, in the unit that
  # suits its size (kg, g, mg or micrograms); the everyday equivalents are written under it. The
  # three bars of g, car-metres and tree-hours on one axis mixed three units, and a computation
  # too short to time drew three empty bars.
  kwh <- x$energy_kwh
  parts <- if (is.list(kwh)) unlist(kwh) else kwh
  tot_kwh <- if ("total" %in% names(parts)) parts[["total"]] else sum(parts)
  gpk <- x$carbon_intensity$g_per_kwh %||% if (tot_kwh > 0) x$co2e_g / tot_kwh else NA_real_
  comp <- c(CPU = if ("cpu" %in% names(parts)) parts[["cpu"]] * gpk else NA_real_,
            memory = if ("memory" %in% names(parts)) parts[["memory"]] * gpk else NA_real_,
            total = x$co2e_g)
  comp <- comp[is.finite(comp)]
  scale <- c(kg = 1e3, g = 1, mg = 1e-3, "\u00b5g" = 1e-6)
  big <- max(comp, 0)
  unit <- names(scale)[which(big >= scale)[1L]]
  if (is.na(unit)) unit <- "\u00b5g"
  vals <- comp / scale[[unit]]
  cols <- .bl_cols(3, col, palette)
  op <- .bl_par(labels = names(vals))
  on.exit(graphics::par(op), add = TRUE)
  where <- x$carbon_intensity$location %||% ""
  title <- .bl_main(main, sprintf("Emissions of the computation (%s, %s)", where, x$usage_mode %||% ""))
  if (big <= 0) {
    graphics::plot.new()
    .bl_title(title)
    graphics::text(0.5, 0.55, "Too short to measure", cex = 1.2, font = 2)
    graphics::text(0.5, 0.4, sprintf("%.3g s of CPU time recorded: no energy above the timer's resolution",
                                     x$cpu_time_s %||% 0), cex = 0.85, col = "#555555")
    return(invisible(data.frame(quantity = names(comp), value = unname(comp), unit = "g", stringsAsFactors = FALSE)))
  }
  graphics::barplot(vals, horiz = TRUE, col = cols[seq_along(vals)], border = NA, names.arg = names(vals),
                    xlab = "", main = "", ...)
  .bl_title(title)
  .bl_xlab(sprintf("%s CO2e", unit))
  .bl_grid(NULL, side = "x")
  eq <- footprint_equivalents(x$co2e_g)
  graphics::mtext(sprintf("%.3g kWh at %.0f g/kWh; about %.3g m by car, %.3g tree-hours", tot_kwh, gpk,
                          1000 * eq$car_km, 24 * 30 * eq$tree_months),
                  side = 3, line = 0.2, cex = 0.75 * graphics::par("cex"), col = "#555555")
  invisible(data.frame(quantity = names(comp), value = unname(comp), unit = "g", stringsAsFactors = FALSE))
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
  if (is.unsorted(x, strictly = TRUE) || is.unsorted(y, strictly = TRUE)) {
    stop("`x` and `y` must be strictly increasing receptor coordinates", call. = FALSE)
  }
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
  graphics::image(xs, ys, ff, col = cols, xlab = "x (m)", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, x$title %||% "Concentration field"))
  .bl_ylab("y (m)")
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
                    xlab = "x", ylab = "", main = "", ...)
    .bl_title(.bl_main(main, "Particles over the counting grid"))
    .bl_ylab("y")
    graphics::points(x$x, x$y, pch = 16, cex = 0.4, col = grDevices::adjustcolor(cols, 0.5))
  } else {
    graphics::plot(x$x, x$y, pch = 16, cex = 0.5, col = grDevices::adjustcolor(cols, 0.5),
                   xlab = "x", ylab = "", main = "", ...)
    .bl_ylab("y")
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
  graphics::plot(d$x, d$y, type = "n", xlab = "Period", ylab = "",
                 ylim = range(c(0, d$y, x$fitted), finite = TRUE),
                 main = "",
                 ...)
  .bl_ylab("Count")
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
  on.exit(.bl_panels_abort(), add = TRUE)
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
  if (is.data.frame(x)) {
    # a Lorenz curve runs from the origin along increasing shares; a hand-made frame in any
    # other order drew a zig-zag
    d <- d[order(d$population, d$value), , drop = FALSE]
    if (any(diff(d$value) < 0) || any(d$population < 0 | d$population > 1 | d$value < 0 | d$value > 1, na.rm = TRUE)) {
      stop("`x` must be a Lorenz frame: cumulative population and value shares in [0, 1], both non-decreasing",
           call. = FALSE)
    }
  }
  # lorenz() starts its curve at the origin; a hand-made frame may not
  if (!nrow(d) || d$population[1L] != 0 || d$value[1L] != 0) {
    d <- rbind(data.frame(population = 0, value = 0), d)
  }
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(d$population, d$value, type = "n", xlim = c(0, 1), ylim = c(0, 1),
                 xlab = "", ylab = "",
                 main = "",
                 ...)
  .bl_ylab("Cumulative share of the total")
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
  if (any(expected <= 0)) stop("`expected` must be positive", call. = FALSE)
  if (!is.numeric(levels) || !length(levels) || any(!is.finite(levels)) || any(levels <= 0 | levels >= 1)) {
    stop("`levels` must be probabilities strictly between 0 and 1", call. = FALSE)
  }
  if (!is.numeric(target) || length(target) != 1L || !is.finite(target) || target <= 0) {
    stop("`target` must be a single positive number", call. = FALSE)
  }
  if (length(observed) != length(expected)) stop("`observed` and `expected` must be the same length", call. = FALSE)
  if (!is.null(area) && length(area) != length(observed)) {
    stop("`area` must have one label per point (recycling would mislabel the areas)", call. = FALSE)
  }
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
  graphics::plot(expected, ratio, type = "n", xlab = "Expected count", ylab = "",
                 ylim = range(c(ratio, lim$lower, lim$upper), finite = TRUE),
                 main = if (is.null(main)) "Funnel plot" else main, ...)
  .bl_ylab("Observed / expected")
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
