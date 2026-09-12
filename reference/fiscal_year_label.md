# Name a fiscal year by the years it spans

Ontario's inmate data keys on the fiscal year's END year, so 2023 is the
fiscal year running from April 2022 to March 2023. This renders that as
`"2022/23"`.

## Usage

``` r
fiscal_year_label(end_year, sep = "/", short = TRUE)
```

## Arguments

- end_year:

  The fiscal year's end year, as a number or a string.

- sep:

  Separator between the two years.

- short:

  Whether to abbreviate the second year to two digits.

## Value

A character vector of labels.

## Examples

``` r
fiscal_year_label(2019:2023)
#> [1] "2018/19" "2019/20" "2020/21" "2021/22" "2022/23"

fiscal_year_label(2023, short = FALSE)
#> [1] "2022/2023"

fiscal_year_label(2023, sep = "-")
#> [1] "2022-23"
```
