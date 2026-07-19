# SHA-256 hex digest (C backend)

Hashes character or raw input with the self-contained SHA-256 in the
`rmoriebricklayer` core. For a character vector each element is hashed
as its UTF-8/native bytes; for a raw vector the raw bytes are hashed.
This is the same routine sibling packages use for provenance via
`LinkingTo: rmoriebricklayer`.

## Usage

``` r
core_sha256(x)
```

## Arguments

- x:

  A character vector or a raw vector.

## Value

A character vector of 64-character lowercase hex digests (one per
element for character input; length-1 for raw input).

## Examples

``` r
# Hash a character scalar (NIST test vector for "abc").
core_sha256("abc")
#> [1] "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
# ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

# Vectorised over character input: one digest per element.
core_sha256(c("abc", "def"))
#> [1] "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
#> [2] "cb8379ac2098aa165029e3938a51da0bcecfc008fd6795f401178647f96c5b34"

# Raw input hashes the bytes directly; identical to the character form.
identical(core_sha256("abc"), core_sha256(charToRaw("abc")))
#> [1] TRUE

# Fingerprint an arbitrary object via its serialization.
core_sha256(serialize(list(a = 1L, b = "x"), NULL))
#> [1] "5d31430add6fdb81ad2d63cc9b82953ee454b281238856418d0bb6ca232afbc7"
```
