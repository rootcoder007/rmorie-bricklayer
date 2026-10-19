# Compare two captured environments

Reports what changed between the environment captured by one run and
another: the R version, the platform, and every package whose version
differs, was added, or disappeared. Use it when a result does not
reproduce, to see first whether the software around it changed.

## Usage

``` r
envdiff(a, b)
```

## Arguments

- a, b:

  Environment records from
  [`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md),
  or whole manifests (such as
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)
  returns) that hold an `environment` element.

## Value

A list of class `c("bricklayer_env_diff", "list")`: `identical`
(logical, `TRUE` when R version, platform and all package versions
agree), `r_version` (a named length-2 character vector `c(a = , b = )`
when they differ, else `NULL`), `platform` (likewise), and `packages` (a
data frame with character columns `package`, `a`, `b` and `change`,
where `change` is `"added"`, `"removed"` or `"changed"`; no rows when
nothing differs).

## Details

This is the question a failed reproduction actually raises. A manifest
records the environment; comparing two manifests by eye across a few
hundred packages does not scale, and the one line that matters – a
dependency that moved a minor version – is exactly what gets missed.

Versions are compared as strings. A package recorded in `b` but not in
`a` (or recorded with an `NA` version in `a`) is `"added"`; the reverse
is `"removed"`. The operating-system string, the capture time and the
random number generator settings are not compared. Rows follow the order
of `a`'s packages, then `b`'s new ones.

Error: `a` or `b` that is not a list.

## See also

[`capenv()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capenv.md),
[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md)

## Examples

``` r
a <- capenv(c("stats", "utils"))
b <- a

# An environment matches itself.
envdiff(a, b)$identical
#> [1] TRUE

# Stage a moved dependency, an added one and a newer R.
b$packages[["stats"]] <- "0.0.0"
b$packages[["tools"]] <- "4.9.0"
b$r_version <- "9.9.9"
d <- envdiff(a, b)
d$packages
#>   package     a     b  change
#> 1   stats 4.6.1 0.0.0 changed
#> 2   tools  <NA> 4.9.0   added
d$r_version
#>       a       b 
#> "4.6.1" "9.9.9" 
d
#> ── Environment diff ──────────────────────────────────────────────
#>   ✗ environments differ
#> 
#>   R version  4.6.1 -> 9.9.9
#>   2 package difference(s):
#> 
#>   stats                    4.6.1        0.0.0        changed
#>   tools                    –          4.9.0        added
#> ──────────────────────────────────────────────────────────────────

# Whole manifests are accepted, not just the environment block.
m <- mkmnf(list(run = "demo"))
envdiff(m, m)$identical
#> [1] TRUE

# anything other than a record is refused
try(envdiff("4.5.1", a))
#> Error : `a` and `b` must be environment records or manifests
```
