# Treated, comparison and excluded places around sites

Assigns each place (a block, an address) to the treated group when it
lies within a radius of a site (a store that donated, a new facility),
to the comparison group when it lies within the same radius of a
comparison point and farther than a buffer from every site, and excludes
it otherwise, so that spillover from the sites does not reach the
comparison.

## Usage

``` r
bufasgn(x, y, sitex, sitey, comx, comy, radius, buffer = 3 * radius)
```

## Arguments

- x, y:

  Coordinates of the places.

- sitex, sitey:

  Coordinates of the sites.

- comx, comy:

  Coordinates of the comparison points (for example the nearest major
  intersections).

- radius:

  The treatment radius.

- buffer:

  The distance from every site a comparison place must keep (default
  `3 * radius`).

## Value

A data frame of class `rmbl_buffer` with the columns `group`
(`"treated"`, `"comparison"` or `"excluded"`), `site_distance` and
`comparison_distance`.

## Details

Distances are Euclidean, so coordinates must be projected (metres or
feet, not degrees). The radius and the buffer are in the same unit. The
buffer should be several times the radius: the design it follows used
330 feet and 990 feet.

## References

Applied to blocks near donor stores: Zorro Medina, Hackett, Green and
Vargas (2025), see
[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md).

## Examples

``` r
set.seed(4)
x <- runif(200, 0, 5000)
y <- runif(200, 0, 5000)
a <- bufasgn(x, y, c(1000, 3500), c(1200, 3000), c(2500, 4500), c(500, 4000),
                   radius = 330)
table(a$group)
#> 
#> comparison   excluded    treated 
#>          4        191          5 
```
