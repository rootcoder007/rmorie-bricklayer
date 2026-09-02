# Capture the Analysis Environment for a Manifest

Records the facts a replicator needs to rebuild the session: R version,
platform, operating system, a UTC timestamp, and the versions of the
requested packages.

## Usage

``` r
capture_environment(packages = loadedNamespaces())
```

## Arguments

- packages:

  Character vector of package names to record. Defaults to every
  currently loaded namespace.

## Value

A list with `r_version`, `platform`, `os`, `captured_utc`, and
`packages` (a named character vector of versions).

## Examples

``` r
# Record specific packages' versions alongside the session facts.
env <- capture_environment(c("stats", "utils"))
env$r_version
#> [1] "4.6.1"
env$os
#> [1] "Linux 6.17.0-1022-azure"
env$packages          # named character vector of versions
#>   stats   utils 
#> "4.6.1" "4.6.1" 

# Default captures every currently loaded namespace.
names(capture_environment())[1:4]
#> [1] "r_version"    "platform"     "os"           "captured_utc"
```
