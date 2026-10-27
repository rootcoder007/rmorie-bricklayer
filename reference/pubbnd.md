# Bounds implied by rounding and suppression in a published table

Administrative releases rarely publish the count that was observed.
Statistics Canada rounds to a base (random rounding to base 5 moves a
cell by up to 4); provincial tables round to the nearest 5 or 10; cells
below a disclosure limit are printed as `"x"`, `"<5"` or `".."`. Every
figure computed downstream inherits that uncertainty, and it is not
sampling uncertainty: no confidence interval covers it. This function
turns each published cell into the interval of observed counts that
could have produced it, so
[`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md)
and
[`yoybnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoybnd.md)
can carry the interval through a difference, a percent change or a rate.

## Usage

``` r
pubbnd(
  x,
  rnd = NULL,
  rndkind = c("nearest", "random"),
  suplim = NULL,
  supmar = c("x", "X", "s", "..", "F", "suppressed", "n/a")
)
```

## Arguments

- x:

  Published values: a numeric vector, or a character vector (or factor)
  in which suppressed cells appear as one of `supmar` or as `"<k"` for a
  limit `k`.

- rnd:

  Numeric scalar, the base the release rounds to (`5`, `10`, ...), or
  `NULL` (the default) when the counts are exact.

- rndkind:

  `"nearest"` (the printed value is the observed value rounded to the
  nearest multiple of `rnd`, so the observed value lies within half a
  base) or `"random"` (Statistics Canada's random rounding, where the
  observed value lies within `rounding - 1`).

- suplim:

  Numeric scalar or `NULL` (the default). For a cell printed as
  suppressed with no explicit limit, the smallest count that would have
  been published: the cell then lies in `[0, suplim - 1]`.

- supmar:

  Character vector of the strings that mark a suppressed cell, matched
  exactly after trimming. Default
  `c("x", "X", "s", "..", "F", "suppressed", "n/a")`.

## Value

A data frame of class `c("rmbl_bounds", "data.frame")`, one row per
cell, with `value` (numeric, the published number, `NA` for a suppressed
cell), `lower` and `upper` (numeric, the interval of observed counts)
and `status` (character: `"exact"`, `"rounded"`, `"suppressed"`, or
`"missing"` for an `NA` that carried no suppression mark). Attribute
`"bounds"` records `rounding`, `rndkind` and `suplim`.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws each
value inside its interval.

## Details

For a published value \\v\\ rounded to base \\b\\: with
`rndkind = "nearest"` the observed count lies in \\\[\max(0, v - b/2),
v + b/2\]\\; with `"random"` (unbiased random rounding, where a count is
moved to one of the two neighbouring multiples) it lies in \\\[\max(0,
v - (b - 1)), v + (b - 1)\]\\. The bounds are not rounded to whole
numbers. A suppressed cell lies in \\\[0, k - 1\]\\, with \\k\\ from
`"<k"` or from `suplim`; rounding is not applied to it. Without `rnd`, a
published number is taken as exact (lower = upper = value).

Text cells are trimmed, and thousands separators (commas) are removed
before they are read as numbers. A missing value (`NA`) that is not a
suppression mark gets status `"missing"` and `NA` bounds.

Errors: `rnd` not one positive finite number; a negative or infinite
count in `x`; an unknown `rndkind`; a text cell that is neither a number
nor a suppression mark (the message lists the cells); a suppressed cell
with no limit (neither `"<k"` nor `suplim`).

## See also

[`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md),
[`yoybnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoybnd.md)

## Examples

``` r
pubbnd(c(120, 35, 0), rnd = 5)
#> ╭── Publication bounds ───────────────────────────────────────────────────────╮
#> │   Cells     3: 0 exact, 3 rounded, 0 suppressed, 0 missing                  │
#> │   Rounding  to 5 (nearest)                                                  │
#> │                                                                             │
#> │   value   lower   upper  status                                             │
#> │   -----  ------  ------  -------                                            │
#> │     120  117.50  122.50  rounded                                            │
#> │      35   32.50   37.50  rounded                                            │
#> │       0    0.00    2.50  rounded                                            │
#> │                                                                             │
#> │   Each published number stands for the range of true counts that could      │
#> │   have produced it; a later comparison has to hold across it.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
pubbnd(c("120", "x", "<5"), rnd = 5,
                 suplim = 5)
#> ╭── Publication bounds ───────────────────────────────────────────────────────╮
#> │   Cells              3: 0 exact, 1 rounded, 2 suppressed, 0 missing         │
#> │   Rounding           to 5 (nearest)                                         │
#> │   Suppression limit  5                                                      │
#> │                                                                             │
#> │   value  lower    upper  status                                             │
#> │   -----  -----  -------  ----------                                         │
#> │     120  117.5  122.500  rounded                                            │
#> │            0.0    4.000  suppressed                                         │
#> │            0.0    4.000  suppressed                                         │
#> │                                                                             │
#> │   Each published number stands for the range of true counts that could      │
#> │   have produced it; a later comparison has to hold across it.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
# random rounding to base 5 is wider than rounding to the nearest 5
pubbnd(15, rnd = 5, rndkind = "random")
#> ╭── Publication bounds ───────────────────────────────────────────────────────╮
#> │   Cells     1: 0 exact, 1 rounded, 0 suppressed, 0 missing                  │
#> │   Rounding  to 5 (random)                                                   │
#> │                                                                             │
#> │   value  lower  upper  status                                               │
#> │   -----  -----  -----  -------                                              │
#> │      15     11     19  rounded                                              │
#> │                                                                             │
#> │   Each published number stands for the range of true counts that could      │
#> │   have produced it; a later comparison has to hold across it.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# thousands separators and a custom suppression mark
pubbnd(c("1,200", "--", "<10"), suplim = 10,
                 supmar = "--")
#> ╭── Publication bounds ───────────────────────────────────────────────────────╮
#> │   Cells              3: 1 exact, 0 rounded, 2 suppressed, 0 missing         │
#> │   Suppression limit  10                                                     │
#> │                                                                             │
#> │   value  lower  upper  status                                               │
#> │   -----  -----  -----  ----------                                           │
#> │   1,200  1,200  1,200  exact                                                │
#> │              0      9  suppressed                                           │
#> │              0      9  suppressed                                           │
#> │                                                                             │
#> │   Each published number stands for the range of true counts that could      │
#> │   have produced it; a later comparison has to hold across it.               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# a suppressed cell needs a limit
try(pubbnd(c("120", "x")))
#> Error : a suppressed cell has no limit: give `suplim` or write the cell as "<k"
```
