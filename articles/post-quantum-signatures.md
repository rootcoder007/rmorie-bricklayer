# Post-quantum signatures: ML-DSA, SLH-DSA and XMSS

A capsule is only as trustworthy as the signature on its manifest.
`rmoriebricklayer` implements the three NIST post-quantum signature
standards natively, with no system cryptography library: **ML-DSA**
(FIPS 204, lattice-based), **SLH-DSA** (FIPS 205, hash-based, stateless)
and **XMSS** (RFC 8391, hash-based, stateful). All three are used
through the same two calls,
[`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md)
and
[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md).

## Why post-quantum, and why three schemes

A signature made today may need to verify in twenty years, when a large
quantum computer could break RSA and ECDSA with Shor’s algorithm. The
three schemes rest on different assumptions, so a break of one does not
take the others:

- **ML-DSA** (Module-Lattice Digital Signature Algorithm, formerly
  Dilithium) rests on the hardness of Module-LWE and Module-SIS. Small
  keys and signatures, fast. The default.
- **SLH-DSA** (Stateless Hash-based, formerly SPHINCS+) rests only on
  the security of a hash function. Conservative; its signatures are
  large.
- **XMSS** is also hash-based but *stateful*: every key signs a fixed
  number of times and an index must never be reused. The package carries
  the state forward for you.

## ML-DSA: the default

``` r

key <- fips_keygen("ML-DSA-65")
key$scheme
#> [1] "ML-DSA-65"

sig <- capsule_sign("a manifest digest", key)
capsule_verify("a manifest digest", sig, fips_public_key(key))
#> [1] TRUE
```

The verifier needs only the public key. Any change to the message is
caught:

``` r

capsule_verify("a manifest digest (edited)", sig, fips_public_key(key))
#> [1] FALSE
```

### Context strings bind a signature to its purpose

FIPS 204 lets a signature carry a *context*: a short string hashed in
with the message. The same message signed for one purpose does not
verify under another, which stops a signature made for “staging” being
replayed as a “release” approval:

``` r

sig2 <- capsule_sign("a manifest digest", key, context = "release")
capsule_verify("a manifest digest", sig2, key, context = "release")
#> [1] TRUE
capsule_verify("a manifest digest", sig2, key, context = "staging")
#> [1] FALSE
```

### Hedged and deterministic signing

By default ML-DSA signing is *hedged*: fresh randomness enters every
signature, so two signatures of one message differ (FIPS 204 recommends
this; it also protects against fault attacks on the nonce).
`deterministic = TRUE` gives the variant where the signature depends
only on the key and the message:

``` r

s1 <- capsule_sign("same message", key, deterministic = TRUE)
s2 <- capsule_sign("same message", key, deterministic = TRUE)
identical(s1$signature, s2$signature)
#> [1] TRUE

h1 <- capsule_sign("same message", key)
h2 <- capsule_sign("same message", key)
identical(h1$signature, h2$signature)
#> [1] FALSE
```

### Signing a digest computed elsewhere

ML-DSA signs `mu = H(tr || M')`, a digest of the message that depends on
the public key but not on the secret.
[`fips_mu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fips_mu.md)
computes it from the *public* key, so the machine holding the secret
never needs to see the message:

``` r

mu <- fips_mu(fips_public_key(key), "a manifest digest", context = "release")
sig3 <- fips_sign_mu(key, mu)
fips_verify_mu(key, mu, sig3)
#> [1] TRUE
# the same signature verifies the ordinary way
capsule_verify("a manifest digest", sig3, key, context = "release")
#> [1] TRUE
```

Since 0.5.10, ML-DSA signing runs **first-order masked** by default (see
the *Side-channel assurance* vignette): every secret-dependent value is
held as two random shares. The signatures are byte-identical to the
unmasked computation; only the cost differs.

## SLH-DSA: hash-based, stateless

``` r

fips_sizes("ML-DSA-65")
#> public_key secret_key  signature       seed   opt_rand 
#>       1952       4032       3309         32         32
fips_sizes("SLH-DSA-SHAKE-128f")
#> public_key secret_key  signature       seed   opt_rand 
#>         32         64      17088         48         16
```

The price of dropping the lattice assumption is size: an SLH-DSA
signature is far larger than an ML-DSA signature at the same security
level.

``` r

fips_sizes("SLH-DSA-SHAKE-128f")[["signature"]] > fips_sizes("ML-DSA-44")[["signature"]]
#> [1] TRUE
```

The calls are identical:

``` r

hkey <- fips_keygen("SLH-DSA-SHAKE-128f")
hsig <- capsule_sign("a manifest digest", hkey)
capsule_verify("a manifest digest", hsig, fips_public_key(hkey))
#> [1] TRUE
```

### Pre-hash variants

HashML-DSA and HashSLH-DSA sign a digest of the message instead of the
message itself, for very large inputs or when the message is hashed on
another machine. The hash function’s OID is bound into the signature, so
two digests of the same length never verify for each other:

``` r

p <- capsule_sign("a large artifact", key, prehash = "sha512")
capsule_verify("a large artifact", p, key, prehash = "sha512")
#> [1] TRUE
capsule_verify("a large artifact", p, key, prehash = "sha3_512")
#> [1] FALSE
```

## XMSS: hash-based, stateful

An XMSS key of height *h* signs 2^h messages. The package stores the
next index in the key and returns the advanced key with every signature;
reusing an index would break security, so always carry `key_state`
forward:

``` r

xkey <- pqc_keygen(height = 3)
xkey$capacity
#> [1] 8
xkey$next_index
#> [1] 0

s1 <- capsule_sign("manifest-1", xkey)
capsule_verify("manifest-1", s1, signing_public_key(xkey))
#> [1] TRUE

xkey <- s1$key_state
xkey$next_index
#> [1] 1
s2 <- capsule_sign("manifest-2", xkey)
capsule_verify("manifest-2", s2, signing_public_key(xkey))
#> [1] TRUE

# a signature does not transfer to another message
capsule_verify("manifest-1", s2, signing_public_key(xkey))
#> [1] FALSE
```

## Every way of being wrong returns FALSE

Verification returns `FALSE` for every signature of the right shape that
does not verify: a truncated or edited signature, a foreign key and an
edited message all fail the same way. (An object that is not a signature
at all, a key of the wrong class or a missing message is an error,
because that is a programming mistake rather than a tampered artefact.)

``` r

pub <- fips_public_key(key)
bad <- sig
bad$signature <- paste0("ff", substring(bad$signature, 3))
capsule_verify("a manifest digest", bad, pub)
#> [1] FALSE
trunc <- sig
trunc$signature <- substring(sig$signature, 1, 64)
capsule_verify("a manifest digest", trunc, pub)
#> [1] FALSE
capsule_verify("a manifest digest", sig, fips_public_key(fips_keygen("ML-DSA-65")))
#> [1] FALSE
```

## How these implementations are checked

ML-DSA and SLH-DSA are compared byte for byte with OpenSSL 3.5 and run
against the NIST ACVP and C2SP Wycheproof vector sets on every change
(6,848 checks, 0 failures at 0.5.10), and fuzzed differentially against
OpenSSL; XMSS, which OpenSSL does not implement, is checked against the
RFC 8391 vectors. Every signer runs under valgrind with the secret key
marked undefined, a dynamic check that no executed branch or memory
address depends on it. `SECURITY.md` in the package repository has the
full table of what each check catches and what it does not.
