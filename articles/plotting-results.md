# Plotting results

Every result the package returns draws itself. `plot(x)` needs nothing
but the object; the chart is the one that result calls for, drawn with
base graphics (no new dependency), with one shared look across the
package. Every method takes the same customisation, and every method
returns the numbers it drew, so a figure can be checked or redrawn
another way.

## One call per result

Stock and flow after Lakner (1976): the average daily population and the
length of stay, one panel per measure.

``` r

sf <- stkflow(days = c(13500, 14600, 15100, 14200), people = c(300, 320, 310, 290),
                 prd = 2020:2023)
plot(sf)
```

![](plotting-results_files/figure-html/plotting-results-stock-flow-1.png)

Period-over-period change with its interval, coloured by verdict:

``` r

y <- yoy(data.frame(year = 2018:2023, n = c(40, 44, 41, 55, 52, 61)), value = "n",
         prd = "year")
plot(y)
```

![](plotting-results_files/figure-html/plotting-results-yoy-1.png)

Small counts get their percentages too: each comes with its exact
interval, as wide as the base is small. Only a zero base has no
percentage, and its row says so.

``` r

plot(yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n", prd = "year"))
```

![](plotting-results_files/figure-html/plotting-results-yoy-small-1.png)

Rates with their intervals, and the change in a rate:

``` r

d <- data.frame(division = rep(c("north", "east", "west"), 2), year = rep(2022:2023, each = 3),
                stops = c(120, 90, 60, 150, 85, 70), residents = c(1e4, 8e3, 5e3, 1e4, 8e3, 5e3))
plot(rtcalc(d[d$year == 2023, ], count = "stops", pop = "residents", by = "division"))
```

![](plotting-results_files/figure-html/plotting-results-rates-1.png)

``` r

plot(ratechg(d, count = "stops", pop = "residents", prd = "year", by = "division"))
```

![](plotting-results_files/figure-html/plotting-results-rates-2.png)

First digits against Benford’s law, the power curve of a check, and a
permutation null:

``` r

set.seed(1)
amounts <- round(exp(rnorm(400, 6, 1.4)))
plot(benfordtst(amounts))
```

![](plotting-results_files/figure-html/plotting-results-checks-1.png)

``` r

dd <- data.frame(x = rnorm(120), y = rnorm(120))
shift <- function(z, s) {
  z$y <- z$y + s * z$x
  z
}
plot(cpspwr(dd, function(z) cor(z$x, z$y), inject = shift, trt = "x",
                   sizes = c(0, 0.2, 0.4, 0.6), n = 49, reps = 6, seed = 1))
```

![](plotting-results_files/figure-html/plotting-results-checks-2.png)

## Air pollution

The concentration-response curve with the exposure marked, the burden it
implies, and the whole
[`vrfpol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
report on one page (curve, burden and the concentration curve of
exposure over income):

``` r

plot(crfno2(25))
```

![](plotting-results_files/figure-html/plotting-results-pollution-1.png)

``` r

plot(polbrdn(25, 1, 0.008, 1e6, poll = "NO2"))
```

![](plotting-results_files/figure-html/plotting-results-pollution-2.png)

``` r

plot(vrfpol("no2", demo = TRUE))
```

![](plotting-results_files/figure-html/plotting-results-report-1.png)

A plume on a grid, and the particle cloud of the random walk:

``` r

plot(plmfld(q = 100, u = 5, h = 50, x = seq(100, 3000, by = 100),
                 y = seq(-500, 500, by = 50)))
```

![](plotting-results_files/figure-html/plotting-results-dispersion-1.png)

``` r

plot(lagrprt(500, 0, 0, u = 2, v = 0.5, kx = 1, ky = 1, dt = 1, nsteps = 60,
                          grid = c(0, 200, -60, 100, 40, 32)))
```

![](plotting-results_files/figure-html/plotting-results-dispersion-2.png)

The footprint of a computation: CPU, memory and the total in one unit
chosen to fit, with its everyday equivalents under the bars:

``` r

plot(co2fp(for (i in 1:20) sum(sqrt(seq_len(2e5))), loc = "CA",
                       cpupwrw = 45, memgb = 8))
```

![](plotting-results_files/figure-html/plotting-results-footprint-1.png)

## Courts and crime

The Ontario Court of Justice and Toronto Police Service data shipped
with the package (see
[`vignette("courts-and-crime")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/courts-and-crime.md)
for the analysis behind each one):

``` r

ext <- function(f) read.csv(system.file("extdata", f, package = "rmoriebricklayer"))
f <- ext("ocj_flow_ontario.csv")
d <- ext("ocj_time_to_disposition.csv")
x <- ext("ocj_dispositions.csv")
g <- ext("ocj_offence_groups.csv")
g <- g[g$year %in% c(2014, 2022), ]
b <- ext("tps_break_enter_d14_2024.csv")
b <- b[!is.na(b$lon), ]
```

Cases received and disposed, and the clearance rate:

``` r

plot(caseflow(f$received, f$disposed, pend = f$pending, prd = f$month))
```

![](plotting-results_files/figure-html/plotting-results-case-flow-1.png)

How long cases stay open, from the published time-to-disposition bands:

``` r

last <- nrow(d)
plot(lifetbl(c(0, 10, 15, 18, Inf), unlist(d[last, 2:5]) * f$disposed[last]))
```

![](plotting-results_files/figure-html/plotting-results-life-table-1.png)

The mix of outcomes over the years:

``` r

plot(dispmix(x[, -(1:2)], prd = x$year))
```

![](plotting-results_files/figure-html/plotting-results-disposition-mix-1.png)

A Simpson’s-paradox check: the parts’ rates, where the work moved, and
the change split into rate and mix effects:

``` r

plot(clrdcmp(g$disposed, g$received, g$offence_group, g$year))
```

![](plotting-results_files/figure-html/plotting-results-simpson-1.png)

Where break-and-enters cluster, and whether they repeat near each other
soon after:

``` r

plot(crmdens(b$lon, b$lat, ngrid = 120))
```

![](plotting-results_files/figure-html/plotting-results-density-1.png)

``` r

plot(knoxtst(b$lon, b$lat, as.Date(b$occ_date), c(100, 200, 400), c(7, 14, 28),
               nsim = 99, seed = 1))
```

![](plotting-results_files/figure-html/plotting-results-density-2.png)

## First Nations, Metis and Inuit health

Published Statistics Canada estimates bundled with the package
([`?indiex`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md);
see
[`vignette("first-nations-metis-inuit-health")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/first-nations-metis-inuit-health.md)
for the methods and the governance behind them). Each group is drawn on
its own: the plots never pool First Nations, Metis and Inuit.

``` r

h <- indiex("health")
adults <- h[h$age == "Total, 18 years and over", ]
mh <- adults[adults$period == "2019/2022" & adults$indicator == "Perceived mental health, very good or excellent", ]
```

Each group against non-Indigenous adults, with intervals from the
published ones:

``` r

plot(indgap(mh, "group", "estimate", "lower", "upper", qual = "quality"))
```

![](plotting-results_files/figure-html/plotting-results-indigenous-gap-1.png)

Perceived mental health on its whole scale (2022 Indigenous Peoples
Survey):

``` r

r <- indiex("mentalhealth")
r <- r[r$region == "Canada", ]
plot(ordcmp(r, "group", "rating", "estimate", "lower", "upper",
                     lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
                     ref = "M\u00e9tis", qual = "quality"))
```

![](plotting-results_files/figure-html/plotting-results-indigenous-ordinal-1.png)

Wellness beside distress, and the two as separate axes (2024 well-being
table):

``` r

wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = c("Always or often has a hopeful outlook",
                                   "Sense of meaning and purpose rating of 8, 9 or 10"),
                      distress = c("Rarely or never has a hopeful outlook",
                                   "Life satisfaction rating between 0 and 5"),
                      qual = "quality")
plot(w)
```

![](plotting-results_files/figure-html/plotting-results-indigenous-wellness-1.png)

``` r

plot(dualcont(w, "Always or often has a hopeful outlook", "Life satisfaction rating between 0 and 5"))
```

![](plotting-results_files/figure-html/plotting-results-indigenous-wellness-2.png)

Change between the two survey periods, wellness first:

``` r

hc <- healchg(adults[adults$indicator %in% c("Perceived mental health, very good or excellent",
                                                    "Mood disorder"), ],
                     "group", "indicator", "period", "estimate", "lower", "upper",
                     from = "2015/2018", to = "2019/2022", qual = "quality",
                     well = "Perceived mental health, very good or excellent")
plot(hc)
```

![](plotting-results_files/figure-html/plotting-results-indigenous-change-1.png)

The Truth and Reconciliation Commission’s Calls to Action, completed and
projected:

``` r

plot(trcprog())
```

![](plotting-results_files/figure-html/plotting-results-indigenous-trc-1.png)

## Evaluating a policy

The designs of
[`vignette("policy-evaluation")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/policy-evaluation.md),
on its made-up panel of twenty districts where a reform arrives in three
stages: the outcome by adoption cohort before any model, the event
study, the Goodman-Bacon weights behind a two-way fixed-effects
estimate, and the randomisation null of the assignment.

``` r

p <- polex()
```

``` r

plot(cohtrnd(p, "district", "month", "crmrate", "refmonth", win = c(-10, 10)))
```

![](plotting-results_files/figure-html/plotting-results-policy-design-1.png)

``` r

es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 4, lags = 6)
plot(es)
```

![](plotting-results_files/figure-html/plotting-results-policy-design-2.png)

``` r

plot(bacondcmp(p, "district", "month", "crmrate", "reformed"))
```

![](plotting-results_files/figure-html/plotting-results-policy-design-3.png)

``` r

plot(perminf(p, "district", "month", "crmrate", "refmonth", cl = "region"))
```

![](plotting-results_files/figure-html/plotting-results-policy-design-4.png)

Whether one district drives the estimate, and a single treated place
against its synthetic control and its synthetic difference in
differences:

``` r

plot(loounit(p, "district", "month", "crmrate", "reformed"))
```

![](plotting-results_files/figure-html/plotting-results-policy-one-1.png)

``` r

p13 <- p[is.na(p$refmonth) | p$district == "D13", ]
plot(synctl(p13, "district", "month", "crmrate", "D13", adopt = 13))
```

![](plotting-results_files/figure-html/plotting-results-policy-one-2.png)

``` r

plot(syndid(p13, "district", "month", "crmrate", "refmonth", reps = 50, seed = 1))
```

![](plotting-results_files/figure-html/plotting-results-policy-one-3.png)

The power of the design on the untreated data, and the cross-fitted AIPW
estimate of
[`vignette("causal-effects")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/causal-effects.md)
with its overlap and balance checks:

``` r

plot(plnpwr(p[p$month <= 12, ], "district", "month", "crmrate", ntrt = 10, adopt = 7:10,
            eff = c(0, 0.5, 1, 1.5), reps = 40, seed = 1))
```

![](plotting-results_files/figure-html/plotting-results-policy-checks-1.png)

``` r

set.seed(7)
n <- 600
d <- data.frame(age = runif(n, 18, 70), income = rnorm(n))
d$t <- rbinom(n, 1, plogis(-2 + 0.04 * d$age + 0.5 * d$income))
d$y <- 10 + 3 * d$t + 0.2 * d$age + d$income + rnorm(n)
fit <- aipwcf(d, "y", "t", c("age", "income"), lrn = "ols")
plot(fit)
```

![](plotting-results_files/figure-html/plotting-results-policy-checks-2.png)

``` r

plot(fit, type = "estimate")
```

![](plotting-results_files/figure-html/plotting-results-policy-checks-3.png)

``` r

e <- pmin(pmax(attr(fit, "propensity")$propensity, 0.01), 0.99)
d$ipw <- ifelse(d$t == 1, 1 / e, 1 / (1 - e))
plot(baltab(d, "t", c("age", "income")), after = baltab(d, "t", c("age", "income"), w = "ipw"))
```

![](plotting-results_files/figure-html/plotting-results-policy-checks-4.png)

## Customising

Every method takes `main`, `col` (or a `palette` name), `grid`, and
`...` for the base-graphics call.
[`plotopt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
sets the session defaults;
[`blpal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
gives the colour-blind-safe sets the package uses.

``` r

plot(sf, what = "alos", col = "firebrick", main = "Length of stay (days)", lwd = 3)
```

![](plotting-results_files/figure-html/plotting-results-custom-1.png)

``` r

old <- plotopt(palette = "grey", grid = FALSE)
plot(y, what = "value")
```

![](plotting-results_files/figure-html/plotting-results-custom-2.png)

``` r

plotopt(palette = old$palette, grid = old$grid)
blpal("okabe", 4)
#> [1] "#0072B2" "#D55E00" "#009E73" "#E69F00"
```

Every method returns the data it drew, invisibly:

``` r

drawn <- plot(y)
```

![](plotting-results_files/figure-html/plotting-results-returned-1.png)

``` r

head(drawn, 3)
#>   label    pctchg     lower    upper verdict   at
#> 1  2018        NA        NA       NA    <NA> 2018
#> 2  2019 10.000000 -29.95683 73.20735      up 2019
#> 3  2020 -6.818182 -40.61975 45.94265    down 2020
```

Results that are plain data frames have a plot function of their own:
the Lorenz curve of a vector, and the funnel plot of observed against
expected counts per area.

``` r

plotlrnz(c(1, 1, 2, 3, 5, 8, 13, 21))
```

![](plotting-results_files/figure-html/plotting-results-helpers-1.png)

``` r

plotfnl(obs = c(4, 20, 50, 9, 31), expd = c(5, 22, 40, 20, 30),
            area = c("a", "b", "c", "d", "e"))
```

![](plotting-results_files/figure-html/plotting-results-helpers-2.png)
