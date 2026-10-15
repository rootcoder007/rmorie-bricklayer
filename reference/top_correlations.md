# Strongest pairwise correlations in a data frame

Ranks the numeric column pairs by the strength of their association and
returns the strongest, so a wide table's structure can be read without
squinting at a correlation matrix. Use it on a new data set to find
near-duplicate columns, derived columns and the relationships worth a
closer look.

## Usage

``` r
top_correlations(data, n = 10L, method = c("spearman", "pearson"), min_abs = 0)
```

## Arguments

- data:

  A data frame; non-numeric columns are ignored.

- n:

  Number of pairs to return, one positive whole number (default 10).

- method:

  `"spearman"` (default) or `"pearson"`.

- min_abs:

  Report only pairs whose absolute correlation reaches this, a number in
  \\\[0, 1\]\\ (default 0).

## Value

A data frame of class `c("bricklayer_correlations", "data.frame")` with
`x` and `y` (character, column names), `correlation` (numeric) and
`abs_correlation` (numeric), strongest first, at most `n` rows; the
method is in `attr(, "method")`. The print method draws a signed bar per
pair.

## Details

Spearman is the default deliberately. Pearson measures LINEAR
association only, so it understates a relationship that is perfectly
monotone but curved, and a single outlier can manufacture or destroy it.
On data you have not yet inspected – which is the situation this
function is for – the rank correlation is the safer question to ask.

Non-numeric columns are ignored. Each pair uses the rows where both
values are present; a pair with fewer than three such rows, or with a
constant column, has no correlation and is left out. Pairs are ranked by
absolute correlation, those below `min_abs` dropped, and the first `n`
returned.
[`correlation_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/correlation_table.md)
gives every pair, with the number of rows behind each. A progress bar is
drawn on stderr for many pairs unless `options(morie.quiet = TRUE)`.

Errors: `data` not a data frame; fewer than two numeric columns; `n` not
one positive whole number; `min_abs` not one number in \\\[0, 1\]\\; an
invalid `method`.

## See also

[`core_cor_spearman()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_rank.md),
[`core_cov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_cov.md),
[`correlation_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/correlation_table.md)

## Examples

``` r
set.seed(1)
n <- 200
df <- data.frame(
  a = stats::rnorm(n),
  b = stats::rnorm(n),
  grade = sample(letters[1:3], n, TRUE)
)
df$c <- df$a * 2 + stats::rnorm(n, sd = 0.1) # strongly related to a
df$d <- exp(df$a) # monotone but curved

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

# Filter to the pairs worth looking at, and keep the top two.
top_correlations(df, n = 2, min_abs = 0.5)
#> ── Top correlations (spearman) ─────────────────────────────────── 
#>  x y correlation                  plot
#>  a d       1.000           |##########
#>  a c       0.998           |##########
#> ────────────────────────────────────────────────────────────────── 

# a threshold above 1 is an error
try(top_correlations(df, min_abs = 2))
#> Error : `min_abs` must be a single value in [0, 1]
```
