# Animated progress on stderr, drawn by the native renderer (src/rmbl_progress.c): the bar
# glides to each new value, a shimmer travels along the filled part, the head pulses while work
# goes on and a spinner turns. One line, redrawn in place, at most 12 times a second, only while
# a person is watching a terminal (the same rule as bricklayer_download()'s bar: an interactive
# session, or the command line). Elsewhere a line at each tenth, and nothing when quiet.
# NO_COLOR turns the colour off; a locale without UTF-8 gets the ASCII bar.

.bl_stderr_tty <- function() isatty(stderr())

.bl_anim_colors <- list(blue = c(80, 200, 255), green = c(120, 220, 140), red = c(255, 120, 120),
                        violet = c(130, 160, 255), amber = c(220, 190, 110))

.bl_anim_new <- function(label, total, color = "blue", quiet = NULL, tty = NULL) {
  a <- new.env(parent = emptyenv())
  a$label <- label
  a$total <- total
  a$rgb <- .bl_anim_colors[[color]] %||% .bl_anim_colors$blue
  a$quiet <- if (is.null(quiet)) .bl_dl_quiet() else isTRUE(quiet)
  a$tty <- !a$quiet && (if (is.null(tty)) .bl_stderr_tty() else isTRUE(tty))
  a$color <- a$tty && !nzchar(Sys.getenv("NO_COLOR"))
  a$unicode <- isTRUE(l10n_info()[["UTF-8"]])
  a$t0 <- proc.time()[["elapsed"]]
  a$last <- -Inf
  a$shown <- 0
  a$done <- 0
  a$info <- ""
  a$width <- 0L
  a$mile <- 0L
  a
}

# the frame for the current state; `now` is seconds since the start
.bl_anim_line <- function(a, now) {
  if (a$total <= 0 && isTRUE(a$indeterminate)) {
    # no count to fill a bar with: the spinner, the time so far and the stage
    spin <- .Call(C_rmbl_progress_spinner, now, a$unicode)
    return(sprintf("%s %s %s  %s", spin, a$label, .bl_fmt_elapsed(now), a$info))
  }
  target <- if (a$total > 0) min(1, a$done / a$total) else 0
  # ease toward the target, a third of the way per frame, so a jump reads as a glide
  a$shown <- a$shown + (target - a$shown) * 0.35
  if (abs(target - a$shown) < 1e-3) a$shown <- target
  cols <- suppressWarnings(as.integer(Sys.getenv("COLUMNS", "")))
  if (is.na(cols) || cols < 40L) cols <- max(80L, as.integer(getOption("width", 80L)))
  w <- max(10L, min(40L, cols - nchar(a$label) - nchar(a$info) - 22L))
  active <- target < 1
  bar <- .Call(C_rmbl_progress_frame, a$shown, now, as.numeric(w), a$color, a$unicode, active, a$rgb)
  spin <- if (active) .Call(C_rmbl_progress_spinner, now, a$unicode) else if (a$unicode) "\u2714" else "*"
  sprintf("%s %s %s %5.1f%%  %s", spin, a$label, bar, 100 * a$shown, a$info)
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
    line <- .bl_anim_line(a, now)
    vis <- nchar(gsub("\033\\[[0-9;]*m", "", line))
    cat("\r", line, strrep(" ", max(0L, a$width - vis)), sep = "", file = stderr())
    a$width <- max(a$width, vis)
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

# the end: the bar at its final value, the line cleared, and a summary
.bl_anim_done <- function(a, summary = NULL) {
  if (a$quiet) return(invisible(a))
  if (a$tty) {
    a$shown <- if (a$total > 0) min(1, a$done / a$total) else 1
    .bl_anim_update(a, force = TRUE)
    cat("\r", strrep(" ", a$width), "\r", sep = "", file = stderr())
  }
  if (!is.null(summary)) cat(summary, "\n", sep = "", file = stderr())
  invisible(a)
}

.bl_fmt_elapsed <- function(s) {
  if (s < 60) sprintf("%.1fs", s) else sprintf("%dm%02ds", as.integer(s %/% 60), as.integer(s %% 60))
}

# The bars of bricklayer_progress() still running, each as the frame of the function that made
# it: a bar made while one of these frames is still on the call stack is nested work and stays
# silent, so one bar shows the outer loop. A frame that has returned (normally, by an error or
# an interrupt) no longer counts, so a bar whose done() was never called cannot silence the
# bars after it. `delay` is the lazy start of every bar (seconds), adjustable for the tests.
.bl_progress_state <- new.env(parent = emptyenv())
.bl_progress_state$active <- list()
.bl_progress_state$delay <- 0.75

.bl_prog_live <- function() {
  frames <- sys.frames()
  Filter(function(e) any(vapply(frames, identical, NA, e)), .bl_progress_state$active)
}

#' Live progress for long-running work
#'
#' Makes a progress bar on stderr for a loop or a long computation: the
#' animated bar of \code{\link{bricklayer_download}()} (drawn in place at no
#' more than 12 frames a second) while a person is watching a terminal, a line
#' at each tenth when stderr is not a terminal, and nothing when quiet. With
#' \code{total = 0} the work has no count, and the bar is a spinner with the
#' time so far and the current stage (the \code{info} text), with a line at
#' each new stage when stderr is not a terminal.
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
  # only a bar that draws holds back the bars inside it; the console's own frame is not on
  # the call stack, so a bar made at top level never counts
  if (!a$quiet && !identical(creator, globalenv())) .bl_progress_state$active <- c(live, creator)
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
      if (!a$quiet && started) .bl_anim_done(a, summary)
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

# A long native call with no count R can see (a key generation, a network request): while it runs,
# a person watching a terminal sees a spinner, the label and the seconds so far, drawn from 0.75 s
# on by the compiled layer each time the call polls for a Ctrl-C (src/rmbl_fetch.cpp,
# rmbl_wait_tick) and wiped when the call ends. Not when quiet, not off a terminal, not inside a
# running bar (that bar is the one line), and not inside another such call (its label stays).
.bl_progress_state$busy <- FALSE

.bl_busy <- function(label, expr) {
  if (!.bl_progress_state$busy && !.bl_dl_quiet() && .bl_stderr_tty() && !length(.bl_prog_live())) {
    .bl_progress_state$busy <- TRUE
    .Call(C_rmbl_wait_label, .rmbl_printable(label), isTRUE(l10n_info()[["UTF-8"]]), !nzchar(Sys.getenv("NO_COLOR")))
    on.exit({
      .Call(C_rmbl_wait_label, "", FALSE, FALSE)
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
