# Download with live progress on stderr, one look across morie, rmorie,
# rmoriebricklayer and rmoriedata: a bar with percent, size and rate while a
# person is watching (an interactive session, or the command line, which sets
# options(morie.progress = TRUE)); milestone lines when stderr is not a
# terminal; nothing when quiet. options(morie.quiet = TRUE) silences it.

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
#' @details Progress is an animated bar, redrawn in place, when the console can
#' redraw a line: a terminal, or the RStudio, Positron, R.app or RKWard console
#' (never a knitr or Jupyter notebook; the options
#' \code{rmoriebricklayer.dynamic} or \code{cli.dynamic}, or the environment
#' variable \code{R_CLI_DYNAMIC}, override the choice). In the RStudio or
#' Positron console the bar is drawn on stdout, elsewhere on stderr. Otherwise
#' milestone lines go to stderr (every 10 percent, or every 50 MB when the size
#' is unknown), and nothing is shown when quiet. By default output is shown in
#' an interactive session or when \code{options(morie.progress = TRUE)} is set,
#' and suppressed by \code{options(morie.quiet = TRUE)}.
#'
#' Network: the transfer runs in the package's compiled HTTP client. The URL is
#' checked, its host resolved and pinned, and every redirect is checked again
#' (no switch from https to http; credentials are not passed to another host).
#' Plain \code{http://} is allowed only when \code{rmoriebricklayer.allowhttp},
#' an option, is \code{TRUE}. A transfer slower than 64 bytes a second for 30
#' seconds is abandoned. A \code{file://} URL is copied locally through the same
#' progress display, only with \code{allowfile = TRUE}.
#'
#' Errors: a URL that is not https (or allowed http/file), or that points at a
#' loopback, link-local or private address; \code{headers} not a named character
#' vector; \code{tmout} below 1 or above 2147483647; \code{maxbytes} below 1; a
#' network failure; an HTTP status of 400 or more; a body larger than
#' \code{maxbytes}. \code{dest} is overwritten. A server busy for a moment (HTTP
#' 429, 500, 502, 503 or 504) is asked again up to three times, after the wait
#' its \code{Retry-After} header asks for (at most a minute) or else 1, 2 and 4
#' seconds.
#'
#' @param url The URL, \code{https}. The option
#'   \code{rmoriebricklayer.allowhttp} set to \code{TRUE} also allows plain
#'   \code{http}. A loopback, link-local or private address is refused.
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
#' @examplesIf isTRUE(getOption("rmbl.examples"))
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
bldl <- function(
  url,
  dest,
  headers = NULL,
  label = basename(dest),
  size = NULL,
  tmout = 3600,
  quiet = NULL,
  tty = NULL,
  allowfile = FALSE,
  maxbytes = 2^31
) {
  .rmbl_no_fn(url = url)
  # the capsule path's transport: https only, never a local or private
  # address, and file:// only when the caller says so (an offline test)
  url <- .rmbl_check_public_url(url, "url", allow_file = allowfile)
  if (is.null(quiet)) {
    quiet <- .bl_dl_quiet()
  }
  dest <- .rmbl_out_file(dest, "dest", connection = FALSE)
  # as.character() of a closure; checked once `dest`, its default, is
  .rmbl_no_fn(label = label)
  quiet <- .rmbl_flag1(quiet, "quiet")
  size <- .bl_dl_size(size)
  # a console that redraws a line in place: a terminal, or the RStudio, Positron
  # or R.app console
  auto_tty <- is.null(tty)
  if (auto_tty) {
    tty <- .bl_stderr_tty()
  }
  a <- .bl_dl_args(headers, tmout, maxbytes)
  st <- .bl_dl_state(size, quiet, tty, auto_tty, label)
  # a transfer that fails or is interrupted ends its bar with a cross
  on.exit(if (!is.null(st$anim)) .bl_anim_done(st$anim, ok = FALSE), add = TRUE)
  if (!quiet && !tty) {
    .bl_dl_announce(label, size)
  }
  # The transport calls this about ten times a second with the bytes so far
  # and the total the server announced (0 when it did not).
  draw <- function(got, total) .bl_dl_draw(st, got, total)
  got <- if (grepl("^file://", url, ignore.case = TRUE)) {
    .bl_dl_file(url, dest, size, draw)
  } else {
    .bl_dl_net(url, dest, a, draw, quiet, label)
  }
  if (!quiet) {
    .bl_dl_finish(st, got)
  }
  invisible(dest)
}

#' What bldl()'s progress callback updates between calls.
#'
#' The size once the server announces it, the bar, and the last milestone
#' printed without a terminal.
#' @param size,quiet,tty,label As for bldl(), checked.
#' @param auto_tty Whether `tty` was detected rather than given.
#' @return An environment.
#' @noRd
.bl_dl_state <- function(size, quiet, tty, auto_tty, label) {
  t0 <- proc.time()[["elapsed"]]
  st <- new.env(parent = emptyenv())
  st$size <- size
  st$mile <- 0L
  st$anim <- NULL
  st$quiet <- quiet
  st$tty <- tty
  st$auto_tty <- auto_tty
  # the label and the URL are the caller's text: escaped before printing
  st$label <- .rmbl_ctl_escape(as.character(label))
  st$t0 <- t0
  st
}

#' Prints the line that starts a download when there is no terminal.
#' @param label,size As for bldl().
#' @return NULL, invisibly.
#' @noRd
.bl_dl_announce <- function(label, size) {
  cat(
    sprintf(
      "%s: downloading%s\n",
      .rmbl_ctl_escape(as.character(label)),
      if (is.finite(size)) paste0(" ", .bl_fmt_bytes(size)) else ""
    ),
    file = stderr()
  )
  invisible(NULL)
}

#' Tells whether a download should draw no progress line.
#' @return `TRUE` when the session is quiet or not interactive and progress is
#'   not forced on.
#' @noRd
.bl_dl_quiet <- function() {
  isTRUE(getOption("morie.quiet")) ||
    !(interactive() || isTRUE(getOption("morie.progress")))
}

#' Formats a byte count in B, KB, MB or GB.
#' @param n The number of bytes to format, `?` when not finite.
#' @return A string; \dQuote{?} for a count that is not finite.
#' @noRd
.bl_fmt_bytes <- function(n) {
  if (!is.finite(n)) {
    return("?")
  }
  units <- c("B", "KB", "MB", "GB")
  i <- 1L
  while (n >= 1024 && i < 4L) {
    n <- n / 1024
    i <- i + 1L
  }
  if (i == 1L) {
    return(sprintf("%d B", as.integer(n)))
  }
  sprintf("%.1f %s", n, units[i])
}

#' Formats one line of a download progress display.
#' @param label The text shown before the bar.
#' @param got The amount received so far.
#' @param size The total size, or a non-finite value when it is unknown (a
#'   spinner is drawn).
#' @param t0 The elapsed time at the start, from `proc.time()`.
#' @param spin The spinner step.
#' @param unit The unit of `got` and `size`; \code{"B"} formats them as bytes.
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
  rate <- sprintf("%s/s", fmt(got / elapsed))
  if (is.finite(size) && size > 0) {
    pct <- min(100L, as.integer((100 * got) %/% size))
    n <- pct %/% 4L
    sprintf(
      "%s  [%s%s] %3d%%  %s / %s  %s",
      label,
      strrep("#", n),
      strrep(".", 25L - n),
      pct,
      fmt(got),
      fmt(size),
      rate
    )
  } else {
    sprintf(
      "%s  %s %s  %s",
      label,
      c("|", "/", "-", "\\")[spin %% 4L + 1L],
      fmt(got),
      rate
    )
  }
}

#' The size the bar is drawn for: text that is no number means no size, as
#' before; a list, a data frame or a function is refused in words.
#' @param size As for bldl().
#' @return The size, or NA.
#' @noRd
.bl_dl_size <- function(size) {
  size <- if (is.null(size)) {
    NA_real_
  } else if (is.character(size)) {
    suppressWarnings(as.numeric(size[1L]))
  } else {
    .rmbl_num(size, "size")[1L]
  }
  if (!is.finite(size) || size <= 0) NA_real_ else size
}

#' bldl()'s headers, time limit and byte cap, checked.
#' @param headers,tmout,maxbytes As for bldl().
#' @return A list: hdr_lines, tmout and maxbytes.
#' @noRd
.bl_dl_args <- function(headers, tmout, maxbytes) {
  hdr_lines <- NULL
  if (!is.null(headers)) {
    if (
      !is.character(headers) ||
        anyNA(headers) ||
        is.null(names(headers)) ||
        !all(nzchar(names(headers)))
    ) {
      stop("`headers` must be a named character vector", call. = FALSE)
    }
    hdr_lines <- paste0(names(headers), ": ", headers)
  }
  tmout <- .rmbl_num(tmout, "tmout")[1L]
  if (is.na(tmout) || tmout < 1) {
    stop("`tmout` must be at least one second", call. = FALSE)
  }
  if (tmout > .Machine$integer.max) {
    stop("`tmout` must be at most 2147483647 seconds", call. = FALSE)
  }
  maxbytes <- .rmbl_num(maxbytes, "maxbytes")[1L]
  if (is.na(maxbytes) || maxbytes < 1) {
    stop("`maxbytes` must be a number of bytes, at least one", call. = FALSE)
  }
  list(hdr_lines = hdr_lines, tmout = tmout, maxbytes = maxbytes)
}

#' Draws the download's progress: the animated bar in a terminal, a line at
#' each tenth (or each 50 MiB) otherwise.
#' @param st The download's state.
#' @param got The bytes so far.
#' @param total The size the server announced (0 when it did not).
#' @noRd
.bl_dl_draw <- function(st, got, total) {
  if (st$quiet) {
    return(invisible(NULL))
  }
  if (is.na(st$size) && is.finite(total) && total > 0) {
    st$size <- total
  }
  size <- st$size
  if (st$tty) {
    # the animated bar from the native renderer once the size is known; until
    # then a spinner with the bytes so far
    if (is.null(st$anim)) {
      st$anim <- .bl_anim_new(
        st$label,
        if (is.finite(size)) size else 0,
        quiet = FALSE,
        tty = if (st$auto_tty) NULL else TRUE,
        unit = "B"
      )
    }
    st$anim$total <- if (is.finite(size)) size else 0
    .bl_anim_update(st$anim, got, "")
    return(invisible(NULL))
  }
  step <- if (is.finite(size)) {
    as.integer((10 * got) %/% size)
  } else {
    as.integer(got %/% 52428800)
  }
  if (step > st$mile) {
    st$mile <- step
    cat(
      "  ",
      .bl_dl_line(st$label, got, size, st$t0, 0L),
      "\n",
      sep = "",
      file = stderr()
    )
  }
  invisible(NULL)
}

#' An offline test's local file, copied through the same bar.
#' @param url The file:// address.
#' @param dest The file the local source is copied to.
#' @param size The size, or NA.
#' @param draw The progress callback.
#' @return The bytes copied.
#' @noRd
.bl_dl_file <- function(url, dest, size, draw) {
  con <- file(sub("^file://", "", url, ignore.case = TRUE), open = "rb")
  on.exit(close(con), add = TRUE)
  out <- file(dest, open = "wb")
  on.exit(close(out), add = TRUE)
  got <- 0
  repeat {
    chunk <- readBin(con, what = "raw", n = 1048576L)
    if (!length(chunk)) {
      break
    }
    writeBin(chunk, out)
    got <- got + length(chunk)
    draw(got, if (is.na(size)) 0 else size)
  }
  got
}

#' A download through the package's transport.
#'
#' Every network byte of the package goes through src/rmbl_fetch.cpp: the URL is
#' checked again there, resolved and pinned, every redirect hop is re-checked
#' (no https -> http, credentials dropped across hosts) and the body is capped;
#' base R's url() did none of that (0.5.7 review) a server busy for a moment
#' (429, 500, 502, 503 or 504; data.rmorie.com answers 503 when many clients
#' fetch one table at once) is asked again up to three times, after its
#' Retry-After (at most a minute) or else 1, 2 and 4 seconds with jitter; any
#' other answer is final
#' @param url,dest,quiet,label As for bldl().
#' @param a The checked arguments (.bl_dl_args()).
#' @param draw The progress callback.
#' @return The bytes written.
#' @noRd
.bl_dl_net <- function(url, dest, a, draw, quiet, label) {
  for (i in 0:3) {
    res <- .bl_http_download(
      url,
      dest,
      as.integer(a$tmout),
      a$hdr_lines,
      draw,
      a$maxbytes,
      FALSE
    )
    if (i == 3L || !(res$status %in% c(429L, 500L, 502L, 503L, 504L))) {
      break
    }
    wait <- .bl_wb_retry_after(res)
    if (is.na(wait)) {
      wait <- 2^i * (0.5 + (as.numeric(Sys.time()) * 1000) %% 1000 / 1000)
    }
    wait <- min(wait, 60)
    if (!quiet) {
      cat(
        sprintf(
          "%s: %s answered HTTP %d; trying again in %.0f s\n",
          .rmbl_ctl_escape(as.character(label)),
          .rmbl_ctl_escape(url),
          res$status,
          wait
        ),
        file = stderr()
      )
    }
    .bl_sleep(wait)
  }
  if (res$status < 0) {
    stop(sprintf("bldl: %s: %s", url, res$error), call. = FALSE)
  }
  if (res$status >= 400) {
    stop(sprintf("bldl: %s answered HTTP %d", url, res$status), call. = FALSE)
  }
  res$bytes
}

#' The download's closing line: the bar ended with a check, or a line.
#' @param st The download's state.
#' @param got The bytes written.
#' @noRd
.bl_dl_finish <- function(st, got) {
  took <- proc.time()[["elapsed"]] - st$t0
  if (!is.null(st$anim)) {
    .bl_anim_done(
      st$anim,
      sprintf(
        "%s: %s in %s",
        st$label,
        .bl_fmt_bytes(got),
        .bl_fmt_elapsed(took)
      )
    )
    st$anim <- NULL
  } else {
    cat(
      sprintf("%s: %s in %.0f s\n", st$label, .bl_fmt_bytes(got), took),
      file = stderr()
    )
  }
}

#' The one call into the native transport, named so a test can stand a reply in
#' for it
#' @param url The URL the native transport fetches.
#' @param dest The file the response body is written to.
#' @param tmout The timeout in seconds.
#' @param headers The request headers.
#' @param draw Whether to draw a progress line.
#' @param maxbytes The largest body accepted.
#' @param head_only Whether to send a HEAD request only.
#' @return What the native transport returns.
#' @noRd
.bl_http_download <- function(
  url,
  dest,
  tmout,
  headers,
  draw,
  maxbytes,
  head_only
) {
  .Call(
    C_rmbl_http_download,
    url,
    dest,
    tmout,
    headers,
    draw,
    maxbytes,
    head_only
  )
}

#' Sleeps for a number of seconds; named so a test can stand in for the wait
#' @param s Seconds.
#' @noRd
.bl_sleep <- function(s) Sys.sleep(s)
