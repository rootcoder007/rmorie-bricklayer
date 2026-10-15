# Recover a shared secret from an ML-KEM ciphertext

Returns the 32-byte shared secret that a ciphertext from
[`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md)
carries, as hex. This is the recipient's side of the exchange: with the
secret half of the key pair, the recipient recovers the same secret the
sender kept, and the two can then use it as a common key.

## Usage

``` r
kem_decapsulate(
  key,
  ciphertext,
  masked = getOption("rmoriebricklayer.masked", TRUE)
)
```

## Arguments

- key:

  A key from
  [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md),
  with its secret half.

- ciphertext:

  The `ciphertext` element from
  [`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md),
  as a hex string or a raw vector, of the length for the key's level.

- masked:

  Logical, `TRUE` or `FALSE`. `TRUE` (the default, taken from the option
  `rmoriebricklayer.masked` when set) runs the first-order masked
  decapsulation, `FALSE` the plain one. Both return the same secret.

## Value

A length-1 character vector of 64 lower-case hex characters: the 32-byte
shared secret.

## Details

This is ML-KEM.Decaps of FIPS 203 (Algorithm 21). For a ciphertext of
the right length there is no failure path, and that is deliberate. A
ciphertext that was not produced by a correct encapsulation under this
key yields a shared secret derived from a value held only inside the
decapsulation key – so it is a real secret, just not the sender's.
Whoever sent it learns nothing about whether it was accepted, which is
what closes off a chosen-ciphertext attack. The consequence for a
caller: a mismatch between the two sides' secrets is the signal that
something was wrong, not an error from this function.

Masked by default. With `masked = TRUE` every value that depends on the
secret key is held as two random shares from the moment the key is read
(first-order masking): decryption, the decoding of the message, the
hashing, the re-encryption with its noise sampling, the comparison with
the ciphertext and the choice between the real and the rejection secret.
No single intermediate value then depends on the key, which is what
defeats first-order power and electromagnetic analysis; `inst/tvla`
checks the masked gadgets against that leakage model. The result is
identical to the unmasked computation for every ciphertext; it costs
about 2.3 to 3.4 times the plain time depending on the CPU (4 ms for
ML-KEM-768 on this package's test machine against 1.2 ms plain).
`masked = FALSE` runs the plain constant-time decapsulation, and the
option `rmoriebricklayer.masked` sets the default for a session.

Errors (checked before any decapsulation): `key` not from
[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md),
or a public key only ("decapsulation needs a key with its secret half");
a ciphertext that is not hex or raw of exactly
[`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md)`[["ciphertext"]]`
bytes for the key's level (768, 1088 or 1568); `masked` not `TRUE` or
`FALSE`.

## See also

[`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md).

## Examples

``` r
key <- kem_keygen(512)
sent <- kem_encapsulate(kem_public_key(key))
identical(kem_decapsulate(key, sent$ciphertext), sent$shared)
#> [1] TRUE

# a tampered ciphertext returns a secret, and it is the wrong one
bad <- sent$ciphertext
substring(bad, 3L, 4L) <- "ff"
other <- kem_decapsulate(key, bad)
nchar(other) == 64L
#> [1] TRUE
identical(other, sent$shared)
#> [1] FALSE

# the masked and the plain decapsulation agree
identical(kem_decapsulate(key, bad, masked = FALSE), other)
#> [1] TRUE

# a public key alone cannot decapsulate, and a short ciphertext is refused
try(kem_decapsulate(kem_public_key(key), sent$ciphertext))
#> Error : decapsulation needs a key with its secret half
try(kem_decapsulate(key, "abcd"))
#> Error : `ciphertext` must be 768 bytes for ML-KEM-512
```
