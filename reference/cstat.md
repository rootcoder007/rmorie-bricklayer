# Fast summary statistics (C backend)

`cmn()`, `cvari()` and `ccorr()` compute the mean, the sample variance
and the Pearson correlation in compiled code. They are thin R wrappers
over the kernels in the package's C/C++ core, the same ones that other
packages call through `LinkingTo: rmoriebricklayer`, so an R result and
a compiled result agree exactly. Use them where you want those shared
kernels; for everyday work [`mean()`](https://rdrr.io/r/base/mean.html),
[`var()`](https://rdrr.io/r/stats/cor.html) and
[`cor()`](https://rdrr.io/r/stats/cor.html) give the same numbers.

## Usage

``` r
cmn(x)

cvari(x)

ccorr(x, y)
```

## Arguments

- x, y:

  Numeric (or logical) vectors. `ccorr()` needs `x` and `y` of the same
  length.

## Value

`cmn()`, `cvari()` and `ccorr()` each return a length-1 numeric.

## Details

With \\n\\ values, \$\$\bar x = \frac{1}{n}\sum_i x_i, \qquad s^2 =
\frac{1}{n - 1}\sum_i (x_i - \bar x)^2, \qquad r = \frac{\sum_i (x_i -
\bar x)(y_i - \bar y)} {\sqrt{\sum_i (x_i - \bar x)^2 \sum_i (y_i - \bar
y)^2}}.\$\$ The variance uses the \\n - 1\\ (sample) denominator, as
[`var`](https://rdrr.io/r/stats/cor.html) does. The mean is accumulated
so that a sum of finite values that would overflow a double (for example
two values of `1e308`) still gives the finite mean.

There is no `na.rm`: any `NA` or `NaN` gives `NA` or `NaN`; remove
missing values first, for example with
[`na.omit`](https://rdrr.io/r/stats/na.fail.html). Edge cases return
`NaN` rather than an error: an empty vector for the mean, fewer than two
values for the variance, and a constant vector for the correlation.

Errors: input that is a character vector, factor, list or data frame
(logical input is accepted and read as 0/1); `x` and `y` of different
lengths in `ccorr()`.

## See also

[`cnormpdf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnormpdf.md),
[`csha256`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md).

## Examples

``` r
## cmn(): sample mean (NA/NaN propagate; no na.rm)
cmn(1:10)                 # 5.5
#> [1] 5.5
cmn(c(1, 2, NA))          # NA -- call stats::na.omit() first if needed
#> [1] NA
cmn(stats::na.omit(c(1, 2, NA)))
#> [1] 1.5
cmn(c(1e308, 1e308))      # no overflow
#> [1] 1e+308

## cvari(): n-1 (sample) variance, matching stats::var()
cvari(c(2, 4, 4, 4, 5, 5, 7, 9))
#> [1] 4.571429
all.equal(cvari(1:10), stats::var(1:10))   # agrees with base R
#> [1] TRUE

## ccorr(): Pearson correlation of two equal-length vectors
ccorr(1:10, (1:10)^2)        # strong positive, near 0.97
#> [1] 0.9745586
ccorr(1:10, 10:1)            # perfect negative: -1
#> [1] -1

## refusals
try(cmn(c("1", "2")))     # character input is not coerced
#> Error : cmn: `x` must be numeric, got character
try(ccorr(1:3, 1:4))         # lengths differ
#> Error : ccorr: `x` and `y` must have the same length
```
