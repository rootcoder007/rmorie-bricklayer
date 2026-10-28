# Difference in differences for treatments that switch on and off

De Chaisemartin and D'Haultfoeuille's estimator of the effect at the
moment units switch: in every period, units that switch into treatment
are compared with units untreated in both periods, and units that switch
out with units treated in both; with the placebo that runs the same
comparison one period earlier.

## Usage

``` r
swtdid(
  data,
  unit,
  time,
  y,
  trtd,
  cl = NULL,
  reps = 499L,
  seed = NULL,
  conflvl = 0.95
)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- trtd:

  Column name of the treatment indicator (0 or 1).

- cl:

  Column name of the clusters (default the unit), or two column names
  for two-way clustering (Cameron, Gelbach and Miller 2011): \\V_a +
  V_b - V\_{ab}\\, each term with the small-sample factor of the
  dimension with fewer clusters, and t on its \\G - 1\\ degrees of
  freedom. A composite cluster (district by month, say) is one column
  made with [`interaction()`](https://rdrr.io/r/base/interaction.html).
  Fewer than ten clusters give a warning (CR1 errors are unreliable with
  so few;
  [`wcb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wcb.md)
  is made for that case), and so does a cluster that changes within a
  unit.

- reps:

  Bootstrap replications (default 499; 0 for none).

- seed:

  Optional seed for the bootstrap.

- conflvl:

  Confidence level of the intervals reported (default 0.95).

## Value

A data frame of class `rmbl_switching_did`, two rows (`effect`,
`placebo`): `estimate`, `se`, `lower`, `upper`, `switchers`.

## Details

For each period \\t\\ with joiners (\\D\_{t-1} = 0, D_t = 1\\) and
stayers untreated in both, \\DID\_{+,t}\\ is the joiners' mean change in
the outcome minus the stayers'; with leavers (1 to 0) and stayers
treated in both, \\DID\_{-,t}\\ is the stayers' change minus the
leavers'. The estimate is \$\$DID_M = \sum_t \frac{N\_{J,t}}{N_S}
DID\_{+,t} + \frac{N\_{L,t}}{N_S} DID\_{-,t},\$\$ over the \\N_S\\
switchers. The placebo compares, between \\t - 2\\ and \\t - 1\\, the
change of the units that switch at \\t\\ with that of the units whose
treatment did not change over \\t - 2\\ to \\t\\; it should be near
zero. Standard errors come from the cluster bootstrap. Unlike the
two-way estimator, \\DID_M\\ never uses a unit whose treatment changed
as a control in the period it changed.

## References

de Chaisemartin C, D'Haultfoeuille X (2020). Two-way fixed effects
estimators with heterogeneous treatment effects. American Economic
Review 110(9):2964-2996.
[doi:10.1257/aer.20181169](https://doi.org/10.1257/aer.20181169)

Applied as a placebo check on ward redistricting: Ternullo S,
Zorro-Medina A, Vargas R (2024). How political dynasties concentrate
advantage within cities. Social Forces 102(4):1310-1331.
[doi:10.1093/sf/soae029](https://doi.org/10.1093/sf/soae029)

## Examples

``` r
p <- polex()
swtdid(p, "district", "month", "crmrate", "reformed", reps = 99, seed = 1)
#> ╭── Difference in differences, switching treatment ──────────────────────╮
#> │   Method     de Chaisemartin and D'Haultfoeuille, switchers vs stayers │
#> │   Switchers  15                                                        │
#> │                                                                        │
#> │   term     estimate      se  interval          switchers               │
#> │   -------  --------  ------  ----------------  ---------               │
#> │   effect     -3.135  0.4556  [-4.028, -2.243]         15               │
#> │   placebo    -0.517  0.4430  [-1.385, 0.351]          15               │
#> │                                                                        │
#> │   At the moment units switch, the effect is -3.135 (its interval       │
#> │   [-4.028, -2.243]): the interval excludes 0, so the data distinguish  │
#> │   it from no effect. The placebo, the same comparison one period       │
#> │   earlier, is -0.5169; near zero supports the design.                  │
#> │                                                                        │
#> │   Intervals are normal, from the cluster-bootstrap standard error.     │
#> ╰────────────────────────────────────────────────────────────────────────╯

# your own panel: eight towns over ten years, four adopting a by-law (two
# in 2019, two in 2021), with each town's population, county and income
own <- data.frame(
  town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
  year = rep(2015:2024, times = 8)
)
i <- match(own$town, unique(own$town))
own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
own$county <- rep(c("North", "South"), 4)[i]
own$income <- 50 + own$year - 2015 + cos(seq_len(80))
own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
  0.2 * own$income + sin(seq_len(80))
swtdid(own, "town", "year", "rate", "bylaw", reps = 49, seed = 1)
#> ╭── Difference in differences, switching treatment ──────────────────────╮
#> │   Method     de Chaisemartin and D'Haultfoeuille, switchers vs stayers │
#> │   Switchers  4                                                         │
#> │                                                                        │
#> │   term     estimate      se  interval          switchers               │
#> │   -------  --------  ------  ----------------  ---------               │
#> │   effect     -4.022  0.3802  [-4.767, -3.277]          4               │
#> │   placebo    -0.062  0.4099  [-0.865, 0.742]           4               │
#> │                                                                        │
#> │   At the moment units switch, the effect is -4.022 (its interval       │
#> │   [-4.767, -3.277]): the interval excludes 0, so the data distinguish  │
#> │   it from no effect. The placebo, the same comparison one period       │
#> │   earlier, is -0.06159; near zero supports the design.                 │
#> │                                                                        │
#> │   Intervals are normal, from the cluster-bootstrap standard error.     │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
