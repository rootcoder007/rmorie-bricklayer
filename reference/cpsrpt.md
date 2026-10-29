# Assess a capsule in one call

Runs the checks this package provides over one data frame and collects
the findings into a single report: the structural schema check, the
distributional comparison against a reference, the missingness picture,
the multivariate outliers, a Benford screen on the wide numeric columns,
and the integrity digests. Use it as the first look at a capsule or a
fresh extract, before any analysis, and keep the Markdown version
([`rptmd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptmd.md))
with the outputs.

## Usage

``` r
cpsrpt(
  data,
  ref = NULL,
  schema = NULL,
  rules = NULL,
  chunks = NULL,
  sig = NULL,
  key = NULL,
  alpha = 0.01,
  maxrowsoutl = 20000L
)
```

## Arguments

- data:

  The data frame to assess.

- ref:

  Optional data frame the capsule was pinned against. Supplying it
  enables the drift comparison, which is the check a digest cannot make.

- schema:

  Optional schema from
  [`infsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/infsch.md),
  or a provenance list containing one. Supplying it enables the
  structural check.

- rules:

  Optional list of
  [`rul()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rul.md)
  objects.

- chunks:

  Optional character vector of capsule chunks (see
  [`chnkfile()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/chnkfile.md))
  to pin with a Merkle root.

- sig, key:

  Optional signature and verifying key, as from
  [`cpssign()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpssign.md),
  checked against the data's own digest.

- alpha:

  Numeric scalar, the significance level passed to
  [`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md);
  default `0.01`.

- maxrowsoutl:

  Integer scalar: skip the outlier scan above this many rows (default
  20000), since it factors a covariance per call.

## Value

A list of class `c("bricklayer_report", "list")`: `findings` (a data
frame of character columns `severity`, `check` (`"schema"`, `"rule"`,
`"drift"`, `"missing"`, `"shape"`, `"outliers"`, `"benford"` or
`"signature"`), `subject` (the column, rule or row count concerned) and
`detail`), `verdict` (the worst severity: `"fatal"`, `"warn"`, `"note"`,
or `"clean"` when there is no finding), `profile` (from
[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md)),
`missingness` (from
[`misssmry()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misssmry.md)),
`drift` (the
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
result, or `NULL` without a reference), `digest` (a list with
`data_digest`, and with `chunks` also `merkle_root`, `merkle_scheme`
(the
[`mrkroot()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mrk.md)
hashing scheme, 2) and `n_chunks`, and, with a signature and key, the
logical `signature_valid`), and `nrows` / `n_cols`.
[`print()`](https://rdrr.io/r/base/print.html) shows the verdict and the
findings; [`summary()`](https://rdrr.io/r/base/summary.html) gives the
verdict and the count of each severity.

## Details

Nothing here is new arithmetic. The value is that the answers arrive
together and ordered by severity, because the failure mode this is built
against is a person running one check, seeing it pass, and concluding
the data is fine.

## What `severity` means

- `fatal` – nothing downstream can run as it stands: a schema check or a
  rule of severity `"fatal"` failed (for example a required column is
  missing), or a column of the reference is absent from the data.

- `warn` – something moved or is badly incomplete: a schema check, or a
  rule of severity `"warning"`, failed (a value left its pinned range, a
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
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
at level `alpha`. The missing run is the longest run from
[`missruns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missruns.md)
of at least `max(2, nrow(data) %/% 20)` rows. The outlier scan is
[`mahaoutl()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahaoutl.md)
on the numeric columns that are not constant or entirely missing, run
only when there are at least two of them, at most `maxrowsoutl` rows and
more complete rows than columns. The Benford screen
([`benfordtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benfordtst.md))
runs on a numeric column with at least 200 non-zero finite values whose
largest absolute value is more than 1,000 times its smallest, and
reports p below 0.01. The digest is
[`dgstobj()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dgstobj.md)
of the data; a signature is checked with
[`cpsvrf()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsvrf.md)
against that digest.

Findings are sorted by severity, then check, then subject. Nothing is
written and nothing is fetched. Errors when `data` is not a data frame
or has no columns, and when `schema` or `rules` are malformed (from
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md)
and
[`valrules()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valrules.md)).

A clean report is not proof the data is correct. It means these
particular checks found nothing, and every one of them has a stated
blind spot – see
[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md)
on statistical power and
[`benfordtst()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benfordtst.md)
on why a departure is a screen rather than a verdict.

## See also

[`cpsdrft()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md),
[`profcols()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profcols.md),
[`valsch()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/valsch.md),
[`rptmd()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rptmd.md)
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
cpsrpt(cur, ref = ref, schema = infsch(ref))
#> ╭── Capsule report ─────────────────────────────────────────╮
#> │   Verdict        ✓ these checks found nothing             │
#> │   Rows           200                                      │
#> │   Columns        3                                        │
#> │   Missing cells  0.0%                                     │
#> │   Complete rows  100.0%                                   │
#> │   Digest         f4d14169312fbd9d251a6ab1daffadef         │
#> │   Findings       0                                        │
#> │                                                           │
#> │   No finding is proof of correctness: each check has a    │
#> │   stated blind spot, and a small sample has little power. │
#> ╰───────────────────────────────────────────────────────────╯

# One rescaled column and a new category: both surface, worst first.
bad <- cur
bad$score <- bad$score * 5
bad$grade[1:80] <- "z"
r <- cpsrpt(bad, ref = ref, schema = infsch(ref))
r
#> ╭── Capsule report ───────────────────────────────────────────────────────────╮
#> │   Verdict        ✗ WARNINGS: something moved                                │
#> │   Rows           200                                                        │
#> │   Columns        3                                                          │
#> │   Missing cells  0.0%                                                       │
#> │   Complete rows  100.0%                                                     │
#> │   Digest         ecc02c79b75e352ef946af8cde6b1dd2                           │
#> │   Findings       4                                                          │
#> │                                                                             │
#> │   No finding is proof of correctness: each check has a                      │
#> │   stated blind spot, and a small sample has little power.                   │
#> │                                                                             │
#> │   FAIL warn  drift      grade: categorical test, p = < 0.001                │
#> │   FAIL warn  drift      score: numeric test, p = < 0.001                    │
#> │   FAIL warn  schema     range_score: Column 'score' has 161 value(s)        │
#> │                         outside [-0.8488307, 10.90645]                      │
#> │   FAIL warn  schema     unexpected_grade: Column 'grade' has unexpected     │
#> │                         values: z                                           │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
r$verdict
#> [1] "warn"
r$findings[, c("severity", "check", "subject")]
#>   severity  check          subject
#> 1     warn  drift            grade
#> 2     warn  drift            score
#> 3     warn schema      range_score
#> 4     warn schema unexpected_grade

# A missing column is fatal, because nothing downstream can run.
cpsrpt(bad[, c("id", "score")], ref = ref, schema = infsch(ref))$verdict
#> [1] "fatal"

# validation rules join the findings, and chunks are pinned with a Merkle
# root
r2 <- cpsrpt(
  bad,
  rules = list(ruleinset("grade", c("a", "b", "c"))),
  chunks = c("part one", "part two")
)
summary(r2)
#> verdict   fatal    warn    note 
#>  "warn"     "0"     "1"     "0" 
r2$digest$merkle_root
#> [1] "271d0c66b493e55e2b9659fda7eddb00b0439d076eb82f36a4b8922d6bd4d062"

# a data frame is required
try(cpsrpt(1:10))
#> Error : cpsrpt: `data` must be a data frame
```
