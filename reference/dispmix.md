# The mix of outcomes over time, with simultaneous intervals and trend tests

For a table of counts – periods in rows, outcomes in columns, such as
cases withdrawn, pleaded guilty, or tried – gives each outcome's share
of its period with Goodman's simultaneous confidence intervals, tests
whether the mix is the same in every period, and tests each outcome for
a linear trend in its share.

## Usage

``` r
dispmix(cnts, prd = NULL, scores = NULL, conflvl = 0.95)
```

## Arguments

- cnts:

  A matrix or data frame of non-negative counts, one row per period and
  one column per outcome. Columns that are not numeric are refused; pass
  only the outcome columns.

- prd:

  Optional period labels (default: the row names, or `1:nrow(counts)`).

- scores:

  Numeric scores for the periods in the trend tests. Default:
  `1:nrow(counts)`, i.e. equally spaced.

- conflvl:

  Confidence level. Default 0.95.

## Value

A list of class `rmbl_disposition_mix`: `shares`, a long data frame
(`period`, `outcome`, `count`, `total`, `share`, `lower`, `upper`);
`homogeneity`, the Pearson chi-square test that every period has the
same mix (with Cramer's V); `trend`, one row per outcome with the
Cochran-Armitage trend statistic, its p-value, the Holm-adjusted
p-value, and the change in share from the first to the last period.

## Details

Goodman's intervals hold for all \\k\\ shares of a period at once: with
\\A\\ the upper \\\alpha/k\\ point of the chi-square distribution on one
degree of freedom, the limits for a share \\n_i / N\\ are \$\$\frac{A +
2 n_i \pm \sqrt{A (A + 4 n_i (N - n_i) / N)}}{2 (N + A)}.\$\$

The trend test for each outcome is the Cochran-Armitage test of its
count against the period totals
([`stats::prop.trend.test()`](https://rdrr.io/r/stats/prop.trend.test.html));
the Holm adjustment covers the \\k\\ tests. Counts of court cases are
large, so these tests detect small changes; the shares and their
intervals show whether a change is large enough to matter.

Errors: `cnts` not a numeric matrix or data frame, with a non-numeric
column, fewer than one period or two outcomes, or a negative, missing or
infinite count; a period with no cases; `scores` not one finite number
per period, or all equal; `prd` of the wrong length or with repeats;
`conflvl` outside (0, 1).

## References

Goodman, L. A. (1965). On simultaneous confidence intervals for
multinomial proportions. *Technometrics*, 7(2), 247-254.

Armitage, P. (1955). Tests for linear trends in proportions and
frequencies. *Biometrics*, 11(3), 375-386.

Holm, S. (1979). A simple sequentially rejective multiple test
procedure. *Scandinavian Journal of Statistics*, 6(2), 65-70.

## See also

[`shrs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md)
for one period's shares with Wilson intervals.

## Examples

``` r
d <- read.csv(system.file("extdata", "ocj_dispositions.csv",
                          package = "rmoriebricklayer"))
mix <- dispmix(d[, -(1:2)], prd = d$year)
mix
#> ╭── Outcome shares by period ─────────────────────────────────────────────────╮
#> │   Periods                   12                                              │
#> │   Outcomes                  7                                               │
#> │   Cases                     2,651,849                                       │
#> │   Intervals                 95% Goodman simultaneous (in $shares)           │
#> │   Same mix in every period  chi-square 43792.1 on 66 df, p < 0.001,         │
#> │                             Cramer's V 0.052                                │
#> │                                                                             │
#> │   Share of each period's cases                                              │
#> │   outcome                           2012     2013     2014     2015         │
#> │   -----------------------------  -------  -------  -------  -------         │
#> │   withdrawn_stayed_before_trial  0.37958  0.39219  0.39803  0.40161         │
#> │   guilty_plea_before_trial       0.42359  0.41458  0.40938  0.41909         │
#> │   other_before_trial             0.03608  0.03489  0.03582  0.03635         │
#> │   withdrawn_at_trial             0.05538  0.05490  0.05471  0.04824         │
#> │   guilty_plea_at_trial           0.05356  0.05213  0.04988  0.04619         │
#> │   other_at_trial                 0.00118  0.00108  0.00120  0.00097         │
#> │   following_trial                0.05063  0.05022  0.05098  0.04755         │
#> │                                                                             │
#> │   outcome                           2016     2017     2018     2019         │
#> │   -----------------------------  -------  -------  -------  -------         │
#> │   withdrawn_stayed_before_trial  0.40928  0.42702  0.44114  0.43649         │
#> │   guilty_plea_before_trial       0.41992  0.41070  0.39989  0.41120         │
#> │   other_before_trial             0.03710  0.03769  0.04347  0.04176         │
#> │   withdrawn_at_trial             0.04520  0.04207  0.03858  0.03785         │
#> │   guilty_plea_at_trial           0.04263  0.03878  0.03660  0.03421         │
#> │   other_at_trial                 0.00085  0.00074  0.00061  0.00063         │
#> │   following_trial                0.04501  0.04301  0.03971  0.03787         │
#> │                                                                             │
#> │   outcome                           2021     2022     2024     2025         │
#> │   -----------------------------  -------  -------  -------  -------         │
#> │   withdrawn_stayed_before_trial  0.53260  0.54286  0.51803  0.50879         │
#> │   guilty_plea_before_trial       0.34898  0.33376  0.34176  0.34300         │
#> │   other_before_trial             0.03676  0.03798  0.03623  0.03581         │
#> │   withdrawn_at_trial             0.02858  0.02960  0.03809  0.04260         │
#> │   guilty_plea_at_trial           0.02103  0.02090  0.02766  0.03166         │
#> │   other_at_trial                 0.00055  0.00054  0.00052  0.00058         │
#> │   following_trial                0.03149  0.03435  0.03771  0.03756         │
#> │                                                                             │
#> │   Cochran-Armitage trend in each share (Holm-adjusted)                      │
#> │   outcome                        statistic  p_value    pholm    change      │
#> │   -----------------------------  ---------  -------  -------  --------      │
#> │   withdrawn_stayed_before_trial  29,543.56  < 0.001  < 0.001   0.12920      │
#> │   guilty_plea_before_trial       10,090.69  < 0.001  < 0.001  -0.08060      │
#> │   other_before_trial                 20.29  < 0.001  < 0.001  -0.00026      │
#> │   withdrawn_at_trial              3,208.77  < 0.001  < 0.001  -0.01278      │
#> │   guilty_plea_at_trial            7,080.55  < 0.001  < 0.001  -0.02190      │
#> │   other_at_trial                    187.10  < 0.001  < 0.001  -0.00061      │
#> │   following_trial                 2,172.85  < 0.001  < 0.001  -0.01306      │
#> │                                                                             │
#> │   From 2012 to 2025:                                                        │
#> │   withdrawn_stayed_before_trial rose most, +12.9 points of the share;       │
#> │   guilty_plea_before_trial fell most, -8.1 points.                          │
#> │   7 of 7 shares trend at the Holm-adjusted 0.05 level: 1 up                 │
#> │   (withdrawn_stayed_before_trial), 6 down (guilty_plea_before_trial,        │
#> │   other_before_trial, withdrawn_at_trial and 3 more).                       │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
plot(mix)


# the parts of the result
head(mix$shares)
#>   period                       outcome count  total     share     lower
#> 1   2012 withdrawn_stayed_before_trial 93775 247047 0.3795836 0.3769607
#> 2   2013 withdrawn_stayed_before_trial 90864 231681 0.3921944 0.3894691
#> 3   2014 withdrawn_stayed_before_trial 83626 210098 0.3980333 0.3951641
#> 4   2015 withdrawn_stayed_before_trial 82430 205249 0.4016098 0.3987024
#> 5   2016 withdrawn_stayed_before_trial 84787 207160 0.4092827 0.4063797
#> 6   2017 withdrawn_stayed_before_trial 91440 214137 0.4270163 0.4241433
#>       upper
#> 1 0.3822136
#> 2 0.3949265
#> 3 0.4009096
#> 4 0.4045240
#> 5 0.4121920
#> 6 0.4298943
mix$trend
#>                         outcome   statistic      p_value        pholm
#> 1 withdrawn_stayed_before_trial 29543.56265 0.000000e+00 0.000000e+00
#> 2      guilty_plea_before_trial 10090.69293 0.000000e+00 0.000000e+00
#> 3            other_before_trial    20.29329 6.643309e-06 6.643309e-06
#> 4            withdrawn_at_trial  3208.77296 0.000000e+00 0.000000e+00
#> 5          guilty_plea_at_trial  7080.54897 0.000000e+00 0.000000e+00
#> 6                other_at_trial   187.10154 1.364671e-42 2.729342e-42
#> 7               following_trial  2172.84508 0.000000e+00 0.000000e+00
#>          change
#> 1  0.1292036827
#> 2 -0.0805960172
#> 3 -0.0002635828
#> 4 -0.0127761314
#> 5 -0.0218969033
#> 6 -0.0006064793
#> 7 -0.0130645687

# years as trend scores, so the gap where no row exists is respected
dispmix(d[, -(1:2)], prd = d$year, scores = d$year)$trend[, 1:3]
#>                         outcome    statistic      p_value
#> 1 withdrawn_stayed_before_trial 30150.915355 0.000000e+00
#> 2      guilty_plea_before_trial 10825.914695 0.000000e+00
#> 3            other_before_trial     7.296441 6.909133e-03
#> 4            withdrawn_at_trial  2890.841438 0.000000e+00
#> 5          guilty_plea_at_trial  6782.412494 0.000000e+00
#> 6                other_at_trial   175.420561 4.845824e-40
#> 7               following_trial  2044.569303 0.000000e+00

# outcome columns only: a text column is refused
try(dispmix(data.frame(year = c("a", "b"), x = 1:2, y = 3:4)))
#> Error : `cnts` has a column that is not numeric (year); pass only the outcome columns
```
