# Convert SIU report HTML to plain text

Convert SIU report HTML to plain text

## Usage

``` r
bricklayer_siu_text(html)
```

## Arguments

- html:

  A length-1 character vector of raw report HTML.

## Value

A length-1 character vector of plain text.

## Limits

The input is capped at 2 MiB (a report page is a few hundred KB). Before
the text is read, a line longer than 2000 characters is split at the
sentence end nearest the cap (else at a space), and a warning says how
many lines were split: a field that spans a split may be incomplete.

## Examples

``` r
bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#> [1] " Number of SIU Investigators assigned: 3\n"
```
