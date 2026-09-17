# Add publication bounds to a year-over-year table

[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
gives an exact conditional-binomial interval for the percent change of a
count, which covers sampling variation. This adds the interval that
rounding and suppression in the published cells imply
([`published_bounds()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/published_bounds.md)
carried through
[`change_envelope()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/change_envelope.md)),
and a combined interval that is the union of the two, which is the
honest range for a figure read off a rounded table.

## Usage

``` r
yoy_bounds(
  y,
  rounding = NULL,
  rounding_kind = c("nearest", "random"),
  suppression_limit = NULL
)
```

## Arguments

- y:

  An `rmbl_yoy` object with count units.

- rounding:

  The base the release rounds to (`5`, `10`, ...), or `NULL` when the
  counts are exact.

- rounding_kind:

  `"nearest"` (the printed value is the observed value rounded to the
  nearest multiple of `rounding`, so the observed value lies within half
  a base) or `"random"` (Statistics Canada's random rounding, where the
  observed value lies within `rounding - 1`).

- suppression_limit:

  For a cell printed as suppressed with no explicit limit, the smallest
  count that would have been published: the cell then lies in
  `[0, suppression_limit - 1]`.

## Value

`y` with columns `env_change_lower`, `env_change_upper`,
`env_pct_lower`, `env_pct_upper`, `combined_pct_lower`,
`combined_pct_upper` and the rounding recorded in an attribute.

## Examples

``` r
seg <- data.frame(year = 2021:2023, n = c(40, 45, 60))
y <- yoy(seg, value = "n", period = "year")
yoy_bounds(y, rounding = 5)
#> year  n   previous  change  change %  interval     
#> ────  ──  ────────  ──────  ────────  ─────────────
#> 2021  40  —         —         —       —            
#>     ↳ percent withheld: no comparison period
#> 2022  45  40        5       ▲ +12.5%  [-28%, +77%] 
#> 2023  60  45        15      ▲ +33.3%  [-11%, +101%]
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20
```
