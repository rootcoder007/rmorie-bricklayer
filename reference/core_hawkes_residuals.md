# Time-rescaling residuals of a Hawkes process

\\U_i = 1 - \exp(-(\Lambda(t_i) - \Lambda(t\_{i-1})))\\, uniform on
(0, 1) when the model is right (Brown et al. 2002); computed in O(n) or
O(n w) by the shared C++ core.

## Usage

``` r
core_hawkes_residuals(
  times,
  horizon,
  kernel = c("exponential", "weibull", "gamma", "lomax"),
  par,
  baseline = c("constant", "sinusoidal")
)
```

## Arguments

- times:

  Sorted event times in `[0, horizon]`.

- horizon:

  End of the observation window.

- kernel:

  One of `"exponential"`, `"weibull"`, `"gamma"`, `"lomax"`.

- par:

  Parameters (baseline, eta, kernel), as
  [`core_hawkes_fit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_fit.md)
  returns them in `theta`.

- baseline:

  `"constant"` or `"sinusoidal"`.

## Value

A numeric vector of length `length(times)`.

## References

Brown EN, Barbieri R, Ventura V, Kass RE, Frank LM (2002). The
time-rescaling theorem and its application to neural spike train data
analysis. *Neural Comput.* 14, 325–346.
[doi:10.1162/08997660252741149](https://doi.org/10.1162/08997660252741149)

## Examples

``` r
set.seed(2)
times <- sort(stats::runif(200, 0, 50))
U <- core_hawkes_residuals(times, 50, "exponential", c(log(3), 0.2, 2))
stats::ks.test(U, "punif")$p.value
#> [1] 0.7935876
```
