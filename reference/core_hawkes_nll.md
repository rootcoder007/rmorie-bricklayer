# Hawkes-process negative log-likelihood (C backend)

The negative log-likelihood of a univariate self-exciting Hawkes process
with constant baseline on `[0, horizon]`, for the event times `times`. A
Hawkes process is the natural model for arrivals that trigger further
arrivals – repeat calls to a service, aftershocks, retweet cascades,
revisions to an open-data release.

## Usage

``` r
core_hawkes_nll(
  times,
  horizon,
  kernel = c("exponential", "weibull", "lomax", "gamma"),
  par
)
```

## Arguments

- times:

  Sorted numeric vector of event times in `[0, horizon]`.

- horizon:

  End of the observation window (length-1, \> 0).

- kernel:

  One of `"exponential"`, `"weibull"`, `"lomax"`, `"gamma"`.

- par:

  Numeric parameter vector, as described above: length 3 for
  `"exponential"`, length 4 for the others.

## Value

A length-1 numeric: the negative log-likelihood, to be MINIMISED. A
parameter set outside the core's feasible region returns the sentinel
`1e12` rather than erroring, so the value can be handed straight to
[`stats::optim()`](https://rdrr.io/r/stats/optim.html) without the
optimiser walking off the domain.

## Details

Four triggering kernels are available. `"exponential"` is memoryless and
evaluates by an O(n) recursion; the other three are not, so they cost
O(n^2).

Parameters are passed on the scales the kernel is defined on:
`par = c(a0, eta, ...)` where `a0` is the LOG baseline intensity (\\\nu
= e^{a0}\\) and `eta` the branching ratio in (0, 1) – the expected
number of children per event, so the process is stationary only for
`eta < 1`. The remaining entries are the kernel's own shape parameters:
`beta` (exponential), `alpha, lambda` (Weibull), `alpha, c` (Lomax),
`alpha, beta` (gamma).

## References

Hawkes AG (1971). Spectra of some self-exciting and mutually exciting
point processes. *Biometrika* 58(1), 83–90.
[doi:10.1093/biomet/58.1.83](https://doi.org/10.1093/biomet/58.1.83)

## Examples

``` r
set.seed(4)
times <- sort(stats::runif(40, 0, 10))

# Exponential kernel: log-baseline -0.5, branching 0.3, decay 1.2.
core_hawkes_nll(times, 10, "exponential", c(-0.5, 0.3, 1.2))
#> [1] -1.8753

# Lower is better, so this is what an optimiser minimises.
nll <- function(p) core_hawkes_nll(times, 10, "exponential", p)
fit <- stats::optim(c(-0.5, 0.3, 1.2), nll)
fit$par
#> [1] 1.03407757 0.99899989 0.08854609

# A branching ratio at or above 1 is not a stationary process, and is
# reported as the infeasible sentinel rather than a number.
core_hawkes_nll(times, 10, "exponential", c(-0.5, 1.5, 1.2)) == 1e12
#> [1] TRUE

# The heavier-tailed kernels take two shape parameters.
core_hawkes_nll(times, 10, "gamma", c(-0.5, 0.3, 2, 1.5))
#> [1] -1.550628
```
