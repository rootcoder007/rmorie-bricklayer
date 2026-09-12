# Ready-made validation rules

Constructors for the checks most schemas need, each returning a
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
that
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
evaluates. Use
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
directly for anything not covered here.

## Usage

``` r
rule_in_set(column, set, na_pass = TRUE, severity = c("warning", "fatal"))

rule_between(column, lo, hi, na_pass = TRUE, severity = c("warning", "fatal"))

rule_not_null(column, severity = c("warning", "fatal"))

rule_unique(column, severity = c("warning", "fatal"))

rule_regex(column, pattern, na_pass = TRUE, severity = c("warning", "fatal"))

rule_increasing(column, strictly = FALSE, severity = c("warning", "fatal"))

rule_within_n_mads(
  column,
  n = 3,
  na_pass = TRUE,
  severity = c("warning", "fatal")
)

rule_complete_rows(severity = c("warning", "fatal"))

rule_distinct_rows(columns = NULL, severity = c("warning", "fatal"))

rule_col_count(n, severity = c("warning", "fatal"))
```

## Arguments

- column:

  Column the rule applies to.

- set:

  Allowed values (`rule_in_set`).

- na_pass:

  Treat `NA` as passing (default `TRUE`; see above).

- severity:

  `"warning"` (default) or `"fatal"`.

- lo, hi:

  Inclusive bounds (`rule_between`).

- pattern:

  Regular expression the values must match (`rule_regex`).

- strictly:

  Require a strict increase rather than non-decreasing
  (`rule_increasing`).

- n:

  Multiplier for `rule_within_n_mads`, or the expected count for
  `rule_col_count`.

- columns:

  Columns that jointly must be unique (`rule_distinct_rows`), or `NULL`
  for all of them.

## Value

A
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
object.

## Details

`NA` handling is explicit and per-rule, because the right answer
differs. `rule_not_null()` exists precisely to fail on `NA`. The value
rules (`rule_in_set`, `rule_between`, `rule_regex`,
`rule_within_n_mads`) treat `NA` as PASSING by default, so that a
column's missingness is reported once by `rule_not_null()` or
`max_missing_fraction` rather than again by every other rule; set
`na_pass = FALSE` to make them fail on it instead.

## See also

[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
for an arbitrary predicate,
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
to evaluate them,
[`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md)
for the structural checks that need no rules at all.

## Examples

``` r
df <- data.frame(
  id = c(1, 2, 2),
  grade = c("a", "b", "z"),
  score = c(5, 200, 7),
  email = c("a@b.com", "nope", "c@d.org"),
  day = c(3, 1, 2),
  stringsAsFactors = FALSE
)

rules <- list(
  rule_unique("id", severity = "fatal"),
  rule_in_set("grade", c("a", "b", "c")),
  rule_between("score", 0, 100),
  rule_regex("email", "^[^@]+@[^@]+\\\\.[a-z]+$"),
  rule_increasing("day")
)
names(validate_rules(df, rules))
#> [1] "id_unique"      "grade_in_set"   "score_between"  "email_regex"   
#> [5] "day_increasing"

# Each names the rows that failed.
validate_rules(df, rules)$grade_in_set$rows
#> [1] 3

# Clean data passes every one of them.
ok <- data.frame(id = 1:3, grade = c("a", "b", "c"),
                 score = c(5, 50, 7),
                 email = c("a@b.com", "c@d.org", "e@f.net"),
                 day = 1:3, stringsAsFactors = FALSE)
length(validate_rules(ok, rules))
#> [1] 1

# A robust outlier rule: MADs from the median, not standard
# deviations from the mean, so one wild value cannot hide the others.
validate_rules(data.frame(v = c(1, 2, 3, 2, 1, 900)),
               rule_within_n_mads("v", 5))$v_within_mads$rows
#> [1] 6

# Whole-table rules.
validate_rules(df, rule_distinct_rows())
#> list()
validate_rules(df, rule_col_count(5))
#> list()
validate_rules(df, rule_complete_rows())
#> list()
```
