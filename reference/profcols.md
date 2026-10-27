# Column report for a data frame

One row per column: type, missingness, and the summaries that suit the
column's type – mean and standard deviation alongside their robust
counterparts (median, MAD) for a numeric column, and the number of
distinct levels plus the most common one for a categorical column.

## Usage

``` r
profcols(data, qnts = c(0.25, 0.5, 0.75))
```

## Arguments

- data:

  A data frame whose columns are profiled.

- qnts:

  Numeric vector of quantile probabilities to include for numeric
  columns, one column each named `q` and the percentage (`q25`, `q50`,
  ...); default the quartiles. `NULL` or an empty vector adds none.

## Value

A data frame of class `bricklayer_profile`, one row per column: the
type, the missing count and share, the number of distinct values, and
for a numeric column the counts of zero, negative and infinite values,
the classical and robust centre and spread, the range, the skewness, the
count outside the Tukey fences, and an
[`inlhist()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/inlhist.md)
sketch of its distribution. A categorical column reports its most common
value in `top` instead. The columns are `column`, `type` (the first
class), `n`, `n_missing`, `pct_missing`, `n_distinct`, `nzero`, `nneg`,
`ninf`, `mean`, `sd`, `median`, `mad`, `min`, `max`, `skewness`,
`n_outliers`, `hist`, `top` and one per quantile; a statistic that does
not apply to the column's type is `NA`. The print method formats the
numbers to four significant digits and shows the histogram last.

## Details

Reporting the classical and robust centres side by side is the point:
where they disagree, the column has outliers or a heavy tail, and the
mean is not describing it. That is visible in one glance here and in no
single number.

How the numbers are computed. A column is numeric when
[`is.numeric()`](https://rdrr.io/r/base/numeric.html) is `TRUE`; every
other column (character, factor, logical, `Date`, ...) is treated as
categorical, and `top` is its most frequent non-missing value as text
(ties broken by the order of `sort(table())`). For a numeric column,
over its non-missing values: `sd` is the sample standard deviation
(\\n - 1\\), `mad` the median absolute deviation scaled by 1.4826,
`skewness` the population moment ratio \\m_3 / m_2^{3/2}\\, `n_outliers`
the count outside the Tukey fences (1.5 interquartile ranges beyond the
quartiles), and the quantiles are type 7. Infinite values are counted in
`ninf` (and in `nneg`, `n_distinct`) and left out of every other numeric
statistic, which are taken over the finite values only: a column with an
infinite value keeps a finite mean and range, and a column with no
finite value has `NA` statistics. A progress bar is shown for wide
tables when `options(morie.progress)` allows it. Errors when `data` is
not a data frame, has no columns, or has duplicate or empty column
names.

## See also

[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
to compare two of these,
[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
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

profcols(df)
#> ╭── Column profile ─────────────────────────────────────────────────────────╮
#> │   Columns              4                                                  │
#> │   Rows                 100                                                │
#> │   Numeric              3                                                  │
#> │   With missing values  1                                                  │
#> │                                                                           │
#> │   column  type         n  n_missing  pct_missing  n_distinct  nzero  nneg │
#> │   ------  ---------  ---  ---------  -----------  ----------  -----  ---- │
#> │   clean   numeric    100          0            0         100      0    54 │
#> │   skewed  numeric    100          0            0         100      0    48 │
#> │   grade   character  100          0            0           3              │
#> │   gappy   numeric    100         10           10          90      0     0 │
#> │                                                                           │
#> │   column  ninf     mean       sd   median     mad     min      max        │
#> │   ------  ----  -------  -------  -------  ------  ------  -------        │
#> │   clean      0  -0.0535   0.9588  -0.1708  0.8777  -2.618    2.682        │
#> │   skewed     0   4.8741  50.0224   0.0445  0.9517  -2.738  500.000        │
#> │   grade                                                                   │
#> │   gappy      0   0.5019   0.2917   0.5243  0.3714   0.008    0.995        │
#> │                                                                           │
#> │   column  skewness  n_outliers  top      q25      q50     q75  hist       │
#> │   ------  --------  ----------  ---  -------  -------  ------  ---------- │
#> │   clean     0.3145           3       -0.7457  -0.1708  0.4220  ▁▁▃█▇█▃▃▂▁ │
#> │   skewed    9.8435           1       -0.7947   0.0445  0.6215  █        ▁ │
#> │   grade                         c                                         │
#> │   gappy    -0.0440           0        0.2545   0.5243  0.7339  █▆▆█▆▇█▆█▆ │
#> │                                                                           │
#> │   Where the mean and the median (or sd and mad) disagree, the column      │
#> │   has outliers or a heavy tail and the mean does not describe it;         │
#> │   n_outliers counts the values beyond the Tukey fences.                   │
#> ╰───────────────────────────────────────────────────────────────────────────╯

# The mean and the median agree on `clean` and disagree sharply on
# `skewed`, which is the outlier announcing itself.
p <- profcols(df)
p[p$column %in% c("clean", "skewed"), c("column", "mean", "median")]
#> ╭── Column profile ─────────────────────────────────────────────────────╮
#> │   Rows     2                                                          │
#> │   Columns  3                                                          │
#> │                                                                       │
#> │   column    mean   median                                             │
#> │   ------  ------  -------                                             │
#> │   clean   -0.054  -0.1708                                             │
#> │   skewed   4.874   0.0445                                             │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯

# The histogram column shows shape no summary number carries.
p[, c("column", "hist")]
#> ╭── Column profile ─────────────────────────────────────────────────────╮
#> │   Rows     4                                                          │
#> │   Columns  2                                                          │
#> │                                                                       │
#> │   column  hist                                                        │
#> │   ------  ----------                                                  │
#> │   clean   ▁▁▃█▇█▃▃▂▁                                                  │
#> │   skewed  █        ▁                                                  │
#> │   grade                                                               │
#> │   gappy   █▆▆█▆▇█▆█▆                                                  │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯

# Zeros, negatives and infinities are counted separately, because
# each breaks a different downstream computation (a log, a square
# root, an average).
p[, c("column", "nzero", "nneg", "ninf")]
#> ╭── Column profile ─────────────────────────────────────────────────────╮
#> │   Rows     4                                                          │
#> │   Columns  4                                                          │
#> │                                                                       │
#> │   column  nzero  nneg  ninf                                           │
#> │   ------  -----  ----  ----                                           │
#> │   clean       0    54     0                                           │
#> │   skewed      0    48     0                                           │
#> │   grade                                                               │
#> │   gappy       0     0     0                                           │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯

# deciles instead of quartiles
names(profcols(df, qnts = c(0.1, 0.9)))
#>  [1] "column"      "type"        "n"           "n_missing"   "pct_missing"
#>  [6] "n_distinct"  "nzero"       "nneg"        "ninf"        "mean"       
#> [11] "sd"          "median"      "mad"         "min"         "max"        
#> [16] "skewness"    "n_outliers"  "hist"        "top"         "q10"        
#> [21] "q90"        

# a table with no columns has nothing to profile
try(profcols(df[, 0]))
#> Error : `data` has no columns to profile
```
