# Parse banded category labels into numeric bounds

Recognises the forms that open-data publishers actually use: a bare
number ( `"3"`) , a closed range ( `"18 to 24"`, `"18-24"`, `"18 - 24"`)
, an open upper band ( `"50+"`, `"Greater than 15"`, `"over 15"`,
`"more than 15"`, `"65 and over"`) , and an open lower band ( `"<18"`,
`"under 18"`, `"less than 18"`) .

## Usage

``` r
parse_bands(x, closed_upper = TRUE, integer_scale = TRUE)
```

## Arguments

- x:

  Character labels.

- closed_upper:

  For an open upper band, whether the stated number is included. `"50+"`
  includes 50; `"Greater than 15"` does not, so its lower bound is 16
  for integer data. Controlled per-label by the wording, and this
  argument only settles the ambiguous `"+"` form.

- integer_scale:

  Whether the quantity is integer-valued, which decides whether
  `"greater than 15"` starts at 16 or just above 15.

## Value

A data frame with `label`, `lower`, `upper`, `open_lower` and
`open_upper`. An unparseable label gives `NA` bounds rather than a
guess.

## References

The forms recognised here are taken from the categories the Ontario
Ministry of the Solicitor General publishes in its inmate datasets (the
segregation and restrictive-confinement releases), where the
placement-count and age categories are banded and the top band is open.

## See also

[`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md),
[`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)

## Examples

``` r
parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#>             label lower upper open_lower open_upper
#> 1               1     1     1      FALSE      FALSE
#> 2          2 to 5     2     5      FALSE      FALSE
#> 3         6 to 10     6    10      FALSE      FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE

parse_bands(c("18 to 24", "25 to 49", "50+"))
#>      label lower upper open_lower open_upper
#> 1 18 to 24    18    24      FALSE      FALSE
#> 2 25 to 49    25    49      FALSE      FALSE
#> 3      50+    50    NA      FALSE       TRUE

# An unrecognised label is reported as unparsed, not guessed at.
parse_bands(c("3", "unknown", "not stated"))
#>        label lower upper open_lower open_upper
#> 1          3     3     3      FALSE      FALSE
#> 2    unknown    NA    NA      FALSE      FALSE
#> 3 not stated    NA    NA      FALSE      FALSE
```
