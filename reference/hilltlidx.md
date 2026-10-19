# Tail index of a heavy-tailed count

The Clauset-Shalizi-Newman maximum-likelihood estimator for a discrete
power law above a threshold. An exponent near 2 or below means the mean
is barely defined and the observed maximum is not informative about the
next one, which is the substantive point when a few units dominate a
total. Use it on counts per unit (placements per person, incidents per
address) to judge whether the largest values are a heavy tail rather
than a few outliers, and read `ks` and `reliable` before quoting the
exponent.

## Usage

``` r
hilltlidx(x, xmin = NULL, discrete = TRUE, approx = FALSE, mintl = 3L)
```

## Arguments

- x:

  Numeric vector of positive values, one per unit.

- xmin:

  Numeric scalar or `NULL` (the default): the threshold at and above
  which the power law is fitted. A power law is a statement about the
  tail, so a threshold is required; `NULL` takes the 50th largest value
  (which leaves at least 50 observations in the tail), or the minimum if
  there are fewer than 50 values.

- discrete:

  Logical scalar, default `TRUE`: whether the quantity is
  integer-valued. A count is, and then the likelihood maximised is the
  zeta distribution's, whose normalising constant is a Hurwitz zeta.

- approx:

  Logical scalar, default `FALSE`. For discrete data, whether to use the
  closed-form continuity-corrected estimator instead of maximising the
  exact likelihood. It is much faster and much worse: the correction is
  an asymptotic approximation in `xmin`, and at `xmin = 1` – where
  administrative counts start – it returns about 2.0 from data generated
  with an exponent of 2.5. Off by default for that reason.

- mintl:

  Integer scalar, default `3`: the fewest tail observations for which an
  estimate is reported at all (values below 2 are raised to 2). Below it
  there is nothing to estimate from and `alpha` is `NA`.

## Value

A list with `alpha` (numeric, the exponent), `se` (its standard error),
`xmin` (the threshold used), `ntl` (integer, the number of values at or
above it), `ks`, `reliable` (logical) and `method` (character, the
estimator used or why there is no estimate). `ks` is the
Kolmogorov-Smirnov distance between the fitted tail and the data: a
large value means the tail is not a power law, whatever `alpha` came out
as. `reliable` is `FALSE` when fewer than 50 observations lie in the
tail, which is the sample size Clauset, Shalizi and Newman give as the
point below which the estimate should not be leaned on – it is reported
rather than enforced, because the right response to a short tail is a
wider interval, not a refusal.

## Details

For a power law \\p(x) \propto x^{-\alpha}\\ above \\x\_{min}\\:

- discrete data, exact (the default): the log-likelihood of the zeta
  distribution truncated at \\x\_{min}\\, \\-n \log \zeta(\alpha,
  x\_{min}) - \alpha \sum \log x_i\\, is maximised over \\\alpha\\ in
  \\(1.0001, 25)\\ with
  [`stats::optimize()`](https://rdrr.io/r/stats/optimize.html);
  \\\zeta\\ is
  [`hurwzeta()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hurwzeta.md).
  The standard error comes from the observed information, by a numerical
  second derivative.

- continuous data (`discrete = FALSE`): the Hill estimator \\\hat\alpha
  = 1 + n / \sum \log(x_i / x\_{min})\\, with standard error
  \\(\hat\alpha - 1)/\sqrt{n}\\.

- discrete data with `approx = TRUE`: the same closed form with
  \\x\_{min} - 1/2\\ in place of \\x\_{min}\\.

`ks` is the Kolmogorov-Smirnov distance between the fitted distribution
and the tail, computed once per distinct value so that ties (most counts
are ties) are handled correctly.

Only finite positive values of `x` are used; the rest are dropped
silently. When the tail has fewer than `mintl` values, or every tail
value is the same, `alpha` is `NA` and `method` says why. An estimate at
the optimiser's bound is flagged in `method` and is not `reliable`.
Errors: no positive finite value in `x`; `xmin` that is not a single
positive number (logical, factor and text are refused); `discrete` or
`approx` not `TRUE` or `FALSE`.

## References

Clauset, A., Shalizi, C. R. and Newman, M. E. J. (2009). Power-law
distributions in empirical data. *SIAM Review* 51(4), 661-703. The
estimator and its threshold guidance are theirs; the continuity
correction they give in closed form is an asymptotic approximation in
`xmin`, which is why the exact likelihood is maximised here instead.
(Not in the local corpus; cited from the published paper.)

## Examples

``` r
# A continuous Pareto tail with exponent 2.5.
set.seed(1)
x <- (1 - stats::runif(5000))^(-1 / 1.5)
round(hilltlidx(x, xmin = 1, discrete = FALSE)$alpha, 2)
#> [1] 2.49

# A discrete power law, where the exact likelihood is needed: the
# closed-form correction is badly biased at a threshold of one.
k <- 1:10000
p <- k^(-2.5) / sum(k^(-2.5))
set.seed(2)
z <- sample(k, 5000, replace = TRUE, prob = p)
c(exact = round(hilltlidx(z, xmin = 1)$alpha, 2),
  approx = round(hilltlidx(z, xmin = 1, approx = TRUE)$alpha, 2))
#>  exact approx 
#>   2.46   2.00 

# A short tail still returns an estimate, marked as not to be leaned
# on, and with a standard error that says the same thing.
short <- hilltlidx(c(3, 4, 5, 9), xmin = 3)
c(alpha = round(short$alpha, 2), n = short$ntl,
  reliable = short$reliable)
#>    alpha        n reliable 
#>     2.59     4.00     0.00 

# Below `mintl` there is nothing to estimate from.
hilltlidx(c(3, 4), xmin = 3)$alpha
#> [1] NA

# the threshold has to be positive
try(hilltlidx(z, xmin = 0))
#> Error : `xmin` must be positive
```
