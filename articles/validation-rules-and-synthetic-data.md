# Validation rules, inferred schemas and synthetic stand-ins

A capsule says what shape its data must have. This vignette covers the
three tools for stating and checking that shape: explicit **rules**, a
**schema** inferred from a known-good table, and a **synthetic
stand-in** generated from the schema when the portal is unreachable.

## Rules

A rule is a name, a predicate and optionally a column. Row-wise rules
report how many rows fail and which; table-wise rules take the whole
data frame. A `fatal` severity stops the pipeline; a `warning` is
recorded.

``` r

df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
                 start = c(1, 5, 3), end = c(2, 4, 9))

rules <- list(
  rule("age_non_negative", function(v) v >= 0, column = "age"),
  rule("id_unique", function(v) !anyDuplicated(v), column = "id", severity = "fatal"),
  rule("dates_ordered", function(d) all(d$start <= d$end))
)

issues <- validate_rules(df, rules)
names(issues)
#> [1] "age_non_negative" "id_unique"        "dates_ordered"
issues$age_non_negative$n_failed
#> [1] 1
issues$age_non_negative$rows
#> [1] 2
```

Clean data produces nothing:

``` r

clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
length(validate_rules(clean, rules))
#> [1] 0
```

Two behaviours matter for trust. A rule for an absent column is
**skipped**, not failed: a missing column is the schema’s finding to
report. And a rule that *errors* is a **failure**, never a silent pass:

``` r

length(validate_rules(data.frame(id = 1:3), rules[1:2]))
#> [1] 0
broken <- list(rule("bad", function(v) stop("boom"), column = "age"))
validate_rules(clean, broken)$bad$message
#> [1] "Rule 'bad' failed (rule could not be evaluated: boom)"
```

### Ready-made rules

Common checks have constructors so the intent is in the name:

``` r

rules2 <- list(
  rule_not_null("id"),
  rule_unique("id", severity = "fatal"),
  rule_between("age", 0, 120),
  rule_in_set("grade", c("a", "b", "c")),
  rule_regex("code", "^[A-Z]{2}-[0-9]{4}$"),
  rule_within_n_mads("score", n = 3),
  rule_col_count(6, severity = "fatal")
)
length(rules2)
#> [1] 7
```

[`rule_increasing()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md),
[`rule_distinct_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
and
[`rule_complete_rows()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_rule_library.md)
complete the set.
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
runs a rule list and stops on any fatal issue, which is the call a
pipeline makes.

## Inferring a schema

Given a table known to be right,
[`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
pins what can be pinned: column names and types, numeric ranges with a
little slack, and the level set of categorical columns (up to
`max_levels`, so free text is not mistaken for a code list):

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
sch$expected_value_sets
#> $grade
#> [1] "a" "b" "c"
```

It validates the table it was learned from, and catches a vanished
column or a new category:

``` r

length(validate_schema(df, list(schema = sch)))
#> [1] 0
length(validate_schema(df[, -3], list(schema = sch))) > 0
#> [1] TRUE
bad <- df
bad$grade[1] <- "z"
length(validate_schema(bad, list(schema = sch))) > 0
#> [1] TRUE
```

A schema goes into the capsule’s provenance record;
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
is what
[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
runs on a fresh download.

## Synthetic stand-ins

When the portal is down, the pipeline should still run end to end on
data of the right shape, clearly marked as synthetic. A recipe names
each column’s generator:

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
res$rows
#> [1] 20
res$seed
#> [1] 42

df <- utils::read.csv(out)
dim(df)
#> [1] 20  4
names(df)
#> [1] "year"   "alert"  "visits" "id"
head(df, 3)
#>   year alert visits      id
#> 1 2024    No      4 p-00001
#> 2 2024    No      7 p-00002
#> 3 2024   Yes      4 p-00003
```

The seed makes the stand-in reproducible; `n_rows` overrides the
recipe’s own count. The written file carries a marker that identifies it
as synthetic, so a synthetic run can never be mistaken for a result:

``` r

make_synthetic_csv(recipe, tempfile(fileext = ".csv"), n_rows = 5)$rows
#> [1] 5
```

[`make_synthetic_column()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_column.md)
generates one column from a spec, for building a table piece by piece or
for testing a generator.

## Putting them together

1.  On the first, trusted download:
    [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md),
    then add the rules the schema cannot express (ordering between
    columns, cross-table consistency) and pin both.
2.  On every later run:
    [`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
    and
    [`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md);
    stop on `fatal`.
3.  When the source is unreachable:
    [`make_synthetic_csv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_synthetic_csv.md)
    from the pinned schema, run the pipeline, and let the synthetic
    marker say what the output is.
