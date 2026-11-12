# Exact p-values for the rows of a year-over-year table

Adds a two-sided exact p-value to each row of a period-over-period
change table of counts from
[`yoychg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md),
testing whether the count changed by more than chance between the two
periods. Use it when you want a test to go with each change, and then
pass the table to
[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md)
to correct for the number of rows tested.

## Usage

``` r
yoypv(y)
```

## Arguments

- y:

  An `rmbl_yoy` object from
  [`yoychg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md)
  with `units = "count"`.

## Value

`y`, with its class and attributes, and an added numeric `p_value`
column; `NA` where there is no comparison period or both counts are
zero.

## Details

For count units the interval in
[`yoychg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md)
is the exact conditional binomial interval for the ratio of two Poisson
means; this is the matching two-sided test. The test conditions on the
total of the two periods and asks whether the split is compatible with
equal means: with current count \\a\\ and previous count \\b\\, \\a \sim
\mathrm{Binomial}(a + b, 1/2)\\ under the null, and the p-value is that
of `stats::binom.test(a, a + b, p = 0.5)`. The two periods are treated
as having equal exposure; for changing populations use
[`ratechg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
and
[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md),
which weight by the exposures. Counts are rounded to whole numbers.

Errors: `y` not a
[`yoychg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md)
result; a
[`yoychg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md)
result whose units are not counts (percentages and measured values have
no Poisson test). A progress indicator is shown for long tables in an
interactive session.

## See also

[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md),
[`yoychg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoychg.md).

## Examples

``` r
seg <- data.frame(year = rep(2022:2023, each = 3),
                  site = rep(c("A", "B", "C"), 2),
                  n = c(30, 50, 80, 45, 52, 79))
y <- yoychg(seg, value = "n", prd = "year", by = "site")
yoypv(y)$p_value
#> [1]        NA 0.1053423        NA 0.9211910        NA 1.0000000

# the same test by hand for site A: 45 against 30
stats::binom.test(45, 75)$p.value
#> [1] 0.1053423

# anything that is not a yoychg() table is refused
try(yoypv(seg))
#> Error : yoypv: `y` must come from yoychg()
```
