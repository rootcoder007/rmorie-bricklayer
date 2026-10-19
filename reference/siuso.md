# Resolve the subject-official count from SIU report text

Counts the subject officials (SO), the officers whose conduct the SIU
investigated, from the plain text of one report, and says which rule
gave the answer. Use it for reports where a model panel or a human coder
is unsure, so that the number is reproducible and its evidence can be
checked.

## Usage

``` r
siuso(text)
```

## Arguments

- text:

  A length-1 character vector of plain report text (see
  [`siutxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siutxt.md)),
  not HTML.

## Value

A list with two elements: `count` (integer, `NA` when unresolved) and
`reason` (character, the rule that fired and its evidence, for example
`"plural cue 'three subject officials'"`).

## Details

The standard SIU privacy paragraph and the witness-officer glossary note
are stripped first (both mention "subject officer" without naming one).
The rules then run most-specific first and the first that applies wins:

1.  the roster under the "Subject Officials"/"Subject Officers" heading:
    the larger of the highest `SO #N` ordinal and the number of entries;

2.  the highest `SO #N` ordinal in the whole document, trusted only when
    `SO #1` is also present;

3.  a spelled-out or numeric plural ("two subject officials");

4.  a singular subject official present (1);

5.  an explicit statement that there was no subject official, or witness
    officials listed and no subject official anywhere (0, a real
    answer);

6.  otherwise unresolved (`NA`).

French reports use the same rules in their vocabulary (the subject
official is tagged "AI no 1", the witness official "AT no 1").

This function is the pure rule set. For reports that already have a
panel-reviewed count, prefer that verified value; use these rules for
unreviewed reports.

Error: `text` that is not a single non-NA string.

## Examples

``` r
siuso(
  "Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#> $count
#> [1] 2
#> 
#> $reason
#> [1] "section: max(ordinal 2, entries 2)"
#> 

# witness officials only: zero is the answer
siuso("Witness Officials\nWO #1 Interviewed\nWO #2 Interviewed")
#> $count
#> [1] 0
#> 
#> $reason
#> [1] "zero: witness officials only, no subject official named"
#> 

# a spelled-out plural, and an unresolved text
siuso("Three subject officials were designated.")$count
#> [1] 3
siuso("No officers are named here.")
#> $count
#> [1] NA
#> 
#> $reason
#> [1] "UNRESOLVED: 'the SO'x0 'the subj off'x0"
#> 

# HTML or several strings are not text
try(siuso(c("a", "b")))
#> Error : `text` must be a single string of report text
```
