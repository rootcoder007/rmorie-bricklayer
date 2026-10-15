# Prove a recode with a before/after cross-tabulation

Checks, after the fact, that a recode did what you said it did. It
cross-tabulates the original values against the recoded ones and stops
with an error unless each original category went to exactly one new
category, that category is the one in your declared mapping, no rows
were lost or added, and no value became missing (or was filled in). Use
it directly after any recode, including recodes done by other code or
other software, to catch swapped groups before a model runs.

## Usage

``` r
verify_recode(original, recoded, declared)
```

## Arguments

- original, recoded:

  Atomic vectors of the same length: the values before and after the
  recode, row for row.

- declared:

  Named character vector, old = new: the mapping the analyst says was
  applied. Old values not listed are expected to be unchanged.

## Value

Invisibly, when every check passes, the cross-tabulation as a data frame
with columns `original`, `recoded` (factors) and `Freq` (integer),
including the zero cells of the full table. Otherwise an error.

## Details

Factors are compared through their labels. The checks, in order:

1.  `original` and `recoded` are atomic and the same length;

2.  `is.na(original)` equals `is.na(recoded)` element by element;

3.  in the table of non-missing pairs, no original value has more than
    one recoded value (the recode is a function of the label);

4.  each original value's recoded value equals `declared[old]`; an
    original value that is not a name of `declared` must be unchanged
    (identity).

The first failed check is an error naming the offending categories.

## See also

[`guard_recode`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md),
[`recode_manifest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md).

## Examples

``` r
before <- c("W", "B", "W", NA)
after <- c("White", "Black", "White", NA)
tab <- verify_recode(before, after, c(W = "White", B = "Black"))
tab[tab$Freq > 0, ]
#>   original recoded Freq
#> 1        B   Black    1
#> 4        W   White    2

# a value not in the declared mapping must be unchanged
verify_recode(c("W", "X"), c("White", "X"), c(W = "White"))

# swapped groups are caught
try(verify_recode(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black")))
#> Error : verify_recode: ‘B’ was mapped to ‘White’ but the declared mapping says ‘Black’. THIS is how groups get swapped; fix the recode before any model runs.

# a value that became NA is caught
try(verify_recode(c("W", "B"), c("White", NA), c(W = "White", B = "Black")))
#> Error : verify_recode: missingness changed during the recode (values silently became NA, or NAs were filled).
```
