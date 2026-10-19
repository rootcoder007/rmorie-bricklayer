# Reseed a DRBG

Mixes fresh entropy into the generator (SP 800-90A's Reseed function)
and resets its request count. Use it after many requests (the standard
requires a reseed after \\2^{48}\\), to add prediction resistance before
a sensitive draw, or to replay a known-answer test that reseeds with
given entropy.

## Usage

``` r
drbgrsd(drbg, entropy = NULL, addl = NULL)
```

## Arguments

- drbg:

  A generator from
  [`drbgnew()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgnew.md).

- entropy:

  Entropy input: exactly 48 bytes, raw or hex; `NULL` (the default)
  draws them from the operating system's CSPRNG.

- addl:

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
[`drbgnew()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgnew.md);
`entropy` not exactly 48 bytes; `addl` longer than 48 bytes; either not
raw or hex.

## See also

[`drbgnew()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbgnew.md),
[`drbggen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbggen.md).

## Examples

``` r
d <- drbgnew(as.raw(0:47))
drbgrsd(d, as.raw(48:95))
drbggen(d, 8)
#> [1] 7b 58 11 e6 34 ba 47 e2

# a reseed with given entropy is reproducible
d2 <- drbgnew(as.raw(0:47))
drbgrsd(d2, as.raw(48:95))
identical(drbggen(d2, 8),
          drbggen(drbgrsd(drbgnew(as.raw(0:47)), as.raw(48:95)), 8))
#> [1] TRUE

# fresh entropy from the operating system, with additional input
drbgrsd(d, addl = charToRaw("before key generation"))

# the entropy must be exactly 48 bytes
try(drbgrsd(d, as.raw(1:10)))
#> Error : `entropy` must be exactly 48 bytes, raw or hex
```
