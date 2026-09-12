# Uniform sample of a stream in one pass

Vitter's Algorithm R: draws `k` items from a stream, each item equally
likely to be retained, in a single pass and using memory proportional to
`k` rather than to the stream's length. Use it to take a fair sample of
a capsule member you cannot hold, or whose length you do not know in
advance.

## Usage

``` r
reservoir_indices(n, k, seed = 42L)

reservoir_sample(x, k, seed = 42L)
```

## Arguments

- n:

  Length of the stream.

- k:

  Sample size. Values above the stream length give the whole stream.

- seed:

  Seed for the core's generator (default 42).

- x:

  Vector to sample from.

## Value

`reservoir_indices()` a sorted numeric vector of 1-based positions;
`reservoir_sample()` the corresponding elements of `x`.

## Details

`reservoir_indices()` returns the retained positions, so the same sample
can be applied to a file read line by line. `reservoir_sample()` applies
it to a vector in memory.

The stream is sampled with the core's own generator seeded by `seed`,
not R's, so the sample is reproducible and R's random stream is left
alone – a capsule whose sample changed between runs would not be
reproducible.

## References

Vitter JS (1985). Random sampling with a reservoir. *ACM Transactions on
Mathematical Software* 11(1), 37–57.
[doi:10.1145/3147.3165](https://doi.org/10.1145/3147.3165)

## Examples

``` r
# A reproducible sample of 5 from 1000.
reservoir_indices(1000, 5, seed = 1)
#> [1]  33  67 304 630 638
reservoir_sample(letters, 4, seed = 2)
#> [1] "m" "r" "s" "z"

# Reproducible, and independent of R's own RNG.
identical(reservoir_indices(1000, 5, seed = 1),
          reservoir_indices(1000, 5, seed = 1))
#> [1] TRUE

# Asking for more than the stream holds returns the whole stream.
reservoir_indices(3, 10)
#> [1] 1 2 3

# Every item is equally likely: over many seeds the retained positions
# are spread uniformly rather than favouring the start or the end.
hits <- unlist(lapply(1:400, function(s) reservoir_indices(50, 5, s)))
round(mean(hits))          # near the midpoint, 25.5
#> [1] 26
```
