# Resolve a Wayback Machine snapshot URL

Asks the Internet Archive which archived copy of a web address is
closest to a given time and returns a URL that downloads that copy. This
is the fetch failsafe the wider morie package family relies on: callers
try the live source first and fall back to the snapshot when the source
is down, has moved or has been taken offline.
[`fdl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/fdl.md)
uses it automatically.

## Usage

``` r
wbsnpurl(url, ts = NULL)
```

## Arguments

- url:

  The original source URL to look up, a single string.

- ts:

  Optional target time as a string of digits `YYYYMMDDhhmmss` (or a
  prefix such as `"2023"` or `"20230115"`); the API returns the snapshot
  closest to it. `NULL` or `""` (the default) asks for the most recent.

## Value

A length-1 character string, the `https` snapshot URL of the form
`https://web.archive.org/web/` followed by `<timestamp>/<url>`, or
`NULL`.

## Details

The function sends one request to the availability API,  
`https://archive.org/wayback/available?url=<url>[&timestamp=<ts>]`,  
where the timestamp part is sent only when `ts` is given.

The answer's `archived_snapshots$closest` is read. When the API reports
an available snapshot its URL is returned, with `http://` rewritten to
`https://` and passed through the same public-URL check as every other
URL the package fetches. The timestamp is passed to the API as given;
the API accepts any prefix of `YYYYMMDDhhmmss` and returns the snapshot
nearest to it, before or after.

`NULL` is returned when the API has no snapshot, when the request fails
(offline, an HTTP error, invalid JSON) or when the answer has no usable
URL. Errors: `url` that is not a single non-empty string or is not a
public web address; `ts` that is not `NULL`, `""` or a string of 1 to 14
digits. Nothing is written.

## Examples

``` r
# argument errors come before any request
try(wbsnpurl(NA))
#> Error : wbsnpurl: `url` must be a single non-empty string
try(wbsnpurl("https://www.r-project.org/", ts = "2020&x=1"))
#> Error : wbsnpurl: `ts` must be NULL, "" or a string of 1 to 14 digits (YYYYMMDDhhmmss or a prefix of it)
try(wbsnpurl(c("https://a.org", "https://b.org")))
#> Error : wbsnpurl: `url` must be a single non-empty string
if (FALSE) { # interactive()
# needs the network
wbsnpurl("https://www.r-project.org/")
# the snapshot nearest to January 2020
wbsnpurl("https://www.r-project.org/", ts = "202001")
}
```
