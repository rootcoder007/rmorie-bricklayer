# Wellness beside distress: a strengths-first profile of published indicators

Puts a group's wellness indicators (life satisfaction, perceived mental
health, a hopeful outlook, a sense of belonging, a strong cultural
identity) first and its distress indicators (suicidal thoughts, mood and
anxiety disorders, fair or poor mental health) after them, each with its
published interval, for each First Nations, Metis and Inuit group: so
that a table of mental health is never read, or plotted, as a list of
deficits alone.

## Usage

``` r
welprof(
  data,
  grp,
  ind,
  est,
  lower,
  upper,
  well,
  distress,
  domain = NULL,
  qual = NULL
)
```

## Arguments

- data:

  A data frame, one row per group and indicator (as
  [`scests`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scests.md)
  gives).

- grp, ind, est, lower, upper:

  Column names: the group, the indicator, the percentage and its
  published limits.

- well, distress:

  The indicators that measure wellness or strength, and those that
  measure distress; rows for any other indicator (totals, “not
  specified”) are left out.

- domain:

  Optional named character vector giving each indicator's holistic
  domain, for example `c("Life satisfaction 8 to 10" = "mental", ...)`.

- qual:

  Optional column of quality flags.

## Value

A data frame of class `rmbl_wellness_profile`, wellness rows first, with
the columns `group`, `indicator`, `side` (`"wellness"` or `"distress"`),
`domain`, `estimate`, `lower`, `upper` and `usewithcau`;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it.

## Details

Indigenous scholars of mental health define it as wellness and as a
process of healing, grounded in community, cultural identity, a holistic
view and interdependence (Stewart 2008), and ask that strengths be
reported together with disparities (Stewart 2020). This function puts
that into how published estimates are reported; it adds no estimate of
its own. The optional `domain` groups indicators by the holistic domains
of the Medicine Wheel teachings that Gabriel, Mirza and Stewart (2022)
describe (physical, emotional, mental, spiritual). That grouping is a
way to lay out the table, not a validated scale, and published tables
have few indicators of the spiritual domain: the profile says what is
there and does not stand one indicator in for another.

Aggregate tables show how indicators vary together across groups; they
cannot show that culture, land or belonging protects mental health
within a group, which would be an ecological inference. The differences
these tables show between groups are the effects of colonial policy and
of structural conditions, not of the people in the groups (Gabriel et
al. 2022); their interpretation belongs with First Nations, Metis and
Inuit communities.

## Acknowledgement

This estimator puts to quantitative use the framework of Professor
Suzanne Stewart (Yellowknives Dene First Nation, University of Toronto).

See the acknowledgements of the `first-nations-metis-inuit-health`
vignette.

## References

Stewart SL (2008). Promoting Indigenous mental health: cultural
perspectives on healing from Native counsellors in Canada. International
Journal of Health Promotion and Education 46(2):49-56.
[doi:10.1080/14635240.2008.10708129](https://doi.org/10.1080/14635240.2008.10708129)

Stewart S (2020). Addressing strengths and disparities in Indigenous
health. International Journal of Indigenous Health 15(1):4.
[doi:10.32799/ijih.v15i1.34976](https://doi.org/10.32799/ijih.v15i1.34976)

Gabriel MD, Mirza S, Stewart SL (2022). Exploring mental health and
holistic healing through the life stories of Indigenous youth who have
experienced homelessness. International Journal of Environmental
Research and Public Health 19(20):13402.
[doi:10.3390/ijerph192013402](https://doi.org/10.3390/ijerph192013402)

## See also

[`scests`](https://rootcoder007.github.io/rmorie-bricklayer/reference/scests.md),
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
[`ordcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md).

## Examples

``` r
# well-being, 2024 (table 41-10-0082-01)
wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = c("Life satisfaction rating of 8, 9 or 10",
                                   "Sense of meaning and purpose rating of 8, 9 or 10",
                                   "Always or often has a hopeful outlook"),
                      distress = c("Life satisfaction rating between 0 and 5",
                                   "Rarely or never has a hopeful outlook"),
                      qual = "quality")
w
#>            group                                         indicator     side
#> 1  First Nations            Life satisfaction rating of 8, 9 or 10 wellness
#> 2          Métis            Life satisfaction rating of 8, 9 or 10 wellness
#> 3          Inuit            Life satisfaction rating of 8, 9 or 10 wellness
#> 4  First Nations Sense of meaning and purpose rating of 8, 9 or 10 wellness
#> 5          Métis Sense of meaning and purpose rating of 8, 9 or 10 wellness
#> 6          Inuit Sense of meaning and purpose rating of 8, 9 or 10 wellness
#> 7  First Nations             Always or often has a hopeful outlook wellness
#> 8          Métis             Always or often has a hopeful outlook wellness
#> 9          Inuit             Always or often has a hopeful outlook wellness
#> 10 First Nations          Life satisfaction rating between 0 and 5 distress
#> 11         Métis          Life satisfaction rating between 0 and 5 distress
#> 12         Inuit          Life satisfaction rating between 0 and 5 distress
#> 13 First Nations             Rarely or never has a hopeful outlook distress
#> 14         Métis             Rarely or never has a hopeful outlook distress
#> 15         Inuit             Rarely or never has a hopeful outlook distress
#>    domain estimate lower upper usewithcau
#> 1    <NA>     36.1  31.9  40.4      FALSE
#> 2    <NA>     38.4  34.1  42.9      FALSE
#> 3    <NA>     38.8  31.5  46.4      FALSE
#> 4    <NA>     47.5  43.4  51.6      FALSE
#> 5    <NA>     51.6  47.0  56.2      FALSE
#> 6    <NA>     50.5  42.4  58.5      FALSE
#> 7    <NA>     50.2  45.9  54.5      FALSE
#> 8    <NA>     52.3  47.6  57.0      FALSE
#> 9    <NA>     54.4  45.7  62.8      FALSE
#> 10   <NA>     31.4  27.4  35.7      FALSE
#> 11   <NA>     28.4  24.0  33.1      FALSE
#> 12   <NA>     25.2  19.4  31.8      FALSE
#> 13   <NA>     17.9  14.6  21.7      FALSE
#> 14   <NA>     14.1  11.0  17.7      FALSE
#> 15   <NA>     16.7   8.2  28.9      FALSE
plot(w)
```
