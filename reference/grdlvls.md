# Build a factor with explicit, verified levels

Creates a factor whose levels you write out in full and in order,
instead of letting [`factor()`](https://rdrr.io/r/base/factor.html) sort
them alphabetically. The first level is the reference category of every
regression fitted on the factor, so writing the levels out decides the
baseline on purpose. Values outside the declared levels are an error,
and you can assert which level is the reference so that a later edit to
`lvls` cannot change it unnoticed.

## Usage

``` r
grdlvls(x, lvls, ref = NULL)
```

## Arguments

- x:

  Character or factor vector. A factor is read through its labels.

- lvls:

  Character vector of every allowed level, in the intended order. The
  first element is the reference category.

- ref:

  Optional character string, default `NULL` (no check). When given it
  must equal `levels[1]`; use it to state the intended baseline next to
  the code that fits the model.

## Value

A factor with exactly the levels in `levels`, in that order.

## Details

The function checks that every non-missing value of `x` is in `lvls`,
then returns `factor(x, levels = levels)`. Declared levels that do not
occur are kept as empty levels (they still appear in tables with a count
of zero).

Errors:

- `lvls` not a non-empty character vector, or containing `NA`;

- a value of `x` not in `lvls` (listed in the message);

- `ref` given and not identical to `levels[1]`.

## See also

[`grdrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md),
[`audcats`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audcats.md).

## Examples

``` r
# reference category chosen on purpose, not by alphabet
g <- grdlvls(c("White", "Black", "White"), c("White", "Black"), "White")
levels(g)
#> [1] "White" "Black"

# a declared level that does not occur is kept, with a zero count
table(grdlvls(c("a", "a"), c("a", "b")))
#> 
#> a b 
#> 2 0 

# a stray value, or a reference that is not first, is refused
try(grdlvls(c("White", "Blak"), c("White", "Black")))
#> Error : grdlvls: values outside the declared levels: ‘Blak’
try(grdlvls(c("White", "Black"), c("White", "Black"), ref = "Black"))
#> Error : grdlvls: declared reference ‘Black’ is not levels[1] (‘White’); reorder `lvls` so the reference is explicit and first.
```
