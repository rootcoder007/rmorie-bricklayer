# Text map of where the missing values are

Draws the missingness of a whole table as a grid, one character per cell
block – a console counterpart of `visdat::vis_miss()` that needs no
graphics device, so it works over SSH, in a log, and inside a capsule's
plain-text summary.

## Usage

``` r
missingness_map(data, height = 20L, width = 12L)
```

## Arguments

- data:

  A data frame.

- height:

  Maximum rows in the map (default 20).

- width:

  Maximum characters per column label (default 12).

## Value

A character vector of the map's lines, invisibly; printed as a side
effect.

## Details

Rows are binned so the map fits `height` lines; a block is drawn at the
shade its missing proportion falls in. Seeing the table at once is the
point: a diagonal band, a block of rows, or a single ragged column are
all instantly recognisable shapes that a column of percentages is not.

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
```
