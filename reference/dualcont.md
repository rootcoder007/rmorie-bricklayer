# Wellness and distress as two continua

For each group, one wellness indicator against one distress indicator,
each with its published interval, and the ratio of the two: the
dual-continua view of mental health, in which wellness is not the
absence of distress and is measured in its own right.

## Usage

``` r
dualcont(x, well, distress, conflvl = 0.95)
```

## Arguments

- x:

  A
  [`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md).

- well, distress:

  One wellness and one distress indicator of `x`.

- conflvl:

  Confidence level of the published intervals and of the ratio (default
  0.95).

## Value

A data frame of class `rmbl_dual_continuum`: `group`, `wellness`,
`wello`, `welup`, `distress`, `distrlo`, `distrup`, `strratio`,
`ratiolo`, `ratioup`, `usewithcau`.

## Details

Keyes (2002, 2005) showed that flourishing and mental illness are
correlated but distinct axes: a person, or a population, can carry
distress and also wellness. That is how Indigenous scholars of mental
health describe it too, as wellness and as a process of healing rather
than as illness alone (Stewart 2008). Plotting the groups on both axes
keeps a strength visible beside the burden it sits next to. The
`strratio` is \\R = W / D\\, wellness over distress, with the log-normal
interval \\\exp\\\log R \pm z\sqrt{\sigma_W^2 + \sigma_D^2}\\\\ from the
two published intervals: above 1, more people report the wellness than
the distress. The two estimates come from the same respondents; their
covariance is not published, so the interval treats them as independent
and is too narrow when they are negatively correlated, as answers about
wellness and distress usually are. Any two indicators on one scale can
be set against each other.

## Acknowledgement

This estimator puts to quantitative use the framework of Professor
Suzanne Stewart (Yellowknives Dene First Nation, University of Toronto);
see the acknowledgements of
[`vignette("first-nations-metis-inuit-health")`](https://rootcoder007.github.io/rmorie-bricklayer/articles/first-nations-metis-inuit-health.md).

## References

Keyes CLM (2002). The mental health continuum: from languishing to
flourishing in life. Journal of Health and Social Behavior
43(2):207-222. [doi:10.2307/3090197](https://doi.org/10.2307/3090197)

Keyes CLM (2005). Mental illness and/or mental health? Investigating
axioms of the complete state model of health. Journal of Consulting and
Clinical Psychology 73(3):539-548.
[doi:10.1037/0022-006X.73.3.539](https://doi.org/10.1037/0022-006X.73.3.539)

Stewart SL (2008), see
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md).

## See also

[`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md).

## Examples

``` r
wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = "Always or often has a hopeful outlook",
                      distress = "Life satisfaction rating between 0 and 5",
                      qual = "quality")
dc <- dualcont(w, "Always or often has a hopeful outlook",
                     "Life satisfaction rating between 0 and 5")
dc
#>           group wellness wello welup distress distrlo distrup strratio  ratiolo
#> 1 First Nations     50.2  45.9  54.5     31.4    27.4    35.7 1.598726 1.365446
#> 2         Métis     52.3  47.6  57.0     28.4    24.0    33.1 1.841549 1.531631
#> 3         Inuit     54.4  45.7  62.8     25.2    19.4    31.8 2.158730 1.609182
#>    ratioup usewithcau
#> 1 1.871862      FALSE
#> 2 2.214178      FALSE
#> 3 2.895953      FALSE
plot(dc)
```
