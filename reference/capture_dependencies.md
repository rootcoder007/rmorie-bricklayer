# Where each loaded package came from

Records, for every package named, its version and enough about its
provenance to find the same one again: the library it was loaded from,
the repository it was installed from, and – for a package installed from
a remote – the remote's URL and commit. Store it in a manifest next to
[`capture_environment()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capture_environment.md)
when an analysis depends on packages installed from GitHub or a local
build.

## Usage

``` r
capture_dependencies(packages = loadedNamespaces())
```

## Arguments

- packages:

  Character vector of package names. Defaults to the namespaces
  currently loaded.

## Value

A data frame with one row per package and character columns `package`,
`version`, `library` (the library directory), `repository`,
`remote_url`, `remote_sha` and `built` (R version, platform and time of
the build). Unavailable fields are `NA` rather than omitted, so a reader
can see that the information was absent rather than forgotten; for a
package that is not installed, every field except `package` is `NA`. An
empty `packages` gives a data frame with no rows and the same columns.

## Details

Why versions alone are not enough. Two installations can report the same
version and differ: one built from CRAN, one from a fork, one from a
local `R CMD INSTALL` of a working tree with uncommitted changes. A
version number identifies an intention; the repository and commit
identify what was actually loaded.

The fields are read from each package's installed DESCRIPTION
([`utils::packageDescription()`](https://rdrr.io/r/utils/packageDescription.html)):
`Repository` (for example `"CRAN"`), `RemoteUrl` and `RemoteSha`
(written by remotes, pak and devtools for packages installed from a Git
host) and `Built`. Packages are sorted and de-duplicated. A progress bar
is drawn on stderr for many packages unless
`options(morie.quiet = TRUE)`. Nothing is written. Error: `packages`
that is not a character vector.

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

# a package that is not installed is a row of NAs, not an error
capture_dependencies("notapackage123")[, c("package", "version")]
#>          package version
#> 1 notapackage123    <NA>

# names must be character
try(capture_dependencies(1))
#> Error : `packages` must be a character vector of package names
```
