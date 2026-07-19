# Use Text As-Is, Falling Back to ASCII When It Cannot Be Represented

Returns `x` unchanged when it is valid, well-formed text (so legitimate
UTF-8 such as an accented name is preserved), and only transliterates to
plain ASCII via
[`to_ascii()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/to_ascii.md)
when the text is not valid UTF-8 (an encoding error) or when
`force = TRUE` (for ASCII-only destinations such as a package
`DESCRIPTION`). This lets author and supervisor names keep their accents
wherever UTF-8 is supported while degrading gracefully instead of
erroring where it is not.

## Usage

``` r
ascii_fallback(x, force = FALSE)
```

## Arguments

- x:

  A character vector.

- force:

  Logical; always transliterate to ASCII (default `FALSE`).

## Value

A character vector: `x` where it can be represented, ASCII otherwise.

## Examples

``` r
# By default valid UTF-8 is preserved (accents kept where supported).
ascii_fallback("\u00c1ngela")               # "\u00c1ngela"
#> [1] "Ángela"

# force = TRUE always transliterates (for ASCII-only destinations
# such as a package DESCRIPTION).
ascii_fallback("\u00c1ngela", force = TRUE)  # "Angela"
#> [1] "Angela"

# Plain ASCII is returned unchanged either way.
ascii_fallback("plain name")
#> [1] "plain name"

# Vectorised; each element handled independently.
ascii_fallback(c("caf\u00e9", "resume"), force = TRUE)
#> [1] "cafe"   "resume"
```
