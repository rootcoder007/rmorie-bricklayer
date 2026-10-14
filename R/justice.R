# SPDX-License-Identifier: AGPL-3.0-or-later
# Courts and police-reported crime: the flow of cases through a court, the time cases take,
# the mix of ways they end, where incidents cluster and whether they repeat close in space
# and time. Each function takes the published counts (or the incident points) as they come,
# returns a classed result with print() and plot() methods, and states the assumption it
# rests on in its documentation.

# ---- shared ---------------------------------------------------------------------------------

# counts as numbers: finite, non-negative, one per period
.jx_counts <- function(x, what, n = NULL, allow_na = FALSE) {
  x <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (!is.null(n) && length(x) != n) {
    stop(sprintf("`%s` must have %d value%s (one per period), got %d", what, n,
                 if (n == 1L) "" else "s", length(x)), call. = FALSE)
  }
  if (!allow_na && anyNA(x)) stop(sprintf("`%s` has missing values", what), call. = FALSE)
  ok <- x[!is.na(x)]
  if (any(!is.finite(ok)) || any(ok < 0)) {
    stop(sprintf("`%s` must be finite, non-negative counts", what), call. = FALSE)
  }
  x
}

.jx_conf <- function(conf_level) {
  conf_level <- .rmbl_num(conf_level, "conf_level")
  if (length(conf_level) != 1L || is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must be a single number between 0 and 1", call. = FALSE)
  }
  conf_level
}

# The exact conditional interval for the ratio a / b of two Poisson counts over the same
# exposure: given a + b, a is binomial with p = r / (1 + r), and the Clopper-Pearson limits
# for p map to r = p / (1 - p).
.jx_ratio_ci <- function(a, b, conf_level) {
  alpha <- 1 - conf_level
  lo <- ifelse(a == 0, 0, stats::qbeta(alpha / 2, a, b + 1))
  hi <- ifelse(b == 0, 1, stats::qbeta(1 - alpha / 2, a + 1, b))
  bad <- is.na(a) | is.na(b) | (a + b) == 0
  lo[bad] <- NA_real_
  hi[bad] <- NA_real_
  list(lower = lo / (1 - lo), upper = ifelse(hi >= 1, Inf, hi / (1 - hi)))
}

.jx_period <- function(period, n) {
  if (is.null(period)) return(seq_len(n))
  if (length(period) != n) stop(sprintf("`period` must have %d values, got %d", n, length(period)), call. = FALSE)
  if (anyNA(period)) stop("`period` has missing values", call. = FALSE)
  if (anyDuplicated(period)) stop("`period` has repeated values; give one row per period", call. = FALSE)
  period
}

# x positions for periods: numbers as they are, dates as dates, "YYYY-MM" as month starts,
# anything else in the order given
.jx_period_x <- function(p) {
  if (is.numeric(p) || inherits(p, "Date")) return(p)
  p <- as.character(p)
  if (all(grepl("^[0-9]{4}-[0-9]{2}$", p))) return(as.Date(paste0(p, "-01")))
  if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", p))) return(as.Date(p))
  seq_along(p)
}

#' Court and police data shipped with the package
#'
#' Small excerpts of published court and police statistics, in
#' \code{inst/extdata}, used by the examples, tests and the
#' \code{courts-and-crime} vignette. Each is a faithful copy of published
#' numbers (no value altered, no row invented); the full tables, every
#' edition and location, are on the package's data hub
#' (\code{\link{bricklayer_data_load}}, collections \code{ocj_statistics}
#' and \code{tps_open_data}).
#'
#' \describe{
#' \item{\code{ocj_flow_ontario.csv}}{Ontario Court of Justice, criminal
#'   clearance-rate statistics, province-wide, monthly from April 2024 to
#'   March 2026 (the 2026 edition): \code{month}, cases \code{received},
#'   cases \code{disposed}, cases \code{pending} (net of bench warrants).}
#' \item{\code{ocj_time_to_disposition.csv}}{The same months from the
#'   disposition-rate statistics: the shares of cases disposed in under 10
#'   months, 10-15, 15-18 and over 18 months (cases without bench
#'   warrants), and the average days to disposition.}
#' \item{\code{ocj_dispositions.csv}}{Province-wide criminal cases
#'   disposed by how they ended, one row per calendar year 2012-2019,
#'   2021, 2022, 2024 and 2025; each row adds to the year's published
#'   total. The 2020 edition covers October to September and the 2026
#'   edition April to March; the 2023 edition publishes no Toronto figures,
#'   so it has no province-wide row.}
#' \item{\code{ocj_offence_groups.csv}}{The same years by offence group:
#'   cases received and disposed. The groups add to each year's
#'   province-wide total.}
#' \item{\code{ocj_courts.csv}}{The same years by court, with
#'   \code{court_series}, which names Toronto's courthouses "Toronto"
#'   throughout: from 2023 the Court publishes Toronto as one location (the
#'   new Toronto courthouse consolidated its criminal courts that year).
#'   Each year's courts add to the province-wide total.}
#' \item{\code{tps_break_enter_d14_2024.csv}}{Toronto Police Service
#'   Break and Enter open data, every break and enter that occurred in
#'   2024 in division D14, one row per occurrence (508): \code{event_id},
#'   occurrence date, premises type, the published longitude and
#'   latitude (which the Service offsets to the nearest intersection),
#'   and \code{offence_records}, the number of offence records the
#'   Service publishes for the occurrence (five have two). Built by
#'   \code{data-raw/tps_break_enter_d14_2024.R} in the source package.}
#' }
#'
#' @source Ontario Court of Justice, court statistics,
#'   \url{https://www.ontariocourts.ca/ocj/statistics/} (retrieved
#'   2026-10-13), editions 2012 to 2026, published by the Court for
#'   public use. Toronto Police Service, Public Safety Data Portal,
#'   dataset "Break and Enter Open Data", \url{https://data.tps.ca/}
#'   (retrieved 2026-10-13); contains information licensed under the
#'   Open Government Licence - Toronto Police Service. See
#'   \code{inst/COPYRIGHTS}.
#' @name justice-data
#' @seealso \code{\link{case_flow}}, \code{\link{life_table}},
#'   \code{\link{disposition_mix}}, \code{\link{clearance_decomposition}},
#'   \code{\link{crime_density}}, \code{\link{knox_test}}.
#' @examples
#' f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
#'                           package = "rmoriebricklayer"))
#' head(f)
#' c <- read.csv(system.file("extdata", "ocj_courts.csv",
#'                           package = "rmoriebricklayer"))
#' tapply(c$disposed, c$year, sum)
NULL

# ---- case flow --------------------------------------------------------------------------------

#' Case flow through a court: clearance, backlog and time to clear
#'
#' Turns the counts a court publishes each period -- cases received, cases
#' disposed and, when it is published, cases pending -- into the measures
#' used to judge whether a court is keeping up: the clearance rate (cases
#' disposed per case received), its rolling value over a window, the net
#' flow into the inventory and, with the pending count, the number of
#' periods the current inventory would take to clear at the recent pace of
#' disposition.
#'
#' @param received Cases received (new cases), one per period, in time
#'   order.
#' @param disposed Cases disposed, one per period.
#' @param pending Optional cases pending at the end of each period.
#' @param period Optional period labels: numbers, dates, or
#'   \code{"YYYY-MM"} strings (which the plot draws on a date axis).
#' @param window Periods in the rolling clearance rate and in the pace
#'   behind \code{periods_to_clear}. Default 12, a year of months.
#' @param conf_level Confidence level for the intervals. Default 0.95.
#'
#' @return A data frame of class \code{rmbl_case_flow}, one row per period:
#'   \code{period}, \code{received}, \code{disposed}, \code{clearance} with
#'   \code{lower} and \code{upper}, \code{net} (received less disposed:
#'   positive grows the inventory), \code{rolling_clearance} with
#'   \code{rolling_lower} and \code{rolling_upper} (\code{NA} until a full
#'   window is available), and either \code{pending},
#'   \code{pending_change} and \code{periods_to_clear}, or, without
#'   \code{pending}, \code{cumulative_net} (the inventory change since the
#'   first period).
#'
#' @details
#' A clearance rate above 1 means the court disposed of more cases than it
#' received, so its inventory fell. The interval treats received and
#' disposed as Poisson counts over the same period: given their sum, the
#' disposed count is binomial, and the exact (Clopper-Pearson) limits for
#' that proportion give exact limits for the ratio. The interval measures
#' the period-to-period noise of counts this size; it does not make
#' received and disposed the same cases, which they are not (a case
#' disposed this month was usually received months before).
#'
#' \code{periods_to_clear} divides the pending inventory by the mean
#' number disposed over the last \code{window} periods (fewer at the start
#' of the series). The published pending count need not equal the previous
#' count plus the net flow -- courts reactivate cases on bench warrants and
#' transfer them -- so \code{pending_change} is reported next to
#' \code{net} rather than derived from it.
#'
#' @references
#' Ostrom, B. J. and Hanson, R. A. (1999). \emph{Efficiency, Timeliness,
#' and Quality: A New Perspective from Nine State Criminal Trial Courts}.
#' National Center for State Courts, Williamsburg, VA. (Clearance rate and
#' time-to-disposition measures.)
#'
#' Ulm, K. (1990). A simple method to calculate the confidence interval of
#' a standardized mortality ratio. \emph{American Journal of Epidemiology},
#' 131(2), 373-375. (Exact limits for a ratio of Poisson counts through the
#' beta distribution.)
#'
#' @seealso \code{\link{life_table}}, \code{\link{disposition_mix}},
#'   \code{\link{stock_flow}} for custody populations.
#' @examples
#' f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
#'                           package = "rmoriebricklayer"))
#' cf <- case_flow(f$received, f$disposed, pending = f$pending, period = f$month)
#' cf
#' plot(cf)
#' @export
case_flow <- function(received, disposed, pending = NULL, period = NULL, window = 12L,
                      conf_level = 0.95) {
  received <- .jx_counts(received, "received")
  n <- length(received)
  if (!n) stop("`received` is empty", call. = FALSE)
  disposed <- .jx_counts(disposed, "disposed", n)
  if (!is.null(pending)) pending <- .jx_counts(pending, "pending", n)
  period <- .jx_period(period, n)
  window <- .rmbl_num(window, "window", integer = TRUE)
  if (length(window) != 1L || is.na(window) || window < 1L) {
    stop("`window` must be a single whole number of at least 1", call. = FALSE)
  }
  conf_level <- .jx_conf(conf_level)
  ci <- .jx_ratio_ci(disposed, received, conf_level)
  clearance <- ifelse(received > 0, disposed / received, NA_real_)
  roll <- function(v) {
    cs <- cumsum(v)
    out <- rep(NA_real_, n)
    if (n >= window) out[window:n] <- cs[window:n] - c(0, cs)[seq_len(n - window + 1L)]
    out
  }
  rr <- roll(received)
  rd <- roll(disposed)
  rci <- .jx_ratio_ci(rd, rr, conf_level)
  out <- data.frame(period = period, received = received, disposed = disposed,
                    clearance = clearance, lower = ci$lower, upper = ci$upper,
                    net = received - disposed,
                    rolling_clearance = ifelse(!is.na(rr) & rr > 0, rd / rr, NA_real_),
                    rolling_lower = rci$lower, rolling_upper = rci$upper,
                    stringsAsFactors = FALSE)
  if (!is.null(pending)) {
    pace <- vapply(seq_len(n), function(i) mean(disposed[max(1L, i - window + 1L):i]), numeric(1))
    out$pending <- pending
    out$pending_change <- c(NA_real_, diff(pending))
    out$periods_to_clear <- ifelse(pace > 0, pending / pace, NA_real_)
  } else {
    out$cumulative_net <- cumsum(out$net)
  }
  attr(out, "case_flow") <- list(window = window, conf_level = conf_level,
                                 total_received = sum(received), total_disposed = sum(disposed))
  class(out) <- c("rmbl_case_flow", "data.frame")
  out
}

#' @export
print.rmbl_case_flow <- function(x, ...) {
  m <- attr(x, "case_flow")
  # a subset (x[1:3, ]) keeps the class but not the summary it was printed with
  if (is.null(m)) {
    print(as.data.frame(unclass(x), stringsAsFactors = FALSE), ...)
    return(invisible(x))
  }
  overall <- m$total_disposed / m$total_received
  ci <- .jx_ratio_ci(m$total_disposed, m$total_received, m$conf_level)
  notes <- sprintf("Over all %d periods: %s received, %s disposed, clearance %.3f (%.3f to %.3f)",
                   nrow(x), format(m$total_received, big.mark = ","), format(m$total_disposed, big.mark = ","),
                   overall, ci$lower, ci$upper)
  if (!is.null(x$pending)) {
    notes <- c(notes, sprintf("Pending at the end: %s, about %.1f periods of disposition at the last %d-period pace",
                              format(utils::tail(x$pending, 1L), big.mark = ","),
                              utils::tail(x$periods_to_clear, 1L), m$window))
  }
  show <- as.data.frame(x)[, intersect(c("period", "received", "disposed", "clearance", "lower", "upper", "net",
                                          "rolling_clearance", "pending", "periods_to_clear", "cumulative_net"),
                                        names(x))]
  for (v in c("clearance", "lower", "upper", "rolling_clearance")) show[[v]] <- round(show[[v]], 3)
  if (!is.null(show$periods_to_clear)) show$periods_to_clear <- round(show$periods_to_clear, 1)
  .rmbl_print_table(sprintf("Case flow, %g%% exact intervals, %d-period rolling window",
                            100 * m$conf_level, m$window), show, notes = notes, ...)
  invisible(x)
}

# fill between two series in two colours by sign, splitting segments where they cross
.jx_fill_between <- function(x, a, b, col_pos, col_neg) {
  x <- as.numeric(x)
  for (i in seq_len(length(x) - 1L)) {
    d1 <- a[i] - b[i]
    d2 <- a[i + 1L] - b[i + 1L]
    if (d1 * d2 < 0) {
      f <- d1 / (d1 - d2)
      xc <- x[i] + f * (x[i + 1L] - x[i])
      yc <- a[i] + f * (a[i + 1L] - a[i])
      graphics::polygon(c(x[i], xc, x[i]), c(a[i], yc, b[i]), border = NA, col = if (d1 > 0) col_pos else col_neg)
      graphics::polygon(c(xc, x[i + 1L], x[i + 1L]), c(yc, a[i + 1L], b[i + 1L]), border = NA,
                        col = if (d2 > 0) col_pos else col_neg)
    } else {
      graphics::polygon(c(x[i], x[i + 1L], x[i + 1L], x[i]), c(a[i], a[i + 1L], b[i + 1L], b[i]),
                        border = NA, col = if (d1 + d2 >= 0) col_pos else col_neg)
    }
  }
  invisible(NULL)
}

.jx_xaxis <- function(px) {
  if (inherits(px, "Date")) graphics::axis.Date(1, px) else graphics::axis(1)
}

#' @rdname plot-methods
#' @export
plot.rmbl_case_flow <- function(x, ..., what = c("flow", "clearance"), main = NULL, col = NULL, palette = NULL) {
  what <- match.arg(what, c("flow", "clearance"), several.ok = TRUE)
  px <- .jx_period_x(x$period)
  cols <- .bl_cols(2, col, palette)
  if (length(what) > 1L) {
    op0 <- graphics::par(no.readonly = TRUE)
    on.exit(graphics::par(op0), add = TRUE)
    .bl_panels_begin(length(what))
    on.exit(.bl_panels_abort(), add = TRUE)
  }
  for (w in what) {
    if (w == "flow") {
      ys <- c(x$received, x$disposed)
      op <- .bl_par(ys)
      graphics::plot(px, x$received, type = "n", ylim = range(ys, finite = TRUE), xaxt = "n",
                     xlab = "Period", ylab = "", main = "", ...)
      .bl_ylab("Cases")
      .jx_xaxis(px)
      .bl_title(.bl_main(if (length(what) == 1L) main else NULL,
                         if (all(graphics::par("pin") >= c(2.6, 1.8))) "Cases received and disposed" else
                           "Received (dashed) and disposed"))
      .bl_grid(NULL)
      # disposed above received (inventory falling) in the first colour, below in the second
      .jx_fill_between(px, x$disposed, x$received, grDevices::adjustcolor(cols[1L], 0.25),
                       grDevices::adjustcolor(cols[2L], 0.25))
      graphics::lines(px, x$received, col = "#333333", lwd = 2, lty = 2)
      graphics::lines(px, x$disposed, col = grDevices::adjustcolor(cols[1L], 0.25), lwd = 6)
      graphics::lines(px, x$disposed, col = cols[1L], lwd = 2.2)
      # a key over a panel smaller than about 2.6 by 1.8 inches hides the lines it explains; the
      # title says which line is which instead
      if (all(graphics::par("pin") >= c(2.6, 1.8))) {
        graphics::legend("bottomleft", c("received", "disposed", "inventory fell", "inventory grew"),
                         col = c("#333333", cols[1L], NA, NA), lty = c(2, 1, NA, NA), lwd = 2,
                         fill = c(NA, NA, grDevices::adjustcolor(cols[1L], 0.25),
                                  grDevices::adjustcolor(cols[2L], 0.25)),
                         border = NA, bty = "n", cex = 0.75)
      }
    } else {
      ys <- c(x$lower, x$upper, x$clearance, 1)
      op <- .bl_par(ys)
      graphics::plot(px, x$clearance, type = "n", ylim = range(ys, finite = TRUE), xaxt = "n",
                     xlab = "Period", ylab = "", main = "", ...)
      .bl_ylab("Disposed per case received")
      .jx_xaxis(px)
      .bl_title(.bl_main(if (length(what) == 1L) main else NULL, "Clearance rate"))
      .bl_grid(NULL)
      ok <- is.finite(x$lower) & is.finite(x$upper)
      if (any(ok)) {
        graphics::polygon(c(px[ok], rev(px[ok])), c(x$lower[ok], rev(x$upper[ok])), border = NA,
                          col = grDevices::adjustcolor(cols[1L], 0.2))
      }
      graphics::abline(h = 1, lty = 2, col = "#666666")
      graphics::lines(px, x$clearance, col = cols[1L], lwd = 1.5)
      graphics::points(px, x$clearance, pch = 21, bg = cols[1L], col = "white", lwd = 0.8, cex = 0.9)
      if (any(is.finite(x$rolling_clearance))) graphics::lines(px, x$rolling_clearance, col = cols[2L], lwd = 2.5)
    }
    graphics::par(op)
  }
  if (length(what) > 1L) {
    .bl_panels_end()
    if (!is.null(main)) graphics::mtext(main, side = 3, outer = TRUE, line = -1.2, font = 2, col = "#1F2430")
  }
  invisible(as.data.frame(x))
}

# ---- grouped time to an event: the actuarial life table --------------------------------------

#' Life table for grouped times: how long cases take
#'
#' The actuarial (Cutler-Ederer) life table for times published only in
#' bands -- for example the share of court cases disposed within 10
#' months, between 10 and 15 months, and so on. It gives, at the end of
#' each band, the proportion still open (the survival function) with a
#' Greenwood confidence interval, the hazard within the band, and the
#' median time.
#'
#' @param breaks Band edges, increasing, starting at the time origin:
#'   \code{c(0, 10, 15, 18, Inf)} for the four bands above. The last edge
#'   may be \code{Inf} (an open band). Or band labels such as
#'   \code{c("Under 10", "10-15", "15-18", "Over 18")}, read with
#'   \code{\link{parse_bands}}.
#' @param events Cases that ended in each band (counts, or expected
#'   counts such as a published share times the number of cases).
#' @param censored Cases withdrawn from observation in each band without
#'   the event (still open when the data were drawn); one value or one per
#'   band. Default 0.
#' @param conf_level Confidence level. Default 0.95.
#' @param conf_type Scale of the interval: \code{"log-log"} (the default,
#'   which keeps the limits inside 0 to 1), \code{"log"} or \code{"plain"}.
#'
#' @return A data frame of class \code{rmbl_life_table}, one row per band:
#'   \code{lower}, \code{upper} (the band edges), \code{entering},
#'   \code{events}, \code{censored}, \code{at_risk} (entering less half the
#'   censored), \code{q} (conditional probability of the event in the
#'   band), \code{survival} at the end of the band with \code{se},
#'   \code{conf_lower} and \code{conf_upper}, \code{hazard} (events per
#'   unit time within the band; \code{NA} for an open band), and the
#'   attribute \code{median}.
#'
#' @details
#' Within a band the censored cases are assumed to have been at risk for
#' half of it, so the number at risk is \eqn{n'_j = n_j - c_j/2}; the
#' conditional probability of the event is \eqn{q_j = d_j / n'_j} and the
#' survival at the end of band \eqn{j} is \eqn{\prod_{i \le j} (1 - q_i)}.
#' Greenwood's formula gives
#' \eqn{\mathrm{Var}(\hat S_j) = \hat S_j^2 \sum_{i \le j} q_i / (n'_i (1 - q_i))}.
#' With no censoring the table equals the Kaplan-Meier estimate at the
#' band edges, and the Greenwood variance equals the one
#' \code{survival::survfit()} reports. The hazard in a closed band is
#' \eqn{d_j / (w_j (n'_j - d_j / 2))} for band width \eqn{w_j}. The median
#' is interpolated linearly inside the band where survival crosses one
#' half, which assumes events are spread evenly across that band; when the
#' crossing falls in an open band, the median is reported as greater than
#' its lower edge.
#'
#' Court statistics that count only disposed cases describe time to
#' disposition among cases that were disposed, with no censoring; cases
#' still pending are not in them, so the survival function describes the
#' disposed cohort, not every case received.
#'
#' @references
#' Cutler, S. J. and Ederer, F. (1958). Maximum utilization of the life
#' table method in analyzing survival. \emph{Journal of Chronic
#' Diseases}, 8(6), 699-712.
#'
#' Greenwood, M. (1926). \emph{The Natural Duration of Cancer}. Reports on
#' Public Health and Medical Subjects 33. HMSO, London.
#'
#' Lee, E. T. and Wang, J. W. (2003). \emph{Statistical Methods for
#' Survival Data Analysis}, 3rd ed. Wiley, Hoboken, NJ. Chapter 4.
#'
#' @seealso \code{\link{case_flow}}, \code{\link{parse_bands}}.
#' @examples
#' d <- read.csv(system.file("extdata", "ocj_time_to_disposition.csv",
#'                           package = "rmoriebricklayer"))
#' f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
#'                           package = "rmoriebricklayer"))
#' last <- nrow(d)
#' shares <- unlist(d[last, c("under_10", "m10_15", "m15_18", "over_18")])
#' lt <- life_table(c(0, 10, 15, 18, Inf), events = shares * f$disposed[last])
#' lt
#' plot(lt)
#' @export
life_table <- function(breaks, events, censored = 0, conf_level = 0.95,
                       conf_type = c("log-log", "log", "plain")) {
  conf_type <- match.arg(conf_type)
  conf_level <- .jx_conf(conf_level)
  if (is.character(breaks) || is.factor(breaks)) {
    # times, not head counts: "Under 10" ends at 10, and "Over 18" starts there
    b <- parse_bands(as.character(breaks), integer_scale = FALSE)
    lo <- b$lower
    # an open first band ("Under 10") starts at the time origin
    if (isTRUE(b$open_lower[1L]) && is.na(lo[1L])) lo[1L] <- 0
    bad <- is.na(lo) | (is.na(b$upper) & !b$open_upper)
    if (any(bad)) stop(sprintf("could not read the band \"%s\"", b$label[bad][1L]), call. = FALSE)
    if (any(utils::head(b$open_upper, -1L))) stop("only the last band may be open (\"Over ...\")", call. = FALSE)
    hi <- ifelse(is.na(b$upper), Inf, b$upper)
    if (any(utils::head(hi, -1L) != lo[-1L])) {
      stop("the bands must be contiguous (each band starts where the one before ends)", call. = FALSE)
    }
  } else {
    breaks <- .rmbl_num_input(breaks, "breaks", allow_null = FALSE)
    if (length(breaks) < 2L || anyNA(breaks) || is.unsorted(breaks, strictly = TRUE)) {
      stop("`breaks` must be at least two increasing band edges", call. = FALSE)
    }
    if (!is.finite(breaks[1L]) || any(!is.finite(utils::head(breaks, -1L)))) {
      stop("only the last of `breaks` may be infinite", call. = FALSE)
    }
    lo <- utils::head(breaks, -1L)
    hi <- breaks[-1L]
  }
  k <- length(lo)
  d <- .jx_counts(events, "events", k)
  w <- .jx_counts(if (length(censored) == 1L) rep(censored, k) else censored, "censored", k)
  total <- sum(d) + sum(w)
  if (total <= 0) stop("there are no cases (`events` and `censored` are all zero)", call. = FALSE)
  entering <- total - c(0, cumsum(d + w))[seq_len(k)]
  at_risk <- entering - w / 2
  q <- ifelse(at_risk > 0, pmin(d / at_risk, 1), NA_real_)
  # entering is built by subtraction, so a band holding every remaining case can come out a
  # rounding error short of q = 1; that is q = 1
  q[!is.na(q) & q > 1 - 1e-9] <- 1
  surv <- cumprod(1 - ifelse(is.na(q), 0, q))
  gw <- cumsum(ifelse(at_risk > 0 & q < 1, d / (at_risk * (at_risk - d)), NA_real_))
  se <- surv * sqrt(gw)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  lims <- switch(conf_type,
    plain = list(pmax(surv - z * se, 0), pmin(surv + z * se, 1)),
    log = list(surv * exp(-z * sqrt(gw)), pmin(surv * exp(z * sqrt(gw)), 1)),
    `log-log` = {
      s <- sqrt(gw) / log(surv)
      list(surv^exp(-z * s), surv^exp(z * s))
    })
  lims <- lapply(lims, function(v) ifelse(surv > 0 & surv < 1 & is.finite(gw), v, NA_real_))
  width <- hi - lo
  hazard <- ifelse(is.finite(width) & at_risk - d / 2 > 0, d / (width * (at_risk - d / 2)), NA_real_)
  s0 <- c(1, utils::head(surv, -1L))
  j <- which(surv <= 0.5)[1L]
  med <- if (is.na(j)) {
    structure(Inf, note = sprintf("over %s: survival never falls to one half", format(utils::tail(hi, 1L))))
  } else if (!is.finite(hi[j])) {
    structure(Inf, note = sprintf("over %s (inside the open band)", format(lo[j])))
  } else {
    lo[j] + width[j] * (s0[j] - 0.5) / (s0[j] - surv[j])
  }
  out <- data.frame(lower = lo, upper = hi, entering = entering, events = d, censored = w,
                    at_risk = at_risk, q = q, survival = surv, se = se,
                    conf_lower = lims[[1L]], conf_upper = lims[[2L]], hazard = hazard)
  attr(out, "median") <- med
  attr(out, "life_table") <- list(conf_level = conf_level, conf_type = conf_type)
  class(out) <- c("rmbl_life_table", "data.frame")
  out
}

#' @export
print.rmbl_life_table <- function(x, ...) {
  m <- attr(x, "life_table")
  if (is.null(m)) {
    print(as.data.frame(unclass(x), stringsAsFactors = FALSE), ...)
    return(invisible(x))
  }
  med <- attr(x, "median")
  show <- as.data.frame(x)
  for (v in c("q", "survival", "se", "conf_lower", "conf_upper")) show[[v]] <- round(show[[v]], 4)
  show$hazard <- signif(show$hazard, 4)
  medtxt <- if (is.finite(med)) sprintf("Median time: %.3g (linear within its band)", med) else
    paste("Median time:", attr(med, "note"))
  .rmbl_print_table(sprintf("Life table (actuarial), %g%% %s Greenwood interval", 100 * m$conf_level, m$conf_type),
                    show, notes = medtxt, ...)
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_life_table <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  cols <- .bl_cols(2, col, palette)
  hi <- x$upper
  open <- !is.finite(hi)
  # an open last band is drawn a band-width past its lower edge, marked with an arrow
  span <- if (nrow(x) > 1L) stats::median(diff(c(x$lower[1L], hi[!open]))) else 1
  hi[open] <- x$lower[open] + span
  tx <- c(x$lower[1L], hi)
  sv <- c(1, x$survival)
  lo <- c(1, x$conf_lower)
  up <- c(1, x$conf_upper)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(tx, sv, type = "n", ylim = c(0, 1), xlab = "Time", ylab = "", main = "", ...)
  .bl_ylab("Proportion still open")
  med <- attr(x, "median")
  .bl_title(.bl_main(main, if (is.finite(med)) sprintf("Life table: median %.3g", med) else "Life table"))
  .bl_grid(NULL)
  ok <- is.finite(lo) & is.finite(up)
  if (sum(ok) > 1L) {
    graphics::polygon(c(tx[ok], rev(tx[ok])), c(lo[ok], rev(up[ok])), border = NA,
                      col = grDevices::adjustcolor(cols[1L], 0.2))
  }
  kk <- length(tx)
  closed <- if (any(open)) seq_len(kk - 1L) else seq_len(kk)
  graphics::polygon(c(tx[closed][1L], tx[closed], tx[closed][sum(closed)]), c(0, sv[closed], 0),
                    col = grDevices::adjustcolor(cols[1L], 0.16), border = NA)
  graphics::lines(tx[closed], sv[closed], col = grDevices::adjustcolor(cols[1L], 0.25), lwd = 7)
  graphics::lines(tx[closed], sv[closed], col = cols[1L], lwd = 2.5)
  graphics::points(tx[closed], sv[closed], pch = 21, bg = cols[1L], col = "white", lwd = 1.5, cex = 1.5)
  # an open band has no end: its fall to zero is drawn dashed, over a nominal width
  if (any(open)) graphics::lines(tx[(kk - 1L):kk], sv[(kk - 1L):kk], col = cols[1L], lwd = 2, lty = 2)
  graphics::abline(h = 0.5, lty = 3, col = "#666666")
  if (is.finite(med)) graphics::abline(v = med, lty = 2, col = cols[2L])
  if (any(open)) graphics::arrows(utils::tail(tx, 2L)[1L], 0.02, utils::tail(tx, 1L), 0.02, length = 0.08,
                                  col = "#666666")
  invisible(data.frame(time = tx, survival = sv, conf_lower = lo, conf_upper = up))
}

# ---- composition: how cases end ------------------------------------------------------------

#' The mix of outcomes over time, with simultaneous intervals and trend tests
#'
#' For a table of counts -- periods in rows, outcomes in columns, such as
#' cases withdrawn, pleaded guilty, or tried -- gives each outcome's share
#' of its period with Goodman's simultaneous confidence intervals, tests
#' whether the mix is the same in every period, and tests each outcome for
#' a linear trend in its share.
#'
#' @param counts A matrix or data frame of non-negative counts, one row per
#'   period and one column per outcome. Columns that are not numeric are
#'   refused; pass only the outcome columns.
#' @param period Optional period labels (default: the row names, or
#'   \code{1:nrow(counts)}).
#' @param scores Numeric scores for the periods in the trend tests.
#'   Default: \code{1:nrow(counts)}, i.e. equally spaced.
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A list of class \code{rmbl_disposition_mix}: \code{shares}, a long
#'   data frame (\code{period}, \code{outcome}, \code{count}, \code{total},
#'   \code{share}, \code{lower}, \code{upper}); \code{homogeneity}, the
#'   Pearson chi-square test that every period has the same mix (with
#'   Cramer's V); \code{trend}, one row per outcome with the
#'   Cochran-Armitage trend statistic, its p-value, the Holm-adjusted
#'   p-value, and the change in share from the first to the last period.
#'
#' @details
#' Goodman's intervals hold for all \eqn{k} shares of a period at once: with
#' \eqn{A} the upper \eqn{\alpha/k} point of the chi-square distribution
#' on one degree of freedom, the limits for a share \eqn{n_i / N} are
#' \deqn{\frac{A + 2 n_i \pm \sqrt{A (A + 4 n_i (N - n_i) / N)}}{2 (N + A)}.}
#'
#' The trend test for each outcome is the Cochran-Armitage test of its
#' count against the period totals (\code{stats::prop.trend.test()}); the
#' Holm adjustment covers the \eqn{k} tests. Counts of court cases are
#' large, so these tests detect small changes; the shares and their
#' intervals show whether a change is large enough to matter.
#'
#' @references
#' Goodman, L. A. (1965). On simultaneous confidence intervals for
#' multinomial proportions. \emph{Technometrics}, 7(2), 247-254.
#'
#' Armitage, P. (1955). Tests for linear trends in proportions and
#' frequencies. \emph{Biometrics}, 11(3), 375-386.
#'
#' Holm, S. (1979). A simple sequentially rejective multiple test
#' procedure. \emph{Scandinavian Journal of Statistics}, 6(2), 65-70.
#'
#' @seealso \code{\link{share}} for one period's shares with Wilson
#'   intervals.
#' @examples
#' d <- read.csv(system.file("extdata", "ocj_dispositions.csv",
#'                           package = "rmoriebricklayer"))
#' mix <- disposition_mix(d[, -(1:2)], period = d$year)
#' mix
#' plot(mix)
#' @export
disposition_mix <- function(counts, period = NULL, scores = NULL, conf_level = 0.95) {
  if (is.data.frame(counts)) {
    bad <- names(counts)[!vapply(counts, is.numeric, logical(1))]
    if (length(bad)) {
      stop(sprintf("`counts` has a column that is not numeric (%s); pass only the outcome columns", bad[1L]),
           call. = FALSE)
    }
    counts <- as.matrix(counts)
  }
  if (!is.matrix(counts) || !is.numeric(counts)) stop("`counts` must be a numeric matrix or data frame", call. = FALSE)
  if (nrow(counts) < 1L || ncol(counts) < 2L) {
    stop("`counts` needs at least one period and two outcomes", call. = FALSE)
  }
  .jx_counts(as.vector(counts), "counts")
  conf_level <- .jx_conf(conf_level)
  nt <- nrow(counts)
  k <- ncol(counts)
  outcome <- colnames(counts) %||% paste0("outcome_", seq_len(k))
  if (is.null(period)) period <- rownames(counts) %||% seq_len(nt)
  period <- .jx_period(period, nt)
  tot <- rowSums(counts)
  if (any(tot <= 0)) stop(sprintf("period %s has no cases", format(period[tot <= 0][1L])), call. = FALSE)
  a <- stats::qchisq(1 - (1 - conf_level) / k, 1)
  ni <- as.vector(counts)
  nn <- rep(tot, times = k)
  half <- sqrt(a * (a + 4 * ni * (nn - ni) / nn))
  shares <- data.frame(period = rep(period, times = k), outcome = rep(outcome, each = nt), count = ni, total = nn,
                       share = ni / nn, lower = (a + 2 * ni - half) / (2 * (nn + a)),
                       upper = (a + 2 * ni + half) / (2 * (nn + a)), stringsAsFactors = FALSE)
  homog <- NULL
  trend <- NULL
  if (nt >= 2L) {
    keep <- colSums(counts) > 0
    m <- counts[, keep, drop = FALSE]
    e <- outer(rowSums(m), colSums(m)) / sum(m)
    x2 <- sum((m - e)^2 / e)
    df <- (nrow(m) - 1L) * (ncol(m) - 1L)
    homog <- data.frame(statistic = x2, df = df, p_value = stats::pchisq(x2, df, lower.tail = FALSE),
                        cramers_v = sqrt(x2 / (sum(m) * min(nrow(m) - 1L, ncol(m) - 1L))))
  }
  if (nt >= 3L) {
    if (is.null(scores)) scores <- seq_len(nt)
    scores <- .rmbl_num_input(scores, "scores", allow_null = FALSE)
    if (length(scores) != nt || any(!is.finite(scores)) || length(unique(scores)) < 2L) {
      stop(sprintf("`scores` must be %d finite numbers, not all equal", nt), call. = FALSE)
    }
    tr <- lapply(seq_len(k), function(j) {
      if (sum(counts[, j]) == 0 || all(counts[, j] == tot)) return(c(NA_real_, NA_real_))
      t <- suppressWarnings(stats::prop.trend.test(counts[, j], tot, score = scores))
      c(unname(t$statistic), t$p.value)
    })
    tr <- do.call(rbind, tr)
    trend <- data.frame(outcome = outcome, statistic = tr[, 1L], p_value = tr[, 2L],
                        p_holm = stats::p.adjust(tr[, 2L], "holm"),
                        change = counts[nt, ] / tot[nt] - counts[1L, ] / tot[1L], stringsAsFactors = FALSE)
    rownames(trend) <- NULL
  }
  structure(list(shares = shares, homogeneity = homog, trend = trend, period = period, outcome = outcome,
                 conf_level = conf_level), class = "rmbl_disposition_mix")
}

#' @export
print.rmbl_disposition_mix <- function(x, ...) {
  s <- x$shares
  wide <- stats::reshape(s[, c("period", "outcome", "share")], idvar = "outcome", timevar = "period",
                         direction = "wide")
  names(wide) <- sub("^share[.]", "", names(wide))
  wide[-1L] <- lapply(wide[-1L], function(v) round(v, 4))
  notes <- NULL
  if (!is.null(x$homogeneity)) {
    h <- x$homogeneity
    notes <- sprintf("Same mix in every period: chi-square %.1f on %d df, p %s, Cramer's V %.3f",
                     h$statistic, h$df, .rmbl_fmt_p(h$p_value), h$cramers_v)
  }
  .rmbl_print_table(sprintf("Outcome shares by period (%g%% Goodman simultaneous intervals in $shares)",
                            100 * x$conf_level), wide, notes = notes, ...)
  if (!is.null(x$trend)) {
    tr <- x$trend
    tr$statistic <- round(tr$statistic, 2)
    tr$p_value <- .rmbl_fmt_p(tr$p_value)
    tr$p_holm <- .rmbl_fmt_p(tr$p_holm)
    tr$change <- round(tr$change, 4)
    .rmbl_print_table("Cochran-Armitage trend in each share (Holm-adjusted)", tr, ...)
  }
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_disposition_mix <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  s <- x$shares
  nt <- length(x$period)
  k <- length(x$outcome)
  sh <- matrix(s$share, nrow = nt, ncol = k)
  cum <- cbind(0, t(apply(sh, 1L, cumsum)))
  if (nt == 1L) cum <- matrix(c(0, cumsum(sh)), nrow = 1L)
  px <- .jx_period_x(x$period)
  pxn <- as.numeric(px)
  cols <- .bl_cols(k, col, palette)
  labs <- gsub("_", " ", x$outcome)
  o <- .bl_plot_opts()
  op <- graphics::par(las = o$las, cex = o$cex, bg = o$bg,
                      bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0), col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430")
  on.exit(graphics::par(op), add = TRUE)
  # the outcome labels are drawn at 0.75 of the text size (text() scales by par("cex") as
  # strwidth() does), so the right margin is their measured width in lines plus a gap
  fit <- .bl_label_fit(labs, cex = 0.75)
  right <- max(.bl_strwidth(fit$labels, cex = 0.75), 0) / graphics::par("csi") + 1.2
  graphics::par(mar = .bl_safe_mar(c(4.2, 4.5, 3, right), o$cex))
  xr <- if (nt == 1L) pxn + c(-0.5, 0.5) else range(pxn)
  graphics::plot(xr, c(0, 1), type = "n", xaxt = "n", xlab = "Period", ylab = "", main = "", ...)
  .bl_ylab("Share of cases")
  if (inherits(px, "Date")) graphics::axis.Date(1, px) else graphics::axis(1, at = pxn, labels = x$period)
  .bl_title(.bl_main(main, "How cases ended"))
  xs <- if (nt == 1L) xr else pxn
  for (j in seq_len(k)) {
    lo <- if (nt == 1L) rep(cum[1L, j], 2L) else cum[, j]
    hi <- if (nt == 1L) rep(cum[1L, j + 1L], 2L) else cum[, j + 1L]
    graphics::polygon(c(xs, rev(xs)), c(lo, rev(hi)), col = cols[j], border = "white", lwd = 0.5)
  }
  mid <- (cum[nt, -1L] + cum[nt, -(k + 1L)]) / 2
  # labels for bands too thin to hold text are pushed apart so they do not overprint
  gap <- 0.75 * graphics::par("cxy")[2L]
  ord <- order(mid)
  ym <- mid[ord]
  for (i in seq_along(ym)[-1L]) ym[i] <- max(ym[i], ym[i - 1L] + gap)
  # pushed past the top: the whole stack moves down, then is spread upward again from the floor
  if (max(ym) > 1) {
    ym[length(ym)] <- 1
    for (i in rev(seq_along(ym))[-1L]) ym[i] <- min(ym[i], ym[i + 1L] - gap)
  }
  # from the frame's edge, not the last period's: drawn from inside the frame, the box ran through the first letter
  graphics::text(graphics::par("usr")[2L], ym, fit$labels[ord], pos = 4, xpd = NA, cex = 0.75, col = cols[ord])
  invisible(s)
}

# ---- where incidents cluster: kernel density ------------------------------------------------

.jx_earth_km <- 6371.0088

# lon/lat to kilometres on a plane through their centre (equirectangular): within a city
# the distortion is far below the bandwidth
.jx_project <- function(lon, lat, lon0, lat0) {
  list(x = .jx_earth_km * (lon - lon0) * pi / 180 * cos(lat0 * pi / 180),
       y = .jx_earth_km * (lat - lat0) * pi / 180)
}

# The one way crime_density(), knox_test() and hotspot_persistence() put longitudes and latitudes on
# the plane: points across the antimeridian are taken on one side of it (179 and -179 degrees were
# 358 degrees apart, a 19,240 km bandwidth; review of e57fed5), the centre is the median, and an
# extent past 2,000 km, where the flat approximation stops being one, is said. Returns the
# projection (kilometres), the centre and the longitudes as used.
.jx_lonlat_plane <- function(lon, lat, caller) {
  if (length(lon) && diff(range(lon)) > 180) {
    alt <- ifelse(lon < 0, lon + 360, lon)
    if (diff(range(alt)) < diff(range(lon))) lon <- alt
  }
  lon0 <- stats::median(lon)
  lat0 <- stats::median(lat)
  p <- .jx_project(lon, lat, lon0, lat0)
  span <- max(diff(range(p$x)), diff(range(p$y)))
  if (span > 2000) {
    warning(sprintf(paste("%s(): the incidents span %.0f km; distances are taken on a flat map through their",
                          "centre, which is accurate for a city or a region, not across a continent"), caller, span),
            call. = FALSE)
  }
  list(x = p$x, y = p$y, lon0 = ((lon0 + 180) %% 360) - 180, lat0 = lat0, lon = lon)
}

# (0, 0) is how raw police exports write "no location": no incident is placed in the Gulf of Guinea
.jx_null_island <- function(lon, lat) is.finite(lon) & is.finite(lat) & lon == 0 & lat == 0

# linear binning (each point shares its weight among the four nearest grid nodes)
.jx_linbin <- function(x, y, w, gx, gy) {
  nx <- length(gx)
  ny <- length(gy)
  dx <- gx[2L] - gx[1L]
  dy <- gy[2L] - gy[1L]
  fx <- (x - gx[1L]) / dx
  fy <- (y - gy[1L]) / dy
  ix <- pmin(pmax(floor(fx), 0), nx - 2)
  iy <- pmin(pmax(floor(fy), 0), ny - 2)
  ax <- fx - ix
  ay <- fy - iy
  m <- numeric(nx * ny)
  add <- function(i, j, v) {
    s <- tapply(v, i + 1 + j * nx, sum)
    k <- as.integer(names(s))
    m[k] <<- m[k] + s
  }
  add(ix, iy, w * (1 - ax) * (1 - ay))
  add(ix + 1, iy, w * ax * (1 - ay))
  add(ix, iy + 1, w * (1 - ax) * ay)
  add(ix + 1, iy + 1, w * ax * ay)
  matrix(m, nx, ny)
}

#' Where incidents cluster: a kernel density surface
#'
#' Estimates the density of incident locations -- police-reported
#' occurrences, calls for service, addresses of people in a program -- as
#' a smooth surface in incidents per square kilometre, and the smallest
#' areas holding a given share of them (the highest-density regions). The
#' plot draws the surface as a heat map with those regions outlined.
#'
#' @param lon,lat Coordinates of the incidents: longitude and latitude in
#'   degrees (WGS84) by default, or planar coordinates in metres with
#'   \code{coords = "planar"}. Points with a missing coordinate are
#'   dropped with a message; in degrees, points at exactly (0, 0), which
#'   is how several open-data portals publish an incident with no
#'   location, are dropped too.
#' @param weights Optional non-negative weight per incident. Default 1.
#' @param bandwidth Kernel standard deviation in kilometres: one value for
#'   both directions or two (east-west, north-south). Default: Scott's
#'   normal-reference rule, \eqn{\sigma n^{-1/6}} for each direction.
#' @param n_grid Grid nodes per direction. Default 200.
#' @param coverage Shares of the incidents whose highest-density regions
#'   are reported and outlined. Default \code{c(0.5, 0.9)}.
#' @param coords \code{"lonlat"} (the default) or \code{"planar"}.
#'
#' @return A list of class \code{rmbl_density}: \code{field} (incidents per
#'   square kilometre on the grid), \code{x} and \code{y} (grid coordinates
#'   in kilometres from the centre), \code{lon} and \code{lat} (the same
#'   grid in degrees, for \code{"lonlat"}), \code{bandwidth}, \code{n},
#'   \code{dropped}, \code{points} (the projected incidents), and
#'   \code{regions}: one row per coverage share with the density
#'   \code{level} that bounds it, its \code{area_km2}, and its share of the
#'   mapped area.
#'
#' @details
#' The estimate is the Gaussian product-kernel density, computed on the
#' grid by linear binning followed by an exact discrete convolution, which
#' agrees with the direct sum to within the binning error (of order the
#' squared grid spacing over the squared bandwidth). The grid extends three
#' bandwidths past the outermost incident so the surface integrates to the
#' total weight.
#'
#' A highest-density region for share \eqn{p} is the set of grid cells
#' with the largest densities whose estimated incidents add up to \eqn{p}
#' of the total. Its area is the spatial counterpart of a concentration
#' index: when half the incidents fall in a few per cent of the mapped
#' area, they are concentrated. The bandwidth decides how sharp the
#' surface is, so it should be reported with any map; the default suits a
#' first look, not a definitive one.
#'
#' @references
#' Scott, D. W. (2015). \emph{Multivariate Density Estimation: Theory,
#' Practice, and Visualization}, 2nd ed. Wiley, Hoboken, NJ.
#'
#' Wand, M. P. (1994). Fast computation of multivariate kernel estimators.
#' \emph{Journal of Computational and Graphical Statistics}, 3(4),
#' 433-445.
#'
#' Hyndman, R. J. (1996). Computing and graphing highest density regions.
#' \emph{The American Statistician}, 50(2), 120-126.
#'
#' Chainey, S., Tompson, L. and Uhlig, S. (2008). The utility of hotspot
#' mapping for predicting spatial patterns of crime. \emph{Security
#' Journal}, 21(1-2), 4-28.
#'
#' @seealso \code{\link{knox_test}}, \code{\link{plume_field}} (the same
#'   kind of surface, for an air pollutant).
#' @examples
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' kd <- crime_density(b$lon, b$lat, n_grid = 120)
#' kd
#' plot(kd)
#' @export
crime_density <- function(lon, lat, weights = NULL, bandwidth = NULL, n_grid = 200L,
                          coverage = c(0.5, 0.9), coords = c("lonlat", "planar")) {
  coords <- match.arg(coords)
  lon <- .rmbl_num_input(lon, "lon", allow_null = FALSE)
  lat <- .rmbl_num_input(lat, "lat", allow_null = FALSE)
  if (length(lon) != length(lat)) stop("`lon` and `lat` must have the same length", call. = FALSE)
  w <- if (is.null(weights)) rep(1, length(lon)) else .jx_counts(weights, "weights", length(lon), allow_na = TRUE)
  keep <- is.finite(lon) & is.finite(lat) & !is.na(w)
  if (coords == "lonlat") {
    bad <- keep & (abs(lat) > 90 | abs(lon) > 180)
    if (any(bad)) {
      stop(sprintf(paste("coordinate %d is not a longitude and latitude in degrees (%g, %g);",
                         "planar data take coords = \"planar\""),
                   which(bad)[1L], lon[bad][1L], lat[bad][1L]), call. = FALSE)
    }
    keep <- keep & !.jx_null_island(lon, lat)
  }
  dropped <- sum(!keep)
  if (dropped) message(sprintf("crime_density(): %d incident%s without a usable location dropped", dropped,
                               if (dropped == 1L) "" else "s"))
  lon <- lon[keep]
  lat <- lat[keep]
  w <- w[keep]
  if (length(lon) < 2L || sum(w) <= 0) stop("need at least two located incidents with positive weight", call. = FALSE)
  n_grid <- .rmbl_num(n_grid, "n_grid", integer = TRUE)
  if (length(n_grid) != 1L || is.na(n_grid) || n_grid < 10L || n_grid > 2000L) {
    stop("`n_grid` must be a whole number from 10 to 2000", call. = FALSE)
  }
  coverage <- .rmbl_num_input(coverage, "coverage", allow_null = FALSE)
  if (!length(coverage) || anyNA(coverage) || any(coverage <= 0 | coverage >= 1)) {
    stop("`coverage` must be shares strictly between 0 and 1", call. = FALSE)
  }
  if (coords == "lonlat") {
    p <- .jx_lonlat_plane(lon, lat, "crime_density")
    lon0 <- p$lon0
    lat0 <- p$lat0
  } else {
    lon0 <- lat0 <- NA_real_
    p <- list(x = (lon - stats::median(lon)) / 1000, y = (lat - stats::median(lat)) / 1000)
  }
  n <- length(p$x)
  if (is.null(bandwidth)) {
    sx <- sqrt(stats::cov.wt(cbind(p$x, p$y), wt = w / sum(w))$cov[c(1L, 4L)])
    h <- sx * n^(-1 / 6)
    if (any(!is.finite(h) | h <= 0)) {
      stop("the incidents do not spread in both directions; give `bandwidth` in kilometres", call. = FALSE)
    }
  } else {
    h <- .rmbl_num_input(bandwidth, "bandwidth", allow_null = FALSE)
    if (!length(h) %in% 1:2 || any(!is.finite(h) | h <= 0)) {
      stop("`bandwidth` must be one or two positive numbers (kilometres)", call. = FALSE)
    }
    h <- rep_len(h, 2L)
    # a bandwidth past half the earth's circumference is not a distance on a map; one far wider than
    # the incidents' spread smooths them into a single blur (1e6 km was taken silently)
    if (coords == "lonlat" && any(h > 20037.5)) {
      stop("`bandwidth` is longer than half the earth's circumference (20,037 km)", call. = FALSE)
    }
    spread <- max(diff(range(p$x)), diff(range(p$y)))
    if (spread > 0 && any(h > 10 * spread)) {
      warning(sprintf("`bandwidth` (%.3g km) is over ten times the incidents' spread (%.3g km): the map is one blur",
                      max(h), spread), call. = FALSE)
    }
  }
  gx <- seq(min(p$x) - 3 * h[1L], max(p$x) + 3 * h[1L], length.out = n_grid)
  gy <- seq(min(p$y) - 3 * h[2L], max(p$y) + 3 * h[2L], length.out = n_grid)
  dx <- gx[2L] - gx[1L]
  dy <- gy[2L] - gy[1L]
  if (dx > h[1L] || dy > h[2L]) {
    warning(sprintf("the grid spacing (%.3g km) is wider than the bandwidth (%.3g km); raise `n_grid`",
                    max(dx, dy), min(h)), call. = FALSE)
  }
  cnt <- .jx_linbin(p$x, p$y, w, gx, gy)
  kx <- stats::dnorm(outer(gx, gx, "-"), sd = h[1L])
  ky <- stats::dnorm(outer(gy, gy, "-"), sd = h[2L])
  field <- kx %*% cnt %*% t(ky)
  cell <- dx * dy
  mass <- field * cell
  o <- order(mass, decreasing = TRUE)
  cm <- cumsum(mass[o]) / sum(mass)
  regions <- do.call(rbind, lapply(sort(coverage), function(cv) {
    m <- which(cm >= cv)[1L]
    data.frame(coverage = cv, level = field[o][m], area_km2 = m * cell, area_share = m / length(field))
  }))
  out <- list(field = field, x = gx, y = gy, bandwidth = h, n = n, total = sum(w), dropped = dropped,
              points = data.frame(x = p$x, y = p$y), regions = regions, coords = coords,
              centre = c(lon = lon0, lat = lat0))
  if (coords == "lonlat") {
    out$lon <- p$lon0 + gx / (.jx_earth_km * cos(lat0 * pi / 180)) * 180 / pi
    # the grid is drawn with image(), which needs increasing longitudes: a grid that runs past
    # 180 degrees (incidents near the antimeridian, 179.5 to 179.99) is wrapped only when every
    # node ends up on one side; otherwise the nodes past 180 keep their continued values
    # (180.3 is -179.7) and the map stays one piece (review of 29a55d8, F4)
    wrapped <- ((out$lon + 180) %% 360) - 180
    wrap <- !is.unsorted(wrapped, strictly = TRUE)
    if (wrap) out$lon <- wrapped
    out$lat <- lat0 + gy / .jx_earth_km * 180 / pi
    # the incidents in the grid's own frame (the same transform as the grid's nodes), so a map that
    # runs past 180 degrees keeps its points on it (30 of 60 fell off; review of 46de6a9, F4)
    plon <- p$lon0 + p$x / (.jx_earth_km * cos(lat0 * pi / 180)) * 180 / pi
    out$points$lon <- if (wrap) ((plon + 180) %% 360) - 180 else plon
    out$points$lat <- lat
  }
  class(out) <- "rmbl_density"
  out
}

#' @export
print.rmbl_density <- function(x, ...) {
  r <- x$regions
  show <- data.frame(incidents = sprintf("%g%%", 100 * r$coverage), area_km2 = signif(r$area_km2, 4),
                     share_of_mapped_area = sprintf("%.1f%%", 100 * r$area_share),
                     density_at_edge = signif(r$level, 4))
  notes <- c(sprintf("%s incidents%s; bandwidth %.3g km east-west, %.3g km north-south",
                     format(x$n, big.mark = ","),
                     if (x$dropped) sprintf(" (%d without a location dropped)", x$dropped) else "",
                     x$bandwidth[1L], x$bandwidth[2L]),
             sprintf("Peak density %.4g incidents per square kilometre", max(x$field)))
  .rmbl_print_table("Kernel density of incidents: smallest areas holding each share", show, notes = notes, ...)
  invisible(x)
}

#' @rdname plot-methods
#' @param points For \code{rmbl_density}, whether to draw the incidents
#'   over the surface.
#' @usage \method{plot}{rmbl_density}(x, ..., points = TRUE, main = NULL,
#'   col = NULL, palette = NULL)
#' @export
plot.rmbl_density <- function(x, ..., points = TRUE, main = NULL, col = NULL, palette = NULL) {
  ll <- x$coords == "lonlat"
  xs <- if (ll) x$lon else x$x
  ys <- if (ll) x$lat else x$y
  f <- x$field
  # the faintest tail is left blank so the map reads as hot spots on a plain ground
  f[f < 0.02 * max(f)] <- NA
  cols <- if (!is.null(col)) col else if (!is.null(palette)) bricklayer_palette(palette, 64) else
    grDevices::hcl.colors(64, "YlOrRd", rev = TRUE)
  op <- .bl_par(ys)
  on.exit(graphics::par(op), add = TRUE)
  asp <- if (ll) 1 / cos(x$centre[["lat"]] * pi / 180) else 1
  graphics::image(xs, ys, f, col = cols, asp = asp, useRaster = TRUE, xlab = if (ll) "Longitude" else "x (km)",
                  ylab = "", main = "", ...)
  .bl_ylab(if (ll) "Latitude" else "y (km)")
  .bl_title(.bl_main(main, sprintf("Incident density, %s incidents", format(x$n, big.mark = ","))))
  if (isTRUE(points)) {
    graphics::points(if (ll) x$points$lon else x$points$x, if (ll) x$points$lat else x$points$y,
                     pch = 16, cex = 0.3, col = grDevices::adjustcolor("#222222", 0.35))
  }
  r <- x$regions
  graphics::contour(xs, ys, x$field, levels = r$level, labels = sprintf("%g%%", 100 * r$coverage),
                    add = TRUE, col = "#222222", lwd = c(2, 1.2)[seq_len(nrow(r)) %% 2 + 1L], labcex = 0.7)
  invisible(data.frame(x = rep(xs, times = length(ys)), y = rep(ys, each = length(xs)), density = as.vector(x$field)))
}

# the y title of the Knox table sits outside its band labels, which are text, not axTicks()
.bl_knox_ylab <- function(labels) {
  o <- graphics::par(c("cex.axis", "csi", "mar", "mgp"))
  w <- max(.bl_strwidth(labels, cex = o$cex.axis), 0)
  graphics::title(ylab = "Metres apart", line = max(min(o$mgp[2L] + w / o$csi + 0.7, o$mar[2L] - 1), 0.2))
}

# ---- near repeats: the Knox test ---------------------------------------------------------------

# pairs closer than `r`: points hashed to cells of side r, each cell compared with itself and
# four of its neighbours, so every close pair is found once
.jx_close_pairs <- function(x, y, r, max_pairs) {
  cx <- floor(x / r)
  cy <- floor(y / r)
  # past 2^53 a cell index is not a whole number a double can hold, so neighbouring cells merge
  # and a pair is counted up to nine times (x = 1e12 with a band of 1e-6; review of 46de6a9)
  if (any(abs(c(cx, cy)) >= 2^53)) {
    stop("the coordinates divided by the band exceed 2^53: no cell index can be held; use a wider band or",
         " rescale the coordinates", call. = FALSE)
  }
  # whole numbers written out in full: paste() writes 1e15 and 1e15 + 1 both as "1e+15", one cell
  key <- function(a, b) sprintf("%.0f %.0f", a, b)
  pts <- data.frame(i = seq_along(x), k = key(cx, cy))
  out_i <- list()
  out_j <- list()
  total <- 0
  for (off in list(c(0, 0), c(1, -1), c(1, 0), c(1, 1), c(0, 1))) {
    nb <- data.frame(j = seq_along(x), k = key(cx - off[1L], cy - off[2L]))
    # sizes first, so a dense cell is refused before memory is spent on it
    a <- table(pts$k)
    b <- table(nb$k)
    common <- intersect(names(a), names(b))
    total <- total + sum(as.numeric(a[common]) * as.numeric(b[common]))
    if (total > max_pairs) {
      stop(sprintf(paste("more than %s candidate pairs within the largest distance band: use a smaller",
                         "largest band, fewer incidents, or raise `max_pairs`"), format(max_pairs, big.mark = ",")),
           call. = FALSE)
    }
    m <- merge(pts, nb, by = "k")
    if (all(off == 0)) m <- m[m$i < m$j, ]
    d2 <- (x[m$i] - x[m$j])^2 + (y[m$i] - y[m$j])^2
    sel <- d2 <= r * r
    out_i[[length(out_i) + 1L]] <- m$i[sel]
    out_j[[length(out_j) + 1L]] <- m$j[sel]
  }
  i <- unlist(out_i)
  j <- unlist(out_j)
  list(i = i, j = j, d = sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2))
}

# pairs (over all n(n-1)/2) whose absolute difference is within each cut, from sorted values
.jx_pairs_within <- function(t, cuts) {
  t <- sort(t)
  vapply(cuts, function(b) sum(findInterval(t + b, t) - seq_along(t)), numeric(1))
}

#' Near-repeat analysis: the Knox test for space-time clustering
#'
#' Asks whether incidents close together in space also happen close
#' together in time more often than chance would give -- the near-repeat
#' pattern of burglary and shootings. Pairs of incidents are classified by
#' distance band and time band; each cell's count is compared with the
#' count expected if the times were shuffled among the locations, and a
#' Monte Carlo permutation test gives its p-value.
#'
#' @param x,y Locations: longitude and latitude in degrees by default
#'   (\code{coords = "lonlat"}), or planar coordinates in metres.
#' @param time Times of the incidents: \code{Date}, \code{POSIXct}, or
#'   numbers in days.
#' @param space_bands Upper edges of the distance bands in metres,
#'   increasing: \code{c(100, 200, 400)} is 0-100, 100-200 and 200-400 m.
#' @param time_bands Upper edges of the time bands in days, increasing.
#' @param nsim Monte Carlo permutations. Default 999.
#' @param seed Optional seed for the permutations; the caller's random
#'   stream is left as it was.
#' @param coords \code{"lonlat"} or \code{"planar"}.
#' @param max_pairs Limit on candidate pairs held in memory. Default 5e7.
#'
#' @return A list of class \code{rmbl_knox}: \code{table}, a long data frame
#'   with one row per distance-by-time cell (\code{space_lower},
#'   \code{space_upper}, \code{time_lower}, \code{time_upper},
#'   \code{observed}, \code{expected}, \code{ratio}, \code{p_value}); the
#'   \code{n} incidents used; \code{nsim}.
#'
#' @details
#' Under the null hypothesis that the times are exchangeable among the
#' locations, every unordered pair of locations receives a uniformly random
#' pair of times, so the expected count in a cell is exact:
#' \eqn{E_{st} = S_s T_t / P}, where \eqn{S_s} is the number of pairs in
#' distance band \eqn{s}, \eqn{T_t} the number in time band \eqn{t}, and
#' \eqn{P = n(n-1)/2}. The ratio is \eqn{O_{st} / E_{st}}: above 1, pairs
#' that close in space are that close in time more often than chance. The
#' p-value of each cell is one-sided, \eqn{(1 + \#\{O^* \ge O\}) / (1 +
#' nsim)} over the permutations. Cells are tested separately; a table of
#' many cells will show some small p-values by chance alone.
#'
#' Only pairs within the largest distance band are needed, and they are
#' found by hashing the locations to a grid, so the work grows with the
#' number of close pairs rather than with \eqn{n^2}.
#'
#' Ties in time -- incidents recorded to the day -- put same-day pairs in
#' the first time band (0 to its edge). The test speaks to the timing of
#' incidents relative to each other, not to what caused them; near-repeat
#' patterns also arise when one offender commits a series.
#'
#' @references
#' Knox, E. G. (1964). The detection of space-time interactions.
#' \emph{Journal of the Royal Statistical Society, Series C (Applied
#' Statistics)}, 13(1), 25-30.
#'
#' Mantel, N. (1967). The detection of disease clustering and a
#' generalized regression approach. \emph{Cancer Research}, 27(2),
#' 209-220.
#'
#' Johnson, S. D., Bernasco, W., Bowers, K. J., Elffers, H., Ratcliffe,
#' J., Rengert, G. and Townsley, M. (2007). Space-time patterns of risk: a
#' cross national assessment of residential burglary victimization.
#' \emph{Journal of Quantitative Criminology}, 23(3), 201-219.
#'
#' @seealso \code{\link{crime_density}}.
#' @examples
#' b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
#'                           package = "rmoriebricklayer"))
#' b <- b[!is.na(b$lon), ]
#' kn <- knox_test(b$lon, b$lat, as.Date(b$occ_date), space_bands = c(100, 200, 400),
#'                 time_bands = c(7, 14, 28), nsim = 199, seed = 1)
#' kn
#' plot(kn)
#' @export
knox_test <- function(x, y, time, space_bands, time_bands, nsim = 999L, seed = NULL,
                      coords = c("lonlat", "planar"), max_pairs = 5e7) {
  coords <- match.arg(coords)
  max_pairs <- .rmbl_num(max_pairs, "max_pairs")
  if (length(max_pairs) != 1L || is.na(max_pairs) || max_pairs < 1) {
    stop("`max_pairs` must be a single number of at least 1", call. = FALSE)
  }
  x <- .rmbl_num_input(x, "x", allow_null = FALSE)
  y <- .rmbl_num_input(y, "y", allow_null = FALSE)
  tt <- if (inherits(time, "Date")) {
    as.numeric(time)
  } else if (inherits(time, "POSIXt")) {
    as.numeric(time) / 86400
  } else {
    .rmbl_num_input(time, "time", allow_null = FALSE)
  }
  if (length(y) != length(x) || length(tt) != length(x)) {
    stop("`x`, `y` and `time` must have the same length", call. = FALSE)
  }
  # an incident without a location or a time is dropped and said, as crime_density() and
  # hotspot_persistence() do (knox_test() alone refused the whole call; review of 29a55d8)
  keep <- is.finite(x) & is.finite(y) & is.finite(tt)
  if (!all(keep)) {
    message(sprintf("knox_test(): %d incident%s without a usable location or time dropped", sum(!keep),
                    if (sum(!keep) == 1L) "" else "s"))
    x <- x[keep]
    y <- y[keep]
    tt <- tt[keep]
  }
  bands <- function(b, what) {
    b <- .rmbl_num_input(b, what, allow_null = FALSE)
    if (!length(b) || anyNA(b) || any(!is.finite(b)) || any(b <= 0) || is.unsorted(b, strictly = TRUE)) {
      stop(sprintf("`%s` must be positive, finite and increasing", what), call. = FALSE)
    }
    b
  }
  sb <- bands(space_bands, "space_bands")
  tb <- bands(time_bands, "time_bands")
  nsim <- .rmbl_num(nsim, "nsim", integer = TRUE)
  if (length(nsim) != 1L || is.na(nsim) || nsim < 19L) {
    stop("`nsim` must be a whole number of at least 19", call. = FALSE)
  }
  if (coords == "lonlat") {
    if (any(abs(y) > 90 | abs(x) > 180)) {
      stop("`x` and `y` are not longitudes and latitudes in degrees; planar data take coords = \"planar\"",
           call. = FALSE)
    }
    # (0, 0) is "no location", as crime_density() and hotspot_persistence() read it: twenty such rows
    # had made the closest space-time cell 163 observed against 33 expected (review of e57fed5, E3)
    nowhere <- .jx_null_island(x, y)
    if (any(nowhere)) {
      message(sprintf("knox_test(): %d incident%s at (0, 0), the raw exports' \"no location\", dropped",
                      sum(nowhere), if (sum(nowhere) == 1L) "" else "s"))
      x <- x[!nowhere]
      y <- y[!nowhere]
      tt <- tt[!nowhere]
    }
  }
  n <- length(x)
  if (n < 3L) stop("need at least three incidents", call. = FALSE)
  if (coords == "lonlat") {
    p <- .jx_lonlat_plane(x, y, "knox_test")
    px <- p$x * 1000
    py <- p$y * 1000
  } else {
    px <- x
    py <- y
  }
  cp <- .jx_close_pairs(px, py, max(sb), max_pairs)
  ks <- length(sb)
  kt <- length(tb)
  s_idx <- findInterval(cp$d, c(0, sb), left.open = TRUE, rightmost.closed = TRUE)
  s_idx[cp$d == 0] <- 1L
  big_p <- n * (n - 1) / 2
  s_cnt <- tabulate(s_idx, ks)
  t_cum <- .jx_pairs_within(tt, tb)
  t_cnt <- diff(c(0, t_cum))
  expected <- outer(s_cnt, t_cnt) / big_p
  cell_of <- function(tv) {
    dt <- abs(tv[cp$i] - tv[cp$j])
    t_idx <- findInterval(dt, c(0, tb), left.open = TRUE, rightmost.closed = TRUE)
    t_idx[dt == 0] <- 1L
    ok <- t_idx >= 1L & t_idx <= kt & dt <= max(tb)
    tabulate(s_idx[ok] + (t_idx[ok] - 1L) * ks, ks * kt)
  }
  obs <- cell_of(tt)
  sims <- .rmbl_with_seed_maybe(seed, vapply(seq_len(nsim), function(k) cell_of(tt[sample.int(n)]),
                                             numeric(ks * kt)))
  sims <- matrix(sims, nrow = ks * kt)
  pv <- (1 + rowSums(sims >= obs)) / (nsim + 1)
  tab <- data.frame(space_lower = rep(c(0, utils::head(sb, -1L)), times = kt), space_upper = rep(sb, times = kt),
                    time_lower = rep(c(0, utils::head(tb, -1L)), each = ks), time_upper = rep(tb, each = ks),
                    observed = obs, expected = as.vector(expected),
                    ratio = ifelse(as.vector(expected) > 0, obs / as.vector(expected), NA_real_), p_value = pv)
  structure(list(table = tab, n = n, nsim = nsim, space_bands = sb, time_bands = tb, close_pairs = length(cp$d)),
            class = "rmbl_knox")
}

# the seed is optional here, unlike .rmbl_with_seed()
.rmbl_with_seed_maybe <- function(seed, expr) {
  if (is.null(seed)) return(expr)
  seed <- .rmbl_num(seed, "seed", integer = TRUE)
  if (length(seed) != 1L || is.na(seed)) stop("`seed` must be a single whole number", call. = FALSE)
  .rmbl_with_seed(seed, expr)
}

#' @export
print.rmbl_knox <- function(x, ...) {
  t <- x$table
  cell <- sprintf("%.2f%s", t$ratio, ifelse(t$p_value < 0.01, "**", ifelse(t$p_value < 0.05, "*", "")))
  cell[is.na(t$ratio)] <- "-"
  m <- matrix(cell, nrow = length(x$space_bands))
  df <- data.frame(distance = sprintf("%g-%g m", c(0, utils::head(x$space_bands, -1L)), x$space_bands), m,
                   check.names = FALSE)
  names(df)[-1L] <- sprintf("%g-%g d", c(0, utils::head(x$time_bands, -1L)), x$time_bands)
  .rmbl_print_table(sprintf("Knox ratios, observed / expected pairs (%s incidents, %d permutations)",
                            format(x$n, big.mark = ","), x$nsim), df,
                    footer = "* p < 0.05, ** p < 0.01, one-sided per cell (not adjusted for the number of cells)", ...)
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_knox <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  t <- x$table
  ks <- length(x$space_bands)
  kt <- length(x$time_bands)
  r <- matrix(t$ratio, nrow = ks)
  lr <- log2(r)
  lim <- max(1, abs(lr[is.finite(lr)]))
  # white at a ratio of 1, blue below, red above (the diverging palette's grey midpoint muddied
  # every cell near 1)
  cols <- if (!is.null(col)) col else if (!is.null(palette)) bricklayer_palette(palette, 63) else
    grDevices::colorRampPalette(c("#2166AC", "#F7F7F7", "#B2182B"))(63)
  ylabs <- sprintf("%g-%g", c(0, utils::head(x$space_bands, -1L)), x$space_bands)
  op <- .bl_par(labels = ylabs)
  on.exit(graphics::par(op), add = TRUE)
  # room for the axis title outside the band labels
  mar <- graphics::par("mar")
  graphics::par(mar = .bl_safe_mar(c(mar[1L], mar[2L] + 1.6, mar[3L], mar[4L])))
  lr[!is.finite(lr)] <- NA
  graphics::image(seq_len(kt), seq_len(ks), t(lr), col = cols, zlim = c(-lim, lim), axes = FALSE,
                  xlab = "Days apart", ylab = "", main = "", ...)
  graphics::axis(1, at = seq_len(kt), labels = sprintf("%g-%g", c(0, utils::head(x$time_bands, -1L)), x$time_bands))
  graphics::axis(2, at = seq_len(ks), labels = ylabs)
  .bl_knox_ylab(ylabs)
  graphics::box()
  .bl_title(.bl_main(main, "Near repeats: Knox ratio (observed / expected)"))
  lab <- sprintf("%.2f%s", t$ratio, ifelse(t$p_value < 0.01, "**", ifelse(t$p_value < 0.05, "*", "")))
  lab[is.na(t$ratio)] <- "-"
  graphics::text(rep(seq_len(kt), each = ks), rep(seq_len(ks), times = kt), lab, cex = 0.85)
  invisible(t)
}

# ---- case mix: Simpson's paradox in an aggregate clearance rate ------------------------------

#' Decompose a change in a clearance rate into rate and case-mix effects
#'
#' An aggregate clearance rate -- cases disposed per case received by a
#' court, or offences cleared per offence reported to a police service --
#' is a weighted mean of the rates of its parts (offence groups, courts,
#' case types), weighted by each part's share of the denominator. It can
#' therefore fall while the rate of every part rises, if the work shifts
#' toward the parts that clear more slowly: Simpson's paradox. This
#' function compares two periods (or two jurisdictions), splits the change
#' in the aggregate exactly into the change in the parts' rates and the
#' change in the mix, reports the rate standardised to a common mix, tests
#' the within-part change, and says whether the comparison is a reversal.
#'
#' @param numerator Cases disposed (or cleared), one per part and
#'   comparison.
#' @param denominator Cases received (or reported), one per part and
#'   comparison.
#' @param group The part each row belongs to: offence group, court, case
#'   type.
#' @param compare The comparison each row belongs to: exactly two values,
#'   such as two years or two jurisdictions.
#' @param base Which value of \code{compare} is the baseline. Default: the
#'   first in sorted order.
#' @param conf_level Confidence level. Default 0.95.
#'
#' @return A list of class \code{rmbl_clearance_decomposition}:
#'   \describe{
#'   \item{\code{groups}}{one row per part: the counts, rates and
#'     denominator shares (\code{weight}) in both comparisons, the rate
#'     ratio with its exact interval, and the part's \code{rate_effect} and
#'     \code{mix_effect}.}
#'   \item{\code{overall}}{the aggregate rates, their \code{change}, its
#'     \code{rate_effect} and \code{mix_effect} (which add to it exactly),
#'     the comparison rate standardised to the baseline mix
#'     (\code{standardised_on_base}) and to the average mix
#'     (\code{standardised_on_average}).}
#'   \item{\code{rate_ratio}}{the crude rate ratio and the Mantel-Haenszel
#'     rate ratio over the parts, each with its interval, and the p-value
#'     for the stratified ratio.}
#'   \item{\code{simpson}}{\code{"full"} when every part moved one way and
#'     the aggregate the other; \code{"mix"} when the aggregate moved
#'     against the mix-standardised change (the mix outweighed the rates);
#'     \code{"none"} otherwise; with the number of parts that rose and
#'     fell.}
#'   }
#'
#' @details
#' With part rates \eqn{r_g} and denominator shares \eqn{w_g}, the
#' aggregate is \eqn{R = \sum_g w_g r_g}. Kitagawa's symmetric
#' decomposition writes the change between comparisons A and B as
#' \deqn{R_B - R_A = \sum_g \bar w_g (r_{gB} - r_{gA}) + \sum_g \bar r_g (w_{gB} - w_{gA}),}
#' with \eqn{\bar w_g} and \eqn{\bar r_g} the averages over A and B: the
#' first sum is the rate effect (the change the aggregate would show with
#' the mix held at its average), the second the mix effect. The two add to
#' the observed change with no residual. Because the shares' changes add to
#' zero, each part's mix term is reported as
#' \eqn{(\bar r_g - \bar R)(w_{gB} - w_{gA})}, centred on the average
#' aggregate rate \eqn{\bar R}: the total is the same, and a part's term
#' is negative when work moved toward a part that clears below average.
#'
#' The within-part change is estimated by the Mantel-Haenszel rate ratio,
#' treating each part's numerator as a Poisson count over its denominator,
#' with the Greenland-Robins variance; the p-value is for the hypothesis
#' that the ratio is 1. Each part's own rate ratio has the exact
#' conditional (binomial) interval. A court's clearance rate can exceed 1,
#' so it is treated as a rate rather than a proportion; for police
#' clearance, where it is a proportion, the Poisson treatment is
#' conservative.
#'
#' The decomposition is only as good as the parts: a different grouping
#' (courts instead of offence groups) can tell a different story, and both
#' can be right. Demers and Rossmo found 210 reversals in fifteen years of
#' clearance rates for Canada's fifty largest police services, four of
#' them reversed in every crime category, and advise comparing clearance
#' rates only within comparable mixes.
#'
#' @references
#' Simpson, E. H. (1951). The interpretation of interaction in contingency
#' tables. \emph{Journal of the Royal Statistical Society, Series B},
#' 13(2), 238-241.
#'
#' Kitagawa, E. M. (1955). Components of a difference between two rates.
#' \emph{Journal of the American Statistical Association}, 50(272),
#' 1168-1194. \doi{10.2307/2281213}
#'
#' Das Gupta, P. (1993). \emph{Standardization and Decomposition of Rates:
#' A User's Manual}. U.S. Bureau of the Census, Current Population Reports
#' P23-186. Washington, DC.
#'
#' Greenland, S. and Robins, J. M. (1985). Estimation of a common effect
#' parameter from sparse follow-up data. \emph{Biometrics}, 41(1), 55-68.
#'
#' Demers, S. and Rossmo, D. K. (2015). Simpson's paradox in Canadian
#' police clearance rates. \emph{Canadian Journal of Criminology and
#' Criminal Justice}, 57(3), 424-434. \doi{10.3138/cjccj.2014-E29}
#'
#' @seealso \code{\link{case_flow}} for the clearance rate over time.
#' @examples
#' g <- read.csv(system.file("extdata", "ocj_offence_groups.csv",
#'                           package = "rmoriebricklayer"))
#' g <- g[g$year %in% c(2014, 2022), ]
#' cd <- clearance_decomposition(g$disposed, g$received, g$offence_group, g$year)
#' cd
#' plot(cd)
#' @export
clearance_decomposition <- function(numerator, denominator, group, compare, base = NULL, conf_level = 0.95) {
  num <- .jx_counts(numerator, "numerator")
  n <- length(num)
  if (!n) stop("`numerator` is empty", call. = FALSE)
  den <- .jx_counts(denominator, "denominator", n)
  if (length(group) != n || length(compare) != n) {
    stop("`numerator`, `denominator`, `group` and `compare` must have the same length", call. = FALSE)
  }
  if (anyNA(group) || anyNA(compare)) stop("`group` and `compare` must not have missing values", call. = FALSE)
  conf_level <- .jx_conf(conf_level)
  levs <- sort(unique(compare))
  if (length(levs) != 2L) {
    stop(sprintf("`compare` must have exactly two values (two periods or two jurisdictions), got %d", length(levs)),
         call. = FALSE)
  }
  if (!is.null(base)) {
    if (length(base) != 1L || !base %in% levs) stop("`base` must be one of the two values of `compare`", call. = FALSE)
    levs <- c(base, setdiff(levs, base))
  }
  key <- paste(group, compare, sep = "\r")
  if (anyDuplicated(key)) {
    d <- which(duplicated(key))[1L]
    stop(sprintf("part \"%s\" appears more than once in %s", group[d], format(compare[d])), call. = FALSE)
  }
  ga <- group[compare == levs[1L]]
  gb <- group[compare == levs[2L]]
  miss <- c(setdiff(ga, gb), setdiff(gb, ga))
  if (length(miss)) {
    stop(sprintf("part \"%s\" is in only one comparison; a rate change needs it in both (merge or drop it first)",
                 miss[1L]), call. = FALSE)
  }
  g <- sort(unique(group))
  pick <- function(v, l) v[match(paste(g, l, sep = "\r"), key)]
  na <- pick(num, levs[1L])
  da <- pick(den, levs[1L])
  nb <- pick(num, levs[2L])
  db <- pick(den, levs[2L])
  if (any(da == 0 | db == 0)) {
    stop(sprintf("part \"%s\" has a zero denominator, so it has no rate", g[da == 0 | db == 0][1L]), call. = FALSE)
  }
  ra <- na / da
  rb <- nb / db
  wa <- da / sum(da)
  wb <- db / sum(db)
  rate_eff <- (wa + wb) / 2 * (rb - ra)
  # each part's mix term is centred on the average aggregate rate: the shares' changes add to zero,
  # so the total is unchanged, and a part's term is negative when work moved toward a part that
  # clears below the average (uncentred, a growing part always looked like a gain)
  centre <- (sum(na) / sum(da) + sum(nb) / sum(db)) / 2
  mix_eff <- ((ra + rb) / 2 - centre) * (wb - wa)
  ci <- .jx_ratio_ci(nb, na, conf_level)
  groups <- data.frame(group = g, numerator_a = na, denominator_a = da, rate_a = ra, weight_a = wa,
                       numerator_b = nb, denominator_b = db, rate_b = rb, weight_b = wb,
                       rate_ratio = rb / ra, lower = ci$lower * da / db, upper = ci$upper * da / db,
                       rate_effect = rate_eff, mix_effect = mix_eff, stringsAsFactors = FALSE)
  agg_a <- sum(na) / sum(da)
  agg_b <- sum(nb) / sum(db)
  overall <- data.frame(rate_a = agg_a, rate_b = agg_b, change = agg_b - agg_a, rate_effect = sum(rate_eff),
                        mix_effect = sum(mix_eff), standardised_on_base = sum(wa * rb),
                        standardised_on_average = sum((wa + wb) / 2 * rb))
  # Mantel-Haenszel rate ratio for person-time data, Greenland-Robins variance of its log
  tt <- da + db
  sa <- sum(nb * da / tt)
  sb <- sum(na * db / tt)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  mh <- sa / sb
  v <- sum((na + nb) * da * db / tt^2) / (sa * sb)
  cci <- .jx_ratio_ci(sum(nb), sum(na), conf_level)
  rr <- data.frame(estimate = c("crude", "mantel_haenszel"),
                   ratio = c(agg_b / agg_a, mh),
                   lower = c(cci$lower * sum(da) / sum(db), mh * exp(-z * sqrt(v))),
                   upper = c(cci$upper * sum(da) / sum(db), mh * exp(z * sqrt(v))),
                   p_value = c(NA_real_, 2 * stats::pnorm(-abs(log(mh)) / sqrt(v))))
  up <- sum(rb > ra)
  down <- sum(rb < ra)
  ch <- overall$change
  type <- if (ch != 0 && ((up == length(g) && ch < 0) || (down == length(g) && ch > 0))) "full" else
    if (ch != 0 && overall$rate_effect != 0 && sign(ch) != sign(overall$rate_effect)) "mix" else "none"
  structure(list(groups = groups, overall = overall, rate_ratio = rr,
                 simpson = list(type = type, up = up, down = down, parts = length(g)),
                 compare = levs, conf_level = conf_level),
            class = "rmbl_clearance_decomposition")
}

#' @export
print.rmbl_clearance_decomposition <- function(x, ...) {
  o <- x$overall
  s <- x$simpson
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  verdict <- switch(s$type,
    full = sprintf("Simpson's paradox: every part moved the other way to the aggregate (%d of %d)",
                   if (o$change < 0) s$up else s$down, s$parts),
    mix = sprintf("Simpson's paradox through the mix: the aggregate %s, but at a fixed mix it %s",
                  if (o$change < 0) "fell" else "rose", if (o$rate_effect < 0) "fell" else "rose"),
    none = "No reversal: the aggregate moved the way the mix-standardised rate did")
  notes <- c(sprintf("%s: %.4f   %s: %.4f   change %+.4f = rate effect %+.4f + mix effect %+.4f",
                     a, o$rate_a, b, o$rate_b, o$change, o$rate_effect, o$mix_effect),
             sprintf("%s standardised to the %s mix: %.4f; to the average mix: %.4f",
                     b, a, o$standardised_on_base, o$standardised_on_average),
             sprintf("%d of %d parts rose, %d fell. %s", s$up, s$parts, s$down, verdict))
  g <- x$groups
  show <- data.frame(part = g$group, rate_a = round(g$rate_a, 4), rate_b = round(g$rate_b, 4),
                     weight_a = round(g$weight_a, 4), weight_b = round(g$weight_b, 4),
                     ratio = round(g$rate_ratio, 4), lower = round(g$lower, 4), upper = round(g$upper, 4),
                     rate_effect = signif(g$rate_effect, 3), mix_effect = signif(g$mix_effect, 3))
  names(show)[2:5] <- c(paste("rate", a), paste("rate", b), paste("share", a), paste("share", b))
  rr <- x$rate_ratio
  footer <- sprintf(paste("Rate ratio %s/%s: crude %.4f (%.4f to %.4f);",
                          "within parts (Mantel-Haenszel) %.4f (%.4f to %.4f), p %s"),
                    b, a, rr$ratio[1L], rr$lower[1L], rr$upper[1L], rr$ratio[2L], rr$lower[2L], rr$upper[2L],
                    .rmbl_fmt_p(rr$p_value[2L]))
  .rmbl_print_table(sprintf("Clearance rate, %s against %s: rate and case-mix effects (Kitagawa)", b, a),
                    show, notes = notes, footer = footer, ...)
  invisible(x)
}

#' @rdname plot-methods
#' @param max_parts For \code{rmbl_clearance_decomposition}, the most parts drawn: past it,
#'   the parts that moved the aggregate most, and the rest summed into one row.
#' @usage \method{plot}{rmbl_clearance_decomposition}(x, ..., what = NULL,
#'   max_parts = 20L, main = NULL, col = NULL, palette = NULL)
#' @export
plot.rmbl_clearance_decomposition <- function(x, ..., what = NULL, max_parts = 20L, main = NULL, col = NULL,
                                              palette = NULL) {
  cols <- .bl_cols(2, col, palette)
  max_parts <- .rmbl_num(max_parts, "max_parts", integer = TRUE)
  if (length(max_parts) != 1L || is.na(max_parts) || max_parts < 2L) {
    stop("`max_parts` must be a whole number of at least 2", call. = FALSE)
  }
  # no more rows than the device has room for (about 0.12 inch each): a 3-inch device shows the
  # parts that moved the aggregate most, the rest summed, instead of 20 rows on top of each other
  din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
  max_parts <- max(2L, min(max_parts, as.integer(floor((din[2L] - 2) / 0.12))))
  v <- .jx_cd_view(x, max_parts)
  x$groups <- v$groups
  x$other <- v$other
  # the paradox needs two pictures side by side: the parts' rates (most went one way) and where
  # the work moved (toward the parts that clear less); the waterfall adds the sum. Ten inches
  # hold all three, six hold the first two, and a smaller device the rates alone, with the
  # decomposition written under them.
  if (is.null(what)) {
    din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
    what <- if (din[1L] >= 10 && din[2L] >= 3.5) c("rates", "mix", "effects") else
      if (din[1L] >= 6 && din[2L] >= 3.5) c("rates", "mix") else "rates"
  }
  what <- match.arg(what, c("rates", "mix", "effects"), several.ok = TRUE)
  o <- x$overall
  line <- sprintf("Change %+.4f = rates %+.4f + mix %+.4f", o$change, o$rate_effect, o$mix_effect)
  op0 <- graphics::par(no.readonly = TRUE)
  on.exit(graphics::par(op0), add = TRUE)
  draw <- list(rates = .jx_cd_rates, mix = .jx_cd_mix, effects = .jx_cd_effects)
  if (length(what) > 1L) {
    .bl_panels_begin(length(what))
    on.exit(.bl_panels_abort(), add = TRUE)
    for (w in what) draw[[w]](x, cols, NULL, ...)
    keys <- .bl_panels_end()
    if (!"effects" %in% what) {
      graphics::mtext(line, side = 1, outer = TRUE, line = if (length(keys)) 1.2 else 0.2,
                      cex = 0.8, adj = 0, col = "#3D4350")
    }
    if (!is.null(main)) graphics::mtext(main, side = 3, outer = TRUE, line = -1.2, font = 2, col = "#1F2430")
  } else {
    if (what != "effects") graphics::par(oma = c(1.4, 0, 0, 0))
    draw[[what]](x, cols, main, ...)
    if (what != "effects") graphics::mtext(line, side = 1, outer = TRUE, line = 0.2,
                                           cex = 0.8, adj = 0, col = "#3D4350")
  }
  invisible(x$groups)
}

# The parts as drawn: ordered by their average rate (lowest at the bottom), so the colours of
# the mix panel separate; past `max_parts`, the parts that moved the aggregate most, and the rest
# summed into one row (its rate from the summed counts, not an average of rates).
.jx_cd_view <- function(x, max_parts) {
  g <- x$groups
  other <- 0L
  if (nrow(g) > max_parts) {
    keep <- order(-(abs(g$rate_effect) + abs(g$mix_effect)))[seq_len(max_parts - 1L)]
    rest <- g[-keep, , drop = FALSE]
    agg <- g[keep[1L], , drop = FALSE]
    agg$group <- sprintf("Other parts (%d)", nrow(rest))
    for (v in c("numerator_a", "denominator_a", "numerator_b", "denominator_b", "weight_a", "weight_b",
                "rate_effect", "mix_effect")) agg[[v]] <- sum(rest[[v]])
    agg$rate_a <- agg$numerator_a / agg$denominator_a
    agg$rate_b <- agg$numerator_b / agg$denominator_b
    agg$rate_ratio <- agg$rate_b / agg$rate_a
    agg$lower <- NA_real_
    agg$upper <- NA_real_
    g <- rbind(g[keep, , drop = FALSE], agg)
    other <- nrow(rest)
  }
  g <- g[order((g$rate_a + g$rate_b) / 2), , drop = FALSE]
  rownames(g) <- NULL
  list(groups = g, other = other)
}

# Row labels for a panel of `units` rows, chosen before the plot so the margin fits them: two
# lines when the rows are tall enough, else one (cut with an ellipsis only past the room), and
# a text size the row height allows.
.jx_row_labels <- function(labs, units) {
  fin <- tryCatch(graphics::par("fin"), error = function(e) c(7, 7))
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) * .bl_plot_opts()$cex
  # the plot's height is the figure less its margins (7.2 lines) and the panel key's outer margin
  oma <- tryCatch(sum(graphics::par("oma")[c(1L, 3L)]), error = function(e) 0)
  rowh <- max(fin[2L] - (7.2 + oma) * csi, csi) / units
  fit <- .bl_label_wrap(labs)
  two <- any(grepl("\n", fit$labels, fixed = TRUE))
  if (two && 2 * csi * 0.9 > rowh) {
    # rows too short for two lines: the whole name a size smaller reads better than a cut one;
    # cut (with an ellipsis) only when even 0.7 of the size does not fit the room
    room <- 0.5 * tryCatch(graphics::par("fin")[1L], error = function(e) 7) - csi
    w <- max(.bl_strwidth(labs, cex = 1), 0)
    sizes <- c(0.85, 0.75, 0.65, 0.6)
    shrink <- sizes[w * sizes <= room]
    if (length(shrink)) {
      fit <- list(labels = labs, mar = max(1, w * shrink[1L] / csi + 1) / shrink[1L])
      fit$cex <- min(shrink[1L], max(0.45, rowh / (csi * 0.9)))
      return(fit)
    }
    fit <- .bl_label_fit(labs)
    two <- FALSE
  }
  fit$cex <- max(0.45, min(1, rowh / ((if (two) 2 else 1) * csi * 0.9)))
  fit
}

# arrows only where they are long enough to have a direction (a part that barely moved gets its
# two points and no arrow: R warns about a zero-length arrow and draws nothing)
.jx_arrows <- function(x0, y, x1, col, lwd) {
  usr <- graphics::par("usr")
  len <- abs(x1 - x0) / diff(usr[1:2]) * graphics::par("pin")[1L]
  ok <- is.finite(len) & len > 0.02
  if (any(ok)) graphics::arrows(x0[ok], y[ok], x1[ok], y[ok], length = 0.06, col = col[ok], lwd = lwd[ok])
}

# each part's rate in both comparisons, the aggregate on top; an arrow per part, coloured by
# direction, so a reversal reads as every arrow pointing one way and the top one the other
.jx_cd_rates <- function(x, cols, main, ...) {
  g <- x$groups
  o <- x$overall
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  labs <- c(as.character(g$group), "All parts")
  k <- nrow(g)
  y <- c(seq_len(k), k + 1.6)
  ra <- c(g$rate_a, o$rate_a)
  rb <- c(g$rate_b, o$rate_b)
  # the panel's text size first: a panel grid lowers par("cex"), and labels measured at the
  # lowered size and drawn at this one ran off the device
  o0 <- .bl_plot_opts()
  op <- graphics::par(las = o0$las, cex = o0$cex, bg = o0$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430")
  on.exit(graphics::par(op), add = TRUE)
  fit <- .jx_row_labels(labs, k + 2.6)
  graphics::par(mar = .bl_safe_mar(c(4.2, fit$mar * fit$cex + 0.8, 3, 1), o0$cex))
  graphics::plot(range(c(ra, rb)), range(y) + c(-0.5, 0.5), type = "n", yaxt = "n", xlab = "", ylab = "",
                 main = "", ...)
  graphics::axis(2, at = y, labels = FALSE)
  # every row labelled (axis() drops labels that would touch)
  graphics::text(graphics::par("usr")[1L] - 0.03 * diff(graphics::par("usr")[1:2]), y, fit$labels, adj = 1,
                 xpd = NA, cex = fit$cex)
  .bl_xlab("Clearance rate")
  title <- sprintf("Rates, %s to %s", a, b)
  if (isTRUE(x$other > 0L)) title <- sprintf("%s, top %d", title, k - 1L)
  .bl_title(.bl_main(main, title))
  .bl_grid(NULL, side = "x")
  graphics::abline(h = k + 0.8, col = "#9AA0AA", lwd = 1.5)
  graphics::abline(v = 1, lty = 3, col = "#888888")
  dir <- ifelse(rb >= ra, cols[1L], cols[2L])
  .jx_arrows(ra, y, rb, dir, c(rep(2, k), 3.5))
  graphics::points(ra, y, pch = 21, bg = "white", col = "#555555", cex = 1.1)
  graphics::points(rb, y, pch = 21, bg = dir, col = "white", lwd = 1.2, cex = 1.5)
  invisible(NULL)
}

# each part's share of the workload in both comparisons, coloured by whether it clears above or
# below the average: the mix that can turn the aggregate against its parts
.jx_cd_mix <- function(x, cols, main, ...) {
  g <- x$groups
  o <- x$overall
  a <- format(x$compare[1L])
  b <- format(x$compare[2L])
  k <- nrow(g)
  y <- seq_len(k)
  wa <- g$weight_a
  wb <- g$weight_b
  centre <- (o$rate_a + o$rate_b) / 2
  colr <- ifelse((g$rate_a + g$rate_b) / 2 >= centre, cols[1L], cols[2L])
  o0 <- .bl_plot_opts()
  op <- graphics::par(las = o0$las, cex = o0$cex, bg = o0$bg, bty = "n", tcl = -0.2, mgp = c(3, 0.55, 0),
                      col.axis = "#3D4350", fg = "#8A909A", col = "#1F2430")
  on.exit(graphics::par(op), add = TRUE)
  fit <- .jx_row_labels(as.character(g$group), k + 1)
  graphics::par(mar = .bl_safe_mar(c(4.2, fit$mar * fit$cex + 0.8, 3, 1), o0$cex))
  graphics::plot(range(c(0, wa, wb)), c(0.5, k + 0.5), type = "n", yaxt = "n", xlab = "", ylab = "", main = "",
                 ...)
  graphics::axis(2, at = y, labels = FALSE)
  graphics::text(graphics::par("usr")[1L] - 0.03 * diff(graphics::par("usr")[1:2]), y, fit$labels, adj = 1,
                 xpd = NA, cex = fit$cex)
  .bl_xlab("Share of workload")
  .bl_title(.bl_main(main, "Where the work moved"))
  .bl_grid(NULL, side = "x")
  .jx_arrows(wa, y, wb, colr, rep(2, k))
  graphics::points(wa, y, pch = 21, bg = "white", col = "#555555", cex = 1.1)
  graphics::points(wb, y, pch = 21, bg = colr, col = "white", lwd = 1.2, cex = 1.5)
  # the colour key under the title, where it covers no point, sized to the panel
  key <- "colour: blue clears above average, orange below"
  kc <- min(0.75, 0.75 * graphics::par("pin")[1L] / max(.bl_strwidth(key, cex = 0.75), 1e-6))
  graphics::mtext(key, side = 3, line = 0.15, cex = kc * graphics::par("cex"), col = "#555555")
  invisible(NULL)
}

# the change in the aggregate as a waterfall: rate effect, then mix effect, then the total
.jx_cd_effects <- function(x, cols, main, ...) {
  o <- x$overall
  vals <- c(o$rate_effect, o$mix_effect)
  ends <- cumsum(c(0, vals))
  op <- .bl_par(c(ends, o$change))
  graphics::plot(c(0.4, 3.6), range(c(0, ends, o$change)) + c(-1, 1) * 0.05 * max(abs(c(ends, o$change)), 1e-12),
                 type = "n", xaxt = "n", xlab = "", ylab = "", main = "", ...)
  .bl_ylab("Change in the clearance rate")
  # mtext, not axis(): axis() drops labels that would touch, and on a small panel kept only one
  graphics::axis(1, at = 1:3, labels = FALSE)
  unit_in <- graphics::par("pin")[1L] / diff(graphics::par("usr")[1:2])
  bar_cex <- min(0.85, 0.85 * 0.9 * unit_in / max(.bl_strwidth(c("rates", "mix", "total"), cex = 0.85)))
  graphics::mtext(c("rates", "mix", "total"), side = 1, at = 1:3, line = 0.8, cex = bar_cex * graphics::par("cex"))
  .bl_title(.bl_main(main, switch(x$simpson$type, full = "Reversal in every part",
                                  mix = "Reversed by the case mix", none = "Rate and mix effects")))
  .bl_grid(NULL)
  graphics::abline(h = 0, col = "#666666")
  for (i in 1:2) {
    graphics::rect(i - 0.35, ends[i], i + 0.35, ends[i + 1L], border = NA,
                   col = if (vals[i] >= 0) cols[1L] else cols[2L])
  }
  graphics::rect(3 - 0.35, 0, 3 + 0.35, o$change, border = "#333333", col = "#999999")
  # the bars' values, and the steps joined, so the waterfall reads as a sum
  graphics::segments(c(1.35, 2.35), ends[2:3], c(1.65, 2.65), ends[2:3], lty = 3, col = "#666666")
  # each value at the far end of its own bar: above a gain, below a loss, so neighbours never meet
  v3 <- c(vals, o$change)
  tip <- c(ends[2:3], o$change)
  graphics::text(1:3, tip, sprintf("%+.4f", v3), pos = ifelse(v3 >= 0, 3, 1), xpd = NA,
                 cex = min(0.75, bar_cex))
  graphics::par(op)
  invisible(NULL)
}
