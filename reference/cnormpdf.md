# Normal density (C backend)

Evaluates the density of the normal distribution with a given mean and
standard deviation at each value of `x`, in compiled code. It is the
same kernel that other packages reach through
`LinkingTo: rmoriebricklayer`, and for a positive standard deviation it
agrees with [`dnorm`](https://rdrr.io/r/stats/Normal.html).

## Usage

``` r
cnormpdf(x, mean = 0, sd = 1)
```

## Arguments

- x:

  Numeric vector of quantiles at which the density is evaluated.

- mean:

  Number, default `0`: the mean \\\mu\\.

- sd:

  Number, default `1`: the standard deviation \\\sigma\\; must be
  positive for a finite result.

## Value

A numeric vector the length of `x`.

## Details

\$\$f(x) = \frac{1}{\sigma\sqrt{2\pi}} \exp\left(-\frac{(x -
\mu)^2}{2\sigma^2}\right).\$\$ The function is vectorised over `x` only;
`mean` must be a single finite number and `sd` a single positive number,
and anything else is an error
([`dnorm()`](https://rdrr.io/r/stats/Normal.html) recycles them, and
gives `Inf` or `NaN` for `sd = 0` or below). `NA` in `x` gives `NA`;
`x = Inf` gives 0. Character, factor or list input for `x` is an error.

## See also

[`cstat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md),
[`dnorm`](https://rdrr.io/r/stats/Normal.html).

## Examples

``` r
# Standard normal density at a few quantiles.
cnormpdf(c(-1, 0, 1))
#> [1] 0.2419707 0.3989423 0.2419707

# Peak of the standard normal is 1/sqrt(2*pi) at x = 0.
cnormpdf(0)
#> [1] 0.3989423

# Shift and scale via mean and sd.
cnormpdf(c(0, 5, 10), mean = 5, sd = 2)
#> [1] 0.00876415 0.19947114 0.00876415

# Identical to stats::dnorm().
all.equal(cnormpdf(-2:2, 0, 1), stats::dnorm(-2:2, 0, 1))
#> [1] TRUE

# a non-positive sd and text are refused
try(cnormpdf(0, sd = 0))
#> Error : cnormpdf: `sd` must be a single positive number
try(cnormpdf("0"))
#> Error : cnormpdf: `x` must be numeric, got character
```
