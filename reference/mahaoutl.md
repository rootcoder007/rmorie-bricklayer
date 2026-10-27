# Multivariate outliers by Mahalanobis distance

Finds the rows of a numeric table that are unusual as a combination of
values, not just on one variable at a time, and gives each row a
distance, a p-value and an outlier flag. Use it before modelling to find
records that are probably data-entry or linkage errors.

## Usage

``` r
mahaoutl(data, alpha = 0.001, robust = TRUE)
```

## Arguments

- data:

  A data frame or numeric matrix; non-numeric columns are dropped. Rows
  with any missing value are skipped, and reported as `NA`.

- alpha:

  Significance level for the `outlier` flag (default 0.001, deliberately
  strict: at 0.05 one row in twenty is flagged by construction).

- robust:

  Use the median/MAD centre and scale (default `TRUE`) .

## Value

A data frame of class `bricklayer_outliers` with `row`, `distance` (the
square root of the squared Mahalanobis distance), `p_value`, `logpvalue`
(the log of the chi-square upper tail, which keeps its information where
`p_value` underflows to 0) and `outlier` (logical), ordered by
descending distance, with skipped rows (`NA` distance) last. `row` is
the row number in `data`. The attributes `robust` and `alpha` record the
settings. The print method shows the number of flagged rows and the ten
most distant.

## Details

Ranks rows by how far they sit from the centre of the data ONCE THE
CORRELATIONS ARE ACCOUNTED FOR, which is what a per-column check cannot
do: a row can be unremarkable on every variable separately and still be
impossible jointly – a person 1.5 m tall weighing 140 kg is inside both
marginal ranges and outside the cloud.

With centre \\c\\ and scatter matrix \\S\\, the squared distance of row
\\x\\ is \$\$d^2 = (x - c)^\top S^{-1} (x - c).\$\$ Under multivariate
normality the squared distance is chi-square on `p` degrees of freedom
(the number of numeric columns), which gives the p-value and the
cut-off.

`robust = TRUE` centres each column on its median and scales it by its
MAD
([`cmad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md),
the 1.4826-scaled median absolute deviation; a column whose MAD is zero
falls back to its standard deviation), then takes \\S\\ as the sample
covariance of the standardised data. `robust = FALSE` uses the column
means and the sample covariance. The robust centre and scales resist
outliers; the correlation shape in \\S\\ is still a classical estimate,
so this is not a high-breakdown estimator such as the minimum covariance
determinant. The choice matters more than it sounds: outliers inflate
the very covariance used to judge them, so with several of them the
classical distance hides exactly the rows it is meant to find (the
masking effect).

Exactly collinear columns are refused rather than repaired: the distance
is undefined there, and flooring the covariance's eigenvalues to make it
invertible would return numbers governed by the floor rather than by the
data. Drop the redundant column first –
[`topcors()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md)
will identify it.

Errors: `data` neither a data frame nor a matrix; no numeric columns; no
more complete rows than columns; collinear columns (smallest eigenvalue
of \\S\\ at most \\10^{-8}\\ times the largest); `alpha` outside (0, 1).
A progress indicator is shown in an interactive session.

## References

Mahalanobis PC (1936). On the generalised distance in statistics.
*Proceedings of the National Institute of Sciences of India* 2(1),
49–55.

## See also

[`ctkyfnc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
for the per-column version,
[`rulemad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
to turn it into a validation rule.

## Examples

``` r
set.seed(1)
n <- 200
df <- data.frame(height = stats::rnorm(n, 170, 10))
df$weight <- df$height * 0.5 + stats::rnorm(n, 0, 5)

# A row that is ordinary on each variable but unlikely jointly:
# short and heavy.
df[1, ] <- list(height = 155, weight = 100)

out <- mahaoutl(df)
head(out, 3)
#> ╭── Mahalanobis outliers (robust) ──────────────────────────────────────╮
#> │   Verdict  ! 1 of 3 rows beyond alpha = 0.001                         │
#> │                                                                       │
#> │   Largest distances first                                             │
#> │   row  distance  p_value  logpvalue  outlier                          │
#> │   ---  --------  -------  ---------  -------                          │
#> │     1     4.301  < 0.001     -9.250  TRUE                             │
#> │    32     2.900    0.015     -4.205  FALSE                            │
#> │    14     2.807    0.019     -3.940  FALSE                            │
#> │                                                                       │
#> │   1 of 3 rows lie beyond alpha = 0.001: row 1 (distance 4.3).         │
#> │                                                                       │
#> │   The distance measures how far a row is from the centre of the data  │
#> │   once the columns' scales and correlations are allowed for; the      │
#> │   p-value is from the chi-square distribution it would follow without │
#> │   outliers, and logpvalue its natural log, for rows far in the tail.  │
#> ╰───────────────────────────────────────────────────────────────────────╯

# It is flagged, although both values lie inside the other rows' ranges.
out$row[1] == 1
#> [1] TRUE
range(df$height[-1])
#> [1] 147.8530 194.0162
range(df$weight[-1])
#> [1]  67.07546 101.82631

# A cluster of bad rows drags the mean toward itself; the median and
# MAD move less, so the robust distance of such a row is the larger.
bad <- df
bad[2:21, ] <- list(height = 150, weight = 110)
dclassical <- mahaoutl(bad, robust = FALSE)
drobust <- mahaoutl(bad, robust = TRUE)
dclassical$distance[dclassical$row == 2] < drobust$distance[drobust$row == 2]
#> [1] TRUE

# A duplicated column has no distance defined, and is refused.
dup <- df
dup$height2 <- dup$height
try(mahaoutl(dup))
#> Error : the columns are collinear, so no Mahalanobis distance is defined. Drop the redundant column(s) -- drpconst() and topcors() will find them.
```
