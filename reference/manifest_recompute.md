# Recompute a manifest's recorded statistics against the data

Re-evaluates named statistics against `data` and compares each to what
the manifest recorded. This is the check
[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md)
cannot make: that one confirms the record is internally consistent,
which an edited-at-the-time manifest also is. Use it when receiving a
capsule, or after a data refresh, to confirm that the numbers in the
record still come out of the data.

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

  The data the statistics are computed from (usually a data frame);
  passed unchanged to each function.

- statistics:

  Named list of functions of `data`, each returning one value. Names
  must match the recorded result names.

- tol:

  Optional numeric tolerance (absolute) overriding each result's own
  recorded `tol`. Supply it to check more strictly than the original run
  did. `NULL` (the default) uses the recorded one.

## Value

A list of class `c("bricklayer_recompute", "list")`:

- `ok`:

  logical, every statistic matched and none was left unchecked.

- `results`:

  data frame, one row per recomputed statistic, with `name` (character),
  `recorded` and `recomputed` (numeric, `NA` for non-numeric values),
  `delta` (numeric absolute difference), `tol` (numeric), `status`
  (`"MATCH"`, `"DIFFER"`, `"NOT_RECORDED"` or `"ERROR"`) and `detail`
  (character explanation).

- `unchecked`:

  character, the names recorded but not recomputed.

## Details

Every recorded result that was NOT recomputed is reported too, as
`unchecked`. An analysis that recorded twenty statistics and re-derives
three has seventeen it has not re-derived, and a report that quietly
omitted them would read as a clean bill of health.

For each function in `statistics`, its value on `data` is compared with
the `observed` value recorded under the same name. Numeric results match
when they are identical (so the same `NA`, `NaN` or infinite value on
both sides matches) or when \\\|recorded - recomputed\| \le tol\\, with
`tol` the argument if given, else the result's recorded `tol`, else 0
(exact); any other pair with a missing or non-finite value is
`"DIFFER"`. A non-numeric result (a label, a verdict) is compared as
text and must be identical. A function that errors gives the status
`"ERROR"` with the message; a name the manifest does not have gives
`"NOT_RECORDED"`. `ok` is `TRUE` only when every row is `"MATCH"` and
nothing recorded was left unchecked. The functions are run as given, so
they can read files or draw random numbers; nothing else is changed.

Errors: `manifest` not a list with `results`; `statistics` not a
non-empty fully named list, or with an element that is not a function.

## See also

[`verify_capsule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_capsule.md),
[`capsule_falsify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_falsify.md),
[`record()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/record.md).

## Examples

``` r
d <- data.frame(x = 1:10)
m <- make_manifest(list(dataset = "demo"), environment = FALSE)
m <- record(m, "mean_x", observed = mean(d$x), expected = 5.5)
#>   mean_x                                       observed = 5.5000       expected = 5.5000       [INFO]
m <- record(m, "n", observed = nrow(d), expected = 10)
#>   n                                            observed = 10.0000      expected = 10.0000      [INFO]

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

# a stricter tolerance than the recorded one
manifest_recompute(m, d, list(mean_x = function(z) mean(z$x) + 1e-9,
                              n = nrow), tol = 0)$results$status
#> [1] "DIFFER" "MATCH" 

# a function that fails is reported, not thrown
manifest_recompute(m, d, list(mean_x = function(z) stop("column y is gone"),
                              n = nrow))$results[, c("name", "status")]
#>     name status
#> 1 mean_x  ERROR
#> 2      n  MATCH

# statistics must be named
try(manifest_recompute(m, d, list(function(z) nrow(z))))
#> Error : `statistics` must be a non-empty named list of functions
```
