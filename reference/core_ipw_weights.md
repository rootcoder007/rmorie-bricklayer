# Trimmed inverse-probability weights (C backend)

The inverse-probability-of-treatment weights \\1/e\\ for the treated and
\\1/(1-e)\\ for the untreated, with the propensity score clamped into
`[trim_lo, trim_hi]` FIRST. Clamping matters: an untrimmed score near 0
or 1 produces a weight large enough for one observation to dominate the
entire estimate.

## Usage

``` r
core_ipw_weights(treat, propensity, trim_lo = 0.01, trim_hi = 0.99)
```

## Arguments

- treat:

  Numeric or logical treatment indicator; `1` / `TRUE` is treated.

- propensity:

  Numeric vector of propensity scores, the same length as `treat`.

- trim_lo, trim_hi:

  Clamp bounds for the score (defaults 0.01 and 0.99).

## Value

A numeric vector of weights the length of `treat`.

## Examples

``` r
treat <- c(1, 0, 1, 0)
e <- c(0.5, 0.25, 0.02, 0.9)

core_ipw_weights(treat, e)
#> [1]  2.000000  1.333333 50.000000 10.000000

# A balanced score gives weight 2 to either arm.
core_ipw_weights(c(1, 0), c(0.5, 0.5))
#> [1] 2 2

# Without trimming the third observation would carry weight 50; the
# default clamp holds it to 100 at the 0.01 floor, and a looser floor
# tames it further.
core_ipw_weights(treat, e, trim_lo = 0.10)
#> [1]  2.000000  1.333333 10.000000 10.000000

# Logical treatment indicators work too.
core_ipw_weights(c(TRUE, FALSE), c(0.4, 0.4))
#> [1] 2.500000 1.666667
```
