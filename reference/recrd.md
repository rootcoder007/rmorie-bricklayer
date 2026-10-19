# Record a Cross-Check Result in a Manifest

Appends one named cross-check to a manifest: a number your analysis
produced (`obs`) next to the number it should reproduce (`expd`, for
example a published table value). Each entry is classified `PASS`,
`DIFFER` or `INFO`, a one-line report is shown as a message, and the
updated manifest is returned so calls can be chained. The tallies appear
in
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md)
and the entries in
[`wrmnfjs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrmnfjs.md).

## Usage

``` r
recrd(man, name, obs, expd, tol = 1e-04, grp = "general", syn = FALSE)
```

## Arguments

- man:

  A manifest as returned by
  [`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md).

- name:

  Character scalar, the name of this cross-check. It is the key of the
  entry in `manifest$results`, so it should be unique.

- obs:

  The value the analysis produced: a numeric scalar for a tolerance
  check, or any single value to be stored as information.

- expd:

  The value to compare against, of the same kind.

- tol:

  Numeric scalar, the absolute tolerance: a numeric pair at most `tol`
  apart is `PASS`. Default `0.0001`.

- grp:

  Character scalar, a grouping label stored with the entry (for example
  the table the number comes from). Default `"general"`.

- syn:

  Logical scalar; `TRUE` marks this entry `INFO` because a comparison on
  synthetic data is not meaningful. Default `FALSE`.

## Value

The manifest with `results[[name]]` set to a list with `group`,
`observed`, `expected`, `diff` (the absolute difference, `NA` when the
pair is not numeric), `status` (`"PASS"`, `"DIFFER"` or `"INFO"`), `tol`
and `note` (a sentence for synthetic entries, else `NULL`).

## Details

The status is decided in this order: `INFO` when `synthetic = TRUE` or
the manifest's `meta$synthetic` is `TRUE` (a comparison on generated
data is not meaningful); `PASS` when both values are numeric and
\\\|observed - expected\| \le tol\\; `DIFFER` when both are numeric and
further apart; `INFO` otherwise (for example a text or logical value, or
an `NA`). The tolerance is absolute, not relative: scale it to the size
of the quantity.

`obs` and `expd` must be single values: a vector of another length
(including an empty one) is an error naming the argument; record a
vector's elements under separate names, or a summary of it. Recording
under an existing `name` replaces that entry. The message line is a side
effect; wrap the call in
[`suppressMessages()`](https://rdrr.io/r/base/message.html) to silence
it.

## See also

[`mkmnf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mkmnf.md),
[`wrsmrytxt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/wrsmrytxt.md).

## Examples

``` r
man <- mkmnf(list(project = "demo"), env = FALSE)

# Within tolerance -> PASS. (Every status below is INFO instead in a
# session that has already generated synthetic data, because mkmnf()
# then marks the manifest synthetic; see mkmnf().)
man <- recrd(man, "meanmatches",
  obs = 1.0001, expd = 1,
  tol = 0.001
)
#>   meanmatches                                  observed = 1.0001       expected = 1.0000       [INFO]
man$results$meanmatches$status # "PASS"
#> [1] "INFO"

# Outside tolerance -> DIFFER.
man <- recrd(man, "sdmatches", obs = 2.5, expd = 2.0, tol = 0.01)
#>   sdmatches                                    observed = 2.5000       expected = 2.0000       [INFO]
man$results$sdmatches$status # "DIFFER"
#> [1] "INFO"

# Synthetic data -> INFO (comparison not meaningful).
man <- recrd(man, "syntheticrow",
  obs = 5, expd = 5,
  syn = TRUE
)
#>   syntheticrow                                 observed = 5.0000       expected = 5.0000       [INFO]
man$results$syntheticrow$status # "INFO"
#> [1] "INFO"

# a non-numeric value is stored as information, silently
man <- suppressMessages(recrd(man, "country", obs = "CA", expd = "CA",
                               grp = "metadata"))
man$results$country$status # "INFO"
#> [1] "INFO"

# Calls chain: record() returns the mutated manifest.
length(man$results) # 4
#> [1] 4
```
