# Simulate event times from a fitted Hawkes process

Draws a new event history from a
[`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md)
result by its cluster representation: immigrant events from the baseline
(a Poisson process, thinned from its upper bound for a sinusoidal
baseline), then each event's offspring, a Poisson number with mean the
branching ratio, at delays drawn from the fitted kernel, generation
after generation, until none fall before the horizon.

## Usage

``` r
chwksim(fit, hor = NULL, seed = 1L)
```

## Arguments

- fit:

  A
  [`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md)
  result.

- hor:

  Number, the end of the window; default the fit's horizon.

- seed:

  Whole number, default 1, for this call only (the session's stream is
  left as it was).

## Value

The sorted event times (numeric), with the attribute `generation` (0 for
an immigrant, 1 for its children, ...).

## See also

[`plothwk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plothwk.md),
[`chwkfit()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chwkfit.md).

## Examples

``` r
set.seed(1)
times <- sort(stats::runif(300, 0, 100))
fit <- chwkfit(times, 100)
sim <- chwksim(fit, seed = 2)
length(sim)
#> [1] 286
table(attr(sim, "generation"))
#> 
#>   0   1   2   3   4 
#> 213  54  14   3   2 
try(chwksim(list(a = 1)))
#> Error : chwksim: `fit` must be a chwkfit() result
```
