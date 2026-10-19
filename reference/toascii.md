# Transliterate Text to Plain ASCII

Converts a character vector to plain 7-bit ASCII, transliterating
accented or non-Latin characters to their nearest ASCII equivalent (for
example, an accented capital A becomes a plain "A"). Falls back to
dropping any character that has no transliteration. This is the
deterministic "fallback" used by
[`asciifb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/asciifb.md).
Use it for destinations that accept only ASCII – a package
`DESCRIPTION`, a file name, a legacy system – so a name written with an
accented letter arrives with the plain letter rather than as an encoding
error or a question mark.

## Usage

``` r
toascii(x)
```

## Arguments

- x:

  A character vector (other types are converted with
  [`as.character()`](https://rdrr.io/r/base/character.html)).

## Value

A character vector the length of `x`, containing only printable ASCII
characters (bytes 32 to 126); `NA` elements become `""`.

## Details

Bytes that are not valid UTF-8 at all (a mislabelled file) are dropped
first. Then, when the stringi package is installed, the ICU transform
`"Any-Latin; Latin-ASCII"` romanises any script and folds accents
(Cyrillic, Greek and Chinese become Latin letters). Without stringi, a
fixed table folds the common Latin accents and ligatures (sharp s to
"ss", the ae ligature to "ae", thorn to "th" and so on) and every other
non-ASCII character is dropped, so non-Latin scripts disappear rather
than being romanised. Either way the result is then stripped of anything
outside the printable ASCII range (space to tilde), so control
characters such as newlines and tabs are removed too. The result never
depends on the session's locale.

A missing value becomes `""`; non-character input is converted with
[`as.character()`](https://rdrr.io/r/base/character.html) first (so
numbers pass through as their digits).

## See also

[`asciifb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/asciifb.md)
to transliterate only when needed,
[`wrtxtfb()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrtxtfb.md)
to write text with an ASCII retry.

## Examples

``` r
# Latin accents fold to their nearest ASCII letter.
toascii("Prof. \u00c1ngela Zorro Medina")  # "Prof. Angela Zorro Medina"
#> [1] "Prof. Angela Zorro Medina"

# Vectorised over the input.
toascii(c("Se\u00e1n", "Zo\u00eb", "na\u00efve"))
#> [1] "Sean"  "Zoe"   "naive"

# Non-Latin scripts are romanised when stringi is available.
if (requireNamespace("stringi", quietly = TRUE))
  toascii("\u041c\u043e\u0441\u043a\u0432\u0430")  # "Moskva" (Cyrillic)
#> [1] "Moskva"

# Either way the result is guaranteed pure 7-bit ASCII (never "?").
all(charToRaw(toascii("caf\u00e9")) < 128)
#> [1] TRUE

# Missing values become empty strings; line breaks are removed.
toascii(c(NA, "two\nlines"))
#> [1] ""         "twolines"
```
