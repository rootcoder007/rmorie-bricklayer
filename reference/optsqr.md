# The optimal search square for a circular normal datum

For a point datum with a circular normal distribution of position error,
the square centred on the datum that a given effort, spread evenly,
should cover to make the probability of success as large as possible
(Frost 1996, chapter 6). With several efforts, each search is optimized
in turn against the distribution as earlier unsuccessful searches left
it.

## Usage

``` r
optsqr(
  effort,
  model = c("invcube", "random", "definite", "mbeta"),
  m = 1,
  E = 1
)
```

## Arguments

- effort:

  Positive numeric vector: the effort (sweep width times track length)
  of each search in turn, in the square of the units of `E`.

- model:

  `"invcube"` (the default; Frost's ideal search conditions), `"random"`
  (poor conditions), `"definite"` or `"mbeta"`.

- m:

  Number in (0, 1\]: the M-Beta height. Default 1.

- E:

  Positive number: the total probable error of position. Default 1.

## Value

A data frame with one row per search: `search`, `effort`, `releff`
(effort over `E^2`), `cumeff` (cumulative relative effort), `factor`,
`side` (`2 f E`), `poc`, `coverage`, `pod`, `pos` and `cumpos` (the
probability that one of the searches so far succeeded).

## Details

The search factor `f` is the half side of the square in units of the
total probable error of position `E` (the radius of the circle holding
half the distribution, `E = 1.1774 sigma`). For relative effort
`z = Z / E^2` the coverage is `C = z / (2 f)^2`, the containment is the
circular normal's mass in the square, `(2 Phi(f E / sigma) - 1)^2` for a
first search, and the probability of success `POC x POD(C)` with the POD
curve of `model`
([`srchpod`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ltrlrng.md)).
The factor is found on a grid of 241 values from 0.02 to 10 and refined
by [`optimize()`](https://rdrr.io/r/stats/optimize.html). After a search
the density inside its square is multiplied by `1 - POD`; every later
search is optimized against what is left, and its `poc` and `pos` are
conditional on the earlier searches having failed. Frost's figures 6-3
to 6-6 are drawn from it by
[`srchfig`](https://rootcoder007.github.io/rmorie-bricklayer/reference/srchfig.md).

## References

Frost, J. R. (1996). The Theory of Search: A Simplified Explanation.
Soza and Company and U.S. Coast Guard Office of Search and Rescue.
Chapter 6.

Koopman, B. O. (1957). The theory of search. III. The optimum
distribution of searching effort. Operations Research 5(5), 613-626.
[doi:10.1287/opre.5.5.613](https://doi.org/10.1287/opre.5.5.613)

## Examples

``` r
# Frost's example: an effort of 4 E^2 on a point datum
optsqr(4)
#>   search effort releff cumeff   factor     side       poc  coverage       pod
#> 1      1      4      4      4 1.021043 2.042086 0.5939919 0.9592059 0.7707087
#>         pos    cumpos
#> 1 0.4577947 0.4577947
# poor search conditions: the random search curve
optsqr(4, model = "random")
#>   search effort releff cumeff factor     side       poc  coverage       pod
#> 1      1      4      4      4 1.0276 2.055199 0.5985885 0.9470049 0.6120989
#>         pos    cumpos
#> 1 0.3663954 0.3663954
# three searches in a row, each optimal for what the last ones left
optsqr(c(4, 4, 8), E = 2)
#>   search effort releff cumeff    factor     side       poc  coverage       pod
#> 1      1      4      1      1 0.6432168 2.572867 0.3037639 0.6042619 0.5511478
#> 2      2      4      1      2 0.9359534 3.743814 0.4381650 0.2853853 0.2794152
#> 3      3      8      2      4 1.1183366 4.473346 0.5339275 0.3997836 0.3836672
#>         pos    cumpos
#> 1 0.1674188 0.1674188
#> 2 0.1224300 0.2693517
#> 3 0.2048504 0.4190253
try(optsqr(-1))
#> Error : optsqr: `effort` must be positive
```
