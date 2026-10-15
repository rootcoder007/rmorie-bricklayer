# Relabel a categorical variable by name, never by position

Gives a factor or character vector new labels with a mapping written by
name, old label = new label, and returns a factor. Assigning a vector of
labels by position (the `levels(x) <- ...` idiom, or
`factor(x, labels = ...)` with labels in a different order from the
codes) is how the four race categories were rotated in the analysis that
the Ontario Human Rights Commission corrected on 26 January 2023; this
function refuses unnamed mappings outright, and refuses levels that the
mapping does not cover.

## Usage

``` r
relabel(x, mapping, keep = character())
```

## Arguments

- x:

  A factor or character vector.

- mapping:

  Named character vector, old label = new label. Every level of `x` must
  appear as a name unless listed in `keep`. Several old labels may map
  to one new label.

- keep:

  Character vector, default empty: levels allowed to pass through
  unchanged.

## Value

A factor with the new labels, levels in the order of `mapping`, carrying
a `recode_audit` attribute (see
[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md)).

## Details

The old levels are `levels(x)` for a factor and the sorted distinct
values otherwise; all of them must be names of `mapping` or members of
`keep`, so for a factor even an unused level must be mapped. The recode
itself is
[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md).
The levels of the result are the distinct values of `mapping` in the
order given, followed by the `keep` labels that occur in the data.

Errors: `mapping` without names (including a plain vector of new
labels); a level with no mapping.

## See also

[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md),
[`relabel_forensics`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md),
[`decode_labelled`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_labelled.md)

## Examples

``` r
f <- factor(c("W", "B", "O", "W"))
relabel(f, c(W = "White", B = "Black", O = "Other"))
#> [1] White Black Other White
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>     W     B     O 
#> White Black Other 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] 992b6c4a35a3cea9e5875c90f562a3259fe9f08f1eb2fac9754d7c5b5f52bdd3
#> 
#> Levels: White Black Other

# the level order follows the mapping, not the alphabet
levels(relabel(f, c(W = "White", O = "Other", B = "Black")))
#> [1] "White" "Other" "Black"

# a kept label passes through
relabel(c("W", "B", "X"), c(W = "White", B = "Black"), keep = "X")
#> [1] White Black X    
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>     W     B 
#> White Black 
#> 
#> attr(,"recode_audit")$kept
#> [1] X
#> 
#> attr(,"recode_audit")$checksum
#> [1] ec818263ffb31defd682d27e1321fa8ea63f3f231b36b6b99fba61dca9510602
#> 
#> Levels: White Black X

# positional labels are refused
try(relabel(f, c("Black", "Other", "White")))
#> Error : relabel: `mapping` must be NAMED (old label = new label). Assigning labels by POSITION is how four race codes were rotated in a published analysis (OHRC correction, 26 January 2023): the labels were in alphabetical order, the codes were not.
```
