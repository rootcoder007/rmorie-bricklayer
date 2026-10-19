# Event rates per unit of population

Turns counts of events (arrests, stops, admissions, deaths) into rates
per unit of exposure, such as per 1,000 or per 100,000 residents, with
an exact Poisson confidence interval for each rate. A count is not
comparable across areas of different size or years of different
population; a rate is. The interval says how much of a rate is signal:
three events in a small area give a rate whose interval is several times
its own width.

## Usage

``` r
rtcalc(x, ...)

# S3 method for class 'data.frame'
rtcalc(x, count, pop, by = NULL, per = 1000,
  conflvl = 0.95, mincnt = 0, ...)

# Default S3 method
rtcalc(x, pop, per = 1000, conflvl = 0.95, mincnt = 0, ...)
```

## Arguments

- x:

  A data frame, or a numeric vector of counts.

- ...:

  Passed to methods.

- count:

  Column of counts, given unquoted or as a string: non-negative whole
  numbers.

- pop:

  For the data-frame method, the column of exposure, unquoted or as a
  string; for the default method, a numeric vector the length of `x` (or
  one number, recycled). Positive. Person-years, stops, residents –
  whatever the events were at risk of happening to.

- by:

  Character vector of grouping columns, default `NULL`. The rate is
  computed within each group.

- per:

  The rate denominator: a positive number, or `"1k"`, `"10k"`, `"100k"`,
  `"1m"`. Default 1000.

- conflvl:

  Number in (0, 1), default 0.95: the confidence level of the interval.

- mincnt:

  Number, default 0. Counts at or below this are flagged as too small to
  report, with the rate still computed. The default flags nothing;
  published guidance often uses 5 or 10.

## Value

A data frame of class `c("rmbl_rate", "data.frame")` with the grouping
columns (or `label`, for a named vector), `count`, `population`, `rate`,
`lower`, `upper` (numeric, rates per `per`) and `flag` (character, `NA`
when not flagged), plus a `rate` attribute: a list of `count`,
`population`, `by`, `per`, `perlbl` (for example `"per 100,000"`),
`conflvl` and `mincnt`. The print method titles the table with the
denominator and the interval.

## Details

For count \\y\\ and exposure \\t\\, the rate is \\\mathrm{per} \times y
/ t\\. The interval is the exact Poisson interval for \\y\\, computed
through the gamma relation, \$\$\left\[G^{-1}(\alpha/2;\\ y),\\
G^{-1}(1 - \alpha/2;\\ y + 1)\right\] \times \mathrm{per} / t,\$\$ with
\\G^{-1}(p; k)\\ the gamma quantile with shape \\k\\; a count of zero
has a lower limit of exactly zero. This is the interval of
[`stats::poisson.test()`](https://rdrr.io/r/stats/poisson.test.html). It
treats the exposure as known without error.

With a data frame, counts and exposures are summed within each
combination of the `by` columns (missing values are ignored in the
sums), and the groups come out in sorted order. Groups with no rows are
not created. Without `by` the whole table is one group. With a vector,
each element is its own row.

`per` takes a number, or one of `"1k"`, `"10k"`, `"100k"`, `"1m"` (case,
spaces, commas and a leading "per" are ignored), because a denominator
mistyped by a factor of ten is invisible once it reaches a table.

A rate and a share are different quantities: use
[`shrs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md)
when the denominator is the total of the same events, not a population.

Errors: count or population columns that are not numeric or not found;
negative or fractional counts; a population of zero or below; `conflvl`
outside (0, 1); an unknown `per` shorthand or a non-positive `per`.

## See also

[`shrs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md)
for a percentage of a total,
[`ratechg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md)
for the change in a rate between periods,
[`stdinc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdinc.md)
for a rate compared against an expected count rather than a population.

## Examples

``` r
stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3),
  residents = c(120000, 41000, 9500))

# per 1,000 residents, the default
rtcalc(stops, stops, residents, by = "division")
#> ── Rate per 1,000, 95% exact Poisson interval ──────────────────── 
#>  division count population      rate      lower     upper flag
#>      East     3       9500 0.3157895 0.06512338 0.9228708 <NA>
#>     North   412     120000 3.4333333 3.10977110 3.7814142 <NA>
#>     South    77      41000 1.8780488 1.48212673 2.3472387 <NA>
#> ────────────────────────────────────────────────────────────────── 

# the denominator published guidance usually asks for
rtcalc(stops, stops, residents, by = "division", per = "100k")
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  division count population      rate      lower     upper flag
#>      East     3       9500  31.57895   6.512338  92.28708 <NA>
#>     North   412     120000 343.33333 310.977110 378.14142 <NA>
#>     South    77      41000 187.80488 148.212673 234.72387 <NA>
#> ────────────────────────────────────────────────────────────────── 

# East's three events: the interval is wider than the estimate, and
# flagging it is the point of mincnt
rtcalc(stops, stops, residents, by = "division", per = "100k",
     mincnt = 5)
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  division count population      rate      lower     upper                flag
#>      East     3       9500  31.57895   6.512338  92.28708 count at or below 5
#>     North   412     120000 343.33333 310.977110 378.14142                <NA>
#>     South    77      41000 187.80488 148.212673 234.72387                <NA>
#> ────────────────────────────────────────────────────────────────── 

# vectors work too, for a single figure; a zero count has a lower limit of 0
rtcalc(c(3, 0), 9500, per = "100k")
#> ── Rate per 100,000, 95% exact Poisson interval ────────────────── 
#>  count population     rate    lower    upper flag
#>      3       9500 31.57895 6.512338 92.28708 <NA>
#>      0       9500  0.00000 0.000000 38.83031 <NA>
#> ────────────────────────────────────────────────────────────────── 

# a fractional count has no Poisson interval
try(rtcalc(2.5, 1000))
#> Error : `count` must be whole numbers: a Poisson interval on a fractional count is not defined. Use a ratio instead.
```
