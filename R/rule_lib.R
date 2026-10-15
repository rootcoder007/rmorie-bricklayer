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
#' [rule()] that
#' [validate_rules()] evaluates. Use
#' [rule()] directly for anything not covered here. Writing the common
#' checks once, here, avoids the off-by-one or the forgotten \code{NA} that
#' makes a hand-written rule pass silently, and gives every failure a
#' readable message and the rows that failed.
#'
#' @details
#' What each rule checks:
#' \itemize{
#'   \item \code{rule_in_set()}: each value, compared as text, is one of
#'     \code{set} (so \code{1} and \code{"1"} match). Name
#'     \code{"<column>_in_set"}.
#'   \item \code{rule_between()}: each value lies in \code{[lo, hi]}, ends
#'     included. Name \code{"<column>_between"}.
#'   \item \code{rule_not_null()}: no value is \code{NA}. Name
#'     \code{"<column>_not_null"}.
#'   \item \code{rule_unique()}: no value repeats an earlier one; the rows
#'     reported are the repeats, not the first occurrence. Two \code{NA}s count
#'     as a repeat. Name \code{"<column>_unique"}.
#'   \item \code{rule_regex()}: each value, as text, matches \code{pattern}
#'     (an extended regular expression, \code{grepl()}). Name
#'     \code{"<column>_regex"}.
#'   \item \code{rule_increasing()}: the column never decreases from one row to
#'     the next (or always increases, with \code{strictly = TRUE}); missing
#'     steps are skipped. A whole-column check: a failure names no rows. Name
#'     \code{"<column>_increasing"}.
#'   \item \code{rule_within_n_mads()}: each value lies within \code{n}
#'     median absolute deviations (scaled by 1.4826, so comparable to standard
#'     deviations for normal data) of the column's median. When the MAD is zero
#'     (more than half the values equal) any value other than the median fails.
#'     The column must be numeric when the rule is evaluated. Name
#'     \code{"<column>_within_mads"}.
#'   \item \code{rule_complete_rows()}: no row has a missing value. Name
#'     \code{"complete_rows"}.
#'   \item \code{rule_distinct_rows()}: no row repeats an earlier one on
#'     \code{columns} (columns not in the data are ignored; when none is
#'     present the rule passes). Name \code{"distinct_rows"}.
#'   \item \code{rule_col_count()}: the data have exactly \code{n} columns.
#'     Name \code{"col_count"}.
#' }
#' The name is the key of the rule's entry in the list
#' [validate_rules()] returns, which holds only the rules
#' that failed (with
#' \code{severity}, \code{message}, and for row-wise rules \code{n_failed}
#' and \code{rows}). A rule that cannot be evaluated (a missing column, text
#' in a numeric rule) is reported as failed, with the reason in its message.
#'
#' Errors, at construction: \code{column} not a single non-empty string;
#' \code{severity} other than \code{"warning"} or \code{"fatal"};
#' \code{rule_between()} with \code{lo > hi} or a missing bound;
#' \code{rule_within_n_mads()} with \code{n} not positive;
#' \code{rule_col_count()} with \code{n} not a non-negative whole number.
#'
#' `NA` handling is explicit and per-rule, because the right answer
#' differs. `rule_not_null()` exists precisely to fail on `NA`.
#' The value rules ( `rule_in_set`, `rule_between`,
#' `rule_regex`, `rule_within_n_mads`) treat `NA` as PASSING
#' by default, so that a column's missingness is reported once by
#' `rule_not_null()` or `max_missing_fraction` rather than again
#' by every other rule; set `na_pass = FALSE` to make them fail on it
#' instead.
#'
#' @param column Character scalar, the name of the column the rule applies
#'   to.
#' @param set Vector of allowed values (\code{rule_in_set()}); compared as
#'   text.
#' @param lo,hi Numeric scalars, the inclusive bounds (\code{rule_between()});
#'   \code{lo} must not exceed \code{hi}.
#' @param pattern Character scalar, the regular expression the values must
#'   match (\code{rule_regex()}); only the first element is used.
#' @param n Numeric scalar: the multiplier for \code{rule_within_n_mads()}
#'   (default \code{3}), or the expected number of columns for
#'   \code{rule_col_count()} (a whole number, no default).
#' @param columns Character vector of columns that jointly must be unique
#'   (\code{rule_distinct_rows()}), or \code{NULL} (the default) for all of
#'   them.
#' @param strictly Logical scalar, default \code{FALSE}: require a strict
#'   increase rather than non-decreasing (\code{rule_increasing()}).
#' @param na_pass Logical scalar, default \code{TRUE}: treat \code{NA} as
#'   passing (see above); \code{FALSE} makes a missing value fail.
#' @param severity \code{"warning"} (the default) or \code{"fatal"}: how
#'   [validate_rules()] and the capsule gate treat a
#'   failure.
#' @return A [rule()] object: a list of class
#'   \code{c("bricklayer_rule", "list")} with
#'   \code{name}, \code{expr} (the predicate function), \code{column}
#'   (\code{NULL} for whole-table rules), \code{severity} and
#'   \code{message}.
#' @seealso
#' [rule()] for an arbitrary predicate,
#' [validate_rules()] to evaluate them,
#' [infer_schema()] for the structural checks
#' that need no rules at all.
#' @examples
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
#'   rule_unique("id", severity = "fatal"),
#'   rule_in_set("grade", c("a", "b", "c")),
#'   rule_between("score", 0, 100),
#'   rule_regex("email", "^[^@]+@[^@]+\\\\.[a-z]+$"),
#'   rule_increasing("day")
#' )
#' names(validate_rules(df, rules))
#'
#' # Each names the rows that failed.
#' validate_rules(df, rules)$grade_in_set$rows
#'
#' # Clean data passes every one of them.
#' ok <- data.frame(
#'   id = 1:3, grade = c("a", "b", "c"),
#'   score = c(5, 50, 7),
#'   email = c("a@b.com", "c@d.org", "e@f.net"),
#'   day = 1:3, stringsAsFactors = FALSE
#' )
#' length(validate_rules(ok, rules))
#'
#' # A robust outlier rule: MADs from the median, not standard
#' # deviations from the mean, so one wild value cannot hide the others.
#' validate_rules(
#'   data.frame(v = c(1, 2, 3, 2, 1, 900)),
#'   rule_within_n_mads("v", 5)
#' )$v_within_mads$rows
#'
#' # Whole-table rules.
#' validate_rules(df, rule_distinct_rows())
#' validate_rules(df, rule_col_count(5))
#' validate_rules(df, rule_complete_rows())
#'
#' # NA fails only when asked to
#' g <- data.frame(grade = c("a", NA, "b"))
#' length(validate_rules(g, rule_in_set("grade", c("a", "b"))))
#' validate_rules(g, rule_in_set("grade", c("a", "b"), na_pass = FALSE))$grade_in_set$rows
#'
#' # bounds are checked when the rule is made
#' try(rule_between("score", 100, 0))
#' @name rmbl_rule_library
#' @export
rule_in_set <- function(column, set, na_pass = TRUE,
                        severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  set <- as.character(set)
  rule(paste0(column, "_in_set"),
    function(v) {
      ok <- as.character(v) %in% set
      if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
    },
    column = column, severity = severity,
    message = sprintf(
      "Column '%s' has values outside the allowed set",
      column
    )
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_between <- function(column, lo, hi, na_pass = TRUE,
                         severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  lo <- .rmbl_num(lo, "lo")[1L]
  hi <- .rmbl_num(hi, "hi")[1L]
  if (is.na(lo) || is.na(hi) || lo > hi) {
    stop("need `lo` <= `hi`, both non-missing", call. = FALSE)
  }
  rule(paste0(column, "_between"),
    function(v) {
      ok <- v >= lo & v <= hi
      if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
    },
    column = column, severity = severity,
    message = sprintf(
      "Column '%s' has values outside [%s, %s]",
      column, format(lo), format(hi)
    )
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_not_null <- function(column, severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  rule(paste0(column, "_not_null"), function(v) !is.na(v),
    column = column, severity = severity,
    message = sprintf("Column '%s' has missing values", column)
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_unique <- function(column, severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  rule(paste0(column, "_unique"),
    # duplicated() marks every occurrence after the first, so the
    # reported rows are the repeats rather than all of them
    function(v) !duplicated(v),
    column = column, severity = severity,
    message = sprintf("Column '%s' has duplicate values", column)
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_regex <- function(column, pattern, na_pass = TRUE,
                       severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  pattern <- as.character(pattern)[1L]
  rule(paste0(column, "_regex"),
    function(v) {
      ok <- grepl(pattern, as.character(v))
      if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
    },
    column = column, severity = severity,
    message = sprintf(
      "Column '%s' has values not matching /%s/",
      column, pattern
    )
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_increasing <- function(column, strictly = FALSE,
                            severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  rule(paste0(column, "_increasing"),
    function(v) {
      d <- diff(as.numeric(v))
      ok <- if (isTRUE(strictly)) {
        all(d > 0, na.rm = TRUE)
      } else {
        all(d >= 0, na.rm = TRUE)
      }
      isTRUE(ok)
    },
    column = column, severity = severity,
    message = sprintf(
      "Column '%s' is not %s", column,
      if (isTRUE(strictly)) {
        "strictly increasing"
      } else {
        "non-decreasing"
      }
    )
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_within_n_mads <- function(column, n = 3, na_pass = TRUE,
                               severity = c("warning", "fatal")) {
  column <- .rmbl_string1(column, "column")
  severity <- .rmbl_arg(severity)
  n <- .rmbl_num(n, "n")[1L]
  if (is.na(n) || n <= 0) stop("`n` must be positive", call. = FALSE)
  rule(paste0(column, "_within_mads"),
    function(v) {
      v <- .rmbl_num(v, "v")
      ok_idx <- !is.na(v)
      if (!any(ok_idx)) {
        return(rep(TRUE, length(v)))
      }
      med <- core_median(v[ok_idx])
      mad <- core_mad(v[ok_idx])
      # A zero MAD means over half the values are identical; any
      # departure at all is then an outlier, and dividing by it would
      # be an error rather than an answer.
      ok <- if (mad > 0) abs(v - med) <= n * mad else v == med
      if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
    },
    column = column, severity = severity,
    message = sprintf(
      "Column '%s' has values more than %s MADs from its median",
      column, format(n)
    )
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_complete_rows <- function(severity = c("warning", "fatal")) {
  severity <- .rmbl_arg(severity)
  rule("complete_rows",
    function(d) stats::complete.cases(d),
    severity = severity,
    message = "Some rows have missing values"
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_distinct_rows <- function(columns = NULL,
                               severity = c("warning", "fatal")) {
  severity <- .rmbl_arg(severity)
  rule("distinct_rows",
    function(d) {
      sub <- if (is.null(columns)) {
        d
      } else {
        have <- intersect(columns, names(d))
        if (length(have) == 0L) {
          return(TRUE)
        }
        d[, have, drop = FALSE]
      }
      !duplicated(sub)
    },
    severity = severity,
    message = if (is.null(columns)) {
      "Some rows are duplicated"
    } else {
      sprintf(
        "Some rows are duplicated on (%s)",
        paste(columns, collapse = ", ")
      )
    }
  )
}

#' @rdname rmbl_rule_library
#' @export
rule_col_count <- function(n, severity = c("warning", "fatal")) {
  severity <- .rmbl_arg(severity)
  n <- .rmbl_num(n, "n", integer = TRUE)[1L]
  if (is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer", call. = FALSE)
  }
  rule("col_count",
    function(d) ncol(d) == n,
    severity = severity,
    message = sprintf("Expected %d columns", n)
  )
}

#' Duplicated rows, with their groups
#'
#' Returns the rows that share a combination of `columns` with at
#' least one other row, grouped so the duplicates sit together. The
#' counterpart of `janitor::get_dupes()`.
#'
#' `rule_distinct_rows()` tells you THAT there are duplicates, which
#' is what a validation gate needs. This shows you WHICH, which is what
#' fixing them needs -- and a duplicate is usually a join that fanned out
#' or a re-release appended rather than replaced, both of which are visible
#' only once the offending rows are in front of you.
#'
#' Two rows are duplicates when their values, converted to text, are equal
#' in every column of \code{columns}; two \code{NA}s are equal. Columns are
#' taken by position when \code{columns = NULL}, so a table with repeated
#' column names can still be inspected. Errors when \code{data} is not a data
#' frame, a named column does not exist, or a named column's name is shared
#' by two columns.
#'
#' @param data A data frame.
#' @param columns Character vector of the columns defining a duplicate, or
#' \code{NULL} (the default) for all of them.
#' @return A data frame: the duplicated rows (every occurrence, including the
#' first), ordered so each group sits together, with an integer
#' \code{dupe_count} column giving each group's size and row names reset.
#' Zero rows (with the same columns) when there are none.
#' @seealso
#' [rule_distinct_rows()],
#' [rule_unique()]
#' @examples
#' df <- data.frame(
#'   id = c(1, 2, 2, 3, 3, 3),
#'   value = c("a", "b", "b", "c", "d", "c"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # Duplicated on every column.
#' duplicate_rows(df)
#'
#' # Duplicated on the identifier alone, which catches more.
#' duplicate_rows(df, "id")
#'
#' # No duplicates gives zero rows, not an error.
#' duplicate_rows(data.frame(x = 1:3))
#'
#' # a column that does not exist is an error
#' try(duplicate_rows(df, "code"))
#' @export
duplicate_rows <- function(data, columns = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  # duplicate column names are messy data, which this exists to inspect: every column by position,
  # a column given by name only when the name is one column's (statistics stress test of 5e1dce5)
  if (nrow(data) == 0L) {
    out <- cbind(data, dupe_count = integer(0))
    return(out)
  }
  if (is.null(columns)) {
    pos <- seq_along(data)
  } else {
    cols <- as.character(columns)
    missing_cols <- setdiff(cols, names(data))
    if (length(missing_cols) > 0L) {
      stop(sprintf(
        "no such column(s): %s",
        paste(missing_cols, collapse = ", ")
      ), call. = FALSE)
    }
    twice <- cols[cols %in% names(data)[duplicated(names(data))]]
    if (length(twice)) {
      stop(sprintf("`data` has two columns named %s: give the columns by position, or rename one", twice[[1L]]),
           call. = FALSE)
    }
    pos <- match(cols, names(data))
  }
  key <- do.call(paste, c(lapply(pos, function(i) {
    as.character(data[[i]])
  }), sep = "\r"))
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

#' Missingness in one line per question
#'
#' The scalar summaries of missingness: how much of the table is missing,
#' how many rows are complete, and how many columns have any or only missing
#' values. Use it as a first look at a new extract, or to report data
#' completeness in a methods section;
#' [missingness_pattern()] then shows which
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
#' @return A named numeric vector: \code{n_rows}, \code{n_cols},
#' \code{n_missing} (missing cells), \code{pct_missing} (percent of cells),
#' \code{n_complete_rows}, \code{pct_complete_rows} (percent of rows),
#' \code{n_cols_any_missing} (columns with at least one missing value) and
#' \code{n_cols_all_missing} (columns with no value at all).
#' @seealso
#' [missingness_pattern()] for which
#' columns are missing together,
#' [profile_columns()] for per-column rates.
#' @examples
#' df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
#' missingness_summary(df)
#'
#' # A complete table is all zeros but for its dimensions.
#' missingness_summary(data.frame(x = 1:3, y = 4:6))
#'
#' # a wholly empty column
#' ms <- missingness_summary(data.frame(x = 1:4, note = NA))
#' ms[c("pct_missing", "n_cols_all_missing")]
#'
#' # a vector is not a table
#' try(missingness_summary(c(1, NA, 3)))
#' @export
missingness_summary <- function(data) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  # every column by position: duplicate or empty names are the messy data this summarises
  if (ncol(data) == 0L) stop("`data` has no columns", call. = FALSE)
  n <- nrow(data)
  per_col <- vapply(data, function(v) sum(is.na(v)), numeric(1))
  total <- sum(per_col)
  cells <- max(1L, n * ncol(data))
  complete <- if (n == 0L) 0L else sum(stats::complete.cases(data))
  c(
    n_rows = n, n_cols = ncol(data), n_missing = total,
    pct_missing = 100 * total / cells,
    n_complete_rows = complete,
    pct_complete_rows = if (n == 0L) 0 else 100 * complete / n,
    n_cols_any_missing = sum(per_col > 0),
    n_cols_all_missing = sum(per_col == n & n > 0)
  )
}
