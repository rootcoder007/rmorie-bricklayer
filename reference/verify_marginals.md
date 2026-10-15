# Verify recoded category counts against the counts a release published

Compares the number of rows per category after a recode with the counts
the data source published for those categories (for example the
frequency table in a codebook or a statistical release). If they
disagree, it tries every reordering of the labels and names the one
under which the observed counts would match, which is the signature of
labels attached to the wrong groups. Use it after decoding or recoding a
column whenever published totals exist.

## Usage

``` r
verify_marginals(x, published, tolerance = 0, strict = TRUE)
```

## Arguments

- x:

  A character or factor vector after recoding.

- published:

  Named numeric vector, label = published count.

- tolerance:

  Non-negative number, default `0`. The absolute difference in counts
  allowed per label, for releases that round or suppress small counts.

- strict:

  Logical, default `TRUE`: a mismatch is an error, so a pipeline stops.
  `FALSE` returns the result with `ok = FALSE`, the `permutation` that
  would explain the counts and the `message` the error would have
  carried, for callers that want to report it or pass the permutation to
  [`relabel_forensics`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md).

## Value

A list with elements `counts` (named numeric, observed count per
published label), `published` (named numeric), `ok` (logical),
`permutation` (named character, true label = label it would have to be
read as, or `NULL`) and `message` (character, or `NULL` when `ok`). It
is returned invisibly when the counts match and visibly when
`strict = FALSE` and they do not. With `strict = TRUE` a mismatch is an
error instead.

## Details

For each label \\l\\ in `names(published)` the observed count is \\n_l =
\sum_i 1\[x_i = l\]\\ (missing values excluded). The counts match when
\\\|n_l - p_l\| \le\\ `tolerance` for every label.

On a mismatch, and when there are at most 7 labels, the function
searches the \\k!\\ permutations of the labels (5040 at \\k = 7\\) for
the first non-identity one under which the observed counts match the
published counts, and names it in the message. With more than 7 labels
no search is done and `permutation` is `NULL`. Several permutations can
match when counts are tied; only the first is reported.

A label that occurs in `x` but not in `published` is always a failure
(no permutation search). `published` must be a named numeric vector,
otherwise an error.

## See also

[`transfer_verify`](https://rootcoder007.github.io/rmorie-bricklayer/reference/transfer_verify.md),
[`relabel_forensics`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md).

## Examples

``` r
x <- c("White", "White", "Black", "Indigenous", "White", "Black")
verify_marginals(x, c(White = 3, Black = 2, Indigenous = 1))$ok
#> [1] TRUE

# swapped labels: the permutation that explains the counts is named
r <- verify_marginals(x, c(White = 2, Black = 3, Indigenous = 1),
                      strict = FALSE)
r$permutation
#>        White        Black   Indigenous 
#>      "Black"      "White" "Indigenous" 

# a release that rounds counts to the nearest 5
verify_marginals(rep(c("A", "B"), c(48, 21)), c(A = 50, B = 20),
                 tolerance = 2)$ok
#> [1] TRUE

# the default is to stop
try(verify_marginals(x, c(White = 2, Black = 3, Indigenous = 1)))
#> Error : verify_marginals: recoded counts do not match the published counts. White: observed 3, published 2; Black: observed 2, published 3; Indigenous: observed 1, published 1. The observed counts match the published ones if the labels are permuted (White -> Black, Black -> White): the labels are attached to the wrong groups.
```
