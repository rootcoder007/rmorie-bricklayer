# Full pairwise correlation table

Computes the correlation of every pair of numeric columns and returns it
in long form – one row per pair, which is easier to sort, filter and
join than a matrix – with the number of complete pairs each figure rests
on. The counterpart of `corrr::correlate()`.

## Usage

``` r
cortbl(data, meth = c("spearman", "pearson"), minprs = 3L)
```

## Arguments

- data:

  A data frame; its numeric columns are correlated in pairs.

- meth:

  `"spearman"` (default) or `"pearson"`. See
  [`topcors()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md)
  for why the rank correlation is the default.

- minprs:

  Minimum complete pairs required before a correlation is computed, a
  whole number of at least 2 (default 3). Below it the pair is `NA`
  rather than a number computed from almost nothing.

## Value

A data frame of class `c("bricklayer_cortable", "data.frame")` with one
row per pair of numeric columns and the columns `x` and `y` (character,
the column names), `correlation` (numeric, in \\\[-1, 1\]\\ or `NA`) and
`nprs` (integer); the method is in `attr(, "method")`.

## Details

Non-numeric columns are ignored. For each pair, rows where either value
is missing are dropped (pairwise deletion), so different pairs can rest
on different rows; `nprs` says how many. Spearman's rank correlation
(the default) is the Pearson correlation of the ranks, robust to
outliers and to monotone transformations; see
[`topcors()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md)
for why it is the default. A pair with fewer than `minprs` complete
rows, or with a constant column (no variance), gets `NA`. The pairs are
listed in column order
([`utils::combn()`](https://rdrr.io/r/utils/combn.html)). A progress bar
is drawn on stderr for many pairs unless `options(morie.quiet = TRUE)`.

Errors: `data` not a data frame; fewer than two numeric columns;
`minprs` not a whole number of at least 2; an invalid `meth`.

## See also

[`topcors()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md)
for just the strongest,
[`ccovm()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ccovm.md)
for the matrix form.

## Examples

``` r
set.seed(1)
df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100))
df$c <- df$a + stats::rnorm(100, sd = 0.2)

cortbl(df)
#> ╭── Correlations (spearman) ──────────────────────────────────────────────╮
#> │   Method         Spearman (rank)                                        │
#> │   Pairs          3                                                      │
#> │   Strongest |r|  0.9665                                                 │
#> │                                                                         │
#> │   x  y  correlation  nprs                                               │
#> │   -  -  -----------  ----                                               │
#> │   a  b       0.0387   100                                               │
#> │   a  c       0.9665   100                                               │
#> │   b  c       0.0151   100                                               │
#> │                                                                         │
#> │   Each row is one pair of numeric columns, over the rows where both are │
#> │   present (nprs); a correlation is blank when too few pairs remain.     │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# Pearson instead of Spearman
cortbl(df, meth = "pearson")
#> ╭── Correlations (pearson) ───────────────────────────────────────────────╮
#> │   Method         pearson                                                │
#> │   Pairs          3                                                      │
#> │   Strongest |r|  0.9747                                                 │
#> │                                                                         │
#> │   x  y  correlation  nprs                                               │
#> │   -  -  -----------  ----                                               │
#> │   a  b      -0.0010   100                                               │
#> │   a  c       0.9747   100                                               │
#> │   b  c      -0.0120   100                                               │
#> │                                                                         │
#> │   Each row is one pair of numeric columns, over the rows where both are │
#> │   present (nprs); a correlation is blank when too few pairs remain.     │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# nprs shows how much data each figure rests on.
gappy <- df
gappy$a[1:80] <- NA
cortbl(gappy)
#> ╭── Correlations (spearman) ──────────────────────────────────────────────╮
#> │   Method         Spearman (rank)                                        │
#> │   Pairs          3                                                      │
#> │   Strongest |r|  0.9594                                                 │
#> │                                                                         │
#> │   x  y  correlation  nprs                                               │
#> │   -  -  -----------  ----                                               │
#> │   a  b        0.165    20                                               │
#> │   a  c        0.959    20                                               │
#> │   b  c        0.015   100                                               │
#> │                                                                         │
#> │   Each row is one pair of numeric columns, over the rows where both are │
#> │   present (nprs); a correlation is blank when too few pairs remain.     │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# A pair with too little overlap is NA, not a number from nothing.
thin <- df
thin$a[1:99] <- NA
cortbl(thin)$correlation
#> [1]         NA         NA 0.01508551

# one numeric column cannot be correlated
try(cortbl(data.frame(a = 1:5, b = letters[1:5])))
#> Error : cortbl: need at least two numeric columns to correlate
```
