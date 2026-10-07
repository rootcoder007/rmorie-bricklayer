# End-to-end pollution burden

Chains the concentration-response function, the attributable fraction
and the baseline case count into annual attributable cases, as the GBD
risk factor estimates do (GBD 2019 Risk Factors Collaborators 2020).

## Usage

``` r
pollution_burden(
  exposure_mean,
  exposure_prevalence,
  baseline_rate,
  population,
  pollutant = "NO2",
  outcome = "all_cause_mortality",
  reference_conc = NULL
)
```

## Arguments

- exposure_mean:

  Population-mean exposure (micrograms per cubic metre).

- exposure_prevalence:

  Proportion of the population at that level (1 for ambient air).

- baseline_rate:

  Cases per person-year in the unexposed scenario.

- population:

  At-risk population.

- pollutant:

  `"PM2.5"` or `"NO2"`.

- outcome:

  Outcome key passed to the concentration-response function.

- reference_conc:

  Counterfactual concentration; `NULL` takes the pollutant's WHO 2021
  guideline value.

## Value

A list of class `rmbl_burden` with `paf`, `attributable_cases`,
`baseline_cases`, `population`, `baseline_rate`, `exposure_mean`,
`reference_conc`, `pollutant`, `citation` and `extra` (the RR and
log-RR).

## References

GBD 2019 Risk Factors Collaborators (2020). Global burden of 87 risk
factors in 204 countries and territories, 1990-2019. The Lancet
396(10258), 1223-1249.

## Examples

``` r
pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2")$attributable_cases
#> [1] 234.1369
```
