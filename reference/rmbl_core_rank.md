# Rank correlation and midranks (C backend)

`core_cor_spearman()` is Spearman's rho: the Pearson correlation of the
ranks, so it measures monotone association rather than linear
association and is unaffected by any order-preserving transformation of
either variable. `core_midranks()` exposes the ranks themselves; tied
values share the average of the ranks they span, which is what makes the
result agree with [`stats::cor()`](https://rdrr.io/r/stats/cor.html) on
tied data.

## Usage

``` r
core_cor_spearman(x, y)

core_midranks(x)
```

## Arguments

- x, y:

  Numeric vectors of the same length.

## Value

`core_cor_spearman()` a length-1 numeric in \[-1, 1\]; `core_midranks()`
a numeric vector the length of `x`.

## Examples

``` r
x <- c(1, 2, 3, 4, 5)
y <- c(2, 4, 9, 16, 25)

# Perfectly monotone but not linear: rho is 1 where Pearson is not.
core_cor_spearman(x, y)
#> [1] 1
core_cor(x, y)
#> [1] 0.9737247

# Agrees with stats::cor(), ties included.
xt <- c(1, 2, 2, 2, 5, 5, 7)
yt <- c(3, 1, 1, 4, 4, 9, 2)
all.equal(core_cor_spearman(xt, yt), stats::cor(xt, yt, method = "spearman"))
#> [1] TRUE

# Tied values share the average of the ranks they cover.
core_midranks(xt)
#> [1] 1.0 3.0 3.0 3.0 5.5 5.5 7.0
all.equal(core_midranks(xt), rank(xt))
#> [1] TRUE

# Invariant to any monotone rescaling.
all.equal(core_cor_spearman(x, y), core_cor_spearman(exp(x), log(y)))
#> [1] TRUE
```
