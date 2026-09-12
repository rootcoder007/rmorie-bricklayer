# Multivariate outliers by Mahalanobis distance

Ranks rows by how far they sit from the centre of the data ONCE THE
CORRELATIONS ARE ACCOUNTED FOR, which is what a per-column check cannot
do: a row can be unremarkable on every variable separately and still be
impossible jointly – a person 1.5 m tall weighing 140 kg is inside both
marginal ranges and outside the cloud.

## Usage

``` r
mahalanobis_outliers(data, alpha = 0.001, robust = TRUE)
```

## Arguments

- data:

  A data frame or numeric matrix; non-numeric columns are dropped. Rows
  with any missing value are skipped, and reported as `NA`.

- alpha:

  Significance level for the `outlier` flag (default 0.001, deliberately
  strict: at 0.05 one row in twenty is flagged by construction).

- robust:

  Use the median/MAD centre and scale (default `TRUE`).

## Value

A data frame of class `bricklayer_outliers` with `row`, `distance` (the
square root of the squared Mahalanobis distance), `p_value` and
`outlier`, ordered by descending distance.

## Details

Under multivariate normality the squared distance is chi-square on `p`
degrees of freedom, which gives the p-value and the cut-off.

`robust = TRUE` centres on the coordinate-wise median and scales by a
MAD-based covariance instead of the mean and sample covariance. This
matters more than it sounds: outliers inflate the very covariance used
to judge them, so with several of them the classical distance hides
exactly the rows it is meant to find (the masking effect).

## References

Mahalanobis PC (1936). On the generalised distance in statistics.
*Proceedings of the National Institute of Sciences of India* 2(1),
49–55.

## See also

[`core_tukey_fences()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_robust.md)
for the per-column version,
[`rule_within_n_mads()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
to turn it into a validation rule.

## Examples

``` r
set.seed(1)
n <- 200
df <- data.frame(height = stats::rnorm(n, 170, 10))
df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)

# A row that is ordinary on each variable but impossible jointly.
df[1, ] <- list(height = 150, weight = 140)

out <- mahalanobis_outliers(df)
head(out, 3)
#> ── Mahalanobis outliers (robust) ───────────────────────────────── 
#>   ! 1 of 3 rows beyond alpha = 0.001
#> 
#>  row distance p_value outlier
#>    1     9.45  <2e-16    TRUE
#>   61     2.76  0.0224   FALSE
#>   14     2.70  0.0258   FALSE
#> ────────────────────────────────────────────────────────────────── 

# It is flagged, even though neither value is a marginal outlier.
out$row[1] == 1
#> [1] TRUE
range(df$height)
#> [1] 147.8530 194.0162
range(df$weight)
#> [1]  67.07546 140.00000

# The classical version can be fooled by the outliers it should find.
mahalanobis_outliers(df, robust = FALSE)$distance[1] <
  mahalanobis_outliers(df, robust = TRUE)$distance[1]
#> [1] FALSE
```
