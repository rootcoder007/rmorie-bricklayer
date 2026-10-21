# Fetch revocation data for a certificate path

Checks over the network whether any certificate in a chain has been
revoked by its issuer. It downloads the certificate revocation lists
(CRLs) that the certificates point to, and asks each OCSP responder they
name about the certificate. It is called by
[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)
when `revocation = "fetch"`; you would call it directly only to inspect
the raw revocation data. Nothing in the package does this unless asked,
because a verifier that goes online stops working offline, can give
different answers on different days, and tells the responder which
certificates are being checked.

## Usage

``` r
rvkfetch(path, tmout = 10)
```

## Arguments

- path:

  A certificate path, leaf first, as
  [`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)
  builds it.

- tmout:

  Number, default 10: seconds to allow each request.

## Value

A list with `crls` (a list of raw DER vectors fetched), `ok` (a logical
vector, one element per CRL fetch or OCSP query, `TRUE` for a success)
and `notes` (a named list of character details, named like
`"crl fetch [1]"` or `"ocsp [1]"` by the certificate's position in the
path; a later attempt for the same certificate overwrites an earlier
note of the same name).

## Details

For each certificate, every http(s) URL in its CRL distribution points
extension (2.5.29.31) is fetched; a PEM CRL is converted to DER. For
each certificate except the last (which has no issuer in the path),
every OCSP URL in its authority information access extension is asked
about it. The OCSP request is sent by POST first, which RFC 6960
requires responders to accept, and if that gets no answer, by GET with
the DER request base64-encoded into the URL, as RFC 6960 appendix A.1.1
allows. A responder that answers neither is reported as unreachable
rather than treated as a pass.

A responder's answer is only believed when its signature verifies under
a certificate in the path or one it carries that the path issued. An
unsigned or unverifiable answer is reported as such – treating it as
`"good"` would make revocation checking worse than skipping it, since it
would look like it had happened.

The fetched CRLs are returned, not checked:
[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md)
checks the certificates against them. Network: plain http is allowed
here, because CRLs and OCSP answers are signed and RFC 5280 and RFC 6960
distribute them over http, but URLs that point at local or private
addresses are refused (and reported as not retrieved). A certificate
with no CRL or OCSP URL produces no request at all.

Errors: `path` not a non-empty list of parsed certificates (each a list
with a raw `der` element); `tmout` not positive. Network failures are
not errors; they are reported in `ok` and `notes`.

## See also

[`certchnvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/certchnvrf.md),
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md).

## Examples

``` r
# Offline: a path entry that names no CRL or OCSP URL (here, bytes that
# are not a certificate at all) makes no request and returns empty results.
str(rvkfetch(list(list(der = as.raw(1:3)))))
#> List of 3
#>  $ crls : list()
#>  $ ok   : logi(0) 
#>  $ notes: list()

# the input checks
try(rvkfetch(list()))
#> Error : `path` must be a non-empty list of parsed certificates (certprs())
try(rvkfetch(list(list(der = as.raw(1:3))), tmout = 0))
#> Error : `tmout` must be positive

# Reaches the network, so it is not run here.

if (FALSE) { # interactive()
res <- certchnvrf("leaf.crt", trust = "ca.crt",
                         rvk = "fetch")
res$checks
}
```
