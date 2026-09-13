# Detect an injected effect of known size

Adds an effect of each given size to the data, reruns the whole
detection procedure, and reports how often it was found. The result is a
power curve, and the smallest size detected reliably is the smallest
effect the analysis could have seen.

## Usage

``` r
capsule_power(
  data,
  statistic,
  inject,
  sizes = c(0, 0.2, 0.5),
  treatment = NULL,
  n = 99L,
  reps = 10L,
  alpha = 0.05,
  seed = NULL
)
```

## Arguments

- data:

  A data frame.

- statistic:

  A function of one data frame returning a single finite number.

- inject:

  A function of `(data, size)` returning the data with an effect of that
  size added. It is the caller's, because what counts as an effect of
  size 0.2 is a modelling decision and not something this function can
  guess.

- sizes:

  Effect sizes to try. `0` is added if absent, since the detection rate
  there is the false-positive rate and belongs on the same curve.

- treatment:

  Column permuted to build the null, as in
  [`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md).

- n:

  Permutations per test.

- reps:

  Repetitions per size. The detection rate at each size is out of this
  many, so its resolution is `1 / reps`.

- alpha:

  Significance threshold for counting a detection.

- seed:

  Optional integer seed.

## Value

A list of class `bricklayer_power`: a `curve` data frame ( `size`,
`detected`, `reps`, `rate`) , the `alpha` used, and `smallest_detected`,
the smallest size found at a rate of at least 0.8 – `NA` when no size
reached it.

## Details

This is the positive control that
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
lacks: its four are all negative. Those establish that the finding is
not an artefact; this establishes that a real effect would not have been
missed. A study that passes every falsification control and has no power
against the effect it was looking for has not found that the effect is
absent – it has found nothing either way, and the two are routinely
reported as the same thing.

## See also

[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
for the negative controls.

## Examples

``` r
set.seed(1)
d <- data.frame(x = rnorm(120), y = rnorm(120))
# inject a linear effect of x on y
inj <- function(z, size) {
  z$y <- z$y + size * z$x
  z
}
pw <- capsule_power(d, function(z) cor(z$x, z$y), inj,
                    sizes = c(0, 0.3, 0.6), treatment = "x",
                    n = 99, reps = 5, seed = 42)
pw$curve
#>   size detected reps rate
#> 1  0.0        0    5    0
#> 2  0.3        5    5    1
#> 3  0.6        5    5    1

# The rate at size 0 estimates the false-positive rate. With few
# repetitions it is usually 0, because alpha is small -- five draws
# at 0.05 come up empty about three times in four -- so read it as a
# sanity check that it is not LARGE, not as an estimate of alpha.
pw$curve[pw$curve$size == 0, "rate"]
#> [1] 0
```
