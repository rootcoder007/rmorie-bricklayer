# Length of stay with its distribution and interval

Where
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
takes the total days and returns a mean, this takes one value per person
and reports the spread as well, because a mean stay is a poor summary of
a distribution that is usually skewed.

## Usage

``` r
stay_summary(days_per_person, conf_level = 0.95)
```

## Arguments

- days_per_person:

  Days served, one element per person.

- conf_level:

  Confidence level for the interval on the mean.

## Value

A one-row data frame: `n`, `total_days`, `mean`, `sd`, `median`, `iqr`,
`max`, `se`, `lower`, `upper`.

## Details

The interval is the ordinary t interval on a mean. It describes
uncertainty about the AVERAGE stay, not the spread of stays, and on a
skewed distribution the median and the interquartile range say more
about a typical stay than the mean does – which is why they are returned
beside it rather than left to be asked for.

Lakner's caveat on
[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md)
applies here too (1976, p.16-17): a person still held has an unfinished
stay, so a window shorter than the longest stay biases the mean
DOWNWARD.

## See also

[`alos()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/alos.md),
[`adp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/adp.md),
[`stock_flow()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stock_flow.md)

## Examples

``` r
# a skewed distribution: most stays short, a few long
stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
stay_summary(stays)
#>    n total_days     mean       sd median iqr max       se    lower    upper
#> 1 93        600 6.451613 16.33183      3   2 120 1.693532 3.088113 9.815113

# the mean is pulled well above the median by the long tail
stay_summary(stays)[, c("mean", "median", "max")]
#>       mean median max
#> 1 6.451613      3 120
```
