# Rates and shares.
#
# A count on its own is not comparable across places or across years,
# and two quantities get conflated constantly in published tables:
#
#   * a RATE is events per unit of population -- per 1,000, per
#     100,000 -- and its denominator is EXPOSURE: how many people (or
#     person-years, or stops) there were for the events to happen to.
#   * a SHARE is what fraction of a total the count is, in percent, and
#     its denominator is the TOTAL OF THE SAME EVENTS.
#
# "40% of stops" and "40 stops per 1,000 residents" are different
# claims, and a table that labels one as the other is wrong no matter
# how the arithmetic went. They are separate functions here for that
# reason, and they carry different intervals because they are different
# sampling problems: exact Poisson for a rate, Wilson for a share.
#
# The third thing people want is the change in a rate between periods,
# which is NOT the percent change of two rates treated as measured
# numbers: the denominators move too. ratechg() conditions on the
# total of the two counts and corrects for the exposure ratio, which is
# the same exact conditional construction yoy() uses for counts,
# generalised to unequal denominators.

.rate_per_names <- c("1k" = 1e3, "10k" = 1e4, "100k" = 1e5,
                     "1m" = 1e6, "1000" = 1e3, "10000" = 1e4,
                     "100000" = 1e5, "1000000" = 1e6)

#' Reads the `per` argument as a positive number.
#'
#' `per` accepts a number or one of the shorthands, because "per 100k" is
#' how the denominator is spoken and mistyping 1e5 as 1e6 is a silent
#' factor of ten in a published number.
#' @param per A number or a shorthand such as `"100k"`.
#' @return The multiplier as a double.
#' @noRd
.rate_per <- function(per) {
  if (is.character(per)) {
    key <- tolower(gsub("[ ,_]", "", per[1L]))
    key <- sub("^per", "", key)
    if (!key %in% names(.rate_per_names)) {
      stop(sprintf("`per` shorthand not recognised: %s (use one of %s, or a number)",
                   per[1L], paste(names(.rate_per_names)[1:4], collapse = ", ")),
           call. = FALSE)
    }
    return(unname(.rate_per_names[[key]]))
  }
  per <- .rmbl_num(per, "per")[1L]
  if (is.na(per) || !is.finite(per) || per <= 0) {
    stop("`per` must be a single positive, finite number", call. = FALSE)
  }
  per
}

#' Writes the label for a rate's denominator.
#'
#' "per 100,000", not "per 1e+05" -- the label goes into published
#' tables, and 1e+05 in a table is a defect.
#' @param per The multiplier.
#' @return One string such as `"per 100,000"`.
#' @noRd
.rate_per_label <- function(per) {
  paste0("per ", formatC(per, format = "d", big.mark = ","))
}

#' Event rates per unit of population
#'
#' @description
#' Turns counts of events (arrests, stops, admissions, deaths) into rates
#' per unit of exposure, such as per 1,000 or per 100,000 residents, with an
#' exact Poisson confidence interval for each rate. A count is not
#' comparable across areas of different size or years of different
#' population; a rate is. The interval says how much of a rate is signal:
#' three events in a small area give a rate whose interval is several times
#' its own width.
#'
#' @details
#' For count \eqn{y} and exposure \eqn{t}, the rate is
#' \eqn{\mathrm{per} \times y / t}. The interval is the exact Poisson
#' interval for \eqn{y}, computed through the gamma relation,
#' \deqn{\left[G^{-1}(\alpha/2;\, y),\ G^{-1}(1 - \alpha/2;\, y + 1)\right]
#'   \times \mathrm{per} / t,}
#' with \eqn{G^{-1}(p; k)} the gamma quantile with shape \eqn{k}; a count of
#' zero has a lower limit of exactly zero. This is the interval of
#' \code{stats::poisson.test()}. It treats the exposure as known without
#' error.
#'
#' With a data frame, counts and exposures are summed within each
#' combination of the \code{by} columns (missing values are ignored in the
#' sums), and the groups come out in sorted order. Groups with no rows are
#' not created. Without \code{by} the whole table is one group. With a
#' vector, each element is its own row.
#'
#' \code{per} takes a number, or one of \code{"1k"}, \code{"10k"},
#' \code{"100k"}, \code{"1m"} (case, spaces, commas and a leading "per" are
#' ignored), because a denominator mistyped by a factor of ten is invisible
#' once it reaches a table.
#'
#' A rate and a share are different quantities: use \code{\link{shrs}} when
#' the denominator is the total of the same events, not a population.
#'
#' Errors: count or population columns that are not numeric or not found;
#' negative or fractional counts; a population of zero or below;
#' \code{conflvl} outside (0, 1); an unknown \code{per} shorthand or a
#' non-positive \code{per}.
#'
#' @param x A data frame, or a numeric vector of counts.
#' @param ... Passed to methods.
#' @param count Column of counts, given unquoted or as a string:
#'   non-negative whole numbers.
#' @param pop For the data-frame method, the column of exposure,
#'   unquoted or as a string; for the default method, a numeric vector the
#'   length of \code{x} (or one number, recycled). Positive. Person-years,
#'   stops, residents -- whatever the events were at risk of happening to.
#' @param by Character vector of grouping columns, default \code{NULL}. The
#'   rate is computed within each group.
#' @param per The rate denominator: a positive number, or \code{"1k"},
#'   \code{"10k"}, \code{"100k"}, \code{"1m"}. Default 1000.
#' @param conflvl Number in (0, 1), default 0.95: the confidence level of
#'   the interval.
#' @param mincnt Number, default 0. Counts at or below this are flagged
#'   as too small to report, with the rate still computed. The default flags
#'   nothing; published guidance often uses 5 or 10.
#'
#' @return A data frame of class \code{c("rmbl_rate", "data.frame")} with
#'   the grouping columns (or \code{label}, for a named vector), \code{count},
#'   \code{population}, \code{rate},
#'   \code{lower}, \code{upper} (numeric, rates per \code{per}) and
#'   \code{flag} (character, \code{NA} when not flagged), plus a \code{rate}
#'   attribute: a list of \code{count}, \code{population}, \code{by},
#'   \code{per}, \code{perlbl} (for example \code{"per 100,000"}),
#'   \code{conflvl} and \code{mincnt}. The print method titles the
#'   table with the denominator and the interval.
#'
#' @seealso \code{\link{shrs}} for a percentage of a total,
#'   \code{\link{ratechg}} for the change in a rate between periods,
#'   \code{\link{stdinc}} for a rate compared against an expected count rather
#'   than a population.
#'
#' @examples
#' stops <- data.frame(
#'   division = c("North", "South", "East"),
#'   stops = c(412, 77, 3),
#'   residents = c(120000, 41000, 9500))
#'
#' # per 1,000 residents, the default
#' rtcalc(stops, stops, residents, by = "division")
#'
#' # the denominator published guidance usually asks for
#' rtcalc(stops, stops, residents, by = "division", per = "100k")
#'
#' # East's three events: the interval is wider than the estimate, and
#' # flagging it is the point of mincnt
#' rtcalc(stops, stops, residents, by = "division", per = "100k",
#'      mincnt = 5)
#'
#' # vectors work too, for a single figure; a zero count has a lower limit of 0
#' rtcalc(c(3, 0), 9500, per = "100k")
#'
#' # a fractional count has no Poisson interval
#' try(rtcalc(2.5, 1000))
#' @export
#' @srrstats {G2.8} rtcalc.default and rtcalc.data.frame both build one data frame that is passed to the shared
#'   .rate_compute().
rtcalc <- function(x, ...) UseMethod("rtcalc")

#' @rdname rtcalc
#' @usage
#' \method{rtcalc}{data.frame}(x, count, pop, by = NULL, per = 1000,
#'   conflvl = 0.95, mincnt = 0, ...)
#' @export
rtcalc.data.frame <- function(x, count, pop, by = NULL, per = 1000,
                            conflvl = 0.95, mincnt = 0, ...) {
  count <- .yoy_col(substitute(count), count, x, "count")
  pop <- .yoy_col(substitute(pop), pop, x,
                          "population")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("rtcalc: `by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  per <- .rate_per(per)
  if (!is.numeric(x[[count]])) {
    stop(sprintf("rtcalc: `%s` must be numeric, not %s", count,
                 class(x[[count]])[1L]), call. = FALSE)
  }
  if (!is.numeric(x[[pop]])) {
    stop(sprintf("rtcalc: `%s` must be numeric, not %s", pop,
                 class(x[[pop]])[1L]), call. = FALSE)
  }
  if (is.null(by)) {
    agg <- data.frame(count = sum(x[[count]], na.rm = TRUE),
                      population = sum(x[[pop]], na.rm = TRUE),
                      stringsAsFactors = FALSE)
  } else {
    # aggregate() drops grouping levels with no rows, which is the
    # right behaviour here: a group with no rows has no exposure
    # either, and inventing a zero denominator would invent an
    # infinite rate.
    agg <- stats::aggregate(x[c(count, pop)], by = x[by], FUN = sum,
                            na.rm = TRUE)
    names(agg)[seq_along(by)] <- by
    names(agg)[match(c(count, pop), names(agg))] <-
      c("count", "population")
  }
  out <- .rate_compute(agg, per, conflvl, mincnt)
  structure(out, class = c("rmbl_rate", "data.frame"),
            rate = list(count = count, population = pop, by = by,
                        per = per, perlbl = .rate_per_label(per),
                        conflvl = conflvl, mincnt = mincnt))
}

#' @rdname rtcalc
#' @export
rtcalc.default <- function(x, pop, per = 1000, conflvl = 0.95,
                         mincnt = 0, ...) {
  lab <- names(x)
  x <- .rmbl_num(x, "x")
  pop <- .rmbl_num(pop, "pop")
  if (any(is.infinite(x)) || any(is.infinite(pop))) stop("`x` and `pop` must be finite counts", call. = FALSE)
  if (length(pop) == 1L) pop <- rep(pop, length(x))
  if (length(x) != length(pop)) {
    stop("`x` and `pop` must be the same length", call. = FALSE)
  }
  per <- .rate_per(per)
  agg <- data.frame(count = x, population = pop,
                    stringsAsFactors = FALSE)
  # a named vector keeps its names as the first column (.rmbl_num drops them)
  if (!is.null(lab)) agg <- cbind(data.frame(label = lab, stringsAsFactors = FALSE), agg)
  structure(.rate_compute(agg, per, conflvl, mincnt),
            class = c("rmbl_rate", "data.frame"),
            rate = list(count = "count", population = "population",
                        by = NULL, per = per,
                        perlbl = .rate_per_label(per),
                        conflvl = conflvl, mincnt = mincnt))
}

#' Computes rates per `per` with exact Poisson intervals from aggregated counts and populations.
#' @param agg A data frame with `count`, `population` and the grouping columns.
#' @param per The multiplier.
#' @param conf_level The confidence level.
#' @param min_count Counts at or below this are flagged.
#' @return A data frame with the grouping columns, `count`, `population`, `rate`, `lower`, `upper` and `flag`.
#' @noRd
.rate_compute <- function(agg, per, conf_level, min_count) {
  conf_level <- .rmbl_conf_level(conf_level)
  cnt <- as.numeric(agg$count)
  pop <- as.numeric(agg$population)
  if (any(cnt < 0, na.rm = TRUE)) {
    stop(.rmbl_fn(), "`count` must be non-negative", call. = FALSE)
  }
  nonint <- stats::na.omit(cnt)
  if (length(nonint) && any(abs(nonint - round(nonint)) > 1e-8)) {
    stop(paste0("`count` must be whole numbers: a Poisson interval on a ",
                "fractional count is not defined. Use a ratio instead."),
         call. = FALSE)
  }
  if (any(pop <= 0, na.rm = TRUE)) {
    stop(.rmbl_fn(), "`pop` must be positive: a rate needs exposure", call. = FALSE)
  }
  a <- 1 - conf_level
  # the exact Poisson interval through the gamma relation, matching
  # stats::poisson.test, so zero counts give a lower limit of zero
  lo <- ifelse(cnt == 0, 0, stats::qgamma(a / 2, shape = cnt))
  hi <- stats::qgamma(1 - a / 2, shape = cnt + 1)
  flag <- rep(NA_character_, length(cnt))
  small <- !is.na(cnt) & cnt <= min_count
  if (min_count > 0) {
    flag[small] <- sprintf("count at or below %g", min_count)
  }
  keep <- setdiff(names(agg), c("count", "population"))
  out <- agg[keep]
  out$count <- cnt
  out$population <- pop
  out$rate <- per * cnt / pop
  out$lower <- per * lo / pop
  out$upper <- per * hi / pop
  out$flag <- flag
  rownames(out) <- NULL
  out
}

#' @export
print.rmbl_rate <- function(x, ...) {
  meta <- attr(x, "rate")
  .rmbl_print_table(sprintf("Rate %s, %g%% exact Poisson interval",
                            meta$perlbl, 100 * meta$conflvl), x, ...)
  invisible(x)
}

#' Share of a total, in percent
#'
#' @description
#' Expresses each count as a percentage of a total (for example each
#' division's share of all stops), with a Wilson confidence interval. A
#' share's denominator is the total of the same events, so shares over a
#' complete grouping sum to 100. Use \code{\link{rtcalc}} instead when the
#' denominator is a population; "40% of stops" and "40 stops per 1,000
#' residents" are different claims.
#'
#' @details
#' For count \eqn{y} out of total \eqn{n}, the share is \eqn{100\,y/n} and
#' the interval is Wilson's score interval for \eqn{\hat p = y/n},
#' \deqn{\frac{\hat p + \frac{z^2}{2n} \pm z\sqrt{\frac{\hat p(1-\hat p)}{n}
#'   + \frac{z^2}{4n^2}}}{1 + z^2/n},}
#' with \eqn{z} the standard normal quantile for \code{conflvl}, reported
#' in percent and clipped to \eqn{[0, 100]}.
#'
#' The interval is Wilson's, not the textbook normal approximation.
#' The normal interval on a proportion is wrong in exactly the cases
#' people reach for it -- small counts and shares near 0 or 100, where
#' it runs past the ends of the scale and reports a negative percentage.
#' Wilson's stays inside the scale and is accurate at those counts. It
#' treats each count as a binomial draw from the total, which is an
#' approximation when the total is itself the sum of the counts.
#'
#' With a data frame, counts are summed within each combination of the
#' \code{by} columns (missing values ignored), groups sorted. The default
#' method treats each element of \code{x} as a row; when \code{x} is named,
#' its names become a leading \code{label} column.
#'
#' Errors: a count column that is not numeric or not found; negative counts;
#' a total of zero or below; a count larger than the total;
#' \code{conflvl} outside (0, 1).
#'
#' @param x A data frame, or a numeric vector of counts.
#' @param ... Passed to methods.
#' @param count Column of counts, unquoted or as a string: non-negative
#'   whole numbers.
#' @param by Character vector of grouping columns. Shares are computed
#'   over the groups, so they sum to 100 unless \code{total} says otherwise.
#' @param total The denominator. \code{NULL} (default) sums \code{count},
#'   which makes the shares sum to 100. A number uses that number; a column
#'   name (data-frame method) uses the sum of that column -- for the case
#'   where some of the total is not in the table.
#' @param conflvl Number in (0, 1), default 0.95: the confidence level
#'   of the interval.
#'
#' @return A data frame of class \code{c("rmbl_share", "data.frame")} with
#'   the grouping columns (or \code{label}, for a named vector), \code{count},
#'   \code{total}, \code{share},
#'   \code{lower} and \code{upper} (percent), plus a \code{share} attribute:
#'   a list of \code{count}, \code{by}, \code{total} and \code{conflvl}.
#'
#' @seealso \code{\link{rtcalc}} for events per population,
#'   \code{\link{yoy}} for change between periods.
#'
#' @examples
#' stops <- data.frame(
#'   division = c("North", "South", "East"),
#'   stops = c(412, 77, 3))
#'
#' # shares of the table's own total, summing to 100
#' shrs(stops, stops, by = "division")
#'
#' # East is 0.6% of stops, and the interval does not run below zero
#' # the way a normal approximation would
#' shrs(stops, stops, by = "division")$lower
#'
#' # a denominator from outside the table
#' shrs(stops, stops, by = "division", total = 10000)
#'
#' # a plain vector
#' shrs(c(3, 7))
#'
#' # a count larger than its total is not a share
#' try(shrs(c(5, 2), total = 4))
#' @export
shrs <- function(x, ...) UseMethod("shrs")

#' @rdname shrs
#' @export
shrs.data.frame <- function(x, count, by = NULL, total = NULL,
                             conflvl = 0.95, ...) {
  if (missing(count)) stop("`count` must name the column of counts", call. = FALSE)
  count <- .yoy_col(substitute(count), count, x, "count")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("shrs: `by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  if (!is.numeric(x[[count]])) {
    stop(sprintf("shrs: `%s` must be numeric, not %s", count,
                 class(x[[count]])[1L]), call. = FALSE)
  }
  if (is.null(by)) {
    agg <- data.frame(count = sum(x[[count]], na.rm = TRUE),
                      stringsAsFactors = FALSE)
  } else {
    agg <- stats::aggregate(x[count], by = x[by], FUN = sum, na.rm = TRUE)
    names(agg)[seq_along(by)] <- by
    names(agg)[match(count, names(agg))] <- "count"
  }
  denom <- if (is.null(total)) {
    sum(agg$count, na.rm = TRUE)
  } else if (is.character(total) && length(total) == 1L && !is.na(total)) {
    if (!total %in% names(x)) {
      stop(sprintf("`total` column not found: %s", total), call. = FALSE)
    }
    sum(x[[total]], na.rm = TRUE)
  } else {
    .share_total(total, "a column name or ")
  }
  out <- .share_compute(agg, denom, conflvl)
  structure(out, class = c("rmbl_share", "data.frame"),
            share = list(count = count, by = by, total = denom,
                         conflvl = conflvl))
}

#' Checks the `total` argument of shrs().
#'
#' One finite, non-negative number: a data frame or a vector in `total` (shrs(1e308, stops, by =
#' "division")) failed in as.numeric()'s words (hostile battery, final audit of 1.0.0)
#' @param total The value passed by the user.
#' @param also Extra text for the error message naming other accepted forms.
#' @return The total as a double.
#' @noRd
.share_total <- function(total, also) {
  if (!is.numeric(total) || length(total) != 1L || !is.finite(total) || total < 0) {
    stop(sprintf("`total` must be NULL, %sone finite non-negative number", also), call. = FALSE)
  }
  as.numeric(total)
}

#' @rdname shrs
#' @export
shrs.default <- function(x, total = NULL, conflvl = 0.95, ...) {
  if (is.null(x) || !is.atomic(x) || all(is.na(x)) || any(is.infinite(x))) {
    stop("`x` must be finite counts (a numeric vector) or a data frame of them", call. = FALSE)
  }
  lab <- names(x)
  x <- .rmbl_num(x, "x")
  denom <- if (is.null(total)) sum(x, na.rm = TRUE) else .share_total(total, "")
  agg <- data.frame(count = x, stringsAsFactors = FALSE)
  # a named vector keeps its names as the first column (.rmbl_num drops them)
  if (!is.null(lab)) agg <- cbind(data.frame(label = lab, stringsAsFactors = FALSE), agg)
  structure(.share_compute(agg, denom, conflvl),
            class = c("rmbl_share", "data.frame"),
            share = list(count = "count", by = NULL, total = denom,
                         conflvl = conflvl))
}

#' Computes each count's share of a total, in percent, with Wilson intervals.
#' @param agg A data frame with `count` and the grouping columns.
#' @param denom The total the counts are shares of.
#' @param conf_level The confidence level.
#' @return A data frame with the grouping columns, `count`, `total`, `share`, `lower` and `upper`.
#' @noRd
.share_compute <- function(agg, denom, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  cnt <- as.numeric(agg$count)
  if (any(cnt < 0, na.rm = TRUE)) {
    stop(.rmbl_fn(), "`count` must be non-negative", call. = FALSE)
  }
  if (is.na(denom) || denom <= 0) {
    stop("the total must be positive", call. = FALSE)
  }
  if (any(cnt > denom, na.rm = TRUE)) {
    stop(paste0("a count is larger than the total, so these are not ",
                "shares of it. Did you mean rtcalc()?"), call. = FALSE)
  }
  ci <- .share_wilson(cnt, denom, conf_level)
  keep <- setdiff(names(agg), "count")
  out <- agg[keep]
  out$count <- cnt
  out$total <- denom
  out$share <- 100 * cnt / denom
  out$lower <- ci$lower
  out$upper <- ci$upper
  rownames(out) <- NULL
  out
}

#' Computes Wilson's score interval for a share, in percent.
#'
#' Wilson's score interval, in percent. Stays inside \[0, 100\] at the
#' small counts and extreme shares where the normal approximation
#' reports impossible values.
#' @param cnt The counts.
#' @param n The total.
#' @param conf_level The confidence level.
#' @return A list with `lower` and `upper`.
#' @noRd
.share_wilson <- function(cnt, n, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  p <- cnt / n
  denom <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / denom
  halfwidth <- (z / denom) * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  list(lower = 100 * pmax(0, centre - halfwidth),
       upper = 100 * pmin(1, centre + halfwidth))
}

#' Change in a rate between periods
#'
#' @description
#' Compares each period's rate with the rate \code{lag} periods earlier (for
#' example this year's stops per 100,000 residents with last year's), and
#' gives the rate ratio, the percent change and an exact confidence interval
#' for the change. Use it instead of the percent change of two published
#' rates: both the counts and the populations move between periods, and the
#' interval here accounts for the randomness in the counts.
#'
#' @details
#' This is not the percent change of two rates treated as measured
#' numbers. Both the counts and the denominators move between periods,
#' and an interval that ignores the denominators understates the
#' uncertainty of the change. The construction here conditions on the
#' total of the two counts and corrects for the ratio of the two
#' exposures, which is \code{\link{yoy}}'s exact conditional-binomial
#' interval generalised to unequal denominators: with equal populations it
#' reduces to exactly that.
#'
#' With counts \eqn{a} (now) and \eqn{b} (earlier) and exposures
#' \eqn{t_a}, \eqn{t_b}, conditional on \eqn{a + b} the count \eqn{a} is
#' binomial with success probability \eqn{p = RR\,t_a / (RR\,t_a + t_b)}.
#' The Clopper-Pearson limits for \eqn{p}, \eqn{p_L =
#' B^{-1}(\alpha/2;\, a, b + 1)} and \eqn{p_U = B^{-1}(1 - \alpha/2;\, a + 1,
#' b)} (0 when \eqn{a = 0}, 1 when \eqn{b = 0}), give
#' \eqn{RR = (t_b / t_a)\, p / (1 - p)} and the percent change
#' \eqn{100 (RR - 1)}. When \eqn{b = 0} the upper limit is \code{Inf} and the
#' percent change itself is \code{NA}; when both counts are 0 there is no
#' interval.
#'
#' Counts and populations are summed within each period (and \code{by}
#' group). Matching to the earlier period: for a numeric period column the
#' comparison is the period whose value is exactly \code{lag} less, so a
#' missing year gives no comparison instead of a silent comparison against
#' the wrong year. For any other period type (character, factor, Date) the
#' earlier period is \code{lag} steps back along the periods observed in the
#' group, so a gap in such a column is not detected.
#'
#' Errors: \code{x} not a data frame; columns not found; \code{lag} not a
#' positive whole number; \code{conflvl} outside (0, 1); a population of
#' zero or below.
#'
#' @param x A data frame.
#' @param ... Passed to methods.
#' @param count Column of counts (unquoted or a string): non-negative whole
#'   numbers.
#' @param pop Column of exposure (unquoted or a string): positive.
#' @param prd Column of periods (unquoted or a string). Sorted within
#'   each group; see Details for how the earlier period is found.
#' @param by Character vector of grouping columns, default \code{NULL}.
#' @param lag Whole number, default 1: how many periods back to compare
#'   against.
#' @param per The rate denominator: a positive number, or \code{"1k"},
#'   \code{"10k"}, \code{"100k"}, \code{"1m"}. Default 1000.
#' @param conflvl Number in (0, 1), default 0.95: the confidence level of
#'   the interval.
#' @param mincnt Number, default 0. Comparisons where the earlier count
#'   is at or below this are flagged as resting on a small count; the percent
#'   change and its exact interval are still reported, as \code{\link{yoy}}
#'   does.
#'
#' @return A data frame of class \code{c("rmbl_rate_change", "data.frame")}
#'   with one row per group and period: the grouping columns, the period
#'   column, \code{count}, \code{population}, \code{rate},
#'   \code{prerate}, \code{precnt},
#'   \code{prepop}, \code{rateratio}, \code{pctchg},
#'   \code{pctlo}, \code{pctup} (numeric) and the character \code{flag}. The
#'   flag is \code{"no comparison period"}, \code{"earlier period is zero"}, a
#'   small-count note, or \code{NA}. The \code{ratechg} attribute records
#'   the settings.
#'
#' @seealso \code{\link{rtcalc}}, \code{\link{yoy}} for change in a count or a
#'   measured quantity.
#'
#' @examples
#' d <- data.frame(
#'   year = rep(2021:2023, each = 2),
#'   division = rep(c("North", "South"), 3),
#'   stops = c(400, 70, 430, 66, 455, 61),
#'   residents = c(120000, 41000, 122000, 41500, 125000, 42000))
#'
#' # North's count rose while its population rose too: the rate change
#' # is smaller than the count change, which is the reason to use it
#' ratechg(d, stops, residents, year, by = "division", per = "100k")
#'
#' # a missing year gives no comparison rather than a wrong one
#' gap <- data.frame(year = c(2019, 2020, 2022), n = c(10, 14, 12),
#'                   pop = c(1000, 1000, 1100))
#' ratechg(gap, n, pop, year)$flag
#'
#' # two-year change, flagging small earlier counts
#' ratechg(d, stops, residents, year, by = "division", lag = 2,
#'             mincnt = 65)
#'
#' try(ratechg(1:3))
#' @export
ratechg <- function(x, ...) UseMethod("ratechg")

#' @rdname ratechg
#' @export
ratechg.default <- function(x, ...) {
  stop(sprintf("`x` must be a data frame, not %s", class(x)[1L]), call. = FALSE)
}

#' @rdname ratechg
#' @export
ratechg.data.frame <- function(x, count, pop, prd, by = NULL,
                                   lag = 1L, per = 1000, conflvl = 0.95,
                                   mincnt = 0, ...) {
  count <- .yoy_col(substitute(count), count, x, "count")
  pop <- .yoy_col(substitute(pop), pop, x,
                          "population")
  prd <- .yoy_col(substitute(prd), prd, x, "period")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("ratechg: `by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  per <- .rate_per(per)
  lag <- .rmbl_num(lag, "lag", integer = TRUE)
  if (length(lag) != 1L || is.na(lag) || lag < 1L) {
    stop("ratechg: `lag` must be a positive integer", call. = FALSE)
  }
  conflvl <- .rmbl_conf_level(conflvl)
  keys <- c(by, prd)
  agg <- stats::aggregate(x[c(count, pop)], by = x[keys], FUN = sum,
                          na.rm = TRUE)
  names(agg)[seq_along(keys)] <- keys
  names(agg)[match(c(count, pop), names(agg))] <-
    c("count", "population")
  pieces <- if (is.null(by)) {
    list(agg)
  } else {
    split(agg, agg[by], drop = TRUE, sep = "\r")
  }
  .res <- lapply(pieces, function(g) {
    g <- g[order(g[[prd]]), , drop = FALSE]
    cnt <- as.numeric(g$count)
    .pop <- as.numeric(g$population)
    if (any(.pop <= 0, na.rm = TRUE)) {
      stop(.rmbl_fn(), "`pop` must be positive: a rate needs exposure", call. = FALSE)
    }
    p <- g[[prd]]
    prev_i <- .rate_previous_index(p, lag)
    prev_cnt <- ifelse(is.na(prev_i), NA_real_, cnt[prev_i])
    prev_pop <- ifelse(is.na(prev_i), NA_real_, .pop[prev_i])
    rate_now <- per * cnt / .pop
    rate_prev <- per * prev_cnt / prev_pop
    ratio <- rate_now / rate_prev
    pct <- 100 * (ratio - 1)
    pct[!is.finite(pct)] <- NA_real_
    ci <- .rate_ratio_ci(cnt, prev_cnt, .pop, prev_pop, conflvl)
    flag <- rep(NA_character_, length(cnt))
    flag[is.na(prev_i)] <- "no comparison period"
    small <- !is.na(prev_cnt) & prev_cnt <= mincnt
    if (mincnt > 0) {
      # flagged, never hidden: the percent change and its interval are still reported
      flag[small] <- sprintf("earlier count at or below %g", mincnt)
    }
    zero <- !is.na(prev_cnt) & prev_cnt == 0
    flag[zero] <- "earlier period is zero"
    out <- g[c(by, prd)]
    out$count <- cnt
    out$population <- .pop
    out$rate <- rate_now
    out$prerate <- rate_prev
    out$precnt <- prev_cnt
    out$prepop <- prev_pop
    out$rateratio <- ratio
    out$pctchg <- pct
    out$pctlo <- ci$lower
    out$pctup <- ci$upper
    out$flag <- flag
    out
  })
  out <- do.call(rbind, .res)
  rownames(out) <- NULL
  structure(out, class = c("rmbl_rate_change", "data.frame"),
            ratechg = list(count = count, population = pop,
                               period = prd, by = by, lag = lag,
                               per = per,
                               perlbl = .rate_per_label(per),
                               conflvl = conflvl,
                               mincnt = mincnt))
}

#' Finds, for each row, the row whose period is `lag` steps earlier.
#'
#' Match on the PERIOD, not on position: the comparison row is the one
#' whose period is `lag` steps earlier on the observed grid, and is NA
#' when that period is absent. Position would compare 2023 against 2020
#' whenever 2021 were missing and say nothing about it.
#' @param p The periods.
#' @param lag The number of steps back.
#' @return An integer index vector, NA where that period is absent.
#' @noRd
.rate_previous_index <- function(p, lag) {
  key <- if (is.numeric(p)) p else as.character(p)
  want <- if (is.numeric(p)) p - lag else NA
  if (!is.numeric(p)) {
    # For non-numeric periods the observed order IS the grid, so step
    # back along the sorted unique values. The out-of-range positions
    # have to be filtered BEFORE indexing: lv[c(0, 1)] drops the zero
    # and returns a shorter vector, which ifelse() then recycles into
    # wrong answers rather than reporting anything.
    lv <- unique(key)
    pos <- match(key, lv)
    want_pos <- pos - lag
    idx <- rep(NA_integer_, length(pos))
    ok <- !is.na(want_pos) & want_pos >= 1L
    idx[ok] <- match(lv[want_pos[ok]], key)
    return(idx)
  }
  match(want, key)
}

#' Computes the exact conditional interval for a rate ratio.
#'
#' The exact conditional interval for a rate ratio. Given the two counts,
#' a is binomial on a + b with success probability
#' p = RR * ta / (RR * ta + tb); inverting a qbeta interval for p gives
#' the interval for RR. With ta == tb this is the same construction
#' yoy() uses for counts.
#' @param a The current counts.
#' @param b The comparison counts.
#' @param ta The current exposures.
#' @param tb The comparison exposures.
#' @param conf_level The confidence level.
#' @return A list with `lower` and `upper`, as percent changes.
#' @noRd
.rate_ratio_ci <- function(a, b, ta, tb, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  n <- length(a)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  alpha <- 1 - conf_level
  for (i in seq_len(n)) {
    ai <- a[i]
    bi <- b[i]
    tai <- ta[i]
    tbi <- tb[i]
    if (is.na(ai) || is.na(bi) || is.na(tai) || is.na(tbi)) next
    if ((ai + bi) == 0) next
    pl <- if (ai == 0) 0 else stats::qbeta(alpha / 2, ai, bi + 1)
    pu <- if (bi == 0) 1 else stats::qbeta(1 - alpha / 2, ai + 1, bi)
    scale <- tbi / tai
    lower[i] <- 100 * (scale * pl / (1 - pl) - 1)
    upper[i] <- if (pu >= 1) Inf else 100 * (scale * pu / (1 - pu) - 1)
  }
  list(lower = lower, upper = upper)
}

#' @export
print.rmbl_rate_change <- function(x, ...) {
  meta <- attr(x, "ratechg")
  .rmbl_print_table(
    sprintf("Change in rate %s, lag %d, %g%% exact conditional interval",
            meta$perlbl, meta$lag, 100 * meta$conflvl), x, ...)
  invisible(x)
}

#' @export
print.rmbl_share <- function(x, ...) {
  meta <- attr(x, "share")
  .rmbl_print_table(sprintf("Share of %s, %g%% Wilson interval",
                            format(meta$total, big.mark = ","),
                            100 * meta$conflvl), x, ...)
  invisible(x)
}
