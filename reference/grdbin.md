# Refuse a categorical column where a numeric 0/1 treatment is required

Checks that a column meant as a binary treatment or outcome indicator is
numeric 0/1 and not a factor or character column. Coercing a factor with
[`as.numeric()`](https://rdrr.io/r/base/numeric.html) returns the level
indices (1, 2, ...) rather than the data, and a mis-ordered level
silently flips every observation; this guard stops before that happens.
Call it at the top of any function that needs a 0/1 column.

## Usage

``` r
grdbin(x, col)
```

## Arguments

- x:

  The column to check.

- col:

  Character string: the column's name, used only in the error message.

## Value

`TRUE`, invisibly, when the column is a 0/1 indicator; otherwise an
error.

## Details

The checks are: `x` is an atomic vector; it is not a factor or character
vector; its distinct non-missing values are all `0` or `1`. Logical
vectors pass, because `TRUE` and `FALSE` compare equal to `1` and `0`.
Missing values are ignored. Each failure is an error that names the
column.

## See also

[`grdrcd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/grdrcd.md)
to build an explicit indicator.

## Examples

``` r
grdbin(c(0, 1, 1, 0, NA), "treated")
grdbin(c(TRUE, FALSE), "arrested")

# a factor is refused rather than coerced
try(grdbin(factor(c("control", "treated")), "treated"))
#> Error : Column ‘treated’ is categorical (‘control’, ‘treated’...). Refusing to coerce: as.numeric() on a factor returns level INDICES (1, 2, ...), not your data, and a mis-ordered level silently relabels every observation. Encode explicitly first, e.g. grdrcd() + as.integer(x == "treated_label").

# so is a numeric column with other values
try(grdbin(c(0, 1, 2), "treated"))
#> Error : Column ‘treated’ must be binary 0/1 (saw: 0, 1, 2).
```
