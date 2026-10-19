# Representative values for banded categories

Gives each band a single number that a calculation can use (a mean, a
concentration index, a regression), under a rule you choose. For closed
bands the rule places the value at the midpoint, the lower or upper
bound, or the geometric mean of the bounds. An open band ("50+", "under
18") has no midpoint, so its missing bound is filled from an explicit
assumption, and the rows that rest on that assumption are flagged in the
result instead of being absorbed into it.

## Usage

``` r
bandvals(
  bands,
  rule = c("midpoint", "lower", "upper", "geometric"),
  openupcap = NULL,
  openupfac = 2,
  openloflr = NULL
)
```

## Arguments

- bands:

  A data frame from
  [`prsbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md),
  or a character vector of labels to parse with its defaults.

- rule:

  Character, one of `"midpoint"` (the default), `"lower"`, `"upper"` or
  `"geometric"`. The geometric mean suits quantities whose distribution
  inside a band is closer to log-uniform than uniform, which is usual
  for counts and durations.

- openupcap:

  Number or `NULL` (the default). The upper bound assumed for every open
  top band, in the units of the labels.

- openupfac:

  Number, default `2`. When no cap is given, the open top band's upper
  bound is its lower bound times this factor (so "Greater than 10"
  becomes 11 to 22).

- openloflr:

  Number or `NULL` (the default). The lower bound assumed for an open
  bottom band ("under 18"). `NULL` uses 0, or the band's own upper bound
  when that is below 0. A floor above a band's upper bound is refused.

## Value

The band table with two added columns: `value` (numeric, the
representative value) and `assumed` (logical, `TRUE` for the open bands
whose value rests on the cap or floor).

## Details

For a band with bounds \\\[l, u\]\\ the value is \\(l + u)/2\\
(`"midpoint"`), \\l\\ (`"lower"`), \\u\\ (`"upper"`) or \\\sqrt{l u}\\
(`"geometric"`; when \\l \le 0\\ the arithmetic midpoint is used
instead, because the geometric mean is undefined there). The `"lower"`
and `"upper"` rules bracket any value that could come from the bands.

An open upper band gets \\u =\\ `openupcap` if given, else \\u = l
\times\\ `openupfac`. An open lower band gets \\l =\\ `openloflr` if
given, else \\\min(0, u)\\. A cap below the band's lower bound, or a
floor above its upper bound, is an error, because the value would lie
outside the band. Unparsed bands give `NA`.

Use
[`bandsens`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
to see how much a result moves with the cap, and
[`expbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expbands.md)
to turn the values into one value per unit.

## See also

[`prsbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md),
[`bandsens`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md),
[`expbands`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expbands.md)

## Examples

``` r
b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
bandvals(b)
#>             label lower upper openlo openup value assumed
#> 1               1     1     1  FALSE  FALSE   1.0   FALSE
#> 2          2 to 5     2     5  FALSE  FALSE   3.5   FALSE
#> 3         6 to 10     6    10  FALSE  FALSE   8.0   FALSE
#> 4 Greater than 10    11    NA  FALSE   TRUE  16.5    TRUE

# The lower and upper rules bracket the truth.
bandvals(b, rule = "lower")$value
#> [1]  1  2  6 11
bandvals(b, rule = "upper", openupcap = 40)$value
#> [1]  1  5 10 40

# geometric placement, and an explicit floor for an open bottom band
bandvals(b, rule = "geometric", openupcap = 40)$value
#> [1]  1.000000  3.162278  7.745967 20.976177
bandvals(c("under 5", "5 to 9", "10+"), openloflr = 1)
#>     label lower upper openlo openup value assumed
#> 1 under 5    NA     4   TRUE  FALSE   2.5    TRUE
#> 2  5 to 9     5     9  FALSE  FALSE   7.0   FALSE
#> 3     10+    10    NA  FALSE   TRUE  15.0    TRUE

# a cap inside the open band is refused
try(bandvals(b, openupcap = 5))
#> Error : the open-band cap (5) lies below the band's own lower bound (11); a midpoint there would be below every value in the band
```
