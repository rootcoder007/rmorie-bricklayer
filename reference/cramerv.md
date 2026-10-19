# Association in a contingency table

Cramer's V, with the bias correction of Bergsma (2013) available, and
the small-expected-count condition reported rather than assumed away.
Use it to say how strongly two categorical variables are associated (0
is none, 1 is complete), for example region by outcome in a
cross-tabulation, on a scale that does not depend on the number of rows
and columns.

## Usage

``` r
cramerv(tbl, biascor = TRUE, minexp = 5, seed = 1L)
```

## Arguments

- tbl:

  A table or matrix of non-negative counts, at least 2 by 2 after empty
  rows and columns are dropped.

- biascor:

  Logical scalar, default `TRUE`: whether to apply Bergsma's correction,
  which removes most of V's upward bias in a sparse table. Worth having:
  uncorrected V on a sparse table reports association that is an
  artefact of the table's size.

- minexp:

  Numeric scalar, default `5`: the expected count below which the
  chi-square approximation is treated as unreliable. Reported, and it
  switches the p-value to the Monte Carlo one; it does not stop the
  calculation.

- seed:

  Integer scalar, default `1`: the seed for the Monte Carlo branch; the
  caller's random number stream is restored afterwards.

## Value

A list with `v` (numeric, Cramer's V), `chisq` (the Pearson statistic),
`df` (integer), `p_value`, `n` (the total count), `minexp` (the smallest
expected count in the table), `cellsbelow` (integer), the number of
cells whose expected count falls under the threshold. When any does,
`p_value` comes from a Monte Carlo permutation instead of the chi-square
approximation, and `method` says which was used.

## Details

With \\\chi^2\\ the Pearson statistic (no continuity correction), \\n\\
the total, \\r\\ rows and \\k\\ columns, \\\phi^2 = \chi^2/n\\ and the
uncorrected \\V = \sqrt{\phi^2 / \min(r-1, k-1)}\\. Bergsma's correction
replaces \\\phi^2\\ with \\\max(0, \phi^2 - (r-1)(k-1)/(n-1))\\ and \\r,
k\\ with \\r - (r-1)^2/(n-1)\\ and \\k - (k-1)^2/(n-1)\\.

Empty rows and columns (an unused factor level) are dropped first, and
`method` says so. When fewer than two rows or columns remain, every
statistic is `NA`. When any expected count is below `minexp`, the
p-value comes from
`stats::chisq.test(simulate.p.value = TRUE, B = 10000)` under `seed`,
and the caller's random number stream is restored afterwards.

Errors: `tbl` `NULL`, not numeric, or with a negative or non-finite
count; `biascor` not `TRUE` or `FALSE`; `minexp` not a single
non-negative number.

## References

Bergsma, W. (2013). A bias-correction for Cramer's V and Tschuprow's T.
*Journal of the Korean Statistical Society* 42(3), 323-328. (Not in the
local corpus; cited from the published paper.)

## Examples

``` r
tbl <- rbind(c(120, 80), c(40, 160))
cramerv(tbl)
#> $v
#> [1] 0.4056758
#> 
#> $chisq
#> [1] 66.66667
#> 
#> $df
#> [1] 1
#> 
#> $p_value
#> [1] 3.215263e-16
#> 
#> $n
#> [1] 400
#> 
#> $minexp
#> [1] 80
#> 
#> $cellsbelow
#> [1] 0
#> 
#> $method
#> [1] "chi-square approximation"
#> 

# No association gives a V near zero.
cramerv(rbind(c(100, 100), c(100, 100)))$v
#> [1] 0

# A sparse table's uncorrected V overstates the association.
sparse <- rbind(c(3, 1), c(1, 3))
c(raw = cramerv(sparse, biascor = FALSE)$v,
  corrected = cramerv(sparse)$v)
#>       raw corrected 
#> 0.5000000 0.3535534 

# small expected counts: a Monte Carlo p-value, and the method says so
cramerv(sparse)$method
#> [1] "Monte Carlo permutation (small expected counts)"

# an unused level is dropped
cramerv(rbind(c(30, 10), c(0, 0), c(12, 28)))$method
#> [1] "chi-square approximation; 1 empty row(s)/column(s) dropped"

# negative counts are refused
try(cramerv(rbind(c(-1, 2), c(1, 2))))
#> Error : `tbl` must be a matrix or table of finite non-negative counts
```
