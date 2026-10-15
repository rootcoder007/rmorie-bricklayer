# Assess a capsule in one call

Runs the checks this package provides over one data frame and collects
the findings into a single report: the structural schema check, the
distributional comparison against a reference, the missingness picture,
the multivariate outliers, a Benford screen on the wide numeric columns,
and the integrity digests. Use it as the first look at a capsule or a
fresh extract, before any analysis, and keep the Markdown version
([`report_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_markdown.md))
with the outputs.

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

  Numeric scalar, the significance level passed to
  [`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md);
  default `0.01`.

- max_rows_outliers:

  Integer scalar: skip the outlier scan above this many rows (default
  20000), since it factors a covariance per call.

## Value

A list of class `c("bricklayer_report", "list")`: `findings` (a data
frame of character columns `severity`, `check` (`"schema"`, `"rule"`,
`"drift"`, `"missing"`, `"shape"`, `"outliers"`, `"benford"` or
`"signature"`), `subject` (the column, rule or row count concerned) and
`detail`), `verdict` (the worst severity: `"fatal"`, `"warn"`, `"note"`,
or `"clean"` when there is no finding), `profile` (from
[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)),
`missingness` (from
[`missingness_summary()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_summary.md)),
`drift` (the
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
result, or `NULL` without a reference), `digest` (a list with
`data_digest`, and with `chunks` also `merkle_root`, `merkle_scheme`
(the
[`merkle_root()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rmbl_merkle.md)
hashing scheme, 2) and `n_chunks`, with a signature and key also logical
`signature_valid`), and `n_rows` / `n_cols`.
[`print()`](https://rdrr.io/r/base/print.html) shows the verdict and the
findings; [`summary()`](https://rdrr.io/r/base/summary.html) gives the
verdict and the count of each severity.

## Details

Nothing here is new arithmetic. The value is that the answers arrive
together and ordered by severity, because the failure mode this is built
against is a person running one check, seeing it pass, and concluding
the data is fine.

## What "severity" means

- `fatal` – nothing downstream can run as it stands: a schema check or a
  rule of severity `"fatal"` failed (for example a required column is
  missing), or a column of the reference is absent from the data.

- `warn` – something moved or is badly incomplete: a schema check or a
  rule of severity `"warning"` failed (a value left its pinned range, a
  type changed), a column drifted from the reference, a column is
  entirely missing or more than half missing, or a signature did not
  verify (or came with no key).

- `note` – worth a look but not necessarily wrong: a column not in the
  reference, a column whose drift could not be tested, a contiguous run
  of missing values (one outage rather than scattered gaps), a constant
  column, values beyond the Tukey fences, multivariate outliers or
  collinear columns, a Benford departure.

## How each check runs

The drift comparison is
[`capsule_drift()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_drift.md)
at level `alpha`. The missing run is the longest run from
[`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)
of at least `max(2, nrow(data) %/% 20)` rows. The outlier scan is
[`mahalanobis_outliers()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahalanobis_outliers.md)
on the numeric columns that are not constant or entirely missing, run
only when there are at least two of them, at most `max_rows_outliers`
rows and more complete rows than columns. The Benford screen
([`benford_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benford_test.md))
runs on a numeric column with at least 200 non-zero finite values whose
largest absolute value is more than 1,000 times its smallest, and
reports p below 0.01. The digest is
[`digest_object()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/digest_object.md)
of the data; a signature is checked with
[`capsule_verify()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_verify.md)
against that digest.

Findings are sorted by severity, then check, then subject. Nothing is
written and nothing is fetched. Errors when `data` is not a data frame
or has no columns, and when `schema` or `rules` are malformed (from
[`validate_schema()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_schema.md)
and
[`validate_rules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/validate_rules.md)).

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

# validation rules join the findings, and chunks are pinned with a Merkle root
r2 <- capsule_report(bad, rules = list(rule_in_set("grade", c("a", "b", "c"))),
                     chunks = c("part one", "part two"))
summary(r2)
#> verdict   fatal    warn    note 
#>  "warn"     "0"     "1"     "0" 
r2$digest$merkle_root
#> [1] "271d0c66b493e55e2b9659fda7eddb00b0439d076eb82f36a4b8922d6bd4d062"

# a data frame is required
try(capsule_report(1:10))
#> Error : `data` must be a data frame
```
