# Check reported odds ratios against a labelled table, under every relabelling

Recomputes the odds ratios a report gives for each group from the
underlying table of counts, and says whether the reported values follow
from the table as it is labelled. If they do not, it tries every
reassignment of the group labels (and the two outcome columns swapped)
and lists the relabellings that do reproduce the reported values. Use it
when a published odds ratio looks implausible: a four-fold ratio
reported as thirty-six-fold is typically reproduced exactly by one such
relabelling, which shows the groups were mislabelled rather than the
arithmetic wrong.

## Usage

``` r
orchk(cnts, ref = NULL, rptd, tol = 0.05)
```

## Arguments

- cnts:

  Numeric matrix, data frame or table of counts with row names (the
  groups) and exactly two columns: outcome absent, then outcome present.

- ref:

  Character string: the row name of the reference group.

- rptd:

  Named numeric vector of the odds ratios the report states, one per
  non-reference group, named by group. Extra names are ignored.

- tol:

  Number, default `0.05`: the relative tolerance for a match (5
  percent), to allow for rounding in the report.

## Value

A list of class `rmbl_or_check` (it prints as a box) with elements
`computed` (named numeric odds ratios from the table as labelled),
`reported` (the reported values, in the same order), `consistent`
(logical), `matches` (a data frame with character `relabelling`, for
example `"B -> C, C -> B"`, and logical `outcome_columns_swapped`, one
row per relabelling that reproduces the reported values) and `verdict`
(a one-sentence character summary).

## Details

With row \\r\\ holding \\a_r\\ (outcome absent) and \\b_r\\ (outcome
present), the odds ratio of group \\r\\ against the reference \\0\\ is
\$\$OR_r = \frac{b_r / a_r}{b_0 / a_0}.\$\$ A reported value matches
when \\\|OR_r - \widehat{OR}\_r\| \le\\ `tol` \\\times
\|\widehat{OR}\_r\|\\ for every non-reference group, and all values are
finite. The search covers all \\k!\\ permutations of the row labels,
each with and without the outcome columns swapped (the identity without
a swap is the “as labelled” check), and is only run for \\k \le 7\\
groups. A zero cell gives an infinite or undefined odds ratio, which
never matches.

Errors: `cnts` not a matrix, data frame or table with two columns and
row names; `ref` not a row name; `rptd` not named by every non-reference
row.

## See also

[`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md),
[`rlblfrns`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rlblfrns.md).

## Examples

``` r
tab <- matrix(c(900, 100, 700, 300, 400, 600),
  ncol = 2, byrow = TRUE,
  dimnames = list(c("A", "B", "C"), c("no", "yes"))
)
# the odds ratios as labelled: B 3.86, C 13.5
orchk(tab, "A", c(B = 3.857, C = 13.5))$consistent
#> [1] TRUE

# a report that swapped B and C
chk <- orchk(tab, "A", c(B = 13.5, C = 3.857))
chk$matches
#>      relabelling outcome_columns_swapped
#> 1 B -> C, C -> B                   FALSE
chk$verdict
#> [1] "the reported odds ratios do NOT follow from the table as labelled; they are reproduced under a relabelling (B -> C, C -> B): the groups were mislabelled, not the software"

# every non-reference group needs a reported value
try(orchk(tab, "A", c(B = 3.857)))
#> Error : orchk: `rptd` must be named by every non-reference row: ‘B’, ‘C’
```
