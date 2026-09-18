# Prove a recode with a before/after cross-tabulation

Cross-tabulates the original against the recoded values and errors
unless the realized mapping is a function (each old category to exactly
one new category) that matches the declared mapping, with no rows lost
and no change in missingness.

## Usage

``` r
verify_recode(original, recoded, declared)
```

## Arguments

- original, recoded:

  Parallel vectors (before and after).

- declared:

  Named character vector: the mapping the analyst claims was applied.
  Identity is assumed for old values absent from `declared`.

## Value

Invisibly, the cross-tabulation as a data frame, if and only if every
check passes.

## Examples

``` r
verify_recode(
  c("W", "B", "W"), c("White", "Black", "White"),
  c(W = "White", B = "Black")
)
```
