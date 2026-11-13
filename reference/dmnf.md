# Curated datasets at data.rmorie.com

The MORIE project keeps databases materialised from Google BigQuery
public datasets (Chicago crime, EPA air quality, US census, FEC, FDA,
NOAA, NHTSA, Hacker News, Ethereum, World Bank, ...) and serves their
tables from the edge, under the data access terms at
`www.rmorie.com/data-license/`. They need no sign-in and no key. The
service address comes from
[`svcs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svcs.md).
`dmnf()` returns the gateway's manifest (every table with rows, columns,
size, SHA-256 and its BigQuery source), kept for a day; `dtabs()` the
same as a data frame; `dload("db/table")` one table as a data frame,
cached under [`tempdir()`](https://rdrr.io/r/base/tempfile.html) (or the
directory in `options(rmoriebricklayer.dcache = )`) so later calls are
local. From the shell: `rmoriebricklayer data list` and
`rmoriebricklayer data pull db/table [--out FILE.csv]`.

## Usage

``` r
dmnf(refresh = FALSE)

dtabs(refresh = FALSE)

dload(key, refresh = FALSE, token = NULL)
```

## Arguments

- refresh:

  Logical scalar, default `FALSE`: fetch again even when a day-old copy
  (of the manifest, or for `dload()` of the table) is cached.

- key:

  Character scalar, a `db/table` key from the manifest (the `key` column
  of `dtabs()`).

- token:

  Ignored, with a warning: the tables need no key, and none is sent.
  Kept so that calls written for earlier versions still run.

## Value

`dmnf()`: the manifest as a list (element `datasets`, one list per table
served with at least `key`, attribute `unserved` the number of tables
left out; and as the service provides them `rows`, `columns`, sizes, the
SHA-256 of the compressed file and the BigQuery `source`); `dtabs()`: a
data frame with `key`, `name` (the description, else the source, else
the key), integer `rows` and `source` (class `dtabs`, which prints one
left-aligned line per table, cut to the console width); `dload()`: the
table as a data frame.

## Details

The manifest is cached as `manifest.json` in the cache folder and
fetched again when it is more than a day old or `refresh = TRUE`. A
reply that is not a manifest (not a JSON object with a list of datasets
each carrying a `key`), or one that lists no tables while the cached
copy lists some, is refused and the cached copy kept.

`dload()` downloads `db/table.csv.gz` once into the cache folder (as
`db__table.csv.gz`) and checks its SHA-256 against the manifest before
every use, cached or not: a file that does not match is deleted and
refused (after one refresh of the manifest, since a table rebuilt
upstream has a new digest). When the manifest cannot be fetched, the
last copy on disk, however old, supplies the digest; with none, a fresh
download is not kept and a cached file is kept but not used. The CSV is
read in compiled code with the same result as
`read.csv(gzfile(f), stringsAsFactors = FALSE)`, two malformed shapes
apart, which are refused with the record they are in where
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) changes the data
without a word: a record with more fields than the header
([`read.csv()`](https://rdrr.io/r/utils/read.table.html) turns the first
column into row names) and a quote mark inside an unquoted field
([`read.csv()`](https://rdrr.io/r/utils/read.table.html) takes the rest
of the file as one quoted run). Tables that inflate past 512 MiB are
read by [`read.csv()`](https://rdrr.io/r/utils/read.table.html) itself,
a piece at a time. A table whose SHA-256 matches the manifest is the
file the service holds, so it is read whatever its size; one the
manifest lists without a digest may decompress to at most the option
`rmoriebricklayer.maxcsvbytes` (1 GiB by default). A large table needs
memory for all of it: a 1 GB decompressed CSV takes a few GB of RAM as a
data frame.

A table the manifest lists without any digest is used with a warning,
once per session and table.

`MORIE_DATA_URL` sets another address for the service (https and
public). No key is sent to either. Tables whose source terms do not
allow redistribution (ICPSR studies, among them the NCVS 38604 extract,
and any table the manifest marks restricted, with `access` other than
`"open"` or `"public"` or `restricted: true`) are not served: `dmnf()`
and `dtabs()` leave them out (the listing counts them in one line), and
`dload()` refuses them before any request, saying where to get them.
Downloads draw a progress bar when `options(morie.progress)` allows it.

Errors: `refresh` not `TRUE` or `FALSE`; the service unavailable; a
`key` that is not of the form `db/table`, not listed in the manifest, or
a table that is not served; a digest mismatch.

## See also

[`svcs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svcs.md).

## Examples

``` r
# Offline, against a cache folder holding a manifest and one table made
# here (nothing is fetched).
cache <- file.path(tempdir(), "data-hub-example")
dir.create(cache)
old <- options(rmoriebricklayer.dcache = cache)
f <- file.path(cache, "demo__counts.csv.gz")
con <- gzfile(f, "w")
write.csv(
  data.frame(region = c("a", "b"), n = c(3L, 5L)),
  con,
  row.names = FALSE
)
close(con)
m <- list(
  datasets = list(list(
    key = "demo/counts",
    rows = 2,
    source = "an example",
    meta = list(description = "Counts by region"),
    sha256_gz = csha256(readBin(f, "raw", file.size(f)))
  ))
)
writeLines(tojs(m, auto_unbox = TRUE), file.path(cache, "manifest.json"))

dtabs()
#> ╭── Curated tables at data.rmorie.com ──╮
#> │   Tables  1                           │
#> │                                       │
#> │   key          rows  name             │
#> │   demo/counts     2  Counts by region │
#> │                                       │
#> │   1 tables; dload("KEY") loads one    │
#> ╰───────────────────────────────────────╯
dload("demo/counts")
#>   region n
#> 1      a 3
#> 2      b 5

# keys are checked against the manifest
try(dload("counts"))
#> Error : key must be db/table (see dtabs())
try(dload("demo/other"))
#> Error : no table demo/other at data.rmorie.com (`rmoriebricklayer data list` shows them)

# a cached file that no longer matches its digest is deleted and refused
writeBin(as.raw(1:10), f)
try(dload("demo/counts"))
#> Error : demo/counts does not match the manifest's SHA-256 (c848e1013f9f... vs c346413f308c...): the cached file was deleted; run again to download it, and if it still fails the file was tampered with in transit
file.exists(f)
#> [1] FALSE

options(old)
unlink(cache, recursive = TRUE)
if (FALSE) { # interactive()
# the real service: needs the network, no sign-in
head(dtabs())
df <- dload("chicago_crime/incidents")
}
```
