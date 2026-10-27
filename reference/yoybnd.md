# Add publication bounds to a year-over-year table

[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
gives an exact conditional-binomial interval for the percent change of a
count, which covers sampling variation. This adds the interval that
rounding and suppression in the published cells imply
([`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
carried through
[`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md)),
and a combined interval that is the union of the two, which is the
honest range for a figure read off a rounded table.

## Usage

``` r
yoybnd(y, rnd = NULL, rndkind = c("nearest", "random"), suplim = NULL)
```

## Arguments

- y:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
  with counts as values.

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

## Value

`y` (still an `rmbl_yoy`) with added numeric columns `envchglo`,
`envchgup`, `envpctlo`, `envpctup` and, when `y` has percent-change
intervals, `compctlo` and `compctup`. The rounding settings are recorded
as `bounds` in the `"yoy"` attribute.

## Details

The `value` and `previous` columns of `y` are passed to
[`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
with the same rounding and suppression settings, and the two intervals
to
[`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md).
The combined interval is the smallest interval that contains both the
sampling interval (`pctlo`, `pctup`) and the publication envelope: its
lower end is the smaller of the two lower ends, its upper end the larger
of the two upper ends. Where either is `NA` (the first period, or a
previous cell that could be zero) the combined end is `NA`. The function
does not check that `y` holds counts; publication bounds make sense only
for counts.

Errors when `y` does not come from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
and for the reasons
[`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md)
gives.

## See also

[`pubbnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md),
[`chgenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chgenv.md),
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

## Examples

``` r
seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
y <- yoy(seg, value = "n", prd = "year")
yoybnd(y, rnd = 5)
#> ╭── Change in n by year ──────────────────────────────────────────────────────╮
#> │   Rows    3                                                                 │
#> │   Change  in percent                                                        │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   year  n   previous  change  change %  interval                            │
#> │   ────  ──  ────────  ──────  ────────  ─────────────                       │
#> │   2021  40  —         —         —       —                                   │
#> │   2022  45  40        5       ▲ +12.5%  [-28%, +77%]                        │
#> │   2023  60  45        15      ▲ +33.3%  [-11%, +101%]                       │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# random rounding to base 5 widens the envelope
yb <- yoybnd(y, rnd = 5, rndkind = "random")
as.data.frame(yb)[, c("year", "envpctlo", "envpctup",
                      "compctlo", "compctup")]
#>   year  envpctlo envpctup  compctlo  compctup
#> 1 2021        NA       NA        NA        NA
#> 2 2022 -6.818182 36.11111 -28.16209  76.74679
#> 3 2023 14.285714 56.09756 -10.91249 100.82285

# only yoy() results are accepted
try(yoybnd(seg, rnd = 5))
#> Error : yoybnd: `y` must come from yoy()
```
