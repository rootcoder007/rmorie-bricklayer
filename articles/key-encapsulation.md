# Key encapsulation: ML-KEM and HQC

A key-encapsulation mechanism (KEM) lets two parties agree on a shared
secret over a public channel: the sender *encapsulates* a fresh secret
under the recipient’s public key, producing a ciphertext; the recipient
*decapsulates* the ciphertext with the secret key and recovers the same
secret. The package implements **ML-KEM** (FIPS 203, lattice-based) and
**HQC** (code-based), natively.

## ML-KEM

``` r

key <- kem_keygen(768)
pub <- kem_public_key(key)

# the sender holds only the public key
sent <- kem_encapsulate(pub)
# the recipient recovers the same secret from the ciphertext
got <- kem_decapsulate(key, sent$ciphertext)
identical(sent$shared, got)
#> [1] TRUE
```

Three parameter sets trade size for security margin:

``` r

kem_sizes(512)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>               800              1632               768                64 
#>     shared_secret 
#>                32
kem_sizes(768)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>              1184              2400              1088                64 
#>     shared_secret 
#>                32
kem_sizes(1024)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>              1568              3168              1568                64 
#>     shared_secret 
#>                32
```

### Implicit rejection

ML-KEM is designed so that a corrupted ciphertext does **not** produce
an error. It produces a *different*, pseudorandom secret derived from
the secret key and the ciphertext. This is the Fujisaki–Okamoto
transform’s *implicit rejection*: an attacker who tampers with
ciphertexts learns nothing from the recipient’s behaviour, because the
recipient behaves identically either way.

``` r

bad <- sent$ciphertext
substring(bad, 1L, 2L) <- "00"
other <- kem_decapsulate(key, bad)
nchar(other) == 64L          # a 32-byte secret, as always
#> [1] TRUE
identical(other, got)        # but not the one the sender has
#> [1] FALSE
```

### Masked decapsulation (the default)

Decapsulation is the operation that uses the secret key, so it is the
one a power or electromagnetic side channel would target. Since 0.5.9 it
runs **first-order masked** by default: every value that depends on the
secret key is held as two random shares that are refreshed from the
operating system’s randomness on every call, and the re-encryption
comparison of the FO transform is done on shares (the decompressed
comparison of Bhasin et al., TCHES 2021). The result is byte-identical
to the plain computation:

``` r

identical(kem_decapsulate(key, sent$ciphertext, masked = FALSE), got)
#> [1] TRUE
identical(kem_decapsulate(key, bad, masked = FALSE), other)
#> [1] TRUE
```

`masked = FALSE` is about five times faster and is the right choice
where no physical attacker is in the threat model (a server in a locked
room). The *Side-channel assurance* vignette explains what the masking
defends against and how it was verified.

### Key validation

FIPS 203 §7.3 requires a decapsulation key to be checked before use: its
stored hash of the encapsulation key must match the key it contains. A
key that fails this check is refused rather than used. This check was
added after the Wycheproof vectors showed the earlier code accepted such
a key.

## HQC

HQC rests on the hardness of decoding random quasi-cyclic codes, an
assumption unrelated to lattices, which is why NIST selected it as the
second KEM. The interface is the same:

``` r

hkey <- hqc_keygen(1)
hpub <- hqc_public_key(hkey)

hsent <- hqc_encapsulate(hpub)
identical(hqc_decapsulate(hkey, hsent$ciphertext), hsent$shared)
#> [1] TRUE
hqc_sizes(1)
#> encapsulation_key decapsulation_key        ciphertext              seed 
#>              2241              2321              4433                32 
#>           message              salt     shared_secret 
#>                16                16                32
```

Two revisions are implemented: the 2025 specification (`version = "v5"`,
the default) and the round-4 submission (`version = "round4"`), which
differ in their shared-secret derivation. A key made under one does not
interoperate with the other, and the version is recorded in the key:

``` r

old <- hqc_keygen(1, version = "round4")
cap <- hqc_encapsulate(hqc_public_key(old))
identical(hqc_decapsulate(old, cap$ciphertext), cap$shared)
#> [1] TRUE
```

### Reproducible keys for tests

Both KEMs accept a 32-byte seed so a test can regenerate the same key.
Never use this outside tests: a key derived from a guessable seed is no
key at all.

``` r

identical(hqc_keygen(1, seed = as.raw(1:32))$public,
          hqc_keygen(1, seed = as.raw(1:32))$public)
#> [1] TRUE
```

## Using the shared secret

The shared secret is 32 bytes of hex. It is a *key*, not a password: use
it directly as the key of
[`core_hmac_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_keyed_digest.md)
or to derive further keys, never as text to be stored.

``` r

tag <- core_hmac_sha256(sent$shared, "the capsule manifest")
core_digest_equal(tag, core_hmac_sha256(got, "the capsule manifest"))
#> [1] TRUE
```

## How these implementations are checked

ML-KEM runs against the NIST ACVP and C2SP Wycheproof sets (key
generation, encapsulation, decapsulation and key validation), is
compared byte for byte with OpenSSL 3.5, and is differentially fuzzed
against it. Decapsulation’s timing is measured on real x86-64 and arm64
CPUs with dudect, its constant-time property is proved under valgrind,
and its masked arithmetic is assessed for first-order power leakage in a
Cortex-M4 simulation. See `SECURITY.md` in the repository.
