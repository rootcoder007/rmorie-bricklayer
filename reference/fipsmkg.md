# Make a Signing Key Inside a FIPS 140-3 Module

Generates an ML-DSA or SLH-DSA key pair inside the module that
[`fipsmod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmod.md)
found. The private key stays in the module's own format (PEM) and never
passes through this package's code;
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
hands it back to the module to sign. The public key is the standard one,
so the signatures verify with
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
(this package's implementation), with
[`cpsxvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsxvrf.md)
(OpenSSL's), and anywhere else FIPS 204 and 205 are implemented.

## Usage

``` r
fipsmkg(scheme = "SLH-DSA-SHA2-128s", mod = fipsmod())
```

## Arguments

- scheme:

  An ML-DSA or SLH-DSA parameter set (see
  [`fipssz()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipssz.md)),
  such as `"ML-DSA-65"`; the default, `"SLH-DSA-SHA2-128s"`, is
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)'s.

- mod:

  The module, from
  [`fipsmod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmod.md).

## Value

A key of class `rmbl_fipsmod_key` (also a `bricklayer_fips_public_key`,
so every verifier accepts it): `public` (hex), `scheme`, `module` (name,
build, status and certificate) and the private key in `pem`.

## Details

The key prints without its private part. It is an ordinary R object:
anything that saves it
([`saveRDS()`](https://rdrr.io/r/base/readRDS.html), a workspace) saves
the private key too, so keep it as carefully as any other private key.
Signing checks that the module loaded now is the one that made the key
and refuses otherwise. XMSS and HQC have no FIPS module and are refused.

## See also

[`fipsmod()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmod.md),
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
for keys made by this package's own code.

## Examples

``` r
mod <- try(fipsmod(), silent = TRUE)
if (inherits(mod, "rmbl_fipsmod")) {
  key <- fipsmkg("SLH-DSA-SHA2-128s", mod)
  key
}
```
