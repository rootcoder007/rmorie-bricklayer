# Justice-pipeline rates with a lag between stages

The rate at which one stage of the justice process follows another
(charges per reported offence, settlements per charge, convictions per
trial), summing each over a window and setting the outcome's window
after the input's, because cases take time to move through.

## Usage

``` r
piperate(num, den, win = 12L, lag = 0L, grp = NULL)
```

## Arguments

- num, den:

  The outcome and input counts, in period order.

- win:

  The number of periods summed (default 12).

- lag:

  The number of periods the input's window precedes the outcome's
  (default 0).

- grp:

  Optional grouping (for example a court or municipality), the counts in
  period order within it.

## Value

A data frame of class `rmbl_pipeline_rate`: `group`, `index` (the
period's position within its group), `numerator`, `denominator` (the
window sums), `rate`.

## Details

For period \\t\\, a window of \\W\\ periods and a lag of \\L\\, \$\$R_t
= \frac{\sum\_{s = t - W + 1}^{t} O_s}{\sum\_{s = t - L - W + 1}^{t - L}
I_s},\$\$ with \\O\\ the outcome stage and \\I\\ the input stage. With
\\W = 1, L = 0\\ it is the same-period ratio (cases with detention over
cases charged; acquittals over acquittals and convictions). Rates are
`NA` until the windows are filled, and when the denominator is zero.
These are administrative counts of every case, so no sampling interval
is given.

## References

Council of Europe, European Commission for the Efficiency of Justice
(CEPEJ) (2014). European judicial systems: efficiency and quality of
justice. CEPEJ Studies 20.

Applied to the stages of a Colombian criminal-procedure reform: Acosta,
Mejia and Zorro Medina (2023), see
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md).

## See also

[`caseflow`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md)
for clearance rates and inventories.

## Examples

``` r
set.seed(2)
reports <- rpois(36, 400)
charges <- rpois(36, 90)
piperate(charges, reports, win = 12, lag = 3)[30:36, ]
#> ╭── Lagged pipeline rate ────────────────────────────────────────────────╮
#> │   Groups          1                                                    │
#> │   Periods         36                                                   │
#> │   Rates computed  7                                                    │
#> │                                                                        │
#> │   group  index  numerator  denominator    rate                         │
#> │   -----  -----  ---------  -----------  ------                         │
#> │   all       30      1,091        4,882  0.2235                         │
#> │   all       31      1,093        4,810  0.2272                         │
#> │   all       32      1,088        4,799  0.2267                         │
#> │   all       33      1,109        4,796  0.2312                         │
#> │   all       34      1,106        4,826  0.2292                         │
#> │   all       35      1,095        4,879  0.2244                         │
#> │   all       36      1,088        4,858  0.2240                         │
#> │                                                                        │
#> │   Each rate is the numerator summed over the window over the           │
#> │   denominator summed over the same window moved back by the lag (cases │
#> │   out over cases in earlier); it is missing until a full window is in. │
#> ╰────────────────────────────────────────────────────────────────────────╯
```
