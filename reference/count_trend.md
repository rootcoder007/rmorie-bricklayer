# Trend in a count series, as a rate ratio per period

Fits a Poisson log-linear trend by iteratively reweighted least squares
and reports the multiplicative change per period, which is what a count
series' trend actually is. An offset carries the denominator when the
exposure varies.

## Usage

``` r
count_trend(y, x = NULL, offset = NULL, conf_level = 0.95)
```

## Arguments

- y:

  Counts, in period order.

- x:

  Periods. Defaults to the position.

- offset:

  Exposure for each period – a population, a number of admissions, a
  number of days. The trend is then in the rate rather than in the
  count.

- conf_level:

  Confidence level for the rate ratio.

## Value

A list with `rate_ratio` (per period), its interval, `p_value`, the
fitted values, the dispersion, and `overdispersed`.

## Details

The dispersion is reported because a Poisson fit assumes it is one. When
it is well above one the interval is too narrow, and the quasi-Poisson
interval – which scales the standard error by the square root of the
dispersion – is returned instead, with `overdispersed` set.

## Examples

``` r
# A count falling by about 15% a year.
set.seed(3)
y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))
fit <- count_trend(y)
round(fit$rate_ratio, 3)
#> [1] 0.869

# With a varying denominator the trend is in the rate.
count_trend(c(20, 25, 30), offset = c(1000, 1500, 2500))$rate_ratio
#> [1] 0.7708656
```
