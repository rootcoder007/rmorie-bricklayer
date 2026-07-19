# Transliterate Text to Plain ASCII

Converts a character vector to plain 7-bit ASCII, transliterating
accented or non-Latin characters to their nearest ASCII equivalent (for
example, an accented capital A becomes a plain "A"). Falls back to
dropping any character that has no transliteration. This is the
deterministic "fallback" used by
[`ascii_fallback()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ascii_fallback.md).

## Usage

``` r
to_ascii(x)
```

## Arguments

- x:

  A character vector.

## Value

A character vector containing only ASCII characters.

## Examples

``` r
# Latin accents fold to their nearest ASCII letter.
to_ascii("Prof. \u00c1ngela Zorro Medina")  # "Prof. Angela Zorro Medina"
#> [1] "Prof. Angela Zorro Medina"

# Vectorised over the input.
to_ascii(c("Se\u00e1n", "Zo\u00eb", "na\u00efve"))
#> [1] "Sean"  "Zoe"   "naive"

# Non-Latin scripts are romanised when stringi is available.
if (requireNamespace("stringi", quietly = TRUE))
  to_ascii("\u041c\u043e\u0441\u043a\u0432\u0430")  # "Moskva" (Cyrillic)
#> [1] "Moskva"

# Either way the result is guaranteed pure 7-bit ASCII (never "?").
all(charToRaw(to_ascii("caf\u00e9")) < 128)
#> [1] TRUE
```
