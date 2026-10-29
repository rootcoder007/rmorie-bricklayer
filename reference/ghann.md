# GitHub workflow annotations, sticky comment and outputs of a capsule check

Plain text for a GitHub Actions step, from a
[`cpschk`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)
result: nothing here talks to GitHub, the caller prints or posts it.
`ghann()` gives one workflow command per failed check, an `::error` for
an error row and a `::warning` for a warn or drift row (notes give
none), naming the file and, where the row has one, the line, with the
data and properties escaped as GitHub requires. `ghcmt()` gives the body
of a sticky pull-request comment: the marker line that finds it again,
the Markdown report and a link to the run, cut to fit GitHub's
65,536-character limit. `ghout()` gives the step outputs of the rmbl
action as a named list (print each as `name=value` to `$GITHUB_OUTPUT`).

## Usage

``` r
ghann(x)

ghcmt(
  x,
  runurl = NULL,
  failon = NULL,
  marker = "<!-- rmbl-action -->",
  limit = 65000L
)

ghout(x, report = "", json = "", comment = "off")
```

## Arguments

- x:

  An `rmbl_cpschk` result.

- runurl:

  Character scalar or `NULL`: the run's address, linked at the end of
  the comment.

- failon:

  Character scalar or `NULL`: the fail-on level, named in the report's
  last line.

- marker:

  Character scalar, the comment's first line (an HTML comment, invisible
  on GitHub).

- limit:

  Integer: the longest body; a longer one is cut and says so.

- report, json:

  Character scalars: the paths of the report and the JSON written,
  passed through as outputs.

- comment:

  Character scalar: what became of the comment (`off`, `dry-run`,
  `skipped`, `created`, `updated` or `failed`), passed through.

## Value

`ghann()`: a character vector, one line per annotation. `ghcmt()`: one
string. `ghout()`: a named list with `status`, `report`, `json`,
`changed` (the capsules whose source bytes changed, comma-separated),
`verified` (capsules without an error), `failed`, `manifest-changed`
(`"true"` or `"false"`) and `comment`. Error: `x` is not a
[`cpschk()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md)
result.

## See also

[`cpschk`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpschk.md).

## Examples

``` r
root <- tempfile("capsules-")
d <- usecpstmpl(file.path(root, "one"), ex = TRUE)
invisible(cpsrfrsh(d))
p <- loadprov(file.path(d, "data_provenance.json"))
cat("1,2\n", file = file.path(d, p$resource$filename), append = TRUE)
x <- cpschk(root, fp = FALSE)
ghann(x)
#> [1] "::error file=/tmp/RtmpeuB1Ln/capsules-1f7f1adf9ebd/one/data_provenance.json,title=rmbl provenance data_sha256::expected 6b1a0d2d11f62eaffe4a95111286753aca9afc015fc4d0ea07c9953ff3030248, got e0061f4de8d524e9a8a421b502ae878a4de372a841e6bdf3ac3a5140b86682c8"
#> [2] "::error file=/tmp/RtmpeuB1Ln/capsules-1f7f1adf9ebd/one/data_provenance.json,title=rmbl provenance data_size_bytes::466 bytes on disk"                                                                                                                          
substr(ghcmt(x, runurl = "https://github.com/o/r/actions/runs/1"), 1, 80)
#> [1] "<!-- rmbl-action -->\n## rmbl capsule verify with [rmoriebricklayer 1.0.3](https:"
str(ghout(x, report = "rmbl-report.md", json = "rmbl-results.json"))
#> List of 8
#>  $ status          : chr "error"
#>  $ report          : chr "rmbl-report.md"
#>  $ json            : chr "rmbl-results.json"
#>  $ changed         : chr ""
#>  $ verified        : int 0
#>  $ failed          : int 1
#>  $ manifest-changed: chr "false"
#>  $ comment         : chr "off"

# one output per line, as $GITHUB_OUTPUT takes them
o <- ghout(x)
cat(sprintf("%s=%s\n", names(o), unlist(o)), sep = "")
#> status=error
#> report=
#> json=
#> changed=
#> verified=0
#> failed=1
#> manifest-changed=false
#> comment=off

try(ghann(list()))
#> Error : ghann: `x` must be a cpschk() result
```
