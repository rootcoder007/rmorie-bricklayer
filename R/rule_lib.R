# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A vocabulary of ready-made rules. rule() takes any predicate, but the
# same handful of checks account for most of what anyone writes -- a
# value in a set, a number in a range, an identifier that must be unique
# -- and writing them out by hand each time invites the off-by-one that
# makes a rule silently pass. These are the standard ones, once.

#' Ready-made validation rules
#'
#' Constructors for the checks most schemas need, each returning a
#' [rul()] that
#' [valrules()] evaluates. Use
#' [rul()] directly for anything not covered here. Writing the common
#' checks once, here, avoids the off-by-one or the forgotten \code{NA} that
#' makes a hand-written rule pass silently, and gives every failure a
#' readable message and the rows that failed.
#'
#' @details
#' What each rule checks:
#' \itemize{
#'   \item \code{ruleinset()}: each value, compared as text, is one of
#'     \code{set} (so \code{1} and \code{"1"} match). Name
#'     \code{"<column>_in_set"}.
#'   \item \code{rulebtw()}: each value lies in \code{[lo, hi]}, ends
#'     included. Name \code{"<column>_between"}.
#'   \item \code{rulenull()}: no value is \code{NA}. Name
#'     \code{"<column>_not_null"}.
#'   \item \code{ruleuniq()}: no value repeats an earlier one; the rows
#'     reported are the repeats, not the first occurrence. Two \code{NA}s count
#'     as a repeat. Name \code{"<column>_unique"}.
#'   \item \code{rulerx()}: each value, as text, matches \code{pattern}
#'     (an extended regular expression, \code{grepl()}). Name
#'     \code{"<column>_regex"}.
#'   \item \code{ruleincr()}: the column never decreases from one row to
#'     the next (or always increases, with \code{strictly = TRUE}); missing
#'     steps are skipped. A whole-column check: a failure names no rows. Name
#'     \code{"<column>_increasing"}.
#'   \item \code{rulemad()}: each value lies within \code{n}
#'     median absolute deviations (scaled by 1.4826, so comparable to standard
#'     deviations for normal data) of the column's median. When the MAD is zero
#'     (more than half the values equal) any value other than the median fails.
#'     The column must be numeric when the rule is evaluated. Name
#'     \code{"<column>_within_mads"}.
#'   \item \code{rulecmpl()}: no row has a missing value. Name
#'     \code{"complete_rows"}.
#'   \item \code{ruledstn()}: no row repeats an earlier one on
#'     \code{cols} (columns not in the data are ignored; when none is
#'     present the rule passes). Name \code{"distinct_rows"}.
#'   \item \code{rulecolcnt()}: the data have exactly \code{n} columns.
#'     Name \code{"col_count"}.
#' }
#' The name is the key of the rule's entry in the list
#' [valrules()] returns, which holds only the rules
#' that failed (with
#' \code{sev}, \code{message}, and for row-wise rules \code{n_failed}
#' and \code{rows}). A rule that cannot be evaluated (a missing column, text
#' in a numeric rule) is reported as failed, with the reason in its message.
#'
#' Errors, at construction: \code{col} not a single non-empty string;
#' \code{sev} other than \code{"warning"} or \code{"fatal"};
#' \code{rulebtw()} with \code{lo > hi} or a missing bound;
#' \code{rulemad()} with \code{n} not positive;
#' \code{rulecolcnt()} with \code{n} not a non-negative whole number.
#'
#' `NA` handling is explicit and per-rule, because the right answer
#' differs. `rulenull()` exists precisely to fail on `NA`.
#' The value rules ( `ruleinset`, `rulebtw`,
#' `rulerx`, `rulemad`) treat `NA` as PASSING
#' by default, so that a column's missingness is reported once by
#' `rulenull()` or `max_missing_fraction` rather than again
#' by every other rule; set `napass = FALSE` to make them fail on it
#' instead.
#'
#' @param col Character scalar, the name of the column the rule applies
#'   to.
#' @param set Vector of allowed values (\code{ruleinset()}); compared as
#'   text.
#' @param lo,hi Numeric scalars, the inclusive bounds (\code{rulebtw()});
#'   \code{lo} must not exceed \code{hi}.
#' @param pat Character scalar, the regular expression the values must
#'   match (\code{rulerx()}); only the first element is used.
#' @param n Numeric scalar: the multiplier for \code{rulemad()}
#'   (default \code{3}), or the expected number of columns for
#'   \code{rulecolcnt()} (a whole number, no default).
#' @param cols Character vector of columns that jointly must be unique
#'   (\code{ruledstn()}), or \code{NULL} (the default) for all of
#'   them.
#' @param strict Logical scalar, default \code{FALSE}: require a strict
#'   increase rather than non-decreasing (\code{ruleincr()}).
#' @param napass Logical scalar, default \code{TRUE}: treat \code{NA} as
#'   passing (see above); \code{FALSE} makes a missing value fail.
#' @param sev \code{"warning"} (the default) or \code{"fatal"}: how
#'   [valrules()] and the capsule gate treat a
#'   failure.
#' @return A [rul()] object: a list of class
#'   \code{c("bricklayer_rule", "list")} with
#'   \code{name}, \code{expr} (the predicate function), \code{column}
#'   (\code{NULL} for whole-table rules), \code{severity} and
#'   \code{message}.
#' @seealso
#' [rul()] for an arbitrary predicate,
#' [valrules()] to evaluate them,
#' [infsch()] for the structural checks
#' that need no rules at all.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' df <- data.frame(
#'   id = c(1, 2, 2),
#'   grade = c("a", "b", "z"),
#'   score = c(5, 200, 7),
#'   email = c("a@b.com", "nope", "c@d.org"),
#'   day = c(3, 1, 2),
#'   stringsAsFactors = FALSE
#' )
#'
#' rules <- list(
#'   ruleuniq("id", sev = "fatal"),
#'   ruleinset("grade", c("a", "b", "c")),
#'   rulebtw("score", 0, 100),
#'   rulerx("email", "^[^@]+@[^@]+\\\\.[a-z]+$"),
#'   ruleincr("day")
#' )
#' names(valrules(df, rules))
#'
#' # Each names the rows that failed.
#' valrules(df, rules)$grade_in_set$rows
#'
#' # Clean data passes every one of them.
#' ok <- data.frame(
#'   id = 1:3,
#'   grade = c("a", "b", "c"),
#'   score = c(5, 50, 7),
#'   email = c("a@b.com", "c@d.org", "e@f.net"),
#'   day = 1:3,
#'   stringsAsFactors = FALSE
#' )
#' length(valrules(ok, rules))
#'
#' # A robust outlier rule: MADs from the median, not standard
#' # deviations from the mean, so one wild value cannot hide the others.
#' valrules(
#'   data.frame(v = c(1, 2, 3, 2, 1, 900)),
#'   rulemad("v", 5)
#' )$v_within_mads$rows
#'
#' # Whole-table rules.
#' valrules(df, ruledstn())
#' valrules(df, rulecolcnt(5))
#' valrules(df, rulecmpl())
#'
#' # NA fails only when asked to
#' g <- data.frame(grade = c("a", NA, "b"))
#' length(valrules(g, ruleinset("grade", c("a", "b"))))
#' valrules(
#'   g,
#'   ruleinset("grade", c("a", "b"), napass = FALSE)
#' )$grade_in_set$rows
#'
#' # bounds are checked when the rule is made
#' try(rulebtw("score", 100, 0))
#' @name rulelib
#' @export
ruleinset <- function(
  col = NULL,
  set,
  napass = TRUE,
  sev = c("warning", "fatal")
) {
  if (is.null(col)) {
    stop(
      "ruleinset: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  .rmbl_no_fn(set = set)
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  set <- as.character(set)
  rul(
    paste0(col, "_in_set"),
    function(v) {
      ok <- as.character(v) %in% set
      if (isTRUE(napass)) ok | is.na(v) else ok & !is.na(v)
    },
    col = col,
    sev = sev,
    msg = sprintf(
      "Column '%s' has values outside the allowed set",
      col
    )
  )
}

#' @rdname rulelib
#' @export
rulebtw <- function(
  col = NULL,
  lo,
  hi,
  napass = TRUE,
  sev = c("warning", "fatal")
) {
  if (is.null(col)) {
    stop(
      "rulebtw: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  lo <- .rule_one(lo, "lo")
  hi <- .rule_one(hi, "hi")
  if (is.na(lo) || is.na(hi) || lo > hi) {
    stop("need `lo` <= `hi`, both non-missing", call. = FALSE)
  }
  rul(
    paste0(col, "_between"),
    function(v) {
      ok <- v >= lo & v <= hi
      if (isTRUE(napass)) ok | is.na(v) else ok & !is.na(v)
    },
    col = col,
    sev = sev,
    msg = sprintf(
      "Column '%s' has values outside [%s, %s]",
      col,
      format(lo),
      format(hi)
    )
  )
}

#' @rdname rulelib
#' @export
rulenull <- function(col = NULL, sev = c("warning", "fatal")) {
  if (is.null(col)) {
    stop(
      "rulenull: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  rul(
    paste0(col, "_not_null"),
    function(v) !is.na(v),
    col = col,
    sev = sev,
    msg = sprintf("Column '%s' has missing values", col)
  )
}

#' @rdname rulelib
#' @export
ruleuniq <- function(col = NULL, sev = c("warning", "fatal")) {
  if (is.null(col)) {
    stop(
      "ruleuniq: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  rul(
    paste0(col, "_unique"),
    # duplicated() marks every occurrence after the first, so the
    # reported rows are the repeats rather than all of them
    function(v) !duplicated(v),
    col = col,
    sev = sev,
    msg = sprintf("Column '%s' has duplicate values", col)
  )
}

#' @rdname rulelib
#' @export
rulerx <- function(
  col = NULL,
  pat,
  napass = TRUE,
  sev = c("warning", "fatal")
) {
  if (is.null(col)) {
    stop(
      "rulerx: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  .rmbl_no_fn(pat = pat)
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  pat <- as.character(pat)[1L]
  rul(
    paste0(col, "_regex"),
    function(v) {
      ok <- grepl(pat, as.character(v))
      if (isTRUE(napass)) ok | is.na(v) else ok & !is.na(v)
    },
    col = col,
    sev = sev,
    msg = sprintf(
      "Column '%s' has values not matching /%s/",
      col,
      pat
    )
  )
}

#' @rdname rulelib
#' @export
ruleincr <- function(col = NULL, strict = FALSE, sev = c("warning", "fatal")) {
  if (is.null(col)) {
    stop(
      "ruleincr: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  rul(
    paste0(col, "_increasing"),
    function(v) {
      d <- diff(as.numeric(v))
      ok <- if (isTRUE(strict)) {
        all(d > 0, na.rm = TRUE)
      } else {
        all(d >= 0, na.rm = TRUE)
      }
      isTRUE(ok)
    },
    col = col,
    sev = sev,
    msg = sprintf(
      "Column '%s' is not %s",
      col,
      if (isTRUE(strict)) {
        "strictly increasing"
      } else {
        "non-decreasing"
      }
    )
  )
}

#' @rdname rulelib
#' @export
rulemad <- function(
  col = NULL,
  n = 3,
  napass = TRUE,
  sev = c("warning", "fatal")
) {
  if (is.null(col)) {
    stop(
      "rulemad: `col` must name a column: a single non-empty string",
      call. = FALSE
    )
  }
  col <- .rmbl_string1(col, "col")
  sev <- .rmbl_arg(sev)
  n <- .rule_one(n, "n")
  if (is.na(n) || n <= 0) {
    stop("`n` must be positive", call. = FALSE)
  }
  rul(
    paste0(col, "_within_mads"),
    function(v) {
      v <- .rmbl_num(v, "v")
      ok_idx <- !is.na(v)
      if (!any(ok_idx)) {
        return(rep(TRUE, length(v)))
      }
      med <- cmed(v[ok_idx])
      mad <- cmad(v[ok_idx])
      # A zero MAD means over half the values are identical; any
      # departure at all is then an outlier, and dividing by it would
      # be an error rather than an answer.
      ok <- if (mad > 0) abs(v - med) <= n * mad else v == med
      if (isTRUE(napass)) ok | is.na(v) else ok & !is.na(v)
    },
    col = col,
    sev = sev,
    msg = sprintf(
      "Column '%s' has values more than %s MADs from its median",
      col,
      format(n)
    )
  )
}

#' @rdname rulelib
#' @export
rulecmpl <- function(sev = c("warning", "fatal")) {
  sev <- .rmbl_arg(sev)
  rul(
    "complete_rows",
    function(d) stats::complete.cases(d),
    sev = sev,
    msg = "Some rows have missing values"
  )
}

#' @rdname rulelib
#' @export
ruledstn <- function(cols = NULL, sev = c("warning", "fatal")) {
  sev <- .rmbl_arg(sev)
  .rmbl_no_fn(cols = cols)
  # NA, 1 or list() built a rule that passed every data frame
  ok <- is.null(cols) ||
    (is.character(cols) && length(cols) && !anyNA(cols) && all(nzchar(cols)))
  if (!ok) {
    stop(
      .rmbl_fn(),
      "`cols` must be NULL or a character vector of column names",
      call. = FALSE
    )
  }
  rul(
    "distinct_rows",
    function(d) {
      sub <- if (is.null(cols)) {
        d
      } else {
        have <- intersect(cols, names(d))
        if (length(have) == 0L) {
          return(TRUE)
        }
        d[, have, drop = FALSE]
      }
      !duplicated(sub)
    },
    sev = sev,
    msg = if (is.null(cols)) {
      "Some rows are duplicated"
    } else {
      sprintf(
        "Some rows are duplicated on (%s)",
        toString(cols)
      )
    }
  )
}

#' @rdname rulelib
#' @export
rulecolcnt <- function(n, sev = c("warning", "fatal")) {
  sev <- .rmbl_arg(sev)
  n <- .rule_one(n, "n", integer = TRUE)
  if (is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer", call. = FALSE)
  }
  rul(
    "col_count",
    function(d) ncol(d) == n,
    sev = sev,
    msg = sprintf("Expected %d columns", n)
  )
}

#' Duplicated rows, with their groups
#'
#' Returns the rows that share a combination of `cols` with at
#' least one other row, grouped so the duplicates sit together. The
#' counterpart of `janitor::get_dupes()`.
#'
#' `ruledstn()` tells you THAT there are duplicates, which
#' is what a validation gate needs. This shows you WHICH, which is what
#' fixing them needs -- and a duplicate is usually a join that fanned out
#' or a re-release appended rather than replaced, both of which are visible
#' only once the offending rows are in front of you.
#'
#' Two rows are duplicates when their values, converted to text, are equal
#' in every column of \code{cols}; two \code{NA}s are equal. Columns are
#' taken by position when \code{cols = NULL}, so a table with repeated
#' column names can still be inspected. Errors when \code{data} is not a data
#' frame, a named column does not exist, or a named column's name is shared
#' by two columns.
#'
#' @param data A data frame whose rows are checked for duplicates.
#' @param cols Character vector of the columns defining a duplicate, or
#' \code{NULL} (the default) for all of them.
#' @param quiet Logical: \code{TRUE} skips the boxed count of duplicate rows
#'   and groups, which is otherwise sent through \code{message()}; default
#'   \code{FALSE}.
#' @return A data frame: the duplicated rows (every occurrence, including the
#' first), ordered so each group sits together, with an integer
#' \code{dupe_count} column giving each group's size and row names reset.
#' Zero rows (with the same columns) when there are none.
#' @seealso
#' [ruledstn()],
#' [ruleuniq()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' df <- data.frame(
#'   id = c(1, 2, 2, 3, 3, 3),
#'   value = c("a", "b", "b", "c", "d", "c"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Duplicated on every column.
#' duprows(df)
#'
#' # Duplicated on the identifier alone, which catches more.
#' duprows(df, "id")
#'
#' # No duplicates gives zero rows, not an error.
#' duprows(data.frame(x = 1:3))
#'
#' # a column that does not exist is an error
#' try(duprows(df, "code"))
#' @export
duprows <- function(data, cols = NULL, quiet = FALSE) {
  if (!is.data.frame(data)) {
    stop("duprows: `data` must be a data frame", call. = FALSE)
  }
  quiet <- .rmbl_flag1(quiet, "quiet")
  out <- .rmbl_duprows(data, cols)
  if (!quiet) {
    .rmbl_note_box(.rmbl_dup_box(data, out, cols))
  }
  out
}

#' Missingness in one line per question
#'
#' The scalar summaries of missingness: how much of the table is missing,
#' how many rows are complete, and how many columns have any or only missing
#' values. Use it as a first look at a new extract, or to report data
#' completeness in a methods section;
#' [misspat()] then shows which
#' columns are missing together.
#'
#' @details
#' A cell is missing when \code{is.na()} is \code{TRUE} (so \code{NaN}
#' counts, and an empty string does not). A row is complete when no cell in it
#' is missing (\code{stats::complete.cases()}). Percentages are of all cells
#' and of all rows. A table with no rows gives zeros. Columns are taken by
#' position, so duplicate or empty column names are fine. Errors when
#' \code{data} is not a data frame or has no columns.
#'
#' @param data A data frame with at least one column.
#' @return A named numeric vector: \code{nrows}, \code{n_cols},
#' \code{n_missing} (missing cells), \code{pct_missing} (percent of cells),
#' \code{n_complete_rows}, \code{pct_complete_rows} (percent of rows),
#' \code{n_cols_any_missing} (columns with at least one missing value) and
#' \code{n_cols_all_missing} (columns with no value at all).
#' @seealso
#' [misspat()] for which
#' columns are missing together,
#' [profcols()] for per-column rates.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
#' misssmry(df)
#'
#' # A complete table is all zeros but for its dimensions.
#' misssmry(data.frame(x = 1:3, y = 4:6))
#'
#' # a wholly empty column
#' ms <- misssmry(data.frame(x = 1:4, note = NA))
#' ms[c("pct_missing", "n_cols_all_missing")]
#'
#' # a vector is not a table
#' try(misssmry(c(1, NA, 3)))
#' @export
misssmry <- function(data) {
  if (!is.data.frame(data)) {
    stop("misssmry: `data` must be a data frame", call. = FALSE)
  }
  # every column by position: duplicate or empty names are the messy data this
  # summarises
  if (ncol(data) == 0L) {
    stop("misssmry: `data` has no columns", call. = FALSE)
  }
  n <- nrow(data)
  per_col <- vapply(data, function(v) sum(is.na(v)), numeric(1))
  total <- sum(per_col)
  cells <- max(1L, n * ncol(data))
  complete <- if (n == 0L) 0L else sum(stats::complete.cases(data))
  c(
    n_rows = n,
    n_cols = ncol(data),
    n_missing = total,
    pct_missing = 100 * total / cells,
    n_complete_rows = complete,
    pct_complete_rows = if (n == 0L) 0 else 100 * complete / n,
    n_cols_any_missing = sum(per_col > 0),
    n_cols_all_missing = sum(per_col == n & n > 0)
  )
}

#' The positions of the columns duprows() compares, checked.
#' @param data,cols As for duprows().
#' @return Column positions.
#' @noRd
.rmbl_dup_pos <- function(data, cols) {
  if (is.null(cols)) {
    return(seq_along(data))
  }
  .rmbl_no_fn(cols = cols)
  .cols <- as.character(cols)
  missing_cols <- setdiff(.cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(
      sprintf(
        "no such column(s): %s",
        toString(missing_cols)
      ),
      call. = FALSE
    )
  }
  twice <- .cols[.cols %in% names(data)[duplicated(names(data))]]
  if (length(twice)) {
    stop(
      sprintf(
        paste0(
          "`data` has two columns named %s: give the columns by ",
          "position, or rename one"
        ),
        twice[[1L]]
      ),
      call. = FALSE
    )
  }
  match(.cols, names(data))
}

#' One number for a rule's bound: a vector was cut to its first element.
#' @param v The value passed by the user.
#' @param what The user's argument name, for the error.
#' @param integer Whether the number must be whole.
#' @return The number, NA when it is missing.
#' @noRd
.rule_one <- function(v, what, integer = FALSE) {
  v <- .rmbl_num(v, what, integer = integer)
  if (length(v) != 1L) {
    stop(.rmbl_fn(), sprintf("`%s` must be one number", what), call. = FALSE)
  }
  v
}

#' duprows()'s search, without its summary.
#' @param data,cols As for duprows().
#' @return The duplicated rows, with `dupe_count`.
#' @noRd
.rmbl_duprows <- function(data, cols) {
  # duplicate column names are messy data, which this exists to inspect: every
  # column by position, a column given by name only when the name is one
  # column's (statistics stress test of 5e1dce5)
  if (nrow(data) == 0L) {
    out <- cbind(data, dupe_count = integer(0))
    return(out)
  }
  pos <- .rmbl_dup_pos(data, cols)
  key <- do.call(
    paste,
    c(
      lapply(pos, function(i) {
        as.character(data[[i]])
      }),
      sep = "\r"
    )
  )
  counts <- table(key)
  dupe_keys <- names(counts)[counts > 1L]
  if (length(dupe_keys) == 0L) {
    return(cbind(data[0L, , drop = FALSE], dupe_count = integer(0)))
  }
  keep <- key %in% dupe_keys
  out <- data[keep, , drop = FALSE]
  out$dupe_count <- as.integer(counts[key[keep]])
  out <- out[order(key[keep]), , drop = FALSE]
  rownames(out) <- NULL
  out
}
