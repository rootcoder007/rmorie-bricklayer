# Record a Cross-Check Result in a Manifest

Appends one named cross-check to a manifest: a number your analysis
produced (`observed`) next to the number it should reproduce
(`expected`, for example a published table value). Each entry is
classified `PASS`, `DIFFER` or `INFO`, a one-line report is shown as a
message, and the updated manifest is returned so calls can be chained.
The tallies appear in
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md)
and the entries in
[`write_manifest_json()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_manifest_json.md).

## Usage

``` r
record(
  manifest,
  name,
  observed,
  expected,
  tol = 1e-04,
  group = "general",
  synthetic = FALSE
)
```

## Arguments

- manifest:

  A manifest as returned by
  [`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md).

- name:

  Character scalar, the name of this cross-check; used as the key in
  `manifest$results`, so it should be unique.

- observed:

  The value the analysis produced: a numeric scalar for a tolerance
  check, or any single value to be stored as information.

- expected:

  The value to compare against, of the same kind.

- tol:

  Numeric scalar, the absolute tolerance: a numeric pair at most `tol`
  apart is `PASS`. Default `0.0001`.

- group:

  Character scalar, a grouping label stored with the entry (for example
  the table the number comes from). Default `"general"`.

- synthetic:

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

`observed` and `expected` must be single values: a vector of another
length (including an empty one) is an error naming the argument; record
a vector's elements under separate names, or a summary of it. Recording
under an existing `name` replaces that entry. The message line is a side
effect; wrap the call in
[`suppressMessages()`](https://rdrr.io/r/base/message.html) to silence
it.

## See also

[`make_manifest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/make_manifest.md),
[`write_summary_txt()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/write_summary_txt.md).

## Examples

``` r
man <- make_manifest(list(project = "demo"), environment = FALSE)

# Within tolerance -> PASS.
man <- record(man, "mean_matches",
  observed = 1.0001, expected = 1,
  tol = 0.001
)
#>   mean_matches                                 observed = 1.0001       expected = 1.0000       [INFO]
man$results$mean_matches$status # "PASS"
#> [1] "INFO"

# Outside tolerance -> DIFFER.
man <- record(man, "sd_matches", observed = 2.5, expected = 2.0, tol = 0.01)
#>   sd_matches                                   observed = 2.5000       expected = 2.0000       [INFO]
man$results$sd_matches$status # "DIFFER"
#> [1] "INFO"

# Synthetic data -> INFO (comparison not meaningful).
man <- record(man, "synthetic_row",
  observed = 5, expected = 5,
  synthetic = TRUE
)
#>   synthetic_row                                observed = 5.0000       expected = 5.0000       [INFO]
man$results$synthetic_row$status # "INFO"
#> [1] "INFO"

# a non-numeric value is stored as information, silently
man <- suppressMessages(record(man, "country", observed = "CA", expected = "CA",
                               group = "metadata"))
man$results$country$status # "INFO"
#> [1] "INFO"

# Calls chain: record() returns the mutated manifest.
length(man$results) # 4
#> [1] 4
```
