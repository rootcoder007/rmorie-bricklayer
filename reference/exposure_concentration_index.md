# Concentration index of exposure by income

Wagstaff, Paci and van Doorslaer (1991): \$\$CI = (2 / \mu) \\
\mathrm{cov}(h_i, R_i)\$\$ with \\R_i = (rank_i - 0.5) / n\\ the
fractional income rank (tied incomes share their average rank, so the
index does not depend on row order) and the population covariance.
Negative values mean lower-income units bear more exposure. Both columns
must be numeric: a factor or character income is refused rather than
ranked by its level codes, and exposures must be non-negative.

## Usage

``` r
exposure_concentration_index(data, exposure, income)
```

## Arguments

- data:

  A data frame.

- exposure, income:

  Column names.

## Value

A list of class `rmbl_equity` with `concentration_index`,
`interpretation`, `exposure_mean`, `citation` and `extra` (`n`, the
covariance and the concentration curve).

## References

Wagstaff, A., Paci, P. and van Doorslaer, E. (1991). On the measurement
of inequalities in health. Social Science and Medicine 33(5), 545-557.

## Examples

``` r
d <- data.frame(exposure = c(30, 25, 20, 15, 10), income = 1:5)
exposure_concentration_index(d, "exposure", "income")$concentration_index
#> [1] -0.2
```
