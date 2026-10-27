# Detect an injected effect of known size

Adds an effect of each given size to the data, reruns the whole
detection procedure, and reports how often it was found. The result is a
power curve, and the smallest size detected reliably is the smallest
effect the analysis could have seen. Use it before reporting a null
result, to show whether the analysis could have found an effect of the
size that matters.

## Usage

``` r
cpspwr(
  data,
  stat,
  inject,
  sizes = c(0, 0.2, 0.5),
  trt = NULL,
  n = 99L,
  reps = 10L,
  alpha = 0.05,
  seed = NULL
)
```

## Arguments

- data:

  A data frame, passed to `stat` and `inject`.

- stat:

  A function of one data frame returning a single finite number (for
  example a correlation or a difference in means).

- inject:

  A function of `(data, size)` returning the data with an effect of that
  size added. It is the caller's, because what counts as an effect of
  size 0.2 is a modelling decision and not something this function can
  guess.

- sizes:

  Numeric vector of effect sizes to try (default `c(0, 0.2, 0.5)`). `0`
  is added if absent, since the detection rate there is the
  false-positive rate and belongs on the same curve. Duplicates are
  removed and the sizes sorted.

- trt:

  Name of the column permuted to build the null, as in
  [`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md).
  Required.

- n:

  Permutations per test, a whole number of at least 9 (default 99).

- reps:

  Repetitions per size, a whole number of at least 1 (default 10). The
  detection rate at each size is out of this many, so its resolution is
  `1 / reps`.

- alpha:

  Significance threshold for counting a detection (default 0.05).

- seed:

  Optional integer seed; `NULL` (the default) uses the session's random
  number state.

## Value

A list of class `c("bricklayer_power", "list")`:

- `curve`:

  data frame with one row per size: `size`, `detected` (integer), `reps`
  (integer, the usable repetitions) and `rate` (`detected / reps`, `NA`
  when none was usable).

- `alpha`, `n`, `reps`, `treatment`:

  the settings used.

- `smadet`:

  the smallest positive size found at a rate of at least 0.8, or `NA`
  when no size reached it.

- `false_positive_rate`:

  the rate at size 0.

## Details

This is the positive control that
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
lacks: its four are all negative. Those establish that the finding is
not an artefact; this establishes that a real effect would not have been
missed. A study that passes every falsification control and has no power
against the effect it was looking for has not found that the effect is
absent – it has found nothing either way, and the two are routinely
reported as the same thing.

For each size (0 is always added) and each of `reps` repetitions, the
statistic is computed on the data passed through the injector, as
`inject(data, size)`, and a permutation null is built by shuffling the
`trt` column `n` times and recomputing the statistic. The two-sided
permutation p-value is \$\$p = \frac{1 + \\\\\|T^\*\| \ge \|T\|\\}{1 +
n\_{ok}}\$\$ over the \\n\_{ok}\\ permutations with a finite statistic
(Phipson and Smyth's correction, so \\p\\ is never 0), and the effect
counts as detected when \\p \le \alpha\\. A repetition whose injection
or observed statistic fails (error or non-finite value) is skipped and
not counted in `reps`. Since the data are the same in every repetition,
`inject` should add randomness of its own (new noise, a resampled
effect) when repetitions are meant to differ; otherwise only the
permutations vary.

The cost is \\\|sizes\| \times reps \times (n + 1)\\ evaluations of
`stat`. A progress bar is drawn on stderr unless
`options(morie.quiet = TRUE)`. With `seed`, R's random number state is
set for the run and restored afterwards; without it, the run uses and
advances the session's generator.

Errors: `data` not a data frame of at least 4 rows; `stat` or `inject`
not a function; `trt` missing or not a column; `n` below 9; `reps` below
1; `n` so small that \\1/(n+1) \> \alpha\\, so that nothing could ever
be detected.

## See also

[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
for the negative controls.

## Examples

``` r
set.seed(1)
d <- data.frame(x = rnorm(120), y = rnorm(120))
# inject a linear effect of x on y
inj <- function(z, size) {
  z$y <- z$y + size * z$x
  z
}
pw <- cpspwr(d, function(z) cor(z$x, z$y), inj,
                    sizes = c(0, 0.3, 0.6), trt = "x",
                    n = 99, reps = 5, seed = 42)
pw$curve
#>   size detected reps rate
#> 1  0.0        0    5    0
#> 2  0.3        5    5    1
#> 3  0.6        5    5    1
pw
#> ╭── Positive controls: an injected effect of known size ──────────╮
#> │   Permutations          99                                      │
#> │   Repetitions per size  5                                       │
#> │   Alpha                 0.05                                    │
#> │   Treatment             x                                       │
#> │   False positive rate   0                                       │
#> │   Smallest detected     0.3                                     │
#> │                                                                 │
#> │     size  detected  rate                                        │
#> │   ------  --------  ----                                        │
#> │   0.0000  0/5          0                                        │
#> │   0.3000  5/5          1                                        │
#> │   0.6000  5/5          1                                        │
#> │                                                                 │
#> │   smallest size detected at a rate of 0.8: 0.3;                 │
#> │   a null result is informative only about effects at least this │
#> │   large; smaller ones would have been missed.                   │
#> ╰─────────────────────────────────────────────────────────────────╯

# The rate at size 0 estimates the false-positive rate. With few
# repetitions it is usually 0, because alpha is small -- five draws
# at 0.05 come up empty about three times in four -- so read it as a
# sanity check that it is not LARGE, not as an estimate of alpha.
pw$curve[pw$curve$size == 0, "rate"]
#> [1] 0

# an injection with fresh noise each time, and effects too small to be
# detected in four repetitions: the smallest detected size is NA
inj2 <- function(z, size) {
  z$y <- z$y + size * z$x + stats::rnorm(nrow(z), sd = 0.5)
  z
}
cpspwr(d, function(z) cor(z$x, z$y), inj2, sizes = c(0.1, 0.2),
              trt = "x", n = 49, reps = 4, seed = 7)$smadet
#> [1] NA

# too few permutations to ever reach alpha = 0.05
try(cpspwr(d, function(z) cor(z$x, z$y), inj, trt = "x", n = 9))
#> Error : with 9 permutations the smallest p-value is 0.1, which is above alpha = 0.05: no size could ever be detected
```
