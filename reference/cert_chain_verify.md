# Verify a certificate chain

Builds the path from a leaf certificate to a trust anchor you supply,
verifying each signature, each validity window, and the constraints that
stop a certificate being used for something it was not issued for.

## Usage

``` r
cert_chain_verify(
  leaf,
  trust,
  intermediates = list(),
  at_time = Sys.time(),
  purpose = NULL,
  crls = list(),
  policies = NULL,
  revocation = c("supplied", "fetch", "none")
)
```

## Arguments

- leaf:

  The certificate to validate, from
  [`cert_parse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_parse.md)
  or anything
  [`cert_parse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_parse.md)
  accepts.

- trust:

  A list of trust anchors – the certificates you have decided to
  believe. A chain that does not reach one of these fails.

- intermediates:

  Optional further certificates to build the path through. They are not
  trusted by being supplied; they still have to verify.

- at_time:

  The time to check validity windows at. Defaults to now.

- purpose:

  Optional extended key usage the leaf must carry, as a name (
  `"timeStamping"`, `"codeSigning"`, ...) or an OID.

- crls:

  Optional list of CRLs, as raw or paths, to check the chain against.

- policies:

  Acceptable certificate policy OIDs. Supplied, the path must yield at
  least one of them after policy mapping and the constraints in RFC 5280
  section 6.1; omitted, policies are processed but only reported as a
  failure when a certificate in the path requires an explicit policy.

- revocation:

  `"supplied"` (the default) checks only the CRLs given in `crls`.
  `"fetch"` additionally retrieves CRLs from the distribution points in
  the certificates and queries OCSP responders – which makes
  verification depend on the network and discloses to the responder
  which certificates are being checked, so it is never the default.
  `"none"` skips revocation entirely.

## Value

A list of class `bricklayer_certpath_check`: `ok`, the `path` that was
built, and a `checks` data frame.

## Details

`at_time` is the point the validity windows are checked against, and it
matters which one you pass. For a timestamp token the right answer is
the time the token asserts: a token signed in 2020 by a certificate that
expired in 2021 was validly signed, and checking it against today would
reject it for no good reason. For a signature you are being asked to
rely on now, pass now.

## See also

[`cert_parse()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_parse.md),
[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md).

## Examples

``` r
if (FALSE) { # \dontrun{
res <- cert_chain_verify("tsa.crt", trust = "ca.crt",
                         purpose = "timeStamping")
res$ok
res$checks
} # }
```
