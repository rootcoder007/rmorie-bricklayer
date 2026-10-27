# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fetch a URL to disk with an Internet Archive fallback (C++/libcurl)
#'
#' The shared data-fetch foundation of the morie ecosystem. Downloads
#' \code{url} to \code{dest}; if the live download fails (404, network),
#' it retries the Wayback Machine snapshot -- so a rotated or removed
#' source file (CIHI, open-data portals) stays retrievable. Backed by the
#' package's C++ kernel \code{rmbl_fetch_with_fallback} (libcurl), which
#' \pkg{rmorie} and \pkg{morie} share through \code{LinkingTo}. The return
#' value says which source served the file, so a report can note that it
#' used an archived copy.
#'
#' @details
#' Before any network use the arguments are checked: \code{url} must be one
#' \code{https} URL to a public host (plain \code{http} only when the option
#' \code{rmoriebricklayer.allowhttp} is \code{TRUE}; loopback, private,
#' link-local and metadata addresses are refused), the directory of
#' \code{dest} must exist and be writable, and \code{tmout} must be at
#' least one second. The compiled layer then resolves the host, pins the
#' connection to the checked addresses and re-checks every redirect.
#'
#' If the live download fails, the fallback is the \code{wb} URL when
#' given, else a snapshot looked up through the Wayback availability API
#' (as [wbsnpnat()] does).
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
#' @param wb Optional explicit Wayback snapshot URL, a string.
#'   \code{""} (default) or \code{NULL} auto-resolves one via
#'   \code{\link{wbsnpurl}}'s API when the live download fails.
#' @param tmout Per-request timeout in seconds, a positive whole number
#'   (default 120).
#' @return Invisibly, \code{"live"} or \code{"wayback"}: the source that
#'   served the file. Throws on total failure.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Inputs are validated before any network access:
#' try(blfetch("", tempfile()))          # empty url -> error
#' try(blfetch("ftp://example.org/data.csv", tempfile()))
#' try(blfetch("https://127.0.0.1/data.csv", tempfile()))
#' try(blfetch("https://example.org/data.csv",
#'                      file.path(tempdir(), "no-such-dir", "data.csv")))
#'
#' @examplesIf interactive()
#' # needs the network
#' dst <- tempfile(fileext = ".xlsx")
#'
#' # Live download; auto-resolves a Wayback snapshot only if the live URL fails.
#' blfetch(
#'   paste0(
#'     "https://www.cihi.ca/sites/default/files/document/",
#'     "hospital-beds-2024-2025-data-tables-en.xlsx"
#'   ),
#'   dst
#' )
#'
#' # Pin an explicit Wayback snapshot to fall back to, and a shorter timeout.
#' blfetch(
#'   "https://example.org/rotated-file.csv",
#'   tempfile(fileext = ".csv"),
#'   wb = paste0(
#'     "https://web.archive.org/web/2024id_/https://example.org/rotated-fil",
#'     "e.csv"
#'   ),
#'   tmout = 60
#' )
#'
#' # The return value tells you which source served the file.
#' status <- blfetch("https://cloud.r-project.org/", tempfile())
#' status # "live" or "wayback"
#' @export
blfetch <- function(url, dest, wb = "", tmout = 120L) {
  tmout <- .bl_fetch_check(url, dest, tmout)
  code <- .bl_net(
    url,
    .Call(
      C_rmbl_fetch_fallback,
      url,
      if (is.null(wb)) "" else as.character(wb),
      dest,
      as.integer(tmout),
      ""
    )
  )
  if (code == 0L) {
    return(invisible("live"))
  }
  if (code == 1L) {
    return(invisible("wayback"))
  }
  .bl_fetch_fail(code, url, dest)
}

#' Resolve a Wayback Machine snapshot URL (C++/libcurl)
#'
#' Queries the Internet Archive \dQuote{available} API for the closest
#' archived snapshot of \code{url} and returns its address, or \code{NULL}
#' when nothing is archived. Use it to find an archived copy of a data file
#' or page that has moved or been removed. C++ backend; supersedes the older
#' R-level resolver \code{\link{wbsnpurl}}, which is kept for
#' the pure-R path and now parses with the package's own JSON codec.
#'
#' @details
#' \code{url} is only a query parameter of the lookup, never fetched, so a
#' plain \code{http://} page can be looked up; a local or private address is
#' still refused. One request is made to \code{https://archive.org/}; the
#' most recent snapshot is asked for (there is no timestamp argument; use
#' [wbsnpurl()] for one). Any network
#' failure, and a URL that was
#' never archived, give \code{NULL} rather than an error. A spinner is drawn
#' on stderr while waiting, unless \code{options(morie.quiet = TRUE)}.
#'
#' Errors: \code{url} not a single non-empty string; a local or private
#' address.
#'
#' @param url URL to resolve, a single string (\code{http} or \code{https}).
#' @param tmout Request timeout in seconds, default 30.
#' @return The \code{https} snapshot URL (a length-1 character string), or
#'   \code{NULL} if none is archived or the lookup failed.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Input is validated before any network call:
#' try(wbsnpnat(""))     # empty url -> error
#' try(wbsnpnat("http://localhost/report.csv"))
#'
#' @examplesIf interactive()
#' # needs the network; any network failure returns NULL rather than erroring.
#' # Closest archived snapshot of a live page (or NULL if none archived).
#' wbsnpnat("https://www.r-project.org/")
#'
#' # A shorter timeout for a quick lookup.
#' wbsnpnat("https://cloud.r-project.org/", tmout = 10)
#'
#' # A never-archived URL returns NULL rather than erroring.
#' wbsnpnat("https://example.invalid/never-archived")
#' @export
wbsnpnat <- function(url, tmout = 30L) {
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("`url` must be a single non-empty string", call. = FALSE)
  }
  # the page is a query parameter of archive.org's lookup, never fetched: a
  # plain-http page is looked up as it is (an http:// URL was refused and never
  # found; review of e57fed5); a private address is still refused
  .rmbl_check_public_url(url, "url", allow_http = TRUE)
  snap <- .bl_net(
    "https://archive.org/",
    .Call(C_rmbl_wayback, url, as.integer(tmout), "")
  )
  if (is.character(snap) && nzchar(snap)) snap else NULL
}

#' blfetch()'s URL: http(s), and public.
#' @param url As for blfetch().
#' @noRd
.bl_fetch_check_url <- function(url) {
  # what can be told before any download: the URL, the destination, the timeout
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    stop(sprintf("blfetch: '%s' is not an http(s) URL", url), call. = FALSE)
  }
  # the same gate every other entry point has (the compiled layer checks
  # again, resolves, pins and re-checks each redirect)
  .rmbl_check_public_url(url, "url")
  invisible(NULL)
}

#' blfetch()'s destination: in a directory that exists and can be written.
#' @param dest As for blfetch().
#' @noRd
.bl_fetch_check_dest <- function(dest) {
  d <- dirname(path.expand(dest))
  if (!dir.exists(d) || file.access(d, 2L) != 0L) {
    stop(
      sprintf(
        "blfetch: cannot write %s (%s)",
        dest,
        if (dir.exists(d)) "no permission" else "its directory does not exist"
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' blfetch()'s URL, destination and timeout, checked before any download.
#' @param url,dest,tmout As for blfetch().
#' @return The timeout, in whole seconds.
#' @noRd
.bl_fetch_check <- function(url, dest, tmout) {
  if (!is.character(url) || length(url) != 1L || is.na(url) || !nzchar(url)) {
    stop("`url` must be one non-empty URL string", call. = FALSE)
  }
  if (
    !is.character(dest) || length(dest) != 1L || is.na(dest) || !nzchar(dest)
  ) {
    stop("`dest` must be one non-empty file path", call. = FALSE)
  }
  .bl_fetch_check_url(url)
  .bl_fetch_check_dest(dest)
  tmout <- suppressWarnings(as.integer(tmout))
  if (length(tmout) != 1L || is.na(tmout) || tmout < 1L) {
    stop("`tmout` must be a positive number of seconds", call. = FALSE)
  }
  tmout
}

#' blfetch()'s error for a failed download: where it failed, and whether the
#' Wayback fallback was tried.
#' @param code The compiled layer's code.
#' @param url,dest As for blfetch().
#' @noRd
.bl_fetch_fail <- function(code, url, dest) {
  # the destination could not be written: a local failure, and no Wayback lookup
  # was made
  if (code == -2L) {
    stop(
      sprintf(
        "blfetch: cannot write %s (the download could not be saved there)",
        dest
      ),
      call. = FALSE
    )
  }
  v <- -code
  live <- v %/% 10L
  stop(
    sprintf(
      "blfetch: %s; %s",
      if (live == 1L) {
        sprintf("could not reach %s", url)
      } else {
        sprintf("%s answered HTTP %d", url, live)
      },
      if (v %% 10L == 1L) {
        "the Wayback fallback failed too (its copy could not be downloaded)"
      } else {
        paste0(
          "the Wayback fallback failed (the Wayback Machine has no ",
          "snapshot of it, or did not answer)"
        )
      }
    ),
    call. = FALSE
  )
}
