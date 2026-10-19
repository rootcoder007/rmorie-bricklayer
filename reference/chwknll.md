# Hawkes-process negative log-likelihood (C backend)

The negative log-likelihood of a univariate self-exciting Hawkes process
with constant baseline on `[0, horizon]`, for the event times `times`. A
Hawkes process is the natural model for arrivals that trigger further
arrivals – repeat calls to a service, aftershocks, retweet cascades,
revisions to an open-data release.

## Usage

``` r
chwknll(
  times,
  hor,
  kernel = c("exponential", "weibull", "lomax", "gamma"),
  par
)
```

## Arguments

- times:

  Numeric vector of event times, sorted increasing, each in
  `[0, horizon]`, in the time unit of your data (days, hours, ...). May
  be empty.

- hor:

  End of the observation window, a single positive finite number in the
  same unit; the window starts at 0.

- kernel:

  The triggering kernel, one of `"exponential"` (the default),
  `"weibull"`, `"lomax"` and `"gamma"`. Partial names are matched.

- par:

  Numeric parameter vector, as described above: length 3 (`a0`, `eta`,
  `beta`) for `"exponential"`, length 4 (`a0`, `eta` and the kernel's
  two parameters) for the others. Rates are per unit of `times`.

## Value

A length-1 numeric: the negative log-likelihood, to be MINIMISED. A
parameter set outside the feasible region returns the sentinel `1e12`
rather than erroring, so the value can be handed straight to
[`stats::optim()`](https://rdrr.io/r/stats/optim.html) without the
optimiser walking off the domain.

## Details

Four triggering kernels are available. `"exponential"` is memoryless and
evaluates by an O(n) recursion; the other three are not, so they cost
O(n^2).

Parameters are passed on the scales the kernel is defined on:
`par = c(a0, eta, ...)` where `a0` is the LOG baseline intensity ( \\\nu
= e^{a0}\\) and `eta` the branching ratio in (0, 1) – the expected
number of children per event, so the process is stationary only for
`eta < 1`. The remaining entries are the kernel's own shape parameters:
`beta` (exponential), `alpha, lambda` (Weibull: shape and scale),
`alpha, c` (Lomax: shape and scale, \\g(u) = \alpha c^\alpha (u +
c)^{-(\alpha + 1)}\\), `alpha, beta` (gamma: shape and rate). This is
the likelihood
[`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md)
maximises, on the same parameters.

The conditional intensity is \\\lambda(t) = \nu + \eta \sum\_{t_i \< t}
g(t - t_i)\\ with \\g\\ a probability density on \\(0, \infty)\\ (so
\\\eta\\ is the branching ratio), and the value returned is \$\$-\ell =
-\sum_i \log \lambda(t_i) + \int_0^T \lambda(t)\\dt,\$\$ with \\T\\ =
`hor` (Hawkes, 1971). For the exponential kernel \\g(u) = \beta
e^{-\beta u}\\. With no events the value is the compensator alone, \\\nu
T\\.

The feasible region, outside which the sentinel `1e12` is returned
instead of a value: \\-20 \< a_0 \< 20\\; \\10^{-6} \< \eta \< 0.999\\;
and for the kernel parameters, exponential \\0.05 \le \beta \le 30\\;
Weibull shape in \\\[0.05, 20\]\\ and scale in \\\[0.001, 1000\]\\;
Lomax shape in \\\[0.05, 30\]\\ and scale in \\\[0.001, 100\]\\; gamma
shape in \\\[0.05, 20\]\\ and rate in \\\[0.05, 30\]\\. A missing
parameter also gives the sentinel.

Refusals (errors, not the sentinel): `times` with a missing value, not
sorted, or outside \\\[0, T\]\\; a `hor` that is not a single positive
finite number; a `kernel` not among the four; and a `par` of the wrong
length for the kernel. The quadratic kernels poll for a Ctrl-C as they
run, so a long evaluation can be interrupted.

## References

Hawkes AG (1971). Spectra of some self-exciting and mutually exciting
point processes. *Biometrika* 58(1), 83–90.
[doi:10.1093/biomet/58.1.83](https://doi.org/10.1093/biomet/58.1.83)

## Examples

``` r
set.seed(4)
times <- sort(stats::runif(40, 0, 10))

# Exponential kernel: log-baseline -0.5, branching 0.3, decay 1.2.
chwknll(times, 10, "exponential", c(-0.5, 0.3, 1.2))
#> [1] -1.8753

# Lower is better, so this is what an optimiser minimises.
nll <- function(p) chwknll(times, 10, "exponential", p)
fit <- stats::optim(c(-0.5, 0.3, 1.2), nll)
fit$par
#> [1] 1.03407757 0.99899989 0.08854609

# A branching ratio at or above 1 is not a stationary process, and is
# reported as the infeasible sentinel rather than a number.
chwknll(times, 10, "exponential", c(-0.5, 1.5, 1.2)) == 1e12
#> [1] TRUE

# The heavier-tailed kernels take two shape parameters.
chwknll(times, 10, "gamma", c(-0.5, 0.3, 2, 1.5))
#> [1] -1.550628

# Unsorted times are an error, not the sentinel.
try(chwknll(rev(times), 10, "exponential", c(-0.5, 0.3, 1.2)))
#> Error : `times` must be sorted in increasing order
```
