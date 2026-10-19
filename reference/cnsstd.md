# An Indigenous standard population from the census

The age structure of a group in a geography of the 2021 Census
Indigenous Population Profile, as the standard of
[`agestd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md)
or
[`stdprev`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md).

## Usage

``` r
cnsstd(
  x,
  grp = "Indigenous identity",
  geo = "Canada",
  ages = c("0 to 4 years", "5 to 9 years", "10 to 14 years", "15 to 19 years",
    "20 to 24 years", "25 to 34 years", "35 to 44 years", "45 to 54 years",
    "55 to 64 years", "65 to 74 years", "75 years and over"),
  resid = "Total - Residence on or off reserve"
)
```

## Arguments

- x:

  A
  [`cnsprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnsprof.md).

- grp:

  The group (default `"Indigenous identity"`).

- geo:

  The geography: its name (default `"Canada"`) or, where names repeat,
  its DGUID.

- ages:

  The age groups, as the profile names them.

- resid:

  On or off reserve, in the tables that split it (default the total).

## Value

A data frame: `age`, `population`, `weight` (shares summing to 1).

## Details

Comparisons of First Nations, Metis and Inuit health are standardised to
the Indigenous population's own, younger, age structure (Kumar and
Tjepkema 2019): a standard as old as Canada's gives weight to ages where
few Indigenous people are. This takes the population in private
households of each age group (the profile's first characteristic) for
the group and geography given. Age groups that do not overlap are chosen
by default (0 to 4, 5 to 9, 10 to 14, 15 to 19, 20 to 24, 25 to 34, 35
to 44, 45 to 54, 55 to 64, 65 to 74, 75 and over); collapse them to the
age groups of the rates being standardised.

## References

Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis
and Inuit (2011-2016): findings from the 2011 Canadian Census Health and
Environment Cohort (CanCHEC). Statistics Canada catalogue no.
99-011-X2019001.

## See also

[`agestd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md),
[`stdprev`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md).

## Examples

``` r
p <- cnsprof(indiex("censuspop"))
cnsstd(p)
#>                  age population     weight
#> 1       0 to 4 years     137510 0.07608819
#> 2       5 to 9 years     155565 0.08607853
#> 3     10 to 14 years     166135 0.09192722
#> 4     15 to 19 years     148820 0.08234633
#> 5     20 to 24 years     136070 0.07529140
#> 6     25 to 34 years     263655 0.14588780
#> 7     35 to 44 years     217990 0.12062006
#> 8     45 to 54 years     206360 0.11418485
#> 9     55 to 64 years     202785 0.11220670
#> 10    65 to 74 years     119410 0.06607295
#> 11 75 years and over      52945 0.02929597
```
