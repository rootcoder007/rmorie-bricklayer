# Generate a Synthetic CSV From a Schema Recipe

Generates a reproducible synthetic data set from the
`schema$synthetic_recipe` block of a provenance object and writes it to
a CSV. Columns are produced in declaration order so later columns can
reference earlier ones, a shared per-row latent propensity drives any
Bernoulli columns, and an optional row-replication block expands
per-person rows.

## Usage

``` r
make_synthetic_csv(schema, out_path, n_rows = NULL, seed = NULL)
```

## Arguments

- schema:

  The synthetic recipe (a list with `columns`, and optional `n_rows`,
  `seed`, and `row_replication`).

- out_path:

  Path where the CSV is written.

- n_rows:

  Number of rows (persons, if replicating) to generate. Defaults to
  `schema$n_rows`, then 50000.

- seed:

  Random seed for reproducibility. Defaults to `schema$seed`, then
  91735246.

## Value

Invisibly, a list with `path`, `rows` (rows written), and `seed` used.
