# Convert a human-readable SIU report date to ISO format

`"January 5, 2023"` (or `"January 5 2023"`) becomes `"2023-01-05"`;
unparseable input becomes `""`.

## Usage

``` r
bricklayer_siu_iso_date(x)
```

## Arguments

- x:

  A character vector of human-readable dates.

## Value

A character vector of `YYYY-MM-DD` strings (or `""`).

## Examples

``` r
bricklayer_siu_iso_date(c("January 5, 2023", "not a date"))
#> [1] "2023-01-05" ""          
```
