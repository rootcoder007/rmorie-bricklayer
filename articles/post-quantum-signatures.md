# Post-quantum signatures: ML-DSA, SLH-DSA and XMSS

A capsule is only as trustworthy as the signature on its manifest.
`rmoriebricklayer` implements the three NIST post-quantum signature
standards natively, with no system cryptography library: **ML-DSA**
(FIPS 204, lattice-based), **SLH-DSA** (FIPS 205, hash-based, stateless)
and **XMSS** (RFC 8391, hash-based, stateful). All three are used
through the same two calls,
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
and
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md).

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

key <- fipskg("ML-DSA-65")
key$scheme
#> [1] "ML-DSA-65"

sig <- cpssign("a manifest digest", key)
cpsvrf("a manifest digest", sig, fipspubkey(key))
#> [1] TRUE
```

The verifier needs only the public key. Any change to the message is
caught:

``` r

cpsvrf("a manifest digest (edited)", sig, fipspubkey(key))
#> [1] FALSE
```

### Context strings bind a signature to its purpose

FIPS 204 lets a signature carry a *context*: a short string hashed in
with the message. The same message signed for one purpose does not
verify under another, which stops a signature made for “staging” being
replayed as a “release” approval:

``` r

sig2 <- cpssign("a manifest digest", key, ctx = "release")
cpsvrf("a manifest digest", sig2, key, ctx = "release")
#> [1] TRUE
cpsvrf("a manifest digest", sig2, key, ctx = "staging")
#> [1] FALSE
```

### Hedged and deterministic signing

By default ML-DSA signing is *hedged*: fresh randomness enters every
signature, so two signatures of one message differ (FIPS 204 recommends
this; it also protects against fault attacks on the nonce).
`deterministic = TRUE` gives the variant where the signature depends
only on the key and the message:

``` r

s1 <- cpssign("same message", key, determ = TRUE)
s2 <- cpssign("same message", key, determ = TRUE)
identical(s1$signature, s2$signature)
#> [1] TRUE

h1 <- cpssign("same message", key)
h2 <- cpssign("same message", key)
identical(h1$signature, h2$signature)
#> [1] FALSE
```

### Signing a digest computed elsewhere

ML-DSA signs `mu = H(tr || M')`, a digest of the message that depends on
the public key but not on the secret.
[`fipsmu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmu.md)
computes it from the *public* key, so the machine holding the secret
never needs to see the message:

``` r

mu <- fipsmu(fipspubkey(key), "a manifest digest", ctx = "release")
sig3 <- fipssignmu(key, mu)
fipsvrfmu(key, mu, sig3)
#> [1] TRUE
# the same signature verifies the ordinary way
cpsvrf("a manifest digest", sig3, key, ctx = "release")
#> [1] TRUE
```

Since 0.5.10, ML-DSA signing runs **first-order masked** by default (see
the *Side-channel assurance* vignette): every secret-dependent value is
held as two random shares. The signatures are byte-identical to the
unmasked computation; only the cost differs.

## SLH-DSA: hash-based, stateless

``` r

fipssz("ML-DSA-65")
#> public_key secret_key  signature       seed        rnd 
#>       1952       4032       3309         32         32
fipssz("SLH-DSA-SHAKE-128f")
#> public_key secret_key  signature       seed        rnd 
#>         32         64      17088         48         16
```

The price of dropping the lattice assumption is size: an SLH-DSA
signature is far larger than an ML-DSA signature at the same security
level.

``` r

fipssz("SLH-DSA-SHAKE-128f")[["signature"]] > fipssz("ML-DSA-44")[["signature"]]
#> [1] TRUE
```

The calls are identical:

``` r

hkey <- fipskg("SLH-DSA-SHAKE-128f")
hsig <- cpssign("a manifest digest", hkey)
cpsvrf("a manifest digest", hsig, fipspubkey(hkey))
#> [1] TRUE
```

### Pre-hash variants

HashML-DSA and HashSLH-DSA sign a digest of the message instead of the
message itself, for very large inputs or when the message is hashed on
another machine. The hash function’s OID is bound into the signature, so
two digests of the same length never verify for each other:

``` r

p <- cpssign("a large artifact", key, prehash = "sha512")
cpsvrf("a large artifact", p, key, prehash = "sha512")
#> [1] TRUE
cpsvrf("a large artifact", p, key, prehash = "sha3_512")
#> [1] FALSE
```

## XMSS: hash-based, stateful

An XMSS key of height *h* signs 2^h messages. The package stores the
next index in the key and `xmssadv(key, signature)` gives the advanced
key after every signature; reusing an index would break security, so
always advance the key with
[`xmssadv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
and save that:

``` r

xkey <- pqckg(height = 3)
xkey$capacity
#> [1] 8
xkey$next_index
#> [1] 0

s1 <- cpssign("manifest-1", xkey)
cpsvrf("manifest-1", s1, signpubkey(xkey))
#> [1] TRUE

xkey <- xmssadv(xkey, s1)
xkey$next_index
#> [1] 1
s2 <- cpssign("manifest-2", xkey)
cpsvrf("manifest-2", s2, signpubkey(xkey))
#> [1] TRUE

# a signature does not transfer to another message
cpsvrf("manifest-1", s2, signpubkey(xkey))
#> [1] FALSE
```

The key is a value, so an old copy of it still says an old `next_index`.
The package therefore also keeps a record of the highest index each key
has used on this machine
([`?xmssadv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssadv.md)
says where), and refuses a used index even from a stale copy. A key
generated here is entered at birth; a key from another machine, one
rebuilt from its seeds, or one used in a CI job or a container with a
fresh home directory is unknown to the record and must be vouched for
once with `xmssregkey(key)` before it signs from index 0.

### The key file is the state

RFC 10033 (*Hash-Based Signatures: State and Backup Management*)
separates the private key, which never changes, from the state, the
indices already used, which must be updated and saved before a signature
is released, and warns that a copied or restored state signs used
indices again. `rmbl sign` follows it: with
`--scheme xmss-sha256 --key-file key.json` the key file is the state. It
is rewritten atomically, with `next_index` advanced and a `used` field,
before any bundle is written, and the run signs from the indices it
reserved.

``` r

root <- tempfile("capsules-")
for (nm in c("one", "two")) {
  d <- file.path(root, nm)
  dir.create(d, recursive = TRUE)
  utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"), row.names = FALSE)
  writeLines('{"resource": {"filename": "data.csv"}}', file.path(d, "data_provenance.json"))
}
kf <- tempfile(fileext = ".json")
writeLines(tojs(unclass(pqckg(height = 4)), auto_unbox = TRUE), kf)
copy <- tempfile(fileext = ".json")
invisible(file.copy(kf, copy))   # an old copy of the key, kept by mistake

status <- blcli(c("sign", root, "--scheme", "xmss-sha256", "--key-file", kf, "--json"),
                out = function(s) NULL)
status
#> [1] 0
state <- fromjs(paste(readLines(kf), collapse = "\n"))
state$next_index                # two capsules signed, two indices used
#> [1] 2
state$used$generation
#> [1] 1

# the old copy is refused: the bundles show indices it does not know are used
blcli(c("sign", root, "--scheme", "xmss-sha256", "--key-file", copy, "--overwrite"),
      out = function(s) cat(s[grepl("stale", s)]))
#> rmoriebricklayer: stale copy of the key: index 1 of it was already signed (seen in /tmp/RtmpMoHPkT/capsules-3a7012a8ae33/two/capsule_bundle.json), but this state says the highest used in its range is -1. Signing would reuse an index: use the copy that made that signature, or generate a new key
xmssidxseen(root)[, c("index", "reused")]
#>   index reused
#> 1     0  FALSE
#> 2     1  FALSE
```

`--state-file` keeps the state in a file of its own.
`--sectors K --sector-index I` splits the indices into K disjoint ranges
so that K signers can share one key, each in its own range (RFC 10033,
section 5.3), and `--reserve N` marks N indices used in one write and
signs from them (section 5.9; the ones a run does not use are lost). A
key kept as a CI secret is a fixed copy that every job starts from, so
every job would sign the same indices: in CI, sign with ML-DSA unless
the XMSS state lives in a file that persists between jobs. NIST SP
800-208 approves XMSS only inside a hardware module that never exports
the key, which a key file is not.

## Every way of being wrong returns FALSE

Verification returns `FALSE` for every signature of the right shape that
does not verify: a truncated or edited signature, a foreign key and an
edited message all fail the same way. (An object that is not a signature
at all, a key of the wrong class or a missing message is an error,
because that is a programming mistake rather than a tampered artefact.)

``` r

pub <- fipspubkey(key)
bad <- sig
bad$signature <- paste0("ff", substring(bad$signature, 3))
cpsvrf("a manifest digest", bad, pub)
#> [1] FALSE
trunc <- sig
trunc$signature <- substring(sig$signature, 1, 64)
cpsvrf("a manifest digest", trunc, pub)
#> [1] FALSE
cpsvrf("a manifest digest", sig, fipspubkey(fipskg("ML-DSA-65")))
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

## Signing a release of Indigenous tables

A signature lets anyone check that a release came from its publisher and
has not changed:

``` r

key <- fipskg("ML-DSA-65")
d <- indiex("mentalhealth")
msg <- dgstobj(d)
sig <- cpssign(msg, key)
cpsvrf(msg, sig, fipspubkey(key))
#> [1] TRUE
```
