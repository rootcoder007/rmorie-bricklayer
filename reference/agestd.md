# Directly age-standardised rates, with Fay-Feuer gamma intervals

The rate a population would have with the age structure of a standard
population, for one or more groups, with Fay and Feuer's gamma
confidence interval.

## Usage

``` r
agestd(events, pop, std, grp = NULL, per = 1e+05, conflvl = 0.95)
```

## Arguments

- events, pop:

  Numbers of events and of people, one per age group (and group).

- std:

  The standard population, one count per age group (its shares are the
  weights).

- grp:

  Optional labels: one rate per group, each over the same age groups in
  the same order.

- per:

  Rate per this many people (default 100,000).

- conflvl:

  Confidence level (default 0.95).

## Value

A data frame with `group`, `events`, `rate`, `lower`, `upper`, and the
attributes `var` (the variances, on the per-person scale) for
[`rategap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rategap.md).

## Details

With \\d_i\\ events and \\n_i\\ people in age group \\i\\ and standard
weights \\w_i\\ (the standard population's shares), the rate is \\y =
\sum w_i d_i / n_i\\, its variance \\v = \sum (w_i / n_i)^2 d_i\\, and
with \\w_M = \max_i w_i / n_i\\ the limits are \\\frac{v}{2y}
\chi^2\_{2y^2/v}(\alpha/2)\\ and \\\frac{v + w_M^2}{2(y + w_M)}
\chi^2\_{2(y + w_M)^2/(v + w_M^2)}(1 - \alpha/2)\\ (Fay and Feuer 1997).
The interval is conservative (coverage at least nominal in Fay and
Feuer's simulations) and reduces to the exact Garwood interval for a
single age group: suited to the few events of small communities. With no
events the lower limit is 0. Rates are per `per` people. Age groups are
matched to `std` by position: order the rows of each group by age, in
the order of `std`.

The choice of standard matters: Statistics Canada's comparisons of First
Nations, Metis and Inuit mortality standardise to the Indigenous
population's own age structure (Kumar and Tjepkema 2019), which is
younger than Canada's.

## References

Fay MP, Feuer EJ (1997). Confidence intervals for directly standardized
rates: a method based on the gamma distribution. Statistics in Medicine
16(7):791-801.  
[doi:10.1002/(sici)1097-0258(19970415)16:7\<791::aid-sim500\>3.0.co;2-#](https://doi.org/10.1002/%28sici%291097-0258%2819970415%2916%3A7%3C791%3A%3Aaid-sim500%3E3.0.co%3B2-%23)

Kumar MB, Tjepkema M (2019). Suicide among First Nations people, Metis
and Inuit (2011-2016): Findings from the 2011 Canadian Census Health and
Environment Cohort (CanCHEC). Statistics Canada 99-011-X2019001.

## See also

[`rategap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rategap.md).

## Examples

``` r
# made-up counts for one small community, by five age groups, to show the computation
std <- c(30000, 25000, 20000, 15000, 10000)   # a younger standard population
agestd(events = c(4, 9, 11, 6, 3), pop = c(9000, 8000, 6000, 4000,
                                                           2000),
                std = std)
#>   group events    rate    lower    upper
#> 1   all     33 115.625 79.23967 165.0186
```
