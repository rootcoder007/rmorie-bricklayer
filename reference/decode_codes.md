# Decode numeric category codes with an explicit code-to-label dictionary

The guard for data that arrives from SPSS, Stata or SAS as integer
codes: every code observed must be listed in `value_labels`, and the
result is the label, never the code. A code without a label is an error,
because treating codes as categories (or
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) on a factor of
them) is how groups get renumbered.

## Usage

``` r
decode_codes(x, value_labels, keep_na = TRUE)
```

## Arguments

- x:

  Numeric or character vector of codes.

- value_labels:

  Named character vector: `c("1" = "White", "2" = "Black", ...)` with
  the codes as names.

- keep_na:

  Logical; `NA` codes stay `NA` (default) rather than error.

## Value

A character vector of labels with a `recode_audit` attribute.

## Examples

``` r
decode_codes(c(1, 2, 2, 3),
             c("1" = "White", "2" = "Black", "3" = "Indigenous"))
#> [1] "White"      "Black"      "Black"      "Indigenous"
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>            1            2            3 
#>      "White"      "Black" "Indigenous" 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] "be0b0dcd1bb12223f6d28bc031e1accfd45a3f700d18c920b54d7d766905bdd0"
#> 
```
