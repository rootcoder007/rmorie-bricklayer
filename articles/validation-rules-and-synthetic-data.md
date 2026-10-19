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
  rul("agenonnegative", function(v) v >= 0, col = "age"),
  rul("idunique", function(v) !anyDuplicated(v), col = "id", sev = "fatal"),
  rul("datesordered", function(d) all(d$start <= d$end))
)

issues <- valrules(df, rules)
names(issues)
#> [1] "agenonnegative" "idunique"       "datesordered"
issues$agenonnegative$n_failed
#> [1] 1
issues$agenonnegative$rows
#> [1] 2
```

Clean data produces nothing:

``` r

clean <- data.frame(id = 1:3, age = c(30, 31, 40), start = 1:3, end = 4:6)
length(valrules(clean, rules))
#> [1] 0
```

Two behaviours matter for trust. A rule for an absent column is
**skipped**, not failed: a missing column is the schema’s finding to
report. And a rule that *errors* is a **failure**, never a silent pass:

``` r

length(valrules(data.frame(id = 1:3), rules[1:2]))
#> [1] 0
broken <- list(rul("bad", function(v) stop("boom"), col = "age"))
valrules(clean, broken)$bad$message
#> [1] "Rule 'bad' failed (rule could not be evaluated: boom)"
```

### Ready-made rules

Common checks have constructors so the intent is in the name:

``` r

rules2 <- list(
  rulenull("id"),
  ruleuniq("id", sev = "fatal"),
  rulebtw("age", 0, 120),
  ruleinset("grade", c("a", "b", "c")),
  rulerx("code", "^[A-Z]{2}-[0-9]{4}$"),
  rulemad("score", n = 3),
  rulecolcnt(6, sev = "fatal")
)
length(rules2)
#> [1] 7
```

[`ruleincr()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md),
[`ruledstn()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
and
[`rulecmpl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rulelib.md)
complete the set. `schval(df, rules2)` runs a rule list the same way and
stops on any fatal issue, which is the call a pipeline makes (it takes a
provenance list or a rule list; until 0.5.12 a rule list was silently
ignored and reported a pass).

## Inferring a schema

Given a table known to be right,
[`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md)
pins what can be pinned: column names and types, numeric ranges with a
little slack, and the level set of categorical columns (up to `maxlvl`,
so free text is not mistaken for a code list):

``` r

set.seed(1)
df <- data.frame(
  id = 1:100,
  score = stats::runif(100, 0, 10),
  grade = sample(c("a", "b", "c"), 100, TRUE),
  note = paste0("free text ", 1:100),
  stringsAsFactors = FALSE
)
sch <- infsch(df)
sch$expected_value_sets
#> $grade
#> [1] "a" "b" "c"
```

It validates the table it was learned from, and catches a vanished
column or a new category:

``` r

length(valsch(df, list(schema = sch)))
#> [1] 0
length(valsch(df[, -3], list(schema = sch))) > 0
#> [1] TRUE
bad <- df
bad$grade[1] <- "z"
length(valsch(bad, list(schema = sch))) > 0
#> [1] TRUE
```

A schema goes into the capsule’s provenance record;
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
is what
[`vrfcps()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfcps.md)
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
res <- mksyncsv(recipe, out)
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

The seed makes the stand-in reproducible; `nrows` overrides the recipe’s
own count. A `<path>.synthetic` sidecar file is written beside the CSV
(the file itself stays a plain table), and the capsule checks read that
marker, so a synthetic run can never be mistaken for a result:

``` r

mksyncsv(recipe, tempfile(fileext = ".csv"), nrows = 5)$rows
#> [1] 5
```

[`mksyncol()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncol.md)
generates one column from a spec, for building a table piece by piece or
for testing a generator.

## Putting them together

1.  On the first, trusted download:
    [`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md),
    then add the rules the schema cannot express (ordering between
    columns, cross-table consistency) and pin both.
2.  On every later run:
    [`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
    and
    [`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md);
    stop on `fatal`.
3.  When the source is unreachable:
    [`mksyncsv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mksyncsv.md)
    from the pinned schema, run the pipeline, and let the synthetic
    marker say what the output is.

## Rules for a published table

Rules catch problems in a table before it is used. For an Indigenous
health table: the estimate inside its interval, a known quality flag,
and a known group:

``` r

d <- indiex("health")
rules <- list(
  ruleinset("quality", c("ok", "E", "F", "x", "..")),
  ruleinset("group", c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous")),
  rul("estimate inside its interval",
       function(x) is.na(x$estimate) | (x$lower <= x$estimate & x$estimate <= x$upper))
)
valrules(d, rules)
#> list()
```

An empty list means every rule held on every row.
