# Generate One Synthetic Column From a Spec

Builds one column of synthetic (made-up) data from a short
specification, such as “sample these categories with these weights” or
“Poisson counts with mean 25”. It is the building block of
[`mksyncsv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncsv.md),
which assembles a whole table from a recipe. Use synthetic columns to
develop and test an analysis pipeline before, or instead of, touching
restricted data.

## Usage

``` r
mksyncol(spec, n, ctx = list(), basep = NULL)
```

## Arguments

- spec:

  A list describing the column: `type` and the fields listed in Details.
  Lists as parsed from JSON (for example `values = list("a", "b")`) are
  accepted.

- n:

  Whole number: how many values to generate.

- ctx:

  Named list of already-generated columns. Later columns can then
  reference earlier ones, as `id_pattern` does with a `year_col`.
  Defaults to an empty list.

- basep:

  Optional numeric vector of per-row latent propensities in \\\[0,
  1\]\\, length `n`, used by the `"bernoulli"` type to add row-level
  variation. Default `NULL`.

## Value

A vector for the requested column type: character for `"sample"` of
strings, `"bernoulli"` and `"id_pattern"`, numeric or integer for
`"poisson"` and `"sequence"` (and for `"sample"` of numbers). Its length
is `n`, except for `"id_pattern"` with a `year_col`.

## Details

The supported `spec$type`s and the fields each reads (defaults in
parentheses):

- `"sample"` (the default type):

  `values`, a vector or list of categories; `weights` (default equal),
  their probabilities. Drawn with replacement.

- `"bernoulli"`:

  `p` (default 0.1), the probability of the first label; `labels`
  (default `c("Yes", "No")`); `p_with_baserate` (default 0), added as
  `p_with_baserate * basep` to give row-level variation when `basep` is
  supplied. A per-row probability above 1 behaves as 1.

- `"poisson"`:

  `lambda` (default 1); `min` (default 0), a floor: draws below it are
  raised to it (so the result is not Poisson below the floor).

- `"id_pattern"`:

  `pattern` (default `"id-\{seq:05d\}"`), in which `{seq:05d}` becomes a
  five-digit zero-padded sequence number and `{year}` the year;
  `year_col`, the name of a column in `ctx` whose values supply `{year}`
  and restart the sequence within each year. With `year_col`, that
  column must have `n` values. No other tokens are recognised.

- `"sequence"`:

  `from` (default 1): `from, from + 1, ...`.

- `"fitted"`:

  `fit`, a
  [`dstfit`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstfit.md)
  result, and `family` (default the first-ranked converged fit): draws
  from that fitted distribution.

Random draws use R's random number generator, so call
[`set.seed()`](https://rdrr.io/r/base/Random.html) first for a
reproducible column. Errors: `spec` not a list; an unknown `type`;
errors from [`sample()`](https://rdrr.io/r/base/sample.html) or
[`rpois()`](https://rdrr.io/r/stats/Poisson.html) on invalid weights or
rates.

## See also

[`mksyncsv`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncsv.md).

## Examples

``` r
set.seed(1)
# "sample": categorical draw, optionally weighted.
mksyncol(list(
  type = "sample", values = list("a", "b"),
  weights = list(0.7, 0.3)
), 5)
#> [1] "a" "a" "a" "b" "a"

# "bernoulli": two-label draw at probability p.
mksyncol(list(
  type = "bernoulli", p = 0.5,
  labels = list("Yes", "No")
), 5)
#> [1] "No"  "No"  "No"  "No"  "Yes"

# "poisson": counts with a floor via min.
mksyncol(list(type = "poisson", lambda = 3, min = 1), 5)
#> [1] 2 1 4 2 4

# "id_pattern": templated IDs (the {seq:05d} token is zero-padded).
mksyncol(list(
  type = "id_pattern",
  pattern = "case-{seq:05d}"
), 3)
#> [1] "case-00001" "case-00002" "case-00003"

# ... numbered within each year of an earlier column
yrs <- c(2024, 2024, 2025)
unname(mksyncol(list(type = "id_pattern",
  pattern = "{year}-{seq:05d}", year_col = "year"), 3,
  ctx = list(year = yrs)))
#> [1] "2024-00001" "2024-00002" "2025-00001"

# "fitted": draws from a distribution fitted by dstfit()
f <- dstfit(stats::rexp(100, 2), fams = "exponential", nboot = 0)
mksyncol(list(type = "fitted", fit = f), 4)
#> [1] 0.2982046 0.4023028 0.8290420 0.9676400

# "sequence": a running integer sequence from from.
mksyncol(list(type = "sequence", from = 100), 4)
#> [1] 100 101 102 103

# An unknown type errors.
try(mksyncol(list(type = "nope"), 3))
#> Error in mksyncol(list(type = "nope"), 3) : 
#>   Unknown synthetic column type: nope
```
