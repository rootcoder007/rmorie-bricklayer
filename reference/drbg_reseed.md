# Reseed a DRBG

Mixes fresh entropy into the generator (SP 800-90A's Reseed function)
and resets its request count.

## Usage

``` r
drbg_reseed(drbg, entropy = NULL, additional = NULL)
```

## Arguments

- drbg:

  A generator from
  [`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md).

- entropy:

  Entropy input: 48 bytes, raw or hex; `NULL` draws them from the
  operating system's CSPRNG.

- additional:

  Optional additional input of up to 48 bytes, raw or hex.

## Value

`drbg`, invisibly, reseeded in place.

## See also

[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md),
[`drbg_generate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_generate.md).

## Examples

``` r
d <- drbg_new(as.raw(0:47))
drbg_reseed(d, as.raw(48:95))
drbg_generate(d, 8)
#> [1] 7b 58 11 e6 34 ba 47 e2
```
