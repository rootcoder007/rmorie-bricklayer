# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fetch an Ontario SIU director's report by drid
#'
#' @description
#' Downloads the web page of one director's report of the Ontario Special
#' Investigations Unit (SIU), the agency that investigates police
#' interactions that end in death, serious injury or sexual-assault
#' allegations, and saves its HTML to \code{dest}. Reports are identified by
#' their \code{drid} number. If the live site does not answer, a copy from
#' the Wayback Machine is used. This is the fetch step of the open SIU
#' corpus pipeline: pair it with the SIU parser in this package
#' (\code{\link{bricklayer_fetch_parse_siu}} fetches and parses in one call;
#' the compiled core under \code{src/siu_*.cpp} is the canonical
#' implementation, and \pkg{rmorie} links to the same core) to rebuild the
#' director's-report corpus yourself.
#'
#' @details
#' The URL fetched is
#' \code{https://www.siu.on.ca/<lang>/directors_report_details.php?drid=<drid>},
#' through \code{\link{bricklayer_fetch}}, which tries the live page first
#' and falls back to a Wayback Machine snapshot (the one given in
#' \code{wayback}, or one it looks up).
#'
#' Network: one or more HTTPS requests to www.siu.on.ca and, on failure,
#' web.archive.org. Side effect: writes \code{dest}.
#'
#' Errors, before any request: \code{drid} not one positive whole number
#' (\code{1.5} is refused rather than read as report 1); \code{lang} not
#' \code{"en"} or \code{"fr"}; \code{dest} not a single non-empty string.
#' Then any error from \code{bricklayer_fetch()}, for example when neither
#' the live page nor an archived copy can be reached.
#'
#' @param drid Director's-report id: the \code{drid=} query parameter, one
#'   positive whole number (integer or integer-like, such as \code{648} or
#'   \code{"648"}).
#' @param dest Character string: the file to write the fetched HTML to.
#' @param lang \code{"en"} (default) or \code{"fr"}: the language of the
#'   report page.
#' @param wayback Optional explicit Wayback snapshot URL (passed through to
#'   \code{bricklayer_fetch}); \code{""} (the default) lets it discover one.
#' @param timeout Request timeout in seconds. Default 120.
#' @return \code{"live"} or \code{"wayback"} (invisibly), as
#'   \code{bricklayer_fetch}: which source the HTML came from.
#' @seealso \code{\link{bricklayer_fetch}},
#'   \code{\link{bricklayer_fetch_parse_siu}}
#' @examples
#' # the report number is checked before anything is sent
#' try(bricklayer_fetch_siu(1.5, tempfile(fileext = ".html")))
#' try(bricklayer_fetch_siu(648, tempfile(fileext = ".html"), lang = "de"))
#'
#' # a real fetch needs the network (the SIU site or the Wayback Machine)
#' \dontrun{
#' dest <- tempfile(fileext = ".html")
#' bricklayer_fetch_siu(648, dest)
#' bricklayer_fetch_siu(648, tempfile(fileext = ".html"), lang = "fr")
#' }
#' @export
bricklayer_fetch_siu <- function(drid, dest, lang = c("en", "fr"),
                                 wayback = "", timeout = 120L) {
  lang <- .rmbl_arg(lang)
  did <- .rmbl_drid(drid)
  dest <- .rmbl_string1(dest, "dest")
  url <- sprintf(
    "https://www.siu.on.ca/%s/directors_report_details.php?drid=%d",
    lang, did)
  bricklayer_fetch(url, dest, wayback = wayback, timeout = timeout)
}

# One positive whole report number: as.integer() would read 1.5 as 1 and fetch another report.
.rmbl_drid <- function(drid) {
  v <- if (length(drid) == 1L && !is.logical(drid)) suppressWarnings(as.numeric(drid)) else NA_real_
  if (is.na(v) || !is.finite(v) || v != floor(v) || v <= 0 || v > .Machine$integer.max) {
    stop("`drid` must be one positive report number (the drid in the SIU report URL)", call. = FALSE)
  }
  as.integer(v)
}
