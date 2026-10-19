# The Community Well-Being index of a community

Indigenous Services Canada's Community Well-Being (CWB) index: income,
education, housing and labour force activity, each scored from 0 to 100,
and their mean, from census profile figures.

## Usage

``` r
cwbscr(
  incpercap,
  highsch20p,
  uni25p,
  notcro,
  nomajrep,
  partic,
  empl,
  bounds = c(2650, 75000)
)
```

## Arguments

- incpercap:

  Income per capita, in the dollars of the series' bounds.

- highsch20p, uni25p:

  Percentages for education.

- notcro, nomajrep:

  Percentages for housing.

- partic, empl:

  Percentages for labour force activity.

- bounds:

  The income bounds (default the 2016 and 2021 series: 2650 and 75000).

## Value

A data frame, one row per community: `income`, `education`, `housing`,
`labour`, `cwb`.

## Details

The components, as the index's methodology sets them out (Penney,
O'Sullivan and Senecal 2012; O'Sullivan and McHardy 2013; Indigenous
Services Canada's reports on trends, 1981 to 2016 and 2021):

- income:

  \\100 (\log y - \log a) / (\log b - \log a)\\ for income per capita
  \\y\\ (total income over total population) between the bounds \\a\\
  and \\b\\ (2,650 and 75,000 dollars in the 2016 and 2021 series; 2,000
  and 40,000 in the earlier ones), kept between 0 and 100 here.

- education:

  two thirds of the percentage aged 20 and over with at least a high
  school certificate, plus one third of the percentage aged 25 and over
  with a university degree at the bachelor's level or above.

- housing:

  half the percentage of people in dwellings with no more than one
  person per room, plus half the percentage in dwellings that need no
  major repairs.

- labour:

  half the participation rate, plus half the employment rate of those
  participating (ages 20 to 64).

The index is the mean of the four. Indigenous Services Canada computes
it from unrounded census microdata, scores only communities of 65 people
or more and suppresses the components of communities under 250 people or
40 households: scores from published, rounded profile figures come close
to the published index but need not equal it, and a small community's
should be treated as the Department would. The full current methodology
is available from the Department on request. The index measures
socio-economic conditions as the census counts them; it says nothing of
culture, language or relationship to land, and is not a measure of
wellness as First Nations and Inuit define it. The CWB is Indigenous
Services Canada's index, with bounds in the Canadian dollars of its
series: for another country, set `bounds` in its currency and read the
result as a CWB-style score, not comparable with Canada's.

## References

Penney C, O'Sullivan E, Senecal S (2012). The Community Well-Being Index
(CWB): Examining Well-Being in Inuit Communities, 1981-2006. Aboriginal
Affairs and Northern Development Canada.

O'Sullivan E, McHardy M (2013). The Community Well-Being (CWB) Index:
Disparity in Well-Being Between First Nations and Other Canadian
Communities Over Time. In White JP, Peters J, Beavon D, Spence N (eds),
Aboriginal Well-Being: Canada's Continuing Challenge. Thompson
Educational.

Indigenous Services Canada (2019). Report on trends in First Nations
communities, 1981 to 2016 (Community Well-Being index).
<https://www.sac-isc.gc.ca/eng/1345816651029/1557323327644>

## Examples

``` r
# made-up profile figures for two communities, to show the computation
cwbscr(incpercap = c(18000, 31000), highsch20p = c(58, 81),
          uni25p = c(6, 19), notcro = c(71, 95),
          nomajrep = c(62, 90),
          partic = c(55, 68), empl = c(78, 92))
#>     income education housing labour      cwb
#> 1 57.30940  40.66667    66.5   66.5 57.74402
#> 2 73.57105  60.33333    92.5   80.0 76.60110
```
