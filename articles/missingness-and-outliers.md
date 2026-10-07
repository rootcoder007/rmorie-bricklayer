# Missingness, duplicates, outliers and distinct counts

Before a published table is analysed it should be looked at for the four
things that most often go wrong in ingestion: missing values with a
pattern, duplicated rows, rows that are ordinary on each column but
impossible jointly, and identifier columns with fewer distinct values
than they should have.

## Missingness

``` r

df <- data.frame(a = c(1, NA, 3), b = c(NA, NA, 3), c = 1:3)
missingness_summary(df)
#>             n_rows             n_cols          n_missing        pct_missing 
#>            3.00000            3.00000            3.00000           33.33333 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>            1.00000           33.33333            2.00000            0.00000
missingness_summary(data.frame(x = 1:3, y = 4:6))
#>             n_rows             n_cols          n_missing        pct_missing 
#>                  3                  2                  0                  0 
#>    n_complete_rows  pct_complete_rows n_cols_any_missing n_cols_all_missing 
#>                  3                100                  0                  0
```

A pattern matters more than a rate:
[`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md)
tabulates the combinations of missing columns,
[`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)
finds runs of consecutive missing rows (a feed that stopped), and
[`missingness_map()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_map.md)
draws an inline text map of where the gaps are.

``` r

set.seed(1)
big <- data.frame(id = 1:40, v = stats::rnorm(40), w = stats::rnorm(40))
big$v[c(10:14, 30)] <- NA
big$w[c(10:14)] <- NA
missingness_pattern(big)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, v, w
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...     34     85.0         0        
#>      .XX      5     12.5         2    v, w
#>      .X.      1      2.5         1       v
#> ──────────────────────────────────────────────────────────────────
missing_runs(big)
#> ── Runs of consecutive missing values ──────────────────────────── 
#>  column start end length
#>       v    10  14      5
#>       w    10  14      5
#> ──────────────────────────────────────────────────────────────────
```

Five rows missing both `v` and `w` in a block is a different problem
from six scattered gaps; the first points at the source, the second at
the records.

## Duplicates

``` r

d <- data.frame(id = c(1, 2, 2, 3, 3, 3), x = c("a", "b", "b", "c", "c", "d"))
duplicate_rows(d)
#>   id x dupe_count
#> 1  2 b          2
#> 2  2 b          2
#> 3  3 c          2
#> 4  3 c          2
duplicate_rows(d, columns = "id")
#>   id x dupe_count
#> 1  2 b          2
#> 2  2 b          2
#> 3  3 c          3
#> 4  3 c          3
#> 5  3 d          3
```

Full-row duplicates are usually an ingestion artefact; duplicates on the
key alone are usually a data-model finding (the key is not a key).

## Multivariate outliers

A row can be inside every column’s range and still be impossible: short
and heavy, young and retired. The Mahalanobis distance measures how far
a row is from the centre of the joint distribution in the metric of its
covariance. The **robust** version uses the median and the MAD, so a
cluster of bad rows cannot drag the centre toward itself and hide:

``` r

set.seed(1)
n <- 200
df <- data.frame(height = stats::rnorm(n, 170, 10))
df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)
df[1, ] <- list(height = 155, weight = 100)      # ordinary on each, unlikely jointly

out <- mahalanobis_outliers(df)
head(out, 3)
#> ── Mahalanobis outliers (robust) ───────────────────────────────── 
#>   ! 1 of 3 rows beyond alpha = 0.001
#> 
#>  row distance  p_value log_p_value outlier
#>    1     4.30 9.61e-05   -9.249997    TRUE
#>   32     2.90   0.0149   -4.204956   FALSE
#>   14     2.81   0.0194   -3.940191   FALSE
#> ──────────────────────────────────────────────────────────────────
out$row[1] == 1
#> [1] TRUE
range(df$height[-1])
#> [1] 147.8530 194.0162
range(df$weight[-1])
#> [1]  67.07546 101.82631
```

With a cluster of bad rows, the classical distance of a bad row is
*smaller* than the robust one, because the cluster has pulled the
classical centre toward itself:

``` r

bad <- df
bad[2:21, ] <- list(height = 150, weight = 110)
d_classical <- mahalanobis_outliers(bad, robust = FALSE)
d_robust <- mahalanobis_outliers(bad, robust = TRUE)
d_classical$distance[d_classical$row == 2] < d_robust$distance[d_robust$row == 2]
#> [1] TRUE
```

The flag threshold is a chi-square quantile (`alpha = 0.001` by default)
with the number of columns as degrees of freedom. A duplicated column
has no distance defined and is refused.

## Distinct counts in fixed memory

How many distinct identifiers does a 200-million-row file have? Holding
them all in a set needs memory proportional to the answer. A HyperLogLog
sketch answers to within about 1% in a few kilobytes, can be fed block
by block, and two sketches of two files merge into one:

``` r

set.seed(1)
x <- sample(1:5000, 200000, replace = TRUE)
distinct_count(distinct_sketch(x))
#> [1] 5039.269
length(unique(x))
#> [1] 5000

s <- distinct_sketch(x[1:100000])
s <- distinct_sketch(x[100001:200000], registers = s)
distinct_count(s)
#> [1] 5039.269

a <- distinct_sketch(x[1:100000])
b <- distinct_sketch(x[100001:200000])
distinct_count(sketch_merge(a, b))
#> [1] 5039.269
```

Small cardinalities are near-exact through linear counting, and an empty
input has no distinct values:

``` r

distinct_count(distinct_sketch(c("a", "b", "c", "a", "b")))
#> [1] 3.000275
distinct_count(distinct_sketch(character(0)))
#> [1] 0
```

An identifier column whose distinct count is far below its row count is
not an identifier;
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
uses the same reasoning to decide which columns to compare as
categories.

## Does the data look fabricated or truncated?

Benford’s law gives the expected distribution of leading digits for a
quantity that spans several orders of magnitude; a strong departure is a
reason to ask how the numbers were produced (rounding, capping,
invention), never a proof of anything on its own:

``` r

set.seed(3)
benford_test(10^stats::runif(2000, 0, 6))$p_value
#> [1] 0.2599175
benford_test(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))$p_value
#> [1] 9.672166e-161
```

## Order of operations

1.  [`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)
    and
    [`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md);
    decide whether gaps are structural.
2.  [`duplicate_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/duplicate_rows.md)
    on the full row and on the key.
3.  [`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md)
    on the numeric columns, robust.
4.  [`distinct_sketch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_distinct.md)
    on identifiers when the table is large.
5.  Then, and only then, the analysis.
