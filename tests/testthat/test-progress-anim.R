# The native progress renderer (src/rmbl_progress.c) and the animation around
# it.

strip <- function(x) gsub("\033\\[[0-9;]*m", "", x)
frame <- function(...) .Call(rmoriebricklayer:::C_rmbl_progress_frame, ...)
spinner <- function(...) .Call(rmoriebricklayer:::C_rmbl_progress_spinner, ...)

test_that(
  paste0(
    "the bar has exactly `width` cells at every fraction, in block ",
    "characters and ASCII"
  ),
  {
    for (u in c(TRUE, FALSE)) {
      for (f in c(0, 0.01, 0.37, 0.5, 0.999, 1)) {
        for (w in c(1, 7, 40)) {
          b <- strip(frame(f, 1.3, w, TRUE, u, TRUE, c(80, 200, 255)))
          expect_identical(nchar(b), as.integer(w), info = paste(u, f, w))
        }
      }
    }
    expect_identical(
      frame(1, 0, 10, FALSE, TRUE, FALSE, c(0, 0, 0)),
      strrep("█", 10)
    )
    expect_identical(frame(0, 0, 4, FALSE, FALSE, FALSE, c(0, 0, 0)), "....")
    expect_identical(frame(0, 0, 4, FALSE, FALSE, TRUE, c(0, 0, 0)), ">...")
    expect_identical(frame(0.5, 0, 4, FALSE, FALSE, FALSE, c(0, 0, 0)), "##..")
    # out-of-range values are clamped, not drawn past the bar
    expect_identical(
      strip(frame(5, 0, 6, TRUE, TRUE, TRUE, c(1, 2, 3))),
      strrep("█", 6)
    )
    expect_identical(
      nchar(strip(frame(NaN, Inf, 6, FALSE, TRUE, TRUE, c(1, 2, 3)))),
      6L
    )
    expect_identical(
      nchar(frame(0.5, 0, 500, FALSE, FALSE, FALSE, c(1, 2, 3))),
      200L
    )
  }
)

test_that(
  paste0(
    "colour is drawn only when asked, and the shimmer and pulse change it ",
    "over time"
  ),
  {
    plain <- frame(0.6, 0.5, 20, FALSE, TRUE, TRUE, c(80, 200, 255))
    expect_false(grepl("\033", plain, fixed = TRUE))
    a <- frame(0.6, 0.2, 20, TRUE, TRUE, TRUE, c(80, 200, 255))
    b <- frame(0.6, 0.7, 20, TRUE, TRUE, TRUE, c(80, 200, 255))
    expect_match(a, "\033[38;2;", fixed = TRUE)
    expect_true(endsWith(a, "\033[0m"))
    expect_false(identical(a, b))
    expect_identical(strip(a), strip(b))
  }
)

test_that("the spinner turns, in braille or ASCII", {
  expect_identical(spinner(0, FALSE), "|")
  expect_identical(spinner(0.1, FALSE), "/")
  expect_identical(spinner(0.35, FALSE), "\\")
  expect_identical(spinner(-1, FALSE), "|")
  expect_identical(spinner(0, TRUE), "⠋")
  expect_false(identical(spinner(0, TRUE), spinner(0.1, TRUE)))
})

test_that("the renderer refuses bad arguments in words", {
  expect_error(
    frame("a", 0, 5, TRUE, TRUE, TRUE, c(1, 2, 3)),
    "`frac` must be a single number"
  )
  expect_error(
    frame(0.5, 0, 0, TRUE, TRUE, TRUE, c(1, 2, 3)),
    "`width` must be at least 1"
  )
  expect_error(
    frame(0.5, 0, 5, NA, TRUE, TRUE, c(1, 2, 3)),
    "`color` must be TRUE or FALSE"
  )
  expect_error(
    frame(0.5, 0, 5, TRUE, TRUE, TRUE, c(1, 2)),
    "`rgb` must be three numbers"
  )
  expect_error(
    frame(0.5, 0, 5, TRUE, TRUE, TRUE, c(1, 2, 300)),
    "`rgb` must be three numbers"
  )
  expect_error(
    frame(0.5, 0, 5, TRUE, TRUE, TRUE, c(1L, NA, 3L)),
    "`rgb` must be three numbers"
  )
  expect_error(
    frame(0.5, 0, 5, TRUE, TRUE, TRUE, c(TRUE, TRUE, TRUE)),
    "`rgb` must be three numbers"
  )
  expect_error(spinner(0, "yes"), "`unicode` must be TRUE or FALSE")
  expect_identical(frame(0.5, 0, 4, FALSE, FALSE, FALSE, c(1L, 2L, 3L)), "##..")
})

test_that(
  paste0(
    "the animation draws one line in place on a terminal, glides, and ends ",
    "with a summary"
  ),
  {
    withr::local_envvar(c(NO_COLOR = NA, COLUMNS = "100"))
    a <- rmoriebricklayer:::.bl_anim_new("Test", 10, quiet = FALSE, tty = TRUE)
    expect_true(a$color)
    msgs <- capture.output(type = "message", {
      rmoriebricklayer:::.bl_anim_update(a, 5, "half", force = TRUE)
      # inside the frame interval: not drawn
      rmoriebricklayer:::.bl_anim_update(a, 5, "half")
      rmoriebricklayer:::.bl_anim_wait(a, 0.3)
      rmoriebricklayer:::.bl_anim_done(a, "Test: done")
    })
    txt <- paste(msgs, collapse = "\n")
    expect_match(txt, "\r", fixed = TRUE)
    expect_match(txt, "half", fixed = TRUE)
    expect_match(txt, "Test: done", fixed = TRUE)
    # the shown value moved toward 50% without jumping there in one frame, and
    # ends exactly at it
    expect_identical(a$shown, 0.5)
    b <- rmoriebricklayer:::.bl_anim_new("T", 4, quiet = FALSE, tty = TRUE)
    invisible(capture.output(
      type = "message",
      rmoriebricklayer:::.bl_anim_update(b, 4, force = TRUE)
    ))
    expect_gt(b$shown, 0)
    expect_lt(b$shown, 1)
  }
)

test_that("NO_COLOR, a pipe, and quiet each change what is drawn", {
  # R_CLI_NUM_COLORS and this package's option outrank NO_COLOR (as in cli);
  # pkgcheck's check sets one
  withr::local_envvar(c(NO_COLOR = "1", R_CLI_NUM_COLORS = NA))
  withr::local_options(rmoriebricklayer.numcol = NULL)
  a <- rmoriebricklayer:::.bl_anim_new("C", 3, quiet = FALSE, tty = TRUE)
  m <- capture.output(
    type = "message",
    rmoriebricklayer:::.bl_anim_update(a, 1, force = TRUE)
  )
  expect_false(any(grepl("\033", m, fixed = TRUE)))
  p <- rmoriebricklayer:::.bl_anim_new("P", 10, quiet = FALSE, tty = FALSE)
  m <- capture.output(
    type = "message",
    for (i in 1:10) {
      rmoriebricklayer:::.bl_anim_update(p, i, "x")
    }
  )
  expect_length(m, 10L)
  expect_match(m[10], "P: 10 of 10 \\(100%\\) x")
  q <- rmoriebricklayer:::.bl_anim_new("Q", 3, quiet = TRUE)
  expect_silent(rmoriebricklayer:::.bl_anim_update(q, 2, force = TRUE))
  expect_silent(rmoriebricklayer:::.bl_anim_done(q, "nothing"))
  expect_silent(rmoriebricklayer:::.bl_anim_wait(q, 0.01))
})

test_that("a download on a terminal draws the native bar", {
  withr::local_options(morie.progress = TRUE, morie.quiet = FALSE)
  src <- withr::local_tempfile(fileext = ".bin")
  writeBin(as.raw(rep(1:255, 4000)), src)
  dest <- withr::local_tempfile(fileext = ".bin")
  m <- capture.output(
    type = "message",
    bldl(
      paste0("file://", src),
      dest,
      allowfile = TRUE,
      label = "anim",
      size = file.size(src),
      tty = TRUE
    )
  )
  expect_true(any(grepl("anim", m)))
  expect_identical(file.size(dest), file.size(src))
})
