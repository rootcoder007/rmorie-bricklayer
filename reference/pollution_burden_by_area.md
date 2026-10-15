# Per-area pollution burden

Applies
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
to every row of a table with one row per area (forward sortation area,
census tract, neighbourhood, ...) and returns the rows sorted by
attributable cases, worst first. Use it to see where in a city or region
the pollution burden falls, for example to rank neighbourhoods for an
intervention.

## Usage

``` r
pollution_burden_by_area(
  area_table,
  area_col = "fsa",
  exposure_col = "exposure",
  population_col = "population",
  baseline_rate_col = "baseline_rate",
  pollutant = "NO2",
  outcome = "all_cause_mortality",
  rare_outcome = FALSE,
  high_rate = FALSE
)
```

## Arguments

- area_table:

  A data frame with one row per area: a label, the exposure in
  micrograms per cubic metre, the population in persons and the baseline
  rate per person-year (0.008 is 800 per 100,000).

- area_col, exposure_col, population_col, baseline_rate_col:

  Column names (single strings) of the label, exposure, population and
  rate; defaults `"fsa"`, `"exposure"`, `"population"` and
  `"baseline_rate"`.

- pollutant, outcome, rare_outcome, high_rate:

  Passed to
  [`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
  for every area: the pollutant (default `"NO2"`), the outcome (default
  all-cause mortality), and the switches that admit a rate below 1e-5 or
  above 0.1 per person-year.

## Value

A data frame with one row per area, sorted by `attributable_cases`,
largest first, and row names reset: the four input columns (exposure,
population and rate as numbers) plus `rr` (relative risk), `paf`
(attributable fraction), `attributable_cases` and `baseline_cases` (per
year).

## Details

Each area is treated as wholly exposed at its own concentration
(`exposure_prevalence = 1`), with the pollutant's default reference
concentration. Every area is checked as
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
checks a single population, and the first area that fails stops the call
with that area's error. Refusals: a column name that is not a single
string or not in the table, an empty table, and a non-numeric exposure,
population or rate column. The area labels can be of any type.

## See also

[`exposure_concentration_index`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exposure_concentration_index.md)
for how the burden is spread across income.

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

# PM2.5 and different column names.
u <- data.frame(tract = c("A", "B", "C"), pm = c(7, 11, 9),
                pop = c(5000, 8000, 6500), rate = 0.0075)
pollution_burden_by_area(u, area_col = "tract", exposure_col = "pm",
                         population_col = "pop", baseline_rate_col = "rate",
                         pollutant = "PM2.5")
#>   tract pm  pop   rate       rr        paf attributable_cases baseline_cases
#> 1     B 11 8000 0.0075 1.040831 0.03922953          2.3537717          60.00
#> 2     C  9 6500 0.0075 1.024933 0.02432675          1.1859290          48.75
#> 3     A  7 5000 0.0075 1.009278 0.00919281          0.3447304          37.50

# A missing column is named in the error.
try(pollution_burden_by_area(t[, c("fsa", "exposure")]))
#> Error : area_table missing columns: population, baseline_rate
```
