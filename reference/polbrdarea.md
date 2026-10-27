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
#> ╭── Pollution burden by area ─────────────────────────────────────────────╮
#> │   Areas               2                                                 │
#> │   Attributable cases  18.75                                             │
#> │   Baseline cases      800                                               │
#> │   Share attributable  2.34%                                             │
#> │                                                                         │
#> │   fsa  exposure  population     brate     rr      paf  attrcases        │
#> │   ---  --------  ----------  --------  -----  -------  ---------        │
#> │   M6H        28      40,000  0.008000  1.036  0.03502     11.205        │
#> │   M5V        18      60,000  0.008000  1.016  0.01572      7.544        │
#> │                                                                         │
#> │   fsa  basecases                                                        │
#> │   ---  ---------                                                        │
#> │   M6H        320                                                        │
#> │   M5V        480                                                        │
#> │                                                                         │
#> │   The areas are sorted by the cases attributable to the exposure,       │
#> │   largest first: rr is the relative risk at the area's exposure and paf │
#> │   the share of its cases the exposure accounts for.                     │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# PM2.5 and different column names.
u <- data.frame(tract = c("A", "B", "C"), pm = c(7, 11, 9),
                pop = c(5000, 8000, 6500), rate = 0.0075)
polbrdarea(u, areacol = "tract", expcol = "pm",
                         popcol = "pop", basratecol = "rate",
                         poll = "PM2.5")
#> ╭── Pollution burden by area ─────────────────────────────────────────────╮
#> │   Areas               3                                                 │
#> │   Attributable cases  3.884                                             │
#> │   Baseline cases      146.2                                             │
#> │   Share attributable  2.66%                                             │
#> │                                                                         │
#> │   tract  pm    pop      rate     rr      paf  attrcases  basecases      │
#> │   -----  --  -----  --------  -----  -------  ---------  ---------      │
#> │   B      11  8,000  0.007500  1.041  0.03923      2.354      60.00      │
#> │   C       9  6,500  0.007500  1.025  0.02433      1.186      48.75      │
#> │   A       7  5,000  0.007500  1.009  0.00919      0.345      37.50      │
#> │                                                                         │
#> │   The areas are sorted by the cases attributable to the exposure,       │
#> │   largest first: rr is the relative risk at the area's exposure and paf │
#> │   the share of its cases the exposure accounts for.                     │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# A missing column is named in the error.
try(polbrdarea(t[, c("fsa", "exposure")]))
#> Error : areatab missing columns: population, brate
```
