# Verify recoded category counts against the counts a release published

After a recode, the number of rows per label must equal the counts the
source published for those labels. If they do not, every permutation of
the labels is tried and the one under which the observed counts match
the published ones is named: the signature of labels attached to the
wrong groups.

## Usage

``` r
verify_marginals(x, published, tolerance = 0)
```

## Arguments

- x:

  A character or factor vector after recoding.

- published:

  Named numeric vector: label = published count.

- tolerance:

  Absolute count tolerance per label (default 0).

## Value

Invisibly, a list with `counts`, `published`, `ok` and `permutation`
(the relabelling that matches, or `NULL`). Errors when the counts
disagree.

## Examples

``` r
x <- c("White", "White", "Black", "Indigenous", "White", "Black")
verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))
```
