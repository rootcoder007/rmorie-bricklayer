# Expected counts under indirect standardisation

Computes, for each area (region, district, institution), the count it
would have if it experienced the overall rate in every stratum, given
its own population in each stratum. Comparing an area's observed count
with this expected count, rather than comparing raw rates, removes the
part of the difference that is explained by who lives in (or is held in)
the area. The result feeds
[`stdinc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md),
[`ebrates`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md)
and
[`fnllim`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md).

## Usage

``` r
expcnts(cnts, pop, area, strata = NULL)
```

## Arguments

- cnts:

  Numeric vector of observed counts (non-negative), one per row of the
  area-by-stratum table.

- pop:

  Numeric vector of the population at risk (positive), the same length
  as `cnts`.

- area:

  Vector of area labels, one per row (converted to character).

- strata:

  Optional vector of stratum labels, one per row: an age band, a gender,
  or their interaction. Default `NULL`: one stratum, so only size is
  adjusted for. With strata the standardisation is indirect in the usual
  sense: the overall stratum-specific rates are applied to each area's
  own stratum populations.

## Value

A data frame with one row per area and columns `area` (character),
`observed`, `population` and `expected` (numeric totals over the area's
rows).

## Details

With \\O\_{as}\\ and \\P\_{as}\\ the count and population of area \\a\\
in stratum \\s\\, the reference rate of a stratum is pooled over all
areas, \\r_s = \sum_a O\_{as} / \sum_a P\_{as}\\, and \$\$E_a = \sum_s
P\_{as} r_s.\$\$ Without strata the expected count is just the area's
population times the overall rate, which adjusts for size but not for
composition. The two are worth distinguishing: a region holding
disproportionately many young men will show an excess on the first and
may show none on the second, and only the second is evidence about the
region.

Rows may repeat an area-stratum pair; they are summed. Rows with a
missing count, population, area or stratum are dropped. The output is
sorted by area label. Because the reference rates come from the same
data, \\\sum_a E_a = \sum_a O_a\\.

Errors: non-numeric, negative or infinite counts or populations; a
population of zero; `cnts`, `pop`, `area` or `strata` of different
lengths.

## References

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC. Chapter 1 sets out the convention used
here: the expected counts come from applying the overall population rate
to each area, and the standardised incidence ratio is the ratio of count
to expected.

Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods Using
R*. Springer, on the distinction between indirect standardisation, which
applies the reference's stratum-specific rates to the study population,
and direct standardisation, which does the reverse.

## See also

[`stdinc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md),
[`ebrates`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md),
[`fnllim`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)

## Examples

``` r
d <- data.frame(
  region = rep(c("North", "South", "East"), each = 2),
  age = rep(c("18 to 24", "25 to 49"), 3),
  n = c(30, 45, 12, 60, 8, 20),
  pop = c(1000, 6000, 900, 9000, 400, 3500)
)

# Adjusting for size only.
expcnts(d$n, d$pop, d$region)
#>    area observed population expected
#> 1  East       28       3900 32.81250
#> 2 North       75       7000 58.89423
#> 3 South       72       9900 83.29327

# Adjusting for size AND age composition, which is the comparison
# that says something about the region.
e <- expcnts(d$n, d$pop, d$region, strata = d$age)
e
#>    area observed population expected
#> 1  East       28       3900 32.34430
#> 2 North       75       7000 62.27967
#> 3 South       72       9900 80.37603

# the expected counts feed the standardised ratio
stdinc(e$observed, e$expected, area = e$area)
#>    area observed expected       sir     lower    upper excess deficit
#> 1  East       28 32.34430 0.8656857 0.5752419 1.251157  FALSE   FALSE
#> 2 North       75 62.27967 1.2042453 0.9472153 1.509532  FALSE   FALSE
#> 3 South       72 80.37603 0.8957895 0.7009001 1.128099  FALSE   FALSE
#>   significant
#> 1       FALSE
#> 2       FALSE
#> 3       FALSE

# a population of zero has no rate
try(expcnts(c(1, 2), c(10, 0), c("a", "b")))
#> Error : `pop` must be positive
```
