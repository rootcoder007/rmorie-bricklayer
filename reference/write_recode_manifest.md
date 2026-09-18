# Write and verify a recode manifest

Write and verify a recode manifest

## Usage

``` r
write_recode_manifest(manifest, path)

verify_recode_manifest(path, original, recoded)
```

## Arguments

- manifest:

  A
  [`recode_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md).

- path:

  File to write (JSON).

- original, recoded:

  The vectors to check the manifest against.

## Value

`write_recode_manifest()` returns the path invisibly.

`verify_recode_manifest()` returns a list with `ok`, `reasons`
(character, empty when ok), `signature_ok` (`NA` when unsigned) and the
manifest.

## Examples

``` r
x <- c("W", "B", "W")
y <- guard_recode(x, c(W = "White", B = "Black"))
m <- recode_manifest(x, y, c(W = "White", B = "Black"))
p <- write_recode_manifest(m, tempfile(fileext = ".json"))
verify_recode_manifest(p, x, y)$ok
#> [1] TRUE
```
