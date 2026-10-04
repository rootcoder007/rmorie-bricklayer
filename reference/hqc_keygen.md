# Generate an HQC key pair

Generates a key for HQC (Hamming Quasi-Cyclic), the code-based key
encapsulation mechanism NIST selected for standardisation in March 2025
(NIST IR 8545) as a second KEM next to ML-KEM. It is implemented in this
package, with no system dependency.

## Usage

``` r
hqc_keygen(level = 3L, seed = NULL)

hqc_public_key(key)
```

## Arguments

- level:

  Security level, as a NIST category: 1, 3 (the default) or 5 (HQC-1,
  HQC-3, HQC-5; 128, 192 and 256 are accepted for the same three). Level
  3 matches the category of ML-KEM-768,
  [`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)'s
  default.

- seed:

  Optional raw vector of 32 bytes (`seed_KEM`). Supplying it makes the
  key reproducible, which is what the known-answer tests need; the
  default draws from the operating system's CSPRNG.

- key:

  A key from `hqc_keygen()`.

## Value

A list of class `bricklayer_hqc_key`: `public`, `secret` (both hex) and
`level`. The secret key is the specification's
`ek || seed_dk || sigma || seed_KEM`.

## Details

The implementation follows the HQC specification of 2025-08-22 and is
byte for byte the scheme of the authors' reference implementation
v5.0.0: all 300 official known-answer vectors are reproduced (the
package's tests check them). It runs in constant time with respect to
secrets – no secret reaches a branch, a memory index or a variable
shift, checked with valgrind – wipes its secret intermediates, and gives
the same bytes on little- and big-endian machines. On x86-64 processors
with PCLMULQDQ and on ARMv8 with the crypto extension the polynomial
products use the carry-less multiply instruction; elsewhere a portable
constant-time product.

NIST's FIPS 207 (HQC-KEM) is still a draft. It is expected to shorten
the decapsulation key to its 32-byte seed; the encapsulation key,
ciphertext and shared secret of the final standard may differ from
these, so keep keys and ciphertexts tagged with the scheme and level
they belong to.

## References

Gaborit, P., Aguilar-Melchor, C., Aragon, N., Bettaieb, S., Bidoux, L.,
Blazy, O., Deneuville, J.-C., Persichetti, E., Zemor, G., et al. (2025).
Hamming Quasi-Cyclic (HQC), specification of 2025-08-22; reference
implementation v5.0.0. <https://pqc-hqc.org/>

Alagic, G. et al. (2025). Status Report on the Fourth Round of the NIST
Post-Quantum Cryptography Standardization Process. NIST IR 8545.
[doi:10.6028/NIST.IR.8545](https://doi.org/10.6028/NIST.IR.8545)

## See also

[`hqc_encapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_encapsulate.md),
[`hqc_decapsulate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_decapsulate.md),
[`hqc_sizes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqc_sizes.md),
[`kem_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kem_keygen.md)
for ML-KEM.

## Examples

``` r
key <- hqc_keygen(1)
pub <- hqc_public_key(key)

# the sender holds only the public key
sent <- hqc_encapsulate(pub)
# the recipient recovers the same secret from the ciphertext
got <- hqc_decapsulate(key, sent$ciphertext)
identical(sent$shared, got)
#> [1] TRUE

# a corrupted ciphertext yields a DIFFERENT secret, not an error
bad <- sent$ciphertext
substring(bad, 1L, 2L) <- if (substring(bad, 1L, 2L) == "00") "01" else "00"
identical(hqc_decapsulate(key, bad), got)
#> [1] FALSE

# a reproducible key from a fixed seed
identical(hqc_keygen(1, seed = as.raw(1:32))$public,
          hqc_keygen(1, seed = as.raw(1:32))$public)
#> [1] TRUE
```
