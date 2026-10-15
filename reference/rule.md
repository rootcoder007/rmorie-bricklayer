# Declare a validation rule

Builds a rule for
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md):
a predicate over one column, or over the whole data frame, with a
severity and a message. Use rules for the checks that are particular to
a data set and that a schema cannot express: an age must be
non-negative, an identifier must be unique, a release date must not
precede an admission date. Rules live alongside a schema in a provenance
record, which keeps the project-specific checks in data rather than
scattered through code.

## Usage

``` r
rule(
  name,
  expr,
  column = NULL,
  severity = c("warning", "fatal"),
  message = NULL
)
```

## Arguments

- name:

  Short identifier for the rule, a string; it names the issue in the
  result of
  [`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md),
  so give each rule a different name.

- expr:

  A function, as described above.

- column:

  Name of the column the rule applies to, or `NULL` (the default) for a
  table-level rule.

- severity:

  `"warning"` (default) or `"fatal"`. A fatal failure stops
  [`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md).

- message:

  Human-readable description of what a failure means, a string. Defaults
  to `"Rule '<name>' failed"`.

## Value

A list of class `c("bricklayer_rule", "list")` with `name`, `expr`,
`column` (`NULL` for a table rule), `severity` and `message`; it prints
as one line.

## Details

`expr` is a function. Given `column`, it receives that column and must
return a logical vector the same length (`TRUE` = the row passes) or a
single logical for a whole-column property. Given no `column`, it
receives the whole data frame and must return a single logical. How the
result is read is described in
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md).

Only the first element of `name`, `column` and `message` is kept. The
rule is not run here. Errors: an empty or `NA` `name`; `expr` not a
function; an empty or `NA` `column`; a `severity` other than `"warning"`
or `"fatal"`.

## See also

[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md),
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
for the structural checks that need no rules.

## Examples

``` r
# A column predicate, applied row-wise.
rule("age_non_negative", function(v) v >= 0, column = "age")
#> <rule> age_non_negative [warning] on `age`

# A whole-column property.
rule("id_unique", function(v) !anyDuplicated(v), column = "id",
     severity = "fatal")
#> <rule> id_unique [fatal] on `id`

# A table-level rule spanning two columns.
rule("dates_ordered", function(df) all(df$start <= df$end))
#> <rule> dates_ordered [warning] table-level

# with a message that says what a failure means
r <- rule("release_after_admission",
          function(d) all(d$release >= d$admission, na.rm = TRUE),
          message = "a release date precedes its admission date")
r$message
#> [1] "a release date precedes its admission date"

# the predicate must be a function, not an expression
try(rule("age_non_negative", "age >= 0", column = "age"))
#> Error : `expr` must be a function
```
