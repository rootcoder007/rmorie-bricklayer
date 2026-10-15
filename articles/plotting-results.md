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

sf <- stock_flow(days = c(13500, 14600, 15100, 14200), people = c(300, 320, 310, 290),
                 period = 2020:2023)
plot(sf)
```

![](plotting-results_files/figure-html/stock-flow-1.png)

Period-over-period change with its interval, coloured by verdict:

``` r

y <- yoy(data.frame(year = 2018:2023, n = c(40, 44, 41, 55, 52, 61)), value = "n",
         period = "year")
plot(y)
```

![](plotting-results_files/figure-html/yoy-1.png)

Small counts get their percentages too: each comes with its exact
interval, as wide as the base is small. Only a zero base has no
percentage, and its row says so.

``` r

plot(yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n", period = "year"))
```

![](plotting-results_files/figure-html/yoy-small-1.png)

Rates with their intervals, and the change in a rate:

``` r

d <- data.frame(division = rep(c("north", "east", "west"), 2), year = rep(2022:2023, each = 3),
                stops = c(120, 90, 60, 150, 85, 70), residents = c(1e4, 8e3, 5e3, 1e4, 8e3, 5e3))
plot(rate(d[d$year == 2023, ], count = "stops", population = "residents", by = "division"))
```

![](plotting-results_files/figure-html/rates-1.png)

``` r

plot(rate_change(d, count = "stops", population = "residents", period = "year", by = "division"))
```

![](plotting-results_files/figure-html/rates-2.png)

First digits against Benford’s law, the power curve of a check, and a
permutation null:

``` r

set.seed(1)
amounts <- round(exp(rnorm(400, 6, 1.4)))
plot(benford_test(amounts))
```

![](plotting-results_files/figure-html/checks-1.png)

``` r

dd <- data.frame(x = rnorm(120), y = rnorm(120))
shift <- function(z, s) {
  z$y <- z$y + s * z$x
  z
}
plot(capsule_power(dd, function(z) cor(z$x, z$y), inject = shift, treatment = "x",
                   sizes = c(0, 0.2, 0.4, 0.6), n = 49, reps = 6, seed = 1))
```

![](plotting-results_files/figure-html/checks-2.png)

## Air pollution

The concentration-response curve with the exposure marked, the burden it
implies, and the whole
[`verify_pollution()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_pollution.md)
report on one page (curve, burden and the concentration curve of
exposure over income):

``` r

plot(crf_no2(25))
```

![](plotting-results_files/figure-html/pollution-1.png)

``` r

plot(pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2"))
```

![](plotting-results_files/figure-html/pollution-2.png)

``` r

plot(verify_pollution("no2", demo = TRUE))
```

![](plotting-results_files/figure-html/report-1.png)

A plume on a grid, and the particle cloud of the random walk:

``` r

plot(plume_field(q = 100, u = 5, h = 50, x = seq(100, 3000, by = 100),
                 y = seq(-500, 500, by = 50)))
```

![](plotting-results_files/figure-html/dispersion-1.png)

``` r

plot(lagrangian_particles(500, 0, 0, u = 2, v = 0.5, kx = 1, ky = 1, dt = 1, n_steps = 60,
                          grid = c(0, 200, -60, 100, 40, 32)))
```

![](plotting-results_files/figure-html/dispersion-2.png)

The footprint of a computation: CPU, memory and the total in one unit
chosen to fit, with its everyday equivalents under the bars:

``` r

plot(compute_footprint(for (i in 1:20) sum(sqrt(seq_len(2e5))), location = "CA",
                       cpu_power_w = 45, memory_gb = 8))
```

![](plotting-results_files/figure-html/footprint-1.png)

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

plot(case_flow(f$received, f$disposed, pending = f$pending, period = f$month))
```

![](plotting-results_files/figure-html/case-flow-1.png)

How long cases stay open, from the published time-to-disposition bands:

``` r

last <- nrow(d)
plot(life_table(c(0, 10, 15, 18, Inf), unlist(d[last, 2:5]) * f$disposed[last]))
```

![](plotting-results_files/figure-html/life-table-1.png)

The mix of outcomes over the years:

``` r

plot(disposition_mix(x[, -(1:2)], period = x$year))
```

![](plotting-results_files/figure-html/disposition-mix-1.png)

A Simpson’s-paradox check: the parts’ rates, where the work moved, and
the change split into rate and mix effects:

``` r

plot(clearance_decomposition(g$disposed, g$received, g$offence_group, g$year))
```

![](plotting-results_files/figure-html/simpson-1.png)

Where break-and-enters cluster, and whether they repeat near each other
soon after:

``` r

plot(crime_density(b$lon, b$lat, n_grid = 120))
```

![](plotting-results_files/figure-html/density-1.png)

``` r

plot(knox_test(b$lon, b$lat, as.Date(b$occ_date), c(100, 200, 400), c(7, 14, 28),
               nsim = 99, seed = 1))
```

![](plotting-results_files/figure-html/density-2.png)

## Customising

Every method takes `main`, `col` (or a `palette` name), `grid`, and
`...` for the base-graphics call.
[`bricklayer_plot_options()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_palette.md)
sets the session defaults;
[`bricklayer_palette()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_palette.md)
gives the colour-blind-safe sets the package uses.

``` r

plot(sf, what = "alos", col = "firebrick", main = "Length of stay (days)", lwd = 3)
```

![](plotting-results_files/figure-html/custom-1.png)

``` r

old <- bricklayer_plot_options(palette = "grey", grid = FALSE)
plot(y, what = "value")
```

![](plotting-results_files/figure-html/custom-2.png)

``` r

bricklayer_plot_options(palette = old$palette, grid = old$grid)
bricklayer_palette("okabe", 4)
#> [1] "#0072B2" "#D55E00" "#009E73" "#E69F00"
```

Every method returns the data it drew, invisibly:

``` r

drawn <- plot(y)
```

![](plotting-results_files/figure-html/returned-1.png)

``` r

head(drawn, 3)
#>   label pct_change     lower    upper verdict
#> 1  2018         NA        NA       NA    <NA>
#> 2  2019  10.000000 -29.95683 73.20735      up
#> 3  2020  -6.818182 -40.61975 45.94265    down
```

Results that are plain data frames have a plot function of their own:
the Lorenz curve of a vector, and the funnel plot of observed against
expected counts per area.

``` r

plot_lorenz(c(1, 1, 2, 3, 5, 8, 13, 21))
```

![](plotting-results_files/figure-html/helpers-1.png)

``` r

plot_funnel(observed = c(4, 20, 50, 9, 31), expected = c(5, 22, 40, 20, 30),
            area = c("a", "b", "c", "d", "e"))
```

![](plotting-results_files/figure-html/helpers-2.png)
