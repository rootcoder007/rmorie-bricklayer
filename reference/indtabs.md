# The Indigenous health and wellbeing tables the data service holds

Lists the First Nations, Metis and Inuit tables mirrored at the data
service: Statistics Canada's Indigenous-titled tables
(`statcan_indigenous`) and the 2021 Census Indigenous Population Profile
(`census2021_ipp`), with their descriptions, row counts and licences,
searchable.

## Usage

``` r
indtabs(pat = NULL, refresh = FALSE)
```

## Arguments

- pat:

  Optional regular expression matched against the descriptions (case
  ignored).

- refresh:

  Fetch the manifest again (default `FALSE`).

## Value

A data frame: `key`, `rows`, `description`, `license`, `source`.

## Details

Needs a data service key: sign in once with
[`dlogin`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dlogin.md).
Only openly licensed aggregate tables are mirrored. First Nations
Information Governance Centre data (the First Nations Regional Health
Survey and its companions) are governed by the OCAP(R) principles and
are not; ask the Centre (fnigc.ca; the site answers scripts with 403,
archived copy
<https://web.archive.org/web/20261001141317/https://fnigc.ca/>).

## Examples

``` r
if (FALSE) { # \dontrun{
indtabs("mental health")
} # }
```
