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

  Integer scalar, the number of permutations and of subsets, at least 9;
  default 199. The permutation p-value cannot be smaller than
  `1 / (n + 1)`, which is reported.

- subset_frac:

  Numeric scalar strictly between 0 and 1, the fraction of rows kept by
  the subset control; default 0.8.

- seed:

  Optional integer seed. Supplied, the result is reproducible; omitted
  (`NULL`, the default), the current random number stream is used and
  only the generator kind is recorded.

## Value

A list of class `bricklayer_falsification`: `observed` (the statistic on
the data as given), `controls` (a data frame with one row per control:
`control`, logical `passed` (`NA` when skipped), numeric `value` (the
p-value, the placebo or noise statistic, or the subset spread) and
`detail`), `permutation` (the vector of permuted statistics, `NULL`
without `treatment`), `n`, `treatment`, `rng_kind` and `seed` (`NA` when
none was given). [`print()`](https://rdrr.io/r/base/print.html) shows
one line per control;
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
permutation distribution.

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

When each control passes:

- permutation – the two-sided permutation p-value \\(1 + \\\\\|s_b\| \ge
  \|s\_{obs}\|\\) / (1 + B)\\ over the \\B\\ usable permutations is
  below 0.05 (the observed statistic is unlike its null);

- placebo – the statistic under one more permuted treatment lies within
  the 95th percentile of the absolute permutation values;

- random common cause – adding a column `.rmbl_random_common_cause` of
  standard normal noise changes the statistic by at most \\10^{-8}
  \max(1, \|s\_{obs}\|)\\;

- subset stability – the observed value lies inside the middle 95% of
  the statistic over `n` random subsets of
  `round(subset_frac * nrow(data))` rows (at least two).

A permutation or subset on which the statistic errors or is not finite
is dropped from that control. The statistic is evaluated `2 n + 3`
times, so its cost sets the run time; a progress bar is shown when
`options(morie.progress)` allows it. With `seed` the random number
stream is set for the call and the caller's stream restored afterwards.

Errors: `data` not a data frame or with fewer than 4 rows; `statistic`
not a function, or failing or not returning one finite number on the
data as given, the placebo data or the noise-augmented data; `n` below
9; `subset_frac` not strictly between 0 and 1; `treatment` not a column
of `data`.

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

# without a treatment column two controls are skipped, and say so
fit <- capsule_falsify(d, function(z) mean(z$y), n = 49, seed = 1)
fit$controls[, c("control", "passed")]
#>               control passed
#> 1         permutation     NA
#> 2             placebo     NA
#> 3 random_common_cause   TRUE
#> 4    subset_stability   TRUE

# the statistic must return one finite number
try(capsule_falsify(d, function(z) c(1, 2), n = 49))
#> Error : the statistic must return one finite number; on the data as given it returned something else
```
