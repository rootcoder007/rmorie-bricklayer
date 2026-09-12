# Assess a capsule in one call

Runs the checks this package provides over one data frame and collects
the findings into a single report: the structural schema check, the
distributional comparison against a reference, the missingness picture,
the multivariate outliers, a Benford screen on the wide numeric columns,
and the integrity digests.

## Usage

``` r
capsule_report(
  data,
  reference = NULL,
  schema = NULL,
  rules = NULL,
  chunks = NULL,
  signature = NULL,
  key = NULL,
  alpha = 0.01,
  max_rows_outliers = 20000L
)
```

## Arguments

- data:

  The data frame to assess.

- reference:

  Optional data frame the capsule was pinned against. Supplying it
  enables the drift comparison, which is the check a digest cannot make.

- schema:

  Optional schema from
  [`infer_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infer_schema.md),
  or a provenance list containing one. Supplying it enables the
  structural check.

- rules:

  Optional list of
  [`rule()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rule.md)
  objects.

- chunks:

  Optional character vector of capsule chunks (see
  [`chunk_file()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chunk_file.md))
  to pin with a Merkle root.

- signature, key:

  Optional signature and verifying key, as from
  [`capsule_sign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_sign.md),
  checked against the data's own digest.

- alpha:

  Significance level passed to
  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md).

- max_rows_outliers:

  Skip the outlier scan above this many rows (default 20000), since it
  factors a covariance per call.

## Value

A list of class `bricklayer_report`: `findings` (a data frame of
`severity`, `check`, `subject`, `detail`), `verdict` (`"fatal"`,
`"warn"`, `"note"` or `"clean"`), `profile`, `missingness`, `drift`,
`digest`, and `n_rows`/`n_cols`.

## Details

Nothing here is new arithmetic. The value is that the answers arrive
together and ordered by severity, because the failure mode this is built
against is a person running one check, seeing it pass, and concluding
the data is fine.

## What "severity" means

- `fatal` – a required column is missing. Nothing downstream can run.

- `warn` – something moved: a column drifted, a value left its pinned
  range, missingness rose, a signature did not verify.

- `note` – worth a look but not necessarily wrong: outliers, a Benford
  departure, a constant column.

A clean report is not proof the data is correct. It means these
particular checks found nothing, and every one of them has a stated
blind spot – see
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
on statistical power and
[`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md)
on why a departure is a screen rather than a verdict.

## See also

[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md),
[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md),
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md),
[`report_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_markdown.md)
to write it out.

## Examples

``` r
set.seed(1)
ref <- data.frame(
  id = 1:200,
  score = stats::runif(200, 0, 10),
  grade = sample(c("a", "b", "c"), 200, TRUE),
  stringsAsFactors = FALSE
)

# A fresh extract from the same process: nothing to report.
cur <- ref
cur$score <- stats::runif(200, 0, 10)
capsule_report(cur, reference = ref, schema = infer_schema(ref))
#> ── Capsule report ────────────────────────────────────────────────
#>   ✓ these checks found nothing
#> 
#>   rows           200
#>   columns        3
#>   missing cells  0.0%
#>   complete rows  100.0%
#>   digest         5d70a73bdcbc84111491db56743c94fd
#> 
#>   No finding is proof of correctness: each check has a
#>   stated blind spot, and a small sample has little power.
#> ──────────────────────────────────────────────────────────────────

# One rescaled column and a new category: both surface, worst first.
bad <- cur
bad$score <- bad$score * 5
bad$grade[1:80] <- "z"
r <- capsule_report(bad, reference = ref, schema = infer_schema(ref))
r
#> ── Capsule report ────────────────────────────────────────────────
#>   ✗ WARNINGS: something moved
#> 
#>   rows           200
#>   columns        3
#>   missing cells  0.0%
#>   complete rows  100.0%
#>   digest         7889e99fa5a2e10e04c767d3958f3c84
#> 
#> ── Findings (4) ──────────────────────────────────────────────────
#>   ✗ warn      drift      grade                  categorical test, p = <2e-16
#>   ✗ warn      drift      score                  numeric test, p = <2e-16
#>   ✗ warn      schema     range_score            Column 'score' has 161 value(s) outside [-0.8488307, 10.90645]
#>   ✗ warn      schema     unexpected_grade       Column 'grade' has unexpected values: z
#> ──────────────────────────────────────────────────────────────────
r$verdict
#> [1] "warn"
r$findings[, c("severity", "check", "subject")]
#>   severity  check          subject
#> 1     warn  drift            grade
#> 2     warn  drift            score
#> 3     warn schema      range_score
#> 4     warn schema unexpected_grade

# A missing column is fatal, because nothing downstream can run.
capsule_report(bad[, c("id", "score")], reference = ref,
               schema = infer_schema(ref))$verdict
#> [1] "fatal"
```
