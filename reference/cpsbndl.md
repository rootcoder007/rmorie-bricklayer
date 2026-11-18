# Bundle a capsule into one signed artifact

Records a digest of every file named, the manifest's canonical digest,
and an attestation covering both, as a single JSON file. `cpsbndlvrf()`
re-hashes the files on disk and checks everything against it.

## Usage

``` r
cpsbndl(
  dir,
  man,
  key,
  files = NULL,
  ctx = NULL,
  prehash = "none",
  note = NULL,
  path = NULL
)

cpsbndlrd(path)

cpsbndlvrf(bundle, dir, man = NULL, keyexp = NULL, key = NULL, seen = NULL)
```

## Arguments

- dir:

  Character scalar, the directory the capsule lives in. For
  `cpsbndlvrf()`, the directory to check the files in.

- man:

  A manifest, as from
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md).
  It is required by `cpsbndl()` and optional for `cpsbndlvrf()`, where
  it adds a check that the manifest still has the bundled digest.

- key:

  For `cpsbndl()`, a signing key from
  [`fipskg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fipskg.md)
  or
  [`pqckg()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pqckg.md),
  or a shared secret (a string or raw vector) for an `"hmac"` bundle
  such as morie writes: the attestation then records the key's id, never
  the secret (see
  [`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)).
  For `cpsbndlvrf()`, the shared secret that checks an `"hmac"` bundle's
  signature; not used for the other schemes.

- files:

  Character vector of paths relative to `dir`. Defaults to every regular
  file in `dir` (recursively, dot-files included), excluding the bundle
  itself.

- ctx, prehash, note:

  As in
  [`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md).

- path:

  Character scalar. For `cpsbndlrd()`, the bundle file to read. For
  `cpsbndl()`, where to write the bundle (an existing file is
  overwritten).

  `capsule_bundle.json` inside `dir` is the default for `cpsbndl()`.

- bundle:

  A bundle read back with `cpsbndlrd()`, or the path to one.

- keyexp:

  Optional public key hex (for `"hmac"`, the key id) the bundle's
  attestation must carry. Supply it when you know which key should have
  signed: without it the check confirms the bundle is internally
  consistent, which any key's holder could arrange.

- seen:

  For `cpsbndlvrf()`, the XMSS signatures seen elsewhere, as
  [`xmssidxseen()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssidxseen.md)
  returns them, or `NULL`. For an XMSS bundle it adds an `xmss_index`
  row, failed (`"xmss index reused"`) when the same key signed the
  bundle's index with another signature: the key's state was copied or
  rolled back (RFC 10033, section 4).

## Value

`cpsbndl()`: the bundle, invisibly, a list of class `bricklayer_bundle`
with `files` (a list of `path`, `sha256`, `size_bytes`),
`manifest_digest`, `bundled_utc` and `attestation` (from
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)),
and the path it was written to as attribute `"path"`.

`cpsbndlrd()`: the same structure read from the file.

`cpsbndlvrf()`: a list of class `bricklayer_bundle_check` with `ok`
(logical) and `checks` (a data frame of `check`, logical `ok` and
`detail`: one `file:PATH` row per listed file, `no_unlisted_files`, a
failed `no_unsigned_fields` row when the bundle or its attestation holds
fields `cpsbndl()` does not write (no signature covers them), the
`attestation:` rows, with a manifest `manifest_digest`, and with `seen`
`xmss_index`). For an XMSS bundle the `attestation:signature` row's
detail names the signature's index and the key fingerprint.

## Details

The file digests are inside the signed payload, not alongside it. That
is the whole point: a list of hashes that is not itself signed can be
rewritten to match whatever the files now say, and a recipient who
re-hashes the files and compares them to that list learns only that the
list is consistent with itself.

What it establishes: the named files have not changed since signing, the
manifest has not changed, and both were signed together by the holder of
that key. What it does not: that the key belongs to anyone in
particular, or that the manifest's claims are true.

How it is built. Each file is hashed with SHA-256
([`sha256file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sha256file.md));
the payload is the list of `path`, `sha256` and `size_bytes`, the
manifest's
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md)
and the UTC time;
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
signs a manifest whose `meta` is that payload, and the bundle (payload
plus attestation) is written as pretty JSON with doubles at 17 digits.
With `files = NULL` every regular file under `dir` is hashed,
recursively and including dot-files (a `.Rprofile` dropped into a
capsule runs code), except the bundle file itself; a temporary left by a
write that was cut short (`.rmbl-*.tmp`) is refused, as the check
reports it. The folder is walked one level at a time: a link that stays
inside is content like any other file or folder, but a link to the
capsule folder or a folder above it, a link that leaves the folder, a
folder that cannot be read and links that would list one folder more
than 64 times are refused, all of them named at once. An empty folder
holds no content: it is not bundled and the check does not report it.
File names are kept by their bytes: a name that is UTF-8 is bundled in
every locale (C and Latin-1 too). A bundle lists only names that verify
on every system, so a name is refused, with its reason, when it is not
UTF-8 (its bytes shown as `<e9>`), starts with `~` or a drive letter
(`c:`), holds a backslash, a double quote, one of `< > : | ? *` or a
control character, or has a part that ends in a dot or a space or that
Windows reserves (CON, PRN, AUX, NUL, COM1 to COM9, LPT1 to LPT9, and
COM and LPT followed by a superscript 1, 2 or 3, with any extension),
letters compared by their ASCII bytes in every locale. Names that differ
only by letter case or by Unicode normalisation (`A.txt` and `a.txt`,
`sub/x` and `SUB/x`, an accented letter written as one character and as
a letter with a combining accent) are one name on Windows and macOS, so
they are refused together, each set named: every name and every folder
above one is compared by Unicode's canonical caseless match (the
canonical decomposition of the simple case folding of the canonical
decomposition, Unicode 15.1, section 3.13), from the Unicode Character
Database's tables and never the locale's. Simple folding maps one
character to one, so `ss` and a sharp s are two names (as Windows takes
them); the Turkish dotted capital I folds to an i with a dot above, not
to a plain i. The check of a bundle does not apply these rules, so a
bundle made before them still verifies. A progress bar is shown when
`options(morie.progress)` allows it.

Each file is read through the real path it had when it was checked,
below `dir`, so a link changed while the bundle is made is not followed
out of the folder. Before anything is signed every file is looked at
again: its real path, a link's target, its size and its modification and
status-change times must be those it had before it was read, and a file
of at most 1 MiB is read a second time and must give the same digest;
anything else stops `cpsbndl()` with the files named and nothing signed.
What remains unseen is a change to a file over 1 MiB that keeps its size
and both times: the system sets the status-change time on every write
and no program can set it back, so only a file system that records whole
seconds, written twice within one, can hide such a change.

How it is checked. `cpsbndlvrf()` re-hashes every listed file (a path
that is absolute or climbs out of `dir` fails its row), reports every
file on disk the bundle does not list (the bundle's own file excepted,
when it is the file checked: a `capsule_bundle.json` in `dir` is
unlisted when another bundle file is checked) and what the walk of `dir`
cannot cover (the links and folders `cpsbndl()` refuses), in the
`no_unlisted_files` row, checks the attestation with
[`cpschkatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
(signature, digest, and `keyexp` when given; an `"hmac"` signature needs
the shared secret as `key`), and, when `man` is given, compares its
digest with the bundled one. Every check is a row of `checks`; `ok` is
`TRUE` only when all pass. A failed check is a row, not an error.

Errors: `dir` missing or not a directory; no files to bundle, or a named
file not in `dir`, or a link whose target does not exist; the links,
folders and names above; a file changed while it was read; a file that
cannot be read, or a bundle file or its folder that cannot be written to
(all before any file is hashed); a key
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
cannot sign with; `cpsbndlrd()` given a file that is not a bundle, or
one over 32 MiB; `cpsbndlvrf()` given something other than a bundle or a
path. Reading a bundle whose signature records a stateful key's state
warns (see
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)).

## See also

[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md),
[`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md),
[`mnfdgst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfcanon.md).

## Examples

``` r
dir <- tempfile()
dir.create(dir)
write.csv(data.frame(x = 1:3), file.path(dir, "data.csv"),
          row.names = FALSE)
m <- mkmnf(list(dataset = "demo"), env = FALSE)
key <- fipskg("ML-DSA-44")

b <- cpsbndl(dir, m, key, note = "as published")
cpsbndlvrf(attr(b, "path"), dir, man = m)$ok
#> [1] TRUE

# touch a byte of the data and the bundle no longer holds
write.csv(data.frame(x = 1:4), file.path(dir, "data.csv"),
          row.names = FALSE)
res <- cpsbndlvrf(attr(b, "path"), dir, man = m)
res$ok
#> [1] FALSE
res$checks[!res$checks$ok, c("check", "detail")]
#>           check
#> 1 file:data.csv
#>                                                                                                                                            detail
#> 1 expected 95aecaa7399a39092c9e716ce1e18bb1c606c82f9503d679ac55c82988f6c38e, got 5140963bf019d514b126f382bc4c324b98109d2fd252c1858b60c821cff88c37

# read back, and checked against the key you expected to have signed
b2 <- cpsbndlrd(attr(b, "path"))
b2
#> ╭── Capsule bundle ───────────────────────────────────────────────────────────╮
#> │   Files            1                                                        │
#> │   Manifest digest  8995763848bcf59327ed818c561d5428a958cd82f86a60c91e416796 │
#> │                    0781a579                                                 │
#> │   Bundled          2026-11-18T03:42:44Z                                     │
#> │   Scheme           ML-DSA-44                                                │
#> │   Note             as published                                             │
#> │   Path             /tmp/Rtmp3LWqKW/file1fd417233c61/capsule_bundle.json     │
#> │                                                                             │
#> │   A signed list of the capsule's files and their digests; check the files   │
#> │   against it with cpsbndlvrf().                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
cpsbndlvrf(b2, dir, keyexp = "00ff")$ok
#> [1] FALSE

# a file added beside the bundle is reported too
writeLines("x", file.path(dir, "extra.txt"))
cpsbndlvrf(b2, dir)$checks[, c("check", "ok")]
#>                              check    ok
#> 1                    file:data.csv FALSE
#> 2                no_unlisted_files FALSE
#> 3 attestation:attestation_complete  TRUE
#> 4      attestation:manifest_digest  TRUE
#> 5            attestation:signature  TRUE

# a bundle signed with a shared secret (HMAC), as morie signs
dir2 <- tempfile()
dir.create(dir2)
writeLines("x,y", file.path(dir2, "d.csv"))
h <- cpsbndl(dir2, m, "shared-secret")
h$attestation$public  # the key id, not the secret
#> [1] "4e289ef69cbe6f4c0d7de16c0801ad1155aba1598f2f4b25cddb46880caacd60"
cpsbndlvrf(attr(h, "path"), dir2, key = "shared-secret",
           keyexp = h$attestation$public)$ok
#> [1] TRUE
# without the secret the signature row cannot pass
cpsbndlvrf(attr(h, "path"), dir2)$ok
#> [1] FALSE
unlink(dir2, recursive = TRUE)

# a directory that does not exist
try(cpsbndl(file.path(tempdir(), "no-such-capsule"), m, key))
#> Error : `dir` does not exist: /tmp/Rtmp3LWqKW/no-such-capsule
unlink(dir, recursive = TRUE)
```
