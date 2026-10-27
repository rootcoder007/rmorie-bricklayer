# Decompose a change in a clearance rate into rate and case-mix effects

An aggregate clearance rate – cases disposed per case received by a
court, or offences cleared per offence reported to a police service – is
a weighted mean of the rates of its parts (offence groups, courts, case
types), weighted by each part's share of the denominator. It can
therefore fall while the rate of every part rises, if the work shifts
toward the parts that clear more slowly: Simpson's paradox. This
function compares two periods (or two jurisdictions), splits the change
in the aggregate exactly into the change in the parts' rates and the
change in the mix, reports the rate standardised to a common mix, tests
the within-part change, and says whether the comparison is a reversal.

## Usage

``` r
clrdcmp(num, den, grp, cmp, base = NULL, conflvl = 0.95)
```

## Arguments

- num:

  Cases disposed (or cleared), one per part and comparison.

- den:

  Cases received (or reported), one per part and comparison.

- grp:

  The part each row belongs to: offence group, court, case type.

- cmp:

  The comparison each row belongs to: exactly two values, such as two
  years or two jurisdictions.

- base:

  Which value of `cmp` is the baseline. Default: the first in sorted
  order.

- conflvl:

  Confidence level. Default 0.95.

## Value

A list of class `rmbl_clearance_decomposition`:

- `groups`:

  one row per part: the counts, rates and denominator shares (`weight`)
  in both comparisons, the rate ratio with its exact interval, and the
  part's `rateeff` and `mixeff`.

- `overall`:

  the aggregate rates, their `change`, its `rateeff` and `mixeff` (which
  add to it exactly), the comparison rate standardised to the baseline
  mix (`staonbase`) and to the average mix (`staonave`).

- `rateratio`:

  the crude rate ratio and the Mantel-Haenszel rate ratio over the
  parts, each with its interval, and the p-value for the stratified
  ratio.

- `simpson`:

  `"full"` when every part moved one way and the aggregate the other;
  `"mix"` when the aggregate moved against the mix-standardised change
  (the mix outweighed the rates); `"none"` otherwise; with the number of
  parts that rose and fell.

## Details

With part rates \\r_g\\ and denominator shares \\w_g\\, the aggregate is
\\R = \sum_g w_g r_g\\. Kitagawa's symmetric decomposition writes the
change between comparisons A and B as \$\$R_B - R_A = \sum_g \bar w_g
(r\_{gB} - r\_{gA}) + \sum_g \bar r_g (w\_{gB} - w\_{gA}),\$\$ with
\\\bar w_g\\ and \\\bar r_g\\ the averages over A and B: the first sum
is the rate effect (the change the aggregate would show with the mix
held at its average), the second the mix effect. The two add to the
observed change with no residual. Because the shares' changes add to
zero, each part's mix term is reported as \\(\bar r_g - \bar
R)(w\_{gB} - w\_{gA})\\, centred on the average aggregate rate \\\bar
R\\: the total is the same, and a part's term is negative when work
moved toward a part that clears below average.

The within-part change is estimated by the Mantel-Haenszel rate ratio,
treating each part's numerator as a Poisson count over its denominator,
with the Greenland-Robins variance; the p-value is for the hypothesis
that the ratio is 1. Each part's own rate ratio has the exact
conditional (binomial) interval. A court's clearance rate can exceed 1,
so it is treated as a rate rather than a proportion; for police
clearance, where it is a proportion, the Poisson treatment is
conservative.

The decomposition is only as good as the parts: a different grouping
(courts instead of offence groups) can tell a different story, and both
can be right. Demers and Rossmo found 210 reversals in fifteen years of
clearance rates for Canada's fifty largest police services, four of them
reversed in every crime category, and advise comparing clearance rates
only within comparable mixes.

## References

Simpson, E. H. (1951). The interpretation of interaction in contingency
tables. *Journal of the Royal Statistical Society, Series B*, 13(2),
238-241.

Kitagawa, E. M. (1955). Components of a difference between two rates.
*Journal of the American Statistical Association*, 50(272), 1168-1194.
[doi:10.2307/2281213](https://doi.org/10.2307/2281213)

Das Gupta, P. (1993). *Standardization and Decomposition of Rates: A
User's Manual*. U.S. Bureau of the Census, Current Population Reports
P23-186. Washington, DC.

Greenland, S. and Robins, J. M. (1985). Estimation of a common effect
parameter from sparse follow-up data. *Biometrics*, 41(1), 55-68.

Demers, S. and Rossmo, D. K. (2015). Simpson's paradox in Canadian
police clearance rates. *Canadian Journal of Criminology and Criminal
Justice*, 57(3), 424-434.
[doi:10.3138/cjccj.2014-E29](https://doi.org/10.3138/cjccj.2014-E29)

## See also

[`caseflow`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md)
for the clearance rate over time.

## Examples

``` r
g <- read.csv(system.file(
  "extdata",
  "ocj_offence_groups.csv",
  package = "rmoriebricklayer"
))
g <- g[g$year %in% c(2014, 2022), ]
cd <- clrdcmp(g$disposed, g$received, g$offence_group, g$year)
cd
#> ╭── Clearance rate, 2022 against 2014 (Kitagawa) ─────────────────────────────╮
#> │   Rate 2014                0.976                                            │
#> │   Rate 2022                0.9749                                           │
#> │   Change                   -0.0011 = rate effect +0.0096 + mix effect       │
#> │                            -0.0107                                          │
#> │   2022 at the 2014 mix     0.9912                                           │
#> │   2022 at the average mix  0.9830                                           │
#> │   Parts                    6                                                │
#> │                                                                             │
#> │   part                       rate 2014  rate 2022  share 2014  share 2022   │
#> │   -------------------------  ---------  ---------  ----------  ----------   │
#> │   Administration of Justice     0.9788      1.038      0.2689      0.2818   │
#> │   Crimes Against Property       0.9851      0.969      0.2279      0.1973   │
#> │   Crimes Against the Person     0.9180      0.858      0.2620      0.3187   │
#> │   Criminal Code Traffic         1.0105      1.021      0.0808      0.0948   │
#> │   Federal Statute               1.0232      1.173      0.1148      0.0534   │
#> │   Other Criminal Code           1.0675      1.082      0.0455      0.0539   │
#> │                                                                             │
#> │   part                       ratio  95% CI            rateeff     mixeff    │
#> │   -------------------------  -----  --------------  ---------  ---------    │
#> │   Administration of Justice  1.060  [1.048, 1.072]   0.016263   0.000424    │
#> │   Crimes Against Property    0.984  [0.971, 0.997]  -0.003375  -0.000052    │
#> │   Crimes Against the Person  0.934  [0.923, 0.945]  -0.017526  -0.004966    │
#> │   Criminal Code Traffic      1.011  [0.990, 1.031]   0.000939   0.000566    │
#> │   Federal Statute            1.147  [1.123, 1.171]   0.012631  -0.007535    │
#> │   Other Criminal Code        1.013  [0.987, 1.040]   0.000713   0.000834    │
#> │                                                                             │
#> │   4 of 6 parts rose, 2 fell.                                                │
#> │   Simpson's paradox through the mix: the aggregate fell, but at a fixed     │
#> │   mix it rose                                                               │
#> │   Rate effect: the change at a fixed case mix; mix effect: the change       │
#> │   from the mix of cases alone.                                              │
#> │                                                                             │
#> │   Rate ratio 2022/2014: crude 0.9989 (0.9929 to 1.0050); within parts       │
#> │   (Mantel-Haenszel) 1.0085 (1.0024 to 1.0146), p 0.006                      │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
plot(cd)


# Simpson's paradox in four numbers: each part clears better in B, yet the
# aggregate falls, because B's workload moved to the part that clears less
toy <- clrdcmp(
  num = c(90, 20, 19, 60),
  den = c(100, 50, 20, 140),
  grp = c("minor", "serious", "minor", "serious"),
  cmp = c("A", "A", "B", "B")
)
toy
#> ╭── Clearance rate, B against A (Kitagawa) ───────────────────────────────────╮
#> │   Rate A                0.7333                                              │
#> │   Rate B                0.4938                                              │
#> │   Change                -0.2396 = rate effect +0.0371 + mix effect -0.2766  │
#> │   B at the A mix        0.7762                                              │
#> │   B at the average mix  0.6350                                              │
#> │   Parts                 2                                                   │
#> │                                                                             │
#> │   part     rate A  rate B  share A  share B  ratio  95% CI          rateeff │
#> │   -------  ------  ------  -------  -------  -----  --------------  ------- │
#> │   minor    0.9000  0.9500   0.6667   0.1250  1.056  [0.607, 1.745]  0.01979 │
#> │   serious  0.4000  0.4286   0.3333   0.8750  1.071  [0.637, 1.877]  0.01726 │
#> │                                                                             │
#> │   part      mixeff                                                          │
#> │   -------  -------                                                          │
#> │   minor    -0.1687                                                          │
#> │   serious  -0.1079                                                          │
#> │                                                                             │
#> │   2 of 2 parts rose, 0 fell.                                                │
#> │   Simpson's paradox: every part moved the other way to the aggregate (2 of  │
#> │   2)                                                                        │
#> │   Rate effect: the change at a fixed case mix; mix effect: the change       │
#> │   from the mix of cases alone.                                              │
#> │                                                                             │
#> │   Rate ratio B/A: crude 0.6733 (0.4978 to 0.9072); within parts             │
#> │   (Mantel-Haenszel) 1.0634 (0.7465 to 1.5149), p 0.733                      │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# every part must appear in both comparisons
try(clrdcmp(c(5, 6, 7), c(10, 10, 10), c("x", "y", "x"), c(1, 1, 2)))
#> Error : part "y" is in only one comparison; a rate change needs it in both (merge or drop it first)
```
