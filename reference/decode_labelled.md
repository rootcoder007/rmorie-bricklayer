# Decode a labelled import by its value labels, by code

Vectors read from SPSS, Stata or SAS carry their categories as numeric
codes with a `labels` attribute (label = code). The categories are the
labels looked up BY CODE; the codes themselves, their order, and the
alphabetical order of the labels are all irrelevant, and treating any of
them as the category is the documented failure. This function looks each
code up in the attribute and refuses codes that have no label.

## Usage

``` r
decode_labelled(x, value_labels = NULL)
```

## Arguments

- x:

  A vector with a `labels` attribute (as produced by haven), or a plain
  numeric vector with `value_labels` supplied.

- value_labels:

  Optional named vector, code = label, used when `x` carries no
  attribute.

## Value

A factor whose levels are the labels in CODE order (not alphabetical),
with a `recode_audit` attribute.

## See also

[`decode_codes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md),
[`relabel`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel.md)

## Examples

``` r
x <- structure(c(1, 2, 2, 4),
               labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
decode_labelled(x)
#> [1] White   Black   Black   Unknown
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>       1       2       3       4 
#>   White   Black   Other Unknown 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] 3d394c3d6f779a313f8fbeecaf5bc4f104738096c07f03c48ab68d5eb52e8de4
#> 
#> Levels: White Black Other Unknown
```
