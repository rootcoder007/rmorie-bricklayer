# The share of a population with a characteristic, from the census profile

The share of a group with a characteristic of the 2021 Census Indigenous
Population Profile (foster children among children, speakers of an
Indigenous language, households needing major repairs, ...), with an
approximate confidence interval that carries the long-form sample and
the random rounding of the counts.

## Usage

``` r
profshr(
  x,
  num,
  den = NULL,
  smpfrac = 0.25,
  deff = 1,
  conflvl = 0.95,
  roubase = 5
)
```

## Arguments

- x:

  A
  [`cnsprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md).

- num:

  The characteristic counted: its `chaid`, or its name exactly.

- den:

  The characteristic it is a share of (id or name); default its parent.

- smpfrac:

  The long-form sampling fraction (default 0.25); full-count
  characteristics use 1 whatever is given.

- deff:

  Design effect (default 1).

- conflvl:

  Confidence level (default 0.95).

- roubase:

  The base of the random rounding (default 5, Statistics Canada's); 1
  for counts that are not rounded.

## Value

A data frame of class `rmbl_profile_share`: `geo`, `dguid`, `residence`,
`gender`, `age`, `group`, `numerator`, `denominator`, `estimate`
(percent), `lower`, `upper`, `quality`; ready for
[`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md)
and
[`dstntst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md).
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it.

## Details

The share is the numerator's count over the denominator's (by default
the numerator's parent in the profile's hierarchy), for each geography,
gender, age group and group. Statistics Canada does not publish standard
errors for the profile, so the interval is an approximation built from
what is known about how the counts were made:

- a long-form ("25\\ household in four, so the share has variance \\d
  (1 - f) p (1 - p) / (f N)\\ for a sampling fraction \\f\\ (`smpfrac`,
  0.25) of a population of \\N\\ (the denominator) and a design effect
  \\d\\ (`deff`, 1 by default: the clustering of people in households
  raises it, and a value of 1.5 to 2 is prudent for characteristics
  shared within a household). On reserves (rows whose `residence` is
  `"On reserve"`) every household got the long form, so \\f = 1\\ there
  and the sampling term vanishes;

- every count is randomly rounded, up or down without bias, to a
  multiple of \\b\\ (`roubase`, 5). Averaged over the remainders, that
  adds variance \\c = (b^2 - 1)/6\\ to each count (4 for \\b = 5\\), so
  \\c (1 + p^2) / N^2\\ to the share (the only error of a full-count
  share).

In all, \$\$V = \frac{d (1 - f) p (1 - p)}{f N} + \frac{c (1 +
p^2)}{N^2}.\$\$ The interval is Wilson's at the effective sample size
\\n_e = \max(p(1-p), 1/N) / V\\ (the floor \\1/N\\ keeps a share of 0 or
100\\ from an infinite \\n_e\\), so it stays inside 0 and 100. It does
not carry non-response (see `tnrlf`) or the edit and imputation error,
so it is narrower than the full error; treat it as a lower bound on the
uncertainty.

## References

Statistics Canada (2022). Guide to the Census of Population, 2021,
chapter 9 (data quality) and chapter 10 (confidentiality and random
rounding). Catalogue no. 98-304-X.

Wilson EB (1927). Probable inference, the law of succession, and
statistical inference. Journal of the American Statistical Association
22(158):209-212.
[doi:10.1080/01621459.1927.10502953](https://doi.org/10.1080/01621459.1927.10502953)

## See also

[`cnsprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md).

## Examples

``` r
p <- cnsprof(indiex("censuspop"))
# children who are foster children, by province, First Nations, Metis, Inuit and
# non-Indigenous
fc <- profshr(p, "Foster children", "Total - Children in census families")
fc <- fc[fc$age == "0 to 14 years" &
           fc$group %in% c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous"), ]
head(fc)
#>                           geo          dguid
#> 256                    Canada 2021A000011124
#> 257                    Canada 2021A000011124
#> 258                    Canada 2021A000011124
#> 262 Newfoundland and Labrador    2021A000210
#> 263 Newfoundland and Labrador    2021A000210
#> 264 Newfoundland and Labrador    2021A000210
#>                               residence         gender           age
#> 256 Total - Residence on or off reserve Total - Gender 0 to 14 years
#> 257                          On reserve Total - Gender 0 to 14 years
#> 258                         Off reserve Total - Gender 0 to 14 years
#> 262 Total - Residence on or off reserve Total - Gender 0 to 14 years
#> 263                          On reserve Total - Gender 0 to 14 years
#> 264                         Off reserve Total - Gender 0 to 14 years
#>             group numerator denominator estimate     lower    upper quality
#> 256 First Nations     11735      265405 4.421544 4.2880409 4.559006      ok
#> 257 First Nations      2350       90270 2.603301 2.5989608 2.607649      ok
#> 258 First Nations      9385      175135 5.358723 5.1789488 5.544373      ok
#> 262 First Nations        95        5125 1.853659 1.3105276 2.615917      ok
#> 263 First Nations        35         705 4.964539 4.4367974 5.551407      ok
#> 264 First Nations        60        4425 1.355932 0.8752591 2.095001      ok
plot(fc[fc$geo == "Canada", ])
```
