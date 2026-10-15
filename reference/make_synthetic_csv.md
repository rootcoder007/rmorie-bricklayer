# Generate a Synthetic CSV From a Schema Recipe

Generates a reproducible synthetic data set from a recipe (the
`schema$synthetic_recipe` block of a provenance object, or a list
written by hand) and writes it to a CSV file. Each column is described
as in
[`make_synthetic_column`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md).
Next to the CSV it writes a `.synthetic` marker file, so the generated
rows can never be mistaken for real data later. Use it to share a
runnable version of an analysis without sharing restricted records.

## Usage

``` r
make_synthetic_csv(schema, out_path, n_rows = NULL, seed = NULL)
```

## Arguments

- schema:

  The synthetic recipe: a list with `columns` (a named list of column
  specs), and optional `n_rows`, `seed` and `row_replication`.

- out_path:

  Character string: the path of the CSV to write.

- n_rows:

  Whole number: the number of rows (persons, if replicating) to
  generate. Defaults to `schema$n_rows`, then 50000.

- seed:

  Random seed for reproducibility. Defaults to `schema$seed`, then
  91735246.

## Value

Invisibly, an object of class `bricklayer_synthetic`: a list with
`path`, `sidecar` (the `<path>.synthetic` marker file;
[`verify_capsule`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
treats its presence as a failed check), `rows` (rows written), `seed`
(the seed used) and `recipe_sha256` (the recipe's digest, `NA` when it
could not be computed). Its print method labels the file as synthetic.

## Details

Columns are produced in declaration order so later columns can reference
earlier ones. A shared per-person latent propensity, uniform on \\\[0,
1\]\\, drives every `"bernoulli"` column through its `p_with_baserate`
field, so those columns are correlated with each other. An optional
`row_replication` block (`values` and `weights`) draws how many rows
each person gets: person-level columns are drawn once per person and
repeated, while `"bernoulli"` columns are drawn once per row. With
replication the file therefore has more than `n_rows` rows.

The data are drawn under `seed` and the caller's random number stream is
restored afterwards, so the same recipe and seed give the same file and
the surrounding analysis is not disturbed.

Side effects: writes `out_path` (overwriting it) and
`paste0(out_path, ".synthetic")`, a small JSON file with
`synthetic: true`, the row count, the seed, the recipe's SHA-256 and the
time; and marks the R session as having made synthetic data, so a
manifest built later in the same session is labelled synthetic. A
progress bar is shown in an interactive session.

Errors: `schema` not a list; any error from
[`make_synthetic_column`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md);
an unwritable `out_path`.

## See also

[`make_synthetic_column`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md),
[`verify_capsule`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md).

## Examples

``` r
recipe <- list(
  n_rows = 20, seed = 42,
  columns = list(
    year   = list(type = "sample", values = list(2024, 2025)),
    alert  = list(type = "bernoulli", p = 0.2),
    visits = list(type = "poisson", lambda = 3, min = 1),
    id     = list(type = "id_pattern", pattern = "p-{seq:05d}")
  )
)
out <- tempfile(fileext = ".csv")
res <- make_synthetic_csv(recipe, out)
res$rows # 20
#> [1] 20
res$seed # 42 (reproducible)
#> [1] 42

# The written CSV round-trips and has the declared columns.
df <- utils::read.csv(out)
dim(df)
#> [1] 20  4
names(df)
#> [1] "year"   "alert"  "visits" "id"    

# and the marker file says it is synthetic
file.exists(res$sidecar)
#> [1] TRUE

# n_rows overrides the recipe's own row count.
make_synthetic_csv(recipe, tempfile(fileext = ".csv"), n_rows = 5)$rows
#> [1] 5

# one to three rows per person
recipe$row_replication <- list(values = list(1, 2, 3))
make_synthetic_csv(recipe, tempfile(fileext = ".csv"), n_rows = 5)$rows
#> [1] 6

try(make_synthetic_csv("not a recipe", tempfile()))
#> Error : `schema` must be a schema list (columns = ..., ...)
```
