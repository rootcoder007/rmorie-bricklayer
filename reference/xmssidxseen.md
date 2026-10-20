# Find XMSS signature indices used twice

Lists every XMSS signature in the capsule bundles under a directory, and
in seen-logs, and marks an index that one key signed with two different
signatures. An XMSS index must sign once: two signatures at one index
let anyone forge a third message, so a reused index means the key's
state was copied or rolled back (RFC 10033, section 4: a verifier that
sees all of a signer's signatures can detect reuse, since each carries
its index).

## Usage

``` r
xmssidxseen(path = ".", seenlog = NULL)
```

## Arguments

- path:

  A directory (every `capsule_bundle.json` under it) or one bundle file.

- seenlog:

  Seen-log files to read as well, or NULL. A file that does not exist
  yet is an empty log; a directory, or a log with a malformed line, is
  refused.

## Value

A data frame, one row per signature seen: `key` (the key fingerprint,
the first 16 hex characters of SHA-256 over the public key), `index`,
`sig` (a digest of the signature), `where` (the file) and `reused`
(`TRUE` when this key signed this index with another signature too).

## Details

A seen-log is the text file `rmbl sign --seen-log FILE` appends to: one
line per signature it made, with the key fingerprint, the index, a
digest of the signature and the bundle it went into, tab-separated;
lines starting with `#` are comments. The same signature found twice
(one bundle copied to two places, or a bundle and its log line) is not a
reuse.

## See also

[`cpsbndlvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md)
(its `seen` argument),
[`blcli()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
(`rmbl sign --seen-log`),
[`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md).

## Examples

``` r
op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
# one-time index record out of your configuration directory
root <- tempfile("capsules-")
d <- file.path(root, "one")
dir.create(d, recursive = TRUE)
writeLines("x\n1", file.path(d, "data.csv"))
key <- pqckg(height = 2)
b <- cpsbndl(d, mkmnf(list(), env = FALSE), key)
xmssidxseen(root)
#>                key index              sig
#> 1 71e6aa17e3f6bd2d     0 da0fa94d9b3664e2
#>                                                          where reused
#> 1 /tmp/RtmpLNUrYh/capsules-1eda58d5864/one/capsule_bundle.json  FALSE

# the same index signed again from a stale copy of the key: reused
e <- file.path(root, "two")
dir.create(e)
writeLines("x\n2", file.path(e, "data.csv"))
invisible(xmssfgt(key))  # forget the record, as a copy on another machine would
b2 <- cpsbndl(e, mkmnf(list(), env = FALSE), key)
xmssidxseen(root)[, c("index", "reused")]
#>   index reused
#> 1     0   TRUE
#> 2     0   TRUE

try(xmssidxseen(tempfile()))
#> Error : xmssidxseen: `path` is not an existing directory or bundle file: /tmp/RtmpLNUrYh/file1eda7da58013
options(op)
```
