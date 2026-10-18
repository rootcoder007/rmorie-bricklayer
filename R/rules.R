# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Declarative column rules. valsch() checks the things every
# table has -- names, types, bounds, levels, missingness. It cannot know
# that an age must be non-negative, that two dates must be ordered, or
# that an identifier must be unique. Those are the caller's rules, so the
# caller supplies them.

#' Declare a validation rule
#'
#' Builds a rule for [valrules()]: a predicate over
#' one column, or over
#' the whole data frame, with a severity and a message. Use rules for the
#' checks that are particular to a data set and that a schema cannot express:
#' an age must be non-negative, an identifier must be unique, a release date
#' must not precede an admission date. Rules live alongside a schema in a
#' provenance record, which keeps the project-specific checks in data rather
#' than scattered through code.
#'
#' @details
#' \code{expr} is a function. Given \code{col}, it receives that column
#' and must return a logical vector the same length (\code{TRUE} = the row
#' passes) or a single logical for a whole-column property. Given no
#' \code{col}, it receives the whole data frame and must return a single
#' logical. How the result is read is described in
#' [valrules()].
#'
#' Only the first element of \code{name}, \code{col} and \code{msg} is
#' kept. The rule is not run here. Errors: an empty or \code{NA} \code{name};
#' \code{expr} not a function; an empty or \code{NA} \code{col}; a
#' \code{sev} other than \code{"warning"} or \code{"fatal"}.
#'
#' @param name Short identifier for the rule, a string; it names the issue
#'   in the result of [valrules()], so give each rule
#'   a different name.
#' @param expr A function, as described above.
#' @param col Name of the column the rule applies to, or \code{NULL} (the
#'   default) for a table-level rule.
#' @param sev \code{"warning"} (default) or \code{"fatal"}. A fatal
#'   failure stops [schval()].
#' @param msg Human-readable description of what a failure means, a
#'   string. Defaults to \code{"Rule '<name>' failed"}.
#' @return A list of class \code{c("bricklayer_rule", "list")} with
#'   \code{name}, \code{expr}, \code{column} (\code{NULL} for a table rule),
#'   \code{severity} and \code{message}; it prints as one line.
#' @seealso
#' [valrules()],
#' [valsch()] for the structural
#' checks that need no rules.
#' @examples
#' # A column predicate, applied row-wise.
#' rul("agenonnegative", function(v) v >= 0, col = "age")
#'
#' # A whole-column property.
#' rul("idunique", function(v) !anyDuplicated(v), col = "id",
#'      sev = "fatal")
#'
#' # A table-level rule spanning two columns.
#' rul("datesordered", function(df) all(df$start <= df$end))
#'
#' # with a message that says what a failure means
#' r <- rul("releaseafteradmission",
#'           function(d) all(d$release >= d$admission, na.rm = TRUE),
#'           msg = "a release date precedes its admission date")
#' r$message
#'
#' # the predicate must be a function, not an expression
#' try(rul("agenonnegative", "age >= 0", col = "age"))
#' @export
rul <- function(name, expr, col = NULL, sev = c("warning", "fatal"),
                 msg = NULL) {
  .rmbl_no_fn(name = name, column = col, message = msg)
  sev <- .rmbl_arg(sev)
  name <- as.character(name)[1L]
  if (is.na(name) || !nzchar(name)) {
    stop("`name` must be a non-empty string", call. = FALSE)
  }
  if (!is.function(expr)) {
    stop("`expr` must be a function", call. = FALSE)
  }
  if (!is.null(col)) {
    col <- as.character(col)[1L]
    if (is.na(col) || !nzchar(col)) {
      stop("`col` must be a non-empty string or NULL", call. = FALSE)
    }
  }
  out <- list(name = name, expr = expr, column = col,
              severity = sev,
              message = if (is.null(msg)) {
                sprintf("Rule '%s' failed", name)
              } else {
                as.character(msg)[1L]
              })
  class(out) <- c("bricklayer_rule", "list")
  out
}

#' Apply declared rules to a data frame
#'
#' Evaluates each rule from [rul()] on a data frame and returns the
#' failures in the same shape [valsch()] uses, so
#' the two can be
#' combined and handed to
#' [schval()] together. Use it
#' each
#' time a data set is refreshed, to see which of its own invariants still
#' hold.
#'
#' @details
#' A rule whose column is absent is SKIPPED rather than failed -- a missing
#' column is [valsch()]'s business, and reporting
#' it twice buries
#' the real finding. A rule that ERRORS is reported as a failure naming the
#' error, never swallowed: a rule that cannot run has not passed. On a table
#' of no rows a row-wise rule has no row to fail and passes.
#'
#' How a rule's result is read: a result that is not logical, or has length
#' 0, is a failure (\code{"rule returned <class>, not a logical"}); a single value
#' fails unless it is \code{TRUE} (so \code{NA} fails); a longer vector is
#' read row by row, and rows that are \code{FALSE} or \code{NA} fail (a rule
#' that cannot decide has not been satisfied). The length of a row-wise
#' result is not checked against the number of rows. The issue is named by
#' the rule's \code{name}; two rules with the same name keep only the later
#' failure. Rules run in the order given and only read the data.
#'
#' Errors: \code{data} not a data frame (or with missing or duplicated
#' column names); \code{rules} not a rule or a list; an element that is not
#' a rule.
#'
#' @param data A data frame.
#' @param rules A list of [rul()] objects, or a single rule.
#' @return A named list of issues, one per failed rule, each a list with
#'   \code{severity} (character) and \code{message} (character; for a row-wise
#'   rule it ends with "(k of n rows)"), and for a row-wise rule
#'   \code{n_failed} (integer) and \code{rows} (integer, the first ten failing
#'   row indices). Empty when everything passes.
#' @seealso
#' [rul()],
#' [valsch()],
#' [schval()]
#' @examples
#' df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
#'                  start = c(1, 5, 3), end = c(2, 4, 9))
#'
#' rules <- list(
#'   rul("agenonnegative", function(v) v >= 0, col = "age"),
#'   rul("idunique", function(v) !anyDuplicated(v), col = "id",
#'        sev = "fatal"),
#'   rul("datesordered", function(d) all(d$start <= d$end))
#' )
#'
#' issues <- valrules(df, rules)
#' names(issues)
#'
#' # A row-wise failure reports how many rows and which.
#' issues$agenonnegative$n_failed
#' issues$agenonnegative$rows
#'
#' # Clean data produces nothing.
#' clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
#' length(valrules(clean, rules))
#'
#' # A rule for an absent column is skipped, not failed -- a missing
#' # column is valsch()'s finding to report, not this one's.
#' length(valrules(data.frame(id = 1:3), rules[1:2]))
#'
#' # A rule that errors is a failure, not a silent pass.
#' broken <- list(rul("bad", function(v) stop("boom"), col = "age"))
#' valrules(clean, broken)$bad$message
#'
#' # NA counts as a failure
#' valrules(data.frame(age = c(30, NA)), rules[1])$agenonnegative$message
#'
#' # only rule() objects are accepted
#' try(valrules(df, list(function(v) v >= 0)))
#' @export
valrules <- function(data, rules) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  .rmbl_df_names(data)
  if (inherits(rules, "bricklayer_rule")) rules <- list(rules)
  if (!is.list(rules)) {
    stop("`rules` must be a rul() or a list of them", call. = FALSE)
  }
  issues <- list()
  for (r in rules) {
    if (!inherits(r, "bricklayer_rule")) {
      stop("every element of `rules` must come from rul()", call. = FALSE)
    }
    # A rule for a column that is not here has nothing to say.
    if (!is.null(r$column) && !r$column %in% names(data)) next

    res <- tryCatch(
      if (is.null(r$column)) r$expr(data) else r$expr(data[[r$column]]),
      error = function(e) e)

    if (inherits(res, "error")) {
      issues[[r$name]] <- list(
        severity = r$severity,
        message = sprintf("%s (rule could not be evaluated: %s)",
                          r$message, conditionMessage(res)))
      next
    }
    # a row-wise rule on a table of no rows has no row to fail (every rule failed on a 0-row frame;
    # CRAN stress test of 0.5.14)
    if (is.logical(res) && length(res) == 0L && nrow(data) == 0L) next
    if (!is.logical(res) || length(res) == 0L) {
      issues[[r$name]] <- list(
        severity = r$severity,
        message = sprintf("%s (rule returned %s, not a logical)",
                          r$message, class(res)[1L]))
      next
    }

    if (length(res) == 1L) {
      if (!isTRUE(res)) {
        issues[[r$name]] <- list(severity = r$severity, message = r$message)
      }
      next
    }
    # Row-wise: NA is a failure, because a rule that cannot decide has
    # not been satisfied.
    failed <- which(is.na(res) | !res)
    if (length(failed) > 0L) {
      issues[[r$name]] <- list(
        severity = r$severity,
        message = sprintf("%s (%d of %d rows)", r$message, length(failed),
                          nrow(data)),
        n_failed = length(failed),
        rows = utils::head(failed, 10L))
    }
  }
  issues
}

#' @export
print.bricklayer_rule <- function(x, ...) {
  cat(sprintf("<rule> %s [%s]%s\n", x$name, x$severity,
              if (is.null(x$column)) " table-level" else
                paste0(" on `", x$column, "`")))
  invisible(x)
}
