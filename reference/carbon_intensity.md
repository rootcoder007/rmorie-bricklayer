# Carbon intensity of electricity by location, offline, anywhere

The grams of CO2-equivalent emitted per kilowatt-hour of electricity at
a location, with the year and source of the figure. The table is bundled
with the package, so it works offline in any country: every country at
the latest year published by Our World in Data from Ember's yearly
electricity data (2024 or 2025 as of this release), sub-national zones
from Electricity Maps' 2024 yearly data as redistributed in the Green
Algorithms data release v3.1 (Canadian provinces and territories, US
balancing authorities, Australian states, Indian and Japanese regions,
Brazilian and Chilean systems, ...), and the world average. All figures
are lifecycle intensities (generation plus upstream), the basis both
sources publish.

## Usage

``` r
carbon_intensity(location = "WORLD")

carbon_intensity_table()
```

## Arguments

- location:

  A location code, alpha-3 code or name; a number in gCO2e/kWh, returned
  as a user-supplied value; or `NULL` to detect the location from the
  environment, time zone or locale.

## Value

`carbon_intensity()`: a list with `g_per_kwh`, `location`, `name`,
`year`, `basis`, `source` and `note` (a character vector, empty unless a
fallback or detection was involved). `carbon_intensity_table()`: the
full table as a data frame with the same columns plus `iso3`.

## Details

A location is matched by its code (`"CA"`, `"CA-ON"`, `"US-CAL-CISO"`),
its ISO 3166-1 alpha-3 code (`"CAN"`) or its name (`"Canada"`),
case-insensitively. An unknown sub-national code falls back to its
country and says so in `note`. `NULL` detects the location with
[`detect_location`](https://rootcoder007.github.io/rmorie-bricklayer/reference/detect_location.md).

## References

Ember (2026). Yearly Electricity Data, via Our World in Data,
<https://ourworldindata.org/grapher/carbon-intensity-electricity>.
Electricity Maps (2025). 2024 Yearly Carbon Intensity Data, via Green
Algorithms data v3.1. Lannelongue, L., Grealey, J. and Inouye, M.
(2021). Green Algorithms: quantifying the carbon footprint of
computation. Advanced Science 8(12), 2100707.

## Examples

``` r
carbon_intensity("CA-ON")
#> $g_per_kwh
#> [1] 90.97
#> 
#> $location
#> [1] "CA-ON"
#> 
#> $name
#> [1] "Canada, Ontario"
#> 
#> $year
#> [1] 2024
#> 
#> $basis
#> [1] "lifecycle"
#> 
#> $source
#> [1] "Electricity Maps (2025). Canada 2024 Yearly Carbon Intensity Data (Version January 27, 2025). Electricity Maps (via Green Algorithms data v3.1)"
#> 
#> $note
#> character(0)
#> 
carbon_intensity("Canada")$year
#> [1] 2025
carbon_intensity("CA-XX")$note
#> [1] "no row for zone CA-XX; its country CA used"
carbon_intensity(120)$source
#> [1] "user-supplied carbon intensity"
nrow(carbon_intensity_table())
#> [1] 380
```
