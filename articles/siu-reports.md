# Parsing SIU director's reports

Ontario’s Special Investigations Unit publishes a director’s report for
every investigation as an HTML page. The reports share a structure but
not a template: fields appear under varying headings, counts are written
in words or figures, and the text is long. The package parses them into
a fixed, panel-reviewed schema with a parser written for hostile input.

## The schema

``` r

sch <- bricklayer_siu_schema()
head(sch$name, 20)
#>  [1] "police_service"                "date_of_incident_iso"         
#>  [3] "date_siu_notified_iso"         "date_of_director_decision_iso"
#>  [5] "siu_investigators"             "siu_forensics_investigators"  
#>  [7] "number_of_witness_officials"   "number_of_civilian_witnesses" 
#>  [9] "number_of_subject_officials"   "age_affected"                 
#> [11] "sex_gender_affected"           "charges_recommended"          
#> [13] "directors_name"                "location_of_call"             
#> [15] "specific_injuries"             "relevant_legislation"
nrow(sch)
#> [1] 16
```

## Parsing a report

The package ships a synthetic report with the structure of a real one
and no real person in it:

``` r

f <- bricklayer_parse_siu(system.file("extdata", "siu_synthetic_report.html",
                                      package = "rmoriebricklayer"))
f[["number_of_subject_officials"]]
#> [1] "2"
f[["date_of_incident_iso"]]
#> [1] "2023-01-05"
```

## The pieces

HTML to plain text, with the layout tags turned into line structure and
entities decoded:

``` r

bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#> [1] " Number of SIU Investigators assigned: 3\n"
```

The subject-official count, resolved from the enumerated list rather
than a headline number that reports sometimes omit:

``` r

bricklayer_siu_resolve_so("Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")
#> $count
#> [1] 2
#> 
#> $reason
#> [1] "section: max(ordinal 2, entries 2)"
```

Dates in the report’s prose, normalised to ISO:

``` r

bricklayer_siu_iso_date("March 4, 2024")
#> [1] "2024-03-04"
bricklayer_siu_iso_date("not a date")
#> [1] ""
```

## Written for hostile input

A parser that reads 5,000 public web pages will meet broken HTML,
megabyte-long lines, unclosed tags and entities of every shape. Three
review rounds on this parser established and tested the following, each
pinned by a test over the sources:

- **No regex crosses a line without a bound.** Two passes that once
  scanned to the end of the document on `[\s\S]*?` were replaced by
  [`find()`](https://rdrr.io/r/utils/apropos.html) scans after 44 KB of
  period-free boilerplate overflowed the C stack; a hygiene test now
  asserts no unbounded cross-line regex exists in the SIU sources.
- **Every pass is linear.** Two tag-stripping passes were quadratic
  (re-scanning from each unclosed `<script` or bare `<`); at the 2 MiB
  input cap one took 40 minutes. Both are single-pass now.
- **Lines are capped at 2,000 characters** and split at the last
  sentence end inside the window, else the last space; the functions
  warn how many lines were split, because a field spanning a split can
  come back incomplete.
- **Numbers are bounded.** Every string-to-integer conversion goes
  through one helper that reads up to nine digits; `SO #1234567` is
  1234567, and `SO #4444444444444444` is ignored as a tag (the count
  falls back to the other cues), not an overflow.
- **The user can interrupt.** The whole path polls for an interrupt
  through a hook the host installs, and raises it only from a frame that
  owns no live C++ objects.
- **Input is capped at 2 MiB**, and the fuzzers run the parser under an
  8 MB stack like R’s, with seeds for every shape the reviewers used.

## Fetching live reports

[`bricklayer_fetch_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_siu.md)
fetches a report by its identifier through the package’s checked
transport (address validation, redirect policy, resource limits) with an
Internet Archive fallback, and
[`bricklayer_fetch_parse_siu()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bricklayer_fetch_parse_siu.md)
fetches and parses in one call:

``` r

f <- bricklayer_fetch_parse_siu("24-OCI-123")
```

The corpus of parsed reports, reviewed round by round, is distributed as
a dataset by the companion package `rmoriedata`; this package provides
the parser so the corpus can be rebuilt and audited.
