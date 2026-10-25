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
#' (\code{\link{siufprs}} fetches and parses in one call;
#' the compiled core under \code{src/siu_*.cpp} is the canonical
#' implementation, and \pkg{rmorie} links to the same core) to rebuild the
#' director's-report corpus yourself.
#'
#' @details The URL fetched is
#' \preformatted{
#' https://www.siu.on.ca/<lang>/directors_report_details.php?drid=<drid>
#' }
#' through \code{\link{blfetch}}, which tries the live page first and falls back
#' to a Wayback Machine snapshot (the one given in \code{wb}, or one it looks
#' up).
#'
#' Network: one or more HTTPS requests to www.siu.on.ca and, on failure,
#' web.archive.org. Side effect: writes \code{dest}.
#'
#' Errors, before any request: \code{drid} not one positive whole number
#' (\code{1.5} is refused rather than read as report 1); \code{lang} not
#' \code{"en"} or \code{"fr"}; \code{dest} not a single non-empty string.
#' Then any error from \code{blfetch()}, for example when neither
#' the live page nor an archived copy can be reached.
#'
#' @param drid Director's-report id: the \code{drid=} query parameter, one
#'   positive whole number (integer or integer-like, such as \code{648} or
#'   \code{"648"}).
#' @param dest Character string: the file to write the fetched HTML to.
#' @param lang \code{"en"} (default) or \code{"fr"}: the language of the
#'   report page.
#' @param wb Optional explicit Wayback snapshot URL (passed through to
#'   \code{blfetch}); \code{""} (the default) lets it discover one.
#' @param tmout Request timeout in seconds. Default 120.
#' @return \code{"live"} or \code{"wayback"} (invisibly), as
#'   \code{blfetch}: which source the HTML came from.
#' @seealso \code{\link{blfetch}},
#'   \code{\link{siufprs}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # the report number is checked before anything is sent
#' try(siufetch(1.5, tempfile(fileext = ".html")))
#' try(siufetch(648, tempfile(fileext = ".html"), lang = "de"))
#'
#' # a real fetch needs the network (the SIU site or the Wayback Machine)
#'
#' @examplesIf interactive()
#' dest <- tempfile(fileext = ".html")
#' siufetch(648, dest)
#' siufetch(648, tempfile(fileext = ".html"), lang = "fr")
#' @export
siufetch <- function(drid, dest, lang = c("en", "fr"), wb = "", tmout = 120L) {
  lang <- .rmbl_arg(lang)
  did <- .rmbl_drid(drid)
  dest <- .rmbl_string1(dest, "dest")
  url <- sprintf(
    "https://www.siu.on.ca/%s/directors_report_details.php?drid=%d",
    lang,
    did
  )
  blfetch(url, dest, wb = wb, tmout = tmout)
}

#' One positive whole report number: as.integer() would read 1.5 as 1 and fetch
#' another report.
#' @param drid The report number passed by the user.
#' @return The report number as an integer.
#' @noRd
.rmbl_drid <- function(drid) {
  v <- if (
    is.atomic(drid) &&
      length(drid) == 1L &&
      !is.logical(drid) &&
      !is.complex(drid)
  ) {
    suppressWarnings(as.numeric(drid))
  } else {
    NA_real_
  }
  if (
    is.na(v) ||
      !is.finite(v) ||
      v != floor(v) ||
      v <= 0 ||
      v > .Machine$integer.max
  ) {
    stop(
      "`drid` must be one positive report number (the drid in the SIU ",
      "report URL)",
      call. = FALSE
    )
  }
  as.integer(v)
}
