# Little's test for data missing completely at random

Tests the MCAR assumption: that whether a value is missing is unrelated
to any value in the data, observed or not.

The assumption matters because it is what licenses the easy options.
Dropping incomplete rows is unbiased under MCAR and biased otherwise;
mean imputation understates variance under MCAR and distorts the centre
as well otherwise. A small p-value here says the easy options are not
available. Run it on the numeric columns of a table before deciding how
to handle its missing values.

## Usage

``` r
mcartst(data, maxit = 500L, tol = 1e-07)
```

## Arguments

- data:

  A data frame or numeric matrix. Non-numeric columns are dropped with a
  warning, since the statistic is defined on moments.

- maxit:

  Whole number, default 500: the maximum number of EM iterations.

- tol:

  Number, default 1e-7: EM stops when the largest absolute change in any
  mean or covariance entry between iterations falls below it.

## Value

A list of class `bricklayer_mcar`: `statistic`, `df`, `p_value`,
`logpvalue` (the log of `p_value`, finite where `p_value` underflows to
0), `npat` (distinct missingness patterns), `nused` (rows in the
patterns that entered the statistic), `nvars` (columns used),
`iterations` (EM iterations), `mu` (named ML means), `sigma` (ML
covariance matrix), and `note` (a caveat when the test is degenerate or
a pattern was skipped, else `NA`). The print method gives the verdict in
words. With complete data `df` is 0 and `p_value` is `NA` – there is
nothing to test.

## Details

### How it works

Rows are grouped by their pattern of missingness. If missingness is
unrelated to the values, then each pattern's observed-variable means
should agree with the overall estimates, up to sampling error. The
statistic sums those disagreements, \$\$d^2 = \sum_j n_j (\bar{x}\_j -
\hat{\mu}\_j)' \hat{\Sigma}\_j^{-1} (\bar{x}\_j - \hat{\mu}\_j),\$\$
over the variables observed in pattern \\j\\, and is compared with a
chi-square distribution on \\\sum_j p_j - p\\ degrees of freedom.

The overall \\\hat\mu\\ and \\\hat\Sigma\\ are the MAXIMUM-LIKELIHOOD
estimates under multivariate normality WITH the missing data, obtained
by expectation-maximisation – not the complete-case estimates, which
would already embed the bias the test is looking for.

### What it cannot do

A large p-value is NOT evidence that the data are MCAR; it is a failure
to detect a departure, and the test has little power on small samples or
with many patterns. The test also assumes multivariate normality, so on
markedly non-normal columns a rejection may be telling you about the
distribution rather than the missingness.

Neither this test nor any other can distinguish missing-at-random from
missing-NOT-at-random, because that distinction depends on the values
that were never observed. Only knowledge of how the data were collected
settles it.

Collinear or constant columns are refused rather than worked around: the
likelihood is degenerate there, and the EM step's eigenvalue floor would
otherwise return a statistic governed by that floor instead of by the
data.

### Practicalities

Columns that are entirely missing and rows with no observed value are
dropped before the test. The EM loop is written in R and visits every
row on every iteration, so it takes about \\n \times\\ iterations small
matrix solves: seconds for a few thousand rows and a handful of columns,
longer for large tables. A progress indicator is shown in an interactive
session. If EM has not converged after `maxit` iterations the last
estimates are used; `iterations` then equals `maxit`.

Errors: `data` neither a data frame nor a matrix; fewer than two numeric
columns, or fewer than two usable rows or columns after the drops;
collinear or constant columns (smallest covariance eigenvalue at most
\\10^{-8}\\ times the largest); EM estimates that cannot be inverted.
Non-numeric columns are dropped with a warning.

## References

Little RJA (1988). A test of missing completely at random for
multivariate data with missing values. *Journal of the American
Statistical Association* 83(404), 1198–1202.
[doi:10.1080/01621459.1988.10478722](https://doi.org/10.1080/01621459.1988.10478722)

Dempster AP, Laird NM, Rubin DB (1977). Maximum likelihood from
incomplete data via the EM algorithm. *Journal of the Royal Statistical
Society B* 39(1), 1–38.

## See also

[`misspat()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
for the patterns themselves,
[`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md)
for the rates.

## Examples

``` r
set.seed(1)
n <- 300
x <- stats::rnorm(n)
y <- x + stats::rnorm(n)

# Missing completely at random: a coin flip decides, so the test
# should not reject.
mcar <- data.frame(x = x, y = y)
mcar$y[sample(n, 90)] <- NA
mcartst(mcar)
#> ── Little's MCAR test ────────────────────────────────────────────
#>   ✓ no departure from MCAR detected
#> 
#>   statistic      1.094
#>   df             1
#>   p-value        0.296
#>   patterns       2
#>   variables      2
#>   rows used      300
#>   EM iterations  13
#> 
#>   Not evidence OF MCAR: a large p-value is a failure to detect a
#>   departure, and this test has little power on small samples.
#> ──────────────────────────────────────────────────────────────────

# Missing depending on the OTHER, observed variable: not MCAR, and
# detectable, because the pattern's mean of x is shifted.
mar <- data.frame(x = x, y = y)
mar$y[x > 0.4] <- NA
mcartst(mar)
#> ── Little's MCAR test ────────────────────────────────────────────
#>   ✗ MCAR rejected: the missingness is related to the data
#> 
#>   statistic      180.118
#>   df             1
#>   p-value        <2e-16
#>   patterns       2
#>   variables      2
#>   rows used      300
#>   EM iterations  69
#> ──────────────────────────────────────────────────────────────────

# Complete data has one pattern and nothing to test.
mcartst(data.frame(a = x, b = y))$df
#> [1] 0

# A duplicated column makes the likelihood degenerate, and is refused.
dup <- mcar
dup$x2 <- dup$x
try(mcartst(dup))
#> Error : the columns are collinear (or one is constant), so the multivariate normal likelihood Little's test is built on is degenerate. Drop the redundant column(s) first -- topcors() and drpconst() will find them.

# The EM estimates are the ML ones: with no missingness they are the
# column means and the ML (1/n) covariance.
fit <- mcartst(data.frame(a = x, b = y))
all.equal(fit$mu, c(mean(x), mean(y)), check.attributes = FALSE)
#> [1] TRUE
```
