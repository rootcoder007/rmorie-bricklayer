# Name a fiscal year by the years it spans

Turns fiscal years keyed by their END year into labels that name both
calendar years. Ontario's inmate data (and many government series) key
on the fiscal year's end year, so 2023 is the fiscal year running from
April 2022 to March 2023; this renders that as `"2022/23"`, which a
reader cannot mistake for the calendar year 2023. Pass it to
[`yoylbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoylbl.md)
to label a change table.

## Usage

``` r
fylbl(endyear, sep = "/", short = TRUE)
```

## Arguments

- endyear:

  The fiscal year's end year, as a whole number or a string; a vector of
  them.

- sep:

  Separator between the two years, a string; default `"/"`.

- short:

  Logical. `TRUE` (the default) abbreviates the second year to two
  digits, as in `"2022/23"`; `FALSE` writes it in full, as in
  `"2022/2023"`.

## Value

A character vector of labels, the same length as `endyear`, with `NA`
where a value is not a year.

## Details

Each value is converted with `as.integer(as.character(endyear))`, so a
string such as `"2023"` works; a fractional number is refused rather
than truncated (2023.7 is an error). The label is `(y - 1)`, `sep`, then
`y` itself or its last two digits. Values that cannot be read as a year
give `NA`. The two-digit form is unambiguous within a century (2000
gives `"1999/00"`).

Errors: `endyear` that is neither numeric nor character (for example
logical); a numeric year below 1; a numeric year that is not whole.

## Examples

``` r
fylbl(2019:2023)
#> [1] "2018/19" "2019/20" "2020/21" "2021/22" "2022/23"

fylbl(2023, short = FALSE)
#> [1] "2022/2023"

fylbl(2023, sep = "-")
#> [1] "2022-23"

# strings work; something that is not a year gives NA
fylbl(c("2023", "n/a", NA))
#> [1] "2022/23" NA        NA       

# logical input is refused
try(fylbl(TRUE))
#> Error : `endyear` must be numeric or character years
```
