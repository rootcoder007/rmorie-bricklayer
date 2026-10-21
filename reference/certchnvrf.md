# Verify a certificate chain

Builds the path from a leaf certificate to a trust anchor you supply,
verifying each signature, each validity window, and the constraints that
stop a certificate being used for something it was not issued for.

## Usage

``` r
certchnvrf(
  leaf,
  trust,
  inter = list(),
  attm = Sys.time(),
  purp = NULL,
  crls = list(),
  pols = NULL,
  rvk = c("supplied", "fetch", "none")
)
```

## Arguments

- leaf:

  The certificate to validate, from
  [`certprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certprs.md)
  or anything
  [`certprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certprs.md)
  accepts.

- trust:

  A list of trust anchors – the certificates you have decided to
  believe. A chain that does not reach one of these fails.

- inter:

  Optional further certificates to build the path through. They are not
  trusted by being supplied; they still have to verify.

- attm:

  The time to check validity windows at: a `POSIXct` or anything
  [`as.POSIXct()`](https://rdrr.io/r/base/as.POSIXlt.html) reads, taken
  as UTC. Defaults to now.

- purp:

  Optional extended key usage the leaf must carry, as a name
  (`"timeStamping"`, `"codeSigning"`, ...) or an OID. Default `NULL`: no
  purpose is required.

- crls:

  Optional list of CRLs, as raw DER or paths, to check the chain
  against. Default [`list()`](https://rdrr.io/r/base/list.html).

- pols:

  Optional character vector of acceptable certificate policy OIDs;
  default `NULL`. Supplied, the path must yield at least one of them
  after policy mapping and the constraints in RFC 5280 section 6.1;
  omitted, policies are processed but only reported as a failure when a
  certificate in the path requires an explicit policy.

- rvk:

  `"supplied"` (the default) checks only the CRLs given in `crls`.
  `"fetch"` additionally retrieves CRLs from the distribution points in
  the certificates and queries OCSP responders – which makes
  verification depend on the network and discloses to the responder
  which certificates are being checked, so it is never the default.
  `"none"` skips revocation entirely.

## Value

A list of class `bricklayer_certpath_check`: `ok` (logical, the
verdict), `path` (the list of certificates from the leaf to the anchor,
as built), `checks` (a data frame with `check`, logical `ok` and
`detail`, one row per check), `attm` (the time used) and `policies` (the
outcome of policy processing).
[`print()`](https://rdrr.io/r/base/print.html) shows the verdict and the
checks.

## Details

`attm` is the point the validity windows are checked against, and it
matters which one you pass. For a timestamp token the right answer is
the time the token asserts: a token signed in 2020 by a certificate that
expired in 2021 was validly signed, and checking it against today would
reject it for no good reason. For a signature you are being asked to
rely on now, pass now.

The path is built by following issuer names from the leaf through the
intermediates until a certificate in `trust` is reached, at most ten
steps (a cycle among supplied certificates cannot loop). Then every link
is checked: the validity window at `attm`, the signature under the
issuer's key (RSA PKCS#1 v1.5 with SHA-1, SHA-256, SHA-384 or SHA-512;
ECDSA with SHA-256, SHA-384 or SHA-512 on P-256, P-384 and P-521), that
every issuer is a CA with a path length that allows the chain, name
constraints, the policy rules of RFC 5280 section 6.1, the requested
`purp` (extended key usage of the leaf), that the anchor is self-signed,
and revocation as `rvk` says. Each check is one row of `checks`; `ok` is
`TRUE` only when every row passed. A failed check is a row, not an
error.

Errors: `trust` empty; a certificate that
[`certprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certprs.md)
cannot read; an unknown `rvk`. With `revocation = "fetch"` the network
is used (distribution points and OCSP responders named in the
certificates); otherwise nothing is fetched.

## See also

[`certprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certprs.md),
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md).

## Examples

``` r
# A small test chain shipped as hexadecimal DER: a self-signed P-256 root
# and a leaf it issued (a throwaway test authority; trust it for nothing).
roothex <- paste0(
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
leafhex <- paste0(
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
root <- certprs(hex2raw(roothex))
leaf <- certprs(hex2raw(leafhex))

# the leaf chains to the root, checked a day after it was issued
res <- certchnvrf(leaf, trust = root, attm = leaf$not_before + 86400)
res$ok
#> [1] TRUE
res$checks[, c("check", "ok")]
#>                                    check   ok
#> 1                         path_to_anchor TRUE
#> 2  validity [1] O=rmbl test, CN=EC256 Le TRUE
#> 3 signature [1] O=rmbl test, CN=EC256 Le TRUE
#> 4  validity [2] O=rmbl test, CN=EC256 Ro TRUE
#> 5   is a CA [2] O=rmbl test, CN=EC256 Ro TRUE
#> 6                     anchor_self_signed TRUE

# after the leaf expired, the same chain fails on validity
certchnvrf(leaf, trust = root, attm = leaf$not_after + 86400)$ok
#> [1] FALSE

# a purpose the leaf was not issued for
r <- certchnvrf(leaf, trust = root, attm = leaf$not_before + 86400,
                       purp = "timeStamping")
r$checks[!r$checks$ok, ]
#>     check    ok                                       detail
#> 7 purpose FALSE the leaf states no extended key usage at all

# a chain must end at something you trust
try(certchnvrf(leaf, trust = list()))
#> Error : `trust` must name at least one anchor; a chain that reaches nothing you have decided to believe proves nothing
if (FALSE) { # interactive()
# with revocation looked up on the network
certchnvrf("tsa.crt", trust = "ca.crt", purp = "timeStamping",
                  rvk = "fetch")
}
```
