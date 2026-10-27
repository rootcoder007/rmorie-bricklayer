# Cumulative risk of a first event by age

The chance that a person experiences an event (a first arrest, a first
conviction, a first jail stay, a first child protection placement) by
each age, from first events and the population by age, as a synthetic
cohort; with mortality as a competing risk when deaths are given.

## Usage

``` r
cmlrisk(age, fireve, pop, atrisk = NULL, dthrate = NULL, conflvl = 0.95)
```

## Arguments

- age:

  The ages, in order.

- fireve:

  First events at each age.

- pop:

  The population at each age.

- atrisk:

  Optional: the persons at risk at each age, when known, in place of the
  synthetic-cohort assumption.

- dthrate:

  Optional death rates by age (probability of dying within the age).

- conflvl:

  Confidence level of the cumulative risk limits (default 0.95).

## Value

A data frame of class `rmbl_cumrisk`: `age`, `hazard`, `atrisk`,
`cmlrisk`, `lower`, `upper`.

## Details

With \\E_a\\ first events at age \\a\\ and \\N_a\\ persons at risk
(those who have not had the event), the hazard is \\h_a = E_a/N_a\\.
When only the population \\P_a\\ is known, the persons at risk are taken
as \\P_a(1 - CR\_{a-1})\\ (the synthetic-cohort assumption). Without
mortality, \\CR_a = 1 - \prod\_{x \le a}(1 - h_x)\\. With death rates
\\q_x\\, the multiple-decrement table carries survivors \\l\_{x+1} =
l_x(1 - h_x - q_x)\\ and \\CR_a = \sum\_{x \le a} l_x h_x / l_0\\, the
risk of the event before death. The interval (without mortality) is
Greenwood's on the log of the survival: \\\mathrm{Var}(\log S_a) =
\sum\_{x \le a} h_x/(N_x(1 - h_x))\\.

Counting first events needs records that link a person's events over
time; an agency's counts of all events overstate first events. Events of
people who do not live in the area, counted against its population, bias
the risk upward.

## References

Bonczar TP (2003). Prevalence of imprisonment in the U.S. population,
1974-2001. Bureau of Justice Statistics, NCJ 197976.

Applied to arrests, convictions and jail in New York City: Hepburn P,
Kohler-Hausmann I, Zorro Medina A (2019). Cumulative risks of multiple
criminal justice outcomes in New York City. Demography 56(3):1161-1171.
[doi:10.1007/s13524-019-00781-7](https://doi.org/10.1007/s13524-019-00781-7)

## Examples

``` r
age <- 16:25
first <- c(900, 1400, 1700, 1600, 1400, 1100, 900, 700, 600, 500)
pop <- rep(100000, 10)
cmlrisk(age, first, pop)
#> ╭── Cumulative risk of a first event ─────────────────────────────────╮
#> │   Ages                  16 to 25                                    │
#> │   Risk by the last age  10.8% [10.6, 11.0]                          │
#> │                                                                     │
#> │   age   hazard   atrisk  cumrisk  interval                          │
#> │   ---  -------  -------  -------  ------------------                │
#> │    16  0.00900  100,000  0.00900  [0.00841, 0.00959]                │
#> │    17  0.01413   99,100  0.02300  [0.02207, 0.02393]                │
#> │    18  0.01740   97,700  0.04000  [0.03878, 0.04121]                │
#> │    19  0.01667   96,000  0.05600  [0.05457, 0.05742]                │
#> │    20  0.01483   94,400  0.07000  [0.06842, 0.07158]                │
#> │    21  0.01183   93,000  0.08100  [0.07931, 0.08269]                │
#> │    22  0.00979   91,900  0.09000  [0.08822, 0.09177]                │
#> │    23  0.00769   91,000  0.09700  [0.09516, 0.09883]                │
#> │    24  0.00664   90,300  0.10300  [0.10111, 0.10488]                │
#> │    25  0.00557   89,700  0.10800  [0.10607, 0.10992]                │
#> │                                                                     │
#> │   By age 25 an estimated 10.8% of the population have had a first   │
#> │   event, from the age-specific first-event hazards of a life table. │
#> ╰─────────────────────────────────────────────────────────────────────╯
```
