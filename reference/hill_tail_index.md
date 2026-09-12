# Tail index of a heavy-tailed count

The Clauset-Shalizi-Newman maximum-likelihood estimator for a discrete
power law above a threshold. An exponent near 2 or below means the mean
is barely defined and the observed maximum is not informative about the
next one, which is the substantive point when a few units dominate a
total.

## Usage

``` r
hill_tail_index(
  x,
  x_min = NULL,
  discrete = TRUE,
  approx = FALSE,
  min_tail = 3L
)
```

## Arguments

- x:

  Positive values, one per unit.

- x_min:

  Threshold above which the power law is fitted. A power law is a
  statement about the tail, so a threshold is required; the default
  takes the value that leaves at least 50 observations, or the minimum
  if the data are smaller than that.

- discrete:

  Whether the quantity is integer-valued. A count is, and then the
  likelihood maximised is the zeta distribution's, whose normalising
  constant is a Hurwitz zeta.

- approx:

  For discrete data, whether to use the closed-form continuity-corrected
  estimator instead of maximising the exact likelihood. It is much
  faster and much worse: the correction is an asymptotic approximation
  in `x_min`, and at `x_min = 1` – where administrative counts start –
  it returns about 2.0 from data generated with an exponent of 2.5. Off
  by default for that reason.

- min_tail:

  Fewest tail observations for which an estimate is reported at all.
  Below it there is nothing to estimate from and `alpha` is `NA`.

## Value

A list with `alpha`, its standard error, `x_min`, `n_tail`, `ks` and
`reliable`. `ks` is the Kolmogorov-Smirnov distance between the fitted
tail and the data: a large value means the tail is not a power law,
whatever `alpha` came out as. `reliable` is `FALSE` when fewer than 50
observations lie in the tail, which is the sample size Clauset, Shalizi
and Newman give as the point below which the estimate should not be
leaned on – it is reported rather than enforced, because the right
response to a short tail is a wider interval, not a refusal.

## References

Clauset, A., Shalizi, C. R. and Newman, M. E. J. (2009). Power-law
distributions in empirical data. *SIAM Review* 51(4), 661-703. The
estimator and its threshold guidance are theirs; the continuity
correction they give in closed form is an asymptotic approximation in
`x_min`, which is why the exact likelihood is maximised here instead.
(Not in the local corpus; cited from the published paper.)

## Examples

``` r
# A continuous Pareto tail with exponent 2.5.
set.seed(1)
x <- (1 - stats::runif(5000))^(-1 / 1.5)
round(hill_tail_index(x, x_min = 1, discrete = FALSE)$alpha, 2)
#> [1] 2.49

# A discrete power law, where the exact likelihood is needed: the
# closed-form correction is badly biased at a threshold of one.
k <- 1:10000
p <- k^(-2.5) / sum(k^(-2.5))
set.seed(2)
z <- sample(k, 5000, replace = TRUE, prob = p)
c(exact = round(hill_tail_index(z, x_min = 1)$alpha, 2),
  approx = round(hill_tail_index(z, x_min = 1, approx = TRUE)$alpha, 2))
#>  exact approx 
#>   2.46   2.00 

# A short tail still returns an estimate, marked as not to be leaned
# on, and with a standard error that says the same thing.
short <- hill_tail_index(c(3, 4, 5, 9), x_min = 3)
c(alpha = round(short$alpha, 2), n = short$n_tail,
  reliable = short$reliable)
#>    alpha        n reliable 
#>     2.59     4.00     0.00 

# Below `min_tail` there is nothing to estimate from.
hill_tail_index(c(3, 4), x_min = 3)$alpha
#> [1] NA
```
