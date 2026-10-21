# Demonstration datasets

Seeded synthetic datasets, made up but shaped like the data each family
of the package reads, so that every tab of
[`rmblapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmblapp.md)
(and any example) has something realistic to run on without a download.
Each call with the same `name` returns the same data, and the caller's
random number stream is left as it was.

## Usage

``` r
rmbldemo(name = NULL)
```

## Arguments

- name:

  The dataset, one of the names `rmbldemo()` lists; `NULL` (the default)
  lists them.

## Value

A data frame; for `"ledger"` the ledger as
[`ldgrread()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ldgrread.md)
returns it. With `name = NULL`, a data frame of `name`, `rows` and
`description`.

## Details

Every dataset is generated in R from a fixed seed, with
[`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md)
for the categorical and count columns and base R's random number
generators for the rest. None of it describes real people, courts or
places.

- `court`:

  576 rows: 16 courts by 36 months (2022 to 2024). Columns `court`,
  `region`, `month` (1 to 36), `date`, `received`, `disposed`, `pending`
  (the backlog carried forward), `clearance` (disposed per 100
  received), `caseload` (cases received per judge), `delay` (median days
  to disposition), `reformed` (1 from the month a court adopted the
  reform) and `refmonth` (the month it did, `NA` for the eight that
  never did). Eight courts adopt a case-management reform in months 13,
  19, 25 or 31; it lowers `delay` by 12 days, and the courts share a
  seasonal cycle and a common trend, so the parallel-trends assumption
  holds.

- `offences`:

  1,440 rows: monthly offence counts for 10 areas, 2013 to 2024. Columns
  `area`, `year`, `month`, `date`, `n` (Poisson counts with a summer
  peak of about 15 percent) and `pop` (growing 1 percent a year). From
  April 2020 every area's level steps down by 28 percent and stays
  there.

- `offences_annual`:

  120 rows: `offences` summed by area and year (`n`), with the mean
  population (`pop`).

- `survey`:

  1,200 respondents of a stratified two-stage sample: 4 strata
  (`stratum`), 10 primary sampling units in each (`psu`), design weights
  (`w`), and 20 bootstrap replicate weights `rw01` to `rw20` (Rao-Wu:
  primary units drawn with replacement within each stratum). Variables
  `age`, `sex`, `smoker` (0/1), `drinks` per week, `victim` (0/1,
  victimized in the past year), `trust` (1 to 5) and `income` (with 8
  percent missing and a few very large values).

- `fnmi`:

  128 rows in the layout of
  [`indiex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md):
  `period` (2015/2018, 2019/2022), `group` (First Nations, Metis, Inuit,
  Non-Indigenous), `age`, `indicator` (four health indicators),
  `estimate`, `lower`, `upper` (95 percent) and `quality` (A to E by
  coefficient of variation; F, with the estimate and its interval
  suppressed, above 33.3 percent).

- `otis`:

  144 rows: admissions to 12 institutions in 2013 to 2024, as a stock
  and flow table. Columns `inst`, `cd` (census division), `region`,
  `year`, `people` (admissions), `days` (days in custody of those
  admitted) and `releases`. Lengths of stay are log-normal and drift up
  after 2019.

- `air`:

  2,016 rows: hourly NO2 at 6 monitors for 14 days around one stack (10
  g/s, effective height 50 m). Columns `monitor`, `x`, `y`, `z` (metres
  from the stack), `hour`, `wind_from` (degrees), `wind_speed` (m/s),
  `stability` (Pasquill-Gifford class) and `no2` (micrograms per cubic
  metre): a diurnal background plus the stack's
  [`gplume()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
  concentration at the monitor for that hour's wind.

- `hawkes`:

  About 700 event times (`t`, in days, over 365 days) from a
  self-exciting process with a baseline of 0.9 events a day, branching
  ratio 0.55 and an exponential kernel of rate 0.8 a day, simulated by
  thinning; `date` and `district` are added.

- `drift`:

  3,000 rows: a reference and a current snapshot (`snapshot`) of 1,500
  rows each, with `age`, `income`, `region`, `visits` and `satisfied`.
  In the current snapshot age is 4 years older on average, income 16
  percent higher, the North region larger and satisfaction lower; visits
  do not change.

- `waits`:

  1,000 court cases: `case_id`, `court_type`, `days` to disposition (a
  gamma body with a heavy log-normal tail) and `appearances`
  (zero-inflated Poisson).

- `ledger`:

  A proof ledger of 120 theorems (proved, sorry or axiom) covering the
  package's functions, written to a temporary JSON file and read back
  with
  [`ldgrread()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ldgrread.md);
  four theorems carry checks that
  [`ldgrchk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ldgrread.md)
  runs.

## See also

[`rmblapp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmblapp.md),
whose tabs open on these datasets;
[`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md).

## Examples

``` r
rmbldemo()
#>               name rows
#> 1            court  576
#> 2         offences 1440
#> 3  offences_annual  120
#> 4           survey 1200
#> 5             fnmi  128
#> 6             otis  144
#> 7              air 2016
#> 8           hawkes   NA
#> 9            drift 3000
#> 10           waits 1000
#> 11          ledger  120
#>                                                                  description
#> 1           Court caseload panel, 16 courts by 36 months, a staggered reform
#> 2   Monthly offence counts by area, seasonal, with a step down in April 2020
#> 3                       The offence counts by area and year, with population
#> 4    Stratified two-stage survey with design and bootstrap replicate weights
#> 5  Published health table by distinction, suppressed cells and quality flags
#> 6       Custody admissions and days by institution and year (stock and flow)
#> 7                   Hourly NO2 at six monitors around a stack, with the wind
#> 8                                   Self-exciting event stream over one year
#> 9              Two snapshots of one table, reference and current, with drift
#> 10                  Days to disposition and appearances of 1,000 court cases
#> 11                 Proof ledger of 120 theorems and the functions they cover
head(rmbldemo("court"))
#>   court  region month       date received disposed pending clearance caseload
#> 1   C01 Central     1 2022-01-01      167      171     396     102.4     55.7
#> 2   C01 Central     2 2022-02-01      158      144     410      91.1     52.7
#> 3   C01 Central     3 2022-03-01      141      125     426      88.7     47.0
#> 4   C01 Central     4 2022-04-01      143      123     446      86.0     47.7
#> 5   C01 Central     5 2022-05-01      162      156     452      96.3     54.0
#> 6   C01 Central     6 2022-06-01      142      121     473      85.2     47.3
#>   delay reformed refmonth
#> 1 105.4        0       13
#> 2 109.9        0       13
#> 3 109.8        0       13
#> 4 107.9        0       13
#> 5 109.4        0       13
#> 6 100.7        0       13
identical(rmbldemo("survey"), rmbldemo("survey"))
#> [1] TRUE
```
