# Apply declared rules to a data frame

Evaluates each rule from
[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
and returns the failures in the same shape
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
uses, so the two can be combined and handed to
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)
together.

## Usage

``` r
validate_rules(data, rules)
```

## Arguments

- data:

  A data frame.

- rules:

  A list of
  [`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
  objects, or a single rule.

## Value

A named list of issues, each with `severity`, `message`, and for a
row-wise rule `n_failed` and `rows` (the first failing row indices).
Empty when everything passes.

## Details

A rule whose column is absent is SKIPPED rather than failed – a missing
column is
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)'s
business, and reporting it twice buries the real finding. A rule that
ERRORS is reported as a failure naming the error, never swallowed: a
rule that cannot run has not passed.

## See also

[`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md),
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md),
[`apply_schema_validation()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/apply_schema_validation.md)

## Examples

``` r
df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
                 start = c(1, 5, 3), end = c(2, 4, 9))

rules <- list(
  rule("age_non_negative", function(v) v >= 0, column = "age"),
  rule("id_unique", function(v) !anyDuplicated(v), column = "id",
       severity = "fatal"),
  rule("dates_ordered", function(d) all(d$start <= d$end))
)

issues <- validate_rules(df, rules)
names(issues)
#> [1] "age_non_negative" "id_unique"        "dates_ordered"   

# A row-wise failure reports how many rows and which.
issues$age_non_negative$n_failed
#> [1] 1
issues$age_non_negative$rows
#> [1] 2

# Clean data produces nothing.
clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
length(validate_rules(clean, rules))
#> [1] 0

# A rule for an absent column is skipped, not failed -- a missing
# column is validate_schema()'s finding to report, not this one's.
length(validate_rules(data.frame(id = 1:3), rules[1:2]))
#> [1] 0

# A rule that errors is a failure, not a silent pass.
broken <- list(rule("bad", function(v) stop("boom"), column = "age"))
validate_rules(clean, broken)$bad$message
#> [1] "Rule 'bad' failed (rule could not be evaluated: boom)"
```
