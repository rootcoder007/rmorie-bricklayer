# Parse an X.509 certificate

Reads the fields a verifier needs: who issued it, who it is for, when it
is valid, what key it carries, and what that key is allowed to do.

## Usage

``` r
cert_parse(certificate)
```

## Arguments

- certificate:

  DER or PEM, as a raw vector or a path.

## Value

A list of class `bricklayer_certificate`.

## See also

[`cert_chain_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cert_chain_verify.md),
[`timestamp_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/timestamp_verify.md).

## Examples

``` r
# Certificates come from outside the package, so there is nothing to
# parse offline; this is the shape of the call.
if (FALSE) { # \dontrun{
cert <- cert_parse("tsa.crt")
cert$subject
cert$not_after
cert$extended_key_usage
} # }
```
