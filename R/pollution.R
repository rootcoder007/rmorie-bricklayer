# SPDX-License-Identifier: AGPL-3.0-or-later
# Air pollution and health: concentration-response functions, the
# attributable fraction, displaced mortality, the burden chain, a cross-fitted
# partially linear exposure-response estimator with a bootstrap, the
# concentration index of exposure by income, and a one-call pipeline with an
# assumption log. Every formula cites the paper it implements. The functions
# mirror rmorie's envhealth module (and morie's Python envhealth) formula for
# formula; see exprspplr() for the one seam that differs.

#' Builds an `rmbl_crf` object from a concentration-response curve evaluated at the exposures.
#' @param rr The relative risk at each exposure.
#' @param log_rr Its logarithm.
#' @param z The exposures.
#' @param scalar Whether one exposure was given (the object then holds its values, not means).
#' @param reference_conc The counterfactual concentration.
#' @param pollutant The pollutant's name.
#' @param citation The source of the curve.
#' @param extra Further fields kept in the object's `extra` list.
#' @param rr_lower The lower 95 percent limit of the relative risk, or NA.
#' @param rr_upper The upper 95 percent limit, or NA.
#' @return An object of class `rmbl_crf`.
#' @noRd
.crf_object <- function(rr, log_rr, z, scalar, reference_conc, pollutant, citation, extra,
                        rr_lower = NA_real_, rr_upper = NA_real_) {
  structure(list(
    rr = if (scalar) rr[[1L]] else mean(rr),
    logrr = if (scalar) log_rr[[1L]] else mean(log_rr),
    # the published 95 percent limits of the relative risk, carried through the same curve
    # (NA for the IER forms, whose papers give no interval on the pooled parameters)
    rrlo = if (scalar) rr_lower[[1L]] else mean(rr_lower),
    rrup = if (scalar) rr_upper[[1L]] else mean(rr_upper),
    refconc = reference_conc,
    expconc = if (scalar) z[[1L]] else mean(z),
    pollutant = pollutant,
    citation = citation,
    extra = c(extra, list(rrperunit = if (scalar) NULL else rr))
  ), class = "rmbl_crf")
}

#' Concentration-response functions for PM2.5 and NO2
#'
#' A concentration-response function (CRF) turns an air-pollution
#' concentration into the relative risk (RR) of a health outcome compared
#' with a counterfactual \dQuote{clean air} level: an RR of 1.05 means 5% more
#' deaths (or cases) than at the reference concentration. These are the
#' first step of any burden estimate; \code{\link{polbrdn}} and
#' \code{\link{vrfpol}} call them for you.
#'
#' @details
#' \code{crfpm25()} is log-linear for all-cause mortality with the pooled
#' cohort estimate of the WHO 2021 guideline review (Chen and Hoek 2020:
#' RR 1.08, 95% CI 1.06-1.09, per 10 micrograms per cubic metre),
#' \deqn{RR(z) = \exp(\ln(1.08) (z - z_{cf}) / 10)}
#' for \eqn{z > z_{cf}} and 1 otherwise; for the cause-specific outcomes
#' (ischaemic heart disease, stroke) it is the Integrated Exposure-Response
#' curve of Burnett et al. (2014, equation 1),
#' \deqn{RR(z) = 1 + \alpha (1 - e^{-\gamma (z - z_{cf})^{\delta}}),}
#' with the GBD 2013 parameter triples; the IER was fitted per cause and has no
#' all-cause form. \code{crfno2()} is the log-linear function of the WHO 2021
#' review (Huangfu and Atkinson 2020: RR 1.02, 95% CI 1.01-1.04, per 10
#' micrograms per cubic metre for all-cause mortality),
#' \deqn{RR(z) = \exp(\beta (z - z_{cf}) / 10).}
#' A vector of exposures gives the mean RR and log-RR. The per-unit
#' relative risks are then in \code{extra$rrperunit}.
#'
#' Every function has zero excess risk at and below the reference
#' concentration (\eqn{z \le z_{cf}} gives RR 1). The published 95%
#' limits of the log-linear coefficients are carried through the same
#' curve into \code{rrlo} and \code{rrup}; the IER parameters come
#' without an interval, so those are \code{NA} for \code{"ihd"} and
#' \code{"stroke"}, and also when \code{betaper10} is supplied.
#'
#' Refusals: an unknown \code{y} (the message lists the available
#' ones); an exposure that is missing, infinite, negative, logical or
#' empty; and a \code{refconc} (or \code{betaper10}) that is not
#' a single finite number, or a negative \code{refconc}. A supplied
#' \code{betaper10} may be negative (a protective association) and
#' replaces the table, in which case \code{y} is only a label.
#' The functions are pure computations: no file, network or option is
#' used.
#'
#' @param expo Ambient concentration in micrograms per cubic metre, a
#'   single non-negative number or a vector of them (one per area, day or
#'   person).
#' @param y PM2.5: \code{"allcause"}, \code{"ihd"} or
#'   \code{"stroke"} (deaths). NO2: \code{"allcause"} and
#'   \code{"respiratory"} (deaths; Huangfu and Atkinson 2020, RR 1.02 and
#'   1.03 per 10 micrograms per cubic metre) or \code{"chiast"}
#'   (incident cases, not deaths; Khreis et al. 2017, OR 1.05 per 4
#'   micrograms per cubic metre, scaled to per 10).
#' @param refconc Counterfactual concentration below which no excess
#'   risk is assumed. PM2.5 default 5.8, the lower bound of the GBD 2019
#'   theoretical minimum risk exposure level (the WHO 2021 guideline is 5);
#'   NO2 default 10, the WHO 2021 guideline.
#' @param betaper10 Optional log relative risk per 10 micrograms per cubic
#'   metre (a single finite number, e.g. \code{log(1.04)}) overriding the
#'   NO2 outcome table; \code{NULL} (the default) uses the table.
#' @return A list of class \code{rmbl_crf} (\code{plot()} draws the curve)
#'   with: \code{rr} and \code{logrr}, the relative risk and its logarithm
#'   at the exposure (their means over a vector of exposures);
#'   \code{rrlo} and \code{rrup}, the RR at the published 95%
#'   limits (\code{NA} where there are none); \code{refconc};
#'   \code{expconc} (the exposure, or the mean of a vector);
#'   \code{pollutant} (\code{"PM2.5"} or \code{"NO2"}); \code{citation}
#'   (the source as a string); and \code{extra}, a list with the
#'   coefficient (\code{betaper10} and \code{betaper10ci} for the
#'   log-linear forms, \code{alpha}, \code{gamma}, \code{delta} for the
#'   IER), \code{form} (PM2.5 only), \code{outcome}, and for a vector of
#'   exposures \code{rrperunit}, the RR at each one.
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
#' # All-cause mortality at an annual PM2.5 of 12 micrograms per cubic metre.
#' r <- crfpm25(12)
#' c(rr = r$rr, lower = r$rrlo, upper = r$rrup)
#'
#' # The cause-specific IER curve for ischaemic heart disease.
#' crfpm25(12, y = "ihd")$rr
#'
#' # NO2 and respiratory deaths; at or below the reference there is no
#' # excess risk.
#' crfno2(25, y = "respiratory")$rr
#' crfno2(8)$rr
#'
#' # A vector of exposures (one per area): the mean RR and each area's RR.
#' crfpm25(c(5, 12, 20))$extra$rrperunit
#'
#' # Your own coefficient: RR 1.04 per 10 micrograms per cubic metre.
#' crfno2(30, betaper10 = log(1.04))$rr
#'
#' # An outcome without a published function is refused.
#' try(crfpm25(12, y = "asthma"))
#' @export
crfpm25 <- function(expo, y = "allcause", refconc = 5.8) {
  .rmbl_no_fn(outcome = y)
  # all-cause: RR 1.08 (95% CI 1.06-1.09) per 10 ug/m3, Chen and Hoek (2020), the WHO 2021 review
  loglinear <- c(allcause = log(1.08))
  loglinear_ci <- list(allcause = log(c(1.06, 1.09)))
  # GBD 2013 cause-specific IER triples (alpha, gamma, delta), Burnett et al. (2014)
  ier <- list(ihd = c(1.91, 0.14, 0.49), stroke = c(1.46, 0.13, 0.61))
  if (!is.character(y) || length(y) != 1L ||
      !y %in% c(names(loglinear), names(ier))) {
    stop(sprintf("Unknown outcome '%s'. Available: %s", paste(y, collapse = ","),
                 paste(c(names(loglinear), names(ier)), collapse = ", ")), call. = FALSE)
  }
  # one reference for every exposure: a vector would recycle against z, an NA would give NA risks
  refconc <- .pollution_scalar(refconc, "refconc")
  z <- .pollution_exposure(expo)
  scalar <- length(z) == 1L
  excess <- pmax(z - refconc, 0)
  if (y %in% names(loglinear)) {
    beta <- loglinear[[y]]
    log_rr <- beta * excess / 10
    ci <- loglinear_ci[[y]]
    return(.crf_object(exp(log_rr), log_rr, z, scalar, refconc, "PM2.5",
                       "Chen & Hoek (2020) Environ Int 143:105974; WHO (2021) Global AQ Guidelines",
                       list(betaper10 = beta, betaper10ci = ci, form = "log-linear", outcome = y),
                       rr_lower = exp(ci[[1L]] * excess / 10), rr_upper = exp(ci[[2L]] * excess / 10)))
  }
  p <- ier[[y]]
  rr <- 1 + p[1L] * (1 - exp(-p[2L] * excess^p[3L]))
  .crf_object(rr, log(rr), z, scalar, refconc, "PM2.5",
              "Burnett et al. (2014) EHP 122(4):397-403",
              list(alpha = p[1L], gamma = p[2L], delta = p[3L], form = "IER", outcome = y))
}

#' @rdname crfpm25
#' @export
crfno2 <- function(expo, y = "allcause", refconc = 10,
                    betaper10 = NULL) {
  .rmbl_no_fn(outcome = y)
  # all-cause RR 1.02 (95% CI 1.01-1.04) and respiratory RR 1.03 (1.00-1.05) per 10 ug/m3,
  # Huangfu and Atkinson (2020), the WHO 2021 review; childhood asthma incidence OR 1.05
  # (1.02-1.07) per 4 ug/m3, Khreis et al. (2017), scaled to per 10 ug/m3
  betas <- c(allcause = log(1.02), respiratory = log(1.03),
             chiast = log(1.05) * 10 / 4)
  betas_ci <- list(allcause = log(c(1.01, 1.04)), respiratory = log(c(1.00, 1.05)),
                   chiast = log(c(1.02, 1.07)) * 10 / 4)
  ci <- c(NA_real_, NA_real_)
  if (is.null(betaper10)) {
    if (!is.character(y) || length(y) != 1L || !y %in% names(betas)) {
      stop(sprintf("Unknown outcome '%s'. Available: %s or pass betaper10 explicitly.",
                   paste(y, collapse = ","), paste(names(betas), collapse = ", ")),
           call. = FALSE)
    }
    beta <- betas[[y]]
    ci <- betas_ci[[y]]
  } else {
    # the same guard as every other scalar: TRUE is not a log relative risk of 1
    beta <- .pollution_scalar(betaper10, "betaper10", nonneg = FALSE)
  }
  refconc <- .pollution_scalar(refconc, "refconc")
  z <- .pollution_exposure(expo)
  scalar <- length(z) == 1L
  log_rr <- beta * pmax(z - refconc, 0) / 10
  cite <- if (identical(y, "chiast") && is.null(betaper10)) {
    "Khreis et al. (2017) Environ Int 100:1-31; WHO (2021) Global AQ Guidelines"
  } else {
    "Huangfu & Atkinson (2020) Environ Int 144:105998; WHO (2021) Global AQ Guidelines"
  }
  .crf_object(exp(log_rr), log_rr, z, scalar, refconc, "NO2", cite,
              list(betaper10 = beta, betaper10ci = ci, outcome = y),
              rr_lower = exp(ci[[1L]] * pmax(z - refconc, 0) / 10),
              rr_upper = exp(ci[[2L]] * pmax(z - refconc, 0) / 10))
}

#' Checks the exposure concentrations: finite, non-negative, none missing.
#' @param exposure The concentrations passed by the user.
#' @return A double vector.
#' @noRd
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

#' Says that a baseline rate above 1 looks like a rate per 100,000.
#' @param rate The rate passed.
#' @return One string.
#' @noRd
.pollution_rate_msg <- function(rate) {
  sprintf(paste("`brate` is a rate per person-year, between 0 and 1 (0.008 is 800 per 100,000);",
                "%s looks like a rate per 100,000, which only vrfpol() takes"), format(rate))
}

#' Checks a baseline rate per person-year.
#'
#' A baseline rate per person-year, checked as vrfpol() checks its rate per 100,000 (the
#' same band, the same switches; review of e57fed5, E4: 0.5 and 8e-8 were taken as they came). The
#' band is 1 to 10,000 per 100,000 a year (1e-5 to 0.1 per person-year): below it, the number is
#' also what a rate per 100,000 passed here looks like (rare = TRUE when the outcome really
#' is that rare, never below 1e-6 per 100,000); above it, no population's all-cause mortality comes
#' close (hirate = TRUE for an outcome that common, never above 1); zero is a measured zero.
#' @param rate The rate.
#' @param rare_outcome Whether a rate below one per 100,000 a year is taken.
#' @param high_rate Whether a rate above 0.1 per person-year is taken.
#' @return `rate`.
#' @noRd
.pollution_rate_pp <- function(rate, rare_outcome = FALSE, high_rate = FALSE) {
  for (a in list(list("rare_outcome", rare_outcome), list("high_rate", high_rate))) {
    if (!is.logical(a[[2L]]) || length(a[[2L]]) != 1L || is.na(a[[2L]])) {
      stop(.rmbl_fn(), sprintf("`%s` must be TRUE or FALSE", a[[1L]]), call. = FALSE)
    }
  }
  if (rate > 1) stop(.pollution_rate_msg(rate), call. = FALSE)
  if (rate == 0) return(rate)
  if (rate < 1e-11) {
    stop(sprintf(paste("`brate` %s per person-year is below one case per 100 billion person-years:",
                       "not a usable rate"), format(rate)), call. = FALSE)
  }
  if (rate < 1e-5 && !rare_outcome) {
    stop(sprintf(paste("`brate` %s per person-year is below one case per 100,000 a year. A rate per",
                       "100,000 divided by 100,000 is the rate here (800 per 100,000 is 0.008); if the outcome",
                       "really is this rare, say so with rare = TRUE"), format(rate)), call. = FALSE)
  }
  if (rate > 0.1 && !high_rate) {
    stop(sprintf(paste("`brate` %s per person-year is %s per 100,000 a year, above a whole population's",
                       "all-cause death rate (an age-specific rate for the oldest ages can be this high). If it",
                       "is a rate per 100,000, divide it by 100,000; if the outcome really is this common, say",
                       "so with hirate = TRUE"),
                 format(rate), format(rate * 1e5, big.mark = ",", scientific = FALSE)), call. = FALSE)
  }
  rate
}

#' One finite number, optionally non-negative: the scalar inputs of the burden functions.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param nonneg Whether a negative value is refused.
#' @param positive Whether zero is refused too.
#' @return The number.
#' @noRd
.pollution_scalar <- function(x, what, nonneg = TRUE, positive = FALSE) {
  # a flag is not a number: as.numeric(TRUE) is 1, and a relative risk of TRUE is a typo
  if (is.logical(x) && !all(is.na(x))) stop(.rmbl_fn(), sprintf("`%s` must be numeric, not logical", what),
                                            call. = FALSE)
  if (is.factor(x)) {
    stop(sprintf("`%s` must be numeric, not a factor (its level codes are not values)", what), call. = FALSE)
  }
  v <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (length(v) != 1L || is.na(v) || !is.finite(v)) {
    stop(sprintf("`%s` must be a single finite number", what), call. = FALSE)
  }
  if (positive && v <= 0) stop(.rmbl_fn(), sprintf("`%s` must be positive", what), call. = FALSE)
  if (nonneg && v < 0) stop(.rmbl_fn(), sprintf("`%s` must be non-negative", what), call. = FALSE)
  v
}

#' \code{"PM2.5"}, \code{"PM25"}, \code{"pm2.5"}, \code{"pm25"} -> \code{"PM2.5"};
#' \code{"NO2"}, \code{"no2"} -> \code{"NO2"}; anything else NA.
#' @param pollutant The pollutant's name as given.
#' @return \code{"PM2.5"}, \code{"NO2"} or NA.
#' @noRd
.pollution_pollutant <- function(pollutant) {
  if (!is.character(pollutant) || length(pollutant) != 1L || is.na(pollutant)) return(NA_character_)
  key <- gsub("[^a-z0-9]", "", tolower(pollutant))
  if (key %in% c("pm25", "pm2.5")) return("PM2.5")
  if (identical(key, "no2")) return("NO2")
  NA_character_
}

#' The unit of an outcome's attributable count: the mortality outcomes are deaths, the
#' childhood-asthma CRF is an incidence relative risk.
#' @param outcome The outcome's code.
#' @return One string.
#' @noRd
.pollution_outcome_unit <- function(outcome) {
  if (identical(outcome, "chiast")) "incident cases" else "deaths"
}

#' Population attributable fraction
#'
#' The share of all cases in a population that is due to an exposure: the
#' fraction that would not occur if the exposure were removed and nothing
#' else changed. It combines how strongly the exposure raises risk (the
#' relative risk) with how common it is (the prevalence); multiplied by the
#' number of cases it gives the attributable cases, as
#' \code{\link{polbrdn}} does.
#'
#' @details
#' Levin's formula (Levin 1953; Rothman, Greenland and Lash 2008, chapter
#' 5):
#' \deqn{PAF = p (RR - 1) / (1 + p (RR - 1)),}
#' with \eqn{p} the proportion exposed. With everyone exposed it is
#' \eqn{1 - 1/RR}. It assumes the relative risk is causal and unconfounded
#' and that removing the exposure changes nothing else. A relative risk
#' below 1 gives a negative fraction (the exposure protects).
#'
#' When both confidence limits of the RR are given, the fraction's limits
#' are the formula applied to them: the formula increases with the RR, so
#' the interval of the fraction is the image of the interval of the risk.
#' Refusals: an \code{rr} or limit that is not a single finite positive
#' number (logical values included), a prevalence outside \eqn{[0, 1]}, only
#' one of the two limits, or limits that do not enclose \code{rr}.
#'
#' @param rr Relative risk among the exposed, a single finite positive
#'   number. A relative risk below 1 gives a negative fraction (a protective
#'   exposure); 0, negative, infinite and missing values are errors.
#' @param expoprev Proportion of the population exposed, in
#'   \code{[0, 1]}.
#' @param rrlo,rrup Optional confidence limits of \code{rr}; when
#'   both are given the fraction carries the limits that the same formula
#'   gives at them (Levin's formula is monotone in the relative risk, so the
#'   interval of the fraction is the image of the interval of the risk).
#' @return A single number, the attributable fraction: in \code{[0, 1)} for
#'   \code{rr >= 1}, negative for a protective exposure. When the limits
#'   were given it carries an attribute \code{ci}, a named numeric vector
#'   (\code{lower}, \code{upper}).
#' @seealso \code{\link{crfpm25}} for a relative risk from a
#'   concentration, \code{\link{polbrdn}} for the attributable
#'   cases.
#' @references Rothman, K. J., Greenland, S. and Lash, T. L. (2008). Modern
#'   Epidemiology, 3rd ed., chapter 5. Levin, M. L. (1953). The occurrence of
#'   lung cancer in man. Acta Unio Internationalis Contra Cancrum 9, 531-541.
#' @examples
#' attrfrac(1.5, 0.4)
#' attrfrac(2, 1)      # everyone exposed: 1 - 1/RR
#'
#' # With the confidence limits of the relative risk.
#' paf <- attrfrac(1.08, 1, rrlo = 1.06, rrup = 1.09)
#' attr(paf, "ci")
#'
#' # A protective exposure gives a negative fraction.
#' attrfrac(0.8, 0.5)
#'
#' # A prevalence above 1 is refused.
#' try(attrfrac(1.5, 40))
#' @export
attrfrac <- function(rr, expoprev, rrlo = NULL, rrup = NULL) {
  rr <- .pollution_scalar(rr, "rr", nonneg = FALSE, positive = TRUE)
  p <- .pollution_scalar(expoprev, "expoprev")
  if (p > 1) {
    stop(sprintf("expoprev must be in [0,1]; got %s", format(p)), call. = FALSE)
  }
  levin <- function(r) p * (r - 1) / (1 + p * (r - 1))   # the denominator is positive: r > 0, p <= 1
  paf <- levin(rr)
  if (!is.null(rrlo) || !is.null(rrup)) {
    if (is.null(rrlo) || is.null(rrup)) stop("rrlo and rrup go together", call. = FALSE)
    lo <- .pollution_scalar(rrlo, "rrlo", nonneg = FALSE, positive = TRUE)
    hi <- .pollution_scalar(rrup, "rrup", nonneg = FALSE, positive = TRUE)
    if (lo > rr || hi < rr) stop("rr must lie between rrlo and rrup", call. = FALSE)
    attr(paf, "ci") <- c(lower = levin(lo), upper = levin(hi))
  }
  paf
}

#' Deaths avoided under a counterfactual exposure reduction
#'
#' The expected number of deaths (or cases) a year that a given drop in
#' exposure would avoid in a population, from the baseline rate and a
#' log-linear concentration-response coefficient. This is the
#' health-impact function used in regulatory benefit assessments, for
#' questions such as \dQuote{how many deaths would a 5 microgram cut in PM2.5
#' avoid in this city?}.
#'
#' @details
#' The BenMAP-CE health-impact function (US EPA 2018; Anenberg et al. 2010):
#' \deqn{\Delta Y = y_0 N (1 - e^{-\beta \Delta x}),}
#' with \eqn{y_0} the baseline rate per person-year, \eqn{N} the population,
#' \eqn{\beta} the log relative risk per unit of exposure and
#' \eqn{\Delta x} the reduction. A negative \code{expdel} (an
#' increase) gives a negative number, the extra cases. A coefficient
#' published per 10 units must be divided by 10 first (for example
#' \code{log(1.08) / 10} for the PM2.5 all-cause RR of 1.08 per 10).
#'
#' The baseline rate is per person-year, not per 100,000: 800 deaths per
#' 100,000 a year is 0.008. A rate below 1e-5 or above 0.1 is refused
#' unless \code{rare} or \code{hirate} says it is meant, because
#' it is also what a rate in the wrong unit looks like; a rate above 1, or
#' below 1e-11, is always refused. Every input must be a single finite
#' number, and the population and rate non-negative.
#'
#' @param expdel Counterfactual reduction in exposure, in the unit
#'   of \code{betaperunit} (positive means the exposure goes down).
#' @param pop At-risk population, a non-negative number of persons.
#' @param brate Baseline rate in cases per person-year (0.008 is
#'   800 per 100,000).
#' @param betaperunit Log relative risk per unit of exposure (per unit,
#'   not per 10), a single finite number.
#' @param rare,hirate \code{TRUE} to admit a baseline rate
#'   below 1e-5 (one per 100,000) or above 0.1 (10,000 per 100,000)
#'   per person-year; without them such a rate is refused, being also
#'   what a rate in the wrong unit looks like.
#' @return A single number: the expected cases avoided per year (negative
#'   for an increase in exposure).
#' @seealso \code{\link{polbrdn}} for the cases attributable to
#'   the whole excess exposure, \code{\link{vrfpol}} which runs
#'   both.
#' @references US EPA (2018). Environmental Benefits Mapping and Analysis
#'   Program - Community Edition, user manual. Anenberg, S. C. et al. (2010).
#'   An estimate of the global burden of anthropogenic ozone and fine
#'   particulate matter on premature human mortality using atmospheric
#'   modeling. Environmental Health Perspectives 118(9), 1189-1195.
#' @examples
#' # A 10-unit cut, a million people, 800 deaths per 100,000 a year.
#' mortdisp(10, 1e6, 0.008, 0.0039)
#'
#' # The PM2.5 all-cause coefficient is published per 10 micrograms.
#' mortdisp(5, 2.8e6, 0.0075, log(1.08) / 10)
#'
#' # A rare outcome must be declared.
#' mortdisp(5, 1e6, 5e-6, 0.01, rare = TRUE)
#'
#' # A rate per 100,000 passed as a rate per person is refused.
#' try(mortdisp(10, 1e6, 800, 0.0039))
#' @export
mortdisp <- function(expdel, pop, brate, betaperunit,
                                rare = FALSE, hirate = FALSE) {
  expdel <- .pollution_scalar(expdel, "expdel", nonneg = FALSE)
  pop <- .pollution_scalar(pop, "population")
  brate <- .pollution_rate_pp(.pollution_scalar(brate, "brate"), rare, hirate)
  betaperunit <- .pollution_scalar(betaperunit, "betaperunit", nonneg = FALSE)
  brate * pop * (1 - exp(-betaperunit * expdel))
}

#' End-to-end pollution burden
#'
#' Chains the concentration-response function, the attributable fraction and
#' the baseline case count into annual attributable cases, as the GBD risk
#' factor estimates do (GBD 2019 Risk Factors Collaborators 2020). Use it
#' for a single population (a city, a region) when you know its mean
#' exposure, its baseline rate and its size; for many areas at once see
#' \code{\link{polbrdarea}}.
#'
#' @details
#' The steps are: the relative risk at \code{expomean} from
#' \code{\link{crfpm25}} or \code{\link{crfno2}} (with the reference
#' concentration given or the pollutant's default); the attributable
#' fraction from \code{\link{attrfrac}} with
#' \code{expoprev}; the baseline cases
#' \eqn{y_0 N}; and the attributable cases, their product. The result is a
#' yearly count of deaths (or incident cases for
#' \code{"chiast"}).
#'
#' Refusals: an unknown pollutant, an outcome the pollutant's CRF does not
#' have, any input that is not a single finite non-negative number, and a
#' baseline rate outside the band described in
#' \code{\link{mortdisp}} unless \code{rare} or
#' \code{hirate} admits it.
#'
#' @param expomean The mean exposure among the exposed, in micrograms per cubic
#'   metre. With \code{expoprev = 1} that is the population mean.
#' @param expoprev Proportion of the population at that level (1
#'   for ambient air), in \code{[0, 1]}.
#' @param brate Cases per person-year in the unexposed scenario (a
#'   rate per person, not per 100,000: 0.008 is 800 per 100,000).
#' @param pop At-risk population (persons; any non-negative number).
#' @param poll \code{"PM2.5"} (also written \code{"PM25"}) or
#'   \code{"NO2"}, in either case.
#' @param y Outcome key passed to the concentration-response function;
#'   \code{extra$unit} says whether the attributable count is deaths or
#'   incident cases.
#' @param refconc Counterfactual concentration; \code{NULL} takes the
#'   pollutant's default (PM2.5 5.8, NO2 10; see \code{\link{crfpm25}}).
#' @param rare,hirate \code{TRUE} to admit a baseline rate
#'   below 1e-5 (one per 100,000) or above 0.1 (10,000 per 100,000)
#'   per person-year, as \code{\link{vrfpol}} does: without
#'   them such a rate is refused, being also what a rate in the wrong
#'   unit looks like.
#' @return A list of class \code{rmbl_burden} (\code{plot()} draws it) with:
#'   \code{paf} (the attributable fraction), \code{attrcases} and
#'   \code{basecases} (per year), \code{population},
#'   \code{brate} (per person-year), \code{expomean},
#'   \code{refconc} (the one used), \code{pollutant}
#'   (\code{"PM2.5"} or \code{"NO2"}), \code{citation} (a string), and
#'   \code{extra}, a list with \code{rr}, \code{logrr}, \code{outcome}
#'   and \code{unit} (\code{"deaths"} or \code{"incident cases"}).
#' @references GBD 2019 Risk Factors Collaborators (2020). Global burden of 87
#'   risk factors in 204 countries and territories, 1990-2019. The Lancet
#'   396(10258), 1223-1249.
#' @examples
#' # Ambient NO2 of 25 micrograms per cubic metre over a million people.
#' b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
#' b$attrcases
#' b$paf
#'
#' # PM2.5 and ischaemic heart disease deaths, against the WHO guideline
#' # of 5 as the counterfactual.
#' polbrdn(12, 1, 0.0012, 2.8e6, poll = "PM2.5", y = "ihd",
#'                  refconc = 5)$attrcases
#'
#' # Childhood asthma counts incident cases, not deaths.
#' polbrdn(30, 1, 0.012, 5e5, y = "chiast")$extra$unit
#'
#' # Only PM2.5 and NO2 have concentration-response functions here.
#' try(polbrdn(40, 1, 0.008, 1e6, poll = "O3"))
#' @export
polbrdn <- function(expomean, expoprev, brate, pop,
                             poll = "NO2", y = "allcause",
                             refconc = NULL, rare = FALSE, hirate = FALSE) {
  .rmbl_no_fn(pollutant = poll)
  pol <- .pollution_pollutant(poll)
  if (is.na(pol)) {
    stop(sprintf("Unknown pollutant '%s'. Use 'PM2.5' or 'NO2'.", paste(poll, collapse = ",")),
         call. = FALSE)
  }
  expomean <- .pollution_scalar(expomean, "expomean")
  expoprev <- .pollution_scalar(expoprev, "expoprev")
  # the same check mortdisp() makes: 800 is a rate per 100,000, and taken per
  # person-year it gave 110 million attributable deaths from a million people
  brate <- .pollution_rate_pp(.pollution_scalar(brate, "brate"), rare, hirate)
  pop <- .pollution_scalar(pop, "population")
  if (!is.null(refconc)) {
    refconc <- .pollution_scalar(refconc, "refconc")
  }
  crf <- if (pol == "PM2.5") {
    crfpm25(expomean, y = y,
             refconc = if (is.null(refconc)) 5.8 else refconc)
  } else {
    crfno2(expomean, y = y,
            refconc = if (is.null(refconc)) 10 else refconc)
  }
  paf <- attrfrac(crf$rr, expoprev)
  baseline_cases <- brate * pop
  structure(list(
    paf = paf,
    attrcases = paf * baseline_cases,
    basecases = baseline_cases,
    population = pop,
    brate = brate,
    expomean = expomean,
    refconc = crf$refconc,
    pollutant = pol,
    citation = paste0(crf$citation, "; Rothman et al. (2008) section 5"),
    extra = list(rr = crf$rr, logrr = crf$logrr, outcome = y,
                 unit = .pollution_outcome_unit(y))
  ), class = "rmbl_burden")
}

#' Cross-fitted partially linear regression (double machine learning)
#'
#' Estimates the effect of a continuous exposure (or treatment) on an
#' outcome after adjusting for confounders, by the double machine learning
#' recipe: the part of the outcome and of the exposure that the confounders
#' predict is removed with models fitted on other folds of the data, and the
#' effect is the slope of what is left. It answers questions such as \dQuote{how
#' much does asthma incidence rise per microgram of NO2, holding income and
#' age structure fixed?}.
#'
#' @details
#' The partially linear model \eqn{Y = \theta D + g(X) + U},
#' \eqn{D = m(X) + V} of Chernozhukov et al. (2018, section 4.2), estimated
#' by the DML2 cross-fitting recipe: the sample is split into \code{kfol}
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
#' to \code{\link{exprspplr}} through \code{estimator}.
#'
#' Each fold's two least-squares fits are computed from the normal
#' equations of the covariates centred and scaled by their full-sample
#' moments (the same column space, so the same fitted values as
#' \code{\link[stats]{lm.fit}}), solved by Cholesky; a fold whose
#' cross-product is poorly conditioned (reciprocal condition number below
#' 1e-5: collinear covariates or a constant column) uses
#' \code{\link[stats]{lm.fit}} instead, whose pivoting drops the redundant
#' columns (their coefficients count as 0). An n = 20000 fit takes a few
#' milliseconds. A bar on stderr shows the folds when the work is slow
#' enough to need one (see \code{\link{blprog}}).
#'
#' Rows with a missing value in any of the named columns are dropped first
#' (\code{n} reports the rows used). The folds are a random permutation of
#' \code{rep_len(1:kfol, n)} drawn with \code{seed}; R's own random
#' stream is restored afterwards. Refusals: a column name that is not a
#' single string (several for \code{covs}) or is not in \code{data};
#' a non-numeric column (a factor is not a code); \code{kfol} that is
#' not a whole number of at least 2; fewer than \code{2 * kfol}
#' complete rows; and a treatment with no variation left after the
#' covariates are partialled out.
#'
#' @param data A data frame with one row per unit.
#' @param y,trt Column names (single strings) of the outcome
#'   and of the continuous treatment or exposure; both numeric.
#' @param covs Column names of the confounders (one or more strings),
#'   numeric. Code a categorical confounder as indicator columns first.
#' @param kfol Number of cross-fitting folds, a whole number of at least
#'   2 (default 5).
#' @param seed Seed of the fold assignment (default 1), so the estimate is
#'   reproducible.
#' @return A list with \code{ate} (the estimate of \eqn{\theta}: the change
#'   in the outcome per unit of the treatment), \code{se} (its sandwich
#'   standard error), \code{n} (complete rows used), \code{kfol} and
#'   \code{method} (a string naming the estimator).
#' @references Chernozhukov, V., Chetverikov, D., Demirer, M., Duflo, E.,
#'   Hansen, C., Newey, W. and Robins, J. (2018). Double/debiased machine
#'   learning for treatment and structural parameters. The Econometrics
#'   Journal 21(1), C1-C68.
#' @examples
#' set.seed(1)
#' d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
#' d$exposure <- 20 + 2 * d$x1 + rnorm(200)
#' d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
#' fit <- plrcf(d, "asthma", "exposure", c("x1", "x2"))
#' fit$ate
#'
#' # A 95 percent normal confidence interval from the standard error.
#' fit$ate + c(-1.96, 1.96) * fit$se
#'
#' # The fold split changes the estimate a little; ten folds instead of five.
#' plrcf(d, "asthma", "exposure", c("x1", "x2"), kfol = 10, seed = 2)$ate
#'
#' # A text column is refused rather than read as codes.
#' d$region <- sample(c("north", "south"), 200, replace = TRUE)
#' try(plrcf(d, "asthma", "exposure", c("x1", "region")))
#' @export
plrcf <- function(data, y, trt, covs, kfol = 5L, seed = 1L) {
  seed <- .rmbl_r_seed(seed)
  .rmbl_colnames(y, "y")
  .rmbl_colnames(trt, "trt")
  .rmbl_colnames(covs, "covs", several = TRUE)
  cols <- c(y, trt, covs)
  missing <- setdiff(cols, names(data))
  if (length(missing)) stop(sprintf("plrcf: data is missing columns: %s", paste(missing, collapse = ", ")),
                            call. = FALSE)
  df <- data[stats::complete.cases(data[, cols, drop = FALSE]), cols, drop = FALSE]
  n <- nrow(df)
  kfol <- as.integer(.rmbl_num(kfol, "kfol", integer = TRUE))
  if (length(kfol) != 1L || is.na(kfol) || kfol < 2L) stop("`kfol` must be at least 2", call. = FALSE)
  for (cl in cols) {
    if (!is.numeric(df[[cl]])) {
      stop(sprintf("column `%s` must be numeric (a factor or character column is not a code)", cl), call. = FALSE)
    }
  }
  if (n < 2L * kfol) {
    stop(sprintf("need at least %d complete rows for %d folds; have %d", 2L * kfol, kfol, n),
         call. = FALSE)
  }
  folds <- .rmbl_with_seed(seed, sample(rep_len(seq_len(kfol), n)))
  .y <- as.numeric(df[[y]])
  d <- as.numeric(df[[trt]])
  X <- cbind(1, as.matrix(df[, covs, drop = FALSE]))
  storage.mode(X) <- "double"
  YD <- cbind(.y, d)
  # the covariates centred and scaled by their full-sample moments: the same column space (the
  # intercept is in it), so the same fitted values, with a cross-product that is well conditioned
  # whatever the covariates' units
  ctr <- colMeans(X[, -1L, drop = FALSE])
  scl <- sqrt(colSums(sweep(X[, -1L, drop = FALSE], 2L, ctr)^2) / n)
  scl[!is.finite(scl) | scl <= 0] <- 1
  Z <- cbind(1, sweep(sweep(X[, -1L, drop = FALSE], 2L, ctr), 2L, scl, "/"))
  U <- numeric(n)
  V <- numeric(n)
  pg <- blprog("cross-fitting", kfol)
  on.exit(pg$done(), add = TRUE)
  for (k in seq_len(kfol)) {
    pg$update(k - 1L, sprintf("fold %d/%d", k, kfol))
    test <- folds == k
    fit <- .plr_fold_fit(X, Z, YD, !test, test)
    U[test] <- .y[test] - fit[, 1L]
    V[test] <- d[test] - fit[, 2L]
  }
  pg$update(kfol, sprintf("fold %d/%d", kfol, kfol))
  denom <- sum(V * V)
  scale <- max(1, sum((d - mean(d))^2))
  if (!is.finite(denom) || denom <= 1e-10 * scale) {
    stop("the treatment has no variation left after partialling out the covariates", call. = FALSE)
  }
  theta <- sum(V * U) / denom
  se <- sqrt(sum(V * V * (U - theta * V)^2)) / denom
  list(ate = theta, se = se, n = n, kfol = kfol,
       method = "partially linear regression, DML2 cross-fitting, OLS nuisances")
}

#' Fits one fold's two nuisance regressions and predicts them on the test rows.
#'
#' One fold's two nuisance fits (outcome and treatment on the covariates, least squares on the
#' training rows) predicted on the test rows. The least-squares solution comes from the normal
#' equations of the standardized design Z, solved by Cholesky: two cross-products and a p x p
#' solve. That is the same projection lm.fit() computes by its LINPACK QR, and it is used only when
#' the cross-product is well conditioned (reciprocal condition number at least 1e-5, so the
#' rounding difference from the QR is far below 1e-10); a near-singular fold (collinear
#' covariates, a constant column) takes lm.fit() on the raw design as before, with its pivoting
#' and its NA coefficients set to 0. lm.fit()'s QR is a long chain of level-1 BLAS calls, which a
#' threaded BLAS on a busy machine runs a hundred times slower than this (an n = 20000 fit took
#' 1.5 s); the cross-products are level-3 calls.
#' @param X The raw design matrix.
#' @param Z The standardized design matrix.
#' @param YD The outcome and treatment, as a two-column matrix.
#' @param train The training rows.
#' @param test The test rows.
#' @return A matrix of predictions, one column for each of `YD`.
#' @noRd
.plr_fold_fit <- function(X, Z, YD, train, test) {
  Zt <- Z[train, , drop = FALSE]
  A <- crossprod(Zt)
  if (all(is.finite(A)) && rcond(A) >= 1e-5) {
    R <- chol(A)
    b <- backsolve(R, backsolve(R, crossprod(Zt, YD[train, , drop = FALSE]), transpose = TRUE))
    return(Z[test, , drop = FALSE] %*% b)
  }
  g <- stats::lm.fit(X[train, , drop = FALSE], YD[train, , drop = FALSE])$coefficients
  g[is.na(g)] <- 0
  X[test, , drop = FALSE] %*% g
}

#' Exposure-response estimate with a bootstrap sensitivity interval
#'
#' Fits the partially linear exposure-response model with
#' \code{\link{plrcf}} (or any estimator with the same interface),
#' then re-fits it on \code{nboot} non-parametric resamples of the rows
#' for a percentile interval (Efron and Tibshirani 1993, chapter 13). The
#' bootstrap interval does not lean on the estimator's own standard error,
#' so it is a check on it: when the two disagree, the analytic one should
#' not be trusted alone.
#'
#' @details
#' Each resample draws \code{nrow(data)} rows with replacement and calls
#' \code{estr(resample, outcome, exposure, confounders)}; a resample on
#' which the estimator fails is skipped, and the run stops if fewer than 10
#' succeed. The interval is the 2.5% and 97.5% type-7 quantiles of the
#' replicate estimates, and \code{seboot} their standard deviation.
#' Resampling uses \code{rstate} and restores R's own random stream
#' afterwards. The cost is \code{nboot + 1} estimator calls; with
#' \code{\link{plrcf}} at n = 20000 and 100 resamples that is a
#' few seconds. A progress bar on stderr follows the resamples when a person
#' is watching (\code{options(morie.progress = TRUE)} outside an
#' interactive session; \code{options(morie.quiet = TRUE)} silences it).
#'
#' Refusals: column names that are not strings, an \code{nboot} that
#' is not a single non-negative whole number, an estimator that is not a
#' function, and the estimator's own errors on the full sample.
#'
#' @param data A data frame with one row per unit.
#' @param y,expo,confs Column names: the outcome and the
#'   exposure (single strings) and the confounders (one or more strings).
#' @param nboot Number of resamples, a non-negative whole number
#'   (default 100); at least 10 must succeed.
#' @param rstate Seed for the resampling (default 42).
#' @param estr A function \code{(data, outcome, treatment, covariates)}
#'   returning a list with \code{ate} and \code{se}. The default is
#'   \code{\link{plrcf}}; rmorie's \code{morie_estimate_double_ml()}
#'   has the same interface.
#' @return A list with \code{ate} (the full-sample estimate),
#'   \code{seana} (the estimator's standard error),
#'   \code{seboot} (the standard deviation of the replicates),
#'   \code{cilobs} and \code{ciupbs} (the 95% percentile
#'   interval), \code{nboot} (the number of successful resamples) and
#'   \code{method} (the estimator's method with
#'   \code{" + percentile bootstrap"}).
#' @seealso \code{\link{cbootmean}} for a bootstrap of a mean.
#' @references Efron, B. and Tibshirani, R. J. (1993). An Introduction to the
#'   Bootstrap. Chapman and Hall.
#' @examples
#' set.seed(1)
#' d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
#' d$exposure <- 20 + 2 * d$x1 + rnorm(200)
#' d$asthma <- 5 + 0.3 * d$exposure + d$x2 + rnorm(200)
#' r <- exprspplr(d, y = "asthma", expo = "exposure",
#'                            confs = c("x1", "x2"), nboot = 20)
#' r$ate
#' c(r$cilobs, r$ciupbs)
#'
#' # Any estimator with the same interface: here an ordinary regression.
#' ols <- function(data, outcome, treatment, covariates) {
#'   f <- stats::reformulate(c(treatment, covariates), outcome)
#'   cf <- summary(stats::lm(f, data = data))$coefficients
#'   list(ate = cf[treatment, 1], se = cf[treatment, 2], method = "OLS")
#' }
#' exprspplr(d, "asthma", "exposure", c("x1", "x2"),
#'                       nboot = 20, estr = ols)$method
#'
#' # Fewer than 10 resamples cannot give an interval.
#' try(exprspplr(d, "asthma", "exposure", c("x1", "x2"), nboot = 5))
#' @export
exprspplr <- function(data, y, expo, confs, nboot = 100L,
                                  rstate = 42L, estr = plrcf) {
  .rmbl_colnames(y, "y")
  .rmbl_colnames(expo, "expo")
  .rmbl_colnames(confs, "confs", several = TRUE)
  # a function, or the name of one
  if (is.character(estr) && length(estr) == 1L && !is.na(estr)) {
    estr <- tryCatch(match.fun(estr), error = function(e) {
      stop(sprintf("`estr` names no function: \"%s\"", estr), call. = FALSE)
    })
  }
  if (!is.function(estr)) stop("`estr` must be a function (plrcf() or one like it)", call. = FALSE)
  rstate <- .rmbl_r_seed(rstate)
  nboot <- .pollution_scalar(nboot, "nboot")
  if (nboot != round(nboot)) stop("`nboot` must be a whole number of resamples", call. = FALSE)
  nboot <- as.integer(nboot)
  pg <- blprog("exposure-response bootstrap", nboot + 1L)
  on.exit(pg$done(), add = TRUE)
  pg$update(0, "fitting the full sample")
  # the full sample: an estimator that cannot take (data, outcome, exposure, confounders) is said so
  base <- tryCatch(estr(data, y, expo, confs), error = function(e) {
    stop(.rmbl_fn(), sprintf(paste("`estr` failed on the full sample, called as",
                                   "estr(data, y, expo, confs): %s"), conditionMessage(e)), call. = FALSE)
  })
  ate <- as.numeric(base$ate)
  se_analytic <- as.numeric(base$se)
  n <- nrow(data)
  boot <- .rmbl_with_seed(rstate, {
    out <- numeric(0)
    for (b in seq_len(nboot)) {
      pg$update(b, sprintf("bootstrap %d/%d", b, nboot))
      idx <- sample.int(n, n, replace = TRUE)
      r <- tryCatch(estr(data[idx, , drop = FALSE], y, expo, confs),
                    error = .rmbl_or(NULL))
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
    seana = se_analytic,
    seboot = stats::sd(boot),
    cilobs = unname(stats::quantile(boot, 0.025, type = 7)),
    ciupbs = unname(stats::quantile(boot, 0.975, type = 7)),
    nboot = length(boot),
    method = paste0(if (is.null(base$method)) "exposure-response" else base$method, " + percentile bootstrap")
  )
}

#' Concentration index of exposure by income
#'
#' Measures whether exposure to pollution is concentrated among
#' lower-income or higher-income people. The index runs from -1 (all the
#' exposure borne by the poorest) through 0 (exposure shared evenly across
#' income) to +1 (all of it borne by the richest); environmental-justice
#' analyses report it next to the burden.
#'
#' @details
#' Wagstaff, Paci and van Doorslaer (1991):
#' \deqn{CI = (2 / \mu) \, \mathrm{cov}(h_i, R_i)}
#' with \eqn{R_i = (rank_i - 0.5) / n} the fractional income rank (tied incomes
#' share their average rank, so the index does not depend on row order) and
#' the population covariance. Negative values mean lower-income units bear
#' more exposure. Both columns must be numeric: a factor or character income
#' is refused rather than ranked by its level codes, and exposures must be
#' non-negative.
#'
#' Rows with a missing exposure or income are dropped. The interpretation
#' calls an index below -0.01 a burden on the poor, above 0.01 a burden on
#' the rich, and anything between an even distribution. Refusals: column
#' names that are not single strings or not in \code{data}; fewer than 2
#' complete rows; a non-numeric or infinite value; a negative exposure; and
#' a mean exposure of zero (the index divides by it). Income only needs an
#' order: an amount, a quintile number or a rank all give the same index.
#'
#' @param data A data frame with one row per person or area.
#' @param expo,income Column names (single strings): the exposure (a
#'   non-negative concentration) and the income measure (numeric).
#' @return A list of class \code{rmbl_equity} (\code{plot()} draws the
#'   concentration curve) with \code{concidx} (a number in
#'   \eqn{[-1, 1]}), \code{interpretation} (a sentence),
#'   \code{expomean}, \code{citation} (a string) and \code{extra}, a
#'   list with \code{n} (rows used), \code{cov_h_R} (the covariance) and
#'   \code{curve}, a data frame of the concentration curve. Its column
#'   \code{population} is the cumulative population share, poorest first, and
#'   \code{exposure} the cumulative share of total exposure.
#' @references Wagstaff, A., Paci, P. and van Doorslaer, E. (1991). On the
#'   measurement of inequalities in health. Social Science and Medicine 33(5),
#'   545-557.
#' @examples
#' d <- data.frame(exposure = c(30, 25, 20, 15, 10), income = 1:5)
#' ci <- expconcidx(d, "exposure", "income")
#' ci$concidx
#' ci$interpretation
#'
#' # Even exposure across income gives 0; tied incomes share a rank.
#' expconcidx(data.frame(exposure = 20, income = c(1, 1, 2, 3)),
#'                              "exposure", "income")$concidx
#'
#' # A text income cannot be ranked.
#' try(expconcidx(data.frame(exposure = 1:3, income = c("a", "b", "c")),
#'                                  "exposure", "income"))
#' @export
expconcidx <- function(data, expo, income) {
  .rmbl_colnames(expo, "expo")
  .rmbl_colnames(income, "income")
  missing <- setdiff(c(expo, income), names(data))
  if (length(missing)) stop(sprintf("expconcidx: data is missing columns: %s", paste(missing, collapse = ", ")),
                            call. = FALSE)
  df <- data[, c(expo, income), drop = FALSE]
  df <- df[stats::complete.cases(df), , drop = FALSE]
  n <- nrow(df)
  if (n < 2L) stop("Need at least 2 rows to compute concentration index.", call. = FALSE)
  h <- .rmbl_num_input(df[[expo]], expo, allow_null = FALSE)
  inc <- .rmbl_num_input(df[[income]], income, allow_null = FALSE)
  if (any(!is.finite(h)) || any(!is.finite(inc))) {
    stop(sprintf("`%s` and `%s` must be finite", expo, income), call. = FALSE)
  }
  if (any(h < 0)) stop(sprintf("`%s` must be non-negative: an exposure is a concentration", expo), call. = FALSE)
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
    concidx = ci,
    interpretation = interp,
    expomean = mu,
    citation = "Wagstaff, Paci & van Doorslaer (1991) Soc Sci Med 33(5):545-557",
    extra = list(n = n, cov_h_R = cov_hr, curve = curve)
  ), class = "rmbl_equity")
}

#' Per-area pollution burden
#'
#' Applies \code{\link{polbrdn}} to every row of a table with one row
#' per area (forward sortation area, census tract, neighbourhood, ...) and
#' returns the rows sorted by attributable cases, worst first. Use it to
#' see where in a city or region the pollution burden falls, for example
#' to rank neighbourhoods for an intervention.
#'
#' @details
#' Each area is treated as wholly exposed at its own concentration
#' (\code{expoprev = 1}), with the pollutant's default reference
#' concentration. Every area is checked as \code{\link{polbrdn}}
#' checks a single population, and the first area that fails stops the
#' call with that area's error. Refusals: a column name that is not a single
#' string or not in the table, an empty table, and a non-numeric exposure,
#' population or rate column. The area labels can be of any type.
#'
#' @param areatab A data frame with one row per area: a label, the
#'   exposure in micrograms per cubic metre, the population in persons and
#'   the baseline rate per person-year (0.008 is 800 per 100,000).
#' @param areacol,expcol,popcol,basratecol Column
#'   names (single strings) of the label, exposure, population and rate;
#'   defaults \code{"fsa"}, \code{"exposure"}, \code{"population"} and
#'   \code{"brate"}.
#' @param poll,y,rare,hirate Passed to
#'   \code{\link{polbrdn}} for every area: the pollutant
#'   (default \code{"NO2"}), the outcome (default all-cause mortality), and
#'   the switches that admit a rate below 1e-5 or above 0.1 per
#'   person-year.
#' @return A data frame with one row per area, sorted by
#'   \code{attrcases}, largest first, and row names reset: the four
#'   input columns (exposure, population and rate as numbers) plus
#'   \code{rr} (relative risk), \code{paf} (attributable fraction),
#'   \code{attrcases} and \code{basecases} (per year).
#' @seealso \code{\link{expconcidx}} for how the burden
#'   is spread across income.
#' @examples
#' t <- data.frame(fsa = c("M6H", "M5V"), exposure = c(28, 18),
#'                 population = c(40000, 60000), brate = 0.008)
#' polbrdarea(t)
#'
#' # PM2.5 and different column names.
#' u <- data.frame(tract = c("A", "B", "C"), pm = c(7, 11, 9),
#'                 pop = c(5000, 8000, 6500), rate = 0.0075)
#' polbrdarea(u, areacol = "tract", expcol = "pm",
#'                          popcol = "pop", basratecol = "rate",
#'                          poll = "PM2.5")
#'
#' # A missing column is named in the error.
#' try(polbrdarea(t[, c("fsa", "exposure")]))
#' @export
polbrdarea <- function(areatab, areacol = "fsa", expcol = "exposure",
                                     popcol = "population",
                                     basratecol = "brate",
                                     poll = "NO2", y = "allcause",
                                     rare = FALSE, hirate = FALSE) {
  for (a in c("areacol", "expcol", "popcol", "basratecol")) .rmbl_colnames(get(a), a)
  required <- c(areacol, expcol, popcol, basratecol)
  missing <- setdiff(required, names(areatab))
  if (length(missing)) {
    stop(sprintf("areatab missing columns: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (!nrow(areatab)) stop("areatab has no rows", call. = FALSE)
  for (cl in c(expcol, popcol, basratecol)) {
    if (!is.numeric(areatab[[cl]])) {
      stop(sprintf("column `%s` must be numeric (a factor or character column is not a count)", cl), call. = FALSE)
    }
  }
  rows <- lapply(seq_len(nrow(areatab)), function(i) {
    r <- polbrdn(
      expomean = as.numeric(areatab[[expcol]][i]),
      expoprev = 1,
      brate = as.numeric(areatab[[basratecol]][i]),
      pop = as.numeric(areatab[[popcol]][i]),
      poll = poll, y = y, rare = rare, hirate = hirate)
    out <- data.frame(a = areatab[[areacol]][i], stringsAsFactors = FALSE)
    names(out) <- areacol
    out[[expcol]] <- as.numeric(areatab[[expcol]][i])
    out[[popcol]] <- as.numeric(areatab[[popcol]][i])
    out[[basratecol]] <- as.numeric(areatab[[basratecol]][i])
    out$rr <- r$extra$rr
    out$paf <- r$paf
    out$attrcases <- r$attrcases
    out$basecases <- r$basecases
    out
  })
  res <- do.call(rbind, rows)
  res <- res[order(-res$attrcases), , drop = FALSE]
  rownames(res) <- NULL
  res
}

# ---- vrfpol -------------------------------------------------------

#' Makes synthetic exposure and income data for the examples.
#'
#' Synthetic exposure and income with the orders of magnitude of Toronto
#' forward-sortation-area NO2 and CIHI asthma rates. R's own RNG, seeded locally.
#' @param pollutant \code{"no2"}, \code{"pm25"} or another name.
#' @return A data frame with `exposure` and `income`.
#' @noRd
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

#' Lists the assumptions of a burden calculation, each checked against the inputs.
#' @param pollutant The pollutant.
#' @param exposure_mean The mean exposure.
#' @param exposure_prevalence The share of the population exposed.
#' @param baseline_rate The baseline rate.
#' @param population The population size.
#' @param reference The counterfactual concentration.
#' @param rare_outcome Whether a rare outcome was declared.
#' @param high_rate Whether a high rate was declared.
#' @return A list of rows, each with `assumption`, `ok` and `note`.
#' @noRd
.pollution_assumptions <- function(pollutant, exposure_mean, exposure_prevalence,
                                   baseline_rate, population, reference, rare_outcome = FALSE,
                                   high_rate = FALSE) {
  top <- if (isTRUE(high_rate)) 1e5 else 1e4
  row <- function(name, ok, note) list(assumption = name, ok = isTRUE(ok), note = note)
  fin <- function(x) length(x) == 1L && is.finite(x)
  list(
    row("exposure finite and non-negative", fin(exposure_mean) && exposure_mean >= 0,
        if (!fin(exposure_mean) || exposure_mean < 0) {
          sprintf("expomean=%s is not a finite non-negative concentration", format(exposure_mean))
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
    # caller says which with rare = TRUE: giving the unit is not enough, since a wrapper
    # or do.call() passes it routinely (review of 52a8883, A6; of 02a38be, C4). Below 1e-6 per
    # 100k (fewer than one case in the world's population over a lifetime) no rate is plausible.
    # the top of the band is 10,000 per 100k (no population's all-cause death rate comes close);
    # hirate = TRUE admits a more common outcome, up to every person every year
    row(sprintf("brate finite: zero, or between %s and %s per 100k%s",
                if (isTRUE(rare_outcome)) "1e-6" else "1", format(top, big.mark = ",", scientific = FALSE),
                if (isTRUE(rare_outcome)) " (a rare outcome)" else ""),
        fin(baseline_rate) && baseline_rate >= 0 && baseline_rate <= top &&
          (baseline_rate == 0 || baseline_rate >= 1 || (isTRUE(rare_outcome) && baseline_rate >= 1e-6)),
        if (fin(baseline_rate) && baseline_rate < 1e-6 && baseline_rate > 0) {
          sprintf(paste("brate=%s per 100k is below one case per 100 billion person-years: not a",
                        "usable rate (check basrateper)"), format(baseline_rate))
        } else if (fin(baseline_rate) && baseline_rate < 1 && baseline_rate > 0 && !isTRUE(rare_outcome)) {
          sprintf(paste("brate=%s per 100k is below one case per 100,000. If it is a rate per person-year",
                        "(0.012 is 1,200 per 100k), pass basrateper = 1; if the outcome really is this",
                        "rare, say so with rare = TRUE"),
                  format(baseline_rate))
        } else if (fin(baseline_rate) && baseline_rate > top && baseline_rate <= 1e5) {
          sprintf(paste("brate=%s per 100k a year is above a whole population's all-cause death rate",
                        "(an age-specific rate for the oldest ages can be this high): if the outcome really is",
                        "this common, say so with hirate = TRUE"),
                  format(baseline_rate, big.mark = ",", scientific = FALSE))
        } else if (fin(baseline_rate) && baseline_rate == 0) {
          "brate=0: a measured zero rate, so no cases"
        } else {
          sprintf("brate=%s per 100k per year", format(baseline_rate))
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
#' \code{polrpttxt()} renders the result as plain text. It is the
#' one-call version of the pollution functions, made for scripts and the
#' command line: it never stops with an R error for bad input, but returns
#' a report whose status says what went wrong.
#'
#' @details
#' The assumption log checks that the exposure mean is finite and
#' non-negative and at most 10,000 micrograms per cubic metre, the
#' prevalence is in \eqn{[0, 1]}, the baseline rate (converted to per
#' 100,000) is zero or between 1 and 10,000 per 100,000 a year (from 1e-6
#' with \code{rare}, up to 100,000 with \code{hirate}), the
#' population is positive and at most 10 billion, the reference is finite
#' and non-negative, and the pollutant has a CRF. Any failure gives status
#' \code{"assumption_failure"} and skips the stages.
#'
#' With data (a CSV or the demo), the \code{"exposed"} are the rows above the
#' reference: their mean is \code{expomean} and their share
#' \code{expoprev}. Empty cells and missing-value tokens
#' (\code{NA}, \code{n/a}, \code{null}, \code{-} ...) are dropped with a
#' message; text that is not a number (a detection-limit flag such as
#' \code{"<2"}) and negative values stop the run with an error report. A
#' gzip, bzip2 or xz file is decompressed; UTF-16 and Latin-1 files are
#' decoded. An \code{income} column, when present and numeric, gives the
#' equity stage (\code{\link{expconcidx}}).
#'
#' The stages: \code{\link{crfpm25}} or \code{\link{crfno2}};
#' \code{\link{attrfrac}} with the CRF's interval;
#' \code{\link{mortdisp}} for removing the excess exposure over
#' the exposed population, with \eqn{\beta = \log(RR) / (\bar x - x_{ref})};
#' and \code{\link{polbrdn}}. The demo data are 1,000 synthetic
#' units with lognormal exposures at the scale of Toronto NO2 or PM2.5
#' levels and five income groups, drawn with a fixed seed (R's own random
#' stream is restored).
#'
#' @param poll \code{"no2"} or \code{"pm25"} (also \code{"PM2.5"}), in
#'   either case.
#' @param y Outcome key for the concentration-response function; the
#'   mortality outcomes count deaths, \code{"chiast"} incident
#'   cases.
#' @param reg,years Labels for the report.
#' @param demo Use synthetic demo data (\code{TRUE} or \code{FALSE}).
#' @param expcsv Path of a CSV with an \code{exposure} column in
#'   micrograms per cubic metre, or a NAPS pull with a \code{value} column
#'   and a \code{unit} column (required with \code{value}): each row is
#'   converted by its own unit, NO2 in ppb at 1.88 micrograms per cubic metre
#'   per ppb (the WHO 2021 conversion at 25 C and 1 atm), and any other unit
#'   is an error. With a CSV or the demo data the exposed are the rows above
#'   \code{ref}: \code{expoprev} is their share and
#'   \code{expomean} their mean, so Levin's formula is not diluted twice.
#' @param expomean,expoprev Scalar inputs used when neither
#'   \code{demo} nor \code{expcsv} is given: the mean exposure among
#'   the exposed and the share of the population exposed.
#'   A wrapper must never default one of them to zero: a prevalence of zero silently
#'   zeroes
#'   the burden, which is why the two are required together.
#' @param ref Counterfactual reference concentration; \code{NULL} takes
#'   the pollutant's default (PM2.5 5.8, NO2 10; see \code{\link{crfpm25}}).
#' @param basrateper The denominator \code{brate} is quoted per: 100,000
#'   (the default), or 1 for a rate per person-year such as a crude death rate of 0.012.
#' @param rare \code{TRUE} when the outcome really is rarer than one case per
#'   100,000
#'   per year. Without it a rate that converts to less than that is an assumption
#'   failure,
#'   because it is also what a rate per person-year passed as per 100,000 looks like
#'   (0.008
#'   per person-year is 800 per 100,000; as 0.008 per 100,000 the burden is 100,000 times
#'   too
#'   small). The check is on the converted rate, so it holds whatever
#'   \code{basrateper} is.
#' @param hirate \code{TRUE} when the outcome really is more common
#'   than 10,000 per 100,000 a year (no population's all-cause death
#'   rate is); without it such a rate is an assumption failure.
#' @param brate Baseline outcome rate per 100,000 per year (unlike
#'   \code{\link{polbrdn}}, which takes a rate per person-year).
#' @param pop Population at risk (persons).
#' @param report A result of \code{vrfpol()} (or a list with the
#'   same parts); anything else is refused with an R error.
#' @return \code{vrfpol()}: the report as a list of class
#'   \code{rmbl_pollution_report} (\code{plot()} draws it); its \code{status}
#'   is \code{"ok"}, \code{"assumption_failure"} or \code{"error"}, and the
#'   attribute \code{exitstat} carries a command-line exit code (0, 1 or
#'   2). An argument the pipeline cannot use (no exposure data at all, a
#'   vector where a single number is expected, an unknown outcome, a missing
#'   reference, a directory as \code{expcsv}) is an \code{"error"}
#'   report with exit status 2, never a raw R error; an exposure at or below
#'   the reference is a valid run with zero attributable cases, and the
#'   scalar inputs \code{expomean} and \code{expoprev} go
#'   together (one without the other is an error report).
#'   On \code{"ok"} the report also holds \code{inputs} (the resolved
#'   exposure mean and prevalence, the rate per 100,000, the population,
#'   the reference and the rows dropped), \code{assumptions} (a list of
#'   \code{assumption}, \code{ok}, \code{note}) and \code{pipeline}
#'   (\code{crf}, \code{paf}, \code{pafci}, \code{displaced},
#'   \code{burden} and \code{equity}, which is \code{NULL} without income
#'   data). \code{polrpttxt()}: a single character string with
#'   embedded newlines, ending in a \code{STATUS:} line (or \code{"ERROR:"}
#'   and the message for an error report).
#' @seealso \code{\link{polbrdn}} and the other stage functions
#'   to run one step on its own.
#' @examples
#' r <- vrfpol("no2", demo = TRUE)
#' r$status
#' r$pipeline$paf
#' cat(polrpttxt(r))
#'
#' # Scalar inputs: a city of 2.8 million at a PM2.5 mean of 9.
#' s <- vrfpol("pm25", expomean = 9, expoprev = 1,
#'                       brate = 750, pop = 2.8e6, reg = "Toronto")
#' s$pipeline$burden$attrcases
#' attr(s, "exitstat")
#'
#' # A CSV of measurements with an income column.
#' f <- tempfile(fileext = ".csv")
#' utils::write.csv(data.frame(exposure = c(12, 18, 25, 31, 9), income = 1:5), f,
#'                  row.names = FALSE)
#' vrfpol("no2", expcsv = f)$pipeline$equity$concidx
#'
#' # A rate per person-year passed as per 100,000 fails an assumption ...
#' bad <- vrfpol("no2", expomean = 20, expoprev = 1,
#'                         brate = 0.008)
#' bad$status
#' # ... and an argument it cannot use is an error report, not an R error.
#' vrfpol("no2")$error
#' @export
#' @srrstats {G2.9} Messages report ppb-to-ug/m3 conversion and dropped rows; test-stress-52a8883-review.R:395
#'   expect_message "have no exposure value".
vrfpol <- function(poll, y = "allcause", reg = NULL,
                             years = NULL, demo = FALSE, expcsv = NULL,
                             expomean = NULL, expoprev = NULL, ref = NULL,
                             brate = 500, basrateper = 1e5, pop = 1e6,
                             rare = FALSE, hirate = FALSE) {
  if (!is.character(poll) || length(poll) != 1L || is.na(poll)) {
    stop("`poll` must be one pollutant name (\"PM2.5\" or \"NO2\")", call. = FALSE)
  }
  pol <- .pollution_pollutant(poll)
  poll <- if (is.na(pol)) tolower(as.character(poll)) else if (pol == "NO2") "no2" else "pm25"
  equity_df <- NULL
  fail <- function(msg) {
    structure(list(status = "error", error = msg), exitstat = 2L,
              class = c("rmbl_pollution_report", "list"))
  }
  # the input contract is part of the report: an argument the pipeline cannot use is an
  # "error" report with exit status 2, never a raw stop() or a silently truncated vector
  if (!is.logical(demo) || length(demo) != 1L || is.na(demo)) return(fail("demo must be TRUE or FALSE"))
  if (is.null(ref)) ref <- if (identical(poll, "no2")) 10 else 5.8
  # the scalar inputs go together: a mean without a prevalence (or the reverse) is not a run
  # with the other at zero, it is half of the data
  no_scalar_data <- is.null(expomean) && is.null(expoprev)
  # one source of exposure: a CSV or the demo with scalars beside it is two answers to one question
  if (isTRUE(demo) && !is.null(expcsv)) {
    return(fail(paste("expcsv and demo = TRUE are two sources of exposure: pass one",
                      "(the demo was used silently before)")))
  }
  if ((isTRUE(demo) || !is.null(expcsv)) && !no_scalar_data) {
    return(fail(paste("expomean / expoprev cannot be combined with expcsv or demo:",
                      "pass one source of exposure")))
  }
  if (xor(is.null(expomean), is.null(expoprev))) {
    return(fail("expomean and expoprev go together: pass both (a zero is a measurement), or neither"))
  }
  # the two population inputs have defaults, not an "absent" value: NULL is a wrong call
  if (is.null(pop)) return(fail("population must be a single number (persons at risk), not NULL"))
  # a number is numeric: as.raw(25) was read as 25 (review of 02a38be)
  scalars <- c("expomean", "expoprev", "brate", "basrateper", "pop", "ref")
  for (nm in scalars) {
    v <- get(nm)
    # a missing value (NA) is not a type error: the checks below report it
    if (!is.null(v) && !is.numeric(v) && !(is.logical(v) && all(is.na(v)))) {
      return(fail(sprintf("%s must be a single number, not %s", nm, class(v)[1L])))
    }
  }
  if (is.null(brate)) return(fail("brate must be a single number, not NULL"))
  if (!is.logical(rare) || length(rare) != 1L || is.na(rare)) {
    return(fail("rare must be TRUE or FALSE"))
  }
  if (!is.logical(hirate) || length(hirate) != 1L || is.na(hirate)) {
    return(fail("hirate must be TRUE or FALSE"))
  }
  if (!is.numeric(basrateper) || length(basrateper) != 1L || !is.finite(basrateper) ||
        basrateper <= 0) {
    return(fail(paste("basrateper must be a single positive number",
                      "(100000 for a rate per 100,000, 1 per person-year)")))
  }
  for (nm in c("ref", "expomean", "expoprev", "brate", "pop")) {
    v <- get(nm, inherits = FALSE)
    if (is.null(v)) next
    # a flag, text, a date, a factor, a list or a complex was refused by type above; a missing
    # value (NA) is logged as a failed assumption below
    if (length(v) != 1L) return(fail(sprintf("%s must be a single number, not %d values", nm, length(v))))
  }
  ref <- suppressWarnings(as.numeric(ref))
  if (!is.character(y) || length(y) != 1L || is.na(y)) {
    return(fail("outcome must be a single outcome name"))
  }
  # the exposed are the rows above the counterfactual floor: Levin's formula wants the
  # relative risk among them and their share, not the population mean twice over
  exposed_summary <- function(x) {
    x <- x[!is.na(x)]
    above <- if (is.finite(ref)) x[x > ref] else x
    list(mean = if (length(above)) mean(above) else if (length(x)) mean(x) else NA_real_,
         prevalence = if (length(x)) length(above) / length(x) else NA_real_)
  }
  dropped_rows <- 0L
  if (isTRUE(demo)) {
    df <- .pollution_demo_data(poll)
    es <- exposed_summary(df$exposure)
    expomean <- es$mean
    expoprev <- es$prevalence
    equity_df <- df
    data_source <- "demo (synthetic)"
  } else if (!is.null(expcsv)) {
    if (!is.character(expcsv) || length(expcsv) != 1L || is.na(expcsv)) {
      return(fail("expcsv must be a single file path"))
    }
    if (!file.exists(expcsv)) return(fail(sprintf("exposure CSV not found: %s", expcsv)))
    if (dir.exists(expcsv)) return(fail(sprintf("exposure CSV is a directory, not a file: %s", expcsv)))
    empty <- sprintf("%s is empty (expected a column exposure in ug/m3, or a NAPS pull's value + unit)", expcsv)
    if (isTRUE(file.size(expcsv) == 0)) return(fail(empty))
    df <- tryCatch(.pollution_read_csv(expcsv), error = function(e) e)
    if (inherits(df, "error")) return(fail(sprintf("%s: %s", expcsv, conditionMessage(df))))
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
      bad <- !is.na(vals) & !(unit %in% ugm3) & !(is_ppb & poll == "no2")
      if (any(bad)) {
        return(fail(sprintf("exposure unit %s is not ug/m3 for %s",
                            paste(sort(unique(unit[bad])), collapse = ", "), poll)))
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
    expomean <- es$mean
    expoprev <- es$prevalence
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
    data_source <- expcsv
  } else {
    expomean <- as.numeric(expomean)
    expoprev <- as.numeric(expoprev)
    data_source <- "scalar arguments"
    # neither given is no data at all: a call with nothing to verify, not a clean run with zero
    # deaths; a missing or negative value is a failed assumption, logged below
    if (no_scalar_data) {
      return(fail(paste("no exposure data: pass expcsv, or expomean and expoprev,",
                        "or demo = TRUE")))
    }
  }
  brate <- as.numeric(brate) * 1e5 / basrateper   # per 100,000 from here on
  pop <- as.numeric(pop)
  assumptions <- .pollution_assumptions(poll, expomean, expoprev,
                                        brate, pop, ref, rare, hirate)
  report <- list(
    command = "verify-pollution", pollutant = poll, outcome = y,
    region = reg, years = years, dsou = data_source,
    inputs = list(expomean = expomean, expoprev = expoprev,
                  baserateper100k = brate, population = pop,
                  refconc = ref, drorows = dropped_rows),
    assumptions = assumptions)
  if (!all(vapply(assumptions, function(a) isTRUE(a$ok), logical(1)))) {
    report$status <- "assumption_failure"
    report$pipeline <- list(skipped = TRUE, reason = "assumptions")
    return(structure(report, exitstat = 1L, class = c("rmbl_pollution_report", "list")))
  }
  crf <- tryCatch(
    if (poll == "no2") {
      crfno2(expomean, y = y, refconc = ref)
    } else {
      crfpm25(expomean, y = y, refconc = ref)
    },
    error = function(e) e)
  if (inherits(crf, "error")) return(fail(conditionMessage(crf)))
  paf <- tryCatch(attrfrac(crf$rr, expoprev,
                                        rrlo = if (is.finite(crf$rrlo)) crf$rrlo,
                                        rrup = if (is.finite(crf$rrup)) crf$rrup),
                  error = function(e) e)
  if (inherits(paf, "error")) return(fail(conditionMessage(paf)))
  paf_ci <- attr(paf, "ci")
  baseline_per_person <- brate / 1e5
  exposure_delta <- max(0, expomean - ref)
  beta_per_unit <- log(crf$rr) / max(exposure_delta, 1e-9)
  # the deaths displaced by removing the excess exposure are counted over the exposed share of the
  # population, and the burden uses the same reference concentration as the RR printed above it
  # every stage runs inside the status contract: what it refuses is an "error" report, never a
  # raw condition out of vrfpol()
  staged <- tryCatch({
    # the rate's band was checked above, with the caller's switches: they go to the stages too, or
    # a rate the caller vouched for (hirate, rare) was refused again by the stage
    displaced <- mortdisp(exposure_delta, pop * expoprev,
                                     baseline_per_person, beta_per_unit,
                                     rare = rare, hirate = hirate)
    burden <- polbrdn(expomean, expoprev, baseline_per_person, pop,
                               poll = if (poll == "pm25") "PM2.5" else "NO2",
                               y = y, refconc = ref,
                               rare = rare, hirate = hirate)
    equity <- if (!is.null(equity_df) && "income" %in% names(equity_df)) {
      complete <- sum(is.finite(equity_df$exposure) & is.finite(suppressWarnings(as.numeric(equity_df$income))))
      if (complete < 2L || !any(equity_df$exposure > 0, na.rm = TRUE)) {
        NULL  # one usable row, or no exposure anywhere: there is no gradient to measure
      } else {
        expconcidx(equity_df, "exposure", "income")
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
    crf = unclass(crf), paf = as.numeric(paf), pafci = paf_ci,
    displaced = list(deadisp = displaced, expdel = exposure_delta,
                     betaperunit = beta_per_unit, unit = .pollution_outcome_unit(y)),
    burden = unclass(burden),
    equity = if (is.null(equity)) NULL else unclass(equity))
  structure(report, exitstat = 0L, class = c("rmbl_pollution_report", "list"))
}

#' Formats the interval of an attributable fraction for printing.
#' @param ci The interval, with `lower` and `upper`, or NULL.
#' @return One string, \code{""} when there is no interval.
#' @noRd
.pollution_paf_ci_text <- function(ci) {
  if (is.null(ci)) return("")
  sprintf("  (95%% CI %.4f to %.4f, from the risk's limits)", ci[["lower"]], ci[["upper"]])
}

#' @rdname vrfpol
#' @export
polrpttxt <- function(report) {
  if (!inherits(report, "rmbl_pollution_report") && !(is.list(report) && is.character(report$status))) {
    stop("`report` must be a report from vrfpol()", call. = FALSE)
  }
  bar <- strrep("=", 66)
  if (identical(report$status, "error")) return(paste0("ERROR: ", report$error, "\n"))
  # a list that only looks like a report (status "ok" and no inputs) is refused in words, not with
  # "$ operator is invalid for atomic vectors"
  parts_ok <- is.list(report$inputs) && is.list(report$assumptions) &&
    all(vapply(report$assumptions, function(a) is.list(a) && is.logical(a$ok), logical(1))) &&
    (!identical(report$status, "ok") || is.list(report$pipeline))
  if (!parts_ok) {
    stop("`report` is not a complete vrfpol() report (its inputs, assumptions or pipeline are missing)",
         call. = FALSE)
  }
  lines <- c(bar, sprintf("  %s -- %s -> %s", report$command, toupper(report$pollutant), report$outcome))
  if (!is.null(report$region)) lines <- c(lines, sprintf("  region: %s", report$region))
  if (!is.null(report$years)) lines <- c(lines, sprintf("  years:  %s", report$years))
  inp <- report$inputs
  lines <- c(lines, sprintf("  data:   %s", report$dsou), bar, "", "Inputs",
             sprintf("  exposure mean:      %.3f", inp$expomean),
             sprintf("  exposure prevalence:%.3f", inp$expoprev),
             sprintf("  baseline rate/100k: %.2f", inp$baserateper100k),
             sprintf("  population:         %s", format(inp$population, big.mark = ",", scientific = FALSE)),
             sprintf("  reference conc:     %s", format(inp$refconc)),
             if (isTRUE(inp$drorows > 0)) {
               sprintf("  rows dropped:       %d (no exposure value)", inp$drorows)
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
             "", sprintf("Attributable fraction (PAF): %.4f%s", p$paf, .pollution_paf_ci_text(p$pafci)),
             "", if (identical(p$displaced$unit, "deaths")) "Mortality displaced" else "Cases displaced",
             sprintf("  expected avoided %s: %.1f", p$displaced$unit %||% "deaths",
                     p$displaced$deadisp),
             "", "Burden of pollution",
             sprintf("  attributable %s:   %.1f", p$burden$extra$unit %||% "deaths",
                     p$burden$attrcases))
  if (!is.null(p$equity)) {
    lines <- c(lines, "", "Equity analysis",
               sprintf("  concentration index: %.4f", p$equity$concidx))
  }
  paste0(paste(lines, collapse = "\n"), "\n\nSTATUS: ok\n")
}

#' Reads the exposure CSV whole.
#'
#' The exposure CSV, read whole: a gzip, bzip2 or xz file is decompressed (as read.csv did
#' before 0.5.12, review of 52a8883, A4) and checked to be complete (.rmbl_decompress_checked), a
#' UTF-16 file is decoded with or without its byte-order mark, a UTF-8 BOM is dropped, a file that
#' is not UTF-8 is read as Latin-1 (and said), other NUL bytes are refused. A parse that reports a
#' problem (an unbalanced quote that swallowed the rest of the file, A5) stops with the parser's
#' own message instead of returning the rows before it.
#' @param path The file.
#' @return A data frame.
#' @noRd
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
  acc <- new.env(parent = emptyenv())
  acc$problems <- character()
  df <- withCallingHandlers(
    utils::read.csv(src, stringsAsFactors = FALSE, encoding = "UTF-8"),
    warning = function(w) {
      m <- conditionMessage(w)
      if (!grepl("incomplete final line", m, fixed = TRUE)) acc$problems <- c(acc$problems, m)
      invokeRestart("muffleWarning")
    })
  if (length(acc$problems)) {
    stop(sprintf("could not be read cleanly (%s): no rows are used from a file the parser stopped part-way through",
                 acc$problems[[1L]]), call. = FALSE)
  }
  df
}

#' Decompresses a compressed CSV whole and checks that it is complete.
#'
#' A compressed CSV, decompressed whole and checked to be complete. R's gzfile() returns whatever
#' a truncated gzip or bzip2 file decodes to, with no error and no warning, so half a file was read
#' as a whole one (review of 02a38be, C3). gzip goes through zlib in C (every member's CRC-32 and
#' length checked); a bzip2 file must end with its end-of-stream marker; an xz decoder warning
#' (\dQuote{lzma decoding result 10} for a cut file) is an error. The output is capped
#' while it is read
#' (option rmoriebricklayer.maxcsvbytes, 1 GiB by default): a few megabytes of gzip no longer
#' expand to gigabytes before anything is refused.
#' @param path The file.
#' @param head The file's first bytes.
#' @return A raw vector.
#' @noRd
.rmbl_decompress_checked <- function(path, head = readBin(path, "raw", 6L)) {
  lim <- min(.rmbl_max_csv_bytes(), 2^31 - 2)   # rawToChar() takes at most 2^31 - 1 bytes
  if (length(head) >= 2L && identical(head[1:2], as.raw(c(0x1f, 0x8b)))) {
    return(.Call(C_rmbl_gunzip_checked, readBin(path, "raw", file.size(path)), lim))
  }
  bz <- length(head) >= 3L && identical(head[1:3], charToRaw("BZh"))
  if (bz && !.rmbl_bzip2_complete(path))
    stop("is truncated: the bzip2 stream has no end-of-stream marker", call. = FALSE)
  con <- gzfile(path, "rb")   # bzip2 and xz
  on.exit(close(con), add = TRUE)
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

#' Returns the most a CSV may decompress to.
#'
#' The option rmoriebricklayer.maxcsvbytes (1 GiB by default): the most a CSV may decompress to,
#' for the pollution readers and dload() alike.
#' @return A number of bytes.
#' @noRd
.rmbl_max_csv_bytes <- function() {
  lim <- .rmbl_getopt("maxcsvbytes", 2^30)
  if (!is.numeric(lim) || length(lim) != 1L || is.na(lim) || lim < 0)
    stop("option rmoriebricklayer.maxcsvbytes must be a single non-negative number", call. = FALSE)
  as.numeric(lim)
}

#' Says whether a bzip2 file ends with its end-of-stream marker.
#'
#' A bzip2 stream ends with the 48-bit end-of-stream magic 0x177245385090, a 32-bit CRC and zero
#' padding to the next byte; none of it is byte-aligned. A file cut anywhere before its end lacks
#' it in its last 11 bytes.
#' @param path The file.
#' @return TRUE or FALSE.
#' @noRd
.rmbl_bzip2_complete <- function(path) {
  n <- file.size(path)
  if (is.na(n) || n < 14) return(FALSE)
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  seek(con, n - 11)
  tail <- readBin(con, "raw", 11L)
  bits <- unlist(lapply(tail, function(b) rev(as.integer(rawToBits(b)))))

  magic <- unlist(lapply(as.raw(c(0x17, 0x72, 0x45, 0x38, 0x50, 0x90)), function(b) rev(as.integer(rawToBits(b)))))
  for (p in 1:8) {   # magic at bit p (0-based), then 32 CRC bits, then 0-7 zero padding bits
    if (identical(bits[(p + 1):(p + 48)], magic) && all(bits[seq_len(88) > p + 80] == 0L)) return(TRUE)
  }
  FALSE
}
