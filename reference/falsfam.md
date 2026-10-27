# Correct a family of falsification results for multiple testing

Takes the p-values from several
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
runs – or a plain numeric vector – and reports which survive once the
size of the family is accounted for.

Running the permutation control over twenty statistics and reporting the
one that came in under 0.05 is not a finding: at that family size
roughly one spurious result is what chance produces. Which correction to
use depends on the claim. Holm controls the probability of ANY false
positive, which is what a claim about a specific statistic needs.
Benjamini-Hochberg controls the expected PROPORTION of false positives
among those declared, which is what a screening exercise needs; it is
less conservative and says something weaker.

A permutation p-value cannot fall below `1 / (n + 1)`, so with a small
number of permutations a whole family can be uncorrectable – every p
sits at the floor. That is reported rather than hidden, because the
alternative is a table of adjusted values that look like evidence of
nothing in particular.

## Usage

``` r
falsfam(x, meth = c("holm", "bh", "bonferroni", "none"), alpha = 0.05)
```

## Arguments

- x:

  A named list of `bricklayer_falsification` objects, or a named numeric
  vector of p-values.

- meth:

  `"holm"` (the default), `"bh"`, `"bonferroni"` or `"none"`.

- alpha:

  Number, default 0.05: the threshold applied to the adjusted values.

## Value

A list of class `bricklayer_falsify_family` with `results` (a data frame
of `name`, `p`, `adjusted` and logical `survives`, sorted by `p`),
`method`, `famsz` (integer), `alpha`, and `atflr` (the names whose
p-value equals the smallest their permutation count could produce; empty
for a numeric vector). The print method shows the table.

## Details

With the \\m\\ p-values sorted, \\p\_{(1)} \le \dots \le p\_{(m)}\\, the
adjusted values are: Holm, \\\max\_{j \le i} (m - j + 1) p\_{(j)}\\;
Benjamini-Hochberg, \\\min\_{j \ge i} (m / j) p\_{(j)}\\; Bonferroni,
\\m p\_{(i)}\\; all capped at 1. They agree with
[`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html) with
methods `"holm"`, `"BH"` and `"bonferroni"`. A member survives when its
adjusted value is at most `alpha`.

For a list of
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
results the p-value used is that of each result's permutation control,
and the floor is \\1/(n + 1)\\ for its `n` permutations. For a numeric
vector there is no floor to check and unnamed values are named `p1`,
`p2`, ....

Errors: a list whose members are not all falsification results, or that
is unnamed; a member without a permutation p-value; a missing p-value; a
p-value outside \\\[0, 1\]\\.

## See also

[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md),
[`prrgdecl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prrgdecl.md).

## Examples

``` r
# four statistics, one of which is real
set.seed(1)
d <- data.frame(x = rnorm(150))
d$y <- 0.6 * d$x + rnorm(150)
d$a <- rnorm(150)
d$b <- rnorm(150)
fam <- list(
  real = cpsfals(d, function(z) cor(z$x, z$y),
                         trt = "x", n = 199, seed = 1),
  noisea = cpsfals(d, function(z) cor(z$a, z$y),
                            trt = "a", n = 199, seed = 2),
  noiseb = cpsfals(d, function(z) cor(z$b, z$y),
                            trt = "b", n = 199, seed = 3))
falsfam(fam)
#> ╭── Family of 3, corrected by holm at alpha 0.05 ─────────────────────────────╮
#> │   Method       holm                                                         │
#> │   Family size  3                                                            │
#> │   Alpha        0.05                                                         │
#> │   Survive      1                                                            │
#> │                                                                             │
#> │   name        p  adjusted_p  survives                                       │
#> │   ------  -----  ----------  --------                                       │
#> │   real    0.005       0.015  survives                                       │
#> │   noisea  0.955       1.000                                                 │
#> │   noiseb  0.995       1.000                                                 │
#> │                                                                             │
#> │   1 of 3 result(s) survive once the size of the family is counted.          │
#> │                                                                             │
#> │   at the permutation floor (more permutations would be needed to say        │
#> │   more): real                                                               │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# the correction is what stops the smallest of several from being
# read as the finding
falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5))$results
#>   name    p adjusted survives
#> 1    a 0.01     0.04     TRUE
#> 2    b 0.04     0.12    FALSE
#> 3    c 0.20     0.40    FALSE
#> 4    d 0.50     0.50    FALSE

# the false-discovery rate is less strict than Holm
falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5), meth = "bh")$results
#>   name    p  adjusted survives
#> 1    a 0.01 0.0400000     TRUE
#> 2    b 0.04 0.0800000    FALSE
#> 3    c 0.20 0.2666667    FALSE
#> 4    d 0.50 0.5000000    FALSE

try(falsfam(c(a = 0.01, b = 1.2)))
#> Error : p-values must lie in [0, 1]
```
