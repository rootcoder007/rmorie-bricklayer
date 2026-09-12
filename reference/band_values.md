# Representative values for banded categories

Turns bounds into the single number per band that a calculation needs,
under a stated rule. The open band is the whole difficulty: it has no
midpoint, so a cap has to be supplied or assumed, and the assumption is
recorded in the result rather than absorbed into it.

## Usage

``` r
band_values(
  bands,
  rule = c("midpoint", "lower", "upper", "geometric"),
  open_upper_cap = NULL,
  open_upper_factor = 2,
  open_lower_floor = 0
)
```

## Arguments

- bands:

  A data frame from
  [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md),
  or labels to parse.

- rule:

  How to place a value inside a closed band. `"midpoint"` is the
  arithmetic mean of the bounds. `"lower"` and `"upper"` give the
  conservative and generous readings, which together bracket whatever
  the truth is. `"geometric"` suits a quantity whose distribution inside
  the band is closer to log-uniform than uniform, which is usual for
  counts and durations.

- open_upper_cap:

  Upper bound to assume for an open top band. The default multiplies the
  band's lower bound by `open_upper_factor`, which is an assumption and
  is flagged as one.

- open_upper_factor:

  Multiplier used when no cap is given.

- open_lower_floor:

  Lower bound to assume for an open bottom band. Defaults to zero.

## Value

The band table with a `value` column and an `assumed` column marking the
rows whose value rests on the open-band assumption.

## See also

[`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)

## Examples

``` r
b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))

band_values(b)
#>             label lower upper open_lower open_upper value assumed
#> 1               1     1     1      FALSE      FALSE   1.0   FALSE
#> 2          2 to 5     2     5      FALSE      FALSE   3.5   FALSE
#> 3         6 to 10     6    10      FALSE      FALSE   8.0   FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE  16.5    TRUE

# The lower and upper rules bracket the truth.
band_values(b, rule = "lower")$value
#> [1]  1  2  6 11
band_values(b, rule = "upper", open_upper_cap = 40)$value
#> [1]  1  5 10 40
```
