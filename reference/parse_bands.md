# Parse banded category labels into numeric bounds

Published administrative tables often report intervals instead of
values: "18 to 24", "2 to 5", "50+", "Greater than 15 days". This
function reads such labels into a lower and an upper bound per band, and
flags the bands that are open at the top or the bottom. It recognises
the wordings open-data publishers actually use, and leaves a label it
cannot read as `NA` rather than guessing. Use it as the first step
before
[`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md),
[`expand_bands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expand_bands.md)
or
[`band_sensitivity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md).

## Usage

``` r
parse_bands(x, closed_upper = TRUE, integer_scale = TRUE)
```

## Arguments

- x:

  Character vector (or factor) of band labels.

- closed_upper:

  Logical, default `TRUE`. For the inclusive open-upper wordings (`"+"`,
  `"and over"`, `"or more"` and the like), whether the stated number
  belongs to the band: `TRUE` reads `"50+"` as 50 and above, `FALSE` as
  above 50 (lower bound 51 on an integer scale). The exclusive wordings
  (`"greater than 15"`) always exclude the number.

- integer_scale:

  Logical, default `TRUE`. Whether the quantity is integer-valued
  (counts, days, whole years). It decides whether `"greater than 15"`
  starts at 16 (`TRUE`) or at 15 as an infimum (`FALSE`). A label
  written with decimals is always treated as continuous.

## Value

A data frame with one row per label and columns `label` (character, as
given), `lower` and `upper` (numeric bounds, `NA` for the open side of
an open band or for an unparsed label), and `open_lower`, `open_upper`
(logical).

## Details

Labels are lower-cased and trimmed; the Unicode dash family (U+2010 to
U+2015 and the minus sign U+2212) is read as a hyphen, and correctly
grouped thousands separators are removed (`"1,000 to 2,499"`). Then, in
order:

- **Closed range**: two numbers joined by `to`, `-` or `through`,
  optionally preceded by one word and followed by a unit
  (`"ages 18-24"`, `"0 to 5 overnight stays"`). The two numbers must be
  the only numbers in the label, the lower must not exceed the upper,
  and no open-band cue word (over, under, more, less, plus, ...) or `+`
  may appear; otherwise the label is `NA`.

- **Open upper band, inclusive**: `"50+"`, `"65 and over"`,
  `"and above"`, `"or more"`, `"or over"`, `"plus"`. The lower bound is
  the number when `closed_upper = TRUE`, and the number plus one step
  otherwise.

- **Open upper band, exclusive**: `"greater than"`, `"more than"`,
  `"over"`, `"above"`, `"gt"`. The lower bound is the number plus one
  step.

- **Open lower band, inclusive**: `"17 and under"`, `"or less"`,
  `"or fewer"`, `"and below"`, `"or under"`. The upper bound is the
  number.

- **Open lower band, exclusive**: `"less than"`, `"fewer than"`,
  `"under"`, `"below"`, `"<"`, `"lt"`. The upper bound is the number
  minus one step.

- **Bare number**: a band of width zero. A bare negative number (`"-5"`)
  is read as a suppressed cell and stays `NA`.

The step is 1 when `integer_scale = TRUE` and the label has no decimal
point, and 0 otherwise. A label with more than one number that is not a
range, an empty label and `NA` all give `NA` bounds. Anything other than
a character or factor vector is an error.

## References

The forms recognised here are taken from the categories the Ontario
Ministry of the Solicitor General publishes in its inmate datasets (the
segregation and restrictive-confinement releases), where the
placement-count and age categories are banded and the top band is open.

## See also

[`band_values`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md),
[`band_sensitivity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md),
[`expand_bands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expand_bands.md)

## Examples

``` r
parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#>             label lower upper open_lower open_upper
#> 1               1     1     1      FALSE      FALSE
#> 2          2 to 5     2     5      FALSE      FALSE
#> 3         6 to 10     6    10      FALSE      FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE

parse_bands(c("18 to 24", "25 to 49", "50+", "under 18"))
#>      label lower upper open_lower open_upper
#> 1 18 to 24    18    24      FALSE      FALSE
#> 2 25 to 49    25    49      FALSE      FALSE
#> 3      50+    50    NA      FALSE       TRUE
#> 4 under 18    NA    17       TRUE      FALSE

# "50+" excluding 50, and a continuous scale
parse_bands(c("50+", "over 15"), closed_upper = FALSE)
#>     label lower upper open_lower open_upper
#> 1     50+    51    NA      FALSE       TRUE
#> 2 over 15    16    NA      FALSE       TRUE
parse_bands(c("over 15", "under 0.5"), integer_scale = FALSE)
#>       label lower upper open_lower open_upper
#> 1   over 15    15    NA      FALSE       TRUE
#> 2 under 0.5    NA   0.5       TRUE      FALSE

# An unrecognised or self-contradictory label is NA, not guessed at.
parse_bands(c("3", "unknown", "24 to 18", "15 to 19 and over"))
#>               label lower upper open_lower open_upper
#> 1                 3     3     3      FALSE      FALSE
#> 2           unknown    NA    NA      FALSE      FALSE
#> 3          24 to 18    NA    NA      FALSE      FALSE
#> 4 15 to 19 and over    NA    NA      FALSE      FALSE

try(parse_bands(1:3))
#> Error : `x` must be character band labels
```
