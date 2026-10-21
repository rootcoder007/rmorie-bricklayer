# Verify an RFC 3161 timestamp token

A timestamp token is a small file, signed by an independent timestamping
authority, saying that a given set of bytes (for example a manifest of
results) existed at a given time. `tsvrf()` checks that a token covers
the bytes given, reports the time it asserts, and verifies the
timestamping authority's signature under a certificate you supply or the
one the token carries. `tsinfo()` reads the token's fields without
verifying anything. Use them to prove that an analysis output existed by
a certain date.

## Usage

``` r
tsvrf(token, data, cert = NULL, trust = NULL, crls = list(), attm = NULL)

tsinfo(token)
```

## Arguments

- token:

  The token: a raw vector, or a path to a `.tsr` / `.tst` file. A full
  `TimeStampResp` or a bare `TimeStampToken` are both accepted.

- data:

  The bytes the token should cover: a raw vector, or a path to a file.

- cert:

  The authority's certificate, DER or PEM, as raw or a path. Optional:
  when the token embeds a certificate, that one is used and the fact is
  reported.

- trust:

  Trust anchors for validating that certificate – see
  [`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md).
  Without them the signature is still checked, but nothing vouches for
  the key that made it.

- crls:

  Optional CRLs to check the chain against, as raw vectors or paths.

- attm:

  The time to check certificate validity at. Defaults to the time the
  token asserts, which is usually what is wanted.

## Value

`tsvrf()` returns a list of class `bricklayer_timestamp`: `ok`
(logical), `time` (a `POSIXct` in UTC, or `NA` when the token could not
be read), `serial` and `policy` (character), `hash_algorithm` (for
example `"sha256"`), `signature_algorithm` (an OID string), and a
`checks` data frame with columns `check`, `ok` and `detail`. The print
method lists the checks. `tsinfo()` returns a plain list with `time`,
`serial`, `policy`, `hash_algorithm`, `imprint` (hex),
`signature_algorithm` and `has_certificate` (logical).

## Details

Every step is recorded as a row of `checks`:

- `token_parses`;

- `token_structure`;

- `message_imprint` (the hash of `data` equals the token's imprint);

- `certificate_source`;

- `signature`;

- `attribute_digest` (the signed attributes commit to the token's
  contents);

- `certificate_trust`;

- with `trust`, the `chain:` checks of
  [`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md).

`ok` is `TRUE` only when every row passes. A token that cannot be parsed
is not an error: it gives `ok = FALSE` and the rows up to the failure.

Pass `trust` and the certificate is validated too: the chain is built to
an anchor you name, every signature in it is verified, every validity
window is checked, an issuer must be a CA, and the leaf must carry the
timeStamping extended key usage. Omit `trust` and the signature is still
checked but `certificate_trust` is reported as failed, because without
an anchor a passing signature says only that the key in the certificate
signed the token – not that anyone should believe that certificate.

Validity windows are checked at the time the TOKEN asserts, unless
`attm` says otherwise. A token signed in 2020 under a certificate that
expired in 2021 was validly signed, and judging it by today's date would
reject it for a reason unconnected to its validity.

RSA and ECDSA over the NIST prime curves P-256, P-384 and P-521 are
verified. Anything else – a post-quantum signature, a compressed EC
point, an Edwards curve – is reported as unverifiable rather than
treated as valid, which is the safe direction for a verifier.

Revocation data are not fetched: a CRL has to be handed in through
`crls`, and nothing is retrieved over the network (chain checks such as
name constraints and certificate policies are done by
[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)).
Nothing is written to disk.

Errors: `token`, `data` or `cert` neither a raw vector nor the path of
an existing file. `tsinfo()` errors on a token it cannot parse.

## References

Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001). Internet
X.509 Public Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161.

## See also

[`chnseal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chn.md)
for the ordering a timestamp cannot give,
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
for authorship.

## Examples

``` r
# Offline: bytes that are not a timestamp token are reported, not
# thrown, so a batch check can carry on.
bad <- tsvrf(as.raw(c(0x30, 0x03, 0x02, 0x01, 0x05)),
                        data = charToRaw("manifest"))
bad$ok
#> [1] FALSE
bad$checks
#>             check    ok                         detail
#> 1    token_parses  TRUE                 5 bytes of DER
#> 2 token_structure FALSE no CMS SignedData in the token

# tsinfo() does refuse an unreadable token
try(tsinfo(as.raw(1:10)))
#> Error : trailing bytes after the DER structure: 4 of 10 consumed

# Real tokens come from a timestamping authority; this is the shape of
# the call.
if (FALSE) { # interactive()
res <- tsvrf("response.tsr", data = "manifest.json")
res$ok
res$time
}
```
