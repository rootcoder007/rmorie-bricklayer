# Adjust a scan of many comparisons for multiple testing

A change table over fifty institutions is fifty tests. Reporting the raw
p-values invites reading the largest of fifty noise draws as a finding.
This adds `p_adjusted` (Benjamini-Hochberg by default, which controls
the false discovery rate over the scan) and `significant` at level
`alpha` after adjustment. Exact p-values are computed where the object
does not carry them: the conditional binomial test for
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
counts and for
[`rate_change()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rate_change.md)
(with the exposures as the binomial weights).

## Usage

``` r
scan_adjust(x, method = "BH", alpha = 0.05)
```

## Arguments

- x:

  An `rmbl_yoy` or `rmbl_rate_change` object, or any data frame with a
  `p_value` column.

- method:

  Adjustment passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html); `"BH"`
  (false discovery rate) by default, `"holm"` for family-wise control.

- alpha:

  Level at which `significant` is decided.

## Value

`x` with `p_value` (if it was missing), `p_adjusted` and `significant`;
the class and attributes of `x` are kept.

## Examples

``` r
seg <- data.frame(year = rep(2022:2023, each = 3),
                  site = rep(c("A", "B", "C"), 2),
                  n = c(30, 50, 80, 45, 52, 79))
y <- yoy(seg, value = "n", period = "year", by = "site")
scan_adjust(y)[, c("site", "pct_change", "p_value", "p_adjusted")]
#> <rmbl_yoy: no periods>
```
