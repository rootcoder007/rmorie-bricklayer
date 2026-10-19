# Adjust a scan of many comparisons for multiple testing

A change table over fifty institutions is fifty tests. Reporting the raw
p-values invites reading the largest of fifty noise draws as a finding.
This adds `padj` (Benjamini-Hochberg by default, which controls the
false discovery rate over the scan) and `significant` at level `alpha`
after adjustment. Exact p-values are computed where the object does not
carry them: the conditional binomial test for
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
counts and for
[`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
(with the exposures as the binomial weights).

## Usage

``` r
scanadj(x, meth = "BH", alpha = 0.05)
```

## Arguments

- x:

  An `rmbl_yoy` or `rmbl_rate_change` object, or any data frame with a
  `p_value` column.

- meth:

  Character, default `"BH"`. It can be any method of
  [`p.adjust`](https://rdrr.io/r/stats/p.adjust.html) (`"BH"`, `"holm"`,
  `"bonferroni"`, `"BY"`, `"hochberg"`, `"hommel"`, `"fdr"`, `"none"`).

- alpha:

  Number, default 0.05: the level at which `significant` is decided,
  applied to the adjusted p-values.

## Value

`x` with `p_value` (if it was missing), `padj` (numeric, `NA` where
`p_value` is) and `significant` (logical) columns; the class and
attributes of `x` are kept, and a `scanadj` attribute lists `method`,
`alpha` and `tests`.

## Details

For a
[`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
table, conditional on the two counts' total the current count is
binomial with success probability \\t_a / (t_a + t_b)\\, the share of
the combined exposure in the current period, and the p-value is the
two-sided exact binomial test of that. Rows without a p-value (no
comparison period, both counts zero) are left out of the adjustment, so
the number of tests is the number of rows with a p-value; it is recorded
in the `scanadj` attribute.

The adjustment is `stats::p.adjust(p, method)`: `"BH"` controls the
expected proportion of false discoveries among the rows declared
significant, which suits a screen; `"holm"` and `"bonferroni"` control
the chance of any false discovery, which a claim about one specific row
needs. A row is `significant` when its adjusted p-value is strictly
below `alpha`.

Errors: `x` not a data frame; no `p_value` column and not a
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
or
[`ratechg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
result; a
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
result without count units; a p-value outside \\\[0, 1\]\\; a method
unknown to [`p.adjust()`](https://rdrr.io/r/stats/p.adjust.html).

## See also

[`yoypv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypv.md),
[`falsfam`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsfam.md)
for a family of falsification results,
[`drftcal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftcal.md).

## Examples

``` r
seg <- data.frame(year = rep(2022:2023, each = 3),
                  site = rep(c("A", "B", "C"), 2),
                  n = c(30, 50, 80, 45, 52, 79))
y <- yoy(seg, value = "n", prd = "year", by = "site")
scanadj(y)[, c("site", "pctchg", "p_value", "padj")]
#>   site pctchg   p_value      padj
#> 1    A     NA        NA        NA
#> 2    A  50.00 0.1053423 0.3160268
#> 3    B     NA        NA        NA
#> 4    B   4.00 0.9211910 1.0000000
#> 5    C     NA        NA        NA
#> 6    C  -1.25 1.0000000 1.0000000

# family-wise control instead of the false discovery rate
scanadj(y, meth = "holm")$padj
#> [1]        NA 0.3160268        NA 1.0000000        NA 1.0000000

# any table with a p_value column
scanadj(data.frame(test = c("a", "b", "c"), p_value = c(0.001, 0.02, 0.4)))
#>   test p_value  padj significant
#> 1    a   0.001 0.003        TRUE
#> 2    b   0.020 0.030        TRUE
#> 3    c   0.400 0.400       FALSE

try(scanadj(data.frame(p_value = 1.5)))
#> Error : `p_value` must lie in [0, 1]; row(s) 1 hold 1.5. Nothing outside that range is a probability, so no adjustment or significance decision is made.
```
