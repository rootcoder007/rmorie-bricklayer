# Everyday equivalents of a quantity of CO2-equivalent

Kilometres driven in an average European passenger car (175 gCO2/km) and
tree-months of carbon sequestration (917 gCO2 per tree per month), the
two comparisons the Green Algorithms calculator prints, with their
sources.

## Usage

``` r
footprint_equivalents(co2e_g)
```

## Arguments

- co2e_g:

  Grams of CO2-equivalent.

## Value

A list with `car_km`, `tree_months` and `sources`.

## References

Green Algorithms data v3.1, context.csv: car factor from Helmers et al.
(2019) Atmospheric Environment and UK BEIS 2019 conversion factors; tree
sequestration from Bernal et al. (2018) via the same file.

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
```
