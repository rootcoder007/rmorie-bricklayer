# rmoriebricklayer

[![r-universe](https://rootcoder007.r-universe.dev/badges/rmoriebricklayer)](https://rootcoder007.r-universe.dev/rmoriebricklayer)

> Brick-proof, reproducible data capsules for R.

`rmoriebricklayer` resolves open-data sources, records and verifies
provenance, validates downloaded data against a pinned schema, and falls
back to schema-driven synthetic data when the real source is unreachable —
so any analysis result can be traced back to its exact inputs.

## What it does

- **CKAN resolution** — `resolve_via_ckan()` / `resolve_via_ckan_search()`
  locate resources through a portal's `package_show` / `package_search`
  endpoints.
- **Provenance** — `load_provenance()`, `make_manifest()`, `record()`,
  `write_manifest_json()`, and `write_summary_txt()` capture every run as a
  manifest plus a plain-language summary.
- **Integrity** — `sha256_file()` / `verify_sha256()` hash and verify
  downloads; `download_data()` / `friendly_download()` fetch with a Wayback
  Machine fallback.
- **Schema validation** — `validate_schema()` / `apply_schema_validation()`
  check data against a pinned schema.
- **Synthetic fallback** — `make_synthetic_column()` / `make_synthetic_csv()`
  generate schema-driven stand-ins when the real source is down, so a
  pipeline still runs end-to-end.

## Installation

```r
install.packages(
  "rmoriebricklayer",
  repos = c("https://rootcoder007.r-universe.dev",
            "https://cloud.r-project.org")
)
```

Development version from GitHub:

```r
# install.packages("remotes")
remotes::install_github("rootcoder007/rmorie-bricklayer")
```

## Quick example

```r
library(rmoriebricklayer)

prov <- load_provenance("provenance.json")     # pinned source + schema + hash
res  <- resolve_via_ckan(prov)                  # find the resource on the portal
path <- friendly_download(res$url, "data.csv")  # download (Wayback fallback)
verify_sha256(path, prov$sha256)                # integrity check
df   <- validate_schema(read.csv(path), prov)   # schema-validated data frame

man  <- make_manifest(project = "my-study")
record(man, "input", path)                      # trace the input
write_manifest_json(man, "manifest.json")
```

## Part of the MORIE family

`rmoriebricklayer` is the reproducibility / provenance layer of the
[MORIE](https://github.com/rootcoder007/morie) ecosystem, alongside
[rmorie](https://github.com/rootcoder007/rmorie) and
[rmoriedata](https://github.com/rootcoder007/rmoriedata).

## Citation

If you use rmoriebricklayer in your research, please cite the software:

> Ruhela, V. S. (2026). *rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback.* https://github.com/rootcoder007/rmorie-bricklayer

BibTeX (or run `citation("rmoriebricklayer")` after installation for the entry
stamped with the exact installed version, sourced from `inst/CITATION`):

```bibtex
@Manual{ruhela_rmoriebricklayer_2026,
  title  = {rmoriebricklayer: Reproducible Data Capsules with Provenance and Fallback},
  author = {Ruhela, Vansh Singh},
  year   = {2026},
  url    = {https://github.com/rootcoder007/rmorie-bricklayer}
}
```

See [`CITATION.cff`](https://github.com/rootcoder007/rmorie-bricklayer/blob/main/CITATION.cff) for the
machine-readable metadata GitHub's "Cite this repository" button uses.

## License

AGPL-3.0-or-later.
