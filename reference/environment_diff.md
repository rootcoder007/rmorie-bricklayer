# Compare two captured environments

Reports what changed between the environment captured by one run and
another: the R version, the platform, and every package whose version
differs, was added, or disappeared.

## Usage

``` r
environment_diff(a, b)
```

## Arguments

- a, b:

  Environment records from
  [`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md),
  or whole manifests containing an `environment` element.

## Value

A list of class `bricklayer_env_diff`: `identical` (logical),
`r_version` (a length-2 character vector when they differ, else `NULL`)
, `platform` (likewise), and `packages` (a data frame of `package`, `a`,
`b`, `change`, where `change` is `"added"`, `"removed"` or `"changed"`)
.

## Details

This is the question a failed reproduction actually raises. A manifest
records the environment; comparing two manifests by eye across a few
hundred packages does not scale, and the one line that matters – a
dependency that moved a minor version – is exactly what gets missed.

## See also

[`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md),
[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md)

## Examples

``` r
a <- capture_environment()
b <- a

# An environment matches itself.
environment_diff(a, b)$identical
#> [1] TRUE

# Stage a moved dependency and a removed one.
if (length(b$packages)) {
  nm <- names(b$packages)[1]
  b$packages[[nm]] <- "0.0.0"
  environment_diff(a, b)$packages
}
#>   package     a     b  change
#> 1      R6 2.6.1 0.0.0 changed

# Whole manifests are accepted, not just the environment block.
m <- make_manifest(list(run = "demo"))
environment_diff(m, m)$identical
#> [1] TRUE
```
