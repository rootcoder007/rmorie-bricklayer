# Convert a human-readable SIU report date to ISO format

Turns the written-out dates found in SIU reports, in English or French,
into ISO `YYYY-MM-DD` strings that sort and convert with
[`as.Date()`](https://rdrr.io/r/base/as.Date.html). `"January 5, 2023"`,
`"January 5 2023"`, `"5 January 2023"` and `"5 janvier 2023"` all become
`"2023-01-05"`.

## Usage

``` r
siudate(x)
```

## Arguments

- x:

  A character vector of human-readable dates. A vector that is all `NA`
  (of any type) is accepted.

## Value

A character vector the same length as `x`: `YYYY-MM-DD` strings, `""`
for unparseable input and `NA` for `NA`. Unnamed.

## Details

Each element is parsed by the native core. Month names may be English or
French (accents optional), full or abbreviated, before or after the day;
ordinals such as `"1er"` are accepted, and an ISO date is passed
through. A date that does not exist (`"February 30, 2023"`) or text that
is not a date gives `""`. `NA` stays `NA`.

Error: `x` that is neither character nor all `NA` ("x must be a
character vector of dates").

## Examples

``` r
siudate(c("January 5, 2023", "not a date"))
#> [1] "2023-01-05" ""          

# French, day-first and impossible dates
siudate(c("5 janvier 2023", "5 January 2023", "February 30, 2023", NA))
#> [1] "2023-01-05" "2023-01-05" ""           NA          
as.Date(siudate("April 28, 2023"))
#> [1] "2023-04-28"

# numbers are refused
try(siudate(20230105))
#> Error : `x` must be a character vector of dates
```
