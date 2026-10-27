# Get a Public Timestamp for a Commitment

Asks an RFC 3161 time-stamping authority to sign the SHA-256 of `data`
together with the current time, then checks the token it returns with
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md).
Anyone holding the same bytes, the token and the authority's certificate
can later prove the bytes existed at that time, without trusting the
person who asked.

## Usage

``` r
tsstmp(
  data,
  tsa = "https://freetsa.org/tsr",
  file = NULL,
  timeout = 60,
  trust = NULL
)
```

## Arguments

- data:

  What to timestamp: a raw vector, the path of an existing file, or a
  list from
  [`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md)
  (its commitment is stamped).

- tsa:

  The time-stamping authority's URL.

- file:

  Optional path to save the token to (a `.tsr` file). An existing file
  is not overwritten.

- timeout:

  Seconds to wait for the authority.

- trust:

  Trust anchors for the authority's certificate, passed to
  [`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md):
  for the default authority, its root certificate from
  <https://freetsa.org/files/cacert.pem>. Without one the token's
  signature is still checked, but the result is not VERIFIED, because
  nothing vouches for the certificate that made it.

## Value

The
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
result for the new token (class `bricklayer_timestamp`, printed as a box
with the time it asserts), with three more elements: `token` (the raw
token), `tsa` and `file` (the path it was saved to, or `NA`). An
authority that does not answer is an error.

## Details

Use it on anything that has to be fixed before the data are seen: the
commitment of a randomisation list from
[`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md)
(pass the list itself), the file of declared outcomes, a manifest or a
capsule. Only the 32-byte SHA-256 leaves the machine; the data never do.

The request carries a random 8-byte nonce from the operating system's
generator and asks for the authority's certificate in the reply, so the
token can be checked offline later. The default authority,
`"https://freetsa.org/tsr"`, is free and needs no account; any RFC 3161
service can be named instead, and an institution's own is better where
there is one. Pass `cert` and `trust` to
[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
when re-checking a saved token to tie it to a certificate you trust.

## References

Adams, C., Cain, P., Pinkas, D., and Zuccherato, R. (2001). Internet
X.509 Public Key Infrastructure Time-Stamp Protocol (TSP). RFC 3161.

## See also

[`tsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/tsvrf.md)
to check a saved token,
[`ralloc()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ralloc.md),
[`prrgdecl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/prrgdecl.md).

## Examples

``` r
if (FALSE) { # interactive()
# Fix a trial's allocation before enrolment, then stamp its commitment.
a <- ralloc(40, seed = "a demonstration only")
ts <- tsstmp(a, file = file.path(tempdir(), "allocation.tsr"))
ts$time

# Years later, anyone re-checks the saved token against the commitment.
tsvrf(ts$file, charToRaw(attr(a, "alloc")$digest))
}
```
