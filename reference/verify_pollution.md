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
  exposure_mean = NULL,
  exposure_prevalence = NULL,
  reference = NULL,
  baseline_rate = 500,
  baseline_rate_per = 1e+05,
  population = 1e+06,
  rare_outcome = FALSE,
  high_rate = FALSE
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

  Use synthetic demo data (`TRUE` or `FALSE`).

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
  exposed. A wrapper must never default one of them to zero: a
  prevalence of zero silently zeroes the burden, which is why the two
  are required together.

- reference:

  Counterfactual reference concentration; `NULL` takes the pollutant's
  default (PM2.5 5.8, NO2 10; see
  [`crf_pm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crf_pm25.md)).

- baseline_rate:

  Baseline outcome rate per 100,000 per year (unlike
  [`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md),
  which takes a rate per person-year).

- baseline_rate_per:

  The denominator `baseline_rate` is quoted per: 100,000 (the default),
  or 1 for a rate per person-year such as a crude death rate of 0.012.

- population:

  Population at risk (persons).

- rare_outcome:

  `TRUE` when the outcome really is rarer than one case per 100,000 per
  year. Without it a rate that converts to less than that is an
  assumption failure, because it is also what a rate per person-year
  passed as per 100,000 looks like (0.008 per person-year is 800 per
  100,000; as 0.008 per 100,000 the burden is 100,000 times too small).
  The check is on the converted rate, so it holds whatever
  `baseline_rate_per` is.

- high_rate:

  `TRUE` when the outcome really is more common than 10,000 per 100,000
  a year (no population's all-cause death rate is); without it such a
  rate is an assumption failure.

- report:

  A result of `verify_pollution()`.

## Value

`verify_pollution()`: the report as a list of class
`rmbl_pollution_report`
([`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it); its
`status` is `"ok"`, `"assumption_failure"` or `"error"`, and the
attribute `exit_status` carries a command-line exit code (0, 1 or 2). An
argument the pipeline cannot use (no exposure data at all, a vector
where a single number is expected, an unknown outcome, a missing
reference, a directory as `exposure_csv`) is an `"error"` report with
exit status 2, never a raw R error; an exposure at or below the
reference is a valid run with zero attributable cases, and the scalar
inputs `exposure_mean` and `exposure_prevalence` go together (one
without the other is an error report). `pollution_report_text()`: a
character string.

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
#>   population:         1,000,000
#>   reference conc:     10
#> 
#> Assumption log
#>   [PASS] exposure finite and non-negative -- mean 24.26113743 vs ref 10
#>   [PASS] exposure within the concentration-response range (at most 10,000 ug/m3) -- exposure_mean=24.26114
#>   [PASS] prevalence in [0,1] -- exposure_prevalence=0.981
#>   [PASS] baseline_rate finite: zero, or between 1 and 10,000 per 100k -- baseline_rate=500 per 100k per year
#>   [PASS] population finite, positive and at most 10 billion -- population=1,000,000
#>   [PASS] reference finite and non-negative -- reference=10
#>   [PASS] pollutant supported by the CRFs -- Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke). Other pollutants reject.
#> 
#> Concentration-response
#>   RR:       1.0286
#>   source:   Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines
#> 
#> Attributable fraction (PAF): 0.0273  (95% CI 0.0138 to 0.0534, from the risk's limits)
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
