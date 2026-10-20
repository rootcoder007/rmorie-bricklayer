# Compare the resources of two manifests

Lists the resources (data files) of two manifests side by side and says
which were added, removed or changed: a different SHA-256, or a
different size where both sizes are recorded. A manifest is a provenance
record (its `resource`), a capsule bundle (its `files`), a data frame
with the columns `path` and `sha256` (and optionally `size_bytes`), or
the path of a JSON file holding one of the first two.
[`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md)
and `rmbl drift` report what a fetched source changed with it.

## Usage

``` r
mnfdiff(old, new)

# S3 method for class 'rmbl_mnfdiff'
format(x, ...)

# S3 method for class 'rmbl_mnfdiff'
print(x, ...)
```

## Arguments

- old, new:

  The two manifests, as described above. A list with neither `resource`
  nor `files` has no resources.

- x:

  An `rmbl_mnfdiff` result.

- ...:

  Not used.

## Value

A data frame of class `rmbl_mnfdiff`, one row per resource in either
manifest, with the columns `resource` (the file name), `change`
(`"added"`, `"removed"`, `"changed"` or `"unchanged"`), `old_sha256`,
`new_sha256`, `old_size` and `new_size` (`NA` where not recorded). It
prints the counts and one line per change. Errors: a manifest that is
not a list, a data frame or a file; a data frame without `path` and
`sha256`.

## See also

[`cpsrfrsh`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsrfrsh.md),
[`cpsbndl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsbndl.md).

## Examples

``` r
a <- data.frame(path = c("a.csv", "b.csv"), sha256 = c("01", "02"),
                size_bytes = c(10, 20))
b <- data.frame(path = c("a.csv", "c.csv"), sha256 = c("09", "03"),
                size_bytes = c(12, 30))
d <- mnfdiff(a, b)
d
#> Manifest diff: 1 changed, 1 added, 1 removed, 0 unchanged
#>   changed   a.csv  sha256 01 -> 09, 10 -> 12 bytes
#>   removed   b.csv  sha256 02 -> -, 20 -> - bytes
#>   added     c.csv  sha256 - -> 03, - -> 30 bytes
d$change
#> [1] "changed" "removed" "added"  

# a provenance record and its re-pinned copy
p <- list(resource = list(filename = "a.csv", sha256 = "01", size_bytes = 10))
q <- p
q$resource$sha256 <- "09"
mnfdiff(p, q)$change
#> [1] "changed"

try(mnfdiff(1, b))
#> Error : mnfdiff: `old` must be a provenance record, a capsule bundle, a data frame of path and sha256, or the path of a JSON file
```
