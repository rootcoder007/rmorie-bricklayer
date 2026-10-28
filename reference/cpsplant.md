# Does the Analysis Recover a Known Effect?

Plants effects of known size into the real data and checks that the
statistic gets them back. Each planted data set keeps every column as it
is, except the outcome: it is shuffled, which removes whatever real
association it had with the treatment, and then the planted effect is
added, `effect * treatment`. A statistic that estimates the treatment's
effect on the outcome should return about `effect` on every one.

## Usage

``` r
cpsplant(
  data,
  stat,
  y,
  trt,
  effects = c(0, 0.5, 1),
  n = 50L,
  tol = NULL,
  seed = NULL
)
```

## Arguments

- data:

  A data frame with at least 4 rows.

- stat:

  A function of one data frame returning one number: the estimated
  effect of `trt` on `y`.

- y:

  The outcome column's name. It must be numeric.

- trt:

  The treatment column's name.

- effects:

  The effects to plant. Include 0, so a statistic that finds an effect
  where there is none fails.

- n:

  Planted data sets per effect.

- tol:

  How far an average estimate may sit from the planted effect. The
  default is 10% of the largest planted effect.

- seed:

  Optional seed, for a reproducible check. The session's own random
  stream is left as it was.

## Value

A list of class `rmbl_plant`: `ok` (every effect recovered), `table`
(one row per effect: `effect`, `recovered` (the average estimate),
`bias`, `se`, `passed`), `observed` (the statistic on the real data),
`n`, `tol`, `y`, `trt` and `seed`. It prints as a box and goes into a
manifest with
[`recevid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recevid.md).

## Details

This is evidence about the statistic as it is applied to this data (its
missing values, its skew, its group sizes), which a simulation on
made-up data cannot give. A statistic that recovers 0, 0.5 and 1
correctly is very unlikely to be computing the wrong thing.

The treatment column must be numeric, logical or a factor with two
levels (the second is coded 1). Effects are on the outcome's own scale
per unit of treatment, so the statistic must estimate an additive
effect: a difference in means, a regression slope, an average treatment
effect. An effect is recovered when the average estimate is within `tol`
of it, after allowing three Monte Carlo standard errors, and that
standard error is itself no larger than `tol`: a statistic too noisy for
the check to mean anything is not recovered (raise `n`). Without the
second condition the allowance grew with the noise, and a statistic that
returned pure noise passed.

## See also

[`cpsspec()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsspec.md)
for agreement across specifications,
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
for falsification controls,
[`recevid()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recevid.md)
to record them all.

## Examples

``` r
set.seed(1)
d <- data.frame(x = rbinom(200, 1, 0.5), z = rnorm(200))
d$y <- 2 * d$x + d$z + rnorm(200)

# A difference in means recovers what is planted.
dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])
cpsplant(d, dm, y = "y", trt = "x", n = 30, seed = 1)
#> ╭── Planted-effect recovery: passed ──────────────────────────────────────────╮
#> │ ✔ VERIFIED                                                                  │
#> │                                                                             │
#> │   Outcome                    y                                              │
#> │   Treatment                  x                                              │
#> │   Data sets per effect       30                                             │
#> │   Tolerance                  0.1                                            │
#> │   Estimate on the real data  1.754                                          │
#> │   Seed                       1                                              │
#> │                                                                             │
#> │   planted  recovered      bias       se  result                             │
#> │   -------  ---------  --------  -------  ------                             │
#> │    0.0000     0.0565   0.05647  0.04314  ok                                 │
#> │    0.5000     0.4977  -0.00234  0.04137  ok                                 │
#> │    1.0000     1.0616   0.06160  0.04818  ok                                 │
#> │                                                                             │
#> │   The statistic recovered every planted effect on this data, so it          │
#> │   measures the treatment's effect on the outcome as intended.               │
#> │                                                                             │
#> │   Each planted data set shuffles the outcome, removing its real             │
#> │   association, then adds effect x treatment.                                │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# A statistic with a bug (it doubles the effect) does not.
bad <- function(df) 2 * dm(df)
cpsplant(d, bad, y = "y", trt = "x", n = 30, seed = 1)$ok
#> [1] FALSE
```
