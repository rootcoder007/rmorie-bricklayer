# Hurwitz zeta function

`zeta(s, q) = sum over k >= 0 of (q + k)^-s`, by Euler-Maclaurin. It is
the normalising constant of the discrete power law truncated below at
`q`, which is why it is here; `zeta(s, 1)` is the Riemann zeta.

## Usage

``` r
hurwitz_zeta(s, q = 1)
```

## Arguments

- s:

  Exponent, which must exceed 1 for the series to converge.

- q:

  Lower limit, which must be positive.

## Value

A numeric vector the length of `s`.

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
c(hurwitz_zeta(2), pi^2 / 6)
#> [1] 1.644934 1.644934
c(hurwitz_zeta(4), pi^4 / 90)
#> [1] 1.082323 1.082323

# Apery's constant.
hurwitz_zeta(3)
#> [1] 1.202057

# Shifting the lower limit removes exactly the leading term.
hurwitz_zeta(2.5, 3) - hurwitz_zeta(2.5, 4)
#> [1] 0.06415003
3^-2.5
#> [1] 0.06415003

# Outside the domain of convergence there is no value to return.
hurwitz_zeta(1)
#> [1] NA
```
