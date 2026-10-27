# Length of stay with its distribution and interval

Where
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
takes the total days and returns a mean, this takes one value per person
and reports the spread as well, because a mean stay is a poor summary of
a distribution that is usually skewed.

## Usage

``` r
staysmry(daysperper, conflvl = 0.95)
```

## Arguments

- daysperper:

  Numeric vector of days served, one element per person; non-negative,
  no `NA` or `Inf`, at least one value.

- conflvl:

  Numeric scalar strictly between 0 and 1, the confidence level for the
  interval on the mean. Default `0.95`.

## Value

A one-row data frame of class `c("rmbl_stay_summary", "data.frame")`
(its print method shows it as a box) with numeric columns `n` (people),
`totaldays`, `mean`, `sd` (sample standard deviation), `median`, `iqr`
(interquartile range, quantile type 7), `max`, `se` (standard error of
the mean), `lower` and `upper` (the t interval on the mean). With a
single person `sd`, `se`, `lower` and `upper` are `NA`.

## Details

The interval is the ordinary t interval on a mean, \\\bar{x} \pm
t\_{n-1, 1-\alpha/2}\\ s / \sqrt{n}\\. It describes uncertainty about
the AVERAGE stay, not the spread of stays, and on a skewed distribution
the median and the interquartile range say more about a typical stay
than the mean does – which is why they are returned beside it rather
than left to be asked for.

Lakner's caveat on
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
applies here too (1976, p.16-17): a person still held has an unfinished
stay, so a window shorter than the longest stay biases the mean
DOWNWARD.

Errors when `daysperper` is not numeric, is empty, or has `NA`, `Inf` or
negative values, and when `conflvl` is not strictly inside (0, 1).

## See also

[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`stkflow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md)

## Examples

``` r
# a skewed distribution: most stays short, a few long
stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
staysmry(stays)
#> ╭── Length of stay ─────────────────────────────────────────────────────╮
#> │   People               93                                             │
#> │   Days served          600                                            │
#> │   Mean stay            6.452 days                                     │
#> │   Median stay          3 days                                         │
#> │   Interquartile range  2 days                                         │
#> │   Longest stay         120 days                                       │
#> │   Standard deviation   16.33                                          │
#> │   Mean, interval       [3.088, 9.815] 95% t interval                  │
#> │                                                                       │
#> │   The mean stay is 2.2 times the median: a few long stays pull it up, │
#> │   so the median says more about a typical stay.                       │
#> │                                                                       │
#> │   The interval is on the AVERAGE stay, not the spread of stays.       │
#> │   Lakner (1976, p.16-17): a person still held has an unfinished stay, │
#> │   so a window shorter than the longest stay biases the mean downward. │
#> ╰───────────────────────────────────────────────────────────────────────╯

# the mean is pulled well above the median by the long tail
staysmry(stays)[, c("mean", "median", "max")]
#>       mean median max
#> 1 6.451613      3 120

# a 90% interval instead of 95%
staysmry(stays, conflvl = 0.90)[, c("mean", "lower", "upper")]
#>       mean    lower   upper
#> 1 6.451613 3.637665 9.26556

# a confidence level of 1 is refused
try(staysmry(stays, conflvl = 1))
#> Error : staysmry: `conflvl` must be a single number strictly between 0 and 1
```
