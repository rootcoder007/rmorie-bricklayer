# SPDX-License-Identifier: AGPL-3.0-or-later
# One plot() method per result the package returns, on base graphics only (no
# new dependency), with one shared look and the same customisation everywhere:
# `main`, `col` or `palette`, `grid`, and `...` handed to the base call. Every
# method returns, invisibly, the data frame it drew, so a test can check the
# numbers on the page and a user can redraw them any other way.

#' Plot styling for the package's plot methods
#'
#' Every \code{plot()} method in the package draws with base graphics and
#' the same small set of style choices, which these functions expose.
#' \code{blpal()} returns colour-blind-safe palettes:
#' \code{"okabe"} (the Okabe-Ito categorical set), \code{"diverging"}
#' (blue, grey, orange), \code{"sequential"} (light to dark blue) and
#' \code{"grey"}. \code{plotopt()} sets the defaults every
#' method uses, for the session: \code{palette}, \code{grid}, \code{cex},
#' \code{las} and \code{bg}. Each method also takes \code{main},
#' \code{col} (which overrides the palette), \code{palette} and \code{...}
#' passed to the underlying base-graphics call, so a single plot can be
#' changed without changing the session. Use \code{blpal()} also
#' to colour your own plots so they match the package's.
#'
#' @details The palettes: \code{"okabe"} is the eight-colour set of Okabe and
#' Ito (2008), distinguishable under the common forms of colour-vision
#' deficiency. \code{"diverging"} has three anchors (blue \code{#2166AC}, grey
#' \code{#8C8C8C}, orange-red \code{#D6604D}) and is used for changes (decrease,
#' no change, increase). The palette \code{"sequential"} has five blues from
#' light to dark; \code{"grey"} five greys from dark to light. With \code{n}
#' given, \code{"okabe"} and \code{"grey"} repeat their colours
#' (\code{rep_len()}) and \code{"diverging"} and \code{"sequential"} are
#' interpolated with \code{grDevices::colorRampPalette()}.
#'
#' The session options are stored in \code{options(rmoriebricklayer.plot)};
#' the defaults are \code{palette = "okabe"}, \code{grid = TRUE},
#' \code{cex = 1}, \code{las = 1}, \code{bg = "white"} and
#' \code{panel = "#EEF1F6"}. Setting some options keeps the others.
#'
#' Text is drawn at the session \code{cex}. Titles, axis titles, row labels and
#' keys are made smaller to fit a small device, but never below 0.6 of that
#' size, so that they stay readable; for larger text set, for example,
#' \code{plotopt(cex = 1.2)}, and for a table with many rows use a taller
#' device.
#'
#' Errors: an unknown palette \code{name}; \code{n} not a positive whole
#' number; an option name other than the six above, or an unnamed value; an
#' unknown \code{palette} option.
#'
#' @param name Character scalar, the palette: \code{"okabe"} (the default), or
#'   one of \code{"diverging"}, \code{"sequential"} and \code{"grey"}.
#' @param n Integer scalar or \code{NULL} (the default: the palette's own
#'   colours). The number of colours wanted; \code{"okabe"} and \code{"grey"}
#'   recycle, \code{"sequential"} and \code{"diverging"} interpolate.
#' @param ... For \code{plotopt()}, named options to set:
#'   \code{palette} (a palette name), \code{grid} (logical, draw grid
#'   lines), \code{cex} (numeric text and symbol size), \code{las} (axis label
#'   orientation, as in \code{par()}), \code{bg} (background colour) and
#'   \code{panel} (the plot region's fill behind white grid lines, \code{NA}
#'   for none). With no arguments, the current values are returned.
#' @return \code{blpal()}: a character vector of hexadecimal
#'   colours. \code{plotopt()}: a named list of the six
#'   options in force (after the change), invisibly when setting.
#' @references Okabe, M. and Ito, K. (2008). Color Universal Design (CUD):
#'   how to make figures and presentations that are friendly to colorblind
#'   people. jfly.uni-koeln.de/color
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' blpal("okabe", 3)
#' # plotopt() returns the options in force, so keep them before a change
#' old <- plotopt()
#' plotopt(palette = "grey", grid = FALSE)
#' plotopt(palette = old$palette, grid = old$grid)
#'
#' # an interpolated sequential scale, shown as swatches
#' cols <- blpal("sequential", 7)
#' barplot(
#'   rep(1, 7),
#'   col = cols,
#'   border = NA,
#'   axes = FALSE,
#'   names.arg = cols,
#'   las = 2,
#'   cex.names = 0.6
#' )
#'
#' # the same palette in a base plot of your own
#' plot(1:8, pch = 19, cex = 3, col = blpal("okabe"))
#'
#' # names are checked
#' try(blpal("viridis"))
#' try(plotopt(colour = "red"))
#' @export
#' @srrstats {EA5.0} All plot methods share one base-graphics style with
#'   colour-blind-safe palettes and the session options set through plotopt().
#' @srrstats {EA5.0b} Default palette is Okabe-Ito (colour-vision-deficiency
#'   safe), with a ColorBrewer-style diverging, sequential and grey set;
#'   test-plots.R checks palettes.
#' @srrstats {EA5.0a} Text follows plotopt(cex = ), and labels shrunk to fit
#'   stop at 0.6 of it (documented in the details); test-plot-fit-1_0_0.R checks
#'   the floor.
#' @srrstats {EA5.4} Axes are drawn with base axis()/axTicks(), which use
#'   pretty(); margins are sized from format(pretty(y)) in .bl_left_margin.
blpal <- function(
  name = c("okabe", "diverging", "sequential", "grey"),
  n = NULL
) {
  name <- .rmbl_arg(name)
  base <- switch(
    name,
    okabe = c(
      "#0072B2",
      "#D55E00",
      "#009E73",
      "#E69F00",
      "#CC79A7",
      "#56B4E9",
      "#F0E442",
      "#000000"
    ),
    diverging = c("#2166AC", "#8C8C8C", "#D6604D"),
    sequential = c("#C6DBEF", "#6BAED6", "#2171B5", "#08306B", "#041E42"),
    grey = c("#252525", "#636363", "#969696", "#BDBDBD", "#D9D9D9")
  )
  if (is.null(n)) {
    return(base)
  }
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 1L) {
    stop("`n` must be a single positive whole number", call. = FALSE)
  }
  n <- as.integer(n)[1L]
  if (name %in% c("okabe", "grey")) {
    return(rep_len(base, n))
  }
  if (n == 1L) {
    return(base[1L])
  }
  grDevices::colorRampPalette(base)(n)
}

#' @rdname blpal
#' @export
plotopt <- function(...) {
  current <- .bl_plot_opts()
  new <- list(...)
  if (!length(new)) {
    return(current)
  }
  bad <- setdiff(names(new), names(current))
  if (is.null(names(new)) || !all(nzchar(names(new))) || length(bad)) {
    stop(
      sprintf("plot options are %s", toString(names(current))),
      call. = FALSE
    )
  }
  if (!is.null(new$palette)) {
    new$palette <- .rmbl_arg(
      new$palette,
      c("okabe", "diverging", "sequential", "grey")
    )
  }
  for (nm in setdiff(names(new), "palette")) {
    .bl_plot_opt_check(nm, new[[nm]])
  }
  current[names(new)] <- new
  options(rmoriebricklayer.plot = current)
  invisible(current)
}

# Panel state: while a multi-panel method runs, titles that do not fit their
# panel become letters, and the key (A: full title ...) is printed under the
# panels at the end.
.bl_state <- new.env(parent = emptyenv())

.bl_state$active <- FALSE

# ---- stock and flow ----------------------------------------------------------

#' Plot methods for the package's results
#'
#' Every result the package returns draws itself with \code{plot()}: no
#' arguments beyond the object are needed, and every method takes the same
#' customisation (\code{main}, \code{col} or \code{palette}, \code{...} for
#' the base-graphics call, the grid from the session option; see
#' \code{\link{plotopt}}). Titles fit their panel: a title
#' too wide for it is drawn a step smaller, and in a panel set one that still
#' does not fit becomes a letter with the key printed under the panels (the
#' returned data carry it as the \code{plnkey} attribute); the left margin
#' is sized from the widest tick label, so an axis title never overlaps the
#' numbers. (Session defaults: see
#' \code{\link{plotopt}} for the session defaults). Each
#' method returns the data it drew, invisibly, as a data frame.
#'
#' \describe{ \item{\code{rmbl_stock_flow}}{(\code{\link{stkflow}}) the average
#'   daily population, length of stay, people and person-days over the periods,
#'   one panel per measure in \code{what}; with an exposure, the flow and stock
#'   rates too.} \item{\code{rmbl_yoy}}{(\code{\link{yoy}}) the
#'   period-over-period percent change with its interval over the periods, the
#'   period across and the change up, groups side by side, coloured by verdict;
#'   \code{what = "value"} draws the values instead.} \item{\code{rmbl_rate},
#'   \code{rmbl_share}}{ (\code{\link{rtcalc}}, \code{\link{shrs}}) the rate or
#'   share per group with its interval.}
#'   \item{\code{rmbl_rate_change}}{(\code{\link{ratechg}}) the percent change
#'   in the rate with its interval over the periods, groups side by side.}
#'   \item{\code{rmbl_band_sensitivity}}{(\code{\link{bandsens}}) the statistic
#'   against the cap applied to the open band.}
#'   \item{\code{rmbl_drift_calibration}, \code{bricklayer_drift}}{
#'   (\code{\link{drftcal}}, \code{\link{cpsdrft}}) the false-alarm rate per
#'   column against alpha; for a drift result, \code{what = "psi"} (the default)
#'   the population stability index per column, worst first, coloured by
#'   verdict, with the warn and fail bands as dashed lines; \code{"columns"} the
#'   reference and current distributions of up to six columns (\code{cols}, or
#'   the worst), each PSI bin's term written on it; \code{"benford"} the first
#'   digits of numeric columns against Benford's law with its 95% band, and the
#'   test's verdict; \code{"ecdf"} both ECDFs with the area between them shaded;
#'   \code{"quantiles"} the current quantiles against the reference's on the
#'   identity line; \code{"fingerprint"} one spoke per column, its PSI as the
#'   distance out, with the bands as rings.}
#'   \item{\code{bricklayer_benford}}{(\code{\link{benfordtst}}) observed
#'   first-digit proportions against Benford's law.}
#'   \item{\code{bricklayer_power}}{(\code{\link{cpspwr}}) the power curve:
#'   detection rate against injected effect size, with the 0.8 line.}
#'   \item{\code{bricklayer_freq}, \code{bricklayer_missingness},
#'   \code{rmbl_region_coverage}}{(\code{\link{freqtbl}}, \code{\link{misspat}}
#'   and \code{\link{rgncov}}) horizontal bars.}
#'   \item{\code{bricklayer_outliers}}{(\code{\link{mahaoutl}}) the distance of
#'   every row, outliers marked.} \item{\code{bricklayer_correlations},
#'   \code{bricklayer_cortable}}{ (\code{\link{topcors}}, \code{\link{cortbl}})
#'   the correlation of every pair as a diverging bar.}
#'   \item{\code{bricklayer_falsification}}{(\code{\link{cpsfals}}) the
#'   permutation null distribution with the observed statistic.}
#'   \item{\code{rmbl_bounds}}{(\code{\link{pubbnd}}) each value inside its
#'   published-rounding envelope.} \item{\code{rmbl_indigenous_gap},
#'   \code{rmbl_dsr}, \code{rmbl_prevalence}}{ each group's difference or ratio,
#'   rate, percentage, odds ratio or index with its interval, for these classes
#'   and for \code{rmbl_exposure_trend} and \code{rmbl_community_index}
#'   (\code{\link{indgap}}, \code{\link{agestd}}, \code{\link{stdprev}},
#'   \code{\link{exptrnd}}, \code{\link{commidx}}); \code{what = "ratio"} draws
#'   the ratio of a gap.}
#'   \item{\code{rmbl_trc_progress}}{(\code{\link{trcprog}}) the Calls to Action
#'   completed, and the pace projected with the band its interval gives.}
#'   \item{\code{rmbl_ordinal_compare}}{(\code{\link{ordcmp}}) each group's
#'   ratings as one stacked bar, lowest rating on the left.}
#'   \item{\code{rmbl_wellness_profile}, \code{rmbl_wellness_continuum}}{
#'   wellness indicators above, distress below, each group's estimate and
#'   interval (\code{\link{welprof}}, \code{\link{mhcont}}).}
#'   \item{\code{rmbl_dual_continuum}}{(\code{\link{dualcont}}) each group on
#'   the two axes, wellness up and distress across.}
#'   \item{\code{rmbl_holistic_balance}}{(\code{\link{holbal}}) the domains as
#'   spokes and each group's levels on them, with its balance.}
#'   \item{\code{rmbl_distinctions}}{(\code{\link{dstntst}}) each group's
#'   estimate and the pooled figure, with I-squared.}
#'   \item{\code{rmbl_connection}}{(\code{\link{connassoc}}) the places on the
#'   two indicators, with their intervals; \code{xlab} and \code{ylab} name the
#'   axes (default: the indicators' column names).}
#'   \item{\code{rmbl_healing_change}}{(\code{\link{healchg}}) the change in
#'   each indicator between the periods, wellness first.}
#'   \item{\code{rmbl_profile_share}}{(\code{\link{profshr}}) each group's share
#'   of a census characteristic with its interval.} \item{\code{rmbl_crf},
#'   \code{rmbl_burden}, \code{rmbl_equity}}{and \code{rmbl_pollution_report}:
#'   in turn, the concentration-response curve with the exposure marked;
#'   baseline against attributable cases; the concentration curve of exposure
#'   over income rank; and, for a report, all three on one page
#'   (\code{\link{crfpm25}}, \code{\link{polbrdn}}, \code{\link{expconcidx}},
#'   \code{\link{vrfpol}}).} \item{\code{rmbl_footprint}}{(\code{\link{co2fp}})
#'   the CPU, memory and total emission in one unit chosen to fit, with the
#'   car-kilometre and tree-month equivalents as a caption; \dQuote{Too short to
#'   measure} when the work took no measurable time.} \item{\code{rmbl_field},
#'   \code{rmbl_particles}}{ (\code{\link{plmfld}}, \code{\link{advdif2d}},
#'   \code{\link{lagrprt}}) a concentration field as an image with contours;
#'   particle positions, with the counting grid behind them when one was given.}
#'   \item{\code{rmbl_count_trend}}{(\code{\link{cnttrnd}}) the counts with the
#'   fitted trend.} \item{\code{bricklayer_analysis}}{(\code{\link{anltab}}) the
#'   change, rates and rate change of a published table, one panel each.}
#'   \item{\code{rmbl_event_study}, \code{rmbl_staggered_att}}{
#'   (\code{\link{evstudy}}, \code{\link{stgatt}}) the effect at each period
#'   since adoption with its interval, the reference period at zero.}
#'   \item{\code{rmbl_synth}, \code{rmbl_synthdid}}{(\code{\link{synctl}},
#'   \code{\link{syndid}}) the treated unit (or mean) and its synthetic or
#'   weighted comparison over time, adoption marked.}
#'   \item{\code{rmbl_power}}{(\code{\link{plnpwr}}) power against effect size,
#'   with the 0.8 line and the minimum detectable effect.}
#'   \item{\code{rmbl_prevalence}}{(\code{\link{stdprev}}) each group's
#'   age-standardised prevalence with its interval.}
#'   \item{\code{rmbl_census_cwb}}{(\code{\link{cnscwb}}) the Community
#'   Well-Being index, or one \code{component}, by place, one colour per group.}
#'   \item{\code{rmbl_balance}}{(\code{\link{baltab}}) a love plot: each
#'   covariate's absolute standardised difference against the \code{threshold}
#'   line, with a second table (\code{after}, after weighting or matching)
#'   beside it.} \item{\code{rmbl_aipw}}{(\code{\link{aipwcf}}) the overlap of
#'   the two groups' out-of-fold propensities (\code{type = "overlap"}) or the
#'   estimate with its interval (\code{type = "estimate"}).}
#'   \item{\code{rmbl_event_study}, \code{rmbl_staggered_att}}{also take
#'   \code{style = "stata"} (hollow points joined by a line, dashed bars) and
#'   \code{shadepost}; \code{\link{plotevgrid}} puts several in one grid.}
#'   \item{\code{rmbl_bacon}}{(\code{\link{bacondcmp}}) each two-group
#'   comparison's estimate against its weight, by type, with the two-way
#'   estimate.} \item{\code{rmbl_permutation}}{(\code{\link{perminf}}) the
#'   permuted statistics as a density (5th and 95th percentiles dashed) or
#'   histogram, the observed one in red, one panel per outcome.}
#'   \item{\code{rmbl_loo}, \code{rmbl_cohort_trends}}{(\code{\link{loounit}},
#'   \code{\link{cohtrnd}}) the leave-one-out estimates with the full-sample
#'   one; each cohort's outcome by time since adoption.}
#'   \item{\code{rmbl_case_flow}}{(\code{\link{caseflow}}) cases received and
#'   disposed, shaded where the inventory grew or fell, and the clearance rate
#'   with its interval and rolling value.}
#'   \item{\code{rmbl_life_table}}{(\code{\link{lifetbl}}) the share of cases
#'   still open at each band edge with its interval, and the median.}
#'   \item{\code{rmbl_disposition_mix}}{(\code{\link{dispmix}}) the shares of
#'   each outcome over the periods, stacked.}
#'   \item{\code{rmbl_density}}{(\code{\link{crmdens}}) the density of incidents
#'   as a heat map, with the highest-density regions outlined.}
#'   \item{\code{rmbl_knox}}{(\code{\link{knoxtst}}) the Knox ratio of each
#'   distance-by-time cell, coloured on a log scale around 1.}
#'   \item{\code{rmbl_hotspot}}{(\code{\link{hotpers}}) the share of places
#'   holding half the incidents and the overlap of hot spots with the period
#'   before, over time, and a map of the cells coloured by how often they were
#'   hot.} \item{\code{rmbl_svy_estimate},
#'   \code{rmbl_svy_compare}}{(\code{\link{svyest}}, \code{\link{svycmp}}) each
#'   domain's estimate with its interval, flagged domains marked; each
#'   difference from the reference domain with its interval.}
#'   \item{\code{rmbl_clearance_decomposition}}{(\code{\link{clrdcmp}}) the
#'   parts' rates in both comparisons with the aggregate on top, where the
#'   workload moved (coloured by whether a part clears above or below the
#'   average), and the change as a waterfall of rate and mix effects: the
#'   pictures that show a Simpson's-paradox reversal and why it happened.} }
#'
#' @param x An `rmbl_stock_flow` result.
#' @param ... Passed to the base-graphics call (\code{plot}, \code{barplot}
#'   or \code{image}). They are passed on to each panel's method for a
#'   \code{bricklayer_analysis} object.
#' @param main Title; each method has a default.
#' @param col Colours, overriding the palette.
#' @param palette A \code{\link{blpal}} name, overriding the
#'   session option.
#' @param what Depends on the class: \itemize{ \item \code{rmbl_indigenous_gap}:
#'   \code{"difference"} or \code{"ratio"}; \item \code{rmbl_stock_flow}: the
#'   measures to draw (one panel each), any of \code{"adp"}, \code{"alos"},
#'   \code{"people"}, \code{"days"}, \code{"flowrate"}, \code{"stkrate"}; \item
#'   \code{rmbl_yoy}: \code{"pctchg"} or \code{"value"}; \item
#'   \code{bricklayer_drift}: \code{"psi"}, \code{"columns"}, \code{"benford"},
#'   \code{"ecdf"}, \code{"quantiles"} or \code{"fingerprint"}; \item
#'   \code{rmbl_case_flow}: \code{"flow"} and/or \code{"clearance"}; \item
#'   \code{rmbl_clearance_decomposition}: any of \code{"rates"}, \code{"mix"}
#'   and \code{"effects"} (the default fits the device). } The 0.5.x values
#'   \code{"pct_change"}, \code{"flow_rate"} and \code{"stock_rate"} are still
#'   accepted, as is \code{"rate_change"} for \code{which}.
#' @param cols For \code{bricklayer_drift}, the columns to draw with
#'   \code{what = "columns"} or \code{"benford"}; \code{NULL} (the default)
#'   takes up to six, worst first.
#' @param warn,fail For \code{bricklayer_drift}, the PSI bands: a column is
#'   \code{warn} above the first and \code{fail} above the second (or when
#'   its test rejects at alpha). \code{NULL} takes the object's \code{bands}.
#' @param exposure For \code{rmbl_crf} and \code{rmbl_burden}, the exposure
#'   range to draw the curve over; the default runs from 0 to 1.5 times the
#'   exposure in the object.
#' @param period For \code{rmbl_rate}, a \code{by} column holding the period:
#'   the rate is drawn over time with its interval band, one panel per group of
#'   the other \code{by} columns.
#' @param which For \code{bricklayer_analysis}, the panels: any of
#'   \code{"change"}, \code{"rates"}, \code{"ratechg"}; \code{NULL} draws
#'   every panel the analysis has.
#' @param contours Number of contour lines over a field image (0 for none).
#' @param xlab For the plots over time (\code{rmbl_stock_flow}, \code{rmbl_yoy},
#'   \code{rmbl_rate_change}, \code{rmbl_count_trend}, \code{rmbl_event_study},
#'   and \code{rmbl_rate} with \code{period}), the title of the period axis. The
#'   default \code{NULL} names the unit the period implies: \code{"Date"} for
#'   dates, \code{"Time"} for date-times, \code{"Fiscal year"} for fiscal-year
#'   labels such as \code{"2022/23"}, \code{"Periods since adoption"} for an
#'   event study, otherwise \code{"Period"}. A number or a date is drawn on its
#'   own continuous scale, so a missing period leaves its gap; any other period
#'   (text, a factor) is drawn at evenly spaced positions labelled with its
#'   text.
#' @param gaps For \code{rmbl_yoy} (\code{what = "value"}) and
#'   \code{rmbl_event_study} (\code{style = "stata"}): how a missing value
#'   shows in a line. \code{"break"} (the default) breaks the
#'   line there, so a \dQuote{no data} period that \code{yoy(complete = TRUE)}
#'   inserted is a visible gap; \code{"join"} draws the line straight over it.
#' @return The data drawn, invisibly. For the plots over time the frame
#'   carries the x position of each point drawn: an \code{at} column
#'   (\code{rmbl_yoy}, \code{rmbl_rate_change}), or an \code{"at"} attribute
#'   (\code{rmbl_stock_flow}).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' sf <- stkflow(
#'   days = c(13500, 14600, 15100),
#'   people = c(300, 320, 310),
#'   prd = 2021:2023
#' )
#' plot(sf)
#' plot(sf, what = "alos", col = "firebrick", main = "Length of stay")
#' y <- yoy(
#'   data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)),
#'   value = "n",
#'   prd = "year"
#' )
#' plot(y)
#' # small counts: each percentage carries its exact interval
#' plot(yoy(
#'   data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)),
#'   value = "n",
#'   prd = "year"
#' ))
#' plot(benfordtst(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9)))
#' plot(crfno2(25))
#' plot(co2fp(
#'   for (i in 1:20) {
#'     sum(sqrt(seq_len(2e5)))
#'   },
#'   loc = "CA",
#'   cpupwrw = 45,
#'   memgb = 8
#' ))
#' # the courts and crime data shipped with the package
#' ext <- function(f) {
#'   read.csv(system.file("extdata", f, package = "rmoriebricklayer"))
#' }
#' fl <- ext("ocj_flow_ontario.csv")
#' plot(caseflow(fl$received, fl$disposed, pend = fl$pending, prd = fl$month))
#' td <- ext("ocj_time_to_disposition.csv")
#' open <- unlist(td[nrow(td), 2:5]) * fl$disposed[nrow(fl)]
#' plot(lifetbl(c(0, 10, 15, 18, Inf), open))
#' dm <- ext("ocj_dispositions.csv")
#' plot(dispmix(dm[, -(1:2)], prd = dm$year))
#' og <- ext("ocj_offence_groups.csv")
#' og <- og[og$year %in% c(2014, 2022), ]
#' plot(clrdcmp(og$disposed, og$received, og$offence_group, og$year))
#' be <- ext("tps_break_enter_d14_2024.csv")
#' be <- be[!is.na(be$lon), ]
#' plot(crmdens(be$lon, be$lat, ngrid = 60))
#' plot(knoxtst(
#'   be$lon,
#'   be$lat,
#'   as.Date(be$occ_date),
#'   c(100, 200, 400),
#'   c(7, 14, 28),
#'   nsim = 99,
#'   seed = 1
#' ))
#' plot(hotpers(be$lon, be$lat, quarters(as.Date(be$occ_date)), cell = 0.3))
#' # rates, shares and the change in a rate
#' rt <- data.frame(
#'   division = rep(c("n", "e", "w"), 2),
#'   year = rep(2022:2023, each = 3),
#'   stops = c(120, 90, 60, 150, 85, 70),
#'   residents = rep(c(1e4, 8e3, 5e3), 2)
#' )
#' r23 <- rt[rt$year == 2023, ]
#' plot(rtcalc(r23, count = "stops", pop = "residents", by = "division"))
#' plot(shrs(r23, count = "stops", by = "division"))
#' plot(ratechg(
#'   rt,
#'   count = "stops",
#'   pop = "residents",
#'   prd = "year",
#'   by = "division"
#' ))
#' # a rate over time, one panel per group
#' plot(
#'   rtcalc(rt, count = "stops", pop = "residents", by = c("division", "year")),
#'   period = "year"
#' )
#' # complex survey estimates by domain, and the differences between domains
#' set.seed(3)
#' sv <- data.frame(
#'   region = rep(c("north", "south", "east"), length.out = 300),
#'   smoker = rbinom(300, 1, 0.25),
#'   w = runif(300, 50, 150)
#' )
#' sd <- svydes(sv, w = "w", strata = "region")
#' plot(svyest(
#'   sd,
#'   sv,
#'   "smoker",
#'   by = "region",
#'   stat = "proportion",
#'   lvls = "1"
#' ))
#' plot(svycmp(
#'   sd,
#'   sv,
#'   "smoker",
#'   by = "region",
#'   stat = "proportion",
#'   lvls = "1"
#' ))
#' # a published table in one call: change, rates and rate change
#' tab <- data.frame(
#'   year = rep(2020:2023, each = 2),
#'   g = rep(c("a", "b"), 4),
#'   n = c(10, 20, 12, 22, 11, 25, 15, 24),
#'   pop = rep(c(1000, 2000), 4)
#' )
#' plot(anltab(tab, value = "n", prd = "year", by = "g", pop = "pop"))
#' plot(cnttrnd(c(21000, 23000, 22000, 25000, 24000)))
#' # banded tables
#' plot(bandsens(
#'   prsbands(c("0-17", "18-24", "25-44", "45+")),
#'   c(10, 20, 30, 40),
#'   caps = c(60, 70, 80, 90)
#' ))
#' plot(pubbnd(c(10, 20), rnd = 5))
#' plot(rgncov(c("a", "b", "c"), c(100, 200, 300), c(1L, 0L, 2L)))
#' # drift between two extracts, and how often the test cries wolf
#' set.seed(1)
#' dd <- data.frame(a = rnorm(400), b = sample(letters[1:3], 400, TRUE))
#' dr <- cpsdrft(dd, transform(dd, a = a + 3))
#' plot(dr)
#' plot(dr, what = "columns")
#' plot(dr, what = "benford", warn = 0.05, fail = 0.2)
#' plot(dr, what = "ecdf")
#' plot(dr, what = "quantiles")
#' plot(dr, what = "fingerprint")
#' plot(drftcal(dd, n = 20L))
#' # describing a table
#' plot(freqtbl(data.frame(g = c("a", "b", "b", "c", "c", "c")), "g"))
#' plot(misspat(data.frame(a = c(1, NA, 3, NA), b = c(NA, NA, 1, 2))))
#' hw <- data.frame(h = rnorm(100), w = rnorm(100))
#' hw$h[1] <- 15
#' plot(mahaoutl(hw))
#' sq <- data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20))
#' plot(topcors(sq))
#' plot(cortbl(sq))
#' # power and falsification of a statistic
#' xy <- data.frame(x = rnorm(60), y = rnorm(60))
#' shift <- function(z, s) {
#'   z$y <- z$y + s * z$x
#'   z
#' }
#' plot(cpspwr(
#'   xy,
#'   function(z) cor(z$x, z$y),
#'   inject = shift,
#'   trt = "x",
#'   sizes = c(0, 0.25, 0.5),
#'   n = 19,
#'   reps = 3,
#'   seed = 1
#' ))
#' plot(cpsfals(xy, function(z) cor(z$x, z$y), trt = "x", n = 29, seed = 1))
#' # air pollution: burden, equity, and the full report
#' plot(polbrdn(25, 1, 0.008, 1e6, poll = "NO2"))
#' plot(expconcidx(
#'   data.frame(exposure = c(4, 1, 8, 2), income = c(2, 1, 4, 3)),
#'   "exposure",
#'   "income"
#' ))
#' plot(vrfpol("no2", demo = TRUE))
#' plot(lagrprt(
#'   200,
#'   0,
#'   0,
#'   1,
#'   0.5,
#'   1,
#'   1,
#'   1,
#'   20,
#'   grid = c(-10, 40, -15, 25, 10, 8)
#' ))
#' plot(plmfld(
#'   q = 100,
#'   u = 5,
#'   h = 50,
#'   x = seq(100, 2000, by = 100),
#'   y = seq(-300, 300, by = 50)
#' ))
#' @name plot-methods
#' @aliases plot.rmbl_stock_flow
#' @srrstats {TS5.1} Stock-flow, yoy, rate-change, trend and event-study plots
#'   put the period on a continuous axis (its own number or Date scale; text
#'   periods at labelled positions) titled with its unit (.bl_period_axis).
#' @srrstats {TS5.3} The period axis is titled with the unit the period implies
#'   ("Date", "Fiscal year", "Period", "Periods since adoption"), and a formal
#'   `xlab` argument overrides it.
#' @export
plot.rmbl_stock_flow <- function(
  x,
  ...,
  what = c("adp", "alos", "people", "days"),
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL
) {
  .rmbl_plot_check(x, "rmbl_stock_flow")
  avail <- intersect(
    c("adp", "alos", "people", "days", "flowrate", "stkrate"),
    names(x)
  )
  what <- .rmbl_alias_val(
    what,
    c(flow_rate = "flowrate", stock_rate = "stkrate")
  ) # 0.5.x values
  what <- .rmbl_arg(what, avail, several = TRUE)
  labs <- c(
    adp = "Average daily population",
    alos = "Average length of stay (days)",
    people = "People",
    days = "Person-days",
    flowrate = "Flow rate",
    stkrate = "Stock rate"
  )
  cols <- .bl_cols(length(what), col, palette)
  op <- graphics::par(
    las = .bl_plot_opts()$las,
    cex = .bl_plot_opts()$cex,
    bg = .bl_plot_opts()$bg,
    mar = .bl_safe_mar(c(4.2, 4.5, 3, 1))
  )
  op2 <- .bl_panels_begin(length(what))
  on.exit(graphics::par(op2), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  on.exit(graphics::par(op), add = TRUE)
  ax <- .bl_period_axis(x$period)
  for (i in seq_along(what)) {
    .bl_series_panel(
      ax,
      x[[what[i]]],
      labs[[what[i]]],
      cols[i],
      main,
      xlab,
      ...
    )
  }
  key <- .bl_panels_end()
  out <- as.data.frame(x)[c("period", what)]
  attr(out, "plnkey") <- key
  attr(out, "at") <- ax$at
  invisible(out)
}

# ---- period-over-period ------------------------------------------------------

#' @rdname plot-methods
#' @srrstats {TS5.2} The yoy and rate-change plots draw the period across and
#'   the change up, points with vertical interval bars (.bl_time_interval), as
#'   the event-study plot does.
#' @srrstats {TS5.5} `gaps = "break"` (default) breaks lines at a missing value,
#'   such as a "no data" period yoy inserted; `gaps = "join"` draws over it
#'   (.bl_line).
#' @srrstats {G2.3a} `gaps` (like `what`) is matched by .rmbl_arg(), the
#'   package's match.arg(); an unknown value is refused listing the choices
#'   (test-srr.R:245).
#' @export
plot.rmbl_yoy <- function(
  x,
  ...,
  what = c("pctchg", "value"),
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL,
  gaps = c("break", "join")
) {
  .rmbl_plot_check(x, "rmbl_yoy")
  what <- .rmbl_alias_val(what, c(pct_change = "pctchg")) # the 0.5.x value
  what <- .rmbl_arg(what)
  gaps <- .rmbl_arg(gaps)
  d <- as.data.frame(x)
  if (!any(is.finite(d$value))) {
    stop(
      .rmbl_fn(),
      "no period has a value, so there is nothing to draw",
      call. = FALSE
    )
  }
  meta <- attr(x, "yoy")
  pa <- .bl_yoy_axis(d, meta)
  grp <- pa$grp
  label <- pa$label
  ax <- pa$ax
  xlab <- xlab %||% ax$xlab
  verdict <- as.character(d$verdict)
  pc <- .bl_yoy_cols(verdict, col, palette)
  # no percentage anywhere (zero bases, or one period): the counts are drawn
  # instead, and the title says why, rather than an empty frame of notes
  if (what == "pctchg" && !any(is.finite(d$pctchg))) {
    main <- .bl_yoy_nopct_main(d, main)
    what <- "value"
  }
  if (what == "pctchg") {
    why <- .bl_yoy_why(d, ax, meta$by, grp, meta$lag)
    at <- .bl_yoy_pct(d, ax, pc$cols, why, grp, main, xlab, ...)
    invisible(data.frame(
      label = label,
      pctchg = d$pctchg,
      lower = d$pctlo,
      upper = d$pctup,
      verdict = verdict,
      at = at,
      stringsAsFactors = FALSE
    ))
  } else {
    .bl_yoy_values(d, ax, grp, pc$pal, col, palette, gaps, main, xlab, ...)
    invisible(data.frame(
      label = label,
      value = d$value,
      at = ax$at,
      stringsAsFactors = FALSE
    ))
  }
}

#' @rdname plot-methods
#' @usage \method{plot}{rmbl_rate}(x, ..., period = NULL, main = NULL,
#'   col = NULL, palette = NULL, xlab = NULL)
#' @export
#' @srrstats {EA5.5} Rate axes carry the unit from the result's metadata, for
#'   example "Rate per 100,000, with interval"; yoy percent axes say "Percent
#'   change".
plot.rmbl_rate <- function(
  x,
  ...,
  period = NULL,
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL
) {
  .rmbl_plot_check(x, "rmbl_rate")
  d <- as.data.frame(x)
  meta <- attr(x, "rate")
  if (!is.null(period)) {
    return(.bl_rate_over_time(d, meta, period, main, col, palette, xlab, ...))
  }
  label <- .bl_group_label(d, meta$by)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(
    label,
    d$rate,
    d$lower,
    d$upper,
    if (is.null(main)) sprintf("Rate %s", meta$perlbl %||% "") else main,
    sprintf("Rate %s, with interval", meta$perlbl %||% ""),
    cols,
    ...
  )
  invisible(data.frame(
    label = label,
    rate = d$rate,
    lower = d$lower,
    upper = d$upper,
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @export
plot.rmbl_share <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_share")
  d <- as.data.frame(x)
  meta <- attr(x, "share")
  label <- .bl_group_label(d, meta$by)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(
    label,
    100 * d$share,
    100 * d$lower,
    100 * d$upper,
    if (is.null(main)) "Share of the total (%)" else main,
    "Percent of the total, with interval",
    cols,
    ...
  )
  invisible(data.frame(
    label = label,
    share = d$share,
    lower = d$lower,
    upper = d$upper,
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @usage \method{plot}{rmbl_rate_change}(x, ..., main = NULL, col = NULL,
#'   palette = NULL, xlab = NULL)
#' @export
plot.rmbl_rate_change <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL
) {
  .rmbl_plot_check(x, "rmbl_rate_change")
  d <- as.data.frame(x)
  meta <- attr(x, "ratechg")
  grp <- if (length(meta$by)) .bl_group_label(d, meta$by)
  label <- as.character(d[[meta$period]])
  if (length(meta$by)) {
    label <- paste(grp, label, sep = ": ")
  }
  # the period order ratechg() was given, as plot.rmbl_yoy() uses its own
  ax <- .bl_period_axis(d[[meta$period]], prdord = meta$prdord)
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  cols <- ifelse(d$pctchg > 0, pal[3L], pal[1L])
  cols[is.na(d$pctchg)] <- pal[2L]
  if (!is.null(col)) {
    cols <- rep_len(col, nrow(d))
  }
  at <- .bl_time_interval(
    ax,
    d$pctchg,
    d$pctlo,
    d$pctup,
    if (is.null(main)) "Change in the rate (%)" else main,
    "Percent change in the rate, with interval",
    xlab %||% ax$xlab,
    cols,
    ref = 0,
    group = grp,
    ...
  )
  invisible(data.frame(
    label = label,
    pctchg = d$pctchg,
    lower = d$pctlo,
    upper = d$pctup,
    at = at,
    stringsAsFactors = FALSE
  ))
}

# ---- banded tables, drift, Benford, power ------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_band_sensitivity <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_band_sensitivity")
  d <- as.data.frame(x)
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(d$value)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$cap,
    d$value,
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Sensitivity to the open band's cap"))
  .bl_ylab("Statistic")
  .bl_xlab("Cap applied to the open band")
  .bl_grid(NULL)
  .bl_line(d$cap, d$value, cols, fill = FALSE)
  invisible(d[c("cap", "value")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_drift_calibration <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_drift_calibration")
  d <- x$columns
  # each column's false-alarm rate with its exact (Clopper-Pearson) interval
  # over the splits, and the rate at which any column flagged: bars of height 0
  # (no false alarm in 3 splits) drew an empty frame, though "0 of 3" still
  # allows a rate up to 0.71
  lab <- c(d$column, "any column")
  rate <- c(d$falsealarmrate, x$anyflag)
  k <- round(rate * x$n)
  ci <- t(vapply(
    k,
    function(ki) stats::binom.test(ki, x$n)$conf.int,
    numeric(2)
  ))
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  cols <- ifelse(ci[, 1L] > x$alpha, pal[1L], pal[3L])
  cols[length(cols)] <- "#4D4D4D"
  if (!is.null(col)) {
    cols <- rep_len(col, length(lab))
  }
  lab <- sprintf("%s (%d of %d)", lab, k, x$n)
  .bl_dot_interval(
    lab,
    rate,
    ci[, 1L],
    ci[, 2L],
    .bl_main(main, sprintf("Drift false alarms over %d random splits", x$n)),
    sprintf(
      "False-alarm rate, with exact interval (dashed: alpha %g)",
      x$alpha
    ),
    cols,
    ref = x$alpha,
    ...
  )
  invisible(data.frame(
    column = c(d$column, "any column"),
    falsealarmrate = rate,
    lower = ci[, 1L],
    upper = ci[, 2L],
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @srrstats {EA5.0} The drift plots colour each column by its verdict under the
#'   PSI bands drawn as reference lines; the same palette and verdicts as
#'   drfthtml()'s page (test-drift-plots.R).
#' @export
plot.bricklayer_drift <- function(
  x,
  ...,
  what = c("psi", "columns", "benford", "ecdf", "quantiles", "fingerprint"),
  cols = NULL,
  warn = NULL,
  fail = NULL,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_drift")
  what <- .rmbl_arg(what)
  b <- .bl_drift_bands(x, warn, fail)
  t <- .bl_drift_table(x, b$warn, b$fail)
  vc <- if (is.null(col) && is.null(palette)) {
    .BL_VERDICT_COLS
  } else {
    stats::setNames(.bl_cols(4, col, palette), names(.BL_VERDICT_COLS))
  }
  if (what == "psi") {
    return(invisible(.bl_drift_psi(x, t, b, vc, col, main, ...)))
  }
  if (what == "fingerprint") {
    return(invisible(.bl_drift_fingerprint(t, b, vc, main, ...)))
  }
  pick <- .bl_drift_pick(x, t, what, cols)
  if (!length(pick)) {
    graphics::plot.new()
    graphics::title(
      main = .bl_main(
        main,
        if (what %in% c("columns", "ecdf")) {
          "Nothing to draw: no column has binned data"
        } else {
          "Nothing to draw: no numeric column"
        }
      )
    )
    return(invisible(data.frame()))
  }
  op <- .bl_panels_begin(length(pick))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  rc <- .bl_cols(2, col, palette)
  # the Benford titles, all at one size: the size the longest needs
  ttl <- if (what == "benford") .bl_benford_titles(x, pick, main)
  drawn <- lapply(pick, function(cl) {
    .bl_drift_draw(x, t, cl, what, rc, main, ttl, cl == pick[1L], ...)
  })
  key <- .bl_panels_end()
  out <- do.call(rbind, drawn)
  attr(out, "plnkey") <- key
  invisible(out)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_benford <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_benford")
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(0, max(c(x$proportion, x$expected / x$n), na.rm = TRUE)))
  on.exit(graphics::par(op), add = TRUE)
  obs <- as.numeric(x$proportion)
  exp_ <- as.numeric(x$expected) / x$n
  mids <- .bl_barplot(
    obs,
    names.arg = 1:9,
    col = cols[1L],
    border = NA,
    labels = FALSE,
    ylim = c(0, max(c(obs, exp_), na.rm = TRUE) * 1.15),
    xlab = "First digit",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Proportion")
  .bl_title(.bl_main(
    main,
    sprintf("First digits against Benford (p = %.3g)", x$p_value)
  ))
  .bl_grid(NULL)
  .bl_line(mids, exp_, cols[2L], fill = FALSE, label = FALSE)
  graphics::legend(
    "topright",
    legend = c("observed", "Benford"),
    fill = c(cols[1L], NA),
    border = NA,
    col = c(NA, cols[2L]),
    lwd = c(NA, 2),
    bty = "n",
    cex = 0.8
  )
  invisible(data.frame(digit = 1:9, observed = obs, expected = exp_))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_power <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_power")
  d <- x$curve
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$size,
    d$rate,
    type = "n",
    ylim = c(0, 1),
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(
    main,
    sprintf("Power curve (alpha = %s)", format(x$alpha))
  ))
  .bl_ylab("Detection rate")
  .bl_xlab("Injected effect size")
  .bl_grid(NULL)
  graphics::abline(h = c(x$alpha, 0.8), col = "#8C8C8C", lty = 2)
  .bl_line(d$size, d$rate, cols)
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.bricklayer_freq <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_freq")
  if (!nrow(x)) {
    graphics::plot.new()
    graphics::title(
      main = if (is.null(main)) "Nothing to draw: no values" else main
    )
    return(invisible(x))
  }
  d <- as.data.frame(x)
  cols <- .bl_cols(
    nrow(d),
    col,
    if (is.null(palette) && is.null(col)) "sequential" else palette
  )
  if (is.null(col) && is.null(palette)) {
    cols <- rev(cols)
  }
  .bl_hbars(
    d$n,
    as.character(d$value),
    "Count",
    if (is.null(main)) "Frequency" else main,
    cols,
    ...
  )
  invisible(d[c("value", "n", "pct")])
}

#' @rdname plot-methods
#' @export
plot.bricklayer_missingness <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_missingness")
  d <- as.data.frame(x)
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_hbars(
    d$n_rows,
    as.character(d$pattern),
    "Rows",
    if (is.null(main)) "Missingness patterns" else main,
    cols,
    ...
  )
  invisible(d[c("pattern", "n_rows", "pctrows")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_region_coverage <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_region_coverage")
  d <- as.data.frame(x)
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  cols <- ifelse(d$hasunit, pal[1L], pal[3L])
  if (!is.null(col)) {
    cols <- rep_len(col, nrow(d))
  }
  .bl_hbars(
    d$popshr,
    as.character(d$region),
    "Share of population (%)",
    if (is.null(main)) "Region coverage (no units: highlighted)" else main,
    cols,
    ...
  )
  invisible(d[c("region", "popshr", "units", "hasunit")])
}

# ---- outliers, correlations, falsification, bounds ---------------------------

#' @rdname plot-methods
#' @export
plot.bricklayer_outliers <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_outliers")
  d <- as.data.frame(x)
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  cols <- ifelse(!is.na(d$outlier) & d$outlier, pal[3L], pal[1L])
  if (!is.null(col)) {
    cols <- rep_len(col, nrow(d))
  }
  op <- .bl_par(d$distance)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$row,
    d$distance,
    type = "n",
    xlab = "Row",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Mahalanobis distance")
  .bl_title(.bl_main(
    main,
    sprintf("Outliers: %d of %d rows", sum(d$outlier, na.rm = TRUE), nrow(d))
  ))
  .bl_grid(NULL)
  .bl_outlier_marks(d, cols)
  invisible(d[c("row", "distance", "outlier")])
}

#' @rdname plot-methods
#' @export
plot.bricklayer_correlations <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_correlations")
  d <- as.data.frame(x)
  label <- paste(d$x, d$y, sep = " ~ ")
  .bl_corr_bars(
    label,
    d$correlation,
    if (is.null(main)) "Strongest correlations" else main,
    col,
    palette,
    ...
  )
  invisible(data.frame(
    pair = label,
    correlation = d$correlation,
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_cortable <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_cortable")
  d <- as.data.frame(x)
  d <- d[order(-abs(d$correlation), na.last = TRUE), , drop = FALSE]
  label <- paste(d$x, d$y, sep = " ~ ")
  .bl_corr_bars(
    label,
    d$correlation,
    if (is.null(main)) {
      sprintf("Pairwise correlations (%s)", attr(x, "method") %||% "pearson")
    } else {
      main
    },
    col,
    palette,
    ...
  )
  invisible(data.frame(
    pair = label,
    correlation = d$correlation,
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_falsification <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "bricklayer_falsification")
  null <- as.numeric(x$permutation)
  null <- null[is.finite(null)]
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par()
  on.exit(graphics::par(op), add = TRUE)
  if (!length(null)) {
    graphics::plot.new()
    graphics::title(
      main = if (is.null(main)) "No finite permutation statistics" else main
    )
    return(invisible(data.frame(statistic = numeric(0))))
  }
  h <- graphics::hist(null, breaks = "FD", plot = FALSE)
  graphics::plot(
    h,
    col = NA,
    border = NA,
    xlim = range(c(null, x$observed), finite = TRUE),
    xlab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  .bl_state$plndone <- TRUE
  graphics::rect(
    h$breaks[-length(h$breaks)],
    0,
    h$breaks[-1L],
    h$counts,
    col = cols[1L],
    border = "white"
  )
  .bl_xlab("Statistic under permutation")
  .bl_title(.bl_main(
    main,
    sprintf("Permutation null (n = %d) and the observed value", length(null))
  ))
  .bl_grid(NULL)
  graphics::abline(v = x$observed, col = cols[2L], lwd = 2)
  invisible(data.frame(statistic = null, observed = x$observed))
}

#' @rdname plot-methods
#' @export
plot.rmbl_bounds <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_bounds")
  d <- as.data.frame(x)
  idx <- as.character(seq_len(nrow(d)))
  label <- if (!is.null(rownames(d)) && !identical(rownames(d), idx)) {
    rownames(d)
  } else {
    idx
  }
  cols <- .bl_cols(nrow(d), col, palette)
  .bl_dot_interval(
    label,
    d$value,
    d$lower,
    d$upper,
    if (is.null(main)) {
      "Published values and their rounding envelopes"
    } else {
      main
    },
    "Value, with the envelope the published rounding allows",
    cols,
    ...
  )
  invisible(d[c("value", "lower", "upper", "status")])
}

#' @rdname plot-methods
#' @export
plot.rmbl_crf <- function(
  x,
  ...,
  exposure = NULL,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_crf")
  d <- .bl_crf_curve(x, exposure)
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(d$rr)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$exposure,
    d$rr,
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Relative risk")
  .bl_xlab(sprintf("%s (micrograms per cubic metre)", x$pollutant))
  .bl_title(.bl_main(
    main,
    sprintf(
      "Concentration-response, %s (%s)",
      x$pollutant,
      x$extra$outcome %||% ""
    )
  ))
  .bl_grid(NULL)
  graphics::abline(v = x$refconc, col = "#8C8C8C", lty = 2)
  .bl_line(d$exposure, d$rr, cols[1L], label = FALSE, points = FALSE)
  graphics::points(
    x$expconc,
    x$rr,
    pch = 21,
    bg = cols[2L],
    col = "white",
    lwd = 2,
    cex = 2
  )
  # under the point, where the rising curve leaves room in any panel width
  graphics::text(
    x$expconc,
    x$rr,
    sprintf("RR %.3f", x$rr),
    pos = 1,
    offset = 0.9,
    cex = 0.8,
    font = 2,
    col = cols[2L]
  )
  invisible(d)
}

#' @rdname plot-methods
#' @export
plot.rmbl_burden <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_burden")
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(x$basecases, x$attrcases))
  on.exit(graphics::par(op), add = TRUE)
  vals <- c(baseline = x$basecases, attributable = x$attrcases)
  unit <- x$extra$unit %||% "cases"
  .bl_barplot(vals, col = cols, border = NA, ylab = "", main = "", ...)
  .bl_ylab(paste("Annual", unit))
  .bl_title(.bl_main(
    main,
    sprintf(
      "%s: PAF %.1f%%, %s attributable",
      x$pollutant,
      100 * x$paf,
      .bl_label(x$attrcases, 3)
    )
  ))
  .bl_grid(NULL)
  invisible(data.frame(
    quantity = names(vals),
    value = unname(vals),
    stringsAsFactors = FALSE
  ))
}

#' @rdname plot-methods
#' @export
plot.rmbl_equity <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_equity")
  cv <- x$extra$curve
  if (is.null(cv)) {
    stop(
      "this equity result carries no concentration curve (older object)",
      call. = FALSE
    )
  }
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    c(0, cv$population),
    c(0, cv$exposure),
    type = "n",
    xlim = c(0, 1),
    ylim = c(0, 1),
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Cumulative share of exposure")
  .bl_xlab("Cumulative share of people, poorest first")
  .bl_title(.bl_main(
    main,
    sprintf("Concentration curve (index %.3f)", x$concidx)
  ))
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  .bl_line(c(0, cv$population), c(0, cv$exposure), cols, label = FALSE)
  invisible(cv)
}

#' @rdname plot-methods
#' @export
plot.rmbl_pollution_report <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  # one clear error for what is not a report (a string, an empty list, an "ok"
  # without its pipeline died in 15 different ways inside the drawing; review of
  # 02a38be)
  .bl_pollution_check(x)
  if (!identical(x$status, "ok")) {
    return(invisible(.bl_pollution_failed(x, main)))
  }
  p <- x$pipeline
  n <- if (is.null(p$equity)) 2L else 3L
  op <- .bl_panels_begin(n)
  graphics::par(oma = c(2.4, 0, 2, 0))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  crf <- structure(p$crf, class = "rmbl_crf")
  d1 <- plot(crf, col = col, palette = palette, ...)
  burden <- structure(p$burden, class = "rmbl_burden")
  d2 <- plot(burden, col = col, palette = palette, ...)
  if (n == 3L) {
    plot(
      structure(p$equity, class = "rmbl_equity"),
      col = col,
      palette = palette,
      ...
    )
  }
  graphics::mtext(
    if (is.null(main)) {
      sprintf(
        "%s, %s",
        toupper(x$pollutant),
        gsub("_", " ", x$outcome, fixed = TRUE)
      )
    } else {
      main
    },
    outer = TRUE,
    cex = 1.1,
    font = 2,
    col = "#1F2430"
  )
  key <- .bl_panels_end()
  invisible(list(crf = d1, burden = d2, plnkey = key))
}

# ---- the footprint -----------------------------------------------------------

#' @rdname plot-methods
#' @export
plot.rmbl_footprint <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_footprint")
  # one quantity in one unit: the emission of the CPU, of the memory and in all,
  # in the unit that suits its size (kg, g, mg or micrograms); the everyday
  # equivalents are written under it. The three bars of g, car-metres and
  # tree-hours on one axis mixed three units, and a computation too short to
  # time drew three empty bars.
  em <- .bl_co2_parts(x)
  comp <- em$comp
  tot_kwh <- em$kwh
  gpk <- em$gpk
  sc <- .bl_co2_unit(comp)
  unit <- sc$unit
  big <- max(comp, 0)
  vals <- comp / sc$scale
  cols <- .bl_cols(3, col, palette)
  op <- .bl_par(labels = names(vals))
  on.exit(graphics::par(op), add = TRUE)
  where <- x$co2int$location %||% ""
  title <- .bl_main(
    main,
    sprintf("Emissions of the computation (%s, %s)", where, x$usagemode %||% "")
  )
  if (big <= 0) {
    return(invisible(.bl_co2_empty(x, comp, title)))
  }
  .bl_barplot(
    vals,
    horiz = TRUE,
    col = cols[seq_along(vals)],
    border = NA,
    names.arg = names(vals),
    xlab = "",
    main = "",
    ...
  )
  .bl_title(title)
  .bl_xlab(sprintf("%s CO2e", unit))
  .bl_grid(NULL, side = "x")
  .bl_co2_note(x$co2eg, tot_kwh, gpk)
  invisible(data.frame(
    quantity = names(comp),
    value = unname(comp),
    unit = "g",
    stringsAsFactors = FALSE
  ))
}

# ---- dispersion --------------------------------------------------------------

#' A Gaussian-plume concentration field on a grid
#'
#' Evaluates \code{\link{gplume}} at every point of an \code{x} by
#' \code{y} ground-level grid (or at height \code{z}) and returns the field
#' as a matrix with the axes, ready for \code{plot()}. Use it to map where the
#' plume from a single stack touches the ground, how far downwind the
#' highest concentration lies, and how wide the affected area is.
#'
#' @details
#' Every grid point \eqn{(x_i, y_j, z)} is passed to
#' \code{\link{gplume}} in one call, with the source at the origin
#' and the wind along \eqn{+x}; the field is therefore zero (or vanishingly
#' small) upwind and at \eqn{x \le 0}. The concentration is in the mass unit
#' of \code{q} per cubic metre (grams per cubic metre for \code{q} in grams
#' per second). \code{dx} and \code{dy} are the median grid spacings, used by
#' the plot method for the cell size. The cost is one plume evaluation per
#' grid point, so a 100 by 100 grid is 10,000 evaluations.
#'
#' Errors: \code{x} or \code{y} not numeric or not strictly increasing;
#' \code{z} negative; and every check of \code{\link{gplume}}
#' (\code{q}, \code{u}, \code{h}, the stability class, the setting, the
#' mixing height).
#'
#' @param q,u,h,stab,set,mixh,nimg As in
#'   \code{\link{gplume}}: emission rate (mass per second), wind
#'   speed (m/s), effective stack height (m), Pasquill class \code{"A"} to
#'   \code{"F"} (default \code{"D"}), \code{"rural"} (default) or
#'   \code{"urban"}, mixing-lid height in metres (default \code{NULL}, no
#'   lid), number of lid image pairs (default \code{3}).
#' @param x,y Numeric vectors, strictly increasing: the downwind and
#'   crosswind coordinates of the grid, in metres from the source.
#' @param z Numeric scalar, the receptor height in metres; default \code{0}
#'   (ground level).
#' @return A list of class \code{rmbl_field}: \code{field} (a numeric
#'   matrix of concentrations, rows along \code{x}, columns along
#'   \code{y}), \code{x}, \code{y}, \code{dx} and \code{dy} (median
#'   spacings, \code{NA} for a single coordinate), \code{units}
#'   (\code{"concentration"}) and \code{title} (character, used by the plot
#'   method).
#' @seealso \code{\link{gplume}}; \code{plot()} draws the field as an
#'   image with contours (see \code{\link{plot-methods}}).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' f <- plmfld(
#'   100,
#'   5,
#'   50,
#'   x = seq(100, 3000, by = 100),
#'   y = seq(-500, 500, by = 50)
#' )
#' dim(f$field)
#' plot(f)
#'
#' # where the ground-level maximum lies, downwind
#' f$x[which.max(apply(f$field, 1, max))]
#'
#' # a more unstable atmosphere brings the plume down sooner
#' fb <- plmfld(
#'   100,
#'   5,
#'   50,
#'   x = seq(100, 3000, by = 100),
#'   y = seq(-500, 500, by = 50),
#'   stab = "B"
#' )
#' fb$x[which.max(apply(fb$field, 1, max))]
#'
#' # the coordinates must increase
#' try(plmfld(100, 5, 50, x = c(300, 100), y = c(-50, 0, 50)))
#' @export
plmfld <- function(
  q,
  u,
  h,
  x,
  y,
  z = 0,
  stab = "D",
  set = "rural",
  mixh = NULL,
  nimg = 3
) {
  x <- .ad_num(x, "x", scalar = FALSE)
  y <- .ad_num(y, "y", scalar = FALSE)
  if (is.unsorted(x, strictly = TRUE) || is.unsorted(y, strictly = TRUE)) {
    stop(
      "`x` and `y` must be strictly increasing receptor coordinates",
      call. = FALSE
    )
  }
  z <- .ad_num(z, "z", min = 0)
  rc <- expand.grid(x = x, y = y)
  rc$z <- z
  v <- gplume(q, u, h, rc, stab = stab, set = set, mixh = mixh, nimg = nimg)
  structure(
    list(
      field = matrix(v, nrow = length(x), ncol = length(y)),
      x = x,
      y = y,
      dx = if (length(x) > 1L) stats::median(diff(x)) else NA_real_,
      dy = if (length(y) > 1L) stats::median(diff(y)) else NA_real_,
      units = "concentration",
      title = sprintf("Gaussian plume, class %s, h = %s m", stab, format(h))
    ),
    class = "rmbl_field"
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_field <- function(
  x,
  ...,
  contours = 8L,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_field")
  f <- x$field
  xs <- if (!is.null(x$x)) x$x else seq_len(nrow(f)) * (x$dx %||% 1)
  ys <- if (!is.null(x$y)) x$y else seq_len(ncol(f)) * (x$dy %||% 1)
  cols <- if (!is.null(col)) {
    .bl_cols(length(col), col)
  } else {
    blpal(if (is.null(palette)) "sequential" else palette, 64)
  }
  op <- .bl_par(ys)
  on.exit(graphics::par(op), add = TRUE)
  ff <- f
  ff[!is.finite(ff)] <- NA
  graphics::image(
    xs,
    ys,
    ff,
    col = cols,
    xlab = "x (m)",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, x$title %||% "Concentration field"))
  .bl_ylab("y (m)")
  if (contours > 0 && any(is.finite(ff)) && diff(range(ff, na.rm = TRUE)) > 0) {
    graphics::contour(
      xs,
      ys,
      ff,
      nlevels = contours,
      add = TRUE,
      col = "#333333",
      labcex = 0.7
    )
  }
  invisible(data.frame(
    x = rep(xs, times = length(ys)),
    y = rep(ys, each = length(xs)),
    value = as.vector(f)
  ))
}

#' @rdname plot-methods
#' @export
plot.rmbl_particles <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL
) {
  .rmbl_plot_check(x, "rmbl_particles")
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(x$y)
  on.exit(graphics::par(op), add = TRUE)
  g <- x$grid
  if (!is.null(x$concentration) && !is.null(g)) {
    .bl_particles_grid(x, g, cols, palette, main, ...)
  } else {
    graphics::plot(
      x$x,
      x$y,
      pch = 16,
      cex = 0.5,
      col = grDevices::adjustcolor(cols, 0.5),
      xlab = "x",
      ylab = "",
      main = "",
      ...
    )
    .bl_ylab("y")
    .bl_title(.bl_main(main, sprintf("%d particles", length(x$x))))
    .bl_grid(NULL)
  }
  graphics::points(
    x$mean_x,
    x$meany,
    pch = 3,
    cex = 1.5,
    lwd = 2,
    col = "#D55E00"
  )
  invisible(data.frame(x = x$x, y = x$y))
}

# ---- trend and the whole-table analysis --------------------------------------

#' @rdname plot-methods
#' @usage \method{plot}{rmbl_count_trend}(x, ..., main = NULL, col = NULL,
#'   palette = NULL, xlab = NULL)
#' @export
plot.rmbl_count_trend <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  xlab = NULL
) {
  .rmbl_plot_check(x, "rmbl_count_trend")
  d <- x$data
  if (is.null(d)) {
    stop("this trend result carries no data (older object)", call. = FALSE)
  }
  cols <- .bl_cols(2, col, palette)
  op <- .bl_par(c(0, d$y, x$fitted))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$x,
    d$y,
    type = "n",
    xlab = xlab %||% "Period",
    ylab = "",
    ylim = range(c(0, d$y, x$fitted), finite = TRUE),
    main = "",
    ...
  )
  .bl_ylab("Count")
  .bl_title(.bl_main(
    main,
    sprintf(
      "Trend: rate ratio %.3f per period (%.3f to %.3f)",
      x$rateratio,
      x$lower,
      x$upper
    )
  ))
  .bl_grid(NULL)
  graphics::lines(
    d$x,
    x$fitted,
    col = grDevices::adjustcolor(cols[2L], 0.25),
    lwd = 7
  )
  graphics::lines(d$x, x$fitted, col = cols[2L], lwd = 2.4)
  graphics::points(
    d$x,
    d$y,
    pch = 21,
    bg = cols[1L],
    col = "white",
    lwd = 1.5,
    cex = 1.5
  )
  invisible(data.frame(x = d$x, y = d$y, fitted = x$fitted))
}

#' @rdname plot-methods
#' @export
plot.bricklayer_analysis <- function(x, ..., which = NULL, main = NULL) {
  .rmbl_plot_check(x, "bricklayer_analysis")
  panels <- c("change", "rates", "ratechg")
  which <- .rmbl_alias_val(which, c(rate_change = "ratechg")) # the 0.5.x value
  which <- if (is.null(which)) {
    panels
  } else {
    .rmbl_arg(which, panels, several = TRUE)
  }
  parts <- Filter(
    Negate(is.null),
    list(change = x$change, rates = x$rates, ratechg = x$ratechg)[which]
  )
  if (!length(parts)) {
    graphics::plot.new()
    graphics::title(
      main = if (is.null(main)) {
        "Nothing to draw: no rates in this analysis"
      } else {
        main
      }
    )
    return(invisible(list()))
  }
  op <- .bl_panels_begin(length(parts))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  out <- lapply(parts, plot, ..., main = main)
  attr(out, "plnkey") <- .bl_panels_end()
  invisible(out)
}

# ---- helpers for results that are plain data frames --------------------------

#' Lorenz and funnel plots
#'
#' Two plots for results that are plain data frames rather than classed
#' objects. \code{plotlrnz()} draws the Lorenz curve of a vector (or of
#' \code{\link{lorenzc}}'s output) with the Gini coefficient in the title.
#' \code{plotfnl()} draws every area's ratio of observed to expected
#' against its expected count, inside the control limits of
#' \code{\link{fnllim}}, the standard small-area funnel plot.
#' Use the Lorenz plot to show how concentrated a total is across units, and
#' the funnel plot to judge which areas' rates differ from the target by more
#' than chance would allow given their size.
#'
#' @details
#' \code{plotlrnz()}: from a numeric vector the curve is computed with
#' \code{\link{lorenzc}}, and the title carries \code{\link{ginicoef}}; a data
#' frame is used as given (sorted, with the origin added when missing) and
#' the title has no Gini. The dashed diagonal is perfect equality.
#'
#' \code{plotfnl()}: each area's ratio observed / expected is drawn
#' against its expected count. The limits are exact Poisson quantiles around
#' \code{target}, computed by \code{\link{fnllim}} at the expected
#' counts present: the widest level is drawn solid, the others dashed. A point
#' outside the widest limits is coloured and, with \code{area}, labelled.
#'
#' Errors: \code{plotlrnz()} given a data frame whose columns are not
#' cumulative shares in \eqn{[0, 1]} that never decrease, or invalid values for
#' \code{\link{lorenzc}}; \code{plotfnl()} given negative or non-finite
#' counts, an expected count of zero or less, \code{observed} and
#' \code{expected} of different lengths, \code{area} of another length,
#' \code{levels} outside (0, 1), or a \code{target} that is not one positive
#' number. Both draw on the current device.
#'
#' @param x For \code{plotlrnz()}, a numeric vector of non-negative values
#'   (one per unit), or the data frame \code{lorenzc()} returns (columns
#'   \code{population} and \code{value}).
#' @param obs,expd Numeric vectors of observed and expected counts
#'   per area, the same length; \code{observed} non-negative, \code{expected}
#'   positive.
#' @param area Optional vector of labels, one per area, drawn for the areas
#'   outside the limits. Default \code{NULL}.
#' @param lvls Numeric vector of control-limit levels strictly between 0
#'   and 1, as in \code{\link{fnllim}}; default \code{c(0.95, 0.998)}
#'   (about two and three standard deviations).
#' @param target Numeric scalar, the ratio the limits are drawn around;
#'   default \code{1} (observed equals expected).
#' @param main,col,pal,... As in \code{\link{plot-methods}}: the title,
#'   colours overriding the palette, a \code{\link{blpal}} name,
#'   and arguments passed to \code{plot()}.
#' @return The data drawn, invisibly. \code{plotlrnz()}: a data frame with
#'   \code{population} and \code{value}, starting at the origin.
#'   \code{plotfnl()}: a data frame with \code{area}, \code{observed},
#'   \code{expected}, \code{ratio} and \code{outside} (logical, outside the
#'   widest limits).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' plotlrnz(c(1, 1, 2, 3, 5, 8, 13))
#' plotfnl(obs = c(4, 20, 50, 9), expd = c(5, 22, 40, 20),
#'             area = c("a", "b", "c", "d"))
#'
#' # a funnel with one area well above expectation, around a target of 1
#' set.seed(4)
#' e <- c(5, 10, 20, 40, 80, 160)
#' o <- rpois(6, e)
#' o[5] <- 130
#' fd <- plotfnl(o, e, area = LETTERS[1:6], lvls = 0.95)
#' fd[fd$outside, ]
#'
#' # a curve from lorenz(), styled
#' plotlrnz(lorenzc(c(rep(1, 50), rep(10, 5), 200)), col = "darkred",
#'             main = "Placements per person")
#'
#' # a hand-made frame must be cumulative shares
#' try(plotlrnz(data.frame(population = c(0, 0.5, 1), value = c(0, 0.8, 0.5))))
#' @export
plotlrnz <- function(x, ..., main = NULL, col = NULL, pal = NULL) {
  d <- if (is.data.frame(x) && all(c("population", "value") %in% names(x))) {
    x
  } else {
    lorenzc(x)
  }
  g <- if (is.data.frame(x)) NA_real_ else ginicoef(x)
  if (is.data.frame(x)) {
    d <- .bl_lorenz_frame(d)
  }
  # lorenz() starts its curve at the origin; a hand-made frame may not
  if (!nrow(d) || d$population[1L] != 0 || d$value[1L] != 0) {
    d <- rbind(data.frame(population = 0, value = 0), d)
  }
  cols <- .bl_cols(1, col, pal)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    d$population,
    d$value,
    type = "n",
    xlim = c(0, 1),
    ylim = c(0, 1),
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab("Cumulative share of the total")
  .bl_xlab("Cumulative share of units, smallest first")
  .bl_title(.bl_main(
    main,
    if (is.na(g)) "Lorenz curve" else sprintf("Lorenz curve (Gini %.3f)", g)
  ))
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  .bl_line(d$population, d$value, cols, label = FALSE, points = FALSE)
  invisible(d)
}

#' @rdname plotlrnz
#' @export
plotfnl <- function(
  obs,
  expd,
  area = NULL,
  lvls = c(0.95, 0.998),
  target = 1,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  chk <- .fnl_check(obs, expd, area, lvls, target)
  obs <- chk$obs
  expd <- chk$expd
  area <- chk$area
  lim <- fnllim(sort(unique(expd)), target = target, lvls = lvls)
  ratio <- obs / expd
  .pal <- .bl_cols(
    3,
    col,
    if (is.null(pal) && is.null(col)) "diverging" else pal
  )
  out <- .fnl_outside(lim, expd, ratio)
  cols <- ifelse(out, .pal[3L], .pal[1L])
  if (!is.null(col)) {
    cols <- rep_len(col, length(ratio))
  }
  op <- .bl_par(ratio)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    expd,
    ratio,
    type = "n",
    xlab = "Expected count",
    ylab = "",
    ylim = range(c(ratio, lim$lower, lim$upper), finite = TRUE),
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Funnel plot"))
  .bl_ylab("Observed / expected")
  .bl_grid(NULL)
  graphics::abline(h = target, col = "#8C8C8C")
  .fnl_limits(lim)
  .fnl_points(expd, ratio, cols, area, out)
  invisible(data.frame(
    area = if (is.null(area)) NA_character_ else as.character(area),
    observed = obs,
    expected = expd,
    ratio = ratio,
    outside = out,
    stringsAsFactors = FALSE
  ))
}

#' Many-plot helpers: ridgelines, ECDFs, violins, hexagonal bins and
#' concentration curves
#'
#' Base-graphics plots in the house style for a numeric variable split by a
#' group, or two numeric variables: \describe{ \item{`plotrdg()`}{a ridgeline:
#' one kernel density per group, stacked with a small overlap.}
#' \item{`plotecdf()`}{the empirical distribution function of each group,
#' overlaid.} \item{`plotvln()`}{a violin per group: the mirrored density, the
#' median as a point and the interquartile range as a bar.}
#' \item{`plothex()`}{the two-dimensional density of `x` and `y` in
#' hexagonal bins, shaded by count.} \item{`plotgain()`}{cumulative-gain
#' (concentration) curves: the Lorenz curve of each group
#' ([lorenzc()]) with its Gini coefficient in the key.} } Missing and
#' non-finite values are dropped. A group of fewer than two values draws no
#' density.
#' @param x Numeric vector to plot, one value per observation.
#' @param grp Optional vector of groups, one per value of `x`.
#' @param y Numeric vector, one per value of `x` (`plothex()`).
#' @param bins Whole number, default 30: hexagons across the range of `x`.
#' @param bw Bandwidth passed to
#'   [stats::density()]: one positive number or
#'   the name of a rule (`"nrd0"`, the default, `"nrd"`, `"ucv"`, `"bcv"`,
#'   `"sj"`, `"sj-ste"`, `"sj-dpi"`).
#' @param ... Further arguments to the `plot()` call that opens each frame.
#' @param main,col,pal The title, colours overriding the palette, and a
#'   [blpal()] name.
#' @return The data drawn, invisibly: for `plotrdg()` and `plotvln()` the
#'   densities (`grp`, `x`, `y`), for `plotvln()` with the
#'   per-group `median`, `q1` and `q3` as an attribute
#'   `summary`, for `plotecdf()` the steps (`grp`, `x`,
#'   `y`), for `plothex()` the hexagon centres (`x`, `y`)
#'   and `count`, for `plotgain()` the curves (`grp`,
#'   `population`, `value`) with the Gini coefficients as an attribute
#'   `gini`.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(3)
#' x <- c(stats::rnorm(200), stats::rnorm(200, 2, 0.6))
#' g <- rep(c("before", "after"), each = 200)
#' plotrdg(x, g)
#' plotecdf(x, g)
#' plotvln(x, g)
#' plothex(x, x + stats::rnorm(400), bins = 20)
#' plotgain(stats::rexp(400), g)
#' try(plotrdg("a"))
#' @name plotmore
NULL

#' @rdname plotmore
#' @export
plotrdg <- function(
  x,
  grp = NULL,
  bw = "nrd0",
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  d <- .bl_xgrp(x, grp)
  .bl_check_bw(bw)
  lv <- levels(d$grp)
  dens <- lapply(lv, function(g) {
    v <- d$x[d$grp == g]
    if (length(v) < 2L) {
      return(NULL)
    }
    k <- stats::density(v, bw = bw)
    data.frame(grp = g, x = k$x, y = k$y, stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, dens)
  top <- max(out$y)
  cols <- .bl_cols(length(lv), col, pal)
  op <- .bl_par(labels = lv)
  on.exit(graphics::par(op), add = TRUE)
  step <- 0.7 * top
  graphics::plot(
    range(out$x),
    c(0, step * (length(lv) - 1L) + top),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL, side = "x")
  for (i in rev(seq_along(lv))) {
    s <- out[out$grp == lv[i], ]
    if (!nrow(s)) {
      next
    }
    b <- step * (i - 1L)
    graphics::polygon(
      c(s$x, rev(s$x)),
      c(b + s$y, rep(b, nrow(s))),
      col = grDevices::adjustcolor(cols[i], 0.55),
      border = "white"
    )
    graphics::lines(s$x, b + s$y, col = cols[i], lwd = 1.8)
  }
  graphics::axis(2, at = step * (seq_along(lv) - 1L), labels = lv, tick = FALSE)
  .bl_xlab("Value")
  .bl_title(.bl_main(main, "Distribution by group"))
  invisible(out)
}

#' @rdname plotmore
#' @export
plotecdf <- function(x, grp = NULL, ..., main = NULL, col = NULL, pal = NULL) {
  d <- .bl_xgrp(x, grp)
  lv <- levels(d$grp)
  cols <- .bl_cols(length(lv), col, pal)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    range(d$x),
    c(0, 1),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  out <- do.call(
    rbind,
    lapply(seq_along(lv), function(i) {
      v <- sort(d$x[d$grp == lv[i]])
      p <- seq_along(v) / length(v)
      graphics::lines(c(v[1L], v), c(0, p), type = "s", col = cols[i], lwd = 2)
      data.frame(grp = lv[i], x = v, y = p, stringsAsFactors = FALSE)
    })
  )
  if (length(lv) > 1L) {
    graphics::legend(
      "bottomright",
      lv,
      col = cols,
      lwd = 2,
      bty = "n",
      cex = 0.85
    )
  }
  .bl_ylab("Share at or below")
  .bl_xlab("Value")
  .bl_title(.bl_main(main, "Empirical distribution functions"))
  invisible(out)
}

#' @rdname plotmore
#' @export
plotvln <- function(
  x,
  grp = NULL,
  bw = "nrd0",
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  d <- .bl_xgrp(x, grp)
  .bl_check_bw(bw)
  lv <- levels(d$grp)
  cols <- .bl_cols(length(lv), col, pal)
  op <- .bl_par(d$x)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    c(0.5, length(lv) + 0.5),
    range(d$x),
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  out <- NULL
  sm <- NULL
  for (i in seq_along(lv)) {
    one <- .bl_violin1(d$x[d$grp == lv[i]], i, lv[i], cols[i], bw)
    sm <- rbind(sm, one$summary)
    out <- rbind(out, one$density)
  }
  graphics::axis(1, at = seq_along(lv), labels = lv, tick = FALSE)
  .bl_ylab("Value")
  .bl_title(.bl_main(main, "Violins: density, median and quartiles"))
  attr(out, "summary") <- sm
  invisible(out)
}

#' @rdname plotmore
#' @export
plothex <- function(
  x,
  y,
  bins = 30L,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  if (!is.numeric(y) || length(y) != length(x)) {
    stop("plothex: `y` must be numeric, one per value of `x`", call. = FALSE)
  }
  .bl_xgrp(x, NULL)
  ok <- is.finite(x) & is.finite(y)
  x <- as.numeric(x[ok])
  y <- as.numeric(y[ok])
  if (length(x) < 2L) {
    stop("plothex: needs at least two points with both values", call. = FALSE)
  }
  bins <- .rmbl_scalar(bins, "bins", 2, 500, integer = TRUE)
  rx <- range(x)
  ry <- range(y)
  if (diff(rx) == 0) {
    rx <- rx + c(-0.5, 0.5)
  }
  if (diff(ry) == 0) {
    ry <- ry + c(-0.5, 0.5)
  }
  out <- .bl_hexbin(x, y, bins, rx, ry)
  shades <- if (is.null(col)) {
    blpal(if (is.null(pal)) "sequential" else pal, 9L)
  } else {
    rep_len(col, 9L)
  }
  lvl <- pmin(9L, 1L + floor(8 * (out$count - 1) / max(1, max(out$count) - 1)))
  op <- .bl_par(y)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(rx, ry, type = "n", xlab = "", ylab = "", main = "", ...)
  .bl_grid(NULL)
  a <- seq(pi / 6, 2 * pi, by = pi / 3)
  hx <- cos(a) / sqrt(3) / bins * diff(rx)
  hy <- sin(a) / sqrt(3) / bins * diff(ry)
  for (i in seq_len(nrow(out))) {
    graphics::polygon(
      out$x[i] + hx,
      out$y[i] + hy,
      col = shades[lvl[i]],
      border = NA
    )
  }
  .bl_xlab("x")
  .bl_ylab("y")
  .bl_title(.bl_main(
    main,
    sprintf("Density in hexagons (most: %d)", max(out$count))
  ))
  invisible(out)
}

#' @rdname plotmore
#' @export
plotgain <- function(x, grp = NULL, ..., main = NULL, col = NULL, pal = NULL) {
  d <- .bl_xgrp(x, grp)
  if (any(d$x < 0)) {
    stop(
      "plotgain: `x` must not be negative (a share of a total)",
      call. = FALSE
    )
  }
  lv <- levels(d$grp)
  cols <- .bl_cols(length(lv), col, pal)
  curves <- .bl_gain_curves(d, lv)
  gini <- vapply(lv, function(g) ginicoef(d$x[d$grp == g]), 1)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    c(0, 1),
    c(0, 1),
    type = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
  for (i in seq_along(lv)) {
    graphics::lines(
      curves[[i]]$population,
      curves[[i]]$value,
      col = cols[i],
      lwd = 2.2
    )
  }
  graphics::legend(
    "topleft",
    sprintf("%s (Gini %.3f)", lv, gini),
    col = cols,
    lwd = 2,
    bty = "n",
    cex = 0.85
  )
  .bl_ylab("Cumulative share of the total")
  .bl_xlab("Cumulative share of units, smallest first")
  .bl_title(.bl_main(main, "Concentration curves"))
  out <- do.call(rbind, curves)
  attr(out, "gini") <- gini
  invisible(out)
}

#' Plots for many series over time
#'
#' Base-graphics plots in the house style for a value observed by period, for
#' one series or many: \describe{ \item{`plotcal()`}{a calendar heatmap of a
#' daily series: one tile per day, weeks across and weekdays down, one block per
#' year.} \item{`plothrz()`}{a horizon chart: each series in its own thin row,
#' its deviation from its own median folded into `bands` shaded bands, above in
#' blue and below in red, so many series fit in little height.}
#' \item{`plotsm()`}{small multiples: one panel per series on a shared scale.}
#' \item{`plotbump()`}{a bump chart: the rank of each series in each period (1 =
#' largest), so changes of order stand out.} }
#' @param x Dates (a `Date` or text `as.Date()` reads) for
#'   `plotcal()`.
#' @param y Numeric vector of values.
#' @param prd Vector of periods, one per value (numbers, dates or text in order
#'   of appearance).
#' @param grp Vector of series names, one per value, or `NULL` for one series.
#' @param bands Whole number, default 3: the bands of a horizon chart.
#' @param desc Logical, default `TRUE`: rank 1 is the largest value
#'   (`FALSE`: the smallest).
#' @param ... Further arguments to the `plot()` call that opens the frame.
#' @param main,col,pal The title, colours overriding the palette, and a
#'   [blpal()] name.
#' @return The data drawn, invisibly: for `plotcal()` the days (`date`,
#'   `year`, `week`, `wday`, `y`), for the others the
#'   series (`grp`, `prd`, `y`, and `rank` for
#'   `plotbump()`, `band` for `plothrz()`).
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(5)
#' days <- seq(as.Date("2024-01-01"), as.Date("2024-12-31"), by = "day")
#' plotcal(days, stats::rpois(length(days), 5 + 3 * (format(days, "%u") > "5")))
#' d <- expand.grid(
#'   year = 2015:2024,
#'   area = c("north", "south", "east", "west")
#' )
#' d$n <- stats::rpois(
#'   nrow(d),
#'   50 + 10 * as.integer(d$area) + 2 * (d$year - 2015)
#' )
#' plotsm(d$n, d$year, d$area)
#' plothrz(d$n, d$year, d$area)
#' plotbump(d$n, d$year, d$area)
#' try(plotcal("not a date", 1))
#' @name plotseries
NULL

#' @rdname plotseries
#' @export
plotcal <- function(x, y, ..., main = NULL, col = NULL, pal = NULL) {
  d <- .bl_cal_days(x, y)
  yrs <- sort(unique(d$year))
  shades <- if (is.null(col)) {
    blpal(if (is.null(pal)) "sequential" else pal, 9L)
  } else {
    rep_len(col, 9L)
  }
  r <- range(d$y, finite = TRUE)
  lvl <- ifelse(
    is.finite(d$y),
    1L + floor(8 * (d$y - r[1L]) / max(diff(r), .Machine$double.eps)),
    NA
  )
  op <- .bl_par(labels = as.character(yrs))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    c(0, 54),
    c(0, 8 * length(yrs)),
    type = "n",
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_cal_years(d, yrs, lvl, shades)
  graphics::axis(
    1,
    at = seq(0, 52, by = 13),
    labels = c("Jan", "Apr", "Jul", "Oct", "Dec"),
    tick = FALSE
  )
  .bl_title(.bl_main(
    main,
    sprintf(
      "Daily values, %s to %s",
      format(r[1L], big.mark = ","),
      format(r[2L], big.mark = ",")
    )
  ))
  invisible(d[, c("date", "year", "week", "wday", "y")])
}

#' @rdname plotseries
#' @export
plothrz <- function(
  y,
  prd,
  grp = NULL,
  bands = 3L,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  d <- .bl_series(y, prd, grp)
  bands <- .rmbl_scalar(bands, "bands", 1, 6, integer = TRUE)
  lv <- levels(d$grp)
  d$dev <- d$y -
    stats::ave(d$y, d$grp, FUN = function(v) stats::median(v, na.rm = TRUE))
  top <- max(abs(d$dev), na.rm = TRUE)
  if (!is.finite(top) || top == 0) {
    top <- 1
  }
  bw <- top / bands
  up <- blpal("sequential", bands + 1L)[-1L]
  dn <- grDevices::colorRampPalette(c("#FBD5CC", "#B2182B"))(bands)
  op <- .bl_par(labels = lv)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    range(d$pos),
    c(0, length(lv)),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  d$band <- pmin(bands, ceiling(abs(d$dev) / bw))
  .bl_horizon_rows(d, lv, bands, bw, up, dn)
  graphics::axis(
    2,
    at = length(lv) - seq_along(lv) + 0.45,
    labels = lv,
    tick = FALSE
  )
  .bl_xlab("Period")
  .bl_title(.bl_main(
    main,
    sprintf("Horizon chart: distance from each series' median, %d bands", bands)
  ))
  invisible(d[, c("grp", "prd", "y", "band")])
}

#' @rdname plotseries
#' @export
plotsm <- function(
  y,
  prd,
  grp = NULL,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  d <- .bl_series(y, prd, grp)
  lv <- levels(d$grp)
  cols <- .bl_cols(length(lv), col, pal)
  op <- .bl_panels_begin(length(lv))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  yl <- range(d$y, finite = TRUE)
  for (i in seq_along(lv)) {
    s <- d[d$grp == lv[i], ]
    graphics::par(mar = c(3, 3.6, 2.6, 0.8))
    graphics::plot(
      range(d$pos),
      yl,
      type = "n",
      xlab = "",
      ylab = "",
      main = "",
      ...
    )
    .bl_grid(NULL)
    .bl_line(s$pos, s$y, cols[i], fill = TRUE, label = FALSE)
    .bl_title(lv[i])
  }
  if (!is.null(main)) {
    graphics::mtext(main, outer = TRUE, side = 1, line = 1)
  }
  out <- d[, c("grp", "prd", "y")]
  attr(out, "plnkey") <- .bl_panels_end()
  invisible(out)
}

#' @rdname plotseries
#' @export
plotbump <- function(
  y,
  prd,
  grp,
  desc = TRUE,
  ...,
  main = NULL,
  col = NULL,
  pal = NULL
) {
  d <- .bl_series(y, prd, grp)
  desc <- .rmbl_flag1(desc, "desc")
  d$rank <- stats::ave(if (desc) -d$y else d$y, d$pos, FUN = function(v) {
    rank(v, ties.method = "min")
  })
  lv <- levels(d$grp)
  cols <- .bl_cols(length(lv), col, pal)
  op <- .bl_par(labels = lv)
  on.exit(graphics::par(op), add = TRUE)
  nr <- max(d$rank, na.rm = TRUE)
  graphics::plot(
    range(d$pos),
    c(nr + 0.5, 0.5),
    type = "n",
    yaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  graphics::axis(2, at = seq_len(nr), tick = FALSE)
  for (i in seq_along(lv)) {
    s <- d[d$grp == lv[i], ]
    graphics::lines(s$pos, s$rank, col = cols[i], lwd = 3)
    graphics::points(
      s$pos,
      s$rank,
      pch = 21,
      bg = cols[i],
      col = "white",
      cex = 1.4
    )
    last <- s[nrow(s), ]
    graphics::text(
      last$pos,
      last$rank,
      lv[i],
      pos = 4,
      xpd = NA,
      cex = 0.8,
      col = cols[i]
    )
  }
  .bl_ylab("Rank")
  .bl_xlab("Period")
  .bl_title(.bl_main(main, "Ranks over time"))
  invisible(d[, c("grp", "prd", "y", "rank")])
}

#' Returns the session plot options, the defaults overlaid with the
#' rmoriebricklayer.plot option.
#' @return A list with `palette`, `grid`, `cex`, `las`, `bg` and
#'   `panel`.
#' @noRd
.bl_plot_opts <- function() {
  d <- list(
    palette = "okabe",
    grid = TRUE,
    cex = 1,
    las = 1,
    bg = "white",
    panel = "#EEF1F6"
  )
  o <- getOption("rmoriebricklayer.plot")
  if (is.list(o)) {
    # set by hand with options(): an entry the plots cannot use keeps its
    # default rather than breaking every plot of the session
    for (nm in intersect(names(o), names(d))) {
      fine <- if (nm == "palette") {
        o[[nm]] %in% c("okabe", "diverging", "sequential", "grey")
      } else {
        !inherits(
          try(.bl_plot_opt_check(nm, o[[nm]]), silent = TRUE),
          "try-error"
        )
      }
      if (isTRUE(fine)) d[[nm]] <- o[[nm]]
    }
  }
  d
}

#' Colours for n series: `col` wins, then the palette argument, then the option
#' @param n The number of series.
#' @param col The colours the caller gave, or NULL.
#' @param palette The palette the caller gave, or NULL for the session option.
#' @return A vector of n colours.
#' @noRd
.bl_cols <- function(n, col = NULL, palette = NULL) {
  if (!is.null(col)) {
    # colours a device can draw, said here: col = "x" failed in col2rgb() or
    # plot.xy() (CRAN stress test of 0.5.14) a palette number is a whole number
    # a device can index (1e10 overflowed to -2^31 in plot.xy())
    ok <- (is.character(col) ||
      (is.numeric(col) &&
        !is.object(col) &&
        all(
          col >= 0 & col <= .Machine$integer.max & col == round(col),
          na.rm = TRUE
        ))) &&
      length(col) > 0L &&
      !anyNA(col) &&
      !inherits(
        tryCatch(grDevices::col2rgb(col, alpha = TRUE), error = function(e) e),
        "error"
      )
    if (!ok) {
      stop(
        "`col` must be colours: names such as \"steelblue\", \"#RRGGBB\" ",
        "codes or palette numbers",
        call. = FALSE
      )
    }
    return(rep_len(col, n))
  }
  blpal(if (is.null(palette)) .bl_plot_opts()$palette else palette, n)
}

#' Draws the panel and its grid lines behind the data.
#'
#' The panel behind the data: the plot region filled with the session's panel
#' colour and crossed by white grid lines, major ones along `side` (the axis
#' values are read against) and fainter ones across, with minor lines halfway
#' between. A method that has already drawn its bars (.bl_barplot) drew the
#' panel first, and the call that follows is skipped.
#' @param grid Whether to draw grid lines; NULL takes the session option.
#' @param side \code{"y"} or \code{"x"}, the axis whose values are read against
#' the major lines.
#' @return Whether grid lines were drawn, invisibly (TRUE when the call is
#'   skipped).
#' @noRd
.bl_grid <- function(grid = NULL, side = "y") {
  if (isTRUE(.bl_state$plndone)) {
    .bl_state$plndone <- FALSE
    return(invisible(TRUE))
  }
  o <- .bl_plot_opts()
  on <- if (is.null(grid)) o$grid else isTRUE(grid)
  usr <- graphics::par("usr")
  fill <- o$panel %||% NA
  if (!is.na(fill)) {
    graphics::rect(usr[1L], usr[3L], usr[2L], usr[4L], col = fill, border = NA)
  }
  if (on) {
    line <- if (is.na(fill)) "#DDDDDD" else "white"
    xt <- graphics::axTicks(1L)
    yt <- graphics::axTicks(2L)
    half <- function(t) if (length(t) > 1L) t[-1L] - diff(t) / 2 else numeric()
    if (side == "y") {
      graphics::abline(h = half(yt), col = line, lwd = 0.6)
      graphics::abline(h = yt, col = line, lwd = 1.4)
      graphics::abline(v = xt, col = line, lwd = 0.6)
    } else {
      graphics::abline(v = half(xt), col = line, lwd = 0.6)
      graphics::abline(v = xt, col = line, lwd = 1.4)
      graphics::abline(h = yt, col = line, lwd = 0.6)
    }
  }
  invisible(on)
}

#' Draws bars on the panel.
#'
#' Bars on the panel, not under it: the frame is set up with invisible bars, the
#' panel drawn, then the bars, each with a soft highlight along its leading edge
#' and its value at its end (when there are few enough bars to label). Takes
#' barplot()'s arguments; returns the midpoints.
#' @param height The bar heights.
#' @param ... Further arguments to barplot().
#' @param col The bar colours.
#' @param horiz Whether the bars are horizontal.
#' @param labels Whether each bar's value is written at its end.
#' @return The bar midpoints, invisibly.
#' @noRd
.bl_barplot <- function(height, ..., col = NULL, horiz = FALSE, labels = TRUE) {
  args <- list(...)
  args$border <- NULL
  h <- as.numeric(height)
  # room past the longest bar for its value
  lim <- if (horiz) "xlim" else "ylim"
  if (is.null(args[[lim]]) && any(is.finite(h))) {
    r <- range(c(0, h), finite = TRUE)
    args[[lim]] <- r + c(-1, 1) * 0.14 * diff(r) * c(any(h < 0), 1)
  }
  first <- utils::modifyList(
    args,
    list(col = NA, border = NA, axes = FALSE, axisnames = FALSE, horiz = horiz)
  )
  do.call(graphics::barplot, c(list(height), first))
  .bl_grid(NULL, side = if (horiz) "x" else "y")
  .bl_state$plndone <- TRUE
  mids <- do.call(
    graphics::barplot,
    c(
      list(height),
      utils::modifyList(
        args,
        list(col = col, border = NA, horiz = horiz, add = TRUE)
      )
    )
  )
  .bl_bar_sheen(mids, h, 0.5 * (args$width %||% 1), horiz)
  if (isTRUE(labels) && length(h) <= 25L) {
    .bl_bar_labels(mids, h, horiz)
  }
  invisible(mids)
}

#' Draws the sheen on each bar of .bl_barplot().
#' @param mids The bars' midpoints.
#' @param h The bars' heights.
#' @param w Half a bar's width.
#' @param horiz Whether the bars are horizontal.
#' @return NULL, invisibly.
#' @noRd
.bl_bar_sheen <- function(mids, h, w, horiz) {
  ok <- is.finite(h) & h != 0
  # the sheen: a white band fading out across the first third of each bar (none
  # when every bar is zero: rect() refuses empty coordinates beside a scalar; a
  # burden at rate 0 did not draw)
  for (k in if (any(ok)) 1:16 else integer()) {
    a <- 0.022 * (17 - k) / 4
    f0 <- (k - 1) / 40
    f1 <- k / 40
    if (horiz) {
      graphics::rect(
        0,
        mids[ok] + w - 2 * w * f1,
        h[ok],
        mids[ok] + w - 2 * w * f0,
        col = grDevices::adjustcolor("white", a),
        border = NA
      )
    } else {
      graphics::rect(
        mids[ok] - w + 2 * w * f0,
        0,
        mids[ok] - w + 2 * w * f1,
        h[ok],
        col = grDevices::adjustcolor("white", a),
        border = NA
      )
    }
  }
  invisible(NULL)
}

#' Writes each bar's value past its end, for .bl_barplot().
#' @param mids The bars' midpoints.
#' @param h The bars' heights.
#' @param horiz Whether the bars are horizontal.
#' @return NULL, invisibly.
#' @noRd
.bl_bar_labels <- function(mids, h, horiz) {
  say <- is.finite(h)
  txt <- trimws(formatC(h[say], digits = 3, format = "fg", big.mark = ","))
  if (horiz) {
    graphics::text(
      h[say],
      mids[say],
      txt,
      pos = ifelse(h[say] < 0, 2, 4),
      cex = 0.75,
      col = "#3D4350",
      xpd = NA
    )
  } else {
    graphics::text(
      mids[say],
      h[say],
      txt,
      pos = ifelse(h[say] < 0, 1, 3),
      cex = 0.75,
      col = "#3D4350",
      xpd = NA
    )
  }
  invisible(NULL)
}

#' Draws a series as a line over a soft fill.
#'
#' A series drawn as a line over a soft fill down to the axis, with haloed
#' points and its last value emphasised and labelled. gaps = \code{"break"}
#' keeps a missing value as a break in the line and its fill (a \dQuote{no data}
#' year that yoy(complete = TRUE) inserted); \code{"join"} draws over it.
#' @param x The x values.
#' @param y The y values.
#' @param col The line colour.
#' @param fill Whether to fill down to the axis.
#' @param label Whether to label the last value.
#' @param points Whether to draw the points.
#' @param gaps \code{"break"} or \code{"join"}: how a missing value is drawn.
#' @return The points the line passes through, NA where it breaks, invisibly.
#' @noRd
.bl_line <- function(
  x,
  y,
  col,
  fill = TRUE,
  label = TRUE,
  points = TRUE,
  gaps = "join"
) {
  x <- as.numeric(x)
  keep <- is.finite(x) & (gaps == "break" | is.finite(y))
  x <- x[keep]
  y <- y[keep]
  y[!is.finite(y)] <- NA
  ok <- !is.na(y)
  if (!any(ok)) {
    return(invisible(NULL))
  }
  if (fill) {
    .bl_line_fill(x, y, ok, col)
  }
  graphics::lines(x, y, col = grDevices::adjustcolor(col, 0.25), lwd = 6)
  graphics::lines(x, y, col = col, lwd = 2.4)
  drawn <- data.frame(x = x, y = y)
  .bl_line_points(x[ok], y[ok], col, points, label)
  invisible(drawn)
}

#' Fills under each unbroken run of a line, for .bl_line().
#' @param x,y The line's points, \code{y} NA at a break.
#' @param ok Which points have a value.
#' @param col The line's colour.
#' @return NULL, invisibly.
#' @noRd
.bl_line_fill <- function(x, y, ok, col) {
  usr <- graphics::par("usr")
  base <- max(usr[3L], min(0, usr[4L]))
  # one fill per unbroken run; lines() itself breaks at the NA
  for (r in split(which(ok), cumsum(!ok)[ok])) {
    if (length(r) > 1L) {
      graphics::polygon(
        c(x[r[1L]], x[r], x[r[length(r)]]),
        c(base, y[r], base),
        col = grDevices::adjustcolor(col, 0.16),
        border = NA
      )
    }
  }
  invisible(NULL)
}

#' Marks a line's points and labels its last value, for .bl_line().
#' @param x,y The points that have a value.
#' @param col The line's colour.
#' @param points Whether the points are marked.
#' @param label Whether the last value is written.
#' @return NULL, invisibly.
#' @noRd
.bl_line_points <- function(x, y, col, points, label) {
  n <- length(x)
  # a dense curve (a concentration curve over every person) is drawn as a line:
  # haloed points that close together merge into a white band
  if (points && n <= 30L) {
    graphics::points(
      x,
      y,
      pch = 21,
      bg = col,
      col = "white",
      lwd = 1.5,
      cex = 1.3
    )
    graphics::points(
      x[n],
      y[n],
      pch = 21,
      bg = col,
      col = "white",
      lwd = 2,
      cex = 2
    )
  }
  if (points && n > 30L) {
    graphics::points(
      x[n],
      y[n],
      pch = 21,
      bg = col,
      col = "white",
      lwd = 2,
      cex = 2
    )
  }
  if (label) {
    graphics::text(
      x[n],
      y[n],
      trimws(formatC(y[n], digits = 3, format = "fg", big.mark = ",")),
      pos = 3,
      offset = 0.7,
      cex = 0.8,
      font = 2,
      col = col,
      xpd = NA
    )
  }
  invisible(NULL)
}

#' Sets the graphics parameters of a single plot and returns the old ones.
#' @param y The values on the y axis, used to size the left margin.
#' @param labels The row labels, used instead of `y` to size the left margin.
#' @return The previous parameters, for `par(op)`.
#' @noRd
.bl_par <- function(y = NULL, labels = NULL) {
  o <- .bl_plot_opts()
  left <- if (is.null(y) && is.null(labels)) 4.5 else .bl_left_margin(y, labels)
  .bl_par_set(
    las = o$las,
    cex = o$cex,
    bg = o$bg,
    mar = .bl_safe_mar(c(4.2, left, 3, 1), o$cex),
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430"
  )
}

#' Sets graphics parameters and returns the values they had before.
#'
#' par(fg = ) also sets col, so the old values par() itself returned for
#' `par(fg = , col = )` held col already changed, and every plot left par("col")
#' grey (B1). The values are read first, every one, then set; par(op) restores
#' them in the order given (fg before col, mfrow before cex).
#' @param ... The parameters to set, named.
#' @param keep The names of further parameters to restore (ones a caller changes
#'   later, as panels change mar).
#' @return The previous values, a named list for `par(op)`.
#' @noRd
.bl_par_set <- function(..., keep = character()) {
  new <- list(...)
  # a panel layout resets cex (and the panels set mar): both come back too
  lay <- if (any(c("mfrow", "mfcol") %in% names(new))) c("cex", "mar")
  nm <- unique(c(names(new), keep, lay))
  op <- graphics::par(nm)
  if (length(nm) == 1L) {
    op <- stats::setNames(list(op), nm)
  }
  graphics::par(new)
  op
}

#' Draws a legend centred under the plot.
#'
#' A legend centred under the plot, `line` text lines below the plot region:
#' placed in inches, so it sits under the axis title on a short panel and a tall
#' one alike (an inset fraction of the plot's height ran into a two-line axis
#' title on one, off the device on another)
#' @param ... Arguments to legend().
#' @param line How many text lines below the plot region the legend sits.
#' @noRd
.bl_legend_below <- function(..., line = 4.8) {
  usr <- graphics::par("usr")
  pin <- graphics::par("pin")
  inch <- graphics::par("csi") * line
  y <- usr[3L] - inch / pin[2L] * (usr[4L] - usr[3L])
  x <- mean(usr[1:2])
  if (graphics::par("ylog")) {
    y <- 10^y
  }
  if (graphics::par("xlog")) {
    x <- 10^x
  }
  graphics::legend(x, y, xjust = 0.5, yjust = 1, xpd = NA, ...)
}

#' Formats numbers for a label, with thousands separators.
#' @param x The numbers.
#' @param digits The number of significant digits.
#' @return A character vector.
#' @noRd
.bl_label <- function(x, digits = 3) format(x, digits = digits, big.mark = ",")

#' The title: the caller's, or the method's default
#' @param main The caller's title, or NULL.
#' @param default The method's title.
#' @return The title.
#' @noRd
.bl_main <- function(main, default) {
  if (is.null(main)) {
    return(default)
  }
  # one title: a string or a plotmath expression
  if (
    !(is.language(main) ||
      is.expression(main) ||
      (is.character(main) && length(main) == 1L && !is.na(main)))
  ) {
    stop(
      "`main` must be one title (a string or an expression), or NULL",
      call. = FALSE
    )
  }
  main
}

#' Starts a set of panels on one device, with the grid from `.bl_panel_grid()`.
#' @param n The number of panels.
#' @return The previous graphics parameters, for `par(op)`.
#' @noRd
.bl_panels_begin <- function(n) {
  .bl_state$active <- TRUE
  .bl_state$n <- n
  .bl_state$nextlet <- 1L
  .bl_state$keys <- character()
  # mfrow resets cex, and each panel sets its own mar (B2): both are restored,
  # cex after mfrow, so par(op) leaves the device as it was
  .bl_par_set(
    mfrow = .bl_panel_grid(n),
    oma = c(2.4, 0, 0, 0),
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430",
    keep = c("cex", "mar")
  )
}

#' Chooses the rows and columns for n panels.
#'
#' Rows and columns for n panels on the device as it is: always one row squeezed
#' four panels into a 3.5-inch device, each too narrow for its tick labels. The
#' grid chosen gives each panel's plot region -- the cell less its margins
#' (about 5.5 lines across, 7.2 down, and the key's 2.4) -- the largest 4:3 box,
#' fewer rows on a tie: a wide device keeps one row, a tall one stacks.
#' @param n The number of panels.
#' @return An integer vector: rows, columns.
#' @noRd
.bl_panel_grid <- function(n) {
  din <- tryCatch(graphics::par("din"), error = function(e) c(7, 7))
  line <- 0.2 * .bl_plot_opts()$cex
  best <- c(1L, n)
  size <- -Inf
  for (r in seq_len(n)) {
    k <- ceiling(n / r)
    if (r > 1L && (r - 1L) * k >= n) {
      next
    }
    s <- min(
      din[1L] / k - 5.5 * line,
      ((din[2L] - 2.4 * line) / r - 7.2 * line) * 4 / 3
    )
    # no grid leaves room for the margins (four panels on a 3.5-inch device):
    # the squarest cells, where R's own smaller text in a 2 x 2 grid does the
    # rest
    if (s <= 0) {
      s <- -1 / min(din[1L] / k, din[2L] / r * 4 / 3)
    }
    if (s > size + 1e-9) {
      size <- s
      best <- c(r, k)
    }
  }
  as.integer(best)
}

#' Ends a set of panels and draws the key of lettered titles under them.
#' @return The key entries, invisibly.
#' @noRd
.bl_panels_end <- function() {
  keys <- .bl_state$keys
  .bl_state$active <- FALSE
  if (length(keys)) {
    .bl_panel_key(keys)
  }
  invisible(keys)
}

#' Ends a set of panels after an error.
#'
#' An error inside a panel set must not leave the next single plot titled
#' \code{"A"}
#' @return NULL, invisibly.
#' @noRd
.bl_panels_abort <- function() {
  .bl_state$active <- FALSE
  .bl_state$keys <- character()
  invisible(NULL)
}

#' Measures the width of a string in inches.
#'
#' The width of a string in inches on the open device, with a fallback before
#' any plot exists (0.55 of a character height per character)
#' @param x The strings.
#' @param cex The text size.
#' @param font The font.
#' @return The widths in inches.
#' @noRd
.bl_strwidth <- function(x, cex = 1, font = 1) {
  w <- tryCatch(
    graphics::strwidth(x, units = "inches", cex = cex, font = font),
    error = function(e) NULL
  )
  if (is.null(w) || !all(is.finite(w))) {
    w <- nchar(x) * 0.55 * graphics::par("csi") * cex
  }
  w
}

#' Draws a title that fits the current panel.
#'
#' Draw a title that fits the current panel: full size, then two smaller steps;
#' a title that still does not fit becomes a letter inside a panel set (the key
#' goes under the panels) or is wrapped onto two lines in a single plot.
#' @param title The title, drawn shrunk to fit the plot width.
#' @return The title as drawn (a letter in a panel set), invisibly.
#' @noRd
.bl_title <- function(title) {
  if (is.null(title) || !nzchar(title)) {
    return(invisible(title))
  }
  width <- graphics::par("pin")[1L] * 0.98
  for (cex in c(1.2, 1, 0.85)) {
    if (.bl_strwidth(title, cex = cex, font = 2) <= width) {
      graphics::title(main = title, cex.main = cex)
      return(invisible(title))
    }
  }
  if (isTRUE(.bl_state$active)) {
    letter <- LETTERS[((.bl_state$nextlet - 1L) %% 26L) + 1L]
    .bl_state$nextlet <- .bl_state$nextlet + 1L
    .bl_state$keys <- c(.bl_state$keys, sprintf("%s: %s", letter, title))
    graphics::title(main = letter, cex.main = 1.2)
    return(invisible(letter))
  }
  words <- strsplit(title, " ", fixed = TRUE)[[1L]]
  lines <- character()
  cur <- ""
  for (w in words) {
    cand <- if (nzchar(cur)) paste(cur, w) else w
    if (nzchar(cur) && .bl_strwidth(cand, cex = 0.85, font = 2) > width) {
      lines <- c(lines, cur)
      cur <- w
    } else {
      cur <- cand
    }
  }
  lines <- c(lines, cur)
  graphics::title(
    main = paste(utils::head(lines, 2L), collapse = "\n"),
    cex.main = 0.85
  )
  invisible(paste(lines, collapse = " "))
}

#' An axis title that fits the plot width: full size, then smaller, then two
#' lines.
#' @param xlab The axis title.
#' @return The axis title, invisibly.
#' @noRd
.bl_xlab <- function(xlab) {
  if (is.null(xlab) || !nzchar(xlab)) {
    return(invisible(xlab))
  }
  width <- graphics::par("pin")[1L] * 0.98
  for (cex in c(1, 0.85)) {
    if (.bl_strwidth(xlab, cex = cex) <= width) {
      graphics::title(xlab = xlab, cex.lab = cex)
      return(invisible(xlab))
    }
  }
  # wrapped onto two lines, a step smaller each time until both fit: keeping
  # only the first two lines cut "Percent change, with interval" to "Percent
  # change, with", and a word wider than the panel ("NO2 (micrograms per cubic
  # metre)") ran past the panel's edge
  words <- strsplit(xlab, " ", fixed = TRUE)[[1L]]
  for (cex in c(0.85, 0.75, 0.65, 0.6)) {
    lines <- character()
    cur <- ""
    for (w in words) {
      cand <- if (nzchar(cur)) paste(cur, w) else w
      if (nzchar(cur) && .bl_strwidth(cand, cex = cex) > width) {
        lines <- c(lines, cur)
        cur <- w
      } else {
        cur <- cand
      }
    }
    lines <- c(lines, cur)
    if (length(lines) <= 2L && all(.bl_strwidth(lines, cex = cex) <= width)) {
      break
    }
  }
  graphics::title(
    xlab = paste(lines, collapse = "\n"),
    cex.lab = cex,
    line = 3.2
  )
  invisible(xlab)
}

#' Draws the y-axis title outside the tick labels.
#'
#' The y-axis title, placed outside the tick labels actually drawn. plot()'s
#' fixed line 3 sits inside a five-digit tick label (\code{"25000"}), so the two
#' overprinted; the line is now the measured label width plus a gap, kept inside
#' the margin, and the title is fitted to the plot height.
#' @param ylab The axis title.
#' @return The axis title, invisibly; NULL when there is no room for it.
#' @noRd
.bl_ylab <- function(ylab) {
  if (is.null(ylab) || !nzchar(ylab)) {
    return(invisible(ylab))
  }
  op <- graphics::par(c("cex.axis", "csi", "mar", "mgp", "pin", "las"))
  at <- graphics::axTicks(2)
  labs <- if (isTRUE(graphics::par("ylog"))) {
    format(at)
  } else {
    format(at, trim = TRUE)
  }
  # strwidth() scales its cex by par("cex"), as axis() and title() scale theirs,
  # so the relative sizes are passed as they are
  w <- if (op$las %in% c(1, 2)) {
    max(.bl_strwidth(labs, cex = op$cex.axis), 0)
  } else {
    graphics::strheight("0", units = "inches", cex = op$cex.axis)
  }
  need <- op$mgp[2L] + w / op$csi + 0.7
  # no room outside the tick labels (a panel on a small device, where the
  # margins were scaled down): leave the title off rather than print it over the
  # labels; each panel's own title names what is plotted
  if (need + 0.8 > op$mar[2L]) {
    return(invisible(NULL))
  }
  line <- need
  height <- op$pin[2L] * 0.98
  # full size, smaller, then cut with an ellipsis: a title longer than the plot
  # is tall ran off the panel
  fit <- NULL
  for (cex in c(1, 0.85, 0.7)) {
    if (.bl_strwidth(ylab, cex = cex) <= height) {
      fit <- cex
      break
    }
  }
  if (is.null(fit)) {
    fit <- 0.7
    for (k in seq(nchar(ylab) - 1L, 6L)) {
      cut <- .bl_short_label(ylab, k)
      if (.bl_strwidth(cut, cex = fit) <= height || k == 6L) {
        ylab <- cut
        break
      }
    }
  }
  graphics::title(ylab = ylab, line = max(line, 0.2), cex.lab = fit)
  invisible(ylab)
}

#' The key under lettered panels, wrapped to the device width
#' @param keys The key entries, \dQuote{A: title} each.
#' @return The key lines drawn, invisibly.
#' @noRd
.bl_panel_key <- function(keys) {
  width <- graphics::par("din")[1L] * 0.96
  # mtext()'s cex is absolute and strwidth()'s is scaled by par("cex"), which a
  # panel grid lowers to 0.83 or 0.66: measured at 0.8 the key was drawn wider
  # than measured and ran off the device a key that wraps to more lines than the
  # outer margin holds is drawn smaller: a third line fell below the device
  room <- graphics::par("oma")[1L]
  for (cex in c(0.8, 0.7, 0.6)) {
    rel <- cex / graphics::par("cex")
    lines <- character()
    cur <- ""
    for (k in keys) {
      cand <- if (nzchar(cur)) paste(cur, k, sep = "    ") else k
      if (nzchar(cur) && .bl_strwidth(cand, cex = rel) > width) {
        lines <- c(lines, cur)
        cur <- k
      } else {
        cur <- cand
      }
    }
    lines <- c(lines, cur)
    # an outer-margin line is scaled by the panel grid's lower par("cex") and
    # the key's cex is absolute, so one line of key text takes cex / par("cex")
    # margin lines
    step <- 1.1 * cex / graphics::par("cex")
    if (length(lines) == 1L || length(lines) * step <= room - 0.2) break
  }
  for (i in seq_along(lines)) {
    graphics::mtext(
      lines[i],
      side = 1,
      outer = TRUE,
      line = (i - 1) * step,
      cex = cex,
      adj = 0,
      col = "#3D4350"
    )
  }
  invisible(lines)
}

#' Cuts long bar labels with an ellipsis.
#'
#' A bar label longer than 28 characters is cut with an ellipsis: the margin it
#' would ask for does not fit a figure (\dQuote{figure margins too large}), and
#' a label that long is not read anyway.
#' @param x The labels to shorten to `max_chars`.
#' @param max_chars The longest label kept whole (at least 8).
#' @return The labels, cut ones told apart when the cut made them equal.
#' @noRd
.bl_short_label <- function(x, max_chars = 28L) {
  x <- as.character(x)
  max_chars <- max(8L, as.integer(max_chars))
  out <- x
  long <- !is.na(x) & nchar(x) > max_chars
  out[long] <- paste0(substr(x[long], 1L, max_chars - 3L), "...")
  # distinct levels the cut made identical are told apart by what the cut
  # removed: their shared start is dropped and the end kept ("Life satisfaction
  # rating of 8, 9 or 10" and "... between 0 and 5" read "...#1" and "...#2"); a
  # number only when the ends collide too, as a 40-column missingness pattern's
  # did (review of 52a8883)
  for (lab in unique(out[!is.na(out) & duplicated(out)])) {
    w <- which(out == lab)
    orig <- unique(x[w])
    if (length(orig) < 2L) {
      next
    }
    pre <- .bl_common_start(orig)
    tail <- trimws(substring(x[w], pre + 1L))
    long <- nchar(tail) > max_chars - 3L
    tail[long] <- paste0(substr(tail[long], 1L, max_chars - 6L), "...")
    cand <- paste0("...", tail)
    if (pre > 0L && !anyDuplicated(cand)) {
      out[w] <- cand
      next
    }
    k <- match(x[w], orig)
    out[w] <- paste0(substr(x[w], 1L, max_chars - 4L - nchar(k)), "...#", k)
  }
  out
}

#' The characters the strings share at their start, back to the last space so no
#' word is split
#' @param x The strings.
#' @return The number of characters.
#' @noRd
.bl_common_start <- function(x) {
  n <- min(nchar(x))
  p <- 0L
  while (p < n && length(unique(substr(x, p + 1L, p + 1L))) == 1L) {
    p <- p + 1L
  }
  sp <- gregexpr(" ", substr(x[[1L]], 1L, p), fixed = TRUE)[[1L]]
  if (sp[[1L]] > 0L) max(sp) else p
}

#' Cuts labels to fit 45% of the figure and gives the left margin they need.
#'
#' Labels and the left margin they need, on the device as it is: a margin wider
#' than the device failed with \dQuote{figure margins too large} on a 2-3 inch
#' plot, so long labels are cut to fit. The longest cut (28 characters down to
#' 8) whose measured width fits 45% of the figure at the text size in use: the
#' margin was sized at cex 1 and floored at 4.5 lines, so cex = 2 on a 2-3 inch
#' device failed and a 4-inch plot cut labels to 14 characters it had room for
#' (review of 02a38be). The margins are then fitted to the figure by
#' .bl_safe_mar().
#' @param labels The labels.
#' @param cex The text size.
#' @return A list with `labels` and `mar`, the margin in lines.
#' @noRd
.bl_label_fit <- function(labels, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin")[1L], error = function(e) 7)
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) * cex
  room <- 0.45 * fin - csi
  fit <- NULL
  for (k in max(28L, nchar(labels), na.rm = TRUE):8) {
    cand <- .bl_short_label(labels, k)
    w <- max(.bl_strwidth(cand[!is.na(cand)], cex = cex), 0)
    fit <- list(labels = cand, w = w)
    if (w <= room) break
  }
  list(labels = fit$labels, mar = max(1, fit$w / csi + 1))
}

#' Breaks long row labels onto two lines, then cuts those that still do not fit.
#'
#' Row labels that do not fit are broken onto two lines at the space nearest
#' their middle before .bl_label_fit() cuts them: \dQuote{Crimes Against the
#' Person} read \dQuote{Crimes Against the Pe...} on a 9-inch device. Returns
#' the labels and the margin, as .bl_label_fit() does.
#' @param labels The labels.
#' @param cex The text size.
#' @return A list with `labels` and `mar`, the margin in lines.
#' @noRd
.bl_label_wrap <- function(labels, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin")[1L], error = function(e) 7)
  csi <- tryCatch(graphics::par("cin")[2L], error = function(e) 0.2) * cex
  room <- 0.45 * fin - csi
  out <- as.character(labels)
  for (i in seq_along(out)) {
    lab <- out[i]
    if (is.na(lab) || .bl_strwidth(lab, cex = cex) <= room) {
      next
    }
    sp <- gregexpr(" ", lab, fixed = TRUE)[[1L]]
    if (sp[1L] < 0) {
      next
    }
    cut <- sp[which.min(abs(sp - nchar(lab) / 2))]
    two <- c(substr(lab, 1L, cut - 1L), substr(lab, cut + 1L, nchar(lab)))
    if (max(.bl_strwidth(two, cex = cex)) <= room) {
      out[i] <- paste(two, collapse = "\n")
    }
  }
  one <- !grepl("\n", out, fixed = TRUE)
  fit <- .bl_label_fit(out[one], cex = cex)
  out[one] <- fit$labels
  w <- max(
    vapply(
      strsplit(out, "\n", fixed = TRUE),
      function(p) max(.bl_strwidth(p, cex = cex)),
      0
    ),
    0
  )
  list(labels = out, mar = max(1, w / csi + 1))
}

#' Scales margins down to fit the figure.
#'
#' Margins (in lines, as par(\code{"mar"})) scaled down so that the left and
#' right together, and the top and bottom together, take at most three quarters
#' of the figure at the text size in use: \dQuote{figure margins too large} on a
#' small device or a panel otherwise.
#' @param mar The margins in lines, as par(\code{"mar"}).
#' @param cex The text size.
#' @return The margins.
#' @noRd
.bl_safe_mar <- function(mar, cex = .bl_plot_opts()$cex) {
  fin <- tryCatch(graphics::par("fin"), error = function(e) c(7, 7))
  csi <- tryCatch(
    graphics::par("cin")[2L] * graphics::par("mex"),
    error = function(e) 0.2
  ) *
    cex
  lim_w <- 0.75 * fin[1L] / csi
  lim_h <- 0.75 * fin[2L] / csi
  if (mar[2L] + mar[4L] > lim_w) {
    mar[c(2L, 4L)] <- mar[c(2L, 4L)] * lim_w / (mar[2L] + mar[4L])
  }
  if (mar[1L] + mar[3L] > lim_h) {
    mar[c(1L, 3L)] <- mar[c(1L, 3L)] * lim_h / (mar[1L] + mar[3L])
  }
  mar
}

#' A left margin (in lines) wide enough for the tick labels of `y`, or for
#' `labels`, plus the axis title
#' @param y The values on the y axis.
#' @param labels The row labels, used instead of `y`.
#' @return The margin in lines.
#' @noRd
.bl_left_margin <- function(y = NULL, labels = NULL) {
  if (!is.null(labels)) {
    txt <- as.character(labels)
  } else {
    y <- y[is.finite(y)]
    if (!length(y)) {
      return(4.5)
    }
    txt <- format(pretty(y), trim = TRUE)
  }
  txt <- txt[!is.na(txt)]
  w <- max(.bl_strwidth(txt, cex = 0.9), 0)
  lines <- w / graphics::par("csi")
  # at most half the panel, the room .bl_label_fit() leaves for labels (a fixed
  # 14 lines clipped labels it had judged to fit on a wide panel)
  fin <- tryCatch(graphics::par("fin")[1L], error = function(e) 7)
  min(
    1.6 + lines + (if (is.null(labels)) 2.2 else 0.6),
    max(14, 0.5 * fin / graphics::par("csi"))
  )
}

#' Writes one label per row on the left.
#'
#' Row labels on the left, one per row whatever the row count: axis() leaves out
#' labels that would overlap, so 44 rows of trchlthgap() on a 4.6-inch page
#' showed 22 and the rest read as beside the wrong points. The text is sized to
#' the row height (down to 0.6) and drawn with mtext(), which drops none;
#' mtext()'s cex is absolute, so par(\code{"cex"}) is applied here.
#' @param at The row positions.
#' @param labels The labels.
#' @param cex The text size before it is fitted to the row height.
#' @return The text size used, invisibly.
#' @noRd
.bl_row_labels <- function(at, labels, cex = 0.85) {
  if (length(at) > 1L) {
    usr <- graphics::par("usr")
    pin <- graphics::par("pin")
    row_in <- min(abs(diff(sort(at)))) / (usr[4L] - usr[3L]) * pin[2L]
    line_in <- graphics::par("csi") * cex * 1.1
    # floored at 0.6 so the labels stay readable (rOpenSci EA5.0a); a taller
    # device fits more rows
    if (line_in > row_in) cex <- max(0.6, cex * row_in / line_in)
  }
  graphics::mtext(
    labels,
    side = 2,
    at = at,
    las = 1,
    line = graphics::par("mgp")[2L],
    cex = cex * graphics::par("cex"),
    col = graphics::par("col.axis")
  )
  invisible(cex)
}

#' Draws a dot and an interval per row.
#'
#' Dots with an interval per row: the chart most of the tabular results want;
#' `key` (a list with `legend` and `col`) adds a key under the panel
#' @param label The row labels.
#' @param est The point estimates, one row each.
#' @param lower The lower limits.
#' @param upper The upper limits.
#' @param main The title.
#' @param xlab The x-axis title.
#' @param cols The colours, recycled to one per row.
#' @param ref A reference value drawn as a dashed line, or NULL.
#' @param note A note written under the plot, or NULL.
#' @param key A list with `legend` and `col` for a key under the panel, or NULL.
#' @param ... Further arguments to the dot plot's plot().
#' @return NULL, invisibly.
#' @noRd
.bl_dot_interval <- function(
  label,
  est,
  lower,
  upper,
  main,
  xlab,
  cols,
  ref = NULL,
  note = NULL,
  key = NULL,
  ...
) {
  n <- length(est)
  # labels too long for 45% of the panel are shortened in the middle, not
  # clipped at the edge
  label <- .bl_label_fit(label)$labels
  op <- .bl_par(labels = label)
  on.exit(graphics::par(op), add = TRUE)
  key_cols <- .bl_key_room(key)
  rng <- .bl_value_range(c(est, lower, upper, ref))
  graphics::plot(
    est,
    seq_len(n),
    xlim = rng,
    ylim = c(0.5, n + 0.5),
    yaxt = "n",
    ylab = "",
    xlab = "",
    main = "",
    type = "n",
    ...
  )
  .bl_title(main)
  .bl_xlab(xlab)
  .bl_grid(NULL, side = "x")
  if (!is.null(ref)) {
    graphics::abline(v = ref, col = "#8C8C8C", lty = 2)
  }
  .bl_dot_marks(est, lower, upper, rep_len(cols, n))
  .bl_row_labels(seq_len(n), label)
  # a row with no estimate says why (a suppressed percentage, the first period),
  # so an empty row never reads as a missing drawing
  if (!is.null(note)) {
    .bl_row_notes(est, note)
  }
  if (!is.null(key)) {
    .bl_legend_below(
      legend = key$legend,
      col = key$col,
      pch = 19,
      ncol = key_cols,
      bty = "n",
      cex = 0.75
    )
  }
  invisible(NULL)
}

#' The range of the finite values, widened when they are all one value.
#' @param vals The values.
#' @return Two numbers; 0 to 1 when no value is finite.
#' @noRd
.bl_value_range <- function(vals) {
  vals <- vals[is.finite(vals)]
  rng <- if (length(vals)) range(vals) else c(0, 1)
  if (diff(rng) == 0) {
    rng <- rng + c(-1, 1)
  }
  rng
}

#' Makes room for a key under the panel of .bl_dot_interval().
#'
#' As many columns as the panel's width takes (an entry needs its text and
#' about half an inch for the symbol and gaps), and a bottom margin with a line
#' per row of it; a six-entry key in one row ran off the page, and the usual
#' 4.2-line margin cut it off.
#' @param key The key: a list with \code{legend} and \code{col}, or NULL.
#' @return The number of the key's columns (1 when there is no key).
#' @noRd
.bl_key_room <- function(key) {
  if (is.null(key)) {
    return(1L)
  }
  entry <- max(.bl_strwidth(key$legend, cex = 0.75)) + 0.5
  key_cols <- max(
    1L,
    min(length(key$legend), floor(graphics::par("pin")[1L] / entry))
  )
  rows <- ceiling(length(key$legend) / key_cols)
  graphics::par(
    mar = .bl_safe_mar(
      c(5.2 + 1.1 * rows, graphics::par("mar")[2L], 3, 1),
      .bl_plot_opts()$cex
    )
  )
  key_cols
}

#' Draws each row's interval and estimate, for .bl_dot_interval().
#' @param est,lower,upper The estimates and their limits.
#' @param cols One colour per row.
#' @return NULL, invisibly.
#' @noRd
.bl_dot_marks <- function(est, lower, upper, cols) {
  n <- length(est)
  ok <- is.finite(lower) & is.finite(upper)
  # no interval anywhere (every standard error NA): nothing to draw, and
  # adjustcolor() on an empty vector warned "non-empty data for zero-extent
  # matrix" (review of 29a55d8)
  if (any(ok)) {
    graphics::segments(
      lower[ok],
      seq_len(n)[ok],
      upper[ok],
      seq_len(n)[ok],
      col = grDevices::adjustcolor(cols[ok], 0.28),
      lwd = 9,
      lend = 1
    )
    graphics::segments(
      lower[ok],
      seq_len(n)[ok],
      upper[ok],
      seq_len(n)[ok],
      col = cols[ok],
      lwd = 1.6,
      lend = 1
    )
  }
  graphics::points(
    est,
    seq_len(n),
    pch = 21,
    bg = cols,
    col = "white",
    lwd = 1.6,
    cex = 1.7
  )
  invisible(NULL)
}

#' Writes the note of each row that has no estimate, for .bl_dot_interval().
#' @param est The estimates; a non-finite one shows its note.
#' @param note One note per row.
#' @return NULL, invisibly.
#' @noRd
.bl_row_notes <- function(est, note) {
  n <- length(est)
  say <- !is.finite(est) & !is.na(note) & nzchar(note) &
    !startsWith(note, "first period")
  if (any(say)) {
    # from the left edge and sized to the plot: centred on the reference line,
    # a long note ran off the panel ("othing to compare")
    usr <- graphics::par("usr")
    room <- graphics::par("pin")[1L] * 0.9
    txt <- note[say]
    cex <- min(0.8, 0.8 * room / max(.bl_strwidth(txt, cex = 0.8, font = 3)))
    # too small to read in a narrow panel: the part before the colon ("first
    # period")
    if (cex < 0.6) {
      txt <- sub(":.*$", "", txt)
      cex <- min(
        0.8,
        0.8 * room / max(.bl_strwidth(txt, cex = 0.8, font = 3))
      )
    }
    graphics::text(
      usr[1L] + 0.02 * (usr[2L] - usr[1L]),
      seq_len(n)[say],
      txt,
      col = "#6E6E6E",
      cex = cex,
      font = 3,
      adj = c(0, 0.5)
    )
  }
  invisible(NULL)
}

# The period on a time axis: a number or a Date on its own continuous scale
# (whole-number and ISO-date text, as stkflow() stores its periods, read back as
# such), anything else (fiscal-year labels, quarters, a factor) at positions
# 1..n labelled with its text; `labels` (yoylbl()'s perlbl) relabels the ticks.
# Gives the positions, the ticks with their labels, and the axis title the
# period implies.
.bl_period_axis <- function(p, labels = NULL, prdord = NULL) {
  txt <- as.character(if (is.null(labels)) p else labels)
  if (is.character(p)) {
    q <- p[!is.na(p)]
    if (all(grepl("^-?[0-9]+$", q))) {
      p <- as.numeric(p)
    } else if (all(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}$", q))) {
      p <- as.Date(p)
    }
  }
  time <- inherits(p, c("Date", "POSIXt"))
  cont <- is.numeric(p) || time
  # text periods in time order, not in order of first appearance (2019/20,
  # 2021/22, 2020/21 was drawn so; pre-CRAN audit of 30bed8e): a factor by its
  # levels, text by .bl_period_order()
  key <- as.character(p)
  lev <- if (is.factor(p)) {
    levels(p)
  } else {
    .bl_period_order(unique(key[!is.na(key)]), prdord)
  }
  at <- if (cont) as.numeric(p) else match(key, lev[lev %in% key])
  first <- !duplicated(at)
  t <- stats::na.omit(txt)
  fiscal <- length(t) > 0L && all(grepl("^[0-9]{4}[/-][0-9]{2}([0-9]{2})?$", t))
  xlab <- if (inherits(p, "Date")) {
    "Date"
  } else if (time) {
    "Time"
  } else if (fiscal) {
    "Fiscal year"
  } else {
    "Period"
  }
  u <- sort(unique(at[is.finite(at)]))
  step <- if (length(u) > 1L) min(diff(u)) else 1
  list(
    p = p,
    at = at,
    ticks = at[first],
    tlab = txt[first],
    cont = cont,
    time = time,
    xlab = xlab,
    xlim = (if (length(u)) range(u) else c(0, 1)) + c(-0.5, 0.5) * step,
    step = step
  )
}

# Text periods in time order, read as the tables read them (yoy()'s period
# reader: fiscal years "2019/20", "Q1 2022", "2022 Q1", "Mar 2021", "March
# 2021" and dates), or in the order `prdord` gives; anything the reader does
# not know is sorted. Before, only year-first labels were ordered, so a plot
# drew "Q1 2022" before "Q3 2021" while its table had them in time order.
.bl_period_order <- function(u, prdord = NULL) {
  if (!length(u)) {
    return(u)
  }
  if (!is.null(prdord)) {
    k <- match(u, prdord)
    return(u[order(is.na(k), k, u)])
  }
  p <- tryCatch(
    .yoy_prd_read(u, quiet = TRUE)$p,
    error = function(e) NULL
  )
  if (is.ordered(p) || inherits(p, "Date")) {
    return(u[order(p)])
  }
  sort(u)
}

# The period axis itself: a tick at every period when there are few (a year
# never reads "2022.5"), the usual pretty ticks along a long numeric or date
# series.
.bl_period_ticks <- function(ax) {
  if (!ax$cont || length(ax$ticks) <= 12L) {
    graphics::axis(1, at = ax$ticks, labels = ax$tlab, cex.axis = 0.8)
  } else if (ax$time) {
    graphics::Axis(ax$p, side = 1)
  } else {
    graphics::axis(1)
  }
  invisible(ax$ticks)
}

# Change over time: each period's estimate as a point with its vertical interval
# bar, the period across; several groups sit side by side within a period, each
# with its own symbol and a key. A period with no estimate carries its note (the
# part before any colon) up its slot. Returns the x position of each point.
.bl_time_interval <- function(
  ax,
  est,
  lower,
  upper,
  main,
  ylab,
  xlab,
  cols,
  ref = NULL,
  note = NULL,
  group = NULL,
  ...
) {
  op <- .bl_par(c(est, lower, upper, ref))
  on.exit(graphics::par(op), add = TRUE)
  g <- if (is.null(group)) rep(1L, length(est)) else match(group, unique(group))
  ng <- max(c(g, 1L))
  # five filled symbols, recycled past five groups
  pch <- c(21, 22, 24, 23, 25)[(g - 1L) %% 5L + 1L]
  x <- ax$at + (g - (ng + 1) / 2) * ax$step * 0.7 / ng
  vals <- c(est, lower, upper, ref)
  vals <- vals[is.finite(vals)]
  rng <- if (length(vals)) range(vals) else c(0, 1)
  if (diff(rng) == 0) {
    rng <- rng + c(-1, 1)
  }
  graphics::plot(
    ax$xlim,
    rng,
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(main)
  .bl_xlab(xlab)
  .bl_ylab(ylab)
  .bl_grid(NULL)
  if (!is.null(ref)) {
    graphics::abline(h = ref, col = "#8C8C8C", lty = 2)
  }
  .bl_time_marks(x, est, lower, upper, rep_len(cols, length(est)), pch)
  .bl_period_ticks(ax)
  if (!is.null(note)) {
    .bl_time_notes(x, est, note, ax$at)
  }
  if (ng > 1L) {
    graphics::legend(
      "topleft",
      legend = unique(group),
      pch = c(21, 22, 24, 23, 25)[(seq_len(ng) - 1L) %% 5L + 1L],
      pt.bg = "#8A909A",
      col = "white",
      bty = "n",
      cex = 0.75
    )
  }
  invisible(x)
}

#' Draws each period's interval and estimate, for .bl_time_interval().
#' @param x The points' positions on the time axis.
#' @param est,lower,upper The estimates and their limits.
#' @param cols One colour per point.
#' @param pch One symbol per point.
#' @return NULL, invisibly.
#' @noRd
.bl_time_marks <- function(x, est, lower, upper, cols, pch) {
  ok <- is.finite(lower) & is.finite(upper)
  if (any(ok)) {
    graphics::segments(
      x[ok],
      lower[ok],
      x[ok],
      upper[ok],
      col = grDevices::adjustcolor(cols[ok], 0.28),
      lwd = 9,
      lend = 1
    )
    graphics::segments(
      x[ok],
      lower[ok],
      x[ok],
      upper[ok],
      col = cols[ok],
      lwd = 1.6,
      lend = 1
    )
  }
  graphics::points(
    x,
    est,
    pch = pch,
    bg = cols,
    col = "white",
    lwd = 1.6,
    cex = 1.7
  )
  invisible(NULL)
}

#' Writes the note of each period that has no estimate, for .bl_time_interval().
#'
#' A period with no estimate says why (the first period, a zero base), so an
#' empty column never reads as a missing drawing: the whole reason, sized to
#' the panel's height, and only when that would be too small to read the part
#' before the colon ("first period").
#' @param x The points' positions on the time axis.
#' @param est The estimates; a non-finite one shows its note at its time.
#' @param note One note per point.
#' @param at Each point's period on the axis (its centre, the same for every
#'   group): a reason the groups share is written once, at the period.
#' @return NULL, invisibly.
#' @noRd
.bl_time_notes <- function(x, est, note, at = x) {
  # the first period is empty in every series, which needs no label (the
  # printed table says it once); any other reason is written once per period,
  # not once per group stacked on itself
  say <- !is.finite(est) & !is.na(note) & nzchar(note) &
    !startsWith(note, "first period")
  shared <- duplicated(paste(at, note)) | duplicated(paste(at, note),
    fromLast = TRUE)
  x <- ifelse(shared, at, x)
  say <- say & !duplicated(paste(at, note))
  if (any(say)) {
    usr <- graphics::par("usr")
    room <- graphics::par("pin")[2L] * 0.9
    txt <- note[say]
    cex <- min(0.7, 0.7 * room / max(.bl_strwidth(txt, cex = 0.7, font = 3)))
    if (cex < 0.6) {
      txt <- sub(":.*$", "", txt)
      cex <- min(0.7, 0.7 * room / max(.bl_strwidth(txt, cex = 0.7, font = 3)))
    }
    graphics::text(
      x[say],
      mean(usr[3:4]),
      txt,
      srt = 90,
      col = "#6E6E6E",
      cex = cex,
      font = 3
    )
  }
  invisible(NULL)
}

#' Draws one series over the periods, for plot.rmbl_stock_flow().
#' @param ax The period axis from .bl_period_axis().
#' @param v The series.
#' @param lab Its label.
#' @param col Its colour.
#' @param main The title, or NULL for the label.
#' @param xlab The x-axis title, or NULL for the axis's own.
#' @param ... Passed to the series panel's plot().
#' @return NULL, invisibly.
#' @noRd
.bl_series_panel <- function(ax, v, lab, col, main, xlab, ...) {
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(v), 3, 1)))
  graphics::plot(
    ax$at,
    v,
    type = "n",
    xaxt = "n",
    xlab = xlab %||% ax$xlab,
    ylab = "",
    main = "",
    ...
  )
  .bl_ylab(lab)
  .bl_title(.bl_main(main, lab))
  .bl_grid(NULL)
  .bl_line(ax$at, v, col)
  .bl_period_ticks(ax)
  invisible(NULL)
}

#' The period axis, groups and row labels of plot.rmbl_yoy().
#' @param d The year-over-year table.
#' @param meta Its period record.
#' @return A list: \code{grp}, the group of each row or NULL, \code{label},
#'   the row labels, and \code{ax}, the period axis.
#' @noRd
.bl_yoy_axis <- function(d, meta) {
  period <- if (!is.null(meta$period)) meta$period else names(d)[1L]
  by <- meta$by
  label <- as.character(d[[period]])
  grp <- if (length(by)) do.call(paste, c(d[by], sep = " / "))
  if (length(by)) {
    label <- paste(grp, label, sep = ": ")
  }
  ax <- .bl_period_axis(
    d[[period]],
    if (isTRUE(meta$perlbl) && "perlbl" %in% names(d)) d$perlbl,
    meta$prdord
  )
  list(grp = grp, label = label, ax = ax)
}

#' Draws the percentage change by period, for plot.rmbl_yoy().
#' @param d The year-over-year table.
#' @param ax The period axis.
#' @param cols One colour per row.
#' @param why Why each row has no percentage.
#' @param grp The group of each row, or NULL.
#' @param main The title, or NULL for the percentage-change default.
#' @param xlab The x-axis title.
#' @param ... Passed to the percentage-change plot().
#' @return The x position of each row.
#' @noRd
.bl_yoy_pct <- function(d, ax, cols, why, grp, main, xlab, ...) {
  .bl_time_interval(
    ax,
    d$pctchg,
    d$pctlo,
    d$pctup,
    if (is.null(main)) "Period-over-period change (%)" else main,
    "Percent change, with interval",
    xlab,
    cols,
    ref = 0,
    note = why,
    group = grp,
    ...
  )
}

#' The colours of plot.rmbl_yoy().
#' @param verdict The verdict of each row.
#' @param col,palette As in plot.rmbl_yoy().
#' @return A list: \code{pal}, the three colours, and \code{cols}, one per
#'   row.
#' @noRd
.bl_yoy_cols <- function(verdict, col, palette) {
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  # good and bad news only when a direction says which is which; "up" and "down"
  # (neutral) take the middle colour, as in print(), yoyhtml() and yoypdf()
  cols <- unname(c(
    bad = pal[1L],
    flat = pal[2L],
    good = pal[3L]
  )[.yoy_verdict_class(verdict)])
  if (!is.null(col)) {
    cols <- rep_len(col, length(verdict))
  }
  list(pal = pal, cols = cols)
}

#' The title of plot.rmbl_yoy() when no period has a percentage change.
#' @param d The year-over-year table.
#' @param main The title asked for, or NULL.
#' @return The title.
#' @noRd
.bl_yoy_nopct_main <- function(d, main) {
  if (!is.null(main)) {
    return(main)
  }
  why <- unique(stats::na.omit(as.character(d$flag)))
  why <- why[nzchar(why)]
  sprintf(
    "Counts by period (no percentage change: %s)",
    if (length(why)) paste(why, collapse = "; ") else "nothing to compare"
  )
}

#' Says why each period of plot.rmbl_yoy() has no percentage change.
#' @param d The year-over-year table.
#' @param ax The period axis from .bl_period_axis().
#' @param by The grouping columns.
#' @param grp The group of each row, or NULL.
#' @param lag The lag of the comparison, or NULL for 1.
#' @return One reason per row.
#' @noRd
.bl_yoy_why <- function(d, ax, by, grp, lag) {
  # no previous value: the first `lag` periods of a group have none to compare
  # with; a later one follows a period without data (inserted by the grid, or
  # absent), and was called "first period" too (pre-CRAN audit of 30bed8e)
  rk <- stats::ave(
    as.numeric(ax$at),
    if (length(by)) grp else rep("", nrow(d)),
    FUN = function(a) match(a, sort(unique(a)))
  )
  first <- is.na(rk) | rk <= (lag %||% 1L)
  flag <- as.character(d$flag)
  # the reasons in order of precedence: no value, then no previous value,
  # then the flag
  why <- ifelse(
    !is.na(flag) & nzchar(flag),
    paste("no percentage:", flag),
    "no percentage"
  )
  noprev <- is.na(d$previous)
  why[noprev] <- ifelse(
    first,
    "first period: nothing to compare with",
    "no data in the previous period"
  )[noprev]
  why[is.na(d$value)] <- "no data"
  why
}

#' Draws the values by period, one line per group, for plot.rmbl_yoy().
#' @param d The year-over-year table.
#' @param ax The period axis from .bl_period_axis().
#' @param grp The group of each row, or NULL.
#' @param pal The three colours.
#' @param col,palette,gaps As in plot.rmbl_yoy().
#' @param main The title, or NULL for "Value by period".
#' @param xlab The x-axis title.
#' @param ... Passed to the value plot().
#' @return NULL, invisibly.
#' @noRd
.bl_yoy_values <- function(
  d,
  ax,
  grp,
  pal,
  col,
  palette,
  gaps,
  main,
  xlab,
  ...
) {
  op <- .bl_par(d$value)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(
    ax$at,
    d$value,
    type = "n",
    xaxt = "n",
    xlab = xlab,
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Value by period"))
  .bl_ylab("Value")
  .bl_grid(NULL)
  if (length(grp)) {
    gc <- .bl_cols(length(unique(grp)), col, palette)
    for (k in seq_along(unique(grp))) {
      idx <- grp == unique(grp)[k]
      .bl_line(ax$at[idx], d$value[idx], gc[k], fill = FALSE, gaps = gaps)
    }
    graphics::legend(
      "topleft",
      legend = unique(grp),
      col = gc,
      lwd = 2,
      bty = "n",
      cex = 0.8
    )
  } else {
    .bl_line(ax$at, d$value, pal[1L], gaps = gaps)
  }
  .bl_period_ticks(ax)
  invisible(NULL)
}

# ---- rates, shares, rate change ----------------------------------------------

#' Labels each row by its grouping columns.
#' @param d The data frame whose `by` columns form the label.
#' @param by The grouping columns.
#' @return A character vector, \code{"all"} when there are no groups.
#' @noRd
.bl_group_label <- function(d, by) {
  if (!length(by)) {
    return("all")
  }
  do.call(paste, c(d[by], sep = " / "))
}

#' Draws a rate over time, one panel per group.
#'
#' A rate over time: one panel per group (the `by` columns other than `period`),
#' the rate as a line over its interval band, every panel on the same scale so
#' groups compare at a glance.
#' @param d The rate table.
#' @param meta The rate's settings, with its `by` columns.
#' @param period The `by` column that holds the period.
#' @param main The title.
#' @param col The colours the caller gave, or NULL.
#' @param palette The palette the caller gave, or NULL.
#' @param xlab The period axis title, or NULL for the one the period implies.
#' @param ... Further arguments to the rate plot().
#' @return The plotted rates as a data frame, invisibly.
#' @noRd
.bl_rate_over_time <- function(
  d,
  meta,
  period,
  main,
  col,
  palette,
  xlab = NULL,
  ...
) {
  g <- .bl_rate_groups(d, meta, period)
  groups <- unique(g)
  pv <- sort(unique(d[[period]]))
  # the period on its own scale, as the other plots over time draw it (index
  # positions before)
  ax <- .bl_period_axis(pv)
  xlab <- xlab %||% ax$xlab
  cols <- .bl_cols(length(groups), col, palette)
  ylim <- range(c(d$lower, d$upper, d$rate), finite = TRUE)
  ylim <- ylim + c(-0.04, 0.12) * diff(ylim)
  op <- .bl_panels_begin(length(groups))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  for (k in seq_along(groups)) {
    .bl_rate_panel(
      d[g == groups[k], , drop = FALSE],
      period,
      pv,
      ax,
      ylim,
      cols[k],
      groups[k],
      xlab,
      meta$perlbl,
      ...
    )
  }
  if (!is.null(main)) {
    graphics::mtext(
      main,
      side = 3,
      outer = TRUE,
      line = -1.2,
      font = 2,
      col = "#1F2430"
    )
  }
  .bl_panels_end()
  invisible(data.frame(
    group = g,
    period = d[[period]],
    rate = d$rate,
    lower = d$lower,
    upper = d$upper,
    stringsAsFactors = FALSE
  ))
}

#' The group of each row of a rate drawn over time.
#' @param d The rate table.
#' @param meta Its record, with the \code{by} columns.
#' @param period The period column, one of them.
#' @return The group of each row: the other columns joined, or "All".
#' @noRd
.bl_rate_groups <- function(d, meta, period) {
  if (!is.character(period) || length(period) != 1L || !period %in% meta$by) {
    stop("`period` must be one of the rate's `by` columns", call. = FALSE)
  }
  grp <- setdiff(meta$by, period)
  g <- if (length(grp)) {
    do.call(paste, c(d[grp], sep = " / "))
  } else {
    rep("All", nrow(d))
  }
  if (length(unique(g)) > 16L) {
    stop(
      "more than 16 groups to draw over time: filter or regroup first",
      call. = FALSE
    )
  }
  g
}

#' Draws one group's rate over time with its band, for .bl_rate_over_time().
#' @param s The group's rows.
#' @param period The period column.
#' @param pv The sorted periods.
#' @param ax The period axis from .bl_period_axis().
#' @param ylim The y-axis limits shared by the panels.
#' @param col The group's colour.
#' @param title The panel's title.
#' @param xlab The x-axis title.
#' @param perlbl The rate's unit, or NULL.
#' @param ... Passed to the rate panel's plot().
#' @return NULL, invisibly.
#' @noRd
.bl_rate_panel <- function(
  s,
  period,
  pv,
  ax,
  ylim,
  col,
  title,
  xlab,
  perlbl,
  ...
) {
  s <- s[order(match(s[[period]], pv)), , drop = FALSE]
  xs <- ax$at[match(s[[period]], pv)]
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(ylim), 3, 1)))
  graphics::plot(
    ax$xlim,
    ylim,
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "",
    main = "",
    ...
  )
  .bl_grid(NULL)
  ok <- is.finite(s$lower) & is.finite(s$upper)
  if (sum(ok) > 1L) {
    graphics::polygon(
      c(xs[ok], rev(xs[ok])),
      c(s$lower[ok], rev(s$upper[ok])),
      col = grDevices::adjustcolor(col, 0.22),
      border = NA
    )
  }
  .bl_line(xs, s$rate, col, fill = FALSE)
  .bl_period_ticks(ax)
  .bl_xlab(xlab)
  .bl_title(title)
  .bl_ylab(sprintf("Rate %s", perlbl %||% ""))
  invisible(NULL)
}

#' Draws the PSI bars of plot.bricklayer_drift().
#' @param x A drift result.
#' @param t The verdict table from .bl_drift_table().
#' @param b The warn and fail bands.
#' @param vc The verdict colours.
#' @param col The colour asked for, or NULL.
#' @param main The title, or NULL for the PSI default.
#' @param ... Passed to the bars.
#' @return The drawn columns: column, psi, p_value, verdict and drifted.
#' @noRd
.bl_drift_psi <- function(x, t, b, vc, col, main, ...) {
  t <- t[order(-xtfrm(ifelse(is.finite(t$psi), t$psi, -1))), , drop = FALSE]
  bc <- if (is.null(col)) unname(vc[t$verdict]) else rep_len(col, nrow(t))
  .bl_hbars(
    ifelse(is.finite(t$psi), t$psi, 0),
    t$column,
    "Population stability index",
    .bl_main(
      main,
      sprintf(
        "Drift by column (%d fail, %d warn)",
        sum(t$verdict == "fail"),
        sum(t$verdict == "warn")
      )
    ),
    bc,
    ref = c(b$warn, b$fail),
    ...
  )
  out <- t[c("column", "psi", "p_value", "verdict")]
  out$drifted <- x$columns$drifted[match(out$column, x$columns$column)]
  rownames(out) <- NULL
  out
}

#' Picks the columns plot.bricklayer_drift() draws a panel for.
#' @param x A drift result.
#' @param t The verdict table from .bl_drift_table().
#' @param what The kind of panel.
#' @param cols The columns asked for, or NULL for the first six that can be
#'   drawn.
#' @return The column names.
#' @noRd
.bl_drift_pick <- function(x, t, what, cols) {
  need <- c(
    columns = "bins",
    benford = "benford",
    ecdf = "bins",
    quantiles = "qq"
  )[[what]]
  have <- vapply(t$column, function(cl) !is.null(x$summ[[cl]][[need]]), NA)
  if (is.null(cols)) {
    return(utils::head(t$column[have], 6L))
  }
  if (!is.character(cols) || anyNA(cols) || !all(cols %in% x$columns$column)) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`cols` must name columns of the drift result (%s)",
        toString(utils::head(x$columns$column, 6L))
      ),
      call. = FALSE
    )
  }
  cols[cols %in% t$column[have]]
}

#' The Benford panel titles of plot.bricklayer_drift(), one per column.
#' @param x A drift result.
#' @param pick The columns drawn.
#' @param main The title, or NULL for the Benford defaults.
#' @return A named character vector.
#' @noRd
.bl_benford_titles <- function(x, pick, main) {
  vapply(
    pick,
    function(cl) {
      bf <- x$summ[[cl]]$benford
      .bl_main(
        main,
        sprintf(
          "%s: %s Benford (p %s)",
          cl,
          if (bf$p_value < x$alpha) {
            "departs from"
          } else {
            "consistent with"
          },
          sub(
            "^([0-9])",
            "= \\1",
            format.pval(bf$p_value, digits = 2, eps = 1e-16)
          )
        )
      )
    },
    "",
    USE.NAMES = TRUE
  )
}

#' Draws one column's panel of plot.bricklayer_drift().
#' @param x A drift result.
#' @param t The verdict table from .bl_drift_table().
#' @param cl The column.
#' @param what The kind of panel.
#' @param rc The two colours: before and after.
#' @param main The title, or NULL for each panel's default.
#' @param ttl The Benford titles, or NULL.
#' @param first Whether this is the first panel.
#' @param ... Passed to the panel.
#' @return The drawn values, as the panel returns them.
#' @noRd
.bl_drift_draw <- function(x, t, cl, what, rc, main, ttl, first, ...) {
  s <- x$summ[[cl]]
  v <- t$verdict[t$column == cl]
  if (what == "benford") {
    return(.bl_drift_benford_panel(
      cl,
      s$benford,
      x$alpha,
      rc,
      ttl[[cl]],
      ttl,
      first,
      ...
    ))
  }
  if (what == "ecdf") {
    return(.bl_drift_ecdf_panel(
      cl,
      s,
      x$columns$statistic[x$columns$column == cl],
      rc,
      main,
      ...
    ))
  }
  if (what == "quantiles") {
    return(.bl_drift_qq_panel(cl, s, v, rc, main, ...))
  }
  .bl_drift_column_panel(cl, s, v, rc, main, ...)
}

#' Draws one column's comparison panel: overlaid histograms (numeric) or
#' side-by-side shares (categorical), each PSI bin's term written above it.
#' @param cl The column.
#' @param s Its summary from cpsdrft().
#' @param v Its verdict.
#' @param rc The reference and current colours.
#' @param main The caller's title, or NULL.
#' @param ... Further arguments to the base call.
#' @return A data frame of the bins drawn: column, bin, ref, cur, contrib.
#' @noRd
.bl_drift_column_panel <- function(cl, s, v, rc, main, ...) {
  b <- s$bins
  ttl <- .bl_main(
    main,
    sprintf(
      "%s: %s, PSI %s",
      cl,
      v,
      formatC(sum(b$contrib), digits = 3, format = "g")
    )
  )
  if (!is.null(s$hist)) {
    .bl_drift_hist(s, rc, ttl, ...)
    .bl_drift_psi_caption(b)
  } else {
    .bl_drift_bars(b, rc, ttl, ...)
  }
  data.frame(
    column = cl,
    bin = b$bin,
    ref = b$ref,
    cur = b$cur,
    contrib = b$contrib,
    stringsAsFactors = FALSE
  )
}

#' Draws one column's ECDFs, reference and current, with the area between them
#' shaded.
#'
#' A numeric column draws its ECDFs on the 64-point grid; a categorical one its
#' cumulative shares over the categories in the reference's order. The largest
#' vertical gap is the KS statistic for a numeric column, marked.
#' @param cl The column.
#' @param s Its summary from cpsdrft().
#' @param stat Its test statistic.
#' @param rc The reference and current colours.
#' @param main The caller's title, or NULL.
#' @param ... Further arguments to the base call.
#' @return A data frame: column, x, ref, cur.
#' @noRd
.bl_drift_ecdf_panel <- function(cl, s, stat, rc, main, ...) {
  e <- if (!is.null(s$ecdf)) {
    s$ecdf
  } else {
    data.frame(
      x = seq_len(nrow(s$bins)),
      ref = cumsum(s$bins$ref),
      cur = cumsum(s$bins$cur)
    )
  }
  .bl_drift_ecdf_frame(e, s, ...)
  .bl_title(.bl_main(
    main,
    sprintf(
      "%s: largest gap %s",
      cl,
      trimws(formatC(max(abs(e$ref - e$cur)), digits = 3, format = "g"))
    )
  ))
  .bl_ylab("Share at or below")
  .bl_grid(NULL)
  graphics::polygon(
    c(e$x, rev(e$x)),
    c(e$ref, rev(e$cur)),
    col = grDevices::adjustcolor(rc[2L], 0.18),
    border = NA
  )
  graphics::lines(e$x, e$ref, type = "s", col = rc[1L], lwd = 2.4)
  graphics::lines(e$x, e$cur, type = "s", col = rc[2L], lwd = 2.4)
  k <- which.max(abs(e$ref - e$cur))
  graphics::segments(e$x[k], e$ref[k], e$x[k], e$cur[k], lwd = 2, lty = 3)
  graphics::legend(
    "bottomright",
    c("reference", "current"),
    col = rc,
    lwd = 2.4,
    bty = "n",
    cex = 0.75
  )
  data.frame(column = cl, x = e$x, ref = e$ref, cur = e$cur)
}

#' Opens the frame of an ECDF panel, with its axis, for .bl_drift_ecdf_panel().
#' @param e The two ECDFs: x, ref and cur.
#' @param s The column's summary.
#' @param ... Passed to the ECDF frame's plot().
#' @return NULL, invisibly.
#' @noRd
.bl_drift_ecdf_frame <- function(e, s, ...) {
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, 1)), 3, 1)))
  graphics::plot(
    range(e$x),
    c(0, 1),
    type = "n",
    xlab = "",
    ylab = "",
    xaxt = if (is.null(s$ecdf) || (s$kind %||% "number") != "number") {
      "n"
    } else {
      "s"
    },
    ...
  )
  if (is.null(s$ecdf)) {
    graphics::axis(1, at = e$x, labels = .bl_short_label(s$bins$bin, 10L))
  } else if ((s$kind %||% "number") != "number") {
    at <- pretty(range(e$x), n = 4L)
    graphics::axis(1, at = at, labels = .bl_drift_iso(at, s$kind))
  }
  invisible(NULL)
}

#' Draws a numeric column's matched quantiles, reference across and current up,
#' on the identity line.
#' @param cl The column.
#' @param s Its summary from cpsdrft().
#' @param v Its verdict.
#' @param rc The reference and current colours.
#' @param main The caller's title, or NULL.
#' @param ... Further arguments to the base call.
#' @return A data frame: column, p, ref, cur.
#' @noRd
.bl_drift_qq_panel <- function(cl, s, v, rc, main, ...) {
  q <- s$qq
  lim <- range(c(q$ref, q$cur))
  kind <- s$kind %||% "number"
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(lim), 3, 1)))
  graphics::plot(
    lim,
    lim,
    type = "n",
    xlab = "",
    ylab = "",
    xaxt = if (kind == "number") "s" else "n",
    yaxt = if (kind == "number") "s" else "n",
    ...
  )
  if (kind != "number") {
    at <- pretty(lim, n = 3L)
    graphics::axis(1, at = at, labels = .bl_drift_iso(at, kind))
    graphics::axis(2, at = at, labels = .bl_drift_iso(at, kind))
  }
  .bl_title(.bl_main(main, sprintf("%s: quantiles (%s)", cl, v)))
  .bl_ylab("Current quantile")
  .bl_xlab("Reference quantile")
  .bl_grid(NULL)
  graphics::abline(0, 1, lty = 2, col = "#4D4D4D")
  graphics::lines(q$ref, q$cur, col = rc[2L], lwd = 2.4)
  graphics::points(
    q$ref,
    q$cur,
    pch = 21,
    bg = rc[2L],
    col = "white",
    cex = 1.1
  )
  data.frame(column = cl, p = q$p, ref = q$ref, cur = q$cur)
}

#' Draws the drift fingerprint: one spoke per column, its PSI as the distance
#' out, the warn and fail bands as rings, each column's point in its verdict's
#' colour.
#' @param t From .bl_drift_table().
#' @param b The PSI bands, drawn as rings.
#' @param vc The verdict colours.
#' @param main The caller's title, or NULL.
#' @param ... Further arguments to plot.window().
#' @return A data frame: column, psi, verdict, angle and radius (1 is the outer
#'   ring).
#' @noRd
.bl_drift_fingerprint <- function(t, b, vc, main, ...) {
  psi <- ifelse(is.finite(t$psi), t$psi, 0)
  cap <- max(2 * b$fail, psi, 1e-9)
  # square-root scale: small PSIs stay apart from the centre
  r <- sqrt(pmin(psi, cap) / cap)
  a <- pi / 2 - 2 * pi * (seq_along(psi) - 1) / max(1L, length(psi))
  op <- graphics::par(mar = c(1, 1, 3, 1), bg = .bl_plot_opts()$bg)
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot.new()
  graphics::plot.window(c(-1.45, 1.45), c(-1.25, 1.25), asp = 1, ...)
  .bl_title(.bl_main(
    main,
    sprintf(
      "Drift fingerprint (%d fail, %d warn)",
      sum(t$verdict == "fail"),
      sum(t$verdict == "warn")
    )
  ))
  .bl_fp_rings(b, cap, vc)
  .bl_fp_marks(t, r, a, vc)
  graphics::mtext(
    sprintf(
      "rings: warn %s, fail %s; outer ring PSI %s (square-root scale)",
      b$warn,
      b$fail,
      signif(cap, 3)
    ),
    side = 1,
    line = -0.2,
    cex = 0.65 * graphics::par("cex"),
    col = "#3D4350"
  )
  data.frame(
    column = t$column,
    psi = t$psi,
    verdict = t$verdict,
    angle = a,
    radius = r,
    stringsAsFactors = FALSE
  )
}

#' Draws the disc and the warn and fail rings of the drift fingerprint.
#' @param b The warn and fail bands.
#' @param cap The PSI at the outer ring.
#' @param vc The verdict colours.
#' @return NULL, invisibly.
#' @noRd
.bl_fp_rings <- function(b, cap, vc) {
  th <- seq(0, 2 * pi, length.out = 181L)
  graphics::polygon(
    cos(th),
    sin(th),
    col = .bl_plot_opts()$panel %||% NA,
    border = NA
  )
  for (ring in c(b$warn, b$fail)) {
    graphics::lines(
      sqrt(ring / cap) * cos(th),
      sqrt(ring / cap) * sin(th),
      lty = 2,
      col = vc[[if (ring == b$fail) "fail" else "warn"]]
    )
  }
  invisible(NULL)
}

#' Draws the spokes, the shape, the points and the labels of the drift
#' fingerprint.
#' @param t The verdict table from .bl_drift_table().
#' @param r,a Each column's radius and angle.
#' @param vc The verdict colours.
#' @return NULL, invisibly.
#' @noRd
.bl_fp_marks <- function(t, r, a, vc) {
  graphics::segments(0, 0, cos(a), sin(a), col = "white", lwd = 1.2)
  if (length(r) > 2L) {
    graphics::polygon(
      r * cos(a),
      r * sin(a),
      col = grDevices::adjustcolor(vc[["ok"]], 0.18),
      border = vc[["ok"]]
    )
  }
  graphics::points(
    r * cos(a),
    r * sin(a),
    pch = 21,
    bg = unname(vc[t$verdict]),
    col = "white",
    cex = 1.6
  )
  graphics::text(
    1.12 * cos(a),
    1.12 * sin(a),
    .bl_short_label(t$column, 14L),
    cex = 0.7,
    col = "#3D4350",
    adj = c(.bl_text_hjust(cos(a)), 0.5),
    xpd = NA
  )
  invisible(NULL)
}

#' Draws one column's first digits against Benford's law, the reference as
#' points.
#' @param cl The column.
#' @param bf Its first-digit counts from cpsdrft().
#' @param alpha The level of the test.
#' @param rc The reference and current colours.
#' @param title This panel's title.
#' @param titles Every panel's title, so all are drawn at the size the longest
#'   needs.
#' @param key Whether this panel carries the legend.
#' @param ... Further arguments to the base call.
#' @return A data frame: column, digit, cur, ref, expected.
#' @noRd
.bl_drift_benford_panel <- function(
  cl,
  bf,
  alpha,
  rc,
  title,
  titles,
  key,
  ...
) {
  cur <- bf$cur / bf$n
  ref <- if (sum(bf$ref)) bf$ref / sum(bf$ref) else rep(NA_real_, 9L)
  e <- log10(1 + 1 / (1:9))
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, cur, e)), 3, 1)))
  mids <- .bl_barplot(
    cur,
    names.arg = 1:9,
    col = rc[2L],
    labels = FALSE,
    ylim = c(0, max(c(cur, ref, e), na.rm = TRUE) * 1.25),
    xlab = "First digit",
    ...
  )
  .bl_shared_title(title, titles)
  .bl_ylab("Proportion")
  .bl_grid(NULL)
  band <- .bl_benford_band(bf$n)
  graphics::polygon(
    c(mids, rev(mids)),
    c(band$lower, rev(band$upper)),
    col = grDevices::adjustcolor("#4D4D4D", 0.15),
    border = NA
  )
  .bl_line(mids, e, "#4D4D4D", fill = FALSE, label = FALSE)
  graphics::points(mids, ref, pch = 21, bg = rc[1L], col = "white", cex = 1.3)
  if (key) {
    .bl_benford_key(rc)
  }
  data.frame(column = cl, digit = 1:9, cur = cur, ref = ref, expected = e)
}

#' Draws a title at the largest size every title of the set fits at.
#' @param title The panel's title.
#' @param titles Every panel's title.
#' @return NULL, invisibly.
#' @noRd
.bl_shared_title <- function(title, titles) {
  width <- graphics::par("pin")[1L] * 0.98
  fit <- Filter(
    function(cx) all(.bl_strwidth(titles, cex = cx, font = 2) <= width),
    c(1.2, 1, 0.85)
  )
  if (length(fit)) {
    graphics::title(main = title, cex.main = fit[[1L]])
  } else {
    .bl_title(title)
  }
  invisible(NULL)
}

#' Draws the key of a Benford panel.
#' @param rc The two colours: reference and current.
#' @return NULL, invisibly.
#' @noRd
.bl_benford_key <- function(rc) {
  graphics::legend(
    "topright",
    c("current", "reference", "Benford expected, 95% band"),
    fill = c(rc[2L], NA, grDevices::adjustcolor("#4D4D4D", 0.15)),
    border = NA,
    pch = c(NA, 21, NA),
    pt.bg = c(NA, rc[1L], NA),
    col = c(NA, "white", "#4D4D4D"),
    lwd = c(NA, NA, 2),
    bty = "n",
    cex = 0.65
  )
  invisible(NULL)
}

# ---- bars: frequencies, missingness, coverage --------------------------------

#' Draws horizontal bars with a label per bar.
#' @param values The bar lengths.
#' @param labels The bar labels; NA is a level of its own.
#' @param xlab The x-axis title.
#' @param main The title.
#' @param cols The colours of the bars, top bar first.
#' @param ... Further arguments to barplot().
#' @param ref Values drawn as dashed reference lines, or NULL.
#' @return NULL, invisibly.
#' @noRd
.bl_hbars <- function(values, labels, xlab, main, cols, ..., ref = NULL) {
  labels <- as.character(labels)
  # a frequency table counts NA as a level of its own; a real level called
  # "(missing)" keeps its name and the NA level is told apart the first of
  # "(missing)", "(NA)", "(NA 2)", ... that no real level uses: "(NA)" was taken
  # when "(missing)" was, and a real "(NA)" level then shared its bar (review of
  # 02a38be)
  na_lab <- "(missing)"
  k <- 1L
  while (na_lab %in% labels) {
    na_lab <- if (k == 1L) "(NA)" else sprintf("(NA %d)", k)
    k <- k + 1L
  }
  labels[is.na(labels)] <- na_lab
  fit <- .bl_label_fit(labels)
  labels <- fit$labels
  op <- .bl_par_set(
    las = 1,
    cex = .bl_plot_opts()$cex,
    bg = .bl_plot_opts()$bg,
    mar = .bl_safe_mar(c(4.2, fit$mar, 3, 1)),
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430"
  )
  on.exit(graphics::par(op), add = TRUE)
  .bl_barplot(
    rev(values),
    names.arg = rev(labels),
    horiz = TRUE,
    col = rev(cols),
    border = NA,
    xlab = xlab,
    main = "",
    ...
  )
  .bl_title(main)
  .bl_grid(NULL, side = "x")
  if (length(ref)) {
    graphics::abline(v = ref, lty = 2, col = "#4D4D4D")
  }
  invisible(NULL)
}

#' Draws each row's distance, the outliers larger and numbered, for
#' plot.bricklayer_outliers().
#' @param d The outlier table.
#' @param cols One colour per row.
#' @return NULL, invisibly.
#' @noRd
.bl_outlier_marks <- function(d, cols) {
  out <- !is.na(d$outlier) & d$outlier
  graphics::points(
    d$row,
    d$distance,
    pch = 21,
    bg = grDevices::adjustcolor(cols, 0.75),
    col = "white",
    lwd = 1,
    cex = ifelse(out, 2, 1.1)
  )
  if (any(out)) {
    graphics::text(
      d$row[out],
      d$distance[out],
      d$row[out],
      pos = 4,
      cex = 0.8,
      font = 2,
      col = cols[out]
    )
  }
  invisible(NULL)
}

#' Draws correlations as horizontal bars from -1 to 1.
#' @param label The bar labels.
#' @param r The correlations.
#' @param main The title.
#' @param col The colours the caller gave, or NULL.
#' @param palette The palette the caller gave, or NULL for the diverging
#'   palette.
#' @param ... Further arguments to barplot().
#' @return NULL, invisibly.
#' @noRd
.bl_corr_bars <- function(label, r, main, col, palette, ...) {
  pal <- .bl_cols(
    3,
    col,
    if (is.null(palette) && is.null(col)) "diverging" else palette
  )
  cols <- ifelse(r > 0, pal[3L], pal[1L])
  cols[is.na(r)] <- pal[2L]
  if (!is.null(col)) {
    cols <- rep_len(col, length(r))
  }
  fit <- .bl_label_fit(label)
  label <- fit$labels
  op <- .bl_par_set(
    las = 1,
    cex = .bl_plot_opts()$cex,
    bg = .bl_plot_opts()$bg,
    mar = .bl_safe_mar(c(4.2, fit$mar, 3, 1)),
    bty = "n",
    tcl = -0.2,
    mgp = c(3, 0.55, 0),
    col.axis = "#3D4350",
    fg = "#8A909A",
    col = "#1F2430"
  )
  on.exit(graphics::par(op), add = TRUE)
  .bl_barplot(
    rev(ifelse(is.na(r), 0, r)),
    names.arg = rev(label),
    horiz = TRUE,
    col = rev(cols),
    border = NA,
    xlim = c(-1, 1),
    xlab = "Correlation",
    main = "",
    ...
  )
  .bl_title(main)
  .bl_grid(NULL, side = "x")
  graphics::abline(v = 0, col = "#8C8C8C")
  invisible(NULL)
}

# ---- air pollution -----------------------------------------------------------

#' The relative-risk curve of a CRF object over a range of exposures
#' @param crf A concentration-response function object.
#' @param exposure The exposures, or NULL for a range up to 1.5 times the CRF's
#'   exposure.
#' @return A data frame with `exposure` and `rr`.
#' @noRd
.bl_crf_curve <- function(crf, exposure = NULL) {
  ref <- crf$refconc
  z <- if (is.null(exposure)) {
    seq(0, max(1.5 * crf$expconc, ref * 2, 1), length.out = 200)
  } else {
    as.numeric(exposure)
  }
  excess <- pmax(z - ref, 0)
  e <- crf$extra
  rr <- if (identical(e$form, "IER")) {
    1 + e$alpha * (1 - exp(-e$gamma * excess^e$delta))
  } else {
    exp(e$betaper10 * excess / 10)
  }
  data.frame(exposure = z, rr = rr)
}

#' Refuses what is not a report from vrfpol().
#' @param x The object given to plot.rmbl_pollution_report().
#' @return NULL, invisibly.
#' @noRd
.bl_pollution_check <- function(x) {
  if (
    !is.list(x) ||
      !is.character(x$status) ||
      length(x$status) != 1L ||
      (identical(x$status, "ok") && !is.list(x$pipeline))
  ) {
    stop("`x` must be a report from vrfpol()", call. = FALSE)
  }
  invisible(NULL)
}

#' Draws a report that did not run: its status and why.
#' @param x A report from vrfpol() whose status is not ok.
#' @param main The title, or NULL for the failure status.
#' @return A one-row data frame of the status.
#' @noRd
.bl_pollution_failed <- function(x, main) {
  graphics::plot.new()
  graphics::title(
    main = if (is.null(main)) sprintf("vrfpol: %s", x$status) else main
  )
  msg <- if (identical(x$status, "error")) {
    x$error
  } else {
    row <- function(a) {
      sprintf("[%s] %s", if (a$ok) "PASS" else "FAIL", a$assumption)
    }
    paste(vapply(x$assumptions, row, ""), collapse = "\n")
  }
  graphics::text(0.5, 0.5, msg, cex = 0.8)
  data.frame(status = x$status, stringsAsFactors = FALSE)
}

#' Writes the energy and the everyday equivalents of an emission over its bars.
#' @param co2eg The grams of CO2e in all.
#' @param tot_kwh The energy in all.
#' @param gpk The grams per kWh.
#' @return NULL, invisibly.
#' @noRd
.bl_co2_note <- function(co2eg, tot_kwh, gpk) {
  eq <- fpeqv(co2eg)
  graphics::mtext(
    sprintf(
      "%.3g kWh at %.0f g/kWh; about %.3g m by car, %.3g tree-hours",
      tot_kwh,
      gpk,
      1000 * eq$carkm,
      24 * 30 * eq$treemon
    ),
    side = 3,
    line = 0.2,
    cex = 0.75 * graphics::par("cex"),
    col = "#555555"
  )
  invisible(NULL)
}

#' The emissions of a footprint, in grams, by component.
#' @param x A footprint from co2fp().
#' @return A list: \code{comp}, the grams of CO2e of the CPU, the memory and
#'   in all (where known), \code{kwh}, the energy in all, and \code{gpk}, the
#'   grams per kWh.
#' @noRd
.bl_co2_parts <- function(x) {
  kwh <- x$enekwh
  parts <- if (is.list(kwh)) unlist(kwh) else kwh
  tot_kwh <- if ("total" %in% names(parts)) parts[["total"]] else sum(parts)
  gpk <- x$co2int$g_per_kwh %||%
    if (tot_kwh > 0) x$co2eg / tot_kwh else NA_real_
  comp <- c(
    CPU = if ("cpu" %in% names(parts)) parts[["cpu"]] * gpk else NA_real_,
    memory = if ("memory" %in% names(parts)) {
      parts[["memory"]] * gpk
    } else {
      NA_real_
    },
    total = x$co2eg
  )
  list(comp = comp[is.finite(comp)], kwh = tot_kwh, gpk = gpk)
}

#' The unit that suits the size of an emission.
#' @param comp The emissions in grams.
#' @return A list: \code{unit}, kg, g, mg or micrograms, and \code{scale}, the
#'   grams in one of it.
#' @noRd
.bl_co2_unit <- function(comp) {
  # names given as values: a "\u00b5g" name in c() was stored as "<U+00B5>g" in
  # a non-UTF-8 locale
  scale <- stats::setNames(c(1e3, 1, 1e-3, 1e-6), c("kg", "g", "mg", "\u00b5g"))
  big <- max(comp, 0)
  unit <- names(scale)[which(big >= scale)[1L]]
  if (is.na(unit)) {
    unit <- "\u00b5g"
  }
  list(unit = unit, scale = scale[[unit]])
}

#' Draws a footprint too short to measure.
#' @param x A footprint from co2fp().
#' @param comp The emissions in grams.
#' @param title The plot's title.
#' @return The emissions as a data frame.
#' @noRd
.bl_co2_empty <- function(x, comp, title) {
  graphics::plot.new()
  .bl_title(title)
  graphics::text(0.5, 0.55, "Too short to measure", cex = 1.2, font = 2)
  graphics::text(
    0.5,
    0.4,
    sprintf(
      "%.3g s of CPU time recorded: no energy above the timer's resolution",
      x$cputms %||% 0
    ),
    cex = 0.85,
    col = "#555555"
  )
  data.frame(
    quantity = names(comp),
    value = unname(comp),
    unit = "g",
    stringsAsFactors = FALSE
  )
}

#' Draws the particles over their counting grid's concentration.
#' @param x A particle result.
#' @param g The grid: x range, y range and the number of cells each way.
#' @param cols The particles' colour.
#' @param palette The image's palette, or NULL for the sequential one.
#' @param main The title, or NULL for the particles default.
#' @param ... Passed to the grid's image().
#' @return NULL, invisibly.
#' @noRd
.bl_particles_grid <- function(x, g, cols, palette, main, ...) {
  xs <- seq(g[1L], g[2L], length.out = g[5L] + 1L)
  ys <- seq(g[3L], g[4L], length.out = g[6L] + 1L)
  graphics::image(
    xs[-1L] - diff(xs) / 2,
    ys[-1L] - diff(ys) / 2,
    x$concentration,
    col = blpal(if (is.null(palette)) "sequential" else palette, 64),
    xlab = "x",
    ylab = "",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Particles over the counting grid"))
  .bl_ylab("y")
  graphics::points(
    x$x,
    x$y,
    pch = 16,
    cex = 0.4,
    col = grDevices::adjustcolor(cols, 0.5)
  )
  invisible(NULL)
}

#' Sorts and checks a hand-made Lorenz frame, for plotlrnz().
#' @param d A data frame of cumulative population and value shares.
#' @return The frame in curve order.
#' @noRd
.bl_lorenz_frame <- function(d) {
  # a Lorenz curve runs from the origin along increasing shares; a hand-made
  # frame in any other order drew a zig-zag
  d <- d[order(d$population, d$value), , drop = FALSE]
  if (
    any(diff(d$value) < 0) ||
      any(
        d$population < 0 | d$population > 1 | d$value < 0 | d$value > 1,
        na.rm = TRUE
      )
  ) {
    stop(
      "`x` must be a Lorenz frame: cumulative population and value ",
      "shares in [0, 1], both non-decreasing",
      call. = FALSE
    )
  }
  d
}

#' plotfnl()'s limit levels and target, checked.
#' @param lvls,target As for plotfnl().
#' @noRd
.fnl_check_levels <- function(lvls, target) {
  if (
    !is.numeric(lvls) ||
      !length(lvls) ||
      !all(is.finite(lvls)) ||
      any(lvls <= 0 | lvls >= 1)
  ) {
    stop("`lvls` must be probabilities strictly between 0 and 1", call. = FALSE)
  }
  if (
    !is.numeric(target) ||
      length(target) != 1L ||
      !is.finite(target) ||
      target <= 0 ||
      target > 1e300
  ) {
    stop("`target` must be a single positive number below 1e300", call. = FALSE)
  }
  invisible(NULL)
}

#' plotfnl()'s counts, labels, levels and target, checked.
#' @param obs,expd,area,lvls,target As for plotfnl().
#' @return A list: obs and expd, as numbers.
#' @noRd
.fnl_check <- function(obs, expd, area, lvls, target) {
  obs <- .rmbl_num_input(obs, "obs")
  expd <- .rmbl_num_input(expd, "expd")
  if (length(obs) != length(expd)) {
    stop("plotfnl: `obs` and `expd` must be the same length", call. = FALSE)
  }
  if (!is.null(area) && length(area) != length(obs)) {
    stop(
      "`area` must have one label per point (recycling would mislabel ",
      "the areas)",
      call. = FALSE
    )
  }
  # a point missing either count is dropped whole: dropping each vector's NAs
  # on its own paired one area's count with the next area's expectation (B5)
  keep <- !is.na(obs) & !is.na(expd)
  obs <- .rmbl_finite_input(obs[keep], "obs", nonneg = TRUE, min_n = 1L)
  expd <- .rmbl_finite_input(expd[keep], "expd", min_n = 1L)
  if (any(expd <= 0)) {
    stop("plotfnl: `expd` must be positive", call. = FALSE)
  }
  .fnl_check_levels(lvls, target)
  list(obs = obs, expd = expd, area = if (!is.null(area)) area[keep])
}

#' A funnel plot's control limits: the outermost solid, the others dashed.
#' @param lim The limits, from fnllim().
#' @noRd
.fnl_limits <- function(lim) {
  for (lv in unique(lim$level)) {
    l <- lim[lim$level == lv, ]
    l <- l[order(l$expected), ]
    graphics::lines(
      l$expected,
      l$lower,
      col = "#8C8C8C",
      lty = if (lv == max(lim$level)) 1 else 2
    )
    graphics::lines(
      l$expected,
      l$upper,
      col = "#8C8C8C",
      lty = if (lv == max(lim$level)) 1 else 2
    )
  }
  invisible(NULL)
}

#' Tells which areas lie outside a funnel's widest limits.
#' @param lim The limits from fnllim().
#' @param expd,ratio Each area's expected count and observed-to-expected ratio.
#' @return TRUE, FALSE or NA for each area.
#' @noRd
.fnl_outside <- function(lim, expd, ratio) {
  outer <- lim[lim$level == max(lim$level), ]
  lo <- outer$lower[match(expd, outer$expected)]
  hi <- outer$upper[match(expd, outer$expected)]
  ratio > hi | ratio < lo
}

#' Draws a funnel's areas, naming those outside its limits.
#' @param expd,ratio Each area's expected count and observed-to-expected ratio.
#' @param cols One colour per area.
#' @param area The areas' names, or NULL.
#' @param out Which areas lie outside.
#' @return NULL, invisibly.
#' @noRd
.fnl_points <- function(expd, ratio, cols, area, out) {
  graphics::points(
    expd,
    ratio,
    pch = 21,
    bg = cols,
    col = "white",
    lwd = 1.2,
    cex = 1.4
  )
  if (!is.null(area) && any(out)) {
    graphics::text(
      expd[out],
      ratio[out],
      labels = as.character(area)[out],
      pos = 3,
      cex = 0.75
    )
  }
  invisible(NULL)
}

# ---- distributions, densities and many series --------------------------------

#' Checks a numeric variable and an optional grouping of the same length for a
#' plot.
#' @param x The values, checked numeric, one per `grp`.
#' @param grp The groups, or NULL.
#' @param what The name of `x` in the messages.
#' @return A data frame of `x` and `grp` (a factor), rows with a missing
#'   value dropped.
#' @noRd
.bl_xgrp <- function(x, grp = NULL, what = "x") {
  if (!is.numeric(x) || is.object(x)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be a numeric vector", what),
      call. = FALSE
    )
  }
  if (is.null(grp)) {
    grp <- rep("all", length(x))
  }
  if (length(grp) != length(x)) {
    stop(
      .rmbl_fn(),
      sprintf("`grp` must have one entry per value of `%s`", what),
      call. = FALSE
    )
  }
  d <- data.frame(
    x = as.numeric(x),
    grp = as.character(grp),
    stringsAsFactors = FALSE
  )
  d <- d[is.finite(d$x) & !is.na(d$grp), , drop = FALSE]
  if (nrow(d) < 2L) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` needs at least two finite values", what),
      call. = FALSE
    )
  }
  d$grp <- factor(d$grp, levels = unique(d$grp))
  d
}

#' Draws one group's violin, median and quartiles, for plotvln().
#' @param v The group's values.
#' @param i Its position.
#' @param lab Its name.
#' @param col Its colour.
#' @param bw The density bandwidth.
#' @return A list: \code{summary}, its median and quartiles, and
#'   \code{density}, the drawn density (NULL for fewer than two values).
#' @noRd
.bl_violin1 <- function(v, i, lab, col, bw) {
  q <- stats::quantile(v, c(0.25, 0.5, 0.75), names = FALSE)
  sm <- data.frame(
    grp = lab,
    median = q[2L],
    q1 = q[1L],
    q3 = q[3L],
    stringsAsFactors = FALSE
  )
  out <- NULL
  if (length(v) >= 2L) {
    k <- stats::density(v, bw = bw)
    w <- 0.42 * k$y / max(k$y)
    graphics::polygon(
      c(i - w, rev(i + w)),
      c(k$x, rev(k$x)),
      col = grDevices::adjustcolor(col, 0.5),
      border = col
    )
    out <- data.frame(grp = lab, x = k$x, y = k$y, stringsAsFactors = FALSE)
  }
  graphics::segments(i, q[1L], i, q[3L], lwd = 5, col = "#1F2430")
  graphics::points(
    i,
    q[2L],
    pch = 21,
    bg = "white",
    col = "#1F2430",
    cex = 1.3
  )
  list(summary = sm, density = out)
}

#' Counts points in hexagons, for plothex().
#' @param x,y The points.
#' @param bins The number of hexagons across.
#' @param rx,ry The ranges the hexagons cover.
#' @return A data frame: each hexagon's centre and count.
#' @noRd
.bl_hexbin <- function(x, y, bins, rx, ry) {
  # hexagons in scaled units: width w across x, rows sqrt(3)/2 * w apart, odd
  # rows shifted half a width
  sx <- (x - rx[1L]) / diff(rx) * bins
  sy <- (y - ry[1L]) / diff(ry) * bins
  h <- sqrt(3) / 2
  r1 <- round(sy / h)
  c1 <- round(sx - (r1 %% 2) / 2)
  r2 <- floor(sy / h)
  r2 <- ifelse(r2 == r1, r2 + 1, r2)
  c2 <- round(sx - (r2 %% 2) / 2)
  d1 <- (sx - c1 - (r1 %% 2) / 2)^2 + (sy - r1 * h)^2
  d2 <- (sx - c2 - (r2 %% 2) / 2)^2 + (sy - r2 * h)^2
  rr <- ifelse(d1 <= d2, r1, r2)
  cc <- ifelse(d1 <= d2, c1, c2)
  key <- paste(rr, cc)
  tab <- table(key)
  first <- match(names(tab), key)
  cx <- cc[first] + (rr[first] %% 2) / 2
  cy <- rr[first] * h
  data.frame(
    x = rx[1L] + cx / bins * diff(rx),
    y = ry[1L] + cy / bins * diff(ry),
    count = as.integer(tab),
    stringsAsFactors = FALSE
  )
}

#' The concentration curve of each group, from the origin, for plotgain().
#' @param d The values and their groups, from .bl_xgrp().
#' @param lv The groups.
#' @return A list of data frames, one per group.
#' @noRd
.bl_gain_curves <- function(d, lv) {
  lapply(lv, function(g) {
    l <- lorenzc(d$x[d$grp == g])
    data.frame(
      grp = g,
      population = c(0, l$population),
      value = c(0, l$value),
      stringsAsFactors = FALSE
    )
  })
}

#' Checks values, periods and series for the many-series plots.
#' @param y The values of the series, checked numeric.
#' @param prd The periods.
#' @param grp The series, or NULL.
#' @return A data frame: grp (factor), prd, y, ordered by series and period.
#' @noRd
.bl_series <- function(y, prd, grp) {
  if (!is.numeric(y) || is.object(y)) {
    stop(.rmbl_fn(), "`y` must be a numeric vector", call. = FALSE)
  }
  if (is.null(grp)) {
    grp <- rep("series", length(y))
  }
  if (length(prd) != length(y) || length(grp) != length(y)) {
    stop(
      .rmbl_fn(),
      "`prd` and `grp` must have one entry per value of `y`",
      call. = FALSE
    )
  }
  d <- data.frame(
    grp = as.character(grp),
    prd = prd,
    y = as.numeric(y),
    stringsAsFactors = FALSE
  )
  d <- d[!is.na(d$grp) & !is.na(d$prd), , drop = FALSE]
  if (!nrow(d)) {
    stop(.rmbl_fn(), "no value has both a period and a series", call. = FALSE)
  }
  d$grp <- factor(d$grp, levels = unique(d$grp))
  d$pos <- if (is.numeric(d$prd) || inherits(d$prd, "Date")) {
    as.numeric(d$prd)
  } else if (is.factor(d$prd)) {
    # a factor's periods run in its level order, not in order of appearance
    as.integer(d$prd)
  } else {
    match(d$prd, unique(d$prd))
  }
  d[order(d$grp, d$pos), , drop = FALSE]
}

#' Places each dated value on its year, week and weekday, for plotcal().
#' @param x The dates, or what as.Date() reads as dates.
#' @param y The daily values, one per date in `x`.
#' @return A data frame: date, y, year, wday and week, without the missing
#'   dates.
#' @noRd
.bl_cal_days <- function(x, y) {
  dt <- tryCatch(as.Date(x), error = function(e) NULL)
  if (
    is.null(dt) ||
      anyNA(dt[!is.na(x)]) ||
      length(dt) != length(y) ||
      !is.numeric(y)
  ) {
    stop(
      "plotcal: `x` must be dates, one per value of the numeric `y`",
      call. = FALSE
    )
  }
  ok <- !is.na(dt)
  d <- data.frame(date = dt[ok], y = as.numeric(y[ok]))
  d$year <- as.integer(format(d$date, "%Y"))
  d$wday <- as.integer(format(d$date, "%u"))
  jan1 <- as.Date(paste0(d$year, "-01-01"))
  d$week <- as.integer(
    (as.numeric(d$date - jan1) + as.integer(format(jan1, "%u")) - 1) %/% 7
  )
  d
}

#' Draws one row of day squares per year, for plotcal().
#' @param d The days from .bl_cal_days().
#' @param yrs The years, in order.
#' @param lvl Each day's shade, NA for a missing value.
#' @param shades The nine shades.
#' @return NULL, invisibly.
#' @noRd
.bl_cal_years <- function(d, yrs, lvl, shades) {
  for (i in seq_along(yrs)) {
    s <- d$year == yrs[i]
    top <- 8 * (length(yrs) - i + 1L)
    graphics::rect(
      d$week[s],
      top - d$wday[s],
      d$week[s] + 0.92,
      top - d$wday[s] + 0.92,
      col = ifelse(is.na(lvl[s]), "#E0E0E0", shades[lvl[s]]),
      border = NA
    )
    graphics::text(-0.5, top - 4, yrs[i], adj = 1, xpd = NA, cex = 0.85)
  }
  invisible(NULL)
}

#' Draws one horizon row per series, for plothrz().
#' @param d The series with each point's distance from its median.
#' @param lv The series, in order.
#' @param bands The number of bands.
#' @param bw The width of a band.
#' @param up,dn The colours above and below the median, one per band.
#' @return NULL, invisibly.
#' @noRd
.bl_horizon_rows <- function(d, lv, bands, bw, up, dn) {
  for (i in seq_along(lv)) {
    s <- d[d$grp == lv[i] & is.finite(d$dev), ]
    base <- length(lv) - i
    for (b in seq_len(bands)) {
      v <- pmin(pmax(abs(s$dev) - (b - 1) * bw, 0), bw) / bw * 0.9
      for (sgn in c(1, -1)) {
        vv <- ifelse(sign(s$dev) == sgn, v, 0)
        graphics::polygon(
          c(s$pos, rev(s$pos)),
          base + c(vv, rep(0, nrow(s))),
          border = NA,
          col = if (sgn > 0) up[b] else dn[b]
        )
      }
    }
  }
  invisible(NULL)
}

#' The horizontal adjustment of a label around a circle: right-aligned on the
#' left, left-aligned on the right, centred near the top and bottom.
#' @param ca The cosine of each label's angle.
#' @return 1, 0 or 0.5 for each label.
#' @noRd
.bl_text_hjust <- function(ca) {
  hj <- ifelse(ca > 0.2, 0, 0.5)
  hj[which(ca < -0.2)] <- 1
  hj
}

#' Draws the reference and current histograms of a numeric column, for
#' .bl_drift_column_panel().
#' @param s The column's summary, with its \code{hist}.
#' @param rc The two colours: reference and current.
#' @param ttl The panel's title.
#' @param ... Passed to the histogram's plot().
#' @return NULL, invisibly.
#' @noRd
.bl_drift_hist <- function(s, rc, ttl, ...) {
  h <- s$hist
  dens <- function(p) p / (h$hi - h$lo)
  graphics::par(
    mar = .bl_safe_mar(c(
      4.2,
      .bl_left_margin(c(0, dens(c(h$ref, h$cur)))),
      3,
      1
    ))
  )
  kind <- s$kind %||% "number"
  graphics::plot(
    range(c(h$lo, h$hi)),
    c(0, max(dens(c(h$ref, h$cur))) * 1.15),
    type = "n",
    xlab = "",
    ylab = "",
    xaxt = if (kind == "number") "s" else "n",
    ...
  )
  if (kind != "number") {
    at <- pretty(range(c(h$lo, h$hi)), n = 4L)
    graphics::axis(1, at = at, labels = .bl_drift_iso(at, kind))
  }
  .bl_title(ttl)
  .bl_ylab("Density")
  .bl_grid(NULL)
  graphics::rect(
    h$lo,
    0,
    h$hi,
    dens(h$ref),
    col = grDevices::adjustcolor(rc[1L], 0.35),
    border = NA
  )
  graphics::lines(
    c(rbind(h$lo, h$hi)),
    rep(dens(h$cur), each = 2L),
    col = rc[2L],
    lwd = 2.4
  )
  .bl_drift_hist_key(rc)
  invisible(NULL)
}

#' Draws the key of the reference and current histograms.
#' @param rc The two colours: reference and current.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_hist_key <- function(rc) {
  graphics::legend(
    "topright",
    c("reference", "current"),
    fill = c(grDevices::adjustcolor(rc[1L], 0.35), NA),
    border = NA,
    col = c(NA, rc[2L]),
    lwd = c(NA, 2.4),
    bty = "n",
    cex = 0.75
  )
  invisible(NULL)
}

#' Writes a column's largest PSI terms under its panel.
#' @param b The column's bins, with their PSI \code{contrib}.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_psi_caption <- function(b) {
  # the three largest terms, sized to this panel (the full list is on
  # drfthtml()'s page): the whole list at a fixed size ran into the next
  # panel's
  top <- utils::head(order(-b$contrib), 3L)
  cap <- paste0(
    "largest PSI terms: ",
    toString(trimws(formatC(b$contrib[top], digits = 2, format = "g"))),
    if (nrow(b) > 3L) " ..." else ""
  )
  cx <- min(
    0.6,
    0.6 * graphics::par("pin")[1L] / .bl_strwidth(cap, cex = 0.6)
  )
  graphics::mtext(
    cap,
    side = 1,
    line = 2.6,
    cex = max(0.35, cx) * graphics::par("cex")
  )
  invisible(NULL)
}

#' Draws the reference and current shares of each bin, for
#' .bl_drift_column_panel().
#' @param b The column's bins.
#' @param rc The two colours: reference and current.
#' @param ttl The panel's title.
#' @param ... Passed to the bars.
#' @return NULL, invisibly.
#' @noRd
.bl_drift_bars <- function(b, rc, ttl, ...) {
  keep <- utils::head(order(-(b$ref + b$cur)), 15L)
  bb <- b[sort(keep), , drop = FALSE]
  m <- rbind(bb$ref, bb$cur)
  graphics::par(mar = .bl_safe_mar(c(4.2, .bl_left_margin(c(0, m)), 3, 1)))
  mids <- .bl_barplot(
    m,
    beside = TRUE,
    names.arg = .bl_short_label(bb$bin, 12L),
    col = rc,
    labels = FALSE,
    ylim = c(0, max(m) * 1.25),
    ...
  )
  .bl_title(ttl)
  .bl_ylab("Share")
  .bl_grid(NULL)
  graphics::text(
    colMeans(mids),
    apply(m, 2L, max),
    formatC(bb$contrib, digits = 2, format = "g"),
    pos = 3,
    cex = 0.6,
    col = "#3D4350",
    xpd = NA
  )
  graphics::legend(
    "topright",
    c("reference", "current"),
    fill = rc,
    border = NA,
    bty = "n",
    cex = 0.75
  )
  invisible(NULL)
}

#' Refuses a plot option value that the plots could not use: a bad value
#' stored by plotopt() would otherwise break every later plot of the session.
#' @param nm The option's name (one of grid, cex, las, bg, panel).
#' @param v The value given.
#' @return NULL, invisibly.
#' @noRd
.bl_plot_opt_check <- function(nm, v) {
  is_col <- function(x, na_ok) {
    length(x) == 1L &&
      (isTRUE(na_ok && is.na(x)) ||
        (is.character(x) &&
          !is.na(x) &&
          !inherits(
            try(grDevices::col2rgb(x), silent = TRUE),
            "try-error"
          )))
  }
  ok <- switch(
    nm,
    grid = is.logical(v) && length(v) == 1L && !is.na(v),
    cex = is.numeric(v) && length(v) == 1L && is.finite(v) && v > 0,
    las = is.numeric(v) && length(v) == 1L && v %in% 0:3,
    bg = is_col(v, FALSE),
    panel = is_col(v, TRUE),
    TRUE
  )
  if (!ok) {
    want <- c(
      grid = "TRUE or FALSE",
      cex = "one positive number",
      las = "0, 1, 2 or 3",
      bg = "one colour",
      panel = "one colour, or NA for none"
    )
    stop("plot option `", nm, "` must be ", want[[nm]], call. = FALSE)
  }
  invisible(NULL)
}

#' Checks a density bandwidth: one positive number or a rule stats::density()
#' knows, refused in words before density() refuses it in its own (B4).
#' @param bw The bandwidth given to plotrdg() or plotvln().
#' @return `bw`, invisibly.
#' @noRd
.bl_check_bw <- function(bw) {
  rules <- c("nrd0", "nrd", "ucv", "bcv", "sj", "sj-ste", "sj-dpi")
  ok <- if (is.character(bw)) {
    length(bw) == 1L && !is.na(bw) && tolower(bw) %in% rules
  } else {
    is.numeric(bw) && length(bw) == 1L && is.finite(bw) && bw > 0
  }
  if (!ok) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`bw` must be one positive number or one of %s",
        toString(dQuote(rules, FALSE))
      ),
      call. = FALSE
    )
  }
  invisible(bw)
}
