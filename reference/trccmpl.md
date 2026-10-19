# Calls to Action completed, year by year

The number of the Truth and Reconciliation Commission's 94 Calls to
Action that the Yellowhead Institute's annual accountability reports
judged complete, by the year they were completed, to the end of 2022:
the only counts here are those the reports state.

## Usage

``` r
trccmpl()
```

## Value

A data frame with `period`, `yearend`, `completed`, `cumulative` and
`source`.

## Details

2015-2019: 8 (13 in all by December 2022, less those of 2020-2022);
2020: none; 2021: 3, all in June; 2022: 2 (Jewell and Mosby 2021, 2022).
Other trackers count otherwise: the federal government reports by theme
rather than call by call; CBC's Beyond 94 and Indigenous Watchdog grade
each call on their own scales and are copyrighted, so their tables are
not reproduced. The reports are licensed CC BY-NC 2.5 Canada; the counts
are facts taken from them, with the reports cited.

## References

Jewell E, Mosby I (2021). Calls to Action Accountability: A 2021 Status
Update on Reconciliation. Yellowhead Institute, Toronto Metropolitan
University.

Jewell E, Mosby I (2022). Calls to Action Accountability: A 2022 Status
Update on Reconciliation. Yellowhead Institute, Toronto Metropolitan
University.

Truth and Reconciliation Commission of Canada (2015). Truth and
Reconciliation Commission of Canada: Calls to Action. Winnipeg.

## See also

[`trcprog`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md).

## Examples

``` r
trccmpl()
#>      period yearend completed cumulative
#> 1 2015-2019    2019         8          8
#> 2      2020    2020         0          8
#> 3      2021    2021         3         11
#> 4      2022    2022         2         13
#>                                        source
#> 1 Jewell and Mosby (2022): 13 complete in all
#> 2                     Jewell and Mosby (2021)
#> 3                     Jewell and Mosby (2021)
#> 4                     Jewell and Mosby (2022)
```
