# Reseed a DRBG

Mixes fresh entropy into the generator (SP 800-90A's Reseed function)
and resets its request count. Use it after many requests (the standard
requires a reseed after \\2^{48}\\), to add prediction resistance before
a sensitive draw, or to replay a known-answer test that reseeds with
given entropy.

## Usage

``` r
drbg_reseed(drbg, entropy = NULL, additional = NULL)
```

## Arguments

- drbg:

  A generator from
  [`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md).

- entropy:

  Entropy input: exactly 48 bytes, raw or hex; `NULL` (the default)
  draws them from the operating system's CSPRNG.

- additional:

  Optional additional input of up to 48 bytes, raw or hex; default
  `NULL` (none).

## Value

`drbg`, invisibly, reseeded in place.

## Details

The new (Key, V) is derived from the old state, the 48 entropy bytes and
the additional input, so the stream after the reseed depends on
everything that went before. The request count is reset to 1 and the
generator is marked as belonging to the current process. Errors: `drbg`
not made by
[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md);
`entropy` not exactly 48 bytes; `additional` longer than 48 bytes;
either not raw or hex.

## See also

[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md),
[`drbg_generate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_generate.md).

## Examples

``` r
d <- drbg_new(as.raw(0:47))
drbg_reseed(d, as.raw(48:95))
drbg_generate(d, 8)
#> [1] 7b 58 11 e6 34 ba 47 e2

# a reseed with given entropy is reproducible
d2 <- drbg_new(as.raw(0:47))
drbg_reseed(d2, as.raw(48:95))
identical(drbg_generate(d2, 8),
          drbg_generate(drbg_reseed(drbg_new(as.raw(0:47)), as.raw(48:95)), 8))
#> [1] TRUE

# fresh entropy from the operating system, with additional input
drbg_reseed(d, additional = charToRaw("before key generation"))

# the entropy must be exactly 48 bytes
try(drbg_reseed(d, as.raw(1:10)))
#> Error : `entropy` must be exactly 48 bytes, raw or hex
```
