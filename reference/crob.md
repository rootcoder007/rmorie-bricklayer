# Quantiles, median and robust spread (C backend)

`cqnt()` is the type-7 quantile, which is R's default, so it agrees with
`stats::quantile(x, probs, type = 7)`. `cmed()` is the 50% point.
`cmad()` is the median absolute deviation, scaled by `constant` so that
it estimates the standard deviation of a normal sample. `ciqr()` is the
interquartile range and `ctkyfnc()` the outlier fences drawn at `k` IQRs
beyond the quartiles.

## Usage

``` r
cqnt(x, probs = c(0, 0.25, 0.5, 0.75, 1))

cmed(x)

cmad(x, const = 1.4826)

ciqr(x)

ctkyfnc(x, k = 1.5)
```

## Arguments

- x:

  Numeric (or logical) vector; coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html).

- probs:

  Numeric vector of probabilities, each in \\\[0, 1\]\\ (default the
  minimum, quartiles and maximum).

- const:

  Scale factor for `cmad()`. The default `1.4826` makes the MAD
  consistent for the standard deviation under normality, and is the same
  rounded value [`stats::mad()`](https://rdrr.io/r/stats/mad.html) uses,
  so the two agree exactly. The unrounded consistency constant is
  `1 / qnorm(3/4)` = 1.4826022185...; pass it explicitly if you want the
  extra digits, or `1` for the unscaled median deviation.

- k:

  Fence width in IQRs, a single non-negative number (default 1.5,
  Tukey's convention; 3 is the usual “far out” cutoff).

## Value

`cqnt()`: a numeric vector the length of `probs`, in the units of `x`,
named by percentage (`"25%"`, ...) as
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html) names them.
`cmed()`, `cmad()` and `ciqr()`: a length-1 numeric in the units of `x`.
`ctkyfnc()`: a named length-2 numeric, `lower` and `upper`.

## Details

These are the robust counterparts of
[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md):
a single corrupted row can move a mean or a variance arbitrarily far,
but moves a median or a MAD hardly at all – which is what you want when
deciding whether a freshly fetched column is still the column a capsule
was pinned against, or when screening a column for values to inspect by
hand.

The type-7 quantile at probability \\p\\ interpolates linearly between
the order statistics \\x\_{(j)}\\ and \\x\_{(j+1)}\\ with \\h = (n -
1)p + 1\\, \\j = \lfloor h \rfloor\\: \\Q(p) = x\_{(j)} + (h -
j)(x\_{(j+1)} - x\_{(j)})\\ (Hyndman and Fan, 1996). The MAD is \\c
\cdot \mathrm{median}\_i \|x_i - \mathrm{median}(x)\|\\ with \\c\\ =
`constant`; the IQR is \\Q(0.75) - Q(0.25)\\; and the fences are
\\Q(0.25) - k \cdot \mathrm{IQR}\\ and \\Q(0.75) + k \cdot
\mathrm{IQR}\\ (Tukey, 1977).

Missing values are not removed: an `NA` or `NaN` anywhere in `x` makes
every result `NaN` (unlike
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html), which
stops). An empty `x` gives `NaN`. `cqnt()` refuses an empty `probs`
(`"probs is empty"`) and any probability outside \\\[0, 1\]\\ or missing
(`"must lie in [0, 1]"`); every function refuses a character, factor or
list `x` (`"must be numeric"`). The quantiles sort a copy of `x`, so the
cost is \\O(n \log n)\\.

## References

Hyndman RJ, Fan Y (1996). Sample quantiles in statistical packages. *The
American Statistician* 50(4), 361–365.
[doi:10.1080/00031305.1996.10473566](https://doi.org/10.1080/00031305.1996.10473566)

Tukey JW (1977). *Exploratory Data Analysis*. Addison-Wesley.

## See also

[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for the non-robust moments,
[`ctrmmean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ctrm.md)
for a robust centre that still averages.

## Examples

``` r
x <- c(2, 4, 4, 4, 5, 5, 7, 9)
cqnt(x, c(0.25, 0.5, 0.75))
#> 25% 50% 75% 
#> 4.0 4.5 5.5 
all.equal(cqnt(x, c(0.1, 0.9)),
          as.numeric(stats::quantile(x, c(0.1, 0.9))))
#> [1] "names for target but not for current"

cmed(x)
#> [1] 4.5
cmad(x)
#> [1] 0.7413
all.equal(cmad(x), stats::mad(x))
#> [1] TRUE
cmad(x, const = 1)                  # unscaled median deviation
#> [1] 0.5
cmad(x, const = 1 / stats::qnorm(3/4))  # unrounded constant
#> [1] 0.7413011

ciqr(x)
#> [1] 1.5
ctkyfnc(x)
#> lower upper 
#>  1.75  7.75 

# Robustness: one wild value barely moves the median, but moves the
# mean a long way.
wild <- c(x, 1000)
c(mean = mean(wild), median = cmed(wild))
#>     mean   median 
#> 115.5556   5.0000 

# Values outside the fences are the candidates to inspect.
f <- ctkyfnc(wild)
wild[wild < f[["lower"]] | wild > f[["upper"]]]
#> [1] 1000

# A missing value is not dropped: the answer is NaN.
cmed(c(1, NA, 3))
#> [1] NaN

# A probability outside [0, 1] is refused.
try(cqnt(x, 1.5))
#> Error : `probs` must lie in [0, 1]
```
