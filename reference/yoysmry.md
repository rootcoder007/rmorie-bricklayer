# Summarise a change table

Collapses a period-over-period change table from
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
into one row per series (or one row per group when
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
was called with `by`). Each row gives the first and last observed
periods, the total change between them, the compound annual growth rate,
and how many period-to-period changes went up, went down or stayed flat.
Use it to report the whole span of a series in one line next to the
detailed table.

## Usage

``` r
yoysmry(object, ...)

# Default S3 method
yoysmry(object, ...)

# S3 method for class 'rmbl_yoy'
yoysmry(object, ...)
```

## Arguments

- object:

  An `rmbl_yoy` object returned by
  [`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- ...:

  Further arguments for methods; not used.

## Value

A data frame with one row per series or group and columns: the `by`
columns (character), when
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
had `by`; `from`, `to` (the first and last observed period, same type as
the period column); `first`, `last` (numeric values at those periods);
`totalpct`, `cagrpct` (numeric, percent); `periods` (integer, observed
periods); `up`, `down`, `flat` (integer counts of period-to-period
changes).

## Details

Rows whose `value` is missing are dropped before the summary, and the
remaining rows are sorted by period, text periods in the order
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
read them (its `prd` and `prdord`). Periods with no order (text
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
could not read, an unordered factor) have no first or last: `from`,
`to`, `first`, `last`, `totalpct` and `cagrpct` are then `NA`, with a
warning saying why. With \\v_1\\ the first and \\v_T\\ the last observed
value, the total change is \$\$100 (v_T / v_1 - 1)\$\$ and, with \\s =
(T - 1) / \mathrm{lag}\\ steps of length `lag`, \$\$100 \left( (v_T /
v_1)^{1/s} - 1 \right).\$\$ Both are `NA` when \\v_1 \le 0\\, because a
growth rate out of zero does not exist; `cagrpct` is also `NA` for a
single period. `"Annual"` in CAGR assumes one period is a year; for
monthly or quarterly data read it as the compound rate per `lag`
periods.

The `up`, `down` and `flat` counts are taken from the percent-change
column (`pctchg`, or `ppchg` for `units = "percent"`). A change out of a
zero base has no percent change and is not counted in any of the three.
A group with no non-missing value gives a row of `NA` with
`periods = 0`.

Anything other than a
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
result is refused with the error “`object` must be a yoy() result”.

## See also

[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
[`yoypals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoypals.md).

## Examples

``` r
# one series
d <- data.frame(year = 2018:2023, n = c(120, 131, 98, 140, 155, 149))
yoysmry(yoy(d, value = "n", prd = "year"))
#> ╭── Year-over-year summary ──────────────────────────────────────────────╮
#> │   Series  1                                                            │
#> │                                                                        │
#> │   from  to    first  last  totalpct  cagrpct  periods  up  down  flat  │
#> │   ----  ----  -----  ----  --------  -------  -------  --  ----  ----  │
#> │   2018  2023    120   149     24.17    4.424        6   3     2     0  │
#> │                                                                        │
#> │   totalpct is the change from the first period to the last and cagrpct │
#> │   the compound rate per step; up, down and flat count the changes from │
#> │   one period to the next.                                              │
#> ╰────────────────────────────────────────────────────────────────────────╯

# one row per group; a zero base gives no percent change
g <- data.frame(year = rep(2019:2022, 2), unit = rep(c("A", "B"), each = 4),
                n = c(10, 12, 0, 15, 5, 7, 6, 9))
yoysmry(yoy(g, value = "n", prd = "year", by = "unit"))
#> ╭── Year-over-year summary ──────────────────────────────────────────────╮
#> │   Series  2                                                            │
#> │                                                                        │
#> │   unit  from  to    first  last  totalpct  cagrpct  periods  up  down  │
#> │   ----  ----  ----  -----  ----  --------  -------  -------  --  ----  │
#> │   A     2019  2022     10    15        50    14.47        4   1     1  │
#> │   B     2019  2022      5     9        80    21.64        4   2     1  │
#> │                                                                        │
#> │   unit  flat                                                           │
#> │   ----  ----                                                           │
#> │   A        0                                                           │
#> │   B        0                                                           │
#> │                                                                        │
#> │   totalpct is the change from the first period to the last and cagrpct │
#> │   the compound rate per step; up, down and flat count the changes from │
#> │   one period to the next.                                              │
#> ╰────────────────────────────────────────────────────────────────────────╯

# anything that is not a yoy() result is refused
try(yoysmry(d))
#> Error : `object` must be a yoy() result, not data.frame
```
