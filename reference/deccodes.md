# Decode numeric category codes with an explicit code-to-label dictionary

Turns a vector of category codes (for example `1`, `2`, `3` from an
SPSS, Stata or SAS file) into the category labels they stand for, using
a code-to-label dictionary that you write out. Every code that occurs in
the data must be in the dictionary; a code without a label is an error
rather than a silent `NA` or a pass-through. Use it whenever a column
arrives as numbers that are really categories, before any table or
model, so that a group can never be renumbered by treating codes (or
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) on a factor of
them) as the categories.

## Usage

``` r
deccodes(x, vlabs, keepna = TRUE)
```

## Arguments

- x:

  Vector of codes: numeric, integer, character or factor. A factor is
  read through its labels, not its integer codes; an ordered factor is
  treated the same as an unordered one (its level order is not used).

- vlabs:

  Named character vector, code = label, for example
  `c("1" = "White", "2" = "Black")`. The names are the codes as they
  print with [`as.character()`](https://rdrr.io/r/base/character.html);
  the values are the labels. Codes in the dictionary that do not occur
  in `x` are allowed.

- keepna:

  Logical, default `TRUE`: `NA` codes stay `NA` in the result. `FALSE`
  makes any `NA` code an error, for columns where missingness should not
  occur.

## Value

A character vector of labels, the same length as `x`, with `NA` where
`x` is `NA`. It carries a `recode_audit` attribute: a list with
`mapping` (the dictionary), `kept` (`character(0)`) and `checksum`
(64-character hexadecimal SHA-256 of the `code=label` pairs).

## Details

`x` is converted to character (a factor by its labels, a number by
[`as.character()`](https://rdrr.io/r/base/character.html), so `1` and
`1.0` both become `"1"`) and every distinct non-missing code is looked
up by name in `vlabs`. The lookup itself is done by
[`grdrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md),
so the result carries the same `recode_audit` attribute, including a
SHA-256 of the dictionary.

Errors:

- `vlabs` not a character vector with non-empty names;

- a code in `x` that is not a name of `vlabs` (the message lists the
  unmapped codes);

- any `NA` in `x` when `keepna = FALSE`.

For a haven-style labelled vector, which carries its dictionary as a
`labels` attribute, use
[`declbld`](https://rootcoder007.github.io/rmorie-bricklayer/reference/declbld.md),
which returns a factor with the levels in code order.

## See also

[`declbld`](https://rootcoder007.github.io/rmorie-bricklayer/reference/declbld.md),
[`grdrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md),
[`audcats`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audcats.md).

## Examples

``` r
# codes from a survey file with their code book
race <- c(1, 2, 2, 3, NA)
book <- c("1" = "White", "2" = "Black", "3" = "Indigenous")
deccodes(race, book)
#> [1] "White"      "Black"      "Black"      "Indigenous" NA          
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>            1            2            3 
#>      "White"      "Black" "Indigenous" 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] "be0b0dcd1bb12223f6d28bc031e1accfd45a3f700d18c920b54d7d766905bdd0"
#> 

# the dictionary that was applied is kept on the result
attr(deccodes(race, book), "recode_audit")$checksum
#> [1] "be0b0dcd1bb12223f6d28bc031e1accfd45a3f700d18c920b54d7d766905bdd0"

# a code with no label is refused, never passed through
try(deccodes(c(1, 2, 9), book))
#> Error : grdrcd: values with NO mapping: ‘9’. Every observed category must be mapped by name (or listed in `keep`); silent pass-through is how group labels get corrupted.

# missing codes can be refused too
try(deccodes(race, book, keepna = FALSE))
#> Error : deccodes: `x` has missing codes and keep_na = FALSE
```
