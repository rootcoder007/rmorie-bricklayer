# Search theory for search and rescue planning

The quantities a search and rescue planner works with (Koopman's search
theory, as used in the U.S. Coast Guard and IAMSAR planning methods):

- `ltrlrng()` (lateral range): the probability that a sensor passing at
  distance `x` detects the object, under the inverse cube, definite
  range or M-Beta model with sweep width `W`;

- `swpwdth()` (sweep width): the area under a sampled lateral range
  curve;

- `srchpod()` (search POD): the probability of detection from coverage,
  for random search, a definite-range sweep and an inverse cube parallel
  sweep;

- `pswppod()` (parallel sweep POD): the POD of a parallel sweep at track
  spacing `S`, computed for any model, with optional normal navigation
  error;

- `srchscs()` (search success): the probability of success, the
  cumulative POD of repeated searches and the containment probabilities
  updated after an unsuccessful search;

- `datumpmap()` (datum probability map): the probability that each grid
  cell contains the object, for a point, line or area datum;

- `optcrcsrch()` (optimal circular search): Koopman's optimal effort for
  a circular normal datum;

- `opteffort()` (optimal effort): the allocation of a fixed effort over
  cells that maximises the probability of success.

## Usage

``` r
ltrlrng(x, W, model = c("invcube", "definite", "mbeta"), m = 1, navsd = 0)

swpwdth(x, p = NULL)

srchpod(coverage, model = c("random", "definite", "invcube", "mbeta"), m = 1)

pswppod(
  W,
  S,
  model = c("invcube", "definite", "mbeta"),
  m = 1,
  navsd = 0,
  npts = 2001,
  ntrk = 60
)

srchscs(poc, pod)

datumpmap(
  xedg,
  yedg,
  datum = c("point", "line", "area", "corridor", "general"),
  center = c(0, 0),
  sigma = 1,
  end = NULL,
  nodes = 64,
  wts = NULL
)

optcrcsrch(sigma, W, effort)

opteffort(poc, area = NULL, W, effort, tol = 1e-14)
```

## Arguments

- x:

  Numeric vector: lateral ranges (distances from the track), any sign.
  For `swpwdth()`, strictly increasing abscissae, or an `rmbl_ltrlrng`
  object (then `p` is taken from it).

- W:

  Positive number: the sweep width.

- model:

  For `ltrlrng()` and `pswppod()`: `"invcube"` (the default),
  `"definite"` or `"mbeta"`. For `srchpod()`: `"random"` (the default),
  `"definite"`, `"invcube"` or `"mbeta"`.

- m:

  Number in (0, 1\]: the M-Beta detection probability inside its range.
  Default 1.

- navsd:

  Non-negative number: the standard deviation of the cross-track
  navigation error, in the units of `x`. Default 0.

- p:

  Numeric vector in \[0, 1\]: the lateral range curve at `x`.

- coverage:

  Non-negative numeric vector of coverages.

- S:

  Positive number: the track spacing.

- npts, ntrk:

  Whole numbers: the quadrature points across one spacing (at least 3,
  raised to the next odd number; default 2001) and the tracks on each
  side (at least 1; default 60).

- poc:

  Numeric vector or matrix in \[0, 1\], summing to at most 1: the
  probability that each area contains the object. For `opteffort()` also
  an `rmbl_datummap` object from `datumpmap()`.

- pod:

  Numeric vector in \[0, 1\], one per area, or a matrix with one row per
  search and one column per area.

- xedg, yedg:

  Strictly increasing numeric vectors: the cell edges of the grid.

- datum:

  `"point"` (the default), `"line"`, `"area"`, `"corridor"` or
  `"general"`.

- center:

  Two numbers: the datum point, the start of a line datum or a corner of
  an area datum. Default `c(0, 0)`.

- sigma:

  Positive number: the standard deviation of the circular normal
  position error.

- end:

  Two numbers: the end of a line datum or the opposite corner of an area
  datum; `NULL` for a point datum.

- nodes:

  Whole number from 2 to 1000: Gauss-Legendre nodes along a line datum.
  Default 64.

- wts:

  For `datum = "general"`: a non-negative matrix of cell weights, one
  row per `y` cell and one column per `x` cell.

- effort:

  Non-negative number: the total effort, as track length.

- area:

  Positive numeric vector, one per cell: the cell areas. May be `NULL`
  when `poc` is an `rmbl_datummap`.

- tol:

  Positive number: the bisection tolerance on log lambda.

## Value

`ltrlrng()`: a numeric vector of class `rmbl_ltrlrng` (the detection
probabilities, with the inputs as attributes;
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) drops them).
`srchpod()`: a numeric vector of class `rmbl_srchpod`. `swpwdth()` and
`pswppod()`: one number. `srchscs()`: a list of class `rmbl_srchscs`
with `pos` (the probability of success), `posarea` (per area), `pocupd`
(the updated containment probabilities) and `cumpod` (the cumulative POD
per area). `datumpmap()`: a list of class `rmbl_datummap` with `poc`, a
matrix with one row per `y` cell and one column per `x` cell, `outside`,
and the inputs. `optcrcsrch()`: a list of class `rmbl_optcrc` with
`radius`, `pos` and `cntrdns` (the coverage at the centre).
`opteffort()`: a list of class `rmbl_opteffort` with `effort`,
`coverage` and `pod` per cell (a matrix when `poc` is one), `pos` and
`lambda`. Every class has a
[`print()`](https://rdrr.io/r/base/print.html) method, and
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
lateral range curve (`equiv = TRUE` adds the equivalent definite-range
rectangle, `spacing` a second track), the POD by coverage for any of the
models (`models`, `m`, `cmax`), the map as an image with contours, a
surface, both side by side, or its cells with their percentages
(`view`), and the allocation (see
[`plot-methods`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md)).
[`srchfig`](https://rootcoder007.github.io/rmorie-bricklayer/reference/srchfig.md)
draws every figure of Frost (1996) with them.

## Details

Coverage is `C = W z / A`: sweep width times track length over the area
searched (for a parallel sweep, `W / S`). The lateral range curves are:
definite range, `p(x) = 1` for `|x| <= W / 2`; M-Beta, `p(x) = m` for
`|x| <= W / (2 m)`; inverse cube, `p(x) = 1 - exp(-W^2 / (4 pi x^2))`.
Each has area `W`, the sweep width. `swpwdth()` integrates by the
trapezoid rule.

With `navsd > 0`, `ltrlrng()` gives the expected curve seen through a
normal cross-track navigation error: the convolution of the curve with
that normal (Frost 1996, equation 5-14), exact for the rectangular
curves and by 40-point Gauss-Hermite quadrature for the inverse cube.
Its area is still `W`; the curve is lower and wider.

`srchpod()`: random search `1 - exp(-C)`; definite range `min(C, 1)`;
inverse cube parallel sweep `erf(sqrt(pi) C / 2)` (Koopman 1956); M-Beta
parallel sweep `C` for `C < M` and `1 - (1 - M)^(C / M)` above it (Frost
1996, equation 5-11), which is exact wherever the tracks overlap a whole
number of times.

`pswppod()` integrates over one track spacing (Simpson's rule on `npts`
points) the probability that at least one of the tracks
`-ntrk, ..., ntrk` detects the object; for the inverse cube model the
tracks beyond `ntrk` are added in closed form from
`sum_k 1 / (x - k S)^2 = (pi / S)^2 / sin^2(pi x / S)`. With `navsd > 0`
the lateral range curve is averaged over a normal cross-track error
(40-point Gauss-Hermite quadrature). Without navigation error the
inverse cube result equals `srchpod(W / S, "invcube")`.

`srchscs()`: the probability of success is `POS = sum(POC * POD)`; after
an unsuccessful search the containment probabilities become
`POC (1 - POD) / (1 - POS)` (Bayes). With several searches (`pod` a
matrix, one row per search) the update is applied in turn and the
cumulative POD is `1 - prod(1 - POD)` per area. When a search is certain
to succeed (`POS = 1`) the update is undefined: it is returned as `NA`,
with a warning.

`datumpmap()`: a point datum is a circular normal of standard deviation
`sigma` about `center`; a line datum the same spread along the segment
from `center` to `end` (Gauss-Legendre quadrature on `nodes` points); an
area datum a uniform distribution over the rectangle with corners
`center` and `end`; a corridor datum normal across the segment from
`center` to `end` and uniform along it, with nothing beyond its ends
(Frost 1996, figure 3-8; the segment must run along x or along y); a
general datum the cell weights `wts` scaled to sum to 1. The share of
the probability outside the grid is returned as `outside`.

`optcrcsrch()`: with effort (track length) `L`, the optimal search of a
circular normal datum covers a disc of radius
`R = (4 sigma^2 W L / pi)^(1/4)`, and succeeds with probability
`1 - (1 + u) exp(-u)`, `u = R^2 / (2 sigma^2)` (Koopman 1957).

`opteffort()`: under random search detection the optimal effort in cell
`i` is `z_i = (A_i / W) log(r_i / lambda)` where `r_i = POC_i W / A_i`
exceeds `lambda`, and 0 elsewhere; the Lagrange multiplier `lambda` is
found by bisection on its logarithm so that the efforts add up to
`effort` (Stone 1975, chapter 2).

Every input is checked: numbers must be finite and of the right length,
sweep widths, spacings and standard deviations positive, probabilities
in \[0, 1\] and containment probabilities summing to at most 1; unknown
models and datum types are errors.

## References

Koopman, B. O. (1946). Search and Screening. OEG Report 56, Operations
Evaluation Group, Office of the Chief of Naval Operations.

Koopman, B. O. (1956). The theory of search. I. Kinematic bases.
Operations Research 4(3), 324-346.
[doi:10.1287/opre.4.3.324](https://doi.org/10.1287/opre.4.3.324)

Koopman, B. O. (1956). The theory of search. II. Target detection.
Operations Research 4(5), 503-531.
[doi:10.1287/opre.4.5.503](https://doi.org/10.1287/opre.4.5.503)

Koopman, B. O. (1957). The theory of search. III. The optimum
distribution of searching effort. Operations Research 5(5), 613-626.
[doi:10.1287/opre.5.5.613](https://doi.org/10.1287/opre.5.5.613)

Frost, J. R. (1996). The Theory of Search: A Simplified Explanation.
Soza and Company and U.S. Coast Guard Office of Search and Rescue.

Stone, L. D. (1975). Theory of Optimal Search. Academic Press.

## Examples

``` r
# inverse cube detection 0.5, 1 and 2 sweep widths off the track
ltrlrng(c(0.5, 1, 2), W = 1)
#> ── Lateral range curve ─────────────────────────────────────────── 
#>   inverse cube model, sweep width W = 1
#> 
#>  range       pod
#>    0.5 0.2726230
#>    1.0 0.0764935
#>    2.0 0.0196978
#> ────────────────────────────────────────────────────────────────── 
plot(ltrlrng(seq(-3, 3, by = 0.5), W = 2))


# the area under the curve is the sweep width
xs <- seq(-200, 200, by = 0.01)
swpwdth(xs, ltrlrng(xs, W = 1, model = "definite"))
#> [1] 1.01

# POD at coverage 1 under the three models
srchpod(1)
#> ── Probability of detection ────────────────────────────────────── 
#>   random search model
#> 
#>  coverage      pod
#>         1 0.632121
#> ────────────────────────────────────────────────────────────────── 
srchpod(c(0.5, 1, 2), model = "invcube")
#> ── Probability of detection ────────────────────────────────────── 
#>   inverse cube model
#> 
#>  coverage      pod
#>       0.5 0.469116
#>       1.0 0.789909
#>       2.0 0.987811
#> ────────────────────────────────────────────────────────────────── 
plot(srchpod(c(0.5, 1, 1.5)))

# the book's M-Beta curves against random search and the definite range
plot(srchpod(1, "mbeta", m = 0.5), models = c("random", "definite", "mbeta"),
     m = c(0.5, 0.25))

# the expected curve under a navigation error as large as half the sweep width
plot(ltrlrng(0, W = 1, navsd = 0.5), equiv = TRUE)


# a parallel sweep at spacing 1.3 W, without and with navigation error
pswppod(1, 1.3)
#> [1] 0.6649981
pswppod(1, 1.3, navsd = 0.3, npts = 201)
#> [1] 0.6460403

# three areas searched once; the containment after finding nothing
srchscs(c(0.5, 0.3, 0.2), c(0.8, 0.5, 0))
#> ── Probability of success ──────────────────────────────────────── 
#>   POS 0.55 after 1 search
#> 
#>  area poc cumpod posarea pocupd
#>     1 0.5    0.8    0.40 0.2222
#>     2 0.3    0.5    0.15 0.3333
#>     3 0.2    0.0    0.00 0.4444
#> ────────────────────────────────────────────────────────────────── 

# a point datum on a 10 x 10 grid, and the best use of 30 units of track
m <- datumpmap(seq(-5, 5), seq(-5, 5), sigma = 2)
plot(m)

plot(m, view = "both")

# the book's line datum: normal across the line, uniform along it
plot(datumpmap(0:10, seq(-3, 3, by = 1.2), "corridor", c(0, 0), end = c(10, 0)),
     view = "cells", digits = 1)

a <- opteffort(m, W = 1, effort = 30)
a$pos
#> [1] 0.4520985
plot(a)

optcrcsrch(sigma = 2, W = 1, effort = 30)$pos
#> [1] 0.4571532

# inputs that cannot be right are refused
try(ltrlrng(1, W = -1))
#> Error : ltrlrng: `W` must be positive
try(srchscs(c(0.8, 0.8), c(0.5, 0.5)))
#> Error : srchscs: `poc` must sum to at most 1, got 1.6
```
