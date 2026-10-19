# Verify a categorical variable that crossed from one program to another

Checks a categorical variable that was moved from SPSS, Stata or SAS
into R against what the source program reported for it. You give the
frequency table the source program printed (label = count) and,
optionally, its code book (code = label); the function decodes the
imported vector and refuses to continue unless it reproduces those
counts exactly and its value labels agree with the code book. Rotated,
swapped or positionally relabelled groups fail at import, with the
permutation named.

## Usage

``` r
xfrvrf(imported, soucnts, codebook = NULL, tol = 0, strict = TRUE)
```

## Arguments

- imported:

  The vector as it arrived. It is a haven-style labelled vector, plain
  codes given with `codebook`, or labels already decoded.

- soucnts:

  Named numeric vector, label = count, as printed by the source program
  (SPSS FREQUENCIES, Stata tabulate).

- codebook:

  Optional named character vector, code = label, from the source
  program's variable view. Default `NULL`. When `imported` carries a
  `labels` attribute the two are compared and any disagreement fails the
  check.

- tol:

  Non-negative number, default `0`: the absolute difference in count
  allowed per label, passed to
  [`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md).

- strict:

  Logical, default `TRUE`: any disagreement is an error. When `FALSE`
  the result comes back with `ok = FALSE`, `reasons`, and
  `marginals$permutation` ready for
  [`rlblfrns`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rlblfrns.md).

## Value

A list with `ok` (logical), `decoded` (a factor; in code order when
decoded from codes), `marginals` (the
[`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md)
result), `code_book_ok` (logical, or `NA` when there was nothing to
compare) and `reasons` (character messages, or `NULL` when `ok`).

## Details

Steps:

1.  When `imported` has a `labels` attribute and `codebook` is given,
    the two are compared code by code; any code whose label differs (or
    that is present in only one) is a disagreement.

2.  The vector is decoded: by its `labels` attribute
    ([`declbld`](https://rootcoder007.github.io/rmorie-bricklayer/reference/declbld.md)),
    else by `codebook`, else taken as already-decoded labels.

3.  The decoded labels are checked with
    [`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md)
    against `soucnts`.

With `strict = TRUE` the first disagreement is an error. With
`strict = FALSE` both checks run and are reported. A code without a
label is an error in either mode (from the decoding step).

## See also

[`declbld`](https://rootcoder007.github.io/rmorie-bricklayer/reference/declbld.md),
[`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md),
[`rlblfrns`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rlblfrns.md)

## Examples

``` r
x <- structure(c(1, 1, 2, 4, 1),
               labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
xfrvrf(x, c(White = 3, Black = 1, Unknown = 1))$ok
#> [1] TRUE

# counts that only match under swapped labels, reported without stopping
r <- xfrvrf(x, c(White = 1, Black = 3, Unknown = 1), strict = FALSE)
r$ok
#> [1] FALSE
r$marginals$permutation
#>     White     Black   Unknown 
#>   "Black"   "White" "Unknown" 

# value labels that disagree with the source code book
try(xfrvrf(x, c(White = 3, Black = 1, Unknown = 1),
  codebook = c("1" = "White", "2" = "Other", "3" = "Black", "4" = "Unknown")))
#> Error : xfrvrf: the value labels that arrived disagree with the source code book at code(s) 2, 3: arrived 2=Black, 3=Other; source 2=Other, 3=Black
```
