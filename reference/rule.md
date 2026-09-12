# Declare a validation rule

Builds a rule for
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md):
a predicate over one column, or over the whole data frame, with a
severity and a message. Rules live alongside a schema in a provenance
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

  Short identifier for the rule.

- expr:

  A function, as described above.

- column:

  Column the rule applies to, or `NULL` for a table-level rule.

- severity:

  `"warning"` (default) or `"fatal"`.

- message:

  Human-readable description of what a failure means. Defaults to a
  generated one naming the rule.

## Value

A list of class `bricklayer_rule`.

## Details

`expr` is a function. Given `column`, it receives that column and must
return a logical vector the same length (TRUE = the row passes) or a
single logical for a whole-column property. Given no `column`, it
receives the whole data frame and must return a single logical.

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
```
