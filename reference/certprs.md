# Parse an X.509 certificate

Reads the fields a verifier needs: who issued it, who it is for, when it
is valid, what key it carries, and what that key is allowed to do. Use
it to inspect the certificate of a timestamping authority or a signer
before you decide to trust it, or as the first step of
[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md).
The DER decoder is the package's own; no system library or network is
used.

## Usage

``` r
certprs(cert)
```

## Arguments

- cert:

  The certificate, DER or PEM: a raw vector of DER bytes, or the path of
  a `.der`, `.crt`, `.cer` or `.pem` file.

## Value

A list of class `bricklayer_certificate` with these elements:

- `version` (integer) and `serial` (hex);

- `issuer` and `subject` (distinguished names as text);

- `not_before` and `not_after` (`POSIXct`, UTC);

- `signature_algorithm` (a name such as `"ECDSA-SHA256"`) and
  `signature_oid`;

- `signature` and `tbs` (raw; the signed part);

- `key` (a list: `type` `"RSA"` or `"EC"`, `bits`, and the key values,
  with `curve` for EC);

- `is_ca` and `path_len`;

- `key_usage` and `extended_key_usage` (character; EKU as OIDs);

- `subject_rdns`, `issuer_rdns`, `san` and `name_constraints`;

- the policy fields `policies`, `policy_mappings` and
  `require_explicit_policy`;

- the policy fields `inhibit_policy_mapping` and `inhibit_any_policy`;

- `self_signed` (logical: issuer equals subject);

- `der` (the bytes).

[`print()`](https://rdrr.io/r/base/print.html) shows a summary.

## Details

The certificate is decoded as DER (RFC 5280 section 4.1); a file whose
text contains a `-----BEGIN` line is read as PEM and its base64 body
decoded first (only the first certificate in the file is used). Version
1 certificates, without the explicit version field, are accepted.
Extensions read: basic constraints, key usage, extended key usage,
subject alternative name, name constraints, certificate policies, policy
mappings and policy constraints, and inhibit any-policy. The signature
is not checked here: that needs the issuer's key, which
[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)
supplies.

Errors: `cert` neither a raw vector nor the path of an existing file (a
directory is refused); bytes that are not well-formed DER or carry
trailing bytes; a DER structure that is not a certificate or has no
signature.

## See also

[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md),
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md).

## Examples

``` r
# Pass the certificate file you were given (.der, .crt, .cer or .pem), for
# example the one a timestamping authority publishes, or raw DER bytes.
# Here: a small test chain shipped with the package, a self-signed P-256
# root and a leaf it issued (a throwaway test authority; trust it for
# nothing).
x509 <- function(f) {
  system.file("extdata", "x509", f, package = "rmoriebricklayer")
}
root <- certprs(x509("test-root.der"))
root
#> ╭── X.509 certificate ────────────────────────────────────────────────────────╮
#> │   Subject             O=rmbl test, CN=EC256 Root                            │
#> │   Issuer              O=rmbl test, CN=EC256 Root                            │
#> │   Serial              52157dfd900c163c5027372ed4090b9d                      │
#> │   Valid from          2026-10-02 08:43:41                                   │
#> │   Valid to            2036-09-29 08:43:41                                   │
#> │   Key                 EC 256 bits                                           │
#> │   Signature           ECDSA-SHA256                                          │
#> │   Is a CA             TRUE                                                  │
#> │   Self-signed         TRUE                                                  │
#> │   Key usage           keyCertSign, cRLSign                                  │
#> │   Extended key usage  none stated                                           │
#> │                                                                             │
#> │   In force now, for 3,623 more days (until 2036-09-29).                     │
#> │   A self-signed CA certificate: a root, trusted or not, never verified.     │
#> │                                                                             │
#> │   What the certificate says about itself. Nothing here is checked:          │
#> │   certchnvrf() verifies it against trust anchors you choose.                │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
leaf <- certprs(x509("test-leaf.der"))
leaf$subject
#> [1] "O=rmbl test, CN=EC256 Leaf"
leaf$key$curve
#> [1] "P-256"
c(leaf$not_before, leaf$not_after)
#> [1] "2026-10-02 08:43:41 UTC" "2031-10-01 08:43:41 UTC"

# the same root as PEM, the text form most authorities hand out
certprs(x509("test-root.pem"))$self_signed
#> [1] TRUE

# raw DER bytes work too
f <- x509("test-leaf.der")
der <- readBin(f, "raw", file.size(f))
identical(certprs(der)$serial, leaf$serial)
#> [1] TRUE

# bytes that are not a certificate
try(certprs(charToRaw("not a certificate")))
#> Error : not well-formed DER
```
