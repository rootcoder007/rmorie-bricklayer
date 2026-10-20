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

#' Checks a positive (or, with `allow_zero`, non-negative) numeric argument.
#' @param x The value passed by the user.
#' @param arg The argument name, used in the error message.
#' @param allow_zero Whether zero is accepted.
#' @param scalar Whether one value is required.
#' @return A double vector.
#' @noRd
.rmbl_pos_num <- function(x, arg, allow_zero = FALSE, scalar = FALSE) {
  x <- .rmbl_num_input(x, arg)
  # a scalar argument with several values was read by its first one and the
  # rest dropped in silence
  if (scalar && length(x) > 1L) {
    stop(sprintf("`%s` must be a single number, got %d values", arg, length(x)), call. = FALSE)
  }
  if (any(!is.finite(x[!is.na(x)]))) {
    stop(.rmbl_fn(), sprintf("`%s` must be finite (no Inf)", arg), call. = FALSE)
  }
  x <- .rmbl_num(x, "x")
  if (!length(x)) stop(.rmbl_fn(), sprintf("`%s` must not be empty", arg), call. = FALSE)
  if (anyNA(x)) stop(sprintf("`%s` must not contain NA", arg), call. = FALSE)
  bad <- if (allow_zero) any(x < 0) else any(x <= 0)
  if (bad) {
    stop(
      sprintf(
        "`%s` must be %s", arg,
        if (allow_zero) "non-negative" else "positive"
      ),
      call. = FALSE
    )
  }
  x
}

#' Average daily population
#'
#' The mean number of person-days served per day over a period: a
#' STOCK, answering how many people are held at one time. Use it to report
#' how much confinement (or bed occupancy, shelter use, open caseload) a
#' system used over a year or any other window, from the days each person
#' spent in it. It is the measure capacity planning needs, because it counts
#' beds in use rather than people who passed through.
#'
#' @param days Numeric vector of person-days served during the period,
#'   non-negative, no \code{NA} or \code{Inf}. The vector is summed, so one
#'   element per person and a single pre-computed total give the same result.
#' @param t Numeric scalar, the length of the period in days; must be
#'   positive. Default \code{365}. A vector of several values is refused.
#'   \code{\link{perdays}} turns two dates into this.
#'
#' @return A numeric scalar: person-days per day, that is the average number
#'   of people held on any one day of the period.
#'
#' @details
#' This is Lakner's \eqn{\bar{X}_{hc} = \sum X_i / t} (1976, p.15), where
#' \eqn{X_i} is the days served by person \eqn{i} inside the period. The
#' denominator is TIME, which is what makes it a stock. Compare
#' [alos()], whose denominator is people: the two are linked by
#' \eqn{\mathrm{ADP} = N \times \mathrm{ALOS} / t} (Little's law), so
#' [admits()] and [stkflow()]
#' can move between them.
#'
#' Only days served inside the period should be counted: a stay that began
#' before the period or ends after it contributes its days within the window.
#'
#' Errors when \code{days} is not numeric (text and factors are refused),
#' is empty, has \code{NA}, \code{Inf} or a negative value, or when
#' \code{t} is not a single positive number.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [alos()],
#'   [stkflow()],
#'   [adpcnts()]
#'
#' @examples
#' # Lakner's own worked example (p.15): 3,000 inmates served 13,500
#' # detention days in a year.
#' adp(13500)
#'
#' # per-person days give the same total
#' adp(c(10, 20, 30), t = 30)
#'
#' # a leap year, with the period length taken from the dates
#' adp(13500, t = perdays("2024-01-01", "2024-12-31"))
#'
#' # negative days are refused
#' try(adp(c(10, -2)))
#' @export
adp <- function(days, t = 365) {
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  t <- .rmbl_pos_num(t, "t", scalar = TRUE)
  sum(days) / t
}

#' Average length of stay
#'
#' The mean number of person-days served per person: the FLOW side of
#' the same person-days. Use it to say how long a typical admission lasts,
#' and together with [adp()] to tell whether a change in the population
#' held
#' came from more people or from longer stays. For the full distribution of
#' stays (median, spread, interval) use [staysmry()].
#'
#' @param days Numeric vector of person-days served during the period,
#'   non-negative, no \code{NA} or \code{Inf}; the vector is summed.
#' @param n Numeric scalar, the number of people; must be positive. A
#'   vector of several values is refused. For an unbiased average this should be the
#'   people both admitted AND released within the period, because anyone
#'   still held has an unfinished stay.
#'
#' @return A numeric scalar: days per person, \eqn{\sum X_i / n}.
#'
#' @details
#' Lakner's \eqn{\bar{X}_t = \sum X_i / N'} (1976, p.16), with a caveat
#' worth repeating (p.16-17): the period must be longer than the longest
#' stay people actually serve, or the average is biased DOWNWARD, since
#' the longest stays are the ones that fail to finish inside the window.
#' For short-stay facilities a year is comfortable; for long sentences it
#' is not, and the period has to be set from the records.
#'
#' Errors when \code{days} is not numeric, is empty, or has \code{NA},
#' \code{Inf} or negative values, and when \code{n} is not a single positive
#' number.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [adp()], [stkflow()]
#'
#' @examples
#' # Lakner (p.17): 2,700 inmates admitted and released served 12,150
#' # detention days between them.
#' alos(12150, 2700)
#'
#' # from one value per released person
#' stays <- c(2, 5, 1, 30, 4, 7)
#' alos(stays, length(stays))
#'
#' # zero people cannot have an average stay
#' try(alos(12150, 0))
#' @export
#' @srrstats {G5.4c} test-custody.R uses stored values from Lakner (1976) worked examples (p.15, p.17, p.20).
alos <- function(days, n) {
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  n <- .rmbl_pos_num(n, "n", scalar = TRUE)
  sum(days) / n
}

#' Admissions implied by a population and a length of stay
#'
#' Works out how many admissions a given average daily population and
#' average length of stay imply over a period. Published statistics often
#' give the population held and the average stay but not the number
#' admitted (or the other way round); this recovers the missing quantity
#' from the identity that links all three.
#'
#' @param adp Numeric scalar, the average daily population (people held on
#'   an average day); must be positive.
#' @param alos Numeric scalar, the average length of stay in days; must be
#'   positive.
#' @param t Numeric scalar, the length of the period in days; must be
#'   positive. Default \code{365}.
#'
#' @return A numeric scalar: the implied number of admissions over the
#'   period, \eqn{\mathrm{adp} \times t / \mathrm{alos}}. It is not rounded.
#'
#' @details
#' Rearranging the identity \eqn{\bar{X}_{hc} = N_a \bar{X}_t / t}
#' (Lakner 1976, p.18-20) for \eqn{N_a}. Useful when two of the three
#' quantities are published and the third is not. The identity holds
#' exactly only in a steady state (admissions and stays roughly constant
#' across the period); with a population that is growing or shrinking
#' quickly the result is an approximation.
#'
#' Errors when any argument is not numeric, is \code{NA} or \code{Inf}, is
#' not positive, or has more than one value.
#'
#' @seealso [adp()],
#'   [alos()],
#'   [stkflow()]
#'
#' @examples
#' # Lakner (p.20) runs this the other way: t = 365, an average daily
#' # population of 25 and 1,750 admissions imply a stay of 5.2 days.
#' alosimplied <- 25 * 365 / 1750
#' round(alosimplied, 1)
#'
#' # and back again
#' admits(25, alosimplied)
#'
#' # a 90-day quarter with 40 held on average and a 12-day average stay
#' admits(40, 12, t = 90)
#'
#' # an average stay of zero is refused
#' try(admits(25, 0))
#' @export
admits <- function(adp, alos, t = 365) {
  adp <- .rmbl_pos_num(adp, "adp", scalar = TRUE)
  alos <- .rmbl_pos_num(alos, "alos", scalar = TRUE)
  t <- .rmbl_pos_num(t, "t", scalar = TRUE)
  adp * t / alos
}

#' Person-days estimated from periodic headcounts
#'
#' When only a count of people present on certain days is available --
#' not a record per person -- the person-days over the period are the
#' mean of those counts scaled to the period's length.
#' Use it with [adp()] or [alos()] when the source
#' is a daily or weekly
#' count sheet rather than admission and release dates.
#'
#' @param cnts Numeric vector of headcounts, one per day on which a count
#'   was taken; non-negative, no \code{NA} or \code{Inf}. The days need not
#'   be consecutive.
#' @param t Numeric scalar, the length of the period in days; must be
#'   positive. Default \code{365}.
#'
#' @return A numeric scalar: the estimated person-days over the period,
#'   \code{mean(counts) * t}. Despite the function's name this is a total of
#'   person-days, not an average daily population; divide by \code{t} (or
#'   pass it to [adp()]) for the population held on an average day.
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
#' adpcnts(rep(34935 / 255, 255))
#'
#' # weekly counts over a 31-day month, then the average daily population
#' pd <- adpcnts(c(120, 130, 125, 128), t = 31)
#' pd
#' adp(pd, t = 31)
#'
#' # a missing count must be dropped or filled first
#' try(adpcnts(c(120, NA, 125)))
#' @export
adpcnts <- function(cnts, t = 365) {
  cnts <- .rmbl_pos_num(cnts, "cnts", allow_zero = TRUE)
  t <- .rmbl_pos_num(t, "t", scalar = TRUE)
  mean(cnts) * t
}

#' Stock and flow side by side, with the decomposition
#'
#' Reports the same person-days as a stock and as a flow, and says how
#' much of any change in the stock came from the number of people and
#' how much from how long they stayed.
#' Use it whenever a report compares periods: the count of people (a flow)
#' and the population held (a stock) can move in opposite directions when the
#' length of stay changes, and a table with only one of them implies the wrong
#' direction for the other.
#'
#' @param days Numeric vector of person-days, one element per period;
#'   non-negative, no \code{NA} or \code{Inf}.
#' @param people Numeric vector of the number of people (admissions or
#'   persons served), one element per period, the same length as
#'   \code{days}; positive.
#' @param prd Optional labels for the periods (any vector, converted to
#'   character), one per period. Default \code{NULL} labels them
#'   \code{1, 2, ...}.
#' @param t Numeric, the length of each period in days: one value for all
#'   periods, or one per period; positive. Default \code{365}.
#'   [perdays()] turns dates into this.
#' @param expo Optional numeric population to express rates against,
#'   one value or one per period, positive; for example provincial
#'   residents. Default \code{NULL} (no rate columns).
#' @param per Numeric scalar, the rate base when \code{expo} is given:
#'   rates are per \code{per} residents. Default \code{100000}.
#' @param base Character scalar, what the change columns compare
#'   against: \code{"first"} (the default) measures every period against the
#'   first, which is what a report on a whole window wants;
#'   \code{"previous"} measures each period against the one before it,
#'   which is what a series wants (the first row's changes are then
#'   \code{NA}).
#'
#' @return A data frame of class \code{c("rmbl_stock_flow", "data.frame")},
#'   one row per period, with columns \code{period} (character),
#'   \code{people}, \code{days}, \code{alos} (days per person),
#'   \code{adp} (days divided by \code{t}); when \code{exposure} is given
#'   also \code{exposure}, \code{flowrate} (people per \code{per}
#'   residents) and \code{stkrate} (\code{adp} per \code{per}
#'   residents). Then the percentage changes against the baseline:
#'   \code{peochg}, \code{aloschg}, \code{dayschg},
#'   \code{adpchg}, and with \code{exposure} also
#'   \code{flowratechg} and \code{stkratechg}. Attribute
#'   \code{"stkflow"} is a list with \code{t} (the period lengths),
#'   \code{baseline} and \code{per} (\code{NA} without \code{exposure}).
#'   The print method shows the levels and a footer with the change from the
#'   baseline to the last period, flagging rates with opposite signs.
#'
#' @details
#' The decomposition is exact, because days are people times length of
#' stay: a change in days is \eqn{(1+p)(1+l) - 1} for proportional
#' changes \eqn{p} in people and \eqn{l} in stay. The two rates can
#' therefore carry OPPOSITE signs, and the point of putting them in one
#' table is that neither can then be quoted alone.
#'
#' Changes are percentages: \eqn{100 (v_i / v_b - 1)} with \eqn{b} the
#' baseline row. Errors when \code{days} and \code{people} differ in length,
#' when \code{expo} has a length other than 1 or the number of periods,
#' when \code{t} has a length other than 1 or the number of periods, when
#' \code{prd} has a length other than the number of periods, when
#' \code{per} has more than one value, when any input has \code{NA},
#' \code{Inf}, text, or a value that is negative (\code{days}) or not
#' positive (the others), and when \code{base} is not one of the two
#' choices.
#'
#' @references
#' Lakner, E. (1976) \emph{A Manual of Statistical Sampling Methods for
#' Corrections Planners}. University of Illinois at Urbana-Champaign.
#'
#' @seealso [adp()], [alos()]
#'
#' @examples
#' # Fewer people, held longer: the flow falls while the stock rises.
#' stkflow(
#'   days = c(115674, 126121), people = c(12647, 9608),
#'   prd = c("2023", "2025"),
#'   expo = c(15495050, 16256538)
#' )
#'
#' # a series of three years against the previous year, with leap-year lengths
#' sf <- stkflow(
#'   days = c(100200, 104000, 99000), people = c(9800, 9500, 9900),
#'   prd = 2023:2025, t = c(365, 366, 365), base = "previous"
#' )
#' as.data.frame(sf)[, c("period", "alos", "adp", "peochg", "adpchg")]
#'
#' # days and people must line up period by period
#' try(stkflow(days = c(100, 120), people = c(10, 12, 14)))
#' @export
#' @srrstats {TS4.3} Returns alos in days per person, adp per day, and attr "stkflow"$t with each period's length in
#'   days.
stkflow <- function(days, people, prd = NULL, t = 365,
                       expo = NULL, per = 100000,
                       base = c("first", "previous")) {
  base <- .rmbl_arg(base)
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  people <- .rmbl_pos_num(people, "people")
  if (length(days) != length(people)) {
    stop("`days` and `people` must be the same length", call. = FALSE)
  }
  t <- .rmbl_pos_num(t, "t")
  if (length(t) == 1L) t <- rep(t, length(days))
  if (length(t) != length(days)) {
    stop("`t` must be length 1 or the same length as `days`", call. = FALSE)
  }
  if (is.null(prd)) prd <- seq_along(days)
  if (length(prd) != length(days)) {
    stop("`prd` must have one label per period (the length of `days`)", call. = FALSE)
  }
  out <- data.frame(
    period = as.character(prd), people = people,
    days = days, stringsAsFactors = FALSE
  )
  out$alos <- days / people
  out$adp <- days / t
  if (!is.null(expo)) {
    expo <- .rmbl_pos_num(expo, "expo")
    if (length(expo) == 1L) expo <- rep(expo, length(days))
    if (length(expo) != length(days)) {
      stop("`expo` must be length 1 or the same length as `days`",
        call. = FALSE
      )
    }
    per <- .rmbl_pos_num(per, "per", scalar = TRUE)
    if (per > 1e12) stop("`per` must be at most 1e12 (a population unit, such as 100000)", call. = FALSE)
    out$exposure <- expo
    out$flowrate <- per * people / expo
    out$stkrate <- per * out$adp / expo
  }
  ## The change columns are what make the two signs visible beside each
  ## other, so which baseline they use is a reporting decision rather
  ## than a detail: against the first period for a window, against the
  ## previous one for a series.
  chg <- if (identical(base, "first")) {
    function(v) 100 * (v / v[1L] - 1)
  } else {
    function(v) c(NA_real_, 100 * (v[-1L] / v[-length(v)] - 1))
  }
  out$peochg <- chg(out$people)
  out$aloschg <- chg(out$alos)
  out$dayschg <- chg(out$days)
  out$adpchg <- chg(out$adp)
  if (!is.null(expo)) {
    out$flowratechg <- chg(out$flowrate)
    out$stkratechg <- chg(out$stkrate)
  }
  structure(out,
    class = c("rmbl_stock_flow", "data.frame"),
    stkflow = list(
      t = t, baseline = base,
      per = if (is.null(expo)) NA else per
    )
  )
}

#' @export
print.rmbl_stock_flow <- function(x, ...) {
  has_rate <- "stkrate" %in% names(x)
  cols <- c("period", "people", "days", "alos", "adp")
  if (has_rate) cols <- c(cols, "flowrate", "stkrate")
  footer <- NULL
  if (nrow(x) > 1L) {
    i <- nrow(x)
    base <- attr(x, "stkflow")$baseline
    from <- if (identical(base, "previous")) x$period[i - 1L] else x$period[1L]
    footer <- sprintf(
      "%s to %s: people %+.1f%%, stay %+.1f%%, days %+.1f%%",
      from, x$period[i], x$peochg[i],
      x$aloschg[i], x$dayschg[i]
    )
    if (has_rate) {
      footer <- c(footer, sprintf(
        "flow rate %+.1f%%, stock rate %+.1f%%%s",
        x$flowratechg[i], x$stkratechg[i],
        if (sign(x$flowratechg[i]) != sign(x$stkratechg[i]))
          "  <- opposite signs: quote both" else ""
      ))
    }
  }
  .rmbl_print_table(paste("Stock and flow over", nrow(x), "periods"),
    x[, cols, drop = FALSE],
    footer = footer, ...
  )
  invisible(x)
}

#' Period length in days, from dates
#'
#' Counts the days from one date to another, both ends included, so the
#' result can be passed as the period length \code{t} to [adp()],
#' [admits()],
#' [adpcnts()] and
#' [stkflow()]. It saves getting
#' a fiscal year, a quarter or a leap year wrong by a day.
#'
#' @param from Start of the period: a single \code{Date}, or a single value
#'   \code{as.Date()} accepts (such as \code{"2024-01-01"}). Numbers are
#'   refused.
#' @param to End of the period, inclusive, in the same forms; must not be
#'   before \code{from}.
#'
#' @return A numeric scalar: the number of days in the period,
#'   \code{to - from + 1}, for use as \code{t}.
#'
#' @details
#' Inclusive of both ends, because a period running from the 1st to the
#' 31st is thirty-one days of exposure, not thirty. Leap years need no
#' special handling: the arithmetic is on dates, so 2024 comes out at
#' 366 and 2023 at 365 without anyone choosing.
#'
#' Errors when either argument is numeric, has a length other than one, is
#' \code{NA}, or when \code{to} precedes \code{from}. Text that is not a
#' date fails inside \code{as.Date()} with base R's own message.
#'
#' @seealso [adp()]
#'
#' @examples
#' perdays("2024-01-01", "2024-12-31") # a leap year
#' perdays("2023-01-01", "2023-12-31")
#' perdays("2025-04-01", "2026-03-31") # a fiscal year
#'
#' # a quarter as the period of an average daily population
#' adp(4200, t = perdays(as.Date("2025-01-01"), as.Date("2025-03-31")))
#'
#' # numbers are not dates, and the end cannot come first
#' try(perdays(1, 31))
#' try(perdays("2024-12-31", "2024-01-01"))
#' @export
#' @srrstats {TS1.8} Day counts use Gregorian Date arithmetic, so leap years give 366 (test-custody.R:140); the
#'   Hawkes sinusoid documents a 365.25-day year.
perdays <- function(from, to) {
  if (is.numeric(from) || is.numeric(to)) {
    stop("`from` and `to` must be dates or date strings, not numbers",
      call. = FALSE
    )
  }
  # text that is no date, a list, a frame or a flag: said, not as.Date()'s "character string is not in
  # a standard unambiguous format" (re-test of the b617a3f CRAN stress fixes, hostile battery)
  as_day <- function(v, what) {
    if (length(v) != 1L || !(inherits(v, c("Date", "POSIXt")) || is.character(v))) {
      stop("`from` and `to` must each be a single date", call. = FALSE)
    }
    if (is.na(v)) return(as.Date(NA))   # refused below, as a missing date
    d <- tryCatch(as.Date(v), error = function(e) as.Date(NA))
    if (is.na(d)) stop(sprintf("`%s` is not a date: %s", what, format(v)), call. = FALSE)
    d
  }
  from <- as_day(from, "from")
  to <- as_day(to, "to")
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
#' @param daysperper Numeric vector of days served, one element per
#'   person; non-negative, no \code{NA} or \code{Inf}, at least one value.
#' @param conflvl Numeric scalar strictly between 0 and 1, the
#'   confidence level for the interval on the mean. Default \code{0.95}.
#'
#' @return A one-row data frame with numeric columns \code{n} (people),
#'   \code{totaldays}, \code{mean}, \code{sd} (sample standard
#'   deviation), \code{median}, \code{iqr} (interquartile range, quantile
#'   type 7), \code{max}, \code{se} (standard error of the mean),
#'   \code{lower} and \code{upper} (the t interval on the mean). With a
#'   single person \code{sd}, \code{se}, \code{lower} and \code{upper}
#'   are \code{NA}.
#'
#' @details
#' The interval is the ordinary t interval on a mean,
#' \eqn{\bar{x} \pm t_{n-1, 1-\alpha/2}\, s / \sqrt{n}}. It describes
#' uncertainty about the AVERAGE stay, not the spread of stays, and on a
#' skewed distribution the median and the interquartile range say more
#' about a typical stay than the mean does -- which is why they are
#' returned beside it rather than left to be asked for.
#'
#' Lakner's caveat on [alos()] applies here too (1976, p.16-17): a
#' person still held has an unfinished stay, so a window shorter than
#' the longest stay biases the mean DOWNWARD.
#'
#' Errors when \code{daysperper} is not numeric, is empty, or has
#' \code{NA}, \code{Inf} or negative values, and when \code{conflvl}
#' is not strictly inside (0, 1).
#'
#' @seealso [alos()],
#'   [adp()],
#'   [stkflow()]
#'
#' @examples
#' # a skewed distribution: most stays short, a few long
#' stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
#' staysmry(stays)
#'
#' # the mean is pulled well above the median by the long tail
#' staysmry(stays)[, c("mean", "median", "max")]
#'
#' # a 90% interval instead of 95%
#' staysmry(stays, conflvl = 0.90)[, c("mean", "lower", "upper")]
#'
#' # a confidence level of 1 is refused
#' try(staysmry(stays, conflvl = 1))
#' @export
staysmry <- function(daysperper, conflvl = 0.95) {
  x <- .rmbl_pos_num(daysperper, "daysperper", allow_zero = TRUE)
  conflvl <- .rmbl_conf_level(conflvl)
  n <- length(x)
  m <- mean(x)
  s <- if (n > 1L) stats::sd(x) else NA_real_
  se <- if (n > 1L) s / sqrt(n) else NA_real_
  tq <- if (n > 1L) stats::qt(1 - (1 - conflvl) / 2, df = n - 1L) else NA_real_
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE, type = 7)
  data.frame(
    n = n, totaldays = sum(x), mean = m, sd = s, median = q[2],
    iqr = q[3] - q[1], max = max(x), se = se,
    lower = if (n > 1L) m - tq * se else NA_real_,
    upper = if (n > 1L) m + tq * se else NA_real_,
    stringsAsFactors = FALSE
  )
}
