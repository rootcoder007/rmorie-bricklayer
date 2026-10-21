# Run the pollution-to-health pipeline and report it

Resolves the exposure (synthetic demo data, a CSV with an `exposure`
column and an optional `income` column, a NAPS-style pull with a `value`
column and a `unit`, or scalar arguments), logs the assumptions, and
when they all hold runs the concentration-response,
attributable-fraction, displaced-mortality, burden and equity stages.
`polrpttxt()` renders the result as plain text. It is the one-call
version of the pollution functions, made for scripts and the command
line: it never stops with an R error for bad input, but returns a report
whose status says what went wrong.

## Usage

``` r
vrfpol(
  poll,
  y = "allcause",
  reg = NULL,
  years = NULL,
  demo = FALSE,
  expcsv = NULL,
  expomean = NULL,
  expoprev = NULL,
  ref = NULL,
  brate = 500,
  basrateper = 1e+05,
  pop = 1e+06,
  rare = FALSE,
  hirate = FALSE
)

polrpttxt(report)
```

## Arguments

- poll:

  `"no2"` or `"pm25"` (also `"PM2.5"`), in either case.

- y:

  Outcome key for the concentration-response function; the mortality
  outcomes count deaths, `"chiast"` incident cases.

- reg, years:

  Labels for the report.

- demo:

  Use synthetic demo data (`TRUE` or `FALSE`).

- expcsv:

  Path of a CSV with an `exposure` column in micrograms per cubic metre,
  or a NAPS pull with a `value` column and a `unit` column (required
  with `value`): each row is converted by its own unit, NO2 in ppb at
  1.88 micrograms per cubic metre per ppb (the WHO 2021 conversion at 25
  C and 1 atm), and any other unit is an error. With a CSV or the demo
  data the exposed are the rows above `ref`: `expoprev` is their share
  and `expomean` their mean, so Levin's formula is not diluted twice.

- expomean, expoprev:

  Scalar inputs used when neither `demo` nor `expcsv` is given: the mean
  exposure among the exposed and the share of the population exposed. A
  wrapper must never default one of them to zero: a prevalence of zero
  silently zeroes the burden, which is why the two are required
  together.

- ref:

  Counterfactual reference concentration; `NULL` takes the pollutant's
  default (PM2.5 5.8, NO2 10; see
  [`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)).

- brate:

  Baseline outcome rate per 100,000 per year (unlike
  [`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md),
  which takes a rate per person-year).

- basrateper:

  The denominator `brate` is quoted per: 100,000 (the default), or 1 for
  a rate per person-year such as a crude death rate of 0.012.

- pop:

  Population at risk (persons).

- rare:

  `TRUE` when the outcome really is rarer than one case per 100,000 per
  year. Without it a rate that converts to less than that is an
  assumption failure, because it is also what a rate per person-year
  passed as per 100,000 looks like (0.008 per person-year is 800 per
  100,000; as 0.008 per 100,000 the burden is 100,000 times too small).
  The check is on the converted rate, so it holds whatever `basrateper`
  is.

- hirate:

  `TRUE` when the outcome really is more common than 10,000 per 100,000
  a year (no population's all-cause death rate is); without it such a
  rate is an assumption failure.

- report:

  A result of `vrfpol()` (or a list with the same parts); anything else
  is refused with an R error.

## Value

`vrfpol()`: the report as a list of class `rmbl_pollution_report`
([`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws it); its
`status` is `"ok"`, `"assumption_failure"` or `"error"`, and the
attribute `exitstat` carries a command-line exit code (0, 1 or 2). An
argument the pipeline cannot use (no exposure data at all, a vector
where a single number is expected, an unknown outcome, a missing
reference, a directory as `expcsv`) is an `"error"` report with exit
status 2, never a raw R error; an exposure at or below the reference is
a valid run with zero attributable cases, and the scalar inputs
`expomean` and `expoprev` go together (one without the other is an error
report). On `"ok"` the report also holds `inputs` (the resolved exposure
mean and prevalence, the rate per 100,000, the population, the reference
and the rows dropped), `assumptions` (a list of `assumption`, `ok`,
`note`) and `pipeline` (`crf`, `paf`, `pafci`, `displaced`, `burden` and
`equity`, which is `NULL` without income data). `polrpttxt()`: a single
character string with embedded newlines, ending in a `STATUS:` line (or
`"ERROR:"` and the message for an error report).

## Details

The assumption log checks that the exposure mean is finite and
non-negative and at most 10,000 micrograms per cubic metre, the
prevalence is in \\\[0, 1\]\\, the baseline rate (converted to per
100,000) is zero or between 1 and 10,000 per 100,000 a year (from 1e-6
with `rare`, up to 100,000 with `hirate`), the population is positive
and at most 10 billion, the reference is finite and non-negative, and
the pollutant has a CRF. Any failure gives status `"assumption_failure"`
and skips the stages.

With data (a CSV or the demo), the `"exposed"` are the rows above the
reference: their mean is `expomean` and their share `expoprev`. Empty
cells and missing-value tokens (`NA`, `n/a`, `null`, `-` ...) are
dropped with a message; text that is not a number (a detection-limit
flag such as `"<2"`) and negative values stop the run with an error
report. A gzip, bzip2 or xz file is decompressed; UTF-16 and Latin-1
files are decoded. An `income` column, when present and numeric, gives
the equity stage
([`expconcidx`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expconcidx.md)).

The stages:
[`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md)
or
[`crfno2`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md);
[`attrfrac`](https://rootcoder007.github.io/rmorie-bricklayer/reference/attrfrac.md)
with the CRF's interval;
[`mortdisp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mortdisp.md)
for removing the excess exposure over the exposed population, with
\\\beta = \log(RR) / (\bar x - x\_{ref})\\; and
[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md).
The demo data are 1,000 synthetic units with lognormal exposures at the
scale of Toronto NO2 or PM2.5 levels and five income groups, drawn with
a fixed seed (R's own random stream is restored).

## See also

[`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md)
and the other stage functions to run one step on its own.

## Examples

``` r
r <- vrfpol("no2", demo = TRUE)
r$status
#> [1] "ok"
r$pipeline$paf
#> [1] 0.02733115
cat(polrpttxt(r))
#> ==================================================================
#>   verify-pollution -- NO2 -> allcause
#>   data:   demo (synthetic)
#> ==================================================================
#> 
#> Inputs
#>   exposure mean:      24.261
#>   exposure prevalence:0.981
#>   baseline rate/100k: 500.00
#>   population:         1,000,000
#>   reference conc:     10
#> 
#> Assumption log
#>   [PASS] exposure finite and non-negative -- mean 24.26113743 vs ref 10
#>   [PASS] exposure within the concentration-response range (at most 10,000 ug/m3) -- exposure_mean=24.26114
#>   [PASS] prevalence in [0,1] -- exposure_prevalence=0.981
#>   [PASS] brate finite: zero, or between 1 and 10,000 per 100k -- brate=500 per 100k per year
#>   [PASS] population finite, positive and at most 10 billion -- population=1,000,000
#>   [PASS] reference finite and non-negative -- reference=10
#>   [PASS] pollutant supported by the CRFs -- Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke). Other pollutants reject.
#> 
#> Concentration-response
#>   RR:       1.0286
#>   source:   Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines
#> 
#> Attributable fraction (PAF): 0.0273  (95% CI 0.0138 to 0.0534, from the risk's limits)
#> 
#> Mortality displaced
#>   expected avoided deaths: 136.6
#> 
#> Burden of pollution
#>   attributable deaths:   136.7
#> 
#> Equity analysis
#>   concentration index: -0.0647
#> 
#> STATUS: ok

# Scalar inputs: a city of 2.8 million at a PM2.5 mean of 9.
s <- vrfpol("pm25", expomean = 9, expoprev = 1,
                      brate = 750, pop = 2.8e6, reg = "Toronto")
s$pipeline$burden$attrcases
#> [1] 510.8617
attr(s, "exitstat")
#> [1] 0

# A CSV of measurements with an income column.
f <- tempfile(fileext = ".csv")
utils::write.csv(data.frame(exposure = c(12, 18, 25, 31, 9), income = 1:5), f,
                 row.names = FALSE)
vrfpol("no2", expcsv = f)$pipeline$equity$concidx
#> [1] 0.02947368

# A rate per person-year passed as per 100,000 fails an assumption ...
bad <- vrfpol("no2", expomean = 20, expoprev = 1,
                        brate = 0.008)
bad$status
#> [1] "assumption_failure"
# ... and an argument it cannot use is an error report, not an R error.
vrfpol("no2")$error
#> [1] "no exposure data: pass expcsv, or expomean and expoprev, or demo = TRUE"
```
