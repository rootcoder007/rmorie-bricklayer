# Association in a contingency table

Cramer's V, with the bias correction of Bergsma (2013) available, and
the small-expected-count condition reported rather than assumed away.

## Usage

``` r
cramers_v(tbl, bias_correct = TRUE, min_expected = 5)
```

## Arguments

- tbl:

  A table or matrix of counts.

- bias_correct:

  Whether to apply Bergsma's correction, which removes most of V's
  upward bias in a sparse table. Worth having: uncorrected V on a sparse
  table reports association that is an artefact of the table's size.

- min_expected:

  Expected count below which the chi-square approximation is unreliable.
  Reported, not enforced.

## Value

A list with `v`, `chisq`, `df`, `p_value`, `n`, `min_expected`, and
`cells_below`, the number of cells whose expected count falls under the
threshold. When any does, `p_value` comes from a Monte Carlo permutation
instead of the chi-square approximation, and `method` says which was
used.

## References

Bergsma, W. (2013). A bias-correction for Cramer's V and Tschuprow's T.
*Journal of the Korean Statistical Society* 42(3), 323-328. (Not in the
local corpus; cited from the published paper.)

## Examples

``` r
tbl <- rbind(c(120, 80), c(40, 160))
cramers_v(tbl)
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
#> $min_expected
#> [1] 80
#> 
#> $cells_below
#> [1] 0
#> 
#> $method
#> [1] "chi-square approximation"
#> 

# No association gives a V near zero.
cramers_v(rbind(c(100, 100), c(100, 100)))$v
#> [1] 0

# A sparse table's uncorrected V overstates the association.
sparse <- rbind(c(3, 1), c(1, 3))
c(raw = cramers_v(sparse, bias_correct = FALSE)$v,
  corrected = cramers_v(sparse)$v)
#>       raw corrected 
#> 0.5000000 0.3535534 
```
