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

  `rmbl_bounds` objects from
  [`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)
  (or data frames with numeric `lower` and `upper`) for the current and
  the earlier cell, with the same number of rows.

- population, previous_population:

  Optional numeric exposures (for example residents) for a rate envelope
  of the current and the previous cell; the rate is
  `per * count / population`. Default `NULL`. `previous_population` is
  used only with `population`.

- per:

  Numeric scalar, the rate base when exposures are given; default `1000`
  (per 1,000).

## Value

A data frame, one row per cell, with numeric columns `change_lower`,
`change_upper`, `pct_lower`, `pct_upper` (`NA` where the previous cell
could have been zero); with `population` also `rate_lower` and
`rate_upper`; with `previous_population` as well `previous_rate_lower`
and `previous_rate_upper`.

## Details

With current interval \\\[a_l, a_u\]\\ and previous interval \\\[b_l,
b_u\]\\: the change lies in \\\[a_l - b_u, a_u - b_l\]\\ and the percent
change in \\\[100(a_l / b_u - 1), 100(a_u / b_l - 1)\]\\. An end of the
percent interval is `NA` when its denominator could be zero (an upper
bound needs \\b_l \> 0\\, a lower bound \\b_u \> 0\\), since a change
from zero has no percentage. A rate interval is \\\[per \cdot a_l / pop,
per \cdot a_u / pop\]\\; the population is taken as exact.

Errors when `now` and `previous` have different numbers of rows. The
populations are not checked; give one per row (or one value).

## See also

[`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md),
[`yoy_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_bounds.md).

## Examples

``` r
now <- published_bounds(c(45, 120), rounding = 5)
prev <- published_bounds(c(40, 100), rounding = 5)
change_envelope(now, prev)
#>   change_lower change_upper pct_lower pct_upper
#> 1            0           10   0.00000  26.66667
#> 2           15           25  14.63415  25.64103

# with rates per 1,000 residents in both years
change_envelope(now, prev, population = c(10000, 20000),
                previous_population = c(10000, 19000))
#>   change_lower change_upper pct_lower pct_upper rate_lower rate_upper
#> 1            0           10   0.00000  26.66667      4.250      4.750
#> 2           15           25  14.63415  25.64103      5.875      6.125
#>   previous_rate_lower previous_rate_upper
#> 1            3.750000            4.250000
#> 2            5.131579            5.394737

# a suppressed previous cell could have been zero: no upper percentage
change_envelope(published_bounds(12), published_bounds("<5"))
#>   change_lower change_upper pct_lower pct_upper
#> 1            8           12       200        NA

# the two sides must line up
try(change_envelope(now, prev[1, ]))
#> Error : `now` and `previous` must have the same number of rows
```
