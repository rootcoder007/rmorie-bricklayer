# Curated datasets at data.rmorie.com

The MORIE project keeps databases materialised from Google BigQuery
public datasets (Chicago crime, EPA air quality, US census, FEC, FDA,
NOAA, NHTSA, Hacker News, Ethereum, World Bank, ...) and serves their
tables from the edge, under the data access terms at
<https://www.rmorie.com/data-license/>. They open with the key
[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)
stores, the same key rmorie and morie use; keys are personal: sign in
with GitHub or an emailed code, or ask at
<https://www.rmorie.com/access/>. The service address comes from
[`bricklayer_services`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_services.md).
`bricklayer_data_manifest()` returns the gateway's manifest (every table
with rows, columns, size, SHA-256 and its BigQuery source), kept for a
day; `bricklayer_data_tables()` the same as a data frame;
`bricklayer_data_load("db/table")` one table as a data frame, cached
under [`tempdir()`](https://rdrr.io/r/base/tempfile.html) (or the
directory in `options(rmoriebricklayer.data_cache = )`) so later calls
are local. From the shell: `rmoriebricklayer data list` and
`rmoriebricklayer data pull db/table [--out FILE.csv]`.

## Usage

``` r
bricklayer_data_manifest(refresh = FALSE)

bricklayer_data_tables(refresh = FALSE)

bricklayer_data_load(key, refresh = FALSE)
```

## Arguments

- refresh:

  Logical scalar, default `FALSE`: fetch again even when a day-old copy
  (of the manifest, or for `bricklayer_data_load()` of the table) is
  cached.

- key:

  Character scalar, a `db/table` key from the manifest (the `key` column
  of `bricklayer_data_tables()`).

## Value

`bricklayer_data_manifest()`: the manifest as a list (element
`datasets`, one list per table with at least `key`, and as the service
provides them `rows`, `columns`, sizes, the SHA-256 of the compressed
file and the BigQuery `source`); `bricklayer_data_tables()`: a data
frame with `key`, `name` (the description, else the source, else the
key), integer `rows` and `source` (class `bricklayer_data_tables`, which
prints one left-aligned line per table, cut to the console width);
`bricklayer_data_load()`: the table as a data frame.

## Details

The manifest is cached as `manifest.json` in the cache folder and
fetched again when it is more than a day old or `refresh = TRUE`. A
reply that is not a manifest (not a JSON object with a list of datasets
each carrying a `key`), or one that lists no tables while the cached
copy lists some, is refused and the cached copy kept.

`bricklayer_data_load()` downloads `db/table.csv.gz` once into the cache
folder (as `db__table.csv.gz`) and checks its SHA-256 against the
manifest before every use, cached or not: a file that does not match is
deleted and refused (after one refresh of the manifest, since a table
rebuilt upstream has a new digest). When the manifest cannot be fetched,
the last copy on disk, however old, supplies the digest; with none, a
fresh download is not kept and a cached file is kept but not used. The
CSV is read in compiled code with the same result as
`read.csv(gzfile(f), stringsAsFactors = FALSE)`; tables that inflate
past 512 MiB are read by
[`read.csv()`](https://rdrr.io/r/utils/read.table.html) itself, a piece
at a time. A table that decompresses to more than the option
`rmoriebricklayer.max_csv_bytes` (1 GiB by default) is refused.

The key is sent only to the address of the signed services document.
With `MORIE_DATA_URL` set to another address the key is not sent and the
download fails with a message saying so. Some tables (ICPSR studies, the
NCVS 38604 extract, the A2AJ case law) open only after their terms are
accepted at <https://data.rmorie.com/terms>. Downloads draw a progress
bar when `options(morie.progress)` allows it.

Errors: `refresh` not `TRUE` or `FALSE`; no key stored (the message says
how to sign in); the service unavailable, or the key rejected; a `key`
that is not of the form `db/table`, or not listed in the manifest; a
digest mismatch; a restricted table whose terms were not accepted.

## See also

[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md),
[`bricklayer_services`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_services.md).

## Examples

``` r
# Offline, against a cache folder holding a manifest and one table made
# here (no key is stored and nothing is fetched).
old_env <- Sys.getenv(c("XDG_CONFIG_HOME", "MORIE_HOSTED_KEY"), unset = NA)
Sys.setenv(XDG_CONFIG_HOME = tempfile())
Sys.unsetenv("MORIE_HOSTED_KEY")
cache <- file.path(tempdir(), "data-hub-example")
dir.create(cache)
old <- options(rmoriebricklayer.data_cache = cache)
f <- file.path(cache, "demo__counts.csv.gz")
con <- gzfile(f, "w")
write.csv(data.frame(region = c("a", "b"), n = c(3L, 5L)), con, row.names = FALSE)
close(con)
m <- list(datasets = list(list(key = "demo/counts", rows = 2, source = "an example",
                               meta = list(description = "Counts by region"),
                               sha256_gz = core_sha256(readBin(f, "raw", file.size(f))))))
writeLines(bricklayer_json_to_json(m, auto_unbox = TRUE),
           file.path(cache, "manifest.json"))

bricklayer_data_tables()
#> key          rows  name
#> demo/counts     2  Counts by region
#> 
#> 1 tables; bricklayer_data_load("KEY") loads one
bricklayer_data_load("demo/counts")
#>   region n
#> 1      a 3
#> 2      b 5

# keys are checked against the manifest
try(bricklayer_data_load("counts"))
#> Error : key must be db/table (see bricklayer_data_tables())
try(bricklayer_data_load("demo/other"))
#> Error : no table demo/other at data.rmorie.com (`rmoriebricklayer data list` shows them)

# a cached file that no longer matches its digest is deleted and refused
writeBin(as.raw(1:10), f)
try(bricklayer_data_load("demo/counts"))
#> Error : demo/counts does not match the manifest's SHA-256 (c848e1013f9f... vs c346413f308c...): the cached file was deleted; run again to download it, and if it still fails the file was tampered with in transit
file.exists(f)
#> [1] FALSE

options(old)
unlink(cache, recursive = TRUE)
for (v in names(old_env)) {
  if (is.na(old_env[[v]])) Sys.unsetenv(v) else do.call(Sys.setenv, as.list(old_env[v]))
}
if (FALSE) { # \dontrun{
# the real service: needs a key and the network
bricklayer_llm_login(token = "sk-...")  # a key issued at www.rmorie.com/access/
head(bricklayer_data_tables())
df <- bricklayer_data_load("chicago_crime/incidents")
} # }
```
