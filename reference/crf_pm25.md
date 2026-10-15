# Concentration-response functions for PM2.5 and NO2

A concentration-response function (CRF) turns an air-pollution
concentration into the relative risk (RR) of a health outcome compared
with a counterfactual "clean air" level: an RR of 1.05 means 5% more
deaths (or cases) than at the reference concentration. These are the
first step of any burden estimate;
[`pollution_burden`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pollution_burden.md)
and
[`verify_pollution`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_pollution.md)
call them for you.

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

  Ambient concentration in micrograms per cubic metre, a single
  non-negative number or a vector of them (one per area, day or person).

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

  Optional log relative risk per 10 micrograms per cubic metre (a single
  finite number, e.g. `log(1.04)`) overriding the NO2 outcome table;
  `NULL` (the default) uses the table.

## Value

A list of class `rmbl_crf`
([`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
curve) with: `rr` and `log_rr`, the relative risk and its logarithm at
the exposure (their means over a vector of exposures); `rr_lower` and
`rr_upper`, the RR at the published 95% limits (`NA` where there are
none); `reference_conc`; `exposure_conc` (the exposure, or the mean of a
vector); `pollutant` (`"PM2.5"` or `"NO2"`); `citation` (the source as a
string); and `extra`, a list with the coefficient (`beta_per_10` and
`beta_per_10_ci` for the log-linear forms, `alpha`, `gamma`, `delta` for
the IER), `form` (PM2.5 only), `outcome`, and for a vector of exposures
`rr_per_unit`, the RR at each one.

## Details

`crf_pm25()` is log-linear for all-cause mortality with the pooled
cohort estimate of the WHO 2021 guideline review (Chen and Hoek 2020: RR
1.08, 95% CI 1.06-1.09, per 10 micrograms per cubic metre), \$\$RR(z) =
\exp(\ln(1.08) (z - z\_{cf}) / 10)\$\$ for \\z \> z\_{cf}\\ and 1
otherwise; for the cause-specific outcomes (ischaemic heart disease,
stroke) it is the Integrated Exposure-Response curve of Burnett et al.
(2014, equation 1), \$\$RR(z) = 1 + \alpha (1 - e^{-\gamma (z -
z\_{cf})^{\delta}}),\$\$ with the GBD 2013 parameter triples; the IER
was fitted per cause and has no all-cause form. `crf_no2()` is the
log-linear function of the WHO 2021 review (Huangfu and Atkinson 2020:
RR 1.02, 95% CI 1.01-1.04, per 10 micrograms per cubic metre for
all-cause mortality), \$\$RR(z) = \exp(\beta (z - z\_{cf}) / 10).\$\$ A
vector of exposures gives the mean RR and log-RR, with the per-unit
relative risks under `extra$rr_per_unit`.

Every function has zero excess risk at and below the reference
concentration (\\z \le z\_{cf}\\ gives RR 1). The published 95% limits
of the log-linear coefficients are carried through the same curve into
`rr_lower` and `rr_upper`; the IER parameters come without an interval,
so those are `NA` for `"ihd"` and `"stroke"`, and also when
`beta_per_10` is supplied.

Refusals: an unknown `outcome` (the message lists the available ones);
an exposure that is missing, infinite, negative, logical or empty; and a
`reference_conc` (or `beta_per_10`) that is not a single finite number,
or a negative `reference_conc`. A supplied `beta_per_10` may be negative
(a protective association) and replaces the table, in which case
`outcome` is only a label. The functions are pure computations: no file,
network or option is used.

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
# All-cause mortality at an annual PM2.5 of 12 micrograms per cubic metre.
r <- crf_pm25(12)
c(rr = r$rr, lower = r$rr_lower, upper = r$rr_upper)
#>       rr    lower    upper 
#> 1.048873 1.036787 1.054883 

# The cause-specific IER curve for ischaemic heart disease.
crf_pm25(12, outcome = "ihd")$rr
#> [1] 1.553634

# NO2 and respiratory deaths; at or below the reference there is no
# excess risk.
crf_no2(25, outcome = "respiratory")$rr
#> [1] 1.045336
crf_no2(8)$rr
#> [1] 1

# A vector of exposures (one per area): the mean RR and each area's RR.
crf_pm25(c(5, 12, 20))$extra$rr_per_unit
#> [1] 1.000000 1.048873 1.115480

# Your own coefficient: RR 1.04 per 10 micrograms per cubic metre.
crf_no2(30, beta_per_10 = log(1.04))$rr
#> [1] 1.0816

# An outcome without a published function is refused.
try(crf_pm25(12, outcome = "asthma"))
#> Error : Unknown outcome 'asthma'. Available: all_cause_mortality, ihd, stroke
```
