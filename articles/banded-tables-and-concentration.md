# Banded tables and concentration: from '6 to 10' to a Gini

Published frequency tables band their values: “1”, “2 to 5”, “6 to 10”,
“Greater than 10”. To compute anything about the underlying
distribution, the bands have to be parsed, given representative values,
and expanded into per-unit values, and the result has to be checked
against the one assumption that cannot be verified: what the open top
band contains.

## Parsing band labels

``` r

prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
#>             label lower upper openlo openup
#> 1               1     1     1  FALSE  FALSE
#> 2          2 to 5     2     5  FALSE  FALSE
#> 3         6 to 10     6    10  FALSE  FALSE
#> 4 Greater than 10    11    NA  FALSE   TRUE
prsbands(c("18 to 24", "25 to 49", "50+"))
#>      label lower upper openlo openup
#> 1 18 to 24    18    24  FALSE  FALSE
#> 2 25 to 49    25    49  FALSE  FALSE
#> 3      50+    50    NA  FALSE   TRUE
```

An unrecognised label is reported as unparsed, never guessed at:

``` r

prsbands(c("3", "unknown", "not stated"))
#>        label lower upper openlo openup
#> 1          3     3     3  FALSE  FALSE
#> 2    unknown    NA    NA  FALSE  FALSE
#> 3 not stated    NA    NA  FALSE  FALSE
```

## Representative values

Each band needs one value to stand for its members: the midpoint by
default, or the lower or upper edge, or the geometric mean for skewed
quantities. The open top band has no upper edge, so a cap or a factor on
its lower edge is supplied explicitly:

``` r

b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
bandvals(b, rule = "midpoint", openupcap = 20)
#>             label lower upper openlo openup value assumed
#> 1               1     1     1  FALSE  FALSE   1.0   FALSE
#> 2          2 to 5     2     5  FALSE  FALSE   3.5   FALSE
#> 3         6 to 10     6    10  FALSE  FALSE   8.0   FALSE
#> 4 Greater than 10    11    NA  FALSE   TRUE  15.5    TRUE
bandvals(b, rule = "geometric", openupcap = 20)
#>             label lower upper openlo openup     value assumed
#> 1               1     1     1  FALSE  FALSE  1.000000   FALSE
#> 2          2 to 5     2     5  FALSE  FALSE  3.162278   FALSE
#> 3         6 to 10     6    10  FALSE  FALSE  7.745967   FALSE
#> 4 Greater than 10    11    NA  FALSE   TRUE 14.832397    TRUE
```

## Expanding to per-unit values

With counts per band,
[`expbands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expbands.md)
returns one value per unit, ready for any statistic:

``` r

x <- expbands(c("1", "2 to 5", "Greater than 5"), cnts = c(10, 4, 2),
                  openupcap = 12)
table(x)
#> x
#>   1 3.5   9 
#>  10   4   2
ginicoef(x)
#> [1] 0.452381
```

## Concentration

The **Gini coefficient** measures how unequally a total is spread across
units: 0 when every unit holds the same, approaching 1 when one unit
holds everything.
[`topshr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
reports what the most frequent few account for, and
[`lorenzc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md)
gives the curve behind the Gini.

``` r

ginicoef(rep(1, 10))             # no concentration
#> [1] 0
ginicoef(c(rep(0, 9), 1))        # one unit holds everything
#> [1] 0.9
1 - 1 / 10                   # the maximum for ten units
#> [1] 0.9

placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
ginicoef(placements)
#> [1] 0.461225
topshr(placements, c(0.01, 0.05, 0.1))
#>   fraction units      share
#> 1     0.01    18 0.08716707
#> 2     0.05    89 0.28280872
#> 3     0.10   178 0.41888620
head(lorenzc(placements))
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
[`bandsens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
recomputes a statistic over a range of caps:

``` r

counts <- c(1200, 430, 110, 38)
bandsens(b, counts)
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
bandsens(b, counts, stat = mean)
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
c(exact = round(hilltlidx(z, xmin = 1)$alpha, 2),
  approx = round(hilltlidx(z, xmin = 1, approx = TRUE)$alpha, 2))
#>  exact approx 
#>   2.46   2.00
```

A short tail still returns an estimate, marked as not to be leaned on:

``` r

short <- hilltlidx(c(3, 4, 5, 9), xmin = 3)
c(alpha = round(short$alpha, 2), n = short$ntl, reliable = short$reliable)
#>    alpha        n reliable 
#>     2.59     4.00     0.00
```

## Workflow

1.  [`prsbands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prsbands.md);
    stop if anything is unparsed.
2.  [`bandvals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandvals.md)
    or
    [`expbands()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expbands.md)
    with an explicit cap for the open band.
3.  The statistic:
    [`ginicoef()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`topshr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`lorenzc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/concentration.md),
    [`hilltlidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hilltlidx.md).
4.  [`bandsens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md)
    over the cap, and report the range, not the point.

## How unevenly a population is spread

Concentration measures apply to any non-negative counts. With the 2021
Census counts of First Nations people by province and territory (bundled
with the package), the Gini coefficient and top shares say how
concentrated the population is in a few jurisdictions:

``` r

cp <- indiex("censuspop")
tot <- cp[cp$GEO_LEVEL != "Country" & cp$AGE_GROUP == "Total - Age groups" &
            cp$RESIDENCE == "Total - Residence on or off reserve" &
            grepl("^Total - Average age", cp$CHARACTERISTIC_NAME), ]
ginicoef(tot$FIRST_NATIONS)
#> [1] 0.5291808
topshr(tot$FIRST_NATIONS, fracs = c(0.25, 0.5))
#>   fraction units     share
#> 1     0.25     4 0.6787850
#> 2     0.50     7 0.9326599
```
