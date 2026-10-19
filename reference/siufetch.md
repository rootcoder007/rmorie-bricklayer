# Fetch an Ontario SIU director's report by drid

Downloads the web page of one director's report of the Ontario Special
Investigations Unit (SIU), the agency that investigates police
interactions that end in death, serious injury or sexual-assault
allegations, and saves its HTML to `dest`. Reports are identified by
their `drid` number. If the live site does not answer, a copy from the
Wayback Machine is used. This is the fetch step of the open SIU corpus
pipeline: pair it with the SIU parser in this package
([`siufprs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufprs.md)
fetches and parses in one call; the compiled core under `src/siu_*.cpp`
is the canonical implementation, and rmorie links to the same core) to
rebuild the director's-report corpus yourself.

## Usage

``` r
siufetch(drid, dest, lang = c("en", "fr"), wb = "", tmout = 120L)
```

## Arguments

- drid:

  Director's-report id: the `drid=` query parameter, one positive whole
  number (integer or integer-like, such as `648` or `"648"`).

- dest:

  Character string: the file to write the fetched HTML to.

- lang:

  `"en"` (default) or `"fr"`: the language of the report page.

- wb:

  Optional explicit Wayback snapshot URL (passed through to `blfetch`);
  `""` (the default) lets it discover one.

- tmout:

  Request timeout in seconds. Default 120.

## Value

`"live"` or `"wayback"` (invisibly), as `blfetch`: which source the HTML
came from.

## Details

The URL fetched is
`https://www.siu.on.ca/<lang>/directors_report_details.php?drid=<drid>`,
through
[`blfetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md),
which tries the live page first and falls back to a Wayback Machine
snapshot (the one given in `wb`, or one it looks up).

Network: one or more HTTPS requests to www.siu.on.ca and, on failure,
web.archive.org. Side effect: writes `dest`.

Errors, before any request: `drid` not one positive whole number (`1.5`
is refused rather than read as report 1); `lang` not `"en"` or `"fr"`;
`dest` not a single non-empty string. Then any error from
[`blfetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md),
for example when neither the live page nor an archived copy can be
reached.

## See also

[`blfetch`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blfetch.md),
[`siufprs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufprs.md)

## Examples

``` r
# the report number is checked before anything is sent
try(siufetch(1.5, tempfile(fileext = ".html")))
#> Error : `drid` must be one positive report number (the drid in the SIU report URL)
try(siufetch(648, tempfile(fileext = ".html"), lang = "de"))
#> Error : `lang` must be one of "en", "fr", not "de"

# a real fetch needs the network (the SIU site or the Wayback Machine)
if (FALSE) { # \dontrun{
dest <- tempfile(fileext = ".html")
siufetch(648, dest)
siufetch(648, tempfile(fileext = ".html"), lang = "fr")
} # }
```
