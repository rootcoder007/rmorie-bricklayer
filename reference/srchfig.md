# The figures of The Theory of Search

Draws any figure of Frost (1996), "The Theory of Search: A Simplified
Explanation", from the package's search theory functions with the book's
parameters, and returns the numbers it drew.

## Usage

``` r
srchfig(fig = NULL, num = NULL, seed = 1, main = NULL)
```

## Arguments

- fig:

  A figure number as text, `"5-7"`, or the chapter as a number with
  `num`; `NULL` (the default) lists the figures.

- num:

  The figure's number within chapter `fig`, or `NULL`.

- seed:

  Number: the seed of figure 6-6's random efforts. Default 1; the
  session's random number stream is left as it was.

- main:

  The title, or `NULL` for the book's caption.

## Value

Without `fig`, a data frame of `fig`, `caption` and `how`. With one, the
figure's data, invisibly: a data frame (or a list of them) of what was
drawn.

## Details

`srchfig()` with no argument lists the book's 36 figures (3-1 to 3-14,
4-1 to 4-7, 5-1 to 5-9 and 6-1 to 6-6) with how each is drawn: `"model"`
figures are computed from the functions with the book's parameters and
reproduce the values the text states (for example 57.91, 9.08 and 1.42
percent in figure 3-4, 0.75 and 0.6836 in figure 5-7, 0.7899 at coverage
1 in figure 5-8, the optimal factor 1.02 at an effort of 4 E^2 in figure
6-3); `"schematic"` figures are diagrams with no data (3-6, 4-3, 4-6,
5-2); `"approximation"` figures are drawn from the model where the
book's plate cannot be recovered exactly: 3-7 (the density implied by
boxing in two circles is drawn as the `"line"` datum, a circular normal
spread along the segment), 3-13 (the book's surface is illustrative; it
is drawn from the cells of figure 3-14), 5-9 (the plate is blank in the
published file; it is drawn from the text, an inverse cube curve with a
smaller sweep width and flattened by navigation error), 6-6 (the book's
random efforts are not given; 250 groups of 5 are drawn here with
`seed`).

Distances are in standard deviations of position error (`E = 1.1774`),
or in sweep widths (`W = 1`) for the lateral range figures. The general
methods draw the same figures with other parameters:
`plot(ltrlrng(...), equiv = , spacing = )`,
`plot(srchpod(...), models = , m = )`, `plot(datumpmap(...), view = )`.

## References

Frost, J. R. (1996). The Theory of Search: A Simplified Explanation.
Soza and Company and U.S. Coast Guard Office of Search and Rescue.
Chapters 3-6.

## Examples

``` r
head(srchfig())
#>   fig                                                              caption
#> 1 3-1     Probability density distribution for a point datum with top view
#> 2 3-2 Circle of radius one standard deviation and its circumscribed square
#> 3 3-3                      Circle of radius E and its circumscribed square
#> 4 3-4                                    Probability map for a point datum
#> 5 3-5                  Circle of radius 1.1 E and its circumscribed square
#> 6 3-6                       Line datum: circles at the end points boxed in
#>         how
#> 1     model
#> 2     model
#> 3     model
#> 4     model
#> 5     model
#> 6 schematic
srchfig("3-4")

srchfig(5, 8)

d <- srchfig("6-3")

head(d)
#>     model search    effort    releff    cumeff    factor      side        poc
#> 1 invcube      1 0.0500000 0.0500000 0.0500000 0.2369631 0.4739262 0.04829326
#> 2 invcube      1 0.2772152 0.2772152 0.2772152 0.4194013 0.8388025 0.14330593
#> 3 invcube      1 0.5044304 0.5044304 0.5044304 0.5120250 1.0240500 0.20557192
#> 4 invcube      1 0.7316456 0.7316456 0.7316456 0.5795946 1.1591892 0.25505216
#> 5 invcube      1 0.9588608 0.9588608 0.9588608 0.6342726 1.2685451 0.29682341
#> 6 invcube      1 1.1860759 1.1860759 1.1860759 0.6808659 1.3617317 0.33321682
#>    coverage       pod        pos     cumpos
#> 1 0.2226120 0.2197573 0.01061280 0.01061280
#> 2 0.3940012 0.3785577 0.05424956 0.05424956
#> 3 0.4810154 0.4534004 0.09320639 0.09320639
#> 4 0.5444927 0.5050269 0.12880820 0.12880820
#> 5 0.5958593 0.5448150 0.16171385 0.16171385
#> 6 0.6396308 0.5772494 0.19234920 0.19234920
try(srchfig("9-9"))
#> Error : srchfig: `fig` must be one of the book's figures, 3-1, 3-2, 3-3, 3-4, 3-5, 3-6, 3-7, 3-8, 3-9, 3-10, 3-11, 3-12, 3-13, 3-14, 4-1, 4-2, 4-3, 4-4, 4-5, 4-6, 4-7, 5-1, 5-2, 5-3, 5-4, 5-5, 5-6, 5-7, 5-8, 5-9, 6-1, 6-2, 6-3, 6-4, 6-5, 6-6; got "9-9"
```
