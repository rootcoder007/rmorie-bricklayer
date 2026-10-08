# Concentration-response functions for PM2.5 and NO2

`crf_pm25()` is log-linear for all-cause mortality with the pooled
cohort estimate of the WHO 2021 guideline review (Chen and Hoek 2020: RR
1.08, 95\\ \$\$RR(z) = \exp(\ln(1.08) (z - z\_{cf}) / 10)\$\$ for \\z \>
z\_{cf}\\ and 1 otherwise; for the cause-specific outcomes (ischaemic
heart disease, stroke) it is the Integrated Exposure-Response curve of
Burnett et al. (2014, equation 1), \$\$RR(z) = 1 + \alpha (1 -
e^{-\gamma (z - z\_{cf})^{\delta}}),\$\$ with the GBD 2013 parameter
triples; the IER was fitted per cause and has no all-cause form.
`crf_no2()` is the log-linear function of the WHO 2021 review (Huangfu
and Atkinson 2020: RR 1.02, 95\\ micrograms per cubic metre for
all-cause mortality), \$\$RR(z) = \exp(\beta (z - z\_{cf}) / 10).\$\$ A
vector of exposures gives the mean RR and log-RR, with the per-unit
relative risks under `extra$rr_per_unit`.

## Usage

``` r
crf_pm25(exposure, outcome = "all_cause_mortality", reference_conc = 5.8)

crf_no2(
  exposure,
  outcome = "all_cause_mortality",
  reference_conc = 10,
  beta_per_10 = NULL
)
```

## Arguments

- exposure:

  Ambient concentration in micrograms per cubic metre, a scalar or a
  vector.

- outcome:

  PM2.5: `"all_cause_mortality"`, `"ihd"` or `"stroke"` (deaths). NO2:
  `"all_cause_mortality"` and `"respiratory"` (deaths; Huangfu and
  Atkinson 2020, RR 1.02 and 1.03 per 10 micrograms per cubic metre) or
  `"childhood_asthma"` (incident cases, not deaths; Khreis et al. 2017,
  OR 1.05 per 4 micrograms per cubic metre, scaled to per 10).

- reference_conc:

  Counterfactual concentration below which no excess risk is assumed.
  PM2.5 default 5.8, the lower bound of the GBD 2019 theoretical minimum
  risk exposure level (the WHO 2021 guideline is 5); NO2 default 10, the
  WHO 2021 guideline.

- beta_per_10:

  Optional log-RR per 10 units overriding the NO2 outcome table.

## Value

A list of class `rmbl_crf` with `rr`, `log_rr`, `reference_conc`,
`exposure_conc`, `pollutant`, `citation` and `extra`.

## References

Chen, J. and Hoek, G. (2020). Long-term exposure to PM and all-cause and
cause-specific mortality: a systematic review and meta-analysis.
Environment International 143, 105974. Huangfu, P. and Atkinson, R.
(2020). Long-term exposure to NO2 and O3 and all-cause and respiratory
mortality: a systematic review and meta-analysis. Environment
International 144, 105998. Khreis, H. et al. (2017). Exposure to
traffic-related air pollution and risk of development of childhood
asthma: a systematic review and meta-analysis. Environment International
100, 1-31. GBD 2019 Risk Factors Collaborators (2020). The Lancet
396(10258), 1223-1249. Burnett, R. T. et al. (2014). An integrated risk
function for estimating the global burden of disease attributable to
ambient fine particulate matter exposure. Environmental Health
Perspectives 122(4), 397-403. WHO (2021). Global Air Quality Guidelines.

## Examples

``` r
crf_pm25(12)$rr
#> [1] 1.048873
crf_pm25(12, outcome = "ihd")$rr
#> [1] 1.553634
crf_no2(25, outcome = "respiratory")$rr
#> [1] 1.045336
crf_pm25(c(5, 12, 20))$extra$rr_per_unit
#> [1] 1.000000 1.048873 1.115480
```
