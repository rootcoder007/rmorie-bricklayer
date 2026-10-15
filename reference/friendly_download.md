# Download a File With Diagnostic Error Messages

Downloads one file like
[`download_data()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/download_data.md),
but never stops on a network failure: it returns `TRUE` or `FALSE`,
prints plain-language advice for the usual academic and corporate
network problems, and then tries a Wayback Machine copy of the same
address. Use it in scripts that other people run on networks you do not
control (university VPNs, corporate proxies), where a bare "cannot open
the connection" is not enough to act on.

## Usage

``` r
friendly_download(url, target_path, attempt_wayback = NULL, allow_file = FALSE)
```

## Arguments

- url:

  URL to download, a single string.

- target_path:

  Destination path on disk, a single string.

- attempt_wayback:

  The Wayback Machine snapshot URL tried as a fallback if the primary
  download fails. `NULL` (the default) resolves a snapshot automatically
  via
  [`wayback_snapshot_url()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url.md)
  (one more request); a URL string overrides the lookup; `""` or `FALSE`
  disables the fallback entirely.

- allow_file:

  Logical. Accept a `file://` URL for `url` (default `FALSE`; offline
  tests pass `TRUE`). It does not apply to `attempt_wayback`.

## Value

`TRUE` if either the primary download or the Wayback fallback succeeded
(the file is at `target_path`), otherwise `FALSE`.

## Details

The URL is checked first, as in
[`download_data()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/download_data.md);
a refused URL is an error, not `FALSE`. The download is then attempted.
On failure the messages name the URL and the error, then the likely
causes picked out from the error text: rate limiting (HTTP 429, common
behind shared VPN addresses), a TLS handshake failure (VPNs that inspect
TLS, such as Cisco AnyConnect, GlobalProtect, Zscaler or Netskope), a
DNS failure, a refused or reset connection, a timeout, an HTTP 403, or
otherwise a moved file or a portal that is down. When base R reports the
HTTP status only in a warning, that warning's text is used as the cause.

The fallback: with `attempt_wayback = NULL` a snapshot is looked up with
[`wayback_snapshot_url()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wayback_snapshot_url.md);
with a URL that URL is used; with `""` or `FALSE` the fallback is off.
The fallback is fetched without `allow_file`, so it must be a public
`https` URL even when `allow_file = TRUE`; a refused fallback URL counts
as a failed fallback (`FALSE`), with a message.

All output goes to the message stream. The transport always draws its
progress (it is called with `quiet = FALSE`). `target_path` is
overwritten on success.

## Examples

``` r
src <- tempfile(fileext = ".csv")
writeLines(c("id,value", "1,10"), src)

# a successful download returns TRUE
friendly_download(paste0("file://", src), tempfile(fileext = ".csv"),
  attempt_wayback = "", allow_file = TRUE)
#> [1] TRUE

# a failed one returns FALSE with advice, here with the fallback off
friendly_download(paste0("file://", src, "-missing"), tempfile(),
  attempt_wayback = "", allow_file = TRUE)
#>   ! Download failed.
#>     URL:   file:///tmp/RtmpU9DUjt/file1db51f3a8507.csv-missing
#>     Error: cannot open file '/tmp/RtmpU9DUjt/file1db51f3a8507.csv-missing': No such file or directory
#> 
#>   Common causes (in rough order of likelihood):
#>     * The server did not serve the file (see the error above): the URL may have moved or the
#>       portal may be down.
#>   The Wayback fallback is switched off; nothing more to try.
#> [1] FALSE

# a refused URL is an error, not FALSE
try(friendly_download("http://example.org/data.csv", tempfile()))
#> Error : url must be an https:// URL, not http:// ('http://example.org/data.csv'); options(rmoriebricklayer.allow_http = TRUE) admits a trusted plain-http mirror
if (FALSE) { # \dontrun{
# needs the network; the Wayback fallback is looked up on failure
ok <- friendly_download("https://cloud.r-project.org/",
  tempfile(fileext = ".html"))
ok
} # }
```
