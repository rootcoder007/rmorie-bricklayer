# Check reported odds ratios against a labelled table, under every relabelling

Given a k-by-2 table of counts (rows = groups, columns = outcome absent,
outcome present), a reference group and the odds ratios a report states
for the other groups, this recomputes the odds ratios from the table and
then under every permutation of the row labels (and with the outcome
columns swapped). It says whether the reported values follow from the
table as labelled and, if not, which relabelling reproduces them. A
four-fold odds ratio that a report gives as thirty-six-fold is typically
reproduced exactly by one such permutation.

## Usage

``` r
odds_ratio_check(counts, reference, reported, tolerance = 0.05)
```

## Arguments

- counts:

  Numeric matrix with row names (groups) and two columns (outcome
  absent, outcome present), in that order.

- reference:

  Row name of the reference group.

- reported:

  Named numeric vector of the reported odds ratios, one per
  non-reference row.

- tolerance:

  Relative tolerance for a match (default 0.05).

## Value

A list: `computed`, `reported`, `consistent`, `matches` (a data frame of
the relabellings that reproduce the reported values) and `verdict`.

## Examples

``` r
tab <- matrix(c(900, 100, 700, 300, 400, 600),
  ncol = 2, byrow = TRUE,
  dimnames = list(c("A", "B", "C"), c("no", "yes"))
)
odds_ratio_check(tab, "A", c(B = 13.5, C = 3.857))$verdict
#> [1] "the reported odds ratios do NOT follow from the table as labelled; they are reproduced under a relabelling (B -> C, C -> B): the groups were mislabelled, not the software"
```
