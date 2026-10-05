# Spread event times recorded to a resolution across their interval

Daily (or hourly, or second) timestamps put every event of an interval
at one time, but a Hawkes process never has two events at one instant,
and fitting the rounded times as exact biases the estimates (Filimonov &
Sornette 2015). The remedy they use is to redistribute each timestamp
uniformly within its interval of uncertainty: `times + resolution * U`,
with `U` uniform on \[0, 1), then sorted. The uniforms are the
splitmix64 stream of
[`core_uniforms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md),
so the result is reproducible and, on daily dates with `seed = 42`, the
same as the jitter rmorie and morie (Python) apply before their TPS
Hawkes fits.

## Usage

``` r
core_hawkes_jitter(times, resolution = 1, seed = 42, horizon = Inf)
```

## Arguments

- times:

  Numeric event times, each the start of its resolution interval (for
  example whole days since an origin).

- resolution:

  The width of the interval a recorded time stands for (positive; 1 for
  daily dates in days).

- seed:

  Seed of the uniforms, as in
  [`core_uniforms()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md).

- horizon:

  End of the observation window, when it cuts an interval short: an
  event recorded at `t` is spread over
  `[t, min(t + resolution, horizon)]`, so a time dated on the horizon
  itself stays there (`Inf`: no window).

## Value

The jittered times, sorted.

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
```
