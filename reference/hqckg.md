# Generate an HQC key pair

Generates a key for HQC (Hamming Quasi-Cyclic), the code-based key
encapsulation mechanism NIST selected for standardisation in March 2025
(NIST IR 8545) as a second KEM next to ML-KEM. It is implemented in this
package, with no system dependency. A key encapsulation mechanism (KEM)
lets two parties agree on a secret key: the recipient publishes the
public half of this key pair, a sender uses it with
[`hqcencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcencap.md)
to make a ciphertext and a shared secret, and only the holder of the
secret half can recover that secret from the ciphertext with
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md).
The shared secret is then used as the key of a symmetric cipher.
`hqcpubkey()` strips the secret half so the public key can be handed
out.

## Usage

``` r
hqckg(lvl = 3L, seed = NULL, ver = c("v5", "round4"))

hqcpubkey(key)
```

## Arguments

- lvl:

  Security level, as a NIST category: 1, 3 (the default) or 5 (HQC-1,
  HQC-3, HQC-5; 128, 192 and 256 are accepted for the same three). Level
  3 matches the category of ML-KEM-768,
  [`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)'s
  default.

- seed:

  Optional raw vector. For v5 it is the 32 bytes of `seed_KEM`. For
  round 4 it is the
  [`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)`["seed"]`
  bytes its key generation draws (`skseed`, `sigma`, `pk_seed`: 96, 104
  or 112). Supplying it makes the key reproducible, which is what the
  known-answer tests need; the default draws from the operating system's
  CSPRNG.

- ver:

  `"v5"` (the default: the specification of 2025-08-22, a 32-byte shared
  secret) or `"round4"` (the submission of 2023-04-30, a 64-byte shared
  secret). Keys remember it; encapsulation and decapsulation follow the
  key.

- key:

  A key from `hqckg()` (`hqcpubkey()` only).

## Value

`hqckg()` returns a list of class `bricklayer_hqc_key` with `public` and
`secret` (character, lowercase hex of the encapsulation and
decapsulation keys; see
[`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md)
for their byte lengths), `level` (integer 1, 3 or 5) and `version`
(`"v5"` or `"round4"`). Its print method shows the level and the start
of the public key and withholds the secret. `hqcpubkey()` returns a list
of class `bricklayer_hqc_public_key` with `public`, `level` and
`version` only. The v5 secret key is the specification's
`ek || seed_dk || sigma || seed_KEM`; the round-4 one is
`skseed || sigma || ek`.

## Details

The implementation follows the HQC specification of 2025-08-22 and is
byte for byte the scheme of the authors' reference implementation
v5.0.0: all 300 official known-answer vectors are reproduced (the
package's tests check them). It runs in constant time with respect to
secrets – no secret reaches a branch, a memory index or a variable
shift, checked under valgrind memcheck in CI (`inst/ctcheck`: the
`hqc1`, `hqc3`, `hqc5` and `hqc1-round4` cases) – wipes its secret
intermediates (the same harness scans the dead stack for them), and
gives the same bytes on little- and big-endian machines. On x86-64
processors with PCLMULQDQ and on ARMv8 with the crypto extension the
polynomial products use the carry-less multiply instruction; elsewhere a
portable constant-time product.

NIST will publish HQC-KEM as FIPS 207 but has not yet released it, or a
draft of it (checked 2026-10-05). The specification of 2025-08-22
followed here already makes the changes NIST listed for FIPS 207 (the
salted FO transform, SHA3-512 seed expansion, the 32-byte shared secret,
the new sampler, the seed in the decapsulation key, the seed-only
compressed key that
[`hqccmpkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqccmpkey.md)
writes); the published standard may still differ in detail. Keep keys
and ciphertexts tagged with the scheme, version and level they belong
to.

`version = "round4"` gives the earlier revision instead: the
fourth-round submission of 2023-04-30 (HQC-128/192/256), the HQC of
liboqs up to 0.12 and of PQClean, with a 64-byte shared secret. It uses
the same codes and parameters under a different key encapsulation
(40-byte seeds, SHAKE256 with domain bytes in place of SHA3, another
sampler), so its keys and ciphertexts are not interchangeable with v5's.
It reproduces that revision's 300 official known-answer vectors (the
package's tests check them); use it to exchange keys with software built
on it, and v5 otherwise.

Errors: a `lvl` other than 1, 3, 5, 128, 192 or 256 (a typo is never
mapped to a default, because the level is not recorded in the
ciphertext); a `seed` that is not a raw vector of exactly
`hqcsz(level, version)[["seed"]]` bytes; a `ver` other than `"v5"` or
`"round4"`. `hqcpubkey()` errors on anything that is not a
`bricklayer_hqc_key`. Key generation takes a few tens of milliseconds
even at level 5.

## Security

The implementation is hand-written. Its standardised schemes are checked
byte for byte against OpenSSL 3.5 and NIST known-answer vectors in the
test suite. Side channels are checked, not assumed: `inst/ctcheck` runs
every operation that touches a secret under valgrind memcheck with the
secret marked undefined (the ctgrind method), so a branch or a memory
address that depends on it is a reported error, and afterwards scans the
dead stack for copies of the secret. Both checks run in CI on every
change, with GCC and with Clang. Timing is also measured on x86-64 and
arm64 hardware (`inst/dudect`) and power leakage is assessed in
simulation under the value and the transition models (`inst/tvla`) for
the masked ML-KEM and ML-DSA kernels; this scheme is not masked. These
are checks of this code on those compilers; the README's security
section lists what each check does and does not cover.

## References

Gaborit, P., Aguilar-Melchor, C., Aragon, N., Bettaieb, S., Bidoux, L.,
Blazy, O., Deneuville, J.-C., Persichetti, E., Zemor, G., et al. (2025).
Hamming Quasi-Cyclic (HQC), specification of 2025-08-22; reference
implementation v5.0.0. https://pqc-hqc.org/

Alagic, G. et al. (2025). Status Report on the Fourth Round of the NIST
Post-Quantum Cryptography Standardization Process. NIST IR 8545.
[doi:10.6028/NIST.IR.8545](https://doi.org/10.6028/NIST.IR.8545)

## See also

[`hqcencap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcencap.md),
[`hqcdecap()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcdecap.md),
[`hqcsz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hqcsz.md),
[`kemkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/kemkg.md)
for ML-KEM.

## Examples

``` r
key <- hqckg(1)
pub <- hqcpubkey(key)

# the sender holds only the public key
sent <- hqcencap(pub)
# the recipient recovers the same secret from the ciphertext
got <- hqcdecap(key, sent$ciphertext)
identical(sent$shared, got)
#> [1] TRUE

# a corrupted ciphertext yields a DIFFERENT secret, not an error
bad <- sent$ciphertext
substring(bad, 1L, 2L) <- if (substring(bad, 1L, 2L) == "00") "01" else "00"
identical(hqcdecap(key, bad), got)
#> [1] FALSE

# a reproducible key from a fixed seed
identical(hqckg(1, seed = as.raw(1:32))$public,
          hqckg(1, seed = as.raw(1:32))$public)
#> [1] TRUE

# the round-4 revision: the same exchange, a 64-byte shared secret
old <- hqckg(1, ver = "round4")
cap <- hqcencap(hqcpubkey(old))
nchar(cap$shared) / 2
#> [1] 64
identical(hqcdecap(old, cap$ciphertext), cap$shared)
#> [1] TRUE
```
