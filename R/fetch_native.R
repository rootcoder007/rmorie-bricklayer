# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
#'
#' The shared data-fetch foundation of the morie ecosystem. Downloads
#' \code{url} to \code{dest}; if the live download fails (404, network),
#' it retries the Wayback Machine snapshot -- so a rotated or removed
#' source file (CIHI, open-data portals) stays retrievable. Backed by the
#' package's C++ \code{rmbl_fetch_with_fallback} kernel (libcurl), which
#' \pkg{rmorie} and \pkg{morie} share through \code{LinkingTo}. The return
#' value says which source served the file, so a report can note that it
#' used an archived copy.
#'
#' @details
#' Before any network use the arguments are checked: \code{url} must be one
#' \code{https} URL to a public host (plain \code{http} only with
#' \code{options(rmoriebricklayer.allow_http = TRUE)}; loopback, private,
#' link-local and metadata addresses are refused), the directory of
#' \code{dest} must exist and be writable, and \code{timeout} must be at
#' least one second. The compiled layer then resolves the host, pins the
#' connection to the checked addresses and re-checks every redirect.
#'
#' If the live download fails, the fallback is the \code{wayback} URL when
#' given, else a snapshot looked up through the Wayback availability API
#' (as [wayback_snapshot_url_native()] does).
#' \code{dest} is overwritten. A
#' spinner is drawn on stderr while waiting, unless
#' \code{options(morie.quiet = TRUE)}.
#'
#' Errors: invalid arguments as above; and, when both sources fail, an error
#' saying whether the live URL could not be reached or answered an HTTP
#' status, and whether the Wayback Machine had no snapshot or its copy could
#' not be downloaded.
#'
#' @param url Live source URL, a single \code{https} string.
#' @param dest Destination file path, a single string; its directory must
#'   exist.
#' @param wayback Optional explicit Wayback snapshot URL, a string.
#'   \code{""} (default) or \code{NULL} auto-resolves one via
#'   \code{\link{wayback_snapshot_url}}'s API when the live download fails.
#' @param timeout Per-request timeout in seconds, a positive whole number
#'   (default 120).
#' @return Invisibly, \code{"live"} or \code{"wayback"}: the source that
#'   served the file. Throws on total failure.
#' @examples
#' # Inputs are validated before any network access:
#' try(bricklayer_fetch("", tempfile()))          # empty url -> error
#' try(bricklayer_fetch("ftp://example.org/data.csv", tempfile()))
#' try(bricklayer_fetch("https://127.0.0.1/data.csv", tempfile()))
#' try(bricklayer_fetch("https://example.org/data.csv",
#'                      file.path(tempdir(), "no-such-dir", "data.csv")))
#'
#' \dontrun{
#' # needs the network
#' dst <- tempfile(fileext = ".xlsx")
#'
#' # Live download; auto-resolves a Wayback snapshot only if the live URL fails.
#' bricklayer_fetch(
#'   paste0("https://www.cihi.ca/sites/default/files/document/",
#'          "hospital-beds-2024-2025-data-tables-en.xlsx"),
#'   dst)
#'
#' # Pin an explicit Wayback snapshot to fall back to, and a shorter timeout.
#' bricklayer_fetch(
#'   "https://example.org/rotated-file.csv", tempfile(fileext = ".csv"),
#'   wayback = "https://web.archive.org/web/2024id_/https://example.org/rotated-file.csv",
#'   timeout = 60)
#'
#' # The return value tells you which source served the file.
#' status <- bricklayer_fetch("https://cloud.r-project.org/", tempfile())
#' status   # "live" or "wayback"
#' }
#' @export
bricklayer_fetch <- function(url, dest, wayback = "", timeout = 120L) {
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("`url` must be one non-empty URL string", call. = FALSE)
  }
  if (!is.character(dest) || length(dest) != 1L || is.na(dest) || !nzchar(dest)) {
    stop("`dest` must be one non-empty file path", call. = FALSE)
  }
  # what can be told before any download: the URL, the destination, the timeout
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    stop(sprintf("bricklayer_fetch: '%s' is not an http(s) URL", url), call. = FALSE)
  }
  # the same gate every other entry point has (the compiled layer checks
  # again, resolves, pins and re-checks each redirect)
  .rmbl_check_public_url(url, "url")
  d <- dirname(path.expand(dest))
  if (!dir.exists(d) || file.access(d, 2L) != 0L) {
    stop(sprintf("bricklayer_fetch: cannot write %s (%s)", dest,
                 if (!dir.exists(d)) "its directory does not exist" else "no permission"), call. = FALSE)
  }
  timeout <- suppressWarnings(as.integer(timeout))
  if (length(timeout) != 1L || is.na(timeout) || timeout < 1L) {
    stop("`timeout` must be a positive number of seconds", call. = FALSE)
  }
  code <- .bl_net(url, .Call(C_rmbl_fetch_fallback, url,
                            if (is.null(wayback)) "" else as.character(wayback),
                            dest, as.integer(timeout)))
  if (code == 0L) return(invisible("live"))
  if (code == 1L) return(invisible("wayback"))
  v <- -code
  live <- v %/% 10L
  stop(sprintf("bricklayer_fetch: %s; %s",
               if (live == 1L) sprintf("could not reach %s", url) else sprintf("%s answered HTTP %d", url, live),
               if (v %% 10L == 1L) "the Wayback fallback failed too (its copy could not be downloaded)"
               else "the Wayback fallback failed (the Wayback Machine has no snapshot of it, or did not answer)"),
       call. = FALSE)
}

#' Resolve a Wayback Machine snapshot URL (C++/libcurl)
#'
#' Queries the Internet Archive \dQuote{available} API for the closest
#' archived snapshot of \code{url} and returns its address, or \code{NULL}
#' when nothing is archived. Use it to find an archived copy of a data file
#' or page that has moved or been removed. C++ backend; supersedes the older
#' R-level resolver \code{\link{wayback_snapshot_url}}, which is kept for
#' the pure-R path and now parses with the package's own JSON codec.
#'
#' @details
#' \code{url} is only a query parameter of the lookup, never fetched, so a
#' plain \code{http://} page can be looked up; a local or private address is
#' still refused. One request is made to \code{https://archive.org/}; the
#' most recent snapshot is asked for (there is no timestamp argument; use
#' [wayback_snapshot_url()] for one). Any network
#' failure, and a URL that was
#' never archived, give \code{NULL} rather than an error. A spinner is drawn
#' on stderr while waiting, unless \code{options(morie.quiet = TRUE)}.
#'
#' Errors: \code{url} not a single non-empty string; a local or private
#' address.
#'
#' @param url URL to resolve, a single string (\code{http} or \code{https}).
#' @param timeout Request timeout in seconds, default 30.
#' @return The \code{https} snapshot URL (a length-1 character string), or
#'   \code{NULL} if none is archived or the lookup failed.
#' @examples
#' # Input is validated before any network call:
#' try(wayback_snapshot_url_native(""))     # empty url -> error
#' try(wayback_snapshot_url_native("http://localhost/report.csv"))
#'
#' \dontrun{
#' # needs the network; any network failure returns NULL rather than erroring.
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
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("`url` must be a single non-empty string", call. = FALSE)
  }
  # the page is a query parameter of archive.org's lookup, never fetched: a plain-http page is looked
  # up as it is (an http:// URL was refused and never found; review of e57fed5); a private address
  # is still refused
  .rmbl_check_public_url(url, "url", allow_http = TRUE)
  snap <- .bl_net("https://archive.org/", .Call(C_rmbl_wayback, url, as.integer(timeout)))
  if (is.character(snap) && nzchar(snap)) snap else NULL
}
