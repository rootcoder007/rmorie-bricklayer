# Audit the categorical columns of a data frame for coding hazards

Checks every categorical column of a data frame for the coding problems
that silently change results: numbers that are really category codes
whose labels were lost, labels still in foreign value-label form, labels
that differ only by case or by an invisible space, empty strings or
`"NA"` stored as a category, unused levels, and identifiers mistaken for
categories. Run it once after every import, before any model. It also
reports which level R will use as the reference category.

## Usage

``` r
audit_categories(data, cols = NULL)
```

## Arguments

- data:

  A data frame.

- cols:

  Character vector of column names to audit, default `NULL`: every
  factor, character or haven-labelled column. Columns of other types can
  be named explicitly and are audited by their distinct values.

## Value

A data frame of class `c("bricklayer_category_audit", "data.frame")`,
one row per audited column, with character columns `column`, `storage`
(the column's class), `levels` (up to eight levels joined with `"|"`),
`reference` (the first level) and `hazards` (all hazards joined with
`" ;; "`, or `""`), and integer `n_levels`. The attribute `clean` is
`TRUE` when no hazard was found. The print method lists each column and
its hazards.

## Details

For each column the levels are `levels(x)` for a factor and the sorted
distinct values (radix sort, as
[`factor()`](https://rdrr.io/r/base/factor.html) would order them)
otherwise. A hazard is reported when:

- the column is haven `labelled` (it still carries value labels and must
  be decoded with
  [`decode_codes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md)
  or
  [`decode_labelled`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_labelled.md));

- every level looks like a number (`^[0-9.]+$`);

- every level starts with a code prefix such as `"1. White"`;

- a level has leading or trailing whitespace, including non-breaking and
  other Unicode spaces, or two levels are equal once trimmed;

- a level is empty, or is a missing-value sentinel (`NA`, `N/A`, `NAN`,
  `NULL`, `NONE`, `.`, `-`, `?`, compared case-insensitively);

- the reference (first) level is empty, a sentinel, or padded;

- two different trimmed levels agree once lower-cased;

- a factor has levels that never occur;

- there are more than 50 levels.

The function only reports; it never changes `data`. It errors when
`data` is not a data frame.

## See also

[`decode_codes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md),
[`guard_levels`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_levels.md),
[`transfer_verify`](https://rootcoder007.github.io/rmorie-bricklayer/reference/transfer_verify.md).

## Examples

``` r
# codes without labels, and a case-variant city name
a <- audit_categories(data.frame(
  race = factor(c("1", "2", "2", "3")),
  city = c("Toronto", "toronto", "Ottawa")[c(1, 2, 3, 3)]
))
a
#> Categorical audit: 2 column(s)
#>   race             factor     3 level(s), reference ‘1’
#>     !! HAZARD: all labels numeric-looking (1,2,3...): likely imported CODES whose value labels were lost; as.numeric() on this column returns level INDICES, not data 
#>   city             character  3 level(s), reference ‘Ottawa’
#>     !! HAZARD: case-variant duplicate labels: ‘Toronto’, ‘toronto’ 
attr(a, "clean")
#> [1] FALSE

# padded, empty and sentinel labels, and an unused level
audit_categories(data.frame(
  g = factor(c(" A", "A", "NA", ""), levels = c("", " A", "A", "NA", "B"))
))
#> Categorical audit: 1 column(s)
#>   g                factor     5 level(s), reference ‘’
#>     !! HAZARD: labels with leading/trailing whitespace (incl. non-breaking): ‘ A’: a space splits one category into two 
#>     !! HAZARD: whitespace-variant duplicate labels: ‘ A’, ‘A’ 
#>     !! HAZARD: empty-string label "": missingness stored as a category 
#>     !! HAZARD: missing-value sentinel stored as a label: ‘NA’ 
#>     !! HAZARD: the REFERENCE level ‘’ is empty, a sentinel, or differs from a real label only by invisible characters: every model on this column is baselined on it 
#>     !! HAZARD: unused levels: ‘B’ 

# a clean frame; non-categorical columns are skipped by default
audit_categories(data.frame(sex = c("F", "M", "F"), age = c(31, 45, 27)))
#> Categorical audit: 1 column(s)
#>   sex              character  2 level(s), reference ‘F’
#>   no hazards detected

try(audit_categories(1:3))
#> Error : audit_categories: `data` must be a data frame
```
