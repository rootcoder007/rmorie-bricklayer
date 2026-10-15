# SHA-256 hex digest (C backend)

Computes the SHA-256 hash (FIPS 180-4) of text or raw bytes with the
self-contained implementation in the package's compiled core, and
returns it as a 64-character lowercase hexadecimal string. A hash is a
short fingerprint: any change to the input changes it, so it is used
throughout the package to record exactly which data, mapping or file a
result came from. Sibling packages use the same routine through
`LinkingTo: rmoriebricklayer`.

## Usage

``` r
core_sha256(x)
```

## Arguments

- x:

  A character vector, or a raw vector. Other atomic vectors are
  converted with
  [`as.character()`](https://rdrr.io/r/base/character.html).

## Value

A character vector of 64-character lowercase hex digests: one per
element for character input, length 1 for raw input (`character(0)` for
an empty character vector).

## Details

For a raw vector the bytes are hashed as one message and one digest is
returned. Any other input is converted with
[`as.character()`](https://rdrr.io/r/base/character.html) and each
element is hashed separately, as the bytes of the string as stored in
memory (no re-encoding). In a UTF-8 session those are the UTF-8 bytes;
for a string marked latin1 they are the latin1 bytes, so use
[`enc2utf8()`](https://rdrr.io/r/base/Encoding.html) first when the
digest must be the same on every platform. `NA` gives `NA`. Numbers are
hashed through their printed form (`1` hashes as `"1"`), and a factor
through its labels.

For a digest of a whole R object, hash its serialization (see the
examples) or use
[`digest_object`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md);
for BLAKE2b use
[`core_blake2b`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_blake2b.md).

## References

National Institute of Standards and Technology (2015). Secure Hash
Standard (SHS). FIPS PUB 180-4.
[doi:10.6028/NIST.FIPS.180-4](https://doi.org/10.6028/NIST.FIPS.180-4)

## Examples

``` r
# Hash a character scalar (NIST test vector for "abc").
core_sha256("abc")
#> [1] "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
# ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

# Vectorised over character input: one digest per element.
core_sha256(c("abc", "def", NA))
#> [1] "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
#> [2] "cb8379ac2098aa165029e3938a51da0bcecfc008fd6795f401178647f96c5b34"
#> [3] NA                                                                

# Raw input hashes the bytes directly; identical to the character form.
identical(core_sha256("abc"), core_sha256(charToRaw("abc")))
#> [1] TRUE

# The empty message.
core_sha256(raw(0))
#> [1] "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

# Fingerprint an arbitrary object via its serialization.
core_sha256(serialize(list(a = 1L, b = "x"), NULL))
#> [1] "5d31430add6fdb81ad2d63cc9b82953ee454b281238856418d0bb6ca232afbc7"
```
