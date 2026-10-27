# Declare a validation rule

Builds a rule for
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md):
a predicate over one column, or over the whole data frame, with a
severity and a message. Use rules for the checks that are particular to
a data set and that a schema cannot express: an age must be
non-negative, an identifier must be unique, a release date must not
precede an admission date. Rules live alongside a schema in a provenance
record, which keeps the project-specific checks in data rather than
scattered through code.

## Usage

``` r
rul(name, expr, col = NULL, sev = c("warning", "fatal"), msg = NULL)
```

## Arguments

- name:

  A short identifier for the rule, a string. It names the issue in the
  result of
  [`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md),
  so give each rule a different name.

- expr:

  A function, as described above.

- col:

  Name of the column the rule applies to, or `NULL` (the default) for a
  table-level rule.

- sev:

  `"warning"` (default) or `"fatal"`. A fatal failure stops
  [`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md).

- msg:

  Human-readable description of what a failure means, a string. Defaults
  to `"Rule '<name>' failed"`.

## Value

A list of class `c("bricklayer_rule", "list")` with `name`, `expr`,
`column` (`NULL` for a table rule), `severity` and `message`; it prints
as one line.

## Details

`expr` is a function. Given `col`, it receives that column and must
return a logical vector the same length (`TRUE` = the row passes) or a
single logical for a whole-column property. Given no `col`, it receives
the whole data frame and must return a single logical. How the result is
read is described in
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md).

Only the first element of `name`, `col` and `msg` is kept. The rule is
not run here. Errors: an empty or `NA` `name`; `expr` not a function; an
empty or `NA` `col`; a `sev` other than `"warning"` or `"fatal"`.

## See also

[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md),
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
for the structural checks that need no rules.

## Examples

``` r
# A column predicate, applied row-wise.
rul("agenonnegative", function(v) v >= 0, col = "age")
#> ╭── Rule agenonnegative ──────────────────────────────────────────────────────╮
#> │   Severity  warning                                                         │
#> │   Applies   on `age`                                                        │
#> │   Message   Rule 'agenonnegative' failed                                    │
#> │                                                                             │
#> │   A check the data must pass; valrules() runs it and reports the rows that  │
#> │   break it.                                                                 │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# A whole-column property.
rul("idunique", function(v) !anyDuplicated(v), col = "id",
     sev = "fatal")
#> ╭── Rule idunique ────────────────────────────────────────────────────────────╮
#> │   Severity  fatal                                                           │
#> │   Applies   on `id`                                                         │
#> │   Message   Rule 'idunique' failed                                          │
#> │                                                                             │
#> │   A check the data must pass; valrules() runs it and reports the rows that  │
#> │   break it.                                                                 │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# A table-level rule spanning two columns.
rul("datesordered", function(df) all(df$start <= df$end))
#> ╭── Rule datesordered ────────────────────────────────────────────────────────╮
#> │   Severity  warning                                                         │
#> │   Applies   table-level                                                     │
#> │   Message   Rule 'datesordered' failed                                      │
#> │                                                                             │
#> │   A check the data must pass; valrules() runs it and reports the rows that  │
#> │   break it.                                                                 │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# with a message that says what a failure means
r <- rul("releaseafteradmission",
          function(d) all(d$release >= d$admission, na.rm = TRUE),
          msg = "a release date precedes its admission date")
r$message
#> [1] "a release date precedes its admission date"

# the predicate must be a function, not an expression
try(rul("agenonnegative", "age >= 0", col = "age"))
#> Error : `expr` must be a function
```
