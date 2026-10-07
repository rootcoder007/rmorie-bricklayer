# SPDX-License-Identifier: AGPL-3.0-or-later
# Air pollution and health: concentration-response functions, the
# attributable fraction, displaced mortality, the burden chain, a cross-fitted
# partially linear exposure-response estimator with a bootstrap, the
# concentration index of exposure by income, and a one-call pipeline with an
# assumption log. Every formula cites the paper it implements. The functions
# mirror rmorie's envhealth module (and morie's Python envhealth) formula for
# formula; see exposure_response_plr() for the one seam that differs.

.crf_object <- function(rr, log_rr, z, scalar, reference_conc, pollutant, citation, extra) {
  structure(list(
    rr = if (scalar) rr[[1L]] else mean(rr),
    log_rr = if (scalar) log_rr[[1L]] else mean(log_rr),
    reference_conc = reference_conc,
    exposure_conc = if (scalar) z[[1L]] else mean(z),
    pollutant = pollutant,
    citation = citation,
    extra = c(extra, list(rr_per_unit = if (scalar) NULL else rr))
  ), class = "rmbl_crf")
}

#' Concentration-response functions for PM2.5 and NO2
#'
#' \code{crf_pm25()} is log-linear for all-cause mortality with the pooled
#' cohort estimate of the WHO 2021 guideline review (Chen and Hoek 2020:
#' RR 1.08, 95\% CI 1.06-1.09, per 10 micrograms per cubic metre),
#' \deqn{RR(z) = \exp(\ln(1.08) (z - z_{cf}) / 10)}
#' for \eqn{z > z_{cf}} and 1 otherwise; for the cause-specific outcomes
#' (ischaemic heart disease, stroke) it is the Integrated Exposure-Response
#' curve of Burnett et al. (2014, equation 1),
#' \deqn{RR(z) = 1 + \alpha (1 - e^{-\gamma (z - z_{cf})^{\delta}}),}
#' with the GBD 2013 parameter triples; the IER was fitted per cause and has no
#' all-cause form. \code{crf_no2()} is the log-linear function of the WHO 2021
#' review (Huangfu and Atkinson 2020: RR 1.02, 95\% CI 1.01-1.04, per 10
#' micrograms per cubic metre for all-cause mortality),
#' \deqn{RR(z) = \exp(\beta (z - z_{cf}) / 10).}
#' A vector of exposures gives the mean RR and log-RR, with the per-unit
#' relative risks under \code{extra$rr_per_unit}.
#'
#' @param exposure Ambient concentration in micrograms per cubic metre, a
#'   scalar or a vector.
#' @param outcome PM2.5: \code{"all_cause_mortality"}, \code{"ihd"} or
#'   \code{"stroke"}. NO2: \code{"all_cause_mortality"}, \code{"respiratory"}
#'   or \code{"childhood_asthma"}.
#' @param reference_conc Counterfactual concentration below which no excess
#'   risk is assumed (PM2.5 default 5.8, NO2 default 10, the WHO 2021
#'   guideline values).
#' @param beta_per_10 Optional log-RR per 10 units overriding the NO2 outcome
#'   table.
#' @return A list of class \code{rmbl_crf} with \code{rr}, \code{log_rr},
#'   \code{reference_conc}, \code{exposure_conc}, \code{pollutant},
#'   \code{citation} and \code{extra}.
#' @references Chen, J. and Hoek, G. (2020). Long-term exposure to PM and
#'   all-cause and cause-specific mortality: a systematic review and
#'   meta-analysis. Environment International 143, 105974. Huangfu, P. and
#'   Atkinson, R. (2020). Long-term exposure to NO2 and O3 and all-cause and
#'   respiratory mortality: a systematic review and meta-analysis. Environment
#'   International 144, 105998. Burnett, R. T. et al. (2014). An integrated
#'   risk function for estimating the global burden of disease attributable to
#'   ambient fine particulate matter exposure. Environmental Health
#'   Perspectives 122(4), 397-403. WHO (2021). Global Air Quality Guidelines.
#' @examples
#' crf_pm25(12)$rr
#' crf_pm25(12, outcome = "ihd")$rr
#' crf_no2(25, outcome = "respiratory")$rr
#' crf_pm25(c(5, 12, 20))$extra$rr_per_unit
#' @export
crf_pm25 <- function(exposure, outcome = "all_cause_mortality", reference_conc = 5.8) {
  # all-cause: RR 1.08 (95% CI 1.06-1.09) per 10 ug/m3, Chen and Hoek (2020), the WHO 2021 review
  loglinear <- c(all_cause_mortality = log(1.08))
  # GBD 2013 cause-specific IER triples (alpha, gamma, delta), Burnett et al. (2014)
  ier <- list(ihd = c(1.91, 0.14, 0.49), stroke = c(1.46, 0.13, 0.61))
  if (!is.character(outcome) || length(outcome) != 1L ||
      !outcome %in% c(names(loglinear), names(ier))) {
    stop(sprintf("Unknown outcome '%s'. Available: %s", paste(outcome, collapse = ","),
                 paste(c(names(loglinear), names(ier)), collapse = ", ")), call. = FALSE)
  }
  z <- .pollution_exposure(exposure)
  scalar <- length(z) == 1L
  excess <- pmax(z - reference_conc, 0)
  if (outcome %in% names(loglinear)) {
    beta <- loglinear[[outcome]]
    log_rr <- beta * excess / 10
    return(.crf_object(exp(log_rr), log_rr, z, scalar, reference_conc, "PM2.5",
                       "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ Guidelines",
                       list(beta_per_10 = beta, form = "log-linear", outcome = outcome)))
  }
  p <- ier[[outcome]]
  rr <- 1 + p[1L] * (1 - exp(-p[2L] * excess^p[3L]))
  .crf_object(rr, log(rr), z, scalar, reference_conc, "PM2.5",
              "Burnett et al. (2014) EHP 122(4):397-403",
              list(alpha = p[1L], gamma = p[2L], delta = p[3L], form = "IER", outcome = outcome))
}

#' @rdname crf_pm25
#' @export
crf_no2 <- function(exposure, outcome = "all_cause_mortality", reference_conc = 10,
                    beta_per_10 = NULL) {
  # all-cause: RR 1.02 (95% CI 1.01-1.04) per 10 ug/m3, Huangfu and Atkinson (2020), the WHO 2021 review
  betas <- c(all_cause_mortality = log(1.02), respiratory = 0.029, childhood_asthma = 0.039)
  if (is.null(beta_per_10)) {
    if (!is.character(outcome) || length(outcome) != 1L || !outcome %in% names(betas)) {
      stop(sprintf("Unknown outcome '%s'. Available: %s or pass beta_per_10 explicitly.",
                   paste(outcome, collapse = ","), paste(names(betas), collapse = ", ")),
           call. = FALSE)
    }
    beta <- betas[[outcome]]
  } else {
    beta <- as.numeric(beta_per_10)
    if (length(beta) != 1L || !is.finite(beta)) {
      stop("`beta_per_10` must be a single finite number", call. = FALSE)
    }
  }
  z <- .pollution_exposure(exposure)
  scalar <- length(z) == 1L
  log_rr <- beta * pmax(z - reference_conc, 0) / 10
  .crf_object(exp(log_rr), log_rr, z, scalar, reference_conc, "NO2",
              "Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines",
              list(beta_per_10 = beta, outcome = outcome))
}

.pollution_exposure <- function(exposure) {
  z <- suppressWarnings(as.numeric(exposure))
  if (!length(z) || anyNA(z)) {
    stop("`exposure` must be one or more concentrations, with no missing values", call. = FALSE)
  }
  z
}

#' Population attributable fraction
#'
#' Levin's formula (Rothman, Greenland and Lash 2008, chapter 5):
#' \deqn{PAF = p (RR - 1) / (1 + p (RR - 1)),}
#' the fraction of cases that would be avoided if the exposure were removed.
#'
#' @param rr Relative risk at the observed exposure level.
#' @param exposure_prevalence Proportion of the population exposed, in
#'   \code{[0, 1]}.
#' @return A number in \code{[0, 1)} for \code{rr >= 1}.
#' @references Rothman, K. J., Greenland, S. and Lash, T. L. (2008). Modern
#'   Epidemiology, 3rd ed., chapter 5. Levin, M. L. (1953). The occurrence of
#'   lung cancer in man. Acta Unio Internationalis Contra Cancrum 9, 531-541.
#' @examples
#' attributable_fraction(1.5, 0.4)
#' attributable_fraction(2, 1)      # everyone exposed: 1 - 1/RR
#' @export
attributable_fraction <- function(rr, exposure_prevalence) {
  rr <- as.numeric(rr)
  p <- as.numeric(exposure_prevalence)
  if (length(rr) != 1L || length(p) != 1L) stop("`rr` and `exposure_prevalence` must be single numbers", call. = FALSE)
  if (is.na(p) || p < 0 || p > 1) {
    stop(sprintf("exposure_prevalence must be in [0,1]; got %s", format(p)), call. = FALSE)
  }
  num <- p * (rr - 1)
  den <- 1 + p * (rr - 1)
  if (den == 0) return(0)
  num / den
}

#' Deaths avoided under a counterfactual exposure reduction
#'
#' The BenMAP-CE health-impact function (US EPA 2018; Anenberg et al. 2010):
#' \deqn{\Delta Y = y_0 N (1 - e^{-\beta \Delta x}).}
#'
#' @param exposure_delta Counterfactual reduction in exposure (positive means
#'   the exposure goes down).
#' @param population At-risk population.
#' @param baseline_rate Baseline rate in cases per person-year.
#' @param beta_per_unit Log-RR per unit of exposure (per unit, not per 10).
#' @return Expected avoided cases.
#' @references US EPA (2018). Environmental Benefits Mapping and Analysis
#'   Program - Community Edition, user manual. Anenberg, S. C. et al. (2010).
#'   An estimate of the global burden of anthropogenic ozone and fine
#'   particulate matter on premature human mortality using atmospheric
#'   modeling. Environmental Health Perspectives 118(9), 1189-1195.
#' @examples
#' mortality_displaced(10, 1e6, 0.008, 0.0039)
#' @export
mortality_displaced <- function(exposure_delta, population, baseline_rate, beta_per_unit) {
  if (population < 0) stop("population must be non-negative", call. = FALSE)
  if (baseline_rate < 0) stop("baseline_rate must be non-negative", call. = FALSE)
  baseline_rate * population * (1 - exp(-beta_per_unit * exposure_delta))
}

#' End-to-end pollution burden
#'
#' Chains the concentration-response function, the attributable fraction and
#' the baseline case count into annual attributable cases, as the GBD risk
#' factor estimates do (GBD 2019 Risk Factors Collaborators 2020).
#'
#' @param exposure_mean Population-mean exposure (micrograms per cubic metre).
#' @param exposure_prevalence Proportion of the population at that level (1
#'   for ambient air).
#' @param baseline_rate Cases per person-year in the unexposed scenario.
#' @param population At-risk population.
#' @param pollutant \code{"PM2.5"} or \code{"NO2"}.
#' @param outcome Outcome key passed to the concentration-response function.
#' @param reference_conc Counterfactual concentration; \code{NULL} takes the
#'   pollutant's WHO 2021 guideline value.
#' @return A list of class \code{rmbl_burden} with \code{paf},
#'   \code{attributable_cases}, \code{baseline_cases}, \code{population},
#'   \code{baseline_rate}, \code{exposure_mean}, \code{reference_conc},
#'   \code{pollutant}, \code{citation} and \code{extra} (the RR and log-RR).
#' @references GBD 2019 Risk Factors Collaborators (2020). Global burden of 87
#'   risk factors in 204 countries and territories, 1990-2019. The Lancet
#'   396(10258), 1223-1249.
#' @examples
#' pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2")$attributable_cases
#' @export
pollution_burden <- function(exposure_mean, exposure_prevalence, baseline_rate, population,
                             pollutant = "NO2", outcome = "all_cause_mortality",
                             reference_conc = NULL) {
  crf <- if (identical(pollutant, "PM2.5")) {
    crf_pm25(exposure_mean, outcome = outcome,
             reference_conc = if (is.null(reference_conc)) 5.8 else reference_conc)
  } else if (identical(pollutant, "NO2")) {
    crf_no2(exposure_mean, outcome = outcome,
            reference_conc = if (is.null(reference_conc)) 10 else reference_conc)
  } else {
    stop(sprintf("Unknown pollutant '%s'. Use 'PM2.5' or 'NO2'.", paste(pollutant, collapse = ",")),
         call. = FALSE)
  }
  paf <- attributable_fraction(crf$rr, exposure_prevalence)
  baseline_cases <- baseline_rate * population
  structure(list(
    paf = paf,
    attributable_cases = paf * baseline_cases,
    baseline_cases = baseline_cases,
    population = as.integer(population),
    baseline_rate = baseline_rate,
    exposure_mean = as.numeric(exposure_mean),
    reference_conc = crf$reference_conc,
    pollutant = pollutant,
    citation = paste0(crf$citation, "; Rothman et al. (2008) section 5"),
    extra = list(rr = crf$rr, log_rr = crf$log_rr, outcome = outcome)
  ), class = "rmbl_burden")
}

#' Cross-fitted partially linear regression (double machine learning)
#'
#' The partially linear model \eqn{Y = \theta D + g(X) + U},
#' \eqn{D = m(X) + V} of Chernozhukov et al. (2018, section 4.2), estimated
#' by the DML2 cross-fitting recipe: the sample is split into \code{k_folds}
#' folds; for each fold the nuisances \eqn{m} and \eqn{g} are fitted on the
#' other folds and predicted on it; \eqn{\hat\theta} is the slope of the
#' out-of-fold outcome residuals on the out-of-fold treatment residuals,
#' \deqn{\hat\theta = \sum_i \hat V_i \hat U_i / \sum_i \hat V_i^2,}
#' with the sandwich standard error
#' \eqn{\sqrt{\sum_i \hat V_i^2 (\hat U_i - \hat\theta \hat V_i)^2} / \sum_i \hat V_i^2}.
#' The nuisances here are ordinary least squares on the covariates, which is
#' the right learner when the confounding is approximately linear and keeps
#' the estimator fully deterministic given \code{seed}; rmorie's
#' \code{morie_estimate_double_ml()} offers richer learners and can be passed
#' to \code{\link{exposure_response_plr}} through \code{estimator}.
#'
#' @param data A data frame.
#' @param outcome,treatment Column names of the outcome and the (continuous)
#'   treatment or exposure.
#' @param covariates Column names of the confounders.
#' @param k_folds Number of cross-fitting folds (default 5).
#' @param seed Seed of the fold assignment.
#' @return A list with \code{ate} (the estimate of \eqn{\theta}), \code{se},
#'   \code{n}, \code{k_folds} and \code{method}.
#' @references Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E.,
#'   Hansen, C., Newey, W. and Robins, J. (2018). Double/debiased machine
#'   learning for treatment and structural parameters. The Econometrics
#'   Journal 21(1), C1-C68.
#' @examples
#' set.seed(1)
#' d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
#' d$exposure <- 20 + 2 * d$x1 + rnorm(200)
#' d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
#' plr_crossfit(d, "asthma", "exposure", c("x1", "x2"))$ate
#' @export
plr_crossfit <- function(data, outcome, treatment, covariates, k_folds = 5L, seed = 1L) {
  cols <- c(outcome, treatment, covariates)
  missing <- setdiff(cols, names(data))
  if (length(missing)) stop(sprintf("data is missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  df <- data[stats::complete.cases(data[, cols, drop = FALSE]), cols, drop = FALSE]
  n <- nrow(df)
  k_folds <- as.integer(k_folds)
  if (is.na(k_folds) || k_folds < 2L) stop("`k_folds` must be at least 2", call. = FALSE)
  if (n < 2L * k_folds) {
    stop(sprintf("need at least %d complete rows for %d folds; have %d", 2L * k_folds, k_folds, n),
         call. = FALSE)
  }
  folds <- .rmbl_with_seed(seed, sample(rep_len(seq_len(k_folds), n)))
  y <- as.numeric(df[[outcome]])
  d <- as.numeric(df[[treatment]])
  X <- cbind(1, as.matrix(df[, covariates, drop = FALSE]))
  storage.mode(X) <- "double"
  U <- numeric(n)
  V <- numeric(n)
  for (k in seq_len(k_folds)) {
    test <- folds == k
    Xt <- X[!test, , drop = FALSE]
    gy <- stats::lm.fit(Xt, y[!test])$coefficients
    gd <- stats::lm.fit(Xt, d[!test])$coefficients
    gy[is.na(gy)] <- 0
    gd[is.na(gd)] <- 0
    U[test] <- y[test] - drop(X[test, , drop = FALSE] %*% gy)
    V[test] <- d[test] - drop(X[test, , drop = FALSE] %*% gd)
  }
  denom <- sum(V * V)
  scale <- max(1, sum((d - mean(d))^2))
  if (!is.finite(denom) || denom <= 1e-10 * scale) {
    stop("the treatment has no variation left after partialling out the covariates", call. = FALSE)
  }
  theta <- sum(V * U) / denom
  se <- sqrt(sum(V * V * (U - theta * V)^2)) / denom
  list(ate = theta, se = se, n = n, k_folds = k_folds,
       method = "partially linear regression, DML2 cross-fitting, OLS nuisances")
}

#' Exposure-response estimate with a bootstrap sensitivity interval
#'
#' Fits the partially linear exposure-response model with
#' \code{\link{plr_crossfit}} (or any estimator with the same interface),
#' then re-fits it on \code{n_bootstrap} non-parametric resamples of the rows
#' for a percentile interval (Efron and Tibshirani 1993, chapter 13).
#'
#' @param data A data frame.
#' @param outcome,exposure,confounders Column names.
#' @param n_bootstrap Number of resamples (default 100).
#' @param random_state Seed for the resampling.
#' @param estimator A function \code{(data, outcome, treatment, covariates)}
#'   returning a list with \code{ate} and \code{se}. The default is
#'   \code{\link{plr_crossfit}}; rmorie's \code{morie_estimate_double_ml()}
#'   has the same interface.
#' @return A list with \code{ate}, \code{se_analytic}, \code{se_bootstrap},
#'   \code{ci_lower_bs}, \code{ci_upper_bs}, \code{n_bootstrap} and
#'   \code{method}.
#' @references Efron, B. and Tibshirani, R. J. (1993). An Introduction to the
#'   Bootstrap. Chapman and Hall.
#' @examples
#' set.seed(1)
#' d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
#' d$exposure <- 20 + 2 * d$x1 + rnorm(200)
#' d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
#' exposure_response_plr(d, outcome = "asthma", exposure = "exposure",
#'                       confounders = c("x1", "x2"), n_bootstrap = 20)$ate
#' @export
exposure_response_plr <- function(data, outcome, exposure, confounders, n_bootstrap = 100L,
                                  random_state = 42L, estimator = plr_crossfit) {
  estimator <- match.fun(estimator)
  base <- estimator(data, outcome, exposure, confounders)
  ate <- as.numeric(base$ate)
  se_analytic <- as.numeric(base$se)
  n <- nrow(data)
  boot <- .rmbl_with_seed(random_state, {
    out <- numeric(0)
    for (b in seq_len(n_bootstrap)) {
      idx <- sample.int(n, n, replace = TRUE)
      r <- tryCatch(estimator(data[idx, , drop = FALSE], outcome, exposure, confounders),
                    error = function(e) NULL)
      if (!is.null(r)) out <- c(out, as.numeric(r$ate))
    }
    out
  })
  if (length(boot) < 10L) {
    stop(sprintf("Only %d successful bootstrap fits; need >=10. Inspect the model's convergence on your resamples.",
                 length(boot)), call. = FALSE)
  }
  list(
    ate = ate,
    se_analytic = se_analytic,
    se_bootstrap = stats::sd(boot),
    ci_lower_bs = unname(stats::quantile(boot, 0.025, type = 7)),
    ci_upper_bs = unname(stats::quantile(boot, 0.975, type = 7)),
    n_bootstrap = length(boot),
    method = paste0(if (is.null(base$method)) "exposure-response" else base$method, " + percentile bootstrap")
  )
}

#' Concentration index of exposure by income
#'
#' Wagstaff, Paci and van Doorslaer (1991):
#' \deqn{CI = (2 / \mu) \, \mathrm{cov}(h_i, R_i)}
#' with \eqn{R_i = (rank_i - 0.5) / n} the fractional income rank (ties kept
#' in input order, as a stable sort does) and the population covariance.
#' Negative values mean lower-income units bear more exposure.
#'
#' @param data A data frame.
#' @param exposure,income Column names.
#' @return A list of class \code{rmbl_equity} with \code{concentration_index},
#'   \code{interpretation}, \code{n_quintiles}, \code{exposure_mean},
#'   \code{citation} and \code{extra}.
#' @references Wagstaff, A., Paci, P. and van Doorslaer, E. (1991). On the
#'   measurement of inequalities in health. Social Science and Medicine 33(5),
#'   545-557.
#' @examples
#' d <- data.frame(exposure = c(30, 25, 20, 15, 10), income = 1:5)
#' exposure_concentration_index(d, "exposure", "income")$concentration_index
#' @export
exposure_concentration_index <- function(data, exposure, income) {
  missing <- setdiff(c(exposure, income), names(data))
  if (length(missing)) stop(sprintf("data is missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  df <- data[, c(exposure, income), drop = FALSE]
  df <- df[stats::complete.cases(df), , drop = FALSE]
  n <- nrow(df)
  if (n < 2L) stop("Need at least 2 rows to compute concentration index.", call. = FALSE)
  h <- as.numeric(df[[exposure]])
  inc <- as.numeric(df[[income]])
  mu <- mean(h)
  if (mu == 0) stop("Mean exposure is zero; concentration index undefined.", call. = FALSE)
  ord <- order(inc, method = "radix")
  ranks <- numeric(n)
  ranks[ord] <- seq_len(n)
  R <- (ranks - 0.5) / n
  cov_hr <- sum((h - mean(h)) * (R - mean(R))) / n
  ci <- 2 * cov_hr / mu
  interp <- if (ci < -0.01) {
    sprintf("CI = %.4f. Pro-poor exposure burden: lower-income individuals bear disproportionately higher pollution.",
            ci)
  } else if (ci > 0.01) {
    sprintf("CI = %.4f. Pro-rich exposure burden: higher-income individuals bear disproportionately higher pollution.",
            ci)
  } else {
    sprintf("CI = %.4f. Exposure distributed approximately evenly across income.", ci)
  }
  structure(list(
    concentration_index = ci,
    interpretation = interp,
    n_quintiles = 5L,
    exposure_mean = mu,
    citation = "Wagstaff, Paci & van Doorslaer (1991) Soc Sci Med 33(5):545-557",
    extra = list(n = n, cov_h_R = cov_hr)
  ), class = "rmbl_equity")
}

#' Per-area pollution burden
#'
#' Applies \code{\link{pollution_burden}} to every row of a table with one row
#' per area (forward sortation area, census tract, neighbourhood, ...) and
#' returns the rows sorted by attributable cases, worst first.
#'
#' @param area_table A data frame with one row per area.
#' @param area_col,exposure_col,population_col,baseline_rate_col Column names.
#' @param pollutant,outcome Passed to \code{\link{pollution_burden}}.
#' @return The input columns plus \code{rr}, \code{paf},
#'   \code{attributable_cases} and \code{baseline_cases}.
#' @examples
#' t <- data.frame(fsa = c("M6H", "M5V"), exposure = c(28, 18),
#'                 population = c(40000, 60000), baseline_rate = 0.008)
#' pollution_burden_by_area(t)
#' @export
pollution_burden_by_area <- function(area_table, area_col = "fsa", exposure_col = "exposure",
                                     population_col = "population",
                                     baseline_rate_col = "baseline_rate",
                                     pollutant = "NO2", outcome = "all_cause_mortality") {
  required <- c(area_col, exposure_col, population_col, baseline_rate_col)
  missing <- setdiff(required, names(area_table))
  if (length(missing)) {
    stop(sprintf("area_table missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (!nrow(area_table)) stop("area_table has no rows", call. = FALSE)
  rows <- lapply(seq_len(nrow(area_table)), function(i) {
    r <- pollution_burden(
      exposure_mean = as.numeric(area_table[[exposure_col]][i]),
      exposure_prevalence = 1,
      baseline_rate = as.numeric(area_table[[baseline_rate_col]][i]),
      population = as.integer(area_table[[population_col]][i]),
      pollutant = pollutant, outcome = outcome)
    out <- data.frame(a = area_table[[area_col]][i], stringsAsFactors = FALSE)
    names(out) <- area_col
    out[[exposure_col]] <- as.numeric(area_table[[exposure_col]][i])
    out[[population_col]] <- as.integer(area_table[[population_col]][i])
    out[[baseline_rate_col]] <- as.numeric(area_table[[baseline_rate_col]][i])
    out$rr <- r$extra$rr
    out$paf <- r$paf
    out$attributable_cases <- r$attributable_cases
    out$baseline_cases <- r$baseline_cases
    out
  })
  res <- do.call(rbind, rows)
  res <- res[order(-res$attributable_cases), , drop = FALSE]
  rownames(res) <- NULL
  res
}

# ---- verify_pollution -------------------------------------------------------

# Synthetic exposure and income with the orders of magnitude of Toronto
# forward-sortation-area NO2 and CIHI asthma rates. R's own RNG, seeded locally.
.pollution_demo_data <- function(pollutant) {
  .rmbl_with_seed(20260417L, {
    n <- 1000L
    meanlog <- switch(pollutant, no2 = log(22), pm25 = log(9), log(15))
    sdlog <- if (pollutant == "pm25") 0.30 else 0.35
    exposure <- stats::rlnorm(n, meanlog, sdlog)
    income <- sample(1:5, n, replace = TRUE, prob = c(0.18, 0.22, 0.22, 0.20, 0.18))
    mult <- c(1.25, 1.12, 1.00, 0.93, 0.85)[income]
    data.frame(exposure = exposure * mult, income = income)
  })
}

.pollution_assumptions <- function(pollutant, exposure_mean, exposure_prevalence,
                                   baseline_rate, population, reference) {
  row <- function(name, ok, note) list(assumption = name, ok = isTRUE(ok), note = note)
  list(
    row("exposure > reference", exposure_mean > reference,
        sprintf("mean %s vs ref %s -- CRF is monotonic only when exposure exceeds the counterfactual floor.",
                format(exposure_mean, digits = 10), format(reference))),
    row("prevalence in [0,1]", exposure_prevalence >= 0 && exposure_prevalence <= 1,
        sprintf("exposure_prevalence=%s", format(exposure_prevalence))),
    row("baseline_rate non-negative", baseline_rate >= 0,
        sprintf("baseline_rate=%s per 100k per year", format(baseline_rate))),
    row("population positive", population > 0, sprintf("population=%s", format(population))),
    row("pollutant supported by the CRFs", tolower(pollutant) %in% c("no2", "pm25"),
        paste("Current CRFs: NO2 (log-linear), PM2.5 (log-linear all-cause; Burnett IER for IHD and stroke).",
              "Other pollutants reject."))
  )
}

#' Run the pollution-to-health pipeline and report it
#'
#' Resolves the exposure (synthetic demo data, a CSV with an \code{exposure}
#' column and an optional \code{income} column, a NAPS-style pull with a
#' \code{value} column and a \code{unit}, or scalar arguments), logs the
#' assumptions, and when they all hold runs the concentration-response,
#' attributable-fraction, displaced-mortality, burden and equity stages.
#' \code{pollution_report_text()} renders the result as plain text.
#'
#' @param pollutant \code{"no2"} or \code{"pm25"}.
#' @param outcome Outcome key for the concentration-response function.
#' @param region,years Labels for the report.
#' @param demo Use synthetic demo data.
#' @param exposure_csv Path of a CSV with an \code{exposure} column in
#'   micrograms per cubic metre, or a \code{value} column with a \code{unit}
#'   column (NO2 in ppb is converted at 1.88 micrograms per cubic metre per
#'   ppb, the WHO 2021 conversion at 25 C and 1 atm).
#' @param exposure_mean,exposure_prevalence Scalar inputs used when neither
#'   \code{demo} nor \code{exposure_csv} is given.
#' @param reference Counterfactual reference concentration.
#' @param baseline_rate Baseline outcome rate per 100,000 per year.
#' @param population Population at risk.
#' @param report A result of \code{verify_pollution()}.
#' @return \code{verify_pollution()}: the report as a list; its \code{status}
#'   is \code{"ok"}, \code{"assumption_failure"} or \code{"error"}, and the
#'   attribute \code{exit_status} carries a command-line exit code (0, 1 or
#'   2). \code{pollution_report_text()}: a character string.
#' @examples
#' r <- verify_pollution("no2", demo = TRUE)
#' r$status
#' r$pipeline$paf
#' cat(pollution_report_text(r))
#' @export
verify_pollution <- function(pollutant, outcome = "all_cause_mortality", region = NULL,
                             years = NULL, demo = FALSE, exposure_csv = NULL,
                             exposure_mean = 0, exposure_prevalence = 0, reference = 5.8,
                             baseline_rate = 500, population = 1e6) {
  pollutant <- tolower(as.character(pollutant))
  equity_df <- NULL
  fail <- function(msg) structure(list(status = "error", error = msg), exit_status = 2L)
  if (isTRUE(demo)) {
    df <- .pollution_demo_data(pollutant)
    exposure_mean <- mean(df$exposure)
    exposure_prevalence <- mean(df$exposure > reference)
    equity_df <- df
    data_source <- "demo (synthetic)"
  } else if (!is.null(exposure_csv)) {
    if (!file.exists(exposure_csv)) return(fail(sprintf("exposure CSV not found: %s", exposure_csv)))
    empty <- sprintf("%s is empty (expected a column exposure in ug/m3, or a NAPS pull's value + unit)", exposure_csv)
    if (isTRUE(file.size(exposure_csv) == 0)) return(fail(empty))
    df <- utils::read.csv(exposure_csv, stringsAsFactors = FALSE)
    if (!nrow(df)) return(fail(empty))
    if (!"exposure" %in% names(df) && "value" %in% names(df)) {
      # a NAPS pull: hourly `value` in `unit`; NO2 is reported in ppb
      vals <- suppressWarnings(as.numeric(df$value))
      units <- if ("unit" %in% names(df)) unique(tolower(trimws(stats::na.omit(df$unit)))) else character()
      if (pollutant == "no2" && any(units %in% c("ppb", "ppbv"))) {
        vals <- vals * 1.88  # ug/m3 per ppb of NO2 at 25 C and 1 atm (WHO 2021 conversion)
        message("note: NO2 in ppb converted to ug/m3 (x 1.88)")
      } else if (length(setdiff(units, c("ug/m3", "\u00b5g/m3", "\u00b5g/m\u00b3", "ug/m\u00b3")))) {
        return(fail(sprintf("exposure unit %s is not ug/m3 for %s", paste(sort(units), collapse = ", "), pollutant)))
      }
      df$exposure <- vals
    }
    if (!"exposure" %in% names(df)) {
      return(fail("CSV missing 'exposure' column (ug/m3); a NAPS pull's 'value' column also works."))
    }
    exposure_mean <- mean(df$exposure, na.rm = TRUE)
    exposure_prevalence <- mean(df$exposure > reference, na.rm = TRUE)
    if ("income" %in% names(df)) equity_df <- df
    data_source <- exposure_csv
  } else {
    exposure_mean <- as.numeric(exposure_mean)
    exposure_prevalence <- as.numeric(exposure_prevalence)
    data_source <- "scalar arguments"
  }
  baseline_rate <- as.numeric(baseline_rate)
  population <- as.integer(population)
  assumptions <- .pollution_assumptions(pollutant, exposure_mean, exposure_prevalence,
                                        baseline_rate, population, reference)
  report <- list(
    command = "verify-pollution", pollutant = pollutant, outcome = outcome,
    region = region, years = years, data_source = data_source,
    inputs = list(exposure_mean = exposure_mean, exposure_prevalence = exposure_prevalence,
                  baseline_rate_per_100k = baseline_rate, population = population,
                  reference_conc = reference),
    assumptions = assumptions)
  if (!all(vapply(assumptions, function(a) a$ok, logical(1)))) {
    report$status <- "assumption_failure"
    report$pipeline <- list(skipped = TRUE, reason = "assumptions")
    return(structure(report, exit_status = 1L))
  }
  crf <- if (pollutant == "no2") {
    crf_no2(exposure_mean, outcome = outcome, reference_conc = reference)
  } else {
    crf_pm25(exposure_mean, outcome = outcome, reference_conc = reference)
  }
  paf <- attributable_fraction(crf$rr, exposure_prevalence)
  baseline_per_person <- baseline_rate / 1e5
  exposure_delta <- max(0, exposure_mean - reference)
  beta_per_unit <- log(crf$rr) / max(exposure_delta, 1e-9)
  # the deaths displaced by removing the excess exposure are counted over the exposed share of the
  # population, and the burden uses the same reference concentration as the RR printed above it
  displaced <- mortality_displaced(exposure_delta, population * exposure_prevalence,
                                   baseline_per_person, beta_per_unit)
  burden <- pollution_burden(exposure_mean, exposure_prevalence, baseline_per_person, population,
                             pollutant = if (pollutant == "pm25") "PM2.5" else "NO2",
                             outcome = outcome, reference_conc = reference)
  equity <- if (!is.null(equity_df) && "income" %in% names(equity_df)) {
    exposure_concentration_index(equity_df, "exposure", "income")
  }
  report$status <- "ok"
  report$pipeline <- list(
    crf = unclass(crf), paf = paf,
    displaced = list(deaths_displaced = displaced, exposure_delta = exposure_delta,
                     beta_per_unit = beta_per_unit),
    burden = unclass(burden),
    equity = if (is.null(equity)) NULL else unclass(equity))
  structure(report, exit_status = 0L)
}

#' @rdname verify_pollution
#' @export
pollution_report_text <- function(report) {
  bar <- strrep("=", 66)
  if (identical(report$status, "error")) return(paste0("ERROR: ", report$error, "\n"))
  lines <- c(bar, sprintf("  %s -- %s -> %s", report$command, toupper(report$pollutant), report$outcome))
  if (!is.null(report$region)) lines <- c(lines, sprintf("  region: %s", report$region))
  if (!is.null(report$years)) lines <- c(lines, sprintf("  years:  %s", report$years))
  inp <- report$inputs
  lines <- c(lines, sprintf("  data:   %s", report$data_source), bar, "", "Inputs",
             sprintf("  exposure mean:      %.3f", inp$exposure_mean),
             sprintf("  exposure prevalence:%.3f", inp$exposure_prevalence),
             sprintf("  baseline rate/100k: %.2f", inp$baseline_rate_per_100k),
             sprintf("  population:         %s", format(inp$population, big.mark = ",")),
             sprintf("  reference conc:     %s", format(inp$reference_conc)),
             "", "Assumption log")
  for (a in report$assumptions) {
    lines <- c(lines, sprintf("  [%s] %s -- %s", if (a$ok) "PASS" else "FAIL", a$assumption, a$note))
  }
  if (identical(report$status, "assumption_failure")) {
    return(paste0(paste(lines, collapse = "\n"), "\n\nSTATUS: assumption_failure (pipeline skipped)\n"))
  }
  p <- report$pipeline
  lines <- c(lines, "", "Concentration-response", sprintf("  RR:       %.4f", p$crf$rr),
             sprintf("  source:   %s", p$crf$citation),
             "", sprintf("Attributable fraction (PAF): %.4f", p$paf),
             "", "Mortality displaced",
             sprintf("  expected avoided deaths: %.1f", p$displaced$deaths_displaced),
             "", "Burden of pollution",
             sprintf("  attributable deaths:   %.1f", p$burden$attributable_cases))
  if (!is.null(p$equity)) {
    lines <- c(lines, "", "Equity analysis",
               sprintf("  concentration index: %.4f", p$equity$concentration_index))
  }
  paste0(paste(lines, collapse = "\n"), "\n\nSTATUS: ok\n")
}
