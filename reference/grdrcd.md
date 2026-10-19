# Recode a categorical column by explicit name-to-name mapping

Recodes a categorical variable with a mapping written out by name,
`old_label = "new_label"`, so that the recode cannot depend on the order
of the levels. Any value that the mapping does not cover is an error
unless you list it in `keep`; nothing is silently set to `NA` or passed
through. The result records the mapping and its SHA-256, so the recode
that was applied can be shown later. Use it for collapsing or renaming
categories (race, offence type, region) before analysis.

## Usage

``` r
grdrcd(x, map, keep = character())
```

## Arguments

- x:

  A factor or character vector (other atomic vectors are compared
  through [`as.character()`](https://rdrr.io/r/base/character.html)
  matching of their values).

- map:

  Named character vector, `c(old_label = "new_label", ...)`. Every name
  must be non-empty.

- keep:

  Character vector, default empty. Labels allowed to pass through
  unchanged.

## Value

A character vector the same length as `x`, with a `recode_audit`
attribute: a list with `mapping` (the mapping as given), `kept` (the
`keep` vector) and `checksum` (hexadecimal SHA-256 of the mapping).

## Details

Let \\S\\ be the set of distinct non-missing values of `x`. The function
refuses unless \\S \subseteq\\ `names(mapping)` \\\cup\\ `keep`. Each
value found in `names(mapping)` is replaced by its mapped label; values
in `keep` are returned unchanged; `NA` stays `NA`. Several old labels
may map to the same new label (a collapse). Matching is exact: case and
whitespace count.

The checksum is
[`csha256`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
of the string `"old1=new1;old2=new2;..."` built from the mapping in its
given order, so the same mapping written in a different order has a
different checksum.

Errors: `map` not a character vector with non-empty names; any observed
value that is neither mapped nor kept (the message lists them).

[`relbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relbl.md)
is the same check but returns a factor;
[`vrfrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md)
proves the result against the declared mapping;
[`rcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md)
records it.

## See also

[`vrfrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md)
to prove the recode,
[`grdlvls`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdlvls.md)
to fix the levels,
[`rcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md)
to record the chain.

## Examples

``` r
# rename three codes
x <- c("W", "B", "O", "W", NA)
grdrcd(x, c(W = "White", B = "Black", O = "Other"))
#> [1] "White" "Black" "Other" "White" NA     
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>       W       B       O 
#> "White" "Black" "Other" 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] "992b6c4a35a3cea9e5875c90f562a3259fe9f08f1eb2fac9754d7c5b5f52bdd3"
#> 

# collapse two categories and let one pass through unchanged
off <- c("assault", "robbery", "theft", "fraud")
grdrcd(off, c(assault = "violent", robbery = "violent",
                    theft = "property"), keep = "fraud")
#> [1] "violent"  "violent"  "property" "fraud"   
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>    assault    robbery      theft 
#>  "violent"  "violent" "property" 
#> 
#> attr(,"recode_audit")$kept
#> [1] "fraud"
#> 
#> attr(,"recode_audit")$checksum
#> [1] "99dadc6bdace7a9f59469d16f31b7450e4f83835c9383bcbe1074ba84007706d"
#> 

# a value with no mapping is an error
try(grdrcd(x, c(W = "White", B = "Black")))
#> Error : grdrcd: values with NO mapping: ‘O’. Every observed category must be mapped by name (or listed in `keep`); silent pass-through is how group labels get corrupted.
```
