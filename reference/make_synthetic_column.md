# Generate One Synthetic Column From a Spec

Builds a single synthetic data column according to a column spec drawn
from a provenance synthetic recipe. Supported `type`s are `"sample"`
(categorical, optionally weighted), `"bernoulli"` (two-label draw with
optional per-row base rate), `"poisson"` (counts with a floor),
`"id_pattern"` (templated IDs, optionally per-year sequenced), and
`"sequence"` (a running integer sequence).

## Usage

``` r
make_synthetic_column(spec, n, ctx = list(), base_p = NULL)
```

## Arguments

- spec:

  A list describing the column; recognised fields depend on `spec$type`
  (e.g. `values`, `weights`, `p`, `p_with_baserate`, `labels`, `lambda`,
  `min`, `pattern`, `year_col`, `from`).

- n:

  Number of values to generate.

- ctx:

  Named list of already-generated columns, letting later columns (such
  as `id_pattern` with a `year_col`) reference earlier ones. Defaults to
  an empty list.

- base_p:

  Optional numeric vector of per-row latent propensities used by the
  `"bernoulli"` type to add row-level variation.

## Value

A vector of length `n` for the requested column type. Errors on an
unknown `type`.
