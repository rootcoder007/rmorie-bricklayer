# Banded tables and concentration: from '6 to 10' to a Gini

Published frequency tables band their values: “1”, “2 to 5”, “6 to 10”,
“Greater than 10”. To compute anything about the underlying
distribution, the bands have to be parsed, given representative values,
and expanded into per-unit values, and the result has to be checked
against the one assumption that cannot be verified: what the open top
band contains.

## Parsing band labels

``` r

parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#>             label lower upper open_lower open_upper
#> 1               1     1     1      FALSE      FALSE
#> 2          2 to 5     2     5      FALSE      FALSE
#> 3         6 to 10     6    10      FALSE      FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE
parse_bands(c("18 to 24", "25 to 49", "50+"))
#>      label lower upper open_lower open_upper
#> 1 18 to 24    18    24      FALSE      FALSE
#> 2 25 to 49    25    49      FALSE      FALSE
#> 3      50+    50    NA      FALSE       TRUE
```

An unrecognised label is reported as unparsed, never guessed at:

``` r

parse_bands(c("3", "unknown", "not stated"))
#>        label lower upper open_lower open_upper
#> 1          3     3     3      FALSE      FALSE
#> 2    unknown    NA    NA      FALSE      FALSE
#> 3 not stated    NA    NA      FALSE      FALSE
```

## Representative values

Each band needs one value to stand for its members: the midpoint by
default, or the lower or upper edge, or the geometric mean for skewed
quantities. The open top band has no upper edge, so a cap or a factor on
its lower edge is supplied explicitly:

``` r

b <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
band_values(b, rule = "midpoint", open_upper_cap = 20)
#>             label lower upper open_lower open_upper value assumed
#> 1               1     1     1      FALSE      FALSE   1.0   FALSE
#> 2          2 to 5     2     5      FALSE      FALSE   3.5   FALSE
#> 3         6 to 10     6    10      FALSE      FALSE   8.0   FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE  15.5    TRUE
band_values(b, rule = "geometric", open_upper_cap = 20)
#>             label lower upper open_lower open_upper     value assumed
#> 1               1     1     1      FALSE      FALSE  1.000000   FALSE
#> 2          2 to 5     2     5      FALSE      FALSE  3.162278   FALSE
#> 3         6 to 10     6    10      FALSE      FALSE  7.745967   FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE 14.832397    TRUE
```

## Expanding to per-unit values

With counts per band,
[`expand_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expand_bands.md)
returns one value per unit, ready for any statistic:

``` r

x <- expand_bands(c("1", "2 to 5", "Greater than 5"), counts = c(10, 4, 2),
                  open_upper_cap = 12)
table(x)
#> x
#>   1 3.5   9 
#>  10   4   2
gini(x)
#> [1] 0.452381
```

## Concentration

The **Gini coefficient** measures how unequally a total is spread across
units: 0 when every unit holds the same, approaching 1 when one unit
holds everything.
[`top_share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
reports what the most frequent few account for, and
[`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
gives the curve behind the Gini.

``` r

gini(rep(1, 10))             # no concentration
#> [1] 0
gini(c(rep(0, 9), 1))        # one unit holds everything
#> [1] 0.9
1 - 1 / 10                   # the maximum for ten units
#> [1] 0.9

placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
gini(placements)
#> [1] 0.461225
top_share(placements, c(0.01, 0.05, 0.1))
#>   fraction units      share
#> 1     0.01    18 0.08716707
#> 2     0.05    89 0.28280872
#> 3     0.10   178 0.41888620
head(lorenz(placements))
#>     population        value
#> 1 0.0000000000 0.0000000000
#> 2 0.0005624297 0.0002421308
#> 3 0.0011248594 0.0004842615
#> 4 0.0016872891 0.0007263923
#> 5 0.0022497188 0.0009685230
#> 6 0.0028121485 0.0012106538
```

Here the top 1% of people account for a disproportionate share of
placements: the substantive finding a banded table hides.

## The assumption you cannot check: sensitivity to the open band

Everything above depends on what the “Greater than 10” band is taken to
contain. If the statistic barely moves as that assumption varies, it has
been measured; if it swings, it has not, and the honest report says so.
[`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
recomputes a statistic over a range of caps:

``` r

counts <- c(1200, 430, 110, 38)
band_sensitivity(b, counts)
#> ── Sensitivity to the open top band's assumed cap ──────────────── 
#>        cap     value
#>   11.55000 0.4254708
#>   15.09841 0.4346095
#>   19.73696 0.4461100
#>   25.80058 0.4604302
#>   33.72707 0.4780278
#>   44.08875 0.4993060
#>   57.63375 0.5245371
#>   75.34008 0.5537719
#>   98.48616 0.5867522
#>  128.74322 0.6228545
#>  168.29590 0.6610951
#>  220.00000 0.7002144
#> 
#>   span over the caps tried: 0.2747 (53.7% of the typical value)
#>   The statistic moves by more than a tenth of itself across the
#>   caps tried, so it is a property of the assumption as much as
#>   of the data. Report the range, not a single figure.
#> ──────────────────────────────────────────────────────────────────
band_sensitivity(b, counts, statistic = mean)
#> ── Sensitivity to the open top band's assumed cap ──────────────── 
#>        cap    value
#>   11.55000 2.257283
#>   15.09841 2.295202
#>   19.73696 2.344771
#>   25.80058 2.409567
#>   33.72707 2.494271
#>   44.08875 2.604998
#>   57.63375 2.749742
#>   75.34008 2.938955
#>   98.48616 3.186298
#>  128.74322 3.509629
#>  168.29590 3.932296
#>  220.00000 4.484814
#> 
#>   span over the caps tried: 2.228 (83.2% of the typical value)
#>   The statistic moves by more than a tenth of itself across the
#>   caps tried, so it is a property of the assumption as much as
#>   of the data. Report the range, not a single figure.
#> ──────────────────────────────────────────────────────────────────
```

## Heavy tails

When the open band holds a long tail, the question is how heavy. The
Hill estimator gives the tail index of a power law; for counts, the
exact discrete likelihood matters, because the continuous closed form is
badly biased at a threshold of one:

``` r

k <- 1:10000
p <- k^(-2.5) / sum(k^(-2.5))
set.seed(2)
z <- sample(k, 5000, replace = TRUE, prob = p)
c(exact = round(hill_tail_index(z, x_min = 1)$alpha, 2),
  approx = round(hill_tail_index(z, x_min = 1, approx = TRUE)$alpha, 2))
#>  exact approx 
#>   2.46   2.00
```

A short tail still returns an estimate, marked as not to be leaned on:

``` r

short <- hill_tail_index(c(3, 4, 5, 9), x_min = 3)
c(alpha = round(short$alpha, 2), n = short$n_tail, reliable = short$reliable)
#>    alpha        n reliable 
#>     2.59     4.00     0.00
```

## Workflow

1.  [`parse_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/parse_bands.md);
    stop if anything is unparsed.
2.  [`band_values()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_values.md)
    or
    [`expand_bands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expand_bands.md)
    with an explicit cap for the open band.
3.  The statistic:
    [`gini()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`top_share()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`lorenz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`hill_tail_index()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hill_tail_index.md).
4.  [`band_sensitivity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/band_sensitivity.md)
    over the cap, and report the range, not the point.
