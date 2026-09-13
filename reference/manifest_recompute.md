# Recompute a manifest's recorded statistics against the data

Re-evaluates named statistics against `data` and compares each to what
the manifest recorded. This is the check
[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
cannot make: that one confirms the record is internally consistent,
which an edited-at-the-time manifest also is.

## Usage

``` r
manifest_recompute(manifest, data, statistics, tol = NULL)
```

## Arguments

- manifest:

  A manifest, as from
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)
  and
  [`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

- data:

  The data the statistics are computed from.

- statistics:

  Named list of functions of `data`. Names must match the recorded
  result names.

- tol:

  Optional numeric tolerance overriding each result's own recorded
  `tol`. Supply it to check more strictly than the original run did.

## Value

A list of class `bricklayer_recompute`: `ok`, a `results` data frame
with one row per recomputed statistic ( `name`, `recorded`,
`recomputed`, `delta`, `tol`, `status`) , and `unchecked`, the names
recorded but not recomputed.

## Details

Every recorded result that was NOT recomputed is reported too, as
`unchecked`. An analysis that recorded twenty statistics and re-derives
three has seventeen it has not re-derived, and a report that quietly
omitted them would read as a clean bill of health.

## See also

[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md),
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

## Examples

``` r
d <- data.frame(x = 1:10)
m <- make_manifest(list(dataset = "demo"), environment = FALSE)
m <- record(m, "mean_x", observed = mean(d$x), expected = 5.5)
#>   mean_x                                       observed = 5.5000       expected = 5.5000       [PASS]
m <- record(m, "n", observed = nrow(d), expected = 10)
#>   n                                            observed = 10.0000      expected = 10.0000      [PASS]

# recomputing both reproduces them
res <- manifest_recompute(m, d, list(mean_x = function(z) mean(z$x),
                                     n = function(z) nrow(z)))
res$ok
#> [1] TRUE
res$results[, c("name", "recorded", "recomputed", "status")]
#>     name recorded recomputed status
#> 1 mean_x      5.5        5.5  MATCH
#> 2      n     10.0       10.0  MATCH

# recomputing one leaves the other reported as unchecked
manifest_recompute(m, d, list(n = function(z) nrow(z)))$unchecked
#> [1] "mean_x"

# and data that no longer matches the record is caught
manifest_recompute(m, data.frame(x = 1:11),
                   list(n = function(z) nrow(z)))$ok
#> [1] FALSE
```
