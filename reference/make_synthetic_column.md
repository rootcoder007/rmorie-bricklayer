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

## Examples

``` r
set.seed(1)
# "sample": categorical draw, optionally weighted.
make_synthetic_column(list(type = "sample", values = list("a", "b"),
                           weights = list(0.7, 0.3)), 5)
#> [1] "a" "a" "a" "b" "a"

# "bernoulli": two-label draw at probability p.
make_synthetic_column(list(type = "bernoulli", p = 0.5,
                           labels = list("Yes", "No")), 5)
#> [1] "No"  "No"  "No"  "No"  "Yes"

# "poisson": counts with a floor via `min`.
make_synthetic_column(list(type = "poisson", lambda = 3, min = 1), 5)
#> [1] 2 1 4 2 4

# "id_pattern": templated IDs (the {seq:05d} token is zero-padded).
make_synthetic_column(list(type = "id_pattern",
                           pattern = "case-{seq:05d}"), 3)
#> [1] "case-00001" "case-00002" "case-00003"

# "sequence": a running integer sequence from `from`.
make_synthetic_column(list(type = "sequence", from = 100), 4)
#> [1] 100 101 102 103

# An unknown type errors.
try(make_synthetic_column(list(type = "nope"), 3))
#> Error in make_synthetic_column(list(type = "nope"), 3) : 
#>   Unknown synthetic column type: nope
```
