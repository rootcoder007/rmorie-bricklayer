# Spread event times recorded to a resolution across their interval

Daily (or hourly, or second) timestamps put every event of an interval
at one time, but a Hawkes process never has two events at one instant,
and fitting the rounded times as exact biases the estimates (Filimonov &
Sornette 2015). This function spreads each recorded time uniformly over
the interval it stands for, so the times can be passed to
[`core_hawkes_fit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_fit.md).

## Usage

``` r
core_hawkes_jitter(times, resolution = 1, seed = 42, horizon = Inf)
```

## Arguments

- times:

  Numeric event times, each the start of its resolution interval (for
  example whole days since an origin).

- resolution:

  The width of the interval a recorded time stands for, one positive
  number in the unit of `times`: 1 (the default) for daily dates in
  days, `1/24` for hourly times in days.

- seed:

  Seed of the uniforms, as in
  [`core_uniforms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md);
  default 42.

- horizon:

  End of the observation window, when it cuts an interval short: an
  event recorded at `t` is spread over
  `[t, min(t + resolution, horizon)]`, so a time dated on the horizon
  itself stays there (`Inf`, the default: no window).

## Value

A numeric vector of the jittered times, the same length as `times`,
sorted increasingly.

## Details

Each time becomes `t + w * U`, with `w = min(resolution, horizon - t)`
and `U` uniform on \[0, 1), and the result is sorted; this is the remedy
Filimonov and Sornette use. The times are sorted (radix order) before
the uniforms are assigned, so the result does not depend on the input
order. The uniforms are the splitmix64 stream of
[`core_uniforms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md),
so the result is reproducible and, on daily dates with `seed = 42`, the
same as the jitter rmorie and morie (Python) apply before their TPS
Hawkes fits. R's random number generator is not used.

Errors: `times` with `NA` or non-finite values; `resolution` not one
positive finite number; `horizon` not one number; a time past `horizon`.

## References

Filimonov V, Sornette D (2015). Apparent criticality and calibration
issues in the Hawkes self-excited point process model: application to
high-frequency financial data. *Quant. Finance* 15(8), 1293–1314.
[doi:10.1080/14697688.2015.1032544](https://doi.org/10.1080/14697688.2015.1032544)

## See also

[`core_hawkes_fit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_hawkes_fit.md),
[`core_uniforms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md)

## Examples

``` r
days <- c(0, 0, 0, 1, 3, 3)
core_hawkes_jitter(days)
#> [1] 0.1599104 0.2786011 0.7415649 1.3441907 3.0380302 3.8682281
anyDuplicated(core_hawkes_jitter(days))
#> [1] 0

# a horizon keeps the last day inside the window
core_hawkes_jitter(c(0, 1, 2), horizon = 2)
#> [1] 0.7415649 1.1599104 2.0000000

# hourly resolution, in days, and another seed
core_hawkes_jitter(c(0, 0, 0), resolution = 1 / 24, seed = 7)
#> [1] 0.0006995123 0.0162429062 0.0375316950

# times past the horizon are refused
try(core_hawkes_jitter(c(0, 5), horizon = 3))
#> Error : `times` must not exceed `horizon`
```
