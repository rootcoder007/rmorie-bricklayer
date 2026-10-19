# Distinct-value count in fixed memory

HyperLogLog: estimates how many distinct values a column holds using a
fixed 4-byte register per bucket – 64 KB at the default `p = 14` –
regardless of the column's length or cardinality. Exact counting needs
memory proportional to the number of distinct values, which is the thing
you cannot afford on a capsule member of unknown size. `dstnskch()`
builds or extends the registers, `dstncnt()` turns them into an
estimate, and `skchmrg()` combines two sketches.

## Usage

``` r
dstnskch(x, p = 14L, regstr = NULL)

dstncnt(regstr)

skchmrg(a, b)
```

## Arguments

- x:

  A vector; coerced to character, since distinctness is compared on the
  rendered value. `NA` is skipped.

- p:

  Log2 of the register count, a whole number from 4 to 20 (default 14,
  so 16,384 registers). Larger `p` is more precise and uses more memory.

- regstr:

  Registers from a previous call (with the same `p`), to fold another
  chunk into the same sketch; `NULL` (the default) starts a new one. For
  `dstncnt()`, the registers to estimate from.

- a, b:

  Register sets to merge.

## Value

`dstnskch()` an integer vector of \\2^p\\ registers; `dstncnt()` a
length-1 numeric estimate (0 for an empty or `NULL` sketch); `skchmrg()`
the element-wise maximum of two register sets, an integer vector.

## Details

Each value is hashed and the first `p` bits pick one of \\m = 2^p\\
registers; the register keeps the longest run of leading zeros (plus
one) seen in the remaining bits. The estimate is the bias-corrected
harmonic mean \\\alpha_m m^2 / \sum_j 2^{-M_j}\\ of Flajolet et al.
(2007).

The estimate carries a relative standard error of about
`1.04 / sqrt(2^p)`, so 0.8% at the default. It is an ESTIMATE: use
`length(unique(x))` when the column fits in memory and an exact answer
matters. Below roughly `2.5 * 2^p` distinct values the estimator
switches to linear counting, which is near-exact in that range (the
estimate of one value is about 1.00003, not 1).

Values are hashed with the package's SHA-256, so the sketch is identical
on every platform and across sessions. Values are compared as text
([`as.character()`](https://rdrr.io/r/base/character.html)), so `1`,
`1.0` and `"1"` are one value. Long vectors are processed in blocks of a
million with a progress bar on stderr unless
`options(morie.quiet = TRUE)`; the registers are the same as in one
pass. Since a register only keeps a maximum, folding chunks with
`regstr` and merging separate sketches with `skchmrg()` give the same
registers as one sketch of all the data.

Errors: `p` not a whole number from 4 to 20; `regstr` not of length
\\2^p\\; registers that are not whole numbers from 0 to 64; two sketches
of different sizes.

## References

Flajolet P, Fusy E, Gandouet O, Meunier F (2007). HyperLogLog: the
analysis of a near-optimal cardinality estimation algorithm. *Analysis
of Algorithms 2007*, 137–156.

## Examples

``` r
set.seed(1)
x <- sample(1:5000, 200000, replace = TRUE)

# Close to the true 5000 distinct values, in fixed memory.
dstncnt(dstnskch(x))
#> [1] 5039.269
length(unique(x))
#> [1] 5000

# Small cardinalities are near-exact, via linear counting.
dstncnt(dstnskch(c("a", "b", "c", "a", "b")))
#> [1] 3.000275

# Chunks fold into one sketch, so a file can be counted block by
# block, and two independent sketches can be merged.
s <- dstnskch(x[1:100000])
s <- dstnskch(x[100001:200000], regstr = s)
dstncnt(s)
#> [1] 5039.269

a <- dstnskch(x[1:100000])
b <- dstnskch(x[100001:200000])
dstncnt(skchmrg(a, b))
#> [1] 5039.269

# An empty input has no distinct values.
dstncnt(dstnskch(character(0)))
#> [1] 0

# a smaller sketch: less memory, more error
dstncnt(dstnskch(x, p = 8))
#> [1] 4772.107

# sketches of different sizes cannot be merged
try(skchmrg(dstnskch(1:10, p = 4), dstnskch(1:10, p = 5)))
#> Error : both sketches must have the same number of registers
```
