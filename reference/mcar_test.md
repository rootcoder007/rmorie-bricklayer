# Little's test for data missing completely at random

Tests the MCAR assumption: that whether a value is missing is unrelated
to any value in the data, observed or not.

## Usage

``` r
mcar_test(data, max_iter = 500L, tol = 1e-07)
```

## Arguments

- data:

  A data frame or numeric matrix. Non-numeric columns are dropped with a
  warning, since the statistic is defined on moments.

- max_iter:

  Maximum EM iterations (default 500).

- tol:

  Convergence tolerance on the largest parameter change (default 1e-7).

## Value

A list of class `bricklayer_mcar`: `statistic`, `df`, `p_value`,
`n_patterns`, `n_used`, `n_vars`, `iterations`, `mu`, `sigma`, and
`note` (a caveat when the test is degenerate). With complete data `df`
is 0 and `p_value` is `NA` – there is nothing to test.

## Details

The assumption matters because it is what licenses the easy options.
Dropping incomplete rows is unbiased under MCAR and biased otherwise;
mean imputation understates variance under MCAR and distorts the centre
as well otherwise. A small p-value here says the easy options are not
available.

## How it works

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

## What it cannot do

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

## References

Little RJA (1988). A test of missing completely at random for
multivariate data with missing values. *Journal of the American
Statistical Association* 83(404), 1198–1202.
[doi:10.1080/01621459.1988.10478722](https://doi.org/10.1080/01621459.1988.10478722)

Dempster AP, Laird NM, Rubin DB (1977). Maximum likelihood from
incomplete data via the EM algorithm. *Journal of the Royal Statistical
Society B* 39(1), 1–38.

## See also

[`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md)
for the patterns themselves,
[`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)
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
mcar_test(mcar)
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
mcar_test(mar)
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
mcar_test(data.frame(a = x, b = y))$df
#> [1] 0

# A duplicated column makes the likelihood degenerate, and is refused.
dup <- mcar
dup$x2 <- dup$x
try(mcar_test(dup))
#> Error : the columns are collinear (or one is constant), so the multivariate normal likelihood Little's test is built on is degenerate. Drop the redundant column(s) first -- top_correlations() and drop_constant() will find them.

# The EM estimates are the ML ones: with no missingness they are the
# column means and the ML (1/n) covariance.
fit <- mcar_test(data.frame(a = x, b = y))
all.equal(fit$mu, c(mean(x), mean(y)), check.attributes = FALSE)
#> [1] TRUE
```
