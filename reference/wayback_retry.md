# Retry the failures of a bulk Wayback run

Reads the results file a
[`wayback_save`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md)
run wrote and tries again every URL whose latest result is `"failed"`
(or `"submitted"`: a capture a stopped run had started, which is polled
rather than submitted again), so nobody has to dig the failures out by
hand. Each failed URL is first looked up in the Wayback Machine, one
lookup a second: a capture made at any time (an earlier one of a page
that has since gone, or one made today by another run when the daily
limit refused this one) is recorded as `"existing"` without capturing
again. What is left is captured again with
[`wayback_save()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md),
appending to the same file. A page its source no longer has (HTTP 404 or
410, "cannot find") is not sent again unless `include_gone = TRUE`: a
new capture would only archive the error. A failure for a daily limit
recorded today (UTC) is not sent again until tomorrow.

## Usage

``` r
wayback_retry(output, include_gone = FALSE, lookup = TRUE, ...)
```

## Arguments

- output:

  The JSON Lines results file of an earlier
  [`wayback_save()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md)
  run (or of `rmbl wayback`); results of the retry are appended to it.

- include_gone:

  Also capture again the pages whose failure says the page is gone.

- lookup:

  Look each failure up in the Wayback Machine before capturing again.

- ...:

  Passed to
  [`wayback_save()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md):
  `jobs`, `within`, the keys, `quiet`, `per_minute`, `max_captures`.

## Value

The whole run as it now stands, one row per URL (a data frame of class
`rmbl_wayback_save`), with the attribute `retry`: how many failures
there were, how many a lookup found, how many were captured again, how
many were left as gone, and how many were left for tomorrow (a daily
limit hit today).

## See also

[`wayback_save`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_save.md);
`rmbl wayback --retry FILE.jsonl` from the command line.

## Examples

``` r
if (FALSE) { # \dontrun{
res <- wayback_save(urls, output = "snapshots.jsonl")
# later, or the next day once the daily capture limits have reset:
res <- wayback_retry("snapshots.jsonl")
attr(res, "retry")
} # }
```
