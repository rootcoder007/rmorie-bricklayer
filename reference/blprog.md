# Live progress for long-running work

Makes a progress bar for a loop or a long computation: the animated bar
of
[`bldl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bldl.md),
redrawn in place at no more than 12 frames a second, when the console
can redraw a line – a terminal, or the RStudio, Positron, R.app or
RKWard console (never a knitr or Jupyter notebook; the options
`rmoriebricklayer.dynamic` or `cli.dynamic`, or the environment variable
`R_CLI_DYNAMIC`, override the choice). In the RStudio or Positron
console the bar is drawn on stdout, elsewhere on stderr. Otherwise a
milestone line goes to stderr at each tenth, and nothing is shown when
quiet. With `total = 0` the work has no count, and the bar is a spinner
with the time so far and the current stage (the `info` text), with a
line at each new stage when the console cannot redraw.

## Usage

``` r
blprog(label, total, quiet = NULL, color = "blue", delay = NULL)
```

## Arguments

- label:

  A short name for the work, shown before the bar.

- total:

  The number of steps, or 0 when the work has no count.

- quiet:

  `TRUE`, `FALSE`, or `NULL` to follow the session (see above).

- color:

  The bar's colour: `"blue"`, `"green"`, `"red"`, `"violet"` or
  `"amber"`.

- delay:

  Seconds of work before anything is drawn; `NULL` takes the package's
  0.75.

## Value

An object of class `rmbl_progress`, a list of functions:
`update(done, info = NULL)` sets the steps done (and the text after the
bar), `tick(by = 1, info = NULL)` adds `by` steps, `wait(seconds)`
sleeps while keeping the animation moving, and `done(summary = NULL)`
ends the bar, clears the line and, when the bar was shown, writes
`summary` on its own line. Each returns the object invisibly.

## Details

Progress is shown when a person is watching: an interactive session, or
a command line that sets `options(morie.progress = TRUE)`.
`options(morie.quiet = TRUE)` or `quiet = TRUE` silences it.

Nothing is drawn until the work has run for `delay` seconds, so a fast
call never flashes a bar. A bar made inside a function while a bar made
by a calling function is still running stays silent, so nested work
shows one bar, for the outer loop.

Updates are cheap: when quiet an update only stores the value, and when
drawing, frames are throttled, so `$tick()` can be called on every
iteration of a loop. Call `$done()` through
[`on.exit()`](https://rdrr.io/r/base/on.exit.html) right after making
the bar, so the line is cleared and the bar is released even when the
work fails or is interrupted:


    p <- blprog("bootstrap", B)
    on.exit(p$done(), add = TRUE)
    for (b in seq_len(B)) {
      ...
      p$tick(info = sprintf("resample %d/%d", b, B))
    }

`$done()` may be called more than once; only the first call acts.

## Examples

``` r
p <- blprog("squares", 50, delay = 0)
for (i in 1:50) {
  x <- sum(seq_len(i)^2)
  p$tick(info = sprintf("step %d/50", i))
}
p$done("squares: 50 steps")

# work with no count: a spinner and the stage
f <- function() {
  p <- blprog("model", 0, delay = 0)
  on.exit(p$done(), add = TRUE)
  p$update(info = "fitting")
  p$wait(0.2)
  p$update(info = "writing")
  invisible(TRUE)
}
f()
```
