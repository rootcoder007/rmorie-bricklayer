# SPDX-License-Identifier: AGPL-3.0-or-later
#
# A file from its source or, failing that, from any mirror, accepted only when
# its SHA-256 matches the one pinned when the analysis was made. For sources the
# Internet Archive cannot capture (a server that refuses the archive's crawler),
# the mirrors carry the file instead.

#' Fetch a file from its source or a mirror, verified by its SHA-256
#'
#' Downloads \code{url} to \code{dest}, trying the source first (with its
#' Wayback Machine snapshot as the source's own fallback, as
#' \code{\link{blfetch}} does) and then each mirror in turn, and keeps the first
#' copy whose SHA-256 is \code{sha256}. A copy with another digest is never
#' used: a changed or truncated file is a different file.
#'
#' @details Some servers refuse the Internet Archive's crawler while serving
#' everyone else (Statistics Canada does), so a Wayback snapshot of their files
#' may not exist. The remedy is a capture made from elsewhere, published as a
#' mirror and pinned by its digest. It can be an Internet Archive item, at
#' \code{https://archive.org/download/} followed by \code{<item>/<file>}; the
#' data service; or an institutional repository. Because the digest is checked,
#' a mirror does not have to be trusted: a copy that matches is the same bytes
#' the analysis used, wherever it came from.
#'
#' Without \code{sha256} the first copy that downloads is kept and its digest is
#' returned, to be pinned for the next run.
#'
#' @param url The source URL (https).
#' @param dest Path the verified file is written to (by way of a `.part` file).
#' @param sha256 The expected SHA-256, 64 hexadecimal characters, or
#'   \code{NULL}.
#' @param mirrors Further URLs that serve the same file, tried in order after
#'   the source.
#' @param tmout Seconds allowed for each download (default 120).
#' @param arcs Archives tried after the source, its Wayback snapshot and the
#'   mirrors: \code{"rmorie"} (archive.rmorie.com, by \code{\link{arcget}}) and
#'   folders written by \code{\link{arccap}} (read from their WARC files), in
#'   order. \code{character()} tries none.
#' @return Invisibly, a list of class \code{rmbl_fetch} (it prints as a
#'   box): \code{source} (\code{"live"}, \code{"wayback"},
#'   \code{"mirror"}, \code{"rmorie"} or \code{"local"}), \code{url} (the URL
#'   that served the kept copy), \code{sha256}, \code{bytes}, and \code{tried}
#'   (a data frame of every attempt: \code{url}, \code{outcome}).
#' @seealso \code{\link{blfetch}}, \code{\link{sha256file}},
#'   \code{\link{wbsave}}.
#' @examplesIf interactive()
#' # a Statistics Canada table the Wayback Machine cannot capture, with the
#' # archive.org copy made from elsewhere as a mirror
#' item <- paste0(
#'   "https://archive.org/download/rmorie-statc",
#'   "an-indigenous-tables-2026-10"
#' )
#' fetchvrf(
#'   "https://www150.statcan.gc.ca/n1/tbl/csv/41100063-eng.zip",
#'   file.path(tempdir(), "41100063-eng.zip"),
#'   mirrors = paste0(item, "/41100063-eng.zip")
#' )
#' @export
fetchvrf <- function(
  url,
  dest,
  sha256 = NULL,
  mirrors = character(),
  tmout = 120L,
  arcs = "rmorie"
) {
  url <- .rmbl_string1(url, "url")
  dest <- .rmbl_out_file(dest, "dest", connection = FALSE)
  sha256 <- .fv_check(sha256, mirrors, arcs)
  tmp <- paste0(dest, ".part")
  on.exit(unlink(tmp), add = TRUE)
  acc <- new.env(parent = emptyenv())
  acc$tried <- data.frame(
    url = character(),
    outcome = character(),
    stringsAsFactors = FALSE
  )
  note <- function(u, o) acc$tried[nrow(acc$tried) + 1L, ] <- list(u, o)
  cands <- c(url, mirrors)
  for (i in seq_along(cands)) {
    r <- .fv_try_live(cands[[i]], i, tmp, dest, sha256, tmout, note, acc)
    if (!is.null(r)) {
      class(r) <- c("rmbl_fetch", "list")
      return(invisible(r))
    }
  }
  # the archives: archive.rmorie.com, then folders written by arccap() (their
  # WARC files)
  for (a in arcs) {
    r <- .fv_try_archive(a, url, tmp, dest, sha256, tmout, note, acc)
    if (!is.null(r)) {
      class(r) <- c("rmbl_fetch", "list")
      return(invisible(r))
    }
  }
  stop(
    sprintf(
      "no source served the file%s:\n%s",
      if (is.null(sha256)) "" else " with the pinned SHA-256",
      paste(
        sprintf("  %s: %s", acc$tried$url, acc$tried$outcome),
        collapse = "\n"
      )
    ),
    call. = FALSE
  )
}

#' @export
format.rmbl_fetch <- function(x, ...) {
  tr <- x$tried
  .rmbl_stat_block(
    "Verified download",
    facts = list(
      Source = x$source,
      URL = .rmbl_printable(x$url),
      `SHA-256` = x$sha256,
      Bytes = x$bytes,
      Attempts = if (is.data.frame(tr)) nrow(tr)
    ),
    reading = sprintf(
      "The kept copy came from the %s source and has the SHA-256 shown.",
      x$source
    ),
    notes = if (is.data.frame(tr) && nrow(tr)) {
      sprintf("%s: %s", .rmbl_printable(tr$url), .rmbl_printable(tr$outcome))
    }
  )
}

# a failed archive or WARC lookup, kept as a value so the next source is tried
# (interrupts still stop)
.bl_arc_fail <- function(e) {
  .bl_unless_interrupted(e, structure(conditionMessage(e), class = "rmbl_fail"))
}

#' fetchvrf()'s pinned digest, mirrors and archives, checked.
#' @param sha256,mirrors,arcs As for fetchvrf().
#' @return The digest, lower case, or NULL.
#' @noRd
.fv_check <- function(sha256, mirrors, arcs) {
  if (!is.null(sha256)) {
    sha256 <- tolower(.rmbl_string1(sha256, "sha256"))
    if (!grepl("^[0-9a-f]{64}$", sha256)) {
      stop("`sha256` must be 64 hexadecimal characters", call. = FALSE)
    }
  }
  if (!is.character(mirrors) || anyNA(mirrors) || !all(nzchar(mirrors))) {
    stop("`mirrors` must be URLs (a character vector)", call. = FALSE)
  }
  if (!is.character(arcs) || anyNA(arcs)) {
    stop('`arcs` must be "rmorie" and/or folders of captures', call. = FALSE)
  }
  sha256
}

#' One live source of fetchvrf(): the URL (with its Wayback fallback) or a
#' mirror, kept when it serves the pinned bytes.
#' @param u The candidate URL fetched live.
#' @param i Its place (1 is the source).
#' @param tmp,dest The part file and the destination.
#' @param sha256,tmout As for fetchvrf().
#' @param note,acc Records an attempt, and where.
#' @return The result, or NULL when the source failed.
#' @noRd
.fv_try_live <- function(u, i, tmp, dest, sha256, tmout, note, acc) {
  # the source falls back to its own Wayback snapshot; a mirror is only itself
  # (its own URL as the explicit fallback, so no snapshot lookup is made for
  # it)
  got <- tryCatch(
    blfetch(u, tmp, wb = if (i == 1L) "" else u, tmout = tmout),
    error = function(e) structure(conditionMessage(e), class = "rmbl_fail")
  )
  if (inherits(got, "rmbl_fail")) {
    note(u, paste("failed:", got))
    return(NULL)
  }
  h <- sha256file(tmp)
  if (!is.null(sha256) && !identical(h, sha256)) {
    note(u, sprintf("refused: SHA-256 %s is not the one pinned", h))
    return(NULL)
  }
  # rename() warns in its own words when it refuses (a folder, another file
  # system); the copy below is the answer to that, so the warning is not
  # passed on
  if (!suppressWarnings(.rmbl_rename(tmp, dest))) {
    if (!file.copy(tmp, dest, overwrite = TRUE)) {
      stop(sprintf("cannot write %s", dest), call. = FALSE)
    }
  }
  note(u, "kept")
  src <- if (i > 1L) "mirror" else as.character(got)
  list(
    source = src,
    url = u,
    sha256 = h,
    bytes = file.size(dest),
    tried = acc$tried
  )
}

#' One archive of fetchvrf(): archive.rmorie.com or a folder of captures.
#' @param a The archive.
#' @param url The source URL.
#' @param tmp,dest The part file and the destination.
#' @param sha256,tmout As for fetchvrf().
#' @param note,acc Records an attempt, and where.
#' @return The result, or NULL when the archive failed.
#' @noRd
.fv_try_archive <- function(a, url, tmp, dest, sha256, tmout, note, acc) {
  if (identical(a, "rmorie")) {
    got <- tryCatch(
      arcget(url, tmp, sha256 = sha256, tmout = tmout),
      error = function(e) .bl_arc_fail(e)
    )
    where <- "archive.rmorie.com"
  } else {
    got <- tryCatch(.bl_warc_get(a, url, tmp, sha256), error = function(e) {
      .bl_arc_fail(e)
    })
    where <- a
  }
  if (inherits(got, "rmbl_fail")) {
    note(where, paste("failed:", got))
    return(NULL)
  }
  h <- sha256file(tmp)
  if (!.bl_move(tmp, dest)) {
    stop(sprintf("cannot write %s", dest), call. = FALSE)
  }
  note(where, "kept")
  list(
    source = if (identical(a, "rmorie")) "rmorie" else "local",
    url = url,
    sha256 = h,
    bytes = file.size(dest),
    tried = acc$tried
  )
}

#' file.rename(), as a seam: the copy fallback is reached in the tests by
#' making it refuse.
#' @param from,to As for file.rename().
#' @return TRUE or FALSE.
#' @noRd
.rmbl_rename <- function(from, to) file.rename(from, to)
