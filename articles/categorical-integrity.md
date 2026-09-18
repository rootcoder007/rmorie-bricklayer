# Categorical integrity: labels that cannot be swapped quietly

In August 2020 the Ontario Human Rights Commission published *A
Disparate Impact*, whose multivariate tables said Black civilians in
Toronto were 30 to 58 times as likely as White civilians to experience
police use of force, and other racialized civilians 5 to 14 times. On 26
January 2023 the Commission published a correction: the figures are 4 to
5 times for Black civilians, and other racialized civilians were about
40% *less* likely. Between the SPSS file and the R analysis the four
race codes had been rotated one place (White read as Black, Black as
other racialized, other racialized as unknown, unknown as White), so the
largest group was being compared with the smallest. The independent
review attributed the rotation to the transfer between the two packages.
Nothing in either package rotates labels on its own; what was missing
was a step that would have refused the rotation, or named it, on the
day. This vignette is that step. Sources: OHRC, *Correction to A
Disparate Impact* (2023-01-26); Jung, M. (2022), *Independent Expert
Review of Part E of the Use of Force by the Toronto Police Service
report*, submitted to the OHRC, December 2022.

## The report’s numbers against the table’s labels

Start with what a reader can check: a table of counts as labelled (the
counts below are illustrative, shaped like the case: a large White
group, a Black group with a real disparity, and a very small unknown
group), the reference group, and the odds ratios a report states.

``` r

tab <- matrix(c(9000, 120, 2000, 220, 1500, 60, 4000, 1), ncol = 2, byrow = TRUE,
              dimnames = list(c("White", "Black", "Other", "Unknown"), c("no", "yes")))
tab
#>           no yes
#> White   9000 120
#> Black   2000 220
#> Other   1500  60
#> Unknown 4000   1
ref <- 120 / 9000
odds_ratio_check(tab, "White", c(Black = 220 / 2000 / ref, Other = 60 / 1500 / ref,
                                 Unknown = 1 / 4000 / ref))$verdict
#> [1] "the reported odds ratios follow from the table as labelled"
```

Now rotate the labels one place, as happened in the transfer, and read
off the odds ratios a report would print:

``` r

rotated <- tab[c("Unknown", "White", "Black", "Other"), ]
rownames(rotated) <- rownames(tab)
rref <- rotated["White", 2] / rotated["White", 1]
reported <- c(Black = rotated["Black", 2] / rotated["Black", 1] / rref,
              Other = rotated["Other", 2] / rotated["Other", 1] / rref,
              Unknown = rotated["Unknown", 2] / rotated["Unknown", 1] / rref)
round(reported, 1)
#>   Black   Other Unknown 
#>    53.3   440.0   160.0
r <- odds_ratio_check(tab, "White", reported)
r$consistent
#> [1] FALSE
r$matches
#>                                                          relabelling
#> 1 White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#>   outcome_columns_swapped
#> 1                   FALSE
r$verdict
#> [1] "the reported odds ratios do NOT follow from the table as labelled; they are reproduced under a relabelling (White -> Black, Black -> Other, Other -> Unknown, Unknown -> White): the groups were mislabelled, not the software"
```

The function tries every relabelling of the rows (and the two outcome
columns) and names the one that reproduces the reported figures: here
the one-place rotation, with the “White” odds actually those of the tiny
unknown group, which is exactly how a real disparity of about 4 becomes
a reported one of about 50. Numbers that no relabelling produces are
reported as exactly that.

``` r

odds_ratio_check(tab, "White", c(Black = 36, Other = 4, Unknown = 1))$verdict
#> [1] "the reported odds ratios follow from no relabelling of this table"
```

## Codes that arrive without their labels

Data exported from SPSS, Stata or SAS often lands as integer codes.
[`decode_codes()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/decode_codes.md)
needs the code-to-label dictionary written out and refuses a code it
does not know;
[`audit_categories()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/audit_categories.md)
flags the columns that still look like codes.

``` r

raw <- data.frame(race = c(1, 2, 2, 3, 1), stringsAsFactors = FALSE)
audit_categories(data.frame(race = factor(raw$race)))
#> Categorical audit: 1 column(s)
#>   race             factor     3 level(s), reference ‘1’
#>     !! HAZARD: all labels numeric-looking (1,2,3...): likely imported CODES whose value labels were lost; as.numeric() on this column returns level INDICES, not data
race <- decode_codes(raw$race, c("1" = "White", "2" = "Black", "3" = "Indigenous"))
race
#> [1] "White"      "Black"      "Black"      "Indigenous" "White"     
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>            1            2            3 
#>      "White"      "Black" "Indigenous" 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] "be0b0dcd1bb12223f6d28bc031e1accfd45a3f700d18c920b54d7d766905bdd0"
```

## A recode you can prove

[`guard_recode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_recode.md)
maps by name only and errors on anything unmapped;
[`verify_recode()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/verify_recode.md)
cross-tabulates before against after and errors unless each old label
went to exactly one new label, the one the mapping declares;
[`guard_levels()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/guard_levels.md)
fixes the level order so the reference group is a decision, not an
accident of the alphabet.

``` r

x <- c("W", "B", "W", "I", "B")
y <- guard_recode(x, c(W = "White", B = "Black", I = "Indigenous"))
verify_recode(x, y, c(W = "White", B = "Black", I = "Indigenous"))
guard_levels(y, c("White", "Black", "Indigenous"), reference = "White")
#> [1] White      Black      White      Indigenous Black     
#> Levels: White Black Indigenous
```

And the swap, caught on the day:

``` r

verify_recode(c("W", "B"), c("Black", "White"), c(W = "White", B = "Black"))
#> Error:
#> ! verify_recode: ‘B’ was mapped to ‘White’ but the declared mapping says ‘Black’. THIS is how groups get swapped; fix the recode before any model runs.
```

## Counts against what was published

If the release states how many rows each label has, the recode must
reproduce those counts. When it does not, the function tries every
permutation of the labels and says which one would make the counts
match: the fingerprint of labels attached to the wrong groups.

``` r

verify_marginals(y, c(White = 2, Black = 2, Indigenous = 1))
verify_marginals(y, c(White = 2, Black = 1, Indigenous = 2))
#> Error:
#> ! verify_marginals: recoded counts do not match the published counts. White: observed 2, published 2; Black: observed 2, published 1; Indigenous: observed 1, published 2. The observed counts match the published ones if the labels are permuted (Black -> Indigenous, Indigenous -> Black): the labels are attached to the wrong groups.
```

## The record

[`recode_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/recode_manifest.md)
writes down the mapping and its digest, the counts before and after, the
checks that passed, and, with a key, a signature over the record. A
later reader verifies the file against the data.

``` r

key <- pqc_keygen(height = 2)
m <- recode_manifest(x, y, c(W = "White", B = "Black", I = "Indigenous"),
                     published = c(White = 2, Black = 2, Indigenous = 1),
                     key = key, context = "vignette")
p <- write_recode_manifest(m, tempfile(fileext = ".json"))
verify_recode_manifest(p, x, y)[c("ok", "signature_ok")]
#> $ok
#> [1] TRUE
#> 
#> $signature_ok
#> [1] TRUE
```

Change the data or the file afterwards and verification says so, with
the reason.

``` r

y_swapped <- as.character(y)
y_swapped[y_swapped == "Black"] <- "Indigenous"
verify_recode_manifest(p, x, y_swapped)[c("ok", "reasons")]
#> $ok
#> [1] FALSE
#> 
#> $reasons
#> [1] "verify_recode: ‘B’ was mapped to ‘Indigenous’ but the declared mapping says ‘Black’. THIS is how groups get swapped; fix the recode before any model runs."
#> [2] "recoded counts differ from the manifest"
```

Finally, the guard that stops a factor from reaching a numeric treatment
slot, where [`as.numeric()`](https://rdrr.io/r/base/numeric.html) would
hand a model the level indices instead of the data:

``` r

guard_binary(c("treated", "control"), "treatment")
#> Error:
#> ! Column ‘treatment’ is categorical (‘treated’, ‘control’...). Refusing to coerce: as.numeric() on a factor returns level INDICES (1, 2, ...), not your data, and a mis-ordered level silently relabels every observation. Encode explicitly first, e.g. guard_recode() + as.integer(x == "treated_label").
```

## The transfer that matters: SPSS (or Stata, SAS) to R

The documented failure happened between two programs. The source stores
each category as a code with a value label; the destination receives the
codes, and the labels are re-attached in the analysis. The only faithful
way to re-attach them is by code. Here is what arrives from a `.sav`
file (haven keeps the labels as an attribute, label = code), and the two
things the source program printed that make the import checkable: its
code book and its frequency table.

``` r

arrived <- structure(c(1, 1, 2, 4, 1, 3, 1, 2),
                     labels = c(White = 1, Black = 2, Other = 3, Unknown = 4))
code_book <- c("1" = "White", "2" = "Black", "3" = "Other", "4" = "Unknown")
spss_frequencies <- c(White = 4, Black = 2, Other = 1, Unknown = 1)
chk <- transfer_verify(arrived, spss_frequencies, code_book = code_book)
chk$ok
#> [1] TRUE
levels(chk$decoded)
#> [1] "White"   "Black"   "Other"   "Unknown"
```

The levels are in code order, not alphabetical order, because the code
book says so. Now the idiom that produced the documented rotation: the
labels, in the order R sorts them, assigned to the codes by position.

``` r

f <- factor(c(1, 2, 3, 4, 1))
levels(f) <- sort(unname(code_book))
data.frame(code = c(1, 2, 3, 4, 1), became = as.character(f))
#>   code  became
#> 1    1   Black
#> 2    2   Other
#> 3    3 Unknown
#> 4    4   White
#> 5    1   Black
```

Code 1 (White) became “Black”, 2 (Black) became “Other”, 3 (Other)
became “Unknown”, 4 (Unknown) became “White”: the four-way rotation in
the correction notice, from one line.
[`relabel()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel.md)
refuses that line:

``` r

relabel(factor(c(1, 2, 3, 4, 1)), sort(unname(code_book)))
#> Error:
#> ! relabel: `mapping` must be NAMED (old label = new label). Assigning labels by POSITION is how four race codes were rotated in a published analysis (OHRC correction, 26 January 2023): the labels were in alphabetical order, the codes were not.
relabel(factor(c(1, 2, 3, 4, 1)), code_book)
#> [1] White   Black   Other   Unknown White  
#> attr(,"recode_audit")
#> attr(,"recode_audit")$mapping
#>       1       2       3       4 
#>   White   Black   Other Unknown 
#> 
#> attr(,"recode_audit")$kept
#> character(0)
#> 
#> attr(,"recode_audit")$checksum
#> [1] 3d394c3d6f779a313f8fbeecaf5bc4f104738096c07f03c48ab68d5eb52e8de4
#> 
#> Levels: White Black Other Unknown
```

And
[`transfer_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/transfer_verify.md)
refuses the result if it somehow got past that, because the frequency
table no longer matches by label:

``` r

transfer_verify(as.character(f), c(White = 2, Black = 1, Other = 1, Unknown = 1))
#> Error:
#> ! verify_marginals: recoded counts do not match the published counts. White: observed 1, published 2; Black: observed 2, published 1; Other: observed 1, published 1; Unknown: observed 1, published 1. The observed counts match the published ones if the labels are permuted (White -> Black, Black -> White): the labels are attached to the wrong groups.
```

## Exonerating the software, or not

When a permutation is blamed on the transfer, the question to ask is
which deterministic step, applied to the code book, yields exactly the
permutation observed.
[`relabel_forensics()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/relabel_forensics.md)
tries the known ones.

``` r

observed <- c(White = "Black", Black = "Other", Other = "Unknown", Unknown = "White")
relabel_forensics(code_book, observed)
#> Mechanism(s) reproducing the observed permutation:
#>   * labels sorted alphabetically, assigned by code position
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#>   * labels sorted case-insensitively, assigned by code position
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#>   * rotation by 1 position(s)
#>       White -> Black, Black -> Other, Other -> Unknown, Unknown -> White
#> 
#> The observed permutation is reproduced EXACTLY by: labels sorted alphabetically, assigned by code position; labels sorted case-insensitively, assigned by code position; rotation by 1 position(s). No import routine (haven, foreign, pandas, pyreadstat) reorders value labels; each carries them keyed by code. A transfer fault does not select the sort order of the labels. The step that did this was a positional relabel in the analysis, and it is reproducible from the code book alone.
```

No import routine in R or Python (haven, foreign, pandas, pyreadstat)
sorts value labels onto codes; each keeps them keyed by code. A
permutation that coincides with the alphabetical order of the labels was
made by a positional relabel in the analysis, and anyone with the code
book can reproduce it. A permutation that no mechanism reproduces points
at a merge, a manual edit, or the file, and the function says so instead
of guessing.
