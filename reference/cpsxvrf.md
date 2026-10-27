# Verify a Signature Here and Again With OpenSSL

Checks an ML-DSA or SLH-DSA signature twice: with this package's own
implementation
([`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md))
and with the `openssl` program (version 3.5 or later), which implements
FIPS 204 and 205 independently. The signature counts as cross-verified
only when both accept it.

## Usage

``` r
cpsxvrf(msg, sig, key, ctx = NULL, openssl = Sys.which("openssl"))
```

## Arguments

- msg:

  The signed message: a string or a raw vector, as given to
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).

- sig:

  A signature from
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md).

- key:

  The signer's key from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  or
  [`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md);
  only its public half is used.

- ctx:

  The context string the signature was made with, or `NULL`.

- openssl:

  Path to the `openssl` program. The default looks it up on the `PATH`.

## Value

A list of class `rmbl_xvrf`: `ok` (`TRUE` only when both implementations
accept the signature), `ours` and `openssl` (each verdict; `openssl` is
`NA` when it could not be asked), `agree`, `version` (OpenSSL's, or
`NA`), `reason` (why OpenSSL gave no verdict, or `NA`) and `scheme`. It
prints as a box that opens with the verdict.

## Details

OpenSSL is never required. When it is missing, older than 3.5, or the
signature is one OpenSSL cannot check (XMSS, an HMAC tag, or a
pre-hashed signature), its verdict is `NA` with the reason, and the
result says the signature was verified here only.

The public key is written as a standard SubjectPublicKeyInfo (the NIST
object identifiers for each parameter set), the message and the
signature as raw bytes, and `openssl pkeyutl -verify -rawin` checks
them, with the context string passed as `hexcontext-string`. Nothing is
sent anywhere: the files live in a temporary folder that is removed
afterwards.

## See also

[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
for this package's verdict alone,
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

## Examples

``` r
key <- fipskg("ML-DSA-44")
sig <- cpssign("a manifest digest", key, ctx = "release")

# Both implementations accept it (or OpenSSL is reported as absent).
cpsxvrf("a manifest digest", sig, fipspubkey(key), ctx = "release")
#> ╭── Signature: verified here; OpenSSL gave no verdict ────────────────────╮
#> │ ✖ NOT VERIFIED                                                          │
#> │                                                                         │
#> │   Scheme        ML-DSA-44                                               │
#> │   This package  accepts                                                 │
#> │   OpenSSL       no verdict (OpenSSL 3.0.13)                             │
#> │                                                                         │
#> │   OpenSSL 3.0.13 is older than 3.5, which first added ML-DSA and        │
#> │   SLH-DSA.                                                              │
#> │                                                                         │
#> │   Only this package's implementation checked it; install OpenSSL 3.5 or │
#> │   later for an independent second verdict.                              │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# A changed message fails in both.
cpsxvrf("a manifest digest!", sig, key, ctx = "release")$ok
#> [1] FALSE
```
