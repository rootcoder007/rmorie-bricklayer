# Confidence limits from a standard error, a coefficient of variation or a margin of error

The comparisons of this family take an estimate and its published
confidence limits. Agencies that publish a standard error, a relative
standard error (coefficient of variation) or a margin of error instead
give the same information; this turns it into limits at the level
wanted.

## Usage

``` r
limfrom(est, se = NULL, cv = NULL, moe = NULL, moelev = 0.9, conflvl = 0.95)
```

## Arguments

- est:

  The estimates the limits are centred on.

- se, cv, moe:

  Give one: standard errors, coefficients of variation (relative
  standard errors, in percent), or margins of error.

- moelev:

  The confidence level of the margins of error (default 0.90).

- conflvl:

  The level of the limits returned (default 0.95).

## Value

A data frame: `estimate`, `lower`, `upper`, `se`.

## Details

With an estimate \\e\\ and \\z = \Phi^{-1}(1 - \alpha/2)\\ for the level
wanted, a standard error \\s\\ gives \\e \pm z s\\; a coefficient of
variation \\c\\ (in percent) gives \\s = e c / 100\\; a margin of error
\\m\\ at level `moelev` (the American Community Survey publishes 90%
margins) gives \\s = m / z\_{moe}\\. The limits are symmetric on the
estimate's scale.

## See also

[`qltyrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/qltyrcd.md),
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md).

## Examples

``` r
limfrom(c(24.1, 31.5), cv = c(8, 12))
#> ╭── Intervals from published precision ───────────────────────────────╮
#> │   Estimates  2                                                      │
#> │   Interval   normal, estimate +/- z x se (default 95%)              │
#> │                                                                     │
#> │   estimate     se  interval                                         │
#> │   --------  -----  --------------                                   │
#> │      24.10  1.928  [20.32, 27.88]                                   │
#> │      31.50  3.780  [24.09, 38.91]                                   │
#> │                                                                     │
#> │   Each interval is rebuilt from the published standard error, CV or │
#> │   margin of error, assuming a normal sampling distribution.         │
#> ╰─────────────────────────────────────────────────────────────────────╯
limfrom(1520, moe = 210)                 # a 90% margin of error
#> ╭── Intervals from published precision ───────────────────────────────╮
#> │   Estimates  1                                                      │
#> │   Interval   normal, estimate +/- z x se (default 95%)              │
#> │                                                                     │
#> │   estimate     se  interval                                         │
#> │   --------  -----  ------------                                     │
#> │      1,520  127.7  [1270, 1770]                                     │
#> │                                                                     │
#> │   Each interval is rebuilt from the published standard error, CV or │
#> │   margin of error, assuming a normal sampling distribution.         │
#> ╰─────────────────────────────────────────────────────────────────────╯
```
