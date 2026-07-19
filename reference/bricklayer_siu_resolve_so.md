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

## Examples

``` r
bricklayer_siu_resolve_so(
  "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#> $count
#> [1] 2
#> 
#> $reason
#> [1] "max ordinal SO #2"
#> 
```
