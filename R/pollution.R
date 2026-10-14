# SPDX-License-Identifier: AGPL-3.0-or-later
# Air pollution and health: concentration-response functions, the
# attributable fraction, displaced mortality, the burden chain, a cross-fitted
# partially linear exposure-response estimator with a bootstrap, the
# concentration index of exposure by income, and a one-call pipeline with an
# assumption log. Every formula cites the paper it implements. The functions
# mirror rmorie's envhealth module (and morie's Python envhealth) formula for
# formula; see exposure_response_plr() for the one seam that differs.

.crf_object <- function(rr, log_rr, z, scalar, reference_conc, pollutant, citation, extra,
                        rr_lower = NA_real_, rr_upper = NA_real_) {
  structure(list(
    rr = if (scalar) rr[[1L]] else mean(rr),
    log_rr = if (scalar) log_rr[[1L]] else mean(log_rr),
    # the published 95 percent limits of the relative risk, carried through the same curve
    # (NA for the IER forms, whose papers give no interval on the pooled parameters)
    rr_lower = if (scalar) rr_lower[[1L]] else mean(rr_lower),
    rr_upper = if (scalar) rr_upper[[1L]] else mean(rr_upper),
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
#'   \code{"stroke"} (deaths). NO2: \code{"all_cause_mortality"} and
#'   \code{"respiratory"} (deaths; Huangfu and Atkinson 2020, RR 1.02 and
#'   1.03 per 10 micrograms per cubic metre) or \code{"childhood_asthma"}
#'   (incident cases, not deaths; Khreis et al. 2017, OR 1.05 per 4
#'   micrograms per cubic metre, scaled to per 10).
#' @param reference_conc Counterfactual concentration below which no excess
#'   risk is assumed. PM2.5 default 5.8, the lower bound of the GBD 2019
#'   theoretical minimum risk exposure level (the WHO 2021 guideline is 5);
#'   NO2 default 10, the WHO 2021 guideline.
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
#'   International 144, 105998. Khreis, H. et al. (2017). Exposure to
#'   traffic-related air pollution and risk of development of childhood
#'   asthma: a systematic review and meta-analysis. Environment International
#'   100, 1-31. GBD 2019 Risk Factors Collaborators (2020). The Lancet
#'   396(10258), 1223-1249. Burnett, R. T. et al. (2014). An integrated
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
  loglinear_ci <- list(all_cause_mortality = log(c(1.06, 1.09)))
  # GBD 2013 cause-specific IER triples (alpha, gamma, delta), Burnett et al. (2014)
  ier <- list(ihd = c(1.91, 0.14, 0.49), stroke = c(1.46, 0.13, 0.61))
  if (!is.character(outcome) || length(outcome) != 1L ||
      !outcome %in% c(names(loglinear), names(ier))) {
    stop(sprintf("Unknown outcome '%s'. Available: %s", paste(outcome, collapse = ","),
                 paste(c(names(loglinear), names(ier)), collapse = ", ")), call. = FALSE)
  }
  # one reference for every exposure: a vector would recycle against z, an NA would give NA risks
  reference_conc <- .pollution_scalar(reference_conc, "reference_conc")
  z <- .pollution_exposure(exposure)
  scalar <- length(z) == 1L
  excess <- pmax(z - reference_conc, 0)
  if (outcome %in% names(loglinear)) {
    beta <- loglinear[[outcome]]
    log_rr <- beta * excess / 10
    ci <- loglinear_ci[[outcome]]
    return(.crf_object(exp(log_rr), log_rr, z, scalar, reference_conc, "PM2.5",
                       "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ Guidelines",
                       list(beta_per_10 = beta, beta_per_10_ci = ci, form = "log-linear", outcome = outcome),
                       rr_lower = exp(ci[[1L]] * excess / 10), rr_upper = exp(ci[[2L]] * excess / 10)))
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
  # all-cause RR 1.02 (95% CI 1.01-1.04) and respiratory RR 1.03 (1.00-1.05) per 10 ug/m3,
  # Huangfu and Atkinson (2020), the WHO 2021 review; childhood asthma incidence OR 1.05
  # (1.02-1.07) per 4 ug/m3, Khreis et al. (2017), scaled to per 10 ug/m3
  betas <- c(all_cause_mortality = log(1.02), respiratory = log(1.03),
             childhood_asthma = log(1.05) * 10 / 4)
  betas_ci <- list(all_cause_mortality = log(c(1.01, 1.04)), respiratory = log(c(1.00, 1.05)),
                   childhood_asthma = log(c(1.02, 1.07)) * 10 / 4)
  ci <- c(NA_real_, NA_real_)
  if (is.null(beta_per_10)) {
    if (!is.character(outcome) || length(outcome) != 1L || !outcome %in% names(betas)) {
      stop(sprintf("Unknown outcome '%s'. Available: %s or pass beta_per_10 explicitly.",
                   paste(outcome, collapse = ","), paste(names(betas), collapse = ", ")),
           call. = FALSE)
    }
    beta <- betas[[outcome]]
    ci <- betas_ci[[outcome]]
  } else {
    # the same guard as every other scalar: TRUE is not a log relative risk of 1
    beta <- .pollution_scalar(beta_per_10, "beta_per_10", nonneg = FALSE)
  }
  reference_conc <- .pollution_scalar(reference_conc, "reference_conc")
  z <- .pollution_exposure(exposure)
  scalar <- length(z) == 1L
  log_rr <- beta * pmax(z - reference_conc, 0) / 10
  cite <- if (identical(outcome, "childhood_asthma") && is.null(beta_per_10)) {
    "Khreis et al. (2017) Environ Int 100:1-31; WHO (2021) Global AQ Guidelines"
  } else {
    "Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines"
  }
  .crf_object(exp(log_rr), log_rr, z, scalar, reference_conc, "NO2", cite,
              list(beta_per_10 = beta, beta_per_10_ci = ci, outcome = outcome),
              rr_lower = exp(ci[[1L]] * pmax(z - reference_conc, 0) / 10),
              rr_upper = exp(ci[[2L]] * pmax(z - reference_conc, 0) / 10))
}

.pollution_exposure <- function(exposure) {
  if (is.logical(exposure)) stop("`exposure` must be numeric, not logical", call. = FALSE)
  z <- .rmbl_num_input(exposure, "exposure", allow_null = FALSE)
  if (!length(z) || anyNA(z) || any(!is.finite(z))) {
    stop("`exposure` must be one or more finite concentrations, with no missing values",
         call. = FALSE)
  }
  if (any(z < 0)) stop("`exposure` must be non-negative", call. = FALSE)
  z
}

# One finite number, optionally non-negative: the scalar inputs of the burden functions.
.pollution_rate_msg <- function(rate) {
  sprintf(paste("`baseline_rate` is a rate per person-year, between 0 and 1 (0.008 is 800 per 100,000);",
                "%s looks like a rate per 100,000, which only verify_pollution() takes"), format(rate))
}

# A baseline rate per person-year, checked as verify_pollution() checks its rate per 100,000 (the
# same band, the same switches; review of e57fed5, E4: 0.5 and 8e-8 were taken as they came). The
# band is 1 to 10,000 per 100,000 a year (1e-5 to 0.1 per person-year): below it, the number is
# also what a rate per 100,000 passed here looks like (rare_outcome = TRUE when the outcome really
# is that rare, never below 1e-6 per 100,000); above it, no population's all-cause mortality comes
# close (high_rate = TRUE for an outcome that common, never above 1); zero is a measured zero.
.pollution_rate_pp <- function(rate, rare_outcome = FALSE, high_rate = FALSE) {
  for (a in list(list("rare_outcome", rare_outcome), list("high_rate", high_rate))) {
    if (!is.logical(a[[2L]]) || length(a[[2L]]) != 1L || is.na(a[[2L]])) {
      stop(sprintf("`%s` must be TRUE or FALSE", a[[1L]]), call. = FALSE)
    }
  }
  if (rate > 1) stop(.pollution_rate_msg(rate), call. = FALSE)
  if (rate == 0) return(rate)
  if (rate < 1e-11) {
    stop(sprintf(paste("`baseline_rate` %s per person-year is below one case per 100 billion person-years:",
                       "not a usable rate"), format(rate)), call. = FALSE)
  }
  if (rate < 1e-5 && !rare_outcome) {
    stop(sprintf(paste("`baseline_rate` %s per person-year is below one case per 100,000 a year. A rate per",
                       "100,000 divided by 100,000 is the rate here (800 per 100,000 is 0.008); if the outcome",
                       "really is this rare, say so with rare_outcome = TRUE"), format(rate)), call. = FALSE)
  }
  if (rate > 0.1 && !high_rate) {
    stop(sprintf(paste("`baseline_rate` %s per person-year is %s per 100,000 a year, above any population's",
                       "all-cause death rate. If it is a rate per 100,000, divide it by 100,000; if the outcome",
                       "really is this common, say so with high_rate = TRUE"),
                 format(rate), format(rate * 1e5, big.mark = ",", scientific = FALSE)), call. = FALSE)
  }
  rate
}

.pollution_scalar <- function(x, what, nonneg = TRUE, positive = FALSE) {
  # a flag is not a number: as.numeric(TRUE) is 1, and a relative risk of TRUE is a typo
  if (is.logical(x) && !all(is.na(x))) stop(sprintf("`%s` must be numeric, not logical", what), call. = FALSE)
  if (is.factor(x)) {
    stop(sprintf("`%s` must be numeric, not a factor (its level codes are not values)", what), call. = FALSE)
  }
  v <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (length(v) != 1L || is.na(v) || !is.finite(v)) {
    stop(sprintf("`%s` must be a single finite number", what), call. = FALSE)
  }
  if (positive && v <= 0) stop(sprintf("`%s` must be positive", what), call. = FALSE)
  if (nonneg && v < 0) stop(sprintf("`%s` must be non-negative", what), call. = FALSE)
  v
}

# "PM2.5", "PM25", "pm2.5", "pm25" -> "PM2.5"; "NO2", "no2" -> "NO2"; anything else NA.
.pollution_pollutant <- function(pollutant) {
  if (!is.character(pollutant) || length(pollutant) != 1L || is.na(pollutant)) return(NA_character_)
  key <- gsub("[^a-z0-9]", "", tolower(pollutant))
  if (key %in% c("pm25", "pm2.5")) return("PM2.5")
  if (identical(key, "no2")) return("NO2")
  NA_character_
}

# The unit of an outcome's attributable count: the mortality outcomes are deaths, the
# childhood-asthma CRF is an incidence relative risk.
.pollution_outcome_unit <- function(outcome) {
  if (identical(outcome, "childhood_asthma")) "incident cases" else "deaths"
}

#' Population attributable fraction
#'
#' Levin's formula (Rothman, Greenland and Lash 2008, chapter 5):
#' \deqn{PAF = p (RR - 1) / (1 + p (RR - 1)),}
#' the fraction of cases that would be avoided if the exposure were removed.
#'
#' @param rr Relative risk among the exposed, a single finite positive
#'   number. A relative risk below 1 gives a negative fraction (a protective
#'   exposure); 0, negative, infinite and missing values are errors.
#' @param exposure_prevalence Proportion of the population exposed, in
#'   \code{[0, 1]}.
#' @param rr_lower,rr_upper Optional confidence limits of \code{rr}; when
#'   both are given the fraction carries the limits that the same formula
#'   gives at them (Levin's formula is monotone in the relative risk, so the
#'   interval of the fraction is the image of the interval of the risk).
#' @return A number in \code{[0, 1)} for \code{rr >= 1}, with an attribute
#'   \code{ci} (\code{lower}, \code{upper}) when the limits were given.
#' @references Rothman, K. J., Greenland, S. and Lash, T. L. (2008). Modern
#'   Epidemiology, 3rd ed., chapter 5. Levin, M. L. (1953). The occurrence of
#'   lung cancer in man. Acta Unio Internationalis Contra Cancrum 9, 531-541.
#' @examples
#' attributable_fraction(1.5, 0.4)
#' attributable_fraction(2, 1)      # everyone exposed: 1 - 1/RR
#' @export
attributable_fraction <- function(rr, exposure_prevalence, rr_lower = NULL, rr_upper = NULL) {
  rr <- .pollution_scalar(rr, "rr", nonneg = FALSE, positive = TRUE)
  p <- .pollution_scalar(exposure_prevalence, "exposure_prevalence")
  if (p > 1) {
    stop(sprintf("exposure_prevalence must be in [0,1]; got %s", format(p)), call. = FALSE)
  }
  levin <- function(r) p * (r - 1) / (1 + p * (r - 1))   # the denominator is positive: r > 0, p <= 1
  paf <- levin(rr)
  if (!is.null(rr_lower) || !is.null(rr_upper)) {
    if (is.null(rr_lower) || is.null(rr_upper)) stop("rr_lower and rr_upper go together", call. = FALSE)
    lo <- .pollution_scalar(rr_lower, "rr_lower", nonneg = FALSE, positive = TRUE)
    hi <- .pollution_scalar(rr_upper, "rr_upper", nonneg = FALSE, positive = TRUE)
    if (lo > rr || hi < rr) stop("rr must lie between rr_lower and rr_upper", call. = FALSE)
    attr(paf, "ci") <- c(lower = levin(lo), upper = levin(hi))
  }
  paf
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
#' @param rare_outcome,high_rate \code{TRUE} to admit a baseline rate
#'   below 1e-5 (one per 100,000) or above 0.1 (10,000 per 100,000)
#'   per person-year; without them such a rate is refused, being also
#'   what a rate in the wrong unit looks like.
#' @return Expected avoided cases.
#' @references US EPA (2018). Environmental Benefits Mapping and Analysis
#'   Program - Community Edition, user manual. Anenberg, S. C. et al. (2010).
#'   An estimate of the global burden of anthropogenic ozone and fine
#'   particulate matter on premature human mortality using atmospheric
#'   modeling. Environmental Health Perspectives 118(9), 1189-1195.
#' @examples
#' mortality_displaced(10, 1e6, 0.008, 0.0039)
#' @export
mortality_displaced <- function(exposure_delta, population, baseline_rate, beta_per_unit,
                                rare_outcome = FALSE, high_rate = FALSE) {
  exposure_delta <- .pollution_scalar(exposure_delta, "exposure_delta", nonneg = FALSE)
  population <- .pollution_scalar(population, "population")
  baseline_rate <- .pollution_rate_pp(.pollution_scalar(baseline_rate, "baseline_rate"), rare_outcome, high_rate)
  beta_per_unit <- .pollution_scalar(beta_per_unit, "beta_per_unit", nonneg = FALSE)
  baseline_rate * population * (1 - exp(-beta_per_unit * exposure_delta))
}

#' End-to-end pollution burden
#'
#' Chains the concentration-response function, the attributable fraction and
#' the baseline case count into annual attributable cases, as the GBD risk
#' factor estimates do (GBD 2019 Risk Factors Collaborators 2020).
#'
#' @param exposure_mean Mean exposure among the exposed (micrograms per cubic
#'   metre). With \code{exposure_prevalence = 1} that is the population mean.
#' @param exposure_prevalence Proportion of the population at that level (1
#'   for ambient air), in \code{[0, 1]}.
#' @param baseline_rate Cases per person-year in the unexposed scenario (a
#'   rate per person, not per 100,000: 0.008 is 800 per 100,000).
#' @param population At-risk population (persons; any non-negative number).
#' @param pollutant \code{"PM2.5"} (also written \code{"PM25"}) or
#'   \code{"NO2"}, in either case.
#' @param outcome Outcome key passed to the concentration-response function;
#'   \code{extra$unit} says whether the attributable count is deaths or
#'   incident cases.
#' @param reference_conc Counterfactual concentration; \code{NULL} takes the
#'   pollutant's default (PM2.5 5.8, NO2 10; see \code{\link{crf_pm25}}).
#' @param rare_outcome,high_rate \code{TRUE} to admit a baseline rate
#'   below 1e-5 (one per 100,000) or above 0.1 (10,000 per 100,000)
#'   per person-year, as \code{\link{verify_pollution}} does: without
#'   them such a rate is refused, being also what a rate in the wrong
#'   unit looks like.
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
                             reference_conc = NULL, rare_outcome = FALSE, high_rate = FALSE) {
  pol <- .pollution_pollutant(pollutant)
  if (is.na(pol)) {
    stop(sprintf("Unknown pollutant '%s'. Use 'PM2.5' or 'NO2'.", paste(pollutant, collapse = ",")),
         call. = FALSE)
  }
  exposure_mean <- .pollution_scalar(exposure_mean, "exposure_mean")
  exposure_prevalence <- .pollution_scalar(exposure_prevalence, "exposure_prevalence")
  # the same check mortality_displaced() makes: 800 is a rate per 100,000, and taken per
  # person-year it gave 110 million attributable deaths from a million people
  baseline_rate <- .pollution_rate_pp(.pollution_scalar(baseline_rate, "baseline_rate"), rare_outcome, high_rate)
  population <- .pollution_scalar(population, "population")
  if (!is.null(reference_conc)) {
    reference_conc <- .pollution_scalar(reference_conc, "reference_conc")
  }
  crf <- if (pol == "PM2.5") {
    crf_pm25(exposure_mean, outcome = outcome,
             reference_conc = if (is.null(reference_conc)) 5.8 else reference_conc)
  } else {
    crf_no2(exposure_mean, outcome = outcome,
            reference_conc = if (is.null(reference_conc)) 10 else reference_conc)
  }
  paf <- attributable_fraction(crf$rr, exposure_prevalence)
  baseline_cases <- baseline_rate * population
  structure(list(
    paf = paf,
    attributable_cases = paf * baseline_cases,
    baseline_cases = baseline_cases,
    population = population,
    baseline_rate = baseline_rate,
    exposure_mean = exposure_mean,
    reference_conc = crf$reference_conc,
    pollutant = pol,
    citation = paste0(crf$citation, "; Rothman et al. (2008) section 5"),
    extra = list(rr = crf$rr, log_rr = crf$log_rr, outcome = outcome,
                 unit = .pollution_outcome_unit(outcome))
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
  k_folds <- as.integer(.rmbl_num(k_folds, "k_folds", integer = TRUE))
  if (length(k_folds) != 1L || is.na(k_folds) || k_folds < 2L) stop("`k_folds` must be at least 2", call. = FALSE)
  for (cl in cols) {
    if (!is.numeric(df[[cl]])) {
      stop(sprintf("column `%s` must be numeric (a factor or character column is not a code)", cl), call. = FALSE)
    }
  }
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
  n_bootstrap <- .pollution_scalar(n_bootstrap, "n_bootstrap")
  if (n_bootstrap != round(n_bootstrap)) stop("`n_bootstrap` must be a whole number of resamples", call. = FALSE)
  n_bootstrap <- as.integer(n_bootstrap)
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
#' with \eqn{R_i = (rank_i - 0.5) / n} the fractional income rank (tied incomes
#' share their average rank, so the index does not depend on row order) and
#' the population covariance. Negative values mean lower-income units bear
#' more exposure. Both columns must be numeric: a factor or character income
#' is refused rather than ranked by its level codes, and exposures must be
#' non-negative.
#'
#' @param data A data frame.
#' @param exposure,income Column names.
#' @return A list of class \code{rmbl_equity} with \code{concentration_index},
#'   \code{interpretation}, \code{exposure_mean}, \code{citation} and
#'   \code{extra} (\code{n}, the covariance and the concentration curve).
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
  h <- .rmbl_num_input(df[[exposure]], exposure, allow_null = FALSE)
  inc <- .rmbl_num_input(df[[income]], income, allow_null = FALSE)
  if (any(!is.finite(h)) || any(!is.finite(inc))) {
    stop(sprintf("`%s` and `%s` must be finite", exposure, income), call. = FALSE)
  }
  if (any(h < 0)) stop(sprintf("`%s` must be non-negative: an exposure is a concentration", exposure), call. = FALSE)
  mu <- mean(h)
  if (mu <= 0) stop("Mean exposure is zero; concentration index undefined.", call. = FALSE)
  # mid-ranks, so tied incomes share a rank and the index does not depend on
  # the order the rows arrived in (all incomes equal gives exactly 0)
  ranks <- rank(inc, ties.method = "average")
  R <- (ranks - 0.5) / n
  cov_hr <- sum((h - mean(h)) * (R - mean(R))) / n
  ci <- 2 * cov_hr / mu
  # the concentration curve behind the index: cumulative exposure share against
  # cumulative population share, poorest first (ties broken by exposure, so the
  # curve is a function of the data, not of the row order)
  ord <- order(inc, h)
  curve <- data.frame(population = seq_len(n) / n, exposure = cumsum(h[ord]) / sum(h))
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
    exposure_mean = mu,
    citation = "Wagstaff, Paci & van Doorslaer (1991) Soc Sci Med 33(5):545-557",
    extra = list(n = n, cov_h_R = cov_hr, curve = curve)
  ), class = "rmbl_equity")
}

#' Per-area pollution burden
#'
#' Applies \code{\link{pollution_burden}} to every row of a table with one row
#' per area (forward sortation area, census tract, neighbourhood, ...) and
#' returns the rows sorted by attributable cases, worst first.
#'
#' @param area_table A data frame with one row per area; the exposure in
#'   micrograms per cubic metre, the population in persons and the baseline
#'   rate per person-year.
#' @param area_col,exposure_col,population_col,baseline_rate_col Column names.
#' @param pollutant,outcome,rare_outcome,high_rate Passed to
#'   \code{\link{pollution_burden}}.
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
                                     pollutant = "NO2", outcome = "all_cause_mortality",
                                     rare_outcome = FALSE, high_rate = FALSE) {
  required <- c(area_col, exposure_col, population_col, baseline_rate_col)
  missing <- setdiff(required, names(area_table))
  if (length(missing)) {
    stop(sprintf("area_table missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (!nrow(area_table)) stop("area_table has no rows", call. = FALSE)
  for (cl in c(exposure_col, population_col, baseline_rate_col)) {
    if (!is.numeric(area_table[[cl]])) {
      stop(sprintf("column `%s` must be numeric (a factor or character column is not a count)", cl), call. = FALSE)
    }
  }
  rows <- lapply(seq_len(nrow(area_table)), function(i) {
    r <- pollution_burden(
      exposure_mean = as.numeric(area_table[[exposure_col]][i]),
      exposure_prevalence = 1,
      baseline_rate = as.numeric(area_table[[baseline_rate_col]][i]),
      population = as.numeric(area_table[[population_col]][i]),
      pollutant = pollutant, outcome = outcome, rare_outcome = rare_outcome, high_rate = high_rate)
    out <- data.frame(a = area_table[[area_col]][i], stringsAsFactors = FALSE)
    names(out) <- area_col
    out[[exposure_col]] <- as.numeric(area_table[[exposure_col]][i])
    out[[population_col]] <- as.numeric(area_table[[population_col]][i])
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
                                   baseline_rate, population, reference, rare_outcome = FALSE,
                                   high_rate = FALSE) {
  top <- if (isTRUE(high_rate)) 1e5 else 1e4
  row <- function(name, ok, note) list(assumption = name, ok = isTRUE(ok), note = note)
  fin <- function(x) length(x) == 1L && is.finite(x)
  list(
    row("exposure finite and non-negative", fin(exposure_mean) && exposure_mean >= 0,
        if (!fin(exposure_mean) || exposure_mean < 0) {
          sprintf("exposure_mean=%s is not a finite non-negative concentration", format(exposure_mean))
        } else if (isTRUE(exposure_mean <= reference)) {
          sprintf("mean %s is at or below the counterfactual floor %s: no excess risk, PAF and cases are 0.",
                  format(exposure_mean, digits = 10), format(reference))
        } else {
          sprintf("mean %s vs ref %s", format(exposure_mean, digits = 10), format(reference))
        }),
    row("exposure within the concentration-response range (at most 10,000 ug/m3)",
        fin(exposure_mean) && exposure_mean <= 1e4,
        sprintf("exposure_mean=%s", format(exposure_mean))),
    row("prevalence in [0,1]", fin(exposure_prevalence) && exposure_prevalence >= 0 && exposure_prevalence <= 1,
        sprintf("exposure_prevalence=%s", format(exposure_prevalence))),
    # a rate below one per 100,000 (the rate as converted, whatever unit it came in) is real for
    # a rare outcome, and is also what a rate per person-year passed as per 100k looks like. The
    # caller says which with rare_outcome = TRUE: giving the unit is not enough, since a wrapper
    # or do.call() passes it routinely (review of 52a8883, A6; of 02a38be, C4). Below 1e-6 per
    # 100k (fewer than one case in the world's population over a lifetime) no rate is plausible.
    # the top of the band is 10,000 per 100k (no population's all-cause death rate comes close);
    # high_rate = TRUE admits a more common outcome, up to every person every year
    row(sprintf("baseline_rate finite: zero, or between %s and %s per 100k%s",
                if (isTRUE(rare_outcome)) "1e-6" else "1", format(top, big.mark = ",", scientific = FALSE),
                if (isTRUE(rare_outcome)) " (a rare outcome)" else ""),
        fin(baseline_rate) && baseline_rate >= 0 && baseline_rate <= top &&
          (baseline_rate == 0 || baseline_rate >= 1 || (isTRUE(rare_outcome) && baseline_rate >= 1e-6)),
        if (fin(baseline_rate) && baseline_rate < 1e-6 && baseline_rate > 0) {
          sprintf(paste("baseline_rate=%s per 100k is below one case per 100 billion person-years: not a",
                        "usable rate (check baseline_rate_per)"), format(baseline_rate))
        } else if (fin(baseline_rate) && baseline_rate < 1 && baseline_rate > 0 && !isTRUE(rare_outcome)) {
          sprintf(paste("baseline_rate=%s per 100k is below one case per 100,000. If it is a rate per person-year",
                        "(0.012 is 1,200 per 100k), pass baseline_rate_per = 1; if the outcome really is this",
                        "rare, say so with rare_outcome = TRUE"),
                  format(baseline_rate))
        } else if (fin(baseline_rate) && baseline_rate > top && baseline_rate <= 1e5) {
          sprintf(paste("baseline_rate=%s per 100k a year is above a whole population's all-cause death rate",
                        "(an age-specific rate for the oldest ages can be this high): if the outcome really is",
                        "this common, say so with high_rate = TRUE"),
                  format(baseline_rate, big.mark = ",", scientific = FALSE))
        } else if (fin(baseline_rate) && baseline_rate == 0) {
          "baseline_rate=0: a measured zero rate, so no cases"
        } else {
          sprintf("baseline_rate=%s per 100k per year", format(baseline_rate))
        }),
    row("population finite, positive and at most 10 billion", fin(population) && population > 0 && population <= 1e10,
        if (fin(population) && population > 1e10) {
          sprintf("population=%s is more people than live on Earth",
                  format(population, big.mark = ",", scientific = FALSE))
        } else {
          sprintf("population=%s", format(population, big.mark = ",", scientific = FALSE))
        }),
    row("reference finite and non-negative", fin(reference) && reference >= 0,
        sprintf("reference=%s", format(reference))),
    row("pollutant supported by the CRFs", !is.na(.pollution_pollutant(pollutant)),
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
#' @param pollutant \code{"no2"} or \code{"pm25"} (also \code{"PM2.5"}), in
#'   either case.
#' @param outcome Outcome key for the concentration-response function; the
#'   mortality outcomes count deaths, \code{"childhood_asthma"} incident
#'   cases.
#' @param region,years Labels for the report.
#' @param demo Use synthetic demo data (\code{TRUE} or \code{FALSE}).
#' @param exposure_csv Path of a CSV with an \code{exposure} column in
#'   micrograms per cubic metre, or a NAPS pull with a \code{value} column
#'   and a \code{unit} column (required with \code{value}): each row is
#'   converted by its own unit, NO2 in ppb at 1.88 micrograms per cubic metre
#'   per ppb (the WHO 2021 conversion at 25 C and 1 atm), and any other unit
#'   is an error. With a CSV or the demo data the exposed are the rows above
#'   \code{reference}: \code{exposure_prevalence} is their share and
#'   \code{exposure_mean} their mean, so Levin's formula is not diluted twice.
#' @param exposure_mean,exposure_prevalence Scalar inputs used when neither
#'   \code{demo} nor \code{exposure_csv} is given: the mean exposure among
#'   the exposed and the share of the population exposed.
#'   A wrapper must never default one of them to zero: a prevalence of zero silently zeroes
#'   the burden, which is why the two are required together.
#' @param reference Counterfactual reference concentration; \code{NULL} takes
#'   the pollutant's default (PM2.5 5.8, NO2 10; see \code{\link{crf_pm25}}).
#' @param baseline_rate_per The denominator \code{baseline_rate} is quoted per: 100,000
#'   (the default), or 1 for a rate per person-year such as a crude death rate of 0.012.
#' @param rare_outcome \code{TRUE} when the outcome really is rarer than one case per 100,000
#'   per year. Without it a rate that converts to less than that is an assumption failure,
#'   because it is also what a rate per person-year passed as per 100,000 looks like (0.008
#'   per person-year is 800 per 100,000; as 0.008 per 100,000 the burden is 100,000 times too
#'   small). The check is on the converted rate, so it holds whatever
#'   \code{baseline_rate_per} is.
#' @param high_rate \code{TRUE} when the outcome really is more common
#'   than 10,000 per 100,000 a year (no population's all-cause death
#'   rate is); without it such a rate is an assumption failure.
#' @param baseline_rate Baseline outcome rate per 100,000 per year (unlike
#'   \code{\link{pollution_burden}}, which takes a rate per person-year).
#' @param population Population at risk (persons).
#' @param report A result of \code{verify_pollution()}.
#' @return \code{verify_pollution()}: the report as a list of class
#'   \code{rmbl_pollution_report} (\code{plot()} draws it); its \code{status}
#'   is \code{"ok"}, \code{"assumption_failure"} or \code{"error"}, and the
#'   attribute \code{exit_status} carries a command-line exit code (0, 1 or
#'   2). An argument the pipeline cannot use (no exposure data at all, a
#'   vector where a single number is expected, an unknown outcome, a missing
#'   reference, a directory as \code{exposure_csv}) is an \code{"error"}
#'   report with exit status 2, never a raw R error; an exposure at or below
#'   the reference is a valid run with zero attributable cases, and the
#'   scalar inputs \code{exposure_mean} and \code{exposure_prevalence} go
#'   together (one without the other is an error report).
#'   \code{pollution_report_text()}: a character string.
#' @examples
#' r <- verify_pollution("no2", demo = TRUE)
#' r$status
#' r$pipeline$paf
#' cat(pollution_report_text(r))
#' @export
verify_pollution <- function(pollutant, outcome = "all_cause_mortality", region = NULL,
                             years = NULL, demo = FALSE, exposure_csv = NULL,
                             exposure_mean = NULL, exposure_prevalence = NULL, reference = NULL,
                             baseline_rate = 500, baseline_rate_per = 1e5, population = 1e6,
                             rare_outcome = FALSE, high_rate = FALSE) {
  pol <- .pollution_pollutant(pollutant)
  pollutant <- if (is.na(pol)) tolower(as.character(pollutant)) else if (pol == "NO2") "no2" else "pm25"
  equity_df <- NULL
  fail <- function(msg) {
    structure(list(status = "error", error = msg), exit_status = 2L,
              class = c("rmbl_pollution_report", "list"))
  }
  # the input contract is part of the report: an argument the pipeline cannot use is an
  # "error" report with exit status 2, never a raw stop() or a silently truncated vector
  if (!is.logical(demo) || length(demo) != 1L || is.na(demo)) return(fail("demo must be TRUE or FALSE"))
  if (is.null(reference)) reference <- if (identical(pollutant, "no2")) 10 else 5.8
  # the scalar inputs go together: a mean without a prevalence (or the reverse) is not a run
  # with the other at zero, it is half of the data
  no_scalar_data <- is.null(exposure_mean) && is.null(exposure_prevalence)
  # one source of exposure: a CSV or the demo with scalars beside it is two answers to one question
  if (isTRUE(demo) && !is.null(exposure_csv)) {
    return(fail(paste("exposure_csv and demo = TRUE are two sources of exposure: pass one",
                      "(the demo was used silently before)")))
  }
  if ((isTRUE(demo) || !is.null(exposure_csv)) && !no_scalar_data) {
    return(fail(paste("exposure_mean / exposure_prevalence cannot be combined with exposure_csv or demo:",
                      "pass one source of exposure")))
  }
  if (xor(is.null(exposure_mean), is.null(exposure_prevalence))) {
    return(fail("exposure_mean and exposure_prevalence go together: pass both (a zero is a measurement), or neither"))
  }
  # the two population inputs have defaults, not an "absent" value: NULL is a wrong call
  if (is.null(population)) return(fail("population must be a single number (persons at risk), not NULL"))
  # a number is numeric: as.raw(25) was read as 25 (review of 02a38be)
  scalars <- c("exposure_mean", "exposure_prevalence", "baseline_rate", "baseline_rate_per", "population", "reference")
  for (nm in scalars) {
    v <- get(nm)
    # a missing value (NA) is not a type error: the checks below report it
    if (!is.null(v) && !is.numeric(v) && !(is.logical(v) && all(is.na(v)))) {
      return(fail(sprintf("%s must be a single number, not %s", nm, class(v)[1L])))
    }
  }
  if (is.null(baseline_rate)) return(fail("baseline_rate must be a single number, not NULL"))
  if (!is.logical(rare_outcome) || length(rare_outcome) != 1L || is.na(rare_outcome)) {
    return(fail("rare_outcome must be TRUE or FALSE"))
  }
  if (!is.logical(high_rate) || length(high_rate) != 1L || is.na(high_rate)) {
    return(fail("high_rate must be TRUE or FALSE"))
  }
  if (!is.numeric(baseline_rate_per) || length(baseline_rate_per) != 1L || !is.finite(baseline_rate_per) ||
        baseline_rate_per <= 0) {
    return(fail(paste("baseline_rate_per must be a single positive number",
                      "(100000 for a rate per 100,000, 1 per person-year)")))
  }
  for (nm in c("reference", "exposure_mean", "exposure_prevalence", "baseline_rate", "population")) {
    v <- get(nm, inherits = FALSE)
    if (is.null(v)) next
    if (length(v) != 1L) return(fail(sprintf("%s must be a single number, not %d values", nm, length(v))))
    # a flag, text, a date or a factor is not a number; a missing value (NA) is logged as a
    # failed assumption below
    if (is.list(v) || is.complex(v)) return(fail(sprintf("%s must be a single number, not a %s", nm, class(v)[1L])))
    if ((is.logical(v) && !is.na(v)) || is.factor(v) || inherits(v, c("Date", "POSIXt", "difftime")) ||
          (!is.numeric(v) && !is.na(v) && is.na(suppressWarnings(as.numeric(v))))) {
      return(fail(sprintf("%s must be a single number", nm)))
    }
  }
  reference <- suppressWarnings(as.numeric(reference))
  if (!is.character(outcome) || length(outcome) != 1L || is.na(outcome)) {
    return(fail("outcome must be a single outcome name"))
  }
  # the exposed are the rows above the counterfactual floor: Levin's formula wants the
  # relative risk among them and their share, not the population mean twice over
  exposed_summary <- function(x) {
    x <- x[!is.na(x)]
    above <- if (is.finite(reference)) x[x > reference] else x
    list(mean = if (length(above)) mean(above) else if (length(x)) mean(x) else NA_real_,
         prevalence = if (length(x)) length(above) / length(x) else NA_real_)
  }
  dropped_rows <- 0L
  if (isTRUE(demo)) {
    df <- .pollution_demo_data(pollutant)
    es <- exposed_summary(df$exposure)
    exposure_mean <- es$mean
    exposure_prevalence <- es$prevalence
    equity_df <- df
    data_source <- "demo (synthetic)"
  } else if (!is.null(exposure_csv)) {
    if (!is.character(exposure_csv) || length(exposure_csv) != 1L || is.na(exposure_csv)) {
      return(fail("exposure_csv must be a single file path"))
    }
    if (!file.exists(exposure_csv)) return(fail(sprintf("exposure CSV not found: %s", exposure_csv)))
    if (dir.exists(exposure_csv)) return(fail(sprintf("exposure CSV is a directory, not a file: %s", exposure_csv)))
    empty <- sprintf("%s is empty (expected a column exposure in ug/m3, or a NAPS pull's value + unit)", exposure_csv)
    if (isTRUE(file.size(exposure_csv) == 0)) return(fail(empty))
    df <- tryCatch(.pollution_read_csv(exposure_csv), error = function(e) e)
    if (inherits(df, "error")) return(fail(sprintf("%s: %s", exposure_csv, conditionMessage(df))))
    if (!nrow(df)) return(fail(empty))
    raw_exposure <- NULL
    naps <- FALSE
    if (!"exposure" %in% names(df) && "value" %in% names(df)) {
      naps <- TRUE
      # a NAPS pull: hourly `value` in `unit`, converted row by row; NO2 is reported in ppb
      if (!"unit" %in% names(df)) {
        return(fail("a 'value' column needs a 'unit' column (NAPS pulls carry one; NO2 is in ppb)"))
      }
      # the text as read goes to the shared check below: converted first, "<2" became NA and was
      # counted as a row with no measurement (ok, prevalence 1.0 instead of 0.4; review of
      # 02a38be, C5), where the same column named exposure is refused
      if (is.character(df$value)) raw_exposure <- trimws(df$value)
      vals <- suppressWarnings(as.numeric(df$value))
      unit <- tolower(trimws(as.character(df$unit)))
      ugm3 <- c("ug/m3", "\u00b5g/m3", "\u00b5g/m\u00b3", "ug/m\u00b3")
      is_ppb <- unit %in% c("ppb", "ppbv")
      bad <- !is.na(vals) & !(unit %in% ugm3) & !(is_ppb & pollutant == "no2")
      if (any(bad)) {
        return(fail(sprintf("exposure unit %s is not ug/m3 for %s",
                            paste(sort(unique(unit[bad])), collapse = ", "), pollutant)))
      }
      if (any(is_ppb & !is.na(vals))) {
        vals[is_ppb] <- vals[is_ppb] * 1.88  # ug/m3 per ppb of NO2 at 25 C and 1 atm (WHO 2021)
        message(sprintf("note: %d NO2 row(s) in ppb converted to ug/m3 (x 1.88)", sum(is_ppb & !is.na(vals))))
      }
      df$exposure <- vals
    }
    if (!"exposure" %in% names(df)) {
      return(fail("CSV missing 'exposure' column (ug/m3); a NAPS pull's 'value' column also works."))
    }
    # only a text column can hold text: a column read.csv parsed as numbers is not converted back
    # to text to be searched (15 of 24 s on a 102 MB file went to that; review of 02a38be)
    if (!naps && is.character(df$exposure)) raw_exposure <- trimws(df$exposure)
    df$exposure <- suppressWarnings(as.numeric(df$exposure))
    # an empty cell or a missing-value token is a row without a measurement: dropped, and the
    # report says how many. Text that is not a number ("<2", a detection-limit flag) is a
    # measurement the reader cannot use: dropping it biased the mean and the prevalence (60% of
    # rows dropped and status ok, review of 52a8883), so the run stops and names them
    text_rows <- FALSE
    if (!is.null(raw_exposure)) {
      missing_tok <- is.na(raw_exposure) |
        tolower(raw_exposure) %in% c("", "na", "n/a", "nan", "null", "-", ".", "missing")
      text_rows <- is.na(df$exposure) & !missing_tok
    }
    if (any(text_rows)) {
      ex <- utils::head(unique(raw_exposure[text_rows]), 3L)
      return(fail(sprintf(paste("%d exposure value(s) are text, not numbers (%s): a censored value such as \"<2\"",
                                "is a measurement, and dropping it would bias the mean and the prevalence; replace",
                                "them (for example with half the detection limit) or remove those rows"),
                          sum(text_rows), paste(sprintf("\"%s\"", ex), collapse = ", "))))
    }
    dropped_rows <- sum(is.na(df$exposure))
    if (dropped_rows > 0L) {
      message(sprintf("note: %d row(s) have no exposure value and were dropped", dropped_rows))
    }
    if (any(df$exposure < 0, na.rm = TRUE)) {
      n_neg <- sum(df$exposure < 0, na.rm = TRUE)
      return(fail(sprintf("%d exposure value(s) are negative: a concentration cannot be", n_neg)))
    }
    es <- exposed_summary(df$exposure)
    exposure_mean <- es$mean
    exposure_prevalence <- es$prevalence
    if ("income" %in% names(df) && all(is.na(df$income))) {
      message("note: the income column is empty: no equity analysis")
      df$income <- NULL
    }
    if ("income" %in% names(df)) {
      if (!is.numeric(df$income)) {
        return(fail("the income column must be numeric (a quintile or an amount); text cannot be ranked"))
      }
      equity_df <- df
    }
    data_source <- exposure_csv
  } else {
    exposure_mean <- as.numeric(exposure_mean)
    exposure_prevalence <- as.numeric(exposure_prevalence)
    data_source <- "scalar arguments"
    # neither given is no data at all: a call with nothing to verify, not a clean run with zero
    # deaths; a missing or negative value is a failed assumption, logged below
    if (no_scalar_data) {
      return(fail(paste("no exposure data: pass exposure_csv, or exposure_mean and exposure_prevalence,",
                        "or demo = TRUE")))
    }
  }
  baseline_rate <- as.numeric(baseline_rate) * 1e5 / baseline_rate_per   # per 100,000 from here on
  population <- as.numeric(population)
  assumptions <- .pollution_assumptions(pollutant, exposure_mean, exposure_prevalence,
                                        baseline_rate, population, reference, rare_outcome, high_rate)
  report <- list(
    command = "verify-pollution", pollutant = pollutant, outcome = outcome,
    region = region, years = years, data_source = data_source,
    inputs = list(exposure_mean = exposure_mean, exposure_prevalence = exposure_prevalence,
                  baseline_rate_per_100k = baseline_rate, population = population,
                  reference_conc = reference, dropped_rows = dropped_rows),
    assumptions = assumptions)
  if (!all(vapply(assumptions, function(a) isTRUE(a$ok), logical(1)))) {
    report$status <- "assumption_failure"
    report$pipeline <- list(skipped = TRUE, reason = "assumptions")
    return(structure(report, exit_status = 1L, class = c("rmbl_pollution_report", "list")))
  }
  crf <- tryCatch(
    if (pollutant == "no2") {
      crf_no2(exposure_mean, outcome = outcome, reference_conc = reference)
    } else {
      crf_pm25(exposure_mean, outcome = outcome, reference_conc = reference)
    },
    error = function(e) e)
  if (inherits(crf, "error")) return(fail(conditionMessage(crf)))
  paf <- tryCatch(attributable_fraction(crf$rr, exposure_prevalence,
                                        rr_lower = if (is.finite(crf$rr_lower)) crf$rr_lower,
                                        rr_upper = if (is.finite(crf$rr_upper)) crf$rr_upper),
                  error = function(e) e)
  if (inherits(paf, "error")) return(fail(conditionMessage(paf)))
  paf_ci <- attr(paf, "ci")
  baseline_per_person <- baseline_rate / 1e5
  exposure_delta <- max(0, exposure_mean - reference)
  beta_per_unit <- log(crf$rr) / max(exposure_delta, 1e-9)
  # the deaths displaced by removing the excess exposure are counted over the exposed share of the
  # population, and the burden uses the same reference concentration as the RR printed above it
  # every stage runs inside the status contract: what it refuses is an "error" report, never a
  # raw condition out of verify_pollution()
  staged <- tryCatch({
    # the rate's band was checked above, with the caller's switches: they go to the stages too, or
    # a rate the caller vouched for (high_rate, rare_outcome) was refused again by the stage
    displaced <- mortality_displaced(exposure_delta, population * exposure_prevalence,
                                     baseline_per_person, beta_per_unit,
                                     rare_outcome = rare_outcome, high_rate = high_rate)
    burden <- pollution_burden(exposure_mean, exposure_prevalence, baseline_per_person, population,
                               pollutant = if (pollutant == "pm25") "PM2.5" else "NO2",
                               outcome = outcome, reference_conc = reference,
                               rare_outcome = rare_outcome, high_rate = high_rate)
    equity <- if (!is.null(equity_df) && "income" %in% names(equity_df)) {
      complete <- sum(is.finite(equity_df$exposure) & is.finite(suppressWarnings(as.numeric(equity_df$income))))
      if (complete < 2L || !any(equity_df$exposure > 0, na.rm = TRUE)) {
        NULL  # one usable row, or no exposure anywhere: there is no gradient to measure
      } else {
        exposure_concentration_index(equity_df, "exposure", "income")
      }
    }
    list(displaced = displaced, burden = burden, equity = equity)
  }, error = function(e) e)
  if (inherits(staged, "error")) return(fail(conditionMessage(staged)))
  displaced <- staged$displaced
  burden <- staged$burden
  equity <- staged$equity
  report$status <- "ok"
  report$pipeline <- list(
    crf = unclass(crf), paf = as.numeric(paf), paf_ci = paf_ci,
    displaced = list(deaths_displaced = displaced, exposure_delta = exposure_delta,
                     beta_per_unit = beta_per_unit, unit = .pollution_outcome_unit(outcome)),
    burden = unclass(burden),
    equity = if (is.null(equity)) NULL else unclass(equity))
  structure(report, exit_status = 0L, class = c("rmbl_pollution_report", "list"))
}

.pollution_paf_ci_text <- function(ci) {
  if (is.null(ci)) return("")
  sprintf("  (95%% CI %.4f to %.4f, from the risk's limits)", ci[["lower"]], ci[["upper"]])
}

#' @rdname verify_pollution
#' @export
pollution_report_text <- function(report) {
  if (!inherits(report, "rmbl_pollution_report") && !(is.list(report) && is.character(report$status))) {
    stop("`report` must be a report from verify_pollution()", call. = FALSE)
  }
  bar <- strrep("=", 66)
  if (identical(report$status, "error")) return(paste0("ERROR: ", report$error, "\n"))
  # a list that only looks like a report (status "ok" and no inputs) is refused in words, not with
  # "$ operator is invalid for atomic vectors"
  parts_ok <- is.list(report$inputs) && is.list(report$assumptions) &&
    all(vapply(report$assumptions, function(a) is.list(a) && is.logical(a$ok), logical(1))) &&
    (!identical(report$status, "ok") || is.list(report$pipeline))
  if (!parts_ok) {
    stop("`report` is not a complete verify_pollution() report (its inputs, assumptions or pipeline are missing)",
         call. = FALSE)
  }
  lines <- c(bar, sprintf("  %s -- %s -> %s", report$command, toupper(report$pollutant), report$outcome))
  if (!is.null(report$region)) lines <- c(lines, sprintf("  region: %s", report$region))
  if (!is.null(report$years)) lines <- c(lines, sprintf("  years:  %s", report$years))
  inp <- report$inputs
  lines <- c(lines, sprintf("  data:   %s", report$data_source), bar, "", "Inputs",
             sprintf("  exposure mean:      %.3f", inp$exposure_mean),
             sprintf("  exposure prevalence:%.3f", inp$exposure_prevalence),
             sprintf("  baseline rate/100k: %.2f", inp$baseline_rate_per_100k),
             sprintf("  population:         %s", format(inp$population, big.mark = ",", scientific = FALSE)),
             sprintf("  reference conc:     %s", format(inp$reference_conc)),
             if (isTRUE(inp$dropped_rows > 0)) {
               sprintf("  rows dropped:       %d (no exposure value)", inp$dropped_rows)
             },
             "", "Assumption log")
  for (a in report$assumptions) {
    lines <- c(lines, sprintf("  [%s] %s -- %s", if (isTRUE(a$ok)) "PASS" else if (isFALSE(a$ok)) "FAIL" else "NA",
                              a$assumption, a$note))
  }
  if (identical(report$status, "assumption_failure")) {
    return(paste0(paste(lines, collapse = "\n"), "\n\nSTATUS: assumption_failure (pipeline skipped)\n"))
  }
  p <- report$pipeline
  lines <- c(lines, "", "Concentration-response", sprintf("  RR:       %.4f", p$crf$rr),
             sprintf("  source:   %s", p$crf$citation),
             "", sprintf("Attributable fraction (PAF): %.4f%s", p$paf, .pollution_paf_ci_text(p$paf_ci)),
             "", if (identical(p$displaced$unit, "deaths")) "Mortality displaced" else "Cases displaced",
             sprintf("  expected avoided %s: %.1f", p$displaced$unit %||% "deaths",
                     p$displaced$deaths_displaced),
             "", "Burden of pollution",
             sprintf("  attributable %s:   %.1f", p$burden$extra$unit %||% "deaths",
                     p$burden$attributable_cases))
  if (!is.null(p$equity)) {
    lines <- c(lines, "", "Equity analysis",
               sprintf("  concentration index: %.4f", p$equity$concentration_index))
  }
  paste0(paste(lines, collapse = "\n"), "\n\nSTATUS: ok\n")
}

# The exposure CSV, read whole: a gzip, bzip2 or xz file is decompressed (as read.csv did
# before 0.5.12, review of 52a8883, A4) and checked to be complete (.rmbl_decompress_checked), a
# UTF-16 file is decoded with or without its byte-order mark, a UTF-8 BOM is dropped, a file that
# is not UTF-8 is read as Latin-1 (and said), other NUL bytes are refused. A parse that reports a
# problem (an unbalanced quote that swallowed the rest of the file, A5) stops with the parser's
# own message instead of returning the rows before it.
.pollution_read_csv <- function(path) {
  head <- readBin(path, "raw", 6L)
  compressed <- length(head) >= 2L && (identical(head[1:2], as.raw(c(0x1f, 0x8b))) ||
    (length(head) >= 3L && identical(head[1:3], charToRaw("BZh"))) ||
    (length(head) >= 6L && identical(head[1:6], as.raw(c(0xfd, 0x37, 0x7a, 0x58, 0x5a, 0x00)))))
  if (compressed) {
    raw <- .rmbl_decompress_checked(path, head)
  } else {
    raw <- readBin(path, "raw", file.size(path))
  }
  if (!length(raw)) return(data.frame())
  note <- NULL
  utf16 <- NULL
  # UTF-32 first: its little-endian mark starts with the UTF-16 one (FF FE 00 00), and decoded as
  # UTF-16 it put a kilobyte of the file into the "embedded nul" message (review of 02a38be)
  if (length(raw) >= 4L && identical(raw[1:4], as.raw(c(0xff, 0xfe, 0, 0)))) {
    utf16 <- "UTF-32LE"
    raw <- raw[-(1:4)]
  } else if (length(raw) >= 4L && identical(raw[1:4], as.raw(c(0, 0, 0xfe, 0xff)))) {
    utf16 <- "UTF-32BE"
    raw <- raw[-(1:4)]
  } else if (length(raw) >= 2L && identical(raw[1:2], as.raw(c(0xff, 0xfe)))) {
    utf16 <- "UTF-16LE"
    raw <- raw[-(1:2)]
  } else if (length(raw) >= 2L && identical(raw[1:2], as.raw(c(0xfe, 0xff)))) {
    utf16 <- "UTF-16BE"
    raw <- raw[-(1:2)]
  } else if (length(grepRaw(as.raw(0L), raw, fixed = TRUE))) {
    # UTF-16 without a byte-order mark: ASCII text puts a NUL in every other byte
    probe <- raw[seq_len(min(length(raw), 2000L))]
    odd <- probe[seq(1L, length(probe), by = 2L)]
    even <- probe[seq(2L, length(probe), by = 2L)]
    if (mean(even == as.raw(0L)) > 0.9 && mean(odd == as.raw(0L)) < 0.1) {
      utf16 <- "UTF-16LE"
    } else if (mean(odd == as.raw(0L)) > 0.9 && mean(even == as.raw(0L)) < 0.1) {
      utf16 <- "UTF-16BE"
    } else {
      stop("contains NUL bytes and is not UTF-16 text: not a text CSV", call. = FALSE)
    }
    note <- sprintf("note: %s has no byte-order mark; read as %s", basename(path), utf16)
  }
  transformed <- compressed || !is.null(utf16)
  if (!is.null(utf16)) {
    txt <- iconv(list(raw), from = utf16, to = "UTF-8")[[1L]]
    if (is.null(txt) || is.na(txt)) stop(sprintf("cannot be decoded as %s", utf16), call. = FALSE)
  } else {
    if (length(raw) >= 3L && identical(raw[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
      raw <- raw[-(1:3)]
      transformed <- TRUE
    }
    txt <- rawToChar(raw)
    if (!validUTF8(txt)) {
      txt <- iconv(txt, from = "latin1", to = "UTF-8")
      note <- sprintf("note: %s is not UTF-8; read as Latin-1 (ISO-8859-1)", basename(path))
      transformed <- TRUE
    }
  }
  rm(raw)
  if (!is.null(note)) message(note)
  Encoding(txt) <- "UTF-8"
  # blank or not: one search that stops at the first non-blank character (trimws() ran two regular
  # expressions over the whole text, a pass the size of the file; review of e57fed5)
  if (!grepl("[^[:space:]]", txt, perl = TRUE)) return(data.frame())
  src <- path
  if (transformed) {
    # the decoded text goes through a file, which read.csv parses in C: text = goes through a
    # text connection, several times slower on a large file
    src <- tempfile(fileext = ".csv")
    on.exit(unlink(src), add = TRUE)
    writeLines(txt, src, useBytes = TRUE)
  }
  rm(txt)
  # every row has the header's number of fields: read.csv wrapped a row with too many into an extra
  # row, and a header with a name twice read only the first of the two columns (review of 02a38be)
  hdr <- names(utils::read.csv(src, nrows = 1L, check.names = FALSE, encoding = "UTF-8"))
  dup <- unique(hdr[duplicated(tolower(trimws(hdr)))])
  if (length(dup)) {
    stop(sprintf("has the column name %s more than once: say which column is meant",
                 paste(sprintf("'%s'", dup), collapse = ", ")), call. = FALSE)
  }
  nf <- utils::count.fields(src, sep = ",", quote = "\"", blank.lines.skip = TRUE, comment.char = "")
  wrong <- which(!is.na(nf) & nf != length(hdr))
  if (length(wrong)) {
    stop(sprintf(paste("line %d has %d fields where the header has %d:",
                       "no rows are used from a file whose rows do not line up"),
                 wrong[[1L]], nf[[wrong[[1L]]]], length(hdr)), call. = FALSE)
  }
  problems <- character()
  df <- withCallingHandlers(
    utils::read.csv(src, stringsAsFactors = FALSE, encoding = "UTF-8"),
    warning = function(w) {
      m <- conditionMessage(w)
      if (!grepl("incomplete final line", m, fixed = TRUE)) problems <<- c(problems, m)
      invokeRestart("muffleWarning")
    })
  if (length(problems)) {
    stop(sprintf("could not be read cleanly (%s): no rows are used from a file the parser stopped part-way through",
                 problems[[1L]]), call. = FALSE)
  }
  df
}

# A compressed CSV, decompressed whole and checked to be complete. R's gzfile() returns whatever
# a truncated gzip or bzip2 file decodes to, with no error and no warning, so half a file was read
# as a whole one (review of 02a38be, C3). gzip goes through zlib in C (every member's CRC-32 and
# length checked); a bzip2 file must end with its end-of-stream marker; an xz decoder warning
# ("lzma decoding result 10" for a cut file) is an error. The output is capped while it is read
# (option rmoriebricklayer.max_csv_bytes, 1 GiB by default): a few megabytes of gzip no longer
# expand to gigabytes before anything is refused.
.rmbl_decompress_checked <- function(path, head = readBin(path, "raw", 6L)) {
  lim <- getOption("rmoriebricklayer.max_csv_bytes", 2^30)
  if (!is.numeric(lim) || length(lim) != 1L || is.na(lim) || lim < 0)
    stop("option rmoriebricklayer.max_csv_bytes must be a single non-negative number", call. = FALSE)
  lim <- min(lim, 2^31 - 2)   # rawToChar() takes at most 2^31 - 1 bytes
  if (length(head) >= 2L && identical(head[1:2], as.raw(c(0x1f, 0x8b)))) {
    return(.Call(C_rmbl_gunzip_checked, readBin(path, "raw", file.size(path)), lim))
  }
  bz <- length(head) >= 3L && identical(head[1:3], charToRaw("BZh"))
  if (bz && !.rmbl_bzip2_complete(path))
    stop("is truncated: the bzip2 stream has no end-of-stream marker", call. = FALSE)
  con <- gzfile(path, "rb")   # bzip2 and xz
  on.exit(close(con))
  chunks <- list()
  total <- 0
  withCallingHandlers({
    repeat {
      b <- readBin(con, "raw", 4194304L)
      if (!length(b)) break
      total <- total + length(b)
      if (total > lim) stop("decompresses to more than the size limit", call. = FALSE)
      chunks[[length(chunks) + 1L]] <- b
    }
  }, warning = function(w) {
    stop(sprintf("is truncated or damaged (the decoder said: %s)", conditionMessage(w)), call. = FALSE)
  })
  do.call(c, chunks)
}

# A bzip2 stream ends with the 48-bit end-of-stream magic 0x177245385090, a 32-bit CRC and zero
# padding to the next byte; none of it is byte-aligned. A file cut anywhere before its end lacks
# it in its last 11 bytes.
.rmbl_bzip2_complete <- function(path) {
  n <- file.size(path)
  if (is.na(n) || n < 14) return(FALSE)
  con <- file(path, "rb")
  on.exit(close(con))
  seek(con, n - 11)
  tail <- readBin(con, "raw", 11L)
  bits <- unlist(lapply(tail, function(b) rev(as.integer(rawToBits(b)))))

  magic <- unlist(lapply(as.raw(c(0x17, 0x72, 0x45, 0x38, 0x50, 0x90)), function(b) rev(as.integer(rawToBits(b)))))
  for (p in 1:8) {   # magic at bit p (0-based), then 32 CRC bits, then 0-7 zero padding bits
    if (identical(bits[(p + 1):(p + 48)], magic) && all(bits[seq_len(88) > p + 80] == 0L)) return(TRUE)
  }
  FALSE
}
