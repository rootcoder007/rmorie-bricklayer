# Everyday equivalents of a quantity of CO2-equivalent

Converts grams of CO2-equivalent into two everyday comparisons:
kilometres driven in an average European passenger car (175 gCO2/km) and
tree-months of carbon sequestration (917 gCO2 per tree per month), the
two comparisons the Green Algorithms calculator prints, with their
sources. Use it to make the `co2e_g` of
[`compute_footprint`](https://rootcoder007.github.io/rmorie-bricklayer/reference/compute_footprint.md)
easier to read in a report.

## Usage

``` r
footprint_equivalents(co2e_g)
```

## Arguments

- co2e_g:

  Numeric scalar, grams of CO2-equivalent; finite and non-negative (for
  example the `co2e_g` element of a
  [`compute_footprint`](https://rootcoder007.github.io/rmorie-bricklayer/reference/compute_footprint.md)
  result).

## Value

A list with `car_km` (numeric, kilometres), `tree_months` (numeric) and
`sources` (named character vector, `car` and `tree`, naming each
factor's source).

## Details

The conversions are plain divisions: \\\mathrm{km} = g / 175\\ and
\\\mathrm{tree\\ months} = g / 917\\. Both factors are averages and the
comparisons are illustrations, not offsets: a tree-month is the carbon
one mature tree takes up in a month, not a promise that planting one
cancels the emission. Errors when `co2e_g` is not a single finite,
non-negative number.

## References

Green Algorithms data v3.1, context.csv: car factor from Helmers et al.
(2019) Atmospheric Environment and UK BEIS 2019 conversion factors; tree
sequestration from Bernal et al. (2018) via the same file.

## See also

[`compute_footprint`](https://rootcoder007.github.io/rmorie-bricklayer/reference/compute_footprint.md)

## Examples

``` r
footprint_equivalents(1200)
#> $car_km
#> [1] 6.857143
#> 
#> $tree_months
#> [1] 1.308615
#> 
#> $sources
#>                                                                  car 
#> "175 gCO2/km, European passenger car (Green Algorithms context.csv)" 
#>                                                                 tree 
#>             "917 gCO2 per tree-month (Green Algorithms context.csv)" 
#> 

# the footprint of a small computation, in everyday terms
fp <- compute_footprint(sum(sqrt(seq_len(2e5))), location = "CA-ON",
                        cpu_power_w = 45, memory_gb = 8)
unlist(footprint_equivalents(fp$co2e_g)[c("car_km", "tree_months")])
#>       car_km  tree_months 
#> 5.733998e-09 1.094274e-09 

# a vector is refused: convert one total at a time
try(footprint_equivalents(c(10, 20)))
#> Error : `co2e_g` must be a single non-negative number
```
