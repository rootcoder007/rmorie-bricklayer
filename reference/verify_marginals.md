# Verify recoded category counts against the counts a release published

After a recode, the number of rows per label must equal the counts the
source published for those labels. If they do not, every permutation of
the labels is tried and the one under which the observed counts match
the published ones is named: the signature of labels attached to the
wrong groups.

## Usage

``` r
verify_marginals(x, published, tolerance = 0, strict = TRUE)
```

## Arguments

- x:

  A character or factor vector after recoding.

- published:

  Named numeric vector: label = published count.

- tolerance:

  Absolute count tolerance per label (default 0).

- strict:

  When `TRUE` (the default) a mismatch is an error, so a pipeline stops
  on the day. When `FALSE` the result is returned with `ok = FALSE`, the
  `permutation` that would explain the counts, and the `message` the
  error would have carried, for callers that want to report or hand the
  permutation to
  [`relabel_forensics()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md).

## Value

Invisibly, a list with `counts`, `published`, `ok`, `permutation` (the
relabelling that matches, or `NULL`) and `message` (`NULL` when `ok`).
Errors when the counts disagree and `strict` is `TRUE`.

## Examples

``` r
x <- c("White", "White", "Black", "Indigenous", "White", "Black")
verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))
```
