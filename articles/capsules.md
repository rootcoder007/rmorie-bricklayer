# Building reproducible data capsules

`rmoriebricklayer` turns “the data was downloaded from the portal at
some point” into a verifiable, self-contained record: a **capsule**. A
capsule pins where the data came from, what its bytes hashed to, what
shape it must have, and — when the portal is unreachable — how to
synthesize a stand-in so the pipeline still runs end-to-end.

This vignette walks the essential flow with a small, fully offline
example:

1.  pin a source in a provenance record,
2.  validate data against the pinned schema,
3.  verify file integrity with SHA256,
4.  fall back to schema-driven synthetic data,
5.  account for every step in a manifest and plain-language summary.

``` r

library(rmoriebricklayer)
```

## 1. The provenance record

Everything starts from a `data_provenance.json` file: the
machine-readable pin of a project’s data source. It records the portal
endpoint, a pattern identifying the right resource, the expected SHA256,
the schema the data must satisfy, and a recipe for synthesizing a
stand-in.

``` r

provjson <- '{
  "dataset": {
    "title": "Demo library statistics",
    "ckan_api_endpoint": "https://data.ontario.ca/api/3/action/package_show?id=ontario-public-library-statistics"
  },
  "resource": { "name_match_pattern": "2014" },
  "schema": {
    "expected_columns": ["year", "visits", "alert"],
    "structural_invariants": { "min_data_rows": 5 },
    "expected_value_sets": { "year": [2024, 2025] },
    "synthetic_recipe": {
      "n_rows": 25,
      "seed": 42,
      "columns": {
        "year":   { "type": "sample",    "values": [2024, 2025] },
        "visits": { "type": "poisson",   "lambda": 3, "min": 1 },
        "alert":  { "type": "bernoulli", "p": 0.2 },
        "id":     { "type": "id_pattern", "pattern": "p-{seq:05d}" }
      }
    }
  }
}'

provpath <- file.path(tempdir(), "data_provenance.json")
writeLines(provjson, provpath)

prov <- loadprov(provpath)
prov$dataset$title
#> [1] "Demo library statistics"
```

## 2. Resolving the live source (network)

On a machine with network access, the resolvers turn the pinned endpoint
into a current download URL — surviving portal-side resource-UUID churn.
CKAN powers data.ontario.ca, data.gov.uk, and data.gov; Socrata and
ArcGIS resolvers cover the Chicago/NYC/Calgary and Toronto Police
portals.

``` r

url <- rslvckan(prov)            # package_show + name match
if (is.null(url))                        # slug-change fallback
  url <- rslvckns(prov)

path <- file.path(tempdir(), "data.csv")
fdl(url, path)             # plain-language failure diagnosis
                                         # + automatic Wayback fallback
```

This vignette stays offline, so we go straight to the fallback path.

## 3. Synthetic fallback: the pipeline always runs

When the real source is down,
[`mksyncsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncsv.md)
generates a reproducible stand-in from the recipe pinned in the
provenance itself. Results from synthetic data are marked as such all
the way through (see the manifest below) — the point is to keep the
*pipeline* testable, never to pass synthetic output off as real.

``` r

datapath <- file.path(tempdir(), "data.csv")
gen <- mksyncsv(prov$schema$synthetic_recipe, datapath)
gen$rows
#> [1] 25

df <- read.csv(datapath)
head(df, 3)
#>   year visits alert      id
#> 1 2025      2    No p-00001
#> 2 2024      2   Yes p-00002
#> 3 2024      2    No p-00003
```

## 4. Integrity and schema validation

Every file gets a SHA256; every data frame is checked against the pinned
schema.
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
reports issues without raising, so callers choose the severity response;
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)
is the strict wrapper (fatal issues stop, drift warns).

``` r

digest <- sha256file(datapath)
substr(digest, 1, 16)
#> [1] "e2f4b6752a2e3b56"

chk <- vrfsha256(datapath, digest)
chk$match
#> [1] TRUE

issues <- valsch(df, prov)
length(issues)   # 0 = clean against the pinned schema
#> [1] 0
```

## 5. The manifest: account for everything

[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md) +
[`recrd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recrd.md)
accumulate named cross-checks (each PASS / DIFFER / INFO), and the
writers produce the two capsule artifacts: a machine-readable
`manifest.json` and a human-readable `SUMMARY.txt`.

``` r

man <- mkmnf(
  list(project = "demo-study", author = "A. Author", synthetic = TRUE),
  env = FALSE  # TRUE also snapshots R/OS/package versions
)

man <- recrd(man, "rowsgenerated", obs = gen$rows, expd = 25)
#>   rowsgenerated                                observed = 25.0000      expected = 25.0000      [INFO]
man <- recrd(man, "meanvisits",
              obs = mean(df$visits), expd = 3,
              tol = 1, syn = TRUE)
#>   meanvisits                                   observed = 2.8000       expected = 3.0000       [INFO]

outdir <- file.path(tempdir(), "capsule-demo")
dir.create(outdir, showWarnings = FALSE)

wrmnfjs(man, file.path(outdir, "manifest.json"))
summarypath <- wrsmrytxt(
  man, outdir,
  paths = list(input = datapath, results = outdir),
  whatwasdone = c("* generated synthetic stand-in (real source offline)",
                    "* validated schema and recorded cross-checks")
)

cat(readLines(summarypath)[7:12], sep = "\n")
#> Project:   demo-study
#> Author:    A. Author
#> When:      2026-10-20 13:39:00 UTC
#> OS:        Linux
#> R:         R version 4.6.1 (2026-06-24)
#> Mode:      SYNTHETIC (not real data -- pipeline check only)
```

The capsule directory now contains everything a reviewer needs to trace
the run: the exact inputs, their digests, every cross-check with its
status, and a plain-language account — reproducible years later even if
the portal has moved on.

## Where this sits in the MORIE family

`rmoriebricklayer` is the provenance/reproducibility layer under
[rmorie](https://github.com/rootcoder007/rmorie) and
[rmoriedata](https://github.com/rootcoder007/rmoriedata); both link
against its compiled core (`LinkingTo: rmoriebricklayer`) for shared
SHA-256 and summary-statistic kernels
([`csha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/csha256.md),
[`cmn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md),
[`cvari()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md),
[`ccorr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cstat.md)).

## A capsule for an Indigenous health table

The same steps pin a Statistics Canada table: write it, record its
digest, and describe it in a manifest that names its source and licence.

``` r

d <- indiex("wellbeing")
f <- file.path(tempdir(), "indigenous_wellbeing.csv")
utils::write.csv(d, f, row.names = FALSE)
h <- sha256file(f)
m <- mkmnf(list(dataset = "indigenouswellbeing", rows = nrow(d), sha256 = h,
                        source = "Statistics Canada, Indigenous Peoples Survey 2022",
                        licence = "Statistics Canada Open Licence"),
                   env = FALSE)
vrfsha256(f, h)
#> $actual
#> [1] "c4b3e61f660856d89b302f1050393f99d84363ad7540b838ebecfbac5e4e5c2a"
#> 
#> $expected
#> [1] "c4b3e61f660856d89b302f1050393f99d84363ad7540b838ebecfbac5e4e5c2a"
#> 
#> $match
#> [1] TRUE
```
