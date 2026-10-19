# Trimmed inverse-probability weights (C backend)

The inverse-probability-of-treatment weights \\1/e\\ for the treated and
\\1/(1-e)\\ for the untreated, with the propensity score clamped into
`[trimlo, trimhi]` FIRST. Clamping matters: an untrimmed score near 0 or
1 produces a weight large enough for one observation to dominate the
entire estimate. These weights reweight a treated and an untreated group
so that each resembles the whole sample on the covariates behind the
propensity score, the basis of inverse-probability-weighted estimates of
a treatment effect (Rosenbaum and Rubin, 1983).

## Usage

``` r
cipw(treat, ps, trimlo = 0.01, trimhi = 0.99)
```

## Arguments

- treat:

  Numeric or logical treatment indicator, coded 0/1 (`1` / `TRUE` is
  treated); `NA` allowed.

- ps:

  Numeric vector of propensity scores (the estimated probability of
  treatment), each in \\\[0, 1\]\\, the same length as `treat`; `NA`
  allowed.

- trimlo, trimhi:

  Clamp bounds for the score, single numbers with
  `0 < trimlo < trimhi < 1` (defaults 0.01 and 0.99).

## Value

A numeric vector of weights the length of `treat`, each at least 1 (and
at most `1 / trimlo` or `1 / (1 - trimhi)`), `NA` where the treatment or
propensity is missing.

## Details

For unit \\i\\ with treatment \\T_i\\ and propensity \\e_i\\, the
clamped score is \\\tilde e_i = \min(\max(e_i, l), u)\\ with \\l\\ =
`trimlo` and \\u\\ = `trimhi`, and the weight is \\1 / \tilde e_i\\ when
\\T_i = 1\\ and \\1 / (1 - \tilde e_i)\\ when \\T_i = 0\\. With the
defaults no weight exceeds 100.

Refusals: vectors of different lengths, a treatment coded other than 0/1
(`"treat must be coded 0/1"`, naming the offending values), a propensity
outside \\\[0, 1\]\\, and bounds that do not satisfy \\0 \< l \< u \<
1\\. A missing treatment or propensity gives a missing weight for that
unit only. The weights are not normalised; divide by their sum within
each arm for stabilised (Hajek) estimates.

## References

Rosenbaum PR, Rubin DB (1983). The central role of the propensity score
in observational studies for causal effects. *Biometrika* 70(1), 41–55.
[doi:10.1093/biomet/70.1.41](https://doi.org/10.1093/biomet/70.1.41)

## See also

[`cwtd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwtd.md)
to average an outcome with these weights.

## Examples

``` r
treat <- c(1, 0, 1, 0)
e <- c(0.5, 0.25, 0.02, 0.9)

cipw(treat, e)
#> [1]  2.000000  1.333333 50.000000 10.000000

# A balanced score gives weight 2 to either arm.
cipw(c(1, 0), c(0.5, 0.5))
#> [1] 2 2

# Without trimming the third observation would carry weight 50; the
# default clamp holds it to 100 at the 0.01 floor, and a looser floor
# tames it further.
cipw(treat, e, trimlo = 0.10)
#> [1]  2.000000  1.333333 10.000000 10.000000

# Logical treatment indicators work too.
cipw(c(TRUE, FALSE), c(0.4, 0.4))
#> [1] 2.500000 1.666667

# A treatment coded 1/2 is refused rather than read as all-control.
try(cipw(c(1, 2), c(0.5, 0.5)))
#> Error : `treat` must be coded 0/1 (got values 2)
```
