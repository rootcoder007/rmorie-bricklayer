# Text map of where the missing values are

Draws the missingness of a whole table as a grid, one character per cell
block – a console counterpart of `visdat::vis_miss()` that needs no
graphics device, so it works over SSH, in a log, and inside a capsule's
plain-text summary.

Rows are binned so the map fits `height` lines; a block is drawn at the
shade its missing proportion falls in. Seeing the table at once is the
point: a diagonal band, a block of rows, or a single ragged column are
all instantly recognisable shapes that a column of percentages is not.

## Usage

``` r
missingness_map(data, height = 20L, width = 12L)
```

## Arguments

- data:

  A data frame.

- height:

  Whole number, default 20: the maximum number of lines (row blocks) in
  the map.

- width:

  Whole number, default 12: column names are cut to this many characters
  in the vertical legend.

## Value

A character vector of the map's lines, invisibly; the map is printed
with [`cat()`](https://rdrr.io/r/base/cat.html) as a side effect.

## Details

The rows are split into at most `height` consecutive blocks of nearly
equal size; each map line is one block, labelled with its first row
number, and each map column is one column of `data`. A cell's shade is
its block's proportion missing rounded to the nearest quarter: blank
(0), light, medium, dark, full (1). Where the console cannot show
Unicode the shades are `" .-+#"`. Column names are written vertically
above the map, cut to `width` characters. A table with no rows prints
`"(no rows)"`. Errors: `data` not a data frame or without columns;
`height` not a positive whole number.

## See also

[`missingness_pattern()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_pattern.md),
[`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)

## Examples

``` r
set.seed(1)
df <- data.frame(
  complete = 1:100,
  block = c(rep(NA, 30), 31:100),
  scattered = ifelse(stats::runif(100) < 0.3, NA, 1),
  mostly_gone = c(1:10, rep(NA, 90))
)
missingness_map(df)
#> ── Missingness map ───────────────────────────────────────────────
#>          cbsm
#>          olco
#>          moas
#>          pctt
#>          lktl
#>          eey
#>          tr_
#>          eeg
#>          do
#>          n
#>          e
#>        1  █▒ 
#>        6  █░ 
#>       11  █▒█
#>       16  █ █
#>       21  █▒█
#>       26  █░█
#>       31   ░█
#>       36   ░█
#>       41    █
#>       46   ░█
#>       51   ▒█
#>       56   ░█
#>       61   ░█
#>       66   ▒█
#>       71    █
#>       76    █
#>       81    █
#>       86   ▓█
#>       91   ▒█
#>       96    █
#> 
#>   legend: ' ' none  '█' all missing
#> ──────────────────────────────────────────────────────────────────
#> 

# a coarser map with short labels
missingness_map(df, height = 5, width = 4)
#> ── Missingness map ───────────────────────────────────────────────
#>          cbsm
#>          olco
#>          moas
#>          pctt
#>        1  █░▒
#>       21  ▒░█
#>       41   ░█
#>       61   ░█
#>       81   ░█
#> 
#>   legend: ' ' none  '█' all missing
#> ──────────────────────────────────────────────────────────────────
#> 

try(missingness_map(df, height = 0))
#> Error : `height` must be a single positive integer
```
