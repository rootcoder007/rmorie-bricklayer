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
env <- capture_environment(c("stats", "utils"))
env$r_version
#> [1] "4.6.1"
```
