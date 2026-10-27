# Complex survey estimation

A survey respondent stands for many people, and not the same number
each: the final weight says how many. The weights fix the estimate; the
design (how the sample was drawn) fixes its uncertainty, and ignoring it
usually understates the interval.
[`svydes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svydes.md)
records the design,
[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
gives means, totals, proportions and ratios with design-based standard
errors, and
[`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md)
tests differences between groups.

## Two ways to the variance

Public-use files from Statistics Canada and Health Canada ship
**replicate weights**: hundreds of alternative weight columns, each a
resampled version of the design. The estimate is recomputed under each
and the spread of those estimates is the variance. Other surveys ship
the **strata and primary sampling units** (PSUs), and the variance comes
from Taylor linearization.

``` r

set.seed(1)
n <- 600
d <- data.frame(
  region = sample(c("north", "south", "east"), n, replace = TRUE),
  age = sample(c("15-24", "25-49", "50+"), n, replace = TRUE),
  used = rbinom(n, 1, 0.3),
  drinks = rpois(n, 3),
  w = runif(n, 40, 160)
)
# a stratified design: variance by linearization
lin <- svydes(d, w = "w", strata = "region")
lin
#> ╭── Survey design ────────────────────────────────────────────────────────╮
#> │   Respondents         600                                               │
#> │   Sum of weights      60,110                                            │
#> │   Variance            Taylor linearization                              │
#> │   Strata              3                                                 │
#> │   PSUs                600                                               │
#> │   Lonely PSUs         fail                                              │
#> │   Degrees of freedom  597                                               │
#> │                                                                         │
#> │   svyest() and svycmp() use this design for every estimate: the weights │
#> │   for the point estimate, the strata and PSUs for its standard error.   │
#> ╰─────────────────────────────────────────────────────────────────────────╯
# a replicate design: 200 bootstrap weights, made here by resampling within
# region
reps <- vapply(1:200, function(r) {
  m <- numeric(n)
  for (g in unique(d$region)) {
    i <- which(d$region == g)
    m[i] <- tabulate(sample(length(i), replace = TRUE), length(i)) *
      length(i) /
      (length(i) - 1)
  }
  d$w * m
}, numeric(n))
repdes <- svydes(d, w = "w", reps = reps, type = "bootstrap")
repdes
#> ╭── Survey design ────────────────────────────────────────────────────────╮
#> │   Respondents         600                                               │
#> │   Sum of weights      60,110                                            │
#> │   Variance            bootstrap replicate weights                       │
#> │   Replicates          200                                               │
#> │   Scale               0.005                                             │
#> │   Centring            on the full-sample estimate                       │
#> │   Lonely PSUs         fail                                              │
#> │   Degrees of freedom  199                                               │
#> │                                                                         │
#> │   svyest() and svycmp() use this design for every estimate: the weights │
#> │   for the point estimate, the replicate weights for its standard error. │
#> ╰─────────────────────────────────────────────────────────────────────────╯
```

## Estimates by domain

A domain (a region, an age group) is estimated inside the whole design:
a respondent outside it counts zero, but stays in the design. That is
what makes the subgroup’s variance right.

``` r

e <- svyest(repdes, d, "used", by = "age", stat = "proportion", lvls = "1")
e
#> ╭── Survey proportion of used by age ────────────────────────────────────╮
#> │   Variable  used                                                       │
#> │   Domains   age                                                        │
#> │   Variance  bootstrap                                                  │
#> │   Interval  95% wilson                                                 │
#> │                                                                        │
#> │   age    level  estimate       se  95% CI               cv    n        │
#> │   -----  -----  --------  -------  ----------------  -----  ---        │
#> │   15-24  1        0.3681  0.03560  [0.3018, 0.4398]   9.67  206        │
#> │   25-49  1        0.2967  0.03063  [0.2375, 0.3635]  10.32  199        │
#> │   50+    1        0.2333  0.03067  [0.1790, 0.2982]  13.15  195        │
#> │                                                                        │
#> │   Highest proportion: 15-24 (0.3681); lowest: 50+ (0.2333). Their      │
#> │   intervals do not overlap: the gap is more than sampling error. Every │
#> │   cv is below 16.6 (the largest 13.1): precise enough to publish.      │
#> │                                                                        │
#> │   cv is the coefficient of variation (the standard error as a          │
#> │   percentage of the estimate); from 16.6 to 33.3 use the estimate with │
#> │   caution, above 33.3 it is too unstable to publish, by Statistics     │
#> │   Canada's usual bands.                                                │
#> ╰────────────────────────────────────────────────────────────────────────╯
plot(e)
```

![](survey-estimation_files/figure-html/survey-estimation-estimate-1.png)

``` r

svyest(lin, d, "drinks", by = "region")
#> ╭── Survey mean of drinks by region ─────────────────────────────────────╮
#> │   Variable  drinks                                                     │
#> │   Domains   region                                                     │
#> │   Variance  linearization                                              │
#> │   Interval  95% wald                                                   │
#> │                                                                        │
#> │   region  estimate      se  95% CI             cv    n                 │
#> │   ------  --------  ------  --------------  -----  ---                 │
#> │   east       2.857  0.1245  [2.614, 3.101]  4.356  186                 │
#> │   north      2.822  0.1254  [2.577, 3.068]  4.442  220                 │
#> │   south      3.046  0.1282  [2.794, 3.297]  4.210  194                 │
#> │                                                                        │
#> │   Highest mean: south (3.046); lowest: north (2.822). Their intervals  │
#> │   overlap: the data cannot tell the two apart. Every cv is below 16.6  │
#> │   (the largest 4.44): precise enough to publish.                       │
#> │                                                                        │
#> │   cv is the coefficient of variation (the standard error as a          │
#> │   percentage of the estimate); from 16.6 to 33.3 use the estimate with │
#> │   caution, above 33.3 it is too unstable to publish, by Statistics     │
#> │   Canada's usual bands.                                                │
#> ╰────────────────────────────────────────────────────────────────────────╯
```

Proportions get the modified Wilson interval of SAS PROC SURVEYFREQ (the
effective sample size $`n/\mathrm{Deff}`$, adjusted for the design’s
degrees of freedom and never above $`n`$); it stays inside 0 to 100% and
behaves near the ends. Domains with fewer than 30 respondents are
flagged, the rule Health Canada uses to suppress estimates in its data
tool; here nothing is withheld, and the flag travels with the row.

## Comparing groups

Two overlapping intervals do not mean two groups are the same, and two
separate intervals leave out the covariance between the estimates.
[`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md)
takes the difference within the design:

``` r

cmp <- svycmp(repdes, d, "used", by = "region", stat = "proportion", lvls = "1",
                      ref = "north")
cmp
#> ╭── Survey proportion of used against north ─────────────────────────────╮
#> │   Variable          used                                               │
#> │   Reference domain  north                                              │
#> │   Confidence        95%                                                │
#> │                                                                        │
#> │   domain  level  estimate  reference  difference       se              │
#> │   ------  -----  --------  ---------  ----------  -------              │
#> │   east    1        0.3074     0.3082    -0.00080  0.04468              │
#> │   south   1        0.2862     0.3082    -0.02199  0.05139              │
#> │                                                                        │
#> │   domain  95% CI               p_value                                 │
#> │   ------  -------------------  -------                                 │
#> │   east    [-0.08838, 0.08677]    0.986                                 │
#> │   south   [-0.12272, 0.07874]    0.669                                 │
#> │                                                                        │
#> │   Not distinguishable from 0 (interval includes it): east (p = 0.986)  │
#> │   and south (p = 0.669).                                               │
#> │                                                                        │
#> │   Each difference is a domain's estimate minus the reference domain's, │
#> │   with the design's covariance between the two taken into account.     │
#> ╰────────────────────────────────────────────────────────────────────────╯
plot(cmp)
```

![](survey-estimation_files/figure-html/survey-estimation-compare-1.png)

## The Canadian Substance Use Survey, against the published figures

CSUS 2023 ships 1,000 **mean bootstrap** weights, each the average of 12
bootstrap weights, so the bootstrap variance is multiplied by 12 (Health
Canada’s technical notes; the same as Fay’s BRR with
$`\rho = 1 - 1/\sqrt{12}`$). The public-use file and its weights are on
data.rmorie.com (sign in once with `rmbl login`), where
[`dload()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md)
checks each table against the SHA-256 its manifest lists:

``` r

a <- dload("csus_2023/pumf")        # 36,180 respondents
b <- dload("csus_2023/bootstrap")   # PUMF_ID, WGT_PUMF and BWGT1 ... BWGT1000
```

Or, without signing in, from Health Canada’s own copies on the Open
Government Portal (the same files, 612 MB for the weights):

``` r

src <- paste0(
  "https://open.canada.ca/data/dataset/",
  "65e2d45e-efc6-4c29-9a9b-db59bc96aa0e/resource"
)
pumf <- file.path(tempdir(), "csus2023_pumf_final.csv")
bwt <- file.path(tempdir(), "csus2023_pumf_bwt.csv")
bldl(
  file.path(
    src,
    "c2c1795b-4501-49ba-9dd1-5b8360cc3b2e/download",
    "csus2023_pumf_final.csv"
  ),
  pumf
)
bldl(
  file.path(
    src,
    "7d19d47a-5f42-4447-b735-aa4d677ad5ed/download",
    "csus2023_pumf_bwt.csv"
  ),
  bwt
)
a <- utils::read.csv(pumf)
b <- utils::read.csv(bwt)
# With rmorie installed, the same two files come from
# rmorie::morie_load_dataset() with the keys "cu23mf" and "cu23bt".
```

Either way, the design and the lifetime cannabis question are:

``` r

a$can <- ifelse(a$CAN_Q01 < 0, NA, a$CAN_Q01)   # -8: not stated
des <- svydes(a, w = "WGT_PUMF", reps = b, id = "PUMF_ID",
                     type = "meanboot", msize = 12)
svyest(des, a, "can", stat = "proportion", lvls = c("1", "2"))
```

Run on 13 October 2026 (1.6 seconds for the 1,000 replicates), against
Health Infobase’s published table:

| Lifetime cannabis use | Published % | Published 95% CI | Here % | Here 95% CI |
|----|----|----|----|----|
| Yes, just once | 9.907782 | 9.544212 to 10.28363 | 9.907816 | 9.522047 to 10.30743 |
| Yes, more than once | 53.192923 | 52.677340 to 53.70783 | 53.193086 | 52.677503 to 53.70799 |

The percentages agree to the fourth decimal, and so does the second
interval, whose design effect is below one so the interval is the plain
Wilson one at the 36,024 respondents. The first interval is slightly
wider here: Health Canada computed from its master file, and the
public-use weights are not identical to it (the percentages differ in
the fifth significant digit).

## When you only have the published table

Often there is no microdata, only the published table: an estimate and
its 95% limits for each group. The limits carry the design. A standard
error is the limits’ width over $`2z`$, and it includes the design
effect of the survey’s weights and clusters.
[`scests()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scests.md)
puts each Statistics Canada estimate beside its limits.
[`indgap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
[`dstntst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md)
and
[`ordcmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md)
then compare groups from them.

They treat the groups as independent samples. Disjoint domains of one
survey nearly are, but not exactly, since they share strata and
clusters. The exact comparison needs the bootstrap weights, which
Statistics Canada holds in its Research Data Centres.

Perceived mental health of First Nations, Métis and Inuit adults living
off reserve, 2019/2022 (table 13-10-0924-01):

``` r

h <- indiex("health")
mh <- h[
  h$period == "2019/2022" &
    h$age == "Total, 18 years and over" &
    h$indicator == "Perceived mental health, very good or excellent",
]
indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")[,
  c("group", "difference", "diflo", "difup")
]
#>           group difference     diflo      difup
#> 1 First Nations      -15.7 -18.53593 -12.864070
#> 2         Métis       -8.7 -11.58531  -5.814692
#> 3         Inuit      -13.7 -20.16568  -7.234321
dstntst(
  mh[mh$group != "Non-Indigenous", ],
  "group",
  "estimate",
  "lower",
  "upper"
)
#> ╭── Distinctions test ───────────────────────────────────────────────────╮
#> │   Groups       3                                                       │
#> │   Cochran's Q  11.97 on 2 df                                           │
#> │   p-value      0.003                                                   │
#> │   I-squared    83% of the variation is beyond chance                   │
#> │   Pooled       49.11 (se 0.973, inverse-variance mean)                 │
#> │                                                                        │
#> │   group          estimate     se  95% CI                               │
#> │   -------------  --------  -----  --------------                       │
#> │   First Nations     45.80  1.429  [43.00, 48.60]                       │
#> │   Métis             52.80  1.454  [49.95, 55.65]                       │
#> │   Inuit             47.80  3.291  [41.35, 54.25]                       │
#> │                                                                        │
#> │   Q says the groups differ: report each one, not the pooled figure.    │
#> │   Q = 11.97, p = 0.00252.                                              │
#> │                                                                        │
#> │   Distinctions-based: each group is reported on its own; a             │
#> │   pan-Indigenous total is left out of the test, never used as a group. │
#> │   Higgins and Thompson (2002) for Q and I-squared.                     │
#> ╰────────────────────────────────────────────────────────────────────────╯
```

## Linearization or replicates, the same answer

On the same data the two routes agree closely when the replicates come
from the same design:

``` r

rbind(linearization = svyest(lin, d, "drinks")[, c("estimate", "se")],
      bootstrap = svyest(repdes, d, "drinks")[, c("estimate", "se")])
#> ╭── Survey estimate ────────────────────────────────────────────────────╮
#> │   Rows     2                                                          │
#> │   Columns  2                                                          │
#> │                                                                       │
#> │   estimate       se                                                   │
#> │   --------  -------                                                   │
#> │      2.906  0.07295                                                   │
#> │      2.906  0.07324                                                   │
#> │                                                                       │
#> │   Some of this result's columns are not here (a subset of it?), so it │
#> │   is shown as a plain table.                                          │
#> ╰───────────────────────────────────────────────────────────────────────╯
```

Every variance formula here is checked in the package tests against the
survey package to machine precision: linearized means, totals, ratios,
proportions and domains with a finite population correction; JK1,
bootstrap and Fay replicate designs; and differences between domains.
