# Westfall-Young stepdown p-values

Adjusted p-values for several hypotheses tested together, from the joint
null distribution of their statistics (permutations or bootstrap draws),
holding the family-wise error rate while using the correlation between
the tests.

## Usage

``` r
stpdnpv(obs, null)
```

## Arguments

- obs:

  The observed statistics, one per hypothesis.

- null:

  A matrix of statistics under the null: one row per draw, one column
  per hypothesis.

## Value

The adjusted p-values, in the order of `observed`.

## Details

The statistics are ordered by size, \\\|t\_{(1)}\| \ge \dots \ge
\|t\_{(K)}\|\\. For each null draw \\b\\, \\q\_{b,j} = \max\_{r \ge j}
\|t^\*\_{b,(r)}\|\\. The adjusted p-value of the \\j\\th is the share of
draws with \\q\_{b,j} \ge \|t\_{(j)}\|\\, made monotone: \\\tilde
p\_{(j)} = \max(\tilde p\_{(j-1)}, p\_{(j)})\\ (Westfall and Young 1993,
algorithm 2.8).

## References

Westfall PH, Young SS (1993). Resampling-Based Multiple Testing. Wiley,
New York.

## See also

[`perminf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perminf.md).

## Examples

``` r
set.seed(1)
null <- matrix(rnorm(3000), ncol = 3)
stpdnpv(c(2.5, 0.4, -2.1), null)
#> [1] 0.044 0.694 0.081
```
