# Check every capsule under a folder

Runs the checks of the rmbl GitHub Action on every capsule (a folder
holding `data_provenance.json` or `capsule_bundle.json`) under `path`:
each capsule file against its JSON Schema
([`schemapath`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schemapath.md)),
then
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
and
[`cpsbndlvrf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).
With `mode = "drift"` or `"refresh"` each source is fetched again and
compared with the pin, column by column
([`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
and
[`benfordtst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benfordtst.md));
`"refresh"` then writes and pins new bytes. `rmbl verify`, `drift` and
`report` call it. [`format()`](https://rdrr.io/r/base/format.html)
renders the Markdown report or the JSON, and
[`ghann`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md),
[`ghcmt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md)
and
[`ghout`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md)
the GitHub pieces.

## Usage

``` r
cpschk(
  path = ".",
  mode = c("verify", "drift", "refresh", "report"),
  key = "",
  pubkey = "",
  psiwarn = 0.1,
  psifail = 0.25,
  base = NULL,
  cache = NULL,
  allowfile = FALSE,
  snapshot = FALSE,
  wayback = FALSE,
  glob = "",
  fp = TRUE,
  seenlog = "",
  archive = FALSE
)

# S3 method for class 'rmbl_cpschk'
format(x, fmt = c("md", "json", "text"), failon = NULL, ...)

# S3 method for class 'rmbl_cpschk'
print(x, ...)
```

## Arguments

- path:

  Character scalar, the folder searched recursively (`.git` and
  `.rmbl-cache` folders skipped).

- mode:

  `"verify"` (the default), `"drift"`, `"refresh"` or `"report"` (the
  verify checks).

- key:

  Character scalar: the shared secret of HMAC bundles, or `""`.

- pubkey:

  Character scalar: the public key (hex) every bundle must be signed
  with (for an HMAC bundle, its key id), or `""`.

- psiwarn, psifail:

  Non-negative numbers, `psiwarn` at most `psifail`: the PSI bands, by
  default 0.1 and 0.25, the bands
  [`drftpsi`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftpsi.md)
  documents.

- base:

  `NULL` (no comparison); the path of one manifest file each manifest is
  compared with; a folder holding the base copy of the tree under `path`
  (the same relative paths); or a function that takes a manifest's path
  and returns the path of its base copy, or `NULL` when the base has
  none (for a git ref, write what `git show` prints to a file). Its
  `"label"` attribute names it in the report.

- cache:

  `NULL` (the default: the user cache folder,
  `tools::R_user_dir("rmoriebricklayer", "cache")`, in an interactive
  session, none otherwise), `FALSE` (none) or a folder.

- allowfile:

  `FALSE` (the default), `TRUE` to accept `file://` sources and local
  files anywhere under `path`, or an existing folder whose files may be
  sources as well. Without it a local source must be a file inside its
  own capsule; a fetched one is `https://` only (see
  [`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md)).

- snapshot:

  Logical: look up the latest Wayback snapshot of each http(s) source, a
  `snapshot` row (a note).

- wayback:

  Logical: with `"refresh"`, capture each changed http(s) source in the
  Wayback Machine first (archive.org keys, as
  [`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
  reads them).

- glob:

  Character scalar: check only the capsule files whose path matches this
  glob (`*` also matches `/`), or `""`.

- fp:

  Logical: measure the footprint of the checks
  ([`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md))
  for the last lines of the report.

- seenlog:

  Character scalar: an XMSS seen-log
  ([`xmssidxseen`](https://rootcoder007.github.io/rmorie-bricklayer/reference/xmssidxseen.md);
  `rmbl verify --seen-log`) read with the bundles under `path`, or `""`.
  Every XMSS bundle gets an `xmss_index` row, failed when the same key
  signed its index with another signature in what was seen.

- archive:

  Logical: use archive.rmorie.com when a source cannot be fetched. In
  `"drift"` and `"refresh"`, a source that neither answers nor has its
  pinned Wayback snapshot is fetched from a copy kept there with the
  pinned SHA-256 (public copies need no key); with `wayback = TRUE`, a
  changed source the Wayback Machine refuses is saved there instead
  (`wbsave(fallback = "rmorie")`, which needs a key:
  [`dlogin()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md)
  or `MORIE_HOSTED_KEY`).

- x:

  An `rmbl_cpschk` result.

- fmt:

  `"md"` (the Markdown report), `"json"` or `"text"` (the console
  summary [`print()`](https://rdrr.io/r/base/print.html) draws as a
  box).

- failon:

  Character scalar or `NULL`: the fail-on level, named in the report's
  last line.

- ...:

  Further arguments of [`format()`](https://rdrr.io/r/base/format.html)
  and [`print()`](https://rdrr.io/r/base/print.html), ignored.

## Value

A list of class `rmbl_cpschk`: `status`, `mode`, `path`, `glob`, `rows`
(a data frame of every check: `capsule`, `part`, `file`, `check`, `ok`,
`detail`, `severity` and `line`, the line of the file where known),
`capsules` (a list per capsule: `capsule`, `source`, `pinned_sha256`,
`fetched_sha256`, `changed`, `result`, `checks_passed`, `checks_total`
and `notes`, and where made `drift` with its `columns` table,
`drift_summary`, `snapshot`, `snapshot_utc` and `manifests`), `base`
(its label), `psiwarn`, `psifail` and `footprint` (the
[`co2fp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
result without its value, or `NULL`). The
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
result of each capsule whose columns were compared, with its provenance
and manifest diff, is in the attribute `drifts` (named by capsule), for
[`drfthtml`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drfthtml.md)
and
[`drftapp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftapp.md).
[`format()`](https://rdrr.io/r/base/format.html) returns one string
(`"md"`, `"json"`) or the lines of the console summary (`"text"`);
[`print()`](https://rdrr.io/r/base/print.html) draws that summary as a
box.

## Details

Each check is one row with a severity: `error`, `drift`, `warn` or
`note` (a note never changes a result). A capsule's result is the worst
severity among its failed rows, and `status` the worst over all
capsules: `ok`, `warn`, `drift` or `error`. Each failed row adds a note,
and one more from
[`explerr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/explerr.md)
where it finds what the row means or where its message is raised.

Drift: when the fetched source's SHA-256 differs from the pin and the
pinned data file is a CSV,
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
runs with `psithr = psifail`. A column is `drift` when
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
flags it and its PSI is above `psifail`, and `warn` when it is flagged
below that or its PSI is above `psiwarn`; an added or removed column is
drift. New bytes whose columns all stay within the bands are a note; new
bytes that cannot be compared are a warning.

Refresh: the new bytes are written as the data file and pinned in the
provenance as
[`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md)
does (refused when they fail the schema the provenance pins,
[`valsch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md));
with `wayback = TRUE` an http(s) source is first captured with
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md).
The capsule is then verified again.

Manifests: with `base`, each capsule's `manifest.json` and
`results/manifest.json` is compared with its base copy: the base's
recorded results against this copy's observed values, each within the
base's tolerance
([`mnfrcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfrcmp.md)),
and the resources of the two
([`mnfdiff`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mnfdiff.md)).
A manifest only one side has is added or removed.

Cache: a fetched source is kept in the cache folder under `source-` and
the first 16 hex digits of the SHA-256 of its URL, one file per source
overwritten by each fetch, and is read only when the live fetch fails.

Side effects: `"drift"` and `"refresh"` fetch each source (the network
for http(s) ones), as `snapshot = TRUE` asks the Wayback Machine once
per capsule
([`wbsnpurl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsnpurl.md));
`"refresh"` writes the capsules; a cache folder is written to. Errors:
`path` is not a directory; a bad argument. A capsule whose checks stop
is one failed row, not an error.

## See also

[`blcli`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blcli.md)
(the verbs),
[`ghann`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ghann.md),
[`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md),
[`explerr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/explerr.md).

## Examples

``` r
root <- tempfile("capsules-")
d <- usecpstmpl(file.path(root, "one"), ex = TRUE)
invisible(cpsrfrsh(d))
x <- cpschk(root, fp = FALSE)
x$status
#> [1] "ok"
x$rows[, c("check", "ok")]
#>                          check   ok
#> 1 schema: data_provenance.json TRUE
#> 2          provenance_readable TRUE
#> 3                 data_present TRUE
#> 4                  data_sha256 TRUE
#> 5              data_size_bytes TRUE
#> 6                data_readable TRUE
#> 7           data_not_synthetic TRUE
x
#> ╭── Capsule check (verify) ───────────────────────────────────────────────────╮
#> │ ✔ VERIFIED  · 7 of 7 checks passed                                          │
#> │                                                                             │
#> │   Status    ok                                                              │
#> │   Path      /tmp/RtmpNrNuyf/capsules-209256239d9d                           │
#> │   Capsules  1                                                               │
#> │   Checks    7 of 7 passed                                                   │
#> │   Checked   rmoriebricklayer 1.0.3, R version 4.6.1 (2026-06-24)            │
#> │                                                                             │
#> │   capsule  result  passed  checks                                           │
#> │   -------  ------  ------  ------                                           │
#> │   one      ok           7       7                                           │
#> │                                                                             │
#> │   capsule  source                                                           │
#> │   -------  --------------------------------------------------------------   │
#> │   one      /tmp/RtmpNrNuyf/temp_libpath20924a85c88c/rmoriebricklayer/e...   │
#> │                                                                             │
#> │   capsule  sha256        size    rows  bounds                               │
#> │   -------  ------------  ------  ----  ------                               │
#> │   one      6b1a0d2d11f6  0.5 KB  -     -                                    │
#> │                                                                             │
#> │   Every capsule is still the one its analysis was run on.                   │
#> │                                                                             │
#> │   /tmp/RtmpNrNuyf/capsules-209256239d9d/one: ok                             │
#> │     source:                                                                 │
#> │     /tmp/RtmpNrNuyf/temp_libpath20924a85c88c/rmoriebricklayer/extdata/otis_ │
#> │     a01_individuals.csv                                                     │
#> │     pinned SHA-256:                                                         │
#> │     6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248        │
#> │   ✔    schema: data_provenance.json  valid against capsule.schema.json      │
#> │   ✔    provenance_readable                                                  │
#> │        /tmp/RtmpNrNuyf/capsules-209256239d9d/one/data_provenance.json       │
#> │   ✔    data_present                                                         │
#> │        /tmp/RtmpNrNuyf/capsules-209256239d9d/one/otis_a01_individuals.csv   │
#> │   ✔    data_sha256                                                          │
#> │        6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248     │
#> │   ✔    data_size_bytes               462 bytes on disk                      │
#> │   ✔    data_readable                                                        │
#> │        /tmp/RtmpNrNuyf/capsules-209256239d9d/one/otis_a01_individuals.csv   │
#> │   ✔    data_not_synthetic no synthetic marker: sidecar, manifest and        │
#> │        provenance all say real data                                         │
#> │   format(x) gives the full Markdown report.                                 │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# the data changed: the digest row fails, and the notes say what it means
p <- loadprov(file.path(d, "data_provenance.json"))
cat("1,2\n", file = file.path(d, p$resource$filename), append = TRUE)
x <- cpschk(root, fp = FALSE)
x$status
#> [1] "error"
x$capsules[[1]]$notes
#> [[1]]
#> [1] "data_sha256: expected 6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248, got e0061f4de8d524e9a8a421b502ae878a4de372a841e6bdf3ac3a5140b86682c8"
#> 
#> [[2]]
#> [1] "explained: the data file's bytes differ from the pinned SHA-256: restore the file, or pin the new bytes with cpsrfrsh() (rmbl refresh)"
#> 
#> [[3]]
#> [1] "data_size_bytes: 466 bytes on disk"
#> 
#> [[4]]
#> [1] "explained: the data file's size differs from resource$size_bytes: its bytes changed"
#> 
substr(format(x, fmt = "json"), 1, 120)
#> [1] "{\n  \"status\": \"error\",\n  \"mode\": \"verify\",\n  \"path\": \"/tmp/RtmpNrNuyf/capsules-209256239d9d\",\n  \"capsules\": [\n    {\n    "

# drift: fetch the source again (here a local file) and compare
cpschk(root, "drift", psiwarn = 0.05, fp = FALSE)$status
#> [1] "error"

try(cpschk(tempfile()))
#> Error : cpschk: `path` is not an existing directory: /tmp/RtmpNrNuyf/file209225d348e0
try(cpschk(root, psiwarn = 1))
#> Error : cpschk: `psiwarn` (1) must not exceed `psifail` (0.25)
```
