# Applied analyses: justice, health, environment and rescue

## Courts and crime: flow, time, outcomes, place and case mix

Court and police statistics are published as counts: cases received and
disposed each month, shares disposed within so many months, incidents
with a date and a place. This vignette works through the questions those
counts are asked to answer, on the Ontario Court of Justice’s criminal
statistics and the Toronto Police Service’s open data (see
`?justice-data` for every file and its source). Each section uses the
excerpt shipped with the package; the full tables, every edition and
every court, load from the data hub:

``` r

clearance <- dload("ocj_statistics/clearance_rate_criminal")
offences  <- dload("ocj_statistics/offence_based_criminal")
mci       <- dload("tps_open_data/major_crime_indicators_open_data_0")
```

### Is the court keeping up? Case flow and clearance

A court keeps up when it disposes of as many cases as it receives.
[`caseflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md)
turns the monthly counts into the clearance rate (disposed per case
received) with an exact interval, its rolling twelve-month value, and,
from the pending count, how many months the inventory would take to
clear at the recent pace.

``` r

f <- ext("ocj_flow_ontario.csv")
cf <- caseflow(f$received, f$disposed, pend = f$pending, prd = f$month)
cf[c(1, 12, 24), c("period", "received", "disposed", "clearance", "rolclr", "pertoclear")]
#>    period received disposed clearance    rolclr pertoclear
#> 1 2024-04    21265    22053  1.037056        NA   6.752097
#> 2 2025-03    20688    20996  1.014888 0.9742875   7.466076
#> 3 2026-03    20602    23136  1.122998 0.9937306   7.196190
plot(cf)
```

![](applied-analyses_files/figure-html/courts-and-crime-flow-1.png)

Over these 24 months the court disposed of 489,448 cases against 497,393
received, a clearance rate of 0.984. The monthly rate swings well beyond
its interval – summer months clear less – which is why the rolling rate
is the one to read.

### How long do cases take? A life table from banded times

The Court publishes the share of cases disposed within 10 months, 10 to
15, 15 to 18 and over 18.
[`lifetbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/lifetbl.md)
reads those bands directly and gives the share still open at each band
edge, with a Greenwood interval, and the median.

``` r

d <- ext("ocj_time_to_disposition.csv")
last <- nrow(d)
shares <- unlist(d[last, c("under_10", "m10_15", "m15_18", "over_18")])
lt <- lifetbl(c("Under 10 Months", "Between 10-15 Months", "Between 15-18 Months", "Over 18 Months"),
                 events = shares * f$disposed[last])
lt
#> ── Life table (actuarial), 95% log-log Greenwood interval ──────── 
#>   Median time: 6.36 (linear within its band)
#> 
#>  lower upper  entering    events censored    atrisk      q survival     se
#>      0    10 23136.000 18184.896        0 23136.000 0.7860    0.214 0.0027
#>     10    15  4951.104  2868.864        0  4951.104 0.5794    0.090 0.0019
#>     15    18  2082.240   879.168        0  2082.240 0.4222    0.052 0.0015
#>     18   Inf  1203.072  1203.072        0  1203.072 1.0000    0.000     NA
#>  conflo confup hazard
#>  0.2087 0.2193 0.1295
#>  0.0864 0.0937 0.1632
#>  0.0492 0.0549 0.1784
#>      NA     NA     NA
#> ──────────────────────────────────────────────────────────────────
plot(lt)
```

![](applied-analyses_files/figure-html/courts-and-crime-life-1.png)

The median of 6.4 months assumes cases are spread evenly within the
first band; the published average for the month is 185 days. Only
disposed cases are in these statistics, so the table describes the cases
that ended, not every case received.

### How do cases end? The mix of outcomes

``` r

x <- ext("ocj_dispositions.csv")
mix <- dispmix(x[, -(1:2)], prd = x$year, scores = x$year)
mix$trend[, c("outcome", "statistic", "pholm", "change")]
#>                         outcome    statistic        pholm        change
#> 1 withdrawn_stayed_before_trial 30150.915355 0.000000e+00  0.1292036827
#> 2      guilty_plea_before_trial 10825.914695 0.000000e+00 -0.0805960172
#> 3            other_before_trial     7.296441 6.909133e-03 -0.0002635828
#> 4            withdrawn_at_trial  2890.841438 0.000000e+00 -0.0127761314
#> 5          guilty_plea_at_trial  6782.412494 0.000000e+00 -0.0218969033
#> 6                other_at_trial   175.420561 9.691647e-40 -0.0006064793
#> 7               following_trial  2044.569303 0.000000e+00 -0.0130645687
plot(mix)
```

![](applied-analyses_files/figure-html/courts-and-crime-mix-1.png)

Every share comes with Goodman’s simultaneous interval (in
`mix$shares`). With a few hundred thousand cases a year every trend is
“significant”; the `change` column says how large each shift is. The
years are the scores, so the gaps at 2020 and 2023 (see `?justice-data`)
are spaced as they should be.

### Is a change in the clearance rate real? Simpson’s paradox and case mix

An aggregate clearance rate is a weighted average of the rates of its
parts – offence groups, courts – weighted by their share of the work. It
can fall while most parts improve, if the work shifts toward the parts
that clear more slowly. Demers and Rossmo (2015) found 210 such
reversals in fifteen years of clearance rates for Canada’s fifty largest
police services.
[`clrdcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clrdcmp.md)
splits a change exactly into the change in the parts’ rates and the
change in the mix (Kitagawa, 1955), and tests the within-part change
with a Mantel-Haenszel rate ratio.

``` r

g <- ext("ocj_offence_groups.csv")
g <- g[g$year %in% c(2014, 2022), ]
cd <- clrdcmp(g$disposed, g$received, g$offence_group, g$year)
cd
#> ── Clearance rate, 2022 against 2014: rate and case-mix effects (Kitagawa)  
#>   2014: 0.9760   2022: 0.9749   change -0.0011 = rate effect +0.0096 + mix effect -0.0107
#>   2022 standardised to the 2014 mix: 0.9912; to the average mix: 0.9830
#>   4 of 6 parts rose, 2 fell. Simpson's paradox through the mix: the aggregate fell, but at a fixed mix it rose
#> 
#>                       part rate 2014 rate 2022 share 2014 share 2022  ratio
#>  Administration of Justice    0.9788    1.0378     0.2689     0.2818 1.0603
#>    Crimes Against Property    0.9851    0.9692     0.2279     0.1973 0.9839
#>  Crimes Against the Person    0.9180    0.8576     0.2620     0.3187 0.9343
#>      Criminal Code Traffic    1.0105    1.0212     0.0808     0.0948 1.0106
#>            Federal Statute    1.0232    1.1734     0.1148     0.0534 1.1468
#>        Other Criminal Code    1.0675    1.0818     0.0455     0.0539 1.0134
#>   lower  upper   rateeff    mixeff
#>  1.0484 1.0725  0.016300  4.24e-04
#>  0.9710 0.9969 -0.003370 -5.16e-05
#>  0.9233 0.9454 -0.017500 -4.97e-03
#>  0.9905 1.0311  0.000939  5.66e-04
#>  1.1230 1.1710  0.012600 -7.54e-03
#>  0.9874 1.0402  0.000713  8.34e-04
#> 
#>   Rate ratio 2022/2014: crude 0.9989 (0.9929 to 1.0050); within parts (Mantel-Haenszel) 1.0085 (1.0024 to 1.0146), p 0.00644
#> ──────────────────────────────────────────────────────────────────
plot(cd)
```

![](applied-analyses_files/figure-html/courts-and-crime-simpson-1.png)

``` r

# a group's share of the cases received in a year, as a percentage
caseshare <- function(group, yr) {
  sprintf("%.0f%%", 100 * sum(g$received[g$offence_group == group & g$year == yr]) / sum(g$received[g$year == yr]))
}
```

Between 2014 and 2022 the province-wide clearance rate moved by -0.0011.
Held at a fixed mix it moved by +0.0096; the shift of work contributed
-0.0107. Crimes against the person, the group with the lowest clearance
rate in both years, grew from 26% to 32% of the cases received, and
federal-statute cases, the group with the highest rate in 2022, fell
from 11% to 5%. 4 of the 6 groups cleared a larger share in 2022 and 2 a
smaller one. The crude ratio’s interval includes 1; the Mantel-Haenszel
ratio within offence groups is 1.0085 (1.0024 to 1.0146). Read alone,
the aggregate would say nothing changed; within the groups, taken
together, clearance improved, though not in every group.

The grouping matters, and so does the pair of years. By court, with
Toronto’s courthouses taken together (they were consolidated in 2023),
comparing 2012 with 2024:

``` r

c <- ext("ocj_courts.csv")
c <- aggregate(cbind(received, disposed) ~ year + court_series, c, sum)
c <- c[c$year %in% c(2012, 2024), ]
c <- c[c$court_series %in% names(which(table(c$court_series) == 2)), ]
cc <- clrdcmp(c$disposed, c$received, c$court_series, c$year)
cc$overall
#>       ratea     rateb       change     rateeff      mixeff staonbase  staonave
#> 1 0.9990086 0.9891387 -0.009869871 -0.01247238 0.002602504 0.9852411 0.9871899
cc$simpson$type
#> [1] "none"
```

Here the aggregate (-0.0099) and the rate at a fixed mix (-0.0125) move
the same way: no reversal, and 27 of 54 courts cleared a smaller share
in 2024. A decomposition does not always find a paradox; it says which
way the parts moved and how much the mix did.

### Where do incidents cluster? Kernel density

[`crmdens()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crmdens.md)
estimates the density of incidents in incidents per square kilometre and
outlines the smallest areas holding half and nine-tenths of them.

``` r

b <- ext("tps_break_enter_d14_2024.csv")
kd <- crmdens(b$lon, b$lat, ngrid = 150)
kd
#> ── Kernel density of incidents: smallest areas holding each share  
#>   508 incidents; bandwidth 0.337 km east-west, 0.412 km north-south
#>   Peak density 77.92 incidents per square kilometre
#> 
#>  incidents areakm2 shrofmaparea densatedge
#>        50%   5.502        11.9%      31.88
#>        90%  14.840        32.1%      11.23
#> ──────────────────────────────────────────────────────────────────
plot(kd)
```

![](applied-analyses_files/figure-html/courts-and-crime-density-1.png)

### Do incidents repeat nearby, soon after? The Knox test

Break-ins close in space and time to an earlier one are the near-repeat
pattern. The Knox test compares the pairs close in both with the number
expected if the dates were shuffled among the places; the expectation is
exact, and a permutation test gives each cell’s p-value.

``` r

b <- b[!is.na(b$lon), ]
kn <- knoxtst(b$lon, b$lat, as.Date(b$occ_date), spcbands = c(100, 200, 400),
                tmbands = c(7, 14, 28), nsim = 199, seed = 1)
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

![](applied-analyses_files/figure-html/courts-and-crime-knox-1.png)

### Do the hot spots last?

A hot spot that stays put is a place problem; one that moves is not.
[`hotpers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hotpers.md)
counts the incidents in grid cells each period, reports the share of
places that holds half of them, which cells are hot (the busiest 5% of
the cells with any incident), and how much each period’s hot spots
overlap the previous period’s:

``` r

h <- hotpers(b$lon, b$lat, quarters(as.Date(b$occ_date)), cell = 0.3)
h
#> Hot spots: 139 active cells of side 0.3 km over 4 periods; hot = busiest 7 (5%)
#>  period incidents actcells cellsforhalf shrforhalf hotcells tiedin tiedout
#>      Q1       128       77           22      15.8%       11      4       0
#>      Q2       133       74           22      15.8%        7      0       0
#>      Q3       112       70           19      13.7%        7      0       0
#>      Q4       135       72           23      16.5%        4      0      12
#>  hotshr jacpre
#>   32.8%       
#>   22.6%   0.29
#>   26.8%   0.17
#>   13.3%   0.10
#> Cells hot in at least half the periods: 7
#> Note: cells tied with the busiest 7 were left out of the hot set (period Q4: 12 cells tied); the counts are too even (or the cells too small) to single out hot spots
plot(h)
```

![](applied-analyses_files/figure-html/courts-and-crime-hotspots-1.png)

The hot set is the busiest 7 cells and every cell tied with the last of
them. When a tie would make more than twice that many cells hot, the
counts do not single those cells out, so the tied group is left out and
counted under `tiedout`: a quarter can then show fewer hot cells than 7,
a smaller hot share, and an overlap with its neighbours that cannot be
computed (left blank), as in Q4 here.

Pairs of break-ins within 100 metres and a week of each other occur 1.66
times as often as chance would give.

### Indigenous life expectancy

[`lifetbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/lifetbl.md)
works from counts of events in age intervals. Where only published
summaries exist, as for Indigenous life expectancy, the comparison is
made on the published estimates and their intervals instead:

``` r

le <- indiex("lifeexp")
le[le$period == "2016/2021", c("group", "estimate", "lower", "upper")]
#>                                                group estimate lower upper
#> 15                                             Métis    80.47 79.98 80.95
#> 16                                             Inuit    71.91 70.80 73.03
#> 17              First Nations (Registered or Treaty)    73.98 73.63 74.33
#> 18  First Nations (Registered or Treaty), on reserve    71.42 71.02 71.81
#> 19 First Nations (Registered or Treaty), off reserve    76.04 75.37 76.71
#> 20          First Nations, without registered status    79.23 78.42 80.04
#> 21                                    Non-Indigenous    84.99 84.93 85.04
```

### References

Demers, S. and Rossmo, D. K. (2015). Simpson’s paradox in Canadian
police clearance rates. *Canadian Journal of Criminology and Criminal
Justice*, 57(3), 424-434.

Kitagawa, E. M. (1955). Components of a difference between two rates.
*Journal of the American Statistical Association*, 50(272), 1168-1194.

Knox, E. G. (1964). The detection of space-time interactions. *Journal
of the Royal Statistical Society, Series C*, 13(1), 25-30.

## Parsing SIU director’s reports

Ontario’s Special Investigations Unit publishes a director’s report for
every investigation as an HTML page. The reports share a structure but
not a template: fields appear under varying headings, counts are written
in words or figures, and the text is long. The package parses them into
a fixed, panel-reviewed schema with a parser written for hostile input.

### The schema

``` r

sch <- siusch()
head(sch$name, 20)
#>  [1] "police_service"                "date_of_incident_iso"         
#>  [3] "date_siu_notified_iso"         "date_of_director_decision_iso"
#>  [5] "siu_investigators"             "siu_forensics_investigators"  
#>  [7] "number_of_witness_officials"   "number_of_civilian_witnesses" 
#>  [9] "number_of_subject_officials"   "age_affected"                 
#> [11] "sex_gender_affected"           "charges_recommended"          
#> [13] "directors_name"                "location_of_call"             
#> [15] "specific_injuries"             "relevant_legislation"
nrow(sch)
#> [1] 16
```

### Parsing a report

The package ships a synthetic report with the structure of a real one
and no real person in it:

``` r

f <- siuprs(system.file("extdata", "siu_synthetic_report.html",
                                      package = "rmoriebricklayer"))
f[["number_of_subject_officials"]]
#> [1] "2"
f[["date_of_incident_iso"]]
#> [1] "2023-01-05"
```

### The pieces

HTML to plain text, with the layout tags turned into line structure and
entities decoded:

``` r

siutxt("<p>Number of SIU Investigators assigned: 3</p>")
#> [1] " Number of SIU Investigators assigned: 3\n"
```

The subject-official count, resolved from the enumerated list rather
than a headline number that reports sometimes omit:

``` r

siuso("Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#> $count
#> [1] 2
#> 
#> $reason
#> [1] "section: max(ordinal 2, entries 2)"
```

Dates in the report’s prose, normalised to ISO:

``` r

siudate("March 4, 2024")
#> [1] "2024-03-04"
siudate("not a date")
#> [1] ""
```

### Written for hostile input

A parser that reads 5,000 public web pages will meet broken HTML,
megabyte-long lines, unclosed tags and entities of every shape. Three
review rounds on this parser established and tested the following, each
pinned by a test over the sources:

- **No regex crosses a line without a bound.** Two passes that once
  scanned to the end of the document on `[\s\S]*?` were replaced by
  [`find()`](https://rdrr.io/r/utils/apropos.html) scans after 44 KB of
  period-free boilerplate overflowed the C stack; a hygiene test now
  asserts no unbounded cross-line regex exists in the SIU sources.
- **Every pass is linear.** Two tag-stripping passes were quadratic
  (re-scanning from each unclosed `<script` or bare `<`); at the 2 MiB
  input cap one took 40 minutes. Both are single-pass now.
- **Lines are capped at 2,000 characters** and split at the last
  sentence end inside the window, else the last space; the functions
  warn how many lines were split, because a field spanning a split can
  come back incomplete.
- **Numbers are bounded.** Every string-to-integer conversion goes
  through one helper that reads up to nine digits; `SO #1234567` is
  1234567, and `SO #4444444444444444` is ignored as a tag (the count
  falls back to the other cues), not an overflow.
- **The user can interrupt.** The whole path polls for an interrupt
  through a hook the host installs, and raises it only from a frame that
  owns no live C++ objects.
- **Input is capped at 2 MiB**, and the fuzzers run the parser under an
  8 MB stack like R’s, with seeds for every shape the reviewers used.

### Fetching live reports

[`siufetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufetch.md)
fetches a report by its identifier through the package’s checked
transport (address validation, redirect policy, resource limits) with an
Internet Archive fallback, and
[`siufprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufprs.md)
fetches and parses in one call:

``` r

f <- siufprs("24-OCI-123")
```

The corpus of parsed reports, reviewed round by round, is distributed as
a dataset by the companion package `rmoriedata`; this package provides
the parser so the corpus can be rebuilt and audited.

### Indigenous police services

Ontario’s First Nations police services, among them the Nishnawbe-Aski
Police Service, the Anishinabek Police Service and the Treaty Three
Police Service, are investigated by the SIU like any other. The parsed
`police_service` field selects their cases (this fetches live reports,
so it is not run here):

``` r

fnservices <- c("Nishnawbe-Aski Police Service", "Anishinabek Police Service",
                 "Treaty Three Police Service", "UCCM Anishnaabe Police Service")
reports <- lapply(reporturls, siufprs)
mine <- Filter(function(r) any(grepl(paste(fnservices, collapse = "|"), r$police_service)),
               reports)
length(mine)
```

### The report’s timeline in a picture

[`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md)
returns each date in the report in ISO form. Drawn on one axis, they
give the investigation’s timeline at a glance.

``` r

rpt <- siuprs(siutxt(paste(readLines(system.file("extdata", "siu_synthetic_report.html",
                                                    package = "rmoriebricklayer"), warn = FALSE),
                           collapse = "\n")))
iso <- rpt[grepl("_iso$", names(rpt)) & grepl("^\\d{4}-\\d{2}-\\d{2}$", rpt)]
when <- as.Date(iso)
o <- order(when)
lab <- gsub("_", " ", sub("_iso$", "", names(iso)[o]))
span <- diff(range(when))
op <- par(mar = c(4, 1, 3, 1))
plot(when[o], seq_along(o), pch = 19, col = blpal()[1], yaxt = "n", xaxt = "n", xlab = "", ylab = "",
     xlim = range(when) + c(-0.1, 0.1) * as.numeric(span), ylim = c(0.5, length(o) + 0.5),
     main = "Dates in the synthetic report")
axis.Date(1, when, format = "%Y-%m-%d")
text(when[o], seq_along(o), paste0(lab, "  ", format(when[o])), cex = 0.75,
     pos = ifelse(seq_along(o) < length(o), 4, 2))
```

![](applied-analyses_files/figure-html/siu-reports-siu-timeline-plot-1.png)

``` r

par(op)
```

## Air pollution: dispersion, health burden, equity, and the footprint of the computation

Three questions about air pollution recur in administrative and
public-health work: where does a plume go, how many deaths does a
concentration imply, and who bears it. A fourth has become part of
reproducible research: what did the computation itself cost in
electricity and carbon. This vignette walks the four tools, each with
the formula it implements and the paper it comes from, on small offline
examples.

### 1. Where the plume goes

#### Dispersion coefficients

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

#### Plume rise

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

#### Ground-level concentration

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

![](applied-analyses_files/figure-html/air-pollution-and-health-plume-1.png)

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

### 2. From concentration to deaths

#### Concentration-response

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

#### Attributable fraction and avoided deaths

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

#### The burden chain

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

### 3. Who bears it

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

### 4. Estimating the exposure effect from your own data

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

### 5. The whole pipeline, with an assumption log

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

### 6. What did this computation cost?

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
#> Computation footprint (modelled): 0.003 s wall, 0.003 s CPU, utilisation 0.25 (process) on 4 cores
#>   energy: 1.43e-08 kWh (cpu 9.38e-09, memory 4.97e-09)
#>   CO2e:   1.3e-06 g at 90.97 gCO2e/kWh (Canada, Ontario, 2024)
fp$assumptions
#> character(0)
```

#### Utilisation: measured, per process or per machine

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
#>        usage     cpukwh
#> prolin  0.25 9.3750e-09
#> maccod  0.50 1.0625e-08
b$usagemode
#> [1] "machine"
```

#### The grid: the latest year, every country, offline

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
#> [1] 7.455208e-05
#> 
#> $treemon
#> [1] 1.42275e-05
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

### First Nations, Métis and Inuit populations

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

### References

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

## First Nations, Metis and Inuit health: published tables, distinctions and governance

This vignette covers the tools for First Nations, Metis and Inuit
health, mental health and wellness data, as Statistics Canada publishes
them. It also covers the rules those tools follow, because with these
data, how you work matters as much as what you compute.

Every example runs on published values.
[`indiex()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md)
bundles excerpts of eight Statistics Canada tables, reproduced under the
Statistics Canada Open Licence:

| Excerpt | Table | Survey and period |
|----|----|----|
| `"health"` | 13-10-0924-01 | Canadian Community Health Survey, 2015/2018 and 2019/2022 |
| `"mentalhealth"` | 41-10-0067-01 | Indigenous Peoples Survey, 2022 |
| `"wellbeing"` | 41-10-0082-01 | 2024 |
| `"suiide"` | 41-10-0021-01 | Aboriginal Peoples Survey, 2017 |
| `"lifeexp"` | 17-10-0160-01 | Projected life expectancy at birth |
| `"infmort"` | 17-10-0161-01 | Infant mortality |
| `"censuspop"` | 98-510-X2021001 | 2021 Census Indigenous Population Profile, population |
| `"censushh"` | 98-510-X2021016 | 2021 Census Indigenous Population Profile, households |

The 13-10-0924 excerpt is the table behind The Daily of 2025-02-13. The
full tables, and the other Indigenous-titled tables, are at the data
service: see
[`indtabs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indtabs.md).

> Some of this vignette concerns suicide. If you or someone you know
> needs support, the Hope for Wellness Help Line (1-855-242-3310, or the
> online chat at hopeforwellness.ca) offers counselling and crisis
> support to Indigenous people across Canada, in English and French, and
> in Cree, Ojibway and Inuktitut on request. You can also call or text
> 9-8-8.

### Whose data these are

Two sets of principles govern Indigenous data in Canada.

- **OCAP®** comes from the First Nations Information Governance Centre.
  It stands for Ownership, Control, Access and Possession. It says First
  Nations own their information and decide how it is collected, used and
  shared.
- **The CARE Principles** come from Carroll et al. (2020). They stand
  for Collective benefit, Authority to control, Responsibility and
  Ethics, and apply to Indigenous data everywhere.

Walter and Andersen (2013) set out what a quantitative methodology looks
like when it starts from Indigenous standpoints. Walter (2016) names the
pattern it pushes against: statistics about Indigenous peoples clustered
around five Ds, namely disparity, deprivation, disadvantage, dysfunction
and difference.

The package follows these principles in six ways.

- **Only open aggregate data.** The data service mirrors only aggregate
  tables published under the Statistics Canada Open Licence. It never
  holds First Nations-held survey data, such as the First Nations
  Regional Health Survey. Those are reached through the FNIGC, on its
  terms.
- **Distinctions-based.** First Nations, Metis and Inuit are reported
  separately. A pooled “Indigenous” total is marked wherever it appears.
  [`dstntst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md)
  shows when pooling would hide a difference.
- **Off-reserve coverage.** The First Nations figures in these surveys
  are for people living off reserve. Reserves are outside the surveys’
  coverage.
- **Suppressed cells stay suppressed.** A cell is suppressed (`x`) to
  protect the people in it, and small communities most of all. `F` cells
  are too unreliable to publish. Both become `NA`, and nothing in the
  package imputes them or works them back from totals.
- **Strengths beside gaps.** Wellness is reported beside distress, and
  [`frmaud()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/frmaud.md)
  checks how deficit-framed a report is.
- **A gap is not a deficit of the people.** A difference between groups
  measures the effects of colonial policy, the residential schools and
  unequal services. Report it with that context, and with the
  communities’ own interpretation where they have given one.

### Reading a table as published

A Statistics Canada table puts each estimate and its limits on separate
rows.
[`scests()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scests.md)
puts them side by side. It reads every layout the Indigenous tables use:

- confidence limits named in any of their forms;
- coefficients of variation, or standard errors, in place of limits;
- several measures per cell;
- tables with no limits at all.

``` r

d <- data.frame(REF_DATE = "2022", GEO = "Canada",
                `Indigenous identity` = rep(c("First Nations", "Metis"), each = 4),
                Statistics = rep(c("Number of persons", "Percent", "Low 95% confidence interval",
                                   "High 95% confidence interval"), 2),
                UOM = rep(c("Persons", "Percent", "Percent", "Percent"), 2),
                VALUE = c(415000, 47.1, 45.2, 49.0, 320000, 50.3, 48.1, 52.5),
                STATUS = "", check.names = FALSE)
scests(d)
#>   REF_DATE    GEO Indigenous identity           measure estimate lower upper
#> 1     2022 Canada       First Nations Number of persons 415000.0    NA    NA
#> 2     2022 Canada       First Nations           Percent     47.1  45.2  49.0
#> 3     2022 Canada               Metis Number of persons 320000.0    NA    NA
#> 4     2022 Canada               Metis           Percent     50.3  48.1  52.5
#>       cisou quality
#> 1      <NA>      ok
#> 2 published      ok
#> 3      <NA>      ok
#> 4 published      ok
```

A mirrored table loads by its id. This needs the data service key, so it
is not run here:

``` r

indtabs("mental health")
e <- scests("41100067")
```

### Perceived mental health, against non-Indigenous adults

The share of adults who rate their mental health very good or excellent,
2019/2022, from table 13-10-0924-01:

``` r

h <- indiex("health")
mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
          h$indicator == "Perceived mental health, very good or excellent", ]
g <- indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")
g
#>           group estimate refest     ratio   ratiolo   ratioup difference
#> 1 First Nations     45.8   61.5 0.7447154 0.7001926 0.7920694      -15.7
#> 2         Métis     52.8   61.5 0.8585366 0.8130217 0.9065995       -8.7
#> 3         Inuit     47.8   61.5 0.7772358 0.6785276 0.8903034      -13.7
#>       diflo      difup usewithcau poogrp
#> 1 -18.53593 -12.864070      FALSE  FALSE
#> 2 -11.58531  -5.814692      FALSE  FALSE
#> 3 -20.16568  -7.234321      FALSE  FALSE
plot(g)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-gap-1.png)

Before pooling the three groups into one “Indigenous” figure, test
whether they differ:

``` r

dt <- dstntst(mh[mh$group != "Non-Indigenous", ], "group", "estimate", "lower", "upper")
dt
#> Distinctions test across 3 groups: Q = 11.97 on 2 df, p = 0.00252, I^2 = 83%
#> Pooled (inverse-variance) 49.11; the groups differ: report each one, not the pooled figure
plot(dt)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-distinctions-1.png)

### The whole scale, not one cut of it

“Very good or excellent” cuts a five-point scale at one place (the table
publishes it in four categories, with fair and poor together).
[`ordcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md)
compares the whole distribution. It gives the probability that a person
in one group rates their mental health higher than a person in the
reference group, with ties counted half (Agresti 1980). The data are
from the 2022 Indigenous Peoples Survey, table 41-10-0067-01:

``` r

r <- indiex("mentalhealth")
r <- r[r$region == "Canada", ]
oc <- ordcmp(r, "group", "rating", "estimate", "lower", "upper",
                      lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
                      ref = "M\u00e9tis", qual = "quality")
oc
#>           group reference   probbet     lower     upper      delta     neff
#> 1 First Nations     Métis 0.4653023 0.4531475 0.4774984 -0.0693954 4021.444
#> 2         Inuit     Métis 0.5062337 0.4928231 0.5196353  0.0124674 2791.908
#>    neffref usewithcau poogrp
#> 1 3884.405      FALSE  FALSE
#> 2 3884.405      FALSE  FALSE
plot(oc)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-ordinal-1.png)

### Age standardisation

First Nations, Metis and Inuit populations are younger than the
non-Indigenous population, and many outcomes vary steeply with age.
[`stdprev()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md)
standardises survey percentages to one age structure. Here it is applied
to serious thoughts of suicide in the past year, from the 2017
Aboriginal Peoples Survey (table 41-10-0021-01):

``` r

si <- indiex("suicide")
si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" &
           si$age != "Total, 15 years and over", ]
si <- si[order(si$group, si$age), ]
sp <- stdprev(si$estimate, si$lower, si$upper, std = c(20, 18, 17, 17, 28),
                             grp = si$group, qual = si$quality)
sp
#>           group estimate    lower    upper        se usewithcau
#> 1 First Nations    5.792 5.141142 6.442858 0.3320767       TRUE
#> 2         Inuit    5.940 5.036123 6.843877 0.4611700       TRUE
#> 3         Métis    4.742 4.125043 5.358957 0.3147799       TRUE
plot(sp)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-prevalence-1.png)

For counts of events (deaths, hospitalisations),
[`agestd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md)
gives directly standardised rates with the Fay-Feuer gamma interval, and
[`rategap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rategap.md)
compares two of them.

### Wellness beside distress

Indigenous scholars of mental health describe it as wellness, and as a
process of healing, grounded in community, cultural identity, a holistic
view and interdependence (Stewart 2008). They ask that strengths be
reported together with disparities (Stewart 2020).

The estimators in this section and the next put that into how published
tables are analysed. They are our translation, inspired by that work,
not methods its authors state, and they say what they cannot show.

[`welprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)
puts wellness indicators first and distress after them. This example
uses the 2024 well-being table, 41-10-0082-01:

``` r

wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = c("Life satisfaction rating of 8, 9 or 10",
                                   "Sense of meaning and purpose rating of 8, 9 or 10",
                                   "Always or often has a hopeful outlook"),
                      distress = c("Life satisfaction rating between 0 and 5",
                                   "Rarely or never has a hopeful outlook"),
                      qual = "quality")
plot(w)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-wellness-1.png)

``` r

frmaud(w)
#> 40% of the indicators reported are deficit-framed.
```

[`dualcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md)
places each group on two axes, wellness and distress. They are related
but distinct (Keyes 2002, 2005):

``` r

dc <- dualcont(w, "Always or often has a hopeful outlook", "Life satisfaction rating between 0 and 5")
dc
#>           group wellness wello welup distress distrlo distrup strratio  ratiolo
#> 1 First Nations     50.2  45.9  54.5     31.4    27.4    35.7 1.598726 1.365446
#> 2         Métis     52.3  47.6  57.0     28.4    24.0    33.1 1.841549 1.531631
#> 3         Inuit     54.4  45.7  62.8     25.2    19.4    31.8 2.158730 1.609182
#>    ratioup usewithcau
#> 1 1.871862      FALSE
#> 2 2.214178      FALSE
#> 3 2.895953      FALSE
plot(dc)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-dual-1.png)

### Holistic balance

Wellness is a balance among the domains of a person; illness is a loss
of that balance (Stewart 2008; Gabriel, Mirza and Stewart 2022). An
average of domains cannot show balance.
[`holbal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md)
measures it as the ratio of the geometric mean of the domain levels to
their arithmetic mean. That ratio is 1 when every domain is level, and
falls as one domain falls behind the others.

Which indicator stands for each domain is a choice for the people whose
data these are to make. The choice below is one reading of it:

``` r

dom <- c("Perceived health, very good or excellent" = "physical",
         "Perceived mental health, very good or excellent" = "mental",
         "Life satisfaction, satisfied or very satisfied" = "emotional",
         "Sense of belonging to local community, somewhat strong or very strong" = "community")
d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator %in% names(dom), ]
d$domain <- dom[d$indicator]
hb <- holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality")
hb
#>            group  level    lvllo    lvlup   balance     ballo     balup
#> 1  First Nations 59.525 58.25190 60.79810 0.9641371 0.9582021 0.9696524
#> 2          Métis 63.725 62.43592 65.01408 0.9751839 0.9707913 0.9791662
#> 3          Inuit 63.800 60.74133 66.85867 0.9699605 0.9562503 0.9812743
#> 4 Non-Indigenous 69.800 69.60196 69.99804 0.9846768 0.9842679 0.9850811
#>     weadom usewithcau
#> 1 physical      FALSE
#> 2 physical      FALSE
#> 3   mental      FALSE
#> 4 physical      FALSE
plot(hb)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-balance-1.png)

A community that weighs the domains differently sets `weights`. The
result says which weights it used.

### The four directions

The First Nations Mental Wellness Continuum Framework (Health Canada and
Assembly of First Nations 2015) describes mental wellness in four
directions: hope, belonging, meaning and purpose.
[`mhcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mhcont.md)
lays out the published proxies for each direction. It says which
directions the tables do not measure, and does not fill them in:

``` r

mw <- mhcont(wb, "group", "indicator", "estimate", "lower", "upper",
        hope = "Always or often has a hopeful outlook",
        meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
        purp = "Sense of meaning and purpose rating of 8, 9 or 10", qual = "quality")
mw[, c("group", "indicator", "domain", "estimate", "shared")]
#>            group indicator                                            domain
#> 1  First Nations      hope             Always or often has a hopeful outlook
#> 2  First Nations belonging                                no published proxy
#> 3  First Nations   meaning Sense of meaning and purpose rating of 8, 9 or 10
#> 4  First Nations   purpose Sense of meaning and purpose rating of 8, 9 or 10
#> 5          Métis      hope             Always or often has a hopeful outlook
#> 6          Métis belonging                                no published proxy
#> 7          Métis   meaning Sense of meaning and purpose rating of 8, 9 or 10
#> 8          Métis   purpose Sense of meaning and purpose rating of 8, 9 or 10
#> 9          Inuit      hope             Always or often has a hopeful outlook
#> 10         Inuit belonging                                no published proxy
#> 11         Inuit   meaning Sense of meaning and purpose rating of 8, 9 or 10
#> 12         Inuit   purpose Sense of meaning and purpose rating of 8, 9 or 10
#>    estimate shared
#> 1      50.2  FALSE
#> 2        NA  FALSE
#> 3      47.5   TRUE
#> 4      47.5   TRUE
#> 5      52.3  FALSE
#> 6        NA  FALSE
#> 7      51.6   TRUE
#> 8      51.6   TRUE
#> 9      54.4  FALSE
#> 10       NA  FALSE
#> 11     50.5   TRUE
#> 12     50.5   TRUE
plot(mw)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-continuum-1.png)

### Healing as a process

A process shows in change.
[`healchg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/healchg.md)
gives the change between survey periods, wellness first. It uses the two
periods of table 13-10-0924-01:

``` r

hc <- healchg(h[h$age == "Total, 18 years and over", ], "group", "indicator", "period",
                     "estimate", "lower", "upper", from = "2015/2018", to = "2019/2022",
                     qual = "quality",
                     well = c("Perceived mental health, very good or excellent",
                                  "Sense of belonging to local community, somewhat strong or very strong"))
hc <- hc[hc$indicator %in% c("Perceived mental health, very good or excellent",
                             "Sense of belonging to local community, somewhat strong or very strong",
                             "Mood disorder", "Anxiety disorder"), ]
plot(hc)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-healing-1.png)

Between the two periods, which span the COVID-19 pandemic, the share
rating their mental health very good or excellent fell for First
Nations, Metis and non-Indigenous adults. The Inuit interval includes no
change. Because the reference group fell too, a group’s change is read
against the reference group’s change, not on its own.

### Connection across places

The land is “an instrumental part of all aspects of Indigenous life
including health and well-being” (Mashford-Pringle and Stewart 2019).
Health and education are interconnected (Mashford-Pringle 2016). Across
places, connections of this kind leave a trace: do two indicators rise
together where people live?

[`connassoc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/connassoc.md)
measures this with Spearman’s rho. Its p-value is exact for up to eight
places, and a Monte Carlo estimate beyond. Its band is a sensitivity
band, not a confidence interval: it shows how far the published sampling
error alone moves rho for these places. Here, by region, it asks whether
First Nations and Metis people’s mental health rise together, using
table 41-10-0067-01:

``` r

r <- indiex("mentalhealth")
r <- r[r$rating == "Excellent or very good" & r$region != "Canada", ]
pair <- merge(r[r$group == "First Nations", ], r[r$group == "M\u00e9tis", ], by = "region",
              suffixes = c("fn", "me"))
ca <- connassoc(pair, "region", "estimatefn", "estimateme", "lowerfn", "upperfn",
                             "lowerme", "upperme")
ca
#> Rank correlation across 11 places: rho = 0.52, permutation p = 0.106; with the published sampling error, 95% interval -0.19 to 0.77
#> An association across places: it does not show that one causes the other for any person.
plot(ca, xlab = "First Nations: excellent or very good (%)",
     ylab = "M\u00e9tis: excellent or very good (%)")
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-connection-1.png)

This is an association across places. It cannot say that one thing makes
a person well.

### Community-set weights, and the Community Well-Being index

[`commidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/commidx.md)
combines protective and risk factors with weights the community sets. It
follows the structure of Inuit Tapiriit Kanatami’s National Inuit
Suicide Prevention Strategy (2016). The function never chooses the
weights. A factor the tables do not publish leaves the index `NA`; it is
not filled in.

``` r

h2 <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
ci <- commidx(h2, "group", "indicator", "estimate", "lower", "upper", qual = "quality",
        w = c("Sense of belonging to local community, somewhat strong or very strong" = 2,
                    "Has a regular healthcare provider" = 1,
                    "Perceived life stress, most days quite a bit or extremely stressful" = -2,
                    "Heavy drinking" = -1))
plot(ci)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-community-1.png)

[`cwbscr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md)
computes Indigenous Services Canada’s Community Well-Being index from
census profile figures: income, education, housing and labour force
activity. The index measures socio-economic conditions only. It is not a
measure of wellness as First Nations and Inuit define it.

### The 2021 Census

The Indigenous Population Profile of the 2021 Census gives counts for
every geography, by gender, age group and about two thousand
characteristics, with First Nations, Metis, Inuit and non-Indigenous
people in their own columns. In the provincial table, residence on and
off reserve is split out too.
[`cnsprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md)
reads it with the hierarchy of the characteristics.
[`profshr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profshr.md)
takes a share with an interval for the 25% long-form sample and the
random rounding of the counts.

Foster children among children under 15, Canada, 2021:

``` r

p <- cnsprof(indiex("censuspop"))
fc <- profshr(p, "Foster children", "Total - Children in census families")
fc <- fc[fc$geo == "Canada" & fc$age == "0 to 14 years" &
           fc$group %in% c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous"), ]
fc[, c("residence", "group", "numerator", "denominator", "estimate", "lower", "upper")]
#>                               residence          group numerator denominator
#> 256 Total - Residence on or off reserve  First Nations     11735      265405
#> 257                          On reserve  First Nations      2350       90270
#> 258                         Off reserve  First Nations      9385      175135
#> 340 Total - Residence on or off reserve          Métis      1975      134670
#> 341                          On reserve          Métis        15         610
#> 342                         Off reserve          Métis      1960      134060
#> 424 Total - Residence on or off reserve          Inuit       770       21525
#> 425                          On reserve          Inuit        35         100
#> 426                         Off reserve          Inuit       735       21425
#> 676 Total - Residence on or off reserve Non-Indigenous     12705     5502310
#> 677                          On reserve Non-Indigenous        20        4070
#> 678                         Off reserve Non-Indigenous     12690     5498235
#>       estimate      lower      upper
#> 256  4.4215444  4.2880409  4.5590064
#> 257  2.6033012  2.5989608  2.6076487
#> 258  5.3587233  5.1789488  5.5443733
#> 340  1.4665479  1.3593905  1.5820167
#> 341  2.4590164  1.8933392  3.1882099
#> 342  1.4620319  1.3548094  1.5776046
#> 424  3.5772358  3.1713963  4.0328470
#> 425 35.0000000 30.9738945 39.2518422
#> 426  3.4305718  3.0324927  3.8788168
#> 676  0.2309030  0.2240599  0.2379546
#> 677  0.4914005  0.4040293  0.5975523
#> 678  0.2308013  0.2239573  0.2378541
plot(fc[fc$residence == "Total - Residence on or off reserve", ])
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-census-foster-1.png)

The overrepresentation of First Nations, Metis and Inuit children in
care is the subject of the first five Calls to Action of the Truth and
Reconciliation Commission.

Knowledge of an Indigenous language (all ages):

``` r

know <- "Total - Knowledge of Indigenous languages for the population in private households - 25% sample data"
la <- profshr(p, "Indigenous languages", know)
la[la$geo == "Canada" & la$age == "Total - Age groups" & la$residence == "Total - Residence on or off reserve" &
     la$group %in% c("First Nations", "M\u00e9tis", "Inuit"), c("group", "estimate", "lower", "upper")]
#>             group  estimate    lower     upper
#> 379 First Nations 17.530439 17.40473 17.656859
#> 505         Métis  1.332062  1.28369  1.382232
#> 631         Inuit 58.130139 57.49824 58.759377
```

The census age structure of the Indigenous population is the standard to
use when age-standardising First Nations, Metis and Inuit rates (Kumar
and Tjepkema 2019):

``` r

cnsstd(p)
#>                  age population     weight
#> 1       0 to 4 years     137510 0.07608819
#> 2       5 to 9 years     155565 0.08607853
#> 3     10 to 14 years     166135 0.09192722
#> 4     15 to 19 years     148820 0.08234633
#> 5     20 to 24 years     136070 0.07529140
#> 6     25 to 34 years     263655 0.14588780
#> 7     35 to 44 years     217990 0.12062006
#> 8     45 to 54 years     206360 0.11418485
#> 9     55 to 64 years     202785 0.11220670
#> 10    65 to 74 years     119410 0.06607295
#> 11 75 years and over      52945 0.02929597
```

A Community Well-Being score from the public profile (income, education,
housing, labour force), by distinction. The household table splits
Indigenous from non-Indigenous households only, so First Nations, Metis
and Inuit people share the Indigenous households’ housing component.
[`?cnscwb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnscwb.md)
explains where it departs from the Department’s own index:

``` r

h <- cnsprof(indiex("censushh"))
cw <- cnscwb(p, h)
cw[cw$geo %in% c("Canada", "Nunavut"), c("geo", "group", "income", "education", "housing", "labour", "cwb")]
#>        geo          group    income education  housing labour      cwb
#> 1   Canada  First Nations  71.03051  51.62081 91.87864  75.85 72.59499
#> 2   Canada          Métis  78.72661  59.55861 91.87864  83.15 78.32846
#> 3   Canada          Inuit  72.12712  38.50607 91.87864  74.75 69.31546
#> 4   Canada Non-Indigenous  84.37515  68.01121 95.98845  86.30 83.66870
#> 53 Nunavut  First Nations        NA        NA       NA     NA       NA
#> 54 Nunavut          Métis        NA        NA       NA     NA       NA
#> 55 Nunavut          Inuit  70.22000  28.49462 70.82270  69.85 59.84683
#> 56 Nunavut Non-Indigenous 100.00000  79.89287 93.30144  94.85 92.01108
plot(cw)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-census-cwb-1.png)

### Intergenerational exposure

Studies of the residential schools ask whether harm passes down
families. Among them are Bombay, Matheson and Anisman (2014), Kaspar
(2014), Hackett, Feeny and Tompa (2016), and McQuaid et al. (2017).

- [`genexpo()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/genexpo.md)
  codes how many of the two generations before a respondent attended. An
  unknown generation stays unknown.
- [`exptrnd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exptrnd.md)
  gives the odds ratio at each level, and the Cochran-Armitage test for
  a trend.

The counts below are made up, to show the computation:

``` r

genexpo(parent = c(TRUE, FALSE, TRUE, NA), gparent = c(TRUE, FALSE, FALSE, TRUE))
#> [1]  2  0  1 NA
et <- exptrnd(cases = c(60, 95, 70), n = c(500, 520, 300))
plot(et)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-generations-1.png)

Individual-level data of this kind belong to the communities who
collected them. These functions are for analyses done under their
authority, or on tables they have published.

### The Calls to Action

Call to Action 19 asks for “measurable goals to identify and close the
gaps in health outcomes between Aboriginal and non-Aboriginal
communities”, for indicators that include infant mortality, suicide,
mental health, addictions, life expectancy and chronic diseases.
[`trcind()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcind.md)
lists which published table measures each of them.
[`trchlthgap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trchlthgap.md)
measures every gap against non-Indigenous people on one scale, the
disadvantage ratio: the ratio of the two estimates, turned so that above
1 means the group fares worse, with its interval. It is a ratio of
published estimates, not a relative risk.

``` r

g <- trchlthgap()
g[g$measure %in% c("Life expectancy at birth", "Infant mortality rate"),
  c("measure", "period", "group", "estimate", "refest", "disratio", "lower", "upper")]
#>                     measure    period
#> 34 Life expectancy at birth 2016/2021
#> 35 Life expectancy at birth 2016/2021
#> 36 Life expectancy at birth 2016/2021
#> 37 Life expectancy at birth 2016/2021
#> 38 Life expectancy at birth 2016/2021
#> 39 Life expectancy at birth 2016/2021
#> 40    Infant mortality rate 2014/2016
#> 41    Infant mortality rate 2014/2016
#> 42    Infant mortality rate 2014/2016
#> 43    Infant mortality rate 2014/2016
#> 44    Infant mortality rate 2014/2016
#>                                                group estimate refest disratio
#> 34                                             Métis    80.47  84.99 1.056170
#> 35                                             Inuit    71.91  84.99 1.181894
#> 36              First Nations (Registered or Treaty)    73.98  84.99 1.148824
#> 37  First Nations (Registered or Treaty), on reserve    71.42  84.99 1.190003
#> 38 First Nations (Registered or Treaty), off reserve    76.04  84.99 1.117701
#> 39          First Nations, without registered status    79.23  84.99 1.072700
#> 40                                             Métis     5.20   4.20 1.238095
#> 41                                             Inuit    13.50   4.20 3.214286
#> 42              First Nations (Registered or Treaty)     9.60   4.20 2.285714
#> 43  First Nations (Registered or Treaty), on reserve    10.00   4.20 2.380952
#> 44 First Nations (Registered or Treaty), off reserve     8.10   4.20 1.928571
#>        lower    upper
#> 34 1.0497867 1.062592
#> 35 1.1636936 1.200379
#> 36 1.1433513 1.154323
#> 37 1.1833943 1.196648
#> 38 1.1078697 1.127620
#> 39 1.0617669 1.083745
#> 40 0.8366176 1.832235
#> 41 2.0315414 5.085613
#> 42 1.7776500 2.938987
#> 43 1.4796282 3.831323
#> 44 1.3632810 2.728262
plot(g)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-trc-gaps-1.png)

Life expectancy at birth in 2016/2021 was 71.4 years for First Nations
people living on reserve and 71.9 for Inuit, against 85.0 for
non-Indigenous people. Infant mortality among Inuit was 13.5 per 1,000
live births in 2014/2016, against 4.2.

How fast the Calls themselves are being completed:

The Truth and Reconciliation Commission made 94 Calls to Action in 2015.
[`trccmpl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trccmpl.md)
holds the number completed each year, as the Yellowhead Institute counts
them (Jewell and Mosby 2021, 2022).
[`trcprog()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md)
takes that pace as a Poisson rate:

``` r

p <- trcprog()
p
#>   completed remaining years     rate    ratelo   rateup   cmplby cmplbyearly
#> 1        13        81  7.04 1.846591 0.9832319 3.157727 2066.865    2048.651
#>   cmplbylate
#> 1   2105.381
plot(p)
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-trc-1.png)

The projection only extends the pace so far. It is not a forecast.

### Cultural continuity

Chandler and Lalonde (1998) found that British Columbia First Nations
communities with more markers of cultural continuity had far fewer youth
suicides. Hallett, Chandler and Lalonde (2007) found the same for
knowledge of an Indigenous language. Their unit was the community.
Across provinces and territories, the published tables allow a coarser
question: where more First Nations people know an Indigenous language,
do more rate their mental health highly?

``` r

prof <- cnsprof(indiex("censuspop"))
la <- profshr(prof, "Indigenous languages", know)
la <- la[la$age == "Total - Age groups" & la$group == "First Nations" & la$geo != "Canada" &
           la$residence == "Total - Residence on or off reserve", ]
mh2 <- indiex("mentalhealth")
mh2 <- mh2[mh2$rating == "Excellent or very good" & mh2$group == "First Nations", ]
both <- merge(la[c("geo", "estimate", "lower", "upper")], mh2[c("region", "estimate", "lower", "upper")],
              by.x = "geo", by.y = "region", suffixes = c("lang", "mh"))
cc <- connassoc(both, "geo", "estimatelang", "estimatemh", "lowerlang", "upperlang",
                             "lowermh", "uppermh")
cc
#> Rank correlation across 8 places: rho = 0.47, exact p = 0.247; with the published sampling error, 95% interval -0.31 to 0.79
#> An association across places: it does not show that one causes the other for any person.
plot(cc, xlab = "First Nations who know an Indigenous language (%)",
     ylab = "First Nations: mental health excellent or very good (%)")
```

![](applied-analyses_files/figure-html/first-nations-metis-inuit-health-continuity-1.png)

Across these eight provinces and territories, the rank correlation is
positive but far from settled: its exact p-value is large and its
sensitivity band includes zero. That is not evidence for or against the
communities’ findings. Eight places are far too few, a province mixes
many communities, and the two measures come from different surveys and
years. The community-level design needs the census profile of each First
Nations community (98-510-X2021002 at the data service), and outcomes
measured for the same communities.

### Your own data

Nothing here is tied to Canada or to these tables. Each estimator takes
a data frame with a group column, an estimate and its limits. A table
from another agency needs two steps first: limits from whatever it
publishes in their place
([`limfrom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/limfrom.md)
takes a standard error, a coefficient of variation or a margin of
error), and its quality flags mapped onto suppressed and
use-with-caution
([`qltyrcd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/qltyrcd.md)).
Here, made-up numbers in an Australian layout, with relative standard
errors and that agency’s flags:

``` r

own <- data.frame(group = c("Aboriginal", "Torres Strait Islander", "Non-Indigenous Australians"),
                  pct = c(31.2, 27.5, 18.9), rse = c(4.1, 22.0, 1.2), flag = c("", "*", ""))
own <- cbind(own, limfrom(own$pct, cv = own$rse)[c("lower", "upper")])
own$quality <- qltyrcd(own$flag, suppr = "**", caution = "*")
indgap(own, "group", "pct", "lower", "upper", ref = "Non-Indigenous Australians",
               qual = "quality")
#>                    group estimate refest    ratio   ratiolo  ratioup difference
#> 1             Aboriginal     31.2   18.9 1.650794 1.5179467 1.795267       12.3
#> 2 Torres Strait Islander     27.5   18.9 1.455026 0.9167364 2.309390        8.6
#>       diflo    difup usewithcau poogrp
#> 1  9.753713 14.84629      FALSE  FALSE
#> 2 -3.266111 20.46611       TRUE  FALSE
```

Name the groups as the peoples concerned name themselves, and give
`pooled` any row that pools several of them, so it is never set beside
its own parts.

### What the package does not compute

Some instruments are individual questionnaires, and aggregate tables
cannot reproduce them:

- the Native Wellness Assessment (Fiedeldey-Van Dijk et al. 2017);
- the Cultural Connectedness Scale (Snowshoe et al. 2015);
- the Historical Loss Scale (Whitbeck et al. 2004).

Two-Eyed Seeing (Bartlett, Marshall and Marshall 2012) is a way of
bringing knowledges together, not a formula. The package follows it by
reporting results beside one another without merging them into one index
([`dualcont()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md),
[`welprof()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)).

### Acknowledgements

The estimators for holistic balance, wellness beside distress, the four
directions, healing as a process and connection across places put to
quantitative use the frameworks of Professor Suzanne Stewart
(Yellowknives Dene First Nation), Director of the Waakebiness-Bryce
Institute for Indigenous Health at the University of Toronto’s Dalla
Lana School of Public Health, and Professor Angela Mashford-Pringle
(Timiskaming First Nation), its Associate Director. This work stands on
theirs. Any error in turning their qualitative work into estimators is
the package’s, not theirs.

### References

- Agresti A (1980). Generalized odds ratios for ordinal data.
  *Biometrics* 36(1):59-67.
- Bartlett C, Marshall M, Marshall A (2012). Two-Eyed Seeing and other
  lessons learned within a co-learning journey of bringing together
  indigenous and mainstream knowledges and ways of knowing. *Journal of
  Environmental Studies and Sciences* 2(4):331-340.
- Bombay A, Matheson K, Anisman H (2014). The intergenerational effects
  of Indian Residential Schools: implications for the concept of
  historical trauma. *Transcultural Psychiatry* 51(3):320-338.
- Chandler MJ, Lalonde C (1998). Cultural continuity as a hedge against
  suicide in Canada’s First Nations. *Transcultural Psychiatry*
  35(2):191-219.
- Carroll SR, Garba I, Figueroa-Rodriguez OL, et al. (2020). The CARE
  Principles for Indigenous Data Governance. *Data Science Journal*
  19:43.
- Fiedeldey-Van Dijk C, Rowan M, Dell C, et al. (2017). Honoring
  Indigenous culture-as-intervention: development and validity of the
  Native Wellness Assessment. *Journal of Ethnicity in Substance Abuse*
  16(2):181-218.
- Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and
  holistic healing through the life stories of Indigenous youth who have
  experienced homelessness. *International Journal of Environmental
  Research and Public Health* 19(20):13402.
- Hackett C, Feeny D, Tompa E (2016). Canada’s residential school
  system: measuring the intergenerational impact of familial attendance
  on health and mental health outcomes. *Journal of Epidemiology and
  Community Health* 70(11):1096-1105.
- Hallett D, Chandler MJ, Lalonde CE (2007). Aboriginal language
  knowledge and youth suicide. *Cognitive Development* 22(3):392-399.
- Health Canada, Assembly of First Nations (2015). *First Nations Mental
  Wellness Continuum Framework*.
- Inuit Tapiriit Kanatami (2016). *National Inuit Suicide Prevention
  Strategy*.
- Jewell E, Mosby I (2021, 2022). *Calls to Action Accountability*.
  Yellowhead Institute.
- Kaspar V (2014). The lifetime effect of residential school attendance
  on Indigenous health status. *American Journal of Public Health*
  104(11):2184-2190.
- Keyes CLM (2002). The mental health continuum: from languishing to
  flourishing in life. *Journal of Health and Social Behavior*
  43(2):207-222.
- Keyes CLM (2005). Mental illness and/or mental health? Investigating
  axioms of the complete state model of health. *Journal of Consulting
  and Clinical Psychology* 73(3):539-548.
- Mashford-Pringle A (2016). Aboriginal health and Aboriginal education
  are interconnected. *Research in the Sociology of Health Care*
  34:85-96.
- Mashford-Pringle A, Stewart SL (2019). Akiikaa (it is the land):
  exploring land-based experiences with university students in Ontario.
  *Global Health Promotion* 26(3 suppl):64-72.
- McQuaid RJ, Bombay A, McInnis OA, et al. (2017). Suicide ideation and
  attempts among First Nations peoples living on-reserve in Canada: the
  intergenerational and cumulative effects of Indian Residential
  Schools. *Canadian Journal of Psychiatry* 62(6):422-430.
- Snowshoe A, Crooks CV, Tremblay PF, Craig WM, Hinson RE (2015).
  Development of a Cultural Connectedness Scale for First Nations youth.
  *Psychological Assessment* 27(1):249-259.
- Stewart SL (2008). Promoting Indigenous mental health: cultural
  perspectives on healing from Native counsellors in Canada.
  *International Journal of Health Promotion and Education* 46(2):49-56.
- Stewart S (2020). Addressing strengths and disparities in Indigenous
  health. *International Journal of Indigenous Health* 15(1):4.
- Walter M (2016). Data politics and Indigenous representation in
  Australian statistics. In Kukutai T, Taylor J (eds), *Indigenous Data
  Sovereignty: Toward an Agenda*, 79-97. ANU Press.
- Walter M, Andersen C (2013). *Indigenous Statistics: A Quantitative
  Research Methodology*. Left Coast Press.
- Whitbeck LB, Adams GW, Hoyt DR, Chen X (2004). Conceptualizing and
  measuring historical trauma among American Indian people. *American
  Journal of Community Psychology* 33(3-4):119-130.

## Search and rescue: detection, coverage and the best use of effort

Search theory began with Koopman’s work for the U.S. Navy (1946) and is
how search and rescue services plan a search: how likely a sensor is to
see the object at a given distance, how much ground a search covers, how
likely the object is to be in each area, and where a limited effort does
the most good. Frost’s *The Theory of Search: A Simplified Explanation*
(1996) explains it for search planners in four chapters of figures. This
vignette walks those chapters and draws every one of the book’s 36
figures with
[`srchfig()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/srchfig.md),
which builds each from the package’s functions with the book’s
parameters.
[`srchfig()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/srchfig.md)
with no argument lists them and says how each is drawn: from the model,
as a schematic, or as an approximation where the book’s plate cannot be
recovered exactly.

``` r

table(srchfig()$how)
#> 
#> approximation         model     schematic 
#>             3            29             4
```

The functions behind the figures work on any inputs:
[`ltrlrng()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
(lateral range curves),
[`swpwdth()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
(sweep width),
[`srchpod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
and
[`pswppod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
(probability of detection),
[`srchscs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
(probability of success and the update after a search),
[`datumpmap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
(where the object may be),
[`opteffort()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md),
[`optcrcsrch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
and
[`optsqr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/optsqr.md)
(the best use of effort).

### Chapter 3: datums and probability maps

**Figure 3-1.** A point datum is a circular normal distribution of
possible positions. The probability that the object is within `R`
standard deviations of the datum is `POC = 1 - exp(-R^2 / 2)`.

``` r

srchfig("3-1")
```

![](applied-analyses_files/figure-html/search-and-rescue-f31-1.png)

**Figures 3-2, 3-3 and 3-5.** The square circumscribed about a circle of
radius `R` holds `(2 Phi(R) - 1)^2` of the distribution: 47% for one
standard deviation, 58% for the total probable error of position
`E = sqrt(2 ln 2) = 1.1774` standard deviations (the radius holding
50%), and 65% for the simplified method’s first search radius of 1.1
`E`.

``` r

srchfig("3-2")
```

![](applied-analyses_files/figure-html/search-and-rescue-f32-1.png)

``` r

srchfig("3-3")
```

![](applied-analyses_files/figure-html/search-and-rescue-f32-2.png)

``` r

srchfig("3-5")
```

![](applied-analyses_files/figure-html/search-and-rescue-f32-3.png)

**Figure 3-4.** A probability map lays a grid over the distribution.
With cells `2E` wide the centre holds 57.91%, a side cell 9.08% and a
corner 1.42%.

``` r

srchfig("3-4")
```

![](applied-analyses_files/figure-html/search-and-rescue-f34-1.png)

**Figures 3-6 and 3-7.** The simplified method extended a point datum to
a line by drawing circles at the two end points and boxing them in. The
density this implies is drawn as a circular normal spread along the
segment (`datum = "line"`), an approximation of the book’s plate.

``` r

srchfig("3-6")
```

![](applied-analyses_files/figure-html/search-and-rescue-f36-1.png)

``` r

srchfig("3-7")
```

![](applied-analyses_files/figure-html/search-and-rescue-f36-2.png)

**Figures 3-8 to 3-10.** A simpler line datum is normal across the line
and uniform along it, with nothing beyond its ends
(`datum = "corridor"`). A strip one standard deviation either side holds
68%, a strip of `2E` holds 76.1%, and dividing strips into cells along
the line gives the completed map of figure 3-10.

``` r

srchfig("3-8")
```

![](applied-analyses_files/figure-html/search-and-rescue-f38-1.png)

``` r

srchfig("3-9")
```

![](applied-analyses_files/figure-html/search-and-rescue-f38-2.png)

``` r

srchfig("3-10")
```

![](applied-analyses_files/figure-html/search-and-rescue-f38-3.png)

**Figures 3-11 and 3-12.** An area datum spreads the probability evenly:
each of 20 equal cells holds 5%.

``` r

srchfig("3-11")
```

![](applied-analyses_files/figure-html/search-and-rescue-f311-1.png)

``` r

srchfig("3-12")
```

![](applied-analyses_files/figure-html/search-and-rescue-f311-2.png)

**Figures 3-13 and 3-14.** A generalized datum takes the planner’s own
cell probabilities (`datum = "general"`, `wts =`). The book’s surface is
illustrative; here it is drawn from the cells of figure 3-14.

``` r

srchfig("3-13")
```

![](applied-analyses_files/figure-html/search-and-rescue-f313-1.png)

``` r

srchfig("3-14")
```

![](applied-analyses_files/figure-html/search-and-rescue-f313-2.png)

### Chapter 4: lateral range curves and sweep width

**Figure 4-1.** A lateral range curve `p(x)` is the probability of
detecting an object that passes at distance `x` from the track. The
sweep width is its area, `W = integral of p(x) dx`; the dashed
rectangles have the same area.

``` r

srchfig("4-1")
```

![](applied-analyses_files/figure-html/search-and-rescue-f41-1.png)

**Figures 4-2 and 4-3.** A definite range sensor sees everything within
`W / 2` of its track and nothing beyond: it sweeps a strip exactly `W`
wide.

``` r

srchfig("4-2")
```

![](applied-analyses_files/figure-html/search-and-rescue-f42-1.png)

``` r

srchfig("4-3")
```

![](applied-analyses_files/figure-html/search-and-rescue-f42-2.png)

**Figures 4-4 and 4-5.** The M-Beta curve has height `M` over a width of
`W / M`; with `M = 0.5` and `M = 0.25` the sweep width is unchanged.

``` r

srchfig("4-4")
```

![](applied-analyses_files/figure-html/search-and-rescue-f44-1.png)

``` r

srchfig("4-5")
```

![](applied-analyses_files/figure-html/search-and-rescue-f44-2.png)

**Figures 4-6 and 4-7.** Koopman’s inverse cube law takes the chance of
a glimpse to be proportional to the solid angle of the wake,
`k h / r^3`, which gives `p(x) = 1 - exp(-W^2 / (4 pi x^2))`. Its sweep
width is `W`: the objects missed inside the sweep width (A) balance
those seen outside it (B).

``` r

srchfig("4-6")
```

![](applied-analyses_files/figure-html/search-and-rescue-f46-1.png)

``` r

srchfig("4-7")
swpwdth(ltrlrng(seq(-500, 500, by = 0.01), W = 1))
#> [1] 0.9996817
```

![](applied-analyses_files/figure-html/search-and-rescue-f46-2.png)

### Chapter 5: effort, coverage and probability of detection

**Figure 5-1.** Search effort is sweep width times track length,
`Z = W L`, and coverage is effort over area, `C = Z / A`. A search whose
path is random gives `POD = 1 - exp(-C)`.

``` r

srchfig("5-1")
```

![](applied-analyses_files/figure-html/search-and-rescue-f51-1.png)

**Figures 5-2 to 5-5.** A parallel sweep at track spacing `S` has
coverage `C = W / S`. With a definite range sensor the POD is
`min(C, 1)`: half the gap is seen at `S = 2W`, all of it at `S = W`.

``` r

srchfig("5-2")
```

![](applied-analyses_files/figure-html/search-and-rescue-f52-1.png)

``` r

srchfig("5-3")
```

![](applied-analyses_files/figure-html/search-and-rescue-f52-2.png)

``` r

srchfig("5-4")
```

![](applied-analyses_files/figure-html/search-and-rescue-f52-3.png)

``` r

srchfig("5-5")
```

![](applied-analyses_files/figure-html/search-and-rescue-f52-4.png)

**Figures 5-6 and 5-7.** M-Beta curves overlap once the tracks are
closer than their width: `POD = C` below `C = M` and
`1 - (1 - M)^(C / M)` above it, 0.75 and 0.6836 at coverage 1 for
`M = 0.5` and `M = 0.25`, nearer the random search curve as `M` falls.

``` r

srchfig("5-6")
```

![](applied-analyses_files/figure-html/search-and-rescue-f56-1.png)

``` r

srchfig("5-7")
```

![](applied-analyses_files/figure-html/search-and-rescue-f56-2.png)

``` r

srchpod(c(0.5, 1, 2), "mbeta", m = 0.25)
#> ── Probability of detection ────────────────────────────────────── 
#>   M-Beta model, M = 0.25
#> 
#>  coverage      pod
#>       0.5 0.437500
#>       1.0 0.683594
#>       2.0 0.899887
#> ──────────────────────────────────────────────────────────────────
```

**Figure 5-8.** The inverse cube parallel sweep gives
`POD = erf(sqrt(pi) C / 2)`, 0.7899 at coverage 1, between the definite
range and random search curves.
[`pswppod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
computes the same sweep directly, for any curve.

``` r

srchfig("5-8")
```

![](applied-analyses_files/figure-html/search-and-rescue-f58-1.png)

``` r

pswppod(W = 1, S = 1)
#> [1] 0.7899086
```

**Figure 5-9.** Poorer conditions shrink the sweep width, and a
cross-track navigation error of standard deviation `sigma` flattens the
curve: the expected curve is the convolution
`phi(x) = integral of p(x - t) Z(t, sigma) dt`, whose area is still `W`
(`ltrlrng(..., navsd = )`). The plate is blank in the published file; it
is drawn from the text.

``` r

srchfig("5-9")
```

![](applied-analyses_files/figure-html/search-and-rescue-f59-1.png)

### Chapter 6: optimal search

**Figures 6-1 and 6-2.** With half the probability in a 3 by 3 square
inside a 5 by 5 one and effort for half the area, the trial squares of
the whole area, half of it and a third of it hold 100%, 60.94% and
46.30%; at coverage 1 the middle trial succeeds most often.

``` r

srchfig("6-1")
```

![](applied-analyses_files/figure-html/search-and-rescue-f61-1.png)

``` r

srchfig("6-2")
```

![](applied-analyses_files/figure-html/search-and-rescue-f61-2.png)

**Figures 6-3 and 6-4.** For a point datum,
[`optsqr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/optsqr.md)
finds the square that an effort, spread evenly, should cover: the search
factor is its half side in units of `E`. An effort of `4 E^2` gives a
factor of 1.02, coverage 0.96 and POS 0.4578, as the book’s program
found.

``` r

optsqr(4)
#>   search effort releff cumeff   factor     side       poc  coverage       pod
#> 1      1      4      4      4 1.021043 2.042086 0.5939919 0.9592059 0.7707087
#>         pos    cumpos
#> 1 0.4577947 0.4577947
srchfig("6-3")
```

![](applied-analyses_files/figure-html/search-and-rescue-f63-1.png)

``` r

srchfig("6-4")
```

![](applied-analyses_files/figure-html/search-and-rescue-f63-2.png)

**Figure 6-5.** By the additive principle, a series of searches each
optimal for what the earlier ones left does as well as one optimal
search with all the effort: the cumulative probability of success
depends on the cumulative effort.

``` r

srchfig("6-5")
```

![](applied-analyses_files/figure-html/search-and-rescue-f65-1.png)

**Figure 6-6.** Searching in a series with random efforts between 0.1
and 50 `E^2`, the optimal factors cluster around the curve, except where
a much smaller effort follows a large one and the best use of it is the
remaining central peak.

``` r

srchfig("6-6")
```

![](applied-analyses_files/figure-html/search-and-rescue-f66-1.png)

### On a grid of your own

The same functions take any grid and datum.
[`opteffort()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
spreads a total track length over the cells to make the probability of
success as large as possible (Stone 1975), and
[`srchscs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)
updates the containment after a search that finds nothing.

``` r

m <- datumpmap(seq(-6, 6, by = 0.5), seq(-6, 6, by = 0.5), sigma = 2)
a <- opteffort(m, W = 1, effort = 30)
a$pos
#> [1] 0.455821
optcrcsrch(sigma = 2, W = 1, effort = 30)$pos
#> [1] 0.4571532
plot(a)
```

![](applied-analyses_files/figure-html/search-and-rescue-grid-1.png)

``` r

srchscs(c(0.5, 0.3, 0.2), c(0.8, 0.5, 0))
#> ── Probability of success ──────────────────────────────────────── 
#>   POS 0.55 after 1 search
#> 
#>  area poc cumpod posarea pocupd
#>     1 0.5    0.8    0.40 0.2222
#>     2 0.3    0.5    0.15 0.3333
#>     3 0.2    0.0    0.00 0.4444
#> ──────────────────────────────────────────────────────────────────
```

### References

Frost, J. R. (1996). The Theory of Search: A Simplified Explanation.
Soza and Company and U.S. Coast Guard Office of Search and Rescue.
Chapters 3-6 and their figures.

Koopman, B. O. (1946). Search and Screening. OEG Report 56, Office of
the Chief of Naval Operations.

Koopman, B. O. (1956-1957). The theory of search, parts I-III.
Operations Research 4(3), 324-346; 4(5), 503-531; 5(5), 613-626.

Stone, L. D. (1975). Theory of Optimal Search. Academic Press.
