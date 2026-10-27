# Event studies for several outcomes in one grid

Draws a list of
[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
(or
[`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md))
results in a grid of panels, one per outcome, with the same style, the
way papers show an effect on several crimes or several groups at once.

## Usage

``` r
plotevgrid(x, ncol = NULL, main = NULL, ...)
```

## Arguments

- x:

  A named list of
  [`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md)
  or
  [`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md)
  results; the names title the panels.

- ncol:

  Panels per row (default up to 3).

- main:

  Optional overall title.

- ...:

  Passed to each panel's
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) (for example
  `style = "stata"`, `shadepost = TRUE`, `refline = 0`).

## Value

Invisibly, a data frame of every panel's estimates with a column
`panel`.

## See also

[`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md),
[`plot-methods`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plot-methods.md).

## Examples

``` r
p <- polex()
es <- list(
  "Crime rate" = evstudy(p, "district", "month", "crmrate", "refmonth",
                             leads = 3, lags = 4),
  "Arrest rate" = evstudy(p, "district", "month", "arrrate", "refmonth",
                              leads = 3, lags = 4))
plotevgrid(es, style = "stata")


# your own panel: eight towns over ten years, four adopting a by-law (two
# in 2019, two in 2021), with each town's population, county and income
own <- data.frame(
  town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
  year = rep(2015:2024, times = 8)
)
i <- match(own$town, unique(own$town))
own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
own$county <- rep(c("North", "South"), 4)[i]
own$income <- 50 + own$year - 2015 + cos(seq_len(80))
own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
  0.2 * own$income + sin(seq_len(80))
plotevgrid(list(
  "Rate" = evstudy(own, "town", "year", "rate", "first", leads = 3,
                   lags = 3),
  "Income" = evstudy(own, "town", "year", "income", "first", leads = 3,
                     lags = 3)
))
```
