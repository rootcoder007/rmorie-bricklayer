# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A file from its source or, failing that, from any mirror, accepted only when its SHA-256 matches the
# one pinned when the analysis was made. For sources the Internet Archive cannot capture (a server that
# refuses the archive's crawler), the mirrors carry the file instead.

#' Fetch a file from its source or a mirror, verified by its SHA-256
#'
#' Downloads \code{url} to \code{dest}, trying the source first (with its Wayback
#' Machine snapshot as the source's own fallback, as \code{\link{blfetch}}
#' does) and then each mirror in turn, and keeps the first copy whose SHA-256 is
#' \code{sha256}. A copy with another digest is never used: a changed or truncated
#' file is a different file.
#'
#' @details Some servers refuse the Internet Archive's crawler while serving everyone
#' else (Statistics Canada does), so a Wayback snapshot of their files may not exist.
#' The remedy is a capture made from elsewhere, published as a mirror and pinned by
#' its digest. It can be an Internet Archive item, at \code{https://archive.org/download/}
#' followed by \code{<item>/<file>}; the data service; or an
#' institutional repository. Because the digest is checked, a mirror does not have to
#' be trusted: a copy that matches is the same bytes the analysis used, wherever it
#' came from.
#'
#' Without \code{sha256} the first copy that downloads is kept and its digest is
#' returned, to be pinned for the next run.
#'
#' @param url The source URL (https).
#' @param dest The file to write.
#' @param sha256 The expected SHA-256, 64 hexadecimal characters, or \code{NULL}.
#' @param mirrors Further URLs that serve the same file, tried in order after the
#'   source.
#' @param tmout Seconds allowed for each download (default 120).
#' @return Invisibly, a list: \code{source} (\code{"live"}, \code{"wayback"} or
#'   \code{"mirror"}), \code{url} (the URL that served the kept copy), \code{sha256},
#'   \code{bytes}, and \code{tried} (a data frame of every attempt: \code{url},
#'   \code{outcome}).
#' @seealso \code{\link{blfetch}}, \code{\link{sha256file}},
#'   \code{\link{wbsave}}.
#' @examplesIf interactive()
#' # a Statistics Canada table the Wayback Machine cannot capture, with the archive.org copy
#' # made from elsewhere as a mirror
#' item <- "https://archive.org/download/rmorie-statcan-indigenous-tables-2026-10"
#' fetchvrf("https://www150.statcan.gc.ca/n1/tbl/csv/41100063-eng.zip",
#'                file.path(tempdir(), "41100063-eng.zip"),
#'                mirrors = paste0(item, "/41100063-eng.zip"))
#' @export
fetchvrf <- function(url, dest, sha256 = NULL, mirrors = character(), tmout = 120L) {
  url <- .rmbl_string1(url, "url")
  dest <- .rmbl_string1(dest, "dest")
  if (!is.null(sha256)) {
    sha256 <- tolower(.rmbl_string1(sha256, "sha256"))
    if (!grepl("^[0-9a-f]{64}$", sha256)) stop("`sha256` must be 64 hexadecimal characters", call. = FALSE)
  }
  if (!is.character(mirrors) || anyNA(mirrors) || any(!nzchar(mirrors))) {
    stop("`mirrors` must be URLs (a character vector)", call. = FALSE)
  }
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  acc <- new.env(parent = emptyenv())
  acc$tried <- data.frame(url = character(), outcome = character(), stringsAsFactors = FALSE)
  note <- function(u, o) acc$tried[nrow(acc$tried) + 1L, ] <- list(u, o)
  cands <- c(url, mirrors)
  for (i in seq_along(cands)) {
    u <- cands[[i]]
    # the source falls back to its own Wayback snapshot; a mirror is only itself (its own URL as
    # the explicit fallback, so no snapshot lookup is made for it)
    got <- tryCatch(blfetch(u, tmp, wb = if (i == 1L) "" else u, tmout = tmout),
                    error = function(e) structure(conditionMessage(e), class = "rmbl_fail"))
    if (inherits(got, "rmbl_fail")) {
      note(u, paste("failed:", got))
      next
    }
    h <- sha256file(tmp)
    if (!is.null(sha256) && !identical(h, sha256)) {
      note(u, sprintf("refused: SHA-256 %s is not the one pinned", h))
      next
    }
    # rename() warns in its own words when it refuses (a folder, another file system);
    # the copy below is the answer to that, so the warning is not passed on
    if (!suppressWarnings(file.rename(tmp, dest))) {
      if (!file.copy(tmp, dest, overwrite = TRUE)) stop(sprintf("cannot write %s", dest), call. = FALSE)
    }
    note(u, "kept")
    src <- if (i > 1L) "mirror" else as.character(got)
    return(invisible(list(source = src, url = u, sha256 = h, bytes = file.size(dest), tried = acc$tried)))
  }
  stop(sprintf("no source served the file%s:\n%s",
               if (is.null(sha256)) "" else " with the pinned SHA-256",
               paste(sprintf("  %s: %s", acc$tried$url, acc$tried$outcome), collapse = "\n")), call. = FALSE)
}
