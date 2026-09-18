# Stock and flow measures for a population held over time.
#
# Two quantities share a numerator -- person-days -- and differ only in
# the denominator. Lakner, A Manual of Statistical Sampling Methods for
# Corrections Planners (University of Illinois at Urbana-Champaign,
# 1976), puts it in one sentence: the average daily population is the
# mean number of detention days served PER DAY, and the average length
# of stay is the mean number served PER INMATE.
#
#   adp(days, t)      = sum(days) / t    a STOCK: how many are held at once
#   alos(days, n)     = sum(days) / n    a FLOW denominator: how long each stays
#   adp = n * alos / t                   the identity linking them
#
# Getting these the wrong way round is not a rounding matter. Counting
# people per year and calling it a rate of confinement answers "how many
# were affected"; the average daily population answers "how much
# confinement was used". When length of stay moves, the two can move in
# OPPOSITE directions, and a report that gives only one implies the
# wrong sign for the other. That is the whole reason these are here.
#
# Nothing about the arithmetic is specific to custody: the same
# relationship governs hospital beds, shelter occupancy and open
# caseloads. It is Little's law with the names corrections planning uses.

.rmbl_pos_num <- function(x, arg, allow_zero = FALSE) {
  x <- .rmbl_num_input(x, arg)
  if (any(!is.finite(x[!is.na(x)]))) {
    stop(sprintf("`%s` must be finite (no Inf)", arg), call. = FALSE)
  }
  x <- as.numeric(x)
  if (!length(x)) stop(sprintf("`%s` must not be empty", arg), call. = FALSE)
  if (anyNA(x)) stop(sprintf("`%s` must not contain NA", arg), call. = FALSE)
  bad <- if (allow_zero) any(x < 0) else any(x <= 0)
  if (bad) {
    stop(sprintf("`%s` must be %s", arg,
                 if (allow_zero) "non-negative" else "positive"),
         call. = FALSE)
  }
  x
}

#' Average daily population
#'
#' The mean number of person-days served per day over a period: a
#' STOCK, answering how many people are held at one time.
#'
#' @param days Person-days served during the period. A vector is summed,
#'   so one element per person is the usual input.
#' @param t Length of the period in days. Default 365.
#'
#' @return A single number: person-days per day.
#'
#' @details
#' This is Lakner's \eqn{\bar{X}_{hc} = \sum X_i / t} (1976, p.15). The
#' denominator is TIME, which is what makes it a stock. Compare
#' [alos()], whose denominator is people.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [alos()],
#'   [stock_flow()],
#'   [adp_from_counts()]
#'
#' @examples
#' # Lakner's own worked example (p.15): 3,000 inmates served 13,500
#' # detention days in a year.
#' adp(13500)
#'
#' # per-person days give the same total
#' adp(c(10, 20, 30), t = 30)
#' @export
adp <- function(days, t = 365) {
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  t <- .rmbl_pos_num(t, "t")[1L]
  sum(days) / t
}

#' Average length of stay
#'
#' The mean number of person-days served per person: the FLOW side of
#' the same person-days.
#'
#' @param days Person-days served during the period, summed.
#' @param n Number of people. For an unbiased average this should be the
#'   people both admitted AND released within the period, because anyone
#'   still held has an unfinished stay.
#'
#' @return A single number: days per person.
#'
#' @details
#' Lakner's \eqn{\bar{X}_t = \sum X_i / N'} (1976, p.16), with a caveat
#' worth repeating (p.16-17): the period must be longer than the longest
#' stay people actually serve, or the average is biased DOWNWARD, since
#' the longest stays are the ones that fail to finish inside the window.
#' For short-stay facilities a year is comfortable; for long sentences it
#' is not, and the period has to be set from the records.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [adp()], [stock_flow()]
#'
#' @examples
#' # Lakner (p.17): 2,700 inmates admitted and released served 12,150
#' # detention days between them.
#' alos(12150, 2700)
#' @export
alos <- function(days, n) {
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  n <- .rmbl_pos_num(n, "n")[1L]
  sum(days) / n
}

#' Admissions implied by a population and a length of stay
#'
#' @param adp Average daily population.
#' @param alos Average length of stay in days.
#' @param t Length of the period in days. Default 365.
#'
#' @return The implied number of admissions.
#'
#' @details
#' Rearranging the identity \eqn{\bar{X}_{hc} = N_a \bar{X}_t / t}
#' (Lakner 1976, p.18-20) for \eqn{N_a}. Useful when two of the three
#' quantities are published and the third is not.
#'
#' @seealso [adp()],
#'   [alos()],
#'   [stock_flow()]
#'
#' @examples
#' # Lakner (p.20) runs this the other way: t = 365, an average daily
#' # population of 25 and 1,750 admissions imply a stay of 5.2 days.
#' alos_implied <- 25 * 365 / 1750
#' round(alos_implied, 1)
#'
#' # and back again
#' admissions(25, alos_implied)
#' @export
admissions <- function(adp, alos, t = 365) {
  adp <- .rmbl_pos_num(adp, "adp")[1L]
  alos <- .rmbl_pos_num(alos, "alos")[1L]
  t <- .rmbl_pos_num(t, "t")[1L]
  adp * t / alos
}

#' Person-days estimated from periodic headcounts
#'
#' When only a count of people present on certain days is available --
#' not a record per person -- the person-days over the period are the
#' mean of those counts scaled to the period's length.
#'
#' @param counts Headcounts, one per day on which a count was taken.
#' @param t Length of the period in days. Default 365.
#'
#' @return Estimated person-days over the period.
#'
#' @details
#' Lakner's \eqn{X_t = (\frac{1}{C}\sum N_i) t} (1976, p.21). The counts
#' need not cover every day: counting on weekdays only is the usual case,
#' and the mean of the days counted stands in for the days not counted.
#' That substitution is an assumption, and it fails if the days counted
#' differ systematically from the days missed -- weekday-only counting
#' where weekend admissions are released before Monday, for instance.
#'
#' @seealso [adp()]
#'
#' @examples
#' # Lakner (p.21): counts on 255 days summing to 34,935 imply just over
#' # fifty thousand detention days across the year.
#' adp_from_counts(rep(34935 / 255, 255))
#' @export
adp_from_counts <- function(counts, t = 365) {
  counts <- .rmbl_pos_num(counts, "counts", allow_zero = TRUE)
  t <- .rmbl_pos_num(t, "t")[1L]
  mean(counts) * t
}

#' Stock and flow side by side, with the decomposition
#'
#' Reports the same person-days as a stock and as a flow, and says how
#' much of any change in the stock came from the number of people and
#' how much from how long they stayed.
#'
#' @param days Person-days, one element per period.
#' @param people Number of people, one element per period.
#' @param period Optional labels for the periods.
#' @param t Length of each period in days, one value or one per period.
#'   Default 365. [period_days()] turns dates into this.
#' @param exposure Optional population to express rates against, one per
#'   period; for example provincial residents.
#' @param per Rate denominator when `exposure` is given. Default 100000.
#' @param baseline What the change columns compare against: `"first"`
#'   (the default) measures every period against the first, which is
#'   what a report on a whole window wants; `"previous"` measures each
#'   period against the one before it, which is what a series wants.
#'
#' @return A data frame of class `rmbl_stock_flow`, one row per period:
#'   `people`, `days`, `alos`, `adp`, and when `exposure` is supplied
#'   `flow_rate` and `stock_rate`. Change columns compare each period
#'   with the first.
#'
#' @details
#' The decomposition is exact, because days are people times length of
#' stay: a change in days is \eqn{(1+p)(1+l) - 1} for proportional
#' changes \eqn{p} in people and \eqn{l} in stay. The two rates can
#' therefore carry OPPOSITE signs, and the point of putting them in one
#' table is that neither can then be quoted alone.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [adp()], [alos()]
#'
#' @examples
#' # Fewer people, held longer: the flow falls while the stock rises.
#' stock_flow(days = c(115674, 126121), people = c(12647, 9608),
#'            period = c("2023", "2025"),
#'            exposure = c(15495050, 16256538))
#' @export
stock_flow <- function(days, people, period = NULL, t = 365,
                       exposure = NULL, per = 100000,
                       baseline = c("first", "previous")) {
  baseline <- match.arg(baseline)
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  people <- .rmbl_pos_num(people, "people")
  if (length(days) != length(people)) {
    stop("`days` and `people` must be the same length", call. = FALSE)
  }
  t <- .rmbl_pos_num(t, "t")
  if (length(t) == 1L) t <- rep(t, length(days))
  if (is.null(period)) period <- seq_along(days)
  out <- data.frame(period = as.character(period), people = people,
                    days = days, stringsAsFactors = FALSE)
  out$alos <- days / people
  out$adp <- days / t
  if (!is.null(exposure)) {
    exposure <- .rmbl_pos_num(exposure, "exposure")
    if (length(exposure) == 1L) exposure <- rep(exposure, length(days))
    if (length(exposure) != length(days)) {
      stop("`exposure` must be length 1 or the same length as `days`",
           call. = FALSE)
    }
    per <- .rmbl_pos_num(per, "per")[1L]
    out$exposure <- exposure
    out$flow_rate <- per * people / exposure
    out$stock_rate <- per * out$adp / exposure
  }
  ## The change columns are what make the two signs visible beside each
  ## other, so which baseline they use is a reporting decision rather
  ## than a detail: against the first period for a window, against the
  ## previous one for a series.
  chg <- if (identical(baseline, "first")) {
    function(v) 100 * (v / v[1L] - 1)
  } else {
    function(v) c(NA_real_, 100 * (v[-1L] / v[-length(v)] - 1))
  }
  out$people_change <- chg(out$people)
  out$alos_change <- chg(out$alos)
  out$days_change <- chg(out$days)
  out$adp_change <- chg(out$adp)
  if (!is.null(exposure)) {
    out$flow_rate_change <- chg(out$flow_rate)
    out$stock_rate_change <- chg(out$stock_rate)
  }
  structure(out, class = c("rmbl_stock_flow", "data.frame"),
            stock_flow = list(t = t, baseline = baseline,
                              per = if (is.null(exposure)) NA else per))
}

#' @export
print.rmbl_stock_flow <- function(x, ...) {
  has_rate <- "stock_rate" %in% names(x)
  cols <- c("period", "people", "days", "alos", "adp")
  if (has_rate) cols <- c(cols, "flow_rate", "stock_rate")
  footer <- NULL
  if (nrow(x) > 1L) {
    i <- nrow(x)
    base <- attr(x, "stock_flow")$baseline
    from <- if (identical(base, "previous")) x$period[i - 1L] else x$period[1L]
    footer <- sprintf("%s to %s: people %+.1f%%, stay %+.1f%%, days %+.1f%%",
                      from, x$period[i], x$people_change[i],
                      x$alos_change[i], x$days_change[i])
    if (has_rate) {
      footer <- c(footer, sprintf(
        "flow rate %+.1f%%, stock rate %+.1f%%%s",
        x$flow_rate_change[i], x$stock_rate_change[i],
        if (sign(x$flow_rate_change[i]) != sign(x$stock_rate_change[i]))
          "  <- opposite signs: quote both" else ""))
    }
  }
  .rmbl_print_table(paste("Stock and flow over", nrow(x), "periods"),
                    x[, cols, drop = FALSE], footer = footer, ...)
  invisible(x)
}

#' Period length in days, from dates
#'
#' @param from Start of the period: a `Date`, or anything `as.Date()`
#'   accepts.
#' @param to End of the period, inclusive.
#'
#' @return The number of days in the period, for use as `t`.
#'
#' @details
#' Inclusive of both ends, because a period running from the 1st to the
#' 31st is thirty-one days of exposure, not thirty. Leap years need no
#' special handling: the arithmetic is on dates, so 2024 comes out at
#' 366 and 2023 at 365 without anyone choosing.
#'
#' @seealso [adp()]
#'
#' @examples
#' period_days("2024-01-01", "2024-12-31")   # a leap year
#' period_days("2023-01-01", "2023-12-31")
#' period_days("2025-04-01", "2026-03-31")   # a fiscal year
#' @export
period_days <- function(from, to) {
  if (is.numeric(from) || is.numeric(to)) {
    stop("`from` and `to` must be dates or date strings, not numbers",
         call. = FALSE)
  }
  from <- as.Date(from); to <- as.Date(to)
  if (length(from) != 1L || length(to) != 1L)
    stop("`from` and `to` must each be a single date", call. = FALSE)
  if (is.na(from) || is.na(to))
    stop("`from` and `to` must be dates", call. = FALSE)
  if (to < from) stop("`to` must not precede `from`", call. = FALSE)
  as.numeric(to - from) + 1
}

#' Length of stay with its distribution and interval
#'
#' Where [alos()] takes the total days and returns a mean, this takes
#' one value per person and reports the spread as well, because a mean
#' stay is a poor summary of a distribution that is usually skewed.
#'
#' @param days_per_person Days served, one element per person.
#' @param conf_level Confidence level for the interval on the mean.
#'
#' @return A one-row data frame: `n`, `total_days`, `mean`, `sd`,
#'   `median`, `iqr`, `max`, `se`, `lower`, `upper`.
#'
#' @details
#' The interval is the ordinary t interval on a mean. It describes
#' uncertainty about the AVERAGE stay, not the spread of stays, and on a
#' skewed distribution the median and the interquartile range say more
#' about a typical stay than the mean does -- which is why they are
#' returned beside it rather than left to be asked for.
#'
#' Lakner's caveat on [alos()] applies here too (1976, p.16-17): a
#' person still held has an unfinished stay, so a window shorter than
#' the longest stay biases the mean DOWNWARD.
#'
#' @seealso [alos()],
#'   [adp()],
#'   [stock_flow()]
#'
#' @examples
#' # a skewed distribution: most stays short, a few long
#' stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
#' stay_summary(stays)
#'
#' # the mean is pulled well above the median by the long tail
#' stay_summary(stays)[, c("mean", "median", "max")]
#' @export
stay_summary <- function(days_per_person, conf_level = 0.95) {
  x <- .rmbl_pos_num(days_per_person, "days_per_person", allow_zero = TRUE)
  conf_level <- as.numeric(conf_level)[1L]
  if (is.na(conf_level) || conf_level <= 0 || conf_level >= 1)
    stop("`conf_level` must lie strictly inside (0, 1)", call. = FALSE)
  n <- length(x)
  m <- mean(x)
  s <- if (n > 1L) stats::sd(x) else NA_real_
  se <- if (n > 1L) s / sqrt(n) else NA_real_
  tq <- if (n > 1L) stats::qt(1 - (1 - conf_level) / 2, df = n - 1L) else NA_real_
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE, type = 7)
  data.frame(n = n, total_days = sum(x), mean = m, sd = s, median = q[2],
             iqr = q[3] - q[1], max = max(x), se = se,
             lower = if (n > 1L) m - tq * se else NA_real_,
             upper = if (n > 1L) m + tq * se else NA_real_,
             stringsAsFactors = FALSE)
}
