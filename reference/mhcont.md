# The four directions of the First Nations Mental Wellness Continuum, from published indicators

Lays out a group's published indicators under the four outcomes of the
First Nations Mental Wellness Continuum Framework (hope, belonging,
meaning, purpose), each with its interval, and says which directions the
tables have no measure of.

## Usage

``` r
mhcont(
  data,
  grp,
  ind,
  est,
  lower,
  upper,
  hope = NULL,
  belong = NULL,
  meaning = NULL,
  purp = NULL,
  qual = NULL,
  conflvl = 0.95
)
```

## Arguments

- data:

  A data frame, one row per group and indicator.

- grp, ind, est, lower, upper:

  Column names: the group, the indicator, the estimate (percent) and its
  published limits.

- hope, belong, meaning, purp:

  The indicators taken as proxies for each direction, or `NULL` where
  the tables have none.

- qual:

  Optional column of quality flags.

- conflvl:

  Confidence level of the published intervals (default 0.95).

## Value

A data frame with the classes `rmbl_wellness_continuum` and
`rmbl_wellness_profile`. Its columns are `group`, `indicator` (the
direction), `side` (`"wellness"`), `domain` (the proxies), `estimate`,
`lower`, `upper`, `usewithcau`, `shared`, `proxy` (always `TRUE`).

## Details

The Framework (Health Canada and Assembly of First Nations 2015)
describes mental wellness as hope for the future, a sense of belonging
and connectedness to family, community and culture, a sense of meaning
and of how one's life fits into creation, and purpose in daily life. It
has no numeric scoring, and no survey table measures the four directions
as the Framework defines them. This function takes the indicators a user
names as proxies for each
(`hope = "Always or often has a hopeful outlook"`, ...), reports each
direction's level (the mean of its proxies, their standard errors
combined as independent; the proxies share respondents, so if they are
positively correlated that standard error is too small), marks every row
as a proxy, and reports a direction given no proxy as missing rather
than filling it from another. One indicator named for two directions
(Statistics Canada asks about "meaning and purpose" together) is used
for both and marked `shared`.

The result plots as a
[`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md).
For the balance across the directions, call
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md)
on the rows with a proxy (`x[x$domain != "no published proxy", ]`, with
`"domain"` as its domain column): a missing direction otherwise leaves
the balance `NA`, and a shared proxy counts once per direction it
serves, so give such directions half weight. Other frameworks of
wellness (Te Whare Tapa Wha, the Social and Emotional Wellbeing domains,
a Nation's own) take the same route through
[`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md)
and
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md),
which accept any set of domains.

## References

Health Canada, Assembly of First Nations (2015). First Nations Mental
Wellness Continuum Framework. Ottawa: Health Canada. Summary report:  
<https://www.sac-isc.gc.ca/eng/1576093687903/1576093725971>

## See also

[`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md),
[`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md).

## Examples

``` r
# well-being, 2024 (table 41-10-0082-01): hope, and meaning and purpose (asked
# together);
# this table has no measure of belonging, so that direction is reported as missing
wb <- indiex("wellbeing")
mw <- mhcont(wb, "group", "indicator", "estimate", "lower", "upper",
        hope = "Always or often has a hopeful outlook",
        meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
        purp = "Sense of meaning and purpose rating of 8, 9 or 10",
        qual = "quality")
mw
#>            group indicator     side
#> 1  First Nations      hope wellness
#> 2  First Nations belonging wellness
#> 3  First Nations   meaning wellness
#> 4  First Nations   purpose wellness
#> 5          Métis      hope wellness
#> 6          Métis belonging wellness
#> 7          Métis   meaning wellness
#> 8          Métis   purpose wellness
#> 9          Inuit      hope wellness
#> 10         Inuit belonging wellness
#> 11         Inuit   meaning wellness
#> 12         Inuit   purpose wellness
#>                                               domain estimate lower upper
#> 1              Always or often has a hopeful outlook     50.2 45.90 54.50
#> 2                                 no published proxy       NA    NA    NA
#> 3  Sense of meaning and purpose rating of 8, 9 or 10     47.5 43.40 51.60
#> 4  Sense of meaning and purpose rating of 8, 9 or 10     47.5 43.40 51.60
#> 5              Always or often has a hopeful outlook     52.3 47.60 57.00
#> 6                                 no published proxy       NA    NA    NA
#> 7  Sense of meaning and purpose rating of 8, 9 or 10     51.6 47.00 56.20
#> 8  Sense of meaning and purpose rating of 8, 9 or 10     51.6 47.00 56.20
#> 9              Always or often has a hopeful outlook     54.4 45.85 62.95
#> 10                                no published proxy       NA    NA    NA
#> 11 Sense of meaning and purpose rating of 8, 9 or 10     50.5 42.45 58.55
#> 12 Sense of meaning and purpose rating of 8, 9 or 10     50.5 42.45 58.55
#>    usewithcau shared proxy
#> 1       FALSE  FALSE  TRUE
#> 2       FALSE  FALSE  TRUE
#> 3       FALSE   TRUE  TRUE
#> 4       FALSE   TRUE  TRUE
#> 5       FALSE  FALSE  TRUE
#> 6       FALSE  FALSE  TRUE
#> 7       FALSE   TRUE  TRUE
#> 8       FALSE   TRUE  TRUE
#> 9       FALSE  FALSE  TRUE
#> 10      FALSE  FALSE  TRUE
#> 11      FALSE   TRUE  TRUE
#> 12      FALSE   TRUE  TRUE
plot(mw)
```
