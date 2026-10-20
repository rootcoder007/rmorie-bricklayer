# Download with live progress on stderr, one look across morie, rmorie,
# rmoriebricklayer and rmoriedata: a bar with percent, size and rate while a
# person is watching (an interactive session, or the command line, which sets
# options(morie.progress = TRUE)); milestone lines when stderr is not a
# terminal; nothing when quiet. options(morie.quiet = TRUE) silences it.

#' Tells whether a download should draw no progress line.
#' @return `TRUE` when the session is quiet or not interactive and progress is not forced on.
#' @noRd
.bl_dl_quiet <- function() {
  isTRUE(getOption("morie.quiet")) ||
    !(interactive() || isTRUE(getOption("morie.progress")))
}

#' Formats a byte count in B, KB, MB or GB.
#' @param n The number of bytes.
#' @return A string; "?" for a count that is not finite.
#' @noRd
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

#' Formats one line of a download progress display.
#' @param label The text shown before the bar.
#' @param got The amount received so far.
#' @param size The total size, or a non-finite value when it is unknown (a spinner is drawn).
#' @param t0 The elapsed time at the start, from `proc.time()`.
#' @param spin The spinner step.
#' @param unit The unit of `got` and `size`; "B" formats them as bytes.
#' @return A string.
#' @noRd
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
#' @description
#' Downloads one file from the web to a local path, showing a progress bar
#' (percent, size and rate) while a person is watching. It is the single
#' download routine of the package and its sibling packages, and it applies
#' the package's network safety rules: HTTPS only, no local or private
#' addresses, a size cap, and checked redirects. Use it when a script must
#' fetch a source file and you want a visible, safe transfer.
#'
#' @details
#' Progress is an animated bar, redrawn in place, when the console can
#' redraw a line: a terminal, or the RStudio, Positron, R.app or RKWard
#' console (never a knitr or Jupyter notebook; the options
#' \code{rmoriebricklayer.dynamic} or \code{cli.dynamic}, or the environment
#' variable \code{R_CLI_DYNAMIC}, override the choice). In the RStudio or
#' Positron console the bar is drawn on stdout, elsewhere on stderr.
#' Otherwise milestone lines go to stderr (every 10 percent, or every 50 MB
#' when the size is unknown), and nothing is shown when quiet. By default output is shown
#' in an interactive session or when \code{options(morie.progress = TRUE)}
#' is set, and suppressed by \code{options(morie.quiet = TRUE)}.
#'
#' Network: the transfer runs in the package's compiled HTTP client. The
#' URL is checked, its host resolved and pinned, and every redirect is
#' checked again (no switch from https to http; credentials are not passed
#' to another host). Plain \code{http://} is allowed only when
#' \code{rmoriebricklayer.allowhttp}, an option, is \code{TRUE}. A transfer slower than
#' 64 bytes a second for 30 seconds is abandoned. A \code{file://} URL is
#' copied locally through the same progress display, only with
#' \code{allowfile = TRUE}.
#'
#' Errors: a URL that is not https (or allowed http/file), or that points at
#' a loopback, link-local or private address; \code{headers} not a named
#' character vector; \code{tmout} below 1 or above 2147483647;
#' \code{maxbytes} below 1; a network failure; an HTTP status of 400 or
#' more; a body larger than \code{maxbytes}. \code{dest} is overwritten.
#'
#' @param url The URL, \code{https}. The option \code{rmoriebricklayer.allowhttp}
#'   set to \code{TRUE} also allows plain \code{http}. A loopback,
#'   link-local or private address is refused.
#' @param maxbytes Most bytes the body may have (default 2 GiB, the
#'   transport's ceiling). A body past it, chunked or not, ends the transfer
#'   with an error and leaves nothing behind: a caller that expects a small
#'   file should say so.
#' @param allowfile Logical, default \code{FALSE}: accept a \code{file://}
#'   URL (for offline tests).
#' @param dest Character string: the path to write.
#' @param headers Character vector of request headers, every element named
#'   (name = header, value = its value), or \code{NULL} (the default).
#' @param label Text shown in front of the bar; the file name by default.
#' @param size Expected size in bytes when known (a percent bar instead of a
#'   spinner); otherwise the size the server announces is used.
#' @param tmout Seconds allowed for the whole transfer: a whole number from 1
#'   to 2147483647, default 3600. A transfer slower than 64 bytes a second
#'   for 30 seconds is ended before that.
#' @param quiet \code{TRUE}, \code{FALSE}, or \code{NULL} (the default) to
#'   follow the session and options.
#' @param tty Draw the live bar (\code{TRUE}) or print milestone lines
#'   (\code{FALSE}); \code{NULL} (the default) draws the bar when the
#'   console redraws a line in place, as described in Details.
#' @return \code{dest}, invisibly.
#' @seealso \code{\link{blfetch}} for a download with a Wayback
#'   Machine fallback.
#' @examples
#' # offline: a local file through the same routine
#' src <- tempfile(fileext = ".txt")
#' writeLines("hello", src)
#' dest <- tempfile(fileext = ".txt")
#' bldl(paste0("file://", src), dest, quiet = TRUE,
#'                     allowfile = TRUE)
#' readLines(dest)
#'
#' # the safety checks run before any connection is made
#' try(bldl("http://example.org/table.csv", tempfile()))
#' try(bldl("https://127.0.0.1/table.csv", tempfile()))
#' try(bldl(paste0("file://", src), tempfile()))
#'
#' # a real download needs the network
#'
#' @examplesIf interactive()
#' bldl("https://www.ontario.ca/some/open-data/table.csv",
#'                     "table.csv", maxbytes = 50e6)
#' @export
bldl <- function(url, dest, headers = NULL,
                                label = basename(dest), size = NULL,
                                tmout = 3600, quiet = NULL, tty = NULL,
                                allowfile = FALSE, maxbytes = 2^31) {
  .rmbl_no_fn(url = url)
  # the capsule path's transport: https only, never a local or private
  # address, and file:// only when the caller says so (an offline test)
  url <- .rmbl_check_public_url(url, "url", allow_file = allowfile)
  if (is.null(quiet)) quiet <- .bl_dl_quiet()
  dest <- .rmbl_string1(dest, "dest")
  quiet <- .rmbl_flag1(quiet, "quiet")
  # the size only sizes the bar: text that is no number means no size, as before; a list, a data
  # frame or a function is refused in words
  size <- if (is.null(size)) NA_real_ else if (is.character(size)) suppressWarnings(as.numeric(size[1L])) else
    .rmbl_num(size, "size")[1L]
  if (!is.finite(size) || size <= 0) size <- NA_real_
  # a console that redraws a line in place: a terminal, or the RStudio, Positron or R.app console
  auto_tty <- is.null(tty)
  if (auto_tty) tty <- .bl_stderr_tty()
  hdr_lines <- NULL
  if (!is.null(headers)) {
    if (!is.character(headers) || anyNA(headers) || is.null(names(headers)) ||
        any(!nzchar(names(headers)))) {
      stop("`headers` must be a named character vector", call. = FALSE)
    }
    hdr_lines <- paste0(names(headers), ": ", headers)
  }
  tmout <- .rmbl_num(tmout, "tmout")[1L]
  if (is.na(tmout) || tmout < 1) stop("`tmout` must be at least one second", call. = FALSE)
  if (tmout > .Machine$integer.max) stop("`tmout` must be at most 2147483647 seconds", call. = FALSE)
  maxbytes <- .rmbl_num(maxbytes, "maxbytes")[1L]
  if (is.na(maxbytes) || maxbytes < 1) stop("`maxbytes` must be a number of bytes, at least one", call. = FALSE)
  t0 <- proc.time()[["elapsed"]]
  # what the progress callback updates between calls: the size once the server announces it,
  # the bar, and the last milestone printed without a terminal
  st <- new.env(parent = emptyenv())
  st$size <- size
  st$mile <- 0L
  st$anim <- NULL
  # a transfer that fails or is interrupted ends its bar with a cross
  on.exit(if (!is.null(st$anim)) .bl_anim_done(st$anim, ok = FALSE), add = TRUE)
  if (!quiet && !tty) {
    cat(sprintf("%s: downloading%s\n", label,
                if (is.finite(size)) paste0(" ", .bl_fmt_bytes(size)) else ""),
        file = stderr())
  }
  # The transport calls this about ten times a second with the bytes so far
  # and the total the server announced (0 when it did not).
  draw <- function(got, total) {
    if (quiet) return(invisible(NULL))
    if (is.na(st$size) && is.finite(total) && total > 0) st$size <- total
    size <- st$size
    if (tty) {
      # the animated bar from the native renderer once the size is known; until then a spinner
      # with the bytes so far
      if (is.null(st$anim)) {
        st$anim <- .bl_anim_new(label, if (is.finite(size)) size else 0, quiet = FALSE,
                                tty = if (auto_tty) NULL else TRUE, unit = "B")
      }
      st$anim$total <- if (is.finite(size)) size else 0
      .bl_anim_update(st$anim, got, "")
    } else {
      step <- if (is.finite(size)) as.integer((10 * got) %/% size) else
        as.integer(got %/% 52428800)
      if (step > st$mile) {
        st$mile <- step
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
    res <- .bl_http_download(url, dest, as.integer(tmout), hdr_lines, draw, maxbytes, FALSE)
    if (res$status < 0) {
      stop(sprintf("%s: %s", url, res$error), call. = FALSE)
    }
    if (res$status >= 400) {
      stop(sprintf("%s answered HTTP %d", url, res$status), call. = FALSE)
    }
    got <- res$bytes
  }
  if (!quiet) {
    took <- proc.time()[["elapsed"]] - t0
    if (!is.null(st$anim)) {
      .bl_anim_done(st$anim, sprintf("%s: %s in %s", label, .bl_fmt_bytes(got), .bl_fmt_elapsed(took)))
      st$anim <- NULL
    } else {
      cat(sprintf("%s: %s in %.0f s\n", label, .bl_fmt_bytes(got), took), file = stderr())
    }
  }
  invisible(dest)
}

#' The one call into the native transport, named so a test can stand a reply in for it
#' @param url The URL to fetch.
#' @param dest The file to write.
#' @param tmout The timeout in seconds.
#' @param headers The request headers.
#' @param draw Whether to draw a progress line.
#' @param maxbytes The largest body accepted.
#' @param head_only Whether to send a HEAD request only.
#' @return What the native transport returns.
#' @noRd
.bl_http_download <- function(url, dest, tmout, headers, draw, maxbytes, head_only) {
  .Call(C_rmbl_http_download, url, dest, tmout, headers, draw, maxbytes, head_only)
}
