# Full pairwise correlation table

Computes the correlation of every pair of numeric columns and returns it
in long form – one row per pair, which is easier to sort, filter and
join than a matrix – with the number of complete pairs each figure rests
on. The counterpart of `corrr::correlate()`.

## Usage

``` r
correlation_table(data, method = c("spearman", "pearson"), min_pairs = 3L)
```

## Arguments

- data:

  A data frame; non-numeric columns are ignored.

- method:

  `"spearman"` (default) or `"pearson"`. See
  [`top_correlations()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/top_correlations.md)
  for why the rank correlation is the default.

- min_pairs:

  Minimum complete pairs required before a correlation is computed, a
  whole number of at least 2 (default 3). Below it the pair is `NA`
  rather than a number computed from almost nothing.

## Value

A data frame of class `c("bricklayer_cortable", "data.frame")` with one
row per pair of numeric columns and the columns `x` and `y` (character,
the column names), `correlation` (numeric, in \\\[-1, 1\]\\ or `NA`) and
`n_pairs` (integer); the method is in `attr(, "method")`.

## Details

Non-numeric columns are ignored. For each pair, rows where either value
is missing are dropped (pairwise deletion), so different pairs can rest
on different rows; `n_pairs` says how many. Spearman's rank correlation
(the default) is the Pearson correlation of the ranks, robust to
outliers and to monotone transformations; see
[`top_correlations()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/top_correlations.md)
for why it is the default. A pair with fewer than `min_pairs` complete
rows, or with a constant column (no variance), gets `NA`. The pairs are
listed in column order
([`utils::combn()`](https://rdrr.io/r/utils/combn.html)). A progress bar
is drawn on stderr for many pairs unless `options(morie.quiet = TRUE)`.

Errors: `data` not a data frame; fewer than two numeric columns;
`min_pairs` not a whole number of at least 2; an invalid `method`.

## See also

[`top_correlations()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/top_correlations.md)
for just the strongest,
[`core_cov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_cov.md)
for the matrix form.

## Examples

``` r
set.seed(1)
df <- data.frame(a = stats::rnorm(100), b = stats::rnorm(100))
df$c <- df$a + stats::rnorm(100, sd = 0.2)

correlation_table(df)
#> ── Correlations (spearman) ─────────────────────────────────────── 
#>  x y correlation n_pairs
#>  a b       0.039     100
#>  a c       0.967     100
#>  b c       0.015     100
#> ────────────────────────────────────────────────────────────────── 

# Pearson instead of Spearman
correlation_table(df, method = "pearson")
#> ── Correlations (pearson) ──────────────────────────────────────── 
#>  x y correlation n_pairs
#>  a b      -0.001     100
#>  a c       0.975     100
#>  b c      -0.012     100
#> ────────────────────────────────────────────────────────────────── 

# n_pairs shows how much data each figure rests on.
gappy <- df
gappy$a[1:80] <- NA
correlation_table(gappy)
#> ── Correlations (spearman) ─────────────────────────────────────── 
#>  x y correlation n_pairs
#>  a b       0.165      20
#>  a c       0.959      20
#>  b c       0.015     100
#> ────────────────────────────────────────────────────────────────── 

# A pair with too little overlap is NA, not a number from nothing.
thin <- df
thin$a[1:99] <- NA
correlation_table(thin)$correlation
#> [1]         NA         NA 0.01508551

# one numeric column cannot be correlated
try(correlation_table(data.frame(a = 1:5, b = letters[1:5])))
#> Error : need at least two numeric columns to correlate
```
