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
# numbers: the denominators move too. rate_change() conditions on the
# total of the two counts and corrects for the exposure ratio, which is
# the same exact conditional construction yoy() uses for counts,
# generalised to unequal denominators.

.rate_per_names <- c("1k" = 1e3, "10k" = 1e4, "100k" = 1e5,
                     "1m" = 1e6, "1000" = 1e3, "10000" = 1e4,
                     "100000" = 1e5, "1000000" = 1e6)

# `per` accepts a number or one of the shorthands, because "per 100k" is
# how the denominator is spoken and mistyping 1e5 as 1e6 is a silent
# factor of ten in a published number.
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
  per <- as.numeric(per)[1L]
  if (is.na(per) || !is.finite(per) || per <= 0) {
    stop("`per` must be a single positive, finite number", call. = FALSE)
  }
  per
}

# "per 100,000", not "per 1e+05" -- the label goes into published
# tables, and 1e+05 in a table is a defect.
.rate_per_label <- function(per) {
  paste0("per ", formatC(per, format = "d", big.mark = ","))
}

#' Event rates per unit of population
#'
#' Counts divided by exposure and scaled to a denominator, with the
#' exact Poisson interval that says how much of the result is signal.
#'
#' A count is not comparable across areas of different size or years of
#' different population; a rate is. What a rate does not do is become
#' reliable just because it is a rate: three events in a small area
#' gives a rate with an interval several times its own width, and the
#' interval here is the one that says so. It is the exact Poisson
#' interval, computed through the gamma relation, so a count of zero has
#' a lower limit of exactly zero rather than a negative number.
#'
#' `per` takes a number, or one of `"1k"`,
#' `"10k"`, `"100k"`, `"1m"`, because a
#' denominator mistyped by a factor of ten is
#' invisible once it reaches a table.
#'
#' @param x A data frame, or a numeric vector of counts.
#' @param ... Passed to methods.
#' @param count Column of counts: non-negative whole numbers.
#' @param population Column of exposure: positive. Person-years, stops,
#'   residents -- whatever the events were at risk of happening to.
#' @param by Character vector of grouping columns. The rate is computed
#'   within each group.
#' @param per The rate denominator: a positive number, or `"1k"`,
#'   `"10k"`, `"100k"`, `"1m"`. Default 1000.
#' @param conf_level Confidence level for the interval.
#' @param min_count Counts at or below this are flagged as too small to
#'   report, with the rate still computed. Default 0, which flags
#'   nothing; published guidance often uses 5 or 10.
#'
#' @return A data frame of class `rmbl_rate` with the
#'   grouping columns, `count`, `population`,
#'   `rate`, `lower`, `upper` and `flag`, plus a
#'   `rate` attribute recording the denominator and
#'   the confidence level.
#'
#' @seealso [share()] for a percentage of a
#'   total, [rate_change()] for the change in a
#'   rate between periods, [sir()] for a rate
#'   compared against an expected count rather
#'   than a population.
#'
#' @examples
#' stops <- data.frame(
#'   division = c("North", "South", "East"),
#'   stops = c(412, 77, 3),
#'   residents = c(120000, 41000, 9500))
#'
#' # per 1,000 residents, the default
#' rate(stops, stops, residents, by = "division")
#'
#' # the denominator published guidance usually asks for
#' rate(stops, stops, residents, by = "division", per = "100k")
#'
#' # East's three events: the interval is wider than the estimate, and
#' # flagging it is the point of min_count
#' rate(stops, stops, residents, by = "division", per = "100k",
#'      min_count = 5)
#'
#' # vectors work too, for a single figure
#' rate(3, 9500, per = "100k")
#' @export
rate <- function(x, ...) UseMethod("rate")

#' @rdname rate
#' @export
rate.data.frame <- function(x, count, population, by = NULL, per = 1000,
                            conf_level = 0.95, min_count = 0, ...) {
  count <- .yoy_col(substitute(count), count, x, "count")
  population <- .yoy_col(substitute(population), population, x,
                          "population")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("`by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  per <- .rate_per(per)
  if (!is.numeric(x[[count]])) {
    stop(sprintf("`%s` must be numeric, not %s", count,
                 class(x[[count]])[1L]), call. = FALSE)
  }
  if (!is.numeric(x[[population]])) {
    stop(sprintf("`%s` must be numeric, not %s", population,
                 class(x[[population]])[1L]), call. = FALSE)
  }
  if (is.null(by)) {
    agg <- data.frame(count = sum(x[[count]], na.rm = TRUE),
                      population = sum(x[[population]], na.rm = TRUE),
                      stringsAsFactors = FALSE)
  } else {
    # aggregate() drops grouping levels with no rows, which is the
    # right behaviour here: a group with no rows has no exposure
    # either, and inventing a zero denominator would invent an
    # infinite rate.
    agg <- stats::aggregate(x[c(count, population)], by = x[by], FUN = sum,
                            na.rm = TRUE)
    names(agg)[seq_along(by)] <- by
    names(agg)[match(c(count, population), names(agg))] <-
      c("count", "population")
  }
  out <- .rate_compute(agg, per, conf_level, min_count)
  structure(out, class = c("rmbl_rate", "data.frame"),
            rate = list(count = count, population = population, by = by,
                        per = per, per_label = .rate_per_label(per),
                        conf_level = conf_level, min_count = min_count))
}

#' @rdname rate
#' @export
rate.default <- function(x, population, per = 1000, conf_level = 0.95,
                         min_count = 0, ...) {
  x <- as.numeric(x)
  population <- as.numeric(population)
  if (length(population) == 1L) population <- rep(population, length(x))
  if (length(x) != length(population)) {
    stop("`x` and `population` must be the same length", call. = FALSE)
  }
  per <- .rate_per(per)
  agg <- data.frame(count = x, population = population,
                    stringsAsFactors = FALSE)
  structure(.rate_compute(agg, per, conf_level, min_count),
            class = c("rmbl_rate", "data.frame"),
            rate = list(count = "count", population = "population",
                        by = NULL, per = per,
                        per_label = .rate_per_label(per),
                        conf_level = conf_level, min_count = min_count))
}

.rate_compute <- function(agg, per, conf_level, min_count) {
  conf_level <- as.numeric(conf_level)[1L]
  if (is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must lie strictly inside (0, 1)", call. = FALSE)
  }
  cnt <- as.numeric(agg$count)
  pop <- as.numeric(agg$population)
  if (any(cnt < 0, na.rm = TRUE)) {
    stop("`count` must be non-negative", call. = FALSE)
  }
  nonint <- stats::na.omit(cnt)
  if (length(nonint) && any(abs(nonint - round(nonint)) > 1e-8)) {
    stop(paste0("`count` must be whole numbers: a Poisson interval on a ",
                "fractional count is not defined. Use a ratio instead."),
         call. = FALSE)
  }
  if (any(pop <= 0, na.rm = TRUE)) {
    stop("`population` must be positive: a rate needs exposure",
         call. = FALSE)
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
                            meta$per_label, 100 * meta$conf_level), x, ...)
  invisible(x)
}

#' Share of a total, in percent
#'
#' What fraction of a total each count is, with the Wilson interval.
#'
#' A share and a rate are different quantities: a share's denominator is
#' the total of the same events, so shares over a complete grouping sum
#' to 100. Use [rate()] when the denominator is a population.
#'
#' The interval is Wilson's, not the textbook normal approximation.
#' The normal interval on a proportion is wrong in exactly the cases
#' people reach for it -- small counts and shares near 0 or 100, where
#' it runs past the ends of the scale and reports a negative percentage.
#' Wilson's stays inside the scale and is accurate at those counts.
#'
#' @param x A data frame, or a numeric vector of counts.
#' @param ... Passed to methods.
#' @param count Column of counts: non-negative whole numbers.
#' @param by Character vector of grouping columns. Shares are computed
#'   over the groups, so they sum to 100 unless `total` says otherwise.
#' @param total The denominator. `NULL` (default) sums `count`, which
#'   makes the shares sum to 100. A number, or a column name, uses that
#'   instead -- for the case where some of the total is not in the table.
#' @param conf_level Confidence level for the interval.
#'
#' @return A data frame of class `rmbl_share`
#'   with the grouping columns, `count`, `total`,
#'   `share`, `lower` and `upper`, plus a `share`
#'   attribute recording the denominator and the
#'   confidence level.
#'
#' @seealso [rate()] for events per population,
#'   [yoy()] for change between periods.
#'
#' @examples
#' stops <- data.frame(
#'   division = c("North", "South", "East"),
#'   stops = c(412, 77, 3))
#'
#' # shares of the table's own total, summing to 100
#' share(stops, stops, by = "division")
#'
#' # East is 0.6% of stops, and the interval does not run below zero
#' # the way a normal approximation would
#' share(stops, stops, by = "division")$lower
#'
#' # a denominator from outside the table
#' share(stops, stops, by = "division", total = 10000)
#' @export
share <- function(x, ...) UseMethod("share")

#' @rdname share
#' @export
share.data.frame <- function(x, count, by = NULL, total = NULL,
                             conf_level = 0.95, ...) {
  count <- .yoy_col(substitute(count), count, x, "count")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("`by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  if (!is.numeric(x[[count]])) {
    stop(sprintf("`%s` must be numeric, not %s", count,
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
  } else if (is.character(total)) {
    if (!total %in% names(x)) {
      stop(sprintf("`total` column not found: %s", total), call. = FALSE)
    }
    sum(x[[total]], na.rm = TRUE)
  } else {
    as.numeric(total)[1L]
  }
  out <- .share_compute(agg, denom, conf_level)
  structure(out, class = c("rmbl_share", "data.frame"),
            share = list(count = count, by = by, total = denom,
                         conf_level = conf_level))
}

#' @rdname share
#' @export
share.default <- function(x, total = NULL, conf_level = 0.95, ...) {
  x <- as.numeric(x)
  denom <- if (is.null(total)) sum(x, na.rm = TRUE) else as.numeric(total)[1L]
  agg <- data.frame(count = x, stringsAsFactors = FALSE)
  structure(.share_compute(agg, denom, conf_level),
            class = c("rmbl_share", "data.frame"),
            share = list(count = "count", by = NULL, total = denom,
                         conf_level = conf_level))
}

.share_compute <- function(agg, denom, conf_level) {
  conf_level <- as.numeric(conf_level)[1L]
  if (is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must lie strictly inside (0, 1)", call. = FALSE)
  }
  cnt <- as.numeric(agg$count)
  if (any(cnt < 0, na.rm = TRUE)) {
    stop("`count` must be non-negative", call. = FALSE)
  }
  if (is.na(denom) || denom <= 0) {
    stop("the total must be positive", call. = FALSE)
  }
  if (any(cnt > denom, na.rm = TRUE)) {
    stop(paste0("a count is larger than the total, so these are not ",
                "shares of it. Did you mean rate()?"), call. = FALSE)
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

# Wilson's score interval, in percent. Stays inside [0, 100] at the
# small counts and extreme shares where the normal approximation
# reports impossible values.
.share_wilson <- function(cnt, n, conf_level) {
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
#' The change in a rate from one period to the period `lag` places
#' earlier, with the exact conditional interval for the rate ratio.
#'
#' This is not the percent change of two rates treated as measured
#' numbers. Both the counts and the denominators move between periods,
#' and an interval that ignores the denominators understates the
#' uncertainty of the change. The construction here conditions on the
#' total of the two counts and corrects for the ratio of the two
#' exposures, which is [yoy()]'s exact conditional-binomial interval
#' generalised to unequal denominators: with equal populations it
#' reduces to exactly that.
#'
#' @param x A data frame.
#' @param ... Passed to methods.
#' @param count Column of counts: non-negative whole numbers.
#' @param population Column of exposure: positive.
#' @param period Column of periods. Sorted, and compared on the period
#'   value rather than on row position, so a missing year gives no
#'   comparison instead of a silent comparison against the wrong year.
#' @param by Character vector of grouping columns.
#' @param lag How many periods back to compare against. Default 1.
#' @param per The rate denominator: a positive number, or `"1k"`,
#'   `"10k"`, `"100k"`, `"1m"`.
#' @param conf_level Confidence level for the interval.
#' @param min_count Comparisons where the earlier count is at or below
#'   this are flagged and their percent change withheld, the way
#'   [yoy()] withholds a percent change off a tiny base.
#'
#' @return A data frame of class
#'   `rmbl_rate_change` with the grouping
#'   columns, `period`, `count`, `population`,
#'   `rate`, `previous_rate`, `rate_ratio`,
#'   `pct_change`, `pct_lower`, `pct_upper` and
#'   `flag`.
#'
#' @seealso [rate()], [yoy()] for change in a count or a measured
#'   quantity.
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
#' rate_change(d, stops, residents, year, by = "division", per = "100k")
#' @export
rate_change <- function(x, ...) UseMethod("rate_change")

#' @rdname rate_change
#' @export
rate_change.data.frame <- function(x, count, population, period, by = NULL,
                                   lag = 1L, per = 1000, conf_level = 0.95,
                                   min_count = 0, ...) {
  count <- .yoy_col(substitute(count), count, x, "count")
  population <- .yoy_col(substitute(population), population, x,
                          "population")
  period <- .yoy_col(substitute(period), period, x, "period")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("`by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  per <- .rate_per(per)
  lag <- as.integer(lag)
  if (length(lag) != 1L || is.na(lag) || lag < 1L) {
    stop("`lag` must be a positive integer", call. = FALSE)
  }
  conf_level <- as.numeric(conf_level)[1L]
  if (is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must lie strictly inside (0, 1)", call. = FALSE)
  }
  keys <- c(by, period)
  agg <- stats::aggregate(x[c(count, population)], by = x[keys], FUN = sum,
                          na.rm = TRUE)
  names(agg)[seq_along(keys)] <- keys
  names(agg)[match(c(count, population), names(agg))] <-
    c("count", "population")
  pieces <- if (is.null(by)) {
    list(agg)
  } else {
    split(agg, agg[by], drop = TRUE, sep = "\r")
  }
  res <- lapply(pieces, function(g) {
    g <- g[order(g[[period]]), , drop = FALSE]
    cnt <- as.numeric(g$count)
    pop <- as.numeric(g$population)
    if (any(pop <= 0, na.rm = TRUE)) {
      stop("`population` must be positive: a rate needs exposure",
           call. = FALSE)
    }
    p <- g[[period]]
    prev_i <- .rate_previous_index(p, lag)
    prev_cnt <- ifelse(is.na(prev_i), NA_real_, cnt[prev_i])
    prev_pop <- ifelse(is.na(prev_i), NA_real_, pop[prev_i])
    rate_now <- per * cnt / pop
    rate_prev <- per * prev_cnt / prev_pop
    ratio <- rate_now / rate_prev
    pct <- 100 * (ratio - 1)
    pct[!is.finite(pct)] <- NA_real_
    ci <- .rate_ratio_ci(cnt, prev_cnt, pop, prev_pop, conf_level)
    flag <- rep(NA_character_, length(cnt))
    flag[is.na(prev_i)] <- "no comparison period"
    small <- !is.na(prev_cnt) & prev_cnt <= min_count
    if (min_count > 0) {
      flag[small] <- sprintf("earlier count at or below %g", min_count)
      pct[small] <- NA_real_
      ci$lower[small] <- NA_real_
      ci$upper[small] <- NA_real_
    }
    zero <- !is.na(prev_cnt) & prev_cnt == 0
    flag[zero] <- "earlier period is zero"
    out <- g[c(by, period)]
    out$count <- cnt
    out$population <- pop
    out$rate <- rate_now
    out$previous_rate <- rate_prev
    out$rate_ratio <- ratio
    out$pct_change <- pct
    out$pct_lower <- ci$lower
    out$pct_upper <- ci$upper
    out$flag <- flag
    out
  })
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  structure(out, class = c("rmbl_rate_change", "data.frame"),
            rate_change = list(count = count, population = population,
                               period = period, by = by, lag = lag,
                               per = per,
                               per_label = .rate_per_label(per),
                               conf_level = conf_level,
                               min_count = min_count))
}

# Match on the PERIOD, not on position: the comparison row is the one
# whose period is `lag` steps earlier on the observed grid, and is NA
# when that period is absent. Position would compare 2023 against 2020
# whenever 2021 were missing and say nothing about it.
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

# The exact conditional interval for a rate ratio. Given the two counts,
# a is binomial on a + b with success probability
# p = RR * ta / (RR * ta + tb); inverting a qbeta interval for p gives
# the interval for RR. With ta == tb this is the same construction
# yoy() uses for counts.
.rate_ratio_ci <- function(a, b, ta, tb, conf_level) {
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
  meta <- attr(x, "rate_change")
  .rmbl_print_table(
    sprintf("Change in rate %s, lag %d, %g%% exact conditional interval",
            meta$per_label, meta$lag, 100 * meta$conf_level), x, ...)
  invisible(x)
}

#' @export
print.rmbl_share <- function(x, ...) {
  meta <- attr(x, "share")
  .rmbl_print_table(sprintf("Share of %s, %g%% Wilson interval",
                            format(meta$total, big.mark = ","),
                            100 * meta$conf_level), x, ...)
  invisible(x)
}
