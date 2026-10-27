# Record a recode as a manifest that can be signed and verified later

Builds a record of a recode that a later reader can check: the mapping
and its SHA-256, the counts per label before and after, the results of
the before/after cross-tabulation check and (when given) of the match
against published counts, a UTC timestamp, and, with a key, a signature
over the whole record. Write it to disk with
[`wrrcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md)
and re-check it with
[`vrfrcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrrcdmnf.md),
so anyone can confirm which labels went where and that nothing was
changed afterwards.

## Usage

``` r
rcdmnf(orig, recd, map, pub = NULL, key = NULL, ctx = NULL)
```

## Arguments

- orig, recd:

  Vectors of the same length: the values before and after the recode.

- map:

  Named character vector, old = new: the mapping that was applied.

- pub:

  Optional named numeric vector of published counts per recoded label,
  default `NULL` (no check).

- key:

  Optional signing key, default `NULL` (unsigned): a key from
  [`pqckg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
  or
  [`fipskg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).
  When given the manifest carries a signature and the public key.

- ctx:

  Optional character string, default `NULL`: free text such as the
  dataset, table and analyst. Only the first element is kept.

## Value

A list of class `bricklayer_recode_manifest` with these elements:

- `context`;

- `created` (ISO 8601 UTC time);

- `mapping` (list) and `mapping_sha256`;

- `n` (number of rows) and `n_missing`;

- `counts_before` and `counts_after` (named lists of counts);

- `checks`, a list: `crosstab_is_function`, `missingness_unchanged` and
  `matches_published`;

- `published` (list or `NULL`);

- `body_sha256`;

- with a key, `signature` and `public_key`.

## Details

The function first runs
[`vrfrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md),
as `vrfrcd(original, recoded, mapping)`. When `pub` is given it then
runs
[`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md),
as `vrfmrg(recoded, published)`, with the default `strict = TRUE`.
Either check failing is an error, so a manifest is only produced for a
recode that passed. For that reason `checks$matches_published` is `TRUE`
or `NA` (no published counts), never `FALSE`.

`body_sha256` is
[`csha256`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md)
of the canonical JSON of every other field. With a `key`,
[`cpssign`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
signs that hash and the manifest also stores the public key: a
`bricklayer_signing_key` from
[`pqckg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md)
(XMSS, which consumes one one-time leaf per signature) or a key from
[`fipskg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
(ML-DSA or SLH-DSA). Nothing is written to disk.

## Examples

``` r
x <- c("W", "B", "W", "I")
map <- c(W = "White", B = "Black", I = "Indigenous")
y <- grdrcd(x, map)
m <- rcdmnf(x, y, map,
  pub = c(White = 2, Black = 1, Indigenous = 1),
  ctx = "example survey, race item"
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
k <- fipskg("ML-DSA-44", seed = as.raw(1:32))
ms <- rcdmnf(x, y, map, key = k)
names(ms)
#>  [1] "context"        "created"        "mapping"        "mapping_sha256"
#>  [5] "n"              "n_missing"      "counts_before"  "counts_after"  
#>  [9] "checks"         "published"      "body_sha256"    "signature"     
#> [13] "public_key"    

# a recode that does not match the published counts is refused
try(rcdmnf(x, y, map, pub = c(White = 1, Black = 2, Indigenous = 1)))
#> Error : vrfmrg: recoded counts do not match the published counts. White: observed 2, published 1; Black: observed 1, published 2; Indigenous: observed 1, published 1. The observed counts match the published ones if the labels are permuted (White -> Black, Black -> White): the labels are attached to the wrong groups.
```
