# Label a period without changing it

Attaches display labels to a change table. The arithmetic already ran on
the period's value, so a label can only affect what is printed:
relabelling cannot move a number.

## Usage

``` r
yoy_label(x, labels)
```

## Arguments

- x:

  An `rmbl_yoy` object from
  [`yoy()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md).

- labels:

  Either a function applied to the period column, or a character vector
  the same length as the number of distinct periods, or a named
  character vector mapping a period (as a string) to its label.

## Value

The object, with a `period_label` column and the labels used by
[`print()`](https://rdrr.io/r/base/print.html),
[`yoy_html()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md),
[`yoy_pdf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy_render.md)
and the delimited writers.

## See also

[`fiscal_year_label()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fiscal_year_label.md)

## Examples

``` r
seg <- data.frame(EndFiscalYear = 2019:2023,
                  n = c(402, 377, 190, 268, 331))
y <- yoy(seg, value = n, period = EndFiscalYear)

# 2023 means the fiscal year 2022/23, so say so.
yoy_label(y, fiscal_year_label)
#> EndFiscalYear  n    previous  change  change %  interval    
#> ─────────────  ───  ────────  ──────  ────────  ────────────
#> 2018/19        402  —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> 2019/20        377  402       -25     ▼ -6.2%   [-19%, +8%] 
#> 2020/21        190  377       -187    ▼ -49.6%  [-58%, -40%]
#> 2021/22        268  190       78      ▲ +41.1%  [+17%, +71%]
#> 2022/23        331  268       63      ▲ +23.5%  [+5%, +46%] 
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20

# Any function will do.
yoy_label(y, function(p) paste0("FY", substr(p, 3, 4)))
#> EndFiscalYear  n    previous  change  change %  interval    
#> ─────────────  ───  ────────  ──────  ────────  ────────────
#> FY19           402  —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> FY20           377  402       -25     ▼ -6.2%   [-19%, +8%] 
#> FY21           190  377       -187    ▼ -49.6%  [-58%, -40%]
#> FY22           268  190       78      ▲ +41.1%  [+17%, +71%]
#> FY23           331  268       63      ▲ +23.5%  [+5%, +46%] 
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20

# Or an explicit mapping, for the periods that need one.
yoy_label(y, c("2020" = "2019/20 (COVID)"))
#> EndFiscalYear    n    previous  change  change %  interval    
#> ───────────────  ───  ────────  ──────  ────────  ────────────
#> 2019             402  —         —         —       —           
#>     ↳ percent withheld: no comparison period
#> 2019/20 (COVID)  377  402       -25     ▼ -6.2%   [-19%, +8%] 
#> 2021             190  377       -187    ▼ -49.6%  [-58%, -40%]
#> 2022             268  190       78      ▲ +41.1%  [+17%, +71%]
#> 2023             331  268       63      ▲ +23.5%  [+5%, +46%] 
#> 
#> lag 1 period · units: count · 95% exact rate-ratio interval · percent withheld below a base of 20
```
