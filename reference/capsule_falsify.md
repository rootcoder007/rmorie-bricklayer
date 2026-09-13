# Run falsification controls against a statistic

Recomputes `statistic` under conditions in which its value is known in
advance, and reports whether it behaved. Four controls, each answering a
different way of being wrong:

## Usage

``` r
capsule_falsify(
  data,
  statistic,
  treatment = NULL,
  n = 199L,
  subset_frac = 0.8,
  seed = NULL
)
```

## Arguments

- data:

  A data frame.

- statistic:

  A function of one data frame returning a single finite number.

- treatment:

  Name of the column the finding is about, permuted for the permutation
  and placebo controls. Optional: without it those two controls are
  skipped and reported as such rather than silently omitted.

- n:

  Number of permutations and subsets. The permutation p-value cannot be
  smaller than `1 / (n + 1)`, which is reported.

- subset_frac:

  Fraction of rows kept by the subset control.

- seed:

  Optional integer seed. Supplied, the result is reproducible; omitted,
  the current RNG state is used and recorded.

## Value

A list of class `bricklayer_falsification`: `observed`, a `controls`
data frame (one row per control, with `passed`) , and `permutation`
holding the null distribution.

## Details

- **permutation** – shuffle `treatment` and the association it carries
  is destroyed, so the statistic should fall to its null distribution.
  Reports where the observed value sits in that distribution, and the
  smallest p-value the number of permutations could have produced.

- **random common cause** – add a column of noise. It cannot possibly
  matter, so a statistic that moves is reading something other than the
  data.

- **placebo treatment** – replace `treatment` with a random draw of the
  same shape. The effect should vanish; if it does not, the statistic is
  picking up structure that has nothing to do with the exposure.

- **subset stability** – recompute on random subsets. Wide spread means
  the finding rests on particular rows, which is worth knowing before it
  rests on a conclusion.

What a pass means. Only that these controls did not catch anything. They
are falsification tests, so they can refute and cannot confirm: passing
all four is consistent with a statistic that is wrong for a reason none
of them probes.

## See also

[`capsule_power()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_power.md)
for the positive control – whether a real effect would have been seen at
all;
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
for the different question of whether the record is intact rather than
whether the finding survives.

## Examples

``` r
set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)
# a real association survives its controls
real <- capsule_falsify(d, function(z) cor(z$x, z$y),
                        treatment = "x", n = 199, seed = 42)
real$controls[, c("control", "passed")]
#>               control passed
#> 1         permutation   TRUE
#> 2             placebo   TRUE
#> 3 random_common_cause   TRUE
#> 4    subset_stability   TRUE

# and a statistic that ignores the data fails the ones that can see it
fake <- capsule_falsify(d, function(z) 0.5, treatment = "x",
                        n = 199, seed = 42)
fake$controls[fake$controls$control == "permutation", "passed"]
#> [1] FALSE
```
