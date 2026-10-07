# Deaths avoided under a counterfactual exposure reduction

The BenMAP-CE health-impact function (US EPA 2018; Anenberg et al.
2010): \$\$\Delta Y = y_0 N (1 - e^{-\beta \Delta x}).\$\$

## Usage

``` r
mortality_displaced(exposure_delta, population, baseline_rate, beta_per_unit)
```

## Arguments

- exposure_delta:

  Counterfactual reduction in exposure (positive means the exposure goes
  down).

- population:

  At-risk population.

- baseline_rate:

  Baseline rate in cases per person-year.

- beta_per_unit:

  Log-RR per unit of exposure (per unit, not per 10).

## Value

Expected avoided cases.

## References

US EPA (2018). Environmental Benefits Mapping and Analysis Program -
Community Edition, user manual. Anenberg, S. C. et al. (2010). An
estimate of the global burden of anthropogenic ozone and fine
particulate matter on premature human mortality using atmospheric
modeling. Environmental Health Perspectives 118(9), 1189-1195.

## Examples

``` r
mortality_displaced(10, 1e6, 0.008, 0.0039)
#> [1] 305.9943
```
