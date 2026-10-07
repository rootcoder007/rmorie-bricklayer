# Falsification controls and power curves: is the statistic real?

A capsule can prove that a statistic was computed from exactly these
bytes. It cannot, by itself, say whether the statistic means anything.
Two complementary checks address that: a **falsification control** asks
whether the statistic survives deliberate attempts to break it, and a
**power curve** asks whether the procedure could have detected an effect
of a given size at all. Both are borrowed from the refutation tests of
causal-inference practice (placebo treatments, random subsets,
permutation) and made to run on any statistic you can write as a
function of the data.

## Falsification controls

[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
takes the data, a statistic (a function of the data frame) and the name
of the treatment column, and runs the controls that a real association
must pass:

- **permutation**: shuffle the treatment; the statistic should collapse
  toward its null;
- **placebo**: replace the treatment with noise; the statistic should
  collapse;
- **subsets**: recompute on random subsets; the statistic should stay
  stable.

``` r

set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)

real <- capsule_falsify(d, function(z) cor(z$x, z$y), treatment = "x", n = 199, seed = 42)
real$controls[, c("control", "passed")]
#>               control passed
#> 1         permutation   TRUE
#> 2             placebo   TRUE
#> 3 random_common_cause   TRUE
#> 4    subset_stability   TRUE
```

A statistic that ignores the data fails the controls that can see it. A
constant “0.5” passes the subset check (it is perfectly stable) and
fails the permutation check (it does not collapse when the treatment is
destroyed):

``` r

fake <- capsule_falsify(d, function(z) 0.5, treatment = "x", n = 199, seed = 42)
fake$controls[fake$controls$control == "permutation", "passed"]
#> [1] FALSE
```

This is the point of running controls rather than looking at a p-value:
the p-value of a constant is undefined, but its behaviour under
permutation is not.

## Power curves

A null result is only informative if the procedure could have found
something.
[`capsule_power()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_power.md)
injects an effect of known size into the data, re-runs the statistic
with its permutation test, and reports the detection rate at each size:

``` r

set.seed(1)
d <- data.frame(x = rnorm(120), y = rnorm(120))
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
```

The rate at size 0 estimates the false-positive rate. With few
repetitions it is usually 0, because alpha is small (five draws at 0.05
come up empty about three times in four), so read it as a sanity check
that it is not *large*, not as an estimate of alpha:

``` r

pw$curve[pw$curve$size == 0, "rate"]
#> [1] 0
```

Use more `reps` for a real study; the example keeps them small so the
vignette builds quickly. The curve answers the question a reviewer will
ask of a null finding: “what effect size would you have detected with
this data?”

## Families of statistics: the multiple-testing correction

When several statistics are examined, the smallest p-value among them is
not the finding.
[`falsify_family()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsify_family.md)
applies a multiple-testing correction across a family of falsification
results, so one real association is still reported as real and the noise
is not:

``` r

set.seed(1)
d <- data.frame(x = rnorm(150))
d$y <- 0.6 * d$x + rnorm(150)
d$a <- rnorm(150)
d$b <- rnorm(150)
fam <- list(
  real    = capsule_falsify(d, function(z) cor(z$x, z$y), treatment = "x", n = 199, seed = 1),
  noise_a = capsule_falsify(d, function(z) cor(z$a, z$y), treatment = "a", n = 199, seed = 2),
  noise_b = capsule_falsify(d, function(z) cor(z$b, z$y), treatment = "b", n = 199, seed = 3)
)
falsify_family(fam)
#> ── Family of 3, corrected by holm at alpha 0.05 ──────────────────
#>   real                   p 0.005      adjusted 0.015      survives
#>   noise_a                p 0.955      adjusted 1          
#>   noise_b                p 0.995      adjusted 1          
#> ──────────────────────────────────────────────────────────────────
#>   at the permutation floor (more permutations would be needed to say more): real
#> ──────────────────────────────────────────────────────────────────
```

It also accepts bare p-values, which is what stops the smallest of
several from being read as the finding:

``` r

falsify_family(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5))$results
#>   name    p adjusted survives
#> 1    a 0.01     0.04     TRUE
#> 2    b 0.04     0.12    FALSE
#> 3    c 0.20     0.40    FALSE
#> 4    d 0.50     0.50    FALSE
```

## Sensitivity to an unmeasured confounder

For an observed risk ratio, the E-value (VanderWeele and Ding 2017) is
the minimum strength of association an unmeasured confounder would need
with both treatment and outcome to explain the result away:

``` r

evalue_rr(2)                       # needs a confounder associated by 3.41 with both
#> evalue_point 
#>     3.414214
evalue_rr(0.5)                     # a protective effect is inverted; same answer
#> evalue_point 
#>     3.414214
evalue_rr(2, lo = 0.9, hi = 4.4)   # an interval that includes the null needs nothing
#> evalue_point evalue_limit 
#>     3.414214     1.000000
evalue_rr(3, lo = 2.1, hi = 4.3)   # a strong result with a limit well above the null
#> evalue_point evalue_limit 
#>     5.449490     3.619868
```

## Where this fits in a capsule

[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
runs the falsification controls alongside the schema, rule and drift
checks when a statistic is supplied, so the capsule records not only
that the number was computed from these bytes but that it survived its
controls. A pre-registered hypothesis
([`prereg_declare()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md),
[`prereg_check()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prereg_declare.md))
pins what was going to be tested before the data were seen, which is the
other half of keeping a finding honest.

## References

VanderWeele, Ding (2017). Sensitivity analysis in observational
research: introducing the E-value. *Annals of Internal Medicine* 167(4).
Benjamini, Hochberg (1995). Controlling the false discovery rate. *JRSS
B* 57(1).
