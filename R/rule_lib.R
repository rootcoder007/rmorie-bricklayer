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
#' [rule()] directly for anything not covered here.
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
#' @param column Column the rule applies to.
#' @param set Allowed values ( `rule_in_set`) .
#' @param lo,hi Inclusive bounds ( `rule_between`) .
#' @param pattern Regular expression the values must match (
#' `rule_regex`) .
#' @param n Multiplier for `rule_within_n_mads`, or the
#' expected count for `rule_col_count`.
#' @param columns Columns that jointly must be unique (
#' `rule_distinct_rows`) , or `NULL` for all of them.
#' @param strictly Require a strict increase rather than
#' non-decreasing ( `rule_increasing`) .
#' @param na_pass Treat `NA` as passing (default
#' `TRUE`; see above).
#' @param severity `"warning"` (default) or
#' `"fatal"`.
#' @return A [rule()] object.
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
#' ok <- data.frame(id = 1:3, grade = c("a", "b", "c"),
#'                  score = c(5, 50, 7),
#'                  email = c("a@b.com", "c@d.org", "e@f.net"),
#'                  day = 1:3, stringsAsFactors = FALSE)
#' length(validate_rules(ok, rules))
#'
#' # A robust outlier rule: MADs from the median, not standard
#' # deviations from the mean, so one wild value cannot hide the others.
#' validate_rules(data.frame(v = c(1, 2, 3, 2, 1, 900)),
#'                rule_within_n_mads("v", 5))$v_within_mads$rows
#'
#' # Whole-table rules.
#' validate_rules(df, rule_distinct_rows())
#' validate_rules(df, rule_col_count(5))
#' validate_rules(df, rule_complete_rows())
#' @name rmbl_rule_library
#' @export
rule_in_set <- function(column, set, na_pass = TRUE,
                        severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  set <- as.character(set)
  rule(paste0(column, "_in_set"),
       function(v) {
         ok <- as.character(v) %in% set
         if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
       },
       column = column, severity = severity,
       message = sprintf("Column '%s' has values outside the allowed set",
                         column))
}

#' @rdname rmbl_rule_library
#' @export
rule_between <- function(column, lo, hi, na_pass = TRUE,
                         severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  lo <- as.numeric(lo)[1L]
  hi <- as.numeric(hi)[1L]
  if (is.na(lo) || is.na(hi) || lo > hi) {
    stop("need `lo` <= `hi`, both non-missing", call. = FALSE)
  }
  rule(paste0(column, "_between"),
       function(v) {
         ok <- v >= lo & v <= hi
         if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
       },
       column = column, severity = severity,
       message = sprintf("Column '%s' has values outside [%s, %s]",
                         column, format(lo), format(hi)))
}

#' @rdname rmbl_rule_library
#' @export
rule_not_null <- function(column, severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  rule(paste0(column, "_not_null"), function(v) !is.na(v),
       column = column, severity = severity,
       message = sprintf("Column '%s' has missing values", column))
}

#' @rdname rmbl_rule_library
#' @export
rule_unique <- function(column, severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  rule(paste0(column, "_unique"),
       # duplicated() marks every occurrence after the first, so the
       # reported rows are the repeats rather than all of them
       function(v) !duplicated(v),
       column = column, severity = severity,
       message = sprintf("Column '%s' has duplicate values", column))
}

#' @rdname rmbl_rule_library
#' @export
rule_regex <- function(column, pattern, na_pass = TRUE,
                       severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  pattern <- as.character(pattern)[1L]
  rule(paste0(column, "_regex"),
       function(v) {
         ok <- grepl(pattern, as.character(v))
         if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
       },
       column = column, severity = severity,
       message = sprintf("Column '%s' has values not matching /%s/",
                         column, pattern))
}

#' @rdname rmbl_rule_library
#' @export
rule_increasing <- function(column, strictly = FALSE,
                            severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  rule(paste0(column, "_increasing"),
       function(v) {
         d <- diff(as.numeric(v))
         ok <- if (isTRUE(strictly)) all(d > 0, na.rm = TRUE) else
           all(d >= 0, na.rm = TRUE)
         isTRUE(ok)
       },
       column = column, severity = severity,
       message = sprintf("Column '%s' is not %s", column,
                         if (isTRUE(strictly)) "strictly increasing" else
                           "non-decreasing"))
}

#' @rdname rmbl_rule_library
#' @export
rule_within_n_mads <- function(column, n = 3, na_pass = TRUE,
                               severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  n <- as.numeric(n)[1L]
  if (is.na(n) || n <= 0) stop("`n` must be positive", call. = FALSE)
  rule(paste0(column, "_within_mads"),
       function(v) {
         v <- as.numeric(v)
         ok_idx <- !is.na(v)
         if (!any(ok_idx)) return(rep(TRUE, length(v)))
         med <- core_median(v[ok_idx])
         mad <- core_mad(v[ok_idx])
         # A zero MAD means over half the values are identical; any
         # departure at all is then an outlier, and dividing by it would
         # be an error rather than an answer.
         ok <- if (mad > 0) abs(v - med) <= n * mad else v == med
         if (isTRUE(na_pass)) ok | is.na(v) else ok & !is.na(v)
       },
       column = column, severity = severity,
       message = sprintf("Column '%s' has values more than %s MADs from its median",
                         column, format(n)))
}

#' @rdname rmbl_rule_library
#' @export
rule_complete_rows <- function(severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  rule("complete_rows",
       function(d) stats::complete.cases(d),
       severity = severity,
       message = "Some rows have missing values")
}

#' @rdname rmbl_rule_library
#' @export
rule_distinct_rows <- function(columns = NULL,
                               severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  rule("distinct_rows",
       function(d) {
         sub <- if (is.null(columns)) d else {
           have <- intersect(columns, names(d))
           if (length(have) == 0L) return(TRUE)
           d[, have, drop = FALSE]
         }
         !duplicated(sub)
       },
       severity = severity,
       message = if (is.null(columns)) "Some rows are duplicated" else
         sprintf("Some rows are duplicated on (%s)",
                 paste(columns, collapse = ", ")))
}

#' @rdname rmbl_rule_library
#' @export
rule_col_count <- function(n, severity = c("warning", "fatal")) {
  severity <- match.arg(severity)
  n <- as.integer(n)[1L]
  if (is.na(n) || n < 0L) {
    stop("`n` must be a non-negative integer", call. = FALSE)
  }
  rule("col_count",
       function(d) ncol(d) == n,
       severity = severity,
       message = sprintf("Expected %d columns", n))
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
#' @param data A data frame.
#' @param columns Columns defining a duplicate (default: all
#' of them).
#' @return The duplicated rows, ordered by group, with a `dupe_count`
#' column giving each group's size. Zero rows when there are none.
#' @seealso
#' [rule_distinct_rows()],
#' [rule_unique()]
#' @examples
#' df <- data.frame(id = c(1, 2, 2, 3, 3, 3),
#'                  value = c("a", "b", "b", "c", "d", "c"),
#'                  stringsAsFactors = FALSE)
#'
#' # Duplicated on every column.
#' duplicate_rows(df)
#'
#' # Duplicated on the identifier alone, which catches more.
#' duplicate_rows(df, "id")
#'
#' # No duplicates gives zero rows, not an error.
#' duplicate_rows(data.frame(x = 1:3))
#' @export
duplicate_rows <- function(data, columns = NULL) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (nrow(data) == 0L) {
    out <- cbind(data, dupe_count = integer(0))
    return(out)
  }
  cols <- if (is.null(columns)) names(data) else as.character(columns)
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols) > 0L) {
    stop(sprintf("no such column(s): %s",
                 paste(missing_cols, collapse = ", ")), call. = FALSE)
  }
  key <- do.call(paste, c(lapply(cols, function(cn) {
    as.character(data[[cn]])
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
#' how many rows are complete, and how many columns are wholly present.
#'
#' @param data A data frame.
#' @return A named numeric vector: `n_rows`, `n_cols`,
#' `n_missing`, `pct_missing`, `n_complete_rows`,
#' `pct_complete_rows`, `n_cols_any_missing`,
#' `n_cols_all_missing`.
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
#' @export
missingness_summary <- function(data) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (ncol(data) == 0L) stop("`data` has no columns", call. = FALSE)
  n <- nrow(data)
  per_col <- vapply(data, function(v) sum(is.na(v)), numeric(1))
  total <- sum(per_col)
  cells <- max(1L, n * ncol(data))
  complete <- if (n == 0L) 0L else sum(stats::complete.cases(data))
  c(n_rows = n, n_cols = ncol(data), n_missing = total,
    pct_missing = 100 * total / cells,
    n_complete_rows = complete,
    pct_complete_rows = if (n == 0L) 0 else 100 * complete / n,
    n_cols_any_missing = sum(per_col > 0),
    n_cols_all_missing = sum(per_col == n & n > 0))
}
