# Statistics for a published administrative table

An open-data extract from a criminal-justice system has a particular
shape: a handful of fiscal years, counts rather than measurements,
categories reported as bands rather than values, and a region code with
no geometry attached. The general-purpose toolkits assume none of that.
This vignette covers the functions that do.

The running example is the shape Ontario’s inmate datasets have – one
row per placement, keyed on the fiscal year’s end year, with banded
counts and a region.

## Bands

Published categories are intervals. Anything computed from them rests on
an assumption about where inside each band the mass sits, and on a
second assumption about where the open top band ends.

``` r

bands <- parse_bands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
bands
#>             label lower upper open_lower open_upper
#> 1               1     1     1      FALSE      FALSE
#> 2          2 to 5     2     5      FALSE      FALSE
#> 3         6 to 10     6    10      FALSE      FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE
```

Note what the bounds say. `"Greater than 10"` starts at 11, because the
quantity is a count of placements; `"10 or more"` would start at 10. One
whole placement separates the two readings, and only the label says
which was meant.

The representative value needs a rule, and the open band needs a cap:

``` r

band_values(bands)
#>             label lower upper open_lower open_upper value assumed
#> 1               1     1     1      FALSE      FALSE   1.0   FALSE
#> 2          2 to 5     2     5      FALSE      FALSE   3.5   FALSE
#> 3         6 to 10     6    10      FALSE      FALSE   8.0   FALSE
#> 4 Greater than 10    11    NA      FALSE       TRUE  16.5    TRUE
```

The last row is marked `assumed`, because a band with no upper bound has
no midpoint. Everything downstream inherits that assumption, so measure
how much it matters:

``` r

counts <- c(1200, 430, 110, 38)
band_sensitivity(bands, counts)
#> Sensitivity to the open top band's assumed cap
#> 
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
#> span over the caps tried: 0.2747 (53.7% of the typical value)
#> The statistic moves by more than a tenth of itself across the
#> caps tried, so it is a property of the assumption as much as
#> of the data. Report the range, not a single figure.
```

Read the span, not the middle row. A statistic that moves by more than a
tenth of itself across plausible caps is a property of the assumption as
much as of the data, and the honest report is the range.

## Concentration

The recurring question is whether a few individuals account for most of
the total.

``` r

placements <- expand_bands(bands, counts, open_upper_cap = 25)
gini(placements)
#> [1] 0.4585838
top_share(placements, c(0.01, 0.05, 0.1))
#>   fraction units      share
#> 1     0.01    18 0.07589599
#> 2     0.05    89 0.25579761
#> 3     0.10   178 0.39095807
```

Gini has a ceiling that depends on the number of units: for `n` units
the maximum is `1 - 1/n`, not 1. A Gini of 0.9 means something different
across ten units than across ten thousand.

``` r

c(ten = 1 - 1 / 10, thousand = 1 - 1 / 1000)
#>      ten thousand 
#>    0.900    0.999
```

If the tail looks heavy, fit it rather than asserting it – and read the
goodness-of-fit distance before the exponent:

``` r

fit <- hill_tail_index(placements, x_min = 1)
c(alpha = round(fit$alpha, 2), ks = round(fit$ks, 3),
  reliable = fit$reliable)
#>    alpha       ks reliable 
#>    2.100    0.044    1.000
```

A large `ks` means the tail is not a power law, whatever `alpha` came
out as. The estimator maximises the exact discrete likelihood: the
closed-form continuity correction usually quoted is an asymptotic
approximation in the threshold, and at a threshold of one – where counts
start – it is badly biased.

## Trend across a handful of years

Five annual points support a rank test and a resistant slope. They do
not support a model with an autocorrelation structure.

``` r

y <- c(402, 377, 190, 268, 331)
tt <- trend_test(y)
c(tau = tt$tau, p = round(tt$p_value, 4), slope = tt$slope)
#>      tau        p    slope 
#>  -0.4000   0.4833 -21.3750
tt$method
#> [1] "Mann-Kendall, exact over all 120 orderings"
```

The p-value is exact, by enumerating all 120 orderings. For counts, the
trend is better expressed as a multiplicative change per year:

``` r

ct <- count_trend(y)
c(rate_ratio = round(ct$rate_ratio, 3),
  lower = round(ct$lower, 3), upper = round(ct$upper, 3),
  dispersion = round(ct$dispersion, 2))
#> rate_ratio      lower      upper dispersion 
#>      0.923      0.776      1.098     24.390
```

The dispersion is reported because a Poisson interval assumes it is one.
Above 1.5 the interval is widened to the quasi-Poisson one rather than
being left too narrow.

### Did it change when the policy changed?

``` r

sc <- step_change(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
c(after = sc$break_after, before = sc$before, after_mean = sc$after,
  p = round(sc$p_value, 4))
#>      after     before after_mean          p 
#> 2020.00000  100.66667   60.33333    0.10120
```

The p-value comes from the permutation distribution of the **maximum**
over splits, not from the best split’s own test. That distinction is the
difference between a change-point test and a way of finding a break in
noise. It also has a consequence worth stating plainly: six points
cannot produce a p-value below about 0.1, however clean the step,
because only 72 of the 720 orderings separate three low values from
three high ones.

``` r

(1 + 2 * factorial(3)^2) / (1 + factorial(6))
#> [1] 0.1012483
```

## Regions

A region code is an areal unit, not a coordinate. Three things go wrong
with a table of regional counts: the regions hold different numbers of
people, they hold different *kinds* of people, and a small region’s rate
is mostly noise.

``` r

d <- expand.grid(
  region = c("Central", "Eastern", "Northern", "Toronto", "Western"),
  age = c("18 to 24", "25 to 49", "50+"),
  stringsAsFactors = FALSE
)
d$pop <- rep(c(4000, 3000, 800, 5000, 2500), 3) *
  rep(c(0.3, 0.55, 0.15), each = 5)
set.seed(13)
rate <- c(Central = 0.006, Eastern = 0.011, Northern = 0.010,
          Toronto = 0.016, Western = 0.012)
d$n <- rpois(nrow(d), lambda = d$pop * rate[d$region])
```

Indirect standardisation handles the second problem: the expected count
is what each region would have under the overall rate in every age band,
given its own age composition.

``` r

e <- expected_counts(d$n, d$pop, d$region, strata = d$age)
e
#>       area observed population  expected
#> 1  Central       17       4000 48.366013
#> 2  Eastern       36       3000 36.274510
#> 3 Northern        9        800  9.673203
#> 4  Toronto       86       5000 60.457516
#> 5  Western       37       2500 30.228758
```

The expected counts total the observed ones. That identity is what makes
them a standardisation rather than a prediction.

``` r

c(observed = sum(e$observed), expected = sum(e$expected))
#> observed expected 
#>      185      185
```

The ratio, with an exact interval – the counts here are small, and a
normal approximation on a count of six is a decoration rather than an
interval:

``` r

sir(e$observed, e$expected, e$area)
#>       area observed  expected       sir     lower     upper excess
#> 1  Central       17 48.366013 0.3514865 0.2047538 0.5627639   TRUE
#> 2  Eastern       36 36.274510 0.9924324 0.6950875 1.3739448  FALSE
#> 3 Northern        9  9.673203 0.9304054 0.4254406 1.7661993  FALSE
#> 4  Toronto       86 60.457516 1.4224865 1.1378056 1.7567592   TRUE
#> 5  Western       37 30.228758 1.2240000 0.8618090 1.6871228  FALSE
```

And the third problem. A league table of rates ranks the small regions
to both ends by construction, so borrow strength across regions:

``` r

eb_rates(e$observed, e$expected, e$area)
#>       area observed  expected       sir        eb  shrinkage       nu    alpha
#> 1  Central       17 48.366013 0.3514865 0.4301763 0.12133873 6.679104 6.679104
#> 2  Eastern       36 36.274510 0.9924324 0.9936092 0.15549575 6.679104 6.679104
#> 3 Northern        9  9.673203 0.9304054 0.9588313 0.40845028 6.679104 6.679104
#> 4  Toronto       86 60.457516 1.4224865 1.3804553 0.09948526 6.679104 6.679104
#> 5  Western       37 30.228758 1.2240000 1.1834634 0.18096698 6.679104 6.679104
```

`shrinkage` is how far each estimate was pulled toward the overall rate.
It is governed by the expected count, which is to say by how much
information the region carries – not by how extreme its ratio was.

The funnel plot shows the reader the same thing directly: what range a
region’s ratio could take, given its size, if it were no different from
anywhere else.

``` r

funnel_limits(c(5, 20, 50, 200))
#>   expected level lower upper
#> 1        5 0.950 0.200 2.000
#> 2       20 0.950 0.600 1.450
#> 3       50 0.950 0.740 1.280
#> 4      200 0.950 0.865 1.140
#> 5        5 0.998 0.000 2.600
#> 6       20 0.998 0.400 1.750
#> 7       50 0.998 0.600 1.460
#> 8      200 0.998 0.790 1.225
```

### Autocorrelation, if you have a neighbour list

``` r

nb <- list(c(2L, 4L), c(1L, 3L), c(2L, 5L), c(1L, 5L), c(3L, 4L))
set.seed(1)
mi <- morans_i(e$observed / e$expected, nb, n_perm = 999L)
c(I = round(mi$I, 3), expectation = round(mi$expectation, 3),
  p = mi$p_value)
#>           I expectation           p 
#>      -0.292      -0.250       0.842
```

The neighbour list has to be supplied. An extract keyed on a region
ships no geometry, and a guessed adjacency would make the answer a
property of the guess. Note too that the null expectation is
`-1/(n - 1)`, not zero: with five regions, a small negative `I` is what
independence looks like.

``` r

-1 / (5 - 1)
#> [1] -0.25
```
