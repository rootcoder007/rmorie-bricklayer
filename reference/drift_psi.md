# Population stability index and Jensen-Shannon divergence (C backend)

Two summaries of how far a new binned distribution has moved from a
reference one.

## Usage

``` r
drift_psi(x, y, bins = 10L, eps = 1e-06)
```

## Arguments

- x, y:

  Numeric vectors, the reference and the new sample. Binned on the
  quantiles of `x`, so the reference defines the bins.

- bins:

  Number of bins (default 10).

- eps:

  Floor applied to empty bins in the PSI (default 1e-6).

## Value

A named length-2 numeric: `psi` and `js_divergence`.

## Details

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

## References

Wu D, Olson DL (2010). Enterprise risk management: coping with model
risk in a large bank. *Journal of the Operational Research Society*
61(2), 179–190.
[doi:10.1057/jors.2008.144](https://doi.org/10.1057/jors.2008.144)

Lin J (1991). Divergence measures based on the Shannon entropy. *IEEE
Transactions on Information Theory* 37(1), 145–151.
[doi:10.1109/18.61115](https://doi.org/10.1109/18.61115)

## Examples

``` r
set.seed(2)
ref <- stats::rnorm(500)

# Same distribution: both indices near zero.
drift_psi(ref, stats::rnorm(500))
#>           psi js_divergence 
#>   0.022072326   0.002752915 

# A shift both indices register.
drift_psi(ref, stats::rnorm(500, mean = 1))
#>           psi js_divergence 
#>     0.9543324     0.1053174 

# A sample compared with itself has moved nowhere at all.
drift_psi(ref, ref)
#>           psi js_divergence 
#>             0             0 

# The Jensen-Shannon divergence is bounded by log(2), whatever the
# shift, which is what makes it comparable across columns.
drift_psi(c(1, 1, 1), c(9, 9, 9))[["js_divergence"]] <= log(2)
#> [1] TRUE
```
