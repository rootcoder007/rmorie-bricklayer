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

  Length of the stream, one non-negative number.

- k:

  Sample size, one non-negative number. Values above the stream length
  give the whole stream; 0 gives an empty result.

- seed:

  Seed for the core's generator, a whole number from 0 to below
  \\2^{53}\\ (default 42).

- x:

  Vector to sample from.

## Value

`reservoir_indices()` a sorted numeric (double) vector of 1-based
positions, of length `min(k, n)`; `reservoir_sample()` the corresponding
elements of `x`, in their original order.

## Details

`reservoir_indices()` returns the retained positions, so the same sample
can be applied to a file read line by line. `reservoir_sample()` applies
it to a vector in memory.

The first `k` items fill the reservoir; item \\i \> k\\ then replaces a
uniformly chosen slot with probability \\k / i\\, so after \\n\\ items
every item is in the sample with probability \\k / n\\ (Vitter 1985).
The positions are returned sorted.

The stream is sampled with the core's own generator seeded by `seed`,
not R's, so the sample is reproducible and R's random stream is left
alone – a capsule whose sample changed between runs would not be
reproducible. The generator is C++ `std::mt19937_64`, whose output
sequence the C++ standard fixes, and each draw is Lemire's unbiased
multiply-and-reject on its 64-bit outputs (Lemire 2019), so the same
seed gives the same sample on every platform and C++ library. Versions
up to 0.5.12 drew with `std::uniform_int_distribution`, whose algorithm
differs between C++ libraries, so their samples for a seed differ from
these.

Errors: `n` or `k` not one non-negative whole number; `n` above
\\2^{53}\\; `k` above \\10^8\\; `seed` not a whole number from 0 to
below \\2^{53}\\ (`NA` included).

## References

Vitter JS (1985). Random sampling with a reservoir. *ACM Transactions on
Mathematical Software* 11(1), 37–57.
[doi:10.1145/3147.3165](https://doi.org/10.1145/3147.3165)

Lemire D (2019). Fast random integer generation in an interval. *ACM
Transactions on Modeling and Computer Simulation* 29(1), 3.
[doi:10.1145/3230636](https://doi.org/10.1145/3230636)

## Examples

``` r
# A reproducible sample of 5 from 1000.
reservoir_indices(1000, 5, seed = 1)
#> [1]  33  67 304 630 638
reservoir_sample(letters, 4, seed = 2)
#> [1] "m" "r" "s" "z"

# Reproducible on every platform, and independent of R's own RNG.
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

# sample rows of a data frame
df <- data.frame(id = 1:20, v = (1:20)^2)
df[reservoir_indices(nrow(df), 3, seed = 7), ]
#>   id  v
#> 3  3  9
#> 8  8 64
#> 9  9 81

# a negative size is refused
try(reservoir_indices(10, -1))
#> Error : `k` must be a single non-negative whole number
```
