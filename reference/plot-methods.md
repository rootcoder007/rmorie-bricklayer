# Plot methods for the package's results

Every result the package returns draws itself with
[`plot()`](https://rdrr.io/r/graphics/plot.default.html): no arguments
beyond the object are needed, and every method takes the same
customisation (`main`, `col` or `palette`, `...` for the base-graphics
call, the grid from the session option; see
[`plotopt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)).
Titles fit their panel: a title too wide for it is drawn a step smaller,
and in a panel set one that still does not fit becomes a letter with the
key printed under the panels (the returned data carry it as the `plnkey`
attribute); the left margin is sized from the widest tick label, so an
axis title never overlaps the numbers. (Session defaults: see
[`plotopt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
for the session defaults). Each method returns the data it drew,
invisibly, as a data frame.

## Usage

``` r
# S3 method for class 'rmbl_census_cwb'
plot(
  x,
  ...,
  component = c("cwb", "income", "education", "housing", "labour"),
  main = NULL,
  col = NULL,
  palette = NULL
)

# S3 method for class 'rmbl_profile_share'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_hotspot'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_connection'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_healing_change'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_community_index'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_indigenous_gap'
plot(
  x,
  ...,
  what = c("difference", "ratio"),
  main = NULL,
  col = NULL,
  palette = NULL
)

# S3 method for class 'rmbl_prevalence'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_dsr'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_prevalence'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_exposure_trend'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_trc_progress'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_ordinal_compare'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_wellness_profile'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_holistic_balance'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_dual_continuum'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_distinctions'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_case_flow'
plot(
  x,
  ...,
  what = c("flow", "clearance"),
  main = NULL,
  col = NULL,
  palette = NULL
)

# S3 method for class 'rmbl_life_table'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_disposition_mix'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_density'
plot(x, ..., points = TRUE, main = NULL,
  col = NULL, palette = NULL)

# S3 method for class 'rmbl_knox'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_clearance_decomposition'
plot(x, ..., what = NULL,
  maxparts = 20L, main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_synthdid'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_power'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_balance'
plot(
  x,
  ...,
  threshold = 0.1,
  after = NULL,
  main = NULL,
  col = NULL,
  palette = NULL
)

# S3 method for class 'rmbl_aipw'
plot(
  x,
  ...,
  type = c("overlap", "estimate"),
  main = NULL,
  col = NULL,
  palette = NULL
)

# S3 method for class 'rmbl_stock_flow'
plot(
  x,
  ...,
  what = c("adp", "alos", "people", "days"),
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL
)

# S3 method for class 'rmbl_yoy'
plot(
  x,
  ...,
  what = c("pctchg", "value"),
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL,
  gaps = c("break", "join")
)

# S3 method for class 'rmbl_rate'
plot(x, ..., period = NULL, main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_share'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_rate_change'
plot(x, ..., main = NULL, col = NULL,
  palette = NULL, xlab = NULL)

# S3 method for class 'rmbl_band_sensitivity'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_drift_calibration'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_drift'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_benford'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_power'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_freq'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_missingness'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_region_coverage'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_outliers'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_correlations'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_cortable'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'bricklayer_falsification'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_bounds'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_crf'
plot(x, ..., exposure = NULL, main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_burden'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_equity'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_pollution_report'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_footprint'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_field'
plot(x, ..., contours = 8L, main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_particles'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_count_trend'
plot(x, ..., main = NULL, col = NULL,
  palette = NULL, xlab = NULL)

# S3 method for class 'bricklayer_analysis'
plot(x, ..., which = NULL, main = NULL)

# S3 method for class 'rmbl_event_study'
plot(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  style = c("dot", "stata"),
  shadepost = FALSE,
  refline = -0.5,
  xlab = NULL,
  gaps = c("break", "join")
)

# S3 method for class 'rmbl_staggered_att'
plot(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  style = c("dot", "stata"),
  shadepost = FALSE,
  refline = -0.5
)

# S3 method for class 'rmbl_synth'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_bacon'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_permutation'
plot(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  type = c("density", "histogram")
)

# S3 method for class 'rmbl_loo'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_cohort_trends'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_svy_estimate'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_svy_compare'
plot(x, ..., main = NULL, col = NULL, palette = NULL)

# S3 method for class 'rmbl_trc_gaps'
plot(x, ..., main = NULL, col = NULL, palette = NULL)
```

## Arguments

- x:

  The result.

- ...:

  Passed to the base-graphics call (`plot`, `barplot` or `image`). They
  are passed on to each panel's method for a `bricklayer_analysis`
  object.

- component:

  For `rmbl_census_cwb`: `"cwb"` (the index, default) or one of its
  components `"income"`, `"education"`, `"housing"`, `"labour"`.

- main:

  Title; each method has a default.

- col:

  Colours, overriding the palette.

- palette:

  A
  [`blpal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/blpal.md)
  name, overriding the session option.

- what:

  Depends on the class:

  - `rmbl_indigenous_gap`: `"difference"` or `"ratio"`;

  - `rmbl_stock_flow`: the measures to draw (one panel each), any of
    `"adp"`, `"alos"`, `"people"`, `"days"`, `"flowrate"`, `"stkrate"`;

  - `rmbl_yoy`: `"pctchg"` or `"value"`;

  - `rmbl_case_flow`: `"flow"` and/or `"clearance"`;

  - `rmbl_clearance_decomposition`: any of `"rates"`, `"mix"` and
    `"effects"` (the default fits the device).

- points:

  For `rmbl_density`, whether to draw the incidents over the surface.

- maxparts:

  For `rmbl_clearance_decomposition`, the most parts drawn: past it, the
  parts that moved the aggregate most, and the rest summed into one row.

- threshold:

  For `rmbl_balance`: the absolute standardised difference drawn as the
  line of acceptable balance (default 0.1).

- after:

  For `rmbl_balance`: optionally a second
  [`baltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/baltab.md)
  on the same covariates (after weighting or matching), drawn beside the
  first.

- type:

  For a permutation test: `"density"` (a kernel density of the permuted
  statistics, their 5th and 95th percentiles dashed, the observed one in
  red; the default) or `"histogram"`. For a cross-fitted AIPW result:
  `"overlap"` (the weighted distribution of the out-of-fold propensity
  in each arm with the clipping bounds; the default) or `"estimate"`
  (the effect with its confidence interval).

- xlab:

  For the plots over time (`rmbl_stock_flow`, `rmbl_yoy`,
  `rmbl_rate_change`, `rmbl_count_trend`, `rmbl_event_study`), the title
  of the period axis. The default `NULL` names the unit the period
  implies: `"Date"` for dates, `"Time"` for date-times, `"Fiscal year"`
  for fiscal-year labels such as `"2022/23"`, `"Periods since adoption"`
  for an event study, otherwise `"Period"`. A number or a date is drawn
  on its own continuous scale, so a missing period leaves its gap; any
  other period (text, a factor) is drawn at evenly spaced positions
  labelled with its text.

- gaps:

  For `rmbl_yoy` (`what = "value"`) and `rmbl_event_study`
  (`style = "stata"`): how a missing value shows in a line. `"break"`
  (the default) breaks the line there, so a "no data" period that
  `yoy(complete = TRUE)` inserted is a visible gap; `"join"` draws the
  line straight over it.

- period:

  For `rmbl_rate`, a `by` column holding the period: the rate is drawn
  over time with its interval band, one panel per group of the other
  `by` columns.

- exposure:

  For `rmbl_crf` and `rmbl_burden`, the exposure range to draw the curve
  over; the default runs from 0 to 1.5 times the exposure in the object.

- contours:

  Number of contour lines over a field image (0 for none).

- which:

  For `bricklayer_analysis`, the panels: any of `"change"`, `"rates"`,
  `"ratechg"`; `NULL` draws every panel the analysis has.

- style:

  For an event study: `"dot"` (filled points with solid capped bars, the
  default) or `"stata"` (hollow points joined by a line, dashed capped
  bars, dashed reference lines).

- shadepost:

  Shade the periods after adoption (default `FALSE`).

- refline:

  Where the vertical reference line goes (default `-0.5`, between the
  reference period and adoption; `0` puts it at adoption).

## Value

The data drawn, invisibly. For the plots over time the frame carries the
x position of each point drawn: an `at` column (`rmbl_yoy`,
`rmbl_rate_change`), or an `"at"` attribute (`rmbl_stock_flow`).

## Details

- `rmbl_stock_flow`:

  ([`stkflow`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stkflow.md))
  the average daily population, length of stay, people and person-days
  over the periods, one panel per measure in `what`; with an exposure,
  the flow and stock rates too.

- `rmbl_yoy`:

  ([`yoy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/yoy.md))
  the period-over-period percent change with its interval over the
  periods, the period across and the change up, groups side by side,
  coloured by verdict; `what = "value"` draws the values instead.

- `rmbl_rate`, `rmbl_share`:

  ([`rtcalc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rtcalc.md),
  [`shrs`](https://rootcoder007.github.io/rmorie-bricklayer/reference/shrs.md))
  the rate or share per group with its interval.

- `rmbl_rate_change`:

  ([`ratechg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ratechg.md))
  the percent change in the rate with its interval over the periods,
  groups side by side.

- `rmbl_band_sensitivity`:

  ([`bandsens`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bandsens.md))
  the statistic against the cap applied to the open band.

- `rmbl_drift_calibration`, `bricklayer_drift`:

  ([`drftcal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/drftcal.md),
  [`cpsdrft`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsdrft.md))
  the false-alarm rate per column against alpha; the population
  stability index per column with the drifted columns marked.

- `bricklayer_benford`:

  ([`benfordtst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/benfordtst.md))
  observed first-digit proportions against Benford's law.

- `bricklayer_power`:

  ([`cpspwr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpspwr.md))
  the power curve: detection rate against injected effect size, with the
  0.8 line.

- `bricklayer_freq`, `bricklayer_missingness`, `rmbl_region_coverage`:

  ([`freqtbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/freqtbl.md),
  [`misspat`](https://rootcoder007.github.io/rmorie-bricklayer/reference/misspat.md)
  and
  [`rgncov`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rgncov.md))
  horizontal bars.

- `bricklayer_outliers`:

  ([`mahaoutl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mahaoutl.md))
  the distance of every row, outliers marked.

- `bricklayer_correlations`, `bricklayer_cortable`:

  ([`topcors`](https://rootcoder007.github.io/rmorie-bricklayer/reference/topcors.md),
  [`cortbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cortbl.md))
  the correlation of every pair as a diverging bar.

- `bricklayer_falsification`:

  ([`cpsfals`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cpsfals.md))
  the permutation null distribution with the observed statistic.

- `rmbl_bounds`:

  ([`pubbnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pubbnd.md))
  each value inside its published-rounding envelope.

- `rmbl_indigenous_gap`, `rmbl_dsr`, `rmbl_prevalence`:

  each group's difference or ratio, rate, percentage, odds ratio or
  index with its interval, for these classes and for
  `rmbl_exposure_trend` and `rmbl_community_index`
  ([`indgap`](https://rootcoder007.github.io/rmorie-bricklayer/reference/indgap.md),
  [`agestd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/agestd.md),
  [`stdprev`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md),
  [`exptrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/exptrnd.md),
  [`commidx`](https://rootcoder007.github.io/rmorie-bricklayer/reference/commidx.md));
  `what = "ratio"` draws the ratio of a gap.

- `rmbl_trc_progress`:

  ([`trcprog`](https://rootcoder007.github.io/rmorie-bricklayer/reference/trcprog.md))
  the Calls to Action completed, and the pace projected with the band
  its interval gives.

- `rmbl_ordinal_compare`:

  ([`ordcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/ordcmp.md))
  each group's ratings as one stacked bar, lowest rating on the left.

- `rmbl_wellness_profile`, `rmbl_wellness_continuum`:

  wellness indicators above, distress below, each group's estimate and
  interval
  ([`welprof`](https://rootcoder007.github.io/rmorie-bricklayer/reference/welprof.md),
  [`mhcont`](https://rootcoder007.github.io/rmorie-bricklayer/reference/mhcont.md)).

- `rmbl_dual_continuum`:

  ([`dualcont`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dualcont.md))
  each group on the two axes, wellness up and distress across.

- `rmbl_holistic_balance`:

  ([`holbal`](https://rootcoder007.github.io/rmorie-bricklayer/reference/holbal.md))
  the domains as spokes and each group's levels on them, with its
  balance.

- `rmbl_distinctions`:

  ([`dstntst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dstntst.md))
  each group's estimate and the pooled figure, with I-squared.

- `rmbl_connection`:

  ([`connassoc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/connassoc.md))
  the places on the two indicators, with their intervals; `xlab` and
  `ylab` name the axes (default: the indicators' column names).

- `rmbl_healing_change`:

  ([`healchg`](https://rootcoder007.github.io/rmorie-bricklayer/reference/healchg.md))
  the change in each indicator between the periods, wellness first.

- `rmbl_profile_share`:

  ([`profshr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/profshr.md))
  each group's share of a census characteristic with its interval.

- `rmbl_crf`, `rmbl_burden`, `rmbl_equity`:

  and `rmbl_pollution_report`: in turn, the concentration-response curve
  with the exposure marked; baseline against attributable cases; the
  concentration curve of exposure over income rank; and, for a report,
  all three on one page
  ([`crfpm25`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crfpm25.md),
  [`polbrdn`](https://rootcoder007.github.io/rmorie-bricklayer/reference/polbrdn.md),
  [`expconcidx`](https://rootcoder007.github.io/rmorie-bricklayer/reference/expconcidx.md),
  [`vrfpol`](https://rootcoder007.github.io/rmorie-bricklayer/reference/vrfpol.md)).

- `rmbl_footprint`:

  ([`co2fp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2fp.md))
  the CPU, memory and total emission in one unit chosen to fit, with the
  car-kilometre and tree-month equivalents as a caption; "Too short to
  measure" when the work took no measurable time.

- `rmbl_field`, `rmbl_particles`:

  ([`plmfld`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plmfld.md),
  [`advdif2d`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md),
  [`lagrprt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/pgsig.md))
  a concentration field as an image with contours; particle positions,
  with the counting grid behind them when one was given.

- `rmbl_count_trend`:

  ([`cnttrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnttrnd.md))
  the counts with the fitted trend.

- `bricklayer_analysis`:

  ([`anltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/anltab.md))
  the change, rates and rate change of a published table, one panel
  each.

- `rmbl_event_study`, `rmbl_staggered_att`:

  ([`evstudy`](https://rootcoder007.github.io/rmorie-bricklayer/reference/evstudy.md),
  [`stgatt`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stgatt.md))
  the effect at each period since adoption with its interval, the
  reference period at zero.

- `rmbl_synth`, `rmbl_synthdid`:

  ([`synctl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/synctl.md),
  [`syndid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/syndid.md))
  the treated unit (or mean) and its synthetic or weighted comparison
  over time, adoption marked.

- `rmbl_power`:

  ([`plnpwr`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plnpwr.md))
  power against effect size, with the 0.8 line and the minimum
  detectable effect.

- `rmbl_prevalence`:

  ([`stdprev`](https://rootcoder007.github.io/rmorie-bricklayer/reference/stdprev.md))
  each group's age-standardised prevalence with its interval.

- `rmbl_census_cwb`:

  ([`cnscwb`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cnscwb.md))
  the Community Well-Being index, or one `component`, by place, one
  colour per group.

- `rmbl_balance`:

  ([`baltab`](https://rootcoder007.github.io/rmorie-bricklayer/reference/baltab.md))
  a love plot: each covariate's absolute standardised difference against
  the `threshold` line, with a second table (`after`, after weighting or
  matching) beside it.

- `rmbl_aipw`:

  ([`aipwcf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/aipwcf.md))
  the overlap of the two groups' out-of-fold propensities
  (`type = "overlap"`) or the estimate with its interval
  (`type = "estimate"`).

- `rmbl_event_study`, `rmbl_staggered_att`:

  also take `style = "stata"` (hollow points joined by a line, dashed
  bars) and `shadepost`;
  [`plotevgrid`](https://rootcoder007.github.io/rmorie-bricklayer/reference/plotevgrid.md)
  puts several in one grid.

- `rmbl_bacon`:

  ([`bacondcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/bacondcmp.md))
  each two-group comparison's estimate against its weight, by type, with
  the two-way estimate.

- `rmbl_permutation`:

  ([`perminf`](https://rootcoder007.github.io/rmorie-bricklayer/reference/perminf.md))
  the permuted statistics as a density (5th and 95th percentiles dashed)
  or histogram, the observed one in red, one panel per outcome.

- `rmbl_loo`, `rmbl_cohort_trends`:

  ([`loounit`](https://rootcoder007.github.io/rmorie-bricklayer/reference/loounit.md),
  [`cohtrnd`](https://rootcoder007.github.io/rmorie-bricklayer/reference/cohtrnd.md))
  the leave-one-out estimates with the full-sample one; each cohort's
  outcome by time since adoption.

- `rmbl_case_flow`:

  ([`caseflow`](https://rootcoder007.github.io/rmorie-bricklayer/reference/caseflow.md))
  cases received and disposed, shaded where the inventory grew or fell,
  and the clearance rate with its interval and rolling value.

- `rmbl_life_table`:

  ([`lifetbl`](https://rootcoder007.github.io/rmorie-bricklayer/reference/lifetbl.md))
  the share of cases still open at each band edge with its interval, and
  the median.

- `rmbl_disposition_mix`:

  ([`dispmix`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dispmix.md))
  the shares of each outcome over the periods, stacked.

- `rmbl_density`:

  ([`crmdens`](https://rootcoder007.github.io/rmorie-bricklayer/reference/crmdens.md))
  the density of incidents as a heat map, with the highest-density
  regions outlined.

- `rmbl_knox`:

  ([`knoxtst`](https://rootcoder007.github.io/rmorie-bricklayer/reference/knoxtst.md))
  the Knox ratio of each distance-by-time cell, coloured on a log scale
  around 1.

- `rmbl_hotspot`:

  ([`hotpers`](https://rootcoder007.github.io/rmorie-bricklayer/reference/hotpers.md))
  the share of places holding half the incidents and the overlap of hot
  spots with the period before, over time, and a map of the cells
  coloured by how often they were hot.

- `rmbl_svy_estimate`, `rmbl_svy_compare`:

  ([`svyest`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svyest.md),
  [`svycmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/svycmp.md))
  each domain's estimate with its interval, flagged domains marked; each
  difference from the reference domain with its interval.

- `rmbl_clearance_decomposition`:

  ([`clrdcmp`](https://rootcoder007.github.io/rmorie-bricklayer/reference/clrdcmp.md))
  the parts' rates in both comparisons with the aggregate on top, where
  the workload moved (coloured by whether a part clears above or below
  the average), and the change as a waterfall of rate and mix effects:
  the pictures that show a Simpson's-paradox reversal and why it
  happened.

## Examples

``` r
sf <- stkflow(days = c(13500, 14600, 15100), people = c(300, 320, 310),
                 prd = 2021:2023)
plot(sf)

plot(sf, what = "alos", col = "firebrick", main = "Length of stay")

y <- yoy(data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)), value = "n",
         prd = "year")
plot(y)

# small counts: each percentage carries its exact interval
plot(yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n",
         prd = "year"))

plot(benfordtst(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9)))

plot(crfno2(25))

plot(co2fp(for (i in 1:20) sum(sqrt(seq_len(2e5))), loc = "CA",
                       cpupwrw = 45, memgb = 8))

# the courts and crime data shipped with the package
ext <- function(f) {
  read.csv(system.file("extdata", f, package = "rmoriebricklayer"))
}
fl <- ext("ocj_flow_ontario.csv")
plot(caseflow(fl$received, fl$disposed, pend = fl$pending, prd = fl$month))

td <- ext("ocj_time_to_disposition.csv")
open <- unlist(td[nrow(td), 2:5]) * fl$disposed[nrow(fl)]
plot(lifetbl(c(0, 10, 15, 18, Inf), open))

dm <- ext("ocj_dispositions.csv")
plot(dispmix(dm[, -(1:2)], prd = dm$year))

og <- ext("ocj_offence_groups.csv")
og <- og[og$year %in% c(2014, 2022), ]
plot(clrdcmp(og$disposed, og$received, og$offence_group, og$year))

be <- ext("tps_break_enter_d14_2024.csv")
be <- be[!is.na(be$lon), ]
plot(crmdens(be$lon, be$lat, ngrid = 60))

# \donttest{
plot(knoxtst(be$lon, be$lat, as.Date(be$occ_date), c(100, 200, 400), c(7, 14, 28),
               nsim = 99, seed = 1))

# }
plot(hotpers(be$lon, be$lat, quarters(as.Date(be$occ_date)), cell = 0.3))

# rates, shares and the change in a rate
rt <- data.frame(division = rep(c("n", "e", "w"), 2), year = rep(2022:2023, each = 3),
                 stops = c(120, 90, 60, 150, 85, 70),
                 residents = rep(c(1e4, 8e3, 5e3), 2))
r23 <- rt[rt$year == 2023, ]
plot(rtcalc(r23, count = "stops", pop = "residents", by = "division"))

plot(shrs(r23, count = "stops", by = "division"))

plot(ratechg(rt, count = "stops", pop = "residents", prd = "year",
                 by = "division"))

# a rate over time, one panel per group
plot(rtcalc(rt, count = "stops", pop = "residents", by = c("division", "year")),
     period = "year")

# complex survey estimates by domain, and the differences between domains
set.seed(3)
sv <- data.frame(region = rep(c("north", "south", "east"), length.out = 300),
                 smoker = rbinom(300, 1, 0.25), w = runif(300, 50, 150))
sd <- svydes(sv, w = "w", strata = "region")
plot(svyest(sd, sv, "smoker", by = "region", stat = "proportion", lvls = "1"))

plot(svycmp(sd, sv, "smoker", by = "region", stat = "proportion", lvls = "1"))

# a published table in one call: change, rates and rate change
tab <- data.frame(year = rep(2020:2023, each = 2), g = rep(c("a", "b"), 4),
                  n = c(10, 20, 12, 22, 11, 25, 15, 24), pop = rep(c(1000, 2000), 4))
plot(anltab(tab, value = "n", prd = "year", by = "g", pop = "pop"))

plot(cnttrnd(c(21000, 23000, 22000, 25000, 24000)))

# banded tables
plot(bandsens(prsbands(c("0-17", "18-24", "25-44", "45+")), c(10, 20, 30, 40),
                      caps = c(60, 70, 80, 90)))

plot(pubbnd(c(10, 20), rnd = 5))

plot(rgncov(c("a", "b", "c"), c(100, 200, 300), c(1L, 0L, 2L)))

# drift between two extracts, and how often the test cries wolf
set.seed(1)
dd <- data.frame(a = rnorm(400), b = sample(letters[1:3], 400, TRUE))
plot(cpsdrft(dd, transform(dd, a = a + 3)))

plot(drftcal(dd, n = 20L))

# describing a table
plot(freqtbl(data.frame(g = c("a", "b", "b", "c", "c", "c")), "g"))

plot(misspat(data.frame(a = c(1, NA, 3, NA), b = c(NA, NA, 1, 2))))

hw <- data.frame(h = rnorm(100), w = rnorm(100))
hw$h[1] <- 15
plot(mahaoutl(hw))

sq <- data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20))
plot(topcors(sq))

plot(cortbl(sq))

# power and falsification of a statistic
xy <- data.frame(x = rnorm(60), y = rnorm(60))
shift <- function(z, s) {
  z$y <- z$y + s * z$x
  z
}
plot(cpspwr(xy, function(z) cor(z$x, z$y), inject = shift, trt = "x",
                   sizes = c(0, 0.25, 0.5), n = 19, reps = 3, seed = 1))

plot(cpsfals(xy, function(z) cor(z$x, z$y), trt = "x", n = 29, seed = 1))

# air pollution: burden, equity, and the full report
plot(polbrdn(25, 1, 0.008, 1e6, poll = "NO2"))

plot(expconcidx(data.frame(exposure = c(4, 1, 8, 2),
                                             income = c(2, 1, 4, 3)),
                                  "exposure", "income"))

plot(vrfpol("no2", demo = TRUE))

plot(lagrprt(200, 0, 0, 1, 0.5, 1, 1, 1, 20,
                          grid = c(-10, 40, -15, 25, 10, 8)))

plot(plmfld(q = 100, u = 5, h = 50, x = seq(100, 2000, by = 100),
                 y = seq(-300, 300, by = 50)))
```
