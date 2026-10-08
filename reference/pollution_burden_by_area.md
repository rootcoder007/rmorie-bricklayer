# Per-area pollution burden

Applies
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
to every row of a table with one row per area (forward sortation area,
census tract, neighbourhood, ...) and returns the rows sorted by
attributable cases, worst first.

## Usage

``` r
pollution_burden_by_area(
  area_table,
  area_col = "fsa",
  exposure_col = "exposure",
  population_col = "population",
  baseline_rate_col = "baseline_rate",
  pollutant = "NO2",
  outcome = "all_cause_mortality"
)
```

## Arguments

- area_table:

  A data frame with one row per area; the exposure in micrograms per
  cubic metre, the population in persons and the baseline rate per
  person-year.

- area_col, exposure_col, population_col, baseline_rate_col:

  Column names.

- pollutant, outcome:

  Passed to
  [`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md).

## Value

The input columns plus `rr`, `paf`, `attributable_cases` and
`baseline_cases`.

## Examples

``` r
t <- data.frame(fsa = c("M6H", "M5V"), exposure = c(28, 18),
                population = c(40000, 60000), baseline_rate = 0.008)
pollution_burden_by_area(t)
#>   fsa exposure population baseline_rate       rr        paf attributable_cases
#> 1 M6H       28      40000         0.008 1.036288 0.03501694          11.205420
#> 2 M5V       18      60000         0.008 1.015968 0.01571728           7.544292
#>   baseline_cases
#> 1            320
#> 2            480
```
