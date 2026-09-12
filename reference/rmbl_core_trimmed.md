# Trimmed and winsorized means (C backend)

Two ways to stop a handful of extreme rows dominating a column's centre.
`core_trimmed_mean()` DISCARDS the `floor(n * trim)` largest and
smallest values, matching `mean(x, trim = )`. `core_winsorized_mean()`
instead PULLS THEM IN to the most extreme surviving values, so every
observation still contributes weight – usually the better choice when
the extremes are real measurements rather than errors.

## Usage

``` r
core_trimmed_mean(x, trim = 0.1)

core_winsorized_mean(x, trim = 0.1)
```

## Arguments

- x:

  Numeric vector (coerced with
  [`as.numeric()`](https://rdrr.io/r/base/numeric.html)) .

- trim:

  Proportion trimmed from *each* end, in \\ \[0, 0.5\]. At `0.5` both
  reduce to the median.

  \[0, 0.5\]: R:0,%200.5%5C

## Value

A length-1 numeric.

## Examples

``` r
x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 100)

mean(x)                               # dragged up by the 100
#> [1] 14.5
core_trimmed_mean(x, 0.1)             # the 100 and the 1 dropped
#> [1] 5.5
core_winsorized_mean(x, 0.1)          # the 100 pulled back to 9
#> [1] 5.5

# Agrees with base R's own trimming.
all.equal(core_trimmed_mean(x, 0.2), mean(x, trim = 0.2))
#> [1] TRUE

# trim = 0 is the plain mean; trim = 0.5 is the median.
all.equal(core_trimmed_mean(x, 0), mean(x))
#> [1] TRUE
all.equal(core_trimmed_mean(x, 0.5), core_median(x))
#> [1] TRUE
```
