# Name the mechanical step that reproduces a label permutation

When categories came out permuted and the transfer between two programs
is being blamed, the question is which deterministic step, applied to
the code book, yields exactly the observed permutation. This function
tries the known ones: labels sorted alphabetically (or reversed, or
case-insensitively) and assigned by code position, labels reversed,
every rotation, codes sorted as strings, and labels ordered by frequency
when counts are supplied. A match is a reconstruction, not a proof of
intent; but a transfer fault has no reason to select the sort order of
the labels, so a match on a sort-based mechanism exonerates the
software.

## Usage

``` r
relabel_forensics(value_labels, observed, counts = NULL)
```

## Arguments

- value_labels:

  Named character vector, code = true label, in code order.

- observed:

  Named character vector, true label = label it was seen under.

- counts:

  Optional named numeric vector of frequencies per true label, enabling
  the frequency-order mechanism.

## Value

A data frame with one row per mechanism (`mechanism`, `permutation`,
`matches`) and a `verdict` attribute.

## Examples

``` r
vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
obs <- c(White = "Black", Black = "Other", Other = "Unknown",
         Unknown = "White")
attr(relabel_forensics(vl, obs), "verdict")
#> [1] "The observed permutation is reproduced EXACTLY by: labels sorted alphabetically, assigned by code position; labels sorted case-insensitively, assigned by code position; rotation by 1 position(s). No import routine (haven, foreign, pandas, pyreadstat) reorders value labels; each carries them keyed by code. A transfer fault does not select the sort order of the labels. The step that did this was a positional relabel in the analysis, and it is reproducible from the code book alone."
```
