# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Evaluating a policy from administrative panels: two-way fixed-effects
# difference in differences, event studies, staggered adoption (Callaway and
# Sant'Anna; Wooldridge), the Goodman-Bacon decomposition, de Chaisemartin and
# D'Haultfoeuille's estimator for switching treatments, permutation inference
# and Westfall-Young stepdown p-values, fixed-effects Poisson, synthetic
# control, severity-weighted crime indices, lagged justice-pipeline rates,
# cumulative risk from first events, and place-based buffers. All of it on
# unit-by-period tables of counts or rates; base R only.

# ---- difference in differences -----------------------------------------------

#' Difference in differences with two-way fixed effects
#'
#' The effect of a policy on a unit-by-period panel (municipalities by month,
#' blocks by quarter, courts by year), from a regression of the outcome on the
#' treatment indicator with unit and period fixed effects, and standard errors
#' clustered by unit or by any coarser grouping.
#'
#' @details The model is \deqn{Y_{it} = \beta T_{it} + X_{it}'\gamma + \delta_i
#' + \mu_t + \varepsilon_{it},}{Y_it = b T_it + X_it'g + d_i + m_t + e_it,}
#' fitted by ordinary least squares after the within transformation (alternating
#' projections, so an unbalanced panel is fine). The variance is the one-way
#' cluster-robust CR1 estimator, \deqn{\hat V = \frac{G}{G - 1}\frac{N - 1}{N -
#' K} (\tilde X'\tilde X)^{-1} \Big(\sum_g \tilde X_g'\hat u_g \hat u_g'\tilde
#' X_g\Big) (\tilde X'\tilde X)^{-1},}{V = G/(G - 1) (N - 1)/(N - K) (X'X)^-1
#' (sum_g X_g'u_g u_g'X_g) (X'X)^-1,} with \eqn{K} counting the regressors and
#' the fixed effects not nested in the clusters, and tests and intervals use
#' Student's t on \eqn{G - 1} degrees of freedom. These are the conventions of
#' Stata's \code{reghdfe} and R's \code{fixest}.
#'
#' The relative effect is \eqn{\hat\beta} over the mean outcome of the units
#' never treated (or not yet treated) in the periods before the first treatment,
#' the way an effect on a rate is usually reported ("a 12% fall").
#'
#' With \code{fe = "time"} the unit effects are left out, and the model is the
#' cross-section with period effects of a comparison between kinds of units (for
#' example blocks in dynastic and in other wards).
#'
#' When treatment starts at different times, this estimator weights
#' earlier-treated units as controls for later ones, and can be biased if the
#' effect changes over time: see \code{\link{bacondcmp}} for the weights and
#' \code{\link{stgatt}} for estimators that avoid them.
#'
#' @param data A data frame, one row per unit and period.
#' @param unit,time,y Column names: the unit, the period (numeric, for example a
#'   year or a month index) and the outcome.
#' @param trtd Column name of the treatment indicator (0 or 1).
#' @param covs Optional column names of time-varying controls.
#' @param cl Column name of the clusters (default the unit), or two column names
#'   for two-way clustering (Cameron, Gelbach and Miller 2011): \eqn{V_a + V_b -
#'   V_{ab}}, each term with the small-sample factor of the dimension with fewer
#'   clusters, and t on its \eqn{G - 1} degrees of freedom. A composite cluster
#'   (district by month, say) is one column made with \code{interaction()}.
#' @param fe \code{c("unit", "time")} (default) or \code{"time"}.
#' @param w Optional column name of non-negative weights, such as population or
#'   matching weights, for weighted least squares with weighted within-means.
#' @param comb Optional linear combination of the terms, named by them, reported
#'   with its delta-method standard error as the attribute \code{combined}. For
#'   a phase-in model with an exposure term \eqn{E_{it} = \min(t - G_i, K)},
#'   \code{comb = c(treated = 1, exposure = 12)} is the effect after twelve
#'   periods, with its error, and as a percentage of the comparison units'
#'   pre-period mean (that mean taken as fixed).
#' @param conflvl Confidence level of the intervals reported (default 0.95).
#' @return A data frame of class \code{rmbl_did}, one row per term (the
#'   treatment first, then the covariates): \code{term}, \code{estimate},
#'   \code{se}, \code{lower}, \code{upper}, \code{t}, \code{p_value}.
#'   Attributes: \code{n}, \code{clusters}, \code{ctlmean} (the pre-period mean
#'   of the comparison units), \code{releff} (the estimate over it),
#'   \code{vcov}, and with \code{comb} also \code{combined}.
#' @references Bertrand M, Duflo E, Mullainathan S (2004). How much should we
#'   trust differences-in-differences estimates? Quarterly Journal of Economics
#'   119(1):249-275. \doi{10.1162/003355304772839588}
#'
#' Cameron AC, Gelbach JB, Miller DL (2011). Robust inference with multiway
#' clustering. Journal of Business and Economic Statistics 29(2):238-249.
#' \doi{10.1198/jbes.2010.07136}
#'
#' Cameron AC, Miller DL (2015). A practitioner's guide to cluster-robust
#' inference. Journal of Human Resources 50(2):317-372.
#' \doi{10.3368/jhr.50.2.317}
#'
#' Applied to a staggered criminal-procedure reform, municipality by month:
#' Acosta C, Mejia D, Zorro Medina A (2023). On the tension between due process
#' protection and public safety: the case of an extensive procedural reform in
#' Colombia. \doi{10.2139/ssrn.4585682}
#' @seealso \code{\link{evstudy}}, \code{\link{stgatt}},
#'   \code{\link{perminf}}, \code{\link{plnpois}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' plndid(p, "district", "month", "crmrate", "reformed")
#' # clustered by region instead of district
#' plndid(p, "district", "month", "crmrate", "reformed", cl = "region")
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # the effect of the by-law, with income as a control, clustered by town
#' # (the default), weighted by population
#' plndid(own, "town", "year", "rate", "bylaw", covs = "income", w = "pop")
#' @export
#' @srrstats {G5.6} polex() is built with a known reform effect of -3;
#'   test-policy_evaluation.R checks that plndid() recovers it.
#' @srrstats {G5.6a} Recovery is to a tolerance: expect_lt(abs(estimate + 3),
#'   0.5).
plndid <- function(
  data,
  unit,
  time,
  y,
  trtd,
  covs = NULL,
  cl = NULL,
  fe = c("unit", "time"),
  w = NULL,
  comb = NULL,
  conflvl = 0.95
) {
  conflvl <- .rmbl_conf_level(conflvl)
  fe <- .rmbl_arg(fe, c("unit", "time"), several = TRUE)
  if (!"time" %in% fe) {
    stop(.rmbl_fn(), "`fe` must include \"time\"", call. = FALSE)
  }
  p <- .rmbl_panel(data, unit, time, y)
  d <- .rmbl_did_trtd(data, trtd)
  .w <- .rmbl_weights(data, w)
  .cl <- .rmbl_cluster(data, cl, p)
  x <- cbind(treated = d, .rmbl_covariates(data, covs))
  fes <- list(time = as.integer(factor(p$t)))
  if ("unit" %in% fe) {
    fes <- c(list(unit = p$u), fes)
  }
  xd <- .rmbl_demean(x, fes, w = .w)
  yd <- as.vector(.rmbl_demean(p$y, fes, w = .w))
  fit <- .rmbl_ols_cr1(yd, xd, .cl, .rmbl_k_fe(fes, .cl), w = .w)
  out <- .rmbl_coef_table(fit, colnames(x), conflvl)
  cm <- .rmbl_did_ctlmean(d, p, .w)
  if (!is.null(comb)) {
    attr(out, "combined") <- .rmbl_did_comb(comb, colnames(x), fit, conflvl, cm)
  }
  attr(out, "n") <- fit$n
  attr(out, "clusters") <- fit$clusters
  attr(out, "ctlmean") <- cm
  attr(out, "releff") <- out$estimate[1L] / cm
  attr(out, "conflvl") <- conflvl
  attr(out, "vcov") <- fit$vcov
  class(out) <- c("rmbl_did", "data.frame")
  out
}

#' @export
format.rmbl_did <- function(x, digits = 4L, ...) {
  title <- "Difference in differences"
  need <- c("term", "estimate", "lower", "upper")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  lvl <- attr(x, "conflvl")
  cm <- attr(x, "ctlmean")
  re <- attr(x, "releff")
  .rmbl_res_block(
    title,
    facts = list(
      Method = "fixed-effects least squares, cluster-robust (CR1) errors",
      Observations = attr(x, "n"),
      Clusters = attr(x, "clusters"),
      Confidence = .rmbl_lvl(lvl),
      `Comparison mean` = if (isTRUE(is.finite(cm))) cm,
      `Relative effect` = if (isTRUE(is.finite(re) && cm != 0)) {
        sprintf("%+.1f%% of the comparison mean", 100 * re)
      }
    ),
    tables = list(
      Estimates = .rmbl_ci_cols(.rmbl_plain(x), lvl),
      `Combined effect` = .rmbl_pe_comb(attr(x, "combined"), lvl)
    ),
    reading = .rmbl_est_reading(
      "The policy's effect on the outcome is",
      x$estimate[1L],
      x$lower[1L],
      x$upper[1L],
      lvl
    ),
    notes = if (isTRUE(is.finite(cm))) {
      paste(
        "The comparison mean is the pre-period mean outcome of the units",
        "not (yet) treated."
      )
    },
    digits = digits
  )
}

# ---- event study -------------------------------------------------------------

#' An event study: the effect period by period around adoption
#'
#' Leads and lags of a policy's adoption, from a two-way fixed-effects
#' regression on indicators of the time since adoption, with a joint test that
#' the leads are zero (no effect before the policy, the testable part of
#' parallel trends).
#'
#' @details With \eqn{G_i} the first treated period of unit \eqn{i} and \eqn{k =
#' t - G_i}, \deqn{Y_{it} = \sum_{k = -L, k \ne r}^{M} \gamma_k \mathbf 1(t -
#' G_i = k) + X_{it}'\theta + \delta_i + \mu_t + \varepsilon_{it},}{Y_it = sum_k
#' g_k 1(t - G_i = k) + X_it'th + d_i + m_t + e_it,} with the reference period
#' \eqn{r} (default -1, the period before adoption) left out. Times beyond the
#' window are binned into its end points (\code{bin = TRUE}), or dropped. Units
#' never treated have every indicator 0. The variance and degrees of freedom are
#' those of \code{\link{plndid}}. The pre-trend test is the Wald statistic
#' \eqn{W = \hat\gamma_{pre}'\hat V_{pre}^{-1}\hat\gamma_{pre}}, reported as
#' \eqn{F = W/q} on \eqn{q} and \eqn{G - 1} degrees of freedom.
#'
#' With staggered adoption and effects that change over time, the lead and lag
#' coefficients can mix in effects from other periods (Sun and Abraham 2021);
#' \code{\link{stgatt}} gives the event-time effects free of that.
#'
#' @inheritParams plndid
#' @param ftreat Column name of the period a unit is first treated (\code{NA},
#' 0 or \code{Inf} for a unit never treated). Treatment is taken as staying on.
#' @param leads,lags The number of periods before and after adoption to estimate
#' (default 4 and 4).
#' @param ref The period left out (default -1).
#' @param bin Bin the periods beyond the window into its end points (default
#' \code{TRUE}).
#' @return A data frame of class \code{rmbl_event_study}: \code{evtm},
#'   \code{estimate}, \code{se}, \code{lower}, \code{upper}, \code{t},
#'   \code{p_value}, with the reference period as a row of zeros; attributes
#'   \code{pretrend} (a list: \code{F}, \code{df1}, \code{df2}, \code{p_value}),
#'   \code{vcov} (of the estimated event times), \code{n}, \code{clusters},
#'   \code{conflvl}. \code{plot()} draws it.
#' @references Sun L, Abraham S (2021). Estimating dynamic treatment effects in
#'   event studies with heterogeneous treatment effects. Journal of Econometrics
#'   225(2):175-199.\cr \doi{10.1016/j.jeconom.2020.09.006}
#'
#' Applied to the effect of donations on police stops, block by quarter: Zorro
#' Medina A, Hackett D, Green D, Vargas R (2025). Evidence of donor bias in
#' Chicago police stops. arXiv:2504.15140 (https://arxiv.org/abs/2504.15140).
#' @seealso \code{\link{plndid}}, \code{\link{stgatt}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3,
#'                   lags = 4)
#' es
#' attr(es, "pretrend")$p_value
#' plot(es)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # three years either side of adoption, weighted by population
#' evstudy(own, "town", "year", "rate", "first", leads = 3, lags = 3,
#'         w = "pop")
#' @export
evstudy <- function(
  data,
  unit,
  time,
  y,
  ftreat,
  leads = 4L,
  lags = 4L,
  ref = -1L,
  bin = TRUE,
  covs = NULL,
  cl = NULL,
  conflvl = 0.95,
  w = NULL
) {
  conflvl <- .rmbl_conf_level(conflvl)
  leads <- .rmbl_scalar(leads, "leads", 1, 1000, integer = TRUE)
  lags <- .rmbl_scalar(lags, "lags", 0, 1000, integer = TRUE)
  ref <- .rmbl_scalar(ref, "ref", -leads, lags, integer = TRUE)
  if (!is.logical(bin) || length(bin) != 1L || is.na(bin)) {
    stop(.rmbl_fn(), "`bin` must be TRUE or FALSE", call. = FALSE)
  }
  p <- .rmbl_panel(data, unit, time, y)
  g <- .rmbl_first_treated(data, ftreat, p)
  if (all(is.infinite(g))) {
    stop("evstudy: no unit is ever treated", call. = FALSE)
  }
  kk <- .rmbl_es_k(p$t - g, leads, lags, bin)
  k <- kk$k
  keep <- kk$keep
  ks <- setdiff(seq(-leads, lags), ref)
  x <- .rmbl_es_design(k, ks)
  cv <- .rmbl_covariates(data, covs)
  if (!is.null(cv)) {
    x <- cbind(x, cv)
  }
  .cl <- .rmbl_cluster(data, cl, p)
  sub <- function(z) if (is.matrix(z)) z[keep, , drop = FALSE] else z[keep]
  fes <- list(unit = sub(p$u), time = as.integer(factor(sub(p$t))))
  .cl <- sub(.cl)
  .w <- sub(.rmbl_weights(data, w))
  x <- sub(x)
  .rmbl_es_present(x, ks)
  fit <- .rmbl_ols_cr1(
    as.vector(.rmbl_demean(sub(p$y), fes, w = .w)),
    .rmbl_demean(x, fes, w = .w),
    .cl,
    .rmbl_k_fe(fes, .cl),
    w = .w
  )
  out <- .rmbl_es_table(fit, ks, ref, conflvl)
  pt <- .rmbl_es_pretrend(fit, ks)
  attr(out, "pretrend") <- pt
  attr(out, "vcov") <- fit$vcov[paste0("k", ks), paste0("k", ks), drop = FALSE]
  attr(out, "n") <- fit$n
  attr(out, "clusters") <- fit$clusters
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_event_study", "data.frame")
  out
}

#' @export
format.rmbl_event_study <- function(x, digits = 4L, ...) {
  title <- "Event study"
  need <- c("evtm", "estimate", "se", "lower", "upper")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  lvl <- attr(x, "conflvl")
  pt <- attr(x, "pretrend")
  ref <- x$evtm[which(x$se == 0 & x$estimate == 0)]
  .rmbl_res_block(
    title,
    facts = list(
      Method = "fixed-effects regression on the periods since adoption",
      Observations = attr(x, "n"),
      Clusters = attr(x, "clusters"),
      Periods = if (nrow(x)) {
        sprintf("%s to %s since adoption", min(x$evtm), max(x$evtm))
      },
      `Reference period` = if (length(ref)) ref[1L],
      Confidence = .rmbl_lvl(lvl),
      `Leads jointly zero` = .rmbl_es_ptxt(pt)
    ),
    tables = .rmbl_ci_cols(.rmbl_plain(x), lvl),
    reading = .rmbl_es_reading(pt),
    digits = digits,
    maxrows = 40L
  )
}

#' @rdname plot-methods
#' @param style For an event study: \code{"dot"} (filled points with solid
#'   capped bars, the default) or \code{"stata"} (hollow points joined by a
#'   line, dashed capped bars, dashed reference lines).
#' @param shadepost Shade the periods after adoption (default \code{FALSE}).
#' @param refline Where the vertical reference line goes (default \code{-0.5},
#'   between the reference period and adoption; \code{0} puts it at adoption).
#' @export
plot.rmbl_event_study <- function(
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
) {
  .rmbl_plot_check(x, "rmbl_event_study")
  style <- .rmbl_arg(style)
  gaps <- .rmbl_arg(gaps)
  d <- as.data.frame(x)
  cl <- .bl_cols(1L, col, palette)
  yl <- range(c(d$lower, d$upper, 0), na.rm = TRUE)
  graphics::plot(
    d$evtm,
    d$estimate,
    ylim = yl,
    type = "n",
    xlab = xlab %||% "Periods since adoption",
    ylab = "Effect, with its interval",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, "Event study"))
  if (isTRUE(shadepost)) {
    .rmbl_es_shade(refline)
  }
  w <- is.finite(d$lower) & is.finite(d$upper) & d$upper > d$lower
  if (style == "stata") {
    .rmbl_es_draw_stata(d, w, refline, gaps, cl)
  } else {
    .rmbl_es_draw_dot(d, w, refline, cl)
  }
  invisible(d)
}

# ---- staggered adoption ------------------------------------------------------

#' Effects of a policy adopted at different times
#'
#' Group-time average treatment effects for staggered adoption, with no unit
#' used as a control after it is treated (Callaway and Sant'Anna 2021), or the
#' extended two-way fixed-effects regression with a coefficient for every cohort
#' and period (Wooldridge 2021); aggregated to one effect and to effects by time
#' since adoption.
#'
#' @details Let the cohort \eqn{g} be the units first treated in period \eqn{g},
#' and \eqn{C} the comparison units: never treated (\code{control = "never"}),
#' or not yet treated by period \eqn{\max(t, g - 1)} (\code{"notyet"}, the
#' default). For \code{meth = "csa"}, \deqn{ATT(g, t) = \big(\bar Y_{g,t} -
#' \bar Y_{g,b}\big) - \big(\bar Y_{C,t} - \bar Y_{C,b}\big),}{ATT(g, t) =
#' (Y_g,t - Y_g,b) - (Y_C,t - Y_C,b),} with base period \eqn{b = g - 1} for
#' \eqn{t \ge g}, and \eqn{b = t - 1} before (the \code{"varying"} base of the
#' \code{did} package), so a pre-period ATT is a placebo of one period. It needs
#' a balanced panel.
#'
#' With \code{covs}, parallel trends need only hold conditionally on them, and
#' each \eqn{ATT(g, t)} is the two-period estimator of Sant'Anna and Zhao (2020)
#' on the cohort and its comparison units, with the covariates taken at the base
#' period \eqn{b} (use covariates fixed before treatment: one the policy moves
#' is a bad control). With \eqn{\Delta Y = Y_t - Y_b}, \eqn{D} the cohort
#' indicator, \eqn{\hat m(X)} the least-squares fit of \eqn{\Delta Y} on \eqn{X}
#' among the comparison units and \eqn{\hat p(X)} the logistic propensity of
#' belonging to the cohort, \deqn{\widehat{ATT}_{dr} = \frac{\sum D (\Delta Y -
#' \hat m)}{\sum D} - \frac{\sum w (\Delta Y - \hat m)}{\sum w}, \quad w =
#' \frac{\hat p (1 - D)}{1 - \hat p};}{ATT_dr = sum D (dY - m) / sum D - sum w
#' (dY - m) / sum w, w = p (1 - D) / (1 - p);} \code{estmeth = "ipw"} drops
#' \eqn{\hat m} (normalised inverse probability weighting) and \code{"reg"}
#' drops the weights (outcome regression). The doubly robust form is consistent
#' when either the propensity or the outcome model is right. Comparison units
#' with \eqn{\hat p \ge 0.995} are trimmed, as the \code{DRDID} package does.
#' These agree with \code{did::attgt()} to rounding error.
#'
#' For \code{meth = "wooldridge"}, the regression of the outcome on unit and
#' period effects and an indicator for every treated cohort-period cell, with
#' never-treated (or last-treated) units as the comparison, gives each
#' \eqn{ATT(g, t)} as a coefficient; without covariates it equals the imputation
#' estimator.
#'
#' The overall effect averages the post-adoption \eqn{ATT(g, t)} weighted by
#' cohort size; the event-time effect \eqn{\theta(e)} averages \eqn{ATT(g, g +
#' e)} over the cohorts observed at \eqn{e}, weighted by cohort size. Standard
#' errors come from the cluster bootstrap: units (or clusters) are resampled
#' with replacement \code{reps} times and everything recomputed; intervals are
#' normal with the bootstrap standard error.
#'
#' @inheritParams evstudy
#' @param ctrl \code{"notyet"} (default) or \code{"never"}.
#' @param meth \code{"csa"} (default) or \code{"wooldridge"}.
#' @param reps Bootstrap replications (default 499; 0 for none).
#' @param covs Optional column names of covariates for conditional parallel
#'   trends (\code{meth = "csa"} only).
#' @param estmeth With covariates: \code{"dr"} (doubly robust, default),
#'   \code{"ipw"} or \code{"reg"}.
#' @param seed Optional seed for the bootstrap.
#' @return A list of class \code{rmbl_staggered_att}: \code{attgt} (a data
#'   frame: \code{cohort}, \code{period}, \code{evtm}, \code{estimate},
#'   \code{se}, \code{lower}, \code{upper}, \code{ncoh}), \code{overall} (one
#'   row: \code{estimate}, \code{se}, \code{lower}, \code{upper}),
#'   \code{dynamic} (by \code{evtm}), \code{method}, \code{control},
#'   \code{conflvl}. \code{plot()} draws the dynamic effects.
#' @references Callaway B, Sant'Anna PHC (2021). Difference-in-differences with
#'   multiple time periods. Journal of Econometrics 225(2):200-230.
#'   \doi{10.1016/j.jeconom.2020.12.001}
#'
#' Sant'Anna PHC, Zhao J (2020). Doubly robust difference-in-differences
#' estimators. Journal of Econometrics 219(1):101-122.
#' \doi{10.1016/j.jeconom.2020.06.003}
#'
#' Wooldridge JM (2021). Two-way fixed effects, the two-way Mundlak regression,
#' and difference-in-differences estimators. \doi{10.2139/ssrn.3906345}
#'
#' Applied to a reform rolled out in four stages across judicial districts:
#' Acosta, Mejia and Zorro Medina (2023), see \code{\link{plndid}}.
#' @seealso \code{\link{bacondcmp}}, \code{\link{evstudy}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 99,
#'                    seed = 1)
#' s$overall
#' head(s$dynamic)
#' plot(s)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # each adoption cohort against the towns not yet treated
#' stgatt(own, "town", "year", "rate", "first", reps = 49, seed = 1)$overall
#' @export
stgatt <- function(
  data,
  unit,
  time,
  y,
  ftreat,
  ctrl = c("notyet", "never"),
  meth = c("csa", "wooldridge"),
  cl = NULL,
  reps = 499L,
  seed = NULL,
  conflvl = 0.95,
  covs = NULL,
  estmeth = c("dr", "ipw", "reg")
) {
  ctrl <- .rmbl_arg(ctrl)
  meth <- .rmbl_arg(meth)
  estmeth <- .rmbl_arg(estmeth)
  if (!is.null(covs) && meth == "wooldridge") {
    stop(
      .rmbl_fn(),
      "covariates are taken by method = \"csa\" (doubly robust, IPW or ",
      "regression)",
      call. = FALSE
    )
  }
  conflvl <- .rmbl_conf_level(conflvl)
  reps <- .rmbl_scalar(reps, "reps", 0, 1e5, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, y)
  g <- .rmbl_first_treated(data, ftreat, p)
  wd <- .rmbl_sg_wide(data, cl, covs, p, g, ctrl)
  spec <- list(meth = meth, ctrl = ctrl, estmeth = estmeth, tl = p$tl)
  a0 <- .rmbl_sg_est(seq_len(wd$nu), wd, spec)
  g0 <- .rmbl_sg_agg(a0)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  se <- .rmbl_sg_boot(wd, spec, a0, g0, reps, seed)
  out <- .rmbl_sg_out(a0, g0, se, z, c(method = meth, control = ctrl), conflvl)
  class(out) <- "rmbl_staggered_att"
  out
}

#' @export
format.rmbl_staggered_att <- function(x, digits = 4L, ...) {
  lvl <- x$conflvl
  o <- x$overall
  dyn <- .rmbl_plain(x$dynamic, c("evtm", "estimate", "se", "lower", "upper"))
  .rmbl_res_block(
    "Staggered adoption",
    facts = list(
      Method = if (identical(x$method, "wooldridge")) {
        "Wooldridge extended two-way fixed effects"
      } else {
        "Callaway and Sant'Anna group-time effects"
      },
      `Comparison units` = if (identical(x$control, "never")) {
        "never treated"
      } else {
        "not yet treated"
      },
      Cohorts = length(unique(x$attgt$cohort)),
      `Group-time effects` = nrow(x$attgt),
      Confidence = .rmbl_lvl(lvl),
      `Overall effect` = if (length(o$estimate)) {
        paste(.rmbl_fmt_num(o$estimate), .rmbl_fmt_ci(o$lower, o$upper))
      }
    ),
    tables = list(`By time since adoption` = .rmbl_ci_cols(dyn, lvl)),
    reading = .rmbl_est_reading(
      "Averaged over the cohorts and the periods after adoption, the effect is",
      o$estimate,
      o$lower,
      o$upper,
      lvl
    ),
    notes = paste(
      "Intervals use the cluster-bootstrap standard error; `attgt` holds",
      "every cohort-period effect."
    ),
    digits = digits,
    maxrows = 40L
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_staggered_att <- function(
  x,
  ...,
  main = NULL,
  col = NULL,
  palette = NULL,
  style = c("dot", "stata"),
  shadepost = FALSE,
  refline = -0.5
) {
  .rmbl_plot_check(x, "rmbl_staggered_att")
  d <- x$dynamic
  es <- structure(
    data.frame(
      evtm = d$evtm,
      estimate = d$estimate,
      se = d$se,
      lower = ifelse(is.finite(d$lower), d$lower, d$estimate),
      upper = ifelse(is.finite(d$upper), d$upper, d$estimate)
    ),
    class = c("rmbl_event_study", "data.frame")
  )
  # the periods before adoption in one colour and after in another, as the did
  # package draws them
  cols <- if (is.null(col)) c("#2C6FBB", "#C0392B") else rep_len(col, 2L)
  plot.rmbl_event_study(
    es,
    ...,
    main = .bl_main(main, "Effect by time since adoption"),
    col = cols[2L],
    palette = palette,
    style = style,
    shadepost = shadepost,
    refline = refline
  )
  pre <- es$evtm < 0
  w <- pre & es$upper > es$lower
  graphics::arrows(
    es$evtm[w],
    es$lower[w],
    es$evtm[w],
    es$upper[w],
    angle = 90,
    code = 3,
    length = 0.03,
    col = cols[1L]
  )
  graphics::points(es$evtm[pre], es$estimate[pre], pch = 19, col = cols[1L])
  invisible(es)
}

# ---- Goodman-Bacon -----------------------------------------------------------

#' The Goodman-Bacon decomposition of a two-way fixed-effects estimate
#'
#' Splits the two-way fixed-effects difference-in-differences estimate of a
#' staggered adoption into the two-group, two-period comparisons it averages,
#' with their weights: treated against never treated, earlier against later
#' treated, and later against earlier treated (the comparisons that use
#' already-treated units as controls).
#'
#' @details For a balanced panel with treatment that stays on and no covariates,
#' the estimate of \code{\link{plndid}} is exactly \eqn{\hat\beta = \sum_{k}
#' s_{kU}\hat\beta_{kU} + \sum_{k \ne l} s_{kl}\hat\beta_{kl}}, with weights
#' that sum to one and grow with the groups' sizes \eqn{n} and the variance of
#' their treatment over time \eqn{\bar D(1 - \bar D)} (Goodman-Bacon 2021,
#' theorem 1). Units treated from the first period act as an already-treated
#' group. A large weight on \dQuote{later vs earlier} comparisons, together with
#' effects that grow over time, is the warning sign that the two-way estimate is
#' biased.
#'
#' @inheritParams plndid
#' @return A data frame of class \code{rmbl_bacon}: \code{type} (\code{"treated
#'   vs never"}, \code{"earlier vs later"}, \code{"later vs earlier"}),
#'   \code{treated}, \code{control} (the adoption periods; \code{Inf} for
#'   never), \code{estimate}, \code{weight}; attribute \code{twfe} (the weighted
#'   sum, equal to the two-way estimate).
#' @references Goodman-Bacon A (2021). Difference-in-differences with variation
#'   in treatment timing. Journal of Econometrics 225(2):254-277.
#'   \doi{10.1016/j.jeconom.2021.03.014}
#' @seealso \code{\link{plndid}}, \code{\link{stgatt}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
#' b
#' tapply(b$weight, b$type, sum)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' bacondcmp(own, "town", "year", "rate", "bylaw")
#' @export
bacondcmp <- function(data, unit, time, y, trtd) {
  p <- .rmbl_panel(data, unit, time, y)
  bw <- .rmbl_bacon_wide(data, trtd, p)
  rows <- c(.rmbl_bacon_never(bw, p$tl), .rmbl_bacon_timing(bw, p$tl))
  out <- do.call(rbind, rows)
  out$weight <- out$weight / sum(out$weight)
  attr(out, "twfe") <- sum(out$weight * out$estimate)
  class(out) <- c("rmbl_bacon", "data.frame")
  out
}

#' @export
format.rmbl_bacon <- function(x, digits = 4L, ...) {
  title <- "Goodman-Bacon decomposition"
  fb <- .rmbl_df_fallback(x, title, c("type", "estimate", "weight"), digits)
  if (!is.null(fb)) {
    return(fb)
  }
  later <- sum(x$weight[x$type == "later vs earlier"])
  each <- c("type", "treated", "control", "estimate", "weight")
  .rmbl_res_block(
    title,
    facts = list(
      `Two-way estimate` = attr(x, "twfe"),
      Comparisons = nrow(x),
      `Weight on later vs earlier` = sprintf("%.1f%%", 100 * later)
    ),
    tables = list(
      `By kind of comparison` = .rmbl_bacon_types(x),
      `Each comparison (control Inf = never treated)` = .rmbl_plain(x, each)
    ),
    reading = .rmbl_bacon_reading(x, later),
    digits = digits
  )
}

# ---- switching treatments ----------------------------------------------------

#' Difference in differences for treatments that switch on and off
#'
#' De Chaisemartin and D'Haultfoeuille's estimator of the effect at the moment
#' units switch: in every period, units that switch into treatment are compared
#' with units untreated in both periods, and units that switch out with units
#' treated in both; with the placebo that runs the same comparison one period
#' earlier.
#'
#' @details For each period \eqn{t} with joiners (\eqn{D_{t-1} = 0, D_t = 1})
#' and stayers untreated in both, \eqn{DID_{+,t}} is the joiners' mean change in
#' the outcome minus the stayers'; with leavers (1 to 0) and stayers treated in
#' both, \eqn{DID_{-,t}} is the stayers' change minus the leavers'. The estimate
#' is \deqn{DID_M = \sum_t \frac{N_{J,t}}{N_S} DID_{+,t} + \frac{N_{L,t}}{N_S}
#' DID_{-,t},}{DID_M = sum_t (N_J,t DID_+,t + N_L,t DID_-,t) / N_S,} over the
#' \eqn{N_S} switchers. The placebo compares, between \eqn{t - 2} and \eqn{t -
#' 1}, the change of the units that switch at \eqn{t} with that of the units
#' whose treatment did not change over \eqn{t - 2} to \eqn{t}; it should be near
#' zero. Standard errors come from the cluster bootstrap. Unlike the two-way
#' estimator, \eqn{DID_M} never uses a unit whose treatment changed as a control
#' in the period it changed.
#'
#' @inheritParams plndid
#' @inheritParams stgatt
#' @return A data frame of class \code{rmbl_switching_did}, two rows
#'   (\code{effect}, \code{placebo}): \code{estimate}, \code{se}, \code{lower},
#'   \code{upper}, \code{switchers}.
#' @references de Chaisemartin C, D'Haultfoeuille X (2020). Two-way fixed
#'   effects estimators with heterogeneous treatment effects. American Economic
#'   Review 110(9):2964-2996. \doi{10.1257/aer.20181169}
#'
#' Applied as a placebo check on ward redistricting: Ternullo S, Zorro-Medina A,
#' Vargas R (2024). How political dynasties concentrate advantage within cities.
#' Social Forces 102(4):1310-1331. \doi{10.1093/sf/soae029}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' swtdid(p, "district", "month", "crmrate", "reformed", reps = 99, seed = 1)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' swtdid(own, "town", "year", "rate", "bylaw", reps = 49, seed = 1)
#' @export
swtdid <- function(
  data,
  unit,
  time,
  y,
  trtd,
  cl = NULL,
  reps = 499L,
  seed = NULL,
  conflvl = 0.95
) {
  conflvl <- .rmbl_conf_level(conflvl)
  reps <- .rmbl_scalar(reps, "reps", 0, 1e5, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, y)
  sw <- .rmbl_sw_wide(data, trtd, cl, p)
  e0 <- .rmbl_sw_est(seq_len(sw$nu), sw)
  if (!is.finite(e0[1L])) {
    stop(
      .rmbl_fn(),
      "no unit switches treatment against a unit that did not",
      call. = FALSE
    )
  }
  se <- .rmbl_sw_boot(sw, reps, seed)
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  out <- data.frame(
    term = c("effect", "placebo"),
    estimate = e0[1:2],
    se = se,
    lower = e0[1:2] - z * se,
    upper = e0[1:2] + z * se,
    switchers = e0[3:4],
    stringsAsFactors = FALSE
  )
  class(out) <- c("rmbl_switching_did", "data.frame")
  out
}

#' @export
format.rmbl_switching_did <- function(x, digits = 4L, ...) {
  title <- "Difference in differences, switching treatment"
  need <- c("term", "estimate", "lower", "upper")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  i <- match("effect", x$term)
  j <- match("placebo", x$term)
  .rmbl_res_block(
    title,
    facts = list(
      Method = "de Chaisemartin and D'Haultfoeuille, switchers vs stayers",
      Switchers = if (!is.na(i)) x$switchers[i]
    ),
    tables = .rmbl_ci_cols(.rmbl_plain(x)),
    reading = c(
      .rmbl_est_reading(
        "At the moment units switch, the effect is",
        x$estimate[i],
        x$lower[i],
        x$upper[i]
      ),
      if (!is.na(j) && is.finite(x$estimate[j])) {
        sprintf(
          paste(
            "The placebo, the same comparison one period earlier, is %s;",
            "near zero supports the design."
          ),
          .rmbl_fmt_num(x$estimate[j])
        )
      }
    ),
    notes = "Intervals are normal, from the cluster-bootstrap standard error.",
    digits = digits
  )
}

# ---- permutation inference and stepdown --------------------------------------

#' Permutation inference for a policy's adoption
#'
#' Re-assigns the adoption dates across clusters (all the distinct assignments
#' when there are few, random ones otherwise), re-estimates the difference in
#' differences each time, and gives the share of assignments with an effect at
#' least as large; for several outcomes, also the Westfall-Young stepdown
#' p-values that hold the family-wise error rate.
#'
#' @details The adoption period of each cluster (for example a judicial
#' district's stage of a reform) is shuffled among the clusters, keeping the
#' number of clusters adopting at each date, and \code{\link{plndid}}'s estimate
#' (\code{statistic = "estimate"}) or t statistic (\code{"t"}, the default) is
#' recomputed. With \eqn{b} of \eqn{R} random assignments at least as extreme as
#' observed, \eqn{p = (b + 1)/(R + 1)}; when every distinct assignment is
#' enumerated (their number is at most \code{reps}), \eqn{p} is the exact share.
#' The test is Fisher's: it is valid in any sample when adoption dates were
#' assigned at random across clusters.
#'
#' For several outcomes, the same assignments give \code{\link{stpdnpv}}.
#'
#' A placebo date is the same analysis with \code{ftreat} moved earlier, on the
#' periods before the real adoption.
#'
#' @inheritParams evstudy
#' @param unit,time Column names: the unit and the period (numeric).
#' @param y One outcome column, or several.
#' @param stat \code{"t"} (default) or \code{"estimate"}.
#' @param reps The number of random assignments (default 999).
#' @param seed Optional seed for the random assignments, or NULL for none.
#' @param ties \code{"count"} (default): an assignment whose statistic equals
#'   the observed one counts (the observed assignment is among those enumerated,
#'   so the exact p-value is at least \eqn{1/N}); \code{"strict"}: only larger
#'   ones count.
#' @return A data frame of class \code{rmbl_permutation}, one row per outcome:
#'   \code{outcome}, \code{estimate}, \code{statistic}, \code{p_value},
#'   \code{pstpdn}, \code{assignments}, \code{exact}; attribute \code{null} (the
#'   matrix of permuted statistics).
#' @references Fisher RA (1935). The Design of Experiments. Oliver and Boyd,
#'   Edinburgh.
#'
#' Applied with the four stages of a reform permuted across districts: Acosta,
#' Mejia and Zorro Medina (2023), see \code{\link{plndid}}.
#' @seealso \code{\link{stpdnpv}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' perminf(p, "district", "month", c("crmrate", "arrrate"),
#'                       "refmonth",
#'                       cl = "region", reps = 199, seed = 3)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # every assignment of the two adoption dates to the eight towns
#' perminf(own, "town", "year", "rate", "first", reps = 99, seed = 1)
#' @export
perminf <- function(
  data,
  unit,
  time,
  y,
  ftreat,
  cl = NULL,
  stat = c("t", "estimate"),
  reps = 999L,
  seed = NULL,
  ties = c("count", "strict")
) {
  stat <- .rmbl_arg(stat)
  ties <- .rmbl_arg(ties)
  reps <- .rmbl_scalar(reps, "reps", 9, 1e6, integer = TRUE)
  y <- .rmbl_colnames(y, "y", several = TRUE)
  p <- .rmbl_panel(data, unit, time, y[1L])
  g <- .rmbl_first_treated(data, ftreat, p)
  .cl <- .rmbl_cluster(data, cl, p)
  gc <- tapply(g, .cl, function(z) z[1L])
  if (any(tapply(g, .cl, function(z) length(unique(z))) > 1L)) {
    stop(
      .rmbl_fn(),
      "`ftreat` must be the same for every unit of a cluster",
      call. = FALSE
    )
  }
  ctx <- list(
    data = data,
    unit = unit,
    time = time,
    cl = cl,
    .cl = .cl,
    stat = stat
  )
  obs <- vapply(y, function(oc) .rmbl_perm_stat(gc, oc, ctx), numeric(1L))
  est <- vapply(y, .rmbl_perm_est, numeric(1L), ctx = ctx, g = g)
  pd <- .rmbl_perm_draws(gc, reps, seed)
  perms <- pd$perms
  exact <- pd$exact
  null <- matrix(NA_real_, nrow(perms), length(y), dimnames = list(NULL, y))
  for (r in seq_len(nrow(perms))) {
    for (j in seq_along(y)) {
      null[r, j] <- .rmbl_perm_stat(perms[r, ], y[j], ctx)
    }
  }
  pv <- .rmbl_perm_pv(null, obs, ties, exact)
  out <- data.frame(
    outcome = y,
    estimate = unname(est),
    statistic = unname(obs),
    p_value = pv,
    pstpdn = if (length(y) > 1L) stpdnpv(obs, null) else pv,
    assignments = nrow(perms),
    exact = exact,
    stringsAsFactors = FALSE
  )
  attr(out, "null") <- null
  class(out) <- c("rmbl_permutation", "data.frame")
  out
}

#' @export
format.rmbl_permutation <- function(x, digits = 4L, ...) {
  title <- "Permutation inference"
  need <- c("outcome", "estimate", "statistic", "p_value")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x, c(need, "pstpdn"))
  names(d)[names(d) == "pstpdn"] <- "stepdown_p"
  .rmbl_res_block(
    title,
    facts = list(
      Method = "randomisation inference on the adoption dates",
      Assignments = x$assignments[1L],
      Draws = if (isTRUE(x$exact[1L])) {
        "every assignment (exact)"
      } else {
        "random draws"
      },
      Outcomes = nrow(x)
    ),
    tables = d,
    reading = c(
      paste(
        "The p-value is the share of reassigned adoption dates that give a",
        "statistic at least as extreme as the one observed; it needs no",
        "model of the errors."
      ),
      if (nrow(x) > 1L) {
        paste(
          "The stepdown p-values (Westfall and Young) hold for all the",
          "outcomes tested together."
        )
      }
    ),
    digits = digits
  )
}

#' Westfall-Young stepdown p-values
#'
#' Adjusted p-values for several hypotheses tested together, from the joint null
#' distribution of their statistics (permutations or bootstrap draws), holding
#' the family-wise error rate while using the correlation between the tests.
#'
#' @details The statistics are ordered by size, \eqn{|t_{(1)}| \ge \dots \ge
#' |t_{(K)}|}. For each null draw \eqn{b}, \eqn{q_{b,j} = \max_{r \ge j}
#' |t^*_{b,(r)}|}. The adjusted p-value of the \eqn{j}th is the share of draws
#' with \eqn{q_{b,j} \ge |t_{(j)}|}, made monotone: \eqn{\tilde p_{(j)} =
#' \max(\tilde p_{(j-1)}, p_{(j)})} (Westfall and Young 1993, algorithm 2.8).
#'
#' @param obs The observed statistics, one per hypothesis.
#' @param null A matrix of statistics under the null: one row per draw, one
#'   column per hypothesis.
#' @return The adjusted p-values, in the order of \code{observed}.
#' @references Westfall PH, Young SS (1993). Resampling-Based Multiple Testing.
#' Wiley, New York.
#' @seealso \code{\link{perminf}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(1)
#' null <- matrix(rnorm(3000), ncol = 3)
#' stpdnpv(c(2.5, 0.4, -2.1), null)
#' @export
stpdnpv <- function(obs, null) {
  obs <- .rmbl_num(obs, "obs")
  if (!is.matrix(null) || !is.numeric(null) || ncol(null) != length(obs)) {
    stop(
      .rmbl_fn(),
      "`null` must be a numeric matrix with one column per observed statistic",
      call. = FALSE
    )
  }
  if (anyNA(obs)) {
    stop(.rmbl_fn(), "`obs` must have no NA", call. = FALSE)
  }
  null <- null[stats::complete.cases(null), , drop = FALSE]
  if (!nrow(null)) {
    stop(.rmbl_fn(), "`null` has no complete draw", call. = FALSE)
  }
  o <- order(-abs(obs))
  a <- abs(null[, o, drop = FALSE])
  k <- length(o)
  q <- a
  if (k > 1L) {
    for (j in (k - 1L):1L) {
      q[, j] <- pmax(q[, j], q[, j + 1L])
    }
  }
  p <- colMeans(sweep(q, 2L, abs(obs[o]) - 1e-12, `>=`))
  p <- cummax(p)
  out <- numeric(k)
  out[o] <- p
  out
}

# ---- fixed-effects Poisson ---------------------------------------------------

#' A fixed-effects Poisson or negative binomial regression for counts
#'
#' The effect of a policy on counts (stops, arrests, offences) with unit and
#' period fixed effects, reported as an incidence rate ratio, with
#' cluster-robust standard errors that do not need the counts to be Poisson.
#'
#' @details The model is \eqn{E(Y_{it}) = \exp(\beta T_{it} + X_{it}'\gamma +
#' \delta_i + \mu_t)} (times the exposure, with \code{offset} its log), fitted
#' by maximum likelihood. Units whose counts are all zero carry no information
#' about \eqn{\beta} and are dropped first, as are periods with no count
#' anywhere. The Poisson likelihood with fixed effects is consistent for
#' \eqn{\beta} whatever the dispersion (Wooldridge 1999); the variance is the
#' cluster-robust sandwich, with the small-sample factors of
#' \code{\link{plndid}}. The rate ratio is \eqn{e^{\beta}}, with interval
#' \eqn{e^{\hat\beta \pm z\,se}}.
#'
#' With \code{family = "negbin"} the variance is \eqn{\mu + \mu^2/\theta}: the
#' fit alternates iteratively reweighted least squares at fixed \eqn{\theta}
#' with the maximum of the profile likelihood in \eqn{\theta}, and the sandwich
#' uses the negative binomial scores with \eqn{\theta} held at its estimate (as
#' \code{sandwich::vcovCL()} does for \code{MASS::glm.nb()};
#' \code{fixest::fenegbin()}, which treats \eqn{\theta} as a parameter of the
#' variance too, gives slightly larger errors). With unit dummies this is the
#' unconditional fixed-effects negative binomial, which behaves well as the
#' number of periods grows (Allison and Waterman 2002); with few periods per
#' unit prefer the Poisson, which is consistent whatever the dispersion.
#'
#' @inheritParams plndid
#' @param offset Optional column name of the log exposure (for example log
#'   population).
#' @param family \code{"poisson"} (default) or \code{"negbin"} (NB2, \eqn{Var(Y)
#'   = \mu + \mu^2/\theta}, with \eqn{\theta} by maximum likelihood).
#' @return A data frame of class \code{rmbl_fe_poisson}, one row per term:
#'   \code{term}, \code{estimate} (log scale), \code{se}, \code{rateratio},
#'   \code{lower}, \code{upper} (of the rate ratio), \code{p_value}; attributes
#'   \code{n}, \code{drounits}, \code{clusters}, \code{family}, \code{theta}
#'   (\code{Inf} for the Poisson).
#' @references Wooldridge JM (1999). Distribution-free estimation of some
#' nonlinear panel data models. Journal of Econometrics 90(1):77-97.
#' \doi{10.1016/S0304-4076(98)00033-5}
#'
#' Santos Silva JMC, Tenreyro S (2006). The log of gravity. Review of Economics
#' and Statistics 88(4):641-658. \doi{10.1162/rest.88.4.641}
#'
#' Allison PD, Waterman RP (2002). Fixed-effects negative binomial regression
#' models. Sociological Methodology 32:247-265. \doi{10.1111/1467-9531.00117}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop")
#'
#' # these counts are not overdispersed, so the negative binomial collapses
#' # to the Poisson fit and says so
#' plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop",
#'            family = "negbin")
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # counts with the population as exposure
#' own$crimes <- round(own$rate * own$pop / 1e4)
#' own$logpop <- log(own$pop)
#' plnpois(own, "town", "year", "crimes", "bylaw", offset = "logpop")
#' @export
plnpois <- function(
  data,
  unit,
  time,
  y,
  trtd,
  covs = NULL,
  offset = NULL,
  cl = NULL,
  family = c("poisson", "negbin"),
  conflvl = 0.95
) {
  family <- .rmbl_arg(family)
  conflvl <- .rmbl_conf_level(conflvl)
  p <- .rmbl_panel(data, unit, time, y)
  if (any(p$y < 0)) {
    stop(.rmbl_fn(), "`y` must be counts (0 or more)", call. = FALSE)
  }
  d <- .rmbl_pp_trtd(data, trtd)
  off <- .rmbl_pp_offset(data, offset, length(p$y))
  .cl <- .rmbl_cluster(data, cl, p)
  x <- cbind(treated = d, .rmbl_covariates(data, covs))
  keep <- (tapply(p$y, p$u, sum) > 0)[p$u] &
    (tapply(p$y, p$t, sum) > 0)[as.character(p$t)]
  dropped <- length(unique(p$u)) - length(unique(p$u[keep]))
  .y <- p$y[keep]
  fu <- factor(p$u[keep])
  ft <- factor(p$t[keep])
  xx <- x[keep, , drop = FALSE]
  X <- cbind(xx, stats::model.matrix(~ fu + ft))
  fit <- stats::glm.fit(X, .y, family = stats::poisson(), offset = off[keep])
  theta <- Inf
  if (family == "negbin") {
    nbf <- .rmbl_pp_negbin(X, .y, fit, off[keep])
    fit <- nbf$fit
    theta <- nbf$theta
  }
  if (!fit$converged) {
    warning("the count model did not converge", call. = FALSE)
  }
  ok <- !is.na(fit$coefficients)
  if (!all(ok[seq_len(ncol(xx))])) {
    stop(
      .rmbl_fn(),
      "a regressor is collinear with the fixed effects",
      call. = FALSE
    )
  }
  X <- X[, ok, drop = FALSE]
  vg <- .rmbl_pp_vcov(X, fit, theta, .y, .cl[keep], list(fu, ft), ncol(xx))
  gn <- vg$gn
  out <- .rmbl_pp_table(colnames(x), fit, vg$vc, ncol(xx), conflvl)
  attr(out, "n") <- length(.y)
  attr(out, "drounits") <- dropped
  attr(out, "clusters") <- gn
  attr(out, "family") <- family
  attr(out, "theta") <- theta
  class(out) <- c("rmbl_fe_poisson", "data.frame")
  out
}

#' @export
format.rmbl_fe_poisson <- function(x, digits = 4L, ...) {
  title <- "Fixed-effects count model"
  need <- c("term", "estimate", "rateratio", "lower", "upper")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x, c(need[1:2], "se", need[3:5], "p_value"))
  names(d)[names(d) == "rateratio"] <- "rate_ratio"
  dr <- attr(x, "drounits")
  .rmbl_res_block(
    title,
    facts = list(
      Model = .rmbl_pp_model(attr(x, "family"), attr(x, "theta")),
      `Fixed effects` = "unit and period",
      Observations = attr(x, "n"),
      Clusters = attr(x, "clusters"),
      `Units dropped` = if (isTRUE(dr > 0)) dr
    ),
    tables = .rmbl_ci_cols(d),
    reading = .rmbl_rr_reading(
      "Under the policy the expected count is multiplied by",
      x$rateratio[1L],
      x$lower[1L],
      x$upper[1L]
    ),
    notes = c(
      "The estimate is on the log scale; the interval is for the rate ratio.",
      if (isTRUE(dr > 0)) {
        sprintf(
          paste(
            "%d unit(s) with no events in any period were dropped: they",
            "carry no information in a fixed-effects count model."
          ),
          dr
        )
      }
    ),
    digits = digits
  )
}

# ---- synthetic control -------------------------------------------------------

#' Synthetic control for one treated unit
#'
#' A weighted average of untreated units that tracks the treated unit before the
#' policy, as its counterfactual after; with the placebo test that runs the same
#' method on every untreated unit.
#'
#' @details The weights solve \deqn{\min_w \sum_{t < T_0} \Big(Y_{1t} - \sum_j
#' w_j Y_{jt}\Big)^2 \quad \textrm{s.t.} \quad w_j \ge 0,\ \sum_j w_j =
#' 1,}{min_w sum_(t < T0) (Y_1t - sum_j w_j Y_jt)^2, w_j >= 0, sum_j w_j = 1,}
#' over the periods before adoption \eqn{T_0} (accelerated projected gradient
#' onto the simplex; the problem is convex, so the solution is the global one).
#' The effect in each period is the gap \eqn{Y_{1t} - \sum_j w_j Y_{jt}}. For
#' inference, each untreated unit in turn is treated as if it had adopted the
#' policy, with the other untreated units as donors; the ratio of root mean
#' squared gap after to before adoption ranks the real unit among the placebos,
#' and \eqn{p} is its rank over the number of units (Abadie, Diamond and
#' Hainmueller 2010).
#'
#' This version matches on the pre-period outcomes only, not on separate
#' predictors.
#'
#' @inheritParams plndid
#' @param treunit The treated unit (a value of \code{unit}).
#' @param adopt The first treated period.
#' @param plac Run the placebo test (default \code{TRUE}).
#' @return A list of class \code{rmbl_synth}: \code{weights} (a named vector
#'   over the donors), \code{path} (a data frame: \code{time}, \code{treated},
#'   \code{synthetic}, \code{gap}), \code{rmspepre}, \code{rmsperatio},
#'   \code{p_value} (\code{NA} without the placebo), \code{placrat}.
#'   \code{plot()} draws the two paths and the gap.
#' @references Abadie A, Diamond A, Hainmueller J (2010). Synthetic control
#'   methods for comparative case studies. Journal of the American Statistical
#'   Association 105(490):493-505.\cr \doi{10.1198/jasa.2009.ap08746}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' p <- polex()
#' p1 <- p[is.na(p$refmonth) | p$district == "D01", ]
#' s <- synctl(p1, "district", "month", "crmrate", treunit = "D01",
#'                        adopt = 13)
#' round(s$weights, 3)
#' s$p_value
#' plot(s)
#'
#' # your own panel: eight towns over ten years, four adopting a by-law (two
#' # in 2019, two in 2021), with each town's population, county and income
#' own <- data.frame(
#'   town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
#'   year = rep(2015:2024, times = 8)
#' )
#' i <- match(own$town, unique(own$town))
#' own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
#' own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
#' own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
#' own$county <- rep(c("North", "South"), 4)[i]
#' own$income <- 50 + own$year - 2015 + cos(seq_len(80))
#' own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
#'   0.2 * own$income + sin(seq_len(80))
#' # one treated town, A, against the four towns never treated
#' own1 <- own[is.na(own$first) | own$town == "A", ]
#' synctl(own1, "town", "year", "rate", treunit = "A", adopt = 2019)
#' @export
synctl <- function(data, unit, time, y, treunit, adopt, plac = TRUE) {
  p <- .rmbl_panel(data, unit, time, y)
  adopt <- .rmbl_scalar(adopt, "adopt")
  if (!is.logical(plac) || length(plac) != 1L || is.na(plac)) {
    stop(.rmbl_fn(), "`plac` must be TRUE or FALSE", call. = FALSE)
  }
  .rmbl_no_fn(treunit = treunit)
  tu <- .rmbl_sc_unit(treunit, p)
  sc <- .rmbl_sc_wide(p, adopt)
  ym <- sc$ym
  it <- match(tu, p$ul)
  donors <- setdiff(seq_along(p$ul), it)
  f <- .rmbl_sc_fit(it, donors, sc, p$ul)
  ratio <- f$post / f$pre
  pr <- NA_real_
  pv <- NA_real_
  if (plac) {
    pr <- .rmbl_sc_placebo(donors, sc, p$ul)
    pv <- (1 + sum(pr >= ratio - 1e-12)) / (1 + length(pr))
  }
  out <- list(
    weights = f$w,
    path = data.frame(
      time = p$tl,
      treated = ym[it, ],
      synthetic = f$synth,
      gap = f$gap,
      row.names = NULL
    ),
    rmspepre = f$pre,
    rmsperatio = ratio,
    p_value = pv,
    placrat = pr,
    adoption = adopt,
    treunit = tu
  )
  class(out) <- "rmbl_synth"
  out
}

#' @export
format.rmbl_synth <- function(x, digits = 4L, ...) {
  w <- x$weights
  w <- sort(w[w > 1e-4], decreasing = TRUE)
  post <- x$path$gap[x$path$time >= x$adoption]
  plac <- isTRUE(is.finite(x$p_value))
  .rmbl_res_block(
    "Synthetic control",
    facts = list(
      `Treated unit` = x$treunit,
      Adoption = format(x$adoption),
      Donors = length(x$weights),
      `Donors with weight` = length(w),
      `Pre-period RMSPE` = x$rmspepre,
      `Mean gap after` = if (length(post)) mean(post),
      `Post/pre RMSPE ratio` = x$rmsperatio,
      `Placebo-in-space p` = if (plac) .rmbl_fmt_p(x$p_value),
      Placebos = if (plac) length(x$placrat)
    ),
    tables = list(
      `Donor weights` = data.frame(
        donor = names(w) %||% rep("", length(w)),
        weight = unname(w),
        stringsAsFactors = FALSE
      )
    ),
    reading = .rmbl_synth_reading(x, post, plac),
    digits = digits,
    maxrows = 12L
  )
}

#' @rdname plot-methods
#' @export
plot.rmbl_synth <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_synth")
  d <- x$path
  cl <- .bl_cols(2L, col, palette)
  graphics::matplot(
    d$time,
    cbind(d$treated, d$synthetic),
    type = "l",
    lty = c(1, 2),
    col = cl,
    lwd = 2,
    xlab = "Period",
    ylab = "Outcome",
    main = "",
    ...
  )
  .bl_title(.bl_main(main, paste("Synthetic control:", x$treunit)))
  graphics::abline(v = x$adoption, lty = 3, col = "#9A9A9A")
  graphics::legend(
    "topleft",
    c(x$treunit, "Synthetic"),
    lty = c(1, 2),
    col = cl,
    lwd = 2,
    bty = "n"
  )
  invisible(d)
}

# ---- measures ----------------------------------------------------------------

#' A severity-weighted crime index
#'
#' Offence rates combined into one index, unweighted (the sum of rates) and
#' weighted by each offence's severity (for example its mean statutory
#' sentence), per unit and period.
#'
#' @details With \eqn{r_{k}} the rate of offence \eqn{k} per \code{per}
#' residents and \eqn{w_k} its weight, the indices are \eqn{\sum_k r_k} and
#' \eqn{\sum_k w_k r_k}. Mean statutory sentence lengths are one choice of
#' weight (as in Acosta, Mejia and Zorro Medina 2023); sentencing guidelines are
#' another (the Cambridge Crime Harm Index, Sherman, Neyroud and Neyroud 2016).
#' The weights are the analyst's to state and defend: the index records them. A
#' unit-period missing an offence that has a weight gets \code{NA}, never a
#' partial sum.
#'
#' @param data A data frame, one row per unit, period and offence.
#' @param unit,time,offence,count Column names.
#' @param w Named weights, one per offence counted.
#' @param pop Optional column name of the population; without it \code{count}
#'   is taken as a rate already.
#' @param per Rate base (default 100000).
#' @return A data frame of class \code{rmbl_severity}: \code{unit}, \code{time},
#'   \code{unweighted}, \code{weighted}; attribute \code{weights}.
#' @references Sherman L, Neyroud PW, Neyroud E (2016). The Cambridge Crime Harm
#' Index: measuring total harm from crime based on sentencing guidelines.
#' Policing 10(3):171-183. \doi{10.1093/police/paw003}
#'
#' Applied with weights from the Colombian Penal Code: Acosta, Mejia and Zorro
#' Medina (2023), see \code{\link{plndid}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- data.frame(
#'   city = rep(c("A", "B"), each = 3),
#'   year = 2024,
#'   offence = rep(c("homicide", "robbery", "burglary"), 2),
#'   n = c(5, 120, 300, 2, 90, 410),
#'   pop = rep(c(250000, 180000), each = 3)
#' )
#' sevidx(
#'   d,
#'   "city",
#'   "year",
#'   "offence",
#'   "n",
#'   w = c(homicide = 25, robbery = 8, burglary = 4),
#'   pop = "pop"
#' )
#' @export
sevidx <- function(data, unit, time, offence, count, w, pop = NULL, per = 1e5) {
  .rmbl_df_names(data)
  .rmbl_sev_check(
    data,
    list(unit = unit, time = time, offence = offence, count = count),
    w
  )
  per <- .rmbl_scalar(per, "per", 1e-12)
  off <- trimws(as.character(data[[offence]]))
  miss <- setdiff(names(w), off)
  if (length(miss)) {
    stop(
      .rmbl_fn(),
      sprintf("not an offence of `data`: %s", toString(miss)),
      call. = FALSE
    )
  }
  r <- .rmbl_num(data[[count]], "count")
  if (!is.null(pop)) {
    r <- r / .rmbl_num(data[[.rmbl_colnames(pop, "pop")]], "pop") * per
  }
  use <- off %in% names(w)
  key <- paste(data[[unit]], data[[time]], sep = "\r")
  if (anyDuplicated(paste(key, off)[use])) {
    stop(
      .rmbl_fn(),
      "an offence appears twice for a unit and period",
      call. = FALSE
    )
  }
  keys <- unique(key)
  first <- match(keys, key)
  out <- data.frame(
    unit = data[[unit]][first],
    time = data[[time]][first],
    unweighted = .rmbl_sev_agg(r, use, key, keys, length(w)),
    weighted = .rmbl_sev_agg(r * unname(w[off]), use, key, keys, length(w)),
    stringsAsFactors = FALSE
  )
  attr(out, "weights") <- w
  class(out) <- c("rmbl_severity", "data.frame")
  out
}

#' @export
format.rmbl_severity <- function(x, digits = 4L, ...) {
  title <- "Severity-weighted index"
  need <- c("unit", "time", "unweighted", "weighted")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  w <- attr(x, "weights")
  .rmbl_res_block(
    title,
    facts = list(
      Rows = nrow(x),
      Units = length(unique(x$unit)),
      Periods = length(unique(x$time)),
      `Offences weighted` = length(w)
    ),
    tables = list(
      Index = .rmbl_plain(x, need),
      Weights = if (length(w)) {
        data.frame(
          offence = names(w) %||% "",
          weight = unname(w),
          stringsAsFactors = FALSE
        )
      }
    ),
    reading = paste(
      "The weighted index adds each offence's count (or rate) times its",
      "severity weight; beside the unweighted total it shows whether the mix",
      "of offences moved, not only their number."
    ),
    digits = digits
  )
}

#' Justice-pipeline rates with a lag between stages
#'
#' The rate at which one stage of the justice process follows another (charges
#' per reported offence, settlements per charge, convictions per trial), summing
#' each over a window and setting the outcome's window after the input's,
#' because cases take time to move through.
#'
#' @details For period \eqn{t}, a window of \eqn{W} periods and a lag of
#' \eqn{L}, \deqn{R_t = \frac{\sum_{s = t - W + 1}^{t} O_s}{\sum_{s = t - L - W
#' + 1}^{t - L} I_s},}{R_t = sum(O over t - W + 1 .. t) / sum(I over t - L - W +
#' 1 .. t - L),} with \eqn{O} the outcome stage and \eqn{I} the input stage.
#' With \eqn{W = 1, L = 0} it is the same-period ratio (cases with detention
#' over cases charged; acquittals over acquittals and convictions). Rates are
#' \code{NA} until the windows are filled, and when the denominator is zero.
#' These are administrative counts of every case, so no sampling interval is
#' given.
#'
#' @param num,den The outcome and input counts, in period order.
#' @param win The number of periods summed (default 12).
#' @param lag The number of periods the input's window precedes the outcome's
#' (default 0).
#' @param grp Optional grouping (for example a court or municipality), the
#'   counts in period order within it.
#' @return A data frame of class \code{rmbl_pipeline_rate}: \code{group},
#'   \code{index} (the period's position
#'   within its group), \code{numerator}, \code{denominator} (the window sums),
#'   \code{rate}.
#' @references Council of Europe, European Commission for the Efficiency of
#'   Justice (CEPEJ) (2014). European judicial systems: efficiency and quality
#'   of justice. CEPEJ Studies 20.
#'
#' Applied to the stages of a Colombian criminal-procedure reform: Acosta, Mejia
#' and Zorro Medina (2023), see \code{\link{plndid}}.
#' @seealso \code{\link{caseflow}} for clearance rates and inventories.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(2)
#' reports <- rpois(36, 400)
#' charges <- rpois(36, 90)
#' piperate(charges, reports, win = 12, lag = 3)[30:36, ]
#' @export
piperate <- function(num, den, win = 12L, lag = 0L, grp = NULL) {
  num <- .rmbl_num(num, "num")
  den <- .rmbl_num(den, "den")
  if (length(num) != length(den)) {
    stop(.rmbl_fn(), "`num` and `den` must be the same length", call. = FALSE)
  }
  if (any(c(num, den) < 0, na.rm = TRUE)) {
    stop(.rmbl_fn(), "counts must not be negative", call. = FALSE)
  }
  win <- .rmbl_scalar(win, "win", 1, 1e6, integer = TRUE)
  lag <- .rmbl_scalar(lag, "lag", 0, 1e6, integer = TRUE)
  if (is.null(grp)) {
    grp <- rep("all", length(num))
  }
  if (length(grp) != length(num)) {
    stop(.rmbl_fn(), "`grp` must be one per count", call. = FALSE)
  }
  roll <- function(x, end) {
    vapply(
      end,
      function(e) if (e - win + 1L < 1L) NA_real_ else sum(x[(e - win + 1L):e]),
      numeric(1L)
    )
  }
  out <- do.call(
    rbind,
    lapply(unique(grp), function(gr) {
      i <- which(grp == gr)
      n <- length(i)
      .num <- roll(num[i], seq_len(n))
      .den <- roll(den[i], seq_len(n) - lag)
      data.frame(
        group = gr,
        index = seq_len(n),
        numerator = .num,
        denominator = .den,
        rate = ifelse(is.finite(.den) & .den > 0, .num / .den, NA_real_),
        stringsAsFactors = FALSE
      )
    })
  )
  rownames(out) <- NULL
  class(out) <- c("rmbl_pipeline_rate", class(out))
  out
}

#' @export
format.rmbl_pipeline_rate <- function(x, digits = 4L, ...) {
  title <- "Lagged pipeline rate"
  need <- c("group", "index", "numerator", "denominator", "rate")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  .rmbl_res_block(
    title,
    facts = list(
      Groups = length(unique(x$group)),
      Periods = if (nrow(x)) max(x$index),
      `Rates computed` = sum(!is.na(x$rate))
    ),
    tables = .rmbl_plain(x, need),
    reading = paste(
      "Each rate is the numerator summed over the window over the",
      "denominator summed over the same window moved back by the lag (cases",
      "out over cases in earlier); it is missing until a full window is in."
    ),
    digits = digits
  )
}

#' Cumulative risk of a first event by age
#'
#' The chance that a person experiences an event (a first arrest, a first
#' conviction, a first jail stay, a first child protection placement) by each
#' age, from first events and the population by age, as a synthetic cohort; with
#' mortality as a competing risk when deaths are given.
#'
#' @details With \eqn{E_a} first events at age \eqn{a} and \eqn{N_a} persons at
#' risk (those who have not had the event), the hazard is \eqn{h_a = E_a/N_a}.
#' When only the population \eqn{P_a} is known, the persons at risk are taken as
#' \eqn{P_a(1 - CR_{a-1})} (the synthetic-cohort assumption). Without mortality,
#' \eqn{CR_a = 1 - \prod_{x \le a}(1 - h_x)}. With death rates \eqn{q_x}, the
#' multiple-decrement table carries survivors \eqn{l_{x+1} = l_x(1 - h_x - q_x)}
#' and \eqn{CR_a = \sum_{x \le a} l_x h_x / l_0}, the risk of the event before
#' death. The interval (without mortality) is Greenwood's on the log of the
#' survival: \eqn{\mathrm{Var}(\log S_a) = \sum_{x \le a} h_x/(N_x(1 - h_x))}.
#'
#' Counting first events needs records that link a person's events over time; an
#' agency's counts of all events overstate first events. Events of people who do
#' not live in the area, counted against its population, bias the risk upward.
#'
#' @param age The ages, in order.
#' @param fireve First events at each age.
#' @param pop The population at each age.
#' @param atrisk Optional: the persons at risk at each age, when known, in place
#'   of the synthetic-cohort assumption.
#' @param dthrate Optional death rates by age (probability of dying within the
#'   age).
#' @param conflvl Confidence level of the cumulative risk limits (default 0.95).
#' @return A data frame of class \code{rmbl_cumrisk}: \code{age},
#'   \code{hazard}, \code{atrisk},
#'   \code{cmlrisk}, \code{lower}, \code{upper}.
#' @references Bonczar TP (2003). Prevalence of imprisonment in the U.S.
#'   population, 1974-2001. Bureau of Justice Statistics, NCJ 197976.
#'
#' Applied to arrests, convictions and jail in New York City: Hepburn P,
#' Kohler-Hausmann I, Zorro Medina A (2019). Cumulative risks of multiple
#' criminal justice outcomes in New York City. Demography 56(3):1161-1171.
#' \doi{10.1007/s13524-019-00781-7}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' age <- 16:25
#' first <- c(900, 1400, 1700, 1600, 1400, 1100, 900, 700, 600, 500)
#' pop <- rep(100000, 10)
#' cmlrisk(age, first, pop)
#' @export
cmlrisk <- function(
  age,
  fireve,
  pop,
  atrisk = NULL,
  dthrate = NULL,
  conflvl = 0.95
) {
  age <- .rmbl_num(age, "age")
  e <- .rmbl_num(fireve, "fireve")
  .pop <- .rmbl_num(pop, "pop")
  conflvl <- .rmbl_conf_level(conflvl)
  n <- length(age)
  .rmbl_cr_check(age, e, .pop)
  if (!is.null(atrisk)) {
    atrisk <- .rmbl_cr_opt(atrisk, "atrisk", n)
  }
  if (!is.null(dthrate)) {
    dthrate <- .rmbl_cr_opt(dthrate, "dthrate", n)
  }
  lt <- .rmbl_cr_life(age, e, .pop, atrisk, dthrate)
  h <- lt$h
  nr <- lt$nr
  cr <- lt$cr
  v <- lt$v
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  s <- 1 - cr
  out <- data.frame(
    age = age,
    hazard = h,
    atrisk = nr,
    cumrisk = cr,
    lower = 1 - s * exp(z * sqrt(v)),
    upper = 1 - s * exp(-z * sqrt(v))
  )
  class(out) <- c("rmbl_cumrisk", class(out))
  out
}

#' @export
format.rmbl_cumrisk <- function(x, digits = 4L, ...) {
  title <- "Cumulative risk of a first event"
  need <- c("age", "hazard", "atrisk", "cumrisk", "lower", "upper")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  k <- nrow(x)
  .rmbl_res_block(
    title,
    facts = list(
      Ages = if (k) sprintf("%s to %s", min(x$age), max(x$age)),
      `Risk by the last age` = if (k) {
        paste0(
          .rmbl_fmt_num(100 * x$cumrisk[k], 3L),
          "% ",
          .rmbl_fmt_ci(100 * x$lower[k], 100 * x$upper[k], 3L)
        )
      }
    ),
    tables = .rmbl_ci_cols(.rmbl_plain(x, need)),
    reading = if (k) {
      sprintf(
        paste(
          "By age %s an estimated %s%% of the population have had a first",
          "event, from the age-specific first-event hazards of a life table."
        ),
        format(x$age[k]),
        .rmbl_fmt_num(100 * x$cumrisk[k], 3L)
      )
    },
    digits = digits,
    maxrows = 40L
  )
}

#' Treated, comparison and excluded places around sites
#'
#' Assigns each place (a block, an address) to the treated group when it lies
#' within a radius of a site (a store that donated, a new facility), to the
#' comparison group when it lies within the same radius of a comparison point
#' and farther than a buffer from every site, and excludes it otherwise, so that
#' spillover from the sites does not reach the comparison.
#'
#' @details Distances are Euclidean, so coordinates must be projected (metres or
#' feet, not degrees). The radius and the buffer are in the same unit. The
#' buffer should be several times the radius: the design it follows used 330
#' feet and 990 feet.
#'
#' @param x,y Coordinates of the places.
#' @param sitex,sitey Coordinates of the sites.
#' @param comx,comy Coordinates of the comparison points (for example
#' the nearest major intersections).
#' @param radius The treatment radius.
#' @param buffer The distance from every site a comparison place must keep
#'   (default \code{3 * radius}).
#' @return A data frame of class \code{rmbl_buffer} with the columns
#'   \code{group} (\code{"treated"},
#'   \code{"comparison"} or \code{"excluded"}), \code{site_distance} and
#'   \code{comparison_distance}.
#' @references Applied to blocks near donor stores: Zorro Medina, Hackett, Green
#'   and Vargas (2025), see \code{\link{evstudy}}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' set.seed(4)
#' x <- runif(200, 0, 5000)
#' y <- runif(200, 0, 5000)
#' a <- bufasgn(x, y, c(1000, 3500), c(1200, 3000), c(2500, 4500), c(500, 4000),
#'                    radius = 330)
#' table(a$group)
#' @export
bufasgn <- function(
  x,
  y,
  sitex,
  sitey,
  comx,
  comy,
  radius,
  buffer = 3 * radius
) {
  x <- .rmbl_num(x, "x")
  y <- .rmbl_num(y, "y")
  sx <- .rmbl_num(sitex, "sitex")
  sy <- .rmbl_num(sitey, "sitey")
  cx <- .rmbl_num(comx, "comx")
  cy <- .rmbl_num(comy, "comy")
  if (
    length(x) != length(y) ||
      length(sx) != length(sy) ||
      length(cx) != length(cy)
  ) {
    stop(
      .rmbl_fn(),
      "each pair of coordinates must be the same length",
      call. = FALSE
    )
  }
  if (!length(sx) || !length(cx)) {
    stop(
      .rmbl_fn(),
      "give one site and one comparison point at least",
      call. = FALSE
    )
  }
  if (anyNA(c(x, y, sx, sy, cx, cy))) {
    stop(.rmbl_fn(), "coordinates must have no NA", call. = FALSE)
  }
  radius <- .rmbl_scalar(radius, "radius", 1e-12)
  buffer <- .rmbl_scalar(buffer, "buffer", 0)
  near <- function(px, py) {
    vapply(
      seq_along(x),
      function(i) sqrt(min((px - x[i])^2 + (py - y[i])^2)),
      numeric(1L)
    )
  }
  ds <- near(sx, sy)
  dc <- near(cx, cy)
  outside <- ifelse(dc <= radius & ds > buffer, "comparison", "excluded")
  grp <- ifelse(ds <= radius, "treated", outside)
  out <- data.frame(group = grp, site_distance = ds, comparison_distance = dc)
  class(out) <- c("rmbl_buffer", class(out))
  out
}

#' @export
format.rmbl_buffer <- function(x, digits = 4L, ...) {
  title <- "Buffer assignment"
  need <- c("group", "site_distance", "comparison_distance")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  lv <- c("treated", "comparison", "excluded")
  .rmbl_res_block(
    title,
    facts = list(
      Points = nrow(x),
      Groups = .rmbl_tally(factor(x$group, levels = lv))
    ),
    tables = .rmbl_plain(x, need),
    reading = paste(
      "A point within the radius of a site is treated; one within the",
      "radius of a comparison point and beyond the buffer of every site is",
      "a comparison; the rest are excluded, so spillover near the sites",
      "does not blur the contrast."
    ),
    digits = digits
  )
}

#' A simulated policy panel for the examples
#'
#' Twenty districts in four regions over 36 months; a reform adopted region by
#' region in three stages (months 13, 19 and 25), with the fourth region never
#' adopting it; crime and arrest rates and counts. The numbers are made up, with
#' a known effect of the reform (a fall of 3 in the crime rate per 100,000), so
#' the examples and tests can check that each estimator recovers it.
#'
#' @param seed The seed (default 20240101).
#' @return A data frame: \code{district}, \code{region}, \code{month},
#' \code{refmonth} (\code{NA} for never), \code{reformed} (0 or 1),
#' \code{population}, \code{logpop}, \code{crimes}, \code{crmrate},
#' \code{arrrate}.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' head(polex())
#' @export
#' @srrstats {G5.1} Exported generator of the test/example panel with a known
#'   effect (-3); used across test-policy_evaluation.R and test-panel_causal.R.
polex <- function(seed = 20240101) {
  .rmbl_with_seed(seed, {
    nd <- 20L
    nm <- 36L
    dist <- sprintf("D%02d", seq_len(nd))
    # the reform reaches the four regions in stages; region R4 never adopts it
    stage <- c(13, 19, 25, NA)[(seq_len(nd) - 1L) %% 4L + 1L]
    pop <- round(stats::runif(nd, 40000, 250000))
    a <- stats::rnorm(nd, 30, 5)
    m <- stats::rnorm(nm, 0, 1.5)
    d <- expand.grid(month = seq_len(nm), i = seq_len(nd))
    d$district <- dist[d$i]
    d$region <- paste0("R", (d$i - 1L) %% 4L + 1L)
    d$refmonth <- stage[d$i]
    d$reformed <- as.numeric(!is.na(d$refmonth) & d$month >= d$refmonth)
    d$population <- pop[d$i]
    d$logpop <- log(d$population)
    lam <- pmax(1, a[d$i] + m[d$month] + 0.05 * d$month - 3 * d$reformed)
    d$crimes <- stats::rpois(nrow(d), lam * d$population / 1e5)
    d$crmrate <- round(lam + stats::rnorm(nrow(d), 0, 1), 3)
    d$arrrate <- round(
      0.4 * lam + 1.2 * d$reformed + stats::rnorm(nrow(d), 0, 0.8),
      3
    )
    d[c(
      "district",
      "region",
      "month",
      "refmonth",
      "reformed",
      "population",
      "logpop",
      "crimes",
      "crmrate",
      "arrrate"
    )]
  })
}

# ---- internal helpers --------------------------------------------------------

#' Checks the unit, time and outcome columns of a panel and returns them coded.
#' @param data The panel data frame.
#' @param unit The name of the unit column.
#' @param time The name of the numeric time column.
#' @param y The name of the outcome column.
#' @return A list with integer unit codes `u`, unit levels `ul`, times `t`,
#'   sorted unique times `tl` and outcomes `y`.
#' @noRd
.rmbl_panel <- function(data, unit, time, y) {
  .rmbl_panel_cols(data, list(unit = unit, time = time, y = y))
  # an empty panel failed later in R's words ("contrasts can be applied only
  # to factors", "length of 'dimnames' [2]")
  if (!nrow(data)) {
    stop(.rmbl_fn(), "`data` has no rows", call. = FALSE)
  }
  u <- data[[unit]]
  t <- data[[time]]
  if (!is.numeric(t) || anyNA(t)) {
    stop(
      .rmbl_fn(),
      "`time` must be a numeric column with no NA",
      call. = FALSE
    )
  }
  if (anyNA(u)) {
    stop(.rmbl_fn(), "`unit` must have no NA", call. = FALSE)
  }
  y <- .rmbl_num(data[[y]], "y")
  # one NA gave "missing value where TRUE/FALSE needed" in the demeaning, and
  # an all-NA outcome a power of 0 at every effect
  if (anyNA(y)) {
    stop(
      .rmbl_fn(),
      "`y` must have no NA: drop or impute the missing outcomes first",
      call. = FALSE
    )
  }
  if (anyDuplicated(data.frame(u, t))) {
    stop(
      .rmbl_fn(),
      "`data` has more than one row for a unit in a period",
      call. = FALSE
    )
  }
  list(
    u = as.integer(factor(u)),
    ul = levels(factor(u)),
    t = t,
    tl = sort(unique(t)),
    y = y
  )
}

#' Reads the first-treated period of each row, with never treated as Inf.
#' @param data The panel data frame.
#' @param first_treated The name of the first-treated column.
#' @param p The coded panel from `.rmbl_panel()`.
#' @return A numeric vector, Inf for units never treated.
#' @noRd
.rmbl_first_treated <- function(data, first_treated, p) {
  v <- .rmbl_colnames(first_treated, "ftreat")
  if (!v %in% names(data)) {
    stop(
      .rmbl_fn(),
      sprintf("`ftreat` (%s) is not a column of `data`", v),
      call. = FALSE
    )
  }
  g <- data[[v]]
  if (is.logical(g) && all(is.na(g))) {
    g <- as.numeric(g)
  }
  if (!is.numeric(g)) {
    stop(
      .rmbl_fn(),
      "`ftreat` must be numeric (NA, 0 or Inf for never treated)",
      call. = FALSE
    )
  }
  g[is.na(g) | g == 0] <- Inf
  per_unit <- tapply(g, p$u, function(z) length(unique(z)))
  if (any(per_unit > 1L)) {
    stop(
      .rmbl_fn(),
      "`ftreat` must be the same in every row of a unit",
      call. = FALSE
    )
  }
  g
}

#' Removes fixed effects from the columns of a matrix.
#'
#' Two-way (or k-way) within transformation by alternating projections: exact
#' for a balanced panel in one sweep, and convergent for an unbalanced one.
#' @param x A vector or matrix.
#' @param fes A list of fixed-effect vectors.
#' @param tol The convergence tolerance.
#' @param maxit The most sweeps.
#' @param w Observation weights, or NULL for equal weights.
#' @return The demeaned matrix.
#' @noRd
.rmbl_demean <- function(x, fes, tol = 1e-12, maxit = 10000L, w = NULL) {
  x <- as.matrix(x)
  if (!length(fes)) {
    return(x)
  }
  if (is.null(w)) {
    w <- rep(1, nrow(x))
  }
  lv <- lapply(fes, function(f) sort(unique(f)))
  idx <- lapply(seq_along(fes), function(k) match(fes[[k]], lv[[k]]))
  sw <- lapply(seq_along(fes), function(k) {
    as.vector(rowsum(w, idx[[k]], reorder = TRUE))
  })
  for (it in seq_len(maxit)) {
    old <- x
    for (k in seq_along(fes)) {
      m <- rowsum(x * w, idx[[k]], reorder = TRUE) / sw[[k]]
      x <- x - m[idx[[k]], , drop = FALSE]
    }
    if (length(fes) == 1L || max(abs(x - old)) < tol * (1 + max(abs(x)))) break
  }
  x
}

#' Fits weighted least squares on demeaned data with cluster-robust variance.
#'
#' OLS on demeaned data with one-way cluster-robust (CR1) variance. `k_fe` is
#' the number of fixed-effect parameters counted in the small-sample factor (N -
#' 1) / (N - K), as fixest counts them.
#' @param y The demeaned outcome.
#' @param x The demeaned regressor matrix, with column names.
#' @param cl A cluster vector, or a list of two for two-way clustering.
#' @param k_fe The number of fixed-effect parameters.
#' @param w Observation weights, or NULL for equal weights.
#' @return A list with `coef`, `vcov`, `resid`, `n` and the smallest
#'   number of `clusters`.
#' @noRd
.rmbl_ols_cr1 <- function(y, x, cl, k_fe, w = NULL) {
  if (is.null(w)) {
    w <- rep(1, length(y))
  }
  sw <- sqrt(w)
  q <- qr(x * sw)
  if (q$rank < ncol(x)) {
    drop <- colnames(x)[q$pivot[(q$rank + 1L):ncol(x)]]
    stop(
      .rmbl_fn(),
      sprintf(
        "collinear with the fixed effects or each other: %s",
        toString(drop)
      ),
      call. = FALSE
    )
  }
  b <- qr.coef(q, y * sw)
  e <- as.vector(y - x %*% b)
  bread <- chol2inv(qr.R(q))
  bread[q$pivot, q$pivot] <- bread
  n <- length(y)
  kk <- ncol(x) + k_fe
  vg <- .rmbl_cr1_vcov(x, w * e, bread, cl, (n - 1) / (n - kk))
  v <- vg$v
  g <- vg$g
  dimnames(v) <- list(colnames(x), colnames(x))
  list(
    coef = stats::setNames(as.vector(b), colnames(x)),
    vcov = v,
    resid = e,
    n = n,
    clusters = g
  )
}

#' Counts the fixed-effect parameters for the small-sample factor.
#' @param fes A list of fixed-effect vectors.
#' @param cl A cluster vector, or a list of them.
#' @return An integer.
#' @noRd
.rmbl_k_fe <- function(fes, cl) {
  # fixest's "nested" count: the fixed effects nested in the clusters drop out,
  # the others count their levels less one, and the absorbed constant counts one
  if (!is.list(cl)) {
    cl <- list(cl)
  }
  k <- 1L
  for (f in fes) {
    nested <- any(vapply(
      cl,
      function(cc) all(tapply(cc, f, function(z) length(unique(z))) == 1L),
      NA
    ))
    if (!nested) k <- k + length(unique(f)) - 1L
  }
  k
}

#' Reads the cluster column or columns, defaulting to the unit.
#' @param data The panel data frame.
#' @param cluster One or two column names, or NULL.
#' @param p The coded panel from `.rmbl_panel()`.
#' @return An integer cluster vector, or a list of two.
#' @noRd
.rmbl_cluster <- function(data, cluster, p) {
  if (is.null(cluster)) {
    return(p$u)
  }
  v <- .rmbl_colnames(cluster, "cl", several = TRUE)
  if (length(v) > 2L) {
    stop(
      .rmbl_fn(),
      "`cl` names one column, or two for two-way clustering",
      call. = FALSE
    )
  }
  out <- lapply(v, function(cc) {
    if (!cc %in% names(data)) {
      stop(
        .rmbl_fn(),
        sprintf("`cl` (%s) is not a column of `data`", cc),
        call. = FALSE
      )
    }
    if (anyNA(data[[cc]])) {
      stop(.rmbl_fn(), "`cl` must have no NA", call. = FALSE)
    }
    as.integer(factor(data[[cc]]))
  })
  if (length(out) == 1L) out[[1L]] else out
}

#' Reads the covariate columns as a numeric matrix.
#' @param data The panel data frame.
#' @param covariates Column names, or NULL.
#' @return A matrix with one column per covariate, or NULL.
#' @noRd
.rmbl_covariates <- function(data, covariates) {
  if (is.null(covariates)) {
    return(NULL)
  }
  covariates <- .rmbl_colnames(covariates, "covariates", several = TRUE)
  miss <- setdiff(covariates, names(data))
  if (length(miss)) {
    stop(
      .rmbl_fn(),
      sprintf("not columns of `data`: %s", toString(miss)),
      call. = FALSE
    )
  }
  m <- vapply(
    covariates,
    function(v) .rmbl_num(data[[v]], v),
    numeric(nrow(data))
  )
  matrix(m, nrow(data), dimnames = list(NULL, covariates))
}

#' Reads the weights column, defaulting to equal weights.
#' @param data The panel data frame.
#' @param weights A column name, or NULL.
#' @param arg The caller's name for that argument, used in the messages.
#' @return A numeric vector of weights.
#' @noRd
.rmbl_weights <- function(data, weights, arg = "w") {
  if (is.null(weights)) {
    return(rep(1, nrow(data)))
  }
  v <- .rmbl_colnames(weights, arg)
  if (!v %in% names(data)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` (%s) is not a column of `data`", arg, v),
      call. = FALSE
    )
  }
  w <- .rmbl_num(data[[v]], arg)
  if (anyNA(w) || any(w < 0) || !any(w > 0)) {
    stop(
      .rmbl_fn(),
      sprintf("`%s` must be 0 or more, with no NA", arg),
      call. = FALSE
    )
  }
  w
}

#' Tabulates coefficients with t intervals on clusters less one degrees of
#' freedom.
#' @param fit A fit from `.rmbl_ols_cr1()`.
#' @param terms The coefficient names to report.
#' @param conf_level The confidence level of the t intervals (clusters - 1 df).
#' @return A data frame with `term`, `estimate`, `se`, `lower`,
#'   `upper`, `t` and `p_value`.
#' @noRd
.rmbl_coef_table <- function(fit, terms, conf_level) {
  se <- sqrt(diag(fit$vcov))[terms]
  est <- fit$coef[terms]
  df <- fit$clusters - 1L
  tq <- stats::qt(1 - (1 - conf_level) / 2, df)
  tv <- est / se
  data.frame(
    term = terms,
    estimate = unname(est),
    se = unname(se),
    lower = unname(est - tq * se),
    upper = unname(est + tq * se),
    t = unname(tv),
    p_value = unname(2 * stats::pt(-abs(tv), df)),
    stringsAsFactors = FALSE
  )
}

#' Computes the Callaway-Sant'Anna group-time average treatment effects.
#' @param y A unit-by-period outcome matrix.
#' @param gg The first-treated period of each unit.
#' @param tl The sorted periods.
#' @param control The comparison group, `"never"` or `"notyet"`.
#' @param x A list of unit-by-period covariate matrices, or NULL.
#' @param est_method The covariate method passed to `.rmbl_drdid()`.
#' @return A data frame with `cohort`, `period`, `evtm`, `estimate` and
#'   `ncoh`.
#' @noRd
.rmbl_cs <- function(y, gg, tl, control, x = NULL, est_method = "dr") {
  cohorts <- sort(unique(gg[is.finite(gg)]))
  rows <- list()
  for (cg in cohorts) {
    ig <- gg == cg
    for (j in seq_along(tl)[-1L]) {
      t <- tl[j]
      b <- if (t >= cg) max(which(tl < cg)) else j - 1L
      cut <- max(t, tl[b])
      ic <- if (control == "never") gg == Inf else (gg > cut & gg != cg)
      ic <- ic & gg != -Inf
      if (!any(ic) || !any(ig)) {
        next
      }
      att <- if (is.null(x)) {
        (mean(y[ig, j]) - mean(y[ig, b])) - (mean(y[ic, j]) - mean(y[ic, b]))
      } else {
        k <- which(ig | ic)
        xb <- cbind(1, vapply(x, function(m) m[k, b], numeric(length(k))))
        .rmbl_drdid(y[k, j] - y[k, b], as.numeric(ig[k]), xb, est_method)
      }
      rows[[length(rows) + 1L]] <- c(cg, t, att, sum(ig))
    }
  }
  if (!length(rows)) {
    stop(
      .rmbl_fn(),
      "no cohort has a comparison group in any period",
      call. = FALSE
    )
  }
  m <- do.call(rbind, rows)
  data.frame(
    cohort = m[, 1L],
    period = m[, 2L],
    evtm = match(m[, 2L], tl) - match(m[, 1L], tl),
    estimate = m[, 3L],
    ncoh = m[, 4L]
  )
}

#' The two-period panel DiD with covariates of Sant'Anna and Zhao (2020):
#' outcome regression on the comparison units (\code{"reg"}), normalised inverse
#' probability weighting (\code{"ipw"}), or both, doubly robust (\code{"dr"});
#' comparison units with a propensity above 0.995 are trimmed, as DRDID does.
#' @param dy The outcome change of each unit.
#' @param d The treatment indicator, 1 or 0.
#' @param x The covariate matrix, with an intercept column.
#' @param est_method `"reg"`, `"ipw"` or `"dr"`.
#' @return The average treatment effect on the treated.
#' @noRd
.rmbl_drdid <- function(dy, d, x, est_method) {
  m <- 0
  if (est_method != "ipw") {
    m <- as.vector(x %*% qr.coef(qr(x[d == 0, , drop = FALSE]), dy[d == 0]))
  }
  if (anyNA(m)) {
    stop(
      .rmbl_fn(),
      "the covariates are collinear among the comparison units",
      call. = FALSE
    )
  }
  if (est_method == "reg") {
    return(mean((dy - m)[d == 1]))
  }
  ps <- suppressWarnings(stats::glm.fit(
    x,
    d,
    family = stats::binomial()
  ))$fitted.values
  wc <- ps * (1 - d) / (1 - ps)
  wc[d == 0 & ps >= 0.995] <- 0
  sum(d * (dy - m)) / sum(d) - sum(wc * (dy - m)) / sum(wc)
}

#' Computes cohort-period effects by the extended two-way fixed-effects
#' regression.
#' @param y A unit-by-period outcome matrix.
#' @param gg The first-treated period of each unit.
#' @param tl The sorted periods.
#' @param control The comparison group, `"never"` or `"notyet"`.
#' @return A data frame with `cohort`, `period`, `evtm`, `estimate` and
#'   `ncoh`.
#' @noRd
.rmbl_etwfe <- function(y, gg, tl, control) {
  nu <- nrow(y)
  nt <- ncol(y)
  keep <- gg != -Inf
  if (control == "notyet" && !any(gg == Inf)) {
    # no never-treated unit: the last cohort serves as the comparison, up to its
    # adoption
    ref_g <- max(gg[is.finite(gg)])
  } else {
    ref_g <- Inf
  }
  u <- rep(seq_len(nu), each = nt)
  t <- rep(seq_len(nt), nu)
  yy <- as.vector(t(y))
  gr <- rep(gg, each = nt)
  ok <- rep(keep, each = nt)
  if (is.finite(ref_g)) {
    ok <- ok & !(gr == ref_g & tl[t] >= ref_g)
  }
  cells <- .rmbl_etwfe_cells(gr, tl[t], ok, ref_g)
  x <- vapply(
    seq_len(nrow(cells)),
    function(i) as.numeric(gr == cells$g[i] & tl[t] == cells$t[i]),
    numeric(length(yy))
  )
  x <- matrix(x, length(yy))[ok, , drop = FALSE]
  colnames(x) <- paste0("g", cells$g, "_t", cells$t)
  fes <- list(u[ok], t[ok])
  xd <- .rmbl_demean(x, fes)
  yd <- as.vector(.rmbl_demean(yy[ok], fes))
  b <- qr.coef(qr(xd), yd)
  if (anyNA(b)) {
    stop(
      .rmbl_fn(),
      "a cohort-period cell is collinear with the fixed effects",
      call. = FALSE
    )
  }
  data.frame(
    cohort = cells$g,
    period = cells$t,
    evtm = match(cells$t, tl) - match(cells$g, tl),
    estimate = unname(b),
    ncoh = vapply(cells$g, function(cg) sum(gg == cg), numeric(1L))
  )
}

#' Lists the distinct permutations of a vector with repeated values.
#' @param v The vector.
#' @return A matrix with one permutation per row.
#' @noRd
.rmbl_multiset_perms <- function(v) {
  if (length(v) <= 1L) {
    return(matrix(v, 1L))
  }
  u <- unique(v)
  do.call(
    rbind,
    lapply(u, function(a) {
      rest <- v[-match(a, v)]
      cbind(a, .rmbl_multiset_perms(rest))
    })
  )
}

#' The negative binomial (NB2) family at a fixed theta, for glm.fit: base R, no
#' MASS
#' @param theta The dispersion parameter.
#' @return A family object.
#' @noRd
.rmbl_negbin_family <- function(theta) {
  f <- stats::poisson()
  f$family <- sprintf("Negative Binomial(%.4g)", theta)
  f$variance <- function(mu) mu + mu^2 / theta
  f$dev.resids <- function(y, mu, wt) {
    2 *
      wt *
      (y * log(pmax(1, y) / mu) - (y + theta) * log((y + theta) / (mu + theta)))
  }
  f$aic <- function(y, n, mu, wt, dev) {
    -2 *
      sum(
        wt *
          (lgamma(y + theta) -
            lgamma(theta) -
            lgamma(y + 1) +
            theta * log(theta / (theta + mu)) +
            y * log(mu / (theta + mu)))
      )
  }
  f
}

#' Solves least squares with the weights on the simplex.
#'
#' Min ||A w - b||^2 over the simplex. An active set on the KKT system first:
#' the exact least squares on a support with the sum constraint (one small
#' solve), a weight that comes out negative leaves the support, a zero weight
#' whose reduced gradient says it would lower the objective joins it. FISTA with
#' the exact Euclidean projection (Duchi et al. 2008) is the fallback: with a
#' tiny ridge (the time weights of syndid(), zeta = 1e-6 sigma) its projected
#' gradient steps ran to the limit, a second a placebo and 55 s of CPU a
#' vignette (final audit of 1.0.0)
#' @param A The design matrix.
#' @param b The target vector.
#' @param maxit The most FISTA iterations.
#' @param tol The FISTA convergence tolerance.
#' @return The weight vector, non-negative and summing to one.
#' @noRd
.rmbl_simplex_ls <- function(A, b, maxit = 20000L, tol = 1e-12) {
  k <- ncol(A)
  ata <- crossprod(A)
  atb <- crossprod(A, b)
  if (k == 1L) {
    return(1)
  }
  w <- .rmbl_simplex_active(ata, atb, k)
  if (!is.null(w)) {
    return(w)
  }
  w <- .rmbl_simplex_fista(ata, atb, k, maxit, tol)
  .rmbl_simplex_polish(w, ata, atb)
}

#' plndid()'s treatment indicator, checked: 0 or 1, varying, no NA.
#' @param data The panel.
#' @param trtd The treatment column.
#' @return The indicator, numeric.
#' @noRd
.rmbl_did_trtd <- function(data, trtd) {
  v <- .rmbl_colnames(trtd, "trtd")
  if (!v %in% names(data)) {
    stop(
      sprintf("plndid: `trtd` (%s) is not a column of `data`", v),
      call. = FALSE
    )
  }
  d <- data[[v]]
  if (is.logical(d)) {
    d <- as.numeric(d)
  }
  if (!is.numeric(d) || anyNA(d) || !all(d %in% c(0, 1))) {
    stop(
      .rmbl_fn(),
      "`trtd` must be 0 or 1 (or FALSE or TRUE), with no NA",
      call. = FALSE
    )
  }
  if (length(unique(d)) < 2L) {
    stop(
      .rmbl_fn(),
      "`trtd` never varies: there is no comparison",
      call. = FALSE
    )
  }
  d
}

#' The control mean before treatment, the base of the relative effect.
#' @param d The treatment indicator.
#' @param p The panel (.rmbl_panel()).
#' @param .w The regression weights, averaging the control units' outcomes.
#' @return One number, NA when there is no pre-treatment control row.
#' @noRd
.rmbl_did_ctlmean <- function(d, p, .w) {
  ever <- tapply(d, p$u, max)[p$u] > 0
  first <- min(p$t[d == 1])
  pre <- !ever & p$t < first
  if (!any(pre)) {
    pre <- d == 0 & p$t < first
  }
  if (any(pre)) sum(.w[pre] * p$y[pre]) / sum(.w[pre]) else NA_real_
}

#' A linear combination of plndid()'s coefficients, with its interval.
#' @param comb The weights, named by term.
#' @param terms The terms of the fit.
#' @param fit The fit (.rmbl_ols_cr1()).
#' @param conflvl The confidence level of the combination's t interval.
#' @param cm The control mean.
#' @return A one-row data frame.
#' @noRd
.rmbl_did_comb <- function(comb, terms, fit, conflvl, cm) {
  if (
    !is.numeric(comb) ||
      is.null(names(comb)) ||
      !all(names(comb) %in% terms)
  ) {
    stop(
      .rmbl_fn(),
      "`comb` must be numbers named by the terms (\"treated\" and ",
      "covariates)",
      call. = FALSE
    )
  }
  a <- stats::setNames(numeric(length(terms)), terms)
  a[names(comb)] <- comb
  est <- sum(a * fit$coef)
  se <- sqrt(as.numeric(t(a) %*% fit$vcov %*% a))
  tq <- stats::qt(1 - (1 - conflvl) / 2, fit$clusters - 1L)
  data.frame(
    estimate = est,
    se = se,
    lower = est - tq * se,
    upper = est + tq * se,
    percent = 100 * est / cm,
    perse = 100 * se / abs(cm)
  )
}

#' Event time for evstudy(): binned at the window's ends, or the rows outside
#' it dropped.
#' @param k Event time, one per row (Inf for a unit never treated).
#' @param leads,lags The window.
#' @param bin Whether the ends are binned.
#' @return list(k, keep).
#' @noRd
.rmbl_es_k <- function(k, leads, lags, bin) {
  keep <- rep(TRUE, length(k))
  if (bin) {
    k[is.finite(k) & k < -leads] <- -leads
    k[is.finite(k) & k > lags] <- lags
  } else {
    keep <- !is.finite(k) | (k >= -leads & k <= lags)
  }
  list(k = k, keep = keep)
}

#' The event-time indicators of evstudy().
#' @param k Event time, one per row.
#' @param ks The event times estimated (the reference left out).
#' @return A matrix, one column per event time.
#' @noRd
.rmbl_es_design <- function(k, ks) {
  x <- vapply(
    ks,
    function(j) as.numeric(is.finite(k) & k == j),
    numeric(length(k))
  )
  x <- matrix(x, length(k), dimnames = list(NULL, paste0("k", ks)))
  x
}

#' Refuses an event time with no observation.
#' @param x The design.
#' @param ks The event times estimated.
#' @return NULL, invisibly.
#' @noRd
.rmbl_es_present <- function(x, ks) {
  present <- colSums(abs(x)) > 0
  if (!all(present[seq_along(ks)])) {
    stop(
      .rmbl_fn(),
      sprintf(
        "no observation at event time %s: narrow `leads` or `lags`",
        toString(ks[!present[seq_along(ks)]])
      ),
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' evstudy()'s coefficients by event time, the reference at zero.
#' @param fit The fit.
#' @param ks The event times estimated.
#' @param ref The reference event time.
#' @param conflvl The confidence level of each event time's interval.
#' @return A data frame ordered by event time.
#' @noRd
.rmbl_es_table <- function(fit, ks, ref, conflvl) {
  tab <- .rmbl_coef_table(fit, paste0("k", ks), conflvl)
  tab$evtm <- ks
  .ref <- data.frame(
    term = paste0("k", ref),
    estimate = 0,
    se = 0,
    lower = 0,
    upper = 0,
    t = NA_real_,
    p_value = NA_real_,
    evtm = ref,
    stringsAsFactors = FALSE
  )
  out <- rbind(tab, .ref)
  out <- out[
    order(out$evtm),
    c("evtm", "estimate", "se", "lower", "upper", "t", "p_value")
  ]
  rownames(out) <- NULL
  out
}

#' The joint test that every lead is zero.
#' @param fit The fit.
#' @param ks The event times estimated.
#' @return list(F, df1, df2, p_value).
#' @noRd
.rmbl_es_pretrend <- function(fit, ks) {
  # with no lead at all paste0() gave "k", not nothing, and the test read past
  # the coefficients (evstudy(leads = 1) with the reference at -1; coverage pass
  # of 1.0.0)
  pre <- if (any(ks < 0)) paste0("k", ks[ks < 0]) else character()
  if (length(pre)) {
    gm <- fit$coef[pre]
    w <- as.numeric(t(gm) %*% solve(fit$vcov[pre, pre, drop = FALSE], gm))
    q <- length(pre)
    pt <- list(
      F = w / q,
      df1 = q,
      df2 = fit$clusters - 1L,
      p_value = stats::pf(w / q, q, fit$clusters - 1L, lower.tail = FALSE)
    )
  } else {
    pt <- list(
      F = NA_real_,
      df1 = 0L,
      df2 = fit$clusters - 1L,
      p_value = NA_real_
    )
  }
  pt
}

#' Shades the post-adoption periods of an event-study plot.
#' @param refline Where the shading starts.
#' @return NULL, invisibly.
#' @noRd
.rmbl_es_shade <- function(refline) {
  u <- graphics::par("usr")
  graphics::rect(
    refline,
    u[3L],
    u[2L],
    u[4L],
    col = grDevices::adjustcolor("#9A9A9A", 0.15),
    border = NA
  )
  invisible(NULL)
}

#' Draws an event study in the Stata style: dashed intervals, a joined line.
#' @param d The coefficients.
#' @param w Which intervals are drawn.
#' @param refline Where the reference line goes.
#' @param gaps "break" or "join".
#' @param cl The colour.
#' @return NULL, invisibly.
#' @noRd
.rmbl_es_draw_stata <- function(d, w, refline, gaps, cl) {
  graphics::abline(h = 0, lty = 2, col = "#9A9A9A")
  graphics::abline(v = refline, lty = 2, col = "#9A9A9A")
  graphics::arrows(
    d$evtm[w],
    d$lower[w],
    d$evtm[w],
    d$upper[w],
    angle = 90,
    code = 3,
    length = 0.03,
    col = "#7A7A7A",
    lty = 2
  )
  on <- gaps == "break" | is.finite(d$estimate)
  graphics::lines(d$evtm[on], d$estimate[on], col = cl)
  graphics::points(d$evtm, d$estimate, pch = 1, col = cl)
  invisible(NULL)
}

#' Draws an event study as dots with their intervals.
#' @param d The coefficients.
#' @param w Which intervals are drawn.
#' @param refline Where the reference line goes.
#' @param cl The colour.
#' @return NULL, invisibly.
#' @noRd
.rmbl_es_draw_dot <- function(d, w, refline, cl) {
  graphics::abline(h = 0, col = "#9A9A9A")
  graphics::abline(v = refline, lty = 2, col = "#9A9A9A")
  graphics::arrows(
    d$evtm[w],
    d$lower[w],
    d$evtm[w],
    d$upper[w],
    angle = 90,
    code = 3,
    length = 0.03,
    col = cl
  )
  graphics::points(d$evtm, d$estimate, pch = 19, col = cl)
  invisible(NULL)
}

#' The balanced panel of stgatt() as unit-by-period matrices.
#' @param data The panel.
#' @param cl The cluster column, or NULL.
#' @param covs The covariate columns, or NULL.
#' @param p The panel (.rmbl_panel()).
#' @param g Each row's first treated period.
#' @param ctrl The control group.
#' @return list(ym, gu, clu, xm, nu): outcomes, cohorts, clusters, covariates
#'   and the number of units.
#' @noRd
.rmbl_sg_wide <- function(data, cl, covs, p, g, ctrl) {
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) {
    stop(
      .rmbl_fn(),
      "`data` must be a balanced panel: every unit in every period",
      call. = FALSE
    )
  }
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  gu <- g[o][seq(1L, by = nt, length.out = nu)]
  # treated from the first period: never comparable
  gu[is.finite(gu) & gu <= p$tl[1L]] <- -Inf
  if (!any(is.finite(gu))) {
    stop(.rmbl_fn(), "no unit is first treated within the panel", call. = FALSE)
  }
  if (ctrl == "never" && !any(gu == Inf)) {
    stop(
      .rmbl_fn(),
      "no never-treated unit: use control = \"notyet\"",
      call. = FALSE
    )
  }
  clu <- if (is.null(cl)) {
    seq_len(nu)
  } else {
    .rmbl_cluster(data, cl, p)[o][seq(1L, by = nt, length.out = nu)]
  }
  xm <- NULL
  if (!is.null(covs)) {
    cv <- .rmbl_covariates(data, covs)
    xm <- lapply(colnames(cv), function(v) {
      matrix(cv[o, v], nu, nt, byrow = TRUE)
    })
    names(xm) <- colnames(cv)
  }
  list(ym = ym, gu = gu, clu = clu, xm = xm, nu = nu)
}

#' The group-time effects of stgatt() on a set of units.
#' @param idx The units (rows of the matrices), with repeats.
#' @param wd The matrices (.rmbl_sg_wide()).
#' @param spec The method, control group, estimator and periods.
#' @return The group-time effects.
#' @noRd
.rmbl_sg_est <- function(idx, wd, spec) {
  .y <- wd$ym[idx, , drop = FALSE]
  gg <- wd$gu[idx]
  if (spec$meth == "wooldridge") {
    return(.rmbl_etwfe(.y, gg, spec$tl, spec$ctrl))
  }
  .rmbl_cs(
    .y,
    gg,
    spec$tl,
    spec$ctrl,
    if (is.null(wd$xm)) {
      NULL
    } else {
      lapply(wd$xm, function(m) m[idx, , drop = FALSE])
    },
    spec$estmeth
  )
}

#' The overall and dynamic aggregates of group-time effects, by cohort size.
#' @param a The group-time effects.
#' @return list(overall, dynamic).
#' @noRd
.rmbl_sg_agg <- function(a) {
  post <- a[a$evtm >= 0 & is.finite(a$estimate), ]
  w <- post$ncoh
  ov <- if (nrow(post)) sum(w * post$estimate) / sum(w) else NA_real_
  es <- sort(unique(a$evtm))
  dyn <- vapply(
    es,
    function(e) {
      r <- a[a$evtm == e & is.finite(a$estimate), ]
      if (nrow(r)) sum(r$ncoh * r$estimate) / sum(r$ncoh) else NA_real_
    },
    numeric(1L)
  )
  list(overall = ov, dynamic = data.frame(evtm = es, estimate = dyn))
}

#' The cluster-bootstrap standard errors of stgatt().
#' @param wd The matrices (.rmbl_sg_wide()).
#' @param spec The method, control group, estimator and periods.
#' @param a0,g0 The estimates and their aggregates.
#' @param reps The bootstrap draws (0: none).
#' @param seed The seed, or NULL.
#' @return list(gt, ov, dyn), NA when there are no draws.
#' @noRd
.rmbl_sg_boot <- function(wd, spec, a0, g0, reps, seed) {
  se_gt <- rep(NA_real_, nrow(a0))
  se_ov <- NA_real_
  se_dyn <- rep(NA_real_, nrow(g0$dynamic))
  if (reps > 0L) {
    ucl <- unique(wd$clu)
    draws <- .rmbl_with_seed(
      seed,
      lapply(seq_len(reps), function(r) {
        pick <- sample(ucl, length(ucl), replace = TRUE)
        idx <- unlist(
          lapply(pick, function(cc) which(wd$clu == cc)),
          use.names = FALSE
        )
        ab <- tryCatch(.rmbl_sg_est(idx, wd, spec), error = function(e) NULL)
        if (is.null(ab)) {
          return(NULL)
        }
        key <- paste(ab$cohort, ab$period)
        gb <- .rmbl_sg_agg(ab)
        list(
          gt = ab$estimate[match(paste(a0$cohort, a0$period), key)],
          ov = gb$overall,
          dyn = gb$dynamic$estimate[match(g0$dynamic$evtm, gb$dynamic$evtm)]
        )
      })
    )
    draws <- Filter(Negate(is.null), draws)
    sdn <- function(m) apply(m, 2L, stats::sd, na.rm = TRUE)
    se_gt <- sdn(do.call(rbind, lapply(draws, `[[`, "gt")))
    se_ov <- stats::sd(vapply(draws, `[[`, numeric(1L), "ov"), na.rm = TRUE)
    se_dyn <- sdn(do.call(rbind, lapply(draws, `[[`, "dyn")))
  }
  list(gt = se_gt, ov = se_ov, dyn = se_dyn)
}

#' The result of stgatt() from its estimates and standard errors.
#' @param a0,g0 The estimates and their aggregates.
#' @param se The standard errors (.rmbl_sg_boot()).
#' @param z The normal quantile of `conflvl`, for the group-time limits.
#' @param how The method and the control group, named.
#' @param conflvl The confidence level the z multiplier was taken from.
#' @return A list: attgt, overall, dynamic, method, control, conflvl.
#' @noRd
.rmbl_sg_out <- function(a0, g0, se, z, how, conflvl) {
  se_gt <- se$gt
  se_ov <- se$ov
  se_dyn <- se$dyn
  a0$se <- se_gt
  a0$lower <- a0$estimate - z * se_gt
  a0$upper <- a0$estimate + z * se_gt
  dyn <- g0$dynamic
  dyn$se <- se_dyn
  dyn$lower <- dyn$estimate - z * se_dyn
  dyn$upper <- dyn$estimate + z * se_dyn
  out <- list(
    attgt = a0[c(
      "cohort",
      "period",
      "evtm",
      "estimate",
      "se",
      "lower",
      "upper",
      "ncoh"
    )],
    overall = data.frame(
      estimate = g0$overall,
      se = se_ov,
      lower = g0$overall - z * se_ov,
      upper = g0$overall + z * se_ov
    ),
    dynamic = dyn,
    method = how[["method"]],
    control = how[["control"]],
    conflvl = conflvl
  )
  out
}

#' The balanced panel of bacondcmp() as matrices, with each unit's first
#' treated period.
#' @param data The panel.
#' @param trtd The treatment column.
#' @param p The panel (.rmbl_panel()).
#' @return list(ym, first, nt, groups, timing).
#' @noRd
.rmbl_bacon_wide <- function(data, trtd, p) {
  v <- .rmbl_colnames(trtd, "trtd")
  if (!v %in% names(data)) {
    stop(
      sprintf("bacondcmp: `trtd` (%s) is not a column of `data`", v),
      call. = FALSE
    )
  }
  d <- as.numeric(data[[v]])
  if (anyNA(d) || !all(d %in% c(0, 1))) {
    stop("bacondcmp: `trtd` must be 0 or 1, with no NA", call. = FALSE)
  }
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) {
    stop("bacondcmp: `data` must be a balanced panel", call. = FALSE)
  }
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  dm <- matrix(d[o], nu, nt, byrow = TRUE)
  if (any(t(apply(dm, 1L, diff)) < 0)) {
    stop(.rmbl_fn(), "treatment must stay on once it starts", call. = FALSE)
  }
  first <- apply(dm, 1L, function(r) {
    if (any(r == 1)) which(r == 1)[1L] else Inf
  })
  groups <- sort(unique(first))
  timing <- groups[is.finite(groups)]
  if (!length(timing)) {
    stop("bacondcmp: no unit is ever treated", call. = FALSE)
  }
  list(ym = ym, first = first, nt = nt, groups = groups, timing = timing)
}

#' One comparison of the Goodman-Bacon decomposition.
#' @param type The kind of comparison.
#' @param tr,co The treated and control timing groups.
#' @param est The two-by-two estimate.
#' @param w Its weight, not yet normalised.
#' @return A one-row data frame.
#' @noRd
.rmbl_bacon_row <- function(type, tr, co, est, w) {
  data.frame(
    type = type,
    treated = tr,
    control = co,
    estimate = est,
    weight = w
  )
}

#' The share of periods a timing group is treated.
#' @param k The group's first treated period (Inf: never).
#' @param nt The number of periods.
#' @return One number.
#' @noRd
.rmbl_bacon_dbar <- function(k, nt) {
  if (is.finite(k)) mean(seq_len(nt) >= k) else 0
}

#' The two-by-two difference in differences of two timing groups.
#' @param bw The panel (.rmbl_bacon_wide()).
#' @param tr,co The treated and control groups.
#' @param win The pre and post periods.
#' @return One number.
#' @noRd
.rmbl_bacon_dd <- function(bw, tr, co, win) {
  pre <- win[[1L]]
  post <- win[[2L]]
  yt <- bw$ym[bw$first == tr, , drop = FALSE]
  yc <- bw$ym[bw$first == co, , drop = FALSE]
  (mean(yt[, post]) - mean(yt[, pre])) - (mean(yc[, post]) - mean(yc[, pre]))
}

#' The comparisons of each timing group with the never treated.
#' @param bw The panel (.rmbl_bacon_wide()).
#' @param tl The period labels, naming each comparison's treatment time.
#' @return A list of rows.
#' @noRd
.rmbl_bacon_never <- function(bw, tl) {
  rows <- list()
  if (!(Inf %in% bw$groups)) {
    return(rows)
  }
  nt <- bw$nt
  nU <- mean(bw$first == Inf)
  for (k in bw$timing) {
    dk <- .rmbl_bacon_dbar(k, nt)
    if (dk <= 0 || dk >= 1) {
      next
    }
    nk <- mean(bw$first == k)
    nkU <- nk / (nk + nU)
    w <- (nk + nU)^2 * nkU * (1 - nkU) * dk * (1 - dk)
    rows[[length(rows) + 1L]] <- .rmbl_bacon_row(
      "treated vs never",
      tl[k],
      Inf,
      .rmbl_bacon_dd(bw, k, Inf, list(seq_len(k - 1L), k:nt)),
      w
    )
  }
  rows
}

#' The comparisons of the timing groups with each other.
#' @param bw The panel (.rmbl_bacon_wide()).
#' @param tl The period labels, passed to each pair of timing groups.
#' @return A list of rows.
#' @noRd
.rmbl_bacon_timing <- function(bw, tl) {
  rows <- list()
  for (k in bw$timing) {
    for (l in bw$timing[bw$timing > k]) {
      rows <- c(rows, .rmbl_bacon_pair(bw, tl, k, l))
    }
  }
  rows
}

#' The earlier-vs-later and later-vs-earlier comparisons of two groups.
#' @param bw The panel (.rmbl_bacon_wide()).
#' @param tl The period labels of the two groups' treatment times.
#' @param k,l The earlier and the later group.
#' @return A list of one or two rows.
#' @noRd
.rmbl_bacon_pair <- function(bw, tl, k, l) {
  nt <- bw$nt
  dk <- .rmbl_bacon_dbar(k, nt)
  dl <- .rmbl_bacon_dbar(l, nt)
  nk <- mean(bw$first == k)
  nl <- mean(bw$first == l)
  nkl <- nk / (nk + nl)
  rows <- list()
  if (k > 1L) {
    w1 <- ((nk + nl) * (1 - dl))^2 *
      nkl *
      (1 - nkl) *
      ((dk - dl) / (1 - dl)) *
      ((1 - dk) / (1 - dl))
    rows[[1L]] <- .rmbl_bacon_row(
      "earlier vs later",
      tl[k],
      tl[l],
      .rmbl_bacon_dd(bw, k, l, list(seq_len(k - 1L), k:(l - 1L))),
      w1
    )
  }
  w2 <- ((nk + nl) * dk)^2 * nkl * (1 - nkl) * (dl / dk) * ((dk - dl) / dk)
  rows[[length(rows) + 1L]] <- .rmbl_bacon_row(
    "later vs earlier",
    tl[l],
    tl[k],
    .rmbl_bacon_dd(bw, l, k, list(k:(l - 1L), l:nt)),
    w2
  )
  rows
}

#' The balanced panel of swtdid() as matrices.
#' @param data The panel.
#' @param trtd The treatment column.
#' @param cl The cluster column, or NULL.
#' @param p The panel (.rmbl_panel()).
#' @return list(ym, dm, clu, nu, nt).
#' @noRd
.rmbl_sw_wide <- function(data, trtd, cl, p) {
  v <- .rmbl_colnames(trtd, "trtd")
  if (!v %in% names(data)) {
    stop(
      sprintf("swtdid: `trtd` (%s) is not a column of `data`", v),
      call. = FALSE
    )
  }
  d <- as.numeric(data[[v]])
  if (anyNA(d) || !all(d %in% c(0, 1))) {
    stop("swtdid: `trtd` must be 0 or 1, with no NA", call. = FALSE)
  }
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) {
    stop("swtdid: `data` must be a balanced panel", call. = FALSE)
  }
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  dm <- matrix(d[o], nu, nt, byrow = TRUE)
  clu <- if (is.null(cl)) {
    seq_len(nu)
  } else {
    .rmbl_cluster(data, cl, p)[o][seq(1L, by = nt, length.out = nu)]
  }
  list(ym = ym, dm = dm, clu = clu, nu = nu, nt = nt)
}

#' The switching estimate and its placebo on a set of units.
#' @param idx The units (rows of the matrices), with repeats.
#' @param sw The matrices (.rmbl_sw_wide()).
#' @return c(effect, placebo, switchers, placebo switchers).
#' @noRd
.rmbl_sw_est <- function(idx, sw) {
  .y <- sw$ym[idx, , drop = FALSE]
  dd <- sw$dm[idx, , drop = FALSE]
  num <- 0
  ns <- 0
  pnum <- 0
  pns <- 0
  for (j in 2:sw$nt) {
    s <- .rmbl_sw_step(.y, dd, j)
    # added one comparison at a time, as they were summed before
    num <- num + s[[1L]]
    num <- num + s[[2L]]
    ns <- ns + s[[3L]]
    ns <- ns + s[[4L]]
    pnum <- pnum + s[[5L]]
    pnum <- pnum + s[[6L]]
    pns <- pns + s[[7L]]
    pns <- pns + s[[8L]]
  }
  c(
    if (ns > 0) num / ns else NA_real_,
    if (pns > 0) pnum / pns else NA_real_,
    ns,
    pns
  )
}

#' One period's switching comparisons, joiners and leavers, and their placebo.
#' @param .y The outcomes, unit by period.
#' @param dd The treatment, unit by period.
#' @param j The period.
#' @return c(the two weighted differences, their switchers, the two placebo
#'   differences, their switchers), 0 where a comparison is not possible.
#' @noRd
.rmbl_sw_step <- function(.y, dd, j) {
  s <- numeric(8L)
  dy <- .y[, j] - .y[, j - 1L]
  jn <- dd[, j - 1L] == 0 & dd[, j] == 1
  s0 <- dd[, j - 1L] == 0 & dd[, j] == 0
  lv <- dd[, j - 1L] == 1 & dd[, j] == 0
  s1 <- dd[, j - 1L] == 1 & dd[, j] == 1
  if (any(jn) && any(s0)) {
    s[c(1L, 3L)] <- c(sum(jn) * (mean(dy[jn]) - mean(dy[s0])), sum(jn))
  }
  if (any(lv) && any(s1)) {
    s[c(2L, 4L)] <- c(sum(lv) * (mean(dy[s1]) - mean(dy[lv])), sum(lv))
  }
  if (j >= 3L) {
    dp <- .y[, j - 1L] - .y[, j - 2L]
    pj <- jn & dd[, j - 2L] == 0
    ps <- s0 & dd[, j - 2L] == 0
    pl <- lv & dd[, j - 2L] == 1
    p1 <- s1 & dd[, j - 2L] == 1
    if (any(pj) && any(ps)) {
      s[c(5L, 7L)] <- c(sum(pj) * (mean(dp[pj]) - mean(dp[ps])), sum(pj))
    }
    if (any(pl) && any(p1)) {
      s[c(6L, 8L)] <- c(sum(pl) * (mean(dp[p1]) - mean(dp[pl])), sum(pl))
    }
  }
  s
}

#' The cluster-bootstrap standard errors of swtdid().
#' @param sw The matrices (.rmbl_sw_wide()).
#' @param reps The bootstrap draws (0: none).
#' @param seed The seed, or NULL.
#' @return The two standard errors, NA when there are no draws.
#' @noRd
.rmbl_sw_boot <- function(sw, reps, seed) {
  se <- c(NA_real_, NA_real_)
  if (reps > 0L) {
    ucl <- unique(sw$clu)
    b <- .rmbl_with_seed(
      seed,
      vapply(
        seq_len(reps),
        function(r) {
          pick <- sample(ucl, length(ucl), replace = TRUE)
          .rmbl_sw_est(
            unlist(
              lapply(pick, function(cc) which(sw$clu == cc)),
              use.names = FALSE
            ),
            sw
          )[1:2]
        },
        numeric(2L)
      )
    )
    se <- apply(b, 1L, stats::sd, na.rm = TRUE)
  }
  se
}

#' perminf()'s statistic for one assignment of adoption times.
#' @param gvec The first treated period of each cluster.
#' @param oc The outcome.
#' @param ctx The data, unit, time and cluster columns, the cluster of each row
#'   and the statistic.
#' @return One number, NA when the assignment cannot be estimated.
#' @noRd
.rmbl_perm_stat <- function(gvec, oc, ctx) {
  dd <- ctx$data
  dd$.rmbl_d <- as.numeric(dd[[ctx$time]] >= gvec[ctx$.cl])
  if (length(unique(dd$.rmbl_d)) < 2L) {
    return(NA_real_)
  }
  r <- tryCatch(
    plndid(dd, ctx$unit, ctx$time, oc, ".rmbl_d", cl = ctx$cl),
    error = function(e) NULL
  )
  if (is.null(r)) {
    NA_real_
  } else if (ctx$stat == "t") {
    r$t[1L]
  } else {
    r$estimate[1L]
  }
}

#' perminf()'s estimate at the observed adoption times.
#' @param oc The outcome.
#' @param ctx As for .rmbl_perm_stat().
#' @param g Each row's first treated period.
#' @return One number.
#' @noRd
.rmbl_perm_est <- function(oc, ctx, g) {
  dd <- ctx$data
  dd$.rmbl_d <- as.numeric(dd[[ctx$time]] >= g)
  plndid(dd, ctx$unit, ctx$time, oc, ".rmbl_d", cl = ctx$cl)$estimate[1L]
}

#' The assignments perminf() compares with: every one when they are few, else
#' a random sample.
#' @param gc The first treated period of each cluster.
#' @param reps The most assignments.
#' @param seed The seed, or NULL.
#' @return list(perms, exact).
#' @noRd
.rmbl_perm_draws <- function(gc, reps, seed) {
  tab <- table(gc)
  n_assign <- exp(lfactorial(length(gc)) - sum(lfactorial(tab)))
  exact <- n_assign <= reps
  perms <- if (exact) {
    .rmbl_multiset_perms(as.vector(gc))
  } else {
    .rmbl_with_seed(
      seed,
      t(vapply(
        seq_len(reps),
        function(r) sample(as.vector(gc)),
        numeric(length(gc))
      ))
    )
  }
  list(perms = perms, exact = exact)
}

#' perminf()'s p-values from the permutation null.
#' @param null The null statistics, one column per outcome.
#' @param obs The observed statistics.
#' @param ties "count" or "strict".
#' @param exact Whether every assignment was used.
#' @return One p-value per outcome.
#' @noRd
.rmbl_perm_pv <- function(null, obs, ties, exact) {
  vapply(
    seq_len(ncol(null)),
    function(j) {
      nz <- null[, j][is.finite(null[, j])]
      b <- if (ties == "count") {
        sum(abs(nz) >= abs(obs[j]) - 1e-12)
      } else {
        sum(abs(nz) > abs(obs[j]) + 1e-12)
      }
      if (exact) b / length(nz) else (b + 1) / (length(nz) + 1)
    },
    numeric(1L)
  )
}

#' plnpois()'s treatment, checked: numeric (or logical), no NA.
#' @param data The panel.
#' @param trtd The treatment column.
#' @return The treatment, numeric.
#' @noRd
.rmbl_pp_trtd <- function(data, trtd) {
  v <- .rmbl_colnames(trtd, "trtd")
  if (!v %in% names(data)) {
    stop(
      sprintf("plnpois: `trtd` (%s) is not a column of `data`", v),
      call. = FALSE
    )
  }
  d <- data[[v]]
  if (is.logical(d)) {
    d <- as.numeric(d)
  }
  if (!is.numeric(d) || anyNA(d)) {
    stop(.rmbl_fn(), "`trtd` must be numeric with no NA", call. = FALSE)
  }
  d
}

#' plnpois()'s offset, checked: a finite log exposure, or zero.
#' @param data The panel.
#' @param offset The offset column, or NULL.
#' @param n The number of rows; no offset is a zero vector of this length.
#' @return The offset, one per row.
#' @noRd
.rmbl_pp_offset <- function(data, offset, n) {
  if (!is.null(offset)) {
    ov <- .rmbl_colnames(offset, "offset")
    if (!ov %in% names(data)) {
      stop(
        .rmbl_fn(),
        sprintf("`offset` (%s) is not a column of `data`", ov),
        call. = FALSE
      )
    }
    if (!is.numeric(data[[ov]]) || !all(is.finite(data[[ov]]))) {
      stop(
        .rmbl_fn(),
        "`offset` must be a finite numeric column (a log exposure)",
        call. = FALSE
      )
    }
  }
  if (is.null(offset)) {
    rep(0, n)
  } else {
    .rmbl_num(data[[.rmbl_colnames(offset, "offset")]], "offset")
  }
}

#' The negative binomial (NB2) log likelihood at a log theta.
#' @param lt The log of theta.
#' @param mu The fitted means.
#' @param y The observed counts the NB2 likelihood is evaluated at.
#' @return One number.
#' @noRd
.rmbl_nb_ll <- function(lt, mu, y) {
  th <- exp(lt)
  sum(
    lgamma(y + th) -
      lgamma(th) -
      lgamma(y + 1) +
      th * log(th / (th + mu)) +
      y * log(mu / (th + mu))
  )
}

#' The negative binomial fit of plnpois(), from the Poisson one.
#'
#' NB2: Var(Y) = mu + mu^2 / theta. The IRLS fit at fixed theta alternates
#' with the maximum of the profile likelihood in theta, to convergence.
#' @param X The design.
#' @param .y The counts.
#' @param fit The Poisson fit.
#' @param off The offset.
#' @return list(fit, theta).
#' @noRd
.rmbl_pp_negbin <- function(X, .y, fit, off) {
  theta <- Inf
  for (it in 1:100) {
    th_new <- exp(
      stats::optimize(
        .rmbl_nb_ll,
        c(-10, 15),
        mu = fit$fitted.values,
        y = .y,
        maximum = TRUE
      )$maximum
    )
    fit <- stats::glm.fit(
      X,
      .y,
      family = .rmbl_negbin_family(th_new),
      offset = off,
      start = fit$coefficients
    )
    done <- abs(log(th_new) - log(theta)) < 1e-8
    theta <- th_new
    if (done) break
  }
  if (theta > exp(14)) {
    warning(
      "no overdispersion: theta is at its bound, the Poisson model fits",
      call. = FALSE
    )
  }
  list(fit = fit, theta = theta)
}

#' The cluster-robust covariance of plnpois()'s coefficients.
#' @param X The design, collinear columns dropped.
#' @param fit The fit.
#' @param theta The negative binomial theta (Inf: Poisson).
#' @param .y The counts.
#' @param clk The cluster of each row.
#' @param fes The unit and time factors.
#' @param nx The number of regressors.
#' @return list(vc, gn).
#' @noRd
.rmbl_pp_vcov <- function(X, fit, theta, .y, clk, fes, nx) {
  mu <- fit$fitted.values
  wt <- if (is.finite(theta)) mu * theta / (theta + mu) else mu
  bread <- solve(crossprod(X * sqrt(wt)))
  s <- rowsum(X * ((.y - mu) * wt / mu), clk)
  gn <- nrow(s)
  ny <- length(.y)
  kk <- nx + .rmbl_k_fe(lapply(fes, as.integer), clk)
  vc <- bread %*% crossprod(s) %*% bread * gn / (gn - 1) * (ny - 1) / (ny - kk)
  list(vc = vc, gn = gn)
}

#' plnpois()'s table of rate ratios.
#' @param terms The regressors' names.
#' @param fit The fit.
#' @param vc The covariance.
#' @param nx The number of regressors.
#' @param conflvl The confidence level of the rate ratios' limits.
#' @return A data frame.
#' @noRd
.rmbl_pp_table <- function(terms, fit, vc, nx, conflvl) {
  k <- seq_len(nx)
  b <- fit$coefficients[k]
  se <- sqrt(diag(vc))[k]
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  data.frame(
    term = terms,
    estimate = unname(b),
    se = unname(se),
    rateratio = exp(unname(b)),
    lower = exp(unname(b - z * se)),
    upper = exp(unname(b + z * se)),
    p_value = 2 * stats::pnorm(-abs(unname(b / se))),
    stringsAsFactors = FALSE
  )
}

#' synctl()'s treated unit, checked: one unit of the panel.
#' @param treunit The treated unit.
#' @param p The panel (.rmbl_panel()).
#' @return The unit, as text.
#' @noRd
.rmbl_sc_unit <- function(treunit, p) {
  if (!is.atomic(treunit)) {
    stop("synctl: `treunit` is not a unit of `data`", call. = FALSE)
  }
  tu <- as.character(treunit)
  if (length(tu) != 1L || !tu %in% p$ul) {
    stop("synctl: `treunit` is not a unit of `data`", call. = FALSE)
  }
  tu
}

#' The balanced panel of synctl() as a unit-by-period matrix.
#' @param p The panel (.rmbl_panel()).
#' @param adopt The adoption period.
#' @return list(ym, pre): the outcomes and which periods precede adoption.
#' @noRd
.rmbl_sc_wide <- function(p, adopt) {
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) {
    stop("synctl: `data` must be a balanced panel", call. = FALSE)
  }
  if (nu < 3L) {
    stop(
      .rmbl_fn(),
      "synthetic control needs two donor units at least",
      call. = FALSE
    )
  }
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE, dimnames = list(p$ul, p$tl))
  pre <- p$tl < adopt
  if (sum(pre) < 2L || all(pre)) {
    stop(
      .rmbl_fn(),
      "`adopt` must leave two periods before it and one after",
      call. = FALSE
    )
  }
  list(ym = ym, pre = pre)
}

#' The synthetic control of one unit from donors.
#' @param i The unit.
#' @param donors The donor units.
#' @param sc The panel (.rmbl_sc_wide()).
#' @param ul The units' labels.
#' @return list(w, synth, gap, pre, post): the weights, the synthetic path, the
#'   gap and its root mean square before and after adoption.
#' @noRd
.rmbl_sc_fit <- function(i, donors, sc, ul) {
  w <- .rmbl_simplex_ls(
    t(sc$ym[donors, sc$pre, drop = FALSE]),
    sc$ym[i, sc$pre]
  )
  synth <- as.vector(crossprod(w, sc$ym[donors, , drop = FALSE]))
  gap <- sc$ym[i, ] - synth
  list(
    w = stats::setNames(w, ul[donors]),
    synth = synth,
    gap = gap,
    pre = sqrt(mean(gap[sc$pre]^2)),
    post = sqrt(mean(gap[!sc$pre]^2))
  )
}

#' The placebo ratios: each donor fitted from the other donors.
#' @param donors The donor units.
#' @param sc The panel (.rmbl_sc_wide()).
#' @param ul The units' labels.
#' @return The post/pre RMSPE ratio of each donor, named.
#' @noRd
.rmbl_sc_placebo <- function(donors, sc, ul) {
  pr <- vapply(
    donors,
    function(j) {
      fj <- .rmbl_sc_fit(j, setdiff(donors, j), sc, ul)
      fj$post / fj$pre
    },
    numeric(1L)
  )
  names(pr) <- ul[donors]
  pr
}

#' Checks sevidx()'s columns and weights.
#' @param data The panel sevidx() was given.
#' @param cols The unit, time, offence and count columns.
#' @param w The weights sevidx() sums the counts by, named by offence.
#' @return NULL, invisibly.
#' @noRd
.rmbl_sev_check <- function(data, cols, w) {
  for (nm in names(cols)) {
    v <- .rmbl_colnames(cols[[nm]], nm)
    if (!v %in% names(data)) {
      stop(
        sprintf("sevidx: `%s` (%s) is not a column of `data`", nm, v),
        call. = FALSE
      )
    }
  }
  if (
    !is.numeric(w) || is.null(names(w)) || anyNA(w) || !all(nzchar(names(w)))
  ) {
    stop(.rmbl_fn(), "`w` must be numbers named by offence", call. = FALSE)
  }
  invisible(NULL)
}

#' Sums a count over the weighted offences of each unit and period; NA where
#' one is missing.
#' @param v The values, one per row.
#' @param use Which rows are weighted offences.
#' @param key The unit and period of each row.
#' @param keys The units and periods, in order.
#' @param nw The number of weighted offences.
#' @return One sum per unit and period.
#' @noRd
.rmbl_sev_agg <- function(v, use, key, keys, nw) {
  s <- tapply(v[use], factor(key[use], levels = keys), function(z) {
    if (anyNA(z)) NA_real_ else sum(z)
  })
  n <- tapply(use[use], factor(key[use], levels = keys), length)
  s[is.na(n) | n < nw] <- NA_real_
  as.vector(s)
}

#' Checks cmlrisk()'s ages, events and populations.
#' @param age,e,.pop The ages, first events and populations.
#' @return NULL, invisibly.
#' @noRd
.rmbl_cr_check <- function(age, e, .pop) {
  n <- length(age)
  if (length(e) != n || length(.pop) != n) {
    stop(.rmbl_fn(), "`age`, `fireve` and `pop` must match", call. = FALSE)
  }
  if (anyNA(c(age, e, .pop)) || any(e < 0) || any(.pop <= 0)) {
    stop(
      .rmbl_fn(),
      "counts must be 0 or more and populations above 0, with no NA",
      call. = FALSE
    )
  }
  if (is.unsorted(age, strictly = TRUE)) {
    stop(.rmbl_fn(), "`age` must be increasing", call. = FALSE)
  }
  invisible(NULL)
}

#' cmlrisk()'s persons at risk or death rates, checked.
#' @param x The `atrisk` or `dthrate` values to check, one per age.
#' @param nm "atrisk" or "dthrate".
#' @param n The number of ages.
#' @return The values, numeric.
#' @noRd
.rmbl_cr_opt <- function(x, nm, n) {
  x <- .rmbl_num(x, nm)
  if (nm == "atrisk" && (length(x) != n || any(x <= 0))) {
    stop(.rmbl_fn(), "`atrisk` must be one per age, above 0", call. = FALSE)
  }
  if (nm == "dthrate" && (length(x) != n || any(x < 0 | x >= 1))) {
    stop(
      .rmbl_fn(),
      "`dthrate` must be one per age, from 0 to below 1",
      call. = FALSE
    )
  }
  x
}

#' The life table of cmlrisk(): hazards, persons at risk, cumulative risk and
#' Greenwood's variance sum.
#' @param age,e,.pop The ages, first events and populations.
#' @param atrisk The persons at risk, or NULL.
#' @param dthrate The death rates, or NULL.
#' @return list(h, nr, cr, v).
#' @noRd
.rmbl_cr_life <- function(age, e, .pop, atrisk, dthrate) {
  n <- length(age)
  h <- nr <- cr <- v <- numeric(n)
  surv <- 1
  l <- 1
  acc <- 0
  vs <- 0
  for (i in seq_len(n)) {
    nr[i] <- if (is.null(atrisk)) {
      .pop[i] * (1 - (if (i > 1L) cr[i - 1L] else 0))
    } else {
      atrisk[i]
    }
    h[i] <- e[i] / nr[i]
    if (h[i] > 1) {
      stop(
        .rmbl_fn(),
        sprintf(
          "more first events than persons at risk at age %s",
          format(age[i])
        ),
        call. = FALSE
      )
    }
    if (is.null(dthrate)) {
      surv <- surv * (1 - h[i])
      cr[i] <- 1 - surv
      vs <- vs + if (h[i] < 1) h[i] / (nr[i] * (1 - h[i])) else Inf
      v[i] <- vs
    } else {
      acc <- acc + l * h[i]
      l <- l * (1 - h[i] - dthrate[i])
      if (l < 0) {
        stop(
          .rmbl_fn(),
          sprintf(
            "events and deaths exceed the cohort at age %s",
            format(age[i])
          ),
          call. = FALSE
        )
      }
      cr[i] <- acc
      v[i] <- NA_real_
    }
  }
  list(h = h, nr = nr, cr = cr, v = v)
}

#' The cluster-robust (CR1) covariance, one-way or two-way.
#' @param x The design.
#' @param we The weighted residuals.
#' @param bread The inverse of the weighted cross-product of the design.
#' @param cl The clusters: a vector, or a list of one or two.
#' @param dof The small-sample factor (n - 1) / (n - k).
#' @return list(v, g): the covariance and the smaller number of clusters.
#' @noRd
.rmbl_cr1_vcov <- function(x, we, bread, cl, dof) {
  if (!is.list(cl)) {
    cl <- list(cl)
  }
  g <- min(vapply(cl, function(cc) length(unique(cc)), 1L))
  if (g < 2L) {
    stop(
      .rmbl_fn(),
      "cluster-robust errors need two clusters at least",
      call. = FALSE
    )
  }
  meat <- function(cc) {
    s <- rowsum(x * we, cc)
    bread %*% crossprod(s) %*% bread * (g / (g - 1)) * dof
  }
  v <- meat(cl[[1L]])
  if (length(cl) == 2L) {
    # two-way (Cameron, Gelbach and Miller 2011): V_a + V_b - V_ab, every term
    # with the factor of the smaller dimension, and t on min(G) - 1 degrees of
    # freedom (fixest's defaults)
    v <- v + meat(cl[[2L]]) - meat(paste(cl[[1L]], cl[[2L]]))
    ev <- eigen(v, symmetric = TRUE)
    if (any(ev$values < 0)) {
      v <- ev$vectors %*%
        diag(pmax(ev$values, 0), length(ev$values)) %*%
        t(ev$vectors)
    }
  }
  list(v = v, g = g)
}

#' The treated cohort-period cells of the extended two-way fixed effects
#' regression.
#' @param gr The cohort of each row.
#' @param tp The period of each row.
#' @param ok Which rows are used.
#' @param ref_g The comparison cohort (Inf: the never treated).
#' @return A data frame of g and t, ordered.
#' @noRd
.rmbl_etwfe_cells <- function(gr, tp, ok, ref_g) {
  cells <- unique(data.frame(g = gr, t = tp)[
    ok & is.finite(gr) & gr != ref_g & tp >= gr,
  ])
  cells <- cells[order(cells$g, cells$t), ]
  if (!nrow(cells)) {
    stop(.rmbl_fn(), "no treated cohort-period cell", call. = FALSE)
  }
  cells
}

#' The active-set solution of .rmbl_simplex_ls().
#' @param ata,atb The normal equations' cross-products.
#' @param k The number of weights.
#' @return The weights, or NULL when the active set does not settle.
#' @noRd
.rmbl_simplex_active <- function(ata, atb, k) {
  sup <- seq_len(k)
  w <- rep(1 / k, k)
  scale <- max(1, abs(atb))
  for (it in seq_len(10L * k + 10L)) {
    m <- rbind(
      cbind(2 * ata[sup, sup, drop = FALSE], 1),
      c(rep(1, length(sup)), 0)
    )
    sol <- tryCatch(solve(m, c(2 * atb[sup], 1)), error = function(e) NULL)
    if (is.null(sol) || !all(is.finite(sol))) {
      break
    }
    ws <- sol[seq_along(sup)]
    mu <- sol[length(sol)]
    if (any(ws < -1e-12)) {
      # one column alone solves to weight 1 exactly, so the support never
      # empties
      sup <- sup[-which.min(ws)]
      next
    }
    w[] <- 0
    w[sup] <- ws
    # the reduced gradient of the Lagrangian on the zero weights: none below
    # zero is the optimum
    g <- 2 * (as.vector(ata %*% w) - as.vector(atb)) + mu
    off <- setdiff(seq_len(k), sup)
    if (!length(off) || all(g[off] >= -1e-10 * scale)) {
      return(w)
    }
    sup <- sort(c(sup, off[which.min(g[off])]))
  }
  NULL
}

#' The Euclidean projection onto the unit simplex.
#' @param v A vector.
#' @return Its projection.
#' @noRd
.rmbl_simplex_proj <- function(v) {
  u <- sort(v, decreasing = TRUE)
  cs <- cumsum(u)
  rho <- max(which(u - (cs - 1) / seq_along(u) > 0))
  pmax(v - (cs[rho] - 1) / rho, 0)
}

#' Accelerated projected gradient (FISTA) on the simplex.
#' @param ata,atb The normal equations' cross-products.
#' @param k The number of weights.
#' @param maxit,tol The iteration cap and the tolerance.
#' @return The weights.
#' @noRd
.rmbl_simplex_fista <- function(ata, atb, k, maxit, tol) {
  lip <- max(eigen(ata, symmetric = TRUE, only.values = TRUE)$values, 1e-12)
  w <- rep(1 / k, k)
  z <- w
  s <- 1
  for (i in seq_len(maxit)) {
    wn <- .rmbl_simplex_proj(as.vector(z - (ata %*% z - atb) / lip))
    sn <- (1 + sqrt(1 + 4 * s^2)) / 2
    z <- wn + ((s - 1) / sn) * (wn - w)
    if (max(abs(wn - w)) < tol) {
      w <- wn
      break
    }
    w <- wn
    s <- sn
  }
  w
}

#' Polishes simplex weights: the exact least squares on their support with the
#' sum constraint (the KKT system), kept when it stays inside the simplex.
#' @param w The simplex weights to polish; their support is where they top 1e-8.
#' @param ata,atb The normal equations' cross-products.
#' @return The weights.
#' @noRd
.rmbl_simplex_polish <- function(w, ata, atb) {
  sup <- which(w > 1e-8)
  m <- rbind(
    cbind(2 * ata[sup, sup, drop = FALSE], 1),
    c(rep(1, length(sup)), 0)
  )
  sol <- tryCatch(solve(m, c(2 * atb[sup], 1)), error = function(e) NULL)
  if (!is.null(sol) && all(sol[seq_along(sup)] > 0)) {
    w[] <- 0
    w[sup] <- sol[seq_along(sup)]
  }
  w
}

# ---- printed reports ---------------------------------------------------------

#' The combined effect of plndid(), shown with its interval.
#' @param cb The `combined` attribute, or NULL.
#' @param lvl The confidence level.
#' @return A data frame, or NULL.
#' @noRd
.rmbl_pe_comb <- function(cb, lvl) {
  if (!is.data.frame(cb)) {
    return(NULL)
  }
  d <- .rmbl_ci_cols(.rmbl_plain(cb), lvl)
  names(d)[names(d) == "percent"] <- "pct_of_mean"
  names(d)[names(d) == "perse"] <- "pct_se"
  d
}

#' The pre-trend test of an event study as text.
#' @param pt The `pretrend` attribute, or NULL.
#' @return One string, or NULL.
#' @noRd
.rmbl_es_ptxt <- function(pt) {
  if (!is.list(pt) || !isTRUE(is.finite(pt$F))) {
    return(NULL)
  }
  sprintf(
    "F(%s, %s) = %.3f, p %s",
    format(pt$df1),
    format(pt$df2),
    pt$F,
    .rmbl_p_txt(pt$p_value)
  )
}

#' The reading of an event study.
#' @param pt The `pretrend` attribute, or NULL.
#' @return Sentences.
#' @noRd
.rmbl_es_reading <- function(pt) {
  lead <- paste(
    "Each row is the effect that many periods from adoption, measured",
    "against the reference period."
  )
  if (!is.list(pt) || !isTRUE(is.finite(pt$p_value))) {
    return(lead)
  }
  c(
    lead,
    if (pt$p_value < 0.05) {
      paste(
        "The leads differ from zero: the groups were already moving apart",
        "before adoption, so read the later effects with care."
      )
    } else {
      paste(
        "The leads are jointly consistent with zero, the testable part of",
        "parallel trends."
      )
    }
  )
}

#' The weight and average estimate of each kind of Goodman-Bacon comparison.
#' @param x A bacondcmp() result.
#' @return A data frame.
#' @noRd
.rmbl_bacon_types <- function(x) {
  ty <- unique(x$type)
  pick <- function(f, v) vapply(ty, f, v, USE.NAMES = FALSE)
  data.frame(
    type = ty,
    comparisons = pick(function(t) sum(x$type == t), 1L),
    weight = pick(function(t) sum(x$weight[x$type == t]), 1),
    estimate = pick(
      function(t) {
        i <- x$type == t
        sum(x$weight[i] * x$estimate[i]) / sum(x$weight[i])
      },
      1
    ),
    stringsAsFactors = FALSE
  )
}

#' The reading of a Goodman-Bacon decomposition.
#' @param x A bacondcmp() result.
#' @param later The weight on later-vs-earlier comparisons.
#' @return Sentences.
#' @noRd
.rmbl_bacon_reading <- function(x, later) {
  c(
    sprintf(
      "The two-way estimate %s is the weighted average of these %d",
      .rmbl_fmt_num(attr(x, "twfe") %||% NA_real_),
      nrow(x)
    ),
    "two-group comparisons.",
    if (later > 0) {
      sprintf(
        paste(
          "%.1f%% of the weight is on comparisons that use already-treated",
          "units as controls; if the effect grows over time, that part pulls",
          "the two-way estimate away from the true effect."
        ),
        100 * later
      )
    } else {
      "No weight is on comparisons that use already-treated units as controls."
    }
  )
}

#' The model line of a fixed-effects count model.
#' @param family "poisson" or "negbin".
#' @param theta The negative binomial's theta.
#' @return One string.
#' @noRd
.rmbl_pp_model <- function(family, theta) {
  if (identical(family, "negbin")) {
    return(sprintf("negative binomial (theta %s)", .rmbl_fmt_num(theta)))
  }
  "Poisson"
}

#' The reading of a synthetic control.
#' @param x A synctl() result.
#' @param post The gaps after adoption.
#' @param plac Whether placebos were run.
#' @return Sentences.
#' @noRd
.rmbl_synth_reading <- function(x, post, plac) {
  c(
    sprintf(
      paste(
        "The synthetic %s is the weighted mix of donors that best tracks it",
        "before adoption."
      ),
      x$treunit
    ),
    if (length(post)) {
      sprintf(
        "After adoption the treated unit is on average %s away from it.",
        .rmbl_fmt_num(mean(post))
      )
    },
    if (plac) {
      sprintf(
        paste(
          "Ranked against every donor run as a placebo, its post/pre ratio",
          "gives p %s."
        ),
        .rmbl_p_txt(x$p_value)
      )
    }
  )
}

#' .rmbl_panel()'s column arguments, each one name of a column of `data`.
#' @param data The panel data frame.
#' @param cols The unit, time and outcome arguments, named.
#' @return NULL, invisibly.
#' @noRd
.rmbl_panel_cols <- function(data, cols) {
  .rmbl_df_names(data)
  for (nm in names(cols)) {
    v <- .rmbl_colnames(cols[[nm]], nm)
    if (!v %in% names(data)) {
      stop(
        .rmbl_fn(),
        sprintf("`%s` (%s) is not a column of `data`", nm, v),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}
