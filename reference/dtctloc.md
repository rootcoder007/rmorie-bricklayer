# Where is this computation running?

Finds a location code for
[`co2int`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md)
without any network access, in this order:

1.  the `RMBL_LOCATION` environment variable (any code or name the table
    knows);

2.  `CODECARBON_COUNTRY_ISO_CODE` (alpha-3), the codecarbon variable, so
    a machine already configured for codecarbon needs nothing more;

3.  the system time zone, mapped to its country through the IANA zone
    tables (`America/Toronto` is Canada, `Europe/Berlin` Germany);

4.  the territory in the locale (`en_CA.UTF-8` is Canada).

When none of these yields a location in the table the answer is
`"WORLD"`, and the method says so, so a report never silently applies
one country's grid to another's computation.

## Usage

``` r
dtctloc(
  envloc = Sys.getenv("RMBL_LOCATION"),
  codloc = Sys.getenv("CODECARBON_COUNTRY_ISO_CODE"),
  tz = Sys.timezone(),
  locale = Sys.getlocale("LC_TIME")
)
```

## Arguments

- envloc, codloc, tz, locale:

  The inputs, exposed so a caller or a test can supply them; the
  defaults read the running session.

## Value

A list with `location` (a code present in
[`co2inttab()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md))
and `method` (how it was found).

## Details

The zone table (`inst/extdata/timezone_countries.csv`, built by
`tools/build_timezones.R` from the IANA database) holds every zone of
`zone.tab`, which names exactly one country per zone (`Europe/Stockholm`
is Sweden even though the database now keeps its rules under
`Europe/Berlin`), plus the aliases and old names of the `backward` file
under their own country: the country of the zone the alias stood for
before the database merged it (`Iceland` is `Atlantic/Reykjavik`,
Iceland, not Abidjan's Ivory Coast), the link target's country when that
target serves a single country (`Asia/Calcutta`, `US/Eastern`), and a
reviewed list for the rest (`Atlantic/Jan_Mayen`,
`America/Coral_Harbour`, `Canada/Eastern`). Every geographic zone
[`OlsonNames()`](https://rdrr.io/r/base/timezones.html) lists resolves
to a country or territory; a territory the carbon table has no row of
its own for (Monaco, Jersey, Vaduz, the Antarctic stations) uses the
grid of the country it draws on or the world average, and the method
says which. The `Etc/`, `UTC`, fixed-offset and generic zones (`CET`,
`EST`, `WET`) name no country and fall through to the locale.

## Examples

``` r
dtctloc()
#> $location
#> [1] "WORLD"
#> 
#> $method
#> [1] "fallback, no location found in environment, time zone or locale"
#> 
dtctloc(envloc = "", codloc = "", tz = "Europe/Paris")
#> $location
#> [1] "FR"
#> 
#> $method
#> [1] "system time zone Europe/Paris"
#> 
dtctloc(envloc = "", codloc = "", tz = "",
                locale = "en_IN.UTF-8")
#> $location
#> [1] "IN"
#> 
#> $method
#> [1] "locale en_IN.UTF-8"
#> 
# an explicit setting wins over everything else
dtctloc(envloc = "CA-QC", tz = "Europe/Paris")
#> $location
#> [1] "CA-QC"
#> 
#> $method
#> [1] "RMBL_LOCATION environment variable"
#> 
# nothing usable: the world average, and the method says so
dtctloc(envloc = "", codloc = "", tz = "UTC", locale = "C")
#> $location
#> [1] "WORLD"
#> 
#> $method
#> [1] "fallback, no location found in environment, time zone or locale"
#> 
```
