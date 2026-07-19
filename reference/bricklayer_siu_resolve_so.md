# Resolve the subject-official count from SIU report text

Deterministic, reproducible extraction of the subject-official (SO)
count for reports where a model panel (or a human) is unsure. The
standard SIU privacy boilerplate is stripped first, then rules apply
most-specific first: highest `SO #N` ordinal; spelled-out plural;
singular subject official present (1); witness-official-only (0, a real
answer); otherwise unresolved (`NA`).

## Usage

``` r
bricklayer_siu_resolve_so(text)
```

## Arguments

- text:

  A length-1 character vector of plain report text (see
  [`bricklayer_siu_text()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_siu_text.md)).

## Value

A list with `count` (integer, `NA` when unresolved) and `reason` (the
human-readable evidence).

## Details

bricklayer is the foundation layer: this function is the pure rule set.
Reports already in the panel-reviewed corpus should never be re-derived
– use `rmorie::morie_siu_resolve_so()`, which returns the verified
corpus value first and only falls back to these rules for unreviewed
reports.

## Examples

``` r
bricklayer_siu_resolve_so(
  "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#> $count
#> [1] 2
#> 
#> $reason
#> [1] "section: max(ordinal 2, entries 2)"
#> 
```
