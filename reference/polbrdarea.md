# Per-area pollution burden

Applies
[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
to every row of a table with one row per area (forward sortation area,
census tract, neighbourhood, ...) and returns the rows sorted by
attributable cases, worst first. Use it to see where in a city or region
the pollution burden falls, for example to rank neighbourhoods for an
intervention.

## Usage

``` r
polbrdarea(
  areatab,
  areacol = "fsa",
  expcol = "exposure",
  popcol = "population",
  basratecol = "brate",
  poll = "NO2",
  y = "allcause",
  rare = FALSE,
  hirate = FALSE
)
```

## Arguments

- areatab:

  A data frame with one row per area: a label, the exposure in
  micrograms per cubic metre, the population in persons and the baseline
  rate per person-year (0.008 is 800 per 100,000).

- areacol, expcol, popcol, basratecol:

  Column names (single strings) of the label, exposure, population and
  rate; defaults `"fsa"`, `"exposure"`, `"population"` and `"brate"`.

- poll, y, rare, hirate:

  Passed to
  [`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
  for every area: the pollutant (default `"NO2"`), the outcome (default
  all-cause mortality), and the switches that admit a rate below 1e-5 or
  above 0.1 per person-year.

## Value

A data frame with one row per area, sorted by `attrcases`, largest
first, and row names reset: the four input columns (exposure, population
and rate as numbers) plus `rr` (relative risk), `paf` (attributable
fraction), `attrcases` and `basecases` (per year).

## Details

Each area is treated as wholly exposed at its own concentration
(`expoprev = 1`), with the pollutant's default reference concentration.
Every area is checked as
[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
checks a single population, and the first area that fails stops the call
with that area's error. Refusals: a column name that is not a single
string or not in the table, an empty table, and a non-numeric exposure,
population or rate column. The area labels can be of any type.

## See also

[`expconcidx`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expconcidx.md)
for how the burden is spread across income.

## Examples

``` r
t <- data.frame(fsa = c("M6H", "M5V"), exposure = c(28, 18),
                population = c(40000, 60000), brate = 0.008)
polbrdarea(t)
#>   fsa exposure population brate       rr        paf attrcases basecases
#> 1 M6H       28      40000 0.008 1.036288 0.03501694 11.205420       320
#> 2 M5V       18      60000 0.008 1.015968 0.01571728  7.544292       480

# PM2.5 and different column names.
u <- data.frame(tract = c("A", "B", "C"), pm = c(7, 11, 9),
                pop = c(5000, 8000, 6500), rate = 0.0075)
polbrdarea(u, areacol = "tract", expcol = "pm",
                         popcol = "pop", basratecol = "rate",
                         poll = "PM2.5")
#>   tract pm  pop   rate       rr        paf attrcases basecases
#> 1     B 11 8000 0.0075 1.040831 0.03922953 2.3537717     60.00
#> 2     C  9 6500 0.0075 1.024933 0.02432675 1.1859290     48.75
#> 3     A  7 5000 0.0075 1.009278 0.00919281 0.3447304     37.50

# A missing column is named in the error.
try(polbrdarea(t[, c("fsa", "exposure")]))
#> Error : areatab missing columns: population, brate
```
