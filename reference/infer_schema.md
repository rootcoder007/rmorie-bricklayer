# Infer a pinnable schema from a data frame

Derives the schema
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
consumes from data you already trust, so a capsule can be pinned without
writing one by hand.

## Usage

``` r
infer_schema(data, slack = 0.1, max_levels = 50L)
```

## Arguments

- data:

  A data frame to learn from.

- slack:

  Fractional headroom added to row counts, numeric ranges and
  missingness rates (default 0.1, i.e. 10%). `0` pins exactly to what
  was observed, which will reject almost any re-release.

- max_levels:

  Maximum distinct values for a categorical column to have its value set
  recorded (default 50). Above this the column is treated as free text
  and no value set is pinned.

## Value

A list with `expected_columns`, `expected_types`,
`structural_invariants`, `expected_value_sets`, `numeric_ranges` and
`max_missing_fraction`, of class `bricklayer_schema`. Wrap it as
`list(schema = <this>)` to hand to
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md).

## Details

What it records: the column names and their types, row-count bounds with
`slack` either side, the observed value set for every low-cardinality
categorical column, the observed range of every numeric column widened
by `slack`, and the observed missingness rate per column with headroom.

## This is a starting point, not an oracle

An inferred schema describes ONE extract. It cannot know that a category
which happens not to occur is nonetheless legal, or that a range is a
physical bound rather than an accident of this sample. Read what it
produces and edit it before committing – the value is in not starting
from a blank file, not in trusting the output blindly.

## See also

[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md),
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
for the distributional check the schema cannot make.

## Examples

``` r
set.seed(1)
df <- data.frame(
  id = 1:100,
  score = stats::runif(100, 0, 10),
  grade = sample(c("a", "b", "c"), 100, TRUE),
  note = paste0("free text ", 1:100),
  stringsAsFactors = FALSE
)

sch <- infer_schema(df)
sch
#> ── Inferred schema ───────────────────────────────────────────────
#>   columns         4
#>   rows            90 to 111
#>   value sets      1
#>   numeric ranges  2
#> 
#>   id                   integer    max NA  10.0%  [ -8.9, 109.9]
#>   score                numeric    max NA  10.0%  [-0.8446,  10.9]
#>   grade                character  max NA  10.0%  a, b, c
#>   note                 character  max NA  10.0%  – free
#> ──────────────────────────────────────────────────────────────────

# The categorical column has its levels pinned; the free-text one does
# not, because it exceeds max_levels.
sch$expected_value_sets
#> $grade
#> [1] "a" "b" "c"
#> 

# It validates the data it was learned from.
length(validate_schema(df, list(schema = sch)))
#> [1] 0

# And catches a column that has gone missing, or a new category.
length(validate_schema(df[, -3], list(schema = sch))) > 0
#> [1] TRUE
bad <- df; bad$grade[1] <- "z"
length(validate_schema(bad, list(schema = sch))) > 0
#> [1] TRUE
```
