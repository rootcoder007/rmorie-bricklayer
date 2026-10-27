# Is CPU energy measurable here?

`TRUE` when the operating system exposes readable RAPL (Running Average
Power Limit) energy counters for at least one CPU package: Linux with
the `intel_rapl` powercap driver (Intel and, since kernel 5.8, AMD),
with read permission on `energy_uj`. On most systems since Linux 5.10
that file is readable by root only, so `FALSE` is the common answer for
an ordinary user, and
[`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)
then falls back to its model.

## Usage

``` r
raplok(rapldir = "/sys/class/powercap")
```

## Arguments

- rapldir:

  Character scalar, the powercap directory; default
  `"/sys/class/powercap"`, the Linux location. Another path is useful
  for testing against a copy of the directory tree.

## Value

A logical scalar: `TRUE` when every CPU-package energy counter under
`rapldir` is readable, `FALSE` otherwise (including when the directory
does not exist).

## Details

A domain counts when it is a directory named `intel-rapl:N` (the
`intel-rapl:N:M` subdomains are parts of a package and would count the
same energy twice) whose `name` file starts with `"package"` and whose
`energy_uj` file holds a number. Every such domain must be readable: if
any is not, the answer is `FALSE`. Only files under `rapldir` are read;
nothing is written. On macOS and Windows there is no such directory and
the answer is `FALSE`. Errors when `rapldir` is not a single non-missing
string.

## See also

[`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md)

## Examples

``` r
raplok()
#> [1] FALSE

# a fake powercap tree with one readable package domain (Linux names the
# domain "intel-rapl:0"; a colon is not allowed in a Windows file name)
if (.Platform$OS.type != "windows") {
  d <- file.path(tempfile(), "intel-rapl:0")
  dir.create(d, recursive = TRUE)
  writeLines("package-0", file.path(d, "name"))
  writeLines("123456789", file.path(d, "energy_uj"))
  raplok(dirname(d))
}
#> [1] TRUE

# a folder that does not exist is simply FALSE; a non-path is an error
raplok(file.path(tempdir(), "no-such-dir"))
#> [1] FALSE
try(raplok(NA_character_))
#> Error : `rapldir` must be a single directory path
```
