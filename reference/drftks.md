# Two-sample Kolmogorov-Smirnov test (C backend)

Tests whether two numeric samples come from the same distribution, for
example a column in a pinned data extract and the same column in a fresh
download. It needs no assumption about the shape of either distribution,
and it reacts to any kind of change: a shift, a change in spread, or a
change in shape. It is the numeric test that
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
runs on every shared numeric or date column.

## Usage

``` r
drftks(x, y)
```

## Arguments

- x, y:

  Numeric vectors, the reference and the new sample. Logical vectors are
  read as 0/1.

## Value

A named length-3 numeric: `statistic` (the KS \\D\\) , `p_value`, and
`neff` (the harmonic-style effective size \\n_xn_y/(n_x+n_y)\\). It has
class `c("rmbl_drftks", "rmbl_measure", "numeric")`, so it prints as a
box with its inputs (kept in attribute `"lakner"`); arithmetic, `[`,
[`c()`](https://rdrr.io/r/base/c.html) and
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) give plain
numbers.

## Details

The statistic is the largest vertical gap between the two empirical
distribution functions, with the asymptotic two-sided p-value from the
Kolmogorov distribution. Distribution-free: it assumes nothing about the
shape of either sample, which is what makes it the right first test on a
column whose distribution was never specified.

The p-value is the ASYMPTOTIC one, \\2\sum_k (-1)^{k-1} e^{-2k^2t^2}\\
with \\t = \sqrt{n\_{\mathrm{eff}}}D\\. It is accurate for moderate
samples and conservative for small ones; for an exact small-sample
p-value use [`stats::ks.test()`](https://rdrr.io/r/stats/ks.test.html).
Ties are handled by comparing the two EDFs at each distinct value, so
tied data does not produce a warning the way
[`ks.test()`](https://rdrr.io/r/stats/ks.test.html) does.

Missing values are dropped. Errors: non-numeric input (character,
factor, list), any infinite value, or no non-missing value left in
either sample. One value per sample is enough to compute the statistic,
but the p-value is only meaningful for samples of a few dozen or more.

## See also

[`drftpsi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftpsi.md),
[`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md),
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)

## Examples

``` r
set.seed(1)
ref <- stats::rnorm(200)

# The same distribution: a small D and a large p-value.
drftks(ref, stats::rnorm(200))
#> ╭── Two-sample Kolmogorov-Smirnov test ───────────────────────────────────────╮
#> │   Samples  200 and 200 values                                               │
#> │                                                                             │
#> │   statistic  value                                                          │
#> │   ---------  -----                                                          │
#> │   statistic  0.06                                                           │
#> │   p_value    0.864                                                          │
#> │   neff       100                                                            │
#> │                                                                             │
#> │   No difference in distribution is detected (p = 0.864, not below 0.05).    │
#> │   At its widest the two cumulative distributions are 6.0 percentage points  │
#> │   apart.                                                                    │
#> │                                                                             │
#> │   D is the largest gap between the two empirical distribution               │
#> │   functions. The p-value is the asymptotic one: rough below a few           │
#> │   dozen values; stats::ks.test() gives an exact one.                        │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# A shifted distribution is detected.
drftks(ref, stats::rnorm(200, mean = 0.8))
#> ╭── Two-sample Kolmogorov-Smirnov test ───────────────────────────────────────╮
#> │   Samples  200 and 200 values                                               │
#> │                                                                             │
#> │   statistic  value                                                          │
#> │   ---------  -------                                                        │
#> │   statistic  0.325                                                          │
#> │   p_value    < 0.001                                                        │
#> │   neff       100                                                            │
#> │                                                                             │
#> │   The two samples differ in distribution (p < 0.001, below 0.05).           │
#> │   At its widest the two cumulative distributions are 32.5 percentage        │
#> │   points apart.                                                             │
#> │                                                                             │
#> │   D is the largest gap between the two empirical distribution               │
#> │   functions. The p-value is the asymptotic one: rough below a few           │
#> │   dozen values; stats::ks.test() gives an exact one.                        │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# So is a change in spread alone, which a mean comparison would miss.
drftks(ref, stats::rnorm(200, sd = 2.5))
#> ╭── Two-sample Kolmogorov-Smirnov test ───────────────────────────────────────╮
#> │   Samples  200 and 200 values                                               │
#> │                                                                             │
#> │   statistic  value                                                          │
#> │   ---------  -------                                                        │
#> │   statistic  0.315                                                          │
#> │   p_value    < 0.001                                                        │
#> │   neff       100                                                            │
#> │                                                                             │
#> │   The two samples differ in distribution (p < 0.001, below 0.05).           │
#> │   At its widest the two cumulative distributions are 31.5 percentage        │
#> │   points apart.                                                             │
#> │                                                                             │
#> │   D is the largest gap between the two empirical distribution               │
#> │   functions. The p-value is the asymptotic one: rough below a few           │
#> │   dozen values; stats::ks.test() gives an exact one.                        │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# The statistic agrees with stats::ks.test().
a <- stats::rnorm(60); b <- stats::rnorm(45, 0.6)
all.equal(drftks(a, b)[["statistic"]],
          as.numeric(suppressWarnings(stats::ks.test(a, b))$statistic))
#> [1] TRUE

# Identical samples have nothing to report.
drftks(ref, ref)[["statistic"]]
#> [1] 0
```
