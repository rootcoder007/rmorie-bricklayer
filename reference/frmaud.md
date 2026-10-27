# How deficit-framed is a set of results?

Counts how many of the indicators in a report measure distress, deficit
or disparity and how many measure wellness or strength, and names any
group reported on deficits alone.

## Usage

``` r
frmaud(x)
```

## Arguments

- x:

  A
  [`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)
  result, whose rows are counted by side.

## Value

A list of class `rmbl_framing`: `bygrp` (a data frame of `group`,
`wellness`, `distress`, `shrdef`), `shrdef` overall and `defonly` (the
groups with no wellness indicator).

## Details

Walter (2016) shows that statistics about Indigenous peoples cluster
around five Ds: disparity, deprivation, disadvantage, dysfunction and
difference. Results built only of those describe Indigenous peoples as
their problems. This audit does not measure anything about people; it
measures the report: the share of its indicators that are
deficit-framed, overall and per group, so a report can be balanced
before it is published. Pair each gap with a strength-framed level
([`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md),
[`dualcont`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md)).

## References

Walter M (2016). Data politics and Indigenous representation in
Australian statistics. In Kukutai T, Taylor J (eds), Indigenous Data
Sovereignty: Toward an Agenda, 79-97. ANU Press.
[doi:10.22459/caepr38.11.2016.05](https://doi.org/10.22459/caepr38.11.2016.05)

Walter M, Andersen C (2013). Indigenous Statistics: A Quantitative
Research Methodology. Left Coast Press.
[doi:10.4324/9781315426570](https://doi.org/10.4324/9781315426570)

## Examples

``` r
wb <- indiex("wellbeing")
w <- welprof(
  wb,
  "group",
  "indicator",
  "estimate",
  "lower",
  "upper",
  well = "Always or often has a hopeful outlook",
  distress = c(
    "Rarely or never has a hopeful outlook",
    "Life satisfaction rating between 0 and 5",
    "Fair or poor perceived health"
  )
)
frmaud(w)
#> ╭── Framing audit ────────────────────────────────────────────────────╮
#> │   Groups               3                                            │
#> │   Wellness indicators  3                                            │
#> │   Distress indicators  9                                            │
#> │   Deficit-framed       75%                                          │
#> │                                                                     │
#> │   By group (shrdef: the deficit-framed share)                       │
#> │   group          wellness  distress  shrdef                         │
#> │   -------------  --------  --------  ------                         │
#> │   First Nations         1         3  0.7500                         │
#> │   Métis                 1         3  0.7500                         │
#> │   Inuit                 1         3  0.7500                         │
#> │                                                                     │
#> │   75% of the indicators reported are deficit-framed.                │
#> │   Most of this report measures disparity or deficit;                │
#> │   pair each with a strength-framed level.                           │
#> │                                                                     │
#> │   Walter (2016): statistics about Indigenous peoples cluster around │
#> │   disparity, deprivation, disadvantage, dysfunction and difference. │
#> │   This audits the report, not the people it describes.              │
#> ╰─────────────────────────────────────────────────────────────────────╯

# your own table: made-up percentages for two communities, with limits
own <- data.frame(
  community = rep(c("Lakeside", "Riverbend"), each = 4),
  item = rep(c("Hopeful", "Satisfied", "Rarely hopeful", "Low satisfaction"),
             2),
  pct = c(64, 71, 12, 18, 58, 66, 16, 22),
  lo = c(59, 66, 9, 14, 52, 60, 12, 17),
  hi = c(69, 76, 15, 22, 64, 72, 20, 27)
)
frmaud(welprof(own, "community", "item", "pct", "lo", "hi",
               well = c("Hopeful", "Satisfied"),
               distress = c("Rarely hopeful", "Low satisfaction")))
#> ╭── Framing audit ────────────────────────────────────────────────────╮
#> │   Groups               2                                            │
#> │   Wellness indicators  4                                            │
#> │   Distress indicators  4                                            │
#> │   Deficit-framed       50%                                          │
#> │                                                                     │
#> │   By group (shrdef: the deficit-framed share)                       │
#> │   group      wellness  distress  shrdef                             │
#> │   ---------  --------  --------  ------                             │
#> │   Lakeside          2         2  0.5000                             │
#> │   Riverbend         2         2  0.5000                             │
#> │                                                                     │
#> │   50% of the indicators reported are deficit-framed.                │
#> │                                                                     │
#> │   Walter (2016): statistics about Indigenous peoples cluster around │
#> │   disparity, deprivation, disadvantage, dysfunction and difference. │
#> │   This audits the report, not the people it describes.              │
#> ╰─────────────────────────────────────────────────────────────────────╯
```
