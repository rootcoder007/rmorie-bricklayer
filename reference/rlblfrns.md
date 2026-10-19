# Name the mechanical step that reproduces a label permutation

When categories come out permuted (each true group reported under
another group's label), this function asks which deterministic step,
applied to the code book, produces exactly that permutation. It tries
the known mechanisms: labels sorted alphabetically (also reversed or
case-insensitive) and assigned by code position, labels reversed, every
rotation, codes sorted as strings, and, when counts are given, labels
ordered by frequency. A match is a reconstruction, not proof of intent;
but a file transfer has no reason to pick the sort order of the labels,
so a match on a sort-based mechanism points to a positional relabel in
the analysis rather than to the software.

## Usage

``` r
rlblfrns(vlabs, obs, cnts = NULL)
```

## Arguments

- vlabs:

  Named character vector, code = true label, in code order (the source
  program's code book).

- obs:

  Named character vector, true label = label it was seen under, covering
  every label once.

- cnts:

  Optional named numeric vector of frequencies per true label, default
  `NULL`. Enables the two frequency-order mechanisms.

## Value

A data frame of class `c("bricklayer_relabel_forensics", "data.frame")`
with one row per mechanism tried and columns `mechanism` (character),
`permutation` (character, `"A -> B, ..."`) and `matches` (logical). The
`verdict` attribute is a character summary. The print method shows only
the matching mechanisms and the verdict.

## Details

With labels \\L_1, \dots, L_k\\ in code order, each mechanism produces a
sequence \\M_1, \dots, M_k\\ meaning "true group \\L_i\\ was seen as
\\M_i\\". It matches when \\M_i =\\ `observed[L_i]` for all \\i\\. There
are five fixed mechanisms, \\k - 1\\ rotations, and two frequency orders
with `cnts`. When `obs` is the identity no mechanism is reported as
matching.

Errors: either argument unnamed; `obs` not a permutation of the labels
in `vlabs`.

## See also

[`vrfmrg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfmrg.md),
[`relbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relbl.md).

## Examples

``` r
# the OHRC 2023 case: alphabetical labels assigned to codes 1-4
vl <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
obs <- c(White = "Black", Black = "Other", Other = "Unknown",
         Unknown = "White")
rlblfrns(vl, obs)
#> Mechanism(s) reproducing the observed permutation:
#>   * labels sorted alphabetically, assigned by code position
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#>   * labels sorted case-insensitively, assigned by code position
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#>   * rotation by 1 position(s)
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#> 
#> The observed permutation is reproduced EXACTLY by: labels sorted alphabetically, assigned by code position; labels sorted case-insensitively, assigned by code position; rotation by 1 position(s). No import routine (haven, foreign, pandas, pyreadstat) reorders value labels; each carries them keyed by code. A transfer fault does not select the sort order of the labels. The step that did this was a positional relabel in the analysis, and it is reproducible from the code book alone.

# a frequency-ordered relabel needs the counts
obs2 <- c(White = "White", Black = "Other", Other = "Black",
          Unknown = "Unknown")
rf <- rlblfrns(vl, obs2, cnts = c(White = 50, Black = 10,
                                             Other = 30, Unknown = 5))
rf$mechanism[rf$matches]
#> [1] "labels ordered by decreasing frequency, assigned by code position"

# observed must be a permutation of the labels
try(rlblfrns(vl, c(White = "Black")))
#> Error : rlblfrns: `obs` must be a permutation of the labels in `vlabs`
```
