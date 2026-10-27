# Apply declared rules to a data frame

Evaluates each rule from
[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
on a data frame and returns the failures in the same shape
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
uses, so the two can be combined and handed to
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)
together. Use it each time a data set is refreshed, to see which of its
own invariants still hold.

## Usage

``` r
valrules(data, rules)
```

## Arguments

- data:

  A data frame the rules are applied to.

- rules:

  A list of
  [`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
  objects, or a single rule.

## Value

A named list of issues, one per failed rule, each a list with `severity`
(character) and `message` (character; for a row-wise rule it ends with
“(k of n rows)”), and for a row-wise rule `n_failed` (integer) and
`rows` (integer, the first ten failing row indices). Empty when
everything passes.

## Details

A rule whose column is absent is SKIPPED rather than failed – a missing
column is
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)'s
business, and reporting it twice buries the real finding. A rule that
ERRORS is reported as a failure naming the error, never swallowed: a
rule that cannot run has not passed. On a table of no rows a row-wise
rule has no row to fail and passes.

How a rule's result is read: a result that is not logical, or has length
0, is a failure (`"rule returned <class>, not a logical"`); a single
value fails unless it is `TRUE` (so `NA` fails); a longer vector is read
row by row, and rows that are `FALSE` or `NA` fail (a rule that cannot
decide has not been satisfied). The length of a row-wise result is not
checked against the number of rows. The issue is named by the rule's
`name`; two rules with the same name keep only the later failure. Rules
run in the order given and only read the data.

Errors: `data` not a data frame (or with missing or duplicated column
names); `rules` not a rule or a list; an element that is not a rule.

## See also

[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md),
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md),
[`schval()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/schval.md)

## Examples

``` r
df <- data.frame(id = c(1, 2, 2), age = c(30, -5, 40),
                 start = c(1, 5, 3), end = c(2, 4, 9))

rules <- list(
  rul("agenonnegative", function(v) v >= 0, col = "age"),
  rul("idunique", function(v) !anyDuplicated(v), col = "id",
       sev = "fatal"),
  rul("datesordered", function(d) all(d$start <= d$end))
)

issues <- valrules(df, rules)
names(issues)
#> [1] "agenonnegative" "idunique"       "datesordered"  

# A row-wise failure reports how many rows and which.
issues$agenonnegative$n_failed
#> [1] 1
issues$agenonnegative$rows
#> [1] 2

# Clean data produces nothing.
clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
length(valrules(clean, rules))
#> [1] 0

# A rule for an absent column is skipped, not failed -- a missing
# column is valsch()'s finding to report, not this one's.
length(valrules(data.frame(id = 1:3), rules[1:2]))
#> [1] 0

# A rule that errors is a failure, not a silent pass.
broken <- list(rul("bad", function(v) stop("boom"), col = "age"))
valrules(clean, broken)$bad$message
#> [1] "Rule 'bad' failed (rule could not be evaluated: boom)"

# NA counts as a failure
valrules(data.frame(age = c(30, NA)), rules[1])$agenonnegative$message
#> [1] "Rule 'agenonnegative' failed (1 of 2 rows)"

# only rule() objects are accepted
try(valrules(df, list(function(v) v >= 0)))
#> Error : every element of `rules` must come from rul()
```
