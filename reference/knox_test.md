# Near-repeat analysis: the Knox test for space-time clustering

Asks whether incidents close together in space also happen close
together in time more often than chance would give – the near-repeat
pattern of burglary and shootings. Pairs of incidents are classified by
distance band and time band; each cell's count is compared with the
count expected if the times were shuffled among the locations, and a
Monte Carlo permutation test gives its p-value.

## Usage

``` r
knox_test(
  x,
  y,
  time,
  space_bands,
  time_bands,
  nsim = 999L,
  seed = NULL,
  coords = c("lonlat", "planar"),
  max_pairs = 5e+07
)
```

## Arguments

- x, y:

  Locations: longitude and latitude in degrees by default
  (`coords = "lonlat"`), or planar coordinates in metres.

- time:

  Times of the incidents: `Date`, `POSIXct`, or numbers in days.

- space_bands:

  Upper edges of the distance bands in metres, increasing:
  `c(100, 200, 400)` is 0-100, 100-200 and 200-400 m.

- time_bands:

  Upper edges of the time bands in days, increasing.

- nsim:

  Monte Carlo permutations. Default 999.

- seed:

  Optional seed for the permutations; the caller's random stream is left
  as it was.

- coords:

  `"lonlat"` or `"planar"`.

- max_pairs:

  Limit on candidate pairs held in memory. Default 5e7.

## Value

A list of class `rmbl_knox`: `table`, a long data frame with one row per
distance-by-time cell (`space_lower`, `space_upper`, `time_lower`,
`time_upper`, `observed`, `expected`, `ratio`, `p_value`); the `n`
incidents used; `nsim`.

## Details

Under the null hypothesis that the times are exchangeable among the
locations, every unordered pair of locations receives a uniformly random
pair of times, so the expected count in a cell is exact: \\E\_{st} = S_s
T_t / P\\, where \\S_s\\ is the number of pairs in distance band \\s\\,
\\T_t\\ the number in time band \\t\\, and \\P = n(n-1)/2\\. The ratio
is \\O\_{st} / E\_{st}\\: above 1, pairs that close in space are that
close in time more often than chance. The p-value of each cell is
one-sided, \\(1 + \\\\O^\* \ge O\\) / (1 + nsim)\\ over the
permutations. Cells are tested separately; a table of many cells will
show some small p-values by chance alone.

Only pairs within the largest distance band are needed, and they are
found by hashing the locations to a grid, so the work grows with the
number of close pairs rather than with \\n^2\\.

Ties in time – incidents recorded to the day – put same-day pairs in the
first time band (0 to its edge). The test speaks to the timing of
incidents relative to each other, not to what caused them; near-repeat
patterns also arise when one offender commits a series.

## References

Knox, E. G. (1964). The detection of space-time interactions. *Journal
of the Royal Statistical Society, Series C (Applied Statistics)*, 13(1),
25-30.

Mantel, N. (1967). The detection of disease clustering and a generalized
regression approach. *Cancer Research*, 27(2), 209-220.

Johnson, S. D., Bernasco, W., Bowers, K. J., Elffers, H., Ratcliffe, J.,
Rengert, G. and Townsley, M. (2007). Space-time patterns of risk: a
cross national assessment of residential burglary victimization.
*Journal of Quantitative Criminology*, 23(3), 201-219.

## See also

[`crime_density`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crime_density.md).

## Examples

``` r
b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv",
                          package = "rmoriebricklayer"))
b <- b[!is.na(b$lon), ]
kn <- knox_test(b$lon, b$lat, as.Date(b$occ_date), space_bands = c(100, 200, 400),
                time_bands = c(7, 14, 28), nsim = 199, seed = 1)
kn
#> ── Knox ratios, observed / expected pairs (508 incidents, 199 permutations)  
#>   distance  0-7 d 7-14 d 14-28 d
#>    0-100 m 1.66**   1.16    1.09
#>  100-200 m   1.25   0.91    1.17
#>  200-400 m   1.07   1.03    1.01
#> 
#>   * p < 0.05, ** p < 0.01, one-sided per cell (not adjusted for the number of cells)
#> ────────────────────────────────────────────────────────────────── 
plot(kn)
```
