# Live progress, one look for bars, spinners and the line that ends them, in a terminal and in the
# IDE consoles. The bar (drawn by the native renderer, src/rmbl_progress.c) glides to each new value
# in eighths of a cell, a shimmer travels along the filled part and the head pulses while work goes
# on; after it come the percent, the count, the rate, the time so far and, once the rate has
# settled, the time left. One line, redrawn in place at most 12 times a second wherever the console
# can redraw a line (.bl_console()); elsewhere a line at each tenth; nothing when quiet. When the
# work ends the bar gives way to one line: a green check, the label, the result and the time, or a
# red cross when the work failed or was interrupted.

# What the console can show, decided the way the cli package decides it (cli 3.6.6:
# is_dynamic_tty(), rstudio_detect(), num_ansi_colors(), is_utf8_output(), console_width(),
# cli_output_connection(); r-lib/cli main, R/tty.R and R/num-ansi-colors.R), with the Positron
# console treated as the progress package treats it (r-lib/progress a48fc71, R/utils.R: POSITRON=1
# is a console like RStudio's).
#  - dynamic: the line can be redrawn with \r. An override first (options rmoriebricklayer.dynamic
#    or cli.dynamic, then R_CLI_DYNAMIC); never inside knitr, an R Markdown notebook chunk or a
#    Jupyter kernel (knitr.in.progress, rstudio.notebook.executing, jupyter.in_kernel), where a \r
#    is not a redraw; else a terminal (isatty), or with the stream not sunk the RStudio console and
#    its build and render panes, and in an interactive session the Positron console, R.app
#    (R_GUI_APP_VERSION) and RKWard. Rgui on Windows answers isatty() itself.
#  - out: where the frames go. cli writes to stdout in an interactive session with no sink and to
#    stderr otherwise; RStudio and Positron print stderr in their error colour, so in those two
#    consoles (interactive, nothing sunk) the frames go to stdout, as cli and progress do, and to
#    stderr everywhere else (a terminal, a script, a log, capture.output(type = "message")).
#  - colors: the number of colours, 1 for none. An override (rmoriebricklayer.num_colors,
#    cli.num_colors, R_CLI_NUM_COLORS, crayon.enabled = FALSE); NO_COLOR (no-color.org: set and not
#    empty); none inside knitr or into a sunk stream; cli.default_num_colors (set by Positron's
#    kernel, ark, for its console); none in R.app and Rgui; the RStudio console's
#    RSTUDIO_CONSOLE_COLOR; else a terminal's COLORTERM and TERM.
#  - unicode: block and braille characters (rmoriebricklayer.unicode or cli.unicode, else a UTF-8
#    locale).
#  - width: rmoriebricklayer.width or cli.width, else COLUMNS outside RStudio's panes, else
#    getOption("width"), which RStudio keeps at its console's width.
# `tty = TRUE` says "this is a terminal" (dynamic, on stderr, a terminal's colours and characters,
# where cli's own options -- which testthat and knitr set for their output -- do not apply; NO_COLOR,
# R_CLI_NUM_COLORS and this package's options do); `tty = FALSE` says it is not.

# a logical override from options, then an environment variable; NULL when none is set
.bl_opt_flag <- function(opts, env = NULL) {
  for (o in opts) {
    v <- getOption(o)
    if (!is.null(v)) return(isTRUE(as.logical(v)[1L]))
  }
  if (!is.null(env) && nzchar(e <- Sys.getenv(env))) return(isTRUE(as.logical(e)))
  NULL
}

# where R runs inside RStudio: "console", "terminal", "build", "render", "job", "subprocess", or ""
# outside it (cli's rstudio_detect(), without its rstudioapi probe)
# the GUI and whether stdin is a terminal, as bindings the tests can replace (a test cannot change
# .Platform$GUI, and its stdin is never a terminal)
.bl_gui <- function() .Platform$GUI
.bl_stdin_tty <- function() isatty(stdin())

.bl_rstudio <- function() {
  if (!identical(Sys.getenv("RSTUDIO"), "1")) return("")
  if (identical(.bl_gui(), "RStudio") ||
        identical(Sys.getenv("RSTUDIO_SESSION_PID"), as.character(Sys.getpid()))) {
    return("console")
  }
  if (.bl_stdin_tty() && !identical(Sys.getenv("ASCIICAST"), "true")) return("terminal")
  pane <- Sys.getenv("RSTUDIO_CHILD_PROCESS_PANE")
  if (pane %in% c("build", "render", "job")) pane else "subprocess"
}

# interactive(), as a binding the tests can replace
.bl_interactive <- function() interactive()

.bl_console <- function(tty = NULL) {
  rs <- .bl_rstudio()
  positron <- identical(.bl_gui(), "Positron") || identical(Sys.getenv("POSITRON"), "1")
  knit <- isTRUE(getOption("knitr.in.progress")) || isTRUE(getOption("rstudio.notebook.executing"))
  notebook <- knit || isTRUE(getOption("jupyter.in_kernel"))
  free_out <- sink.number() == 0L
  free_err <- sink.number("message") == 2L
  ide <- .bl_interactive() && (rs == "console" || positron)
  out <- if (is.null(tty) && ide && free_out && free_err) "stdout" else "stderr"
  con <- if (out == "stdout") stdout() else stderr()
  free <- if (out == "stdout") free_out else free_err
  ov <- .bl_opt_flag(c("rmoriebricklayer.dynamic", "cli.dynamic"), "R_CLI_DYNAMIC")
  dynamic <- if (!is.null(tty)) {
    isTRUE(tty)
  } else if (!is.null(ov)) {
    ov
  } else if (notebook) {
    FALSE
  } else {
    isatty(con) || (free && (rs %in% c("console", "build", "render") ||
                               (.bl_interactive() && (positron || nzchar(Sys.getenv("R_GUI_APP_VERSION")) ||
                                                    "rkward" %in% .packages()))))
  }
  ov <- .bl_opt_flag(c("rmoriebricklayer.unicode", if (!isTRUE(tty)) "cli.unicode"))
  list(dynamic = dynamic,
       colors = .bl_num_colors(con, rs, positron, knit, free, isTRUE(tty)),
       unicode = if (is.null(ov)) isTRUE(l10n_info()[["UTF-8"]]) else ov,
       out = out, width = .bl_console_width(rs), rstudio = rs, positron = positron, knitr = knit)
}

.bl_num_colors <- function(con, rs, positron, knit, free, tty) {
  n <- function(x) {
    x <- suppressWarnings(as.integer(x)[1L])
    if (length(x) != 1L || is.na(x) || x < 1L) 1L else x
  }
  for (o in c("rmoriebricklayer.num_colors", if (!tty) "cli.num_colors")) {
    if (!is.null(v <- getOption(o))) return(n(v))
  }
  if (nzchar(e <- Sys.getenv("R_CLI_NUM_COLORS"))) return(n(e))
  if (!tty && identical(getOption("crayon.enabled"), FALSE)) return(1L)
  if (nzchar(Sys.getenv("NO_COLOR")) || knit || !free) return(1L)
  if (!tty && !is.null(v <- getOption("cli.default_num_colors"))) return(n(v))
  if (.bl_gui() %in% c("AQUA", "Rgui") && rs == "") return(1L)
  if (rs %in% c("console", "build", "job")) return(n(Sys.getenv("RSTUDIO_CONSOLE_COLOR")))
  # ponytail: a Positron console without ark's cli.default_num_colors is taken as 256 colours
  # (cli's is_ansi_tty() says its console is ANSI); not checked in a live Positron session
  if (positron && !isatty(con)) return(256L)
  if (!tty && !isatty(con)) return(1L)
  # a terminal: cli's detect_tty_colors() without its tput call
  term <- Sys.getenv("TERM")
  if (identical(term, "dumb")) return(1L)
  if (Sys.getenv("COLORTERM") %in% c("truecolor", "24bit")) return(16777216L)
  if (.Platform$OS.type == "windows" || grepl("256|^xterm", term)) return(256L)
  8L
}

.bl_console_width <- function(rs = .bl_rstudio()) {
  w <- getOption("rmoriebricklayer.width", getOption("cli.width"))
  if (is.null(w) && !rs %in% c("console", "build", "render")) w <- Sys.getenv("COLUMNS")
  w <- suppressWarnings(as.integer(w)[1L])
  if (length(w) != 1L || is.na(w) || w < 20L) w <- suppressWarnings(as.integer(getOption("width", 80L))[1L])
  if (length(w) != 1L || is.na(w) || w < 20L) 80L else min(w, 500L)
}

# ---- styles ------------------------------------------------------------------------------------

.bl_anim_colors <- list(blue = c(80, 200, 255), green = c(120, 220, 140), red = c(255, 120, 120),
                        violet = c(130, 160, 255), amber = c(220, 190, 110))

# the escape for a foreground colour at `n` colours ("" below 8): 24-bit, the 6x6x6 cube of 256,
# or the basic colour made of the channels within a quarter of the brightest (as src/rmbl_progress.c)
.bl_sgr <- function(rgb, n) {
  rgb <- as.integer(round(rgb))
  if (n < 8L) return("")
  if (n >= 16777216L) return(sprintf("\033[38;2;%d;%d;%dm", rgb[1L], rgb[2L], rgb[3L]))
  if (n >= 256L) {
    q <- as.integer(rgb / 255 * 5 + 0.5)
    return(sprintf("\033[38;5;%dm", 16L + 36L * q[1L] + 6L * q[2L] + q[3L]))
  }
  on <- rgb >= 0.75 * max(rgb)
  sprintf("\033[%dm", 30L + sum(c(1L, 2L, 4L)[on]))
}

.bl_styles <- function(rgb, n) {
  list(accent = .bl_sgr(rgb, n), ok = .bl_sgr(.bl_anim_colors$green, n), err = .bl_sgr(.bl_anim_colors$red, n),
       dim = if (n >= 256L) .bl_sgr(c(135, 135, 145), n) else if (n >= 8L) "\033[2m" else "")
}

.bl_paint <- function(x, code) if (nzchar(code) && nzchar(x)) paste0(code, x, "\033[0m") else x

.bl_w <- function(x) nchar(x, type = "width")

# `x` cut to `n` cells, the cut marked with an ellipsis
.bl_trunc <- function(x, n, unicode = TRUE) {
  n <- max(0L, as.integer(n))
  if (.bl_w(x) <= n) return(x)
  ell <- if (unicode) "\u2026" else "..."
  if (n <= .bl_w(ell)) return(substr(ell, 1L, n))
  y <- substr(x, 1L, n)
  while (nzchar(y) && .bl_w(y) > n - .bl_w(ell)) y <- substr(y, 1L, nchar(y) - 1L)
  paste0(y, ell)
}

# ---- formats -----------------------------------------------------------------------------------

.bl_fmt_elapsed <- function(s) {
  if (s < 60) sprintf("%.1fs", s) else sprintf("%dm%02ds", as.integer(s %/% 60), as.integer(s %% 60))
}

# a time left, whole seconds rounded up: 4s, 2m05s, 1h03m; NULL past 99 hours
.bl_fmt_eta <- function(s) {
  if (!is.finite(s) || s < 0 || s > 99 * 3600) return(NULL)
  s <- ceiling(s)
  if (s < 60) return(sprintf("%ds", as.integer(s)))
  if (s < 3600) return(sprintf("%dm%02ds", as.integer(s %/% 60), as.integer(s %% 60)))
  sprintf("%dh%02dm", as.integer(s %/% 3600), as.integer((s %% 3600) %/% 60))
}

# a rate: 12.3 MB/s for bytes; 0.25/s, 4.2/s, 85/s, 12k/s, 3.4M/s for steps
.bl_fmt_rate <- function(x, bytes = FALSE) {
  if (!is.finite(x) || x < 0) return(NULL)
  if (bytes) return(paste0(.bl_fmt_bytes(x), "/s"))
  if (x >= 1e6) sprintf("%.1fM/s", x / 1e6) else if (x >= 1e4) sprintf("%.0fk/s", x / 1e3) else
    if (x >= 10) sprintf("%.0f/s", x) else if (x >= 1) sprintf("%.1f/s", x) else sprintf("%.2f/s", x)
}

# ---- the animation -----------------------------------------------------------------------------

# `unit`: "" counts steps, "B" counts bytes (rates in MB/s)
.bl_anim_new <- function(label, total, color = "blue", quiet = NULL, tty = NULL, unit = "") {
  a <- new.env(parent = emptyenv())
  a$label <- label
  a$total <- total
  a$unit <- unit
  a$rgb <- .bl_anim_colors[[color]] %||% .bl_anim_colors$blue
  a$quiet <- if (is.null(quiet)) .bl_dl_quiet() else isTRUE(quiet)
  con <- .bl_console(tty)
  a$tty <- !a$quiet && con$dynamic
  a$ncolors <- if (a$tty) con$colors else 1L
  a$color <- a$ncolors > 1L
  a$sty <- .bl_styles(a$rgb, a$ncolors)
  a$unicode <- con$unicode
  a$out <- con$out
  a$rs <- con$rstudio
  a$t0 <- proc.time()[["elapsed"]]
  a$last <- -Inf
  a$shown <- 0
  a$done <- 0
  a$info <- ""
  a$width <- 0L
  a$mile <- 0L
  # the rate: a moving average over windows of at least half a second
  a$rate <- NA_real_
  a$r_t <- 0
  a$r_d <- 0
  a$r_n <- 0L
  a
}

.bl_rate_sample <- function(a, now) {
  dt <- now - a$r_t
  if (dt < 0.5) return(invisible(a))
  inst <- max(0, a$done - a$r_d) / dt
  a$rate <- if (is.na(a$rate)) inst else a$rate + 0.3 * (inst - a$rate)
  a$r_n <- a$r_n + 1L
  a$r_t <- now
  a$r_d <- a$done
  invisible(a)
}

.bl_rate_now <- function(a, now) {
  if (!is.na(a$rate)) a$rate else if (now > 0.2) a$done / now else NA_real_
}

# the text after the bar, most important last-dropped: count, rate, time so far, time left (shown
# once three rate windows have passed, two seconds in and 2% done, so it does not jump about)
.bl_anim_stats <- function(a, now) {
  bytes <- identical(a$unit, "B")
  rate <- .bl_rate_now(a, now)
  if (a$total > 0) {
    cnt <- if (bytes) paste0(.bl_fmt_bytes(a$done), "/", .bl_fmt_bytes(a$total)) else
      paste0(.bl_n(a$done), "/", .bl_n(a$total))
    frac <- a$done / a$total
    eta <- if (a$r_n >= 3L && now >= 2 && frac >= 0.02 && frac < 1 && is.finite(rate) && rate > 0) {
      .bl_fmt_eta((a$total - a$done) / rate)
    }
  } else {
    cnt <- if (a$done > 0) (if (bytes) .bl_fmt_bytes(a$done) else .bl_n(a$done))
    eta <- NULL
  }
  c(count = cnt, rate = if (a$done > 0) .bl_fmt_rate(rate, bytes), elapsed = .bl_fmt_elapsed(now),
    eta = if (!is.null(eta)) paste(if (a$unicode) "ETA" else "eta", eta))
}

# the frame for the current state, fitted to the console's width; `now` is seconds since the start
.bl_anim_line <- function(a, now) {
  cols <- .bl_console_width(a$rs) - 1L
  sep <- if (a$unicode) " \u00b7 " else ", "
  if (a$total <= 0) {
    # no count to fill a bar with: the spinner, the label, the time so far and the stage
    spin <- .bl_paint(.Call(C_rmbl_progress_spinner, now, a$unicode), a$sty$accent)
    st <- .bl_anim_stats(a, now)
    el <- st[["elapsed"]]
    extra <- st[intersect(c("count", "rate"), names(st))]
    if (length(extra)) el <- paste(paste(extra, collapse = sep), el, sep = sep)
    lab <- .bl_trunc(a$label, max(8L, cols - 3L - .bl_w(el)), a$unicode)
    info <- .bl_trunc(a$info, cols - 5L - .bl_w(lab) - .bl_w(el), a$unicode)
    return(sprintf("%s %s %s  %s", spin, lab, el, info))
  }
  target <- min(1, a$done / a$total)
  # ease toward the target, a third of the way per frame, so a jump reads as a glide
  a$shown <- a$shown + (target - a$shown) * 0.35
  if (abs(target - a$shown) < 1e-3) a$shown <- target
  active <- target < 1
  stats <- .bl_anim_stats(a, now)
  lab <- a$label
  info <- a$info
  frame_w <- if (a$unicode) 0L else 2L
  need <- function(bw) {
    2L + .bl_w(lab) + 1L + bw + frame_w + 5L +
      (if (length(stats)) .bl_w(paste(stats, collapse = sep)) + 1L else 0L) +
      (if (nzchar(info)) 2L + .bl_w(info) else 0L)
  }
  # the bar's width leaves room for the widest the numbers after it get (the stage takes what is
  # left), so it does not jump when the rate or the time left appears
  bytes <- identical(a$unit, "B")
  widest <- c(if (bytes) paste0(.bl_fmt_bytes(a$total), "/", .bl_fmt_bytes(a$total)) else
                paste0(.bl_n(a$total), "/", .bl_n(a$total)),
              if (bytes) "000.0 MB/s" else "0000/s", "0m00s", "ETA 0m00s")
  bw <- max(10L, min(40L, cols - (2L + .bl_w(lab) + 1L + frame_w + 5L + .bl_w(paste(widest, collapse = sep)) + 1L)))
  # narrow consoles: the bar is at 10 cells, then the stage is cut and dropped, then the count,
  # the rate and the time so far go, then the label is cut, then the bar shrinks to 4
  if (need(bw) > cols && nzchar(info)) {
    room <- cols - need(bw) + .bl_w(info)
    info <- if (room >= 8L) .bl_trunc(info, room, a$unicode) else ""
  }
  for (k in c("count", "rate", "elapsed")) if (need(bw) > cols) stats <- stats[names(stats) != k]
  if (need(bw) > cols) lab <- .bl_trunc(lab, max(6L, cols - need(bw) + .bl_w(lab)), a$unicode)
  if (need(bw) > cols) bw <- max(4L, cols - need(0L))
  bar <- .Call(C_rmbl_progress_frame, a$shown, now, as.numeric(bw),
               if (a$color) as.integer(a$ncolors) else FALSE, a$unicode, active, a$rgb)
  if (!a$unicode) bar <- paste0("[", bar, "]")
  spin <- if (active) .bl_paint(.Call(C_rmbl_progress_spinner, now, a$unicode), a$sty$accent) else
    .bl_paint(if (a$unicode) "\u2714" else "v", a$sty$ok)
  # the percent is the count's (the bar glides behind it)
  paste0(spin, " ", lab, " ", bar, " ", sprintf("%3d%%", as.integer(floor(100 * target + 1e-9))),
         if (length(stats)) paste0(" ", .bl_paint(paste(stats, collapse = sep), a$sty$dim)),
         if (nzchar(info)) paste0("  ", info))
}

# the line that replaces the bar: a check (or a cross when `ok` is FALSE), the summary or else the
# label and its result, and the time taken
.bl_anim_final <- function(a, now, summary = NULL, ok = TRUE) {
  cols <- .bl_console_width(a$rs) - 1L
  mark <- if (ok) .bl_paint(if (a$unicode) "\u2714" else "v", a$sty$ok) else
    .bl_paint(if (a$unicode) "\u2716" else "x", a$sty$err)
  bytes <- identical(a$unit, "B")
  tail <- ""
  if (!is.null(summary)) {
    text <- summary
  } else {
    # the count reached (of the total when short of it), then the last stage
    res <- if (a$total > 0) {
      if (bytes) paste0(.bl_fmt_bytes(a$done), if (a$done < a$total) paste0(" of ", .bl_fmt_bytes(a$total))) else
        paste0(.bl_n(a$done), if (a$done != a$total) paste0("/", .bl_n(a$total)))
    } else {
      ""
    }
    if (!ok) res <- paste0("stopped", if (nzchar(res)) paste0(" at ", res))
    if (nzchar(a$info)) res <- if (nzchar(res)) paste0(res, "  ", a$info) else a$info
    text <- if (nzchar(res)) paste0(a$label, "  ", res) else a$label
    tail <- if (a$unicode) paste0("\u00b7 ", .bl_fmt_elapsed(now)) else paste0("(", .bl_fmt_elapsed(now), ")")
  }
  text <- .bl_trunc(text, cols - 2L - (if (nzchar(tail)) .bl_w(tail) + 1L else 0L), a$unicode)
  paste0(mark, " ", text, if (nzchar(tail)) paste0(" ", .bl_paint(tail, a$sty$dim)))
}

.bl_out <- function(a) if (identical(a$out, "stdout")) stdout() else stderr()

# one frame in place: back to the start of the line, the frame, spaces over what the last frame
# left (no erase-line escape: the RStudio console redraws on \r but has no cursor control)
.bl_draw <- function(a, line, end = "") {
  vis <- .bl_w(gsub("\033\\[[0-9;]*m", "", line))
  pad <- max(0L, min(a$width, .bl_console_width(a$rs) - 1L) - vis)
  cat("\r", line, strrep(" ", pad), end, sep = "", file = .bl_out(a))
  a$width <- if (nzchar(end)) 0L else max(a$width, vis)
  invisible(a)
}

# a new value (`done` of `total`) and the text after the bar; `force` draws even inside the
# frame interval (the last frame of a run)
.bl_anim_update <- function(a, done = a$done, info = a$info, force = FALSE) {
  a$done <- done
  a$info <- info
  if (a$quiet) return(invisible(a))
  now <- proc.time()[["elapsed"]] - a$t0
  if (a$tty) {
    if (!force && now - a$last < 1 / 12) return(invisible(a))
    a$last <- now
    .bl_rate_sample(a, now)
    .bl_draw(a, .bl_anim_line(a, now))
  } else if (a$total > 0) {
    step <- as.integer((10 * min(done, a$total)) %/% a$total)
    if (step > a$mile) {
      a$mile <- step
      cat(sprintf("  %s: %d of %d (%d%%) %s\n", a$label, as.integer(done), as.integer(a$total),
                  as.integer(100 * done / a$total), info), file = stderr())
    }
  } else if (isTRUE(a$indeterminate) && nzchar(info) && !identical(info, a$stage) &&
               now - a$said >= 2) {
    # no count: a line at a new stage, at most one every two seconds (an iteration count in
    # `info` must not write a line per iteration into a log)
    a$stage <- info
    a$said <- now
    cat(sprintf("  %s: %s (%s)\n", a$label, info, .bl_fmt_elapsed(now)), file = stderr())
  }
  invisible(a)
}

# keep the animation moving while waiting `seconds` (a poll interval, a back-off)
.bl_anim_wait <- function(a, seconds) {
  end <- proc.time()[["elapsed"]] + seconds
  repeat {
    left <- end - proc.time()[["elapsed"]]
    if (left <= 0) break
    Sys.sleep(min(left, if (a$tty) 1 / 12 else left))
    .bl_anim_update(a)
  }
  invisible(a)
}

# the end: on a console that redraws, the bar replaced by its last line (a check, or a cross when
# `ok` is FALSE); elsewhere the summary, when there is one, on a line of its own
.bl_anim_done <- function(a, summary = NULL, ok = TRUE) {
  if (a$quiet) return(invisible(a))
  if (a$tty) {
    a$shown <- if (a$total > 0) min(1, a$done / a$total) else 1
    .bl_draw(a, .bl_anim_final(a, proc.time()[["elapsed"]] - a$t0, summary, ok), "\n")
  } else if (!is.null(summary)) {
    cat(summary, "\n", sep = "", file = stderr())
  }
  invisible(a)
}

# The bars of bricklayer_progress() still running, each as the frame of the function that made
# it: a bar made while one of these frames is still on the call stack is nested work and stays
# silent, so one bar shows the outer loop. A frame that has returned (normally, by an error or
# an interrupt) no longer counts, so a bar whose done() was never called cannot silence the
# bars after it. `delay` is the lazy start of every bar (seconds), adjustable for the tests.
.bl_progress_state <- new.env(parent = emptyenv())
.bl_progress_state$active <- list()
.bl_progress_state$delay <- 0.75
# what returnValue() gives in an on.exit() when the frame is leaving by an error or an interrupt
.bl_progress_state$unwound <- new.env(parent = emptyenv())

.bl_prog_live <- function() {
  frames <- sys.frames()
  Filter(function(e) any(vapply(frames, identical, NA, e)), .bl_progress_state$active)
}

#' Live progress for long-running work
#'
#' Makes a progress bar for a loop or a long computation: the animated bar of
#' \code{\link{bricklayer_download}()}, redrawn in place at no more than 12
#' frames a second, when the console can redraw a line -- a terminal, or the
#' RStudio, Positron, R.app or RKWard console (never a knitr or Jupyter
#' notebook; the options \code{rmoriebricklayer.dynamic} or
#' \code{cli.dynamic}, or the environment variable \code{R_CLI_DYNAMIC},
#' override the choice). In the RStudio or Positron console the bar is drawn
#' on stdout, elsewhere on stderr. Otherwise a milestone line goes to stderr
#' at each tenth, and nothing is shown when quiet. With \code{total = 0} the
#' work has no count, and the bar is a spinner with the time so far and the
#' current stage (the \code{info} text), with a line at each new stage when
#' the console cannot redraw.
#'
#' Progress is shown when a person is watching: an interactive session, or a
#' command line that sets \code{options(morie.progress = TRUE)}.
#' \code{options(morie.quiet = TRUE)} or \code{quiet = TRUE} silences it.
#'
#' Nothing is drawn until the work has run for \code{delay} seconds, so a
#' fast call never flashes a bar. A bar made inside a function while a bar
#' made by a calling function is still running stays silent, so nested work
#' shows one bar, for the outer loop.
#'
#' Updates are cheap: when quiet an update only stores the value, and when
#' drawing, frames are throttled, so \code{$tick()} can be called on every
#' iteration of a loop. Call \code{$done()} through \code{on.exit()} right
#' after making the bar, so the line is cleared and the bar is released even
#' when the work fails or is interrupted:
#' \preformatted{
#' p <- bricklayer_progress("bootstrap", B)
#' on.exit(p$done(), add = TRUE)
#' for (b in seq_len(B)) {
#'   ...
#'   p$tick(info = sprintf("resample \%d/\%d", b, B))
#' }
#' }
#' \code{$done()} may be called more than once; only the first call acts.
#'
#' @param label A short name for the work, shown before the bar.
#' @param total The number of steps, or 0 when the work has no count.
#' @param quiet \code{TRUE}, \code{FALSE}, or \code{NULL} to follow the
#'   session (see above).
#' @param color The bar's colour: \code{"blue"}, \code{"green"},
#'   \code{"red"}, \code{"violet"} or \code{"amber"}.
#' @param delay Seconds of work before anything is drawn; \code{NULL} takes the
#'   package's 0.75.
#' @return An object of class \code{rmbl_progress}, a list of functions:
#'   \code{update(done, info = NULL)} sets the steps done (and the text after
#'   the bar), \code{tick(by = 1, info = NULL)} adds \code{by} steps,
#'   \code{wait(seconds)} sleeps while keeping the animation moving, and
#'   \code{done(summary = NULL)} ends the bar, clears the line and, when the
#'   bar was shown, writes \code{summary} on its own line. Each returns the
#'   object invisibly.
#' @examples
#' p <- bricklayer_progress("squares", 50, delay = 0)
#' for (i in 1:50) {
#'   x <- sum(seq_len(i)^2)
#'   p$tick(info = sprintf("step %d/50", i))
#' }
#' p$done("squares: 50 steps")
#'
#' # work with no count: a spinner and the stage
#' f <- function() {
#'   p <- bricklayer_progress("model", 0, delay = 0)
#'   on.exit(p$done(), add = TRUE)
#'   p$update(info = "fitting")
#'   p$wait(0.2)
#'   p$update(info = "writing")
#'   invisible(TRUE)
#' }
#' f()
#' @export
bricklayer_progress <- function(label, total, quiet = NULL, color = "blue", delay = NULL) {
  label <- as.character(label)
  if (length(label) != 1L || is.na(label)) stop("`label` must be a single string", call. = FALSE)
  if (!is.numeric(total) || length(total) != 1L || is.na(total) || !is.finite(total) || total < 0) {
    stop("`total` must be a single non-negative number (0 when the work has no count)", call. = FALSE)
  }
  if (!is.character(color) || length(color) != 1L || !color %in% names(.bl_anim_colors)) {
    stop(sprintf("`color` must be one of %s", paste(names(.bl_anim_colors), collapse = ", ")), call. = FALSE)
  }
  if (!is.null(quiet) && !(is.logical(quiet) && length(quiet) == 1L && !is.na(quiet))) {
    stop("`quiet` must be TRUE, FALSE or NULL", call. = FALSE)
  }
  delay <- if (is.null(delay)) .bl_progress_state$delay else delay
  if (!is.numeric(delay) || length(delay) != 1L || is.na(delay) || delay < 0) {
    stop("`delay` must be a single non-negative number of seconds", call. = FALSE)
  }
  creator <- parent.frame()
  live <- .bl_prog_live()
  nested <- length(live) > 0L
  a <- .bl_anim_new(label, total, color = color, quiet = if (nested) TRUE else quiet)
  a$indeterminate <- total <= 0
  a$stage <- NULL
  a$said <- -Inf
  started <- delay <= 0
  closed <- FALSE
  failed <- FALSE
  # only a bar that draws holds back the bars inside it; the console's own frame is not on
  # the call stack, so a bar made at top level never counts
  if (!a$quiet && !identical(creator, globalenv())) {
    .bl_progress_state$active <- c(live, creator)
    # how the creating function ends: an on.exit() of its own, added now so it runs before the
    # caller's on.exit(p$done()), notes an error or an interrupt (returnValue() gives its default
    # then), and done() ends the bar with a cross instead of a check
    unwound <- .bl_progress_state$unwound
    note <- function(value) if (identical(value, unwound)) failed <<- TRUE
    do.call(on.exit, list(as.call(list(note, as.call(list(quote(base::returnValue), unwound)))), add = TRUE),
            envir = creator)
  }
  self <- NULL
  draw <- function(force = FALSE) {
    if (!started) {
      if (proc.time()[["elapsed"]] - a$t0 < delay) return(invisible(self))
      started <<- TRUE
      force <- TRUE
    }
    .bl_anim_update(a, force = force)
    invisible(self)
  }
  self <- structure(list(
    update = function(done = a$done, info = NULL) {
      a$done <- done
      if (!is.null(info)) a$info <- as.character(info)[1L]
      if (a$quiet || closed) return(invisible(self))
      draw()
    },
    tick = function(by = 1, info = NULL) {
      a$done <- a$done + by
      if (!is.null(info)) a$info <- as.character(info)[1L]
      if (a$quiet || closed) return(invisible(self))
      draw()
    },
    wait = function(seconds) {
      if (a$quiet || closed) {
        Sys.sleep(seconds)
        return(invisible(self))
      }
      end <- proc.time()[["elapsed"]] + seconds
      repeat {
        left <- end - proc.time()[["elapsed"]]
        if (left <= 0) break
        Sys.sleep(min(left, 1 / 12))
        draw()
      }
      invisible(self)
    },
    done = function(summary = NULL) {
      if (closed) return(invisible(self))
      closed <<- TRUE
      .bl_progress_state$active <- Filter(function(e) !identical(e, creator), .bl_progress_state$active)
      if (!a$quiet && started) .bl_anim_done(a, summary, ok = !failed)
      invisible(self)
    }
  ), class = "rmbl_progress")
  self
}

#' @export
print.rmbl_progress <- function(x, ...) {
  a <- environment(x$update)$a
  cat(sprintf("<progress \"%s\": %s of %s%s>\n", a$label, format(a$done),
              if (a$total > 0) format(a$total) else "?",
              if (a$quiet) ", quiet" else ""))
  invisible(x)
}

# a bar's total from a count the caller passed, before the caller's own checks have run: a
# count that is not a finite non-negative number gives a bar with no count, so the check that
# follows reports it in its own words
.bl_count <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  if (length(x) != 1L || !is.finite(x) || x < 0) 0 else x
}

# whether the console redraws a line in place (the name is older than the IDE consoles)
.bl_stderr_tty <- function() .bl_console()$dynamic

# A long native call with no count R can see (a key generation, a network request): from 0.75 s on
# the compiled layer draws a spinner, the label and the time so far each time the call polls for a
# Ctrl-C (src/rmbl_fetch.cpp, rmbl_wait_tick) and, when the call ends, a check (a cross after an
# error or an interrupt) with the time taken. Where the console cannot redraw, a line when the call
# has run 0.75 s, one every ten seconds after it and one at the end. Not when quiet, not inside a
# running bar (that bar is the one line), and not inside another such call (its label stays).
# The mode travels to C as c(colours, redraws, to stdout[, ended well]).
.bl_progress_state$busy <- FALSE

.bl_busy <- function(label, expr) {
  if (!.bl_progress_state$busy && !.bl_dl_quiet() && !length(.bl_prog_live())) {
    con <- .bl_console()
    dyn <- .bl_stderr_tty()
    mode <- c(if (dyn) con$colors else 1, dyn, dyn && identical(con$out, "stdout"))
    .bl_progress_state$busy <- TRUE
    .Call(C_rmbl_wait_label, .bl_trunc(.rmbl_printable(label), con$width - 14L, con$unicode), con$unicode,
          as.numeric(mode))
    on.exit({
      ok <- !identical(returnValue(.bl_progress_state$unwound), .bl_progress_state$unwound)
      .Call(C_rmbl_wait_label, "", con$unicode, as.numeric(c(mode, ok)))
      .bl_progress_state$busy <- FALSE
    }, add = TRUE)
  }
  expr
}

# a network request: "waiting for <host>"
.bl_net <- function(url, expr) {
  host <- sub("^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*).*$", "\\1", as.character(url)[1L])
  .bl_busy(paste("waiting for", sub("^.*@", "", host)), expr)
}

# a count for a bar's text: 1,000,000, never 1e+06
.bl_n <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
