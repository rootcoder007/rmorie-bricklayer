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
#' Computes the change from one period to the period `lag` places
#' before it, matched on the period's own value rather than on row order,
#' and carries an exact interval for count data. Use it for the
#' "up 12% on last year" figures of an annual report or an open-data
#' release: a missing year shows as a gap instead of shifting every
#' comparison, a percentage is compared in percentage points, and a change
#' off a small count comes with an interval as wide as the count is small.
#'
#' @details
#' Rows are first combined to one per period (and group) with `fun`. With
#' `complete = TRUE` the periods missing from a regular grid (numbers, `Date`
#' or `POSIXct` with a common step, the levels of an ordered factor, text
#' periods read as described under `prd`) are inserted with `NA` values and
#' flagged \dQuote{no data}. Each period is then compared with the period
#' `lag` steps earlier in that grid: `change` is the difference, `pctchg`
#' \eqn{100 (v_t / v_{t-lag} - 1)} (`NA` off a zero base), and for percentages
#' `ppchg` is the difference in percentage points.
#'
#' For counts, conditional on their sum \eqn{n = a + b} the current count
#' \eqn{a} is binomial with probability \eqn{\rho / (1 + \rho)}, \eqn{\rho}
#' the rate ratio; the Clopper-Pearson interval for that probability,
#' transformed back, is an exact interval for the ratio, reported as
#' `pctlo` and `pctup` (percent change). It is the interval
#' `stats::poisson.test()` gives for two counts with equal exposure. A zero
#' base has no percent change but still an interval (with an infinite upper
#' end).
#'
#' `verdict` is `"up"`, `"down"` or `"unchanged"` for
#' `direction = "neutral"`, and `"better"`, `"worse"` or
#' `"unchanged"` otherwise; it reads
#' the sign of the change only and makes no claim of significance.
#'
#' Errors: `x` neither a data frame, a numeric vector nor a `ts`; `value`,
#' `period` or `by` naming a column that does not exist; a non-numeric or
#' infinite `value`; for `units = "count"`, negative or fractional values;
#' `lag` not a positive whole number; `conflvl` outside (0, 1); an unknown
#' `units` or `direction`; a `prdord` that is not distinct labels, lacks a
#' label of the data, or is given for periods that are not text.
#'
#' @param x A data frame, a numeric (or integer) vector, or a `ts`.
#' @param value For a data frame, the column holding the
#' measure, as a string or a bare name.
#' @param prd For a data frame, the column holding the period (a year, a `Date`,
#' a fiscal-year integer, an ordered factor, or text). An ordered factor is
#' compared by level order, one level being one period; an unordered factor has
#' no order, so every row is flagged \dQuote{no comparison period}. For a
#' numeric vector, the periods themselves.
#'
#' Text periods are read when every label has the same one of these forms
#' (one step is the period itself, so a missing period is a gap):
#' \itemize{
#' \item a year: `"1987"`, `"2031"`;
#' \item a fiscal year by the two years it spans, ordered by the first:
#'   `"2019/20"`, `"2019/2020"`, `"2019-20"`,
#'   `"2019-2020"`, `"FY 2019-20"`,
#'   `"FY2019/20"`; or by one year: `"FY2020"`, `"FY 2020"` (the two kinds do
#'   not mix);
#' \item a quarter: `"2021 Q3"`, `"2021Q3"`, `"2021-Q3"`, `"Q3 2021"`;
#' \item a month: `"2021-03"`, `"2021/03"`, `"2021-3"`, or an English month
#'   name or its three-letter abbreviation: `"Mar 2021"`, `"March 2021"`,
#'   `"2021 Mar"`;
#' \item a date: `"2021-03-15"`, `"2021/03/15"`, compared as a `Date`.
#' }
#' The result keeps the labels as text, with any period the grid inserts
#' spelled like the first one. Labels of mixed forms, or of a form not listed
#' (`"Q3"`, `"FY19/20"`), or that read as two forms alike (`"2010-11"`,
#' `"2011-12"`: fiscal years or months), have no order: yoy() warns once,
#' naming them, and no row has a comparison period. Give their order with
#' `prdord`.
#' @param prdord Optional character vector: the period labels in order, one
#' label being one step, for text (or factor) periods the reader above does not
#' know. Every label in the data must be in it; one it lists that the data lacks
#' is a gap. `NULL` (the default) reads the labels as above.
#' @param by Optional grouping columns, as a character vector.
#' The change is computed within each group.
#' @param lag How many periods back to compare with. `1` is
#' year-over-year on annual data; for a `ts` the default follows the
#' series' own frequency, so monthly data compares with the same month a
#' year earlier.
#' @param fun How several rows of one period (and group) are combined into
#'   one value: `NULL` (the default) sums counts ([sum()]) and
#'   averages
#'   continuous values and percentages ([mean()]); pass a function of
#'   a
#'   numeric vector returning one number to choose.
#' @param units What the measure is. `"count"` gets the
#' exact rate-ratio interval. `"continuous"` gets the percent change
#' without one, since a single pair of totals carries no information about
#' its own variability. `"percent"` reports a percentage-POINT change
#' and withholds the percent change, which for a percentage is a different
#' quantity.
#' @param minbase Optional: previous-period values below this get a
#' \dQuote{small base} note. Nothing is withheld either way: every non-zero base
#' gets its percent change and exact interval, which is as wide as the base is
#' small. Defaults to 0 (no note); only a zero base has no percent change.
#' @param conflvl Numeric scalar in (0, 1), the confidence level for the
#' count interval; default 0.95.
#' @param dir Which way is an improvement:
#' `"higher"`, `"lower"` (segregation days,
#' deaths in custody, use of force), or `"neutral"`. Affects colour
#' and the `verdict` column only, never the arithmetic.
#' @param complete Logical scalar, default `TRUE`: insert the missing periods
#' in the observed range so that a gap is visible as a gap instead of closing
#' up.
#' @param ... Passed between methods: the numeric and `ts` methods pass every
#' argument of the data-frame method (`units`, `minbase`, `dir`,
#' ...)
#' through.
#' @section 0.5.x argument names:
#' The 0.5.x names `period`, `min_base`, `conf_level` and
#' `direction` are still accepted for `prd`, `minbase`, `conflvl`
#' and `dir`, the names to use, as are the 0.5.x values
#' `"higher_is_better"` and `"lower_is_better"` of `dir`. A call
#' that gives both names of one argument is refused.
#' @return An `rmbl_yoy` object (a data frame of class
#' `c("rmbl_yoy", "data.frame")`) with one row per period (and group): the
#' period column under its own name (`period` for a vector or a `ts`), the
#' grouping columns, then `value`, `previous`, `change`, `pctchg`
#' (or
#' `ppchg` for percentages), `flag` (character: \dQuote{no comparison period},
#' \dQuote{no data}, \dQuote{previous period is zero}, or a small-base note when
#' `minbase` is set; `NA` otherwise), `pctlo` and `pctup`
#' for counts,
#' and `verdict`. Attribute `"yoy"` records `value`, `period`,
#' `by`, `lag`,
#' `units`, `minbase`, `conflvl`, `direction` and the display
#' digits;
#' the writers ([yoywr()]) and
#' [yoysmry()] read it.
#' @references
#' The exact interval for a ratio of two counts is the conditional-binomial
#' (Clopper-Pearson) one, which is the construction
#' `stats::poisson.test` uses and which this is verified against. On
#' the reporting conventions, the Toronto Police Service's *Understanding
#' Strip Searches in 2020 Methodological Report* -- in the local corpus
#' -- reports year-over-year change on exactly this kind of
#' administrative extract, and is the shape this function is built for.
#' @seealso
#' [yoyhtml()], [yoypdf()],
#' [yoysmry()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' seg <- data.frame(
#'   EndFiscalYear = rep(2019:2023, each = 2),
#'   Gender = rep(c("Female", "Male"), 5),
#'   NumberOfPlacements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
#' )
#'
#' y <- yoy(
#'   seg,
#'   value = "NumberOfPlacements",
#'   prd = "EndFiscalYear",
#'   by = "Gender",
#'   dir = "lower"
#' )
#' y
#'
#' # The interval is exact, so a small group does not get a confident
#' # percent it has not earned.
#' subset(as.data.frame(y), Gender == "Female")
#'
#' # A percentage is handled as percentage points, not as a percent of a
#' # percent.
#' rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
#' yoy(rate, value = "share", prd = "year", units = "percent")
#'
#' # a missing year stays a gap; a bare column name works too
#' yoy(
#'   data.frame(year = c(2019, 2021, 2022), n = c(10, 12, 15)),
#'   value = n,
#'   prd = year
#' )
#'
#' # a quarterly series compares each quarter with the same quarter a year
#' # earlier
#' q <- ts(c(5, 6, 7, 8, 6, 7, 9, 9), frequency = 4, start = c(2020, 1))
#' as.data.frame(yoy(q))[5:8, c("period", "value", "previous", "pctchg")]
#'
#' # text periods are read: fiscal years, quarters, months
#' fy <- data.frame(fy = c("2019/20", "2020/21", "2022/23"), n = c(5, 7, 9))
#' as.data.frame(yoy(fy, "n", "fy"))[, c("fy", "previous", "flag")]
#' qt <- data.frame(q = c("2021 Q4", "2022 Q1", "2022 Q2"), n = c(3, 4, 6))
#' as.data.frame(yoy(qt, "n", "q"))[, c("q", "previous", "pctchg")]
#'
#' # labels the reader does not know take their order from `prdord`
#' ws <- data.frame(s = c("spring", "summer", "fall"), n = c(4, 6, 5))
#' yoy(ws, "n", "s", prdord = c("spring", "summer", "fall", "winter"))
#'
#' # counts must be whole numbers
#' try(yoy(data.frame(year = 1:3, n = c(1.5, 2, 3)), "n", "year"))
#' @export
#' @srrstats {G2.6} S3 methods for numeric, integer and ts pre-process 1-D input
#'   (as.numeric, ts frequency used as lag) before yoy.data.frame.
#' @srrstats {G2.10} Columns are extracted with `x[[value]]`, which returns a
#'   vector for data.frame, tibble and data.table alike.
#' @srrstats {G3.0} Whole-count check uses tolerance abs(v - round(v)) > 1e-8
#'   rather than exact equality.
#' @srrstats {EA2.3} The one internal join (.yoy_complete merge) is keyed only
#'   on the columns the user names in `prd` and `by`; no column names are
#'   assumed.
#' @srrstats {EA4.0} .yoy_restore puts aggregated key columns back to their
#'   input class (Date, POSIXct, factor, integer, numeric, logical);
#'   test-yoy.R:203-207,652.
#' @srrstats {EA4.2} The rmbl_yoy result has print (yoy_output.R) and plot
#'   (plots.R) methods; summary exists for drift, Benford and report objects;
#'   test-plots.R, test-print_methods.R.
#' @srrstats {TS1.1} @param x/prd list data frame, numeric, integer or ts input,
#'   with Date, POSIXct, integer or ordered-factor periods; methods dispatch on
#'   each class.
#' @srrstats {TS1.2} yoy.default rejects other classes, and .rmbl_num rejects
#'   factors, text, lists and logicals; tested in test-round5.R:317 and
#'   test-input-contracts.R.
#' @srrstats {TS1.3} yoy.numeric, yoy.integer and yoy.ts all convert to one
#'   period/value data frame and pass it to yoy.data.frame, the single
#'   validation and compute path.
#' @srrstats {TS1.4} .yoy_restore keeps the Date or POSIXct class and the tzone
#'   of the period column; tested in test-branches.R:32-42.
#' @srrstats {TS1.5} Rows are sorted by period and matched on the period's
#'   value, not row order; test-yoy.R "the percent change is the arithmetic, not
#'   the row order".
#' @srrstats {TS2.0} complete = TRUE inserts periods missing from the regular
#'   grid as explicit NA rows flagged "no data"; tested in test-yoy.R:34 and
#'   test-round5.R:96.
#' @srrstats {TS2.1} The `complete` option lets the user show gaps as explicit
#'   missing rows (TRUE) or analyse the irregular rows as they are (FALSE).
#' @srrstats {TS2.1b} complete = FALSE gives the same matched comparisons as the
#'   completed regular grid; test-yoy.R:34-55 checks `previous[2022]` under both
#'   settings.
#' @srrstats {TS4.0} Results are class-defined formats (rmbl_yoy,
#'   rmbl_count_trend, rmbl_stock_flow, rmbl_event_study), each with print and
#'   plot methods.
#' @srrstats {TS4.0b} Returns class c("rmbl_yoy","data.frame") with a "yoy"
#'   metadata attribute that the print, summary, plot and writer methods read.
#' @srrstats {TS4.1} The period's Date/POSIXct class and tzone carry into the
#'   output (test-branches.R:38-42); a ts frequency is kept as the lag in attr
#'   "yoy".
#' @srrstats {TS4.2} @return gives the class, every column with its type, and
#'   the contents of the "yoy" attribute.
yoy <- function(x, ...) UseMethod("yoy")

#' @rdname yoy
#' @export
yoy.default <- function(x, ...) {
  stop(
    sprintf(
      "`x` must be a data frame, a numeric or integer vector, or a ts, not %s",
      class(x)[1L]
    ),
    call. = FALSE
  )
}

#' @rdname yoy
#' @export
yoy.data.frame <- function(
  x,
  value,
  prd,
  by = NULL,
  lag = 1L,
  fun = NULL,
  units = c("count", "continuous", "percent"),
  minbase = NULL,
  conflvl = 0.95,
  dir = c(
    "neutral",
    "higher",
    "lower"
  ),
  complete = TRUE,
  prdord = NULL,
  ...
) {
  old <- .rmbl_old_names(.yoy_old_args)
  if (!is.null(old)) {
    # called the 0.5.x way: the result comes back under its 0.5.x names
    return(.rmbl_alias_out("yoy", withVisible(eval(old$call, old$env))))
  }
  .rmbl_no_dots("yoy", ...)
  .yoy_by_type(by)
  units <- .rmbl_arg(units)
  dir <- .rmbl_alias_val(
    dir,
    c(higher_is_better = "higher", lower_is_better = "lower")
  )
  dir <- .rmbl_arg(dir)
  # several rows for one period: counts add up, a rate or a share is averaged
  # (two shares of 53% and 57.9% are not 110.9%)
  if (is.null(fun)) {
    fun <- if (units == "count") sum else mean
  }
  value <- .yoy_col(substitute(value), value, x, "value")
  prd <- .yoy_col(substitute(prd), prd, x, "period")
  # text periods are read into an order (C18): "2019/20", "2021 Q3", "Mar 2021"
  pk <- .yoy_prd_read(x[[prd]], prdord)
  x[[prd]] <- pk$p
  .yoy_na_warn(x[[prd]])
  if (!is.null(by)) {
    by <- .yoy_check_by(by, x)
  }
  lag <- .yoy_check_lag(lag)
  conflvl <- .rmbl_conf_level(conflvl)
  v <- x[[value]]
  .yoy_check_value(v, value, units)
  minbase <- minbase %||% 0

  agg <- .yoy_aggregate(x, value, prd, by, fun)
  if (isTRUE(complete)) {
    agg <- .yoy_complete(agg, prd, by, lag)
  }
  out <- .yoy_compute(agg, value, prd, by, lag, units, minbase, conflvl, dir)
  .yoy_result(
    .yoy_prd_back(out, prd, pk),
    .yoy_settings(value, prd, by, lag, units, minbase, conflvl, dir, v),
    prdord
  )
}

#' @rdname yoy
#' @export
yoy.numeric <- function(x, prd = seq_along(x), ...) {
  old <- .rmbl_old_names(.yoy_old_args)
  if (!is.null(old)) {
    # called the 0.5.x way: the result comes back under its 0.5.x names
    return(.rmbl_alias_out("yoy", withVisible(eval(old$call, old$env))))
  }
  if (any(c("value", "data") %in% names(list(...)))) {
    stop(
      "for a numeric `x`, `x` is the values: give `prd` (and options), ",
      "not `value`",
      call. = FALSE
    )
  }
  if (length(prd) != length(x)) {
    stop("`prd` must have one entry per value of `x`", call. = FALSE)
  }
  d <- data.frame(period = prd, value = as.numeric(x))
  yoy.data.frame(d, value = "value", prd = "period", ...)
}

#' @rdname yoy
#' @export
yoy.integer <- function(x, prd = seq_along(x), ...) {
  old <- .rmbl_old_names(.yoy_old_args)
  if (!is.null(old)) {
    # called the 0.5.x way: the result comes back under its 0.5.x names
    return(.rmbl_alias_out("yoy", withVisible(eval(old$call, old$env))))
  }
  yoy.numeric(as.numeric(x), prd = prd, ...)
}

#' @rdname yoy
#' @export
yoy.ts <- function(x, lag = NULL, ...) {
  old <- .rmbl_old_names(.yoy_old_args)
  if (!is.null(old)) {
    # called the 0.5.x way: the result comes back under its 0.5.x names
    return(.rmbl_alias_out("yoy", withVisible(eval(old$call, old$env))))
  }
  f <- stats::frequency(x)
  # a year-over-year comparison on a seasonal series means the same
  # season one year earlier, which is the frequency itself -- comparing
  # with the previous OBSERVATION would mix January with December
  if (is.null(lag)) {
    lag <- max(1L, as.integer(round(f)))
  }
  tt <- stats::time(x)
  d <- data.frame(period = as.numeric(tt), value = as.numeric(x))
  yoy.data.frame(d, value = "value", prd = "period", lag = lag, ...)
}

#' yoy()'s grouping columns, each in the data.
#' @param by The columns.
#' @param x The data, which must have the `by` columns.
#' @return The columns, as text.
#' @noRd
.yoy_check_by <- function(by, x) {
  by <- as.character(by)
  miss <- setdiff(by, names(x))
  if (length(miss)) {
    stop(
      sprintf(
        "yoy: `by` column not found: %s",
        toString(miss)
      ),
      call. = FALSE
    )
  }
  by
}

#' yoy()'s value column: numeric, finite, and whole and non-negative for
#' counts.
#' @param v The value column, checked numeric and finite.
#' @param value Its name.
#' @param units The units.
#' @noRd
.yoy_check_value <- function(v, value, units) {
  if (!is.numeric(v)) {
    stop(
      sprintf("yoy: `%s` must be numeric, not %s", value, class(v)[1L]),
      call. = FALSE
    )
  }
  if (any(is.infinite(v))) {
    stop(
      "`value` has an infinite entry: a count or a measurement is finite",
      call. = FALSE
    )
  }
  if (units == "count") {
    nonint <- stats::na.omit(v)
    if (
      length(nonint) &&
        (any(nonint < 0) ||
          any(abs(nonint - round(nonint)) > 1e-8))
    ) {
      stop(
        "`units = \"count\"` needs non-negative whole numbers; ",
        "use units = \"continuous\" for a measured quantity",
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

# the 0.5.x argument names of yoy(), still accepted (yoy() kept its name, so it
# has no alias)
.yoy_old_args <- c(
  period = "prd",
  min_base = "minbase",
  conf_level = "conflvl",
  direction = "dir"
)

#' Resolve a column given either a bare name or a string.
#'
#' The unevaluated argument is consulted FIRST. Testing is.character(val)
#' before that forces the promise, so a bare column name -- the whole
#' point of accepting one -- raised \dQuote{object 'n' not found} instead of
#' naming the column.
#' @param sub The unevaluated argument, from `substitute()`.
#' @param val The argument itself.
#' @param data The data frame to find the column in.
#' @param what The argument's name, quoted if the column is not found.
#' @return The column's name.
#' @noRd
.yoy_col <- function(sub, val, data, what) {
  nm <- NULL
  if (is.name(sub)) {
    cand <- as.character(sub)
    if (cand %in% names(data)) nm <- cand
  }
  if (is.null(nm)) {
    # the promise of a bare name the table lacks fails in R's words ("object
    # 'stops' not found"; final audit of 1.0.0): read as no name
    v <- tryCatch(val, error = function(e) NULL)
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

#' Collapse to one row per period (and group).
#' @param x The data frame aggregated by period and group.
#' @param value The value column's name.
#' @param period The period column's name.
#' @param by The group columns' names, or NULL.
#' @param fun The function that collapses a period's values to one.
#' @return A data frame ordered by group and period.
#' @noRd
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
  for (k in keys) {
    out[[k]] <- .yoy_restore(out[[k]], x[[k]])
  }
  out[[value]] <- unname(vals)
  out[order(.yoy_order(out, keys)), , drop = FALSE]
}

#' Warns of rows with no period: they are kept, with no change.
#' @param p The periods.
#' @return NULL, invisibly.
#' @noRd
.yoy_na_warn <- function(p) {
  if (anyNA(p)) {
    warning(
      sprintf(
        "yoy: %d row(s) have no period (NA): they are kept, with no change",
        sum(is.na(p))
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Orders rows by the keys taken last first, so rows sort by group and then by
#' period.
#' @param d The data frame to order by `keys`.
#' @param keys The columns to order by.
#' @return An integer permutation.
#' @noRd
.yoy_order <- function(d, keys) {
  do.call(order, lapply(rev(keys), function(k) d[[k]]))
}

#' Put a stringified key back into the class it came from.
#' @param chr The stringified key.
#' @param orig The original column.
#' @return `chr` in the class of `orig`.
#' @noRd
.yoy_restore <- function(chr, orig) {
  if (is.factor(orig)) {
    # an ordered factor stays ordered: its levels are the period grid
    return(factor(chr, levels = levels(orig), ordered = is.ordered(orig)))
  }
  if (inherits(orig, "Date")) {
    return(as.Date(chr))
  }
  if (inherits(orig, "POSIXct")) {
    return(as.POSIXct(chr, tz = attr(orig, "tzone")))
  }
  if (is.integer(orig)) {
    return(as.integer(chr))
  }
  if (is.numeric(orig)) {
    return(as.numeric(chr))
  }
  if (is.logical(orig)) {
    return(as.logical(chr))
  }
  chr
}

#' Insert the periods that are absent from the observed range, so a gap
#' shows as a gap instead of the next period closing up over it.
#' @param agg The aggregated data, from `.yoy_aggregate()`.
#' @param period The period column's name.
#' @param by The group columns' names, or NULL.
#' @param lag The comparison lag, in periods.
#' @return `agg` with the missing periods added as rows with no value.
#' @noRd
.yoy_complete <- function(agg, period, by, lag) {
  p <- agg[[period]]
  full <- .yoy_period_grid(p)
  if (is.null(full) || length(full) == length(unique(p))) {
    return(agg)
  }
  if (is.null(by)) {
    grid <- data.frame(x = full, stringsAsFactors = FALSE)
    names(grid) <- period
  } else {
    grid <- expand.grid(
      c(
        stats::setNames(list(full), period),
        lapply(agg[by], unique)
      ),
      stringsAsFactors = FALSE
    )
  }
  # all = TRUE, not all.x: the grid contributes the missing periods and
  # the data keeps every period it actually has, even one the grid does
  # not contain.
  out <- merge(grid, agg, by = c(period, by), all = TRUE)
  out[order(.yoy_order(out, c(period, by))), , drop = FALSE]
}

#' The full grid of dated periods: whole calendar months apart for yearly,
#' quarterly or monthly dates, else days.
#' @param u The periods, sorted and unique.
#' @return The grid, or NULL.
#' @noRd
.yoy_date_grid <- function(u) {
  cal <- .yoy_calendar(u)
  if (!is.null(cal)) {
    # yearly, quarterly or monthly dates: whole calendar months apart, not a
    # count of days (2019-01-01 to 2020-01-01 is 365 days, then 366: a one-day
    # grid compared nothing)
    mu <- .yoy_months(u)
    step <- .yoy_gcd(diff(mu))
    n <- (max(mu) - min(mu)) / step + 1
    if (cal == "end") {
      return(seq(min(u) + 1, by = paste(step, "months"), length.out = n) - 1)
    }
    return(seq(min(u), by = paste(step, "months"), length.out = n))
  }
  d <- as.numeric(diff(u))
  step <- .yoy_gcd(d)
  if (!is.finite(step) || step <= 0) {
    return(NULL)
  }
  seq(min(u), max(u), by = step)
}

#' The full grid of numeric periods, at their common step.
#' @param p The numeric periods the grid spans.
#' @param u The periods, sorted and unique.
#' @return The grid, or NULL.
#' @noRd
.yoy_num_grid <- function(p, u) {
  d <- diff(u)
  step <- .yoy_gcd(d)
  if (!is.finite(step) || step <= 0) {
    return(NULL)
  }
  n <- (max(u) - min(u)) / step
  if (!is.finite(n) || n > 1e5) {
    return(NULL)
  }
  g <- min(u) + step * seq.int(0L, round(n))
  if (is.integer(p)) as.integer(round(g)) else g
}

#' The regular grid a period column implies, or NULL when it has none.
#' @param p The period column.
#' @return A vector of periods, or NULL.
#' @noRd
.yoy_period_grid <- function(p) {
  if (is.ordered(p)) {
    r <- range(as.integer(p), na.rm = TRUE)
    return(factor(levels(p)[r[1L]:r[2L]], levels = levels(p), ordered = TRUE))
  }
  if (!is.numeric(p) && !inherits(p, c("Date", "POSIXct"))) {
    return(NULL)
  }
  u <- sort(unique(p))
  if (length(u) < 2L) {
    return(NULL)
  }
  if (inherits(p, "Date")) {
    return(.yoy_date_grid(u))
  }
  if (is.numeric(u)) {
    return(.yoy_num_grid(p, u))
  }
  NULL
}

#' Whether sorted unique dates fall on calendar steps.
#' @param u Sorted unique dates.
#' @return `"day"` when all share one day of the month (1 to 28), `"end"` when
#'   all are month ends, else NULL (daily or weekly data, stepped in days).
#' @noRd
.yoy_calendar <- function(u) {
  lt <- as.POSIXlt(u)
  if (length(unique(lt$mday)) == 1L && lt$mday[1L] <= 28L) {
    return("day")
  }
  if (all(as.POSIXlt(u + 1)$mday == 1L)) {
    return("end")
  }
  NULL
}

#' Month number (12 * year + month) of dates.
#' @param x Dates.
#' @return A double vector.
#' @noRd
.yoy_months <- function(x) {
  lt <- as.POSIXlt(x)
  (lt$year + 1900) * 12 + lt$mon
}

#' Returns the greatest common step of period differences, or the smallest when
#' they are fractional.
#' @param d The differences.
#' @return A number, or NA when there is no positive difference.
#' @noRd
.yoy_gcd <- function(d) {
  d <- d[is.finite(d) & d > 0]
  if (!length(d)) {
    return(NA_real_)
  }
  if (any(abs(d - round(d)) > 1e-8)) {
    return(min(d))
  }
  g <- abs(round(d[1L]))
  for (k in round(d[-1L])) {
    k <- abs(k)
    while (k) {
      t <- g %% k
      g <- k
      k <- t
    }
  }
  as.numeric(g)
}

#' The comparison itself.
#' @param agg The completed data, from `.yoy_complete()`.
#' @param value The value column's name.
#' @param period The period column's name.
#' @param by The group columns' names, or NULL.
#' @param lag The comparison lag, in periods.
#' @param units \code{"count"}, \code{"percent"} or another unit.
#' @param min_base The previous value below which a change is flagged as a small
#'   base.
#' @param conf_level The confidence level of the count-ratio interval.
#' @param direction \code{"higher"}, \code{"lower"} or \code{"neutral"}: which
#' way is better.
#' @return A data frame, one row per period and group.
#' @noRd
.yoy_compute <- function(
  agg,
  value,
  period,
  by,
  lag,
  units,
  min_base,
  conf_level,
  direction
) {
  conf_level <- .rmbl_conf_level(conf_level)
  pieces <- if (is.null(by)) {
    list(agg)
  } else {
    split(agg, agg[by], drop = TRUE, sep = "\r")
  }
  res <- lapply(
    pieces,
    .yoy_compute_one,
    value = value,
    period = period,
    by = by,
    lag = lag,
    units = units,
    min_base = min_base,
    conf_level = conf_level,
    direction = direction
  )
  # unnamed: rbind() makes row names of the group labels, and in a C locale
  # translating one that is not ASCII warned "unable to translate"
  out <- do.call(rbind, unname(res))
  rownames(out) <- NULL
  out
}

#' Previous value at the period `lag` grid-steps earlier.
#' @param p The periods; each one's previous period is found.
#' @param v The values, taken at each previous period.
#' @param lag The lag, in grid steps.
#' @return A double vector, NA where the earlier period is absent.
#' @noRd
.yoy_previous <- function(p, v, lag) {
  # A period has to be on a numeric scale for "lag periods earlier" to
  # mean anything. A character or factor column -- "Q1", "Q2" -- has no
  # step, and taking diff() of it raised rather than reporting that
  # there is no comparison to make.
  if (is.ordered(p)) {
    # an ordered factor's levels are the grid: one level is one step
    key <- as.integer(p)
    idx <- match(key - lag, key)
    out <- rep(NA_real_, length(v))
    out[!is.na(idx)] <- v[idx[!is.na(idx)]]
    return(out)
  }
  if (!is.numeric(p) && !inherits(p, c("Date", "POSIXct"))) {
    return(rep(NA_real_, length(v)))
  }
  u <- sort(unique(p))
  if (length(u) < 2L) {
    return(rep(NA_real_, length(v)))
  }
  if (inherits(p, "Date") && !is.null(.yoy_calendar(u))) {
    # calendar steps: count in months, so a year back is 12 months back, leap
    # day or not
    p <- .yoy_months(p)
    u <- .yoy_months(u)
  }
  step <- .yoy_gcd(as.numeric(diff(u)))
  if (!is.finite(step) || step <= 0) {
    return(rep(NA_real_, length(v)))
  }
  # Match on the grid INDEX rather than on a reconstructed period value. A
  # monthly ts has a step of 1/12, so p - 12 * step lands a few parts in 10^16
  # away from the period it is meant to find and match() misses every row -- a
  # table in which nothing has a comparison period. Dividing by the step first
  # turns the comparison into integers. from the first period: 2017 / 2 is
  # 1008.5, and round() goes to the even 1008 for 2015 and 2017 alike, so a
  # biennial series had no comparison at all
  key <- round((as.numeric(p) - as.numeric(min(u))) / step)
  idx <- match(key - lag, key)
  out <- rep(NA_real_, length(v))
  ok <- !is.na(idx)
  out[ok] <- v[idx[ok]]
  out
}

#' Exact interval for the ratio of two counts.
#'
#' Conditional on the total a + b, the current count a is
#' Binomial(a + b, p) with p = R / (1 + R), where R is the ratio of the
#' two periods' rates. A Clopper-Pearson interval for p therefore maps
#' straight onto an exact interval for R, and from there to the percent
#' change. No simulation and no normal approximation, which is what makes
#' it usable at the small counts where the percent change is least
#' trustworthy.
#' @param a The current counts in the ratios.
#' @param b The previous counts.
#' @param conf_level The confidence level of the ratio intervals.
#' @return A list with the percent-change limits `lower` and `upper`.
#' @noRd
.yoy_ratio_ci <- function(a, b, conf_level) {
  conf_level <- .rmbl_conf_level(conf_level)
  n <- length(a)
  lower <- rep(NA_real_, n)
  upper <- rep(NA_real_, n)
  alpha <- 1 - conf_level
  for (i in seq_len(n)) {
    ai <- a[i]
    bi <- b[i]
    if (is.na(ai) || is.na(bi) || (ai + bi) == 0) {
      next
    }
    pl <- if (ai == 0) 0 else stats::qbeta(alpha / 2, ai, bi + 1)
    pu <- if (bi == 0) 1 else stats::qbeta(1 - alpha / 2, ai + 1, bi)
    lower[i] <- 100 * (pl / (1 - pl) - 1)
    upper[i] <- if (pu >= 1) Inf else 100 * (pu / (1 - pu) - 1)
  }
  list(lower = lower, upper = upper)
}

#' How many decimals the value column needs. A count has none; a measured
#' quantity keeps what it actually carries, so a rate of 4.1 does not
#' print as 4 and its change of 0.5 does not print as 0.
#' @param v The values whose decimal places are chosen.
#' @param units \code{"count"} or another unit.
#' @return An integer from 0 to 6.
#' @noRd
.yoy_value_digits <- function(v, units) {
  if (identical(units, "count")) {
    return(0L)
  }
  fin <- v[is.finite(v)]
  if (!length(fin)) {
    return(0L)
  }
  dec <- vapply(
    fin,
    function(z) {
      for (k in 0:6) {
        if (abs(z - round(z, k)) < 1e-9) return(k)
      }
      6L
    },
    0L
  )
  min(6L, max(dec))
}

#' Names each change: up, down or unchanged, or better or worse when a direction
#' is set.
#' @param chg The changes to call up, down or flat.
#' @param direction \code{"higher"}, \code{"lower"} or \code{"neutral"}.
#' @return A character vector.
#' @noRd
.yoy_verdict <- function(chg, direction) {
  out <- rep(NA_character_, length(chg))
  ok <- !is.na(chg)
  if (!any(ok)) {
    return(out)
  }
  flat <- ok & chg == 0
  up <- ok & chg > 0
  down <- ok & chg < 0
  out[flat] <- "unchanged"
  if (direction == "neutral") {
    out[up] <- "up"
    out[down] <- "down"
  } else if (direction == "higher") {
    out[up] <- "better"
    out[down] <- "worse"
  } else {
    out[up] <- "worse"
    out[down] <- "better"
  }
  out
}

#' Checks yoy()'s `by` is NULL or column names.
#' @param by The value passed.
#' @return `by`, invisibly.
#' @noRd
.yoy_by_type <- function(by) {
  if (!is.null(by) && (!is.character(by) || !length(by) || anyNA(by))) {
    stop("yoy: `by` must be one or more column names, or NULL", call. = FALSE)
  }
  invisible(by)
}

#' Checks yoy()'s `lag`.
#' @param lag The value passed.
#' @return `lag` as a positive whole number.
#' @noRd
.yoy_check_lag <- function(lag) {
  lag <- .rmbl_num(lag, "lag", integer = TRUE)
  if (length(lag) != 1L || is.na(lag) || lag < 1L) {
    stop("yoy: `lag` must be a positive integer", call. = FALSE)
  }
  lag
}

#' The `yoy` attribute of a yoy() result: what was compared, and how.
#' @param value,period,by,lag,units,minbase,conflvl,direction As used.
#' @param v The value column, for its printed digits.
#' @return A list.
#' @noRd
.yoy_settings <- function(
  value,
  period,
  by,
  lag,
  units,
  minbase,
  conflvl,
  direction,
  v
) {
  list(
    value = value,
    period = period,
    by = by,
    lag = lag,
    units = units,
    minbase = minbase,
    conflvl = conflvl,
    direction = direction,
    valuedig = .yoy_value_digits(v, units)
  )
}

#' A yoy() result: the table, its class and its settings.
#' @param out The change table.
#' @param meta The settings, from .yoy_settings().
#' @param prdord The order of text periods yoy() was given, or NULL; yoysmry()
#'   reads it.
#' @return An `rmbl_yoy` object.
#' @noRd
.yoy_result <- function(out, meta, prdord) {
  meta$prdord <- prdord
  structure(out, class = c("rmbl_yoy", "data.frame"), yoy = meta)
}

#' The year-on-year rows of one series (one `by` group).
#' @param g The group's aggregated rows.
#' @param value,period,by,lag,units,min_base,conf_level,direction As for
#'   .yoy_compute().
#' @return A data frame.
#' @noRd
.yoy_compute_one <- function(
  g,
  value,
  period,
  by,
  lag,
  units,
  min_base,
  conf_level,
  direction
) {
  g <- g[order(g[[period]]), , drop = FALSE]
  v <- as.numeric(g[[value]])
  p <- g[[period]]
  # Match on the PERIOD, not on position: previous is the row whose
  # period is `lag` steps earlier on the grid, and is NA when that
  # period is absent. Taking v[i - lag] instead would compare 2023
  # with 2020 whenever 2021 were missing, and say nothing about it.
  prev <- .yoy_previous(p, v, lag)
  # a row with no period has no period before it (its NA key matched itself)
  prev[is.na(p)] <- NA_real_
  out <- data.frame(
    period = p,
    value = v,
    previous = prev,
    stringsAsFactors = FALSE
  )
  names(out)[1L] <- period
  out$change <- v - prev
  if (units == "percent") {
    # a percentage moves by percentage POINTS; the percent change of a
    # percent is a different quantity and is not reported as "the"
    # change
    out$ppchg <- v - prev
  } else {
    pct <- 100 * (v - prev) / prev
    pct[!is.finite(pct)] <- NA_real_
    out$pctchg <- pct
  }
  out$flag <- .yoy_flags(v, prev, units, min_base)
  if (units == "count") {
    ci <- .yoy_ratio_ci(v, prev, conf_level)
    out$pctlo <- ci$lower
    out$pctup <- ci$upper
  }
  # The verdict follows the CHANGE, not the percent: a rise from a zero
  # base has no percent but is still a rise.
  out$verdict <- .yoy_verdict(out$change, direction)
  if (!is.null(by)) {
    for (b in by) {
      out[[b]] <- g[[b]][seq_len(nrow(out))]
    }
    out <- out[, c(by, setdiff(names(out), by)), drop = FALSE]
  }
  out
}

#' The flag of each year-on-year row: why its change is missing or weak.
#' @param v The values to flag.
#' @param prev The values `lag` periods earlier.
#' @param units The value's units; percents get no small-base or zero-base flag.
#' @param min_base The smallest base the caller trusts.
#' @return A character vector, NA where there is nothing to say.
#' @noRd
.yoy_flags <- function(v, prev, units, min_base) {
  flag <- rep(NA_character_, length(v))
  flag[is.na(prev)] <- "no comparison period"
  small <- !is.na(prev) & prev < min_base
  if (units != "percent") {
    # a small base is computed like any other: the exact interval carries how
    # little it supports; the note appears only when the caller set minbase
    flag[small] <- sprintf("small base (below %g)", min_base)
    zero <- !is.na(prev) & prev == 0
    flag[zero] <- "previous period is zero"
  }
  # a period the grid inserted: nothing was published for it
  flag[is.na(v)] <- "no data"
  flag
}

#' Reads text periods into an order yoy() can step through.
#'
#' A character period column had no order, so every row was flagged \dQuote{no
#' comparison period} for "2019/20" or "2021 Q3" alike (C18). The labels are
#' read when all of them have one form the reader knows (see yoy()'s `prd`);
#' `prdord` gives the order of any others.
#' @param p The period column.
#' @param prdord NULL, or the labels in order.
#' @param quiet Whether to skip the warning about labels with no order.
#' @return A list: `p`, the periods to compute on (an ordered factor, dates, or
#'   `p` itself), and `back`, a function turning the computed periods back into
#'   text (NULL to keep them as they are).
#' @noRd
.yoy_prd_read <- function(p, prdord = NULL, quiet = FALSE) {
  if (!is.null(prdord)) {
    return(.yoy_prd_given(p, prdord))
  }
  # an unordered factor's levels are only sorted labels, not an order: its
  # labels are read as text is ("2019/20" before "2020/21")
  if (is.factor(p) && !is.ordered(p)) {
    p <- as.character(p)
  }
  if (!is.character(p)) {
    return(list(p = p))
  }
  lab <- unique(p[!is.na(p)])
  if (!length(lab)) {
    return(list(p = p))
  }
  k <- .yoy_prd_kind(lab)
  if (is.null(k$kind)) {
    if (!quiet) {
      .yoy_prd_warn(k)
    }
    return(list(p = p))
  }
  if (k$kind == "date") {
    return(.yoy_prd_dates(p, lab, k$key))
  }
  .yoy_prd_factor(p, lab, k)
}

#' yoy()'s periods in the order `prdord` gives.
#' @param p The period column, text or a factor.
#' @param prdord The labels in order, one label one step.
#' @return As for .yoy_prd_read().
#' @noRd
.yoy_prd_given <- function(p, prdord) {
  if (
    !is.character(prdord) ||
      !length(prdord) ||
      anyNA(prdord) ||
      !all(nzchar(prdord)) ||
      anyDuplicated(prdord)
  ) {
    stop(
      "yoy: `prdord` must be the period labels in order: distinct, ",
      "non-empty strings",
      call. = FALSE
    )
  }
  if (!is.character(p) && !is.factor(p)) {
    stop(
      sprintf(
        "yoy: `prdord` orders text periods, but the `prd` column is %s",
        class(p)[1L]
      ),
      call. = FALSE
    )
  }
  s <- as.character(p)
  miss <- setdiff(unique(s[!is.na(s)]), prdord)
  if (length(miss)) {
    stop(
      sprintf(
        "yoy: `prdord` must list every period label; it lacks %s",
        .yoy_prd_shown(miss)
      ),
      call. = FALSE
    )
  }
  list(
    p = factor(s, levels = prdord, ordered = TRUE),
    back = if (is.character(p)) as.character
  )
}

#' Up to five labels, quoted, for a message.
#' @param b The labels.
#' @return One string.
#' @noRd
.yoy_prd_shown <- function(b) {
  more <- if (length(b) > 5L) sprintf(" and %d more", length(b) - 5L) else ""
  paste0(toString(dQuote(utils::head(b, 5L), FALSE)), more)
}

#' Warns once that yoy()'s text periods have no order, naming them.
#' @param k The reader's verdict, from .yoy_prd_kind(): `bad` and `why`.
#' @noRd
.yoy_prd_warn <- function(k) {
  warning(
    sprintf(
      paste0(
        "yoy: the periods %s %s, so they have no order and no row has a ",
        "comparison period; give their order with `prdord`"
      ),
      .yoy_prd_shown(k$bad),
      k$why
    ),
    call. = FALSE
  )
}

#' The one form every label has, with each label's step number.
#' @param lab The distinct labels, none missing.
#' @return A list: `kind` and `key` (one number per label) when every label
#'   reads as one form; else `bad`, the labels with no order, and `why`.
#' @noRd
.yoy_prd_kind <- function(lab) {
  keys <- lapply(.yoy_prd_kinds(), function(f) f(lab))
  full <- names(keys)[!vapply(keys, anyNA, NA)]
  # one label has no comparison either way: a form it shares is no matter
  if (length(full) == 1L || (length(full) > 1L && length(lab) == 1L)) {
    return(list(kind = full[1L], key = keys[[full[1L]]]))
  }
  words <- c(
    year = "years",
    fiscal = "fiscal years",
    fy = "fiscal years",
    quarter = "quarters",
    month = "months",
    date = "dates"
  )
  if (length(full) > 1L) {
    why <- paste("read as", paste(unique(words[full]), collapse = " or as "))
    return(list(bad = lab, why = paste(why, "alike")))
  }
  hit <- vapply(keys, function(k) sum(!is.na(k)), 0L)
  if (!any(hit > 0L)) {
    return(list(bad = lab, why = "are of no form yoy() reads"))
  }
  best <- which.max(hit)
  list(
    bad = lab[is.na(keys[[best]])],
    why = sprintf("are not %s like the others", words[names(keys)[best]])
  )
}

#' The forms of text period yoy() reads, each a function giving a label's step
#' number (NA when the label is not of that form).
#' @return A named list of functions.
#' @noRd
.yoy_prd_kinds <- function() {
  list(
    year = .yoy_key_year,
    fiscal = .yoy_key_fiscal,
    fy = .yoy_key_fy,
    quarter = .yoy_key_quarter,
    month = .yoy_key_month,
    date = .yoy_key_date
  )
}

#' The groups of a regular expression in each string.
#' @param s The strings.
#' @param re A Perl regular expression with `n` groups.
#' @param n The number of groups.
#' @return A character matrix, one row per string, NA where it does not match.
#' @noRd
.yoy_rx <- function(s, re, n) {
  m <- regmatches(s, regexec(re, s, perl = TRUE))
  out <- matrix(NA_character_, length(s), n)
  hit <- lengths(m) > 0L
  if (any(hit)) {
    g <- unlist(lapply(m[hit], `[`, -1L))
    out[hit, ] <- matrix(g, ncol = n, byrow = TRUE)
  }
  out
}

# a fiscal year by the two years it spans: "2019/20", "FY 2019-2020"
.YOY_FISCAL <- "^([Ff][Yy] ?)?([0-9]{4})([/-])([0-9]{2}|[0-9]{4})$"

#' A plain year's step number: the year.
#' @param s The labels.
#' @return A double vector, NA where a label is not a year.
#' @noRd
.yoy_key_year <- function(s) as.numeric(.yoy_rx(s, "^([0-9]{4})$", 1L)[, 1L])

#' A two-year fiscal year's step number: its first year.
#' @param s The labels.
#' @return A double vector, NA where a label is not such a fiscal year (the
#'   second year must follow the first).
#' @noRd
.yoy_key_fiscal <- function(s) {
  g <- .yoy_rx(s, .YOY_FISCAL, 4L)
  y1 <- as.numeric(g[, 2L])
  y2 <- as.numeric(g[, 4L])
  nxt <- ifelse(nchar(g[, 4L]) == 2L, (y1 + 1) %% 100, y1 + 1)
  y1[is.na(y2) | y2 != nxt] <- NA_real_
  y1
}

#' A one-year fiscal year's ("FY2020") step number: the year.
#' @param s The labels.
#' @return A double vector, NA where a label is not of that form.
#' @noRd
.yoy_key_fy <- function(s) {
  as.numeric(.yoy_rx(s, "^[Ff][Yy] ?([0-9]{4})$", 1L)[, 1L])
}

#' A quarter's step number: 4 * year + quarter - 1.
#' @param s The labels: "2021 Q3", "2021Q3", "2021-Q3" or "Q3 2021".
#' @return A double vector, NA where a label is not a quarter.
#' @noRd
.yoy_key_quarter <- function(s) {
  a <- .yoy_rx(s, "^([0-9]{4})[ -]?[Qq]([1-4])$", 2L)
  b <- .yoy_rx(s, "^[Qq]([1-4]) ([0-9]{4})$", 2L)
  y <- as.numeric(ifelse(is.na(a[, 1L]), b[, 2L], a[, 1L]))
  q <- as.numeric(ifelse(is.na(a[, 2L]), b[, 1L], a[, 2L]))
  4 * y + q - 1
}

#' A month's step number: 12 * year + month - 1.
#' @param s The labels: "2021-03", "2021/3", "Mar 2021", "March 2021" or
#'   "2021 Mar" (English month names).
#' @return A double vector, NA where a label is not a month.
#' @noRd
.yoy_key_month <- function(s) {
  a <- .yoy_rx(s, "^([0-9]{4})[-/]([0-9]{1,2})$", 2L)
  b <- .yoy_rx(s, "^([A-Za-z]+) ([0-9]{4})$", 2L)
  d <- .yoy_rx(s, "^([0-9]{4}) ([A-Za-z]+)$", 2L)
  nm <- ifelse(is.na(b[, 1L]), d[, 2L], b[, 1L])
  l <- tolower(nm)
  mn <- match(l, tolower(month.abb))
  mn <- ifelse(is.na(mn), match(l, tolower(month.name)), mn)
  yn <- ifelse(is.na(b[, 2L]), d[, 1L], b[, 2L])
  y <- as.numeric(ifelse(is.na(a[, 1L]), yn, a[, 1L]))
  m <- ifelse(is.na(a[, 2L]), mn, as.numeric(a[, 2L]))
  m[!is.na(m) & (m < 1 | m > 12)] <- NA_real_
  12 * y + m - 1
}

#' A date's step number: its day number, as a Date.
#' @param s The labels: "2021-03-15" or "2021/03/15".
#' @return A double vector, NA where a label is not a date.
#' @noRd
.yoy_key_date <- function(s) {
  ok <- grepl("^[0-9]{4}([-/])[0-9]{2}\\1[0-9]{2}$", s, perl = TRUE)
  d <- rep(NA_real_, length(s))
  iso <- gsub("/", "-", s[ok], fixed = TRUE)
  d[ok] <- as.numeric(as.Date(iso, format = "%Y-%m-%d"))
  d
}

#' Text periods of one form as an ordered factor of every step in their range.
#'
#' One level per step from the first period to the last, so a missing period is
#' a gap (an absent level), exactly as for numeric years. A step the data lacks
#' is named like the first label; a period spelled two ways takes its first
#' spelling.
#' @param p The period column.
#' @param lab Its distinct labels.
#' @param k The reader's verdict: `kind` and `key`, one step number per label.
#' @return As for .yoy_prd_read().
#' @noRd
.yoy_prd_factor <- function(p, lab, k) {
  key <- k$key
  grid <- seq(min(key), max(key))
  lv <- lab[match(grid, key)]
  gap <- is.na(lv)
  if (any(gap)) {
    lv[gap] <- .yoy_key_label(k$kind, lab[which.min(key)], grid[gap])
  }
  pf <- factor(lv[match(key[match(p, lab)], grid)], levels = lv, ordered = TRUE)
  list(p = pf, back = as.character)
}

#' Text dates as dates, and back as their own labels.
#' @param p The period column.
#' @param lab Its distinct labels.
#' @param key Each label's day number.
#' @return As for .yoy_prd_read().
#' @noRd
.yoy_prd_dates <- function(p, lab, key) {
  d <- as.Date(key[match(p, lab)], origin = "1970-01-01")
  sep <- if (grepl("/", lab[1L], fixed = TRUE)) "/" else "-"
  back <- function(x) {
    out <- lab[match(as.numeric(x), key)]
    new <- is.na(out) & !is.na(x)
    out[new] <- format(x[new], paste0("%Y", sep, "%m", sep, "%d"))
    out
  }
  list(p = d, back = back)
}

#' The label of a step the data lacks, spelled like a label it has.
#' @param kind The form: year, fiscal, fy, quarter or month.
#' @param tpl A label of that form, whose spelling is copied.
#' @param key The step numbers to name.
#' @return A character vector.
#' @noRd
.yoy_key_label <- function(kind, tpl, key) {
  switch(
    kind,
    year = as.character(key),
    fy = paste0(sub("[0-9]{4}$", "", tpl), key),
    fiscal = .yoy_lab_fiscal(tpl, key),
    quarter = .yoy_lab_quarter(tpl, key),
    month = .yoy_lab_month(tpl, key)
  )
}

#' A two-year fiscal year's label, spelled like `tpl`.
#' @param tpl A fiscal-year label.
#' @param key The first years.
#' @return A character vector.
#' @noRd
.yoy_lab_fiscal <- function(tpl, key) {
  g <- .yoy_rx(tpl, .YOY_FISCAL, 4L)
  y2 <- if (nchar(g[4L]) == 2L) {
    sprintf("%02d", as.integer((key + 1) %% 100))
  } else {
    key + 1
  }
  paste0(g[1L], key, g[3L], y2)
}

#' A quarter's label, spelled like `tpl`.
#' @param tpl A quarter label.
#' @param key The step numbers (4 * year + quarter - 1).
#' @return A character vector.
#' @noRd
.yoy_lab_quarter <- function(tpl, key) {
  y <- key %/% 4
  q <- key %% 4 + 1
  if (grepl("^[Qq]", tpl)) {
    return(paste0(substr(tpl, 1L, 1L), q, " ", y))
  }
  paste0(y, sub("^[0-9]{4}([ -]?[Qq])[1-4]$", "\\1", tpl), q)
}

#' A month's label, spelled like `tpl`.
#' @param tpl A month label.
#' @param key The step numbers (12 * year + month - 1).
#' @return A character vector.
#' @noRd
.yoy_lab_month <- function(tpl, key) {
  y <- key %/% 12
  m <- key %% 12 + 1
  a <- .yoy_rx(tpl, "^[0-9]{4}([-/])([0-9]{1,2})$", 2L)
  if (!is.na(a[1L])) {
    mm <- if (nchar(a[2L]) == 2L) sprintf("%02d", as.integer(m)) else m
    return(paste0(y, a[1L], mm))
  }
  nm <- regmatches(tpl, regexpr("[A-Za-z]+", tpl))
  mon <- if (nchar(nm) > 3L) month.name[m] else month.abb[m]
  if (identical(nm, toupper(nm))) {
    mon <- toupper(mon)
  }
  if (grepl("^[0-9]", tpl)) paste(y, mon) else paste(mon, y)
}

#' yoy()'s computed periods back as the text they were given as.
#' @param out The change table.
#' @param prd The period column's name.
#' @param pk The reader's result, from .yoy_prd_read().
#' @return `out`.
#' @noRd
.yoy_prd_back <- function(out, prd, pk) {
  if (!is.null(pk$back)) {
    out[[prd]] <- pk$back(out[[prd]])
  }
  out
}

#' A sort key for periods, read as yoy() reads them, or NULL when they have no
#' order (text or an unordered factor the reader cannot place).
#' @param p The periods.
#' @param prdord The order yoy() was given, or NULL.
#' @return An integer or double vector, or NULL.
#' @noRd
.yoy_prd_rank <- function(p, prdord = NULL) {
  if (!is.character(p) && !(is.factor(p) && !is.ordered(p))) {
    return(xtfrm(p))
  }
  if (is.factor(p) && is.null(prdord)) {
    return(NULL)
  }
  r <- tryCatch(
    .yoy_prd_read(p, prdord, quiet = TRUE)$p,
    error = function(e) NULL
  )
  if (is.null(r) || is.character(r)) NULL else xtfrm(r)
}

#' The distinct periods, in the order yoy() reads them (sorted when they have
#' none).
#' @param p The periods.
#' @return The distinct non-missing periods.
#' @noRd
.yoy_prd_sort <- function(p, prdord = NULL) {
  u <- unique(p[!is.na(p)])
  r <- .yoy_prd_rank(u, prdord)
  if (is.null(r)) sort(u) else u[order(r)]
}
