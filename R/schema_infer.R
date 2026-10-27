# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Writing a schema by hand is the step people skip, so the capsule ends
# up pinned on nothing. Deriving one from data they already trust removes
# the excuse: infer it once, read it, commit it.

#' Infer a pinnable schema from a data frame
#'
#' Derives the schema [valsch()]
#' consumes from data you already trust, so a capsule can be pinned without
#' writing one by hand. Infer it once from the extract the analysis was run
#' on, read it, edit it, commit it, and validate every later download
#' against it.
#'
#' @details
#' What it records: the column names and their types, row-count bounds with
#' \code{slack} either side, the observed value set for every
#' low-cardinality categorical column, the observed range of every numeric
#' column widened by \code{slack}, and the observed missingness rate per
#' column with headroom.
#'
#' The rules, with \eqn{n} rows: \itemize{ \item types: the first class of each
#' column (\code{"integer"}, \code{"numeric"}, \code{"character"},
#' \code{"factor"}, \code{"Date"}, ...); \item rows: \code{min_data_rows} \eqn{=
#' \lfloor n(1 - slack) \rfloor} (at least 0) and \code{max_data_rows} \eqn{=
#' \lceil n(1 + slack) \rceil}; \item numeric ranges: \eqn{[lo - pad, hi + pad]}
#' with \eqn{pad = slack \times (hi - lo)}, or \eqn{slack \times \max(|lo|, 1)}
#' for a constant column; a column with no non-missing value gets no range;
#' \item value sets: for character, factor and logical columns with at most
#' \code{maxlvl} distinct non-missing values, those values as sorted text; \item
#' missingness: the observed share of \code{NA} plus \code{slack} (added, not
#' multiplied), capped at 1. } Other column types (dates, lists) get a type and
#' a missingness ceiling only.
#'
#' ## This is a starting point, not an oracle
#'
#' An inferred schema describes ONE extract. It cannot know that a category
#' which happens not to occur is nonetheless legal, or that a range is a
#' physical bound rather than an accident of this sample. Read what it
#' produces and edit it before committing -- the value is in not starting
#' from a blank file, not in trusting the output blindly.
#'
#' Errors: \code{data} not a data frame or without columns; \code{slack} not
#' one non-negative number; \code{maxlvl} not one positive whole number.
#'
#' @param data A data frame to learn from.
#' @param slack Headroom, one non-negative number (default 0.1). It is a
#'   fraction of the row count and of each numeric range, and an absolute
#'   amount added to each missingness rate (0.1 allows ten more percentage
#'   points of \code{NA}). \code{0} pins exactly to what was observed, which
#'   will reject almost any re-release.
#' @param maxlvl Maximum distinct values for a
#'   categorical column to have its value set recorded, one positive whole
#'   number (default 50). Above this the column is treated as free text and
#'   no value set is pinned.
#' @return A list of class \code{bricklayer_schema} with these elements:
#'   \itemize{
#'     \item \code{expected_columns} (character);
#'     \item \code{expected_types} (named character);
#'     \item \code{structural_invariants} (list of \code{min_data_rows} and
#'       \code{max_data_rows}, integers);
#'     \item \code{expected_value_sets} (named list of character vectors);
#'     \item \code{numeric_ranges} (named list of \code{c(min =, max =)});
#'     \item \code{max_missing_fraction} (named numeric).
#'   }
#'   Wrap it as \code{list(schema = <this>)} to hand to
#'   [valsch()].
#' @seealso
#' [valsch()],
#' [cpsdrft()] for the distributional
#' check the schema cannot make.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' df <- data.frame(
#'   id = 1:100,
#'   score = stats::runif(100, 0, 10),
#'   grade = sample(c("a", "b", "c"), 100, TRUE),
#'   note = paste0("free text ", 1:100),
#'   stringsAsFactors = FALSE
#' )
#'
#' sch <- infsch(df)
#' sch
#'
#' # The categorical column has its levels pinned; the free-text one does
#' # not, because it exceeds max_levels.
#' sch$expected_value_sets
#'
#' # It validates the data it was learned from.
#' length(valsch(df, list(schema = sch)))
#'
#' # And catches a column that has gone missing, or a new category.
#' length(valsch(df[, -3], list(schema = sch))) > 0
#' bad <- df; bad$grade[1] <- "z"
#' length(valsch(bad, list(schema = sch))) > 0
#'
#' # no slack pins the exact observed range
#' infsch(df, slack = 0)$numeric_ranges$score
#'
#' # a negative slack is refused
#' try(infsch(df, slack = -0.1))
#' @export
infsch <- function(data, slack = 0.1, maxlvl = 50L) {
  if (!is.data.frame(data)) {
    stop("infsch: `data` must be a data frame", call. = FALSE)
  }
  if (ncol(data) == 0L) {
    stop("`data` has no columns to learn a schema from", call. = FALSE)
  }
  a <- .infsch_check(slack, maxlvl)
  slack <- a$slack
  maxlvl <- a$maxlvl

  n <- nrow(data)
  types <- vapply(data, function(v) class(v)[1L], character(1))

  cs <- .infsch_columns(data, slack, maxlvl)

  out <- list(
    expected_columns = names(data),
    expected_types = types,
    structural_invariants = list(
      min_data_rows = max(0L, as.integer(floor(n * (1 - slack)))),
      max_data_rows = as.integer(ceiling(n * (1 + slack)))
    ),
    expected_value_sets = cs$value_sets,
    numeric_ranges = cs$ranges,
    max_missing_fraction = cs$miss
  )
  class(out) <- c("bricklayer_schema", "list")
  out
}

#' @export
format.bricklayer_schema <- function(x, ...) {
  g <- .rmbl_glyphs()
  rows <- vapply(
    x$expected_columns,
    function(nm) {
      detail <- .infsch_detail(x, nm, g)
      sprintf(
        "%-20s %-10s max NA %5.1f%%  %s",
        nm,
        x$expected_types[[nm]],
        100 * x$max_missing_fraction[[nm]],
        detail
      )
    },
    character(1)
  )
  .rmbl_stat_block(
    "Inferred schema",
    facts = list(
      Columns = length(x$expected_columns),
      Rows = sprintf(
        "%d to %d",
        x$structural_invariants$min_data_rows,
        x$structural_invariants$max_data_rows
      ),
      `Value sets` = length(x$expected_value_sets),
      `Numeric ranges` = length(x$numeric_ranges)
    ),
    reading = paste(
      "What later extracts must look like to pass valsch(): these columns",
      "and types, missingness at most as shown, values inside these sets."
    ),
    notes = unname(rows)
  )
}

#' infsch()'s slack and level cap, checked.
#' @param slack,maxlvl As for infsch().
#' @return A list: slack and maxlvl.
#' @noRd
.infsch_check <- function(slack, maxlvl) {
  slack <- .rmbl_num(slack, "slack")
  if (length(slack) != 1L || is.na(slack) || slack < 0) {
    stop("`slack` must be a single non-negative number", call. = FALSE)
  }
  maxlvl <- .rmbl_num(maxlvl, "maxlvl", integer = TRUE)
  if (length(maxlvl) != 1L || is.na(maxlvl) || maxlvl < 1L) {
    stop("infsch: `maxlvl` must be a single positive integer", call. = FALSE)
  }
  list(slack = slack, maxlvl = maxlvl)
}

#' infsch()'s per-column rules: missing fractions, ranges and value sets.
#' @param data The data frame whose columns' rules are inferred.
#' @param slack,maxlvl The checked slack and level cap.
#' @return A list with `value_sets`, `ranges` and `miss` (named by column).
#' @noRd
.infsch_columns <- function(data, slack, maxlvl) {
  n <- nrow(data)
  value_sets <- list()
  ranges <- list()
  miss <- numeric(0)
  for (nm in names(data)) {
    v <- data[[nm]]
    miss[[nm]] <- min(1, sum(is.na(v)) / max(1L, n) + slack)
    if (is.numeric(v)) {
      ranges[[nm]] <- .infsch_range(v, slack)
    } else if (is.factor(v) || is.character(v) || is.logical(v)) {
      lv <- unique(as.character(v[!is.na(v)]))
      if (length(lv) <= maxlvl) value_sets[[nm]] <- sort(lv)
    }
  }
  list(value_sets = value_sets, ranges = ranges, miss = miss)
}

#' The rule column of one schema line: a range, the levels, or free.
#' @param x The schema.
#' @param nm The name of the column whose rule is described.
#' @param g The glyphs from `.rmbl_glyphs()`.
#' @return A single string.
#' @noRd
.infsch_detail <- function(x, nm, g) {
  if (!is.null(x$numeric_ranges[[nm]])) {
    sprintf(
      "[%s, %s]",
      formatC(x$numeric_ranges[[nm]][["min"]], format = "g", digits = 4),
      formatC(x$numeric_ranges[[nm]][["max"]], format = "g", digits = 4)
    )
  } else if (!is.null(x$expected_value_sets[[nm]])) {
    lv <- x$expected_value_sets[[nm]]
    if (length(lv) > 4L) {
      sprintf("%s, ... (%d levels)", toString(lv[1:4]), length(lv))
    } else {
      toString(lv)
    }
  } else {
    paste0(g$dash, " free")
  }
}

#' A numeric column's range, padded by the slack (by its magnitude when it is
#' constant), or NULL when it has no values.
#' @param v The numeric column whose padded range is returned.
#' @param slack The slack.
#' @return The range, named min and max, or NULL.
#' @noRd
.infsch_range <- function(v, slack) {
  ok <- v[!is.na(v)]
  if (!length(ok)) {
    return(NULL)
  }
  lo <- min(ok)
  hi <- max(ok)
  pad <- slack * (hi - lo)
  # A constant column has no width to pad, so pad by the magnitude
  # of the value itself rather than pinning it to a single number.
  if (pad == 0) {
    pad <- slack * max(abs(lo), 1)
  }
  c(min = lo - pad, max = hi + pad)
}
