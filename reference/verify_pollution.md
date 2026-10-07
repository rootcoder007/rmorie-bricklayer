# Run the pollution-to-health pipeline and report it

Resolves the exposure (synthetic demo data, a CSV with an `exposure`
column and an optional `income` column, a NAPS-style pull with a `value`
column and a `unit`, or scalar arguments), logs the assumptions, and
when they all hold runs the concentration-response,
attributable-fraction, displaced-mortality, burden and equity stages.
`pollution_report_text()` renders the result as plain text.

## Usage

``` r
verify_pollution(
  pollutant,
  outcome = "all_cause_mortality",
  region = NULL,
  years = NULL,
  demo = FALSE,
  exposure_csv = NULL,
  exposure_mean = 0,
  exposure_prevalence = 0,
  reference = 5.8,
  baseline_rate = 500,
  population = 1e+06
)

pollution_report_text(report)
```

## Arguments

- pollutant:

  `"no2"` or `"pm25"`.

- outcome:

  Outcome key for the concentration-response function.

- region, years:

  Labels for the report.

- demo:

  Use synthetic demo data.

- exposure_csv:

  Path of a CSV with an `exposure` column in micrograms per cubic metre,
  or a `value` column with a `unit` column (NO2 in ppb is converted at
  1.88 micrograms per cubic metre per ppb, the WHO 2021 conversion at 25
  C and 1 atm).

- exposure_mean, exposure_prevalence:

  Scalar inputs used when neither `demo` nor `exposure_csv` is given.

- reference:

  Counterfactual reference concentration.

- baseline_rate:

  Baseline outcome rate per 100,000 per year.

- population:

  Population at risk.

- report:

  A result of `verify_pollution()`.

## Value

`verify_pollution()`: the report as a list; its `status` is `"ok"`,
`"assumption_failure"` or `"error"`, and the attribute `exit_status`
carries a command-line exit code (0, 1 or 2). `pollution_report_text()`:
a character string.

## Examples

``` r
r <- verify_pollution("no2", demo = TRUE)
r$status
#> [1] "ok"
r$pipeline$paf
#> [1] 0.03533756
cat(pollution_report_text(r))
#> ==================================================================
#>   verify-pollution -- NO2 -> all_cause_mortality
#>   data:   demo (synthetic)
#> ==================================================================
#> 
#> Inputs
#>   exposure mean:      23.968
#>   exposure prevalence:1.000
#>   baseline rate/100k: 500.00
#>   population:         1,000,000
#>   reference conc:     5.8
#> 
#> Assumption log
#>   [PASS] exposure > reference -- mean 23.96781213 vs ref 5.8 -- CRF is monotonic only when exposure exceeds the counterfactual floor.
#>   [PASS] prevalence in [0,1] -- exposure_prevalence=1
#>   [PASS] baseline_rate non-negative -- baseline_rate=500 per 100k per year
#>   [PASS] population positive -- population=1000000
#>   [PASS] pollutant supported by the CRFs -- Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke). Other pollutants reject.
#> 
#> Concentration-response
#>   RR:       1.0366
#>   source:   Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines
#> 
#> Attributable fraction (PAF): 0.0353
#> 
#> Mortality displaced
#>   expected avoided deaths: 176.7
#> 
#> Burden of pollution
#>   attributable deaths:   176.7
#> 
#> Equity analysis
#>   concentration index: -0.0668
#> 
#> STATUS: ok
```
