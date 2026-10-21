# The indicators of Calls to Action 19 and 55, and the tables that measure them

Call to Action 19 asks the federal government to “establish measurable
goals to identify and close the gaps in health outcomes between
Aboriginal and non-Aboriginal communities, and to publish annual
progress reports and assess long-term trends”, focusing on “infant
mortality, maternal health, suicide, mental health, addictions, life
expectancy, birth rates, infant and child health issues, chronic
diseases, illness and injury incidence, and the availability of
appropriate health services”. Call to Action 55 asks for annual data on,
among others, “the number of Aboriginal children–including Metis and
Inuit children–in care, compared with non-Aboriginal children” and “the
educational and income attainments of Aboriginal peoples in Canada
compared with non-Aboriginal people”. This lists, for each indicator,
the Statistics Canada tables at the data service (or the census profile)
that measure it, the measure, and which direction is better.

## Usage

``` r
trcind()
```

## Value

A data frame with `call`, `indicator` (the Call's words), `table`,
`measure`, `better` (`"higher"` or `"lower"`) and `note`.

## Details

The list is a map of what the published tables can measure, not a
judgement of what the Calls require: maternal health is measured here
only through birth outcomes in Inuit regions, and several indicators
(addictions, the availability of services) only through proxies. The
direction is the direction of better health for the people measured.

## References

Truth and Reconciliation Commission of Canada (2015). Truth and
Reconciliation Commission of Canada: Calls to Action. Winnipeg.
Government of Canada catalogue IR4-8/2015E.
<https://publications.gc.ca/collections/collection_2015/trc/IR4-8-2015-eng.pdf>

## See also

[`trchlthgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trchlthgap.md),
[`trcprog`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md).

## Examples

``` r
ti <- trcind()
ti[ti$call == "19", c("indicator", "table", "measure", "better")]
#>                                      indicator          table
#> 1                             infant mortality     17-10-0161
#> 2                              maternal health     13-10-0064
#> 3                                      suicide     41-10-0021
#> 4                                mental health     13-10-0924
#> 5                                mental health     13-10-0924
#> 6                                mental health     13-10-0924
#> 7                                mental health     13-10-0924
#> 8                                   addictions     13-10-0924
#> 9                                   addictions     13-10-0924
#> 10                             life expectancy     17-10-0160
#> 11                                 birth rates census profile
#> 12              infant and child health issues     13-10-0064
#> 13                            chronic diseases     13-10-0924
#> 14                            chronic diseases     13-10-0924
#> 15                            chronic diseases     13-10-0924
#> 16                            chronic diseases     13-10-0924
#> 17                illness and injury incidence     13-10-0157
#> 18 availability of appropriate health services     13-10-0924
#>                                                                measure better
#> 1                                                Infant mortality rate  lower
#> 2                                    Low birth weight; Pre-term births  lower
#> 3                 Seriously contemplated suicide in the past 12 months  lower
#> 4                      Perceived mental health, very good or excellent higher
#> 5                                                        Mood disorder  lower
#> 6                                                     Anxiety disorder  lower
#> 7  Perceived life stress, most days quite a bit or extremely stressful  lower
#> 8                                                       Heavy drinking  lower
#> 9                                  Current smoker, daily or occasional  lower
#> 10                                            Life expectancy at birth higher
#> 11                                              Population aged 0 to 4       
#> 12                                           Small for gestational age  lower
#> 13                    At least one underlying chronic health condition  lower
#> 14                                                            Diabetes  lower
#> 15                                                 High blood pressure  lower
#> 16                                                           Arthritis  lower
#> 17                                                           Mortality  lower
#> 18                                   Has a regular healthcare provider higher
```
