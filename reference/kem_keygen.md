# Generate an ML-KEM key pair

Generates a key for ML-KEM (FIPS 203), the standardised post-quantum key
encapsulation mechanism. It is implemented in this package, with no
system dependency.

## Usage

``` r
kem_keygen(level = 768L, seed = NULL)

kem_public_key(key)
```

## Arguments

- level:

  Security level: 512, 768 (the default) or 1024. 768 is the level NIST
  and the IETF have settled on for general use.

- seed:

  Optional raw vector of 64 seed bytes ( `d || z`) . Supplying it makes
  the key reproducible, which is what the standard's test vectors need;
  the default draws from the operating system's CSPRNG.

- key:

  A key from `kem_keygen()`.

## Value

A list of class `bricklayer_kem_key`: `public`, `secret` (both hex), and
`level`.

## Details

A KEM is not a signature scheme and not a cipher. Encapsulation produces
two things: a ciphertext to send, and a 32-byte shared secret to keep.
The holder of the decapsulation key recovers the same secret from the
ciphertext. What either side then does with that secret – feed it to a
KDF, key an AEAD – is outside the mechanism.

## Security

A hand-written implementation. The standardised schemes are checked byte
for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
operation that touches a secret under valgrind memcheck with the secret
marked undefined (the ctgrind method), so a branch or a memory address
that depends on it is a reported error, and afterwards scans the dead
stack for copies of the secret. Both checks run in CI on every change,
with GCC and with Clang. Timing is also measured on x86-64 and arm64
hardware (`inst/dudect`), power leakage is assessed in simulation under
the value and the transition models (`inst/tvla`), and ML-KEM
decapsulation and ML-DSA signing are first-order masked by default.
These are checks of this code on those compilers and under those leakage
models; no third-party security audit has been commissioned, and the
README's security section lists what each check does and does not cover.

## References

National Institute of Standards and Technology (2024).
Module-Lattice-Based Key-Encapsulation Mechanism Standard. FIPS 203.
[doi:10.6028/NIST.FIPS.203](https://doi.org/10.6028/NIST.FIPS.203)

## See also

[`kem_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_encapsulate.md),
[`kem_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_decapsulate.md),
[`kem_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_sizes.md),
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
for the signature schemes.

## Examples

``` r
key <- kem_keygen(768)
pub <- kem_public_key(key)

# the sender holds only the public key
sent <- kem_encapsulate(pub)
# the recipient recovers the same secret from the ciphertext
got <- kem_decapsulate(key, sent$ciphertext)
identical(sent$shared, got)
#> [1] TRUE

# a corrupted ciphertext yields a DIFFERENT secret, not an error
bad <- sent$ciphertext
substring(bad, 1L, 2L) <- "00"
identical(kem_decapsulate(key, bad), got)
#> [1] FALSE
```
