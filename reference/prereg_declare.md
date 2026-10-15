# Declare an analysis before running it

`prereg_declare()` records, before the analysis is run, the statistics
it intends to report and the claim each one is meant to test, with a UTC
timestamp. `prereg_check()` compares that declaration with what was
actually reported and lists the departures in both directions. Seal the
declaration with
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
and it acquires a date it cannot be moved off. Use the pair to make a
pre-analysis plan checkable.

## Usage

``` r
prereg_declare(hypotheses, note = NULL)

prereg_check(prereg, reported)
```

## Arguments

- hypotheses:

  Named character vector: one claim per statistic, named by the
  statistic's name as it will be recorded.

- note:

  Optional character string, default `NULL`: free text – the design, the
  data source, what would count as a refutation. Only the first element
  is kept.

- prereg:

  A declaration from `prereg_declare()`.

- reported:

  Character vector of the statistic names actually reported, or a
  manifest (any list with a named `results` element, such as a capsule
  manifest), whose result names are used.

## Value

`prereg_declare()` returns a list of class `bricklayer_prereg` with
`statistics` (the names), `hypotheses` (the claims), `note` and
`declared_utc` (ISO 8601 time). `prereg_check()` returns a list of class
`bricklayer_prereg_check` with `ok` (logical: no departures),
`declared_not_reported` and `reported_not_declared` (character vectors),
`hypotheses` (a data frame of `statistic`, `hypothesis` and logical
`reported`) and `declared_utc`. Both print a short summary.

## Details

The comparison `prereg_check()` makes is asymmetric on purpose, because
the two ways of departing from a plan are different failures:

- a declared statistic that was NOT reported is outcome switching – the
  analysis was run and its result dropped;

- a reported statistic that was NOT declared is an addition, and twenty
  of them is why a nominal p of 0.05 means nothing.

Neither is misconduct on its own and both are invisible without a
declaration made in advance.

Statistics are matched by exact name. The timestamp is the computer's
clock at the time of the call, so on its own it proves nothing; the
attestation is what fixes the date. Nothing is written to disk.

Errors: `hypotheses` not a non-empty character vector with non-empty,
unique names; `prereg` not from `prereg_declare()`.

## See also

[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
to seal a declaration,
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md)
for the controls themselves,
[`falsify_family()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsify_family.md)
for the correction that additions make necessary.

## Examples

``` r
plan <- prereg_declare(c(
  ate = "use of force is higher in the exposed division",
  n_rows = "the extract has the row count the source publishes"),
  note = "OTIS 2019-2024, division-level, pre-specified")

# afterwards, against what was reported
prereg_check(plan, c("ate", "n_rows"))$ok
#> [1] TRUE

# dropping a declared outcome is outcome switching
prereg_check(plan, "n_rows")$declared_not_reported
#> [1] "ate"

# and adding undeclared ones is what makes a nominal p meaningless
prereg_check(plan, c("ate", "n_rows", "ate_by_year",
                     "ate_by_precinct"))$reported_not_declared
#> [1] "ate_by_year"     "ate_by_precinct"

# the full check prints the departures
prereg_check(plan, c("ate", "ate_by_year"))
#> ── Against the declaration of 2026-10-15T20:11:44Z: departures below 
#>   declared but not reported (outcome switching): n_rows
#>   reported but not declared (1 addition(s)): ate_by_year
#> ──────────────────────────────────────────────────────────────────

try(prereg_declare(c("an unnamed claim")))
#> Error : `hypotheses` must be a named character vector: one claim per statistic
```
