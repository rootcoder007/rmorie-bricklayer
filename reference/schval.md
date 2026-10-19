# Apply Schema Validation, Stopping on Fatal Issues

Runs
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
(or, for a list of rules,
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md))
and acts on the result: the first fatal issue stops with an error, and
every warning-severity issue is raised as an R warning. Put it at the
top of an analysis script so that a re-released file with a missing
column stops the run before any result is computed.

## Usage

``` r
schval(dfraw, prov)
```

## Arguments

- dfraw:

  The data frame to validate.

- prov:

  A provenance list as returned by
  [`loadprov()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loadprov.md)
  (with a `schema` element), or one rule or a list of rules from
  [`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md),
  run with
  [`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
  under the same stop-on-fatal contract.

## Value

Invisibly, `TRUE` if no issues were found and `FALSE` if only
warning-severity issues were found (each raised as a warning). Errors if
any fatal issue is present.

## Details

Issues are handled in the order the validator returns them; a fatal
issue stops at once, so warnings after it are not raised. With a list of
rules the same contract applies to each rule's `severity`.

Unlike
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md),
this function refuses to check against nothing, because a validation
that checks nothing must not report success. Errors: `dfraw` not a data
frame; `prov` a data frame; `prov` `NULL` or an empty list; a list that
mixes rules with other elements; an unnamed list that is not all rules;
something other than a list; a provenance list with no `schema` element
(the message names the elements it has, so a typo such as `scheme`
shows); an empty schema (`list(schema = list())`).

## Examples

``` r
prov <- list(schema = list(expected_columns = "id"))
schval(data.frame(id = 1), prov)
# A missing required column is fatal:
try(schval(data.frame(x = 1), prov))
#> Error : Missing required columns: id

# a warning-level issue is raised as a warning and the result is FALSE
ranged <- list(schema = list(numeric_ranges = list(v = c(min = 0, max = 1))))
ok <- withCallingHandlers(
  schval(data.frame(v = c(0.5, 3)), ranged),
  warning = function(w) {
    message("warning: ", conditionMessage(w))
    invokeRestart("muffleWarning")
  }
)
#> warning: Column 'v' has 1 value(s) outside [0, 1]
ok
#> [1] FALSE

# rules work the same way
rules <- list(rul("id_positive", function(v) v > 0, col = "id", sev = "fatal"))
try(schval(data.frame(id = c(1, -2)), rules))
#> Error : Rule 'id_positive' failed (1 of 2 rows)

# a provenance without a schema is refused, not passed
try(schval(data.frame(id = 1), list(scheme = list())))
#> Error : `prov` has no `schema` element (it has scheme): nothing would be validated
```
