# Envelope of a difference, a percent change or a rate under publication bounds

Given the intervals from
[`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
for the current and the previous cell, the set of differences and
percent changes that the observed counts could have produced is an
interval too: its ends are reached at the ends of the input intervals,
because the difference and the ratio are monotone in each argument. This
is interval arithmetic, not a confidence interval; it says nothing about
sampling and everything about what the release withheld.

## Usage

``` r
chgenv(now, prev, pop = NULL, prepop = NULL, per = 1000)
```

## Arguments

- now, prev:

  `rmbl_bounds` objects from
  [`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
  (or data frames with numeric `lower` and `upper`) for the current and
  the earlier cell, with the same number of rows.

- pop, prepop:

  Optional numeric exposures (for example residents) for a rate envelope
  of the current and the previous cell; the rate is
  `per * count / population`. Default `NULL`. `prepop` is used only with
  `pop`.

- per:

  Numeric scalar, the rate base when exposures are given; default `1000`
  (per 1,000).

## Value

A data frame, one row per cell, with numeric columns `chglo`, `chgup`,
`pctlo`, `pctup` (`NA` where the previous cell could have been zero);
with `population` also `ratelo` and `rateup`; with `prepop` as well
`preratelo` and `prerateup`.

## Details

With current interval \\\[a_l, a_u\]\\ and previous interval \\\[b_l,
b_u\]\\: the change lies in \\\[a_l - b_u, a_u - b_l\]\\ and the percent
change in \\\[100(a_l / b_u - 1), 100(a_u / b_l - 1)\]\\. An end of the
percent interval is `NA` when its denominator could be zero (an upper
bound needs \\b_l \> 0\\, a lower bound \\b_u \> 0\\), since a change
from zero has no percentage. A rate interval is \\\[per \cdot a_l / pop,
per \cdot a_u / pop\]\\; the population is taken as exact.

Errors when `now` and `prev` have different numbers of rows. The
populations are not checked; give one per row (or one value).

## See also

[`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md),
[`yoybnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoybnd.md).

## Examples

``` r
now <- pubbnd(c(45, 120), rnd = 5)
prev <- pubbnd(c(40, 100), rnd = 5)
chgenv(now, prev)
#> ╭── Change between published values ─────────────────────────────────────╮
#> │   Cells          2                                                     │
#> │   Certain rises  1                                                     │
#> │   Certain falls  0                                                     │
#> │                                                                        │
#> │   cell  change    change %                                             │
#> │   ----  --------  --------------                                       │
#> │      1  [0, 10]   [0.00, 26.67]                                        │
#> │      2  [15, 25]  [14.63, 25.64]                                       │
#> │                                                                        │
#> │   Each interval holds every change consistent with the two published   │
#> │   (rounded or suppressed) values. An interval that spans 0 cannot tell │
#> │   a rise from a fall.                                                  │
#> ╰────────────────────────────────────────────────────────────────────────╯

# with rates per 1,000 residents in both years
chgenv(now, prev, pop = c(10000, 20000),
                prepop = c(10000, 19000))
#> ╭── Change between published values ─────────────────────────────────────╮
#> │   Cells          2                                                     │
#> │   Certain rises  1                                                     │
#> │   Certain falls  0                                                     │
#> │                                                                        │
#> │   cell  change    change %        rate            previous rate        │
#> │   ----  --------  --------------  --------------  --------------       │
#> │      1  [0, 10]   [0.00, 26.67]   [4.250, 4.750]  [3.750, 4.250]       │
#> │      2  [15, 25]  [14.63, 25.64]  [5.875, 6.125]  [5.132, 5.395]       │
#> │                                                                        │
#> │   Each interval holds every change consistent with the two published   │
#> │   (rounded or suppressed) values. An interval that spans 0 cannot tell │
#> │   a rise from a fall.                                                  │
#> ╰────────────────────────────────────────────────────────────────────────╯

# a suppressed previous cell could have been zero: no upper percentage
chgenv(pubbnd(12), pubbnd("<5"))
#> ╭── Change between published values ─────────────────────────────────────╮
#> │   Cells          1                                                     │
#> │   Certain rises  1                                                     │
#> │   Certain falls  0                                                     │
#> │                                                                        │
#> │   cell  change   change %                                              │
#> │   ----  -------  --------                                              │
#> │      1  [8, 12]  [200, ]                                               │
#> │                                                                        │
#> │   Each interval holds every change consistent with the two published   │
#> │   (rounded or suppressed) values. An interval that spans 0 cannot tell │
#> │   a rise from a fall.                                                  │
#> ╰────────────────────────────────────────────────────────────────────────╯

# the two sides must line up
try(chgenv(now, prev[1, ]))
#> Error : `now` and `prev` must have the same number of rows
```
