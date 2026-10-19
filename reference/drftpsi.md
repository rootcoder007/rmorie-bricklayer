# Population stability index and Jensen-Shannon divergence (C backend)

Two effect-size summaries of how far the distribution of a numeric
column has moved from a reference sample. Both samples are binned on the
reference's quantiles and the two sets of bin shares are compared.
Unlike a p-value they do not grow with the sample size, so they say how
large a shift is rather than whether it is detectable.
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
reports both for every numeric column.

## Usage

``` r
drftpsi(x, y, bins = 10L, eps = 1e-06)
```

## Arguments

- x, y:

  Numeric vectors, the reference and the new sample. Binned on the
  quantiles of `x`, so the reference defines the bins.

- bins:

  Whole number, default 10: the number of quantile bins of the
  reference. Fewer bins are used when the reference has tied quantiles.

- eps:

  Floor applied to empty bins in the PSI (default 1e-6), any value in
  (0, 1). An empty bin contributes \\(p - eps)\log(p/eps)\\ to the
  index, so the floor is part of the statistic: the default reports the
  raw index, and a larger floor (0.01, 0.05) smooths an empty bin toward
  that share, which dampens the PSI. Compare runs only at one `eps`.

## Value

A named length-2 numeric: `psi` (non-negative, unbounded) and `jsdiv`
(in nats, between 0 and \\\log 2 \approx 0.693\\).

## Details

Binning: values are rounded to 12 significant digits (so a formatting
difference between two releases does not move tied values across an
edge), the `bins + 1` quantiles of `x` are computed, duplicates are
removed, and the interior quantiles become right-closed cut points with
open ends at \\\pm\infty\\. When the reference has fewer than three
distinct quantiles (a constant or nearly constant column), every
distinct quantile is a cut point instead. The bin shares \\p_i\\
(reference) and \\q_i\\ (new) are the proportions of each sample in each
bin.

The population stability index is \\\sum_i (p_i - q_i)\log(p_i/q_i)\\ –
the symmetrised Kullback-Leibler divergence of the two discrete
distributions. The conventional reading, from credit-risk monitoring
where it originates, is that below 0.1 is stable, 0.1 to 0.25 warrants a
look, and above 0.25 is a material shift.

The Jensen-Shannon divergence is \\\tfrac12 KL(p\\m) + \tfrac12
KL(q\\m)\\ with \\m\\ the mixture \\(p+q)/2\\. Unlike PSI it is bounded
– by \\\log 2\\ in nats – so it is comparable across columns with
different numbers of bins, and it is finite even when a category is
absent from one side.

Empty bins are floored at `eps` for the PSI only, since \\\log(0)\\
would otherwise send it to infinity on a single missing category.

Missing values are dropped. Errors: non-numeric or infinite input, an
empty sample, `bins` not a whole number from 2 to 1,000,000, `eps` not
strictly between 0 and 1. The PSI bands quoted above are heuristics with
no calibrated null distribution; on a few hundred rows binning noise
alone can exceed 0.25 (see `psiminn` in
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)).

## References

Wu D, Olson DL (2010). Enterprise risk management: coping with model
risk in a large bank. *Journal of the Operational Research Society*
61(2), 179–190.
[doi:10.1057/jors.2008.144](https://doi.org/10.1057/jors.2008.144)

Lin J (1991). Divergence measures based on the Shannon entropy. *IEEE
Transactions on Information Theory* 37(1), 145–151.
[doi:10.1109/18.61115](https://doi.org/10.1109/18.61115)

## See also

[`drftks()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftks.md),
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md).

## Examples

``` r
set.seed(2)
ref <- stats::rnorm(500)

# Same distribution: both indices near zero.
drftpsi(ref, stats::rnorm(500))
#>         psi       jsdiv 
#> 0.022072326 0.002752915 

# A shift both indices register.
drftpsi(ref, stats::rnorm(500, mean = 1))
#>       psi     jsdiv 
#> 0.9543324 0.1053174 

# A sample compared with itself has moved nowhere at all.
drftpsi(ref, ref)
#>   psi jsdiv 
#>     0     0 

# The Jensen-Shannon divergence is bounded by log(2), whatever the
# shift, which is what makes it comparable across columns.
drftpsi(c(1, 1, 1), c(9, 9, 9))[["jsdiv"]] <= log(2)
#> [1] TRUE

# a coarser binning, and a larger floor that damps an empty bin
drftpsi(ref, stats::rnorm(500, mean = 1), bins = 4)
#>        psi      jsdiv 
#> 0.69315439 0.08234528 
drftpsi(ref, stats::rnorm(500, mean = 1), eps = 0.01)
#>       psi     jsdiv 
#> 0.9232609 0.1061611 

try(drftpsi(ref, ref, bins = 1))
#> Error : `bins` must be one whole number of at least 2
```
