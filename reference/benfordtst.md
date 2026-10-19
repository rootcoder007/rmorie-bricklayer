# Benford first-digit test

Compares the distribution of leading significant digits in `x` with
Benford's law, \\P(d) = \log\_{10}(1 + 1/d)\\. Naturally occurring
quantities that span several orders of magnitude follow it closely;
figures that were rounded, truncated, capped, re-scaled, or invented
typically do not. That makes it a cheap screen for a numeric column that
arrived looking plausible but is not the measurement it claims to be.

It is a SCREEN, not a verdict. Columns with a narrow range, a unit floor
or ceiling, or an assigned-identifier structure (postcodes, year fields,
prices ending in 99) legitimately violate Benford's law. Treat a small
p-value as a reason to look, never as evidence of fabrication.

## Usage

``` r
benfordtst(x)
```

## Arguments

- x:

  Numeric vector.

## Value

A list of class `bricklayer_benford` with `counts` (observed digit
frequencies 1–9), `expected`, `proportion`, `statistic`, `df`,
`p_value`, `logpvalue` (the log of the upper tail, which keeps its
information where `p_value` underflows to 0), and `n` (the number of
values used). `counts`, `expected` and `proportion` are named numeric
vectors with names `"1"` to `"9"`. The print method shows the verdict
and a bar chart of observed against expected shares.

## Details

Zeros and non-finite values have no leading significant digit and are
excluded; the sign is ignored.

With \\n\\ usable values, \\O_d\\ the count with leading digit \\d\\ and
\\E_d = n \log\_{10}(1 + 1/d)\\, \$\$X^2 = \sum\_{d=1}^{9} \frac{(O_d -
E_d)^2}{E_d}\$\$ on 8 degrees of freedom. The smallest Benford share is
0.046 (digit 9), so the chi-square approximation needs about \\n \ge
110\\ for every expected count to reach 5; below that treat the p-value
as rough. Digits are counted in compiled code in blocks of a million
values, and a long vector shows a progress bar in an interactive session
(silenced by `options(morie.quiet = TRUE)`). Errors: non-numeric input,
or no finite non-zero value.

## References

Benford F (1938). The law of anomalous numbers. *Proceedings of the
American Philosophical Society* 78(4), 551–572.

## See also

[`drftchisq()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftchisq.md),
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md).

## Examples

``` r
# A quantity spanning several orders of magnitude follows the law.
set.seed(3)
benfordtst(10^stats::runif(2000, 0, 6))
#> ── Benford first-digit screen ────────────────────────────────────
#>   ✓ consistent with Benford's law
#> 
#>   values used  2,000
#>   chi-square   10.073
#>   df           8
#>   p-value      0.26
#> 
#>   digit  observed  expected        shape
#>       1     0.298     0.301  ####################
#>       2     0.169     0.176  ###########         
#>       3     0.126     0.125  ########            
#>       4     0.092     0.097  ######              
#>       5     0.073     0.079  #####               
#>       6     0.072     0.067  #####               
#>       7     0.054     0.058  ####                
#>       8     0.060     0.051  ####                
#>       9     0.055     0.046  ####                
#> ──────────────────────────────────────────────────────────────────

# Digits drawn uniformly do not.
benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))
#> ── Benford first-digit screen ────────────────────────────────────
#>   ! departs from Benford's law (screen only, not a verdict)
#> 
#>   values used  2,000
#>   chi-square   769.038
#>   df           8
#>   p-value      <2e-16
#> 
#>   digit  observed  expected        shape
#>       1     0.106     0.301  #################   
#>       2     0.123     0.176  ####################
#>       3     0.123     0.125  ####################
#>       4     0.112     0.097  ##################  
#>       5     0.103     0.079  #################   
#>       6     0.102     0.067  #################   
#>       7     0.099     0.058  ################    
#>       8     0.119     0.051  ################### 
#>       9     0.112     0.046  ##################  
#> ──────────────────────────────────────────────────────────────────

# The expected proportions are the closed form.
b <- benfordtst(10^stats::runif(500, 0, 5))
all.equal(b$expected / b$n, log10(1 + 1 / (1:9)))
#> [1] "names for target but not for current"

# Zeros carry no leading digit and are excluded from n.
benfordtst(c(0, 0, 1, 2, 3))$n
#> [1] 3

try(benfordtst(c(0, NA)))
#> Error : `x` has no finite non-zero values to take a leading digit from
```
