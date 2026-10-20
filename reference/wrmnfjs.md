# Write a Manifest to JSON

Writes a manifest to a JSON file, so the record of a run (its metadata,
cross-checks and environment) can be kept next to the outputs, shared,
and read back by any JSON reader. By default the file is pretty-printed
for people; `canonical = TRUE` writes the byte-stable form that
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
hashes. The package's own JSON codec
([`tojs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tojs.md))
is used; jsonlite is not needed.

## Usage

``` r
wrmnfjs(man, path, canon = FALSE)
```

## Arguments

- man:

  A manifest as returned by
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)
  and built up with
  [`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md).

- path:

  Character scalar, the destination file path.

- canon:

  Logical scalar, default `FALSE`. `TRUE` writes the canonical form
  instead of the pretty-printed one: one line, keys sorted, which is
  what
  [`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
  hashes. Use it when the file itself has to be byte-stable rather than
  read by a person.

## Value

`path` (character scalar), invisibly.

## Details

Numbers are written with 17 significant digits, so every double reads
back exactly; `NA` and `NULL` are written as `null`, and length-one
vectors as scalars. When the manifest's `meta$synthetic` is `TRUE`, or
the session is flagged synthetic (see
[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)),
`meta$synthetic = true` is written whatever the list says, so a file
written from generated data always says so. An existing file at `path`
is overwritten; the folder must exist.

Errors when `path` is not a single non-empty string, and (from base R)
when the file cannot be opened for writing.

## See also

[`mnfcanon()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md),
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md).

## Examples

``` r
man <- mkmnf(list(project = "demo"), env = FALSE)
man <- recrd(man, "rowcount", obs = 20, expd = 20)
#>   rowcount                                     observed = 20.0000      expected = 20.0000      [INFO]
path <- wrmnfjs(man, tempfile(fileext = ".json"))
file.exists(path)
#> [1] TRUE

# Round-trips back through the package's own codec.
back <- fromjs(path, simplifyVector = FALSE)
back$results$rowcount$status # "PASS" ("INFO" after synthetic data, see mkmnf())
#> [1] "INFO"

# the canonical form: one line whose SHA-256 is the manifest digest
cpath <- wrmnfjs(man, tempfile(fileext = ".json"), canon = TRUE)
identical(readLines(cpath), as.character(mnfcanon(man)))
#> [1] TRUE

# the path must be one string
try(wrmnfjs(man, c("a.json", "b.json")))
#> Error : wrmnfjs: `path` must be a single non-empty string
```
