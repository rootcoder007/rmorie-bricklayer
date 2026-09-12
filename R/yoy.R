# Period-over-period change, with the uncertainty that a percent change
# off a small base actually carries.
#
# A year-over-year percent change is the most-quoted and least-qualified
# number in open-data reporting. Three things go wrong with it, and all
# three are arithmetic rather than opinion:
#
#   1. Matching on row ORDER rather than on the period's value. A missing
#      year silently shifts every comparison by one period, and the table
#      still prints.
#   2. Reporting a percent change off a tiny base. Two segregation
#      placements becoming twenty is a 900% rise and also nothing at all;
#      the headline is a function of the denominator's smallness.
#   3. Taking the percent change OF a percentage. If a rate moves from 4%
#      to 5% that is one percentage point, not 25%, and the two are
#      different quantities with different meanings.
#
# For counts the right uncertainty is available exactly and cheaply.
# Conditional on the total of the two periods, the current count is
# binomial, so the ratio of the two has an exact Clopper-Pearson
# interval -- no simulation, no normal approximation, no extra
# dependency.

#' Year-over-year (and period-over-period) change
#'
#' Computes the change from one period to the period `lag` places before
#' it, matched on the period's own value rather than on row order, and
#' carries an exact interval for count data.
#'
#' @param x A data frame, a numeric vector, or a `ts`.
#' @param value For a data frame, the column holding the measure, as a
#'   string or a bare name.
#' @param period For a data frame, the column holding the period (a year,
#'   a `Date`, a fiscal-year integer, an ordered factor). For a numeric
#'   vector, the periods themselves.
#' @param by Optional grouping columns, as a character vector. The change
#'   is computed within each group.
#' @param lag How many periods back to compare with. `1` is
#'   year-over-year on annual data; for a `ts` the default follows the
#'   series' own frequency, so monthly data compares with the same month
#'   a year earlier.
#' @param fun Aggregation applied to `value` within a period and group,
#'   when there is more than one row. Default [sum()], which is what a
#'   count needs.
#' @param units What the measure is. `"count"` gets the exact rate-ratio
#'   interval. `"continuous"` gets the percent change without one, since
#'   a single pair of totals carries no information about its own
#'   variability. `"percent"` reports a percentage-POINT change and
#'   withholds the percent change, which for a percentage is a different
#'   quantity.
#' @param min_base Smallest previous-period value for which a percent
#'   change is reported. Below it the percent is `NA` and the reason is
#'   recorded, rather than a large number that describes the denominator.
#'   Defaults to 20 for counts and to no gate otherwise.
#' @param conf_level Confidence level for the count interval.
#' @param direction Which way is an improvement: `"higher_is_better"`,
#'   `"lower_is_better"` (segregation days, deaths in custody, use of
#'   force), or `"neutral"`. Affects colour and the `verdict` column only,
#'   never the arithmetic.
#' @param complete Whether to insert the missing periods in the observed
#'   range so that a gap is visible as a gap instead of closing up.
#' @param ... Passed between methods.
#' @return An `rmbl_yoy` object: a data frame with one row per period
#'   (and group), and columns `period`, `value`, `previous`, `change`,
#'   `pct_change` (or `pp_change` for percentages), `pct_lower` and
#'   `pct_upper` for counts, `verdict`, and `flag` recording why a
#'   percent was withheld.
#' @seealso [yoy_html()], [yoy_pdf()], [yoy_summary()]
#' @examples
#' seg <- data.frame(
#'   EndFiscalYear = rep(2019:2023, each = 2),
#'   Gender = rep(c("Female", "Male"), 5),
#'   Number_Of_Placements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
#' )
#'
#' y <- yoy(seg, value = "Number_Of_Placements", period = "EndFiscalYear",
#'          by = "Gender", direction = "lower_is_better")
#' y
#'
#' # The interval is exact, so a small group does not get a confident
#' # percent it has not earned.
#' subset(as.data.frame(y), Gender == "Female")
#'
#' # A percentage is handled as percentage points, not as a percent of a
#' # percent.
#' rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
#' yoy(rate, value = "share", period = "year", units = "percent")
#' @export
yoy <- function(x, ...) UseMethod("yoy")

#' @rdname yoy
#' @export
yoy.data.frame <- function(x, value, period, by = NULL, lag = 1L,
                           fun = sum,
                           units = c("count", "continuous", "percent"),
                           min_base = NULL, conf_level = 0.95,
                           direction = c("neutral", "higher_is_better",
                                         "lower_is_better"),
                           complete = TRUE, ...) {
  units <- match.arg(units)
  direction <- match.arg(direction)
  value <- .yoy_col(substitute(value), value, x, "value")
  period <- .yoy_col(substitute(period), period, x, "period")
  if (!is.null(by)) {
    by <- as.character(by)
    miss <- setdiff(by, names(x))
    if (length(miss)) {
      stop(sprintf("`by` column not found: %s",
                   paste(miss, collapse = ", ")), call. = FALSE)
    }
  }
  lag <- as.integer(lag)
  if (length(lag) != 1L || is.na(lag) || lag < 1L) {
    stop("`lag` must be a positive integer", call. = FALSE)
  }
  conf_level <- as.numeric(conf_level)[1L]
  if (is.na(conf_level) || conf_level <= 0 || conf_level >= 1) {
    stop("`conf_level` must lie strictly inside (0, 1)", call. = FALSE)
  }
  v <- x[[value]]
  if (!is.numeric(v)) {
    stop(sprintf("`%s` must be numeric, not %s", value, class(v)[1L]),
         call. = FALSE)
  }
  if (units == "count") {
    nonint <- stats::na.omit(v)
    if (length(nonint) && (any(nonint < 0) ||
                             any(abs(nonint - round(nonint)) > 1e-8))) {
      stop(paste0("`units = \"count\"` needs non-negative whole numbers; ",
                  "use units = \"continuous\" for a measured quantity"),
           call. = FALSE)
    }
  }
  if (is.null(min_base)) min_base <- if (units == "count") 20 else 0

  agg <- .yoy_aggregate(x, value, period, by, fun)
  if (isTRUE(complete)) agg <- .yoy_complete(agg, period, by, lag)
  out <- .yoy_compute(agg, value, period, by, lag, units, min_base,
                      conf_level, direction)
  structure(out, class = c("rmbl_yoy", "data.frame"),
            yoy = list(value = value, period = period, by = by, lag = lag,
                       units = units, min_base = min_base,
                       conf_level = conf_level, direction = direction,
                       value_digits = .yoy_value_digits(v, units)))
}

#' @rdname yoy
#' @export
yoy.numeric <- function(x, period = seq_along(x), ...) {
  d <- data.frame(period = period, value = as.numeric(x))
  yoy.data.frame(d, value = "value", period = "period", ...)
}

#' @rdname yoy
#' @export
yoy.integer <- function(x, period = seq_along(x), ...) {
  yoy.numeric(as.numeric(x), period = period, ...)
}

#' @rdname yoy
#' @export
yoy.ts <- function(x, lag = NULL, ...) {
  f <- stats::frequency(x)
  # a year-over-year comparison on a seasonal series means the same
  # season one year earlier, which is the frequency itself -- comparing
  # with the previous OBSERVATION would mix January with December
  if (is.null(lag)) lag <- max(1L, as.integer(round(f)))
  tt <- stats::time(x)
  d <- data.frame(period = as.numeric(tt), value = as.numeric(x))
  yoy.data.frame(d, value = "value", period = "period", lag = lag, ...)
}

# Resolve a column given either a bare name or a string.
#
# The unevaluated argument is consulted FIRST. Testing is.character(val)
# before that forces the promise, so a bare column name -- the whole
# point of accepting one -- raised "object 'n' not found" instead of
# naming the column.
.yoy_col <- function(sub, val, data, what) {
  nm <- NULL
  if (is.name(sub)) {
    cand <- as.character(sub)
    if (cand %in% names(data)) nm <- cand
  }
  if (is.null(nm)) {
    v <- val
    if (is.character(v) && length(v) == 1L && !is.na(v)) {
      nm <- v
    } else {
      stop(sprintf("`%s` must be a column name", what), call. = FALSE)
    }
  }
  if (!nm %in% names(data)) {
    stop(sprintf("`%s` column not found: %s", what, nm), call. = FALSE)
  }
  nm
}

# Collapse to one row per period (and group).
.yoy_aggregate <- function(x, value, period, by, fun) {
  keys <- c(period, by)
  if (!anyDuplicated(x[keys])) {
    return(x[order(.yoy_order(x, keys)), c(keys, value), drop = FALSE])
  }
  sp <- split(x[[value]], x[keys], drop = TRUE, sep = "\r")
  vals <- vapply(sp, function(z) as.numeric(fun(z)), 0)
  parts <- do.call(rbind, strsplit(names(sp), "\r", fixed = TRUE))
  out <- as.data.frame(parts, stringsAsFactors = FALSE)
  names(out) <- keys
  # split() stringifies its keys, so restore each column's original type
  for (k in keys) out[[k]] <- .yoy_restore(out[[k]], x[[k]])
  out[[value]] <- unname(vals)
  out[order(.yoy_order(out, keys)), , drop = FALSE]
}

.yoy_order <- function(d, keys) {
  do.call(order, lapply(rev(keys), function(k) d[[k]]))
}

# Put a stringified key back into the class it came from.
.yoy_restore <- function(chr, orig) {
  if (is.factor(orig)) return(factor(chr, levels = levels(orig)))
  if (inherits(orig, "Date")) return(as.Date(chr))
  if (inherits(orig, "POSIXct")) return(as.POSIXct(chr, tz = attr(orig, "tzone")))
  if (is.integer(orig)) return(as.integer(chr))
  if (is.numeric(orig)) return(as.numeric(chr))
  if (is.logical(orig)) return(as.logical(chr))
  chr
}

# Insert the periods that are absent from the observed range, so a gap
# shows as a gap instead of the next period closing up over it.
.yoy_complete <- function(agg, period, by, lag) {
  p <- agg[[period]]
  full <- .yoy_period_grid(p)
  if (is.null(full) || length(full) == length(unique(p))) return(agg)
  if (is.null(by)) {
    grid <- data.frame(x = full, stringsAsFactors = FALSE)
    names(grid) <- period
  } else {
    grid <- expand.grid(c(stats::setNames(list(full), period),
                          lapply(agg[by], function(z) unique(z))),
                        stringsAsFactors = FALSE)
  }
  # all = TRUE, not all.x: the grid contributes the missing periods and
  # the data keeps every period it actually has, even one the grid does
  # not contain.
  out <- merge(grid, agg, by = c(period, by), all = TRUE)
  out[order(.yoy_order(out, c(period, by))), , drop = FALSE]
}

# The regular grid a period column implies, or NULL when it has none.
.yoy_period_grid <- function(p) {
  if (!is.numeric(p) && !inherits(p, c("Date", "POSIXct"))) return(NULL)
  u <- sort(unique(p))
  if (length(u) < 2L) return(NULL)
  if (inherits(p, "Date")) {
    d <- as.numeric(diff(u))
    step <- .yoy_gcd(d)
    if (!is.finite(step) || step <= 0) return(NULL)
    return(seq(min(u), max(u), by = step))
  }
  if (is.numeric(u)) {
    d <- diff(u)
    step <- .yoy_gcd(d)
    if (!is.finite(step) || step <= 0) return(NULL)
    n <- (max(u) - min(u)) / step
    if (!is.finite(n) || n > 1e5) return(NULL)
    g <- min(u) + step * seq.int(0L, round(n))
    return(if (is.integer(p)) as.integer(round(g)) else g)
  }
  NULL
}

.yoy_gcd <- function(d) {
  d <- d[is.finite(d) & d > 0]
  if (!length(d)) return(NA_real_)
  if (any(abs(d - round(d)) > 1e-8)) return(min(d))
  g <- abs(round(d[1L]))
  for (k in round(d[-1L])) {
    k <- abs(k)
    while (k) { t <- g %% k; g <- k; k <- t }
  }
  as.numeric(g)
}

# The comparison itself.
.yoy_compute <- function(agg, value, period, by, lag, units, min_base,
                         conf_level, direction) {
  pieces <- if (is.null(by)) {
    list(agg)
  } else {
    split(agg, agg[by], drop = TRUE, sep = "\r")
  }
  res <- lapply(pieces, function(g) {
    g <- g[order(g[[period]]), , drop = FALSE]
    v <- as.numeric(g[[value]])
    p <- g[[period]]
    # Match on the PERIOD, not on position: previous is the row whose
    # period is `lag` steps earlier on the grid, and is NA when that
    # period is absent. Taking v[i - lag] instead would compare 2023
    # with 2020 whenever 2021 were missing, and say nothing about it.
    prev <- .yoy_previous(p, v, lag)
    out <- data.frame(period = p, value = v, previous = prev,
                      stringsAsFactors = FALSE)
    names(out)[1L] <- period
    out$change <- v - prev
    if (units == "percent") {
      # a percentage moves by percentage POINTS; the percent change of a
      # percent is a different quantity and is not reported as "the"
      # change
      out$pp_change <- v - prev
    } else {
      pct <- 100 * (v - prev) / prev
      pct[!is.finite(pct)] <- NA_real_
      out$pct_change <- pct
    }
    flag <- rep(NA_character_, nrow(out))
    flag[is.na(prev)] <- "no comparison period"
    small <- !is.na(prev) & prev < min_base
    if (units != "percent") {
      flag[small] <- sprintf("base below %g", min_base)
      out$pct_change[small] <- NA_real_
      zero <- !is.na(prev) & prev == 0
      flag[zero] <- "previous period is zero"
    }
    out$flag <- flag
    if (units == "count") {
      ci <- .yoy_ratio_ci(v, prev, conf_level)
      out$pct_lower <- ci$lower
      out$pct_upper <- ci$upper
      out$pct_lower[small] <- NA_real_
      out$pct_upper[small] <- NA_real_
    }
    # The verdict follows the CHANGE, not the percent. Which way a
    # series moved is known even when the percent is withheld for a
    # small base, and withholding the direction too would hide the one
    # fact that is not in question.
    out$verdict <- .yoy_verdict(out$change, direction)
    if (!is.null(by)) {
      for (b in by) out[[b]] <- g[[b]][seq_len(nrow(out))]
      out <- out[, c(by, setdiff(names(out), by)), drop = FALSE]
    }
    out
  })
  out <- do.call(rbind, res)
  rownames(out) <- NULL
  out
}

# Previous value at the period `lag` grid-steps earlier.
.yoy_previous <- function(p, v, lag) {
  # A period has to be on a numeric scale for "lag periods earlier" to
  # mean anything. A character or factor column -- "Q1", "Q2" -- has no
  # step, and taking diff() of it raised rather than reporting that
  # there is no comparison to make.
  if (!is.numeric(p) && !inherits(p, c("Date", "POSIXct"))) {
    return(rep(NA_real_, length(v)))
  }
  u <- sort(unique(p))
  if (length(u) < 2L) return(rep(NA_real_, length(v)))
  step <- .yoy_gcd(as.numeric(diff(u)))
  if (!is.finite(step) || step <= 0) return(rep(NA_real_, length(v)))
  # Match on the grid INDEX rather than on a reconstructed period value.
  # A monthly ts has a step of 1/12, so p - 12 * step lands a few parts
  # in 10^16 away from the period it is meant to find and match() misses
  # every row -- a table in which nothing has a comparison period.
  # Dividing by the step first turns the comparison into integers.
  key <- round(as.numeric(p) / step)
  idx <- match(key - lag, key)
  out <- rep(NA_real_, length(v))
  ok <- !is.na(idx)
  out[ok] <- v[idx[ok]]
  out
}

# Exact interval for the ratio of two counts.
#
# Conditional on the total a + b, the current count a is
# Binomial(a + b, p) with p = R / (1 + R), where R is the ratio of the
# two periods' rates. A Clopper-Pearson interval for p therefore maps
# straight onto an exact interval for R, and from there to the percent
# change. No simulation and no normal approximation, which is what makes
# it usable at the small counts where the percent change is least
# trustworthy.
.yoy_ratio_ci <- function(a, b, conf_level) {
  n <- length(a)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  alpha <- 1 - conf_level
  for (i in seq_len(n)) {
    ai <- a[i]
    bi <- b[i]
    if (is.na(ai) || is.na(bi) || (ai + bi) == 0) next
    pl <- if (ai == 0) 0 else stats::qbeta(alpha / 2, ai, bi + 1)
    pu <- if (bi == 0) 1 else stats::qbeta(1 - alpha / 2, ai + 1, bi)
    lower[i] <- 100 * (pl / (1 - pl) - 1)
    upper[i] <- if (pu >= 1) Inf else 100 * (pu / (1 - pu) - 1)
  }
  list(lower = lower, upper = upper)
}

# How many decimals the value column needs. A count has none; a measured
# quantity keeps what it actually carries, so a rate of 4.1 does not
# print as 4 and its change of 0.5 does not print as 0.
.yoy_value_digits <- function(v, units) {
  if (identical(units, "count")) return(0L)
  fin <- v[is.finite(v)]
  if (!length(fin)) return(0L)
  dec <- vapply(fin, function(z) {
    for (k in 0:6) if (abs(z - round(z, k)) < 1e-9) return(k)
    6L
  }, 0L)
  min(6L, max(dec))
}

.yoy_verdict <- function(chg, direction) {
  out <- rep(NA_character_, length(chg))
  ok <- !is.na(chg)
  if (!any(ok)) return(out)
  flat <- ok & chg == 0
  up <- ok & chg > 0
  down <- ok & chg < 0
  out[flat] <- "unchanged"
  if (direction == "neutral") {
    out[up] <- "up"
    out[down] <- "down"
  } else if (direction == "higher_is_better") {
    out[up] <- "better"
    out[down] <- "worse"
  } else {
    out[up] <- "worse"
    out[down] <- "better"
  }
  out
}
