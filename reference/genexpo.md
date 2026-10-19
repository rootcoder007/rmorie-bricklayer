# Generations of residential school attendance in a family

Codes the intergenerational exposure used in the epidemiology of Indian
Residential Schools: how many generations before the respondent
attended, 0 (neither parents nor grandparents), 1 (parents or
grandparents) or 2 (both a parent and a grandparent), as in McQuaid et
al. (2017).

## Usage

``` r
genexpo(parent, gparent, partial = c("na", "lowerbnd"))
```

## Arguments

- parent, gparent:

  Logical vectors: did a parent, did a grandparent attend.

- partial:

  What a known attendance with the other generation unknown counts as:
  `"na"` (not known, the default) or `"lowerbnd"` (1).

## Value

An integer vector of 0, 1, 2 or `NA`.

## Details

Each answer is `TRUE` (attended), `FALSE` (did not) or `NA` (not known).
An unknown answer may hide an attendance, so the count is unknown (`NA`)
whenever an unknown answer could change it: always when the known answer
is `FALSE`, and, with `partial = "na"` (the default), also when the
known answer is `TRUE` (the count is 1 or 2). `partial = "lowerbnd"`
codes that case 1, a lower bound: it keeps the person but can classify
them a level too low, which biases a trend toward no effect.

## References

McQuaid RJ, Bombay A, McInnis OA, Humeny C, Matheson K, Anisman H
(2017). Suicide ideation and attempts among First Nations peoples living
on-reserve in Canada: the intergenerational and cumulative effects of
Indian Residential Schools. Canadian Journal of Psychiatry
62(6):422-430.
[doi:10.1177/0706743717702075](https://doi.org/10.1177/0706743717702075)

Bombay A, Matheson K, Anisman H (2014). The intergenerational effects of
Indian Residential Schools: implications for the concept of historical
trauma. Transcultural Psychiatry 51(3):320-338.
[doi:10.1177/1363461513503380](https://doi.org/10.1177/1363461513503380)

## See also

[`exptrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exptrnd.md).

## Examples

``` r
genexpo(c(TRUE, FALSE, TRUE, NA, FALSE), c(TRUE, FALSE, FALSE, TRUE, NA))
#> [1]  2  0  1 NA NA
genexpo(c(TRUE, FALSE, TRUE, NA, FALSE), c(TRUE, FALSE, FALSE, TRUE, NA),
                    partial = "lowerbnd")
#> [1]  2  0  1  1 NA
```
