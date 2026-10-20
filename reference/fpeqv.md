# Everyday equivalents of a quantity of CO2-equivalent

Converts grams of CO2-equivalent into two everyday comparisons:
kilometres driven in an average European passenger car (175 gCO2/km) and
tree-months of carbon sequestration (917 gCO2 per tree per month), the
two comparisons the Green Algorithms calculator prints, with their
sources. Use it to make the `co2eg` of
[`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
easier to read in a report.

## Usage

``` r
fpeqv(co2eg)
```

## Arguments

- co2eg:

  Numeric scalar, grams of CO2-equivalent; finite and non-negative (for
  example the `co2eg` element of a
  [`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
  result).

## Value

A list with `carkm` (numeric, kilometres), `treemon` (numeric) and
`sources` (named character vector, `car` and `tree`, naming each
factor's source).

## Details

The conversions are plain divisions: \\\mathrm{km} = g / 175\\ and
\\\mathrm{tree\\ months} = g / 917\\. Both factors are averages and the
comparisons are illustrations, not offsets: a tree-month is the carbon
one mature tree takes up in a month, not a promise that planting one
cancels the emission. Errors when `co2eg` is not a single finite,
non-negative number.

## References

Green Algorithms data v3.1, context.csv: car factor from Helmers et al.
(2019) Atmospheric Environment and UK BEIS 2019 conversion factors; tree
sequestration from Bernal et al. (2018) via the same file.

## See also

[`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)

## Examples

``` r
fpeqv(1200)
#> $carkm
#> [1] 6.857143
#> 
#> $treemon
#> [1] 1.308615
#> 
#> $sources
#>                                                                  car 
#> "175 gCO2/km, European passenger car (Green Algorithms context.csv)" 
#>                                                                 tree 
#>             "917 gCO2 per tree-month (Green Algorithms context.csv)" 
#> 

# the footprint of a small computation, in everyday terms
fp <- co2fp(sum(sqrt(seq_len(2e5))), loc = "CA-ON",
                        cpupwrw = 45, memgb = 8)
unlist(fpeqv(fp$co2eg)[c("carkm", "treemon")])
#>        carkm      treemon 
#> 4.539836e-09 8.663810e-10 

# a vector is refused: convert one total at a time
try(fpeqv(c(10, 20)))
#> Error : `co2eg` must be a single non-negative number
```
