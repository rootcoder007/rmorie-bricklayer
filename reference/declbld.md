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
declbld(x, vlabs = NULL)
```

## Arguments

- x:

  A vector with a `labels` attribute (as produced by haven), or a plain
  vector of codes when `vlabs` is supplied. A factor, ordered or not, is
  read through its integer codes; the result is an unordered factor
  whose levels follow the codes.

- vlabs:

  Optional named character vector, code = label, used only when `x`
  carries no `labels` attribute. Default `NULL`.

## Value

A factor whose levels are the labels in code order (not alphabetical),
with a `recode_audit` attribute as described in
[`grdrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md).

## Details

When `x` has a `labels` attribute (a named vector, label = code) it is
used and `vlabs` is ignored; otherwise `vlabs` (code = label) is
required. Decoding is done by
[`deccodes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/deccodes.md).
The levels are the labels ordered by their numeric code (codes that are
not numbers are ordered after the numeric ones, by string), and include
labels of codes that do not occur.

Errors: a `labels` attribute without names; no attribute and no `vlabs`;
a code with no label.

## See also

[`deccodes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/deccodes.md),
[`relbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relbl.md),
[`xfrvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xfrvrf.md)

## Examples

``` r
x <- structure(c(1, 2, 2, 4),
               labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
declbld(x)
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
declbld(c(2, 1, 10), vlabs = c("10" = "Ten", "2" = "Two", "1" = "One"))
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
try(declbld(c(1, 2, 2)))
#> Error : declbld: `x` carries no `labels` attribute and `vlabs` was not supplied; the codes alone are NOT the categories
```
