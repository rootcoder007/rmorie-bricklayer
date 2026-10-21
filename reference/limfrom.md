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

  The estimates.

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
#>   estimate    lower    upper    se
#> 1     24.1 20.32119 27.87881 1.928
#> 2     31.5 24.09134 38.90866 3.780
limfrom(1520, moe = 210)                 # a 90% margin of error
#>   estimate   lower   upper       se
#> 1     1520 1269.77 1770.23 127.6709
```
