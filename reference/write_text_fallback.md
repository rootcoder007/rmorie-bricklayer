# Write Text as UTF-8, Falling Back to ASCII on an Encoding Error

Writes `text` to `path` as UTF-8, one element per line. If the write
fails (for example a destination or locale that cannot represent the
characters), it retries with an ASCII transliteration produced by
[`to_ascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/to_ascii.md),
so capsule generation never fails on a non-ASCII name. Use it to write
generated text files (README, citation, script) whose content may
include names with accents.

## Usage

``` r
write_text_fallback(text, path)
```

## Arguments

- text:

  A character vector of lines to write (other types are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html)).

- path:

  The destination file, a single non-empty string. Its directory must
  exist.

## Value

Invisibly, `path`.

## Details

The lines are joined with `"\n"`, a final newline is added, and the
UTF-8 bytes are written through a binary connection, so the bytes on
disk are UTF-8 whatever the session locale (a text connection would
re-encode from the native locale) and line endings are `"\n"` on every
platform. An existing file is overwritten. A missing element is written
as the two letters `NA`, and an empty `text` writes a file holding a
single newline.

The ASCII retry is taken on any error from the first write, not only on
an encoding error; if the retry also fails (a directory that does not
exist, a read-only location), that error reaches the caller. A `path`
that is not a single non-empty string is refused before anything is
written (`"path must be a single non-empty string"`).

## See also

[`to_ascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/to_ascii.md)
for the retry's transliteration.

## Examples

``` r
p <- write_text_fallback(c("line one", "line two"),
                         tempfile(fileext = ".txt"))
readLines(p)
#> [1] "line one" "line two"

# Accented names are written as UTF-8 bytes, whatever the locale.
q <- write_text_fallback("Author: \u00c1ngela Zorro Medina", tempfile())
readLines(q, encoding = "UTF-8")
#> [1] "Author: Ángela Zorro Medina"
readBin(q, "raw", 20)
#>  [1] 41 75 74 68 6f 72 3a 20 c3 81 6e 67 65 6c 61 20 5a 6f 72 72

# The path must be one string.
try(write_text_fallback("x", c("a.txt", "b.txt")))
#> Error : `path` must be a single non-empty string
```
