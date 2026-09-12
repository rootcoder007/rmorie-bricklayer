# Standardised incidence ratio, with an exact interval

The ratio of observed to expected, with the exact Poisson interval for
it. A ratio of one is the overall experience; above one is an excess.

## Usage

``` r
sir(observed, expected, area = NULL, conf_level = 0.95)
```

## Arguments

- observed:

  Observed counts.

- expected:

  Expected counts, from
  [`expected_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expected_counts.md).

- area:

  Optional labels.

- conf_level:

  Confidence level.

## Value

A data frame with `observed`, `expected`, `sir`, `lower`, `upper` and
`excess` – whether the interval excludes one.

## Details

The interval is the exact Poisson one, from the relation between the
Poisson and gamma distributions, and so is identical to
[`stats::poisson.test`](https://rdrr.io/r/stats/poisson.test.html)'s. It
is the interval to use here because the counts that matter are small: a
normal approximation on an observed count of three is not an interval,
it is a decoration.

## References

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, Chapter 1.

## See also

[`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md),
[`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md)

## Examples

``` r
sir(observed = c(30, 12, 3), expected = c(20, 14, 5),
    area = c("North", "South", "East"))
#>    area observed expected       sir     lower    upper excess
#> 1 North       30       20 1.5000000 1.0120437 2.141343   TRUE
#> 2 South       12       14 0.8571429 0.4428982 1.497256  FALSE
#> 3  East        3        5 0.6000000 0.1237344 1.753455  FALSE

# An observed count of three carries almost no information, and the
# interval says so rather than hiding it.
sir(3, 5)
#>   observed expected sir     lower    upper excess
#> 1        3        5 0.6 0.1237344 1.753455  FALSE
```
