# Read the 2021 Census Indigenous Population Profile

Reads a table of the Indigenous Population Profile, 2021 Census of
Population (Statistics Canada catalogue 98-510-X2021001 to
98-510-X2021016), as the data service mirrors it, into one row per
geography, gender, age group, characteristic and group: First Nations,
Metis, Inuit, the other identity groups and non-Indigenous people (or,
in the household tables, Indigenous and non-Indigenous households), each
in its own rows. The data service keeps these tables under
`census2021_ipp/`.

## Usage

``` r
cnsprof(x)
```

## Arguments

- x:

  A profile table as published (a data frame read from its CSV), or a
  data service key (`"census2021_ipp/x2021001_pop"`).

## Value

A data frame of class `rmbl_census_profile`: `geo`, `dguid`, `geolvl`,
`residence` (on or off reserve, in the tables that split it), `gender`,
`age`, `chaid`, `characteristic`, `level`, `parid`, `rootid`, `sample`,
`group`, `value`, `quality`, `tnrsf`, `tnrlf`.

## Details

The profile gives each characteristic in a hierarchy shown only by
indentation (“Total - Highest certificate, diploma or degree”, “High
(secondary) school diploma or equivalency certificate”, ...): the level,
the parent and the topic's total (`rootid`) are worked out from it, so a
share can be taken of its parent. A topic marked “25% sample data” comes
from the long-form sample (`sample = "25%"`); the others from the full
count (`"100%"`). Counts are randomly rounded to multiples of 5 (of 10
below 10) by Statistics Canada, and a cell suppressed to protect
confidentiality (`x`), too unreliable (`F`), not available (`..`) or not
applicable (`...`) has no value here; `E` values are kept and marked.
The global non-response rates of the geography (`tnrsf`, `tnrlf`, in
percent) are kept: Statistics Canada suppresses an area whose long-form
rate is 50% or more, and a high rate means a larger error than the
sample alone.

## References

Statistics Canada (2023). Indigenous Population Profile, 2021 Census of
Population. Statistics Canada Catalogue no. 98-510-X2021001. Released
June 21, 2023. Published at
www12.statcan.gc.ca/census-recensement/2021/dp-pd/ipp-ppa/index.cfm?Lang=E
(the site answers scripts with 403); the Wayback Machine holds a copy of
that address captured on 8 March 2026 (web.archive.org, snapshot
20260308015010).

Statistics Canada (2022). Guide to the Census of Population, 2021.
Catalogue no. 98-304-X.

## See also

[`profshr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profshr.md),
[`cnsstd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsstd.md),
[`cnscwb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnscwb.md),
[`indiex`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indiex.md).

## Examples

``` r
p <- cnsprof(indiex("censuspop"))
head(p[p$characteristic == "Foster children" & p$geo == "Canada", ])
#>       geo          dguid  geolvl                           residence
#> 5  Canada 2021A000011124 Country Total - Residence on or off reserve
#> 27 Canada 2021A000011124 Country                          On reserve
#> 49 Canada 2021A000011124 Country                         Off reserve
#> 71 Canada 2021A000011124 Country Total - Residence on or off reserve
#> 82 Canada 2021A000011124 Country                          On reserve
#> 93 Canada 2021A000011124 Country                         Off reserve
#>            gender                age chaid  characteristic level parid rootid
#> 5  Total - Gender Total - Age groups    38 Foster children     2    37     13
#> 27 Total - Gender Total - Age groups    38 Foster children     2    37     13
#> 49 Total - Gender Total - Age groups    38 Foster children     2    37     13
#> 71 Total - Gender      0 to 14 years    38 Foster children     2    37     13
#> 82 Total - Gender      0 to 14 years    38 Foster children     2    37     13
#> 93 Total - Gender      0 to 14 years    38 Foster children     2    37     13
#>    sample group value quality tnrsf tnrlf
#> 5     25% Total 43535      ok   3.1   4.3
#> 27    25% Total  3100      ok   3.1   4.3
#> 49    25% Total 40435      ok   3.1   4.3
#> 71    25% Total 27535      ok   3.1   4.3
#> 82    25% Total  2455      ok   3.1   4.3
#> 93    25% Total 25080      ok   3.1   4.3
```
