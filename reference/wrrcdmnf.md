# Write and verify a recode manifest

`wrrcdmnf()` saves a manifest from
[`rcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md)
as a JSON file. `vrfrcdmnf()` reads such a file back and checks it
against the data: that the mapping and the manifest body are unchanged
since they were written, that the recode in the data still matches the
recorded mapping, that the recoded counts are the recorded counts, and,
for a signed manifest, that the signature verifies. Use the pair to hand
a recode to a reviewer or to re-check it before a later analysis.

## Usage

``` r
wrrcdmnf(man, path)

vrfrcdmnf(path, orig, recd)
```

## Arguments

- man:

  A manifest returned by
  [`rcdmnf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rcdmnf.md).

- path:

  Character string: the JSON file to write (`wrrcdmnf()`) or read
  (`vrfrcdmnf()`).

- orig, recd:

  The vectors before and after the recode, to check the manifest
  against.

## Value

`wrrcdmnf()` returns `path` invisibly.

`vrfrcdmnf()` returns a list with `ok` (logical), `reasons` (character;
empty, `character(0)`, when `ok`), `signature_ok` (logical, `NA` when
the manifest is unsigned) and `manifest` (the parsed JSON as a list).

## Details

`vrfrcdmnf()` collects every failure in `reasons` instead of stopping at
the first:

- the SHA-256 of the stored mapping differs from `mapping_sha256`;

- the SHA-256 of the body (all fields except `body_sha256`, `signature`
  and `public_key`) differs from `body_sha256`, meaning the file was
  edited after it was written;

- [`vrfrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfrcd.md)`(original, recoded, mapping)`
  fails;

- the counts of `recoded` differ from `counts_after`.

The signature, when present, is checked with
[`cpsvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
over the stored `body_sha256`. It therefore proves who wrote that hash;
the body check above proves the body still matches it. Both are needed
for `ok = TRUE`.

`wrrcdmnf()` errors when `man` is not a `bricklayer_recode_manifest`; it
overwrites `path`.

## Examples

``` r
x <- c("W", "B", "W")
y <- grdrcd(x, c(W = "White", B = "Black"))
m <- rcdmnf(x, y, c(W = "White", B = "Black"))
p <- wrrcdmnf(m, tempfile(fileext = ".json"))
vrfrcdmnf(p, x, y)$ok
#> [1] TRUE

# the data changed after the manifest was written
y2 <- y
y2[2] <- "White"
vrfrcdmnf(p, x, y2)$reasons
#> [1] "vrfrcd: ‘B’ was mapped to ‘White’ but the declared mapping says ‘Black’. THIS is how groups get swapped; fix the recode before any model runs."
#> [2] "recoded counts differ from the manifest"                                                                                                       

# only manifests can be written
try(wrrcdmnf(list(a = 1), tempfile()))
#> Error : wrrcdmnf: `man` must come from rcdmnf()
```
