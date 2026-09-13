# Where each loaded package came from

Records, for every package named, its version and enough about its
provenance to find the same one again: the library it was loaded from,
the repository it was installed from, and – for a package installed from
a remote – the remote's URL and commit.

## Usage

``` r
capture_dependencies(packages = loadedNamespaces())
```

## Arguments

- packages:

  Character vector of package names. Defaults to the namespaces
  currently loaded.

## Value

A data frame with one row per package: `package`, `version`, `library`,
`repository`, `remote_url`, `remote_sha`, `built`. Unavailable fields
are `NA` rather than omitted, so a reader can see that the information
was absent rather than forgotten.

## Details

Why versions alone are not enough. Two installations can report the same
version and differ: one built from CRAN, one from a fork, one from a
local `R CMD INSTALL` of a working tree with uncommitted changes. A
version number identifies an intention; the repository and commit
identify what was actually loaded.

## See also

[`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md),
[`environment_diff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/environment_diff.md).

## Examples

``` r
deps <- capture_dependencies(c("stats", "utils"))
deps[, c("package", "version")]
#>   package version
#> 1   stats   4.6.1
#> 2   utils   4.6.1

# a package with no repository field records that fact
is.na(capture_dependencies("stats")$repository)
#> [1] TRUE
```
