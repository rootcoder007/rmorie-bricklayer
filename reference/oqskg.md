# Generate a standardised post-quantum signing key (deprecated name)

Kept so code written against the liboqs-backed version keeps working.
The schemes are no longer reached through liboqs – they are implemented
in this package – and the name no longer describes anything, so use
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
instead. New code should not call these functions.

## Usage

``` r
oqskg(scheme = "ML-DSA-65")

oqspubkey(key)
```

## Arguments

- scheme:

  Scheme name; see
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

- key:

  A key from `oqskg()`.

## Value

As
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
(a `bricklayer_fips_key`) and
[`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
(a `bricklayer_fips_public_key`).

## Details

`oqskg()` calls
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
(with a fresh random seed) and `oqspubkey()` calls
[`fipspubkey()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md),
each after a deprecation warning from
[`.Deprecated()`](https://rdrr.io/r/base/Deprecated.html). The keys are
the same objects
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
returns, with the same classes.

## Security

The implementation is hand-written. Its standardised schemes are checked
byte for byte against OpenSSL 3.5 and NIST known-answer vectors in the
test suite. Side channels are checked, not assumed: `inst/ctcheck` runs
every operation that touches a secret under valgrind memcheck with the
secret marked undefined (the ctgrind method), so a branch or a memory
address that depends on it is a reported error, and afterwards scans the
dead stack for copies of the secret. Both checks run in CI on every
change, with GCC and with Clang. Timing is also measured on x86-64 and
arm64 hardware (`inst/dudect`), power leakage is assessed in simulation
under the value and the transition models (`inst/tvla`), and ML-KEM
decapsulation and ML-DSA signing are first-order masked by default.
These are checks of this code on those compilers and under those leakage
models; the README's security section lists what each check does and
does not cover.

## See also

[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md).

## Examples

``` r
# Deprecated: use fipskg().
key <- suppressWarnings(oqskg("ML-DSA-65"))
key$scheme
#> [1] "ML-DSA-65"

# The same as the current name, after a warning.
pub <- suppressWarnings(oqspubkey(key))
identical(pub, fipspubkey(key))
#> [1] TRUE

# The warning names the replacement.
tryCatch(oqskg(), warning = function(w) conditionMessage(w))
#> [1] "'oqskg' is deprecated.\nUse 'fipskg' instead.\nSee help(\"Deprecated\")"
```
