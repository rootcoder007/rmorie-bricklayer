# Printed reports for bricklayer objects

Human-readable renderings of the objects the package returns. Each leads
with the verdict, then the evidence.
[`format()`](https://rdrr.io/r/base/format.html) returns the lines as a
character vector so they can be logged or written to a file;
[`print()`](https://rdrr.io/r/base/print.html) sends them to the console
and returns its argument invisibly.

## Usage

``` r
# S3 method for class 'bricklayer_attestation'
print(x, ...)

# S3 method for class 'bricklayer_bundle'
print(x, ...)

# S3 method for class 'bricklayer_attestation_check'
print(x, ...)

# S3 method for class 'bricklayer_benford'
print(x, ...)

# S3 method for class 'bricklayer_bundle_check'
print(x, ...)

# S3 method for class 'bricklayer_certificate'
print(x, ...)

# S3 method for class 'bricklayer_certpath_check'
print(x, ...)

# S3 method for class 'bricklayer_chain'
print(x, ...)

# S3 method for class 'bricklayer_drbg'
print(x, ...)

# S3 method for class 'bricklayer_drift'
print(x, ...)

# S3 method for class 'bricklayer_env_diff'
print(x, ...)

# S3 method for class 'bricklayer_falsification'
print(x, ...)

# S3 method for class 'bricklayer_falsify_family'
print(x, ...)

# S3 method for class 'bricklayer_fips_key'
print(x, ...)

# S3 method for class 'bricklayer_fips_public_key'
print(x, ...)

# S3 method for class 'bricklayer_hqc_capsule'
print(x, ...)

# S3 method for class 'bricklayer_hqc_key'
print(x, ...)

# S3 method for class 'bricklayer_hqc_public_key'
print(x, ...)

# S3 method for class 'bricklayer_kem_capsule'
print(x, ...)

# S3 method for class 'bricklayer_kem_key'
print(x, ...)

# S3 method for class 'bricklayer_kem_public_key'
print(x, ...)

# S3 method for class 'bricklayer_mcar'
print(x, ...)

# S3 method for class 'bricklayer_oqs_key'
print(x, ...)

# S3 method for class 'bricklayer_oqs_public_key'
print(x, ...)

# S3 method for class 'bricklayer_power'
print(x, ...)

# S3 method for class 'bricklayer_prereg'
print(x, ...)

# S3 method for class 'bricklayer_prereg_check'
print(x, ...)

# S3 method for class 'bricklayer_public_key'
print(x, ...)

# S3 method for class 'bricklayer_recode_manifest'
print(x, ...)

# S3 method for class 'bricklayer_recompute'
print(x, ...)

# S3 method for class 'bricklayer_report'
print(x, ...)

# S3 method for class 'bricklayer_schema'
print(x, ...)

# S3 method for class 'bricklayer_signature'
print(x, ...)

# S3 method for class 'bricklayer_signing_key'
print(x, ...)

# S3 method for class 'bricklayer_timestamp'
print(x, ...)

# S3 method for class 'rmbl_bounds'
print(x, ...)

# S3 method for class 'rmbl_fetch'
print(x, ...)

# S3 method for class 'rmbl_margin_check'
print(x, ...)

# S3 method for class 'rmbl_or_check'
print(x, ...)

# S3 method for class 'rmbl_recode_manifest_check'
print(x, ...)

# S3 method for class 'rmbl_transfer_check'
print(x, ...)

# S3 method for class 'bricklayer_drift'
summary(object, ...)

# S3 method for class 'bricklayer_benford'
summary(object, ...)

# S3 method for class 'bricklayer_report'
summary(object, ...)
```

## Arguments

- x:

  The object to render.

- ...:

  Ignored, present for S3 consistency.

- object:

  The object to summarise.

## Value

[`format()`](https://rdrr.io/r/base/format.html) methods return a
character vector; [`print()`](https://rdrr.io/r/base/print.html) methods
return `x` invisibly.

## Details

Box-drawing characters are used only when the session's encoding can
render them; otherwise the same layout is drawn in plain ASCII. Set the
environment variable `RMBL_ASCII_ONLY` to force the ASCII form, which is
what to do when capturing output into a fixed-width log.

## Examples

``` r
# keep this example's
op <- options(rmoriebricklayer.xmssidxfile = tempfile())
# one-time index record out of your configuration directory; leave the
# default in use
set.seed(7)
ref <- data.frame(v = stats::rnorm(200), g = sample(c("a", "b"), 200, TRUE))
cur <- data.frame(
  v = stats::rnorm(200, mean = 1),
  g = sample(c("a", "b"), 200, TRUE)
)

# The drift report leads with its verdict.
cpsdrft(ref, cur)
#> ╭── Capsule drift report ─────────────────────────────────────────────────╮
#> │   Verdict          ✗ DRIFT DETECTED                                     │
#> │   Reference rows   200                                                  │
#> │   Current rows     200                                                  │
#> │   Columns tested   2                                                    │
#> │   Columns drifted  1                                                    │
#> │   Alpha            0.01                                                 │
#> │                                                                         │
#> │   Per-column tests                                                      │
#> │      column  type           stat        p     psi                       │
#> │   -  ------  -----------  ------  -------  ------                       │
#> │   ✖  v       numeric      0.3600  < 0.001  0.8136                       │
#> │   ✔  g       categorical  1.4413    0.230  0.0144                       │
#> │                                                                         │
#> │   1 of 2 columns changed between the reference and the current table by │
#> │   more than chance at alpha 0.01; check those columns before trusting   │
#> │   results built on the reference.                                       │
#> │                                                                         │
#> │   plot(x, what = "columns") draws the columns; drfthtml(x, file) writes │
#> │   an interactive report.                                                │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# format() gives the same lines for a log file.
head(format(cpsdrft(ref, cur)), 3)
#> [1] "── Capsule drift report ──────────────────────────────────────────"
#> [2] "  Verdict          ✗ DRIFT DETECTED"                               
#> [3] "  Reference rows   200"                                            

# A Benford screen.
benfordtst(10^stats::runif(500, 0, 5))
#> ╭── Benford first-digit screen ───────────────────────────────────────────╮
#> │   ✔ consistent with Benford's law                                       │
#> │                                                                         │
#> │   values used  500                                                      │
#> │   chi-square   5.919                                                    │
#> │   df           8                                                        │
#> │   p-value      0.656                                                    │
#> │                                                                         │
#> │   digit  observed  expected        shape                                │
#> │       1     0.300     0.301  ####################                       │
#> │       2     0.184     0.176  ############                               │
#> │       3     0.124     0.125  ########                                   │
#> │       4     0.112     0.097  #######                                    │
#> │       5     0.078     0.079  #####                                      │
#> │       6     0.066     0.067  ####                                       │
#> │       7     0.062     0.058  ####                                       │
#> │       8     0.030     0.051  ##                                         │
#> │       9     0.044     0.046  ###                                        │
#> │                                                                         │
#> │   The leading digits are consistent with Benford's law (p = 0.656); the │
#> │   largest gap is at 8, 3.0% seen against 5.1% expected. Benford's law   │
#> │   expects a leading 1 about 30% of the time and a 9 under 5%. A         │
#> │   departure is a reason to look closer (rounding, thresholds, made-up   │
#> │   figures), never proof by itself.                                      │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# Keys and signatures print without ever showing the secret seed.
key <- pqckg(height = 2)
key
#> ╭── Signing key (post-quantum) ───────────────────────────────────────────────╮
#> │   scheme     xmss-sha256                                                    │
#> │   root       10c07288803a78d8d3dee59fb1032981a4c57feaacc5400ddcd655e0fc5529 │
#> │              12                                                             │
#> │   height     2                                                              │
#> │   used       0 of 4 signatures                                              │
#> │   remaining  4                                                              │
#> │   secret     <withheld>                                                     │
#> │   ! one signature per index; never sign twice at one index                  │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
cpssign("a-manifest", key)
#> ╭── Capsule signature ────────────────────────────────────────────────────────╮
#> │   scheme     xmss-sha256                                                    │
#> │   index      0                                                              │
#> │   root       10c07288803a78d8d3dee59fb1032981a4c57feaacc5400ddcd655e0fc5529 │
#> │              12                                                             │
#> │   signature  4b791583e517856d23c0de2094fc1b43... (2144 bytes)               │
#> │   auth path  2 nodes                                                        │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
options(op)
```
