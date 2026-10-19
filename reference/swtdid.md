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

- reps:

  Bootstrap replications (default 499; 0 for none).

- seed:

  Optional seed for the bootstrap.

- conflvl:

  Confidence level (default 0.95).

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
#>      term   estimate        se     lower      upper switchers
#> 1  effect -3.1355000 0.4555572 -4.028376 -2.2426243        15
#> 2 placebo -0.5169222 0.4429911 -1.385169  0.3513245        15
```
