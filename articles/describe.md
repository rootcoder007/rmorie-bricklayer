# Look at the data first

A capsule is only worth pinning if somebody looked at the data first.
Looking is the step that gets skipped, because it is tedious and because
it is never obviously necessary until afterwards.

This vignette is the short version of looking.

## One command

[`capsule_report()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/capsule_report.md)
runs the checks this package provides and puts the findings in one
place, worst first.

``` r

reference <- data.frame(
  id = 1:300,
  score = stats::runif(300, 0, 10),
  grade = sample(c("a", "b", "c"), 300, TRUE),
  stringsAsFactors = FALSE
)

fresh <- reference
fresh$score <- stats::runif(300, 0, 10)

capsule_report(fresh, reference = reference,
               schema = infer_schema(reference))
#> ── Capsule report ────────────────────────────────────────────────
#>   ✓ these checks found nothing
#> 
#>   rows           300
#>   columns        3
#>   missing cells  0.0%
#>   complete rows  100.0%
#>   digest         6037a08fc090f81243bc07b5094099e0
#> 
#>   No finding is proof of correctness: each check has a
#>   stated blind spot, and a small sample has little power.
#> ──────────────────────────────────────────────────────────────────
```

Now a fetch that went wrong in four different ways at once — a rescaled
column, a category nobody expected, a column that arrived empty, and one
that arrived constant:

``` r

broken <- fresh
broken$score <- broken$score * 5
broken$grade[1:100] <- "z"
broken$dead <- NA_real_
broken$flat <- 7

report <- capsule_report(broken, reference = reference,
                         schema = infer_schema(reference))
report
#> ── Capsule report ────────────────────────────────────────────────
#>   ✗ WARNINGS: something moved
#> 
#>   rows           300
#>   columns        5
#>   missing cells  20.0%
#>   complete rows  0.0%
#>   digest         a70671d4bd03067f631d54ce3143d9a2
#> 
#> ── Findings (8) ──────────────────────────────────────────────────
#>   ✗ warn      drift      grade                  categorical test, p = <2e-16
#>   ✗ warn      drift      score                  numeric test, p = <2e-16
#>   ✗ warn      missing    dead                   column(s) entirely missing
#>   ✗ warn      schema     range_score            Column 'score' has 226 value(s) outside [-0.8488307, 10.90645]
#>   ✗ warn      schema     unexpected_grade       Column 'grade' has unexpected values: z
#>   ! note      drift      dead, flat             column(s) not in the reference
#>   ! note      missing    dead                   a contiguous run of 300 missing values from row 1 -- one outage rather than scattered failures
#>   ! note      shape      flat                   constant: no information, and it breaks anything scaled by variance
#> ──────────────────────────────────────────────────────────────────
```

``` r

report$verdict
#> [1] "warn"
summary(report)
#> verdict   fatal    warn    note 
#>  "warn"     "0"     "5"     "3"
```

Each problem is reported **once**. An entirely missing column is
missing, is trivially constant, and makes any covariance singular —
reporting all three would bury the findings that matter under a single
cause.

[`report_markdown()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/report_markdown.md)
writes the same assessment beside the capsule it describes, so it
outlives the console.

``` r

cat(head(report_markdown(report), 12), sep = "\n")
#> # Capsule report
#> 
#> **Warnings** -- something moved.
#> 
#> | | |
#> |---|---|
#> | rows | 300 |
#> | columns | 5 |
#> | missing cells | 20.0% |
#> | complete rows | 0.0% |
#> | data digest | `a70671d4bd03067f631d54ce3143d9a29a498637315736cf2770ec5777746c33` |
```

## Per column

[`profile_columns()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profile_columns.md)
is the underlying description. It reports the classical and robust
centre side by side, which is the cheapest outlier detector there is:
where a mean and a median disagree, the mean is not describing the
column.

``` r

messy <- data.frame(
  clean = stats::rnorm(200),
  bimodal = c(stats::rnorm(100, -3), stats::rnorm(100, 3)),
  skewed = c(stats::rexp(199), 500),
  zeros = c(rep(0, 50), stats::runif(150))
)
profile_columns(messy)[, c("column", "mean", "median", "sd", "mad")]
#>    column         mean     median         sd       mad
#> 1   clean -0.109165485 -0.1445507  1.0340169 1.0397160
#> 2 bimodal -0.006117203 -0.2014852  3.2205494 4.4949028
#> 3  skewed  3.633870943  0.7332377 35.2946592 0.8114156
#> 4   zeros  0.342795696  0.2656884  0.3197161 0.3939096
```

The `hist` column carries what no single number can:

``` r

profile_columns(messy)[, c("column", "hist")]
#>    column       hist
#> 1   clean ▁▂▃▇█▇▇▃▃▁
#> 2 bimodal ▂▆▆▅ ▂▄█▄▁
#> 3  skewed █        ▁
#> 4   zeros █▃▂▂▂▂▂▃▁▂
```

`bimodal` is visibly two humps. Its mean and median agree perfectly and
tell you nothing about that.

## Where the gaps are

The *rate* of missingness is the least interesting thing about it. Two
frames with identical per-column rates can need completely different
handling:

``` r

structural <- data.frame(
  id = 1:20,
  a = c(rep(NA, 6), 7:20),
  b = c(rep(NA, 6), 7:20)
)
scattered <- data.frame(
  id = 1:20,
  a = c(rep(NA, 6), 7:20),
  b = c(1:14, rep(NA, 6))
)

c(structural = sum(is.na(structural$a)), scattered = sum(is.na(scattered$a)))
#> structural  scattered 
#>          6          6
```

``` r

missingness_pattern(structural)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, a, b
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...     14     70.0         0        
#>      .XX      6     30.0         2    a, b
#> ──────────────────────────────────────────────────────────────────
```

``` r

missingness_pattern(scattered)
#> ── Missingness patterns ────────────────────────────────────────── 
#>   columns, in pattern order: id, a, b
#> 
#>  pattern n_rows pct_rows n_missing columns
#>      ...      8     40.0         0        
#>      ..X      6     30.0         1       b
#>      .X.      6     30.0         1       a
#> ──────────────────────────────────────────────────────────────────
```

Two patterns against three. In the first, one structural gap took out
both columns in the same rows — those rows are a different population,
and often belong dropped or modelled separately. In the second the
failures are independent.

[`missing_runs()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missing_runs.md)
answers a different question again — whether a gap is one outage or many
failures:

``` r

missing_runs(data.frame(
  outage = c(1, 2, rep(NA, 8), 11:20),
  sporadic = c(1, NA, 3, NA, 5, NA, 7:20)
), min_run = 2)
#> ── Runs of consecutive missing values ──────────────────────────── 
#>  column start end length
#>  outage     3  10      8
#> ──────────────────────────────────────────────────────────────────
```

And
[`missingness_map()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/missingness_map.md)
shows the whole table at once, with no graphics device, so it works over
SSH and inside a plain-text summary:

``` r

gappy <- data.frame(
  complete = 1:100,
  early = c(rep(NA, 30), 31:100),
  random = ifelse(stats::runif(100) < 0.3, NA, 1),
  late = c(1:70, rep(NA, 30))
)
missingness_map(gappy, height = 10)
#> ── Missingness map ───────────────────────────────────────────────
#>          cerl
#>          oaaa
#>          mrnt
#>          plde
#>          lyo
#>          em
#>          t
#>          e
#>        1  █░ 
#>       11  █░ 
#>       21  █▒ 
#>       31     
#>       41   ░ 
#>       51   ▒ 
#>       61     
#>       71   ░█
#>       81   ░█
#>       91    █
#> 
#>   legend: ' ' none  '█' all missing
#> ──────────────────────────────────────────────────────────────────
```

## Is the missingness itself a problem?

Dropping incomplete rows is unbiased **only** if the data are missing
completely at random. Otherwise the complete cases are a biased sample
and every downstream estimate inherits the bias.

[`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
is Little’s test for that assumption. It needs maximum-likelihood
estimates of the mean and covariance *under* missingness, which have no
closed form, so it carries an EM estimator.

``` r

n <- 400
x <- stats::rnorm(n)
y <- x + stats::rnorm(n)

# Missing on a coin flip: nothing to find.
mcar <- data.frame(x = x, y = y)
mcar$y[sample(n, 120)] <- NA
mcar_test(mcar)
#> ── Little's MCAR test ────────────────────────────────────────────
#>   ✓ no departure from MCAR detected
#> 
#>   statistic      0.817
#>   df             1
#>   p-value        0.366
#>   patterns       2
#>   variables      2
#>   rows used      400
#>   EM iterations  12
#> 
#>   Not evidence OF MCAR: a large p-value is a failure to detect a
#>   departure, and this test has little power on small samples.
#> ──────────────────────────────────────────────────────────────────
```

``` r

# Missing whenever x is large: the complete cases are a biased sample,
# and that is detectable because the pattern's mean of x is shifted.
mar <- data.frame(x = x, y = y)
mar$y[x > 0.4] <- NA
mcar_test(mar)
#> ── Little's MCAR test ────────────────────────────────────────────
#>   ✗ MCAR rejected: the missingness is related to the data
#> 
#>   statistic      247.984
#>   df             1
#>   p-value        <2e-16
#>   patterns       2
#>   variables      2
#>   rows used      400
#>   EM iterations  71
#> ──────────────────────────────────────────────────────────────────
```

Read the caveat the second report prints. A large p-value is a failure
to detect a departure, not evidence of MCAR, and the test has little
power on small samples. Neither this test nor any other can separate
missing-at-random from missing-**not**-at-random, because that depends
on values that were never observed — only knowing how the data were
collected settles it.

## Rows that do not belong

A row can be unremarkable on every column separately and impossible
jointly.

``` r

people <- data.frame(height_cm = stats::rnorm(300, 170, 10))
people$weight_kg <- people$height_cm * 0.5 + stats::rnorm(300, 0, 5)

# Inside both marginal ranges, outside the cloud.
people[1, ] <- list(height_cm = 150, weight_kg = 140)

range(people$height_cm)
#> [1] 146.2977 196.0117
range(people$weight_kg)
#> [1]  61.95293 140.00000
```

``` r

head(mahalanobis_outliers(people), 3)
#> ── Mahalanobis outliers (robust) ───────────────────────────────── 
#>   ! 1 of 3 rows beyond alpha = 0.001
#> 
#>  row distance p_value outlier
#>    1    10.80  <2e-16    TRUE
#>   59     3.14 0.00725   FALSE
#>  203     2.91  0.0146   FALSE
#> ──────────────────────────────────────────────────────────────────
```

The default is a robust centre and scale, and that default matters more
than it sounds: outliers inflate the very covariance used to judge them,
so with several of them the classical distance hides exactly the rows it
is meant to find.

``` r

many <- people
many[1:8, ] <- list(height_cm = rep(150, 8), weight_kg = rep(140, 8))

c(robust = mahalanobis_outliers(many, robust = TRUE)$distance[1],
  classical = mahalanobis_outliers(many, robust = FALSE)$distance[1])
#>    robust classical 
#>  5.629601  5.510207
```

## Figures that were not measured

Quantities spanning several orders of magnitude follow Benford’s law.
Figures that were rounded, capped, rescaled or invented usually do not.

``` r

benford_test(10^stats::runif(2000, 0, 6))
#> ── Benford first-digit screen ────────────────────────────────────
#>   ✓ consistent with Benford's law
#> 
#>   values used  2,000
#>   chi-square   3.183
#>   df           8
#>   p-value      0.922
#> 
#>   digit  observed  expected        shape
#>       1     0.305     0.301  ####################
#>       2     0.172     0.176  ###########         
#>       3     0.127     0.125  ########            
#>       4     0.088     0.097  ######              
#>       5     0.083     0.079  #####               
#>       6     0.065     0.067  ####                
#>       7     0.060     0.058  ####                
#>       8     0.056     0.051  ####                
#>       9     0.044     0.046  ###                 
#> ──────────────────────────────────────────────────────────────────
```

``` r

benford_test(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))
#> ── Benford first-digit screen ────────────────────────────────────
#>   ! departs from Benford's law (screen only, not a verdict)
#> 
#>   values used  2,000
#>   chi-square   859.762
#>   df           8
#>   p-value      <2e-16
#> 
#>   digit  observed  expected        shape
#>       1     0.117     0.301  ################### 
#>       2     0.103     0.176  #################   
#>       3     0.098     0.125  ################    
#>       4     0.120     0.097  ####################
#>       5     0.113     0.079  ##################  
#>       6     0.101     0.067  ################    
#>       7     0.122     0.058  ####################
#>       8     0.113     0.051  ##################  
#>       9     0.113     0.046  ##################  
#> ──────────────────────────────────────────────────────────────────
```

This is a **screen**, not a verdict. Postcodes, year fields, prices
ending in 99 and anything with a unit floor all violate Benford’s law
perfectly legitimately. A small p-value is a reason to look.

## What none of this does

Every check here has a blind spot, and a clean report means only that
these particular checks found nothing:

- the drift tests have little power on small samples;
- [`mcar_test()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mcar_test.md)
  assumes multivariate normality, so on markedly non-normal columns a
  rejection may be telling you about the distribution rather than the
  missingness;
- Mahalanobis distance assumes the bulk of the data is elliptical;
- Benford’s law does not apply to most bounded or assigned quantities.

None of them can tell you the data means what you think it means. That
still requires reading the documentation for the source, which is the
part
[`load_provenance()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/load_provenance.md)
and the manifest exist to keep attached.
