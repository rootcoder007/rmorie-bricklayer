# Download with live progress on stderr, one look across morie, rmorie,
# rmoriebricklayer and rmoriedata: a bar with percent, size and rate while a
# person is watching (an interactive session, or the command line, which sets
# options(morie.progress = TRUE)); milestone lines when stderr is not a
# terminal; nothing when quiet. options(morie.quiet = TRUE) silences it.

.bl_dl_quiet <- function() {
  isTRUE(getOption("morie.quiet")) ||
    !(interactive() || isTRUE(getOption("morie.progress")))
}

.bl_fmt_bytes <- function(n) {
  if (!is.finite(n)) return("?")
  units <- c("B", "KB", "MB", "GB")
  i <- 1L
  while (n >= 1024 && i < 4L) {
    n <- n / 1024
    i <- i + 1L
  }
  if (i == 1L) return(sprintf("%d B", as.integer(n)))
  sprintf("%.1f %s", n, units[i])
}

.bl_dl_line <- function(label, got, size, t0, spin, unit = "B") {
  elapsed <- max(proc.time()[["elapsed"]] - t0, 1e-6)
  fmt <- .bl_fmt_bytes
  if (!identical(unit, "B")) {
    fmt <- function(n) {
      paste(format(round(n), big.mark = ",", scientific = FALSE), unit)
    }
  }
  rate <- paste0(fmt(got / elapsed), "/s")
  if (is.finite(size) && size > 0) {
    pct <- min(100L, as.integer((100 * got) %/% size))
    n <- pct %/% 4L
    sprintf("%s  [%s%s] %3d%%  %s / %s  %s", label, strrep("#", n),
            strrep(".", 25L - n), pct, fmt(got), fmt(size), rate)
  } else {
    sprintf("%s  %s %s  %s", label, c("|", "/", "-", "\\")[spin %% 4L + 1L],
            fmt(got), rate)
  }
}

#' Download a file with live progress
#'
#' One download routine for the MORIE family: a bar with percent, size and
#' rate on stderr while a person is watching (an interactive session, or a
#' command line that sets \code{options(morie.progress = TRUE)}), milestone
#' lines when stderr is not a terminal, and nothing when
#' \code{options(morie.quiet = TRUE)} or \code{quiet = TRUE}.
#'
#' @param url The URL: \code{https} (plain \code{http} only with
#'   \code{options(rmoriebricklayer.allow_http = TRUE)}); a loopback,
#'   link-local or private address is refused.
#' @param max_bytes Most bytes the body may have (default 2 GiB, the
#'   transport's ceiling). A body past it, chunked or not, ends the transfer
#'   with an error and leaves nothing behind: a caller that expects a small
#'   file should say so.
#' @param allow_file Accept a \code{file://} URL (default \code{FALSE}).
#' @param dest Path to write.
#' @param headers Character vector of request headers, every element named, or
#'   \code{NULL}.
#' @param label Text shown in front of the bar; the file name by default.
#' @param size Expected size in bytes when known (a percent bar instead of a
#'   spinner).
#' @param timeout Seconds allowed for the whole transfer: a whole number from 1
#'   to 2147483647. A transfer slower than 64 bytes a second for 30 seconds is
#'   ended before that.
#' @param quiet \code{TRUE}, \code{FALSE}, or \code{NULL} to follow the
#'   session and options.
#' @param tty Draw the live bar (\code{TRUE}) or print milestone lines
#'   (\code{FALSE}); \code{NULL} asks whether stderr is a terminal.
#' @return \code{dest}, invisibly.
#' @examples
#' src <- tempfile(fileext = ".txt")
#' writeLines("hello", src)
#' dest <- tempfile(fileext = ".txt")
#' bricklayer_download(paste0("file://", src), dest, quiet = TRUE,
#'                     allow_file = TRUE)
#' readLines(dest)
#' @export
bricklayer_download <- function(url, dest, headers = NULL,
                                label = basename(dest), size = NULL,
                                timeout = 3600, quiet = NULL, tty = NULL,
                                allow_file = FALSE, max_bytes = 2^31) {
  # the capsule path's transport: https only, never a local or private
  # address, and file:// only when the caller says so (an offline test)
  url <- .rmbl_check_public_url(url, "url", allow_file = allow_file)
  if (is.null(quiet)) quiet <- .bl_dl_quiet()
  size <- suppressWarnings(as.numeric(if (is.null(size)) NA else size[[1L]]))
  if (!is.finite(size) || size <= 0) size <- NA_real_
  if (is.null(tty)) tty <- isatty(stderr())
  hdr_lines <- NULL
  if (!is.null(headers)) {
    if (!is.character(headers) || anyNA(headers) || is.null(names(headers)) ||
        any(!nzchar(names(headers)))) {
      stop("`headers` must be a named character vector", call. = FALSE)
    }
    hdr_lines <- paste0(names(headers), ": ", headers)
  }
  timeout <- suppressWarnings(as.numeric(timeout))[1L]
  if (is.na(timeout) || timeout < 1) stop("`timeout` must be at least one second", call. = FALSE)
  if (timeout > .Machine$integer.max) stop("`timeout` must be at most 2147483647 seconds", call. = FALSE)
  max_bytes <- suppressWarnings(as.numeric(max_bytes))[1L]
  if (is.na(max_bytes) || max_bytes < 1) stop("`max_bytes` must be a number of bytes, at least one", call. = FALSE)
  t0 <- proc.time()[["elapsed"]]
  mile <- 0L
  spin <- 0L
  width <- 0L
  if (!quiet && !tty) {
    cat(sprintf("%s: downloading%s\n", label,
                if (is.finite(size)) paste0(" ", .bl_fmt_bytes(size)) else ""),
        file = stderr())
  }
  # The transport calls this about ten times a second with the bytes so far
  # and the total the server announced (0 when it did not).
  draw <- function(got, total) {
    if (quiet) return(invisible(NULL))
    if (is.na(size) && is.finite(total) && total > 0) size <<- total
    if (tty) {
      spin <<- spin + 1L
      line <- .bl_dl_line(label, got, size, t0, spin)
      pad <- strrep(" ", max(0L, width - nchar(line)))
      cat("\r", line, pad, sep = "", file = stderr())
      width <<- max(width, nchar(line))
    } else {
      step <- if (is.finite(size)) as.integer((10 * got) %/% size) else
        as.integer(got %/% 52428800)
      if (step > mile) {
        mile <<- step
        cat("  ", .bl_dl_line(label, got, size, t0, 0L), "\n", sep = "", file = stderr())
      }
    }
    invisible(NULL)
  }
  if (grepl("^file://", url, ignore.case = TRUE)) {
    # an offline test's local file, copied through the same bar
    con <- file(sub("^file://", "", url, ignore.case = TRUE), open = "rb")
    on.exit(close(con), add = TRUE)
    out <- file(dest, open = "wb")
    on.exit(close(out), add = TRUE)
    got <- 0
    repeat {
      chunk <- readBin(con, what = "raw", n = 1048576L)
      if (!length(chunk)) break
      writeBin(chunk, out)
      got <- got + length(chunk)
      draw(got, if (is.na(size)) 0 else size)
    }
  } else {
    # every network byte of the package goes through src/rmbl_fetch.cpp: the
    # URL is checked again there, resolved and pinned, every redirect hop is
    # re-checked (no https -> http, credentials dropped across hosts) and the
    # body is capped; base R's url() did none of that (0.5.7 review)
    res <- .Call(C_rmbl_http_download, url, dest, as.integer(timeout), hdr_lines, draw, max_bytes, FALSE)
    if (res$status < 0) {
      stop(sprintf("%s: %s", url, res$error), call. = FALSE)
    }
    if (res$status >= 400) {
      stop(sprintf("%s answered HTTP %d", url, res$status), call. = FALSE)
    }
    got <- res$bytes
  }
  if (!quiet) {
    if (tty) cat("\r", strrep(" ", width), "\r", sep = "", file = stderr())
    cat(sprintf("%s: %s in %.0f s\n", label, .bl_fmt_bytes(got),
                proc.time()[["elapsed"]] - t0), file = stderr())
  }
  invisible(dest)
}
