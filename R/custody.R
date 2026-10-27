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
#'   of people held on any one day of the period. It has class
#'   \code{c("rmbl_adp", "rmbl_measure", "numeric")} and an attribute
#'   \code{"lakner"} (the total days and \code{t}), so it prints as a box
#'   with its inputs, formula and caveats; arithmetic, \code{round()},
#'   \code{sum()}, \code{mean()}, \code{[}, \code{c()} and
#'   \code{as.numeric()} give a plain number.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  .rmbl_measure(sum(days) / t, "adp", list(days = sum(days), t = t))
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
#' @param n Numeric scalar, the number of people; must be positive. A vector of
#'   several values is refused. For an unbiased average this should be the
#'   people both admitted AND released within the period, because anyone still
#'   held has an unfinished stay.
#'
#' @return A numeric scalar: days per person, \eqn{\sum X_i / n}. It has
#'   class \code{c("rmbl_alos", "rmbl_measure", "numeric")} and an attribute
#'   \code{"lakner"} (the total days and \code{n}), so it prints as a box
#'   with its inputs, formula and caveats; arithmetic, \code{round()},
#'   \code{sum()}, \code{mean()}, \code{[}, \code{c()} and
#'   \code{as.numeric()} give a plain number.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
#' @srrstats {G5.4c} test-custody.R uses stored values from Lakner (1976) worked
#'   examples (p.15, p.17, p.20).
alos <- function(days, n) {
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  n <- .rmbl_pos_num(n, "n", scalar = TRUE)
  .rmbl_measure(sum(days) / n, "alos", list(days = sum(days), n = n))
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
#'   It has class \code{c("rmbl_admits", "rmbl_measure", "numeric")} and an
#'   attribute \code{"lakner"} (\code{adp}, \code{alos} and \code{t}), so it
#'   prints as a box with its inputs, formula and caveats; arithmetic,
#'   \code{round()}, \code{sum()}, \code{mean()}, \code{[}, \code{c()} and
#'   \code{as.numeric()} give a plain number.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  .rmbl_measure(
    adp * t / alos,
    "admits",
    list(adp = adp, alos = alos, t = t)
  )
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
#'   pass it to [adp()]) for the population held on an average day. It has
#'   class \code{c("rmbl_adpcnts", "rmbl_measure", "numeric")} and an
#'   attribute \code{"lakner"} (the number of counts, their mean and
#'   \code{t}), so it prints as a box with its inputs, formula and caveats;
#'   arithmetic, \code{round()}, \code{sum()}, \code{mean()}, \code{[},
#'   \code{c()} and \code{as.numeric()} give a plain number, and
#'   [adp()] takes it as \code{days}.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  .rmbl_measure(
    mean(cnts) * t,
    "adpcnts",
    list(counts = length(cnts), mean = mean(cnts), t = t)
  )
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
#' @srrstats {TS4.3} Returns alos in days per person, adp per day, and attr
#'   "stkflow"$t with each period's length in days.
stkflow <- function(
  days,
  people,
  prd = NULL,
  t = 365,
  expo = NULL,
  per = 100000,
  base = c("first", "previous")
) {
  base <- .rmbl_arg(base)
  days <- .rmbl_pos_num(days, "days", allow_zero = TRUE)
  people <- .rmbl_pos_num(people, "people")
  if (length(days) != length(people)) {
    stop("`days` and `people` must be the same length", call. = FALSE)
  }
  t <- .rmbl_pos_num(t, "t")
  pr <- .rmbl_sf_periods(days, t, prd)
  out <- data.frame(
    period = as.character(pr$prd),
    people = people,
    days = days,
    stringsAsFactors = FALSE
  )
  out$alos <- days / people
  out$adp <- days / pr$t
  if (!is.null(expo)) {
    ex <- .rmbl_sf_rates(out, expo, per)
    out <- ex$out
    per <- ex$per
  }
  out <- .rmbl_sf_changes(out, base, !is.null(expo))
  structure(
    out,
    class = c("rmbl_stock_flow", "data.frame"),
    stkflow = list(
      t = pr$t,
      baseline = base,
      per = if (is.null(expo)) NA else per
    )
  )
}

#' @export
format.rmbl_stock_flow <- function(x, ...) {
  m <- attr(x, "stkflow")
  need <- c("period", "people", "days", "alos", "adp")
  # a subset keeps the class but not the record it was printed with
  if (is.null(m) || !all(need %in% names(x)) || !nrow(x)) {
    return(.an_plain(x, ...))
  }
  rates <- all(c("stkrate", "flowratechg", "stkratechg") %in% names(x))
  cols <- c(need, if (rates) c("flowrate", "stkrate"))
  .an_block(
    paste("Stock and flow over", nrow(x), "periods"),
    facts = .sf_facts(x, m, rates),
    tables = list(as.data.frame(x)[cols]),
    reading = .sf_reading(x, m, rates),
    notes = c(
      "Lakner (1976): adp = people x alos / t, exact only in a steady state.",
      "A period shorter than the longest stay cuts unfinished stays short,",
      "so alos is biased downward (p.16-17)."
    )
  )
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
#'   \code{to - from + 1}, for use as \code{t}. It has class
#'   \code{c("rmbl_perdays", "rmbl_measure", "numeric")} and an attribute
#'   \code{"lakner"} (\code{from} and \code{to} as dates), so it prints as a
#'   box; arithmetic, \code{round()}, \code{sum()}, \code{mean()},
#'   \code{[}, \code{c()} and \code{as.numeric()} give a plain number, and
#'   every \code{t} argument takes it as it is.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
#' @srrstats {TS1.8} Day counts use Gregorian Date arithmetic, so leap years
#'   give 366 (test-custody.R:140); the Hawkes sinusoid documents a 365.25-day
#'   year.
perdays <- function(from, to) {
  if (is.numeric(from) || is.numeric(to)) {
    stop(
      "`from` and `to` must be dates or date strings, not numbers",
      call. = FALSE
    )
  }
  from <- .rmbl_as_day(from, "from")
  to <- .rmbl_as_day(to, "to")
  if (is.na(from) || is.na(to)) {
    stop("`from` and `to` must be dates", call. = FALSE)
  }
  if (to < from) {
    stop("`to` must not precede `from`", call. = FALSE)
  }
  .rmbl_measure(
    as.numeric(to - from) + 1,
    "perdays",
    list(from = from, to = to)
  )
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
#' @return A one-row data frame of class
#'   \code{c("rmbl_stay_summary", "data.frame")} (its print method shows it as
#'   a box) with numeric columns \code{n} (people),
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
  out <- data.frame(
    n = n,
    totaldays = sum(x),
    mean = m,
    sd = s,
    median = q[2],
    iqr = q[3] - q[1],
    max = max(x),
    se = se,
    lower = if (n > 1L) m - tq * se else NA_real_,
    upper = if (n > 1L) m + tq * se else NA_real_,
    stringsAsFactors = FALSE
  )
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_stay_summary", class(out))
  out
}

#' @export
format.rmbl_stay_summary <- function(x, ...) {
  need <- c("n", "totaldays", "mean", "median", "iqr", "max", "lower", "upper")
  if (!all(need %in% names(x)) || nrow(x) != 1L) {
    return(.an_plain(x, ...))
  }
  lvl <- attr(x, "conflvl") %||% 0.95
  .an_block(
    "Length of stay",
    facts = list(
      People = x$n,
      `Days served` = x$totaldays,
      `Mean stay` = sprintf("%s days", .rmbl_fmt_num(x$mean)),
      `Median stay` = sprintf("%s days", .rmbl_fmt_num(x$median)),
      `Interquartile range` = sprintf("%s days", .rmbl_fmt_num(x$iqr)),
      `Longest stay` = sprintf("%s days", .rmbl_fmt_num(x$max)),
      `Standard deviation` = if (is.finite(x$sd)) x$sd,
      `Mean, interval` = if (is.finite(x$lower)) {
        paste(.an_ci(x$lower, x$upper), .an_lvl(lvl), "t interval")
      }
    ),
    reading = .ss_reading(x),
    notes = c(
      "The interval is on the AVERAGE stay, not the spread of stays.",
      "Lakner (1976, p.16-17): a person still held has an unfinished stay,",
      "so a window shorter than the longest stay biases the mean downward."
    )
  )
}

# ---- the single measures as boxes -------------------------------------------
# adp(), alos(), admits(), adpcnts() and perdays() return their number with a
# class in front and the inputs it came from in attribute "lakner", so it
# prints as a box. Everything else treats it as the plain number it is:
# arithmetic, Math and Summary functions, mean(), [, c() and as.numeric()
# drop the class, so it never leaks into later results.

#' @export
Ops.rmbl_measure <- function(e1, e2) {
  f <- get(.Generic, mode = "function", envir = baseenv())
  if (nargs() == 1L) {
    return(f(.rmbl_measure_plain(e1)))
  }
  f(.rmbl_measure_plain(e1), .rmbl_measure_plain(e2))
}

#' @export
Math.rmbl_measure <- function(x, ...) {
  f <- get(.Generic, mode = "function", envir = baseenv())
  f(.rmbl_measure_plain(x), ...)
}

#' @export
Summary.rmbl_measure <- function(..., na.rm = FALSE) {
  f <- get(.Generic, mode = "function", envir = baseenv())
  do.call(f, c(lapply(list(...), .rmbl_measure_plain), list(na.rm = na.rm)))
}

#' @export
mean.rmbl_measure <- function(x, ...) {
  mean(.rmbl_measure_plain(x), ...)
}

#' @export
as.double.rmbl_measure <- function(x, ...) {
  as.double(.rmbl_measure_plain(x))
}

#' @export
c.rmbl_measure <- function(...) {
  do.call(c, lapply(list(...), .rmbl_measure_plain))
}

#' @export
as.data.frame.rmbl_measure <- function(x, ..., nm = deparse1(substitute(x))) {
  as.data.frame(.rmbl_measure_plain(x), ..., nm = nm)
}

#' @export
format.rmbl_adp <- function(x, ...) {
  if (!.lk_ok(x, c("days", "t"))) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  d <- .rmbl_fmt_num(m$days)
  t <- .rmbl_fmt_num(m$t)
  .an_block(
    "Average daily population",
    facts = list(
      `Average daily population` = .lk_value(x, "people on an average day"),
      `Person-days` = d,
      Period = paste(t, "days"),
      Formula = sprintf("adp = days / t = %s / %s", d, t)
    ),
    tables = .lk_table(x, "adp"),
    reading = .lk_read(x, sprintf(
      "%s person-days over %s days: %s people held on an average day.",
      d,
      t,
      .rmbl_fmt_num(.rmbl_measure_plain(x))
    )),
    notes = c(
      "Lakner (1976, p.15): a stock -- people held at once, not people who",
      "passed through. Count only the days served inside the period.",
      "adp = n x alos / t links it to alos() and admits(), exactly only in a",
      "steady state."
    )
  )
}

#' @export
format.rmbl_alos <- function(x, ...) {
  if (!.lk_ok(x, c("days", "n"))) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  d <- .rmbl_fmt_num(m$days)
  n <- .rmbl_fmt_num(m$n)
  .an_block(
    "Average length of stay",
    facts = list(
      `Average stay` = .lk_value(x, "days per person"),
      `Person-days` = d,
      People = n,
      Formula = sprintf("alos = days / n = %s / %s", d, n)
    ),
    tables = .lk_table(x, "alos"),
    reading = .lk_read(x, sprintf(
      "%s people served %s days between them: %s days each on average.",
      n,
      d,
      .rmbl_fmt_num(.rmbl_measure_plain(x))
    )),
    notes = c(
      "Lakner (1976, p.16-17): n should be the people admitted AND released",
      "in the period. A period shorter than the longest stay cuts unfinished",
      "stays short, so alos is biased downward. staysmry() gives the median."
    )
  )
}

#' @export
format.rmbl_admits <- function(x, ...) {
  if (!.lk_ok(x, c("adp", "alos", "t"))) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  a <- .rmbl_fmt_num(m$adp)
  l <- .rmbl_fmt_num(m$alos)
  t <- .rmbl_fmt_num(m$t)
  .an_block(
    "Admissions implied by stock and stay",
    facts = list(
      Admissions = .lk_value(x, "over the period"),
      `Average daily population` = a,
      `Average stay` = paste(l, "days"),
      Period = paste(t, "days"),
      Formula = sprintf("admits = adp x t / alos = %s x %s / %s", a, t, l)
    ),
    tables = .lk_table(x, "admits"),
    reading = .lk_read(x, sprintf(
      "%s held on an average day, staying %s days each, imply %s %s %s days.",
      a,
      l,
      .rmbl_fmt_num(.rmbl_measure_plain(x)),
      "admissions over",
      t
    )),
    notes = c(
      "Lakner (1976, p.18-20): adp = admissions x alos / t is exact only in",
      "a steady state; with a population growing or shrinking quickly the",
      "result is an approximation. It is not rounded."
    )
  )
}

#' @export
format.rmbl_adpcnts <- function(x, ...) {
  if (!.lk_ok(x, c("counts", "mean", "t"))) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  k <- .rmbl_fmt_num(m$counts)
  mc <- .rmbl_fmt_num(m$mean)
  t <- .rmbl_fmt_num(m$t)
  .an_block(
    "Person-days from headcounts",
    facts = list(
      `Person-days` = .lk_value(x, "over the period"),
      Headcounts = paste(k, "days counted"),
      `Mean count` = paste(mc, "people"),
      Period = paste(t, "days"),
      Formula = sprintf("days = mean(counts) x t = %s x %s", mc, t)
    ),
    tables = .lk_table(x, "days"),
    reading = .lk_read(x, sprintf(
      "Counts on %s days average %s people: about %s person-days in %s days.",
      k,
      mc,
      .rmbl_fmt_num(.rmbl_measure_plain(x)),
      t
    )),
    notes = c(
      "Lakner (1976, p.21): the mean of the days counted stands in for the",
      "days not counted, which fails if they differ systematically (weekday",
      "counts where weekend admissions leave before Monday).",
      "A total of person-days, not a population: adp(x, t) divides by t."
    )
  )
}

#' @export
format.rmbl_perdays <- function(x, ...) {
  if (!.lk_ok(x, c("from", "to"))) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  .an_block(
    "Period length",
    facts = list(
      Length = .lk_value(x, "days"),
      From = format(m$from),
      To = format(m$to),
      Formula = "t = to - from + 1 (both ends counted)"
    ),
    tables = .lk_table(x, "days"),
    reading = .lk_read(x, c(
      sprintf(
        "From %s to %s is %s days.",
        format(m$from),
        format(m$to),
        .rmbl_fmt_num(.rmbl_measure_plain(x))
      ),
      "Pass it as t to adp(), admits(), adpcnts() or stkflow()."
    )),
    notes = c(
      "Both ends count: the 1st to the 31st is 31 days of exposure. A leap",
      "year comes out at 366 from the dates, without anyone choosing."
    )
  )
}

#' A Lakner measure: the number with its class and the inputs it came from.
#' @param v The number(s).
#' @param name The measure's name: "adp", "alos", "admits", ...
#' @param inputs Named list of the inputs, kept as attribute "lakner".
#' @return `v` with class c("rmbl_<name>", "rmbl_measure", "numeric").
#' @noRd
.rmbl_measure <- function(v, name, inputs) {
  structure(
    v,
    lakner = inputs,
    class = c(paste0("rmbl_", name), "rmbl_measure", "numeric")
  )
}

#' A measure as a plain double: its class and inputs dropped, names kept.
#' @param x A measure, or anything else (returned as it is).
#' @return A plain double vector.
#' @noRd
.rmbl_measure_plain <- function(x) {
  if (!inherits(x, "rmbl_measure")) {
    return(x)
  }
  nm <- names(x)
  x <- as.vector(unclass(x))
  names(x) <- nm
  x
}

#' Elements of a measure, as plain numbers: the `[` method of a measure.
#' @param x The measure.
#' @param ... The indices, as for `[`.
#' @return A plain double vector.
#' @noRd
.rmbl_measure_subset <- function(x, ...) {
  .rmbl_measure_plain(x)[...]
}

#' @export
`[.rmbl_measure` <- .rmbl_measure_subset

#' Whether a measure still has the record its block is built from.
#' @param x The measure.
#' @param need The inputs the block shows.
#' @return TRUE or FALSE.
#' @noRd
.lk_ok <- function(x, need) {
  m <- attr(x, "lakner")
  is.list(m) && all(need %in% names(m)) && length(x) > 0L
}

#' A measure without its record, formatted as the plain number.
#' @param x The measure.
#' @param ... Passed to format().
#' @return Strings.
#' @noRd
.lk_plain <- function(x, ...) {
  format(.rmbl_measure_plain(x), ...)
}

#' The number of a one-value measure with its unit, NULL for several values.
#' @param x The measure.
#' @param unit The unit.
#' @return One string, or NULL.
#' @noRd
.lk_value <- function(x, unit) {
  if (length(x) != 1L) {
    return(NULL)
  }
  paste(.rmbl_fmt_num(.rmbl_measure_plain(x)), unit)
}

#' A small table of a measure with several values, none for one value.
#' @param x The measure.
#' @param name The column's name.
#' @return A list of one data frame, or an empty list.
#' @noRd
.lk_table <- function(x, name) {
  if (length(x) < 2L) {
    return(list())
  }
  v <- .rmbl_measure_plain(x)
  d <- data.frame(
    value = if (is.null(names(v))) seq_along(v) else names(v),
    unname(v),
    stringsAsFactors = FALSE
  )
  names(d) <- c("value", name)
  list(d)
}

#' The reading of a measure: its sentence for one value, a pointer to the
#' table for several.
#' @param x The measure.
#' @param one The sentence for one value.
#' @return Strings.
#' @noRd
.lk_read <- function(x, one) {
  if (length(x) == 1L) one else "One value per row of the table."
}

#' Checks a positive (or, with `allow_zero`, non-negative) numeric argument.
#' @param x The argument's value, checked to be positive numbers.
#' @param arg The argument's name, quoted when a value is not positive.
#' @param allow_zero Whether zero is accepted.
#' @param scalar Whether one value is required.
#' @return A double vector.
#' @noRd
.rmbl_pos_num <- function(x, arg, allow_zero = FALSE, scalar = FALSE) {
  x <- .rmbl_num_input(x, arg)
  # a scalar argument with several values was read by its first one and the
  # rest dropped in silence
  if (scalar && length(x) > 1L) {
    stop(
      sprintf("`%s` must be a single number, got %d values", arg, length(x)),
      call. = FALSE
    )
  }
  if (!all(is.finite(x[!is.na(x)]))) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be finite (no Inf)", arg),
      call. = FALSE
    )
  }
  x <- .rmbl_num(x, "x")
  if (!length(x)) {
    stop(.rmbl_fn(), sprintf("`%s` must not be empty", arg), call. = FALSE)
  }
  if (anyNA(x)) {
    stop(sprintf("`%s` must not contain NA", arg), call. = FALSE)
  }
  bad <- if (allow_zero) any(x < 0) else any(x <= 0)
  if (bad) {
    stop(
      sprintf(
        "`%s` must be %s",
        arg,
        if (allow_zero) "non-negative" else "positive"
      ),
      call. = FALSE
    )
  }
  x
}

#' Checks stkflow()'s period lengths and labels against the periods.
#' @param days The checked `days` vector.
#' @param t The checked period lengths, length 1 or one per period.
#' @param prd The period labels, or `NULL` for 1, 2, ...
#' @return A list with `t` (one length per period) and `prd` (the labels).
#' @noRd
.rmbl_sf_periods <- function(days, t, prd) {
  if (length(t) == 1L) {
    t <- rep(t, length(days))
  }
  if (length(t) != length(days)) {
    stop("`t` must be length 1 or the same length as `days`", call. = FALSE)
  }
  if (is.null(prd)) {
    prd <- seq_along(days)
  }
  if (length(prd) != length(days)) {
    stop(
      "`prd` must have one label per period (the length of `days`)",
      call. = FALSE
    )
  }
  list(t = t, prd = prd)
}

#' Adds stkflow()'s exposure and the flow and stock rates.
#' @param out The stkflow() table so far (with `people` and `adp`).
#' @param expo,per As for stkflow().
#' @return A list with `out` (the table with `exposure`, `flowrate` and
#'   `stkrate`) and `per` (the checked unit).
#' @noRd
.rmbl_sf_rates <- function(out, expo, per) {
  expo <- .rmbl_pos_num(expo, "expo")
  if (length(expo) == 1L) {
    expo <- rep(expo, nrow(out))
  }
  if (length(expo) != nrow(out)) {
    stop(
      "`expo` must be length 1 or the same length as `days`",
      call. = FALSE
    )
  }
  per <- .rmbl_pos_num(per, "per", scalar = TRUE)
  if (per > 1e12) {
    stop(
      "`per` must be at most 1e12 (a population unit, such as 100000)",
      call. = FALSE
    )
  }
  out$exposure <- expo
  out$flowrate <- per * out$people / expo
  out$stkrate <- per * out$adp / expo
  list(out = out, per = per)
}

#' Adds stkflow()'s percentage-change columns.
#'
#' The change columns are what make the two signs visible beside each
#' other, so which baseline they use is a reporting decision rather
#' than a detail: against the first period for a window, against the
#' previous one for a series.
#' @param out The stkflow() table so far.
#' @param base `"first"` or `"previous"`.
#' @param rates Whether the table has the rate columns.
#' @return `out` with the change columns added.
#' @noRd
.rmbl_sf_changes <- function(out, base, rates) {
  chg <- if (identical(base, "first")) {
    function(v) 100 * (v / v[1L] - 1)
  } else {
    function(v) c(NA_real_, 100 * (v[-1L] / v[-length(v)] - 1))
  }
  out$peochg <- chg(out$people)
  out$aloschg <- chg(out$alos)
  out$dayschg <- chg(out$days)
  out$adpchg <- chg(out$adp)
  if (rates) {
    out$flowratechg <- chg(out$flowrate)
    out$stkratechg <- chg(out$stkrate)
  }
  out
}

#' One end of a perdays() period as a Date.
#'
#' Text that is no date, a list, a frame or a flag is said, not as.Date()'s
#' "character string is not in a standard unambiguous format" (re-test of the
#' b617a3f CRAN stress fixes, hostile battery).
#' @param v The value passed as `from` or `to`.
#' @param what The argument's name (`from` or `to`), quoted when not a date.
#' @return A Date of length one, `NA` for a missing date.
#' @noRd
.rmbl_as_day <- function(v, what) {
  if (
    length(v) != 1L || !(inherits(v, c("Date", "POSIXt")) || is.character(v))
  ) {
    stop("`from` and `to` must each be a single date", call. = FALSE)
  }
  if (is.na(v)) {
    return(as.Date(NA))
  } # refused by perdays(), as a missing date
  d <- tryCatch(as.Date(v), error = function(e) as.Date(NA))
  if (is.na(d)) {
    stop(sprintf("`%s` is not a date: %s", what, format(v)), call. = FALSE)
  }
  d
}

#' The facts of a stock and flow table: its periods, lengths and baseline.
#' @param x The stkflow() table.
#' @param m Its "stkflow" record.
#' @param rates Whether the table has the rate columns.
#' @return A named list.
#' @noRd
.sf_facts <- function(x, m, rates) {
  t <- unique(m$t)
  list(
    Periods = if (nrow(x) > 1L) {
      paste(x$period[1L], "to", x$period[nrow(x)])
    } else {
      x$period[1L]
    },
    `Period length` = if (length(t) == 1L) {
      sprintf("%s days", .rmbl_fmt_num(t))
    } else {
      toString(.rmbl_fmt_num(m$t))
    },
    `Changes against` = if (identical(m$baseline, "previous")) {
      "the previous period"
    } else {
      "the first period"
    },
    `Rates per` = if (rates) sprintf("%s residents", .rmbl_fmt_num(m$per)),
    Columns = "alos = days per person; adp = people held on an average day"
  )
}

#' The reading of a stock and flow table: the change to the last period, and
#' a flag when the flow and the stock moved in opposite directions.
#' @param x The stkflow() table.
#' @param m Its "stkflow" record.
#' @param rates Whether the table has the rate columns.
#' @return A character vector, or NULL for one period.
#' @noRd
.sf_reading <- function(x, m, rates) {
  if (nrow(x) < 2L) {
    return("One period: no change to report.")
  }
  i <- nrow(x)
  prev <- identical(m$baseline, "previous")
  from <- if (prev) x$period[i - 1L] else x$period[1L]
  out <- sprintf(
    "%s to %s: people %+.1f%%, stay %+.1f%%, days %+.1f%%",
    from,
    x$period[i],
    x$peochg[i],
    x$aloschg[i],
    x$dayschg[i]
  )
  if (rates) {
    opp <- isTRUE(sign(x$flowratechg[i]) != sign(x$stkratechg[i]))
    out <- c(
      out,
      sprintf(
        "flow rate %+.1f%%, stock rate %+.1f%%",
        x$flowratechg[i],
        x$stkratechg[i]
      ),
      if (opp) "<- opposite signs: quote both, neither alone tells the story"
    )
  }
  out
}

#' The reading of a length-of-stay summary: the mean against the median.
#' @param x The staysmry() row.
#' @return One or two sentences.
#' @noRd
.ss_reading <- function(x) {
  if (!is.finite(x$median) || x$median <= 0 || x$mean <= x$median) {
    return("The mean and the median stay agree: the stays are not skewed.")
  }
  c(
    sprintf(
      "The mean stay is %.1f times the median: a few long stays pull it up,",
      x$mean / x$median
    ),
    "so the median says more about a typical stay."
  )
}

# ---- printed blocks shared by the analysis families -------------------------
# The custody, justice, Indigenous, TRC, census, search, pollution and
# dispersion results print through these: one titled block (a box on the
# console), its facts, its tables fitted to the console's width, a reading
# and the caveats the source attaches to the measure.

#' One titled block for an analysis result, its tables fitted to the console.
#' @param title The block's title.
#' @param facts Named list of facts shown under the title.
#' @param tables List of data frames; a non-empty name is printed as a caption
#'   above its table.
#' @param reading Plain-language sentences.
#' @param notes Cautions and caveats.
#' @param digits Significant digits of the tables' numbers.
#' @return A character vector of lines.
#' @noRd
.an_block <- function(
  title,
  facts = list(),
  tables = list(),
  reading = NULL,
  notes = NULL,
  digits = 4L
) {
  head <- .rmbl_stat_block(title, facts)
  out <- head[-length(head)]
  caps <- names(tables) %||% rep("", length(tables))
  for (i in seq_along(tables)) {
    out <- c(out, .an_table_lines(tables[[i]], caps[i], digits))
  }
  if (length(reading)) {
    out <- c(out, "", paste0("  ", reading))
  }
  if (length(notes)) {
    out <- c(out, "", paste0("  ", notes))
  }
  c(out, .rmbl_rule())
}

#' One table of a block: a blank line, its caption, its fitted lines.
#' @param df The table, or NULL.
#' @param caption The caption, or "".
#' @param digits Significant digits of the table's numbers.
#' @return A character vector of lines (empty for no table).
#' @noRd
.an_table_lines <- function(df, caption, digits = 4L) {
  if (!is.data.frame(df) || !nrow(df) || !ncol(df)) {
    return(character())
  }
  c(
    "",
    if (!is.na(caption) && nzchar(caption)) paste0("  ", caption),
    .an_fit_table(df, digits)
  )
}

#' An estimate table split into column groups that fit the console, the
#' first column repeated in each.
#' @param df The estimate table to fit.
#' @param digits Significant digits of its numbers.
#' @return A character vector of lines.
#' @noRd
.an_fit_table <- function(df, digits = 4L) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  rownames(df) <- NULL
  lim <- .an_width()
  df <- .an_clip_cols(df, lim)
  wide <- function(cols) {
    max(nchar(.rmbl_stat_table(df[cols], digits), type = "width"))
  }
  if (ncol(df) < 3L || wide(seq_len(ncol(df))) <= lim) {
    return(.rmbl_stat_table(df, digits))
  }
  out <- character()
  rest <- seq_len(ncol(df))[-1L]
  while (length(rest)) {
    take <- rest[1L]
    for (j in rest[-1L]) {
      if (wide(c(1L, take, j)) > lim) {
        break
      }
      take <- c(take, j)
    }
    part <- .rmbl_stat_table(df[c(1L, take)], digits)
    out <- c(out, if (length(out)) "", part)
    rest <- setdiff(rest, take)
  }
  out
}

#' The widest line a box on this console holds.
#' @return An integer.
#' @noRd
.an_width <- function() {
  w <- .rmbl_print_caps()$width
  max(36L, min(w - 1L, 100L) - 4L)
}

#' A classed data frame printed as a plain one: what a subset that lost the
#' record its block needs prints as.
#' @param x The classed data frame to print plainly.
#' @param ... Passed to print().
#' @return The printed lines.
#' @noRd
.an_plain <- function(x, ...) {
  d <- as.data.frame(unclass(x), stringsAsFactors = FALSE)
  utils::capture.output(print(d, ...))
}

#' A confidence level as text, "95%".
#' @param conflvl The level, or NULL.
#' @return One string, or NULL.
#' @noRd
.an_lvl <- function(conflvl) {
  if (!is.numeric(conflvl) || length(conflvl) != 1L || is.na(conflvl)) {
    return(NULL)
  }
  sprintf("%g%%", 100 * conflvl)
}

#' The first rows of a table, and a line saying how many were left out.
#' @param df The table whose first rows are shown.
#' @param n The most rows shown.
#' @return A list: `df` (the rows shown) and `more` (one string, or NULL).
#' @noRd
.an_head <- function(df, n = 12L) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  more <- if (nrow(df) > n) {
    sprintf(
      "... and %d more rows: as.data.frame(x) has them all.",
      nrow(df) - n
    )
  }
  list(df = utils::head(df, n), more = more)
}

#' A note that rows were marked for caution, when any were.
#' @param flag The rows' caution flags.
#' @return One string, or NULL.
#' @noRd
.an_caution <- function(flag) {
  if (!any(.an_true(flag))) {
    return(NULL)
  }
  paste(
    "* use with caution: the source flags the estimate (E, high sampling",
    "variability)."
  )
}

#' Text labels marked with a star where flagged for caution.
#' @param lab The labels to mark.
#' @param flag The caution flags.
#' @return The labels.
#' @noRd
.an_star <- function(lab, flag) {
  paste0(lab, ifelse(.an_true(flag), " *", ""))
}

#' A table per value of a key column, named by the value.
#' @param d The rows.
#' @param key The key column.
#' @param fn A function of one key's rows returning its table.
#' @return A named list of data frames, in the order the keys appear.
#' @noRd
.an_by <- function(d, key, fn) {
  keys <- unique(as.character(d[[key]]))
  out <- lapply(keys, function(k) {
    fn(d[as.character(d[[key]]) %in% k, , drop = FALSE])
  })
  names(out) <- keys
  out
}

#' The name of an interval column: "95% CI", or "interval" when the level is
#' not recorded.
#' @param conflvl The level, or NULL.
#' @return One string.
#' @noRd
.an_ci_name <- function(conflvl) {
  lvl <- .an_lvl(conflvl)
  if (is.null(lvl)) "interval" else paste(lvl, "CI")
}

#' Indicator captions with the side each is on, "(wellness)" or "(distress)".
#' @param ind The indicator names to caption.
#' @param d The rows, with `indicator` and `side`.
#' @return The captions.
#' @noRd
.an_side_caption <- function(ind, d) {
  side <- d$side[match(ind, d$indicator)]
  ifelse(is.na(side) | !nzchar(side), ind, sprintf("%s (%s)", ind, side))
}

#' The distinct values of a column, as text: all of them when few, else the
#' count and the first and last.
#' @param v The column, or NULL.
#' @return One string, or NULL.
#' @noRd
.an_values <- function(v) {
  if (is.null(v) || !length(v)) {
    return(NULL)
  }
  u <- unique(as.character(v[!is.na(v)]))
  if (length(u) <= 4L) {
    return(paste(u, collapse = "; "))
  }
  sprintf("%d, from %s to %s", length(u), u[1L], u[length(u)])
}

#' A decimal year as the calendar year it falls in, or "never" at a zero pace.
#' @param v The decimal year.
#' @return One string.
#' @noRd
.an_year <- function(v) {
  if (!is.finite(v)) {
    return("never at this pace")
  }
  format(floor(v))
}

#' Text cut to a width, with an ellipsis where it was cut.
#' @param s The text to cut.
#' @param n The widest it may be.
#' @return The text.
#' @noRd
.an_clip <- function(s, n = 40L) {
  s <- as.character(s)
  long <- !is.na(s) & nchar(s) > n
  s[long] <- paste0(substr(s[long], 1L, n - 3L), "...")
  s
}

#' The census a profile comes from, read from its DGUIDs (their first four
#' characters are the vintage).
#' @param dguid The DGUIDs, or NULL.
#' @return One string, or NULL.
#' @noRd
.an_census_year <- function(dguid) {
  v <- unique(substr(as.character(dguid[!is.na(dguid)]), 1L, 4L))
  v <- v[grepl("^[0-9]{4}$", v)]
  if (!length(v)) {
    return(NULL)
  }
  paste0(toString(v), " Census of Population (DGUID vintage)")
}

#' Counts of each value, as text: "ok 670, E 2".
#' @param v The values, or NULL.
#' @return One string, or NULL.
#' @noRd
.an_counts <- function(v) {
  if (is.null(v) || !length(v)) {
    return(NULL)
  }
  tb <- table(as.character(v), useNA = "no")
  toString(sprintf("%s %d", names(tb), as.integer(tb)))
}

#' The range of a profile's global non-response rates.
#' @param d The profile, with `tnrsf` and `tnrlf`.
#' @return One string, or NULL.
#' @noRd
.an_nonresp <- function(d) {
  rng <- function(v) {
    v <- suppressWarnings(as.numeric(v))
    v <- v[is.finite(v)]
    if (!length(v)) {
      return(NULL)
    }
    if (min(v) == max(v)) {
      return(sprintf("%g%%", v[1L]))
    }
    sprintf("%g%% to %g%%", min(v), max(v))
  }
  sf <- rng(d$tnrsf)
  lf <- rng(d$tnrlf)
  if (is.null(sf) && is.null(lf)) {
    return(NULL)
  }
  paste(
    c(
      if (!is.null(sf)) paste("short form", sf),
      if (!is.null(lf)) paste("long form", lf)
    ),
    collapse = "; "
  )
}

#' An interval as [lower, upper], blank when both bounds are missing.
#' @param lo,hi The lower and upper bounds.
#' @param digits Significant digits of each bound.
#' @return Strings.
#' @noRd
.an_ci <- function(lo, hi, digits = 4L) {
  out <- .rmbl_fmt_ci(lo, hi, digits)
  out[is.na(lo) & is.na(hi)] <- ""
  out
}

#' Counts as text with thousands separators, other numbers as the block
#' formats them.
#' @param v The counts, or other numbers.
#' @return Strings, right-aligned to a common width.
#' @noRd
.an_count <- function(v) {
  whole <- !is.na(v) & v == round(v) & abs(v) < 1e15
  out <- .rmbl_fmt_num(v)
  out[whole] <- formatC(v[whole], format = "f", digits = 0L, big.mark = ",")
  formatC(out, width = max(c(0L, nchar(out))))
}

#' Text columns cut so that the first column and any other one fit side by
#' side in the box.
#' @param df The table whose text columns are cut.
#' @param lim The widest line.
#' @return The table.
#' @noRd
.an_clip_cols <- function(df, lim) {
  txt <- vapply(df, function(v) is.character(v) || is.factor(v), NA)
  if (txt[1L]) {
    df[[1L]] <- .an_clip(df[[1L]], max(12L, lim %/% 2L))
  }
  first <- max(nchar(c(names(df)[1L], as.character(df[[1L]]))), na.rm = TRUE)
  for (j in which(txt)[which(txt) > 1L]) {
    df[[j]] <- .an_clip(df[[j]], max(10L, lim - first - 6L))
  }
  df
}

#' Which values are TRUE, NA and NULL counted as not.
#' @param x A logical vector, or NULL.
#' @return A logical vector.
#' @noRd
.an_true <- function(x) {
  vapply(x, isTRUE, NA, USE.NAMES = FALSE)
}
