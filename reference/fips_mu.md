# Sign an ML-DSA message digest computed elsewhere

The external-mu interface. `fips_mu()` reduces a message to the 64-byte
value mu that is the only thing ML-DSA signing actually consumes;
`fips_sign_mu()` signs that value and `fips_verify_mu()` checks it.

## Usage

``` r
fips_mu(key, message, context = NULL, prehash = "none")

fips_sign_mu(
  key,
  mu,
  deterministic = FALSE,
  masked = getOption("rmoriebricklayer.masked", TRUE)
)

fips_verify_mu(key, mu, signature)
```

## Arguments

- key:

  A key from
  [`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md)
  or
  [`fips_key()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_key.md).
  An ML-DSA scheme: SLH-DSA has no external-mu interface, because its
  digest depends on per-signature randomness that the signer chooses.

- message:

  Length-1 character vector or raw vector.

- context:

  Optional context string, as in
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- prehash:

  Pre-hash function, as in
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- mu:

  The 64 raw bytes from `fips_mu()`.

- deterministic:

  As in
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

- masked:

  `TRUE` (the default) for the first-order masked ML-DSA signer, `FALSE`
  for the plain constant-time one; both give the same signature for the
  same randomness. The option `rmoriebricklayer.masked` sets the default
  for a session, so chain- and bundle-heavy code that has no physical
  attacker in its threat model can take the plain path everywhere with
  `options(rmoriebricklayer.masked = FALSE)`. SLH-DSA and XMSS signing
  are not masked and ignore it. Masking costs about 3 to 12 times the
  plain time on ML-KEM decapsulation (4 ms for ML-KEM-768 on this
  package's test machine) and 13 to 24 times on ML-DSA signing (26 ms
  for ML-DSA-65), depending on the CPU.

- signature:

  A signature from `fips_sign_mu()` or
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md).

## Value

`fips_mu()` returns 64 raw bytes; `fips_sign_mu()` a
`bricklayer_signature`; `fips_verify_mu()` a length-1 logical.

## Details

The point is that the message need never reach the key. A large file can
be reduced to mu on the machine that holds it and only mu handed to
whatever holds the signing key – a smartcard, a remote signer, another
process. mu is not a bare digest: it binds the public key (through
`tr = H(pk)`) and the context string, so a mu computed under one key
cannot be signed under another to any useful effect.

The resulting signature is an ordinary ML-DSA signature.
[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
accepts it, given the same message and context.

## References

National Institute of Standards and Technology (2024).
Module-Lattice-Based Digital Signature Standard. FIPS 204.
[doi:10.6028/NIST.FIPS.204](https://doi.org/10.6028/NIST.FIPS.204)

## See also

[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
[`fips_keygen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_keygen.md).

## Examples

``` r
key <- fips_keygen("ML-DSA-65")
mu <- fips_mu(key, "a manifest digest", context = "release")
length(mu)
#> [1] 64

sig <- fips_sign_mu(key, mu)
fips_verify_mu(key, mu, sig)
#> [1] TRUE

# the same signature verifies the ordinary way, from the message
capsule_verify("a manifest digest", sig, key, context = "release")
#> [1] TRUE

# mu is computable from the PUBLIC key alone, which is what lets the
# message stay on the machine that has it
identical(fips_mu(fips_public_key(key), "a manifest digest",
                  context = "release"), mu)
#> [1] TRUE
```
