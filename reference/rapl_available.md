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

  The powercap directory; the default is the Linux location.

## Value

A single logical.

## Examples

``` r
rapl_available()
#> [1] FALSE
```
