# Draw bytes from a DRBG

Generates `n` bytes (SP 800-90A's Generate function) and advances the
generator. Use it to draw reproducible random bytes from a generator
made by
[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md):
the same seed and the same sequence of calls give the same bytes on
every platform, which is what known-answer tests and reproducible key
generation need.

## Usage

``` r
drbg_generate(drbg, n, additional = NULL)
```

## Arguments

- drbg:

  A generator from
  [`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md).

- n:

  Integer scalar, the number of bytes, 1 to 65536 (the standard's limit
  per request for AES: 2^19 bits).

- additional:

  Optional additional input of up to 48 bytes, raw or hex, mixed into
  the state before and after the output. Default `NULL` (none).

## Value

A raw vector of `n` bytes.

## Details

Each call encrypts the counter V under Key with AES-256 to produce the
output, then updates (Key, V) with the additional input, so the next
call gives different bytes and earlier outputs cannot be recovered from
the new state. The generator is changed in place. When the generator was
created or last reseeded in another process (a fork, or a copy restored
from a file), it first reseeds itself from the operating system. After
\\2^{48}\\ requests since seeding the standard requires a reseed, and
the call errors until
[`drbg_reseed()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_reseed.md)
is called.

Errors: `drbg` not made by
[`drbg_new()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drbg_new.md);
`n` not a single whole number from 1 to 65536; `additional` longer than
48 bytes or neither raw nor hex.

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

# random integers in 1..6 from the bytes (rejection keeps them uniform)
r <- as.integer(drbg_generate(drbg_new(as.raw(0:47)), 64))
head(r[r < 252] %% 6 + 1, 10)
#>  [1] 1 4 3 6 6 4 3 5 4 2

# one request is at most 65536 bytes
try(drbg_generate(d, 70000))
#> Error : `n` must be a single integer between 1 and 65536
```
