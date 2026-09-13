# Fetch revocation data for a certificate path

Retrieves CRLs from the distribution points named in the certificates,
and asks any OCSP responder they name about each one. Called by
[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
when `revocation = "fetch"`.

## Usage

``` r
revocation_fetch(path, timeout = 10)
```

## Arguments

- path:

  A certificate path, leaf first, as
  [`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md)
  builds it.

- timeout:

  Seconds to allow each request.

## Value

A list with `crls` (raw vectors fetched), `ok` (a logical per note) and
`notes` (a named list of details).

## Details

The OCSP request is sent by GET with the DER request base64-encoded into
the URL, as RFC 6960 appendix A.1.1 allows. That avoids needing to POST,
and works with responders that accept it; one that requires POST is
reported as unreachable rather than treated as a pass.

A responder's answer is only believed when its signature verifies under
a certificate in the path or one it carries that the path issued. An
unsigned or unverifiable answer is reported as such – treating it as
"good" would make revocation checking worse than skipping it, since it
would look like it had happened.

## See also

[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md),
[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md).

## Examples

``` r
# Reaches the network, so it is not run here.
if (FALSE) { # \dontrun{
res <- cert_chain_verify("leaf.crt", trust = "ca.crt",
                         revocation = "fetch")
res$checks
} # }
```
