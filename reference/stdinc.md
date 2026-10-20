# Standardised incidence ratio, with an exact interval

Divides each area's observed count by its expected count to give the
standardised incidence ratio (SIR), and adds an exact Poisson confidence
interval. A ratio of one is the overall experience; above one is an
excess and below one a deficit. Use it after
[`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md)
to say which areas differ from the overall rate by more than chance.

## Usage

``` r
stdinc(obs, expd, area = NULL, conflvl = 0.95)
```

## Arguments

- obs:

  Numeric vector of observed counts (non-negative).

- expd:

  Numeric vector of expected counts (positive), for example from
  [`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md);
  the same length as `obs`, or length one.

- area:

  Optional vector of area labels, added as the first column. Default
  `NULL`.

- conflvl:

  Number in (0, 1), default `0.95`: the two-sided confidence level of
  the interval.

## Value

A data frame with one row per area: `area` (when given), `observed`,
`expected`, `sir`, `lower`, `upper` (numeric), and logical `excess` (the
interval lies above one), `deficit` (the interval lies below one) and
`significant` (either).

## Details

With observed count \\O\\ and expected \\E\\, \\SIR = O / E\\. The
interval for \\1 - \alpha\\ coverage is
\$\$\left\[\frac{G^{-1}(\alpha/2;\\ O)}{E},\\ \frac{G^{-1}(1-\alpha/2;\\
O+1)}{E}\right\]\$\$ where \\G^{-1}(p; k)\\ is the gamma quantile with
shape \\k\\; the lower limit is 0 when \\O = 0\\. This is the exact
Poisson interval, from the relation between the Poisson and gamma
distributions, and so is identical to
[`stats::poisson.test()`](https://rdrr.io/r/stats/poisson.test.html)'s.
It is the interval to use here because the counts that matter are small:
a normal approximation on an observed count of three is not an interval,
it is a decoration.

Each area's interval is a separate test; with many areas some will
exclude one by chance (see
[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md)).
Missing values are dropped before the lengths are compared.

Errors: negative, infinite or non-numeric counts; an expected count of
zero or below; lengths that differ (a single `expd` is recycled). A
`conflvl` outside (0, 1) is an error.

## References

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, Chapter 1.

## See also

[`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md),
[`ebrates`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md),
[`fnllim`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)

## Examples

``` r
stdinc(obs = c(30, 12, 3), expd = c(20, 14, 5),
    area = c("North", "South", "East"))
#>    area observed expected       sir     lower    upper excess deficit
#> 1 North       30       20 1.5000000 1.0120437 2.141343   TRUE   FALSE
#> 2 South       12       14 0.8571429 0.4428982 1.497256  FALSE   FALSE
#> 3  East        3        5 0.6000000 0.1237344 1.753455  FALSE   FALSE
#>   significant
#> 1        TRUE
#> 2       FALSE
#> 3       FALSE

# An observed count of three carries almost no information, and the
# interval says so rather than hiding it.
stdinc(3, 5)
#>   observed expected sir     lower    upper excess deficit significant
#> 1        3        5 0.6 0.1237344 1.753455  FALSE   FALSE       FALSE

# a 90 percent interval, and a zero count (lower limit exactly 0)
stdinc(c(0, 40), c(2, 25), conflvl = 0.90)
#>   observed expected sir   lower    upper excess deficit significant
#> 1        0        2 0.0 0.00000 1.497866  FALSE   FALSE       FALSE
#> 2       40       25 1.6 1.20783 2.082775   TRUE   FALSE        TRUE

try(stdinc(c(3, 4), c(5, 0)))
#> Error : stdinc: `expd` must be positive
```
