# Fast summary statistics (C backend)

Thin R wrappers over the `rmoriebricklayer` compiled core – the same
kernels that sibling packages reach through
`LinkingTo: rmoriebricklayer`. NA/NaN values propagate (there is no
`na.rm`); call
[`stats::na.omit()`](https://rdrr.io/r/stats/na.fail.html) first if you
need NA handling.

## Usage

``` r
core_mean(x)

core_var(x)

core_cor(x, y)
```

## Arguments

- x, y:

  Numeric vectors (coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html)).

## Value

`core_mean()`, `core_var()` and `core_cor()` return a length-1 numeric.
`core_var()` uses the `n - 1` (sample) denominator, matching
[`stats::var()`](https://rdrr.io/r/stats/cor.html).

## Examples

``` r
## core_mean(): sample mean (NA/NaN propagate; no na.rm)
core_mean(1:10)                 # 5.5
#> [1] 5.5
core_mean(c(2.5, 3.5))          # 3
#> [1] 3
core_mean(c(1, 2, NA))          # NA -- call stats::na.omit() first if needed
#> [1] NA
core_mean(stats::na.omit(c(1, 2, NA)))
#> [1] 1.5

## core_var(): n-1 (sample) variance, matching stats::var()
core_var(c(2, 4, 4, 4, 5, 5, 7, 9))
#> [1] 4.571429
all.equal(core_var(1:10), stats::var(1:10))   # agrees with base R
#> [1] TRUE

## core_cor(): Pearson correlation of two equal-length vectors
core_cor(1:10, (1:10)^2)        # strong positive, near 0.97
#> [1] 0.9745586
core_cor(1:10, 10:1)            # perfect negative: -1
#> [1] -1
```
