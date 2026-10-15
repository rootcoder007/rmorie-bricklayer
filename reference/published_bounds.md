# Bounds implied by rounding and suppression in a published table

Administrative releases rarely publish the count that was observed.
Statistics Canada rounds to a base (random rounding to base 5 moves a
cell by up to 4); provincial tables round to the nearest 5 or 10; cells
below a disclosure limit are printed as `"x"`, `"<5"` or `".."`. Every
figure computed downstream inherits that uncertainty, and it is not
sampling uncertainty: no confidence interval covers it. This function
turns each published cell into the interval of observed counts that
could have produced it, so
[`change_envelope()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/change_envelope.md)
and
[`yoy_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_bounds.md)
can carry the interval through a difference, a percent change or a rate.

## Usage

``` r
published_bounds(
  x,
  rounding = NULL,
  rounding_kind = c("nearest", "random"),
  suppression_limit = NULL,
  suppressed_marks = c("x", "X", "s", "..", "F", "suppressed", "n/a")
)
```

## Arguments

- x:

  Published values: a numeric vector, or a character vector (or factor)
  in which suppressed cells appear as one of `suppressed_marks` or as
  `"<k"` for a limit `k`.

- rounding:

  Numeric scalar, the base the release rounds to (`5`, `10`, ...), or
  `NULL` (the default) when the counts are exact.

- rounding_kind:

  `"nearest"` (the printed value is the observed value rounded to the
  nearest multiple of `rounding`, so the observed value lies within half
  a base) or `"random"` (Statistics Canada's random rounding, where the
  observed value lies within `rounding - 1`).

- suppression_limit:

  Numeric scalar or `NULL` (the default). For a cell printed as
  suppressed with no explicit limit, the smallest count that would have
  been published: the cell then lies in `[0, suppression_limit - 1]`.

- suppressed_marks:

  Character vector of the strings that mark a suppressed cell, matched
  exactly after trimming. Default
  `c("x", "X", "s", "..", "F", "suppressed", "n/a")`.

## Value

A data frame of class `c("rmbl_bounds", "data.frame")`, one row per
cell, with `value` (numeric, the published number, `NA` for a suppressed
cell), `lower` and `upper` (numeric, the interval of observed counts)
and `status` (character: `"exact"`, `"rounded"`, `"suppressed"`, or
`"missing"` for an `NA` that carried no suppression mark). Attribute
`"bounds"` records `rounding`, `rounding_kind` and `suppression_limit`.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws each
value inside its interval.

## Details

For a published value \\v\\ rounded to base \\b\\: with
`rounding_kind = "nearest"` the observed count lies in \\\[\max(0, v -
b/2), v + b/2\]\\; with `"random"` (unbiased random rounding, where a
count is moved to one of the two neighbouring multiples) it lies in
\\\[\max(0, v - (b - 1)), v + (b - 1)\]\\. The bounds are not rounded to
whole numbers. A suppressed cell lies in \\\[0, k - 1\]\\, with \\k\\
from `"<k"` or from `suppression_limit`; rounding is not applied to it.
Without `rounding`, a published number is taken as exact (lower = upper
= value).

Text cells are trimmed, and thousands separators (commas) are removed
before they are read as numbers. A missing value (`NA`) that is not a
suppression mark gets status `"missing"` and `NA` bounds.

Errors: `rounding` not a positive number; an unknown `rounding_kind`; a
text cell that is neither a number nor a suppression mark (the message
lists the cells); a suppressed cell with no limit (neither `"<k"` nor
`suppression_limit`).

## See also

[`change_envelope()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/change_envelope.md),
[`yoy_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_bounds.md)

## Examples

``` r
published_bounds(c(120, 35, 0), rounding = 5)
#>   value lower upper  status
#> 1   120 117.5 122.5 rounded
#> 2    35  32.5  37.5 rounded
#> 3     0   0.0   2.5 rounded
published_bounds(c("120", "x", "<5"), rounding = 5,
                 suppression_limit = 5)
#>   value lower upper     status
#> 1   120 117.5 122.5    rounded
#> 2    NA   0.0   4.0 suppressed
#> 3    NA   0.0   4.0 suppressed
# random rounding to base 5 is wider than rounding to the nearest 5
published_bounds(15, rounding = 5, rounding_kind = "random")
#>   value lower upper  status
#> 1    15    11    19 rounded

# thousands separators and a custom suppression mark
published_bounds(c("1,200", "--", "<10"), suppression_limit = 10,
                 suppressed_marks = "--")
#>   value lower upper     status
#> 1  1200  1200  1200      exact
#> 2    NA     0     9 suppressed
#> 3    NA     0     9 suppressed

# a suppressed cell needs a limit
try(published_bounds(c("120", "x")))
#> Error : a suppressed cell has no limit: give `suppression_limit` or write the cell as "<k"
```
