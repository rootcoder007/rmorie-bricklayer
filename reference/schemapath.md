# Path of a JSON Schema shipped with the package

The capsule files are described by JSON Schema (draft 2020-12) documents
in the package's `schemas` folder, the same files as the `spec` folder
of the rmbl GitHub Action: `capsule` for `data_provenance.json`,
`bundle` for `capsule_bundle.json` and `manifest` for a results
manifest. `rmbl verify` checks each capsule file against its schema
before the package's own checks.

## Usage

``` r
schemapath(name)
```

## Arguments

- name:

  Character scalar: `"capsule"`, `"bundle"` or `"manifest"`, with or
  without the `.schema.json` ending.

## Value

The path of the installed schema file, a character scalar. Error: any
other name.

## See also

[`blcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
(the verify verb),
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md).

## Examples

``` r
schemapath("capsule")
#> [1] "/tmp/Rtmpmcz67L/temp_libpath1f1a14636f98/rmoriebricklayer/schemas/capsule.schema.json"
s <- fromjs(paste(readLines(schemapath("bundle")), collapse = "\n"))
s$required
#> [1] "files"           "manifest_digest" "bundled_utc"     "attestation"    

# only the four schemas exist
try(schemapath("nope"))
#> Error : schemapath: `name` must be capsule, bundle, manifest or ledger, not 'nope'
```
