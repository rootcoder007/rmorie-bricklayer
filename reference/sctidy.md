# Read a Statistics Canada table as published

Tidies a Statistics Canada full-table download (the “CSV for database
loading” form, as the data service mirrors it under
`statcan_indigenous/tbl_<pid>`): `VALUE` as a number, and the quality
flags kept beside it in `quality`.

## Usage

``` r
sctidy(x)
```

## Arguments

- x:

  A data frame read from a Statistics Canada table (English-language
  full-table CSV), or a key of the data service
  (`"statcan_indigenous/tbl_13100924"`, or the eight-digit table id
  alone). A key needs a data service key: sign in once with
  [`dlogin`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md)
  (see
  [`dload`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dmnf.md));
  a data frame you read yourself needs none.

## Value

The data frame with `VALUE` numeric and a factor column `quality` with
levels `"ok"`, `"E"`, `"F"`, `"x"`, `".."`, `"..."`, of class
`c("rmbl_statcan", "data.frame")`.

## Details

Statistics Canada flags every estimate: `E` use with caution, `F` too
unreliable to be published, `x` suppressed to meet the confidentiality
requirements of the Statistics Act, `..` not available, `...` not
applicable. An `F`, `x`, `..` or `...` cell has no value here (`NA`),
whatever the file holds, and nothing in the package imputes it or works
it back from totals and margins: a suppressed cell is suppressed to
protect people, and small First Nations, Metis and Inuit communities
most of all. `E` values are kept and marked.

The census data tables (98-10-xxxx) come in a wide layout: one column
per member of a dimension (`"Indigenous identity (9):Inuk (Inuit)[6]"`),
each followed by its `Symbol` column, and no `VALUE`. They are made long
first: the dimension becomes a column of member labels
(`"Indigenous identity (9)"`), the values `VALUE` and the symbols
`STATUS`, so every Statistics Canada table reads the same way.

A label that names two members of one dimension (the census tables
repeat labels under different parents, and the file drops the hierarchy)
gets its member number from the coordinate: `"Without children [3]"` and
`"Without children [7]"`. Other labels are left as they are.

## References

Statistics Canada. Symbol legend.
<https://www.statcan.gc.ca/en/concepts/definitions/guide-symbol>

## See also

[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
[`indtabs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indtabs.md).

## Examples

``` r
# the layout of a downloaded table, with one cell suppressed
d <- data.frame(REF_DATE = "2019/2022", GEO = "Canada",
                `Indigenous identity` = c("First Nations", "Inuk (Inuit)",
                                          "Non-Indigenous"),
                VALUE = c("45.8", "", "61.5"), STATUS = c("", "x", ""),
                check.names = FALSE)
sctidy(d)
#>    REF_DATE    GEO Indigenous identity VALUE STATUS quality
#> 1 2019/2022 Canada       First Nations  45.8             ok
#> 2 2019/2022 Canada        Inuk (Inuit)    NA      x       x
#> 3 2019/2022 Canada      Non-Indigenous  61.5             ok
if (FALSE) { # interactive()
# needs a data service key: sign in once with dlogin()
t924 <- sctidy("13100924")
}
```
