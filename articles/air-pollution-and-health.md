# Air pollution: dispersion, health burden, equity, and the footprint of the computation

Three questions about air pollution recur in administrative and
public-health work: where does a plume go, how many deaths does a
concentration imply, and who bears it. A fourth has become part of
reproducible research: what did the computation itself cost in
electricity and carbon. This vignette walks the four tools, each with
the formula it implements and the paper it comes from, on small offline
examples.

## 1. Where the plume goes

### Dispersion coefficients

The Gaussian plume model needs the horizontal and vertical spread of the
plume as a function of downwind distance and atmospheric stability.
Pasquill’s stability classes A (very unstable) to F (very stable) with
Briggs’s (1973) curve fits are the standard parameterisation; rural and
urban coefficients differ because cities are rougher and warmer.

``` r

pgsig(1000, "D")
#> $sigmay
#> [1] 76.27701
#> 
#> $sigmaz
#> [1] 37.94733
pgsig(1000, "D", set = "urban")
#> $sigmay
#> [1] 135.2247
#> 
#> $sigmaz
#> [1] 122.7881
```

### Plume rise

A hot, fast stack gas rises before it levels off. Briggs’s plume-rise
equations give the buoyancy flux, the final rise and the distance at
which it is reached; before that distance the plume is still rising:

``` r

r <- briggs(c(100, 500, 2000), u = 4, diam = 1, exitvel = 12,
                       stktmp = 420, ambtmp = 285)
r$flux
#> [1] 9.45594
r$finalrise
#> [1] 28.88281
r$rise
#> [1] 18.22335 28.88281 28.88281
```

### Ground-level concentration

With the effective height (stack height plus rise), the plume equation
gives the concentration at any receptor; ground reflection is included,
and a mixing lid adds image terms. Concentration first rises with
distance as the plume reaches the ground, then falls as it dilutes:

``` r

x <- seq(200, 5000, by = 100)
h <- 30 + r$finalrise
cd <- gplume(q = 100, u = 4, h = h, rcpt = cbind(x, 0, 0), stab = "D")
cb <- gplume(q = 100, u = 4, h = h, rcpt = cbind(x, 0, 0), stab = "B")
plot(x, cd, type = "l", xlab = "downwind distance (m)", ylab = "concentration (g/m^3)",
     main = "Ground-level centreline concentration")
lines(x, cb, col = 2)
legend("topright", c("class D (neutral)", "class B (unstable)"), col = 1:2, lty = 1, bty = "n")
```

![](air-pollution-and-health_files/figure-html/plume-1.png)

[`gspuff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
is the instantaneous-release counterpart;
[`advdif2d()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
and
[`lagrprt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md)
are grid and particle models for cases the Gaussian assumptions (steady
wind, flat terrain) do not fit. The particle model is deterministic from
its seed and takes any normal generator through `normals=`, so another
package’s random stream can be reproduced exactly.

``` r

p <- lagrprt(n = 500, x0 = 0, y0 = 0, u = 1, v = 0, kx = 0.5, ky = 0.5,
                          dt = 1, nsteps = 50, seed = 1, grid = c(0, 100, -30, 30, 20, 12))
c(mean_x = p$mean_x, meany = p$meany)
#>       mean_x        meany 
#> 49.981881150  0.009562424
```

## 2. From concentration to deaths

### Concentration-response

The relative risk of death at an ambient concentration, relative to a
counterfactual concentration below which no excess risk is assumed. The
all-cause PM2.5 function is log-linear with the pooled cohort estimate
of the WHO 2021 guideline review, RR 1.08 per 10 µg/m³ (Chen and Hoek
2020); NO2 uses RR 1.02 per 10 µg/m³ (Huangfu and Atkinson 2020). The
cause-specific PM2.5 functions are the Integrated Exposure-Response
curves of Burnett et al. (2014), which saturate at high concentrations:

``` r

crfpm25(12)$rr
#> [1] 1.048873
exp(log(1.08) * (12 - 5.8) / 10)          # the same, by hand
#> [1] 1.048873
crfpm25(12, y = "ihd")$rr
#> [1] 1.553634
crfno2(25)$rr
#> [1] 1.03015
```

A vector of exposures gives the mean RR and keeps the per-unit values:

``` r

v <- crfpm25(c(6, 10, 15, 22))
v$rr
#> [1] 1.060136
v$extra$rrperunit
#> [1] 1.001540 1.032852 1.073371 1.132782
```

### Attributable fraction and avoided deaths

Levin’s population attributable fraction turns a relative risk and an
exposure prevalence into the share of deaths the exposure accounts for;
the BenMAP health-impact function gives the deaths avoided by a
counterfactual reduction:

``` r

attrfrac(crfno2(25)$rr, expoprev = 1)
#> [1] 0.02926711
mortdisp(expdel = 10, pop = 1e6, brate = 0.008,
                    betaperunit = log(1.02) / 10)
#> [1] 156.8627
```

### The burden chain

[`polbrdn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
chains concentration-response, attributable fraction and the baseline
case count, as the Global Burden of Disease risk-factor estimates do:

``` r

b <- polbrdn(expomean = 25, expoprev = 1, brate = 0.008,
                      pop = 1e6, poll = "NO2")
c(rr = b$extra$rr, paf = b$paf, attributable = b$attrcases)
#>           rr          paf attributable 
#>   1.03014950   0.02926711 234.13691783
b$citation
#> [1] "Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines; Rothman et al. (2008) section 5"
```

Per area, sorted worst first:

``` r

areas <- data.frame(fsa = c("M6H", "M5V", "M4W", "M1B"), exposure = c(28, 18, 15, 24),
                    population = c(40000, 60000, 25000, 70000), brate = 0.008)
polbrdarea(areas)
#>   fsa exposure population brate       rr         paf attrcases basecases
#> 1 M1B       24      70000 0.008 1.028112 0.027342904 15.312026       560
#> 2 M6H       28      40000 0.008 1.036288 0.035016937 11.205420       320
#> 3 M5V       18      60000 0.008 1.015968 0.015717276  7.544292       480
#> 4 M4W       15      25000 0.008 1.009950 0.009852457  1.970491       200
```

## 3. Who bears it

The concentration index of Wagstaff, Paci and van Doorslaer (1991)
measures whether exposure concentrates among lower- or higher-income
people: it is twice the covariance of exposure with the fractional
income rank, divided by mean exposure. Negative means the poor bear
more.

``` r

d <- data.frame(exposure = c(30, 27, 22, 18, 14), income = 1:5)
e <- expconcidx(d, "exposure", "income")
e$concidx
#> [1] -0.1477477
e$interpretation
#> [1] "CI = -0.1477. Pro-poor exposure burden: lower-income individuals bear disproportionately higher pollution."
```

## 4. Estimating the exposure effect from your own data

When individual or area data with confounders are available, the
partially linear model of Chernozhukov et al. (2018) estimates the
exposure effect with cross-fitted nuisance functions, so the confounder
adjustment cannot overfit the same rows it is evaluated on.
[`exprspplr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exprspplr.md)
adds a percentile bootstrap for a sensitivity interval. The default
estimator uses ordinary-least-squares nuisances; any estimator with the
same interface can be passed.

``` r

set.seed(1)
n <- 300
sim <- data.frame(income = rnorm(n), density = rnorm(n))
sim$no2 <- 20 - 2 * sim$income + 3 * sim$density + rnorm(n)
sim$asthmarate <- 5 + 0.3 * sim$no2 - 0.5 * sim$income + rnorm(n)
fit <- exprspplr(sim, y = "asthmarate", expo = "no2",
                             confs = c("income", "density"), nboot = 30)
c(ate = fit$ate, lower = fit$cilobs, upper = fit$ciupbs)
#>       ate     lower     upper 
#> 0.2464713 0.1437978 0.3132657
```

The true coefficient is 0.3 and the interval covers it.

## 5. The whole pipeline, with an assumption log

[`vrfpol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
runs the chain end to end and records every assumption it checked, so a
report says not only the number but the conditions under which it holds.
Synthetic demo data stand in here:

``` r

r <- vrfpol("no2", demo = TRUE, reg = "demo", years = "2024")
r$status
#> [1] "ok"
cat(polrpttxt(r))
#> ==================================================================
#>   verify-pollution -- NO2 -> allcause
#>   region: demo
#>   years:  2024
#>   data:   demo (synthetic)
#> ==================================================================
#> 
#> Inputs
#>   exposure mean:      24.261
#>   exposure prevalence:0.981
#>   baseline rate/100k: 500.00
#>   population:         1,000,000
#>   reference conc:     10
#> 
#> Assumption log
#>   [PASS] exposure finite and non-negative -- mean 24.26113743 vs ref 10
#>   [PASS] exposure within the concentration-response range (at most 10,000 ug/m3) -- exposure_mean=24.26114
#>   [PASS] prevalence in [0,1] -- exposure_prevalence=0.981
#>   [PASS] brate finite: zero, or between 1 and 10,000 per 100k -- brate=500 per 100k per year
#>   [PASS] population finite, positive and at most 10 billion -- population=1,000,000
#>   [PASS] reference finite and non-negative -- reference=10
#>   [PASS] pollutant supported by the CRFs -- Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke). Other pollutants reject.
#> 
#> Concentration-response
#>   RR:       1.0286
#>   source:   Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines
#> 
#> Attributable fraction (PAF): 0.0273  (95% CI 0.0138 to 0.0534, from the risk's limits)
#> 
#> Mortality displaced
#>   expected avoided deaths: 136.6
#> 
#> Burden of pollution
#>   attributable deaths:   136.7
#> 
#> Equity analysis
#>   concentration index: -0.0647
#> 
#> STATUS: ok
```

An input that violates an assumption stops the pipeline and says why,
with a non-zero exit status for scripts (a negative exposure here); an
exposure at or below the reference is a valid run with zero attributable
cases, and a call with no exposure data at all is an error, not a clean
zero:

``` r

bad <- vrfpol("pm25", expomean = -3, expoprev = 0.5)
bad$status
#> [1] "assumption_failure"
attr(bad, "exitstat")
#> [1] 1
none <- vrfpol("pm25")
none$status
#> [1] "error"
attr(none, "exitstat")
#> [1] 2
```

A CSV with an `exposure` column (and optionally `income`) replaces the
demo data; a NAPS pull with `value` in ppb is converted to µg/m³ at 1.88
for NO2.

## 6. What did this computation cost?

Computation uses electricity, and electricity has a carbon intensity.
[`co2fp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
reports both for any expression, two ways. On Linux with readable RAPL
counters it *measures* the CPU package energy, as codecarbon does.
Everywhere else it *models* energy with the Green Algorithms formula
(Lannelongue, Grealey and Inouye 2021),
$`E = t\,(P_{cpu} u + M \cdot 0.3725\,\mathrm{W/GB})\,PUE`$. Every
default that stood in for a measurement is listed:

``` r

raplok()
#> [1] FALSE
fp <- co2fp(sum(sqrt(seq_len(3e5))), loc = "CA-ON", cpupwrw = 45,
                        memgb = 16)
print(fp)
#> Computation footprint (modelled): 0.004 s wall, 0.004 s CPU, utilisation 0.25 (process) on 4 cores
#>   energy: 1.91e-08 kWh (cpu 1.25e-08, memory 6.62e-09)
#>   CO2e:   1.74e-06 g at 90.97 gCO2e/kWh (Canada, Ontario, 2024)
fp$assumptions
#> character(0)
```

### Utilisation: measured, per process or per machine

The Green Algorithms calculator asks the user for the utilisation $`u`$
and defaults to 1; codecarbon measures it in one of two tracking modes.
[`co2fp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
measures it too, in the same two ways. `usage = "process"` (the default)
is this R process’s own CPU time, children included, over wall time and
cores, so an idle wait is not charged as computation.
`usage = "machine"` is the whole machine’s busy share over the run, read
from `/proc/stat` on Linux, for the case where the computation is all
the machine is doing or the question is what the machine drew; where
there is no `/proc/stat` the process figure is used and the assumptions
say so. A number fixes it, as the calculator does. `loadcur` chooses how
power follows utilisation: linearly (Green Algorithms) or along
codecarbon’s curves, a 10% floor for a process and $`0.1 + 0.9u^3`$ for
a machine, so a figure can be made comparable with either tool:

``` r

busy <- function() sum(sqrt(seq_len(2e5)))
a <- co2fp(busy(), loc = "CA-ON", cpupwrw = 45, memgb = 16)
b <- co2fp(busy(), loc = "CA-ON", cpupwrw = 45, memgb = 16,
                       usage = "machine", loadcur = "codecarbon")
rbind(prolin = c(usage = a$usage, cpukwh = a$enekwh$cpu),
      maccod = c(usage = b$usage, cpukwh = b$enekwh$cpu))
#>            usage       cpukwh
#> prolin 0.2500000 9.375000e-09
#> maccod 0.3333333 2.333333e-08
b$usagemode
#> [1] "machine"
```

### The grid: the latest year, every country, offline

The carbon intensity comes from a table bundled with the package, so
nothing is fetched and it works in any country: every country at the
latest year Our World in Data publishes from Ember’s yearly electricity
data (2024 or 2025 at this release for all but a few grids whose latest
row is older, Ukraine’s 2022 among them; every row carries its year),
sub-national zones from Electricity Maps’ 2024 yearly data as
redistributed by Green Algorithms (Canadian provinces, US balancing
authorities, Australian states, Indian and Japanese regions, …), and the
world average. Each row carries its year and source, so a report can
cite them. A location is matched by code, alpha-3 code or name; an
unknown zone falls back to its country and says so; a number of your own
is accepted when you have a better figure:

``` r

co2int("CA-ON")[c("g_per_kwh", "year", "source")]
#> $g_per_kwh
#> [1] 90.97
#> 
#> $year
#> [1] 2024
#> 
#> $source
#> [1] "Electricity Maps (2025). Canada 2024 Yearly Carbon Intensity Data (Version January 27, 2025). Electricity Maps (via Green Algorithms data v3.1)"
co2int("Kenya")[c("location", "g_per_kwh", "year")]
#> $location
#> [1] "KE"
#> 
#> $g_per_kwh
#> [1] 95.44
#> 
#> $year
#> [1] 2025
co2int("CA-XX")$note
#> [1] "no row for zone CA-XX; its country CA used"
tab <- co2inttab()
nrow(tab)
#> [1] 378
table(nchar(tab$location) == 2, tab$year)[, c("2024", "2025")]
#>        
#>         2024 2025
#>   FALSE  155    3
#>   TRUE   125   91
```

With `location = NULL` (the default) the location is detected offline,
in order, from the `RMBL_LOCATION` environment variable, codecarbon’s
`CODECARBON_COUNTRY_ISO_CODE`, the system time zone (`America/Toronto`
is Canada, `Asia/Kolkata` India) and the locale, and the detection is
written into the assumptions; when nothing is found the world average is
used and the result says so, so one country’s grid is never silently
applied to another’s computation:

``` r

dtctloc()
#> $location
#> [1] "WORLD"
#> 
#> $method
#> [1] "fallback, no location found in environment, time zone or locale"
dtctloc(envloc = "", codloc = "", tz = "Asia/Kolkata")
#> $location
#> [1] "IN"
#> 
#> $method
#> [1] "system time zone Asia/Kolkata"
co2fp(1 + 1, cpupwrw = 45, memgb = 16)$assumptions[1]
#> [1] "location WORLD via fallback, no location found in environment, time zone or locale"
```

For a long analysis the figures become meaningful; the equivalents are
the two the Green Algorithms calculator prints:

``` r

fpeqv(fp$co2eg * 1e4)   # if this ran ten thousand times
#> $carkm
#> [1] 9.940277e-05
#> 
#> $treemon
#> [1] 1.897e-05
#> 
#> $sources
#>                                                                  car 
#> "175 gCO2/km, European passenger car (Green Algorithms context.csv)" 
#>                                                                 tree 
#>             "917 gCO2 per tree-month (Green Algorithms context.csv)"
```

**Cross-checked against codecarbon.** On the same 8-second CPU-bound
workload with the same forced inputs (65 W CPU, 16 GB at 0.3725 W/GB),
codecarbon 3.3.1 and
[`co2fp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
charged the memory identically (5.96 W) and the CPU within 8%;
`loadcur = "codecarbon"` reproduces codecarbon’s power-from-load curves,
so what remains of the difference is the load measurement itself
(codecarbon samples it during the run, this function integrates the CPU
time). The carbon intensity they applied to Canada differed (170 g/kWh
from codecarbon’s 2023 Our World in Data figure; 190.7 g/kWh from the
2025 figure bundled here), which is the point of carrying the year with
every row: grid intensities move, and a report should cite the year of
the one it used. CodeCarbonR on CRAN wraps the same Python tracker
through reticulate; this function needs no Python and no network.

**What this does and does not cover.** The measured mode reads the CPU
packages only; memory, storage, network and GPU are not in the RAPL
counters (GPU power needs the vendor library; this package has no GPU
dependency). The modelled mode inherits Green Algorithms’ assumptions:
memory draws 0.3725 W/GB regardless of how it is populated (codecarbon
v3 moved to a per-DIMM heuristic for the same reason), and the grid
intensity is an annual average, not the hour’s. Embodied emissions of
the hardware are excluded, as in both reference tools. The place to
improve a figure is the inputs: a measured `cpupwrw` for your CPU, the
actual `memgb` your job used, the data centre’s `pue`, and, if you have
it, the hour’s carbon intensity passed as a number.

## First Nations, Métis and Inuit populations

The 2021 Census gives the populations a burden estimate needs. The
bundled Indigenous Population Profile excerpt has them by province and
territory; the concentrations below are scenarios (the WHO 2021
guideline of 5 µg/m³ against 8 and 12 µg/m³), not measurements of any
community.

``` r

cp <- indiex("censuspop")
tot <- cp[cp$GEO_LEVEL != "Country" & cp$AGE_GROUP == "Total - Age groups" &
            cp$RESIDENCE == "Total - Residence on or off reserve" &
            grepl("^Total - Average age", cp$CHARACTERISTIC_NAME), ]
pop <- stats::setNames(tot$FIRST_NATIONS, tot$GEO_NAME)
head(pop[order(-pop)], 5)
#>          Ontario British Columbia          Alberta         Manitoba 
#>           251030           180085           145640           134890 
#>     Saskatchewan 
#>           121175
# relative risk of all-cause mortality from PM2.5, and the share of deaths attributable to
# the excess above the guideline if the whole population breathes the scenario level
sapply(c(8, 12), function(conc) {
  rr <- crfpm25(conc, refconc = 5)$rr
  c(pm25 = conc, rr = rr, attributable = attrfrac(rr, 1))
})
#>                    [,1]       [,2]
#> pm25         8.00000000 12.0000000
#> rr           1.02335691  1.0553503
#> attributable 0.02282382  0.0524473
```

## References

Briggs (1973). Diffusion estimation for small emissions. ATDL 79. Briggs
(1975). Plume rise predictions. AMS. Burnett et al. (2014). An
integrated risk function for estimating the global burden of disease
attributable to ambient fine particulate matter exposure. *EHP* 122(4).
Chen, Hoek (2020). Long-term exposure to PM and all-cause and
cause-specific mortality. *Environment International* 143. Chernozhukov
et al. (2018). Double/debiased machine learning. *Econometrics Journal*
21(1). Huangfu, Atkinson (2020). Long-term exposure to NO2 and O3 and
all-cause and respiratory mortality. *Environment International* 144.
Lannelongue, Grealey, Inouye (2021). Green Algorithms: quantifying the
carbon footprint of computation. *Advanced Science* 8(12), 2100707.
Ember (2026). Yearly Electricity Data, via Our World in Data,
<https://ourworldindata.org/grapher/carbon-intensity-electricity>.
Electricity Maps (2025). 2024 Yearly Carbon Intensity Data, via Green
Algorithms data v3.1. Levin (1953). The occurrence of lung cancer in
man. *Acta Unio Internationalis Contra Cancrum* 9. Wagstaff, Paci, van
Doorslaer (1991). On the measurement of inequalities in health. *Social
Science and Medicine* 33(5). WHO (2021). Global Air Quality Guidelines.
