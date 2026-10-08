# Where is this computation running?

Finds a location code for
[`carbon_intensity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/carbon_intensity.md)
without any network access, in this order: the `RMBL_LOCATION`
environment variable (any code or name the table knows); codecarbon's
`CODECARBON_COUNTRY_ISO_CODE` (alpha-3), so a machine already configured
for codecarbon needs nothing more; the system time zone, mapped to its
country through the IANA zone tables (`America/Toronto` is Canada,
`Europe/Berlin` Germany); the territory in the locale (`en_CA.UTF-8` is
Canada). When none of these yields a location in the table the answer is
`"WORLD"`, and the method says so, so a report never silently applies
one country's grid to another's computation.

## Usage

``` r
detect_location(
  env_location = Sys.getenv("RMBL_LOCATION"),
  codecarbon_location = Sys.getenv("CODECARBON_COUNTRY_ISO_CODE"),
  tz = Sys.timezone(),
  locale = Sys.getlocale("LC_TIME")
)
```

## Arguments

- env_location, codecarbon_location, tz, locale:

  The inputs, exposed so a caller or a test can supply them; the
  defaults read the running session.

## Value

A list with `location` (a code present in
[`carbon_intensity_table()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/carbon_intensity.md))
and `method` (how it was found).

## Details

The zone table (`inst/extdata/timezone_countries.csv`, built by
`tools/build_timezones.R` from the IANA database) holds every zone of
`zone.tab`, which names exactly one country per zone (`Europe/Stockholm`
is Sweden even though the database now keeps its rules under
`Europe/Berlin`), plus every alias and old name in the `backward` file
(`US/Eastern`, `Asia/Calcutta`, `America/Montreal`) under the country of
the zone it links to. Every geographic zone
[`OlsonNames()`](https://rdrr.io/r/base/timezones.html) lists resolves;
the `Etc/`, `UTC` and fixed-offset zones name no country and fall
through to the locale.

## Examples

``` r
detect_location()
#> $location
#> [1] "WORLD"
#> 
#> $method
#> [1] "fallback, no location found in environment, time zone or locale"
#> 
detect_location(env_location = "", codecarbon_location = "", tz = "Europe/Paris")
#> $location
#> [1] "FR"
#> 
#> $method
#> [1] "system time zone Europe/Paris"
#> 
detect_location(env_location = "", codecarbon_location = "", tz = "",
                locale = "en_IN.UTF-8")
#> $location
#> [1] "IN"
#> 
#> $method
#> [1] "locale en_IN.UTF-8"
#> 
```
