# Archive many pages in the Wayback Machine

Asks the Internet Archive to take a dated copy of each web page or file
in a list, so that the exact source an analysis used (a statistics page,
a data download, a policy document) can be cited and checked later even
if the original changes or disappears. It needs a free archive.org
account and its API keys.

Saves every URL in the Internet Archive's Wayback Machine with Save Page
Now 2, the API archive.org offers to account holders, keeping several
captures in flight at once while keeping to archive.org's rate limits. A
page archived recently is kept as it is (`within`); a page archive.org
has already captured today (its daily limit) is recorded with that
capture. Each result is written to `output` as it arrives, so an
interrupted run started again with the same `output` carries on where it
stopped. A live progress bar shows the run while a person is watching.

## Usage

``` r
wayback_save(
  urls,
  access_key = NULL,
  secret_key = NULL,
  within = "30d",
  jobs = 4L,
  output = NULL,
  poll = 10,
  max_wait = 600,
  capture_all = FALSE,
  quiet = NULL,
  per_minute = 6,
  max_captures = 1000
)
```

## Arguments

- urls:

  Character vector of `http` or `https` URLs. Duplicates, `NA` and empty
  strings are dropped.

- access_key, secret_key:

  Your archive.org S3-like API keys
  (<https://archive.org/account/s3.php>). By default they are read from
  the environment variables `IA_S3_ACCESS_KEY` and `IA_S3_SECRET_KEY`,
  or from the files named by `IA_S3_ACCESS_KEY_FILE` and
  `IA_S3_SECRET_KEY_FILE` (a key file other users can read is warned
  about). They are sent to web.archive.org only and never printed.

- within:

  Keep a capture made within this long instead of making a new one: a
  number followed by `s`, `m`, `h` or `d` (default `"30d"`); `"0"`
  always captures.

- jobs:

  Captures in flight at once, 1 to 12. Default 4.

- output:

  Optional path of a JSON Lines file: one line per URL, written as each
  finishes, and read at the start so a run can be resumed. Its folder
  must exist; this is checked before anything is sent.

- poll:

  Seconds between status checks of a capture. Default 10.

- max_wait:

  Seconds a capture may take before it is given up as failed. Default
  600.

- capture_all:

  Also capture error pages (4xx and 5xx); default `FALSE`.

- quiet:

  `TRUE` for no progress output; the default shows it while a person is
  watching.

- per_minute:

  Captures started per minute, at most; default 6 (archive.org allows an
  account 7).

- max_captures:

  The most captures this run starts; default 1000. The rest are left for
  the next run (with the same `output`, it carries on from them).

## Value

A data frame of class `rmbl_wayback_save`, one row per URL with a
result: `url`, `status` (`"saved"`, a new capture; `"existing"`, a
capture already there; `"failed"`; or `"submitted"`, a capture started
when the run was stopped, polled again by the next run), `timestamp`
(`YYYYMMDDhhmmss`), `snapshot` (the archived copy's address) and
`message` (archive.org's reason, for a failure). The attribute
`not_sent` lists the URLs this run did not start (`max_captures`, or
archive.org's daily cap for the account).

## Details

Captures start no faster than `per_minute`. When archive.org asks the
run to slow down (HTTP 429, or a reply saying the account has too many
captures running, inside an HTTP 200 as SPN2 sends it), nothing more is
submitted until the wait is over: as long as its `Retry-After` says, or
15 seconds doubling to 10 minutes; eight such replies in a row stop the
run. A reply saying the account's daily cap is reached stops submitting
for the day. A server error or a lost connection is retried with
back-off, up to six times per URL; status checks that fail back off the
same way. A refused key (HTTP 401 or 403) stops the run.

A run of many URLs is slow by design: at the default 6 captures a
minute, 1,000 URLs take close to three hours. URLs already finished in
`output` are skipped, so a run can be stopped and restarted.

Network: every request goes to <https://web.archive.org>; the keys
travel in the `Authorization` header and are never written to `output`
or printed.

Errors, all raised before anything is sent: no usable URL; a URL with an
invisible or control character, or not starting with `http://` or
`https://`; missing keys, or keys that are not letters and digits;
`within` not of the form `"30d"`; `jobs` outside 1 to 12; `poll` below
1; `max_wait` below `poll`; `per_minute` outside (0, 60\];
`max_captures` below 1; `capture_all` not `TRUE` or `FALSE`; an `output`
whose folder does not exist or that cannot be written.

## References

Internet Archive. Save Page Now 2 (SPN2) public API.
<https://archive.org/details/spn-2-public-api-page-docs>.

## See also

[`wayback_snapshot_url_native`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url_native.md)
to look up an existing capture;
[`wayback_retry`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_retry.md);
`rmbl wayback FILE` runs this from the command line.

## Examples

``` r
# The checks run before any request, so these need no network or keys:
try(wayback_save("ftp://example.org/report.pdf"))
#> Error : not an http(s) URL: ftp://example.org/report.pdf
try(wayback_save("https://example.org/", access_key = "abc", secret_key = "def",
                 jobs = 20))
#> Error : `jobs` must be a whole number from 1 to 12
try(wayback_save("https://example.org/", access_key = "abc", secret_key = "def",
                 output = file.path(tempdir(), "no-such-folder", "runs.jsonl")))
#> Error : the folder for `output` does not exist: /tmp/RtmpZSI4mI/no-such-folder

# A real run needs archive.org keys and the network.
if (FALSE) { # \dontrun{
Sys.setenv(IA_S3_ACCESS_KEY_FILE = "~/.config/ia/s3_access_key.txt",
           IA_S3_SECRET_KEY_FILE = "~/.config/ia/s3_secret_key.txt")
res <- wayback_save(c("https://www.ontariocourts.ca/ocj/statistics/",
                      "https://www150.statcan.gc.ca/n1/tbl/csv/35100177-eng.zip"),
                    output = "snapshots.jsonl")
res
} # }
```
