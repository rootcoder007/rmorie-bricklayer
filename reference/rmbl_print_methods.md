# Printed reports for bricklayer objects

Human-readable renderings of the objects the package returns. Each leads
with the verdict, then the evidence.
[`format()`](https://rdrr.io/r/base/format.html) returns the lines as a
character vector so they can be logged or written to a file;
[`print()`](https://rdrr.io/r/base/print.html) sends them to the console
and returns its argument invisibly.

## Usage

``` r
# S3 method for class 'bricklayer_chain'
print(x, ...)

# S3 method for class 'bricklayer_mcar'
print(x, ...)

# S3 method for class 'bricklayer_drift'
print(x, ...)

# S3 method for class 'bricklayer_drift'
summary(object, ...)

# S3 method for class 'bricklayer_benford'
print(x, ...)

# S3 method for class 'bricklayer_signing_key'
print(x, ...)

# S3 method for class 'bricklayer_public_key'
print(x, ...)

# S3 method for class 'bricklayer_signature'
print(x, ...)

# S3 method for class 'bricklayer_benford'
summary(object, ...)

# S3 method for class 'bricklayer_env_diff'
print(x, ...)

# S3 method for class 'bricklayer_report'
print(x, ...)

# S3 method for class 'bricklayer_report'
summary(object, ...)

# S3 method for class 'bricklayer_schema'
print(x, ...)

# S3 method for class 'bricklayer_oqs_key'
print(x, ...)

# S3 method for class 'bricklayer_oqs_public_key'
print(x, ...)
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
set.seed(7)
ref <- data.frame(v = stats::rnorm(200),
                  g = sample(c("a", "b"), 200, TRUE))
cur <- data.frame(v = stats::rnorm(200, mean = 1),
                  g = sample(c("a", "b"), 200, TRUE))

# The drift report leads with its verdict.
capsule_drift(ref, cur)
#> ── Capsule drift report ──────────────────────────────────────────
#>   ✗ DRIFT DETECTED
#> 
#>   reference rows  200
#>   current rows    200
#>   columns tested  2
#>   alpha           0.01
#> 
#> ── Per-column tests ──────────────────────────────────────────────
#>      column        type stat        p   psi
#>    ✗      v     numeric 0.36 1.11e-11 0.814
#>    ✓      g categorical 1.44     0.23     –
#> ──────────────────────────────────────────────────────────────────

# format() gives the same lines for a log file.
head(format(capsule_drift(ref, cur)), 3)
#> [1] "── Capsule drift report ──────────────────────────────────────────"
#> [2] "  ✗ DRIFT DETECTED"                                                
#> [3] ""                                                                  

# A Benford screen.
benford_test(10^stats::runif(500, 0, 5))
#> ── Benford first-digit screen ────────────────────────────────────
#>   ✓ consistent with Benford's law
#> 
#>   values used  500
#>   chi-square   5.919
#>   df           8
#>   p-value      0.656
#> 
#>   digit  observed  expected        shape
#>       1     0.300     0.301  ####################
#>       2     0.184     0.176  ############        
#>       3     0.124     0.125  ########            
#>       4     0.112     0.097  #######             
#>       5     0.078     0.079  #####               
#>       6     0.066     0.067  ####                
#>       7     0.062     0.058  ####                
#>       8     0.030     0.051  ##                  
#>       9     0.044     0.046  ###                 
#> ──────────────────────────────────────────────────────────────────

# Keys and signatures print without ever showing the secret seed.
key <- pqc_keygen(height = 2)
key
#> ── Signing key (post-quantum) ────────────────────────────────────
#>   scheme     xmss-sha256
#>   root       921b0056f85ebf293a6ded6e84871070a93e5fd62e025c9a7a91f63cafdcec1d
#>   height     2
#>   used       0 of 4 signatures
#>   remaining  4
#>   secret     <withheld>
#>   ! one signature per index; never sign twice at one index
#> ──────────────────────────────────────────────────────────────────
capsule_sign("a-manifest", key)
#> ── Capsule signature ─────────────────────────────────────────────
#>   scheme     xmss-sha256
#>   index      0
#>   root       921b0056f85ebf293a6ded6e84871070a93e5fd62e025c9a7a91f63cafdcec1d
#>   signature  d25129d49ea9b692f4b04ba89687ce71... (2144 bytes)
#>   auth path  2 nodes
#> ──────────────────────────────────────────────────────────────────
```
