# Declare an analysis before running it

`prrgdecl()` records, before the analysis is run, the statistics it
intends to report and the claim each one is meant to test, with a UTC
timestamp. `prrgchk()` compares that declaration with what was actually
reported and lists the departures in both directions. Seal the
declaration with
[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
and it acquires a date it cannot be moved off. Use the pair to make a
pre-analysis plan checkable.

## Usage

``` r
prrgdecl(hyps, note = NULL)

prrgchk(prereg, rptd)
```

## Arguments

- hyps:

  Named character vector: one claim per statistic, named by the
  statistic's name as it will be recorded.

- note:

  Optional character string, default `NULL`: free text – the design, the
  data source, what would count as a refutation. Only the first element
  is kept.

- prereg:

  A declaration from `prrgdecl()`.

- rptd:

  Character vector of the statistic names actually reported, or a
  manifest (any list with a named `results` element, such as a capsule
  manifest), whose result names are used.

## Value

`prrgdecl()` returns a list of class `bricklayer_prereg` with
`statistics` (the names), `hypotheses` (the claims), `note` and `decutc`
(ISO 8601 time).

`prrgchk()` returns a list of class `bricklayer_prereg_check` with `ok`
(logical: no departures), the character vectors `decnotrep` and
`repnotdec`, `hypotheses` (a data frame of `statistic`, `hypothesis` and
logical `reported`) and `decutc`. Both print a short summary.

## Details

The comparison `prrgchk()` makes is asymmetric on purpose, because the
two ways of departing from a plan are different failures:

- a declared statistic that was NOT reported is outcome switching – the
  analysis was run and its result dropped;

- a reported statistic that was NOT declared is an addition, and twenty
  of them is why a nominal p of 0.05 means nothing.

Neither is misconduct on its own and both are invisible without a
declaration made in advance.

Statistics are matched by exact name. The timestamp is the computer's
clock at the time of the call, so on its own it proves nothing; the
attestation is what fixes the date. Nothing is written to disk.

Errors: `hyps` not a non-empty character vector with non-empty, unique
names; `prereg` not from `prrgdecl()`.

## See also

[`cpsatst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsatst.md)
to seal a declaration,
[`cpsfals()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md)
for the controls themselves,
[`falsfam()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/falsfam.md)
for the correction that additions make necessary.

## Examples

``` r
plan <- prrgdecl(c(
  ate = "use of force is higher in the exposed division",
  nrows = "the extract has the row count the source publishes"),
  note = "OTIS 2019-2024, division-level, pre-specified")

# afterwards, against what was reported
prrgchk(plan, c("ate", "nrows"))$ok
#> [1] TRUE

# dropping a declared outcome is outcome switching
prrgchk(plan, "nrows")$decnotrep
#> [1] "ate"

# and adding undeclared ones is what makes a nominal p meaningless
prrgchk(plan, c("ate", "nrows", "atebyyear",
                     "atebyprecinct"))$repnotdec
#> [1] "atebyyear"     "atebyprecinct"

# the full check prints the departures
prrgchk(plan, c("ate", "atebyyear"))
#> ── Against the declaration of 2026-10-19T11:34:49Z: departures below 
#>   declared but not reported (outcome switching): nrows
#>   reported but not declared (1 addition(s)): atebyyear
#> ──────────────────────────────────────────────────────────────────

try(prrgdecl(c("an unnamed claim")))
#> Error : `hyps` must be a named character vector: one claim per statistic
```
