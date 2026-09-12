# Quantiles, median and robust spread (C backend)

`core_quantile()` is the type-7 quantile, which is R's default, so it
agrees with `stats::quantile(x, probs, type = 7)`. `core_median()` is
the 50% point. `core_mad()` is the median absolute deviation, scaled by
`constant` so that it estimates the standard deviation of a normal
sample. `core_iqr()` is the interquartile range and
`core_tukey_fences()` the outlier fences drawn at `k` IQRs beyond the
quartiles.

## Usage

``` r
core_quantile(x, probs = c(0, 0.25, 0.5, 0.75, 1))

core_median(x)

core_mad(x, constant = 1.4826)

core_iqr(x)

core_tukey_fences(x, k = 1.5)
```

## Arguments

- x:

  Numeric vector (coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html)).

- probs:

  Numeric vector of probabilities in \[0, 1\].

- constant:

  Scale factor for `core_mad()`. The default `1.4826` makes the MAD
  consistent for the standard deviation under normality, and is the same
  rounded value [`stats::mad()`](https://rdrr.io/r/stats/mad.html) uses,
  so the two agree exactly. The unrounded consistency constant is
  `1 / qnorm(3/4)` = 1.4826022185...; pass it explicitly if you want the
  extra digits, or `1` for the unscaled median deviation.

- k:

  Fence width in IQRs (default 1.5, Tukey's convention; 3 is the usual
  "far out" cutoff).

## Value

`core_quantile()` returns a numeric vector the length of `probs`;
`core_median()`, `core_mad()` and `core_iqr()` a length-1 numeric;
`core_tukey_fences()` a named length-2 numeric (`lower`, `upper`).

## Details

These are the robust counterparts of
[`core_moments()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_moments.md):
a single corrupted row can move a mean or a variance arbitrarily far,
but moves a median or a MAD hardly at all – which is what you want when
deciding whether a freshly fetched column is still the column a capsule
was pinned against.

## Examples

``` r
x <- c(2, 4, 4, 4, 5, 5, 7, 9)
core_quantile(x, c(0.25, 0.5, 0.75))
#> 25% 50% 75% 
#> 4.0 4.5 5.5 
all.equal(core_quantile(x, c(0.1, 0.9)),
          as.numeric(stats::quantile(x, c(0.1, 0.9))))
#> [1] "names for target but not for current"

core_median(x)
#> [1] 4.5
core_mad(x)
#> [1] 0.7413
all.equal(core_mad(x), stats::mad(x))
#> [1] TRUE
core_mad(x, constant = 1)                  # unscaled median deviation
#> [1] 0.5
core_mad(x, constant = 1 / stats::qnorm(3/4))  # unrounded constant
#> [1] 0.7413011

core_iqr(x)
#> [1] 1.5
core_tukey_fences(x)
#> lower upper 
#>  1.75  7.75 

# Robustness: one wild value barely moves the median, but moves the
# mean a long way.
wild <- c(x, 1000)
c(mean = mean(wild), median = core_median(wild))
#>     mean   median 
#> 115.5556   5.0000 

# Values outside the fences are the candidates to inspect.
f <- core_tukey_fences(wild)
wild[wild < f[["lower"]] | wild > f[["upper"]]]
#> [1] 1000
```
