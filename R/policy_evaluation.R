# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Evaluating a policy from administrative panels: two-way fixed-effects difference in differences, event
# studies, staggered adoption (Callaway and Sant'Anna; Wooldridge), the Goodman-Bacon decomposition,
# de Chaisemartin and D'Haultfoeuille's estimator for switching treatments, permutation inference and
# Westfall-Young stepdown p-values, fixed-effects Poisson, synthetic control, severity-weighted crime
# indices, lagged justice-pipeline rates, cumulative risk from first events, and place-based buffers.
# All of it on unit-by-period tables of counts or rates; base R only.

# ---- panel helpers ---------------------------------------------------------------------------------

.rmbl_panel <- function(data, unit, time, outcome) {
  .rmbl_df_names(data)
  for (nm in c("unit", "time", "outcome")) {
    v <- .rmbl_colnames(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("`%s` (%s) is not a column of `data`", nm, v), call. = FALSE)
  }
  u <- data[[unit]]
  t <- data[[time]]
  if (!is.numeric(t) || anyNA(t)) stop("`time` must be a numeric column with no NA", call. = FALSE)
  if (anyNA(u)) stop("`unit` must have no NA", call. = FALSE)
  y <- .rmbl_num(data[[outcome]], "outcome")
  if (anyDuplicated(data.frame(u, t))) {
    stop("`data` has more than one row for a unit in a period", call. = FALSE)
  }
  list(u = as.integer(factor(u)), ul = levels(factor(u)), t = t, tl = sort(unique(t)), y = y)
}

.rmbl_first_treated <- function(data, first_treated, p) {
  v <- .rmbl_colnames(first_treated, "first_treated")
  if (!v %in% names(data)) stop(sprintf("`first_treated` (%s) is not a column of `data`", v), call. = FALSE)
  g <- data[[v]]
  if (is.logical(g) && all(is.na(g))) g <- as.numeric(g)
  if (!is.numeric(g)) stop("`first_treated` must be numeric (NA, 0 or Inf for never treated)", call. = FALSE)
  g[is.na(g) | g == 0] <- Inf
  per_unit <- tapply(g, p$u, function(z) length(unique(z)))
  if (any(per_unit > 1L)) stop("`first_treated` must be the same in every row of a unit", call. = FALSE)
  g
}

# Two-way (or k-way) within transformation by alternating projections: exact for a balanced panel in
# one sweep, and convergent for an unbalanced one.
.rmbl_demean <- function(x, fes, tol = 1e-12, maxit = 10000L, w = NULL) {
  x <- as.matrix(x)
  if (!length(fes)) return(x)
  if (is.null(w)) w <- rep(1, nrow(x))
  lv <- lapply(fes, function(f) sort(unique(f)))
  idx <- lapply(seq_along(fes), function(k) match(fes[[k]], lv[[k]]))
  sw <- lapply(seq_along(fes), function(k) as.vector(rowsum(w, idx[[k]], reorder = TRUE)))
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

# OLS on demeaned data with one-way cluster-robust (CR1) variance. `k_fe` is the number of fixed-effect
# parameters counted in the small-sample factor (N - 1) / (N - K), as fixest counts them.
.rmbl_ols_cr1 <- function(y, x, cl, k_fe, w = NULL) {
  if (is.null(w)) w <- rep(1, length(y))
  sw <- sqrt(w)
  q <- qr(x * sw)
  if (q$rank < ncol(x)) {
    drop <- colnames(x)[q$pivot[(q$rank + 1L):ncol(x)]]
    stop(sprintf("collinear with the fixed effects or each other: %s", paste(drop, collapse = ", ")),
         call. = FALSE)
  }
  b <- qr.coef(q, y * sw)
  e <- as.vector(y - x %*% b)
  bread <- chol2inv(qr.R(q))
  bread[q$pivot, q$pivot] <- bread
  n <- length(y)
  kk <- ncol(x) + k_fe
  if (!is.list(cl)) cl <- list(cl)
  g <- min(vapply(cl, function(cc) length(unique(cc)), 1L))
  if (g < 2L) stop("cluster-robust errors need two clusters at least", call. = FALSE)
  meat <- function(cc) {
    s <- rowsum(x * (w * e), cc)
    bread %*% crossprod(s) %*% bread * (g / (g - 1)) * ((n - 1) / (n - kk))
  }
  v <- meat(cl[[1L]])
  if (length(cl) == 2L) {
    # two-way (Cameron, Gelbach and Miller 2011): V_a + V_b - V_ab, every term with the factor of the
    # smaller dimension, and t on min(G) - 1 degrees of freedom (fixest's defaults)
    v <- v + meat(cl[[2L]]) - meat(paste(cl[[1L]], cl[[2L]]))
    ev <- eigen(v, symmetric = TRUE)
    if (any(ev$values < 0)) v <- ev$vectors %*% diag(pmax(ev$values, 0), length(ev$values)) %*% t(ev$vectors)
  }
  dimnames(v) <- list(colnames(x), colnames(x))
  list(coef = stats::setNames(as.vector(b), colnames(x)), vcov = v, resid = e, n = n, clusters = g)
}

.rmbl_k_fe <- function(fes, cl) {
  # fixest's "nested" count: the fixed effects nested in the clusters drop out, the others count
  # their levels less one, and the absorbed constant counts one
  if (!is.list(cl)) cl <- list(cl)
  k <- 1L
  for (f in fes) {
    nested <- any(vapply(cl, function(cc) all(tapply(cc, f, function(z) length(unique(z))) == 1L), NA))
    if (!nested) k <- k + length(unique(f)) - 1L
  }
  k
}

.rmbl_cluster <- function(data, cluster, p) {
  if (is.null(cluster)) return(p$u)
  v <- .rmbl_colnames(cluster, "cluster", several = TRUE)
  if (length(v) > 2L) stop("`cluster` names one column, or two for two-way clustering", call. = FALSE)
  out <- lapply(v, function(cc) {
    if (!cc %in% names(data)) stop(sprintf("`cluster` (%s) is not a column of `data`", cc), call. = FALSE)
    if (anyNA(data[[cc]])) stop("`cluster` must have no NA", call. = FALSE)
    as.integer(factor(data[[cc]]))
  })
  if (length(out) == 1L) out[[1L]] else out
}

.rmbl_covariates <- function(data, covariates) {
  if (is.null(covariates)) return(NULL)
  covariates <- .rmbl_colnames(covariates, "covariates", several = TRUE)
  miss <- setdiff(covariates, names(data))
  if (length(miss)) stop(sprintf("not columns of `data`: %s", paste(miss, collapse = ", ")), call. = FALSE)
  m <- vapply(covariates, function(v) .rmbl_num(data[[v]], v), numeric(nrow(data)))
  matrix(m, nrow(data), dimnames = list(NULL, covariates))
}

.rmbl_weights <- function(data, weights) {
  if (is.null(weights)) return(rep(1, nrow(data)))
  v <- .rmbl_colnames(weights, "weights")
  if (!v %in% names(data)) stop(sprintf("`weights` (%s) is not a column of `data`", v), call. = FALSE)
  w <- .rmbl_num(data[[v]], "weights")
  if (anyNA(w) || any(w < 0) || !any(w > 0)) stop("`weights` must be 0 or more, with no NA", call. = FALSE)
  w
}

.rmbl_coef_table <- function(fit, terms, conf_level) {
  se <- sqrt(diag(fit$vcov))[terms]
  est <- fit$coef[terms]
  df <- fit$clusters - 1L
  tq <- stats::qt(1 - (1 - conf_level) / 2, df)
  tv <- est / se
  data.frame(term = terms, estimate = unname(est), se = unname(se), lower = unname(est - tq * se),
             upper = unname(est + tq * se), t = unname(tv), p_value = unname(2 * stats::pt(-abs(tv), df)),
             stringsAsFactors = FALSE)
}

# ---- difference in differences ---------------------------------------------------------------------

#' Difference in differences with two-way fixed effects
#'
#' The effect of a policy on a unit-by-period panel (municipalities by month, blocks
#' by quarter, courts by year), from a regression of the outcome on the treatment
#' indicator with unit and period fixed effects, and standard errors clustered by unit
#' or by any coarser grouping.
#'
#' @details The model is
#' \deqn{Y_{it} = \beta T_{it} + X_{it}'\gamma + \delta_i + \mu_t +
#' \varepsilon_{it},}{Y_it = b T_it + X_it'g + d_i + m_t + e_it,} fitted by ordinary
#' least squares after the within transformation (alternating projections, so an
#' unbalanced panel is fine). The variance is the one-way cluster-robust CR1
#' estimator,
#' \deqn{\hat V = \frac{G}{G - 1}\frac{N - 1}{N - K} (\tilde X'\tilde X)^{-1}
#' \Big(\sum_g \tilde X_g'\hat u_g \hat u_g'\tilde X_g\Big) (\tilde X'\tilde
#' X)^{-1},}{V = G/(G - 1) (N - 1)/(N - K) (X'X)^-1 (sum_g X_g'u_g u_g'X_g) (X'X)^-1,}
#' with \eqn{K} counting the regressors and the fixed effects not nested in the
#' clusters, and tests and intervals use Student's t on \eqn{G - 1} degrees of
#' freedom. These are the conventions of Stata's \code{reghdfe} and R's \code{fixest}.
#'
#' The relative effect is \eqn{\hat\beta} over the mean outcome of the units never
#' treated (or not yet treated) in the periods before the first treatment, the way an
#' effect on a rate is usually reported ("a 12\% fall").
#'
#' With \code{fixed_effects = "time"} the unit effects are left out, and the model is
#' the cross-section with period effects of a comparison between kinds of units (for
#' example blocks in dynastic and in other wards).
#'
#' When treatment starts at different times, this estimator weights earlier-treated
#' units as controls for later ones, and can be biased if the effect changes over
#' time: see \code{\link{bacon_decomposition}} for the weights and
#' \code{\link{staggered_att}} for estimators that avoid them.
#'
#' @param data A data frame, one row per unit and period.
#' @param unit,time,outcome Column names: the unit, the period (numeric, for example a
#'   year or a month index) and the outcome.
#' @param treated Column name of the treatment indicator (0 or 1).
#' @param covariates Optional column names of time-varying controls.
#' @param cluster Column name of the clusters (default the unit), or two column names
#'   for two-way clustering (Cameron, Gelbach and Miller 2011):
#'   \eqn{V_a + V_b - V_{ab}}, each term with the small-sample factor of the dimension
#'   with fewer clusters, and t on its \eqn{G - 1} degrees of freedom. A composite
#'   cluster (district by month, say) is one column made with \code{interaction()}.
#' @param fixed_effects \code{c("unit", "time")} (default) or \code{"time"}.
#' @param weights Optional column name of non-negative weights (population, or
#'   matching weights): weighted least squares, with weighted within-means.
#' @param combine Optional linear combination of the terms, named by them, reported
#'   with its delta-method standard error as the attribute \code{combined}. For a
#'   phase-in model with an exposure term \eqn{E_{it} = \min(t - G_i, K)},
#'   \code{combine = c(treated = 1, exposure = 12)} is the effect after twelve
#'   periods, with its error, and as a percentage of the comparison units' pre-period
#'   mean (that mean taken as fixed).
#' @param conf_level Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_did}, one row per term (the treatment
#'   first, then the covariates): \code{term}, \code{estimate}, \code{se},
#'   \code{lower}, \code{upper}, \code{t}, \code{p_value}. Attributes: \code{n},
#'   \code{clusters}, \code{control_mean} (the pre-period mean of the comparison
#'   units), \code{relative_effect} (the estimate over it), \code{vcov}, and with
#'   \code{combine} also \code{combined}.
#' @references Bertrand M, Duflo E, Mullainathan S (2004). How much should we trust
#'   differences-in-differences estimates? Quarterly Journal of Economics
#'   119(1):249-275. \doi{10.1162/003355304772839588}
#'
#' Cameron AC, Gelbach JB, Miller DL (2011). Robust inference with multiway
#' clustering. Journal of Business and Economic Statistics 29(2):238-249.
#' \doi{10.1198/jbes.2010.07136}
#'
#' Cameron AC, Miller DL (2015). A practitioner's guide to cluster-robust inference.
#' Journal of Human Resources 50(2):317-372. \doi{10.3368/jhr.50.2.317}
#'
#' Applied to a staggered criminal-procedure reform, municipality by month: Acosta C,
#' Mejia D, Zorro Medina A (2023). On the tension between due process protection and
#' public safety: the case of an extensive procedural reform in Colombia.
#' \doi{10.2139/ssrn.4585682}
#' @seealso \code{\link{event_study}}, \code{\link{staggered_att}},
#'   \code{\link{permutation_inference}}, \code{\link{fe_poisson}}.
#' @examples
#' p <- policy_example()
#' did_panel(p, "district", "month", "crime_rate", "reformed")
#' # clustered by region instead of district
#' did_panel(p, "district", "month", "crime_rate", "reformed", cluster = "region")
#' @export
did_panel <- function(data, unit, time, outcome, treated, covariates = NULL, cluster = NULL,
                      fixed_effects = c("unit", "time"), weights = NULL, combine = NULL, conf_level = 0.95) {
  conf_level <- .rmbl_conf_level(conf_level)
  fixed_effects <- .rmbl_arg(fixed_effects, c("unit", "time"), several = TRUE)
  if (!"time" %in% fixed_effects) stop("`fixed_effects` must include \"time\"", call. = FALSE)
  p <- .rmbl_panel(data, unit, time, outcome)
  v <- .rmbl_colnames(treated, "treated")
  if (!v %in% names(data)) stop(sprintf("`treated` (%s) is not a column of `data`", v), call. = FALSE)
  d <- data[[v]]
  if (is.logical(d)) d <- as.numeric(d)
  if (!is.numeric(d) || anyNA(d) || !all(d %in% c(0, 1))) {
    stop("`treated` must be 0 or 1 (or FALSE or TRUE), with no NA", call. = FALSE)
  }
  if (length(unique(d)) < 2L) stop("`treated` never varies: there is no comparison", call. = FALSE)
  w <- .rmbl_weights(data, weights)
  cl <- .rmbl_cluster(data, cluster, p)
  x <- cbind(treated = d, .rmbl_covariates(data, covariates))
  fes <- list(time = as.integer(factor(p$t)))
  if ("unit" %in% fixed_effects) fes <- c(list(unit = p$u), fes)
  xd <- .rmbl_demean(x, fes, w = w)
  yd <- as.vector(.rmbl_demean(p$y, fes, w = w))
  fit <- .rmbl_ols_cr1(yd, xd, cl, .rmbl_k_fe(fes, cl), w = w)
  out <- .rmbl_coef_table(fit, colnames(x), conf_level)
  ever <- tapply(d, p$u, max)[p$u] > 0
  first <- min(p$t[d == 1])
  pre <- !ever & p$t < first
  if (!any(pre)) pre <- d == 0 & p$t < first
  cm <- if (any(pre)) sum(w[pre] * p$y[pre]) / sum(w[pre]) else NA_real_
  if (!is.null(combine)) {
    if (!is.numeric(combine) || is.null(names(combine)) || !all(names(combine) %in% colnames(x))) {
      stop("`combine` must be numbers named by the terms (\"treated\" and covariates)", call. = FALSE)
    }
    a <- stats::setNames(numeric(ncol(x)), colnames(x))
    a[names(combine)] <- combine
    est <- sum(a * fit$coef)
    se <- sqrt(as.numeric(t(a) %*% fit$vcov %*% a))
    tq <- stats::qt(1 - (1 - conf_level) / 2, fit$clusters - 1L)
    attr(out, "combined") <- data.frame(estimate = est, se = se, lower = est - tq * se, upper = est + tq * se,
                                        percent = 100 * est / cm, percent_se = 100 * se / abs(cm))
  }
  attr(out, "n") <- fit$n
  attr(out, "clusters") <- fit$clusters
  attr(out, "control_mean") <- cm
  attr(out, "relative_effect") <- out$estimate[1L] / cm
  attr(out, "conf_level") <- conf_level
  attr(out, "vcov") <- fit$vcov
  class(out) <- c("rmbl_did", "data.frame")
  out
}

#' @export
print.rmbl_did <- function(x, ...) {
  d <- as.data.frame(x)
  cat(sprintf("Difference in differences: %d observations, %d clusters\n", attr(x, "n"), attr(x, "clusters")))
  print(format(d, digits = 4L), row.names = FALSE)
  cm <- attr(x, "control_mean")
  if (is.finite(cm) && cm != 0) {
    cat(sprintf("Effect relative to the comparison units' pre-period mean (%.4g): %+.1f%%\n", cm,
                100 * attr(x, "relative_effect")))
  }
  invisible(x)
}

# ---- event study -----------------------------------------------------------------------------------

#' An event study: the effect period by period around adoption
#'
#' Leads and lags of a policy's adoption, from a two-way fixed-effects regression on
#' indicators of the time since adoption, with a joint test that the leads are zero
#' (no effect before the policy, the testable part of parallel trends).
#'
#' @details With \eqn{G_i} the first treated period of unit \eqn{i} and
#' \eqn{k = t - G_i},
#' \deqn{Y_{it} = \sum_{k = -L, k \ne r}^{M} \gamma_k \mathbf 1(t - G_i = k) +
#' X_{it}'\theta + \delta_i + \mu_t + \varepsilon_{it},}{Y_it = sum_k g_k 1(t - G_i =
#' k) + X_it'th + d_i + m_t + e_it,} with the reference period \eqn{r} (default -1,
#' the period before adoption) left out. Times beyond the window are binned into its
#' end points (\code{bin = TRUE}), or dropped. Units never treated have every
#' indicator 0. The variance and degrees of freedom are those of
#' \code{\link{did_panel}}. The pre-trend test is the Wald statistic
#' \eqn{W = \hat\gamma_{pre}'\hat V_{pre}^{-1}\hat\gamma_{pre}}, reported as
#' \eqn{F = W/q} on \eqn{q} and \eqn{G - 1} degrees of freedom.
#'
#' With staggered adoption and effects that change over time, the lead and lag
#' coefficients can mix in effects from other periods (Sun and Abraham 2021);
#' \code{\link{staggered_att}} gives the event-time effects free of that.
#'
#' @inheritParams did_panel
#' @param first_treated Column name of the period a unit is first treated (\code{NA},
#' 0 or \code{Inf} for a unit never treated). Treatment is taken as staying on.
#' @param leads,lags The number of periods before and after adoption to estimate
#' (default 4 and 4).
#' @param reference The period left out (default -1).
#' @param bin Bin the periods beyond the window into its end points (default
#' \code{TRUE}).
#' @return A data frame of class \code{rmbl_event_study}: \code{event_time},
#'   \code{estimate}, \code{se}, \code{lower}, \code{upper}, \code{t}, \code{p_value},
#'   with the reference period as a row of zeros; attributes \code{pretrend} (a list:
#'   \code{F}, \code{df1}, \code{df2}, \code{p_value}), \code{vcov} (of the estimated
#'   event times), \code{n}, \code{clusters}, \code{conf_level}. \code{plot()} draws
#'   it.
#' @references Sun L, Abraham S (2021). Estimating dynamic treatment effects in event
#'   studies with heterogeneous treatment effects. Journal of Econometrics
#'   225(2):175-199. \doi{10.1016/j.jeconom.2020.09.006}
#'
#' Applied to the effect of donations on police stops, block by quarter: Zorro Medina
#' A, Hackett D, Green D, Vargas R (2025). Evidence of donor bias in Chicago police
#' stops. \href{https://arxiv.org/abs/2504.15140}{arXiv:2504.15140}.
#' @seealso \code{\link{did_panel}}, \code{\link{staggered_att}}.
#' @examples
#' p <- policy_example()
#' es <- event_study(p, "district", "month", "crime_rate", "reform_month", leads = 3,
#'                   lags = 4)
#' es
#' attr(es, "pretrend")$p_value
#' plot(es)
#' @export
event_study <- function(data, unit, time, outcome, first_treated, leads = 4L, lags = 4L, reference = -1L,
                        bin = TRUE, covariates = NULL, cluster = NULL, conf_level = 0.95) {
  conf_level <- .rmbl_conf_level(conf_level)
  leads <- .rmbl_scalar(leads, "leads", 1, 1000, integer = TRUE)
  lags <- .rmbl_scalar(lags, "lags", 0, 1000, integer = TRUE)
  reference <- .rmbl_scalar(reference, "reference", -leads, lags, integer = TRUE)
  if (!is.logical(bin) || length(bin) != 1L || is.na(bin)) stop("`bin` must be TRUE or FALSE", call. = FALSE)
  p <- .rmbl_panel(data, unit, time, outcome)
  g <- .rmbl_first_treated(data, first_treated, p)
  if (all(is.infinite(g))) stop("no unit is ever treated", call. = FALSE)
  k <- p$t - g
  keep <- rep(TRUE, length(k))
  if (bin) {
    k[is.finite(k) & k < -leads] <- -leads
    k[is.finite(k) & k > lags] <- lags
  } else {
    keep <- !is.finite(k) | (k >= -leads & k <= lags)
  }
  ks <- setdiff(seq(-leads, lags), reference)
  x <- vapply(ks, function(j) as.numeric(is.finite(k) & k == j), numeric(length(k)))
  x <- matrix(x, length(k), dimnames = list(NULL, paste0("k", ks)))
  cv <- .rmbl_covariates(data, covariates)
  if (!is.null(cv)) x <- cbind(x, cv)
  cl <- .rmbl_cluster(data, cluster, p)
  sub <- function(z) if (is.matrix(z)) z[keep, , drop = FALSE] else z[keep]
  fes <- list(unit = sub(p$u), time = as.integer(factor(sub(p$t))))
  cl <- sub(cl)
  x <- sub(x)
  present <- colSums(abs(x)) > 0
  if (any(!present[seq_along(ks)])) {
    stop(sprintf("no observation at event time %s: narrow `leads` or `lags`",
                 paste(ks[!present[seq_along(ks)]], collapse = ", ")), call. = FALSE)
  }
  fit <- .rmbl_ols_cr1(as.vector(.rmbl_demean(sub(p$y), fes)), .rmbl_demean(x, fes), cl, .rmbl_k_fe(fes, cl))
  tab <- .rmbl_coef_table(fit, paste0("k", ks), conf_level)
  tab$event_time <- ks
  ref <- data.frame(term = paste0("k", reference), estimate = 0, se = 0, lower = 0, upper = 0, t = NA_real_,
                    p_value = NA_real_, event_time = reference, stringsAsFactors = FALSE)
  out <- rbind(tab, ref)
  out <- out[order(out$event_time), c("event_time", "estimate", "se", "lower", "upper", "t", "p_value")]
  rownames(out) <- NULL
  pre <- paste0("k", ks[ks < 0])
  if (length(pre)) {
    gm <- fit$coef[pre]
    w <- as.numeric(t(gm) %*% solve(fit$vcov[pre, pre, drop = FALSE], gm))
    q <- length(pre)
    pt <- list(F = w / q, df1 = q, df2 = fit$clusters - 1L,
               p_value = stats::pf(w / q, q, fit$clusters - 1L, lower.tail = FALSE))
  } else {
    pt <- list(F = NA_real_, df1 = 0L, df2 = fit$clusters - 1L, p_value = NA_real_)
  }
  attr(out, "pretrend") <- pt
  attr(out, "vcov") <- fit$vcov[paste0("k", ks), paste0("k", ks), drop = FALSE]
  attr(out, "n") <- fit$n
  attr(out, "clusters") <- fit$clusters
  attr(out, "conf_level") <- conf_level
  class(out) <- c("rmbl_event_study", "data.frame")
  out
}

#' @export
print.rmbl_event_study <- function(x, ...) {
  cat(sprintf("Event study: %d observations, %d clusters\n", attr(x, "n"), attr(x, "clusters")))
  print(format(as.data.frame(x), digits = 4L), row.names = FALSE)
  pt <- attr(x, "pretrend")
  if (is.finite(pt$F)) {
    cat(sprintf("Leads jointly zero: F(%d, %d) = %.3f, p = %.4g\n", pt$df1, pt$df2, pt$F, pt$p_value))
  }
  invisible(x)
}

#' @rdname plot-methods
#' @param style For an event study: \code{"dot"} (filled points with solid capped
#'   bars, the default) or \code{"stata"} (hollow points joined by a line, dashed
#'   capped bars, dashed reference lines).
#' @param shade_post Shade the periods after adoption (default \code{FALSE}).
#' @param ref_line Where the vertical reference line goes (default \code{-0.5},
#'   between the reference period and adoption; \code{0} puts it at adoption).
#' @export
plot.rmbl_event_study <- function(x, ..., main = NULL, col = NULL, palette = NULL, style = c("dot", "stata"),
                                  shade_post = FALSE, ref_line = -0.5) {
  .rmbl_plot_check(x, "rmbl_event_study")
  style <- .rmbl_arg(style)
  d <- as.data.frame(x)
  cl <- .bl_cols(1L, col, palette)
  yl <- range(c(d$lower, d$upper, 0), na.rm = TRUE)
  graphics::plot(d$event_time, d$estimate, ylim = yl, type = "n", xlab = "Periods since adoption",
                 ylab = "Effect, with its interval", main = .bl_main(main, "Event study"), ...)
  if (isTRUE(shade_post)) {
    u <- graphics::par("usr")
    graphics::rect(ref_line, u[3L], u[2L], u[4L], col = grDevices::adjustcolor("#9A9A9A", 0.15), border = NA)
  }
  w <- is.finite(d$lower) & is.finite(d$upper) & d$upper > d$lower
  if (style == "stata") {
    graphics::abline(h = 0, lty = 2, col = "#9A9A9A")
    graphics::abline(v = ref_line, lty = 2, col = "#9A9A9A")
    graphics::arrows(d$event_time[w], d$lower[w], d$event_time[w], d$upper[w], angle = 90, code = 3,
                     length = 0.03, col = "#7A7A7A", lty = 2)
    graphics::lines(d$event_time, d$estimate, col = cl)
    graphics::points(d$event_time, d$estimate, pch = 1, col = cl)
  } else {
    graphics::abline(h = 0, col = "#9A9A9A")
    graphics::abline(v = ref_line, lty = 2, col = "#9A9A9A")
    graphics::arrows(d$event_time[w], d$lower[w], d$event_time[w], d$upper[w], angle = 90, code = 3,
                     length = 0.03, col = cl)
    graphics::points(d$event_time, d$estimate, pch = 19, col = cl)
  }
  invisible(d)
}

# ---- staggered adoption ----------------------------------------------------------------------------

#' Effects of a policy adopted at different times
#'
#' Group-time average treatment effects for staggered adoption, with no unit used as a
#' control after it is treated (Callaway and Sant'Anna 2021), or the extended two-way
#' fixed-effects regression with a coefficient for every cohort and period (Wooldridge
#' 2021); aggregated to one effect and to effects by time since adoption.
#'
#' @details Let the cohort \eqn{g} be the units first treated in period \eqn{g}, and
#' \eqn{C} the comparison units: never treated (\code{control = "never"}), or not yet
#' treated by period \eqn{\max(t, g - 1)} (\code{"notyet"}, the default). For
#' \code{method = "callaway_santanna"},
#' \deqn{ATT(g, t) = \big(\bar Y_{g,t} - \bar Y_{g,b}\big) - \big(\bar Y_{C,t} - \bar
#' Y_{C,b}\big),}{ATT(g, t) = (Y_g,t - Y_g,b) - (Y_C,t - Y_C,b),} with base period
#' \eqn{b = g - 1} for \eqn{t \ge g}, and \eqn{b = t - 1} before (the "varying" base
#' of the \code{did} package), so a pre-period ATT is a placebo of one period. It
#' needs a balanced panel.
#'
#' With \code{covariates}, parallel trends need only hold conditionally on them, and
#' each \eqn{ATT(g, t)} is the two-period estimator of Sant'Anna and Zhao (2020) on
#' the cohort and its comparison units, with the covariates taken at the base period
#' \eqn{b} (use covariates fixed before treatment: one the policy moves is a bad
#' control). With \eqn{\Delta Y = Y_t - Y_b}, \eqn{D} the cohort indicator,
#' \eqn{\hat m(X)} the least-squares fit of \eqn{\Delta Y} on \eqn{X} among the
#' comparison units and \eqn{\hat p(X)} the logistic propensity of belonging to the
#' cohort,
#' \deqn{\widehat{ATT}_{dr} = \frac{\sum D (\Delta Y - \hat m)}{\sum D} - \frac{\sum
#' w (\Delta Y - \hat m)}{\sum w}, \quad w = \frac{\hat p (1 - D)}{1 - \hat
#' p};}{ATT_dr = sum D (dY - m) / sum D - sum w (dY - m) / sum w, w = p (1 - D) / (1 -
#' p);} \code{est_method = "ipw"} drops \eqn{\hat m} (normalised inverse probability
#' weighting) and \code{"reg"} drops the weights (outcome regression). The doubly
#' robust form is consistent when either the propensity or the outcome model is right.
#' Comparison units with \eqn{\hat p \ge 0.995} are trimmed, as the \code{DRDID}
#' package does. These agree with \code{did::att_gt()} to rounding error.
#'
#' For \code{method = "wooldridge"}, the regression of the outcome on unit and period
#' effects and an indicator for every treated cohort-period cell, with never-treated
#' (or last-treated) units as the comparison, gives each \eqn{ATT(g, t)} as a
#' coefficient; without covariates it equals the imputation estimator.
#'
#' The overall effect averages the post-adoption \eqn{ATT(g, t)} weighted by cohort
#' size; the event-time effect \eqn{\theta(e)} averages \eqn{ATT(g, g + e)} over the
#' cohorts observed at \eqn{e}, weighted by cohort size. Standard errors come from the
#' cluster bootstrap: units (or clusters) are resampled with replacement \code{reps}
#' times and everything recomputed; intervals are normal with the bootstrap standard
#' error.
#'
#' @inheritParams event_study
#' @param control \code{"notyet"} (default) or \code{"never"}.
#' @param method \code{"callaway_santanna"} (default) or \code{"wooldridge"}.
#' @param reps Bootstrap replications (default 499; 0 for none).
#' @param covariates Optional column names of covariates for conditional parallel
#'   trends (\code{method = "callaway_santanna"} only).
#' @param est_method With covariates: \code{"dr"} (doubly robust, default),
#'   \code{"ipw"} or \code{"reg"}.
#' @param seed Optional seed for the bootstrap.
#' @return A list of class \code{rmbl_staggered_att}: \code{att_gt} (a data frame:
#'   \code{cohort}, \code{period}, \code{event_time}, \code{estimate}, \code{se},
#'   \code{lower}, \code{upper}, \code{n_cohort}), \code{overall} (one row:
#'   \code{estimate}, \code{se}, \code{lower}, \code{upper}), \code{dynamic} (by
#'   \code{event_time}), \code{method}, \code{control}, \code{conf_level}.
#'   \code{plot()} draws the dynamic effects.
#' @references Callaway B, Sant'Anna PHC (2021). Difference-in-differences with
#'   multiple time periods. Journal of Econometrics 225(2):200-230.
#'   \doi{10.1016/j.jeconom.2020.12.001}
#'
#' Sant'Anna PHC, Zhao J (2020). Doubly robust difference-in-differences estimators.
#' Journal of Econometrics 219(1):101-122. \doi{10.1016/j.jeconom.2020.06.003}
#'
#' Wooldridge JM (2021). Two-way fixed effects, the two-way Mundlak regression, and
#' difference-in-differences estimators. \doi{10.2139/ssrn.3906345}
#'
#' Applied to a reform rolled out in four stages across judicial districts: Acosta,
#' Mejia and Zorro Medina (2023), see \code{\link{did_panel}}.
#' @seealso \code{\link{bacon_decomposition}}, \code{\link{event_study}}.
#' @examples
#' p <- policy_example()
#' s <- staggered_att(p, "district", "month", "crime_rate", "reform_month", reps = 99,
#'                    seed = 1)
#' s$overall
#' head(s$dynamic)
#' plot(s)
#' @export
staggered_att <- function(data, unit, time, outcome, first_treated, control = c("notyet", "never"),
                          method = c("callaway_santanna", "wooldridge"), cluster = NULL, reps = 499L,
                          seed = NULL, conf_level = 0.95, covariates = NULL,
                          est_method = c("dr", "ipw", "reg")) {
  control <- .rmbl_arg(control)
  method <- .rmbl_arg(method)
  est_method <- .rmbl_arg(est_method)
  if (!is.null(covariates) && method == "wooldridge") {
    stop("covariates are taken by method = \"callaway_santanna\" (doubly robust, IPW or regression)",
         call. = FALSE)
  }
  conf_level <- .rmbl_conf_level(conf_level)
  reps <- .rmbl_scalar(reps, "reps", 0, 1e5, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, outcome)
  g <- .rmbl_first_treated(data, first_treated, p)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel: every unit in every period", call. = FALSE)
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  gu <- g[o][seq(1L, by = nt, length.out = nu)]
  gu[is.finite(gu) & gu <= p$tl[1L]] <- -Inf  # treated from the first period: never comparable
  if (!any(is.finite(gu))) stop("no unit is first treated within the panel", call. = FALSE)
  if (control == "never" && !any(gu == Inf)) {
    stop("no never-treated unit: use control = \"notyet\"", call. = FALSE)
  }
  clu <- if (is.null(cluster)) seq_len(nu) else .rmbl_cluster(data, cluster, p)[o][seq(1L, by = nt, length.out = nu)]
  xm <- NULL
  if (!is.null(covariates)) {
    cv <- .rmbl_covariates(data, covariates)
    xm <- lapply(colnames(cv), function(v) matrix(cv[o, v], nu, nt, byrow = TRUE))
    names(xm) <- colnames(cv)
  }
  est <- function(idx) {
    y <- ym[idx, , drop = FALSE]
    gg <- gu[idx]
    if (method == "wooldridge") return(.rmbl_etwfe(y, gg, p$tl, control))
    .rmbl_cs(y, gg, p$tl, control, if (is.null(xm)) NULL else lapply(xm, function(m) m[idx, , drop = FALSE]),
             est_method)
  }
  agg <- function(a) {
    post <- a[a$event_time >= 0 & is.finite(a$estimate), ]
    w <- post$n_cohort
    ov <- if (nrow(post)) sum(w * post$estimate) / sum(w) else NA_real_
    es <- sort(unique(a$event_time))
    dyn <- vapply(es, function(e) {
      r <- a[a$event_time == e & is.finite(a$estimate), ]
      if (nrow(r)) sum(r$n_cohort * r$estimate) / sum(r$n_cohort) else NA_real_
    }, numeric(1L))
    list(overall = ov, dynamic = data.frame(event_time = es, estimate = dyn))
  }
  a0 <- est(seq_len(nu))
  g0 <- agg(a0)
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  se_gt <- rep(NA_real_, nrow(a0))
  se_ov <- NA_real_
  se_dyn <- rep(NA_real_, nrow(g0$dynamic))
  if (reps > 0L) {
    ucl <- unique(clu)
    draws <- .rmbl_with_seed(seed, lapply(seq_len(reps), function(r) {
      pick <- sample(ucl, length(ucl), replace = TRUE)
      idx <- unlist(lapply(pick, function(cc) which(clu == cc)), use.names = FALSE)
      ab <- tryCatch(est(idx), error = function(e) NULL)
      if (is.null(ab)) return(NULL)
      key <- paste(ab$cohort, ab$period)
      gb <- agg(ab)
      list(gt = ab$estimate[match(paste(a0$cohort, a0$period), key)], ov = gb$overall,
           dyn = gb$dynamic$estimate[match(g0$dynamic$event_time, gb$dynamic$event_time)])
    }))
    draws <- Filter(Negate(is.null), draws)
    sdn <- function(m) apply(m, 2L, stats::sd, na.rm = TRUE)
    se_gt <- sdn(do.call(rbind, lapply(draws, `[[`, "gt")))
    se_ov <- stats::sd(vapply(draws, `[[`, numeric(1L), "ov"), na.rm = TRUE)
    se_dyn <- sdn(do.call(rbind, lapply(draws, `[[`, "dyn")))
  }
  a0$se <- se_gt
  a0$lower <- a0$estimate - z * se_gt
  a0$upper <- a0$estimate + z * se_gt
  dyn <- g0$dynamic
  dyn$se <- se_dyn
  dyn$lower <- dyn$estimate - z * se_dyn
  dyn$upper <- dyn$estimate + z * se_dyn
  out <- list(att_gt = a0[c("cohort", "period", "event_time", "estimate", "se", "lower", "upper", "n_cohort")],
              overall = data.frame(estimate = g0$overall, se = se_ov, lower = g0$overall - z * se_ov,
                                   upper = g0$overall + z * se_ov),
              dynamic = dyn, method = method, control = control, conf_level = conf_level)
  class(out) <- "rmbl_staggered_att"
  out
}

.rmbl_cs <- function(y, gg, tl, control, x = NULL, est_method = "dr") {
  cohorts <- sort(unique(gg[is.finite(gg)]))
  rows <- list()
  for (cg in cohorts) {
    ig <- gg == cg
    for (j in seq_along(tl)[-1L]) {
      t <- tl[j]
      b <- if (t >= cg) max(which(tl < cg)) else j - 1L
      if (!length(b) || !is.finite(b)) next
      cut <- max(t, tl[b])
      ic <- if (control == "never") gg == Inf else (gg > cut & gg != cg)
      ic <- ic & gg != -Inf
      if (!any(ic) || !any(ig)) next
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
  if (!length(rows)) stop("no cohort has a comparison group in any period", call. = FALSE)
  m <- do.call(rbind, rows)
  data.frame(cohort = m[, 1L], period = m[, 2L], event_time = match(m[, 2L], tl) - match(m[, 1L], tl),
             estimate = m[, 3L], n_cohort = m[, 4L])
}

# The two-period panel DiD with covariates of Sant'Anna and Zhao (2020): outcome regression on the
# comparison units ("reg"), normalised inverse probability weighting ("ipw"), or both, doubly robust
# ("dr"); comparison units with a propensity above 0.995 are trimmed, as DRDID does.
.rmbl_drdid <- function(dy, d, x, est_method) {
  m <- 0
  if (est_method != "ipw") m <- as.vector(x %*% qr.coef(qr(x[d == 0, , drop = FALSE]), dy[d == 0]))
  if (anyNA(m)) stop("the covariates are collinear among the comparison units", call. = FALSE)
  if (est_method == "reg") return(mean((dy - m)[d == 1]))
  ps <- suppressWarnings(stats::glm.fit(x, d, family = stats::binomial()))$fitted.values
  wc <- ps * (1 - d) / (1 - ps)
  wc[d == 0 & ps >= 0.995] <- 0
  sum(d * (dy - m)) / sum(d) - sum(wc * (dy - m)) / sum(wc)
}

.rmbl_etwfe <- function(y, gg, tl, control) {
  nu <- nrow(y)
  nt <- ncol(y)
  keep <- gg != -Inf
  if (control == "notyet" && !any(gg == Inf)) {
    # no never-treated unit: the last cohort serves as the comparison, up to its adoption
    ref_g <- max(gg[is.finite(gg)])
  } else {
    ref_g <- Inf
  }
  u <- rep(seq_len(nu), each = nt)
  t <- rep(seq_len(nt), nu)
  yy <- as.vector(t(y))
  gr <- rep(gg, each = nt)
  ok <- rep(keep, each = nt)
  if (is.finite(ref_g)) ok <- ok & !(gr == ref_g & tl[t] >= ref_g)
  cells <- unique(data.frame(g = gr, t = tl[t])[ok & is.finite(gr) & gr != ref_g & tl[t] >= gr, ])
  cells <- cells[order(cells$g, cells$t), ]
  if (!nrow(cells)) stop("no treated cohort-period cell", call. = FALSE)
  x <- vapply(seq_len(nrow(cells)), function(i) as.numeric(gr == cells$g[i] & tl[t] == cells$t[i]),
              numeric(length(yy)))
  x <- matrix(x, length(yy))[ok, , drop = FALSE]
  colnames(x) <- paste0("g", cells$g, "_t", cells$t)
  fes <- list(u[ok], t[ok])
  xd <- .rmbl_demean(x, fes)
  yd <- as.vector(.rmbl_demean(yy[ok], fes))
  b <- qr.coef(qr(xd), yd)
  if (anyNA(b)) stop("a cohort-period cell is collinear with the fixed effects", call. = FALSE)
  data.frame(cohort = cells$g, period = cells$t, event_time = match(cells$t, tl) - match(cells$g, tl),
             estimate = unname(b), n_cohort = vapply(cells$g, function(cg) sum(gg == cg), numeric(1L)))
}

#' @export
print.rmbl_staggered_att <- function(x, ...) {
  cat(sprintf("Staggered adoption (%s, %s comparison units)\n",
              if (x$method == "wooldridge") "Wooldridge" else "Callaway-Sant'Anna",
              if (x$control == "never") "never-treated" else "not-yet-treated"))
  o <- x$overall
  cat(sprintf("Overall effect: %.4g (%.4g, %.4g)\n", o$estimate, o$lower, o$upper))
  cat("By time since adoption:\n")
  print(format(x$dynamic, digits = 4L), row.names = FALSE)
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_staggered_att <- function(x, ..., main = NULL, col = NULL, palette = NULL, style = c("dot", "stata"),
                                    shade_post = FALSE, ref_line = -0.5) {
  .rmbl_plot_check(x, "rmbl_staggered_att")
  d <- x$dynamic
  es <- structure(data.frame(event_time = d$event_time, estimate = d$estimate, se = d$se,
                             lower = ifelse(is.finite(d$lower), d$lower, d$estimate),
                             upper = ifelse(is.finite(d$upper), d$upper, d$estimate)),
                  class = c("rmbl_event_study", "data.frame"))
  # the periods before adoption in one colour and after in another, as the did package draws them
  cols <- if (is.null(col)) c("#2C6FBB", "#C0392B") else rep_len(col, 2L)
  plot.rmbl_event_study(es, ..., main = .bl_main(main, "Effect by time since adoption"), col = cols[2L],
                        palette = palette, style = style, shade_post = shade_post, ref_line = ref_line)
  pre <- es$event_time < 0
  w <- pre & es$upper > es$lower
  graphics::arrows(es$event_time[w], es$lower[w], es$event_time[w], es$upper[w], angle = 90, code = 3,
                   length = 0.03, col = cols[1L])
  graphics::points(es$event_time[pre], es$estimate[pre], pch = 19, col = cols[1L])
  invisible(es)
}

# ---- Goodman-Bacon ---------------------------------------------------------------------------------

#' The Goodman-Bacon decomposition of a two-way fixed-effects estimate
#'
#' Splits the two-way fixed-effects difference-in-differences estimate of a staggered
#' adoption into the two-group, two-period comparisons it averages, with their
#' weights: treated against never treated, earlier against later treated, and later
#' against earlier treated (the comparisons that use already-treated units as
#' controls).
#'
#' @details For a balanced panel with treatment that stays on and no covariates, the
#' estimate of \code{\link{did_panel}} is exactly
#' \eqn{\hat\beta = \sum_{k} s_{kU}\hat\beta_{kU} + \sum_{k \ne l} s_{kl}\hat\beta_{kl}},
#' with weights that sum to one and grow with the groups' sizes \eqn{n} and the
#' variance of their treatment over time \eqn{\bar D(1 - \bar D)} (Goodman-Bacon 2021,
#' theorem 1). Units treated from the first period act as an already-treated group. A
#' large weight on "later vs earlier" comparisons, together with effects that grow
#' over time, is the warning sign that the two-way estimate is biased.
#'
#' @inheritParams did_panel
#' @return A data frame of class \code{rmbl_bacon}: \code{type}
#'   (\code{"treated vs never"}, \code{"earlier vs later"},
#'   \code{"later vs earlier"}), \code{treated}, \code{control} (the adoption periods;
#'   \code{Inf} for never), \code{estimate}, \code{weight}; attribute \code{twfe} (the
#'   weighted sum, equal to the two-way estimate).
#' @references Goodman-Bacon A (2021). Difference-in-differences with variation in
#'   treatment timing. Journal of Econometrics 225(2):254-277.
#'   \doi{10.1016/j.jeconom.2021.03.014}
#' @seealso \code{\link{did_panel}}, \code{\link{staggered_att}}.
#' @examples
#' p <- policy_example()
#' b <- bacon_decomposition(p, "district", "month", "crime_rate", "reformed")
#' b
#' tapply(b$weight, b$type, sum)
#' @export
bacon_decomposition <- function(data, unit, time, outcome, treated) {
  p <- .rmbl_panel(data, unit, time, outcome)
  v <- .rmbl_colnames(treated, "treated")
  if (!v %in% names(data)) stop(sprintf("`treated` (%s) is not a column of `data`", v), call. = FALSE)
  d <- as.numeric(data[[v]])
  if (anyNA(d) || !all(d %in% c(0, 1))) stop("`treated` must be 0 or 1, with no NA", call. = FALSE)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel", call. = FALSE)
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  dm <- matrix(d[o], nu, nt, byrow = TRUE)
  if (any(t(apply(dm, 1L, diff)) < 0)) stop("treatment must stay on once it starts", call. = FALSE)
  first <- apply(dm, 1L, function(r) if (any(r == 1)) which(r == 1)[1L] else Inf)
  groups <- sort(unique(first))
  timing <- groups[is.finite(groups)]
  if (!length(timing)) stop("no unit is ever treated", call. = FALSE)
  dbar <- function(k) if (is.finite(k)) mean(seq_len(nt) >= k) else 0
  nsh <- function(k) mean(first == k)
  dd <- function(tr, co, win) {
    pre <- win[[1L]]
    post <- win[[2L]]
    yt <- ym[first == tr, , drop = FALSE]
    yc <- ym[first == co, , drop = FALSE]
    (mean(yt[, post]) - mean(yt[, pre])) - (mean(yc[, post]) - mean(yc[, pre]))
  }
  rows <- list()
  add <- function(type, tr, co, est, w) {
    rows[[length(rows) + 1L]] <<- data.frame(type = type, treated = tr, control = co, estimate = est, weight = w)
  }
  if (Inf %in% groups) {
    for (k in timing) {
      dk <- dbar(k)
      if (dk <= 0 || dk >= 1) next
      nk <- nsh(k)
      nkU <- nk / (nk + nsh(Inf))
      w <- (nk + nsh(Inf))^2 * nkU * (1 - nkU) * dk * (1 - dk)
      add("treated vs never", p$tl[k], Inf, dd(k, Inf, list(seq_len(k - 1L), k:nt)), w)
    }
  }
  for (k in timing) for (l in timing) {
    if (k >= l) next
    dk <- dbar(k)
    dl <- dbar(l)
    nk <- nsh(k)
    nl <- nsh(l)
    nkl <- nk / (nk + nl)
    if (k > 1L) {
      w1 <- ((nk + nl) * (1 - dl))^2 * nkl * (1 - nkl) * ((dk - dl) / (1 - dl)) * ((1 - dk) / (1 - dl))
      add("earlier vs later", p$tl[k], p$tl[l], dd(k, l, list(seq_len(k - 1L), k:(l - 1L))), w1)
    }
    w2 <- ((nk + nl) * dk)^2 * nkl * (1 - nkl) * (dl / dk) * ((dk - dl) / dk)
    add("later vs earlier", p$tl[l], p$tl[k], dd(l, k, list(k:(l - 1L), l:nt)), w2)
  }
  out <- do.call(rbind, rows)
  out$weight <- out$weight / sum(out$weight)
  attr(out, "twfe") <- sum(out$weight * out$estimate)
  class(out) <- c("rmbl_bacon", "data.frame")
  out
}

#' @export
print.rmbl_bacon <- function(x, ...) {
  cat(sprintf("Goodman-Bacon decomposition: two-way estimate %.4g\n", attr(x, "twfe")))
  s <- tapply(seq_len(nrow(x)), x$type, function(i) {
    c(sum(x$weight[i]), sum(x$weight[i] * x$estimate[i]) / sum(x$weight[i]))
  })
  for (nm in names(s)) cat(sprintf("  %-18s weight %.3f, average estimate %.4g\n", nm, s[[nm]][1L], s[[nm]][2L]))
  invisible(x)
}

# ---- switching treatments --------------------------------------------------------------------------

#' Difference in differences for treatments that switch on and off
#'
#' De Chaisemartin and D'Haultfoeuille's estimator of the effect at the moment units
#' switch: in every period, units that switch into treatment are compared with units
#' untreated in both periods, and units that switch out with units treated in both;
#' with the placebo that runs the same comparison one period earlier.
#'
#' @details For each period \eqn{t} with joiners (\eqn{D_{t-1} = 0, D_t = 1}) and
#' stayers untreated in both, \eqn{DID_{+,t}} is the joiners' mean change in the
#' outcome minus the stayers'; with leavers (1 to 0) and stayers treated in both,
#' \eqn{DID_{-,t}} is the stayers' change minus the leavers'. The estimate is
#' \deqn{DID_M = \sum_t \frac{N_{J,t}}{N_S} DID_{+,t} + \frac{N_{L,t}}{N_S}
#' DID_{-,t},}{DID_M = sum_t (N_J,t DID_+,t + N_L,t DID_-,t) / N_S,} over the
#' \eqn{N_S} switchers. The placebo compares, between \eqn{t - 2} and \eqn{t - 1}, the
#' change of the units that switch at \eqn{t} with that of the units whose treatment
#' did not change over \eqn{t - 2} to \eqn{t}; it should be near zero. Standard errors
#' come from the cluster bootstrap. Unlike the two-way estimator, \eqn{DID_M} never
#' uses a unit whose treatment changed as a control in the period it changed.
#'
#' @inheritParams did_panel
#' @inheritParams staggered_att
#' @return A data frame of class \code{rmbl_switching_did}, two rows (\code{effect},
#'   \code{placebo}): \code{estimate}, \code{se}, \code{lower}, \code{upper},
#'   \code{switchers}.
#' @references de Chaisemartin C, D'Haultfoeuille X (2020). Two-way fixed effects
#'   estimators with heterogeneous treatment effects. American Economic Review
#'   110(9):2964-2996. \doi{10.1257/aer.20181169}
#'
#' Applied as a placebo check on ward redistricting: Ternullo S, Zorro-Medina A,
#' Vargas R (2024). How political dynasties concentrate advantage within cities.
#' Social Forces 102(4):1310-1331. \doi{10.1093/sf/soae029}
#' @examples
#' p <- policy_example()
#' switching_did(p, "district", "month", "crime_rate", "reformed", reps = 99, seed = 1)
#' @export
switching_did <- function(data, unit, time, outcome, treated, cluster = NULL, reps = 499L, seed = NULL,
                          conf_level = 0.95) {
  conf_level <- .rmbl_conf_level(conf_level)
  reps <- .rmbl_scalar(reps, "reps", 0, 1e5, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, outcome)
  v <- .rmbl_colnames(treated, "treated")
  if (!v %in% names(data)) stop(sprintf("`treated` (%s) is not a column of `data`", v), call. = FALSE)
  d <- as.numeric(data[[v]])
  if (anyNA(d) || !all(d %in% c(0, 1))) stop("`treated` must be 0 or 1, with no NA", call. = FALSE)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel", call. = FALSE)
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  dm <- matrix(d[o], nu, nt, byrow = TRUE)
  clu <- if (is.null(cluster)) seq_len(nu) else .rmbl_cluster(data, cluster, p)[o][seq(1L, by = nt, length.out = nu)]
  est <- function(idx) {
    y <- ym[idx, , drop = FALSE]
    dd <- dm[idx, , drop = FALSE]
    num <- 0
    ns <- 0
    pnum <- 0
    pns <- 0
    for (j in 2:nt) {
      dy <- y[, j] - y[, j - 1L]
      jn <- dd[, j - 1L] == 0 & dd[, j] == 1
      s0 <- dd[, j - 1L] == 0 & dd[, j] == 0
      lv <- dd[, j - 1L] == 1 & dd[, j] == 0
      s1 <- dd[, j - 1L] == 1 & dd[, j] == 1
      if (any(jn) && any(s0)) {
        num <- num + sum(jn) * (mean(dy[jn]) - mean(dy[s0]))
        ns <- ns + sum(jn)
      }
      if (any(lv) && any(s1)) {
        num <- num + sum(lv) * (mean(dy[s1]) - mean(dy[lv]))
        ns <- ns + sum(lv)
      }
      if (j >= 3L) {
        dp <- y[, j - 1L] - y[, j - 2L]
        pj <- jn & dd[, j - 2L] == 0
        ps <- s0 & dd[, j - 2L] == 0
        pl <- lv & dd[, j - 2L] == 1
        p1 <- s1 & dd[, j - 2L] == 1
        if (any(pj) && any(ps)) {
          pnum <- pnum + sum(pj) * (mean(dp[pj]) - mean(dp[ps]))
          pns <- pns + sum(pj)
        }
        if (any(pl) && any(p1)) {
          pnum <- pnum + sum(pl) * (mean(dp[p1]) - mean(dp[pl]))
          pns <- pns + sum(pl)
        }
      }
    }
    c(if (ns > 0) num / ns else NA_real_, if (pns > 0) pnum / pns else NA_real_, ns, pns)
  }
  e0 <- est(seq_len(nu))
  if (!is.finite(e0[1L])) stop("no unit switches treatment against a unit that did not", call. = FALSE)
  se <- c(NA_real_, NA_real_)
  if (reps > 0L) {
    ucl <- unique(clu)
    b <- .rmbl_with_seed(seed, vapply(seq_len(reps), function(r) {
      pick <- sample(ucl, length(ucl), replace = TRUE)
      est(unlist(lapply(pick, function(cc) which(clu == cc)), use.names = FALSE))[1:2]
    }, numeric(2L)))
    se <- apply(b, 1L, stats::sd, na.rm = TRUE)
  }
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  out <- data.frame(term = c("effect", "placebo"), estimate = e0[1:2], se = se, lower = e0[1:2] - z * se,
                    upper = e0[1:2] + z * se, switchers = e0[3:4], stringsAsFactors = FALSE)
  class(out) <- c("rmbl_switching_did", "data.frame")
  out
}

# ---- permutation inference and stepdown ------------------------------------------------------------

#' Permutation inference for a policy's adoption
#'
#' Re-assigns the adoption dates across clusters (all the distinct assignments when
#' there are few, random ones otherwise), re-estimates the difference in differences
#' each time, and gives the share of assignments with an effect at least as large; for
#' several outcomes, also the Westfall-Young stepdown p-values that hold the
#' family-wise error rate.
#'
#' @details The adoption period of each cluster (for example a judicial district's
#' stage of a reform) is shuffled among the clusters, keeping the number of clusters
#' adopting at each date, and \code{\link{did_panel}}'s estimate
#' (\code{statistic = "estimate"}) or t statistic (\code{"t"}, the default) is
#' recomputed. With \eqn{b} of \eqn{R} random assignments at least as extreme as
#' observed, \eqn{p = (b + 1)/(R + 1)}; when every distinct assignment is enumerated
#' (their number is at most \code{reps}), \eqn{p} is the exact share. The test is
#' Fisher's: it is valid in any sample when adoption dates were assigned at random
#' across clusters.
#'
#' For several outcomes, the same assignments give \code{\link{stepdown_pvalues}}.
#'
#' A placebo date is the same analysis with \code{first_treated} moved earlier, on the
#' periods before the real adoption.
#'
#' @inheritParams event_study
#' @param unit,time Column names: the unit and the period (numeric).
#' @param outcome One outcome column, or several.
#' @param statistic \code{"t"} (default) or \code{"estimate"}.
#' @param reps The number of random assignments (default 999).
#' @param seed Optional seed.
#' @param ties \code{"count"} (default): an assignment whose statistic equals the
#'   observed one counts (the observed assignment is among those enumerated, so the
#'   exact p-value is at least \eqn{1/N}); \code{"strict"}: only larger ones count.
#' @return A data frame of class \code{rmbl_permutation}, one row per outcome:
#'   \code{outcome}, \code{estimate}, \code{statistic}, \code{p_value},
#'   \code{p_stepdown}, \code{assignments}, \code{exact}; attribute \code{null} (the
#'   matrix of permuted statistics).
#' @references Fisher RA (1935). The Design of Experiments. Oliver and Boyd,
#'   Edinburgh.
#'
#' Applied with the four stages of a reform permuted across districts: Acosta, Mejia
#' and Zorro Medina (2023), see \code{\link{did_panel}}.
#' @seealso \code{\link{stepdown_pvalues}}.
#' @examples
#' p <- policy_example()
#' permutation_inference(p, "district", "month", c("crime_rate", "arrest_rate"),
#'                       "reform_month",
#'                       cluster = "region", reps = 199, seed = 3)
#' @export
permutation_inference <- function(data, unit, time, outcome, first_treated, cluster = NULL,
                                  statistic = c("t", "estimate"), reps = 999L, seed = NULL,
                                  ties = c("count", "strict")) {
  statistic <- .rmbl_arg(statistic)
  ties <- .rmbl_arg(ties)
  reps <- .rmbl_scalar(reps, "reps", 9, 1e6, integer = TRUE)
  outcome <- .rmbl_colnames(outcome, "outcome", several = TRUE)
  p <- .rmbl_panel(data, unit, time, outcome[1L])
  g <- .rmbl_first_treated(data, first_treated, p)
  cl <- .rmbl_cluster(data, cluster, p)
  gc <- tapply(g, cl, function(z) z[1L])
  if (any(tapply(g, cl, function(z) length(unique(z))) > 1L)) {
    stop("`first_treated` must be the same for every unit of a cluster", call. = FALSE)
  }
  stat <- function(gvec, oc) {
    dd <- data
    dd$.rmbl_d <- as.numeric(dd[[time]] >= gvec[cl])
    if (length(unique(dd$.rmbl_d)) < 2L) return(NA_real_)
    r <- tryCatch(did_panel(dd, unit, time, oc, ".rmbl_d", cluster = cluster), error = function(e) NULL)
    if (is.null(r)) NA_real_ else if (statistic == "t") r$t[1L] else r$estimate[1L]
  }
  obs <- vapply(outcome, function(oc) stat(gc, oc), numeric(1L))
  est <- vapply(outcome, function(oc) {
    dd <- data
    dd$.rmbl_d <- as.numeric(dd[[time]] >= g)
    did_panel(dd, unit, time, oc, ".rmbl_d", cluster = cluster)$estimate[1L]
  }, numeric(1L))
  tab <- table(gc)
  n_assign <- exp(lfactorial(length(gc)) - sum(lfactorial(tab)))
  exact <- n_assign <= reps
  perms <- if (exact) .rmbl_multiset_perms(as.vector(gc)) else
    .rmbl_with_seed(seed, t(vapply(seq_len(reps), function(r) sample(as.vector(gc)), numeric(length(gc)))))
  null <- matrix(NA_real_, nrow(perms), length(outcome), dimnames = list(NULL, outcome))
  for (r in seq_len(nrow(perms))) for (j in seq_along(outcome)) null[r, j] <- stat(perms[r, ], outcome[j])
  pv <- vapply(seq_along(outcome), function(j) {
    nz <- null[, j][is.finite(null[, j])]
    b <- if (ties == "count") sum(abs(nz) >= abs(obs[j]) - 1e-12) else sum(abs(nz) > abs(obs[j]) + 1e-12)
    if (exact) b / length(nz) else (b + 1) / (length(nz) + 1)
  }, numeric(1L))
  out <- data.frame(outcome = outcome, estimate = unname(est), statistic = unname(obs), p_value = pv,
                    p_stepdown = if (length(outcome) > 1L) stepdown_pvalues(obs, null) else pv,
                    assignments = nrow(perms), exact = exact, stringsAsFactors = FALSE)
  attr(out, "null") <- null
  class(out) <- c("rmbl_permutation", "data.frame")
  out
}

.rmbl_multiset_perms <- function(v) {
  if (length(v) <= 1L) return(matrix(v, 1L))
  u <- unique(v)
  do.call(rbind, lapply(u, function(a) {
    rest <- v[-match(a, v)]
    cbind(a, .rmbl_multiset_perms(rest))
  }))
}

#' Westfall-Young stepdown p-values
#'
#' Adjusted p-values for several hypotheses tested together, from the joint null
#' distribution of their statistics (permutations or bootstrap draws), holding the
#' family-wise error rate while using the correlation between the tests.
#'
#' @details The statistics are ordered by size,
#' \eqn{|t_{(1)}| \ge \dots \ge |t_{(K)}|}. For each null draw \eqn{b},
#' \eqn{q_{b,j} = \max_{r \ge j} |t^*_{b,(r)}|}. The adjusted p-value of the \eqn{j}th
#' is the share of draws with \eqn{q_{b,j} \ge |t_{(j)}|}, made monotone:
#' \eqn{\tilde p_{(j)} = \max(\tilde p_{(j-1)}, p_{(j)})} (Westfall and Young 1993,
#' algorithm 2.8).
#'
#' @param observed The observed statistics, one per hypothesis.
#' @param null A matrix of statistics under the null: one row per draw, one column per
#'   hypothesis.
#' @return The adjusted p-values, in the order of \code{observed}.
#' @references Westfall PH, Young SS (1993). Resampling-Based Multiple Testing. Wiley,
#' New York.
#' @seealso \code{\link{permutation_inference}}.
#' @examples
#' set.seed(1)
#' null <- matrix(rnorm(3000), ncol = 3)
#' stepdown_pvalues(c(2.5, 0.4, -2.1), null)
#' @export
stepdown_pvalues <- function(observed, null) {
  observed <- .rmbl_num(observed, "observed")
  if (!is.matrix(null) || !is.numeric(null) || ncol(null) != length(observed)) {
    stop("`null` must be a numeric matrix with one column per observed statistic", call. = FALSE)
  }
  if (anyNA(observed)) stop("`observed` must have no NA", call. = FALSE)
  null <- null[stats::complete.cases(null), , drop = FALSE]
  if (!nrow(null)) stop("`null` has no complete draw", call. = FALSE)
  o <- order(-abs(observed))
  a <- abs(null[, o, drop = FALSE])
  k <- length(o)
  q <- a
  if (k > 1L) for (j in (k - 1L):1L) q[, j] <- pmax(q[, j], q[, j + 1L])
  p <- colMeans(sweep(q, 2L, abs(observed[o]) - 1e-12, `>=`))
  p <- cummax(p)
  out <- numeric(k)
  out[o] <- p
  out
}

# ---- fixed-effects Poisson -------------------------------------------------------------------------

#' A fixed-effects Poisson or negative binomial regression for counts
#'
#' The effect of a policy on counts (stops, arrests, offences) with unit and period
#' fixed effects, reported as an incidence rate ratio, with cluster-robust standard
#' errors that do not need the counts to be Poisson.
#'
#' @details The model is
#' \eqn{E(Y_{it}) = \exp(\beta T_{it} + X_{it}'\gamma + \delta_i + \mu_t)} (times the
#' exposure, with \code{offset} its log), fitted by maximum likelihood. Units whose
#' counts are all zero carry no information about \eqn{\beta} and are dropped first,
#' as are periods with no count anywhere. The Poisson likelihood with fixed effects is
#' consistent for \eqn{\beta} whatever the dispersion (Wooldridge 1999); the variance
#' is the cluster-robust sandwich, with the small-sample factors of
#' \code{\link{did_panel}}. The rate ratio is \eqn{e^{\beta}}, with interval
#' \eqn{e^{\hat\beta \pm z\,se}}.
#'
#' With \code{family = "negbin"} the variance is \eqn{\mu + \mu^2/\theta}: the fit
#' alternates iteratively reweighted least squares at fixed \eqn{\theta} with the
#' maximum of the profile likelihood in \eqn{\theta}, and the sandwich uses the
#' negative binomial scores with \eqn{\theta} held at its estimate (as
#' \code{sandwich::vcovCL()} does for \code{MASS::glm.nb()};
#' \code{fixest::fenegbin()}, which treats \eqn{\theta} as a parameter of the variance
#' too, gives slightly larger errors). With unit dummies this is the unconditional
#' fixed-effects negative binomial, which behaves well as the number of periods grows
#' (Allison and Waterman 2002); with few periods per unit prefer the Poisson, which is
#' consistent whatever the dispersion.
#'
#' @inheritParams did_panel
#' @param offset Optional column name of the log exposure (for example log
#'   population).
#' @param family \code{"poisson"} (default) or \code{"negbin"} (NB2,
#'   \eqn{Var(Y) = \mu + \mu^2/\theta}, with \eqn{\theta} by maximum likelihood).
#' @return A data frame of class \code{rmbl_fe_poisson}, one row per term:
#'   \code{term}, \code{estimate} (log scale), \code{se}, \code{rate_ratio},
#'   \code{lower}, \code{upper} (of the rate ratio), \code{p_value}; attributes
#'   \code{n}, \code{dropped_units}, \code{clusters}, \code{family}, \code{theta}
#'   (\code{Inf} for the Poisson).
#' @references Wooldridge JM (1999). Distribution-free estimation of some nonlinear
#' panel data models. Journal of Econometrics 90(1):77-97.
#' \href{https://doi.org/10.1016/S0304-4076(98)00033-5}{doi:10.1016/S0304-4076(98)00033-5}
#'
#' Santos Silva JMC, Tenreyro S (2006). The log of gravity. Review of Economics and
#' Statistics 88(4):641-658. \doi{10.1162/rest.88.4.641}
#'
#' Allison PD, Waterman RP (2002). Fixed-effects negative binomial regression models.
#' Sociological Methodology 32:247-265. \href{https://doi.org/10.1111/1467-9531.00117}{doi:10.1111/1467-9531.00117}
#' @examples
#' p <- policy_example()
#' fe_poisson(p, "district", "month", "crimes", "reformed", offset = "log_population")
#' fe_poisson(p, "district", "month", "crimes", "reformed", offset = "log_population",
#'            family = "negbin")
#' @export
fe_poisson <- function(data, unit, time, outcome, treated, covariates = NULL, offset = NULL, cluster = NULL,
                       family = c("poisson", "negbin"), conf_level = 0.95) {
  family <- .rmbl_arg(family)
  conf_level <- .rmbl_conf_level(conf_level)
  p <- .rmbl_panel(data, unit, time, outcome)
  if (any(p$y < 0)) stop("`outcome` must be counts (0 or more)", call. = FALSE)
  v <- .rmbl_colnames(treated, "treated")
  if (!v %in% names(data)) stop(sprintf("`treated` (%s) is not a column of `data`", v), call. = FALSE)
  d <- data[[v]]
  if (is.logical(d)) d <- as.numeric(d)
  if (!is.numeric(d) || anyNA(d)) stop("`treated` must be numeric with no NA", call. = FALSE)
  off <- if (is.null(offset)) rep(0, length(p$y)) else .rmbl_num(data[[.rmbl_colnames(offset, "offset")]], "offset")
  cl <- .rmbl_cluster(data, cluster, p)
  x <- cbind(treated = d, .rmbl_covariates(data, covariates))
  keep <- (tapply(p$y, p$u, sum) > 0)[p$u] & (tapply(p$y, p$t, sum) > 0)[as.character(p$t)]
  dropped <- length(unique(p$u)) - length(unique(p$u[keep]))
  y <- p$y[keep]
  fu <- factor(p$u[keep])
  ft <- factor(p$t[keep])
  xx <- x[keep, , drop = FALSE]
  X <- cbind(xx, stats::model.matrix(~ fu + ft))
  fit <- stats::glm.fit(X, y, family = stats::poisson(), offset = off[keep])
  theta <- Inf
  if (family == "negbin") {
    # NB2: Var(Y) = mu + mu^2 / theta. Alternate the IRLS fit at fixed theta with the maximum of the
    # profile likelihood in theta, to convergence
    ll <- function(lt, mu) {
      th <- exp(lt)
      sum(lgamma(y + th) - lgamma(th) - lgamma(y + 1) + th * log(th / (th + mu)) + y * log(mu / (th + mu)))
    }
    for (it in 1:100) {
      th_new <- exp(stats::optimize(ll, c(-10, 15), mu = fit$fitted.values, maximum = TRUE)$maximum)
      fit <- stats::glm.fit(X, y, family = .rmbl_negbin_family(th_new), offset = off[keep],
                            start = fit$coefficients)
      done <- abs(log(th_new) - log(theta)) < 1e-8
      theta <- th_new
      if (done) break
    }
    if (theta > exp(14)) warning("no overdispersion: theta is at its bound, the Poisson model fits", call. = FALSE)
  }
  if (!fit$converged) warning("the count model did not converge", call. = FALSE)
  ok <- !is.na(fit$coefficients)
  if (!all(ok[seq_len(ncol(xx))])) stop("a regressor is collinear with the fixed effects", call. = FALSE)
  X <- X[, ok, drop = FALSE]
  mu <- fit$fitted.values
  wt <- if (is.finite(theta)) mu * theta / (theta + mu) else mu
  bread <- solve(crossprod(X * sqrt(wt)))
  s <- rowsum(X * ((y - mu) * wt / mu), cl[keep])
  gn <- nrow(s)
  ny <- length(y)
  kk <- ncol(xx) + .rmbl_k_fe(list(as.integer(fu), as.integer(ft)), cl[keep])
  vc <- bread %*% crossprod(s) %*% bread * gn / (gn - 1) * (ny - 1) / (ny - kk)
  k <- seq_len(ncol(xx))
  b <- fit$coefficients[k]
  se <- sqrt(diag(vc))[k]
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  out <- data.frame(term = colnames(x), estimate = unname(b), se = unname(se), rate_ratio = exp(unname(b)),
                    lower = exp(unname(b - z * se)), upper = exp(unname(b + z * se)),
                    p_value = 2 * stats::pnorm(-abs(unname(b / se))), stringsAsFactors = FALSE)
  attr(out, "n") <- length(y)
  attr(out, "dropped_units") <- dropped
  attr(out, "clusters") <- gn
  attr(out, "family") <- family
  attr(out, "theta") <- theta
  class(out) <- c("rmbl_fe_poisson", "data.frame")
  out
}

# The negative binomial (NB2) family at a fixed theta, for glm.fit: base R, no MASS
.rmbl_negbin_family <- function(theta) {
  f <- stats::poisson()
  f$family <- sprintf("Negative Binomial(%.4g)", theta)
  f$variance <- function(mu) mu + mu^2 / theta
  f$dev.resids <- function(y, mu, wt) {
    2 * wt * (y * log(pmax(1, y) / mu) - (y + theta) * log((y + theta) / (mu + theta)))
  }
  f$aic <- function(y, n, mu, wt, dev) {
    -2 * sum(wt * (lgamma(y + theta) - lgamma(theta) - lgamma(y + 1) + theta * log(theta / (theta + mu)) +
                     y * log(mu / (theta + mu))))
  }
  f
}

# ---- synthetic control -----------------------------------------------------------------------------

#' Synthetic control for one treated unit
#'
#' A weighted average of untreated units that tracks the treated unit before the
#' policy, as its counterfactual after; with the placebo test that runs the same
#' method on every untreated unit.
#'
#' @details The weights solve
#' \deqn{\min_w \sum_{t < T_0} \Big(Y_{1t} - \sum_j w_j Y_{jt}\Big)^2 \quad
#' \textrm{s.t.} \quad w_j \ge 0,\ \sum_j w_j = 1,}{min_w sum_(t < T0) (Y_1t - sum_j
#' w_j Y_jt)^2, w_j >= 0, sum_j w_j = 1,} over the periods before adoption \eqn{T_0}
#' (accelerated projected gradient onto the simplex; the problem is convex, so the
#' solution is the global one). The effect in each period is the gap
#' \eqn{Y_{1t} - \sum_j w_j Y_{jt}}. For inference, each untreated unit in turn is
#' treated as if it had adopted the policy, with the other untreated units as donors;
#' the ratio of root mean squared gap after to before adoption ranks the real unit
#' among the placebos, and \eqn{p} is its rank over the number of units (Abadie,
#' Diamond and Hainmueller 2010).
#'
#' This version matches on the pre-period outcomes only, not on separate predictors.
#'
#' @inheritParams did_panel
#' @param treated_unit The treated unit (a value of \code{unit}).
#' @param adoption The first treated period.
#' @param placebo Run the placebo test (default \code{TRUE}).
#' @return A list of class \code{rmbl_synth}: \code{weights} (a named vector over the
#'   donors), \code{path} (a data frame: \code{time}, \code{treated},
#'   \code{synthetic}, \code{gap}), \code{rmspe_pre}, \code{rmspe_ratio},
#'   \code{p_value} (\code{NA} without the placebo), \code{placebo_ratios}.
#'   \code{plot()} draws the two paths and the gap.
#' @references Abadie A, Diamond A, Hainmueller J (2010). Synthetic control methods
#'   for comparative case studies. Journal of the American Statistical Association
#'   105(490):493-505. \doi{10.1198/jasa.2009.ap08746}
#' @examples
#' p <- policy_example()
#' p1 <- p[is.na(p$reform_month) | p$district == "D01", ]
#' s <- synthetic_control(p1, "district", "month", "crime_rate", treated_unit = "D01",
#'                        adoption = 13)
#' round(s$weights, 3)
#' s$p_value
#' plot(s)
#' @export
synthetic_control <- function(data, unit, time, outcome, treated_unit, adoption, placebo = TRUE) {
  p <- .rmbl_panel(data, unit, time, outcome)
  adoption <- .rmbl_scalar(adoption, "adoption")
  if (!is.logical(placebo) || length(placebo) != 1L || is.na(placebo)) {
    stop("`placebo` must be TRUE or FALSE", call. = FALSE)
  }
  tu <- as.character(treated_unit)
  if (length(tu) != 1L || !tu %in% p$ul) stop("`treated_unit` is not a unit of `data`", call. = FALSE)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel", call. = FALSE)
  if (nu < 3L) stop("synthetic control needs two donor units at least", call. = FALSE)
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE, dimnames = list(p$ul, p$tl))
  pre <- p$tl < adoption
  if (sum(pre) < 2L || all(pre)) stop("`adoption` must leave two periods before it and one after", call. = FALSE)
  fit1 <- function(i, donors) {
    w <- .rmbl_simplex_ls(t(ym[donors, pre, drop = FALSE]), ym[i, pre])
    synth <- as.vector(crossprod(w, ym[donors, , drop = FALSE]))
    gap <- ym[i, ] - synth
    list(w = stats::setNames(w, p$ul[donors]), synth = synth, gap = gap,
         pre = sqrt(mean(gap[pre]^2)), post = sqrt(mean(gap[!pre]^2)))
  }
  it <- match(tu, p$ul)
  donors <- setdiff(seq_len(nu), it)
  f <- fit1(it, donors)
  ratio <- f$post / f$pre
  pr <- NA_real_
  pv <- NA_real_
  if (placebo) {
    pr <- vapply(donors, function(j) {
      fj <- fit1(j, setdiff(donors, j))
      fj$post / fj$pre
    }, numeric(1L))
    names(pr) <- p$ul[donors]
    pv <- (1 + sum(pr >= ratio - 1e-12)) / (1 + length(pr))
  }
  out <- list(weights = f$w, path = data.frame(time = p$tl, treated = ym[it, ], synthetic = f$synth, gap = f$gap,
                                               row.names = NULL),
              rmspe_pre = f$pre, rmspe_ratio = ratio, p_value = pv, placebo_ratios = pr, adoption = adoption,
              treated_unit = tu)
  class(out) <- "rmbl_synth"
  out
}

# min ||A w - b||^2 over the simplex: FISTA with the exact Euclidean projection (Duchi et al. 2008)
.rmbl_simplex_ls <- function(A, b, maxit = 20000L, tol = 1e-12) {
  proj <- function(v) {
    u <- sort(v, decreasing = TRUE)
    cs <- cumsum(u)
    rho <- max(which(u - (cs - 1) / seq_along(u) > 0))
    pmax(v - (cs[rho] - 1) / rho, 0)
  }
  k <- ncol(A)
  ata <- crossprod(A)
  atb <- crossprod(A, b)
  lip <- max(eigen(ata, symmetric = TRUE, only.values = TRUE)$values, 1e-12)
  w <- rep(1 / k, k)
  z <- w
  s <- 1
  for (i in seq_len(maxit)) {
    wn <- proj(as.vector(z - (ata %*% z - atb) / lip))
    sn <- (1 + sqrt(1 + 4 * s^2)) / 2
    z <- wn + ((s - 1) / sn) * (wn - w)
    if (max(abs(wn - w)) < tol) {
      w <- wn
      break
    }
    w <- wn
    s <- sn
  }
  # polish: the exact least squares on the support with the sum constraint (the KKT system), kept when
  # it stays inside the simplex
  sup <- which(w > 1e-8)
  m <- rbind(cbind(2 * ata[sup, sup, drop = FALSE], 1), c(rep(1, length(sup)), 0))
  sol <- tryCatch(solve(m, c(2 * atb[sup], 1)), error = function(e) NULL)
  if (!is.null(sol) && all(sol[seq_along(sup)] > 0)) {
    w[] <- 0
    w[sup] <- sol[seq_along(sup)]
  }
  w
}

#' @export
print.rmbl_synth <- function(x, ...) {
  cat(sprintf("Synthetic control for %s, adoption at %s\n", x$treated_unit, format(x$adoption)))
  w <- sort(x$weights[x$weights > 1e-4], decreasing = TRUE)
  cat("Donor weights:", paste(sprintf("%s %.3f", names(w), w), collapse = ", "), "\n")
  post <- x$path$gap[x$path$time >= x$adoption]
  cat(sprintf("Pre-period RMSPE %.4g; mean gap after adoption %.4g; post/pre RMSPE ratio %.3g\n",
              x$rmspe_pre, mean(post), x$rmspe_ratio))
  if (is.finite(x$p_value)) cat(sprintf("Placebo-in-space p = %.3g (%d placebos)\n", x$p_value,
                                        length(x$placebo_ratios)))
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_synth <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_synth")
  d <- x$path
  cl <- .bl_cols(2L, col, palette)
  graphics::matplot(d$time, cbind(d$treated, d$synthetic), type = "l", lty = c(1, 2), col = cl, lwd = 2,
                    xlab = "Period", ylab = "Outcome",
                    main = .bl_main(main, paste("Synthetic control:", x$treated_unit)), ...)
  graphics::abline(v = x$adoption, lty = 3, col = "#9A9A9A")
  graphics::legend("topleft", c(x$treated_unit, "Synthetic"), lty = c(1, 2), col = cl, lwd = 2, bty = "n")
  invisible(d)
}

# ---- measures --------------------------------------------------------------------------------------

#' A severity-weighted crime index
#'
#' Offence rates combined into one index, unweighted (the sum of rates) and weighted
#' by each offence's severity (for example its mean statutory sentence), per unit and
#' period.
#'
#' @details With \eqn{r_{k}} the rate of offence \eqn{k} per \code{per} residents and
#' \eqn{w_k} its weight, the indices are \eqn{\sum_k r_k} and \eqn{\sum_k w_k r_k}.
#' Mean statutory sentence lengths are one choice of weight (as in Acosta, Mejia and
#' Zorro Medina 2023); sentencing guidelines are another (the Cambridge Crime Harm
#' Index, Sherman, Neyroud and Neyroud 2016). The weights are the analyst's to state
#' and defend: the index records them. A unit-period missing an offence that has a
#' weight gets \code{NA}, never a partial sum.
#'
#' @param data A data frame, one row per unit, period and offence.
#' @param unit,time,offence,count Column names.
#' @param weights Named weights, one per offence counted.
#' @param population Optional column name of the population; without it \code{count}
#'   is taken as a rate already.
#' @param per Rate base (default 100000).
#' @return A data frame of class \code{rmbl_severity}: \code{unit}, \code{time},
#'   \code{unweighted}, \code{weighted}; attribute \code{weights}.
#' @references Sherman L, Neyroud PW, Neyroud E (2016). The Cambridge Crime Harm
#' Index: measuring total harm from crime based on sentencing guidelines. Policing
#' 10(3):171-183. \doi{10.1093/police/paw003}
#'
#' Applied with weights from the Colombian Penal Code: Acosta, Mejia and Zorro Medina
#' (2023), see \code{\link{did_panel}}.
#' @examples
#' d <- data.frame(city = rep(c("A", "B"), each = 3), year = 2024,
#'                 offence = rep(c("homicide", "robbery", "burglary"), 2),
#'                 n = c(5, 120, 300, 2, 90, 410), pop = rep(c(250000, 180000), each
#' = 3))
#' severity_index(d, "city", "year", "offence", "n",
#'                weights = c(homicide = 25, robbery = 8,
#'                            burglary = 4), population = "pop")
#' @export
severity_index <- function(data, unit, time, offence, count, weights, population = NULL, per = 1e5) {
  .rmbl_df_names(data)
  for (nm in c("unit", "time", "offence", "count")) {
    v <- .rmbl_colnames(get(nm), nm)
    if (!v %in% names(data)) stop(sprintf("`%s` (%s) is not a column of `data`", nm, v), call. = FALSE)
  }
  if (!is.numeric(weights) || is.null(names(weights)) || anyNA(weights) || any(!nzchar(names(weights)))) {
    stop("`weights` must be numbers named by offence", call. = FALSE)
  }
  per <- .rmbl_scalar(per, "per", 1e-12)
  off <- trimws(as.character(data[[offence]]))
  miss <- setdiff(names(weights), off)
  if (length(miss)) stop(sprintf("not an offence of `data`: %s", paste(miss, collapse = ", ")), call. = FALSE)
  r <- .rmbl_num(data[[count]], "count")
  if (!is.null(population)) r <- r / .rmbl_num(data[[.rmbl_colnames(population, "population")]], "population") * per
  use <- off %in% names(weights)
  key <- paste(data[[unit]], data[[time]], sep = "\r")
  if (anyDuplicated(paste(key, off)[use])) stop("an offence appears twice for a unit and period", call. = FALSE)
  keys <- unique(key)
  agg <- function(v) {
    s <- tapply(v[use], factor(key[use], levels = keys), function(z) if (anyNA(z)) NA_real_ else sum(z))
    n <- tapply(use[use], factor(key[use], levels = keys), length)
    s[is.na(n) | n < length(weights)] <- NA_real_
    as.vector(s)
  }
  first <- match(keys, key)
  out <- data.frame(unit = data[[unit]][first], time = data[[time]][first], unweighted = agg(r),
                    weighted = agg(r * unname(weights[off])), stringsAsFactors = FALSE)
  attr(out, "weights") <- weights
  class(out) <- c("rmbl_severity", "data.frame")
  out
}

#' Justice-pipeline rates with a lag between stages
#'
#' The rate at which one stage of the justice process follows another (charges per
#' reported offence, settlements per charge, convictions per trial), summing each over
#' a window and setting the outcome's window after the input's, because cases take
#' time to move through.
#'
#' @details For period \eqn{t}, a window of \eqn{W} periods and a lag of \eqn{L},
#' \deqn{R_t = \frac{\sum_{s = t - W + 1}^{t} O_s}{\sum_{s = t - L - W + 1}^{t - L}
#' I_s},}{R_t = sum(O over t - W + 1 .. t) / sum(I over t - L - W + 1 .. t - L),} with
#' \eqn{O} the outcome stage and \eqn{I} the input stage. With \eqn{W = 1, L = 0} it
#' is the same-period ratio (cases with detention over cases charged; acquittals over
#' acquittals and convictions). Rates are \code{NA} until the windows are filled, and
#' when the denominator is zero. These are administrative counts of every case, so no
#' sampling interval is given.
#'
#' @param numerator,denominator The outcome and input counts, in period order.
#' @param window The number of periods summed (default 12).
#' @param lag The number of periods the input's window precedes the outcome's (default
#' 0).
#' @param group Optional grouping (for example a court or municipality), the counts in
#'   period order within it.
#' @return A data frame: \code{group}, \code{index} (the period's position within its
#'   group), \code{numerator}, \code{denominator} (the window sums), \code{rate}.
#' @references Council of Europe, European Commission for the Efficiency of Justice
#'   (CEPEJ) (2014). European judicial systems: efficiency and quality of justice.
#'   CEPEJ Studies 20.
#'
#' Applied to the stages of a Colombian criminal-procedure reform: Acosta, Mejia and
#' Zorro Medina (2023), see \code{\link{did_panel}}.
#' @seealso \code{\link{case_flow}} for clearance rates and inventories.
#' @examples
#' set.seed(2)
#' reports <- rpois(36, 400)
#' charges <- rpois(36, 90)
#' pipeline_rate(charges, reports, window = 12, lag = 3)[30:36, ]
#' @export
pipeline_rate <- function(numerator, denominator, window = 12L, lag = 0L, group = NULL) {
  numerator <- .rmbl_num(numerator, "numerator")
  denominator <- .rmbl_num(denominator, "denominator")
  if (length(numerator) != length(denominator)) {
    stop("`numerator` and `denominator` must be the same length", call. = FALSE)
  }
  if (any(c(numerator, denominator) < 0, na.rm = TRUE)) stop("counts must not be negative", call. = FALSE)
  window <- .rmbl_scalar(window, "window", 1, 1e6, integer = TRUE)
  lag <- .rmbl_scalar(lag, "lag", 0, 1e6, integer = TRUE)
  if (is.null(group)) group <- rep("all", length(numerator))
  if (length(group) != length(numerator)) stop("`group` must be one per count", call. = FALSE)
  roll <- function(x, end) {
    vapply(end, function(e) if (e - window + 1L < 1L) NA_real_ else sum(x[(e - window + 1L):e]), numeric(1L))
  }
  out <- do.call(rbind, lapply(unique(group), function(gr) {
    i <- which(group == gr)
    n <- length(i)
    num <- roll(numerator[i], seq_len(n))
    den <- roll(denominator[i], seq_len(n) - lag)
    data.frame(group = gr, index = seq_len(n), numerator = num, denominator = den,
               rate = ifelse(is.finite(den) & den > 0, num / den, NA_real_), stringsAsFactors = FALSE)
  }))
  rownames(out) <- NULL
  out
}

#' Cumulative risk of a first event by age
#'
#' The chance that a person experiences an event (a first arrest, a first conviction,
#' a first jail stay, a first child protection placement) by each age, from first
#' events and the population by age, as a synthetic cohort; with mortality as a
#' competing risk when deaths are given.
#'
#' @details With \eqn{E_a} first events at age \eqn{a} and \eqn{N_a} persons at risk
#' (those who have not had the event), the hazard is \eqn{h_a = E_a/N_a}. When only
#' the population \eqn{P_a} is known, the persons at risk are taken as
#' \eqn{P_a(1 - CR_{a-1})} (the synthetic-cohort assumption). Without mortality,
#' \eqn{CR_a = 1 - \prod_{x \le a}(1 - h_x)}. With death rates \eqn{q_x}, the
#' multiple-decrement table carries survivors \eqn{l_{x+1} = l_x(1 - h_x - q_x)} and
#' \eqn{CR_a = \sum_{x \le a} l_x h_x / l_0}, the risk of the event before death. The
#' interval (without mortality) is Greenwood's on the log of the survival:
#' \eqn{\mathrm{Var}(\log S_a) = \sum_{x \le a} h_x/(N_x(1 - h_x))}.
#'
#' Counting first events needs records that link a person's events over time; an
#' agency's counts of all events overstate first events. Events of people who do not
#' live in the area, counted against its population, bias the risk upward.
#'
#' @param age The ages, in order.
#' @param first_events First events at each age.
#' @param population The population at each age.
#' @param at_risk Optional: the persons at risk at each age, when known, in place of
#'   the synthetic-cohort assumption.
#' @param death_rate Optional death rates by age (probability of dying within the
#'   age).
#' @param conf_level Confidence level (default 0.95).
#' @return A data frame: \code{age}, \code{hazard}, \code{at_risk},
#'   \code{cumulative_risk}, \code{lower}, \code{upper}.
#' @references Bonczar TP (2003). Prevalence of imprisonment in the U.S. population,
#'   1974-2001. Bureau of Justice Statistics, NCJ 197976.
#'
#' Applied to arrests, convictions and jail in New York City: Hepburn P,
#' Kohler-Hausmann I, Zorro Medina A (2019). Cumulative risks of multiple criminal
#' justice outcomes in New York City. Demography 56(3):1161-1171.
#' \href{https://doi.org/10.1007/s13524-019-00781-7}{doi:10.1007/s13524-019-00781-7}
#' @examples
#' age <- 16:25
#' first <- c(900, 1400, 1700, 1600, 1400, 1100, 900, 700, 600, 500)
#' pop <- rep(100000, 10)
#' cumulative_risk(age, first, pop)
#' @export
cumulative_risk <- function(age, first_events, population, at_risk = NULL, death_rate = NULL,
                            conf_level = 0.95) {
  age <- .rmbl_num(age, "age")
  e <- .rmbl_num(first_events, "first_events")
  pop <- .rmbl_num(population, "population")
  conf_level <- .rmbl_conf_level(conf_level)
  n <- length(age)
  if (length(e) != n || length(pop) != n) stop("`age`, `first_events` and `population` must match", call. = FALSE)
  if (anyNA(c(age, e, pop)) || any(e < 0) || any(pop <= 0)) {
    stop("counts must be 0 or more and populations above 0, with no NA", call. = FALSE)
  }
  if (is.unsorted(age, strictly = TRUE)) stop("`age` must be increasing", call. = FALSE)
  if (!is.null(at_risk)) {
    at_risk <- .rmbl_num(at_risk, "at_risk")
    if (length(at_risk) != n || any(at_risk <= 0)) stop("`at_risk` must be one per age, above 0", call. = FALSE)
  }
  if (!is.null(death_rate)) {
    death_rate <- .rmbl_num(death_rate, "death_rate")
    if (length(death_rate) != n || any(death_rate < 0 | death_rate >= 1)) {
      stop("`death_rate` must be one per age, from 0 to below 1", call. = FALSE)
    }
  }
  h <- nr <- cr <- v <- numeric(n)
  surv <- 1
  l <- 1
  acc <- 0
  vs <- 0
  for (i in seq_len(n)) {
    nr[i] <- if (is.null(at_risk)) pop[i] * (1 - (if (i > 1L) cr[i - 1L] else 0)) else at_risk[i]
    h[i] <- e[i] / nr[i]
    if (h[i] > 1) stop(sprintf("more first events than persons at risk at age %s", format(age[i])), call. = FALSE)
    if (is.null(death_rate)) {
      surv <- surv * (1 - h[i])
      cr[i] <- 1 - surv
      vs <- vs + if (h[i] < 1) h[i] / (nr[i] * (1 - h[i])) else Inf
      v[i] <- vs
    } else {
      acc <- acc + l * h[i]
      l <- l * (1 - h[i] - death_rate[i])
      if (l < 0) stop(sprintf("events and deaths exceed the cohort at age %s", format(age[i])), call. = FALSE)
      cr[i] <- acc
      v[i] <- NA_real_
    }
  }
  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  s <- 1 - cr
  data.frame(age = age, hazard = h, at_risk = nr, cumulative_risk = cr,
             lower = 1 - s * exp(z * sqrt(v)), upper = 1 - s * exp(-z * sqrt(v)))
}

#' Treated, comparison and excluded places around sites
#'
#' Assigns each place (a block, an address) to the treated group when it lies within a
#' radius of a site (a store that donated, a new facility), to the comparison group
#' when it lies within the same radius of a comparison point and farther than a buffer
#' from every site, and excludes it otherwise, so that spillover from the sites does
#' not reach the comparison.
#'
#' @details Distances are Euclidean, so coordinates must be projected (metres or feet,
#' not degrees). The radius and the buffer are in the same unit. The buffer should be
#' several times the radius: the design it follows used 330 feet and 990 feet.
#'
#' @param x,y Coordinates of the places.
#' @param site_x,site_y Coordinates of the sites.
#' @param comparison_x,comparison_y Coordinates of the comparison points (for example
#' the nearest major intersections).
#' @param radius The treatment radius.
#' @param buffer The distance from every site a comparison place must keep (default
#'   \code{3 * radius}).
#' @return A data frame: \code{group} (\code{"treated"}, \code{"comparison"} or
#'   \code{"excluded"}), \code{site_distance}, \code{comparison_distance}.
#' @references Applied to blocks near donor stores: Zorro Medina, Hackett, Green and
#'   Vargas (2025), see \code{\link{event_study}}.
#' @examples
#' set.seed(4)
#' x <- runif(200, 0, 5000)
#' y <- runif(200, 0, 5000)
#' a <- buffer_assign(x, y, c(1000, 3500), c(1200, 3000), c(2500, 4500), c(500, 4000),
#'                    radius = 330)
#' table(a$group)
#' @export
buffer_assign <- function(x, y, site_x, site_y, comparison_x, comparison_y, radius, buffer = 3 * radius) {
  x <- .rmbl_num(x, "x")
  y <- .rmbl_num(y, "y")
  sx <- .rmbl_num(site_x, "site_x")
  sy <- .rmbl_num(site_y, "site_y")
  cx <- .rmbl_num(comparison_x, "comparison_x")
  cy <- .rmbl_num(comparison_y, "comparison_y")
  if (length(x) != length(y) || length(sx) != length(sy) || length(cx) != length(cy)) {
    stop("each pair of coordinates must be the same length", call. = FALSE)
  }
  if (!length(sx) || !length(cx)) stop("give one site and one comparison point at least", call. = FALSE)
  if (anyNA(c(x, y, sx, sy, cx, cy))) stop("coordinates must have no NA", call. = FALSE)
  radius <- .rmbl_scalar(radius, "radius", 1e-12)
  buffer <- .rmbl_scalar(buffer, "buffer", 0)
  near <- function(px, py) vapply(seq_along(x), function(i) sqrt(min((px - x[i])^2 + (py - y[i])^2)), numeric(1L))
  ds <- near(sx, sy)
  dc <- near(cx, cy)
  grp <- ifelse(ds <= radius, "treated", ifelse(dc <= radius & ds > buffer, "comparison", "excluded"))
  data.frame(group = grp, site_distance = ds, comparison_distance = dc, stringsAsFactors = FALSE)
}

#' A simulated policy panel for the examples
#'
#' Twenty districts in four regions over 36 months; a reform adopted region by region
#' in three stages (months 13, 19 and 25), with the fourth region never adopting it;
#' crime and arrest rates and counts. The numbers are made up, with a known effect of
#' the reform (a fall of 3 in the crime rate per 100,000), so the examples and tests
#' can check that each estimator recovers it.
#'
#' @param seed The seed (default 20240101).
#' @return A data frame: \code{district}, \code{region}, \code{month},
#' \code{reform_month} (\code{NA} for never), \code{reformed} (0 or 1),
#' \code{population}, \code{log_population}, \code{crimes}, \code{crime_rate},
#' \code{arrest_rate}.
#' @examples
#' head(policy_example())
#' @export
policy_example <- function(seed = 20240101) {
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
    d$reform_month <- stage[d$i]
    d$reformed <- as.numeric(!is.na(d$reform_month) & d$month >= d$reform_month)
    d$population <- pop[d$i]
    d$log_population <- log(d$population)
    lam <- pmax(1, a[d$i] + m[d$month] + 0.05 * d$month - 3 * d$reformed)
    d$crimes <- stats::rpois(nrow(d), lam * d$population / 1e5)
    d$crime_rate <- round(lam + stats::rnorm(nrow(d), 0, 1), 3)
    d$arrest_rate <- round(0.4 * lam + 1.2 * d$reformed + stats::rnorm(nrow(d), 0, 0.8), 3)
    d[c("district", "region", "month", "reform_month", "reformed", "population", "log_population", "crimes",
        "crime_rate", "arrest_rate")]
  })
}
