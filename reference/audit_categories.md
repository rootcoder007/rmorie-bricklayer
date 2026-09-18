# Audit the categorical columns of a data frame for coding hazards

One call after every import, before any model. Reports, per categorical
column: storage, levels in order, the reference level R would use, and
the known hazards: numeric-looking labels (codes imported without their
value labels), still-labelled foreign columns, case-variant duplicate
labels, unused levels, and high-cardinality accidents.

## Usage

``` r
audit_categories(data, cols = NULL)
```

## Arguments

- data:

  A data frame.

- cols:

  Columns to audit (default: every factor, character or labelled
  column).

## Value

A data frame of class `bricklayer_category_audit` with one row per
column (`column`, `storage`, `n_levels`, `levels`, `reference`,
`hazards`) and a `clean` attribute.

## Examples

``` r
audit_categories(data.frame(
  race = factor(c("1", "2", "2", "3")),
  city = c("Toronto", "toronto", "Ottawa")[c(1, 2, 3, 3)]
))
#> Categorical audit: 2 column(s)
#>   race             factor     3 level(s), reference ‘1’
#>     !! HAZARD: all labels numeric-looking (1,2,3...): likely imported CODES whose value labels were lost; as.numeric() on this column returns level INDICES, not data 
#>   city             character  3 level(s), reference ‘Ottawa’
#>     !! HAZARD: case-variant duplicate labels: ‘Toronto’, ‘toronto’ 
```
