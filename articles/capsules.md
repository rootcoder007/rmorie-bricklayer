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

prov_json <- '{
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

prov_path <- file.path(tempdir(), "data_provenance.json")
writeLines(prov_json, prov_path)

prov <- load_provenance(prov_path)
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

url <- resolve_via_ckan(prov)            # package_show + name match
if (is.null(url))                        # slug-change fallback
  url <- resolve_via_ckan_search(prov)

path <- file.path(tempdir(), "data.csv")
friendly_download(url, path)             # plain-language failure diagnosis
                                         # + automatic Wayback fallback
```

This vignette stays offline, so we go straight to the fallback path.

## 3. Synthetic fallback: the pipeline always runs

When the real source is down,
[`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
generates a reproducible stand-in from the recipe pinned in the
provenance itself. Results from synthetic data are marked as such all
the way through (see the manifest below) — the point is to keep the
*pipeline* testable, never to pass synthetic output off as real.

``` r

data_path <- file.path(tempdir(), "data.csv")
gen <- make_synthetic_csv(prov$schema$synthetic_recipe, data_path)
gen$rows
#> [1] 25

df <- read.csv(data_path)
head(df, 3)
#>   year visits alert      id
#> 1 2025      2    No p-00001
#> 2 2024      2   Yes p-00002
#> 3 2024      2    No p-00003
```

## 4. Integrity and schema validation

Every file gets a SHA256; every data frame is checked against the pinned
schema.
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
reports issues without raising, so callers choose the severity response;
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
is the strict wrapper (fatal issues stop, drift warns).

``` r

digest <- sha256_file(data_path)
substr(digest, 1, 16)
#> [1] "e2f4b6752a2e3b56"

chk <- verify_sha256(data_path, digest)
chk$match
#> [1] TRUE

issues <- validate_schema(df, prov)
length(issues)   # 0 = clean against the pinned schema
#> [1] 0
```

## 5. The manifest: account for everything

[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md) +
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md)
accumulate named cross-checks (each PASS / DIFFER / INFO), and the
writers produce the two capsule artifacts: a machine-readable
`manifest.json` and a human-readable `SUMMARY.txt`.

``` r

man <- make_manifest(
  list(project = "demo-study", author = "A. Author", synthetic = TRUE),
  environment = FALSE  # TRUE also snapshots R/OS/package versions
)

man <- record(man, "rows_generated", observed = gen$rows, expected = 25)
#>   rows_generated                               observed = 25.0000      expected = 25.0000      [PASS]
man <- record(man, "mean_visits",
              observed = mean(df$visits), expected = 3,
              tol = 1, synthetic = TRUE)
#>   mean_visits                                  observed = 2.8000       expected = 3.0000       [INFO]

out_dir <- file.path(tempdir(), "capsule-demo")
dir.create(out_dir, showWarnings = FALSE)

write_manifest_json(man, file.path(out_dir, "manifest.json"))
summary_path <- write_summary_txt(
  man, out_dir,
  paths = list(input = data_path, results = out_dir),
  what_was_done = c("* generated synthetic stand-in (real source offline)",
                    "* validated schema and recorded cross-checks")
)

cat(readLines(summary_path)[7:12], sep = "\n")
#> Project:   demo-study
#> Author:    A. Author
#> When:      2026-07-25 20:00:39 UTC
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
([`core_sha256()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_sha256.md),
[`core_mean()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md),
[`core_var()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md),
[`core_cor()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_core_stats.md)).
