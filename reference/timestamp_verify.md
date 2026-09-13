# Verify an RFC 3161 timestamp token

Checks that a timestamp token covers the bytes given, reports the time
it asserts, and verifies the timestamping authority's signature under a
certificate you supply.

## Usage

``` r
timestamp_verify(
  token,
  data,
  certificate = NULL,
  trust = NULL,
  crls = list(),
  at_time = NULL
)

timestamp_info(token)
```

## Arguments

- token:

  The token: a raw vector, or a path to a `.tsr` / `.tst` file. A full
  `TimeStampResp` or a bare `TimeStampToken` are both accepted.

- data:

  The bytes the token should cover: a raw vector, or a path to a file.

- certificate:

  The authority's certificate, DER or PEM, as raw or a path. Optional:
  when the token embeds a certificate, that one is used and the fact is
  reported.

- trust:

  Trust anchors for validating that certificate – see
  [`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md).
  Without them the signature is still checked, but nothing vouches for
  the key that made it.

- crls:

  Optional CRLs to check the chain against, as raw vectors or paths.

- at_time:

  The time to check certificate validity at. Defaults to the time the
  token asserts, which is usually what is wanted.

## Value

A list of class `bricklayer_timestamp`: `ok`, `time` (a `POSIXct` in
UTC), `serial`, `policy`, `hash_algorithm`, `signature_algorithm`, and a
`checks` data frame.

## Details

Pass `trust` and the certificate is validated too: the chain is built to
an anchor you name, every signature in it is verified, every validity
window is checked, an issuer must be a CA, and the leaf must carry the
timeStamping extended key usage. Omit `trust` and the signature is still
checked but `certificate_trust` is reported as failed, because without
an anchor a passing signature says only that the key in the certificate
signed the token – not that anyone should believe that certificate.

Validity windows are checked at the time the TOKEN asserts, unless
`at_time` says otherwise. A token signed in 2020 under a certificate
that expired in 2021 was validly signed, and judging it by today's date
would reject it for a reason unconnected to its validity.

RSA and ECDSA over the NIST prime curves P-256, P-384 and P-521 are
verified. Anything else – a post-quantum signature, a compressed EC
point, an Edwards curve – is reported as unverifiable rather than
treated as valid, which is the safe direction for a verifier.

Still not done: name constraints, policy mapping, and fetching
revocation data. A CRL has to be handed in through `crls`; nothing is
retrieved over the network.

## References

Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001). Internet
X.509 Public Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161.

## See also

[`chain_seal()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_chain.md)
for the ordering a timestamp cannot give,
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
for authorship.

## Examples

``` r
# Tokens come from a timestamping authority, so there is nothing to
# demonstrate offline; this is the shape of the call.
if (FALSE) { # \dontrun{
res <- timestamp_verify("response.tsr", data = "manifest.json")
res$ok
res$time
} # }
```
