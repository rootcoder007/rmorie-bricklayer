# Fit a Hawkes process by maximum likelihood (analytic gradient, fast routes)

Maximum-likelihood fit of a univariate Hawkes process \\\lambda(t) =
\nu(t) + \eta \sum\_{t_j \< t} g(t - t_j)\\ with a constant baseline
(\\\nu = e^{a_0}\\) or a sinusoidal one (\\\nu(t) = \exp(a_0 + a_1 t/T +
a_2 \sin(2\pi t/365.25) + a_3 \cos(2\pi t/365.25))\\, its integral by
the trapezoid rule on `max(64, floor(T) + 1)` points) and one of four
normalised kernels: exponential (decay `beta`), Weibull
(`alpha, lambda`), gamma (`alpha, beta`) or Lomax (`alpha, c`). Every
route uses the analytic gradient, so one likelihood evaluation per point
instead of one per parameter.

## Usage

``` r
core_hawkes_fit(
  times,
  horizon,
  kernel = c("exponential", "weibull", "gamma", "lomax"),
  baseline = c("constant", "sinusoidal"),
  method = "auto",
  eps = 1e-09,
  start = NULL
)
```

## Arguments

- times:

  Sorted event times in `[0, horizon]`.

- horizon:

  End of the observation window.

- kernel:

  One of `"exponential"`, `"weibull"`, `"gamma"`, `"lomax"`.

- baseline:

  `"constant"` or `"sinusoidal"`.

- method:

  One of `"auto"`, `"exact"`, `"soe"`, `"truncate"`, `"em"`, `"inar"`.

- eps:

  Error level of `"soe"` (relative, per intensity) and `"truncate"`
  (kernel tail mass).

- start:

  Optional starting values (baseline, eta, kernel).

## Value

A list: `theta`, `baseline_params`, `branching_ratio`, `kernel_params`,
`nll`, `aic`, `bic`, `n`, `horizon`, `k_params`, `ks_stat`, `ks_pvalue`
(time-rescaling residuals against the uniform), `method`, `eps`,
`converged` (the optimiser stopped at a maximum within the parameter
box) and `at_bound` (the parameters that lie on the box, `character(0)`
for an interior maximum). An estimate on the box is not an interior
maximum of the likelihood: day-dated (tied) times drive a shape or decay
to its wall, and a Lomax fitted to exponential data runs to its
exponential limit. Events at the same instant do not excite each other:
the intensity is \\\lambda(t) = \nu(t) + \eta \sum\_{t_j \< t} g(t -
t_j)\\, over strictly earlier events, as the definition of a Hawkes
process (a simple point process, with no two events at one time) has it.
Tied times are fitted that way, with a warning: data recorded to a
resolution, such as daily dates, carry ties the process itself never
makes, and treating them as exact biases the fit (Filimonov & Sornette
2015), so spread them uniformly across their interval first with
[`core_hawkes_jitter()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_jitter.md).

## Details

- `"exact"`:

  Ozaki's O(n) recursion for the exponential kernel; for Weibull and
  gamma the double sum stops where the kernel underflows to exactly 0
  (the same value as the full sum); Lomax the full O(n^2) sum.

- `"soe"`:

  the completely monotone kernels (Lomax; gamma with shape \< 1) as a
  sum of exponentials (Beylkin & Monzon 2010): relative error `eps` on
  every intensity, O(n K); a gamma kernel with shape \>= 1 is truncated
  at `eps`.

- `"truncate"`:

  each event excites only lags with kernel tail mass above `eps`: an
  approximation for light-tailed kernels, O(n w).

- `"em"`:

  the EM algorithm (Veen & Schoenberg 2008), finished by the projected
  BFGS on the exact likelihood from EM's point (EM's steps shrink before
  it reaches the maximum): the same maximum, a different route.

- `"inar"`:

  Kirchner's (2017) INAR(p) least-squares estimator on binned counts
  (constant baseline only): a different, fast, approximate estimator.

- `"auto"`:

  `"exact"` for the exponential kernel, `"truncate"` for Weibull,
  `"soe"` for gamma and Lomax.

The reported `nll` is the exact likelihood at the estimate whatever the
route, so AIC is comparable across routes. An event exactly at `horizon`
is part of the record and counted, as in morie's Python fit.

## References

Ozaki T (1979). Maximum likelihood estimation of Hawkes' self-exciting
point processes. *Ann. Inst. Statist. Math.* 31, 145–155.
[doi:10.1007/BF02480272](https://doi.org/10.1007/BF02480272)

Beylkin G, Monzon L (2010). Approximation by exponential sums revisited.
*Appl. Comput. Harmon. Anal.* 28, 131–149.
[doi:10.1016/j.acha.2009.08.011](https://doi.org/10.1016/j.acha.2009.08.011)

Veen A, Schoenberg FP (2008). Estimation of space-time branching process
models in seismology using an EM-type algorithm. *JASA* 103, 614–624.
[doi:10.1198/016214508000000148](https://doi.org/10.1198/016214508000000148)

Kirchner M (2017). An estimation procedure for the Hawkes process.
*Quant. Finance* 17, 571–595.
[doi:10.1080/14697688.2016.1211312](https://doi.org/10.1080/14697688.2016.1211312)

Filimonov V, Sornette D (2015). Apparent criticality and calibration
issues in the Hawkes self-excited point process model: application to
high-frequency financial data. *Quant. Finance* 15(8), 1293–1314.
[doi:10.1080/14697688.2015.1032544](https://doi.org/10.1080/14697688.2015.1032544)

## See also

[`core_hawkes_jitter()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_jitter.md),
for times recorded to a resolution.

## Examples

``` r
set.seed(1)
times <- sort(stats::runif(400, 0, 100))
fit <- core_hawkes_fit(times, 100, "exponential")
fit$branching_ratio
#> [1] 0.02919195
core_hawkes_fit(times, 100, "lomax", method = "soe", eps = 1e-8)$nll
#> [1] -156.388
core_hawkes_fit(times, 100, "exponential", baseline = "sinusoidal")$aic
#> [1] -305.1927
```
