# Envelope of a difference, a percent change or a rate under publication bounds

Given the intervals from
[`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)
for the current and the previous cell, the set of differences and
percent changes that the observed counts could have produced is an
interval too: its ends are reached at the ends of the input intervals,
because the difference and the ratio are monotone in each argument. This
is interval arithmetic, not a confidence interval; it says nothing about
sampling and everything about what the release withheld.

## Usage

``` r
change_envelope(
  now,
  previous,
  population = NULL,
  previous_population = NULL,
  per = 1000
)
```

## Arguments

- now, previous:

  `rmbl_bounds` (or data frames with `lower` and `upper`) for the
  current and the earlier cell, of equal length.

- population, previous_population:

  Optional exposures for a rate envelope; the rate is
  `per * count / population`.

- per:

  Rate denominator when exposures are given.

## Value

A data frame with `change_lower`, `change_upper`, `pct_lower`,
`pct_upper` (`NA` where the previous cell could have been zero) and,
with exposures, `rate_lower`, `rate_upper`.

## Examples

``` r
now <- published_bounds(c(45, 120), rounding = 5)
prev <- published_bounds(c(40, 100), rounding = 5)
change_envelope(now, prev)
#>   change_lower change_upper pct_lower pct_upper
#> 1            0           10   0.00000  26.66667
#> 2           15           25  14.63415  25.64103
```
