# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
#'
#' The shared data-fetch foundation of the morie ecosystem. Downloads
#' \code{url} to \code{dest}; if the live download fails (404, network),
#' it retries the Wayback Machine snapshot -- so a rotated or removed
#' source file (CIHI, open-data portals) stays retrievable. Backed by the
#' package's C++ \code{rmbl_fetch_with_fallback} kernel (libcurl), which
#' \pkg{rmorie} and \pkg{morie} share through \code{LinkingTo}.
#'
#' @param url Live source URL.
#' @param dest Destination file path.
#' @param wayback Optional explicit Wayback snapshot URL. \code{""}
#'   (default) auto-resolves one via \code{\link{wayback_snapshot_url}}.
#' @param timeout Per-request timeout, seconds.
#' @return Invisibly, one of \code{"live"}, \code{"wayback"}, or throws on
#'   total failure.
#' @examples
#' # Inputs are validated before any network access:
#' try(bricklayer_fetch("", tempfile()))          # empty url -> error
#'
#' \donttest{
#' # Downloads from the live web service; try() keeps the example graceful
#' # when neither the live URL nor its Wayback fallback is reachable.
#' dst <- tempfile(fileext = ".xlsx")
#'
#' # Live download; auto-resolves a Wayback snapshot only if the live URL fails.
#' try(bricklayer_fetch(
#'   "https://www.cihi.ca/sites/default/files/document/hospital-beds-2024-2025-data-tables-en.xlsx",
#'   dst))
#'
#' # Pin an explicit Wayback snapshot to fall back to, and a shorter timeout.
#' try(bricklayer_fetch(
#'   "https://example.org/rotated-file.csv", tempfile(fileext = ".csv"),
#'   wayback = "https://web.archive.org/web/2024id_/https://example.org/rotated-file.csv",
#'   timeout = 60))
#'
#' # The return value tells you which source served the file.
#' status <- try(bricklayer_fetch("https://cloud.r-project.org/", tempfile()))
#' status   # "live" or "wayback"
#' }
#' @export
bricklayer_fetch <- function(url, dest, wayback = "", timeout = 120L) {
  stopifnot(is.character(url), length(url) == 1L, nzchar(url),
            is.character(dest), length(dest) == 1L, nzchar(dest))
  code <- .Call(C_rmbl_fetch_fallback, url,
                if (is.null(wayback)) "" else as.character(wayback),
                dest, as.integer(timeout))
  if (code == 0L) return(invisible("live"))
  if (code == 1L) return(invisible("wayback"))
  stop("bricklayer_fetch: both the live URL and its Wayback fallback failed for ",
       url, call. = FALSE)
}

#' Resolve a Wayback Machine snapshot URL (C++/libcurl)
#'
#' Queries the Internet Archive \dQuote{available} API for the closest
#' archived snapshot of \code{url}. C++ backend; supersedes the older
#' jsonlite-based resolver (kept internally for offline use).
#'
#' @param url URL to resolve.
#' @param timeout Request timeout, seconds.
#' @return The https snapshot URL, or \code{NULL} if none is archived.
#' @examples
#' # Input is validated before any network call:
#' try(wayback_snapshot_url_native(""))     # empty url -> error
#'
#' \donttest{
#' # Uses the live Wayback service; degrades gracefully offline: any
#' # network failure returns NULL rather than erroring.
#' # Closest archived snapshot of a live page (or NULL if none archived).
#' wayback_snapshot_url_native("https://www.r-project.org/")
#'
#' # A shorter timeout for a quick lookup.
#' wayback_snapshot_url_native("https://cloud.r-project.org/", timeout = 10)
#'
#' # A never-archived URL returns NULL rather than erroring.
#' wayback_snapshot_url_native("https://example.invalid/never-archived")
#' }
#' @export
wayback_snapshot_url_native <- function(url, timeout = 30L) {
  stopifnot(is.character(url), length(url) == 1L, nzchar(url))
  snap <- .Call(C_rmbl_wayback, url, as.integer(timeout))
  if (is.character(snap) && nzchar(snap)) snap else NULL
}
