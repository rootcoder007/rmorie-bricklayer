# Capture the Analysis Environment for a Manifest

Records the facts a replicator needs to rebuild the session in which a
result was produced: the R version, platform and operating system, a UTC
timestamp, the random number generator in use and whether it was seeded,
and the versions of the packages involved. Store the result in a results
manifest (for example with
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md))
next to the numbers it produced, and compare two captures with
[`envdiff()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/envdiff.md).

## Usage

``` r
capenv(pkgs = loadedNamespaces())
```

## Arguments

- pkgs:

  Character vector of package names to record. Defaults to every
  currently loaded namespace
  ([`loadedNamespaces()`](https://rdrr.io/r/base/ns-load.html)).

## Value

A list of seven elements:

- `r_version`:

  character, e.g. `"4.5.1"`.

- `platform`:

  character, `R.version$platform`.

- `os`:

  character, the system name and release.

- `captured_utc`:

  character, ISO 8601 time `YYYY-MM-DDThh:mm:ssZ`.

- `rng_kind`:

  character, the three [`RNGkind()`](https://rdrr.io/r/base/Random.html)
  values joined by commas.

- `rng_seeded`:

  logical, whether `.Random.seed` exists.

- `packages`:

  named list of version strings, sorted by name (`NA` for a package that
  is not installed). A list, not a vector, so the names survive the
  manifest's JSON: a named vector is written as a bare array.

The list has class `c("rmbl_capenv", "list")`, which only changes how it
prints (a box); its elements, and the JSON written from it, are those of
a plain list.

## Details

Package versions come from
[`utils::packageVersion()`](https://rdrr.io/r/utils/packageDescription.html);
a package that is not installed gets `NA` rather than an error. The
packages are sorted and de-duplicated. The generator kinds come from
[`RNGkind()`](https://rdrr.io/r/base/Random.html) (R has changed its
default [`sample()`](https://rdrr.io/r/base/sample.html) algorithm
before, so a recorded seed means nothing without the kind it was fed
to), and `rng_seeded` says whether `.Random.seed` exists in the global
environment. Nothing is written and the random state is not touched.

## Examples

``` r
# Record specific packages' versions alongside the session facts.
env <- capenv(c("stats", "utils"))
env$r_version
#> [1] "4.6.2"
env$os
#> [1] "Linux 7.0.0-1017-azure"
env$packages          # named list of versions
#> $stats
#> [1] "4.6.2"
#> 
#> $utils
#> [1] "4.6.2"
#> 

# Default captures every currently loaded namespace.
names(capenv())
#> [1] "r_version"    "platform"     "os"           "captured_utc" "rng_kind"    
#> [6] "rng_seeded"   "packages"    

# the generator and whether it was seeded
set.seed(42)
capenv("stats")[c("rng_kind", "rng_seeded")]
#> $rng_kind
#> [1] "Mersenne-Twister,Inversion,Rejection"
#> 
#> $rng_seeded
#> [1] TRUE
#> 

# a package that is not installed is recorded as NA, not an error
capenv(c("stats", "notapackage123"))$packages
#> $notapackage123
#> [1] NA
#> 
#> $stats
#> [1] "4.6.2"
#> 
```
