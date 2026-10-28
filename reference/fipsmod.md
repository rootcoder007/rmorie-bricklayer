# Sign Inside a FIPS 140-3 Module

Finds the OpenSSL FIPS provider (a FIPS 140-3 cryptographic module),
loads it on its own, and reports which module it is and whether that
module is on the package's list of validated ones. Keys from
[`fipsmkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmkg.md)
are then made, and
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md)
signs with them, inside that module rather than in this package's own
code.

## Usage

``` r
fipsmod(
  openssl = Sys.which("openssl"),
  conf = getOption("rmbl.fips.conf", Sys.getenv("RMBL_FIPS_CONF"))
)
```

## Arguments

- openssl:

  Path to the `openssl` program. The default looks it up on the `PATH`.

- conf:

  Path to an OpenSSL configuration that loads the FIPS provider, or `""`
  to let the package write one.

## Value

A list of class `rmbl_fipsmod`: `name`, `version` and `build` (the
module as it reports itself), `status` (`"validated"`,
`"validated without PQC"` or `"not listed"`), `cmvp` (the certificate,
such as `"#5523"`, or `NA`), `pqc` (whether that certificate covers
ML-DSA and SLH-DSA), `openssl`, `openssl_version` and `conf`. It prints
as a box. The result is remembered for the session.

## Details

The package's own ML-DSA and SLH-DSA are not a validated module, and
FIPS mode does not change that. What it gives is a way to sign with a
module that is: a module listed as validated, run as this function runs
it, is used in its approved mode. Whether a given module is validated is
NIST's to say; the package only recognises the exact module names and
builds that a certificate names (the file `modules.csv` in the package's
`fips` folder), and says "not on the list" for every other one,
including a FIPS provider that may well be validated under a certificate
the list does not have yet.

The `openssl` program must be 3.5 or later (the first with ML-DSA and
SLH-DSA). Unless `conf` names a configuration, the package writes its
own to a private temporary folder: it loads only the FIPS provider and
the base provider, sets `default_properties = fips=yes`, and makes a
configuration error fatal, so nothing can quietly fall back to the
default provider. A distribution's own FIPS provider (Red Hat, Fedora,
Chainguard) loads as it is; an upstream build is first installed with
`openssl fipsinstall`, which runs the module's self-tests. Give `conf`
(or set the option `rmbl.fips.conf` or the environment variable
`RMBL_FIPS_CONF`) to use the configuration your organisation's FIPS
deployment prescribes instead.

Refusals: no `openssl` program, one older than 3.5, a FIPS provider that
is missing or does not load, or a `conf` file that does not exist.

## See also

[`fipsmkg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipsmkg.md),
[`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
[`cpsxvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsxvrf.md).

## Examples

``` r
# Only where an OpenSSL 3.5 FIPS provider is installed:
mod <- try(fipsmod(), silent = TRUE)
if (inherits(mod, "rmbl_fipsmod")) {
  print(mod)
  key <- fipsmkg("ML-DSA-44", mod)
  sig <- cpssign("a manifest digest", key)
  cpsvrf("a manifest digest", sig, key)
}
```
