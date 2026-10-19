# Variance and standard deviation with the right correction, and why

The variance, standard deviation and standard error of the mean of a
variable, with the denominator its source calls for: Bessel's \\n - 1\\
when the values are a sample from a larger population, \\n\\ when they
are the whole population and it is being described, and the
finite-population correction when they are a sample drawn without
replacement from a known, finite population. `design = "auto"` chooses
from `N`, and the result says which rule it applied and why.

## Usage

``` r
sprd(
  x,
  des = c("auto", "sample", "census", "finite"),
  N = NULL,
  w = NULL,
  wtype = c("frequency", "reliability"),
  narm = FALSE
)
```

## Arguments

- x:

  A numeric vector.

- des:

  `"auto"` (default), `"sample"`, `"census"` or `"finite"`.

- N:

  The population size \\N\\, for `"finite"` and `"auto"`.

- w:

  Optional non-negative weights, one per value.

- wtype:

  `"frequency"` (default) or `"reliability"`.

- narm:

  Drop missing values (default `FALSE`: they are an error).

## Value

A list of class `rmbl_spread`: `n`, `mean`, `variance`, `sd`, `semean`,
`design` (the rule applied), `denominator`, and `reason` (a sentence).
The print method shows them.

## Details

With \\n\\ values \\x_i\\ and mean \\\bar x\\:

- `"sample"`:

  values drawn independently from a large population (or from a
  process). \\s^2 = \sum (x_i - \bar x)^2 / (n - 1)\\ is unbiased for
  the population variance: the \\n - 1\\ (the Bessel correction) makes
  up for measuring spread around the mean of the sample itself, which is
  closer to the values than the population mean is. The standard error
  of the mean is \\s / \sqrt n\\.

- `"census"`:

  every unit of the population is observed (a full count, complete
  administrative records) and the aim is to describe that population:
  \\\sigma^2 = \sum (x_i - \bar x)^2 / n\\, with no correction, because
  \\\bar x\\ is the population mean itself; the mean has no sampling
  error. If the population is instead treated as one realisation of a
  process (the offences of one year as a draw of what the conditions of
  the city produce), use `"sample"`.

- `"finite"`:

  \\n\\ units drawn without replacement from \\N\\: \\s^2\\ (with \\n -
  1\\) is unbiased for the population variance defined with \\N - 1\\,
  and the standard error of the mean is \\\sqrt{(1 - n/N) s^2 / n}\\;
  the factor \\1 - n/N\\ is the finite-population correction, negligible
  below a sampling fraction of about 5 percent.

`"auto"` picks `"sample"` without `N`, `"census"` when \\n = N\\, and
`"finite"` when \\n \< N\\.

With weights: frequency weights (each value stands for \\w_i\\ identical
observations) use \\\sum w - 1\\; reliability or sampling weights (each
value counts \\w_i\\ times as much) use \\\sum w - \sum w^2 / \sum w\\,
which is \\n - 1\\ when the weights are equal, and the standard error of
the weighted mean is the sandwich \\\sqrt{\sum w_i^2 (x_i - \bar x_w)^2}
/ \sum w_i\\. Survey weights from a complex design need the design
itself for a standard error
([`svydes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svydes.md)).

## References

Cochran WG (1977). Sampling Techniques, 3rd edition. Wiley, New York,
sections 2.4 to 2.6.

## See also

[`svydes`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svydes.md)
for weighted surveys with strata and clusters.

## Examples

``` r
x <- c(12, 15, 9, 20, 14)
sprd(x)                                   # a sample: n - 1
#> n 5, mean 14, variance 16.5, sd 4.06202, standard error of the mean 1.81659
#> Rule: sample (denominator n - 1 (Bessel)): the values are a sample from a larger population, so the spread is measured around the mean of the sample itself and n - 1 corrects the bias that causes.
sprd(x, des = "census")                # the whole population: n
#> n 5, mean 14, variance 13.2, sd 3.63318, standard error of the mean 0
#> Rule: census (denominator n): the values are the whole population and it is described as it is: the mean is the population mean, so no correction, and the mean has no sampling error.
sprd(x, N = 40)             # 5 of 40 drawn: finite-population correction
#> n 5, mean 14, variance 16.5, sd 4.06202, standard error of the mean 1.69926
#> Rule: finite (denominator n - 1 (Bessel)): 5 of 40 units were drawn without replacement: n - 1 for the variance, and the finite-population correction 1 - n/N = 0.875 for the standard error.
sprd(x, N = 5)              # n = N: a census
#> n 5, mean 14, variance 13.2, sd 3.63318, standard error of the mean 0
#> Rule: census (denominator n): the values are the whole population and it is described as it is: the mean is the population mean, so no correction, and the mean has no sampling error.
sprd(c(1, 2, 3), w = c(10, 5, 1))   # frequency weights
#> n 3, mean 1.4375, variance 0.395833, sd 0.629153, standard error of the mean 0.157288
#> Rule: sample (denominator sum of weights - 1): the values are a sample from a larger population, so the spread is measured around the mean of the sample itself and n - 1 corrects the bias that causes.
```
