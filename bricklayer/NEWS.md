# rmoriebricklayer 0.2.5

* `make_synthetic_column("id_pattern")` without a `year_col` now returns
  all `n` ids (a vectorised-`gsub` misuse returned a single id).
* `bernoulli` columns unlist JSON-derived `labels`, fixing mangled
  column names from provenance-parsed schemas.
* Single-value `row_replication` no longer trips base R's scalar
  `sample()` expansion.
* Test suite grown from 9 to 43 behavioural tests covering the full
  export surface (provenance, CKAN guards, Wayback handling, offline
  file:// downloads, sha256, schema validation, manifests, synthetic
  generation, RNG hygiene).

# rmoriebricklayer 0.2.4

* `make_synthetic_csv()` now restores the caller's `.Random.seed` on exit
  (CRAN policy: no lasting RNG-state change).
* First CRAN submission prep: `cran-comments.md`, build exclusions.

# rmoriebricklayer 0.2.3

* Capsule terminology adopted across the documentation; CITATION added;
  37/37 reproduction checks in `examples/otis-mrp/`.
