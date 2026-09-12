# Distinct-value count in fixed memory

HyperLogLog: estimates how many distinct values a column holds using a
fixed 4-byte register per bucket – 64 KB at the default `p = 14` –
regardless of the column's length or cardinality. Exact counting needs
memory proportional to the number of distinct values, which is the thing
you cannot afford on a capsule member of unknown size.

## Usage

``` r
distinct_sketch(x, p = 14L, registers = NULL)

distinct_count(registers)

sketch_merge(a, b)
```

## Arguments

- x:

  A vector; coerced to character, since distinctness is compared on the
  rendered value. `NA` is skipped.

- p:

  Log2 of the register count, 4 to 20 (default 14).

- registers:

  Registers from a previous call, to fold another chunk into the same
  sketch.

- a, b:

  Register sets to merge.

## Value

`distinct_sketch()` an integer vector of registers; `distinct_count()` a
length-1 numeric estimate; `sketch_merge()` the element-wise maximum of
two register sets.

## Details

The estimate carries a relative standard error of about
`1.04 / sqrt(2^p)`, so 0.8% at the default. It is an ESTIMATE: use
`length(unique(x))` when the column fits in memory and an exact answer
matters. Below roughly `2.5 * 2^p` distinct values the estimator
switches to linear counting, which is near-exact in that range.

Values are hashed with the package's SHA-256, so the sketch is identical
on every platform and across sessions.

## References

Flajolet P, Fusy E, Gandouet O, Meunier F (2007). HyperLogLog: the
analysis of a near-optimal cardinality estimation algorithm. *Analysis
of Algorithms 2007*, 137–156.

## Examples

``` r
set.seed(1)
x <- sample(1:5000, 200000, replace = TRUE)

# Close to the true 5000 distinct values, in fixed memory.
distinct_count(distinct_sketch(x))
#> [1] 5039.269
length(unique(x))
#> [1] 5000

# Small cardinalities are near-exact, via linear counting.
distinct_count(distinct_sketch(c("a", "b", "c", "a", "b")))
#> [1] 3.000275

# Chunks fold into one sketch, so a file can be counted block by
# block, and two independent sketches can be merged.
s <- distinct_sketch(x[1:100000])
s <- distinct_sketch(x[100001:200000], registers = s)
distinct_count(s)
#> [1] 5039.269

a <- distinct_sketch(x[1:100000])
b <- distinct_sketch(x[100001:200000])
distinct_count(sketch_merge(a, b))
#> [1] 5039.269

# An empty input has no distinct values.
distinct_count(distinct_sketch(character(0)))
#> [1] 0
```
