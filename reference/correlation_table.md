# Full pairwise correlation table

Every numeric pair's correlation in long form – one row per pair, which
is easier to sort, filter and join than a matrix. The counterpart of
`corrr::correlate()`.

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

  Minimum complete pairs required before a correlation is computed
  (default 3). Below it the pair is `NA` rather than a number computed
  from almost nothing.

## Value

A data frame of class `bricklayer_cortable` with `x`, `y`, `correlation`
and `n_pairs`.

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
```
