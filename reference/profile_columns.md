# Column report for a data frame

One row per column: type, missingness, and the summaries that suit the
column's type – mean and standard deviation alongside their robust
counterparts (median, MAD) for a numeric column, and the number of
distinct levels plus the most common one for a categorical column.

## Usage

``` r
profile_columns(data, quantiles = c(0.25, 0.5, 0.75))
```

## Arguments

- data:

  A data frame.

- quantiles:

  Quantile probabilities to include for numeric columns (default the
  quartiles).

## Value

A data frame of class `bricklayer_profile`, one row per column: the
type, the missing count and share, the number of distinct values, and
for a numeric column the counts of zero, negative and infinite values,
the classical and robust centre and spread, the range, the skewness, the
count outside the Tukey fences, and an
[`inline_hist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/inline_hist.md)
sketch of its distribution. A categorical column reports its most common
value in `top` instead.

## Details

Reporting the classical and robust centres side by side is the point:
where they disagree, the column has outliers or a heavy tail, and the
mean is not describing it. That is visible in one glance here and in no
single number.

## See also

[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
to compare two of these,
[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md)
for the underlying kernel.

## Examples

``` r
set.seed(9)
df <- data.frame(
  clean = stats::rnorm(100),
  skewed = c(stats::rnorm(99), 500),
  grade = sample(c("a", "b", "c"), 100, TRUE),
  gappy = c(rep(NA, 10), stats::runif(90))
)

profile_columns(df)
#> ── Column profile ──────────────────────────────────────────────── 
#>  column      type     n n_missing pct_missing n_distinct n_zero n_negative
#>   clean   numeric   100         0           0        100      0         54
#>  skewed   numeric   100         0           0        100      0         48
#>   grade character   100         0           0          3      –          –
#>   gappy   numeric   100        10          10         90      0          0
#>  n_infinite     mean     sd  median    mad      min    max skewness n_outliers
#>           0 -0.05351 0.9588 -0.1708 0.8777   -2.618  2.682   0.3145          3
#>           0    4.874  50.02 0.04449 0.9517   -2.738    500    9.844          1
#>           –        –      –       –      –        –      –        –          –
#>           0   0.5019 0.2917  0.5243 0.3714 0.007639 0.9953 -0.04396          0
#>  top     q25     q50    q75       hist
#>    – -0.7457 -0.1708  0.422 ▁▁▃█▇█▃▃▂▁
#>    – -0.7947 0.04449 0.6215 █        ▁
#>    c       –       –      –          –
#>    –  0.2545  0.5243 0.7339 █▆▆█▆▇█▆█▆
#> ────────────────────────────────────────────────────────────────── 

# The mean and the median agree on `clean` and disagree sharply on
# `skewed`, which is the outlier announcing itself.
p <- profile_columns(df)
p[p$column %in% c("clean", "skewed"), c("column", "mean", "median")]
#>   column        mean      median
#> 1  clean -0.05351488 -0.17078983
#> 2 skewed  4.87405667  0.04448896

# The histogram column shows shape no summary number carries.
p[, c("column", "hist")]
#>   column       hist
#> 1  clean ▁▁▃█▇█▃▃▂▁
#> 2 skewed █        ▁
#> 3  grade       <NA>
#> 4  gappy █▆▆█▆▇█▆█▆

# Zeros, negatives and infinities are counted separately, because
# each breaks a different downstream computation (a log, a square
# root, an average).
p[, c("column", "n_zero", "n_negative", "n_infinite")]
#>   column n_zero n_negative n_infinite
#> 1  clean      0         54          0
#> 2 skewed      0         48          0
#> 3  grade     NA         NA         NA
#> 4  gappy      0          0          0
```
