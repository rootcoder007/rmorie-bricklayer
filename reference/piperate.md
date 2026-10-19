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

A data frame: `group`, `index` (the period's position within its group),
`numerator`, `denominator` (the window sums), `rate`.

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
#>    group index numerator denominator      rate
#> 30   all    30      1091        4882 0.2234740
#> 31   all    31      1093        4810 0.2272349
#> 32   all    32      1088        4799 0.2267139
#> 33   all    33      1109        4796 0.2312344
#> 34   all    34      1106        4826 0.2291753
#> 35   all    35      1095        4879 0.2244312
#> 36   all    36      1088        4858 0.2239605
```
