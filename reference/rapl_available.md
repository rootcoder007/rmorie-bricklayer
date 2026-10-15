# Is CPU energy measurable here?

`TRUE` when the operating system exposes readable RAPL (Running Average
Power Limit) energy counters for at least one CPU package: Linux with
the `intel_rapl` powercap driver (Intel and, since kernel 5.8, AMD),
with read permission on `energy_uj`. On most systems since Linux 5.10
that file is readable by root only, so `FALSE` is the common answer for
an ordinary user, and
[`compute_footprint`](https://rootcoder007.github.io/rmorie-bricklayer/reference/compute_footprint.md)
then falls back to its model.

## Usage

``` r
rapl_available(rapl_dir = "/sys/class/powercap")
```

## Arguments

- rapl_dir:

  Character scalar, the powercap directory; default
  `"/sys/class/powercap"`, the Linux location. Another path is useful
  for testing against a copy of the directory tree.

## Value

A logical scalar: `TRUE` when every CPU-package energy counter under
`rapl_dir` is readable, `FALSE` otherwise (including when the directory
does not exist).

## Details

A domain counts when it is a directory named `intel-rapl:N` (the
`intel-rapl:N:M` subdomains are parts of a package and would count the
same energy twice) whose `name` file starts with `"package"` and whose
`energy_uj` file holds a number. Every such domain must be readable: if
any is not, the answer is `FALSE`. Only files under `rapl_dir` are read;
nothing is written. On macOS and Windows there is no such directory and
the answer is `FALSE`. Errors when `rapl_dir` is not a single
non-missing string.

## See also

[`compute_footprint`](https://rootcoder007.github.io/rmorie-bricklayer/reference/compute_footprint.md)

## Examples

``` r
rapl_available()
#> [1] FALSE

# a fake powercap tree with one readable package domain
d <- file.path(tempfile(), "intel-rapl:0")
dir.create(d, recursive = TRUE)
writeLines("package-0", file.path(d, "name"))
writeLines("123456789", file.path(d, "energy_uj"))
rapl_available(dirname(d))
#> [1] TRUE

# a folder that does not exist is simply FALSE; a non-path is an error
rapl_available(file.path(tempdir(), "no-such-dir"))
#> [1] FALSE
try(rapl_available(NA_character_))
#> Error : `rapl_dir` must be a single directory path
```
