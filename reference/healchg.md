# Healing as a process: change in published indicators between two periods

For each group and indicator, the change between two survey periods with
its confidence interval, wellness indicators first: change over time
read as Indigenous scholars describe mental health, as a process of
healing, not as a fixed deficit.

## Usage

``` r
healchg(
  data,
  grp,
  ind,
  prd,
  est,
  lower,
  upper,
  from,
  to,
  well = NULL,
  qual = NULL,
  conflvl = 0.95,
  distress = NULL
)
```

## Arguments

- data:

  A data frame, one row per group, indicator and period.

- grp, ind, prd, est, lower, upper:

  Column names: the change is in the estimate's own units (percentage
  points for percentages).

- from, to:

  The two periods.

- well, distress:

  Optional indicators of wellness (listed first) and of distress; with
  `distress` given, any other indicator is marked `"other"`.

- qual:

  Optional column of quality flags: `"E"` rows are marked use with
  caution, and suppressed ones (`"F"`, `"x"`, `".."`) get no estimate.

- conflvl:

  Confidence level of each change's interval (default 0.95).

## Value

A data frame of class `rmbl_healing_change`: `group`, `indicator`,
`side`, `from`, `to`, `change`, `lower`, `upper`, `usewithcau`.

## Details

Stewart (2008) describes Indigenous mental health as wellness and as a
process of healing; a process is seen in change. The change \\p_2 -
p_1\\ has the interval \\p_2 - p_1 \pm z\sqrt{s_1^2 + s_2^2}\\, with the
standard errors from the published intervals and the two periods'
samples independent (separate cycles of a survey are). A change is only
as comparable as the two periods' questions and designs: Statistics
Canada flags breaks in a series, and a change across one is not a change
in the people.

## Acknowledgement

This estimator puts to quantitative use the framework of Professor
Suzanne Stewart (Yellowknives Dene First Nation, University of Toronto).

See the acknowledgements of the `first-nations-metis-inuit-health`
vignette.

## References

Stewart SL (2008), see
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md).

## See also

[`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md).

## Examples

``` r
# 2015/2018 to 2019/2022, adults (table 13-10-0924-01)
h <- indiex("health")
belong <- paste0(
  "Sense of belonging to local community, ",
  "somewhat strong or very strong"
)
h <- h[
  h$age == "Total, 18 years and over" &
    h$indicator %in%
      c(
        "Perceived mental health, very good or excellent",
        belong,
        "Mood disorder",
        "Anxiety disorder"
      ),
]
hc <- healchg(
  h,
  "group",
  "indicator",
  "period",
  "estimate",
  "lower",
  "upper",
  from = "2015/2018",
  to = "2019/2022",
  qual = "quality",
  well = c("Perceived mental health, very good or excellent", belong)
)
hc
#> ╭── Healing as change between two periods ────────────────────────────────────╮
#> │   Periods     2015/2018 to 2019/2022                                        │
#> │   Groups      First Nations; Métis; Inuit; Non-Indigenous                   │
#> │   Indicators  4                                                             │
#> │   Units       the estimate's own (percentage points for percentages)        │
#> │                                                                             │
#> │   Perceived mental health, very good or excellent (wellness)                │
#> │   group            from     to   change  interval                           │
#> │   --------------  -----  -----  -------  ------------------                 │
#> │   First Nations   59.80  45.80  -14.000  [-17.688, -10.312]                 │
#> │   Métis           61.00  52.80   -8.200  [-11.926, -4.474]                  │
#> │   Inuit           49.10  47.80   -1.300  [-9.974, 7.374]                    │
#> │   Non-Indigenous  70.60  61.50   -9.100  [-9.702, -8.498]                   │
#> │                                                                             │
#> │   Sense of belonging to local community, somewhat strong or very strong     │
#> │   (wellness)                                                                │
#> │   group            from     to   change  interval                           │
#> │   --------------  -----  -----  -------  ----------------                   │
#> │   First Nations   64.10  63.70  -0.4000  [-4.117, 3.317]                    │
#> │   Métis           64.70  65.10   0.4000  [-3.224, 4.024]                    │
#> │   Inuit           76.50  73.50  -3.0000  [-11.210, 5.210]                   │
#> │   Non-Indigenous  67.50  67.40  -0.1000  [-0.702, 0.502]                    │
#> │                                                                             │
#> │   Anxiety disorder (distress)                                               │
#> │   group            from     to  change  interval                            │
#> │   --------------  -----  -----  ------  ---------------                     │
#> │   First Nations   17.80  22.50   4.700  [1.764, 7.636]                      │
#> │   Métis           18.60  18.60   0.000  [-2.866, 2.866]                     │
#> │   Inuit           12.30  15.70   3.400  [-2.859, 9.659]                     │
#> │   Non-Indigenous   8.20  10.90   2.700  [2.380, 3.020]                      │
#> │                                                                             │
#> │   Mood disorder (distress)                                                  │
#> │   group            from     to  change  interval                            │
#> │   --------------  -----  -----  ------  ---------------                     │
#> │   First Nations   15.30  20.30   5.000  [2.298, 7.702]                      │
#> │   Métis           16.80  18.70   1.900  [-0.974, 4.774]                     │
#> │   Inuit           11.00  13.80   2.800  [-3.164, 8.764]                     │
#> │   Non-Indigenous   8.50   9.80   1.300  [0.980, 1.620]                      │
#> │                                                                             │
#> │   7 of 16 changes have an interval clear of zero.                           │
#> │   Wellness: 0 rose and 3 fell by more than chance; distress: 4 rose and 0   │
#> │   fell.                                                                     │
#> │   Both sides point away from healing: wellness down, distress up.           │
#> │                                                                             │
#> │   Wellness indicators come first: a change is read as part of healing.      │
#> │   A change is only as comparable as the two periods' questions and          │
#> │   designs: across a break in the series it is not a change in people.       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
plot(hc)


# your own table: made-up percentages for one community in two surveys
own <- data.frame(
  community = "Lakeside",
  item = rep(c("Good mental health", "Anxiety"), 2),
  survey = rep(c("2018", "2023"), each = 2),
  pct = c(55, 14, 61, 11),
  lo = c(50, 11, 56, 8),
  hi = c(60, 17, 66, 14)
)
healchg(own, "community", "item", "survey", "pct", "lo", "hi",
        from = "2018", to = "2023", well = "Good mental health",
        distress = "Anxiety")
#> ╭── Healing as change between two periods ────────────────────────────────────╮
#> │   Periods     2018 to 2023                                                  │
#> │   Groups      Lakeside                                                      │
#> │   Indicators  2                                                             │
#> │   Units       the estimate's own (percentage points for percentages)        │
#> │                                                                             │
#> │   Good mental health (wellness)                                             │
#> │   group     from  to  change  interval                                      │
#> │   --------  ----  --  ------  ----------------                              │
#> │   Lakeside    55  61       6  [-1.071, 13.070]                              │
#> │                                                                             │
#> │   Anxiety (distress)                                                        │
#> │   group     from  to  change  interval                                      │
#> │   --------  ----  --  ------  ---------------                               │
#> │   Lakeside    14  11      -3  [-7.243, 1.243]                               │
#> │                                                                             │
#> │   0 of 2 changes have an interval clear of zero.                            │
#> │   Wellness: 0 rose and 0 fell by more than chance; distress: 0 rose and 0   │
#> │   fell.                                                                     │
#> │   No change is larger than its interval, on either side.                    │
#> │                                                                             │
#> │   Wellness indicators come first: a change is read as part of healing.      │
#> │   A change is only as comparable as the two periods' questions and          │
#> │   designs: across a break in the series it is not a change in people.       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
