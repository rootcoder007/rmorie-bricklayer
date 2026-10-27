# Convert SIU report HTML to plain text

Strips the markup from one SIU director's report page and returns the
readable text, keeping line breaks so section headings (“Subject
Officials”, “Witness Officials”) stay on lines of their own. Use it
before
[`siuso()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuso.md),
or to read or search a saved report without a browser.

## Usage

``` r
siutxt(html)
```

## Arguments

- html:

  A length-1 character vector holding the raw HTML of one report page. A
  file path is not read here (use
  [`siuprs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuprs.md),
  which accepts a path).

## Value

A length-1 character vector of plain text.

## Details

The conversion runs in the native core: tags are removed, block-level
tags become line breaks, HTML entities are decoded and runs of spaces
are collapsed while newlines are kept. Nothing is fetched and nothing is
written.

Errors: `html` must be a single non-NA character string (“html must be a
single non-NA character string”), and input over 2 MiB is refused (“html
is larger than 2 MiB: not a report page”).

## Limits

The input is capped at 2 MiB (a report page is a few hundred KB). Before
the text is read, a line longer than 2000 characters is split at the
sentence end nearest the cap (else at a space), and a warning says how
many lines were split: a field that spans a split may be incomplete.

## Examples

``` r
siutxt("<p>Number of SIU Investigators assigned: 3</p>")
#> [1] " Number of SIU Investigators assigned: 3\n"

# the bundled synthetic report, as text
f <- system.file(
  "extdata",
  "siu_synthetic_report.html",
  package = "rmoriebricklayer"
)
txt <- siutxt(paste(readLines(f), collapse = "\n"))
cat(substr(txt, 1, 200))
#> 
#> 
#> SIU Director's Report - Case # 23-OFD-001
#> 
#> The Investigation
#> Notification of the SIU
#> On January 6, 2023, the Barrie Police Service contacted the SIU with the
#> following information. It reported that 

# more than one string is refused
try(siutxt(c("<p>a</p>", "<p>b</p>")))
#> Error : `html` must be a single string (the report page)
```
