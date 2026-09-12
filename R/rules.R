# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Declarative column rules. validate_schema() checks the things every
# table has -- names, types, bounds, levels, missingness. It cannot know
# that an age must be non-negative, that two dates must be ordered, or
# that an identifier must be unique. Those are the caller's rules, so the
# caller supplies them.

#' Declare a validation rule
#'
#' Builds a rule for [validate_rules()]: a predicate over one column, or
#' over the whole data frame, with a severity and a message. Rules live
#' alongside a schema in a provenance record, which keeps the
#' project-specific checks in data rather than scattered through code.
#'
#' `expr` is a function. Given `column`, it receives that column and must
#' return a logical vector the same length (TRUE = the row passes) or a
#' single logical for a whole-column property. Given no `column`, it
#' receives the whole data frame and must return a single logical.
#'
#' @param name Short identifier for the rule.
#' @param expr A function, as described above.
#' @param column Column the rule applies to, or `NULL` for a
#'   table-level rule.
#' @param severity `"warning"` (default) or `"fatal"`.
#' @param message Human-readable description of what a failure means.
#'   Defaults to a generated one naming the rule.
#' @return A list of class `bricklayer_rule`.
#' @seealso [validate_rules()], [validate_schema()] for the structural
#'   checks that need no rules.
#' @examples
#' # A column predicate, applied row-wise.
#' rule("age_non_negative", function(v) v >= 0, column = "age")
#'
#' # A whole-column property.
#' rule("id_unique", function(v) !anyDuplicated(v), column = "id",
#'      severity = "fatal")
#'
#' # A table-level rule spanning two columns.
#' rule("dates_ordered", function(df) all(df$start <= df$end))
#' @export
rule <- function(name, expr, column = NULL, severity = c("warning", "fatal"),
                 message = NULL) {
  severity <- match.arg(severity)
  name <- as.character(name)[1L]
  if (is.na(name) || !nzchar(name)) {
    stop("`name` must be a non-empty string", call. = FALSE)
  }
  if (!is.function(expr)) {
    stop("`expr` must be a function", call. = FALSE)
  }
  if (!is.null(column)) {
    column <- as.character(column)[1L]
    if (is.na(column) || !nzchar(column)) {
      stop("`column` must be a non-empty string or NULL", call. = FALSE)
    }
  }
  out <- list(name = name, expr = expr, column = column,
              severity = severity,
              message = if (is.null(message)) {
                sprintf("Rule '%s' failed", name)
              } else {
                as.character(message)[1L]
              })
  class(out) <- c("bricklayer_rule", "list")
  out
}

#' Apply declared rules to a data frame
#'
#' Evaluates each rule from [rule()] and returns the failures in the same
#' shape [validate_schema()] uses, so the two can be combined and handed
#' to [apply_schema_validation()] together.
#'
#' A rule whose column is absent is SKIPPED rather than failed -- a
#' missing column is [validate_schema()]'s business, and reporting it
#' twice buries the real finding. A rule that ERRORS is reported as a
#' failure naming the error, never swallowed: a rule that cannot run has
#' not passed.
#'
#' @param data A data frame.
#' @param rules A list of [rule()] objects, or a single rule.
#' @return A named list of issues, each with `severity`, `message`, and
#'   for a row-wise rule `n_failed` and `rows` (the first failing row
#'   indices). Empty when everything passes.
#' @seealso [rule()], [validate_schema()], [apply_schema_validation()]
#' @examples
#' df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
#'                  start = c(1, 5, 3), end = c(2, 4, 9))
#'
#' rules <- list(
#'   rule("age_non_negative", function(v) v >= 0, column = "age"),
#'   rule("id_unique", function(v) !anyDuplicated(v), column = "id",
#'        severity = "fatal"),
#'   rule("dates_ordered", function(d) all(d$start <= d$end))
#' )
#'
#' issues <- validate_rules(df, rules)
#' names(issues)
#'
#' # A row-wise failure reports how many rows and which.
#' issues$age_non_negative$n_failed
#' issues$age_non_negative$rows
#'
#' # Clean data produces nothing.
#' clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
#' length(validate_rules(clean, rules))
#'
#' # A rule for an absent column is skipped, not failed -- a missing
#' # column is validate_schema()'s finding to report, not this one's.
#' length(validate_rules(data.frame(id = 1:3), rules[1:2]))
#'
#' # A rule that errors is a failure, not a silent pass.
#' broken <- list(rule("bad", function(v) stop("boom"), column = "age"))
#' validate_rules(clean, broken)$bad$message
#' @export
validate_rules <- function(data, rules) {
  if (!is.data.frame(data)) stop("`data` must be a data frame", call. = FALSE)
  if (inherits(rules, "bricklayer_rule")) rules <- list(rules)
  if (!is.list(rules)) {
    stop("`rules` must be a rule() or a list of them", call. = FALSE)
  }
  issues <- list()
  for (r in rules) {
    if (!inherits(r, "bricklayer_rule")) {
      stop("every element of `rules` must come from rule()", call. = FALSE)
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
