# Use Text As-Is, Falling Back to ASCII When It Cannot Be Represented

Returns `x` unchanged when it is valid, well-formed text (so legitimate
UTF-8 such as an accented name is preserved), and only transliterates to
plain ASCII via
[`toascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/toascii.md)
when the text is not valid UTF-8 (an encoding error) or when
`force = TRUE` (for ASCII-only destinations such as a package
`DESCRIPTION`) . This lets author and supervisor names keep their
accents wherever UTF-8 is supported while degrading gracefully instead
of erroring where it is not.

## Usage

``` r
asciifb(x, force = FALSE)
```

## Arguments

- x:

  A character vector (other types are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html)).

- force:

  A single logical: `TRUE` always transliterates every element to ASCII;
  `FALSE` (the default) only the elements that are not valid UTF-8.
  Anything other than `TRUE` counts as `FALSE`.

## Value

A character vector the length of `x`: each element unchanged when it is
valid UTF-8 (and `force` is not `TRUE`), otherwise its ASCII
transliteration.

## Details

Each element is tested on its bytes with
[`validUTF8()`](https://rdrr.io/r/base/validUTF8.html), so the outcome
does not depend on the session locale. Valid elements (including plain
ASCII and properly encoded accented text) are returned unchanged;
invalid ones go through
[`toascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/toascii.md),
which drops the bytes that are not UTF-8 and transliterates the rest.
With `force = TRUE` every element goes through
[`toascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/toascii.md).
A missing value is kept as `NA` unless `force = TRUE`, when it becomes
`""`.

## See also

[`toascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/toascii.md),
which does the transliteration.

## Examples

``` r
# By default valid UTF-8 is preserved (accents kept where supported).
asciifb("\u00c1ngela")               # "\u00c1ngela"
#> [1] "Ángela"

# force = TRUE always transliterates (for ASCII-only destinations
# such as a package DESCRIPTION).
asciifb("\u00c1ngela", force = TRUE)  # "Angela"
#> [1] "Angela"

# Plain ASCII is returned unchanged either way.
asciifb("plain name")
#> [1] "plain name"

# Vectorised; each element handled independently.
asciifb(c("caf\u00e9", "resume"), force = TRUE)
#> [1] "cafe"   "resume"

# Bytes that are not UTF-8 (a Latin-1 file read as UTF-8) are repaired.
bad <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
validUTF8(bad)
#> [1] FALSE
asciifb(bad)
#> [1] "caf"
```
