# Recode a categorical column by explicit name-to-name mapping

Every mapping is written `old_label = "new_label"` by name; positional
and index-based recoding are impossible, and any value not covered by
the mapping is an error (never a silent `NA` or pass-through) unless
listed in `keep`. The result carries a `recode_audit` attribute with the
mapping and its SHA-256, so the mapping that was applied is on the
record.

## Usage

``` r
guard_recode(x, mapping, keep = character())
```

## Arguments

- x:

  A factor or character vector.

- mapping:

  Named character vector: `c(old_label = "new_label", ...)`.

- keep:

  Optional character vector of labels allowed to pass through unchanged.

## Value

A character vector with a `recode_audit` attribute (`mapping`, `kept`,
`checksum`).

## See also

[`verify_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_recode.md)
to prove the recode,
[`guard_levels`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_levels.md)
to fix the levels,
[`recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md)
to record the chain.

## Examples

``` r
guard_recode(c("W", "B", "O", "W"), c(W = "White", B = "Black", O = "Other"))
#> [1] "White" "Black" "Other" "White"
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
```
