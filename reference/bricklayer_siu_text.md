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

## Examples

``` r
bricklayer_siu_text("<p>Number of SIU Investigators assigned: 3</p>")
#> [1] " Number of SIU Investigators assigned: 3\n"
```
