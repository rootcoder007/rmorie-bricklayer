# Period labels.
#
# A period's value and a period's name are not the same thing. Ontario's
# inmate data keys on `EndFiscalYear`, where 2023 means the fiscal year
# 2022/23; printing it as "2023" names a calendar year that the row is
# not about. Labels are display-only -- the comparison still runs on the
# value, so relabelling cannot change an answer.

#' Label a period without changing it
#'
#' Attaches display labels to a change table. The arithmetic already ran on
#' the period's value, so a label can only affect what is printed:
#' relabelling cannot move a number.
#'
#' @param x An `rmbl_yoy` object from
#' [yoy()].
#' @param labels Either a function applied to the period
#' column, or a character vector the same length as the number of distinct
#' periods, or a named character vector mapping a period (as a string) to
#' its label.
#' @return The object, with a `period_label` column and the labels
#' used by `print()`, [yoy_html()],
#' [yoy_pdf()] and the delimited writers.
#' @seealso [fiscal_year_label()]
#' @examples
#' seg <- data.frame(EndFiscalYear = 2019:2023,
#'                   n = c(402, 377, 190, 268, 331))
#' y <- yoy(seg, value = n, period = EndFiscalYear)
#'
#' # 2023 means the fiscal year 2022/23, so say so.
#' yoy_label(y, fiscal_year_label)
#'
#' # Any function will do.
#' yoy_label(y, function(p) paste0("FY", substr(p, 3, 4)))
#'
#' # Or an explicit mapping, for the periods that need one.
#' yoy_label(y, c("2020" = "2019/20 (COVID)"))
#' @export
yoy_label <- function(x, labels) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("`x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  p <- x[[m$period]]
  lab <- if (is.function(labels)) {
    as.character(labels(p))
  } else if (!is.null(names(labels))) {
    # a named mapping covers only the periods it names; the rest keep
    # their own value, so a partial mapping is not a partial table
    out <- as.character(p)
    hit <- match(out, names(labels))
    out[!is.na(hit)] <- as.character(labels)[hit[!is.na(hit)]]
    out
  } else {
    u <- unique(p)
    if (length(labels) != length(u)) {
      stop(sprintf(
        "`labels` has %d entries for %d distinct periods; name them, or pass a function",
        length(labels), length(u)), call. = FALSE)
    }
    as.character(labels)[match(p, u)]
  }
  if (length(lab) != nrow(x)) {
    stop("`labels` must produce one label per row", call. = FALSE)
  }
  x$period_label <- lab
  attr(x, "yoy")$period_label <- TRUE
  x
}

#' Name a fiscal year by the years it spans
#'
#' Ontario's inmate data keys on the fiscal year's END year, so 2023 is the
#' fiscal year running from April 2022 to March 2023. This renders that as
#' `"2022/23"`.
#'
#' @param end_year The fiscal year's end year, as a number
#' or a string.
#' @param sep Separator between the two years.
#' @param short Whether to abbreviate the second year to two
#' digits.
#' @return A character vector of labels.
#' @examples
#' fiscal_year_label(2019:2023)
#'
#' fiscal_year_label(2023, short = FALSE)
#'
#' fiscal_year_label(2023, sep = "-")
#' @export
fiscal_year_label <- function(end_year, sep = "/", short = TRUE) {
  y <- suppressWarnings(as.integer(as.character(end_year)))
  out <- rep(NA_character_, length(y))
  ok <- !is.na(y)
  if (!any(ok)) return(out)
  # a two-digit abbreviation of the end year is only unambiguous inside
  # a century, which is the span these datasets cover
  tail <- if (isTRUE(short)) sprintf("%02d", y[ok] %% 100L) else
    as.character(y[ok])
  out[ok] <- paste0(y[ok] - 1L, sep, tail)
  out
}

# The column a renderer should print for the period.
.yoy_period_text <- function(x, m) {
  if (!is.null(m$period_label) && "period_label" %in% names(x)) {
    return(as.character(x$period_label))
  }
  as.character(x[[m$period]])
}
