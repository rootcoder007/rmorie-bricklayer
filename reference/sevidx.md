# A severity-weighted crime index

Offence rates combined into one index, unweighted (the sum of rates) and
weighted by each offence's severity (for example its mean statutory
sentence), per unit and period.

## Usage

``` r
sevidx(data, unit, time, offence, count, w, pop = NULL, per = 1e+05)
```

## Arguments

- data:

  A data frame, one row per unit, period and offence.

- unit, time, offence, count:

  Column names.

- w:

  Named weights, one per offence counted.

- pop:

  Optional column name of the population; without it `count` is taken as
  a rate already.

- per:

  Rate base (default 100000).

## Value

A data frame of class `rmbl_severity`: `unit`, `time`, `unweighted`,
`weighted`; attribute `weights`.

## Details

With \\r\_{k}\\ the rate of offence \\k\\ per `per` residents and
\\w_k\\ its weight, the indices are \\\sum_k r_k\\ and \\\sum_k w_k
r_k\\. Mean statutory sentence lengths are one choice of weight (as in
Acosta, Mejia and Zorro Medina 2023); sentencing guidelines are another
(the Cambridge Crime Harm Index, Sherman, Neyroud and Neyroud 2016). The
weights are the analyst's to state and defend: the index records them. A
unit-period missing an offence that has a weight gets `NA`, never a
partial sum.

## References

Sherman L, Neyroud PW, Neyroud E (2016). The Cambridge Crime Harm Index:
measuring total harm from crime based on sentencing guidelines. Policing
10(3):171-183.
[doi:10.1093/police/paw003](https://doi.org/10.1093/police/paw003)

Applied with weights from the Colombian Penal Code: Acosta, Mejia and
Zorro Medina (2023), see
[`plndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plndid.md).

## Examples

``` r
d <- data.frame(city = rep(c("A", "B"), each = 3), year = 2024,
                offence = rep(c("homicide", "robbery", "burglary"), 2),
                n = c(5, 120, 300, 2, 90, 410), pop = rep(c(250000, 180000), each
= 3))
sevidx(d, "city", "year", "offence", "n",
               w = c(homicide = 25, robbery = 8,
                           burglary = 4), pop = "pop")
#>   unit time unweighted weighted
#> 1    A 2024   170.0000  914.000
#> 2    B 2024   278.8889 1338.889
```
