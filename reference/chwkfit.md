# Fit a Hawkes process by maximum likelihood (analytic gradient, fast routes)

Fits a self-exciting (Hawkes) point process to a series of event times,
such as the times of shootings, break-ins or calls for service, and
returns the estimated background rate, the branching ratio (the share of
events triggered by earlier events) and the shape of the triggering
kernel, with AIC, BIC and a goodness-of-fit test. Use it to ask whether
events cluster in time beyond what a steady or seasonal rate explains.

## Usage

``` r
chwkfit(
  times,
  hor,
  kernel = c("exponential", "weibull", "gamma", "lomax"),
  base = c("constant", "sinusoidal"),
  meth = "auto",
  eps = 1e-09,
  start = NULL
)
```

## Arguments

- times:

  Numeric vector of event times, sorted increasingly, all in
  `[0, horizon]`, in any time unit (days are the natural unit for the
  sinusoidal baseline's yearly cycle). At least 50 events.

- hor:

  End of the observation window, one positive number in the same unit as
  `times`; the window is `[0, horizon]`. With the sinusoidal baseline
  (an annual cycle, `times` in days) at most 4194304 days: that baseline
  is integrated a day at a time.

- kernel:

  The triggering kernel: `"exponential"` (the default), `"weibull"`,
  `"gamma"` or `"lomax"`.

- base:

  `"constant"` (the default) or `"sinusoidal"` (trend plus a 365.25-unit
  cycle).

- meth:

  One of `"auto"` (the default), `"exact"`, `"soe"`, `"truncate"`,
  `"em"`, `"inar"`. `"auto"` is `"exact"` for the exponential kernel,
  `"truncate"` for Weibull and `"soe"` for Lomax and gamma.

- eps:

  Error level, one number in (0, 1), default `1e-9`: the relative error
  per intensity of `"soe"` and the kernel tail mass dropped by
  `"truncate"`. Ignored by the other routes.

- start:

  Optional numeric vector of starting values in the order of `theta`:
  the baseline terms (`a0`, or `a0..a3`), then `eta`, then the kernel
  parameters. Values outside the parameter box are moved onto it. `NULL`
  (the default) uses a start from the data.

## Value

A list:

- `theta`:

  numeric, all estimates in the order baseline, `eta`, kernel.

- `basepar`:

  numeric, `a0` (constant) or `a0..a3` (sinusoidal), on the log scale.

- `braratio`:

  numeric, \\\eta\\, the expected number of events each event triggers.

- `kerpar`:

  numeric, the kernel parameters (`beta`; `alpha, lambda`;
  `alpha, beta`; or `alpha, c`).

- `nll`, `aic`, `bic`:

  numeric: the exact negative log-likelihood, \\2k + 2\\nll\\ and \\k
  \log n + 2\\nll\\.

- `n`, `horizon`, `kpar`:

  the number of events (integer), the window end and the number of
  parameters (integer).

- `ksstat`, `kspva`:

  numeric, the Kolmogorov-Smirnov test of the time-rescaling residuals
  against the uniform.

- `kernel`, `baseline`, `method`:

  character, the choices used (`method` after `"auto"` is resolved).

- `eps`:

  numeric, `eps` for `"soe"` and `"truncate"`, `NA` otherwise.

- `converged`:

  logical, the optimiser stopped at a maximum within the parameter box
  (before its iteration limit, at a finite likelihood). A maximum on the
  box counts: `atbound` names the parameters that lie on it.

- `atbound`:

  character, the names of parameters that lie on the box (`character(0)`
  for an interior maximum).

A warning is given when \\\eta\\ reaches its upper bound 0.99 (a
near-critical, probably non-stationary fit). An estimate on the box is
not an interior maximum of the likelihood: day-dated (tied) times drive
a shape or decay to its wall, and a Lomax fitted to exponential data
runs to its exponential limit.

## Details

The model is the univariate Hawkes process \$\$\lambda(t) = \nu(t) +
\eta \sum\_{t_j \< t} g(t - t_j)\$\$ with a constant baseline (\\\nu =
e^{a_0}\\) or a sinusoidal one (\\\nu(t) = \exp(a_0 + a_1 t/T + a_2
\sin(2\pi t/365.25) + a_3 \cos(2\pi t/365.25))\\, a trend plus a yearly
cycle when times are in days, its integral by the trapezoid rule on
`max(64, floor(T) + 1)` points), branching ratio \\\eta \in \[0.001,
0.99\]\\ and one of four normalised kernels \\g\\: exponential (decay
`beta`), Weibull (shape `alpha`, scale `lambda`), gamma (shape `alpha`,
rate `beta`) or Lomax (shape `alpha`, scale `c`). The log-likelihood is
\\\sum_i \log \lambda(t_i) - \int_0^T \lambda(t)\\dt\\. Every route uses
the analytic gradient of the shared C++ core (the code morie's Python
arm calls), so one likelihood evaluation per point instead of one per
parameter. The optimiser is a projected BFGS inside a fixed parameter
box (\\a_0 \in \[-15, 15\]\\, the other baseline terms in \\\[-5, 5\]\\,
kernel parameters bounded as listed in the source), at most 2000
iterations.

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
  it reaches the maximum). It is an R loop of up to 500 iterations and
  much slower than the other routes (tens of seconds for a few hundred
  events); because it starts from the same point but moves differently,
  it can end at a different local maximum.

- `"inar"`:

  Kirchner's (2017) INAR(p) least-squares estimator on binned counts
  (constant baseline only): a different, fast, approximate estimator.

- `"auto"`:

  `"exact"` for the exponential kernel, `"truncate"` for Weibull,
  `"soe"` for gamma and Lomax.

For the Weibull, gamma and Lomax kernels without `start`, a second
deterministic start at the exponential fit (the shape-1 member) is also
run and the better optimum kept, because the likelihood is multimodal.
The exponential kernel without `start` is also run from a second start
(branching ratio 0.1 and a decay a quarter of the reciprocal mean gap),
and the better optimum kept: on data with little clustering its
likelihood can have more than one maximum, one of them with the decay on
its bound. A parameter on its bound (see `atbound`) is still a reason to
refit from another `start` and compare `nll`.

The reported `nll` is the exact likelihood at the estimate whatever the
route, so AIC is comparable across routes. An event exactly at `hor` is
part of the record and counted, as in morie's Python fit. The
Kolmogorov-Smirnov test compares the time-rescaling residuals of
[`chwkres()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkres.md)
with the uniform distribution (exact p-value up to 10,000 events without
ties, asymptotic otherwise).

Events at the same instant do not excite each other: the intensity sums
over strictly earlier events, as the definition of a Hawkes process (a
simple point process, with no two events at one time) has it. Tied times
are fitted that way, with a warning: data recorded to a resolution, such
as daily dates, carry ties the process itself never makes, and treating
them as exact biases the fit (Filimonov & Sornette 2015), so spread them
uniformly across their interval first with
[`chwkjit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkjit.md).

Errors: `times` with `NA`, unsorted, or outside `[0, horizon]`; `hor`
not one positive finite number; fewer than 50 events; an event rate
`n / horizon` outside \\\[e^{-15}, 100 e^{15}\]\\ per unit time (rescale
the times); `eps` not in (0, 1); `start` of the wrong length or with a
non-finite likelihood; `method = "soe"` with a kernel other than Lomax
or gamma; `method = "inar"` with the sinusoidal baseline. Long fits show
a progress spinner (EM a bar) on stderr unless
`options(morie.quiet = TRUE)`.

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

[`chwkjit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkjit.md),
for times recorded to a resolution;
[`chwkres()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkres.md)
for the residuals.

## Examples

``` r
set.seed(1)
times <- sort(stats::runif(400, 0, 100))
fit <- chwkfit(times, 100, "exponential")
fit$braratio
#> [1] 0.3996747
fit$atbound # an interior maximum: the better of two starts
#> character(0)
# one start alone can stop with the decay on its bound, at a worse nll
chwkfit(times, 100, "exponential", start = c(log(2.4), 0.4, 4))$atbound
#> [1] "beta"
fit$nll
#> [1] -156.4648
chwkfit(times, 100, "lomax", meth = "soe", eps = 1e-8)$nll
#> [1] -156.388
chwkfit(times, 100, "exponential", base = "sinusoidal")$aic
#> [1] -305.1927

# the fast approximate INAR estimator
chwkfit(times, 100, meth = "inar")$braratio
#> [1] 0.005597589

# daily dates: spread the ties across each day first
days <- floor(times)
jit <- chwkjit(days, hor = 100)
chwkfit(jit, 100)$converged
#> [1] TRUE

# too few events, or times past the horizon, are refused
try(chwkfit(times[1:20], 100))
#> Error : too few events (20) for the fit
try(chwkfit(times, 50))
#> Error : `times` must lie within [0, hor] (they span 1.30776 to 99.6077); chwkjit(times, hor = ) keeps them inside
```
