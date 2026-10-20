# Fetch a capsule's source again and pin the new bytes

Downloads the source named in a capsule's `data_provenance.json`
(`resource$direct_url`, else `source$url`; a local path is read
directly), and when its bytes differ from the pin writes them as the
capsule's data file and pins them in the provenance, in the form the
`analysis.R` of
[`usecpstmpl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/usecpstmpl.md)
writes on its first run: `source$sha256`, and `resource$filename`,
`sha256`, `size_bytes` and `retrieved_utc` (`row_count_data_rows` too
when it was recorded).
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
then verifies the capsule against the new data. From the shell:
`rmbl refresh PATH`.

## Usage

``` r
cpsrfrsh(dir, allowfile = FALSE)
```

## Arguments

- dir:

  Character scalar, the capsule directory.

- allowfile:

  Logical: accept a `file://` source URL (a local path is always read).

## Value

The
[`mnfdiff`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)
of the provenance before and after: all `"unchanged"` when the source
still matches its pin.

## Details

Nothing is written when the bytes are unchanged. A download goes through
[`fdl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fdl.md),
with the provenance's `wayback$csv_snapshot` as its fallback. A capsule
bundle is not signed again: that needs your key
([`cpsbndl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)).
Side effects: writes the data file and `data_provenance.json` in `dir`.
Errors: `dir` is not a directory or holds no provenance; the provenance
names no source, or a `TODO` one, or a `file://` one without
`allowfile`; the source cannot be fetched; `resource$filename` is not a
plain relative path inside `dir`; the new data fail the schema the
provenance pins
([`valsch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)).

## See also

[`mnfdiff`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md),
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md),
[`usecpstmpl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/usecpstmpl.md).

## Examples

``` r
d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
cpsrfrsh(d)            # the first pin: the data file is added
#> Manifest diff: 0 changed, 1 added, 0 removed, 0 unchanged
#>   added     otis_a01_individuals.csv  sha256 - -> 6b1a0d2d11f6, - -> 462 bytes
vrfcps(d)$ok
#> [1] TRUE
cpsrfrsh(d)$change     # the source has not changed since
#> [1] "unchanged"

try(cpsrfrsh(tempfile()))
#> Error : cpsrfrsh: `dir` is not an existing directory: /tmp/RtmpxAJGDE/file1e1739fdacae
```
