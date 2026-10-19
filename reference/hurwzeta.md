# Hurwitz zeta function

Computes the Hurwitz zeta function \\\zeta(s, q) = \sum\_{k \ge 0} (q +
k)^{-s}\\ for a vector of exponents `s` and one lower limit `q`. It is
the normalising constant of the discrete power law truncated below at
`q`, which is why it is here (see
[`hilltlidx()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hilltlidx.md));
`zeta(s, 1)` is the Riemann zeta.

## Usage

``` r
hurwzeta(s, q = 1)
```

## Arguments

- s:

  Numeric vector of exponents. The series converges for `s > 1`; below 1
  the value is the analytic continuation (so `hurwzeta(0.5, 0.5)` is
  \\-0.6049\\), and `s = 1` is a pole (`NA`).

- q:

  Numeric scalar, the lower limit; default `1` (the Riemann zeta). Any
  real number but zero or a negative integer (poles, `NA`). For a
  negative non-integer `q` the value is real only for a whole `s`; a
  fractional `s` gives `NA`.

## Value

A numeric vector the length of `s`.

## Details

For \\s \> 1\\ and \\q \> 0\\ the series is evaluated in compiled code
by Euler-Maclaurin summation: direct terms, the integral of the tail,
and Bernoulli-number corrections. For \\s \< 1\\ the value is the
analytic continuation: exact Bernoulli polynomials for whole \\s \> -5\\
(\\\zeta(-n, q) = -B\_{n+1}(q)/(n+1)\\), Riemann's functional equation
at \\q = 1\\, Hurwitz's Fourier series for \\s \le -5\\, Hermite's
integral (by
[`stats::integrate()`](https://rdrr.io/r/stats/integrate.html)) for \\-5
\< s \< 1\\, and the asymptotic series for large \\q\\, with the shift
\\\zeta(s, q) = q^{-s} + \zeta(s, q + 1)\\ to move \\q\\ into range. A
negative non-integer `q` uses the reflection of its negative terms.

Values that do not exist are `NA`, not errors: `s = 1` (a pole), `q`
zero or a negative integer (poles), a fractional `s` with a negative `q`
(a complex value), and a non-finite `s`. Errors when `s` or `q` is
logical or not numeric, and when `q` is not a single finite number.

## References

The Euler-Maclaurin expansion used here – direct terms to `q + N`, then
the integral tail, then the Bernoulli-number corrections – is the
standard evaluation; see Abramowitz, M. and Stegun, I. A. *Handbook of
Mathematical Functions*, Sec. 23.2. (Not in the local corpus; cited from
the published reference. The implementation is checked against `pi^2/6`,
`pi^4/90`, Apery's constant and the shift identity, which is stronger
evidence than the citation.)

## Examples

``` r
# The Riemann zeta at even integers has a closed form.
c(hurwzeta(2), pi^2 / 6)
#> [1] 1.644934 1.644934
c(hurwzeta(4), pi^4 / 90)
#> [1] 1.082323 1.082323

# Apery's constant.
hurwzeta(3)
#> [1] 1.202057

# Shifting the lower limit removes exactly the leading term.
hurwzeta(2.5, 3) - hurwzeta(2.5, 4)
#> [1] 0.06415003
3^-2.5
#> [1] 0.06415003

# Outside the domain of convergence there is no value to return.
hurwzeta(1)
#> [1] NA

# several exponents at once, including the analytic continuation
hurwzeta(c(2, 0.5, -1))  # -1/12 at s = -1
#> [1]  1.64493407 -1.46035451 -0.08333333

# one lower limit per call
try(hurwzeta(2, q = c(1, 2)))
#> Error : `q` must be a single finite number
```
