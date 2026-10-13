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
