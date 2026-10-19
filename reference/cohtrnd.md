# Raw outcome trends by adoption cohort

The mean outcome of each adoption cohort by time since adoption,
smoothed by a moving average and scaled to 1 in the period before
adoption: a check, before any model, that the cohorts moved together
before the policy.

## Usage

``` r
cohtrnd(data, unit, time, y, ftreat, win = c(-12, 12), ma = 3L, norm = TRUE)
```

## Arguments

- data:

  A data frame, one row per unit and period.

- unit, time, y:

  Column names: the unit, the period (numeric, for example a year or a
  month index) and the outcome.

- ftreat:

  Column name of the period a unit is first treated (`NA`, 0 or `Inf`
  for a unit never treated). Treatment is taken as staying on.

- win:

  Periods before and after adoption to show (default -12 to 12).

- ma:

  Width of the trailing moving average (default 3; 1 for none).

- norm:

  Scale each cohort to 1 at period -1 (default `TRUE`).

## Value

A data frame of class `rmbl_cohort_trends`: `cohort`, `evtm`, `value`.
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws one line
per cohort, with the period before adoption marked.

## Examples

``` r
p <- polex()
ct <- cohtrnd(p, "district", "month", "crmrate", "refmonth",
                    win = c(-10, 10))
plot(ct)
```
