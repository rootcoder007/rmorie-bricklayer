# Expected counts under indirect standardisation

The count each area would have if it experienced the overall rate in
every stratum, given its own composition. Comparing observed against
this rather than against a raw rate removes the part of the difference
that is explained by who the area holds.

## Usage

``` r
expected_counts(counts, population, area, strata = NULL)
```

## Arguments

- counts:

  Observed counts.

- population:

  Population at risk, the same length as `counts`.

- area:

  Area label for each row.

- strata:

  Optional stratum label for each row – an age band, a gender, or their
  interaction. With strata the standardisation is indirect in the usual
  sense: the overall stratum-specific rates are applied to each area's
  own stratum populations.

## Value

A data frame with one row per area: `observed`, `population` and
`expected`.

## Details

Without strata the expected count is just the area's population times
the overall rate, which adjusts for size but not for composition. The
two are worth distinguishing: a region holding disproportionately many
young men will show an excess on the first and may show none on the
second, and only the second is evidence about the region.

## References

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC. Chapter 1 sets out the convention used
here: the expected counts come from applying the overall population rate
to each area, and the standardised incidence ratio is the ratio of count
to expected.

Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods Using
R*. Springer, on the distinction between indirect standardisation, which
applies the reference's stratum-specific rates to the study population,
and direct standardisation, which does the reverse.

## See also

[`sir()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sir.md),
[`eb_rates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/eb_rates.md),
[`funnel_limits()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/funnel_limits.md)

## Examples

``` r
d <- data.frame(
  region = rep(c("North", "South", "East"), each = 2),
  age = rep(c("18 to 24", "25 to 49"), 3),
  n = c(30, 45, 12, 60, 8, 20),
  pop = c(1000, 6000, 900, 9000, 400, 3500)
)

# Adjusting for size only.
expected_counts(d$n, d$pop, d$region)
#>    area observed population expected
#> 1  East       28       3900 32.81250
#> 2 North       75       7000 58.89423
#> 3 South       72       9900 83.29327

# Adjusting for size AND age composition, which is the comparison
# that says something about the region.
expected_counts(d$n, d$pop, d$region, strata = d$age)
#>    area observed population expected
#> 1  East       28       3900 32.34430
#> 2 North       75       7000 62.27967
#> 3 South       72       9900 80.37603
```
