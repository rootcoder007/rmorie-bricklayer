# Period labels.
#
# A period's value and a period's name are not the same thing. Ontario's
# inmate data keys on `EndFiscalYear`, where 2023 means the fiscal year
# 2022/23; printing it as "2023" names a calendar year that the row is
# not about. Labels are display-only -- the comparison still runs on the
# value, so relabelling cannot change an answer.

#' Label a period without changing it
#'
#' Attaches display labels to the periods of a change table from
#' [yoy()],
#' so a fiscal year keyed as 2023 can print as \code{"2022/23"}, or a year can
#' carry a note such as \dQuote{(COVID)}. The arithmetic already ran on the
#' period's value, so a label can only affect what is printed: relabelling
#' cannot move a number.
#'
#' @details
#' The labels are stored in a new \code{perlbl} column, and the
#' table's \code{yoy} attribute is marked so that \code{print()},
#' [yoyhtml()], [yoypdf()] and the
#' delimited writers show the label in
#' place of the period. The period column itself is unchanged, as are all
#' values, changes and verdicts.
#'
#' \code{labels} is interpreted as follows: a function is called once on the
#' period column and must return one label per row; a named character vector
#' maps periods (matched as strings) to labels, and periods it does not name
#' keep their own value; an unnamed character vector gives one label per
#' distinct period, in order of first appearance.
#'
#' Errors: \code{x} not from [yoy()]; an unnamed vector whose length is
#' not
#' the number of distinct periods; a function that does not return one label
#' per row.
#'
#' @param x An \code{rmbl_yoy} object from [yoy()].
#' @param labels Either a function applied to the period
#'   column, or a character vector the same length as the number of distinct
#'   periods, or a named character vector mapping a period (as a string) to
#'   its label.
#' @return The object, still of class \code{rmbl_yoy}, with an added
#'   character column \code{perlbl}. Its \code{yoy} attribute gets
#'   \code{perlbl} set to \code{TRUE}, as \code{attr(x, "yoy")$perlbl}, so the labels
#'   are used by \code{print()},
#'   [yoyhtml()],
#'   [yoypdf()] and the delimited writers.
#' @seealso [fylbl()]
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' seg <- data.frame(EndFiscalYear = 2019:2023,
#'                   n = c(402, 377, 190, 268, 331))
#' y <- yoy(seg, value = n, prd = EndFiscalYear)
#'
#' # 2023 means the fiscal year 2022/23, so say so.
#' yoylbl(y, fylbl)
#'
#' # Any function will do.
#' yoylbl(y, function(p) paste0("FY", substr(p, 3, 4)))
#'
#' # Or an explicit mapping, for the periods that need one.
#' yoylbl(y, c("2020" = "2019/20 (COVID)"))
#'
#' # the numbers are untouched
#' identical(yoylbl(y, fylbl)$change, y$change)
#'
#' # an unnamed vector must have one label per distinct period
#' try(yoylbl(y, c("a", "b")))
#' @export
yoylbl <- function(x, labels) {
  if (!inherits(x, "rmbl_yoy")) {
    stop("yoylbl: `x` must be an rmbl_yoy object from yoy()", call. = FALSE)
  }
  m <- .yoy_meta(x)
  p <- x[[m$period]]
  if (!is.function(labels) && !is.atomic(labels)) {
    stop("`labels` must be a function of the periods or a vector of labels", call. = FALSE)
  }
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
  x$perlbl <- lab
  attr(x, "yoy")$perlbl <- TRUE
  x
}

#' Name a fiscal year by the years it spans
#'
#' Turns fiscal years keyed by their END year into labels that name both
#' calendar years. Ontario's inmate data (and many government series) key on
#' the fiscal year's end year, so 2023 is the fiscal year running from April
#' 2022 to March 2023; this renders that as \code{"2022/23"}, which a reader
#' cannot mistake for the calendar year 2023. Pass it to
#' [yoylbl()] to
#' label a change table.
#'
#' @details
#' Each value is converted with \code{as.integer(as.character(endyear))},
#' so a string such as \code{"2023"} works; a fractional number is refused
#' rather than truncated (2023.7 is an error). The label is
#' \code{(y - 1)}, \code{sep}, then \code{y} itself or its last two digits.
#' Values that cannot be read as a year give \code{NA}. The two-digit form
#' is unambiguous within a century (2000 gives \code{"1999/00"}).
#'
#' Errors: \code{endyear} that is neither numeric nor character (for
#' example logical); a numeric year below 1; a numeric year that is not whole.
#'
#' @param endyear The fiscal year's end year, as a whole number
#'   or a string; a vector of them.
#' @param sep Separator between the two years, a string; default
#'   \code{"/"}.
#' @param short Logical. \code{TRUE} (the default) abbreviates the second year
#'   to two digits, as in \code{"2022/23"}; \code{FALSE} writes it in full, as in
#'   \code{"2022/2023"}.
#' @return A character vector of labels, the same length as
#'   \code{endyear}, with \code{NA} where a value is not a year.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' fylbl(2019:2023)
#'
#' fylbl(2023, short = FALSE)
#'
#' fylbl(2023, sep = "-")
#'
#' # strings work; something that is not a year gives NA
#' fylbl(c("2023", "n/a", NA))
#'
#' # logical input is refused
#' try(fylbl(TRUE))
#' @export
fylbl <- function(endyear, sep = "/", short = TRUE) {
  sep <- .rmbl_text1(sep, "sep")
  if (!is.null(endyear) && !is.numeric(endyear) && !is.character(endyear)) {
    stop("`endyear` must be numeric or character years", call. = FALSE)
  }
  if (is.numeric(endyear) && any(endyear < 1, na.rm = TRUE)) {
    stop("`endyear` must be positive years", call. = FALSE)
  }
  # 2024.5 labelled "2023/24" silently (final audit of 1.0.0): a year is a whole number
  if (is.numeric(endyear) && any(endyear != round(endyear), na.rm = TRUE)) {
    stop("`endyear` must be whole years", call. = FALSE)
  }
  y <- suppressWarnings(as.integer(as.character(endyear)))
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

#' The column a renderer should print for the period.
#' @param x The result table.
#' @param m The result's metadata, with `period` and, when set, `perlbl`.
#' @return A character vector, one label per row.
#' @noRd
.yoy_period_text <- function(x, m) {
  if (!is.null(m$perlbl) && "perlbl" %in% names(x)) {
    return(as.character(x$perlbl))
  }
  as.character(x[[m$period]])
}
