# Ready-made validation rules

Constructors for the checks most schemas need, each returning a
[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
that
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
evaluates. Use
[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
directly for anything not covered here. Writing the common checks once,
here, avoids the off-by-one or the forgotten `NA` that makes a
hand-written rule pass silently, and gives every failure a readable
message and the rows that failed.

## Usage

``` r
ruleinset(col = NULL, set, napass = TRUE, sev = c("warning", "fatal"))

rulebtw(col = NULL, lo, hi, napass = TRUE, sev = c("warning", "fatal"))

rulenull(col = NULL, sev = c("warning", "fatal"))

ruleuniq(col = NULL, sev = c("warning", "fatal"))

rulerx(col = NULL, pat, napass = TRUE, sev = c("warning", "fatal"))

ruleincr(col = NULL, strict = FALSE, sev = c("warning", "fatal"))

rulemad(col = NULL, n = 3, napass = TRUE, sev = c("warning", "fatal"))

rulecmpl(sev = c("warning", "fatal"))

ruledstn(cols = NULL, sev = c("warning", "fatal"))

rulecolcnt(n, sev = c("warning", "fatal"))
```

## Arguments

- col:

  Character scalar, the name of the column the rule applies to.

- set:

  Vector of allowed values (`ruleinset()`); compared as text.

- napass:

  Logical scalar, default `TRUE`: treat `NA` as passing (see above);
  `FALSE` makes a missing value fail.

- sev:

  `"warning"` (the default) or `"fatal"`: how
  [`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
  and the capsule gate treat a failure.

- lo, hi:

  Numeric scalars, the inclusive bounds (`rulebtw()`); `lo` must not
  exceed `hi`.

- pat:

  Character scalar, the regular expression the values must match
  (`rulerx()`); only the first element is used.

- strict:

  Logical scalar, default `FALSE`: require a strict increase rather than
  non-decreasing (`ruleincr()`).

- n:

  Numeric scalar: the multiplier for `rulemad()` (default `3`), or the
  expected number of columns for `rulecolcnt()` (a whole number, no
  default).

- cols:

  Character vector of columns that jointly must be unique
  (`ruledstn()`), or `NULL` (the default) for all of them.

## Value

A
[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
object: a list of class `c("bricklayer_rule", "list")` with `name`,
`expr` (the predicate function), `column` (`NULL` for whole-table
rules), `severity` and `message`.

## Details

What each rule checks:

- `ruleinset()`: each value, compared as text, is one of `set` (so `1`
  and `"1"` match). Name `"<column>_in_set"`.

- `rulebtw()`: each value lies in `[lo, hi]`, ends included. Name
  `"<column>_between"`.

- `rulenull()`: no value is `NA`. Name `"<column>_not_null"`.

- `ruleuniq()`: no value repeats an earlier one; the rows reported are
  the repeats, not the first occurrence. Two `NA`s count as a repeat.
  Name `"<column>_unique"`.

- `rulerx()`: each value, as text, matches `pattern` (an extended
  regular expression, [`grepl()`](https://rdrr.io/r/base/grep.html)).
  Name `"<column>_regex"`.

- `ruleincr()`: the column never decreases from one row to the next (or
  always increases, with `strictly = TRUE`); missing steps are skipped.
  A whole-column check: a failure names no rows. Name
  `"<column>_increasing"`.

- `rulemad()`: each value lies within `n` median absolute deviations
  (scaled by 1.4826, so comparable to standard deviations for normal
  data) of the column's median. When the MAD is zero (more than half the
  values equal) any value other than the median fails. The column must
  be numeric when the rule is evaluated. Name `"<column>_within_mads"`.

- `rulecmpl()`: no row has a missing value. Name `"complete_rows"`.

- `ruledstn()`: no row repeats an earlier one on `cols` (columns not in
  the data are ignored; when none is present the rule passes). Name
  `"distinct_rows"`.

- `rulecolcnt()`: the data have exactly `n` columns. Name `"col_count"`.

The name is the key of the rule's entry in the list
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
returns, which holds only the rules that failed (with `sev`, `message`,
and for row-wise rules `n_failed` and `rows`). A rule that cannot be
evaluated (a missing column, text in a numeric rule) is reported as
failed, with the reason in its message.

Errors, at construction: `col` not a single non-empty string; `sev`
other than `"warning"` or `"fatal"`; `rulebtw()` with `lo > hi` or a
missing bound; `rulemad()` with `n` not positive; `rulecolcnt()` with
`n` not a non-negative whole number.

`NA` handling is explicit and per-rule, because the right answer
differs. `rulenull()` exists precisely to fail on `NA`. The value rules
( `ruleinset`, `rulebtw`, `rulerx`, `rulemad`) treat `NA` as PASSING by
default, so that a column's missingness is reported once by `rulenull()`
or `max_missing_fraction` rather than again by every other rule; set
`napass = FALSE` to make them fail on it instead.

## See also

[`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
for an arbitrary predicate,
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)
to evaluate them,
[`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md)
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
  ruleuniq("id", sev = "fatal"),
  ruleinset("grade", c("a", "b", "c")),
  rulebtw("score", 0, 100),
  rulerx("email", "^[^@]+@[^@]+\\\\.[a-z]+$"),
  ruleincr("day")
)
names(valrules(df, rules))
#> [1] "id_unique"      "grade_in_set"   "score_between"  "email_regex"   
#> [5] "day_increasing"

# Each names the rows that failed.
valrules(df, rules)$grade_in_set$rows
#> [1] 3

# Clean data passes every one of them.
ok <- data.frame(
  id = 1:3,
  grade = c("a", "b", "c"),
  score = c(5, 50, 7),
  email = c("a@b.com", "c@d.org", "e@f.net"),
  day = 1:3,
  stringsAsFactors = FALSE
)
length(valrules(ok, rules))
#> [1] 1

# A robust outlier rule: MADs from the median, not standard
# deviations from the mean, so one wild value cannot hide the others.
valrules(
  data.frame(v = c(1, 2, 3, 2, 1, 900)),
  rulemad("v", 5)
)$v_within_mads$rows
#> [1] 6

# Whole-table rules.
valrules(df, ruledstn())
#> list()
valrules(df, rulecolcnt(5))
#> list()
valrules(df, rulecmpl())
#> list()

# NA fails only when asked to
g <- data.frame(grade = c("a", NA, "b"))
length(valrules(g, ruleinset("grade", c("a", "b"))))
#> [1] 0
valrules(
  g,
  ruleinset("grade", c("a", "b"), napass = FALSE)
)$grade_in_set$rows
#> [1] 2

# bounds are checked when the rule is made
try(rulebtw("score", 100, 0))
#> Error : need `lo` <= `hi`, both non-missing
```
