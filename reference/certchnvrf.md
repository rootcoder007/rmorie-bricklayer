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
# The test chain shipped with the package: a self-signed P-256 root and a
# leaf it issued (a throwaway test authority; trust it for nothing). With
# your own certificates, pass their files (or certprs() results).
x509 <- function(f) {
  system.file("extdata", "x509", f, package = "rmoriebricklayer")
}
root <- certprs(x509("test-root.der"))
leaf <- certprs(x509("test-leaf.der"))

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
r <- certchnvrf(
  leaf,
  trust = root,
  attm = leaf$not_before + 86400,
  purp = "timeStamping"
)
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
