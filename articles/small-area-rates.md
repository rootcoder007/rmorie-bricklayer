# Small-area rates: expected counts, shrinkage, funnels and spatial autocorrelation

Published tables often give a count per region, division or facility.
Comparing those counts fairly needs three steps: adjust for the
population each unit serves (and its composition), stabilise the ratios
of small units, and judge each unit against limits that widen as its
expected count shrinks. This vignette walks the four tools that do that.

## Expected counts by indirect standardisation

If the overall rate applied everywhere, how many events would each unit
have? That is the *expected count*. Adjusting for size alone:

``` r

d <- data.frame(
  region = rep(c("North", "South", "East"), each = 2),
  age = rep(c("18 to 24", "25 to 49"), 3),
  n = c(30, 45, 12, 60, 8, 20),
  pop = c(1000, 6000, 900, 9000, 400, 3500),
  stringsAsFactors = FALSE
)
expcnts(d$n, d$pop, d$region)
#> ╭── Expected counts, indirect standardisation ────────────────────────────╮
#> │   Areas       3                                                         │
#> │   Observed    175                                                       │
#> │   Expected    175                                                       │
#> │   Population  20,800                                                    │
#> │                                                                         │
#> │   area   observed  population  expected                                 │
#> │   -----  --------  ----------  --------                                 │
#> │   East         28       3,900     32.81                                 │
#> │   North        75       7,000     58.89                                 │
#> │   South        72       9,900     83.29                                 │
#> │                                                                         │
#> │   expected is the count an area would have at the overall rate of each  │
#> │   stratum, given its own population in it. stdinc() puts an interval on │
#> │   the ratio of observed to expected.                                    │
#> │                                                                         │
#> │   The expected counts sum to the observed ones: the reference rates     │
#> │   come from the same data.                                              │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

Adjusting for size **and** age composition is indirect standardisation:
each stratum’s overall rate is applied to the unit’s population in that
stratum, then summed. This is the comparison that says something about
the unit rather than about who lives there:

``` r

expcnts(d$n, d$pop, d$region, strata = d$age)
#> ╭── Expected counts, indirect standardisation ────────────────────────────╮
#> │   Areas       3                                                         │
#> │   Observed    175                                                       │
#> │   Expected    175                                                       │
#> │   Population  20,800                                                    │
#> │                                                                         │
#> │   area   observed  population  expected                                 │
#> │   -----  --------  ----------  --------                                 │
#> │   East         28       3,900     32.34                                 │
#> │   North        75       7,000     62.28                                 │
#> │   South        72       9,900     80.38                                 │
#> │                                                                         │
#> │   expected is the count an area would have at the overall rate of each  │
#> │   stratum, given its own population in it. stdinc() puts an interval on │
#> │   the ratio of observed to expected.                                    │
#> │                                                                         │
#> │   The expected counts sum to the observed ones: the reference rates     │
#> │   come from the same data.                                              │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

## Direct standardisation, for populations of different ages

Indirect standardisation asks what each unit would expect at the overall
rates. Direct standardisation asks what rate each population would have
with one standard age structure. It is the comparison to use when the
populations’ ages differ a great deal. First Nations, Métis and Inuit
populations, for example, are younger than the non-Indigenous
population.
[`agestd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md)
gives the rates with the Fay-Feuer gamma interval, which holds for small
counts.
[`rategap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rategap.md)
compares two of them. The counts below are made up, to show the
computation:

``` r

r <- agestd(
  events = c(4, 9, 11, 6, 3, 40, 70, 90, 80, 60),
  pop = c(9000, 8000, 6000, 4000, 2000, 300000, 320000, 350000, 340000, 300000),
  std = c(30, 25, 20, 15, 10),
  grp = rep(c("Inuit", "Non-Indigenous"), each = 5)
)
r
#> ╭── Directly age-standardised rate ──────────────────────────────────────╮
#> │   Groups    2                                                          │
#> │   Events    373                                                        │
#> │   Rate per  100,000                                                    │
#> │   Interval  gamma (Fay and Feuer 1997)                                 │
#> │                                                                        │
#> │   group           events    rate  95% CI                               │
#> │   --------------  ------  ------  ---------------                      │
#> │   Inuit               33  115.63  [79.24, 165.02]                      │
#> │   Non-Indigenous     340   20.14  [17.93, 22.58]                       │
#> │                                                                        │
#> │   Highest rate: Inuit (115.6); lowest: Non-Indigenous (20.14).         │
#> │   Their intervals do not overlap: the gap is more than sampling error. │
#> │                                                                        │
#> │   Each rate is what the group's age-specific rates give for the        │
#> │   standard population's ages, so the groups compare without them.      │
#> │   Compare only rates standardised to the same population.              │
#> ╰────────────────────────────────────────────────────────────────────────╯
rategap(r, "Inuit", "Non-Indigenous")
#> ╭── Gap between two standardised rates ──────────────────────────────────╮
#> │   Group      Inuit                                                     │
#> │   Reference  Non-Indigenous                                            │
#> │                                                                        │
#> │   group  reference       ratio  ratio CI        difference             │
#> │   -----  --------------  -----  --------------  ----------             │
#> │   Inuit  Non-Indigenous  5.741  [3.994, 8.252]       95.48             │
#> │                                                                        │
#> │   group  difference CI                                                 │
#> │   -----  ---------------                                               │
#> │   Inuit  [55.54, 135.40]                                               │
#> │                                                                        │
#> │   The rate ratio is 5.741 (its interval [3.994, 8.252]): the interval  │
#> │   excludes 1, so the data distinguish it from no effect. A ratio of    │
#> │   5.741 is a 474% rise. The difference, per the rates' unit, is 95.48  │
#> │   (its interval [55.54, 135.40]): the interval excludes 0, so the data │
#> │   distinguish it from no effect.                                       │
#> │                                                                        │
#> │   The intervals are at the level agestd() was given.                   │
#> ╰────────────────────────────────────────────────────────────────────────╯
```

For survey percentages rather than counts,
[`stdprev()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md)
does the same.

## Standardised ratios with exact intervals

The ratio of observed to expected is the standardised incidence ratio
(SIR).
[`stdinc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md)
gives the exact Poisson interval, which is what makes a small count
honest:

``` r

stdinc(obs = c(30, 12, 3), expd = c(20, 14, 5),
    area = c("North", "South", "East"))
#> ╭── Standardised incidence ratios ──────────────────────────────────────╮
#> │   Areas          3                                                    │
#> │   Observed       45                                                   │
#> │   Expected       39                                                   │
#> │   Overall ratio  1.154                                                │
#> │   Interval       exact Poisson, at the level asked for (default 95%)  │
#> │   Above one      1                                                    │
#> │   Below one      0                                                    │
#> │                                                                       │
#> │   area   observed  expected     sir  interval        finding          │
#> │   -----  --------  --------  ------  --------------  -------          │
#> │   North        30        20  1.5000  [1.012, 2.141]  excess           │
#> │   South        12        14  0.8571  [0.443, 1.497]                   │
#> │   East          3         5  0.6000  [0.124, 1.753]                   │
#> │                                                                       │
#> │   A ratio above 1 means more cases than the area's population would   │
#> │   give at the overall rates. An excess or a deficit is an interval    │
#> │   wholly above or below 1 (the significant column is either).         │
#> │                                                                       │
#> │   Each interval is a separate test: with many areas some exclude 1 by │
#> │   chance (scanadj() allows for that).                                 │
#> ╰───────────────────────────────────────────────────────────────────────╯
```

An observed count of three carries almost no information, and the
interval says so rather than hiding it:

``` r

stdinc(3, 5)
#> ╭── Standardised incidence ratios ──────────────────────────────────────╮
#> │   Areas          1                                                    │
#> │   Observed       3                                                    │
#> │   Expected       5                                                    │
#> │   Overall ratio  0.6                                                  │
#> │   Interval       exact Poisson, at the level asked for (default 95%)  │
#> │   Above one      0                                                    │
#> │   Below one      0                                                    │
#> │                                                                       │
#> │   observed  expected     sir  interval          finding               │
#> │   --------  --------  ------  ----------------  -------               │
#> │          3         5  0.6000  [0.1237, 1.7530]                        │
#> │                                                                       │
#> │   A ratio above 1 means more cases than the area's population would   │
#> │   give at the overall rates. An excess or a deficit is an interval    │
#> │   wholly above or below 1 (the significant column is either).         │
#> │                                                                       │
#> │   Each interval is a separate test: with many areas some exclude 1 by │
#> │   chance (scanadj() allows for that).                                 │
#> ╰───────────────────────────────────────────────────────────────────────╯
```

## Empirical Bayes shrinkage

A tiny unit’s raw ratio is extreme by chance. Empirical Bayes shrinks
each ratio toward the overall experience in proportion to how little its
own data say: the pooled ratios share a Gamma prior whose parameters are
estimated from all units, and each unit’s posterior mean is a weighted
average of its own ratio and the prior mean, weighted by its expected
count (Clayton and Kaldor 1987).

``` r

ebrates(obs = c(30, 45, 2), expd = c(25, 50, 0.5),
         area = c("North", "South", "Tiny"))
#> ╭── Empirical Bayes rates ────────────────────────────────────────────────╮
#> │   Areas               3                                                 │
#> │   Overall ratio       1.02                                              │
#> │   Prior shape (nu)    26.98                                             │
#> │   Prior rate (alpha)  26.46                                             │
#> │   Method              gamma-Poisson, moments (Clayton and Kaldor 1987)  │
#> │                                                                         │
#> │   area   observed  expected    sir     eb  shrinkage                    │
#> │   -----  --------  --------  -----  -----  ---------                    │
#> │   North        30     25.00  1.200  1.107     0.5141                    │
#> │   South        45     50.00  0.900  0.941     0.3460                    │
#> │   Tiny          2      0.50  4.000  1.075     0.9815                    │
#> │                                                                         │
#> │   Each raw ratio (sir) is pulled toward the overall ratio; shrinkage is │
#> │   the share of the pull (0 untouched, 1 replaced), largest for areas    │
#> │   with small expected counts. Use eb for maps and rankings, stdinc()    │
#> │   for each area's own evidence.                                         │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

The tiny area’s raw ratio of 4 is pulled sharply toward 1; the large
areas barely move.

## Funnel plots

A funnel plot draws control limits that narrow as the expected count
grows (Spiegelhalter 2005): a ratio of 2 means nothing at an expected
count of 2 and a great deal at 200. Units outside the limits are the
ones worth a second look; the rest are consistent with the common rate.

``` r

fnllim(c(2, 20, 200))
#>   expected level lower upper
#> 1        2 0.950 0.000 2.500
#> 2       20 0.950 0.600 1.450
#> 3      200 0.950 0.865 1.140
#> 4        2 0.998 0.000 4.000
#> 5       20 0.998 0.400 1.750
#> 6      200 0.998 0.790 1.225
```

``` r

e <- seq(2, 200, length.out = 60)
lim <- fnllim(e)
plot(e, lim$upper_95, type = "l", ylim = c(0, 3), xlab = "expected count",
     ylab = "observed / expected", main = "Funnel limits")
lines(e, lim$lower_95)
lines(e, lim$upper_998, lty = 2)
lines(e, lim$lower_998, lty = 2)
abline(h = 1, col = "grey")
points(c(20, 14, 5), c(30, 12, 3) / c(20, 14, 5), pch = 19, col = 2)
```

![](small-area-rates_files/figure-html/small-area-rates-funnel-plot-1.png)

The `levels` argument sets which limits are drawn; 95% and 99.8% (about
two and three standard deviations) are the conventional pair.

## Spatial autocorrelation

Rates of neighbouring areas are rarely independent. Moran’s *I* measures
whether similar values cluster in space, against a permutation null;
`neighbours` is a list giving each area’s adjacent areas:

``` r

# six areas in a line
nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)

set.seed(1)
morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 999L)[c("I", "p_value")] # a gradient
#> $I
#> [1] 0.7142857
#> 
#> $p_value
#> [1] 0.011

set.seed(1)
morani(c(1, 6, 1, 6, 1, 6), nb, nperm = 999L)[c("I", "p_value")] # alternating
#> $I
#> [1] -1
#> 
#> $p_value
#> [1] 0.199
```

The null expectation of *I* is not zero but $`-1/(n-1)`$:

``` r

-1 / (6 - 1)
#> [1] -0.2
```

Positive autocorrelation in the residual ratios means neighbouring units
share something the standardisation did not capture, and a funnel that
treats them as independent is optimistic.

## From a published table to a judgement

1.  [`expcnts()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md)
    with the strata the table publishes.
2.  [`stdinc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md)
    for the ratios and their exact intervals.
3.  [`ebrates()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md)
    where small units dominate.
4.  [`fnllim()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)
    to see which units are outside the common experience.
5.  [`morani()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/morani.md)
    on the residuals before trusting independence.

## References

Clayton, Kaldor (1987). Empirical Bayes estimates of age-standardized
relative risks for use in disease mapping. *Biometrics* 43(3).
Spiegelhalter (2005). Funnel plots for comparing institutional
performance. *Statistics in Medicine* 24(8). Moran (1950). Notes on
continuous stochastic phenomena. *Biometrika* 37(1/2).
