# Parse an SIU director's report into the schema fields

Extracts every
[`siusch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siusch.md)
field from the HTML of an Ontario SIU director's report: the police
service, the incident, notification and decision dates, the investigator
and witness counts, the affected person's age and sex, the injuries, the
legislation considered and the director's name. The extraction is
rule-based, deterministic and offline, so the same report always gives
the same answer; use it to turn a folder of saved reports into a data
set.

## Usage

``` r
siuprs(html)
```

## Arguments

- html:

  A character vector. Each element is either the raw HTML of one report
  or the path to a saved report file (for example one written by
  [`siufetch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siufetch.md)).
  With more than one element, each is parsed and the results are bound
  into a data frame.

## Value

For one input, a named character vector of 17 elements: the 16 schema
fields plus `_language` (`"en"`, `"fr"` or `"unknown"`), in alphabetical
order of name. Every value is a string, counts included (`"2"`); convert
with [`as.integer()`](https://rdrr.io/r/base/integer.html) as needed.
For several inputs, a data.frame with one row per input and one
character column per field (`NA` where a field is absent from a row).

## Details

The text is first converted as in
[`siutxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siutxt.md),
then the report language is detected from section headings (English or
French; the SIU publishes both) and each field is read by its own rule
set in the native core. Dates are converted with the same rules as
[`siudate()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siudate.md).
The subject-official count uses the rules of
[`siuso()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/siuso.md).
Fields the report does not state come back as `""`; a page that is not a
report gives all fields `""` and `_language` `"unknown"`.

A single string with no `<` that is shorter than 1000 bytes and names an
existing file is read as a path. A string that looks like a path (ends
in `.htm`/`.html` or contains a slash) but names no file is an error,
not an empty report.

Errors: `html` not character, empty or `NA`; a missing file (“no such
file”); input over 2 MiB.

## Limits

The input is capped at 2 MiB (a report page is a few hundred KB). Before
the text is read, a line longer than 2000 characters is split at the
sentence end nearest the cap (else at a space), and a warning says how
many lines were split: a field that spans a split may be incomplete.

## Examples

``` r
f <- siuprs(system.file(
  "extdata",
  "siu_synthetic_report.html",
  package = "rmoriebricklayer"
))
f[["number_of_subject_officials"]]
#> [1] "2"
f[c(
  "police_service",
  "date_of_incident_iso",
  "date_of_director_decision_iso"
)]
#>                police_service          date_of_incident_iso 
#>       "Barrie Police Service"                  "2023-01-05" 
#> date_of_director_decision_iso 
#>                  "2023-04-28" 

# several reports at once give a data frame, one row each
path <- system.file(
  "extdata",
  "siu_synthetic_report.html",
  package = "rmoriebricklayer"
)
html <- paste(readLines(path), collapse = "\n")
df <- siuprs(c(html, "<p>not a report</p>"))
df[, c("_language", "police_service", "number_of_witness_officials")]
#>   _language        police_service number_of_witness_officials
#> 1        en Barrie Police Service                           3
#> 2   unknown                                                  

# a mistyped path is an error, not an empty report
try(siuprs("no-such-report.html"))
#> Error : `html`: no such file: no-such-report.html
```
