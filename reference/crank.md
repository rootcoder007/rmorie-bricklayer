# Rank correlation and midranks (C backend)

`cspr()` is Spearman's rho: the Pearson correlation of the ranks, so it
measures monotone association rather than linear association and is
unaffected by any order-preserving transformation of either variable.
`cmidrk()` exposes the ranks themselves; tied values share the average
of the ranks they span, which is what makes the result agree with
[`stats::cor()`](https://rdrr.io/r/stats/cor.html) on tied data. Use
Spearman's rho when two variables rise and fall together but not along a
straight line (counts against rates, incomes against ranks), or when a
few extreme values would dominate a Pearson correlation.

## Usage

``` r
cspr(x, y)

cmidrk(x)
```

## Arguments

- x, y:

  Numeric (or logical) vectors of the same length.

## Value

`cspr()`: a length-1 numeric in \\\[-1, 1\]\\ (`NaN` as described
above). `cmidrk()`: a numeric vector the length of `x`, the rank of each
value (1 for the smallest; tied values share the mean of their ranks;
`NA` kept as `NA`).

## Details

With \\r_i\\ and \\s_i\\ the midranks of \\x_i\\ and \\y_i\\, \$\$\rho =
\frac{\sum_i (r_i - \bar r)(s_i - \bar s)} {\sqrt{\sum_i (r_i - \bar
r)^2 \sum_i (s_i - \bar s)^2}},\$\$ the Pearson correlation of the ranks
(Spearman, 1904). Because ties get midranks, the shortcut \\1 - 6 \sum
d_i^2 / (n(n^2 - 1))\\ is NOT what is computed; the full formula above
is, and it stays correct with ties.

`cspr()` does not remove missing values: an `NA` in either vector gives
`NaN`, and so does a constant vector (its ranks have no variance).
`cmidrk()` leaves an `NA` in place and ranks the rest, as
`rank(x, na.last = "keep")` does. Refusals: vectors of different lengths
(`"must have the same length"`) and a character, factor or list argument
(`"must be numeric"`). Ranking sorts, so the cost is \\O(n \log n)\\.

## References

Spearman C (1904). The proof and measurement of association between two
things. *The American Journal of Psychology* 15(1), 72–101.
[doi:10.2307/1412159](https://doi.org/10.2307/1412159)

## See also

[`ccorr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)
for the Pearson correlation.

## Examples

``` r
x <- c(1, 2, 3, 4, 5)
y <- c(2, 4, 9, 16, 25)

# Perfectly monotone but not linear: rho is 1 where Pearson is not.
cspr(x, y)
#> [1] 1
ccorr(x, y)
#> [1] 0.9737247

# Agrees with stats::cor(), ties included.
xt <- c(1, 2, 2, 2, 5, 5, 7)
yt <- c(3, 1, 1, 4, 4, 9, 2)
all.equal(cspr(xt, yt), stats::cor(xt, yt, method = "spearman"))
#> [1] TRUE

# Tied values share the average of the ranks they cover.
cmidrk(xt)
#> [1] 1.0 3.0 3.0 3.0 5.5 5.5 7.0
all.equal(cmidrk(xt), rank(xt))
#> [1] TRUE

# Invariant to any monotone rescaling.
all.equal(cspr(x, y), cspr(exp(x), log(y)))
#> [1] TRUE

# Missing values are kept in place by cmidrk().
cmidrk(c(3, NA, 1, 3))
#> [1] 2.5  NA 1.0 2.5
try(cspr(1:3, 1:4))
#> Error : cspr: `x` and `y` must have the same length
```
