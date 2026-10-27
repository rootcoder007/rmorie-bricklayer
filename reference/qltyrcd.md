# Recode another agency's quality flags to the package's

The comparisons of this family read Statistics Canada's quality flags:
`E` (use with caution), and `F`, `x`, `..`, `...` (no value: too
unreliable, suppressed, not available, not applicable). Other agencies
flag otherwise: the Australian Bureau of Statistics `np` (not published)
and `*` or `**` (relative standard error over 25% or 50%), Stats NZ `S`
(suppressed), the US Census Bureau `(X)`. This maps them to the
package's vocabulary, so suppressed cells are never compared and
uncertain ones are marked.

## Usage

``` r
qltyrcd(x, suppr = c("F", "x", "..", "..."), caution = "E")
```

## Arguments

- x:

  The flags, one per row.

- suppr:

  Flags meaning the value must not be used (it becomes `"x"`).

- caution:

  Flags meaning the value may be used with caution (it becomes `"E"`).

## Value

A character vector of `"ok"`, `"E"` and `"x"`; empty and missing flags
are `"ok"`. `x` must be character (or a factor); a flag in neither
`suppr` nor `caution` (other than `"ok"`) becomes `"ok"` and is named in
a warning.

## See also

[`limfrom`](https://rootcoder007.github.io/rmorie-bricklayer/reference/limfrom.md),
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md).

## Examples

``` r
# flags as an Australian table might give them
qltyrcd(c("", "np", "*", "**", NA), suppr = c("np", "**"), caution = "*")
#> [1] "ok" "x"  "E"  "x"  "ok"
```
