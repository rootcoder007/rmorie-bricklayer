# Curated datasets at data.rmorie.com

The MORIE project keeps databases materialised from Google BigQuery
public datasets (Chicago crime, EPA air quality, US census, FEC, FDA,
NOAA, NHTSA, Hacker News, Ethereum, World Bank, ...) and serves their
tables from the edge, under the data access terms at
<https://rmorie.com/data-license>. They open with the key
[`bricklayer_llm_login`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_llm_login.md)
stores, the same key rmorie and morie use; keys are personal and issued
on request at <https://rmorie.com/access>. The service address comes
from
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

  Fetch again even when a day-old copy is cached.

- key:

  A `db/table` key from the manifest.

## Value

`bricklayer_data_manifest()`: a list; `bricklayer_data_tables()`: a data
frame with `key`, `name`, `rows` and `source`; `bricklayer_data_load()`:
the table as a data frame.

## Examples

``` r
if (FALSE) { # \dontrun{
bricklayer_llm_login(token = "sk-...")  # a key issued at rmorie.com/access
head(bricklayer_data_tables())
df <- bricklayer_data_load("chicago_crime/incidents")
} # }
```
