# Compare a fetched data frame with the one a capsule was pinned against

Runs the appropriate drift test on every shared column and collects the
verdicts in one report:
[`drift_ks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_ks.md)
plus
[`drift_psi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_psi.md)
for a numeric column,
[`drift_homogeneity()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_homogeneity.md)
for a categorical one. Columns that appeared or vanished are listed
separately, since no test applies to them.

## Usage

``` r
capsule_drift(
  reference,
  current,
  alpha = 0.01,
  psi_threshold = 0.25,
  psi_min_n = 1000L,
  bins = 10L
)
```

## Arguments

- reference:

  Data frame the capsule was built from.

- current:

  Data frame just fetched.

- alpha:

  Significance level for the `drifted` flag (default 0.01; deliberately
  stricter than 0.05 because a wide table runs many tests).

- psi_threshold:

  PSI above which a numeric column is flagged even when its p-value is
  not significant (default 0.25, the conventional "material shift"
  line).

- psi_min_n:

  Minimum size BOTH samples must reach before `psi_threshold` is allowed
  to flag a column on its own (default 1000). The PSI bands are
  large-sample heuristics with no calibrated null distribution: on a few
  hundred rows, binning noise alone routinely pushes the index past
  0.25, so applying the threshold there manufactures drift. Below this
  size the flag rests on the Kolmogorov-Smirnov p-value, which is
  calibrated, and the PSI is still reported as an effect size.

- bins:

  Bins passed to
  [`drift_psi()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_psi.md)
  (default 10).

## Value

A list of class `bricklayer_drift`: `columns` (a data frame, one row per
shared column, with `column`, `type`, `statistic`, `p_value`, `psi`,
`js_divergence` and `drifted`) , `added`, `removed`, `n_reference`,
`n_current`, `alpha`, and `any_drift`.

## Details

The categorical test is the two-sample homogeneity test, NOT
[`drift_chisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drift_chisq.md)
's goodness-of-fit against a known distribution: the reference here is
itself a finite sample, and ignoring its sampling error would report
drift too readily.

This is the check that a byte-level digest cannot make. A re-released
extract legitimately has a different SHA-256 while being the same data
statistically; conversely a column can keep its name, type and row count
while having been silently rescaled. `capsule_drift()` asks whether the
DATA moved.

## See also

[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
for the structural check, which this complements rather than replaces.

## Examples

``` r
set.seed(5)
ref <- data.frame(
  value = stats::rnorm(300),
  size = stats::runif(300, 1, 10),
  grade = sample(c("a", "b", "c"), 300, TRUE)
)

# A fresh draw from the same process: no drift.
same <- data.frame(
  value = stats::rnorm(300),
  size = stats::runif(300, 1, 10),
  grade = sample(c("a", "b", "c"), 300, TRUE)
)
d <- capsule_drift(ref, same)
d$any_drift
#> [1] FALSE

# A silently rescaled column, and a new category, are both caught.
moved <- same
moved$size <- moved$size * 3
moved$grade[1:100] <- "z"
capsule_drift(ref, moved)
#> ── Capsule drift report ──────────────────────────────────────────
#>   ✗ DRIFT DETECTED
#> 
#>   reference rows  300
#>   current rows    300
#>   columns tested  3
#>   alpha           0.01
#> 
#> ── Per-column tests ──────────────────────────────────────────────
#>      column        type  stat      p   psi
#>    ✗  grade categorical   121 <2e-16     –
#>    ✗   size     numeric 0.743 <2e-16 4.299
#>    ✓  value     numeric  0.05  0.847 0.092
#> ──────────────────────────────────────────────────────────────────

# The PSI is always reported as an effect size, but on a sample this
# small it is not allowed to raise the flag by itself -- binning noise
# alone would clear 0.25. Lower psi_min_n to override that.
capsule_drift(ref, same)$columns$psi
#> [1] 0.09244204 0.06635985         NA

# Structural changes are reported rather than tested.
capsule_drift(ref, same[, c("value", "grade")])$removed
#> [1] "size"
```
