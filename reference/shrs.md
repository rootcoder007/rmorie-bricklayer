# Share of a total, in percent

Expresses each count as a percentage of a total (for example each
division's share of all stops), with a Wilson confidence interval. A
share's denominator is the total of the same events, so shares over a
complete grouping sum to 100. Use
[`rtcalc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md)
instead when the denominator is a population; “40% of stops” and “40
stops per 1,000 residents” are different claims.

## Usage

``` r
shrs(x, ...)

# S3 method for class 'data.frame'
shrs(x, count = NULL, by = NULL, total = NULL, conflvl = 0.95, ...)

# Default S3 method
shrs(x, total = NULL, conflvl = 0.95, ...)
```

## Arguments

- x:

  A data frame, or a numeric vector of counts.

- ...:

  Passed to methods.

- count:

  Column of counts (required), unquoted or as a string: non-negative
  whole numbers.

- by:

  Character vector of grouping columns. Shares are computed over the
  groups, so they sum to 100 unless `total` says otherwise.

- total:

  The denominator. `NULL` (default) sums `count`, which makes the shares
  sum to 100. A number uses that number; a column name (data-frame
  method) uses the sum of that column – for the case where some of the
  total is not in the table.

- conflvl:

  Number in (0, 1), default 0.95: the confidence level of the interval.

## Value

A data frame of class `c("rmbl_share", "data.frame")` with the grouping
columns (or `label`, for a named vector), `count`, `total`, `share`,
`lower` and `upper` (percent), plus a `share` attribute: a list of
`count`, `by`, `total` and `conflvl`.

## Details

For count \\y\\ out of total \\n\\, the share is \\100\\y/n\\ and the
interval is Wilson's score interval for \\\hat p = y/n\\, \$\$\frac{\hat
p + \frac{z^2}{2n} \pm z\sqrt{\frac{\hat p(1-\hat p)}{n} +
\frac{z^2}{4n^2}}}{1 + z^2/n},\$\$ with \\z\\ the standard normal
quantile for `conflvl`, reported in percent and clipped to \\\[0,
100\]\\.

The interval is Wilson's, not the textbook normal approximation. The
normal interval on a proportion is wrong in exactly the cases people
reach for it – small counts and shares near 0 or 100, where it runs past
the ends of the scale and reports a negative percentage. Wilson's stays
inside the scale and is accurate at those counts. It treats each count
as a binomial draw from the total, which is an approximation when the
total is itself the sum of the counts.

With a data frame, counts are summed within each combination of the `by`
columns (missing values ignored), groups sorted. The default method
treats each element of `x` as a row; when `x` is named, its names become
a leading `label` column.

Errors: a count column that is not numeric or not found; negative
counts; a total of zero or below; a count larger than the total;
`conflvl` outside (0, 1).

## See also

[`rtcalc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md)
for events per population,
[`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md)
for change between periods.

## Examples

``` r
stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3))

# shares of the table's own total, summing to 100
shrs(stops, stops, by = "division")
#> ╭── Share ───────────────────────────────────────────────────────────────╮
#> │   Count     stops                                                      │
#> │   Total     492                                                        │
#> │   Groups    division                                                   │
#> │   Interval  95% Wilson                                                 │
#> │                                                                        │
#> │   division  count  total  share  95% CI                                │
#> │   --------  -----  -----  -----  --------------                        │
#> │   East          3    492   0.61  [0.21, 1.78]                          │
#> │   North       412    492  83.74  [80.22, 86.74]                        │
#> │   South        77    492  15.65  [12.71, 19.13]                        │
#> │                                                                        │
#> │   Highest share: North (83.74); lowest: East (0.6098). Their intervals │
#> │   do not overlap: the gap is more than sampling error.                 │
#> │                                                                        │
#> │   Each share is the count as a percentage of the total, with a Wilson  │
#> │   interval, which stays inside 0 to 100 for small counts.              │
#> ╰────────────────────────────────────────────────────────────────────────╯

# East is 0.6% of stops, and the interval does not run below zero
# the way a normal approximation would
shrs(stops, stops, by = "division")$lower
#> [1]  0.2075843 80.2200225 12.7074531

# a denominator from outside the table
shrs(stops, stops, by = "division", total = 10000)
#> ╭── Share ───────────────────────────────────────────────────────────────╮
#> │   Count     stops                                                      │
#> │   Total     10,000                                                     │
#> │   Groups    division                                                   │
#> │   Interval  95% Wilson                                                 │
#> │                                                                        │
#> │   division  count   total   share  95% CI                              │
#> │   --------  -----  ------  ------  ----------------                    │
#> │   East          3  10,000  0.0300  [0.0102, 0.0882]                    │
#> │   North       412  10,000  4.1200  [3.7477, 4.5275]                    │
#> │   South        77  10,000  0.7700  [0.6166, 0.9612]                    │
#> │                                                                        │
#> │   Highest share: North (4.12); lowest: East (0.03). Their intervals do │
#> │   not overlap: the gap is more than sampling error.                    │
#> │                                                                        │
#> │   Each share is the count as a percentage of the total, with a Wilson  │
#> │   interval, which stays inside 0 to 100 for small counts.              │
#> ╰────────────────────────────────────────────────────────────────────────╯

# a plain vector
shrs(c(3, 7))
#> ╭── Share ──────────────────────────────────────────────────────────────╮
#> │   Count     count                                                     │
#> │   Total     10                                                        │
#> │   Interval  95% Wilson                                                │
#> │                                                                       │
#> │   count  total  share  95% CI                                         │
#> │   -----  -----  -----  --------------                                 │
#> │       3     10     30  [10.78, 60.32]                                 │
#> │       7     10     70  [39.68, 89.22]                                 │
#> │                                                                       │
#> │   Highest share: row 2 (70); lowest: row 1 (30). Their intervals      │
#> │   overlap: the data cannot tell the two apart.                        │
#> │                                                                       │
#> │   Each share is the count as a percentage of the total, with a Wilson │
#> │   interval, which stays inside 0 to 100 for small counts.             │
#> ╰───────────────────────────────────────────────────────────────────────╯

# a count larger than its total is not a share
try(shrs(c(5, 2), total = 4))
#> Error : a count is larger than the total, so these are not shares of it. Did you mean rtcalc()?
```
