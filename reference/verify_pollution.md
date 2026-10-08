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
  reference = NULL,
  baseline_rate = 500,
  population = 1e+06
)

pollution_report_text(report)
```

## Arguments

- pollutant:

  `"no2"` or `"pm25"` (also `"PM2.5"`), in either case.

- outcome:

  Outcome key for the concentration-response function; the mortality
  outcomes count deaths, `"childhood_asthma"` incident cases.

- region, years:

  Labels for the report.

- demo:

  Use synthetic demo data.

- exposure_csv:

  Path of a CSV with an `exposure` column in micrograms per cubic metre,
  or a NAPS pull with a `value` column and a `unit` column (required
  with `value`): each row is converted by its own unit, NO2 in ppb at
  1.88 micrograms per cubic metre per ppb (the WHO 2021 conversion at 25
  C and 1 atm), and any other unit is an error. With a CSV or the demo
  data the exposed are the rows above `reference`: `exposure_prevalence`
  is their share and `exposure_mean` their mean, so Levin's formula is
  not diluted twice.

- exposure_mean, exposure_prevalence:

  Scalar inputs used when neither `demo` nor `exposure_csv` is given:
  the mean exposure among the exposed and the share of the population
  exposed.

- reference:

  Counterfactual reference concentration; `NULL` takes the pollutant's
  default (PM2.5 5.8, NO2 10; see
  [`crf_pm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crf_pm25.md)).

- baseline_rate:

  Baseline outcome rate per 100,000 per year (unlike
  [`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md),
  which takes a rate per person-year).

- population:

  Population at risk (persons).

- report:

  A result of `verify_pollution()`.

## Value

`verify_pollution()`: the report as a list of class
`rmbl_pollution_report`
([`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it); its
`status` is `"ok"`, `"assumption_failure"` or `"error"`, and the
attribute `exit_status` carries a command-line exit code (0, 1 or 2).
`pollution_report_text()`: a character string.

## Examples

``` r
r <- verify_pollution("no2", demo = TRUE)
r$status
#> [1] "ok"
r$pipeline$paf
#> [1] 0.02733115
cat(pollution_report_text(r))
#> ==================================================================
#>   verify-pollution -- NO2 -> all_cause_mortality
#>   data:   demo (synthetic)
#> ==================================================================
#> 
#> Inputs
#>   exposure mean:      24.261
#>   exposure prevalence:0.981
#>   baseline rate/100k: 500.00
#>   population:         1e+06
#>   reference conc:     10
#> 
#> Assumption log
#>   [PASS] exposure finite and non-negative -- mean 24.26113743 vs ref 10
#>   [PASS] prevalence in [0,1] -- exposure_prevalence=0.981
#>   [PASS] baseline_rate finite and non-negative -- baseline_rate=500 per 100k per year
#>   [PASS] population finite and positive -- population=1e+06
#>   [PASS] reference finite and non-negative -- reference=10
#>   [PASS] pollutant supported by the CRFs -- Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke). Other pollutants reject.
#> 
#> Concentration-response
#>   RR:       1.0286
#>   source:   Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines
#> 
#> Attributable fraction (PAF): 0.0273
#> 
#> Mortality displaced
#>   expected avoided deaths: 136.6
#> 
#> Burden of pollution
#>   attributable deaths:   136.7
#> 
#> Equity analysis
#>   concentration index: -0.0647
#> 
#> STATUS: ok
```
