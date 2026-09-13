# Declare an analysis before running it

Records the statistics an analysis intends to report and what each is
meant to show, so that what was actually reported can be compared
against it afterwards. Seal it with
[`capsule_attest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_attest.md)
and the declaration acquires a date it cannot be moved off.

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

  Optional free text – the design, the data source, what would count as
  a refutation.

- prereg:

  A declaration from `prereg_declare()`.

- reported:

  Character vector of the statistic names actually reported, or a
  manifest from which they are taken.

## Value

`prereg_declare()` a list of class `bricklayer_prereg`; `prereg_check()`
a list with `ok`, `declared_not_reported`, `reported_not_declared` and a
`hypotheses` data frame.

## Details

The comparison `prereg_check()` makes is asymmetric on purpose, because
the two ways of departing from a plan are different failures:

- a declared statistic that was NOT reported is outcome switching – the
  analysis was run and its result dropped;

- a reported statistic that was NOT declared is an addition, and twenty
  of them is why a nominal p of 0.05 means nothing.

Neither is misconduct on its own and both are invisible without a
declaration made in advance.

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
```
