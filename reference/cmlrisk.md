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

  Confidence level (default 0.95).

## Value

A data frame: `age`, `hazard`, `atrisk`, `cmlrisk`, `lower`, `upper`.

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
#>    age      hazard atrisk cumrisk      lower       upper
#> 1   16 0.009000000 100000   0.009 0.00841449 0.009585164
#> 2   17 0.014127144  99100   0.023 0.02207046 0.023928652
#> 3   18 0.017400205  97700   0.040 0.03878469 0.041213777
#> 4   19 0.016666667  96000   0.056 0.05457388 0.057423968
#> 5   20 0.014830508  94400   0.070 0.06841727 0.071580045
#> 6   21 0.011827957  93000   0.081 0.07930742 0.082689464
#> 7   22 0.009793254  91900   0.090 0.08822453 0.091772013
#> 8   23 0.007692308  91000   0.097 0.09516380 0.098832470
#> 9   24 0.006644518  90300   0.103 0.10111410 0.104881945
#> 10  25 0.005574136  89700   0.108 0.10607420 0.109921649
```
