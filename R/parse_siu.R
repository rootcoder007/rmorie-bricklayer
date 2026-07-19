# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SIU parse/resolve surface over the native core (src/siu_*.cpp -- the
# canonical home; the standalone `siu` package mirrors it). Everything here
# is deterministic and offline; the only network function remains
# bricklayer_fetch_siu().

#' The panel-reviewed SIU report field schema
#'
#' The sixteen fields extracted from every Special Investigations Unit
#' director's report. Count-type fields (`is_count = TRUE`) count distinct
#' entities and zero is a real answer -- a witness-official-only
#' investigation has zero subject officials.
#'
#' @return A data.frame with columns `name`, `is_count`, and `description`.
#' @examples
#' bricklayer_siu_schema()
#' @export
bricklayer_siu_schema <- function() {
  as.data.frame(.Call(C_rmbl_siu_schema, NULL), stringsAsFactors = FALSE)
}

#' Convert SIU report HTML to plain text
#'
#' @param html A length-1 character vector of raw report HTML.
#' @return A length-1 character vector of plain text.
#' @examples
#' bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#' @export
bricklayer_siu_text <- function(html) {
  .Call(C_rmbl_siu_html_to_text, html)
}

#' Parse an SIU director's report into the schema fields
#'
#' Deterministic, offline extraction of every [bricklayer_siu_schema()]
#' field (plus `_language`) from report HTML. Fields the report does not
#' state come back as `""`.
#'
#' @param html A length-1 character vector of raw report HTML, or the path
#'   to a saved report file (e.g. from [bricklayer_fetch_siu()]).
#' @return A named character vector: the 16 schema fields plus `_language`.
#' @examples
#' f <- bricklayer_parse_siu(system.file("extdata",
#'                                       "siu_synthetic_report.html",
#'                                       package = "rmoriebricklayer"))
#' f[["number_of_subject_officers"]]
#' @export
bricklayer_parse_siu <- function(html) {
  stopifnot(is.character(html), length(html) == 1L, !is.na(html))
  if (!grepl("<", html, fixed = TRUE) && file.exists(html)) {
    html <- paste(readLines(html, warn = FALSE, encoding = "UTF-8"),
                  collapse = "\n")
  }
  .Call(C_rmbl_siu_parse_html, html)
}

#' Fetch and parse one SIU director's report
#'
#' Convenience: [bricklayer_fetch_siu()] then [bricklayer_parse_siu()].
#' Fails gracefully -- returns `NULL` with a message when the report cannot
#' be retrieved.
#'
#' @param drid Director's-report id (the `drid=` query parameter).
#' @param lang `"en"` (default) or `"fr"`.
#' @return A named character vector of parsed fields, or `NULL` when the
#'   fetch fails.
#' @examples
#' \donttest{
#' f <- try(bricklayer_fetch_parse_siu(648), silent = TRUE)
#' if (is.character(f)) f[["police_service"]]
#' }
#' @export
bricklayer_fetch_parse_siu <- function(drid, lang = c("en", "fr")) {
  dest <- tempfile(fileext = ".html")
  on.exit(unlink(dest), add = TRUE)
  ok <- tryCatch(bricklayer_fetch_siu(drid, dest, lang = lang),
                 error = function(e) {
                   message("bricklayer: could not fetch SIU report ", drid,
                           ": ", conditionMessage(e))
                   NULL
                 })
  if (is.null(ok) || !file.exists(dest)) return(NULL)
  bricklayer_parse_siu(dest)
}

#' Convert a human-readable SIU report date to ISO format
#'
#' `"January 5, 2023"` (or `"January 5 2023"`) becomes `"2023-01-05"`;
#' unparseable input becomes `""`.
#'
#' @param x A character vector of human-readable dates.
#' @return A character vector of `YYYY-MM-DD` strings (or `""`).
#' @examples
#' bricklayer_siu_iso_date(c("January 5, 2023", "not a date"))
#' @export
bricklayer_siu_iso_date <- function(x) {
  stopifnot(is.character(x))
  vapply(x, function(v) .Call(C_rmbl_siu_to_iso_date, v), character(1),
         USE.NAMES = FALSE)
}

#' Resolve the subject-official count from SIU report text
#'
#' Deterministic, reproducible extraction of the subject-official (SO)
#' count for reports where a model panel (or a human) is unsure. The
#' standard SIU privacy boilerplate is stripped first, then rules apply
#' most-specific first: highest `SO #N` ordinal; spelled-out plural;
#' singular subject official present (1); witness-official-only (0, a real
#' answer); otherwise unresolved (`NA`).
#'
#' @param text A length-1 character vector of plain report text (see
#'   [bricklayer_siu_text()]).
#' @return A list with `count` (integer, `NA` when unresolved) and
#'   `reason` (the human-readable evidence).
#'
#' @details bricklayer is the foundation layer: this function is the pure
#'   rule set. Reports already in the panel-reviewed corpus should never be
#'   re-derived -- use `rmorie::morie_siu_resolve_so()`, which returns the
#'   verified corpus value first and only falls back to these rules for
#'   unreviewed reports.
#' @examples
#' bricklayer_siu_resolve_so(
#'   "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#' @export
bricklayer_siu_resolve_so <- function(text) {
  stopifnot(is.character(text), length(text) == 1L, !is.na(text))
  .Call(C_rmbl_siu_resolve_so, text)
}
