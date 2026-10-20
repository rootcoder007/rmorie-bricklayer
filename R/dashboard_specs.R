# SPDX-License-Identifier: AGPL-3.0-or-later
# The dashboard's tabs as data: for each analysis, the exported functions it calls (steps, then a
# plot, then diagnostic plots), and for each argument the form control that sets it. The engine in
# dashboard.R builds the form, the call and the result from these, so a tab is added here without
# new server code. Each tab opens on a demo dataset (rmbldemo()); a column argument may name several
# defaults, and takes the first one the data has.

#' One argument of a step: its control type and options.
#' @param type data, ref, fixed, seed, col, cols, vec, date, frame, mat, num, nums, text, texts, seq,
#'   area, choice, choices or flag.
#' @param ... label, default, choices, name (ref), value (fixed), input (a shared control), pos.
#' @return A list.
#' @noRd
.ua <- function(type, ...) list(type = type, ...)

#' One step of an analysis.
#' @param fn The function called.
#' @param out The name its value is given.
#' @param ... Its arguments, each an .ua().
#' @return A list.
#' @noRd
.us <- function(fn, out = "res", ...) list(fn = fn, out = out, args = list(...))

#' One diagnostic plot of an analysis: plot() of an earlier step's value with fixed options.
#' @param label The plot's name in the diagnostics card.
#' @param ref The step whose value is plotted.
#' @param ... Fixed arguments of the plot() call.
#' @return A list: label and step.
#' @noRd
.ud <- function(label, ref, ...) {
  fx <- lapply(list(...), function(v) .ua("fixed", value = v))
  list(label = label, step = do.call(.us, c(list("plot", "plot", x = .ua("ref", name = ref, pos = TRUE)), fx)))
}

#' An analysis whose plot is plot() of its last step.
#' @param label The menu label.
#' @param steps The steps.
#' @param ... Further arguments of the plot() call.
#' @param plot Whether there is a plot.
#' @param about One line on what the analysis assumes.
#' @param needs_data Whether the analysis reads the data.
#' @param diag Diagnostic plots, each an .ud().
#' @param long Whether the analysis resamples, so runs in the background.
#' @param assume Its assumptions, when they differ from the tab's.
#' @param hover The argument naming the period column, for the plot's hover.
#' @return A list.
#' @noRd
.uf <- function(label, steps, ..., plot = TRUE, about = NULL, needs_data = TRUE, diag = NULL, long = FALSE,
                assume = NULL, hover = NULL) {
  last <- steps[[length(steps)]]$out
  list(label = label, steps = steps, about = about, needs_data = needs_data, diag = diag, long = long,
       assume = assume, hover = hover,
       plot = if (plot) .us("plot", "plot", x = .ua("ref", name = last, pos = TRUE), ...))
}

#' An analysis that is a plot function alone.
#' @param label The menu label.
#' @param fn The plot function.
#' @param ... Its arguments.
#' @return A list.
#' @noRd
.ufp <- function(label, fn, ...) list(label = label, steps = list(), plot = .us(fn, "plot", ...))

#' The R expression of a demo dataset, for a tab's Data menu.
#' @param name The dataset.
#' @param wrap An expression with `d` for the dataset, or NULL.
#' @return One string.
#' @noRd
.ux <- function(name, wrap = NULL) {
  if (is.null(wrap)) return(sprintf("rmbldemo(\"%s\")", name))
  sprintf("local({ d <- rmbldemo(\"%s\"); %s })", name, wrap)
}

#' The tabs of the dashboard.
#' @return A list of tab specs: id, title, about, assume, sources, filters, fns (and linked,
#'   extra).
#' @noRd
.bl_app_specs <- function() {
  D <- .ua("data", pos = TRUE)
  X <- .ua("data")
  col <- function(lab, def = NULL) .ua("col", label = lab, default = def)
  vec <- function(lab, def = NULL) .ua("vec", label = lab, default = def)
  num <- function(lab, def = NA) .ua("num", label = lab, default = def)
  ch <- function(lab, choices, def = choices[[1L]]) .ua("choice", label = lab, choices = choices, default = def)
  seed <- .ua("seed")
  yoyex <- paste0("data.frame(year = rep(2019:2023, 2), area = rep(c(\"north\", \"south\"), each = 5), ",
                  "n = c(402, 377, 190, 268, 331, 150, 160, 171, 140, 155), pop = rep(c(50000, 42000), each = 5))")
  ext <- function(f) sprintf("utils::read.csv(system.file(\"extdata\", \"%s\", package = \"rmoriebricklayer\"))", f)
  pan <- list(unit = col("Unit", c("court", "district")), time = col("Period", "month"),
              y = col("Outcome", c("delay", "crmrate")))
  panel <- function(fn, out, ..., trt = "trtd", cl = TRUE) {
    a <- c(list(data = D), pan, list(...))
    a[[trt]] <- if (trt == "trtd") col("Treated (0/1)", "reformed") else col("First period treated", "refmonth")
    if (cl) a$cl <- col("Cluster", "")
    do.call(.us, c(list(fn, out), a))
  }
  ind <- list(grp = col("Group", "group"), est = col("Estimate", "estimate"), lower = col("Lower", "lower"),
              upper = col("Upper", "upper"))
  q <- list(qual = col("Quality flag", "quality"))
  # the series a trend test reads, drawn as it is
  series <- .us("plotsm", "plot", y = vec("Value", "n"), prd = .ua("vec", label = "Period", default = "year",
                                                                  input = "x"))
  ser1 <- .ux("offences_annual", "stats::aggregate(cbind(n, pop) ~ year, d, sum)")
  list(
    list(id = "describe", title = "Describe", filters = character(), linked = "columns",
         about = paste("What each column looks like before you trust it: types, gaps, common values and odd rows.",
                       "Choose a column name in the profile to see its distribution."),
         assume = "Nothing: these are descriptions of the rows as they are, before any model.",
         sources = c("Demo: a survey with gaps and outliers (rmbldemo)" = .ux("survey"),
                     "Demo: court caseload panel (rmbldemo)" = .ux("court"),
                     "Example: airquality" = "datasets::airquality"),
         fns = list(
           profcols = .uf("Profile every column (profcols)", list(.us("profcols", "prof", data = D)), plot = FALSE),
           freqtbl = .uf("Frequency table (freqtbl)", list(.us("freqtbl", "ft", data = D,
                                                                col = col("Column", c("stratum", "Month"))))),
           cortbl = .uf("Correlations (cortbl)", list(.us("cortbl", "ct", data = D,
                                                           meth = ch("Method", c("spearman", "pearson"))))),
           mahaoutl = .uf("Outlying rows (mahaoutl)", list(.us("mahaoutl", "out", data = D, alpha = num("Alpha", 0.001),
                                                                robust = .ua("flag", label = "Robust",
                                                                             default = TRUE))),
                          assume = "The numeric columns are roughly elliptical (multivariate normal in the bulk)."),
           missgrid = .uf("Missingness grid (missgrid)", list(.us("missgrid", "mg", data = D)), plot = FALSE),
           plotrdg = .ufp("Ridgeline by group (plotrdg)", "plotrdg", x = vec("Value", c("age", "Ozone")),
                          grp = vec("Group", c("stratum", "Month"))),
           plotecdf = .ufp("Distribution functions by group (plotecdf)", "plotecdf",
                           x = vec("Value", c("income", "Ozone")),
                           grp = vec("Group", c("stratum", "Month"))),
           plotvln = .ufp("Violins by group (plotvln)", "plotvln", x = vec("Value", c("drinks", "Ozone")),
                          grp = vec("Group", c("stratum", "Month"))),
           plothex = .ufp("Two columns in hexagons (plothex)", "plothex", x = vec("x", c("age", "Temp")),
                          y = vec("y", c("income", "Wind")), bins = num("Hexagons across", 30)),
           plotgain = .ufp("Concentration curves (plotgain)", "plotgain", x = vec("Value", c("income", "Ozone")),
                           grp = vec("Group", c("stratum", "Month")))
         )),
    list(id = "yoy", title = "Year over year", filters = character(),
         about = paste("Change matched on the period itself: a missing year is a gap, not a longer comparison.",
                       "Point at the plot to see the rows of a period."),
         assume = paste("The counts are complete for each period and the periods are comparable (same definitions);",
                        "percentage changes on a small base are flagged, not hidden."),
         sources = c("Demo: offences by area and year (rmbldemo)" = .ux("offences_annual"),
                     "Example: counts by area" = yoyex),
         fns = list(yoy = c(.uf("Change from period to period (yoy)", list(.us("yoy", "y", x = D,
           value = col("Value", "n"), prd = col("Period", "year"), by = .ua("cols", label = "Groups", default = "area"),
           lag = num("Lag", 1), units = ch("Units", c("count", "continuous", "percent")),
           minbase = num("Smallest base for a percentage"),
           dir = ch("Better is", c("neutral", "higher", "lower")))), hover = "prd",
           diag = list(.ud("The values, not the change", "y", what = "value")))))),
    list(id = "rates", title = "Rates", filters = character(),
         about = "A rate is events per population; a share is a part of a total. The two are kept apart.",
         assume = paste("Counts are Poisson given the population (intervals are exact Poisson or Wilson);",
                        "the population is the one at risk of the event."),
         sources = c("Demo: offences by area and year (rmbldemo)" = .ux("offences_annual"),
                     "Demo: offences by area, 2024 (rmbldemo)" = .ux("offences_annual", "d[d$year == 2024, ]"),
                     "Example: counts by area" = yoyex),
         fns = list(
           rtcalc = .uf("Rate per population (rtcalc)", list(.us("rtcalc", "r", x = D, count = col("Count", "n"),
             pop = col("Population", "pop"), by = .ua("cols", label = "Groups", default = "area"),
             per = num("Per", 1000),
             conflvl = num("Confidence level", 0.95)))),
           ratechg = .uf("Change in a rate (ratechg)", list(.us("ratechg", "rc", x = D, count = col("Count", "n"),
             pop = col("Population", "pop"), prd = col("Period", "year"),
             by = .ua("cols", label = "Groups", default = "area"), per = num("Per", 1000))), hover = "prd"),
           shrs = .uf("Shares of a total (shrs)", list(.us("shrs", "s", x = D, count = col("Count", "n"),
             by = .ua("cols", label = "Groups", default = "area"))))
         )),
    list(id = "trends", title = "Trends", filters = character(),
         about = "Tests for a trend or a step in a short series, and plots for many series at once.",
         assume = paste("One value per period, in time order; the tests treat the periods as exchangeable under no",
                        "trend, so strong autocorrelation or seasonality inflates them."),
         sources = c("Demo: offences per year, all areas (rmbldemo)" = ser1,
                     "Demo: offences by area and year (rmbldemo)" = .ux("offences_annual"),
                     "Example: a step in a series" = paste0("data.frame(year = 2014:2023, n = c(100, 104, 98, 101, ",
                                                            "97, 60, 63, 58, 61, 59))"),
                     "Example: a daily series" = paste0("local({ set.seed(1); d <- seq(as.Date(\"2024-01-01\"), ",
                                                        "as.Date(\"2024-12-31\"), by = \"day\"); data.frame(day = d, ",
                                                        "n = stats::rpois(length(d), 5)) })")),
         fns = list(
           trndtst = list(label = "Mann-Kendall and Theil-Sen (trndtst)", steps = list(.us("trndtst", "mk",
             y = vec("Value", "n"), x = vec("Period", "year"),
             alt = ch("Alternative", c("two.sided", "increasing", "decreasing")))), plot = series),
           stepchg = list(label = "Step change (stepchg)", steps = list(.us("stepchg", "st", y = vec("Value", "n"),
             x = vec("Period", "year"), nperm = num("Permutations", 9999), seed = seed)), plot = series, long = TRUE,
             assume = "At most one step; the permutation test assumes the values are exchangeable with no step."),
           cnttrnd = .uf("Trend in counts (cnttrnd)", list(.us("cnttrnd", "ct", y = vec("Count", "n"),
             x = vec("Period", "year"))),
             assume = "Counts are Poisson with a log-linear trend; the dispersion check says when they are not."),
           plotcal = .ufp("Calendar heatmap (plotcal)", "plotcal", x = .ua("date", label = "Day", default = "day"),
                          y = vec("Value", "n")),
           plothrz = .ufp("Horizon chart (plothrz)", "plothrz", y = vec("Value", "n"), prd = vec("Period", "year"),
                          grp = vec("Series", "area")),
           plotsm = .ufp("Small multiples (plotsm)", "plotsm", y = vec("Value", "n"), prd = vec("Period", "year"),
                         grp = vec("Series", "area")),
           plotbump = .ufp("Ranks over time (plotbump)", "plotbump", y = vec("Value", "n"),
                           prd = vec("Period", "year"), grp = vec("Series", "area"))
         )),
    list(id = "survey", title = "Survey", filters = character(),
         about = paste("Design-based estimates: the weights, strata and clusters (or replicate weights) say how the",
                       "sample was drawn."),
         assume = paste("The weights are the inverse selection probabilities (adjusted for nonresponse), primary units",
                        "were drawn independently within strata, and replicate weights, when given, were made for",
                        "this design."),
         sources = c("Demo: stratified two-stage survey (rmbldemo)" = .ux("survey"),
                     "Example: a weighted sample" = paste0("local({ set.seed(1); data.frame(region = rep(c(\"north\", ",
           "\"south\", \"east\"), length.out = 150), smoker = stats::rbinom(150, 1, 0.3), ",
           "drinks = stats::rpois(150, 3), w = stats::runif(150, 50, 150)) })")),
         fns = local({
           des <- .us("svydes", "des", data = D, w = col("Weight", "w"), strata = col("Strata", "stratum"),
                      psu = col("Clusters", "psu"), reps = .ua("mat", label = "Replicate weights"),
                      type = ch("Replicate type", c("bootstrap", "meanboot", "jk1", "jkn", "brr", "fay")))
           list(
             svyest = .uf("Estimates with standard errors (svyest)", list(des, .us("svyest", "est",
               des = .ua("ref", name = "des"), data = X, y = col("Variable", "drinks"),
               by = .ua("cols", label = "Domains", default = c("stratum", "region")),
               stat = ch("Statistic", c("mean", "total", "proportion", "ratio")),
               den = col("Denominator (ratio)"), lvls = .ua("texts", label = "Levels (proportion)"))), long = TRUE),
             svycmp = .uf("Compare domains (svycmp)", list(des, .us("svycmp", "cmp", des = .ua("ref", name = "des"),
               data = X, y = col("Variable", "drinks"),
               by = .ua("cols", label = "Domains", default = c("stratum", "region")),
               stat = ch("Statistic", c("mean", "total", "proportion", "ratio")),
               ref = .ua("text", label = "Reference domain"))), long = TRUE)
           )
         })),
    list(id = "dist", title = "Distributions", filters = character(),
         about = paste("Candidate distributions by maximum likelihood, ranked by AIC. The KS and AD statistics",
                       "rank fits made from the same data; they are not tests."),
         assume = paste("The values are independent draws from one distribution; the bootstrap intervals of the",
                        "parameters assume the sample is large enough for the resamples to mimic it."),
         sources = c("Demo: days to disposition of 1,000 cases (rmbldemo)" = .ux("waits"),
                     "Example: waiting times and visit counts" = paste0("local({ set.seed(1); data.frame(wait = ",
           "stats::rgamma(300, 2, 0.5), visits = ifelse(stats::runif(300) < 0.3, 0, stats::rpois(300, 4))) })")),
         fns = local({
           fit <- .us("dstfit", "fit", x = vec("Variable", c("days", "wait")),
                      fams = .ua("choices", label = "Families (none: every one the data allow)",
                                 choices = names(.dst_fams())),
                      nboot = num("Bootstrap resamples", 50), seed = seed)
           list(
             dstfit = .uf("Fit and rank (dstfit)", list(fit), which = ch("View", c("density", "qq", "pp", "tail")),
                          long = TRUE, diag = list(.ud("QQ plot of the best fits", "fit", which = "qq"),
                                                   .ud("PP plot", "fit", which = "pp"),
                                                   .ud("The upper tail", "fit", which = "tail"))),
             synth = list(label = "A synthetic sample from the best fit (mksyncol)", long = TRUE,
                          about = "Draws from the first-ranked fit; set the families to draw from another.",
                          steps = list(fit, .us("mksyncol", "sim",
                                                spec = .ua("fixed", value = quote(list(type = "fitted", fit = fit))),
                                                n = num("Sample size", 500))),
                          plot = .us("plotecdf", "plot", x = .ua("ref", name = "sim")),
                          diag = list(.ud("QQ plot of the fit drawn from", "fit", which = "qq")))
           )
         })),
    list(id = "policy", title = "Policy", filters = character(),
         about = paste("Panel designs compare treated units with controls over time. They assume the outcomes would",
                       "have moved in parallel without the policy: read the pre-period coefficients of the event",
                       "study and the cohort trends before the estimate."),
         assume = paste("Parallel trends without the policy, no anticipation, no spillover between units, and (for",
                        "the two-way estimator) effects that do not vary across adoption cohorts."),
         sources = c("Demo: court caseload panel, staggered reform (rmbldemo)" = .ux("court"),
                     "Demo: one reformed court and the never reformed (rmbldemo)" =
                       .ux("court", "d[is.na(d$refmonth) | d$court == \"C03\", ]"),
                     "Example: a staggered reform (polex)" = "polex()"),
         fns = list(
           plndid = .uf("Two-way difference in differences (plndid)", list(panel("plndid", "did")), plot = FALSE),
           evstudy = .uf("Event study with pre-trends (evstudy)", list(panel("evstudy", "es", trt = "ftreat",
             leads = num("Leads", 4), lags = num("Lags", 4)))),
           stgatt = .uf("Staggered adoption (stgatt)", list(panel("stgatt", "s", trt = "ftreat",
             ctrl = ch("Controls", c("notyet", "never")), reps = num("Bootstrap", 99), seed = seed)), long = TRUE,
             assume = paste("Parallel trends for each cohort against its controls (not yet or never treated),",
                            "no anticipation.")),
           bacondcmp = .uf("Goodman-Bacon decomposition (bacondcmp)", list(panel("bacondcmp", "b", cl = FALSE))),
           swtdid = .uf("Switching difference in differences (swtdid)", list(panel("swtdid", "sw",
             reps = num("Bootstrap", 99), seed = seed)), plot = FALSE, long = TRUE),
           perminf = .uf("Randomisation inference (perminf)", list(panel("perminf", "ri", trt = "ftreat",
             reps = num("Permutations", 199), seed = seed)), type = ch("Plot", c("density", "histogram")), long = TRUE,
             assume = "Adoption dates are exchangeable across units under no effect (the sharp null)."),
           syndid = .uf("Synthetic difference in differences (syndid)", list(panel("syndid", "sd", trt = "ftreat",
             cl = FALSE, reps = num("Replications", 50), seed = seed)), long = TRUE,
             assume = "A weighted mix of controls tracks the treated units before adoption; one adoption date."),
           mtchdid = .uf("Matched difference in differences (mtchdid)", list(panel("mtchdid", "m", trt = "ftreat",
             cl = FALSE, covs = .ua("cols", label = "Covariates", default = "caseload"),
             ratio = num("Controls per treated", 1))), plot = FALSE),
           wcb = .uf("Wild cluster bootstrap (wcb)", list(panel("wcb", "w", reps = num("Bootstrap", 999),
             seed = seed)), plot = FALSE, long = TRUE,
             assume = "Errors independent across clusters; few clusters are fine, that is what it is for."),
           loounit = .uf("Leave one unit out (loounit)", list(panel("loounit", "loo")), long = TRUE),
           cohtrnd = .uf("Cohort trends (cohtrnd)", list(panel("cohtrnd", "ct", trt = "ftreat", cl = FALSE))),
           plnpwr = .uf("Power of the design (plnpwr)", list(.us("plnpwr", "pw", data = D, unit = pan$unit,
             time = pan$time, y = pan$y, ntrt = num("Treated units", 6),
             adopt = .ua("nums", label = "Adoption periods", default = "13, 19, 25, 31"),
             eff = .ua("nums", label = "Effects", default = "0, 4, 8"), reps = num("Simulations", 40),
             seed = seed)), long = TRUE),
           baltab = .uf("Covariate balance (baltab)", list(.us("baltab", "bal", data = D,
             grp = col("Group (0/1)", "reformed"), covs = .ua("cols", label = "Covariates",
                                                              default = c("caseload", "arrrate"))))),
           tse = .uf("Sensitivity to pre-trends (tse)", list(panel("evstudy", "es", trt = "ftreat"),
             .us("tse", "sens", x = .ua("ref", name = "es", pos = TRUE), seed = seed)), plot = FALSE, long = TRUE)
         )),
    list(id = "drift", title = "Drift", filters = character(), linked = "density",
         extra = function() {
           bslib::accordion(open = FALSE, class = "mt-3", bslib::accordion_panel(
             "Compare two CSV files (the app of drftapp())", .bl_drift_ui("drift")))
         },
         about = paste("Whether a fresh copy of a dataset still looks like the pinned one, column by column:",
                       "the population stability index (PSI) and a two-sample test for each column. Brush a range",
                       "of a column's two densities to see each snapshot's share of rows in it."),
         assume = paste("The rows of each snapshot are independent draws from its population; with large snapshots",
                        "the tests flag small shifts, so read the PSI beside them."),
         sources = c("Demo: two snapshots, reference and current (rmbldemo)" = .ux("drift")),
         fns = list(cpsdrft = list(
           label = "Drift between two snapshots (cpsdrft)",
           steps = list(.us("cpsdrft", "dr",
                            ref = .ua("fixed", value = quote(data[data$snapshot == "reference", -1L])),
                            cur = .ua("fixed", value = quote(data[data$snapshot == "current", -1L])),
                            alpha = num("Alpha", 0.01), bins = num("Bins", 10))),
           plot = .us("plot", "plot", x = .ua("ref", name = "dr", pos = TRUE),
                      what = ch("View", c("psi", "fingerprint"))),
           diag = list(.ud("Fingerprint of every column", "dr", what = "fingerprint"))))),
    list(id = "fnmi", title = "First Nations, Métis and Inuit",
         filters = c("group", "period", "age", "indicator", "region", "rating", "measure"),
         assume = paste("Each distinction is its own population: estimates are compared, never pooled; a suppressed",
                        "cell (F) is not a zero, and an E-flagged estimate is used with caution."),
         about = shiny::tagList(
           shiny::tags$p(paste(
             "Statistics Canada's published tables, read as published: each distinction (First Nations, Métis,",
             "Inuit) is reported on its own and never pooled, suppressed cells (quality F, x, ..) stay suppressed",
             "and are never imputed, and the quality flags are shown beside each estimate.",
             "The First Nations figures are for people living off reserve. The demo table is made up, in the same",
             "layout.")),
           shiny::tags$p(shiny::tags$strong("Whose data these are. "), paste(
             "OCAP® (First Nations Information Governance Centre): Ownership, Control, Access and Possession;",
             "First Nations own their information and decide how it is collected, used and shared. The CARE",
             "Principles (Carroll et al. 2020): Collective benefit, Authority to control, Responsibility and Ethics.",
             "The package mirrors only openly licensed aggregate tables, never First Nations-held survey data.")),
           local({
             ids <- c("1310092401", "4110006701", "4110008201", "4110002101", "1710016001", "1710016101")
             links <- lapply(ids, function(id) {
               shiny::tags$a(href = paste0("https://doi.org/10.25318/", id, "-eng"), target = "_blank",
                             rel = "noopener", sprintf("%s-%s-%s-01", substr(id, 1, 2), substr(id, 3, 4),
                                                       substr(id, 5, 8)))
             })
             shiny::tags$p("Source tables: ", shiny::HTML(paste(vapply(links, as.character, ""), collapse = ", ")),
                           " (Statistics Canada Open Licence).")
           })),
         sources = c("Demo: a published table with suppressed cells (rmbldemo)" = .ux("fnmi"),
                     "Health indicators (indiex)" = "indiex(\"health\")",
                     "Self-rated mental health (indiex)" = "indiex(\"mentalhealth\")",
                     "Wellbeing (indiex)" = "indiex(\"wellbeing\")",
                     "Suicidal ideation (indiex)" = "indiex(\"suicide\")"),
         fns = list(
           published = list(label = "The table as published, with quality flags", plot = NULL,
                            steps = list(.us("utils::head", "tab", x = D, n = num("Rows", 500)))),
           indgap = .uf("Gap to a reference group (indgap)", list(do.call(.us, c(list("indgap", "g", data = D), ind,
             list(ref = .ua("text", label = "Reference group", default = "Non-Indigenous")), q))),
             diag = list(.ud("The gap as a ratio", "g", what = "ratio"))),
           dstntst = .uf("Distinctions against each other (dstntst)", list(do.call(.us, c(list("dstntst", "dt",
             data = D), ind, q)))),
           ordcmp = .uf("Ordered ratings (ordcmp)", list(do.call(.us, c(list("ordcmp", "oc", data = D), ind,
             list(cat = col("Rating", "rating"), lvls = .ua("texts", label = "Levels, lowest first",
                                                          default = "Fair or poor, Good, Very good, Excellent"),
                  ref = .ua("text", label = "Reference group", default = "Métis")), q)))),
           welprof = .uf("Wellness beside distress (welprof, dualcont)", list(
             do.call(.us, c(list("welprof", "w", data = D, ind = col("Indicator", "indicator")), ind, list(
               well = .ua("texts", label = "Wellness indicators",
                          default = "Always or often has a hopeful outlook"),
               distress = .ua("texts", label = "Distress indicators",
                              default = "Life satisfaction rating between 0 and 5")), q)),
             .us("dualcont", "dc", x = .ua("ref", name = "w"),
                 well = .ua("text", label = "Wellness indicator for the dual continuum", input = "dcwell",
                            default = "Always or often has a hopeful outlook"),
                 distress = .ua("text", label = "Distress indicator for the dual continuum", input = "dcdist",
                                default = "Life satisfaction rating between 0 and 5")))),
           healchg = .uf("Change between periods (healchg)", list(do.call(.us, c(list("healchg", "hc", data = D,
             ind = col("Indicator", "indicator"), prd = col("Period", "period")), ind,
             list(from = .ua("text", label = "From", default = "2015/2018"),
                  to = .ua("text", label = "To", default = "2019/2022")), q)))),
           mhcont = .uf("Mental health continuum (mhcont)", list(do.call(.us, c(list("mhcont", "mw", data = D,
             ind = col("Indicator", "indicator")), ind,
             list(hope = .ua("text", label = "Hope indicator", default = "Always or often has a hopeful outlook")),
             q)))),
           stdprev = .uf("Age-standardised prevalence (stdprev)", list(.us("stdprev", "sp", est = vec("Estimate",
             "estimate"), lower = vec("Lower", "lower"), upper = vec("Upper", "upper"),
             std = .ua("nums", label = "Standard population weights, one per age group",
                       default = "20, 18, 17, 17, 28"),
             grp = vec("Group", "group"), qual = vec("Quality flag", "quality")))),
           trcprog = list(label = "Truth and Reconciliation Calls to Action (trcprog)", needs_data = FALSE,
                          steps = list(.us("trcprog", "p")), plot = .us("plot", "plot", x = .ua("ref", name = "p")))
         )),
    list(id = "justice", title = "Courts and corrections", filters = "year",
         about = paste("Stock and flow, case flow and clearance from published counts. A clearance rate compares",
                       "dispositions with new cases in the same period, not the same cases."),
         assume = paste("Counts are complete and consistently defined over the periods; a clearance rate above 100",
                        "means the backlog shrank, not that every case was finished."),
         sources = c("Demo: court case flow, all courts by month (rmbldemo)" =
                       .ux("court", "stats::aggregate(cbind(received, disposed, pending) ~ month, d, sum)"),
                     "Demo: custody admissions, all institutions by year (rmbldemo)" =
                       .ux("otis", "stats::aggregate(cbind(people, days) ~ year, d, sum)"),
                     "Demo: custody admissions by institution (rmbldemo)" = .ux("otis"),
                     "Ontario Court of Justice case flow" = ext("ocj_flow_ontario.csv"),
                     "Ontario Court of Justice offence groups" = ext("ocj_offence_groups.csv"),
                     "Ontario Court of Justice dispositions" = ext("ocj_dispositions.csv"),
                     "Toronto break and enter, D14 2024" = ext("tps_break_enter_d14_2024.csv")),
         fns = list(
           caseflow = .uf("Case flow and clearance (caseflow)", list(.us("caseflow", "cf",
             recv = vec("Received", "received"), disp = vec("Disposed", "disposed"), pend = vec("Pending", "pending"),
             prd = vec("Period", "month"), win = num("Rolling window", 12))),
             diag = list(.ud("Clearance with its interval", "cf", what = "clearance"))),
           stkflow = .uf("Stock and flow (stkflow)", list(.us("stkflow", "sf", days = vec("Days in custody", "days"),
             people = vec("People", "people"), prd = vec("Period", "year"))),
             diag = list(.ud("Average length of stay", "sf", what = "alos"))),
           clrdcmp = .uf("Clearance decomposition, Simpson (clrdcmp)", list(.us("clrdcmp", "cd",
             num = vec("Disposed", "disposed"), den = vec("Received", "received"),
             grp = vec("Part", "offence_group"), cmp = vec("Comparison", "year")))),
           dispmix = .uf("Mix of dispositions (dispmix)", list(.us("dispmix", "mix",
             cnts = .ua("frame", label = "Outcome columns"), prd = vec("Period", "year")))),
           lifetbl = .uf("Time to disposition (lifetbl)", list(.us("lifetbl", "lt",
             breaks = .ua("nums", label = "Band edges", default = "0, 10, 15, 18, Inf"),
             events = .ua("nums", label = "Cases per band", default = "600, 150, 60, 90"))), needs_data = FALSE),
           crmdens = .uf("Density of events (crmdens)", list(.us("crmdens", "kd", lon = vec("Longitude", "lon"),
             lat = vec("Latitude", "lat"), ngrid = num("Grid", 120)))),
           knoxtst = .uf("Space-time clustering, Knox (knoxtst)", list(.us("knoxtst", "kn", x = vec("Longitude", "lon"),
             y = vec("Latitude", "lat"), time = .ua("date", label = "Date", default = "occ_date"),
             spcbands = .ua("nums", label = "Distance bands (m)", default = "100, 200, 400"),
             tmbands = .ua("nums", label = "Time bands (days)", default = "7, 14, 28"), nsim = num("Simulations", 199),
             seed = seed)), long = TRUE),
           rgnmapintg = .uf("Unit-to-region map checks (rgnmapintg)", list(.us("rgnmapintg", "rm", map = D,
             unit = col("Unit", "inst"), reg = col("Region", "cd"))), plot = FALSE),
           siuprs = list(label = "Read an SIU report (siuprs)", needs_data = FALSE, plot = NULL,
                         steps = list(.us("siuprs", "rep", html = .ua("area", label = "Report HTML (paste)")))),
           siuso = list(label = "Count subject officials in SIU text (siuso)", needs_data = FALSE, plot = NULL,
                        steps = list(.us("siuso", "so", text = .ua("area", label = "Report text (paste)"))))
         )),
    list(id = "air", title = "Air pollution", filters = character(),
         about = paste("The Gaussian plume assumes steady wind and emission, flat terrain and Pasquill-Gifford",
                       "dispersion; burden estimates assume the concentration-response function applies to this",
                       "population."),
         assume = paste("Steady wind and emission over the averaging time, flat terrain, Pasquill-Gifford",
                        "dispersion; the concentration-response functions are the cited meta-analyses'."),
         sources = c("Demo: hourly NO2 at six monitors around a stack (rmbldemo)" = .ux("air"),
                     "Example: three receptors" = "data.frame(x = c(500, 1000, 2000), y = c(0, 50, -100), z = 0)"),
         fns = list(
           plmfld = list(label = "Plume concentration map (plmfld)", needs_data = FALSE,
                         steps = list(.us("plmfld", "f", q = num("Emission (g/s)", 10), u = num("Wind (m/s)", 5),
                                          h = num("Effective height (m)", 50),
                                          x = .ua("seq", label = "Downwind from, to, by (m)",
                                                  default = "100, 3000, 100"),
                                          y = .ua("seq", label = "Crosswind from, to, by (m)",
                                                  default = "-500, 500, 50"),
                                          stab = ch("Stability class", c("D", "A", "B", "C", "E", "F")),
                                          set = ch("Setting", c("rural", "urban")))),
                         plot = .us("plot", "plot", x = .ua("ref", name = "f", pos = TRUE))),
           monitors = .ufp("The monitors' readings over time (plotsm)", "plotsm", y = vec("Value", "no2"),
                           prd = vec("Period", "hour"), grp = vec("Series", "monitor")),
           profile = list(label = "Downwind profile (gplume)", needs_data = FALSE,
                          steps = list(.us("gplume", "conc", q = num("Emission (g/s)", 10), u = num("Wind (m/s)", 5),
                                           h = num("Effective height (m)", 50),
                                           rcpt = .ua("fixed", value = quote(cbind(seq(100, 5000, by = 50), 0, 0))),
                                           stab = ch("Stability class", c("D", "A", "B", "C", "E", "F")))),
                          plot = .us("plotsm", "plot", y = .ua("ref", name = "conc"),
                                     prd = .ua("fixed", value = quote(seq(100, 5000, by = 50))))),
           gplume = .uf("Concentration at your receptors (gplume)", list(.us("gplume", "conc",
             q = num("Emission (g/s)", 10), u = num("Wind (m/s)", 5), h = num("Effective height (m)", 50),
             rcpt = .ua("mat", label = "Receptor x, y, z columns", default = c("x", "y", "z")),
             stab = ch("Stability class", c("D", "A", "B", "C", "E", "F")))), plot = FALSE),
           crfpm25 = .uf("PM2.5 concentration-response (crfpm25)", list(.us("crfpm25", "rr",
             expo = .ua("nums", label = "Concentrations", default = "6, 10, 15, 22"),
             y = ch("Outcome", c("allcause", "ihd", "stroke")))), plot = FALSE,
             needs_data = FALSE),
           crfno2 = .uf("NO2 concentration-response (crfno2)", list(.us("crfno2", "rr",
             expo = .ua("nums", label = "Concentrations", default = "25"),
             y = ch("Outcome", c("allcause", "respiratory", "chiast")))), plot = FALSE, needs_data = FALSE),
           polbrdn = .uf("Attributable burden (polbrdn)", list(.us("polbrdn", "b", expomean = num("Mean exposure", 25),
             expoprev = num("Share exposed", 1), brate = num("Baseline rate", 0.008), pop = num("Population", 1e6),
             poll = ch("Pollutant", c("NO2", "PM2.5")))), needs_data = FALSE),
           vrfpol = .uf("Verified pipeline (vrfpol)", list(.us("vrfpol", "r", poll = ch("Pollutant", c("no2", "pm25")),
             demo = .ua("flag", label = "Demonstration data", default = TRUE), expomean = num("Mean exposure"),
             expoprev = num("Share exposed"), reg = .ua("text", label = "Region"))), needs_data = FALSE)
         )),
    list(id = "hawkes", title = "Hawkes", filters = character(),
         about = paste("A Hawkes process: each event raises the chance of more for a while. The fit assumes the",
                       "baseline is constant (or a trend and a yearly cycle) and the branching ratio below 1;",
                       "times recorded to the day carry ties to spread first (chwkjit)."),
         assume = paste("A constant (or sinusoidal) baseline, one kernel shape for every event, a branching ratio",
                        "below 1, and no ties; the time-rescaling QQ plot checks the fit."),
         sources = c("Demo: a self-exciting event stream over a year (rmbldemo)" = .ux("hawkes"),
                     "Example: 300 event times" =
                       "local({ set.seed(1); data.frame(t = sort(stats::runif(300, 0, 365))) })"),
         fns = local({
           fit <- .us("chwkfit", "fit", times = vec("Event times", "t"), hor = num("Horizon (window end)", 365),
                      kernel = ch("Kernel", c("exponential", "weibull", "gamma", "lomax")),
                      base = ch("Baseline", c("constant", "sinusoidal")))
           qq <- list(label = "Time-rescaling QQ plot", step = .us("plothwk", "plot", fit = .ua("ref", name = "fit",
                                                                                                pos = TRUE),
                                                                   times = vec("Event times", "t"),
                                                                   what = .ua("fixed", value = "qq")))
           list(
             chwkfit = list(label = "Fit (chwkfit)", steps = list(fit), long = TRUE, diag = list(qq),
                            plot = .us("plothwk", "plot", fit = .ua("ref", name = "fit", pos = TRUE),
                                       times = vec("Event times", "t"),
                                       what = ch("View", c("intensity", "qq", "tree")))),
             chwksim = list(label = "Simulate from the fit (chwksim)", long = TRUE, diag = list(qq),
                            steps = list(fit, .us("chwksim", "sim", fit = .ua("ref", name = "fit", pos = TRUE),
                                                  seed = seed)),
                            plot = .us("plothwk", "plot", fit = .ua("ref", name = "fit", pos = TRUE),
                                       times = .ua("ref", name = "sim"))),
             chwkjit = .uf("Spread tied times (chwkjit)", list(.us("chwkjit", "jit", times = vec("Event times", "t"))),
                           plot = FALSE)
           )
         }))
  )
}
