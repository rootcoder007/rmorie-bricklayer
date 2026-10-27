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
sac-isc.gc.ca/eng/1345816651029/1557323327644

## See also

[`cwbscr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cwbscr.md).

## Examples

``` r
p <- cnsprof(indiex("censuspop"))
h <- cnsprof(indiex("censushh"))
cnscwb(p, h)[, c("geo", "group", "income", "education", "housing", "labour",
                     "cwb")]
#> ╭── Community Well-Being index, from the census ──────────────────────────────╮
#> │   Rows         56                                                           │
#> │   Geographies  14, from Canada to Nunavut                                   │
#> │   Groups       First Nations; Métis; Inuit; Non-Indigenous                  │
#> │   Not scored   3                                                            │
#> │   Scale        0 to 100 for each component and the score                    │
#> │                                                                             │
#> │   geo                        group           income  education  housing     │
#> │   -------------------------  --------------  ------  ---------  -------     │
#> │   Canada                     First Nations    71.03      51.62    91.88     │
#> │   Canada                     Métis            78.73      59.56    91.88     │
#> │   Canada                     Inuit            72.13      38.51    91.88     │
#> │   Canada                     Non-Indigenous   84.38      68.01    95.99     │
#> │   Newfoundland and Labrador  First Nations    76.70      58.92    95.35     │
#> │   Newfoundland and Labrador  Métis            80.48      57.62    95.35     │
#> │   Newfoundland and Labrador  Inuit            77.97      53.86    95.35     │
#> │   Newfoundland and Labrador  Non-Indigenous   82.00      60.51    97.26     │
#> │   Prince Edward Island       First Nations    70.83      58.61    92.84     │
#> │   Prince Edward Island       Métis            77.88      67.58    92.84     │
#> │   Prince Edward Island       Inuit                                          │
#> │   Prince Edward Island       Non-Indigenous   79.57      65.87    96.03     │
#> │   Nova Scotia                First Nations    69.63      60.08    92.75     │
#> │   Nova Scotia                Métis            78.43      59.96    92.75     │
#> │   Nova Scotia                Inuit            72.25      62.24    92.75     │
#> │   Nova Scotia                Non-Indigenous   81.07      66.07    95.58     │
#> │   New Brunswick              First Nations    70.47      55.35    91.56     │
#> │   New Brunswick              Métis            76.57      56.66    91.56     │
#> │   New Brunswick              Inuit            69.28      59.11    91.56     │
#> │   New Brunswick              Non-Indigenous   79.92      62.51    96.00     │
#> │   Quebec                     First Nations    75.80      52.36    92.99     │
#> │   Quebec                     Métis            77.97      57.36    92.99     │
#> │   Quebec                     Inuit            70.14      30.68    92.99     │
#> │   Quebec                     Non-Indigenous   82.45      64.95    96.30     │
#> │   Ontario                    First Nations    75.50      55.06    92.91     │
#> │   Ontario                    Métis            80.75      61.84    92.91     │
#> │   Ontario                    Inuit            73.25      56.25    92.91     │
#> │   Ontario                    Non-Indigenous   85.18      69.53    95.77     │
#> │   Manitoba                   First Nations    60.40      43.53    89.27     │
#> │   Manitoba                   Métis            76.12      58.21    89.27     │
#> │   Manitoba                   Inuit            74.02      55.02    89.27     │
#> │   Manitoba                   Non-Indigenous   82.26      67.24    95.55     │
#> │   Saskatchewan               First Nations    61.61      47.39    89.11     │
#> │   Saskatchewan               Métis            76.22      58.78    89.11     │
#> │   Saskatchewan               Inuit            73.38      58.70    89.11     │
#> │   Saskatchewan               Non-Indigenous   83.92      66.68    95.89     │
#> │   Alberta                    First Nations    70.34      49.38    92.84     │
#> │   Alberta                    Métis            79.66      58.47    92.84     │
#> │   Alberta                    Inuit            76.49      59.03    92.84     │
#> │   Alberta                    Non-Indigenous   86.55      69.00    96.20     │
#> │   British Columbia           First Nations    71.85      52.81    92.69     │
#> │   British Columbia           Métis            78.50      61.18    92.69     │
#> │   British Columbia           Inuit            70.77      57.78    92.69     │
#> │   British Columbia           Non-Indigenous   85.34      70.53    95.91     │
#> │   Yukon                      First Nations    80.04      50.44    88.77     │
#> │   Yukon                      Métis            88.07      63.73    88.77     │
#> │   Yukon                      Inuit            74.30      49.46    88.77     │
#> │   Yukon                      Non-Indigenous   90.61      73.08    94.12     │
#> │   Northwest Territories      First Nations    79.64      39.50    83.50     │
#> │   Northwest Territories      Métis            91.25      55.79    83.50     │
#> │   Northwest Territories      Inuit            77.46      37.80    83.50     │
#> │   Northwest Territories      Non-Indigenous   97.48      75.50    92.89     │
#> │   Nunavut                    First Nations                                  │
#> │   Nunavut                    Métis                                          │
#> │   Nunavut                    Inuit            70.22      28.49    70.82     │
#> │   Nunavut                    Non-Indigenous  100.00      79.89    93.30     │
#> │                                                                             │
#> │   geo                        labour    cwb                                  │
#> │   -------------------------  ------  -----                                  │
#> │   Canada                      75.85  72.59                                  │
#> │   Canada                      83.15  78.33                                  │
#> │   Canada                      74.75  69.32                                  │
#> │   Canada                      86.30  83.67                                  │
#> │   Newfoundland and Labrador   78.75  77.43                                  │
#> │   Newfoundland and Labrador   79.65  78.27                                  │
#> │   Newfoundland and Labrador   79.05  76.56                                  │
#> │   Newfoundland and Labrador   80.75  80.13                                  │
#> │   Prince Edward Island        80.60  75.72                                  │
#> │   Prince Edward Island        87.10  81.35                                  │
#> │   Prince Edward Island                                                      │
#> │   Prince Edward Island        87.50  82.24                                  │
#> │   Nova Scotia                 76.25  74.68                                  │
#> │   Nova Scotia                 81.80  78.24                                  │
#> │   Nova Scotia                 78.40  76.41                                  │
#> │   Nova Scotia                 83.70  81.61                                  │
#> │   New Brunswick               76.90  73.57                                  │
#> │   New Brunswick               79.50  76.07                                  │
#> │   New Brunswick               72.95  73.23                                  │
#> │   New Brunswick               85.25  80.92                                  │
#> │   Quebec                      82.90  76.01                                  │
#> │   Quebec                      84.00  78.08                                  │
#> │   Quebec                      78.35  68.04                                  │
#> │   Quebec                      88.00  82.93                                  │
#> │   Ontario                     77.30  75.20                                  │
#> │   Ontario                     81.80  79.33                                  │
#> │   Ontario                     77.10  74.88                                  │
#> │   Ontario                     84.95  83.86                                  │
#> │   Manitoba                    69.25  65.61                                  │
#> │   Manitoba                    84.15  76.94                                  │
#> │   Manitoba                    74.45  73.19                                  │
#> │   Manitoba                    88.30  83.34                                  │
#> │   Saskatchewan                67.45  66.39                                  │
#> │   Saskatchewan                83.35  76.87                                  │
#> │   Saskatchewan                78.15  74.83                                  │
#> │   Saskatchewan                88.95  83.86                                  │
#> │   Alberta                     73.30  71.46                                  │
#> │   Alberta                     82.90  78.47                                  │
#> │   Alberta                     79.90  77.06                                  │
#> │   Alberta                     86.60  84.59                                  │
#> │   British Columbia            78.35  73.92                                  │
#> │   British Columbia            84.85  79.31                                  │
#> │   British Columbia            79.55  75.20                                  │
#> │   British Columbia            86.90  84.67                                  │
#> │   Yukon                       79.15  74.60                                  │
#> │   Yukon                       86.10  81.67                                  │
#> │   Yukon                       74.65  71.80                                  │
#> │   Yukon                       91.15  87.24                                  │
#> │   Northwest Territories       76.50  69.79                                  │
#> │   Northwest Territories       87.00  79.39                                  │
#> │   Northwest Territories       75.70  68.62                                  │
#> │   Northwest Territories       92.90  89.69                                  │
#> │   Nunavut                                                                   │
#> │   Nunavut                                                                   │
#> │   Nunavut                     69.85  59.85                                  │
#> │   Nunavut                     94.85  92.01                                  │
#> │                                                                             │
#> │   Highest score: Nunavut, Non-Indigenous (92.01); lowest: Nunavut, Inuit    │
#> │   (59.85).                                                                  │
#> │   Within a geography the groups' scores are furthest apart in Nunavut       │
#> │   (32.2 points) and closest in Newfoundland and Labrador (3.57).            │
#> │                                                                             │
#> │   cwb is the mean of income, education, housing and labour force            │
#> │   activity (Indigenous Services Canada's Community Well-Being index).       │
#> │   CWB-style, close to but not the Department's index: the public            │
#> │   profile's inputs differ (ages 25 and over; housing from households,       │
#> │   pooled for First Nations, Métis and Inuit people).                        │
#> │   Never a measure of wellness as First Nations, Métis or Inuit              │
#> │   people define it. A group below minpop people gets no score.              │
#> │   Housing needs the household table (dwell).                                │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
```
