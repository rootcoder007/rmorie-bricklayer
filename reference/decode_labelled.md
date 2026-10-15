# Decode a labelled import by its value labels, by code

Converts a vector read from SPSS, Stata or SAS (for example by
`haven::read_sav()`), which stores categories as numeric codes with a
`labels` attribute, into a factor of the labels. Each code is looked up
by its value, so neither the order of the codes nor the alphabetical
order of the labels can affect which label a row gets. Codes with no
label are refused. The factor's levels are in code order, which keeps
the source program's reference category.

## Usage

``` r
decode_labelled(x, value_labels = NULL)
```

## Arguments

- x:

  A vector with a `labels` attribute (as produced by haven), or a plain
  vector of codes when `value_labels` is supplied.

- value_labels:

  Optional named character vector, code = label, used only when `x`
  carries no `labels` attribute. Default `NULL`.

## Value

A factor whose levels are the labels in code order (not alphabetical),
with a `recode_audit` attribute as described in
[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md).

## Details

When `x` has a `labels` attribute (a named vector, label = code) it is
used and `value_labels` is ignored; otherwise `value_labels` (code =
label) is required. Decoding is done by
[`decode_codes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md).
The levels are the labels ordered by their numeric code (codes that are
not numbers are ordered after the numeric ones, by string), and include
labels of codes that do not occur.

Errors: a `labels` attribute without names; no attribute and no
`value_labels`; a code with no label.

## See also

[`decode_codes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md),
[`relabel`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel.md),
[`transfer_verify`](https://rootcoder007.github.io/rmorie-bricklayer/reference/transfer_verify.md)

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

# plain codes with a code book; levels follow the codes 1, 2, 10
decode_labelled(c(2, 1, 10), value_labels = c("10" = "Ten", "2" = "Two", "1" = "One"))
#> [1] Two One Ten
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>  10   2   1 
#> Ten Two One 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] 04b601fcdea59b8af2b9872c344ef20fe46363eb3f2dab525ba486cb22d8ecaf
#> 
#> Levels: One Two Ten

# codes alone are not categories
try(decode_labelled(c(1, 2, 2)))
#> Error : decode_labelled: `x` carries no `labels` attribute and `value_labels` was not supplied; the codes alone are NOT the categories
```
