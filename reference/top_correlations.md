# Strongest pairwise correlations in a data frame

Ranks the numeric column pairs by the strength of their association, so
a wide table's structure can be read without squinting at a correlation
matrix.

## Usage

``` r
top_correlations(data, n = 10L, method = c("spearman", "pearson"), min_abs = 0)
```

## Arguments

- data:

  A data frame; non-numeric columns are ignored.

- n:

  Number of pairs to return (default 10).

- method:

  `"spearman"` (default) or `"pearson"`.

- min_abs:

  Report only pairs whose absolute correlation reaches this (default 0).

## Value

A data frame of class `bricklayer_correlations` with `x`, `y`,
`correlation` and `abs_correlation`, strongest first.

## Details

Spearman is the default deliberately. Pearson measures LINEAR
association only, so it understates a relationship that is perfectly
monotone but curved, and a single outlier can manufacture or destroy it.
On data you have not yet inspected – which is the situation this
function is for – the rank correlation is the safer question to ask.

## See also

[`core_cor_spearman()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_rank.md),
[`core_cov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_cov.md)

## Examples

``` r
set.seed(1)
n <- 200
df <- data.frame(
  a = stats::rnorm(n),
  b = stats::rnorm(n),
  grade = sample(letters[1:3], n, TRUE)
)
df$c <- df$a * 2 + stats::rnorm(n, sd = 0.1)   # strongly related to a
df$d <- exp(df$a)                              # monotone but curved

top_correlations(df)
#> ── Top correlations (spearman) ─────────────────────────────────── 
#>  x y correlation                  plot
#>  a d       1.000           |##########
#>  a c       0.998           |##########
#>  c d       0.998           |##########
#>  a b      -0.062          #|          
#>  b d      -0.062          #|          
#>  b c      -0.060          #|          
#> ────────────────────────────────────────────────────────────────── 

# The curved pair is ranked correctly by Spearman and understated by
# Pearson, which is why Spearman is the default.
tc <- top_correlations(df, method = "spearman")
tc[tc$x == "a" & tc$y == "d", "correlation"]
#> [1] 1
tp <- top_correlations(df, method = "pearson")
tp[tp$x == "a" & tp$y == "d", "correlation"]
#> [1] 0.8496382

# Filter to the pairs worth looking at.
top_correlations(df, min_abs = 0.5)
#> ── Top correlations (spearman) ─────────────────────────────────── 
#>  x y correlation                  plot
#>  a d       1.000           |##########
#>  a c       0.998           |##########
#>  c d       0.998           |##########
#> ────────────────────────────────────────────────────────────────── 
```
