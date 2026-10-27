# Standardised incidence ratio, with an exact interval

Divides each area's observed count by its expected count to give the
standardised incidence ratio (SIR), and adds an exact Poisson confidence
interval. A ratio of one is the overall experience; above one is an
excess and below one a deficit. Use it after
[`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md)
to say which areas differ from the overall rate by more than chance.

## Usage

``` r
stdinc(obs, expd, area = NULL, conflvl = 0.95)
```

## Arguments

- obs:

  Numeric vector of observed counts (non-negative).

- expd:

  Numeric vector of expected counts (positive), for example from
  [`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md);
  the same length as `obs`, or length one.

- area:

  Optional vector of area labels, added as the first column. Default
  `NULL`.

- conflvl:

  Number in (0, 1), default `0.95`: the two-sided confidence level of
  the interval.

## Value

A data frame with one row per area: `area` (when given), `observed`,
`expected`, `sir`, `lower`, `upper` (numeric), and logical `excess` (the
interval lies above one), `deficit` (the interval lies below one) and
`significant` (either).

## Details

With observed count \\O\\ and expected \\E\\, \\SIR = O / E\\. The
interval for \\1 - \alpha\\ coverage is
\$\$\left\[\frac{G^{-1}(\alpha/2;\\ O)}{E},\\ \frac{G^{-1}(1-\alpha/2;\\
O+1)}{E}\right\]\$\$ where \\G^{-1}(p; k)\\ is the gamma quantile with
shape \\k\\; the lower limit is 0 when \\O = 0\\. This is the exact
Poisson interval, from the relation between the Poisson and gamma
distributions, and so is identical to
[`stats::poisson.test()`](https://rdrr.io/r/stats/poisson.test.html)'s.
It is the interval to use here because the counts that matter are small:
a normal approximation on an observed count of three is not an interval,
it is a decoration.

Each area's interval is a separate test; with many areas some will
exclude one by chance (see
[`scanadj`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scanadj.md)).
A row with a missing observed or expected count is dropped whole (its
area label with it), after the lengths are compared.

Errors: negative, infinite or non-numeric counts; an expected count of
zero or below; lengths that differ (a single `expd` is recycled). A
`conflvl` outside (0, 1) is an error.

## References

Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
Modeling*. Chapman and Hall/CRC, Chapter 1.

## See also

[`expcnts`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expcnts.md),
[`ebrates`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ebrates.md),
[`fnllim`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fnllim.md)

## Examples

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

# An observed count of three carries almost no information, and the
# interval says so rather than hiding it.
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

# a 90 percent interval, and a zero count (lower limit exactly 0)
stdinc(c(0, 40), c(2, 25), conflvl = 0.90)
#> ╭── Standardised incidence ratios ──────────────────────────────────────╮
#> │   Areas          2                                                    │
#> │   Observed       40                                                   │
#> │   Expected       27                                                   │
#> │   Overall ratio  1.481                                                │
#> │   Interval       exact Poisson, at the level asked for (default 95%)  │
#> │   Above one      1                                                    │
#> │   Below one      0                                                    │
#> │                                                                       │
#> │   observed  expected    sir  interval        finding                  │
#> │   --------  --------  -----  --------------  -------                  │
#> │          0         2  0.000  [0.000, 1.498]                           │
#> │         40        25  1.600  [1.208, 2.083]  excess                   │
#> │                                                                       │
#> │   A ratio above 1 means more cases than the area's population would   │
#> │   give at the overall rates. An excess or a deficit is an interval    │
#> │   wholly above or below 1 (the significant column is either).         │
#> │                                                                       │
#> │   Each interval is a separate test: with many areas some exclude 1 by │
#> │   chance (scanadj() allows for that).                                 │
#> ╰───────────────────────────────────────────────────────────────────────╯

try(stdinc(c(3, 4), c(5, 0)))
#> Error : stdinc: `expd` must be positive
```
