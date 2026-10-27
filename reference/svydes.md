# Describe a complex survey design

Collects what design-based estimation needs: the final weight, and
either a set of replicate weights or the strata and primary sampling
units (PSUs) for Taylor linearization.
[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
and
[`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md)
take the result. Use it once per survey file: a public-use file from
Statistics Canada or Health Canada ships its final weight and a set of
bootstrap replicate weights, and estimates computed without them
understate the standard errors. The design checks the replicate columns
it is given and remembers the rows it was built on, so a later estimate
cannot silently be run on a reordered or different table.

## Usage

``` r
svydes(
  data,
  w,
  strata = NULL,
  psu = NULL,
  fpc = NULL,
  reps = NULL,
  id = NULL,
  type = c("bootstrap", "meanboot", "jk1", "jkn", "brr", "fay"),
  msize = 1,
  rho = NULL,
  mse = TRUE,
  lonely = c("fail", "remove", "adjust"),
  rscales = NULL,
  degf = NULL
)
```

## Arguments

- data:

  A data frame, one row per respondent.

- w:

  The final (full-sample) weight: a column name or a numeric vector with
  one non-negative value per row.

- strata, psu:

  Optional stratum and primary sampling unit: column names or vectors. A
  PSU label need only be unique within its stratum.

- fpc:

  Optional finite population correction per row: a column name or vector
  holding either the stratum's population count of PSUs or (all values
  at most 1) the sampling fraction.

- reps:

  Optional replicate weights: a data frame or matrix with one column per
  replicate, or the names of replicate weight columns in `data`.

- id:

  With a `reps` data frame, the column (present in both) that matches
  its rows to `data`'s; without it the rows must already be in the same
  order.

- type:

  How the replicates were made: `"bootstrap"` (the default),
  `"meanboot"`, `"jk1"`, `"jkn"`, `"brr"` or `"fay"`; see Details.
  Ignored without `reps`.

- msize:

  For `type = "meanboot"`, the number of bootstrap weights averaged into
  each replicate; default `1`.

- rho:

  For `type = "fay"`, Fay's coefficient, between 0 and 1; default
  `NULL`.

- mse:

  Logical scalar, default `TRUE`: centre replicate deviations on the
  full-sample estimate (`TRUE`) or on the mean of the replicate
  estimates (`FALSE`).

- lonely:

  What to do with a stratum that has a single PSU under linearization:
  `"fail"` (the default; an error naming it), `"remove"` (it contributes
  nothing) or `"adjust"` (its PSU is centred on the mean of all PSU
  totals).

- rscales:

  Per-replicate factors: required for `type = "jkn"` (\\(n_h - 1)/n_h\\
  for each replicate's stratum), optional otherwise (multiplying the
  type's scale).

- degf:

  The design's degrees of freedom, when known (a public-use file's
  documentation gives them); by default computed as described in
  Details.

## Value

An object of class `rmbl_svy_design`: a list with `n` (respondents),
`weights`, `type` (the replicate type, or `"linearization"`), `scale`
and `reps` (the replicate scale and weights, `NULL` under
linearization), `mse`, `strata` and `psu` (integer codes), `lonely`,
`check` (the row names and digests used to recognise the data later) and
`degf` (the design degrees of freedom). The print method summarises it.

## Details

Replicate variances are \\v = s \sum_r (\hat\theta_r - c)^2\\, where
\\\hat\theta_r\\ is the estimate under replicate weight \\r\\, \\c\\ is
the full-sample estimate (`mse = TRUE`) or the mean of the replicate
estimates, and the scale \\s\\ depends on how the replicates were made,
for \\B\\ replicates:

- `"bootstrap"`:

  \\1/B\\: the Rao-Wu rescaled bootstrap Statistics Canada ships with
  its public-use files. It is not the survey package's
  `type = "bootstrap"` (Canty and Davison's), whose scale is \\m/((m -
  1)(B - 1))\\ for \\m\\ PSUs a stratum: for those replicates give that
  factor over \\1/B\\ in `rscales`, \\B m/((m - 1)(B - 1))\\ for each,
  with `mse = FALSE` (survey's default centring).

- `"meanboot"`:

  \\R/B\\, where each replicate weight is the mean of \\R\\ bootstrap
  weights (`msize`). The Canadian Substance Use Survey 2023 ships 1,000
  mean bootstrap weights with \\R = 12\\; Health Canada's technical
  notes give the factor of 12, equivalently Fay's BRR with \\\rho = 1 -
  1/\sqrt{12}\\.

- `"jk1"`:

  \\(B - 1)/B\\, the delete-one jackknife.

- `"brr"`:

  \\1/B\\, balanced repeated replication.

- `"fay"`:

  \\1/(B (1 - \rho)^2)\\, Fay's BRR with coefficient `rho`.

- `"jkn"`:

  the stratified delete-one-PSU jackknife: each replicate has its own
  factor \\(n_h - 1)/n_h\\ for the \\n_h\\ PSUs of the stratum it
  deletes from, given as `rscales` (passed as `"jk1"`, JKn weights
  overstated the standard error by 37 percent in a test design).

The replicate columns are taken as given: which columns are replicates
is not guessed from their values (rules that tried refused genuine
designs, a dominant PSU or a jackknife on a subset). Refused, because no
genuine replicate can be it: the `id`'s values, the row numbers, a
column of `data` passed under another name, a second column named like
the weight or the `id` that holds other values, and under JK1, JKn and
BRR a copy of the full-sample weight (equal to it, or within 1 percent
of it on every row; under JKn, a single replicate equal to it, while two
or more equal to it are kept, as a stratum left out of a subset leaves
all of its replicates at the weight). Not a copy: a jackknife replicate
that scales the rows by one factor \\k/(k - 1)\\ (its deleted PSU
outside a subset), and, in a set whose replicates are post-stratified or
calibrated (factors off 0, 1, 2 and \\k/(k - 1)\\), a replicate equal or
close to the weight. Warned about, because a genuine set can produce it
but rarely does: under the bootstrap, more replicates equal to the
full-sample weight than chance draws; under the bootstrap or Fay's
method, a replicate within 1 percent of the weight on every row, and
under Fay's method one equal to it (a post-stratified domain whose rows
sit in one PSU per stratum); under JK1 and JKn, one factor \\k/(k - 1)\\
on every row with no row left out that more or fewer replicates than
\\k\\ carry (a rescaled copy beside a full set, or a lone stray; a
genuine set carries it on exactly \\k\\, on a subset too); under JK1,
JKn and BRR, a replicate that leaves no row out; a replicate more than
ten times the weight on a typical row (a column on another scale, such
as an outcome); and a set whose replicates total, on average, under a
tenth or over ten times the weight (multipliers such as survey's
`$repweights` passed in place of replicate weights). A column of `data`
named in `reps`, and every column of an unnamed matrix, is a replicate
because it was given as one; a stray that is itself shaped like a
replicate (another design's multipliers, a constant under the bootstrap)
cannot be told from one. BRR and Fay replicates must come in a Hadamard
order (2, or a multiple of 4).

The data passed to
[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
must be the rows the design was built on, in the same order: rows in
another order are refused (within strata or PSUs too), and a column
changed since (a permuted outcome for a permutation test) is not a
reorder.

The design's degrees of freedom (`df = "design"` in
[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md))
are PSUs less strata under linearization; for replicate weights, the
rank of the replicate weight matrix less one, as the `survey` package
computes them (twelve BRR half-samples of an eight-stratum design have
8, not 11), or `degf` when given.

Without replicates, the variance is the with-replacement Taylor
linearization: within each stratum \\h\\ with \\n_h\\ PSUs, \\(1 - f_h)
n_h / (n_h - 1)\\ times the sum of squared deviations of the PSU totals
of the weighted linearized values from their stratum mean, summed over
strata (\\f_h\\ from `fpc`, zero without one). No strata means one
stratum; no PSUs means every respondent is its own PSU.

Errors: `data` not a data frame or with fewer than two rows; a named
column that `data` does not have, or a vector of the wrong length;
weights or replicate weights that are negative, missing or not finite;
both replicates and strata or PSUs; fewer than two replicates, or
replicate columns refused for the reasons above; BRR or Fay replicates
not in a Hadamard order; `type = "jkn"` without `rscales`, or `rscales`
not one non-negative number per replicate; `rho` not in \[0, 1) for Fay;
`msize` or `degf` below 1; missing strata or PSU labels; an `fpc` that
is not positive, varies within a stratum, or is smaller than the PSUs
sampled. Nothing is computed until
[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md)
is called, so a single-PSU stratum under `lonely = "fail"` is reported
then.

## See also

[`svyest()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md),
[`svycmp()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md)

## Examples

``` r
set.seed(1)
d <- data.frame(region = rep(c("north", "south"), each = 50),
                smoker = rbinom(100, 1, rep(c(0.2, 0.35), each = 50)),
                w = runif(100, 50, 150))
# ten bootstrap replicates, made here by resampling for the example
reps <- replicate(10, d$w * tabulate(sample(100, replace = TRUE), 100))
des <- svydes(d, w = "w", reps = reps, type = "bootstrap")
des
#> ╭── Survey design ────────────────────────────────────────────────────────╮
#> │   Respondents         100                                               │
#> │   Sum of weights      10,175                                            │
#> │   Variance            bootstrap replicate weights                       │
#> │   Replicates          10                                                │
#> │   Scale               0.1                                               │
#> │   Centring            on the full-sample estimate                       │
#> │   Lonely PSUs         fail                                              │
#> │   Degrees of freedom  9                                                 │
#> │                                                                         │
#> │   svyest() and svycmp() use this design for every estimate: the weights │
#> │   for the point estimate, the replicate weights for its standard error. │
#> ╰─────────────────────────────────────────────────────────────────────────╯
# the same data as a stratified design, variance by linearization
svydes(d, w = "w", strata = "region")
#> ╭── Survey design ────────────────────────────────────────────────────────╮
#> │   Respondents         100                                               │
#> │   Sum of weights      10,175                                            │
#> │   Variance            Taylor linearization                              │
#> │   Strata              2                                                 │
#> │   PSUs                100                                               │
#> │   Lonely PSUs         fail                                              │
#> │   Degrees of freedom  98                                                │
#> │                                                                         │
#> │   svyest() and svycmp() use this design for every estimate: the weights │
#> │   for the point estimate, the strata and PSUs for its standard error.   │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# delete-one jackknife replicates over ten groups of respondents
grp <- rep(1:10, length.out = 100)
jk <- sapply(1:10, function(g) ifelse(grp == g, 0, d$w * 10 / 9))
svydes(d, w = "w", reps = jk, type = "jk1")
#> ╭── Survey design ────────────────────────────────────────────────────────╮
#> │   Respondents         100                                               │
#> │   Sum of weights      10,175                                            │
#> │   Variance            jackknife (JK1)                                   │
#> │   Replicates          10                                                │
#> │   Scale               0.9                                               │
#> │   Centring            on the full-sample estimate                       │
#> │   Lonely PSUs         fail                                              │
#> │   Degrees of freedom  9                                                 │
#> │                                                                         │
#> │   svyest() and svycmp() use this design for every estimate: the weights │
#> │   for the point estimate, the replicate weights for its standard error. │
#> ╰─────────────────────────────────────────────────────────────────────────╯

# a weight column that does not exist
try(svydes(d, w = "wt"))
#> Error : `w` names a column `data` does not have: wt
```
