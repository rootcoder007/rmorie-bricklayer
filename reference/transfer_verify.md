# Verify a categorical variable that crossed from one program to another

The transfer that matters is SPSS/Stata/SAS to R or Python: the source
program stores codes plus value labels, the destination is handed the
codes, and the labels are re-attached in the analysis. This function
takes what the source program printed for that variable (its frequency
table, label = count, and optionally its code book, code = label) and
refuses to continue unless the imported vector reproduces it exactly.
Rotated, swapped or positionally relabelled groups fail here, on the day
of the import, with the permutation named.

## Usage

``` r
transfer_verify(imported, source_counts, code_book = NULL, tolerance = 0)
```

## Arguments

- imported:

  The vector as it arrived: a haven-style labelled vector, plain codes
  (with `code_book`), or already-decoded labels.

- source_counts:

  Named numeric vector, label = count, as printed by the source program
  (SPSS FREQUENCIES, Stata tabulate).

- code_book:

  Optional named character vector, code = label, from the source
  program's variable view. When `imported` carries a `labels` attribute
  the two are compared and any disagreement is an error.

- tolerance:

  Passed to
  [`verify_marginals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_marginals.md).

## Value

A list with `ok`, `decoded` (a factor in code order), `marginals` (the
[`verify_marginals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_marginals.md)
result) and `code_book_ok`.

## See also

[`decode_labelled`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_labelled.md),
[`verify_marginals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_marginals.md),
[`relabel_forensics`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md)

## Examples

``` r
x <- structure(c(1, 1, 2, 4, 1),
               labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
transfer_verify(x, c(White = 3, Black = 1, Unknown = 1))$ok
#> [1] TRUE
```
