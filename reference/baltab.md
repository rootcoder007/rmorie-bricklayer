# A covariate balance table

Means of each covariate in the treated and comparison groups, their
standardised mean difference, and Welch's test, optionally weighted
(after matching or weighting).

## Usage

``` r
baltab(data, grp, covs, w = NULL)
```

## Arguments

- data:

  A data frame, one row per unit.

- grp:

  Column name of the 0/1 group (1 = treated).

- covs:

  Column names to compare.

- w:

  Optional column name of weights.

## Value

A data frame of class `rmbl_balance`: `covariate`, `meantrtd`,
`meanctl`, `smd`, `p_value`.

## Details

The standardised mean difference is \\(\bar x_1 - \bar x_0) / s_1\\ with
\\s_1\\ the unweighted standard deviation in the treated group (the
convention for the effect on the treated, so that it does not move when
weights change the comparison group); \\\|SMD\| \< 0.1\\ is the usual
threshold for balance. With weights the means are weighted and the test
uses the weighted variances and Kish's effective sample sizes.

## References

Welch BL (1947). The generalization of 'Student's' problem when several
different population variances are involved. Biometrika 34(1-2):28-35.
[doi:10.1093/biomet/34.1-2.28](https://doi.org/10.1093/biomet/34.1-2.28)

## Examples

``` r
d <- data.frame(t = rep(0:1, each = 50),
                age = c(stats::rnorm(50, 30), stats::rnorm(50, 33)))
baltab(d, "t", "age")
#>   covariate meantrtd  meanctl      smd      p_value
#> 1       age 32.80419 30.09459 2.747349 1.777265e-26
```
