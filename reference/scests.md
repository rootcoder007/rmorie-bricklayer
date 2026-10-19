# The estimates of a Statistics Canada table, with their confidence limits

Statistics Canada's tables give each estimate on several rows: the
estimate itself (a percent, a rate, a count, a life expectancy), its low
and high confidence limits, or its coefficient of variation or standard
error, all in one statistics column (`Statistics`, `Characteristics`,
`Statistics (3)`, ...). This puts them side by side, one row per cell of
the table and measure, ready for
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
[`ordcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md),
[`stdprev`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md)
and the rest. Every table reads: one without a statistics column (a
census count) gives each value as its own estimate, with no limits.

## Usage

``` r
scests(x)
```

## Arguments

- x:

  A table read by
  [`sctidy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sctidy.md),
  a data frame as downloaded, or a table key.

## Value

A data frame, one row per cell and measure: the identifying columns,
`measure`, `estimate`, `lower`, `upper`, `cisou` and `quality`; the
attribute `conflvl` is the level of the limits, and `unmatched` names
any limits that could not be matched to one measure.

## Details

Each label of the statistics column is read as an estimate or as one of
its measures of precision, in every form the tables use:

- `"Low 95% confidence interval"`;

- `"High 95% confidence interval, age-standardized rate"`;

- `"Confidence interval lower bound of count"`;

- `"95% confidence interval (upper limit)"`;

- `"95% confidence interval lower bound, 2020"`;

- `"Coefficient of variation for percent"`;

- `"Standard error"`.

A limit that names its measure is matched to it (ignoring case and
spacing); one that names none, or a name that fits several measures
(`"potential years of life lost"` in a table with a number, a crude rate
and an age-standardised rate of them), is matched to the measure with
the same unit (`UOM`) whose estimates it contains in every cell, and
left unmatched (said in the attribute `unmatched`) if no single measure
fits. A coefficient of variation \\c\\ (in percent) gives log-normal
limits \\e \exp(\mp z \sqrt{\log(1 + (c/100)^2)})\\, which stay positive
however large \\c\\ is; a standard error \\s\\ the limits \\e \mp z s\\;
the column `cisou` says which (`"published"`, `"cv"` or `"se"`).
Published limits that do not contain their own estimate (it happens: a
100\\ 98.6 in table 41-10-0012) are kept as published and marked
`"inconsistent"`; every comparison of the family warns and leaves such a
row out. A limit is matched to a measure when it fits 95\\
English-language tables.

Every other column but the metadata (`VECTOR`, `COORDINATE`, `UOM`, ...)
identifies the cell, `DGUID` among them (one place name can name several
geographies), with the spaces some labels end in trimmed. The quality
flag is the estimate's: an `F` or `x` estimate is `NA` (see
[`sctidy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sctidy.md)),
and so are its limits.

## References

Statistics Canada (2023). Self-perceived mental health of First Nations
people living off reserve, Metis and Inuit by age group and gender.
Table 41-10-0067-01.
[doi:10.25318/4110006701-eng](https://doi.org/10.25318/4110006701-eng)

## See also

[`sctidy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/sctidy.md),
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
[`ordcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md).

## Examples

``` r
# the layout of a downloaded table: percent and number of persons, with limits for the
# percent
d <- data.frame(REF_DATE = "2022", GEO = "Canada",
                `Indigenous identity` = rep(c("First Nations", "Metis"), each = 4),
                Statistics = rep(c("Number of persons", "Percent",
                                   "Low 95% confidence interval",
                                   "High 95% confidence interval"), 2),
                UOM = rep(c("Persons", "Percent", "Percent", "Percent"), 2),
                VALUE = c(415000, 47.1, 45.2, 49.0, 320000, 50.3, 48.1, 52.5),
                STATUS = "", check.names = FALSE)
scests(d)
#>   REF_DATE    GEO Indigenous identity           measure estimate lower upper
#> 1     2022 Canada       First Nations Number of persons 415000.0    NA    NA
#> 2     2022 Canada       First Nations           Percent     47.1  45.2  49.0
#> 3     2022 Canada               Metis Number of persons 320000.0    NA    NA
#> 4     2022 Canada               Metis           Percent     50.3  48.1  52.5
#>       cisou quality
#> 1      <NA>      ok
#> 2 published      ok
#> 3      <NA>      ok
#> 4 published      ok
# a rate with its coefficient of variation instead of limits
r <- data.frame(GEO = "Canada",
                Characteristics = c("Rate", "Coefficient of variation for rate"),
                VALUE = c(12.5, 8), STATUS = "")
scests(r)
#>      GEO measure estimate    lower    upper cisou quality
#> 1 Canada    Rate     12.5 10.68864 14.61832    cv      ok
```
