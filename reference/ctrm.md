# Trimmed and winsorized means (C backend)

Two ways to stop a handful of extreme rows dominating a column's centre.
`ctrmmean()` DISCARDS the `floor(n * trim)` largest and smallest values,
as `mean(x, trim = )` does. `cwinsmean()` instead PULLS THEM IN to the
most extreme surviving values, so every observation still contributes
weight – usually the better choice when the extremes are real
measurements rather than errors.

## Usage

``` r
ctrmmean(x, trim = 0.1)

cwinsmean(x, trim = 0.1)
```

## Arguments

- x:

  Numeric (or logical) vector; coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html).

- trim:

  Proportion trimmed (or winsorized) at *each* end, a single number in
  \\\[0, 0.5\]\\ (default 0.1, i.e. 10% at each end). At `0.5` both
  reduce to the median.

## Value

A length-1 numeric in the units of `x`.

## Details

With \\g = \lfloor n \cdot \mathrm{trim} \rfloor\\ and the sorted values
\\x\_{(1)} \le \dots \le x\_{(n)}\\, the trimmed mean is \\\frac{1}{n -
2g} \sum\_{i=g+1}^{n-g} x\_{(i)}\\ and the winsorized mean replaces
\\x\_{(1)}, \dots, x\_{(g)}\\ by \\x\_{(g+1)}\\ and \\x\_{(n-g+1)},
\dots, x\_{(n)}\\ by \\x\_{(n-g)}\\ before averaging all \\n\\ values.
At `trim = 0.5` both return the median, as
[`mean()`](https://rdrr.io/r/base/mean.html) does.

A `trim` that is not a single number in \\\[0, 0.5\]\\ is an error. An
empty `x`, or any `NA`/`NaN` in `x`, gives `NaN` (missing values are not
removed). A character, factor or list `x` is refused
(`"must be numeric"`). Both sort a copy of `x`, so the cost is \\O(n
\log n)\\.

## See also

[`cmed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
and
[`cmad()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crob.md)
for the other robust summaries;
[`cmom()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cmom.md)
for the ordinary mean.

## Examples

``` r
x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 100)

mean(x)                               # dragged up by the 100
#> [1] 14.5
ctrmmean(x, 0.1)             # the 100 and the 1 dropped
#> [1] 5.5
cwinsmean(x, 0.1)          # the 100 pulled back to 9
#> [1] 5.5

# Agrees with base R's own trimming.
all.equal(ctrmmean(x, 0.2), mean(x, trim = 0.2))
#> [1] TRUE

# trim = 0 is the plain mean; trim = 0.5 is the median.
all.equal(ctrmmean(x, 0), mean(x))
#> [1] TRUE
all.equal(ctrmmean(x, 0.5), cmed(x))
#> [1] TRUE

# A trim past one half is not a trim.
try(cwinsmean(x, 0.7))
#> Error : `trim` must be a single number in [0, 0.5]
try(ctrmmean(letters))
#> Error : ctrmmean: `x` must be numeric, got character
```
