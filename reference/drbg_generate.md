# Draw bytes from a DRBG

Generates `n` bytes (SP 800-90A's Generate function) and advances the
generator.

## Usage

``` r
drbg_generate(drbg, n, additional = NULL)
```

## Arguments

- drbg:

  A generator from
  [`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md).

- n:

  Number of bytes, 1 to 65536 (the standard's limit per request for AES:
  2^19 bits).

- additional:

  Optional additional input of up to 48 bytes, raw or hex, mixed into
  the state before and after the output.

## Value

A raw vector of `n` bytes.

## See also

[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md),
[`drbg_reseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_reseed.md).

## Examples

``` r
d <- drbg_new(as.raw(0:47))
x <- drbg_generate(d, 16)
y <- drbg_generate(d, 16)
identical(x, y)  # the state moved on
#> [1] FALSE

# additional input changes the output and the state
e <- drbg_new(as.raw(0:47))
identical(drbg_generate(e, 16, additional = "00ff"), x)
#> [1] FALSE
```
