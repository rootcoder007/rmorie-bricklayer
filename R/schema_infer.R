# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Writing a schema by hand is the step people skip, so the capsule ends
# up pinned on nothing. Deriving one from data they already trust removes
# the excuse: infer it once, read it, commit it.

#' Infer a pinnable schema from a data frame
#'
#' Derives the schema [validate_schema()] consumes from data you already
#' trust, so a capsule can be pinned without writing one by hand.
#'
#' What it records: the column names and their types, row-count bounds
#' with `slack` either side, the observed value set for every
#' low-cardinality categorical column, the observed range of every
#' numeric column widened by `slack`, and the observed missingness rate
#' per column with headroom.
#'
#' # This is a starting point, not an oracle
#'
#' An inferred schema describes ONE extract. It cannot know that a
#' category which happens not to occur is nonetheless legal, or that a
#' range is a physical bound rather than an accident of this sample.
#' Read what it produces and edit it before committing -- the value is in
#' not starting from a blank file, not in trusting the output blindly.
#'
#' @param data A data frame to learn from.
#' @param slack Fractional headroom added to row counts, numeric ranges
#'   and missingness rates (default 0.1, i.e. 10%). `0` pins exactly to
#'   what was observed, which will reject almost any re-release.
#' @param max_levels Maximum distinct values for a categorical column to
#'   have its value set recorded (default 50). Above this the column is
#'   treated as free text and no value set is pinned.
#' @return A list with `expected_columns`, `expected_types`,
#'   `structural_invariants`, `expected_value_sets`, `numeric_ranges` and
#'   `max_missing_fraction`, of class `bricklayer_schema`. Wrap it as
#'   `list(schema = <this>)` to hand to [validate_schema()].
#' @seealso [validate_schema()], [capsule_drift()] for the
#'   distributional check the schema cannot make.
#' @examples
#' set.seed(1)
#' df <- data.frame(
#'   id = 1:100,
#'   score = stats::runif(100, 0, 10),
#'   grade = sample(c("a", "b", "c"), 100, TRUE),
#'   note = paste0("free text ", 1:100),
#'   stringsAsFactors = FALSE
#' )
#'
#' sch <- infer_schema(df)
#' sch
#'
#' # The categorical column has its levels pinned; the free-text one does
#' # not, because it exceeds max_levels.
#' sch$expected_value_sets
#'
#' # It validates the data it was learned from.
#' length(validate_schema(df, list(schema = sch)))
#'
#' # And catches a column that has gone missing, or a new category.
#' length(validate_schema(df[, -3], list(schema = sch))) > 0
#' bad <- df; bad$grade[1] <- "z"
#' length(validate_schema(bad, list(schema = sch))) > 0
#' @export
infer_schema <- function(data, slack = 0.1, max_levels = 50L) {
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame", call. = FALSE)
  }
  if (ncol(data) == 0L) {
    stop("`data` has no columns to learn a schema from", call. = FALSE)
  }
  slack <- as.numeric(slack)
  if (length(slack) != 1L || is.na(slack) || slack < 0) {
    stop("`slack` must be a single non-negative number", call. = FALSE)
  }
  max_levels <- as.integer(max_levels)
  if (length(max_levels) != 1L || is.na(max_levels) || max_levels < 1L) {
    stop("`max_levels` must be a single positive integer", call. = FALSE)
  }

  n <- nrow(data)
  types <- vapply(data, function(v) class(v)[1L], character(1))

  value_sets <- list()
  ranges <- list()
  miss <- numeric(0)
  for (nm in names(data)) {
    v <- data[[nm]]
    miss[[nm]] <- min(1, sum(is.na(v)) / max(1L, n) + slack)
    if (is.numeric(v)) {
      ok <- v[!is.na(v)]
      if (length(ok)) {
        lo <- min(ok)
        hi <- max(ok)
        pad <- slack * (hi - lo)
        # A constant column has no width to pad, so pad by the magnitude
        # of the value itself rather than pinning it to a single number.
        if (pad == 0) pad <- slack * max(abs(lo), 1)
        ranges[[nm]] <- c(min = lo - pad, max = hi + pad)
      }
    } else if (is.factor(v) || is.character(v) || is.logical(v)) {
      lv <- unique(as.character(v[!is.na(v)]))
      if (length(lv) <= max_levels) value_sets[[nm]] <- sort(lv)
    }
  }

  out <- list(
    expected_columns = names(data),
    expected_types = types,
    structural_invariants = list(
      min_data_rows = max(0L, as.integer(floor(n * (1 - slack)))),
      max_data_rows = as.integer(ceiling(n * (1 + slack)))
    ),
    expected_value_sets = value_sets,
    numeric_ranges = ranges,
    max_missing_fraction = miss
  )
  class(out) <- c("bricklayer_schema", "list")
  out
}

#' @export
format.bricklayer_schema <- function(x, ...) {
  g <- .rmbl_glyphs()
  lines <- c(.rmbl_rule("Inferred schema"),
             .rmbl_kv(list(
               columns = length(x$expected_columns),
               rows = sprintf("%d to %d",
                              x$structural_invariants$min_data_rows,
                              x$structural_invariants$max_data_rows),
               "value sets" = length(x$expected_value_sets),
               "numeric ranges" = length(x$numeric_ranges))),
             "")
  rows <- vapply(x$expected_columns, function(nm) {
    detail <- if (!is.null(x$numeric_ranges[[nm]])) {
      sprintf("[%s, %s]",
              formatC(x$numeric_ranges[[nm]][["min"]], format = "g",
                      digits = 4),
              formatC(x$numeric_ranges[[nm]][["max"]], format = "g",
                      digits = 4))
    } else if (!is.null(x$expected_value_sets[[nm]])) {
      lv <- x$expected_value_sets[[nm]]
      if (length(lv) > 4L) {
        sprintf("%s, ... (%d levels)", paste(lv[1:4], collapse = ", "),
                length(lv))
      } else {
        paste(lv, collapse = ", ")
      }
    } else {
      paste0(g$dash, " free")
    }
    sprintf("  %-20s %-10s max NA %5.1f%%  %s", nm, x$expected_types[[nm]],
            100 * x$max_missing_fraction[[nm]], detail)
  }, character(1))
  c(lines, rows, .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_schema <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
