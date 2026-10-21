# Deaths avoided under a counterfactual exposure reduction

The expected number of deaths (or cases) a year that a given drop in
exposure would avoid in a population, from the baseline rate and a
log-linear concentration-response coefficient. This is the health-impact
function used in regulatory benefit assessments, for questions such as
“how many deaths would a 5 microgram cut in PM2.5 avoid in this city?”.

## Usage

``` r
mortdisp(expdel, pop, brate, betaperunit, rare = FALSE, hirate = FALSE)
```

## Arguments

- expdel:

  Counterfactual reduction in exposure, in the unit of `betaperunit`
  (positive means the exposure goes down).

- pop:

  At-risk population, a non-negative number of persons.

- brate:

  Baseline rate in cases per person-year (0.008 is 800 per 100,000).

- betaperunit:

  Log relative risk per unit of exposure (per unit, not per 10), a
  single finite number.

- rare, hirate:

  `TRUE` to admit a baseline rate below 1e-5 (one per 100,000) or above
  0.1 (10,000 per 100,000) per person-year; without them such a rate is
  refused, being also what a rate in the wrong unit looks like.

## Value

A single number: the expected cases avoided per year (negative for an
increase in exposure).

## Details

The BenMAP-CE health-impact function (US EPA 2018; Anenberg et al.
2010): \$\$\Delta Y = y_0 N (1 - e^{-\beta \Delta x}),\$\$ with \\y_0\\
the baseline rate per person-year, \\N\\ the population, \\\beta\\ the
log relative risk per unit of exposure and \\\Delta x\\ the reduction. A
negative `expdel` (an increase) gives a negative number, the extra
cases. A coefficient published per 10 units must be divided by 10 first
(for example `log(1.08) / 10` for the PM2.5 all-cause RR of 1.08 per
10).

The baseline rate is per person-year, not per 100,000: 800 deaths per
100,000 a year is 0.008. A rate below 1e-5 or above 0.1 is refused
unless `rare` or `hirate` says it is meant, because it is also what a
rate in the wrong unit looks like; a rate above 1, or below 1e-11, is
always refused. Every input must be a single finite number, and the
population and rate non-negative.

## References

US EPA (2018). Environmental Benefits Mapping and Analysis Program -
Community Edition, user manual. Anenberg, S. C. et al. (2010). An
estimate of the global burden of anthropogenic ozone and fine
particulate matter on premature human mortality using atmospheric
modeling. Environmental Health Perspectives 118(9), 1189-1195.

## See also

[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
for the cases attributable to the whole excess exposure,
[`vrfpol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)
which runs both.

## Examples

``` r
# A 10-unit cut, a million people, 800 deaths per 100,000 a year.
mortdisp(10, 1e6, 0.008, 0.0039)
#> [1] 305.9943

# The PM2.5 all-cause coefficient is published per 10 micrograms.
mortdisp(5, 2.8e6, 0.0075, log(1.08) / 10)
#> [1] 792.7406

# A rare outcome must be declared.
mortdisp(5, 1e6, 5e-6, 0.01, rare = TRUE)
#> [1] 0.2438529

# A rate per 100,000 passed as a rate per person is refused.
try(mortdisp(10, 1e6, 800, 0.0039))
#> Error : `brate` is a rate per person-year, between 0 and 1 (0.008 is 800 per 100,000); 800 looks like a rate per 100,000, which only vrfpol() takes
```
