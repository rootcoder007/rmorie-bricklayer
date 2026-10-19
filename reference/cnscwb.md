# A Community Well-Being score from the census profile

Indigenous Services Canada's Community Well-Being (CWB) index
([`cwbscr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md))
computed from the public 2021 Census Indigenous Population Profile, for
each geography and group.

## Usage

``` r
cnscwb(
  x,
  dwell = NULL,
  groups = c("First Nations", "Métis", "Inuit", "Non-Indigenous"),
  bounds = c(2650, 75000),
  resid = "Total - Residence on or off reserve",
  minpop = 250
)
```

## Arguments

- x:

  A
  [`cnsprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md)
  of a population table.

- dwell:

  Optional
  [`cnsprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md)
  of the matching household table.

- groups:

  The groups to score (default First Nations, Metis, Inuit and
  non-Indigenous people).

- bounds:

  Income bounds of
  [`cwbscr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md).

- resid:

  On or off reserve, in the tables that split it (default the total).

- minpop:

  The smallest population scored (default 250; the Department uses 65).

## Value

A data frame of class `rmbl_census_cwb`: `geo`, `dguid`, `group`; the
components `income`, `education`, `housing`, `labour` and the score
`cwb` (0 to 100, `NA` where not scored); and the inputs `incpercap`
(dollars), `highsch25p`, `uni25p`, `population`, `participation`,
`employment`, `nomajrep`, `notcro` (percentages).

## Details

The Department computes the CWB from census microdata; the public
profile gives close but not the same inputs, and this function says
where it departs:

- income:

  per capita: the number of total income recipients aged 15 and over
  times their average total income, over the population in private
  households (all ages), as the CWB does.

- education:

  the shares with at least a high school diploma (all but those with no
  certificate, diploma or degree) and with a bachelor's degree or
  higher, both among those aged 25 and over: the profile has no age
  group of 20 and over, which the CWB uses for the first.

- labour force:

  the participation rate and the employment rate of participants (100
  less the unemployment rate) of those aged 25 to 64: the CWB uses 20 to
  64.

- housing:

  the shares of households with one person or fewer per room and needing
  no major repairs, from the household profile (`dwell`), which splits
  Indigenous from non-Indigenous households only, so First Nations,
  Metis and Inuit people all get the pooled Indigenous households'
  housing: the CWB counts persons, not households. Without `dwell` the
  housing component and the score are `NA`.

A group of fewer than `minpop` people in a geography gets no score. The
Department scores communities of 65 people or more; the default here is
250, because the public profile's counts are rounded to multiples of 5
and its long-form counts rest on a few dozen households at that size.
Geographies are matched by DGUID, so places that share a name stay
apart. The inputs are those of the 2021 profile (98-510-X2021001 to
-016): other editions name their characteristics differently. Read the
result as a CWB-style description of socio-economic conditions, close to
but not the Department's index, and never as a measure of the wellness
of First Nations, Metis or Inuit people as they define it (see
[`cwbscr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md)).

## References

Indigenous Services Canada (2019). Report on trends in First Nations
communities, 1981 to 2016 (Community Well-Being index).
<https://www.sac-isc.gc.ca/eng/1345816651029/1557323327644>

## See also

[`cwbscr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md).

## Examples

``` r
p <- cnsprof(indiex("censuspop"))
h <- cnsprof(indiex("censushh"))
cnscwb(p, h)[, c("geo", "group", "income", "education", "housing", "labour",
                     "cwb")]
#>                          geo          group    income education  housing labour
#> 1                     Canada  First Nations  71.03051  51.62081 91.87864  75.85
#> 2                     Canada          Métis  78.72661  59.55861 91.87864  83.15
#> 3                     Canada          Inuit  72.12712  38.50607 91.87864  74.75
#> 4                     Canada Non-Indigenous  84.37515  68.01121 95.98845  86.30
#> 5  Newfoundland and Labrador  First Nations  76.69559  58.92037 95.34860  78.75
#> 6  Newfoundland and Labrador          Métis  80.47825  57.62144 95.34860  79.65
#> 7  Newfoundland and Labrador          Inuit  77.97221  53.85984 95.34860  79.05
#> 8  Newfoundland and Labrador Non-Indigenous  81.99766  60.51028 97.25758  80.75
#> 9       Prince Edward Island  First Nations  70.83288  58.61214 92.83854  80.60
#> 10      Prince Edward Island          Métis  77.88242  67.58410 92.83854  87.10
#> 11      Prince Edward Island          Inuit        NA        NA       NA     NA
#> 12      Prince Edward Island Non-Indigenous  79.56542  65.86887 96.02953  87.50
#> 13               Nova Scotia  First Nations  69.63374  60.08069 92.74710  76.25
#> 14               Nova Scotia          Métis  78.43462  59.96003 92.74710  81.80
#> 15               Nova Scotia          Inuit  72.25059  62.23958 92.74710  78.40
#> 16               Nova Scotia Non-Indigenous  81.07461  66.07309 95.58339  83.70
#> 17             New Brunswick  First Nations  70.46816  55.34642 91.55738  76.90
#> 18             New Brunswick          Métis  76.57387  56.66446 91.55738  79.50
#> 19             New Brunswick          Inuit  69.28439  59.11111 91.55738  72.95
#> 20             New Brunswick Non-Indigenous  79.92296  62.51079 95.99897  85.25
#> 21                    Quebec  First Nations  75.79821  52.35905 92.98831  82.90
#> 22                    Quebec          Métis  77.97239  57.35862 92.98831  84.00
#> 23                    Quebec          Inuit  70.13841  30.67729 92.98831  78.35
#> 24                    Quebec Non-Indigenous  82.44963  64.94822 96.30485  88.00
#> 25                   Ontario  First Nations  75.50222  55.06378 92.91404  77.30
#> 26                   Ontario          Métis  80.74708  61.84098 92.91404  81.80
#> 27                   Ontario          Inuit  73.25351  56.25000 92.91404  77.10
#> 28                   Ontario Non-Indigenous  85.17523  69.53217 95.77163  84.95
#> 29                  Manitoba  First Nations  60.39601  43.52566 89.26761  69.25
#> 30                  Manitoba          Métis  76.11823  58.20675 89.26761  84.15
#> 31                  Manitoba          Inuit  74.01584  55.02008 89.26761  74.45
#> 32                  Manitoba Non-Indigenous  82.25944  67.24349 95.54920  88.30
#> 33              Saskatchewan  First Nations  61.61161  47.38542 89.11140  67.45
#> 34              Saskatchewan          Métis  76.22189  58.78027 89.11140  83.35
#> 35              Saskatchewan          Inuit  73.38165  58.69565 89.11140  78.15
#> 36              Saskatchewan Non-Indigenous  83.92413  66.68426 95.88947  88.95
#> 37                   Alberta  First Nations  70.34422  49.37512 92.83794  73.30
#> 38                   Alberta          Métis  79.65743  58.46937 92.83794  82.90
#> 39                   Alberta          Inuit  76.48720  59.03226 92.83794  79.90
#> 40                   Alberta Non-Indigenous  86.54861  68.99823 96.20293  86.60
#> 41          British Columbia  First Nations  71.85170  52.80625 92.69112  78.35
#> 42          British Columbia          Métis  78.50137  61.18405 92.69112  84.85
#> 43          British Columbia          Inuit  70.76883  57.77778 92.69112  79.55
#> 44          British Columbia Non-Indigenous  85.34473  70.53123 95.90973  86.90
#> 45                     Yukon  First Nations  80.03941  50.44316 88.77095  79.15
#> 46                     Yukon          Métis  88.07050  63.72549 88.77095  86.10
#> 47                     Yukon          Inuit  74.30427  49.46237 88.77095  74.65
#> 48                     Yukon Non-Indigenous  90.61359  73.07803 94.11649  91.15
#> 49     Northwest Territories  First Nations  79.63866  39.50453 83.50449  76.50
#> 50     Northwest Territories          Métis  91.24905  55.79134 83.50449  87.00
#> 51     Northwest Territories          Inuit  77.46422  37.79637 83.50449  75.70
#> 52     Northwest Territories Non-Indigenous  97.48298  75.49915 92.89084  92.90
#> 53                   Nunavut  First Nations        NA        NA       NA     NA
#> 54                   Nunavut          Métis        NA        NA       NA     NA
#> 55                   Nunavut          Inuit  70.22000  28.49462 70.82270  69.85
#> 56                   Nunavut Non-Indigenous 100.00000  79.89287 93.30144  94.85
#>         cwb
#> 1  72.59499
#> 2  78.32846
#> 3  69.31546
#> 4  83.66870
#> 5  77.42864
#> 6  78.27457
#> 7  76.55766
#> 8  80.12888
#> 9  75.72089
#> 10 81.35126
#> 11       NA
#> 12 82.24095
#> 13 74.67788
#> 14 78.23544
#> 15 76.40932
#> 16 81.60777
#> 17 73.56799
#> 18 76.07393
#> 19 73.22572
#> 20 80.92068
#> 21 76.01139
#> 22 78.07983
#> 23 68.03850
#> 24 82.92567
#> 25 75.19501
#> 26 79.32553
#> 27 74.87939
#> 28 83.85726
#> 29 65.60982
#> 30 76.93565
#> 31 73.18838
#> 32 83.33803
#> 33 66.38961
#> 34 76.86589
#> 35 74.83468
#> 36 83.86197
#> 37 71.46432
#> 38 78.46618
#> 39 77.06435
#> 40 84.58744
#> 41 73.92477
#> 42 79.30663
#> 43 75.19693
#> 44 84.67142
#> 45 74.60088
#> 46 81.66673
#> 47 71.79690
#> 48 87.23953
#> 49 69.78692
#> 50 79.38622
#> 51 68.61627
#> 52 89.69324
#> 53       NA
#> 54       NA
#> 55 59.84683
#> 56 92.01108
```
