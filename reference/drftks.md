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
`neff` (the harmonic-style effective size \\n_xn_y/(n_x+n_y)\\).

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
#>   statistic     p_value        neff 
#>   0.0600000   0.8642828 100.0000000 

# A shifted distribution is detected.
drftks(ref, stats::rnorm(200, mean = 0.8))
#>    statistic      p_value         neff 
#> 3.250000e-01 1.338317e-09 1.000000e+02 

# So is a change in spread alone, which a mean comparison would miss.
drftks(ref, stats::rnorm(200, sd = 2.5))
#>    statistic      p_value         neff 
#> 3.150000e-01 4.813445e-09 1.000000e+02 

# The statistic agrees with stats::ks.test().
a <- stats::rnorm(60); b <- stats::rnorm(45, 0.6)
all.equal(drftks(a, b)[["statistic"]],
          as.numeric(suppressWarnings(stats::ks.test(a, b))$statistic))
#> [1] TRUE

# Identical samples have nothing to report.
drftks(ref, ref)[["statistic"]]
#> [1] 0
```
