# Infer a pinnable schema from a data frame

Derives the schema
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
consumes from data you already trust, so a capsule can be pinned without
writing one by hand. Infer it once from the extract the analysis was run
on, read it, edit it, commit it, and validate every later download
against it.

## Usage

``` r
infsch(data, slack = 0.1, maxlvl = 50L)
```

## Arguments

- data:

  A data frame to learn from.

- slack:

  Headroom, one non-negative number (default 0.1). It is a fraction of
  the row count and of each numeric range, and an absolute amount added
  to each missingness rate (0.1 allows ten more percentage points of
  `NA`). `0` pins exactly to what was observed, which will reject almost
  any re-release.

- maxlvl:

  Maximum distinct values for a categorical column to have its value set
  recorded, one positive whole number (default 50). Above this the
  column is treated as free text and no value set is pinned.

## Value

A list of class `c("bricklayer_schema", "list")` with `expected_columns`
(character), `expected_types` (named character), `structural_invariants`
(list of `min_data_rows` and `max_data_rows`, integers),
`expected_value_sets` (named list of character vectors),
`numeric_ranges` (named list of `c(min =, max =)`) and
`max_missing_fraction` (named numeric). Wrap it as
`list(schema = <this>)` to hand to
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md).

## Details

What it records: the column names and their types, row-count bounds with
`slack` either side, the observed value set for every low-cardinality
categorical column, the observed range of every numeric column widened
by `slack`, and the observed missingness rate per column with headroom.

The rules, with \\n\\ rows:

- types: the first class of each column (`"integer"`, `"numeric"`,
  `"character"`, `"factor"`, `"Date"`, ...);

- rows: `min_data_rows` \\= \lfloor n(1 - slack) \rfloor\\ (at least 0)
  and `max_data_rows` \\= \lceil n(1 + slack) \rceil\\;

- numeric ranges: \\\[lo - pad, hi + pad\]\\ with \\pad = slack \times
  (hi - lo)\\, or \\slack \times \max(\|lo\|, 1)\\ for a constant
  column; a column with no non-missing value gets no range;

- value sets: for character, factor and logical columns with at most
  `maxlvl` distinct non-missing values, those values as sorted text;

- missingness: the observed share of `NA` plus `slack` (added, not
  multiplied), capped at 1.

Other column types (dates, lists) get a type and a missingness ceiling
only.

### This is a starting point, not an oracle

An inferred schema describes ONE extract. It cannot know that a category
which happens not to occur is nonetheless legal, or that a range is a
physical bound rather than an accident of this sample. Read what it
produces and edit it before committing – the value is in not starting
from a blank file, not in trusting the output blindly.

Errors: `data` not a data frame or without columns; `slack` not one
non-negative number; `maxlvl` not one positive whole number.

## See also

[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md),
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
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

sch <- infsch(df)
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
length(valsch(df, list(schema = sch)))
#> [1] 0

# And catches a column that has gone missing, or a new category.
length(valsch(df[, -3], list(schema = sch))) > 0
#> [1] TRUE
bad <- df; bad$grade[1] <- "z"
length(valsch(bad, list(schema = sch))) > 0
#> [1] TRUE

# no slack pins the exact observed range
infsch(df, slack = 0)$numeric_ranges$score
#>       min       max 
#> 0.1339033 9.9190609 

# a negative slack is refused
try(infsch(df, slack = -0.1))
#> Error : `slack` must be a single non-negative number
```
