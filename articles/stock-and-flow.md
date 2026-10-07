# Stock and flow: population, admissions and length of stay

A custodial or clinical population can be described two ways: the
**stock** (how many are held on an average day) and the **flow** (how
many pass through in a period). The two are linked by the length of
stay, and a published table that reports one without the others is easy
to misread. These functions implement the standard measures (Lakner’s
formulation, as used in the Canadian corrections statistics) with exact
intervals.

## Average daily population

The stock. Detention days in a period divided by the days in the period:

``` r

# Lakner's worked example: 3,000 inmates served 13,500 detention days in a year
adp(13500)
#> [1] 36.9863

# per-person days over a 30-day period give the same total
adp(c(10, 20, 30), t = 30)
#> [1] 2
```

[`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)
estimates person-days from periodic headcounts (a monthly census) when
daily data are not published.

## Average length of stay

Detention days divided by the number of people who completed a stay:

``` r

# Lakner: 2,700 inmates admitted and released served 12,150 detention days
alos(12150, 2700)
#> [1] 4.5
```

## Admissions implied by stock and stay

Little’s law ties the three together: in a stationary system, stock =
flow × stay, so admissions = ADP × days / ALOS. Lakner (p. 20) runs it
the other way: an average daily population of 25 and 1,750 admissions in
a year imply a stay of 5.2 days, and back again:

``` r

alos_implied <- 25 * 365 / 1750
round(alos_implied, 1)
#> [1] 5.2
admissions(25, alos_implied)
#> [1] 1750
```

## Stock and flow together

[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
takes detention days and people per period, with an exposure (the
population at risk) to turn counts into rates, and reports how the
stock, the flow and the stay moved between periods. The pattern it is
built to surface: **fewer people, held longer**, so the flow falls while
the stock rises.

``` r

stock_flow(
  days = c(115674, 126121), people = c(12647, 9608),
  period = c("2023", "2025"),
  exposure = c(15495050, 16256538)
)
#> ── Stock and flow over 2 periods ───────────────────────────────── 
#>  period people   days      alos      adp flow_rate stock_rate
#>    2023  12647 115674  9.146359 316.9151  81.61961   2.045267
#>    2025   9608 126121 13.126665 345.5370  59.10237   2.125526
#> 
#>   2023 to 2025: people -24.0%, stay +43.5%, days +9.0%
#>   flow rate -27.6%, stock rate +3.9%  <- opposite signs: quote both
#> ──────────────────────────────────────────────────────────────────
```

A table that reported only admissions would show a decline; one that
reported only the daily count would show growth. Both are true, and the
length of stay is the reason.

## The distribution of stays

The mean stay is pulled far above the median by a few long stays, so the
summary that matters is the whole distribution:

``` r

stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
stay_summary(stays)
#>    n total_days     mean       sd median iqr max       se    lower    upper
#> 1 93        600 6.451613 16.33183      3   2 120 1.693532 3.088113 9.815113
stay_summary(stays)[, c("mean", "median", "max")]
#>       mean median max
#> 1 6.451613      3 120
```

[`stay_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stay_summary.md)
gives the mean with its interval, the quantiles and the maximum, so a
report can say “half of stays were three days or less, and the longest
was 120” instead of “the average stay was 9.6 days”, which describes
almost no one.

## Periods and fiscal years

Published series use fiscal years and uneven periods:

``` r

period_days("2024-04-01", "2025-03-31")
#> [1] 365
fiscal_year_label(2024)
#> [1] "2023/24"
```

## From a published table

1.  [`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md)
    for the stock from detention days, or
    [`adp_from_counts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp_from_counts.md)
    from headcounts.
2.  [`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
    for the stay;
    [`admissions()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/admissions.md)
    to check the implied flow against the published one.
3.  [`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)
    across periods, with the population as exposure.
4.  [`stay_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stay_summary.md)
    whenever per-person stays are available, and report the median.

## Reference

Lakner, *A Manual of Correctional Statistics* (the ADP and ALOS worked
examples at pp. 15 and 17 are reproduced above).
