# Relabel a categorical variable by name, never by position

A relabel is only safe when every old level is mapped BY NAME to its new
label. Assigning a vector of labels by position (the `levels<-` idiom,
or `factor(x, labels = ...)` with labels in a different order from the
codes) is the mechanism behind the documented four-way rotation in the
OHRC 2023 correction, so this function refuses unnamed mappings
outright.

## Usage

``` r
relabel(x, mapping, keep = character())
```

## Arguments

- x:

  A factor or character vector.

- mapping:

  Named character vector, old label to new label. Every observed level
  must appear as a name unless listed in `keep`.

- keep:

  Levels allowed to pass through unchanged.

## Value

A factor with the new labels, levels in the order of `mapping`, carrying
a `recode_audit` attribute (see
[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md)).

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
try(relabel(f, c("Black", "Other", "White")))
#> Error : relabel: `mapping` must be NAMED (old label = new label). Assigning labels by POSITION is how four race codes were rotated in a published analysis (OHRC correction, 26 January 2023): the labels were in alphabetical order, the codes were not.
```
