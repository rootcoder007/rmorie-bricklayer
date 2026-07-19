# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fetch an Ontario SIU director's report by drid
#'
#' Downloads the HTML of one Ontario Special Investigations Unit (SIU)
#' director's report to \code{dest}, via \code{\link{bricklayer_fetch}}
#' (live URL with a Wayback Machine fallback). This is the fetch step of
#' the open SIU corpus pipeline: pair it with the SIU parser in
#' \pkg{rmorie} (or the standalone \code{siu} C++ package) to rebuild the
#' full director's-report corpus yourself, then audit it with the
#' multi-agent panel.
#'
#' @param drid Director's-report id -- the \code{drid=} query parameter
#'   (integer or integer-like scalar).
#' @param dest Destination file path for the fetched HTML.
#' @param lang \code{"en"} (default) or \code{"fr"}.
#' @param wayback Optional explicit Wayback snapshot URL (passed through
#'   to \code{bricklayer_fetch}); \code{""} lets it discover one.
#' @param timeout Request timeout in seconds. Default 120.
#' @return \code{"live"} or \code{"wayback"} (invisibly), as
#'   \code{bricklayer_fetch}.
#' @seealso \code{\link{bricklayer_fetch}}
#' @examples
#' \dontrun{
#' # Fetch report drid 648 to a temp file.
#' dest <- tempfile(fileext = ".html")
#' bricklayer_fetch_siu(648, dest)
#' }
#' @export
bricklayer_fetch_siu <- function(drid, dest, lang = c("en", "fr"),
                                 wayback = "", timeout = 120L) {
  lang <- match.arg(lang)
  did <- suppressWarnings(as.integer(drid))
  stopifnot(length(drid) == 1L, !is.na(did), did > 0L,
            is.character(dest), length(dest) == 1L, nzchar(dest))
  url <- sprintf(
    "https://www.siu.on.ca/%s/directors_report_details.php?drid=%d",
    lang, did)
  bricklayer_fetch(url, dest, wayback = wayback, timeout = timeout)
}
