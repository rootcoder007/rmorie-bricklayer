# Change in a rate between periods

Compares each period's rate with the rate `lag` periods earlier (for
example this year's stops per 100,000 residents with last year's), and
gives the rate ratio, the percent change and an exact confidence
interval for the change. Use it instead of the percent change of two
published rates: both the counts and the populations move between
periods, and the interval here accounts for the randomness in the
counts.

## Usage

``` r
ratechg(x, ...)

# Default S3 method
ratechg(x, ...)

# S3 method for class 'data.frame'
ratechg(
  x,
  count,
  pop,
  prd,
  by = NULL,
  lag = 1L,
  per = 1000,
  conflvl = 0.95,
  mincnt = 0,
  prdord = NULL,
  ...
)
```

## Arguments

- x:

  A data frame.

- ...:

  Passed to methods.

- count:

  Column of counts (unquoted or a string): non-negative whole numbers.

- pop:

  Column of exposure (unquoted or a string): positive.

- prd:

  Column of periods (unquoted or a string). Sorted within each group;
  see Details for how the earlier period is found.

- by:

  Character vector of grouping columns, default `NULL`.

- lag:

  Whole number, default 1: how many periods back to compare against.

- per:

  The rate denominator: a positive number, or `"1k"`, `"10k"`, `"100k"`,
  `"1m"`. Default 1000.

- conflvl:

  Number in (0, 1), default 0.95: the confidence level of the interval.

- mincnt:

  Number, default 0. Comparisons where the earlier count is at or below
  this are flagged as resting on a small count; the percent change and
  its exact interval are still reported, as
  [`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
  does.

- prdord:

  Optional character vector: the period labels in order, as for
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).
  A label it lists that the data lacks is a gap, so the change across it
  is not reported as one step.

## Value

A data frame of class `c("rmbl_rate_change", "data.frame")` with one row
per group and period: the grouping columns, the period column, `count`,
`population`, `rate`, `prerate`, `precnt`, `prepop`, `rateratio`,
`pctchg`, `pctlo`, `pctup` (numeric) and the character `flag`. The flag
is `"no comparison period"`, `"earlier period is zero"`, a small-count
note, or `NA`. The `ratechg` attribute records the settings.

## Details

This is not the percent change of two rates treated as measured numbers.
Both the counts and the denominators move between periods, and an
interval that ignores the denominators understates the uncertainty of
the change. The construction here conditions on the total of the two
counts and corrects for the ratio of the two exposures, which is
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)'s
exact conditional-binomial interval generalised to unequal denominators:
with equal populations it reduces to exactly that.

With counts \\a\\ (now) and \\b\\ (earlier) and exposures \\t_a\\,
\\t_b\\, conditional on \\a + b\\ the count \\a\\ is binomial with
success probability \\p = RR\\t_a / (RR\\t_a + t_b)\\. The
Clopper-Pearson limits for \\p\\, \\p_L = B^{-1}(\alpha/2;\\ a, b + 1)\\
and \\p_U = B^{-1}(1 - \alpha/2;\\ a + 1, b)\\ (0 when \\a = 0\\, 1 when
\\b = 0\\), give \\RR = (t_b / t_a)\\ p / (1 - p)\\ and the percent
change \\100 (RR - 1)\\. When \\b = 0\\ the upper limit is `Inf` and the
percent change itself is `NA`; when both counts are 0 there is no
interval.

Counts and populations are summed within each period (and `by` group).
Matching to the earlier period: for a numeric period column the
comparison is the period whose value is exactly `lag` less, so a missing
year gives no comparison instead of a silent comparison against the
wrong year. For any other period type (character, factor, Date) the
earlier period is `lag` steps back along the periods observed in the
group, so a gap in such a column is not detected.

Errors: `x` not a data frame; columns not found; `lag` not a positive
whole number; `conflvl` outside (0, 1); a population of zero or below.

## See also

[`rtcalc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md),
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
for change in a count or a measured quantity.

## Examples

``` r
d <- data.frame(
  year = rep(2021:2023, each = 2),
  division = rep(c("North", "South"), 3),
  stops = c(400, 70, 430, 66, 455, 61),
  residents = c(120000, 41000, 122000, 41500, 125000, 42000))

# North's count rose while its population rose too: the rate change
# is smaller than the count change, which is the reason to use it
ratechg(d, stops, residents, year, by = "division", per = "100k")
#> ╭── Change in rate per 100,000 ───────────────────────────────────────────╮
#> │   Count       stops                                                     │
#> │   Population  residents                                                 │
#> │   Period      year                                                      │
#> │   Groups      division                                                  │
#> │   Lag         1                                                         │
#> │   Interval    95% exact conditional, on the % change                    │
#> │                                                                         │
#> │   division  year  count  population   rate  precnt   prepop  prerate    │
#> │   --------  ----  -----  ----------  -----  ------  -------  -------    │
#> │   North     2021    400     120,000  333.3                              │
#> │   North     2022    430     122,000  352.5     400  120,000    333.3    │
#> │   North     2023    455     125,000  364.0     430  122,000    352.5    │
#> │   South     2021     70      41,000  170.7                              │
#> │   South     2022     66      41,500  159.0      70   41,000    170.7    │
#> │   South     2023     61      42,000  145.2      66   41,500    159.0    │
#> │                                                                         │
#> │   division  rateratio  pctchg  pct_interval     flag                    │
#> │   --------  ---------  ------  ---------------  ----                    │
#> │   North                                         [1]                     │
#> │   North        1.0574   5.738  [-7.94, 21.47]                           │
#> │   North        1.0327   3.274  [-9.68, 18.10]                           │
#> │   South                                         [1]                     │
#> │   South        0.9315  -6.850  [-34.47, 32.29]                          │
#> │   South        0.9132  -8.676  [-36.60, 31.36]                          │
#> │                                                                         │
#> │   Not distinguishable from 0 (interval includes it): North 2022         │
#> │   (+5.7%), North 2023 (+3.3%), South 2022 (-6.9%) and South 2023        │
#> │   (-8.7%).                                                              │
#> │                                                                         │
#> │   [1] no comparison period                                              │
#> │   pctchg is the percentage change in the rate from the period `lag`     │
#> │   before; an interval that includes 0 means the change could be chance. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# a missing year gives no comparison rather than a wrong one
gap <- data.frame(year = c(2019, 2020, 2022), n = c(10, 14, 12),
                  pop = c(1000, 1000, 1100))
ratechg(gap, n, pop, year)$flag
#> [1] "no comparison period" NA                     "no comparison period"

# two-year change, flagging small earlier counts
ratechg(d, stops, residents, year, by = "division", lag = 2,
            mincnt = 65)
#> ╭── Change in rate per 1,000 ─────────────────────────────────────────────╮
#> │   Count       stops                                                     │
#> │   Population  residents                                                 │
#> │   Period      year                                                      │
#> │   Groups      division                                                  │
#> │   Lag         2                                                         │
#> │   Interval    95% exact conditional, on the % change                    │
#> │                                                                         │
#> │   division  year  count  population   rate  precnt   prepop  prerate    │
#> │   --------  ----  -----  ----------  -----  ------  -------  -------    │
#> │   North     2021    400     120,000  3.333                              │
#> │   North     2022    430     122,000  3.525                              │
#> │   North     2023    455     125,000  3.640     400  120,000    3.333    │
#> │   South     2021     70      41,000  1.707                              │
#> │   South     2022     66      41,500  1.590                              │
#> │   South     2023     61      42,000  1.452      70   41,000    1.707    │
#> │                                                                         │
#> │   division  rateratio  pctchg  pct_interval     flag                    │
#> │   --------  ---------  ------  ---------------  ----                    │
#> │   North                                         [1]                     │
#> │   North                                         [1]                     │
#> │   North        1.0920    9.20  [-4.74, 25.22]                           │
#> │   South                                         [1]                     │
#> │   South                                         [1]                     │
#> │   South        0.8507  -14.93  [-40.66, 21.66]                          │
#> │                                                                         │
#> │   Not distinguishable from 0 (interval includes it): North 2023 (+9.2%) │
#> │   and South 2023 (-14.9%).                                              │
#> │                                                                         │
#> │   [1] no comparison period                                              │
#> │   pctchg is the percentage change in the rate from the period `lag`     │
#> │   before; an interval that includes 0 means the change could be chance. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

try(ratechg(1:3))
#> Error : `x` must be a data frame, not integer
```
