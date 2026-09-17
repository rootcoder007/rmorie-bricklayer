# Exact p-values for the rows of a year-over-year table

For count units the interval in
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
is the exact conditional binomial interval for the ratio of two Poisson
means; this is the matching two-sided test, so a scan over many groups
can be corrected for multiple comparisons with
[`scan_adjust()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scan_adjust.md).
The test conditions on the total of the two periods and asks whether the
split is compatible with equal means.

## Usage

``` r
yoy_pvalues(y)
```

## Arguments

- y:

  An `rmbl_yoy` object with count units.

## Value

`y` with a `p_value` column; `NA` where there is no comparison period or
both counts are zero.

## Examples

``` r
seg <- data.frame(year = rep(2022:2023, each = 3),
                  site = rep(c("A", "B", "C"), 2),
                  n = c(30, 50, 80, 45, 52, 79))
y <- yoy(seg, value = "n", period = "year", by = "site")
yoy_pvalues(y)$p_value
#> [1]        NA 0.1053423        NA 0.9211910        NA 1.0000000
```
