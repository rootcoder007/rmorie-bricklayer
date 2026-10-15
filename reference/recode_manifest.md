# Record a recode as a manifest that can be signed and verified later

Builds a record of a recode that a later reader can check: the mapping
and its SHA-256, the counts per label before and after, the results of
the before/after cross-tabulation check and (when given) of the match
against published counts, a UTC timestamp, and, with a key, a signature
over the whole record. Write it to disk with
[`write_recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_recode_manifest.md)
and re-check it with
[`verify_recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_recode_manifest.md),
so anyone can confirm which labels went where and that nothing was
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

  Vectors of the same length: the values before and after the recode.

- mapping:

  Named character vector, old = new: the mapping that was applied.

- published:

  Optional named numeric vector of published counts per recoded label,
  default `NULL` (no check).

- key:

  Optional signing key, default `NULL` (unsigned): a key from
  [`pqc_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
  or
  [`fips_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).
  When given the manifest carries a signature and the public key.

- context:

  Optional character string, default `NULL`: free text such as the
  dataset, table and analyst. Only the first element is kept.

## Value

A list of class `c("bricklayer_recode_manifest", "list")` with elements
`context`, `created` (ISO 8601 UTC time), `mapping` (list),
`mapping_sha256`, `n` (number of rows), `n_missing`, `counts_before` and
`counts_after` (named lists of counts), `checks` (list of
`crosstab_is_function`, `missingness_unchanged`, `matches_published`),
`published` (list or `NULL`), `body_sha256`, and with a key `signature`
and `public_key`.

## Details

The function first runs
[`verify_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_recode.md)`(original, recoded, mapping)`
and, when `published` is given,
[`verify_marginals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_marginals.md)`(recoded, published)`
with the default `strict = TRUE`. Either check failing is an error, so a
manifest is only produced for a recode that passed;
`checks$matches_published` is therefore `TRUE` or `NA` (no published
counts), never `FALSE`.

`body_sha256` is
[`core_sha256`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md)
of the canonical JSON of every other field. With a `key`,
[`capsule_sign`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
signs that hash and the manifest also stores the public key: a
`bricklayer_signing_key` from
[`pqc_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqc_keygen.md)
(XMSS, which consumes one one-time leaf per signature) or a key from
[`fips_keygen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
(ML-DSA or SLH-DSA). Nothing is written to disk.

## Examples

``` r
x <- c("W", "B", "W", "I")
map <- c(W = "White", B = "Black", I = "Indigenous")
y <- guard_recode(x, map)
m <- recode_manifest(x, y, map,
  published = c(White = 2, Black = 1, Indigenous = 1),
  context = "example survey, race item"
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
m$counts_after
#> $Black
#> [1] 1
#> 
#> $Indigenous
#> [1] 1
#> 
#> $White
#> [1] 2
#> 

# signed with an ML-DSA key
k <- fips_keygen(seed = as.raw(1:32))
ms <- recode_manifest(x, y, map, key = k)
names(ms)
#>  [1] "context"        "created"        "mapping"        "mapping_sha256"
#>  [5] "n"              "n_missing"      "counts_before"  "counts_after"  
#>  [9] "checks"         "published"      "body_sha256"    "signature"     
#> [13] "public_key"    

# a recode that does not match the published counts is refused
try(recode_manifest(x, y, map, published = c(White = 1, Black = 2, Indigenous = 1)))
#> Error : verify_marginals: recoded counts do not match the published counts. White: observed 2, published 1; Black: observed 1, published 2; Indigenous: observed 1, published 1. The observed counts match the published ones if the labels are permuted (White -> Black, Black -> White): the labels are attached to the wrong groups.
```
