# Label a period without changing it

Attaches display labels to the periods of a change table from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
so a fiscal year keyed as 2023 can print as `"2022/23"`, or a year can
carry a note such as “(COVID)”. The arithmetic already ran on the
period's value, so a label can only affect what is printed: relabelling
cannot move a number.

## Usage

``` r
yoylbl(x, labels)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md),
  whose periods are labelled.

- labels:

  Either a function applied to the period column, or a character vector
  the same length as the number of distinct periods, or a named
  character vector mapping a period (as a string) to its label.

## Value

The object, still of class `rmbl_yoy`, with an added character column
`perlbl`. Its `yoy` attribute gets `perlbl` set to `TRUE`, as
`attr(x, "yoy")$perlbl`, so the labels are used by
[`print()`](https://rdrr.io/r/base/print.html),
[`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md),
[`yoypdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
and the delimited writers.

## Details

The labels are stored in a new `perlbl` column, and the table's `yoy`
attribute is marked so that
[`print()`](https://rdrr.io/r/base/print.html),
[`yoyhtml()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md),
[`yoypdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoyren.md)
and the delimited writers show the label in place of the period. The
period column itself is unchanged, as are all values, changes and
verdicts.

`labels` is interpreted as follows: a function is called once on the
period column and must return one label per row; a named character
vector maps periods (matched as strings) to labels, and periods it does
not name keep their own value; an unnamed character vector gives one
label per distinct period, in order of first appearance.

Errors: `x` not from
[`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md);
an unnamed vector whose length is not the number of distinct periods; a
function that does not return one label per row.

## See also

[`fylbl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fylbl.md)

## Examples

``` r
seg <- data.frame(EndFiscalYear = 2019:2023,
                  n = c(402, 377, 190, 268, 331))
y <- yoy(seg, value = n, prd = EndFiscalYear)

# 2023 means the fiscal year 2022/23, so say so.
yoylbl(y, fylbl)
#> ╭── Change in n by EndFiscalYear ─────────────────────────────────────────────╮
#> │   Rows    5                                                                 │
#> │   Change  in percent                                                        │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   EndFiscalYear  n    previous  change  change %  interval                  │
#> │   ─────────────  ───  ────────  ──────  ────────  ────────────              │
#> │   2018/19        402  —         —         —       —                         │
#> │   2019/20        377  402       -25     ▼ -6.2%   [-19%, +8%]               │
#> │   2020/21        190  377       -187    ▼ -49.6%  [-58%, -40%]              │
#> │   2021/22        268  190       78      ▲ +41.1%  [+17%, +71%]              │
#> │   2022/23        331  268       63      ▲ +23.5%  [+5%, +46%]               │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# Any function will do.
yoylbl(y, function(p) paste0("FY", substr(p, 3, 4)))
#> ╭── Change in n by EndFiscalYear ─────────────────────────────────────────────╮
#> │   Rows    5                                                                 │
#> │   Change  in percent                                                        │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   EndFiscalYear  n    previous  change  change %  interval                  │
#> │   ─────────────  ───  ────────  ──────  ────────  ────────────              │
#> │   FY19           402  —         —         —       —                         │
#> │   FY20           377  402       -25     ▼ -6.2%   [-19%, +8%]               │
#> │   FY21           190  377       -187    ▼ -49.6%  [-58%, -40%]              │
#> │   FY22           268  190       78      ▲ +41.1%  [+17%, +71%]              │
#> │   FY23           331  268       63      ▲ +23.5%  [+5%, +46%]               │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# Or an explicit mapping, for the periods that need one.
yoylbl(y, c("2020" = "2019/20 (COVID)"))
#> ╭── Change in n by EndFiscalYear ─────────────────────────────────────────────╮
#> │   Rows    5                                                                 │
#> │   Change  in percent                                                        │
#> │   Better  not set (direction neutral): the colour shows no verdict          │
#> │                                                                             │
#> │   EndFiscalYear    n    previous  change  change %  interval                │
#> │   ───────────────  ───  ────────  ──────  ────────  ────────────            │
#> │   2019             402  —         —         —       —                       │
#> │   2019/20 (COVID)  377  402       -25     ▼ -6.2%   [-19%, +8%]             │
#> │   2021             190  377       -187    ▼ -49.6%  [-58%, -40%]            │
#> │   2022             268  190       78      ▲ +41.1%  [+17%, +71%]            │
#> │   2023             331  268       63      ▲ +23.5%  [+5%, +46%]             │
#> │                                                                             │
#> │   Note: the first period has nothing to compare with, so it shows no        │
#> │   change.                                                                   │
#> │                                                                             │
#> │   lag 1 period                                                              │
#> │   units: count                                                              │
#> │   95% exact rate-ratio interval                                             │
#> ╰─────────────────────────────────────────────────────────────────────────────╯

# the numbers are untouched
identical(yoylbl(y, fylbl)$change, y$change)
#> [1] TRUE

# an unnamed vector must have one label per distinct period
try(yoylbl(y, c("a", "b")))
#> Error : `labels` has 2 entries for 5 distinct periods; name them, or pass a function
```
