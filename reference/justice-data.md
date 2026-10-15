# Court and police data shipped with the package

Small excerpts of published court and police statistics, in
`inst/extdata`, used by the examples, tests and the `courts-and-crime`
vignette. Each is a faithful copy of published numbers (no value
altered, no row invented); the full tables, every edition and location,
are on the package's data hub
([`bricklayer_data_load`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_data_manifest.md),
collections `ocj_statistics` and `tps_open_data`).

## Source

Ontario Court of Justice, court statistics,
<https://www.ontariocourts.ca/ocj/statistics/> (retrieved 2026-10-13),
editions 2012 to 2026, published by the Court for public use. Toronto
Police Service, Public Safety Data Portal, dataset "Break and Enter Open
Data", <https://data.tps.ca/> (retrieved 2026-10-13); contains
information licensed under the Open Government Licence - Toronto Police
Service. See `inst/COPYRIGHTS`.

## Value

No R object: each file is a CSV in `inst/extdata`, read into a data
frame with
`read.csv(system.file("extdata", <file>, package = "rmoriebricklayer"))`.

## Details

- `ocj_flow_ontario.csv`:

  Ontario Court of Justice, criminal clearance-rate statistics,
  province-wide, monthly from April 2024 to March 2026 (the 2026
  edition): `month`, cases `received`, cases `disposed`, cases `pending`
  (net of bench warrants).

- `ocj_time_to_disposition.csv`:

  The same months from the disposition-rate statistics: the shares of
  cases disposed in under 10 months, 10-15, 15-18 and over 18 months
  (cases without bench warrants), and the average days to disposition.

- `ocj_dispositions.csv`:

  Province-wide criminal cases disposed by how they ended, one row per
  calendar year 2012-2019, 2021, 2022, 2024 and 2025; each row adds to
  the year's published total. The 2020 edition covers October to
  September and the 2026 edition April to March; the 2023 edition
  publishes no Toronto figures, so it has no province-wide row.

- `ocj_offence_groups.csv`:

  The same years by offence group: cases received and disposed. The
  groups add to each year's province-wide total.

- `ocj_courts.csv`:

  The same years by court, with `court_series`, which names Toronto's
  courthouses "Toronto" throughout: from 2023 the Court publishes
  Toronto as one location (the new Toronto courthouse consolidated its
  criminal courts that year). Each year's courts add to the
  province-wide total.

- `tps_break_enter_d14_2024.csv`:

  Toronto Police Service Break and Enter open data, every break and
  enter that occurred in 2024 in division D14, one row per occurrence
  (508): `event_id`, occurrence date, premises type, the published
  longitude and latitude (which the Service offsets to the nearest
  intersection), and `offence_records`, the number of offence records
  the Service publishes for the occurrence (five have two). Built by
  `data-raw/tps_break_enter_d14_2024.R` in the source package.

## See also

[`case_flow`](https://rootcoder007.github.io/rmorie-bricklayer/reference/case_flow.md),
[`life_table`](https://rootcoder007.github.io/rmorie-bricklayer/reference/life_table.md),
[`disposition_mix`](https://rootcoder007.github.io/rmorie-bricklayer/reference/disposition_mix.md),
[`clearance_decomposition`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clearance_decomposition.md),
[`crime_density`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crime_density.md),
[`knox_test`](https://rootcoder007.github.io/rmorie-bricklayer/reference/knox_test.md).

## Examples

``` r
f <- read.csv(system.file("extdata", "ocj_flow_ontario.csv",
                          package = "rmoriebricklayer"))
head(f)
#>     month received disposed pending
#> 1 2024-04    21265    22053  148904
#> 2 2024-05    21521    22546  147957
#> 3 2024-06    19728    20599  145989
#> 4 2024-07    22483    19552  147277
#> 5 2024-08    21019    18383  149417
#> 6 2024-09    20720    18186  151588
c <- read.csv(system.file("extdata", "ocj_courts.csv",
                          package = "rmoriebricklayer"))
tapply(c$disposed, c$year, sum)
#>   2012   2013   2014   2015   2016   2017   2018   2019   2021   2022   2023 
#> 247047 231681 210098 205249 207160 214137 211488 220548 204308 209961 203206 
#>   2024   2025 
#> 245160 245012 
```
