# Parse an X.509 certificate

Reads the fields a verifier needs: who issued it, who it is for, when it
is valid, what key it carries, and what that key is allowed to do. Use
it to inspect the certificate of a timestamping authority or a signer
before you decide to trust it, or as the first step of
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md).
The DER decoder is the package's own; no system library or network is
used.

## Usage

``` r
cert_parse(certificate)
```

## Arguments

- certificate:

  The certificate, DER or PEM: a raw vector of DER bytes, or the path of
  a `.der`, `.crt`, `.cer` or `.pem` file.

## Value

A list of class `c("bricklayer_certificate", "list")` with `version`
(integer), `serial` (hex), `issuer` and `subject` (distinguished names
as text), `not_before` and `not_after` (`POSIXct`, UTC),
`signature_algorithm` (a name such as `"ECDSA-SHA256"`) and
`signature_oid`, `signature` and `tbs` (raw; the signed part), `key` (a
list: `type` `"RSA"` or `"EC"`, `bits`, and the key values, with `curve`
for EC), `is_ca` and `path_len`, `key_usage` and `extended_key_usage`
(character; EKU as OIDs), `subject_rdns`, `issuer_rdns`, `san`,
`name_constraints`, the policy fields (`policies`, `policy_mappings`,
`require_explicit_policy`, `inhibit_policy_mapping`,
`inhibit_any_policy`), `self_signed` (logical: issuer equals subject)
and `der` (the bytes). [`print()`](https://rdrr.io/r/base/print.html)
shows a summary.

## Details

The certificate is decoded as DER (RFC 5280 section 4.1); a file whose
text contains a `-----BEGIN` line is read as PEM and its base64 body
decoded first (only the first certificate in the file is used). Version
1 certificates, without the explicit version field, are accepted.
Extensions read: basic constraints, key usage, extended key usage,
subject alternative name, name constraints, certificate policies, policy
mappings and policy constraints, and inhibit any-policy. The signature
is not checked here: that needs the issuer's key, which
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
supplies.

Errors: `certificate` neither a raw vector nor the path of an existing
file (a directory is refused); bytes that are not well-formed DER or
carry trailing bytes; a DER structure that is not a certificate or has
no signature.

## See also

[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md),
[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md).

## Examples

``` r
# A small test chain shipped as hexadecimal DER: a self-signed P-256 root
# and a leaf it issued (a throwaway test authority; trust it for nothing).
root_hex <- paste0(
  "308201973082013ca003020102021452157dfd900c163c5027372ed4090b9d11748286300a06",
  "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
  "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3336303932",
  "393038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
  "030c0a454332353620526f6f743059301306072a8648ce3d020106082a8648ce3d0301070342",
  "0004624ad2e98f4566cd8f003a188f822875fa4760ed894507e8a4130a08fcb59280e958aa6c",
  "e6147989d155ce20d1a6d94fe109d3d2f2bc13d1394cea3520197fdda3423040300f0603551d",
  "130101ff040530030101ff300e0603551d0f0101ff040403020106301d0603551d0e04160414",
  "2ef598166f5b9e6bb65d3252cf127b2c992348ae300a06082a8648ce3d040302034900304602",
  "21009cd3d7968f65630677b3c7437cae5187021d553c756820d34b6a8a1240e7efb7022100a3",
  "c37f0a8e1f38a5263b14414e6f916962bbd36bcbaca40b07d371352de745c0")
leaf_hex <- paste0(
  "308201ae30820154a00302010202142fa99d48ead4c033c568837b2288f9e9bf137068300a06",
  "082a8648ce3d040302302931123010060355040a0c09726d626c207465737431133011060355",
  "04030c0a454332353620526f6f74301e170d3236313030323038343334315a170d3331313030",
  "313038343334315a302931123010060355040a0c09726d626c20746573743113301106035504",
  "030c0a4543323536204c6561663059301306072a8648ce3d020106082a8648ce3d0301070342",
  "00045f0ad14e657dedf3f6cc18530f9d905823b6e9f492ecc0eb1989c9ad8a11a859ebb7681a",
  "e5b1f579974e3c6709e824245608c448da6fe248ebf67bf727d598f4a35a305830090603551d",
  "1304023000300b0603551d0f040403020780301d0603551d0e04160414b1d22b6dd5987f0dfa",
  "0ff3a5d0140351d752e0fb301f0603551d230418301680142ef598166f5b9e6bb65d3252cf12",
  "7b2c992348ae300a06082a8648ce3d0403020348003045022100bc9d6ec452554adb8f33e4ac",
  "53d5e29620fc19528074153028ce849d98c8c15202205c841de357dbad5042daba7fb4af3724",
  "78d684f648e6ef23c68a3d764894c8fc")
hex2raw <- function(h) {
  as.raw(strtoi(substring(h, seq(1, nchar(h), 2), seq(2, nchar(h), 2)), 16L))
}
root <- cert_parse(hex2raw(root_hex))
root
#> ── X.509 certificate ─────────────────────────────────────────────
#>   subject     O=rmbl test, CN=EC256 Root
#>   issuer      O=rmbl test, CN=EC256 Root
#>   serial      52157dfd900c163c5027372ed4090b9d
#>   valid from  2026-10-02 08:43:41
#>   valid to    2036-09-29 08:43:41
#>   key         EC 256 bits
#>   signature   ECDSA-SHA256
#>   is a CA     TRUE
#>   key usage   
#> ──────────────────────────────────────────────────────────────────
leaf <- cert_parse(hex2raw(leaf_hex))
leaf$subject
#> [1] "O=rmbl test, CN=EC256 Leaf"
leaf$key$curve
#> [1] "P-256"
c(leaf$not_before, leaf$not_after)
#> [1] "2026-10-02 08:43:41 UTC" "2031-10-01 08:43:41 UTC"

# the same certificate from a PEM file
pem <- tempfile(fileext = ".pem")
writeLines(c("-----BEGIN CERTIFICATE-----",
             strsplit(bricklayer_json_base64_enc(hex2raw(root_hex)), "\n")[[1]],
             "-----END CERTIFICATE-----"), pem)
cert_parse(pem)$self_signed
#> [1] TRUE

# bytes that are not a certificate
try(cert_parse(charToRaw("not a certificate")))
#> Error : not well-formed DER
```
