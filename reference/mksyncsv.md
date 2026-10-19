# Generate a Synthetic CSV From a Schema Recipe

Generates a reproducible synthetic data set from a recipe (the
`schema$synthetic_recipe` block of a provenance object, or a list
written by hand) and writes it to a CSV file. Each column is described
as in
[`mksyncol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md).
Next to the CSV it writes a `.synthetic` marker file, so the generated
rows can never be mistaken for real data later. Use it to share a
runnable version of an analysis without sharing restricted records.

## Usage

``` r
mksyncsv(schema, outpath, nrows = NULL, seed = NULL)
```

## Arguments

- schema:

  The synthetic recipe: a list with `columns` (a named list of column
  specs), and optional `nrows`, `seed` and `row_replication`.

- outpath:

  Character string: the path of the CSV to write.

- nrows:

  Whole number: the number of rows (persons, if replicating) to
  generate, from 1 to 100 million (the table is built in memory).
  Defaults to `schema$nrows`, then 50000.

- seed:

  Random seed for reproducibility. Defaults to `schema$seed`, then
  91735246.

## Value

Invisibly, an object of class `bricklayer_synthetic`: a list with
`path`, `sidecar` (the `<path>.synthetic` marker file;
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
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
replication the file therefore has more than `nrows` rows.

The data are drawn under `seed` and the caller's random number stream is
restored afterwards, so the same recipe and seed give the same file and
the surrounding analysis is not disturbed.

Side effects: writes `outpath` (overwriting it) and
`paste0(outpath, ".synthetic")`, a small JSON file with
`synthetic: true`, the row count, the seed, the recipe's SHA-256 and the
time; and marks the R session as having made synthetic data, so a
manifest built later in the same session is labelled synthetic. A
progress bar is shown in an interactive session.

Errors: `schema` not a list; any error from
[`mksyncol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md);
an unwritable `outpath`.

## See also

[`mksyncol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md),
[`vrfcps`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md).

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
res <- mksyncsv(recipe, out)
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

# nrows overrides the recipe's own row count.
mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows
#> [1] 5

# one to three rows per person
recipe$row_replication <- list(values = list(1, 2, 3))
mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows
#> [1] 6

try(mksyncsv("not a recipe", tempfile()))
#> Error : `schema` must be a schema list (columns = ..., ...)
```
