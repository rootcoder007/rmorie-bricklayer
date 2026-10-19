# End-to-end pollution burden

Chains the concentration-response function, the attributable fraction
and the baseline case count into annual attributable cases, as the GBD
risk factor estimates do (GBD 2019 Risk Factors Collaborators 2020). Use
it for a single population (a city, a region) when you know its mean
exposure, its baseline rate and its size; for many areas at once see
[`polbrdarea`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdarea.md).

## Usage

``` r
polbrdn(
  expomean,
  expoprev,
  brate,
  pop,
  poll = "NO2",
  y = "allcause",
  refconc = NULL,
  rare = FALSE,
  hirate = FALSE
)
```

## Arguments

- expomean:

  Mean exposure among the exposed (micrograms per cubic metre). With
  `expoprev = 1` that is the population mean.

- expoprev:

  Proportion of the population at that level (1 for ambient air), in
  `[0, 1]`.

- brate:

  Cases per person-year in the unexposed scenario (a rate per person,
  not per 100,000: 0.008 is 800 per 100,000).

- pop:

  At-risk population (persons; any non-negative number).

- poll:

  `"PM2.5"` (also written `"PM25"`) or `"NO2"`, in either case.

- y:

  Outcome key passed to the concentration-response function;
  `extra$unit` says whether the attributable count is deaths or incident
  cases.

- refconc:

  Counterfactual concentration; `NULL` takes the pollutant's default
  (PM2.5 5.8, NO2 10; see
  [`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)).

- rare, hirate:

  `TRUE` to admit a baseline rate below 1e-5 (one per 100,000) or above
  0.1 (10,000 per 100,000) per person-year, as
  [`vrfpol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
  does: without them such a rate is refused, being also what a rate in
  the wrong unit looks like.

## Value

A list of class `rmbl_burden`
([`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it)
with: `paf` (the attributable fraction), `attrcases` and `basecases`
(per year), `population`, `brate` (per person-year), `expomean`,
`refconc` (the one used), `pollutant` (`"PM2.5"` or `"NO2"`), `citation`
(a string), and `extra`, a list with `rr`, `logrr`, `outcome` and `unit`
(`"deaths"` or `"incident cases"`).

## Details

The steps are: the relative risk at `expomean` from
[`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
or
[`crfno2`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
(with the reference concentration given or the pollutant's default); the
attributable fraction from
[`attrfrac`](https://rootcoder007.github.io/rmorie-bricklayer/reference/attrfrac.md)
with `expoprev`; the baseline cases \\y_0 N\\; and the attributable
cases, their product. The result is a yearly count of deaths (or
incident cases for `"chiast"`).

Refusals: an unknown pollutant, an outcome the pollutant's CRF does not
have, any input that is not a single finite non-negative number, and a
baseline rate outside the band described in
[`mortdisp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mortdisp.md)
unless `rare` or `hirate` admits it.

## References

GBD 2019 Risk Factors Collaborators (2020). Global burden of 87 risk
factors in 204 countries and territories, 1990-2019. The Lancet
396(10258), 1223-1249.

## Examples

``` r
# Ambient NO2 of 25 micrograms per cubic metre over a million people.
b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
b$attrcases
#> [1] 234.1369
b$paf
#> [1] 0.02926711

# PM2.5 and ischaemic heart disease deaths, against the WHO guideline
# of 5 as the counterfactual.
polbrdn(12, 1, 0.0012, 2.8e6, poll = "PM2.5", y = "ihd",
                 refconc = 5)$attrcases
#> [1] 1235.817

# Childhood asthma counts incident cases, not deaths.
polbrdn(30, 1, 0.012, 5e5, y = "chiast")$extra$unit
#> [1] "incident cases"

# Only PM2.5 and NO2 have concentration-response functions here.
try(polbrdn(40, 1, 0.008, 1e6, poll = "O3"))
#> Error : Unknown pollutant 'O3'. Use 'PM2.5' or 'NO2'.
```
