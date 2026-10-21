# A community-weighted index of protective and risk factors

Combines published indicators into one index for each group or place,
with weights the community sets: protective factors count for, risk
factors against. The weights are never estimated.

## Usage

``` r
commidx(data, grp, ind, est, lower, upper, w, qual = NULL, conflvl = 0.95)
```

## Arguments

- data:

  A data frame, one row per group (or place) and indicator.

- grp, ind, est, lower, upper:

  Column names; every indicator must be on one scale (percent, for
  example: a rate per 1,000 beside a percentage makes the weights
  meaningless).

- w:

  Named weights, one per indicator used: positive for a protective
  factor, negative for a risk factor.

- qual:

  Optional column of quality flags.

- conflvl:

  Confidence level (default 0.95).

## Value

A data frame of class `rmbl_community_index`: `group`, `index`, `lower`,
`upper`, `usewithcau`; attributes `weights` and `conflvl`.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it.

## Details

Inuit Tapiriit Kanatami's National Inuit Suicide Prevention Strategy
(2016) names risk factors (among them crowded housing, food insecurity,
childhood adversity, mental distress) and protective factors (among them
cultural continuity, social equity, family strength, healthy child
development). How much each matters is a judgement for the people the
index describes, so the function takes the weights as given: positive
for protective, negative for risk. The index is \\\sum_i w_i p_i /
\sum_i \|w_i\|\\, with standard error \\\sqrt{\sum_i w_i^2 s_i^2} /
\sum_i \|w_i\|\\ from the published intervals (independent estimates).
It is a summary of the indicators under the weights given; with other
weights it ranks places otherwise, and it is never a ranking of Nations
or communities on their culture. For Inuit regions, use Inuit data only.

## References

Inuit Tapiriit Kanatami (2016). National Inuit Suicide Prevention
Strategy. Ottawa. itk.ca/national-inuit-suicide-prevention-strategy

Carroll SR, et al. (2020), see
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md).

## Examples

``` r
# weights a community might set for adults, 2019/2022 (table 13-10-0924-01); others
# would differ
h <- indiex("health")
h <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
w <- c(2, 1, -2, -1)
names(w) <- c("Sense of belonging to local community, somewhat strong or very strong",
              "Has a regular healthcare provider",
              "Perceived life stress, most days quite a bit or extremely stressful",
              "Heavy drinking")
ci <- commidx(h, "group", "indicator", "estimate", "lower", "upper",
                      qual = "quality", w = w)
ci
#>            group    index    lower    upper usewithcau
#> 1  First Nations 21.96667 20.65579 23.27755      FALSE
#> 2          Métis 22.20000 20.84466 23.55534      FALSE
#> 3          Inuit 22.13333 18.93042 25.33625      FALSE
#> 4 Non-Indigenous 26.58333 26.37836 26.78831      FALSE
# an indicator the table does not publish for the period leaves the index NA, never
# filled: food insecurity is ".." for 2019/2022
w2 <- c(w, "Household food insecure" = -2)
commidx(h, "group", "indicator", "estimate", "lower", "upper",
                qual = "quality",
                w = w2)$index
#> [1] NA NA NA NA
plot(ci)
```
