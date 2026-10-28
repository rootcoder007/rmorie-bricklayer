# Retry the failures of a bulk Wayback run

Picks up where a
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
run left off: it re-tries only the URLs whose captures failed or were
still running, after first checking whether the Wayback Machine already
holds a copy of each. Use it after a run that hit archive.org's limits,
typically the next day.

## Usage

``` r
wbrtry(output, incgone = FALSE, lookup = TRUE, ...)
```

## Arguments

- output:

  The JSON Lines results file of an earlier
  [`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
  run (or of `rmbl wayback`); results of the retry are appended to it.

- incgone:

  Logical, default `FALSE`. Also capture again the pages whose failure
  says the page is gone.

- lookup:

  Logical, default `TRUE`. Look each failure up in the Wayback Machine
  (one lookup a second) before capturing again.

- ...:

  Passed to
  [`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md):
  `jobs`, `within`, the keys, `quiet`, `permin`, `maxcap`.

## Value

The whole run as it now stands, one row per URL (a data frame of class
`rmbl_wayback_save`), with the attribute `retry`: how many failures
there were, how many a lookup found, how many were captured again, how
many were left as gone, and how many were left for tomorrow (a daily
limit hit today), as a one-row data frame with integer columns `failed`,
`found_by_lookup`, `captured_again`, `left_as_gone` and
`left_for_tomorrow`.

## Details

Reads the results file a
[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md)
run wrote and tries again every URL whose latest result is `"failed"`
(or `"submitted"`: a capture a stopped run had started, which is polled
rather than submitted again), so nobody has to dig the failures out by
hand. Each failed URL is first looked up in the Wayback Machine, one
lookup a second: a capture made at any time (an earlier one of a page
that has since gone, or one made today by another run when the daily
limit refused this one) is recorded as `"existing"` without capturing
again. What is left is captured again with
[`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md),
appending to the same file. A page its source no longer has is not sent
again unless `incgone = TRUE`: a new capture would only archive the
error. `"Gone"` means the recorded message contains archive.org's report
of the target server's reply (“target server cannot find”, “returned
404”, “returned 410”, `"error:not-found"` or `"error:gone"`); an HTTP
404 from archive.org's own API does not count. A failure for a daily
limit recorded today (UTC) is not sent again until tomorrow.

Network: the lookups use the Wayback availability API and the new
captures use
[`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md),
which needs the archive.org keys. When there is nothing left to send, no
keys and no network are needed. Each lookup that finds a capture is
appended to `output` as an `"existing"` line.

Errors: `output` not a single path to an existing file; `incgone` or
`lookup` not `TRUE` or `FALSE`; any error from
[`wbsave()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md).

## See also

[`wbsave`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wbsave.md);
`rmbl wayback --retry FILE.jsonl` from the command line.

## Examples

``` r
# Offline: a results file whose only failure is a page that is gone
# has nothing to send again, so no keys or network are used.
f <- tempfile(fileext = ".jsonl")
writeLines(
  c(
    paste0(
      '{"url":"https://example.org/","status":"saved",',
      '"timestamp":"20260101120000",',
      '"snapshot":"https://web.archive.org/web/20260101120000/https://',
      'example.org/",',
      '"message":"","at":"2026-01-01T12:00:00Z"}'
    ),
    paste0(
      '{"url":"https://example.org/old","status":"failed",',
      '"message":"target server cannot find the ',
      'page","at":"2026-01-01T12:00:00Z"}'
    )
  ),
  f
)
res <- wbrtry(f, lookup = FALSE)
res
#> ╭── Wayback Machine captures ─────────────────────────────────────────────────╮
#> │   URLs  2 URLs: 1 saved, 0 existing, 1 failed                               │
#> │                                                                             │
#> │   status  timestamp       url                                               │
#> │   ------  --------------  -----------------------                           │
#> │   saved   20260101120000  https://example.org/                              │
#> │   failed                  https://example.org/old                           │
#> │                                                                             │
#> │   Saved and existing URLs have a copy in the Wayback Machine at the         │
#> │   timestamp shown; wbrtry() tries the failed ones again.                    │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
attr(res, "retry")
#>   failed found_by_lookup captured_again left_as_gone left_for_tomorrow
#> 1      1               0              0            1                 0

try(wbrtry(tempfile(fileext = ".jsonl")))
#> Error : no results file at /tmp/RtmpysAncb/file20e64900c6a1.jsonl

# With failures to resend, keys and the network are needed.
if (FALSE) { # interactive()
res <- wbsave(urls, output = "snapshots.jsonl")
# later, or the next day once the daily capture limits have reset:
res <- wbrtry("snapshots.jsonl")
attr(res, "retry")
}
```
