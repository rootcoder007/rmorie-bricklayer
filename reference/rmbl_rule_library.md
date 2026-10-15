# Ready-made validation rules

Constructors for the checks most schemas need, each returning a
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
that
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
evaluates. Use
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
directly for anything not covered here. Writing the common checks once,
here, avoids the off-by-one or the forgotten `NA` that makes a
hand-written rule pass silently, and gives every failure a readable
message and the rows that failed.

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

  Character scalar, the name of the column the rule applies to.

- set:

  Vector of allowed values (`rule_in_set()`); compared as text.

- na_pass:

  Logical scalar, default `TRUE`: treat `NA` as passing (see above);
  `FALSE` makes a missing value fail.

- severity:

  `"warning"` (the default) or `"fatal"`: how
  [`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
  and the capsule gate treat a failure.

- lo, hi:

  Numeric scalars, the inclusive bounds (`rule_between()`); `lo` must
  not exceed `hi`.

- pattern:

  Character scalar, the regular expression the values must match
  (`rule_regex()`); only the first element is used.

- strictly:

  Logical scalar, default `FALSE`: require a strict increase rather than
  non-decreasing (`rule_increasing()`).

- n:

  Numeric scalar: the multiplier for `rule_within_n_mads()` (default
  `3`), or the expected number of columns for `rule_col_count()` (a
  whole number, no default).

- columns:

  Character vector of columns that jointly must be unique
  (`rule_distinct_rows()`), or `NULL` (the default) for all of them.

## Value

A
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
object: a list of class `c("bricklayer_rule", "list")` with `name`,
`expr` (the predicate function), `column` (`NULL` for whole-table
rules), `severity` and `message`.

## Details

What each rule checks:

- `rule_in_set()`: each value, compared as text, is one of `set` (so `1`
  and `"1"` match). Name `"<column>_in_set"`.

- `rule_between()`: each value lies in `[lo, hi]`, ends included. Name
  `"<column>_between"`.

- `rule_not_null()`: no value is `NA`. Name `"<column>_not_null"`.

- `rule_unique()`: no value repeats an earlier one; the rows reported
  are the repeats, not the first occurrence. Two `NA`s count as a
  repeat. Name `"<column>_unique"`.

- `rule_regex()`: each value, as text, matches `pattern` (an extended
  regular expression, [`grepl()`](https://rdrr.io/r/base/grep.html)).
  Name `"<column>_regex"`.

- `rule_increasing()`: the column never decreases from one row to the
  next (or always increases, with `strictly = TRUE`); missing steps are
  skipped. A whole-column check: a failure names no rows. Name
  `"<column>_increasing"`.

- `rule_within_n_mads()`: each value lies within `n` median absolute
  deviations (scaled by 1.4826, so comparable to standard deviations for
  normal data) of the column's median. When the MAD is zero (more than
  half the values equal) any value other than the median fails. The
  column must be numeric when the rule is evaluated. Name
  `"<column>_within_mads"`.

- `rule_complete_rows()`: no row has a missing value. Name
  `"complete_rows"`.

- `rule_distinct_rows()`: no row repeats an earlier one on `columns`
  (columns not in the data are ignored; when none is present the rule
  passes). Name `"distinct_rows"`.

- `rule_col_count()`: the data have exactly `n` columns. Name
  `"col_count"`.

The name is the key of the rule's entry in the list
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)
returns, which holds only the rules that failed (with `severity`,
`message`, and for row-wise rules `n_failed` and `rows`). A rule that
cannot be evaluated (a missing column, text in a numeric rule) is
reported as failed, with the reason in its message.

Errors, at construction: `column` not a single non-empty string;
`severity` other than `"warning"` or `"fatal"`; `rule_between()` with
`lo > hi` or a missing bound; `rule_within_n_mads()` with `n` not
positive; `rule_col_count()` with `n` not a non-negative whole number.

`NA` handling is explicit and per-rule, because the right answer
differs. `rule_not_null()` exists precisely to fail on `NA`. The value
rules ( `rule_in_set`, `rule_between`, `rule_regex`,
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
ok <- data.frame(
  id = 1:3, grade = c("a", "b", "c"),
  score = c(5, 50, 7),
  email = c("a@b.com", "c@d.org", "e@f.net"),
  day = 1:3, stringsAsFactors = FALSE
)
length(validate_rules(ok, rules))
#> [1] 1

# A robust outlier rule: MADs from the median, not standard
# deviations from the mean, so one wild value cannot hide the others.
validate_rules(
  data.frame(v = c(1, 2, 3, 2, 1, 900)),
  rule_within_n_mads("v", 5)
)$v_within_mads$rows
#> [1] 6

# Whole-table rules.
validate_rules(df, rule_distinct_rows())
#> list()
validate_rules(df, rule_col_count(5))
#> list()
validate_rules(df, rule_complete_rows())
#> list()

# NA fails only when asked to
g <- data.frame(grade = c("a", NA, "b"))
length(validate_rules(g, rule_in_set("grade", c("a", "b"))))
#> [1] 0
validate_rules(g, rule_in_set("grade", c("a", "b"), na_pass = FALSE))$grade_in_set$rows
#> [1] 2

# bounds are checked when the rule is made
try(rule_between("score", 100, 0))
#> Error : need `lo` <= `hi`, both non-missing
```
