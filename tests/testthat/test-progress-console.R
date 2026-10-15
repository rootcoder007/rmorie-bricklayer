# What the console can show (.bl_console(): redraws, colours, characters, width, stream), the
# formats of the progress line, its fitting to the width, and the line that ends a bar or a
# native spinner. The IDE consoles are simulated through the variables and options they set.

ns <- asNamespace("rmoriebricklayer")
strip <- function(x) gsub("\033\\[[0-9;]*m", "", x)

# a console with none of the session's own signals: testthat's reproducible output sets cli's
# options, and the host may set RSTUDIO, COLORTERM or NO_COLOR
plain_console <- function(env = parent.frame()) {
  withr::local_options(cli.dynamic = NULL, cli.num_colors = NULL, cli.unicode = NULL, crayon.enabled = NULL,
                       cli.default_num_colors = NULL, cli.width = NULL, knitr.in.progress = NULL,
                       rstudio.notebook.executing = NULL, jupyter.in_kernel = NULL,
                       rmoriebricklayer.dynamic = NULL, rmoriebricklayer.num_colors = NULL,
                       rmoriebricklayer.unicode = NULL, rmoriebricklayer.width = NULL, .local_envir = env)
  withr::local_envvar(RSTUDIO = NA, RSTUDIO_SESSION_PID = NA, RSTUDIO_CHILD_PROCESS_PANE = NA,
                      RSTUDIO_CONSOLE_COLOR = NA, POSITRON = NA, R_GUI_APP_VERSION = NA, R_CLI_DYNAMIC = NA,
                      R_CLI_NUM_COLORS = NA, NO_COLOR = NA, COLORTERM = NA, COLUMNS = NA, .local_envir = env)
}
rstudio_console <- function(env = parent.frame()) {
  withr::local_envvar(RSTUDIO = "1", RSTUDIO_SESSION_PID = as.character(Sys.getpid()), .local_envir = env)
}

test_that("a script with stderr off a terminal does not redraw and has no colour", {
  plain_console()
  skip_if(isatty(stderr()))
  con <- ns$.bl_console()
  expect_false(con$dynamic)
  expect_identical(con$colors, 1L)
  expect_identical(con$out, "stderr")
  expect_identical(con$rstudio, "")
  expect_false(ns$.bl_stderr_tty())
})

test_that("the RStudio console redraws on \\r, with RSTUDIO_CONSOLE_COLOR's colours", {
  plain_console()
  rstudio_console()
  skip_if(isatty(stderr()) || isatty(stdout()))
  con <- ns$.bl_console()
  expect_identical(con$rstudio, "console")
  expect_true(con$dynamic)
  expect_identical(con$colors, 1L)                     # ANSI switched off in RStudio's options
  withr::local_envvar(RSTUDIO_CONSOLE_COLOR = "256")
  expect_identical(ns$.bl_console()$colors, 256L)
  # not interactive (knitting, a script sourced from a job): stderr; interactive: stdout, as cli
  expect_identical(con$out, "stderr")
  local_mocked_bindings(.bl_interactive = function() TRUE)
  expect_identical(ns$.bl_console()$out, "stdout")
  # a sink on the stream: neither redrawn nor coloured, and on stderr
  sunk <- NULL
  invisible(capture.output(sunk <- ns$.bl_console()))
  expect_identical(sunk$out, "stderr")
  invisible(capture.output(type = "message", sunk <- ns$.bl_console()))
  expect_false(sunk$dynamic)
  expect_identical(sunk$colors, 1L)
  # the width is R's, which RStudio keeps at the console's; COLUMNS is the shell's
  withr::local_envvar(COLUMNS = "200")
  withr::local_options(width = 77)
  expect_identical(ns$.bl_console()$width, 77L)
})

test_that("RStudio's panes, terminal and subprocesses are told apart as cli does", {
  plain_console()
  withr::local_envvar(RSTUDIO = "1", RSTUDIO_SESSION_PID = "1")
  skip_if(isatty(stdin()))
  expect_identical(ns$.bl_rstudio(), "subprocess")
  expect_false(ns$.bl_console()$dynamic)
  withr::local_envvar(RSTUDIO_CHILD_PROCESS_PANE = "build", RSTUDIO_CONSOLE_COLOR = "256")
  expect_identical(ns$.bl_rstudio(), "build")
  expect_true(ns$.bl_console()$dynamic)
  expect_identical(ns$.bl_console()$colors, 256L)
  withr::local_envvar(RSTUDIO_CHILD_PROCESS_PANE = "job")
  expect_false(ns$.bl_console()$dynamic)
})

test_that("Positron, R.app and RKWard redraw in an interactive session only", {
  plain_console()
  withr::local_envvar(POSITRON = "1")
  skip_if(isatty(stderr()) || isatty(stdout()))
  expect_false(ns$.bl_console()$dynamic)
  local_mocked_bindings(.bl_interactive = function() TRUE)
  con <- ns$.bl_console()
  expect_true(con$dynamic)
  expect_true(con$positron)
  expect_identical(con$out, "stdout")
  expect_identical(con$colors, 256L)
  withr::local_options(cli.default_num_colors = 16L)   # what Positron's kernel sets
  expect_identical(ns$.bl_console()$colors, 16L)
  withr::local_envvar(POSITRON = NA, R_GUI_APP_VERSION = "4.4")
  con <- ns$.bl_console()
  expect_true(con$dynamic)
  expect_identical(con$out, "stderr")
})

test_that("knitr, a notebook chunk and a Jupyter kernel never redraw; overrides come first", {
  # with knitr.in.progress set before knitr is loaded, anything that loads knitr meanwhile sees the
  # option during knitr's own load and loads it again: "cyclic namespace dependency" (pkgcheck, ASAN)
  if (requireNamespace("knitr", quietly = TRUE)) loadNamespace("knitr")
  plain_console()
  rstudio_console()
  expect_true(ns$.bl_console()$dynamic)
  for (o in c("knitr.in.progress", "rstudio.notebook.executing", "jupyter.in_kernel")) {
    withr::with_options(stats::setNames(list(TRUE), o), {
      expect_false(ns$.bl_console()$dynamic, info = o)
    })
  }
  withr::with_options(list(knitr.in.progress = TRUE), expect_identical(ns$.bl_console()$colors, 1L))
  # an override: this package's option, then cli's, then R_CLI_DYNAMIC
  withr::local_envvar(R_CLI_DYNAMIC = "false")
  expect_false(ns$.bl_console()$dynamic)
  withr::local_options(cli.dynamic = TRUE)
  expect_true(ns$.bl_console()$dynamic)
  withr::local_options(rmoriebricklayer.dynamic = FALSE)
  expect_false(ns$.bl_console()$dynamic)
  withr::local_options(knitr.in.progress = TRUE, rmoriebricklayer.dynamic = TRUE)
  expect_true(ns$.bl_console()$dynamic)
  # tty = TRUE or FALSE is the caller's word
  expect_false(ns$.bl_console(tty = FALSE)$dynamic)
})

test_that("colours: NO_COLOR, the overrides, and a terminal's TERM and COLORTERM", {
  plain_console()
  rstudio_console()
  withr::local_envvar(RSTUDIO_CONSOLE_COLOR = "256")
  withr::with_envvar(c(NO_COLOR = "1"), expect_identical(ns$.bl_console()$colors, 1L))
  withr::with_envvar(c(R_CLI_NUM_COLORS = "8"), expect_identical(ns$.bl_console()$colors, 8L))
  withr::with_options(list(crayon.enabled = FALSE), expect_identical(ns$.bl_console()$colors, 1L))
  withr::with_options(list(rmoriebricklayer.num_colors = 16777216), {
    expect_identical(ns$.bl_console()$colors, 16777216L)
  })
  # a terminal (tty = TRUE): cli's options do not apply, the variables do
  withr::local_envvar(RSTUDIO = NA)
  withr::local_options(cli.num_colors = 1, crayon.enabled = FALSE)
  withr::with_envvar(c(TERM = "dumb"), expect_identical(ns$.bl_console(TRUE)$colors, 1L))
  withr::with_envvar(c(TERM = "xterm-256color", COLORTERM = "truecolor"), {
    expect_identical(ns$.bl_console(TRUE)$colors, 16777216L)
  })
  skip_on_os("windows")
  withr::with_envvar(c(TERM = "xterm-256color"), expect_identical(ns$.bl_console(TRUE)$colors, 256L))
  withr::with_envvar(c(TERM = "linux"), expect_identical(ns$.bl_console(TRUE)$colors, 8L))
  withr::with_envvar(c(TERM = "xterm", NO_COLOR = "1"), expect_identical(ns$.bl_console(TRUE)$colors, 1L))
})

test_that("characters and width follow the options, then the locale and the console", {
  plain_console()
  withr::local_options(rmoriebricklayer.unicode = FALSE)
  expect_false(ns$.bl_console()$unicode)
  withr::local_options(rmoriebricklayer.unicode = TRUE)
  expect_true(ns$.bl_console()$unicode)
  withr::local_envvar(COLUMNS = "120")
  expect_identical(ns$.bl_console_width(""), 120L)
  withr::local_options(cli.width = 64)
  expect_identical(ns$.bl_console_width(""), 64L)
  withr::local_options(rmoriebricklayer.width = 50)
  expect_identical(ns$.bl_console_width(""), 50L)
  withr::local_options(rmoriebricklayer.width = NULL, cli.width = NULL, width = 90)
  withr::local_envvar(COLUMNS = "junk")
  expect_identical(ns$.bl_console_width(""), 90L)
})

test_that("rates, times left and truncation are compact", {
  expect_identical(ns$.bl_fmt_rate(85), "85/s")
  expect_identical(ns$.bl_fmt_rate(12.4), "12/s")
  expect_identical(ns$.bl_fmt_rate(4.26), "4.3/s")
  expect_identical(ns$.bl_fmt_rate(0.25), "0.25/s")
  expect_identical(ns$.bl_fmt_rate(12345), "12k/s")
  expect_identical(ns$.bl_fmt_rate(3.4e6), "3.4M/s")
  expect_identical(ns$.bl_fmt_rate(12.3 * 1024^2, bytes = TRUE), "12.3 MB/s")
  expect_null(ns$.bl_fmt_rate(NA_real_))
  expect_identical(ns$.bl_fmt_eta(4.2), "5s")
  expect_identical(ns$.bl_fmt_eta(125), "2m05s")
  expect_identical(ns$.bl_fmt_eta(3780), "1h03m")
  expect_null(ns$.bl_fmt_eta(1e9))
  expect_null(ns$.bl_fmt_eta(-1))
  expect_identical(ns$.bl_trunc("abcdefghij", 6), "abcde\u2026")
  expect_identical(ns$.bl_trunc("abcdefghij", 6, unicode = FALSE), "abc...")
  expect_identical(ns$.bl_trunc("abc", 6), "abc")
  expect_identical(ns$.bl_trunc("abcdef", 0), "")
})

test_that("a colour at each depth, the same in R and in the renderer", {
  blue <- c(80, 200, 255)
  expect_identical(ns$.bl_sgr(blue, 1L), "")
  expect_identical(ns$.bl_sgr(blue, 16777216L), "\033[38;2;80;200;255m")
  expect_identical(ns$.bl_sgr(blue, 256L), "\033[38;5;117m")
  expect_identical(ns$.bl_sgr(blue, 8L), "\033[36m")
  expect_identical(ns$.bl_sgr(c(120, 220, 140), 8L), "\033[32m")
  expect_identical(ns$.bl_sgr(c(255, 120, 120), 8L), "\033[31m")
  expect_identical(ns$.bl_sgr(c(220, 190, 110), 8L), "\033[33m")
  frame <- function(...) .Call(ns$C_rmbl_progress_frame, ...)
  f256 <- frame(0.4, 0.3, 20, 256L, TRUE, TRUE, blue)
  expect_match(f256, "\033[38;5;117m", fixed = TRUE)
  expect_false(grepl("38;2;", f256, fixed = TRUE))
  f8 <- frame(0.4, 0.3, 20, 8L, TRUE, TRUE, blue)
  expect_match(f8, "\033[36m", fixed = TRUE)
  expect_match(f8, "\033[2m", fixed = TRUE)
  expect_false(grepl("38;", f8, fixed = TRUE))
  # no shimmer at 8 colours: the frame does not change with time
  expect_identical(f8, frame(0.4, 1.7, 20, 8L, TRUE, TRUE, blue))
  for (n in c(1L, 8L, 256L, 16777216L)) {
    expect_identical(nchar(strip(frame(0.37, 0.5, 13, n, TRUE, TRUE, blue))), 13L)
  }
  expect_false(grepl("\033", frame(0.5, 0, 9, 4L, TRUE, TRUE, blue), fixed = TRUE))
  expect_error(frame(0.5, 0, 5, -1, TRUE, TRUE, blue), "`color` must be TRUE or FALSE, or a number of colours")
  expect_error(frame(0.5, 0, 5, NA, TRUE, TRUE, blue), "`color` must be TRUE or FALSE")
})

anim <- function(label = "Work", total = 400, ...) {
  a <- ns$.bl_anim_new(label, total, quiet = FALSE, tty = TRUE, ...)
  a$ncolors <- 1L
  a$color <- FALSE
  a$sty <- ns$.bl_styles(a$rgb, 1L)
  a
}

test_that("the bar line: percent, count, rate, time so far, and a time left once settled", {
  withr::local_envvar(COLUMNS = "120", NO_COLOR = "1")
  withr::local_options(rmoriebricklayer.width = NULL, cli.width = NULL)
  a <- anim()
  a$unicode <- TRUE
  a$done <- 211
  a$shown <- 211 / 400
  line <- ns$.bl_anim_line(a, 2.5)
  expect_match(line, " 52% 211/400 \u00b7 84/s \u00b7 2.5s", fixed = TRUE)
  expect_false(grepl("ETA", line, fixed = TRUE))
  a$rate <- 85
  a$r_n <- 3L
  expect_match(ns$.bl_anim_line(a, 2.5), "85/s \u00b7 2.5s \u00b7 ETA 3s", fixed = TRUE)
  # bytes
  b <- anim("file", 4 * 1048576, unit = "B")
  b$unicode <- TRUE
  b$done <- 1048576
  b$rate <- 2 * 1048576
  expect_match(ns$.bl_anim_line(b, 0.5), "1.0 MB/4.0 MB \u00b7 2.0 MB/s", fixed = TRUE)
  # ASCII: a bracketed bar and commas
  a$unicode <- FALSE
  line <- ns$.bl_anim_line(a, 2.5)
  expect_match(line, "] ", fixed = TRUE)
  expect_match(line, "85/s, 2.5s, eta 3s", fixed = TRUE)
  expect_false(grepl("[^ -~]", line))
})

test_that("the line fits the console, cutting the stage, the extras and then the label", {
  withr::local_options(rmoriebricklayer.width = NULL, cli.width = NULL)
  a <- anim(strrep("a long label ", 6))
  a$unicode <- TRUE
  a$done <- 100
  a$info <- strrep("stage text ", 10)
  a$shown <- 0.25
  for (w in c(200, 100, 60, 40, 24)) {
    withr::local_envvar(COLUMNS = as.character(w))
    line <- strip(ns$.bl_anim_line(a, 3))
    expect_lte(nchar(line, type = "width"), w - 1L)
    expect_match(line, "25%", fixed = TRUE)
  }
  withr::local_envvar(COLUMNS = "200")
  expect_match(strip(ns$.bl_anim_line(a, 3)), "stage text stage", fixed = TRUE)
  withr::local_envvar(COLUMNS = "60")
  expect_match(strip(ns$.bl_anim_line(a, 3)), "\u2026", fixed = TRUE)
})

test_that("the end replaces the bar: a check and the time, a cross when the work stopped", {
  # forcing a$unicode = TRUE prints U+2714 whatever the locale; a C locale writes it as <U+2714>
  utf8 <- isTRUE(l10n_info()[["UTF-8"]])
  withr::local_envvar(COLUMNS = "100")
  withr::local_options(rmoriebricklayer.width = NULL, cli.width = NULL)
  a <- anim("Fit", 10)
  a$unicode <- TRUE
  a$done <- 10
  out <- paste(capture.output(type = "message", ns$.bl_anim_done(a)), collapse = "\n")
  if (utf8) expect_match(out, "^\r\u2714 Fit  10 \u00b7 [0-9.]+s *$")
  a <- anim("Fit", 10)
  a$unicode <- FALSE
  a$done <- 3
  out <- paste(capture.output(type = "message", ns$.bl_anim_done(a, ok = FALSE)), collapse = "\n")
  expect_match(out, "^\rx Fit  stopped at 3/10 \\([0-9.]+s\\) *$")
  a <- anim("Fit", 10)
  out <- paste(capture.output(type = "message", ns$.bl_anim_done(a, "Fit: 10 models")), collapse = "\n")
  expect_match(out, "Fit: 10 models *$")
  # coloured: green check, dim time
  a <- anim("Fit", 10)
  a$unicode <- TRUE
  a$sty <- ns$.bl_styles(a$rgb, 256L)
  out <- paste(capture.output(type = "message", ns$.bl_anim_done(a)), collapse = "\n")
  if (utf8) expect_match(out, paste0(ns$.bl_sgr(c(120, 220, 140), 256L), paste0("\u2714", "\033[0m")), fixed = TRUE)
  # quiet: nothing
  q <- ns$.bl_anim_new("Q", 3, quiet = TRUE)
  expect_identical(capture.output(type = "message", ns$.bl_anim_done(q, ok = FALSE)), character())
})

test_that("bricklayer_progress() ends with a cross when its function fails, a check otherwise", {
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL, rmoriebricklayer.width = NULL, cli.width = NULL)
  withr::local_envvar(COLUMNS = "100", NO_COLOR = "1")
  st <- ns$.bl_progress_state
  old <- st$delay
  st$delay <- 0
  withr::defer(st$delay <- old)
  run <- function(fail) {
    p <- bricklayer_progress("Boom", 10)
    a <- environment(p$update)$a
    a$tty <- TRUE
    a$unicode <- FALSE
    on.exit(p$done(), add = TRUE)
    p$tick(5)
    if (fail) stop("the work failed")
    p$tick(5)
    invisible(TRUE)
  }
  out <- paste(capture.output(type = "message", expect_error(run(TRUE), "the work failed")), collapse = "\n")
  expect_match(out, "\rx Boom  stopped at 5/10", fixed = TRUE)
  out <- paste(capture.output(type = "message", run(FALSE)), collapse = "\n")
  expect_match(out, "\rv Boom  10 (", fixed = TRUE)
  expect_false(grepl("stopped", out, fixed = TRUE))
  # a summary is the caller's whole line
  g <- function() {
    p <- bricklayer_progress("Sum", 2)
    environment(p$update)$a$tty <- TRUE
    on.exit(p$done("Sum: two"), add = TRUE)
    p$tick(2)
  }
  expect_match(paste(capture.output(type = "message", g()), collapse = "\n"), "Sum: two *$")
  expect_length(st$active, 0L)
})

test_that("the native spinner: a redrawn line ending in a check, or lines where nothing redraws", {
  wl <- function(...) invisible(.Call(ns$C_rmbl_wait_label, ...))
  tick <- function() invisible(.Call(ns$C_rmbl_check_interrupt))
  withr::defer(wl("", FALSE, FALSE))
  # where the console cannot redraw: a line at 0.75 s, none per poll, one at the end
  out <- capture.output(type = "message", {
    wl("hashing", FALSE, c(1, 0, 0))
    tick()
    Sys.sleep(0.8)
    tick()
    tick()
    wl("", FALSE, c(1, 0, 0, 1))
  })
  expect_length(out, 2L)
  expect_match(out[1], "^  hashing \\([0-9.]+s\\)$")
  expect_match(out[2], "^  hashing: done \\([0-9.]+s\\)$")
  # a console that redraws: \r frames, then a check line with the time (the unicode spinner and
  # check are forced on here, so only a UTF-8 locale can show them as written)
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]), "the forced unicode frames need a UTF-8 locale")
  out <- paste(capture.output(type = "message", {
    wl("hashing", TRUE, c(256, 1, 0))
    Sys.sleep(0.8)
    tick()
    wl("", TRUE, c(256, 1, 0, 1))
  }), collapse = "\n")
  expect_match(out, "\r\033[38;5;117m", fixed = TRUE)
  expect_match(out, paste0("\u2714", "\033[0m hashing "), fixed = TRUE)
  # the RStudio and Positron consoles: on stdout, and a cross after an error
  out <- paste(capture.output({
    wl("hashing", FALSE, c(1, 1, 1))
    Sys.sleep(0.8)
    tick()
    wl("", FALSE, c(1, 1, 1, 0))
  }), collapse = "\n")
  expect_match(out, "\r[|/\\\\-] hashing [0-9.]+s")
  expect_match(out, "\rx hashing  stopped (", fixed = TRUE)
  # quick: nothing at all
  expect_identical(capture.output(type = "message", {
    wl("quick", TRUE, c(256, 1, 0))
    tick()
    wl("", TRUE, c(256, 1, 0, 1))
  }), character())
  expect_error(wl("x", TRUE, c(1, 2)), "`color` must be TRUE, FALSE or c(colours, redraws, to stdout)", fixed = TRUE)
  expect_error(wl("x", TRUE, c(1, NA, 0)), "`color` must be", fixed = TRUE)
})

test_that(".bl_busy() sets the spinner where nothing redraws too, and passes how the call ended", {
  seen <- list()
  local_mocked_bindings(.bl_stderr_tty = function() FALSE)
  withr::local_options(morie.progress = TRUE, morie.quiet = NULL)
  expect_identical(ns$.bl_busy("work", {
    seen$on <- ns$.bl_progress_state$busy
    3
  }), 3)
  expect_true(seen$on)
  expect_error(ns$.bl_busy("boom", stop("failed")), "failed")
  expect_false(ns$.bl_progress_state$busy)
  withr::local_options(morie.quiet = TRUE)
  expect_identical(ns$.bl_busy("quiet", ns$.bl_progress_state$busy), FALSE)
})
