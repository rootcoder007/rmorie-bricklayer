# Record a recode as a manifest that can be signed and verified later

The accountable end of the chain: the mapping and its SHA-256, the
counts per label before and after, the before/after cross-tabulation
check, the match against published counts when given, a timestamp, and
(with a key) a signature over the whole record via
[`capsule_sign`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).
Written with
[`write_recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_recode_manifest.md)
and re-checked with
[`verify_recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_recode_manifest.md),
so a later reader can prove which labels went where and that nothing was
changed afterwards.

## Usage

``` r
recode_manifest(
  original,
  recoded,
  mapping,
  published = NULL,
  key = NULL,
  context = NULL
)
```

## Arguments

- original, recoded:

  Parallel vectors (before and after the recode).

- mapping:

  The named mapping that was applied.

- published:

  Optional named numeric vector of published counts per recoded label.

- key:

  Optional signing key (from
  [`pqc_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  or
  [`fips_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md));
  when given the manifest carries a signature and the public key.

- context:

  Optional free-text context (dataset, table, analyst).

## Value

A list of class `bricklayer_recode_manifest`.

## Examples

``` r
x <- c("W", "B", "W", "I")
y <- guard_recode(x, c(W = "White", B = "Black", I = "Indigenous"))
m <- recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"),
  published = c(White = 2, Black = 1, Indigenous = 1)
)
m$checks
#> $crosstab_is_function
#> [1] TRUE
#> 
#> $missingness_unchanged
#> [1] TRUE
#> 
#> $matches_published
#> [1] TRUE
#> 
```
