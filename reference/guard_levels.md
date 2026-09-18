# Build a factor with explicit, verified levels

`factor(x)` orders levels alphabetically, which silently decides the
reference category of every downstream regression. This constructor
requires the level set to be written out, errors on values outside it,
and asserts the declared reference level.

## Usage

``` r
guard_levels(x, levels, reference = NULL)
```

## Arguments

- x:

  Character (or factor) vector.

- levels:

  Complete character vector of allowed levels, in the intended order;
  the first is the reference category.

- reference:

  Optional; assert which level is the reference (must equal
  `levels[1]`).

## Value

A factor with exactly the declared levels.

## Examples

``` r
guard_levels(c("White", "Black", "White"), c("White", "Black"), "White")
#> [1] White Black White
#> Levels: White Black
```
