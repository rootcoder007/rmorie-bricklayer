# Areal statistics for region-coded tables.
#
# An administrative extract keys on a region, not on a coordinate: OTIS
# carries Region_MostRecentPlacement and no geometry at all. That rules
# out the distance-based spatial toolkit and rules IN the areal one,
# which is the right family anyway for a count attached to a unit with a
# population.
#
# Three things go wrong with a table of regional counts. The regions
# hold different numbers of people, so the counts are not comparable.
# They hold different KINDS of people, so even the rates are not
# comparable. And a small region's rate is mostly noise, so a league
# table of rates ranks the small regions to the top and bottom by
# construction. Indirect standardisation fixes the second, empirical
# Bayes the third, and a funnel plot shows the reader the first.

#' Expected counts under indirect standardisation
#'
#' @description
#' Computes, for each area (region, district, institution), the count it
#' would have if it experienced the overall rate in every stratum, given its
#' own population in each stratum. Comparing an area's observed count with
#' this expected count, rather than comparing raw rates, removes the part of
#' the difference that is explained by who lives in (or is held in) the
#' area. The result feeds \code{\link{stdinc}}, \code{\link{ebrates}} and
#' \code{\link{fnllim}}.
#'
#' @details
#' With \eqn{O_{as}} and \eqn{P_{as}} the count and population of area
#' \eqn{a} in stratum \eqn{s}, the reference rate of a stratum is pooled over
#' all areas, \eqn{r_s = \sum_a O_{as} / \sum_a P_{as}}, and
#' \deqn{E_a = \sum_s P_{as} r_s.}
#' Without strata the expected count is just the area's population times
#' the overall rate, which adjusts for size but not for composition. The
#' two are worth distinguishing: a region holding disproportionately many
#' young men will show an excess on the first and may show none on the
#' second, and only the second is evidence about the region.
#'
#' Rows may repeat an area-stratum pair; they are summed. Rows with a
#' missing count, population, area or stratum are dropped. The output is
#' sorted by area label. Because the reference rates come from the same
#' data, \eqn{\sum_a E_a = \sum_a O_a}.
#'
#' Errors: non-numeric, negative or infinite counts or populations; a
#' population of zero; \code{cnts}, \code{pop}, \code{area} or
#' \code{strata} of different lengths.
#'
#' @param cnts Numeric vector of observed counts (non-negative), one per
#'   row of the area-by-stratum table.
#' @param pop Numeric vector of the population at risk (positive),
#'   the same length as \code{cnts}.
#' @param area Vector of area labels, one per row (converted to character).
#' @param strata Optional vector of stratum labels, one per row: an age
#'   band, a gender, or their interaction. Default \code{NULL}: one stratum,
#'   so only size is adjusted for. With strata the standardisation is
#'   indirect in the usual sense: the overall stratum-specific rates are
#'   applied to each area's own stratum populations.
#' @return A data frame with one row per area and columns \code{area}
#'   (character), \code{observed}, \code{population} and \code{expected}
#'   (numeric totals over the area's rows).
#' @references
#' Lawson, A. B. \emph{Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling}. Chapman and Hall/CRC. Chapter 1 sets out the convention used
#' here: the expected counts come from applying the overall population rate
#' to each area, and the standardised incidence ratio is the ratio of count
#' to expected.
#'
#' Hedderich, J. and Sachs, L. (2020). \emph{Applied Statistics: Methods Using
#' R}. Springer, on the distinction between indirect standardisation, which
#' applies the reference's stratum-specific rates to the study population,
#' and direct standardisation, which does the reverse.
#' @seealso
#' \code{\link{stdinc}}, \code{\link{ebrates}}, \code{\link{fnllim}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- data.frame(
#'   region = rep(c("North", "South", "East"), each = 2),
#'   age = rep(c("18 to 24", "25 to 49"), 3),
#'   n = c(30, 45, 12, 60, 8, 20),
#'   pop = c(1000, 6000, 900, 9000, 400, 3500)
#' )
#'
#' # Adjusting for size only.
#' expcnts(d$n, d$pop, d$region)
#'
#' # Adjusting for size AND age composition, which is the comparison
#' # that says something about the region.
#' e <- expcnts(d$n, d$pop, d$region, strata = d$age)
#' e
#'
#' # the expected counts feed the standardised ratio
#' stdinc(e$observed, e$expected, area = e$area)
#'
#' # a population of zero has no rate
#' try(expcnts(c(1, 2), c(10, 0), c("a", "b")))
#' @export
expcnts <- function(cnts, pop, area, strata = NULL) {
  .rmbl_no_fn(area = area, strata = strata)
  # the missing values are kept until the rows are dropped together: dropped
  # from each vector alone, the counts and populations paired the wrong rows
  cnts <- .ar_keep_na(cnts, "cnts")
  pop <- .ar_keep_na(pop, "pop")
  area <- as.character(area)
  n <- length(cnts)
  if (length(pop) != n || length(area) != n) {
    stop("`cnts`, `pop` and `area` must be the same length", call. = FALSE)
  }
  if (any(pop <= 0, na.rm = TRUE)) {
    stop("expcnts: `pop` must be positive", call. = FALSE)
  }
  if (is.null(strata)) {
    strata <- rep("all", n)
  } else {
    strata <- as.character(strata)
    if (length(strata) != n) {
      stop("`strata` must be the same length as `cnts`", call. = FALSE)
    }
  }
  ok <- !is.na(cnts) & !is.na(pop) & !is.na(area) & !is.na(strata)
  cnts <- cnts[ok]
  pop <- pop[ok]
  area <- area[ok]
  strata <- strata[ok]
  # the reference rate in each stratum, over every area at once
  num <- tapply(cnts, strata, sum)
  den <- tapply(pop, strata, sum)
  rate <- num / den
  expected_row <- pop * rate[match(strata, names(rate))]
  areas <- sort(unique(area))
  .rmbl_cls(data.frame(
    area = areas,
    observed = as.numeric(tapply(cnts, area, sum)[areas]),
    population = as.numeric(tapply(pop, area, sum)[areas]),
    expected = as.numeric(tapply(expected_row, area, sum)[areas]),
    stringsAsFactors = FALSE
  ), "rmbl_expected")
}

#' Standardised incidence ratio, with an exact interval
#'
#' @description
#' Divides each area's observed count by its expected count to give the
#' standardised incidence ratio (SIR), and adds an exact Poisson confidence
#' interval. A ratio of one is the overall experience; above one is an
#' excess and below one a deficit. Use it after \code{\link{expcnts}}
#' to say which areas differ from the overall rate by more than chance.
#'
#' @details With observed count \eqn{O} and expected \eqn{E}, \eqn{SIR = O / E}.
#' The interval for \eqn{1 - \alpha} coverage is
#' \deqn{\left[\frac{G^{-1}(\alpha/2;\, O)}{E},\ \frac{G^{-1}(1-\alpha/2;\,
#' O+1)}{E}\right]} where \eqn{G^{-1}(p; k)} is the gamma quantile with shape
#' \eqn{k}; the lower limit is 0 when \eqn{O = 0}. This is the exact Poisson
#' interval, from the relation between the Poisson and gamma distributions, and
#' so is identical to \code{stats::poisson.test()}'s. It is the interval to use
#' here because the counts that matter are small: a normal approximation on an
#' observed count of three is not an interval, it is a decoration.
#'
#' Each area's interval is a separate test; with many areas some will
#' exclude one by chance (see \code{\link{scanadj}}). A row with a missing
#' observed or expected count is dropped whole (its area label with it), after
#' the lengths are compared.
#'
#' Errors: negative, infinite or non-numeric counts; an expected count of
#' zero or below; lengths that differ (a single \code{expd} is recycled).
#' A \code{conflvl} outside (0, 1) is an error.
#'
#' @param obs Numeric vector of observed counts (non-negative).
#' @param expd Numeric vector of expected counts (positive), for example
#'   from \code{\link{expcnts}}; the same length as \code{obs},
#'   or length one.
#' @param area Optional vector of area labels, added as the first column.
#'   Default \code{NULL}.
#' @param conflvl Number in (0, 1), default \code{0.95}: the two-sided
#'   confidence level of the interval.
#' @return A data frame with one row per area: \code{area} (when given),
#' \code{observed}, \code{expected}, \code{sir}, \code{lower}, \code{upper}
#' (numeric), and logical \code{excess} (the interval lies above one),
#' \code{deficit} (the interval lies below one) and \code{significant}
#' (either).
#' @references
#' Lawson, A. B. \emph{Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling}. Chapman and Hall/CRC, Chapter 1.
#' @seealso
#' \code{\link{expcnts}}, \code{\link{ebrates}},
#' \code{\link{fnllim}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' stdinc(obs = c(30, 12, 3), expd = c(20, 14, 5),
#'     area = c("North", "South", "East"))
#'
#' # An observed count of three carries almost no information, and the
#' # interval says so rather than hiding it.
#' stdinc(3, 5)
#'
#' # a 90 percent interval, and a zero count (lower limit exactly 0)
#' stdinc(c(0, 40), c(2, 25), conflvl = 0.90)
#'
#' try(stdinc(c(3, 4), c(5, 0)))
#' @export
#' @srrstats {G2.0} .rmbl_conf_level()/.rmbl_scalar() refuse inputs of the wrong
#'   length; test-docs-bugs-0513.R:34 refuses conflvl = c(0.9, 0.95).
stdinc <- function(obs, expd, area = NULL, conflvl = 0.95) {
  obs <- .ar_keep_na(obs, "obs", min_n = 1L)
  expd <- .ar_keep_na(expd, "expd", min_n = 1L)
  if (length(expd) == 1L) {
    expd <- rep(expd, length(obs))
  }
  if (length(obs) != length(expd)) {
    stop("stdinc: `obs` and `expd` must be the same length", call. = FALSE)
  }
  if (any(expd <= 0, na.rm = TRUE)) {
    stop("stdinc: `expd` must be positive", call. = FALSE)
  }
  if (
    !is.null(area) &&
      (!is.atomic(area) || is.matrix(area) || length(area) != length(obs))
  ) {
    stop(
      "stdinc: `area` must be NULL or one label per area (as many as `obs`)",
      call. = FALSE
    )
  }
  conflvl <- .rmbl_conf_level(conflvl)
  ok <- .ar_complete(obs, expd)
  obs <- obs[ok]
  expd <- expd[ok]
  area <- area[ok]
  a <- 1 - conflvl
  # the exact Poisson interval, via the gamma relation: an observed
  # count of zero has a lower limit of exactly zero rather than a
  # negative one
  lo <- ifelse(obs == 0, 0, stats::qgamma(a / 2, shape = obs)) / expd
  hi <- stats::qgamma(1 - a / 2, shape = obs + 1) / expd
  out <- data.frame(
    observed = obs,
    expected = expd,
    sir = obs / expd,
    lower = lo,
    upper = hi,
    excess = lo > 1,
    deficit = hi < 1,
    significant = lo > 1 | hi < 1,
    stringsAsFactors = FALSE
  )
  if (!is.null(area)) {
    out <- cbind(area = as.character(area), out, stringsAsFactors = FALSE)
  }
  .rmbl_cls(out, "rmbl_sir")
}

#' Empirical Bayes rates, shrunk toward the overall experience
#'
#' @description
#' A small area's rate is mostly noise, so ranking areas by their raw ratios
#' puts the smallest areas at both ends of the table by construction. This
#' function borrows strength across areas: each area's ratio of observed to
#' expected is pulled toward the overall ratio by an amount that depends on
#' how little information the area carries. Use the shrunk estimates for
#' maps and rankings; use \code{\link{stdinc}} for each area's own evidence.
#'
#' @details The area relative risks \eqn{\theta_a} are taken to come from a
#' gamma prior with shape \eqn{\nu} and rate \eqn{\alpha}. Its mean is the
#' overall ratio \eqn{m = \sum O_a / \sum E_a}, and its variance is estimated by
#' the method of moments, \deqn{s^2 = \frac{\sum_a E_a (\theta_a - m)^2}{\sum_a
#' E_a} - \frac{m}{\bar E},} with \eqn{\theta_a = O_a / E_a} and \eqn{\bar E}
#' the mean expected count; the subtracted term is the spread that Poisson
#' sampling alone would produce. Then \eqn{\alpha = m / s^2}, \eqn{\nu = m^2 /
#' s^2}, and the posterior mean \eqn{(O_a + \nu)/(E_a + \alpha)} is reported,
#' with shrinkage \eqn{\alpha / (E_a + \alpha)}. Where the expected count is
#' large the data dominate and the estimate barely moves; where it is small the
#' prior does, which is the intended behaviour and not a defect.
#'
#' When the between-area variance estimate comes out at or below zero there
#' is no evidence of any real variation between areas, and every estimate
#' collapses to the overall rate. That is reported through \code{shrinkage}
#' (all ones) and \code{NA} prior parameters rather than hidden.
#'
#' Errors: lengths that differ; missing, negative or infinite counts;
#' missing, infinite or non-positive expected counts; fewer than two areas.
#'
#' @param obs Numeric vector of observed counts (non-negative, no
#'   \code{NA}).
#' @param expd Numeric vector of expected counts (positive), the same
#'   length, for example from \code{\link{expcnts}}.
#' @return A data frame with one row per area: \code{area} (when given),
#' \code{observed}, \code{expected}, the raw ratio \code{sir}, the shrunk
#' estimate \code{eb}, the \code{shrinkage} applied (zero means untouched,
#' one means replaced by the overall rate), and the fitted prior's \code{nu}
#' (shape) and \code{alpha} (rate), the same on every row.
#' @references
#' Clayton, D. and Kaldor, J. (1987). Empirical Bayes estimates of
#' age-standardized relative risks for use in disease mapping.
#' \emph{Biometrics} 43(3), 671-681.
#'
#' Lawson, A. B. \emph{Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling}. Chapman and Hall/CRC, which cites Clayton and Kaldor as the
#' empirical-Bayes approximation in the development of Bayesian disease
#' mapping.
#' @seealso
#' \code{\link{stdinc}}, \code{\link{fnllim}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Three areas, one of them tiny. The tiny area's raw ratio is
#' # extreme; its shrunk one is not.
#' ebrates(obs = c(30, 45, 2), expd = c(25, 50, 0.5),
#'          area = c("North", "South", "Tiny"))
#'
#' # no variation beyond chance: every estimate is the overall ratio
#' ebrates(c(10, 11, 9), c(10, 10, 10))
#'
#' # one area has nothing to borrow from
#' try(ebrates(5, 4))
#' @export
#' @inheritParams stdinc
ebrates <- function(obs, expd, area = NULL) {
  obs <- .rmbl_num(obs, "obs")
  expd <- .rmbl_num(expd, "expd")
  .eb_check(obs, expd, area)
  n <- length(obs)
  theta <- obs / expd
  esum <- sum(expd)
  # the overall relative risk, which is the prior's mean
  m <- sum(obs) / esum
  # and its variance, by the method of moments; the subtracted term is
  # the part of the spread in theta that the Poisson sampling alone
  # would produce, so what is left is the between-area variation
  s2 <- sum(expd * (theta - m)^2) / esum - m / (esum / n)
  s2 <- max(s2, 0)
  if (s2 <= 0) {
    # no evidence of real variation between areas: every estimate is the
    # overall rate, and the shrinkage is total
    return(.eb_frame(
      area,
      obs,
      expd,
      theta,
      rep(m, n),
      rep(1, n),
      NA_real_,
      NA_real_
    ))
  }
  alpha <- m / s2
  nu <- m^2 / s2
  eb <- (obs + nu) / (expd + alpha)
  # the weight the DATA carry, so shrinkage is one minus it
  w <- expd / (expd + alpha)
  .eb_frame(area, obs, expd, theta, eb, 1 - w, nu, alpha)
}

#' Funnel-plot control limits
#'
#' @description
#' Gives the range within which an area's ratio of observed to expected
#' would fall, for a given expected count, if the area were no different
#' from the overall experience. Plotted against the expected count these
#' limits form a funnel: wide for small areas, narrow for large ones. A
#' funnel plot is the alternative to a league table: it shows directly that
#' a small area's ratio can wander far from one without meaning anything.
#'
#' @details
#' For expected count \eqn{E}, target ratio \eqn{\rho} and coverage
#' \eqn{1 - a}, the limits are
#' \deqn{\frac{Q(a/2;\ \rho E)}{E},\quad \frac{Q(1 - a/2;\ \rho E)}{E}}
#' with \eqn{Q} the Poisson quantile function. They are exact Poisson
#' quantiles divided by the expected count, so they are the discrete
#' counterpart of the usual normal funnel and stay correct at the small
#' expected counts where the normal version goes below zero. Because the
#' Poisson is discrete the limits move in steps of \eqn{1/E}. The usual pair
#' of levels, 0.95 and 0.998, corresponds to about two and three standard
#' deviations.
#'
#' Errors: non-positive, infinite or missing expected counts (missing
#' values are dropped); a non-positive \code{target}; a level outside
#' (0, 1).
#'
#' @param expd Numeric vector of expected counts (positive) at which to
#'   compute limits, for example a grid from the smallest to the largest
#'   area.
#' @param target Number, default \code{1}: the ratio the limits are centred
#'   on. One is the overall experience.
#' @param lvls Numeric vector of two-sided coverage levels in (0, 1),
#'   default \code{c(0.95, 0.998)}; one pair of limits per level.
#' @return A data frame with one row per expected count and level, sorted by
#' level then expected count, with numeric columns \code{expected},
#' \code{level}, \code{lower} and \code{upper} (the limits on the ratio
#' scale).
#' @references
#' Spiegelhalter, D. J. (2005). Funnel plots for comparing institutional
#' performance. \emph{Statistics in Medicine} 24(8), 1185-1202.
#' \doi{10.1002/sim.1970}
#'
#' \emph{Advanced Statistics in Criminology and Criminal Justice} discusses
#' the funnel plot as the display of the relationship between an estimate
#' and the sample size behind it.
#'
#' Lawson, A. B. \emph{Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling}. Chapman and Hall/CRC, on the Poisson counts these limits are
#' built from.
#' @seealso
#' \code{\link{stdinc}}, \code{\link{ebrates}}
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # The funnel narrows as the expected count grows, which is the whole
#' # point: a ratio of 2 means nothing at an expected count of 2 and a
#' # great deal at an expected count of 200.
#' fnllim(c(2, 20, 200))
#'
#' # one 90 percent funnel around a target ratio of 1.2
#' fnllim(c(5, 50), target = 1.2, lvls = 0.90)
#'
#' # a funnel drawn with base graphics
#' e <- c(1, 2, 5, 10, 20, 50, 100, 200)
#' f <- fnllim(e, lvls = 0.95)
#' plot(f$expected, f$upper, type = "s", log = "x", ylim = c(0, 4),
#'      xlab = "expected count", ylab = "ratio")
#' lines(f$expected, f$lower, type = "s")
#' abline(h = 1, lty = 2)
#'
#' try(fnllim(10, lvls = 1))
#' @export
fnllim <- function(expd, target = 1, lvls = c(0.95, 0.998)) {
  expd <- .rmbl_finite_input(expd, "expd", min_n = 1L)
  if (any(expd <= 0, na.rm = TRUE)) {
    stop("fnllim: `expd` must be positive", call. = FALSE)
  }
  # c(1, 2) used the first target and said nothing of the second
  target <- .rmbl_num(target, "target")
  if (length(target) != 1L || is.na(target) || target <= 0) {
    stop(.rmbl_fn(), "`target` must be positive: one number", call. = FALSE)
  }
  lvls <- .rmbl_num(lvls, "lvls")
  # NULL, NA and numeric(0) gave an empty frame of limits
  if (!length(lvls) || anyNA(lvls)) {
    stop(
      .rmbl_fn(),
      "`lvls` must be one or more levels, with no missing value",
      call. = FALSE
    )
  }
  lvls <- sort(lvls)
  if (any(lvls <= 0 | lvls >= 1)) {
    stop("`lvls` must lie strictly inside (0, 1)", call. = FALSE)
  }
  grid <- expand.grid(expected = expd, level = lvls)
  a <- 1 - grid$level
  mu <- target * grid$expected
  # the exact Poisson quantiles at the two tails, on the ratio scale
  grid$lower <- stats::qpois(a / 2, lambda = mu) / grid$expected
  grid$upper <- stats::qpois(1 - a / 2, lambda = mu) / grid$expected
  grid[order(grid$level, grid$expected), , drop = FALSE]
}

#' Global Moran's I over a neighbour list
#'
#' @description
#' Measures spatial autocorrelation in a variable measured on areas: whether
#' neighbouring areas tend to have similar values (positive I), dissimilar
#' values (negative I), or neither. The p-value comes from randomly
#' permuting the values over the areas. You must supply the neighbour
#' structure (a list or a weight matrix); none is invented, because an
#' administrative extract keyed on a region ships no geometry, and guessing
#' adjacency would make the answer a property of the guess.
#'
#' @details With weights \eqn{w_{ij}}, total \eqn{W = \sum_{ij} w_{ij}} and
#' \eqn{z_i = x_i - \bar x}, \deqn{I = \frac{n}{W}\,\frac{\sum_{i}\sum_{j}
#' w_{ij} z_i z_j}{\sum_i z_i^2}.} The expectation of I under the null is
#' \eqn{-1/(n - 1)}, not zero, so a small negative I is what independence looks
#' like in a small set of areas. The p-value comes from permuting the values
#' over the areas, which needs no distributional assumption -- and with a
#' handful of regions no distributional assumption is safe. It is two-sided
#' around \eqn{-1/(n - 1)}, \eqn{(1 + \mathrm{count}(|I^* - E| \ge |I - E|))/(1
#' + B)} over the \eqn{B} finite permuted values, so it is never exactly zero.
#'
#' A neighbour list is binary; a weight matrix keeps its magnitudes (for
#' example inverse distances). Self-neighbours and the diagonal are dropped.
#' \code{style = "W"} divides each area's weights by their total. The
#' permutations use R's random number generator, so call
#' \code{set.seed()} first for a reproducible p-value. The work is done in
#' compiled code.
#'
#'
#' Errors: fewer than three areas; missing values in \code{x}; a constant
#' \code{x}; a neighbour index outside \code{1..n}; a list of the wrong
#' length; a weight matrix that is not \eqn{n \times n}, not finite, or has
#' negative weights; no area with any neighbour.
#'
#' @param x Numeric vector, one value per area, no missing values.
#' @param nbrs Either a list with one integer vector of neighbour
#'   indices per area (in the order of \code{x}), or a square \eqn{n \times
#'   n} weight matrix.
#' @param style \code{"W"} (the default) row-standardises the weights, so
#'   each area's neighbours carry a total weight of one; \code{"B"} leaves
#'   them as given (binary for a list). Row standardisation is the usual
#'   choice, and stops an area with many neighbours from dominating.
#' @param nperm Integer, default \code{9999}: the number of random
#'   permutations for the null distribution.
#' @return A list with \code{I} (the statistic), \code{expectation}
#' (\eqn{-1/(n-1)}), \code{nullmean} and \code{nullsd} (mean and standard
#' deviation of the permuted values), \code{z} (\code{(I - nullmean) /
#' nullsd}), \code{p_value}, \code{W} (the total weight), \code{n} (number
#' of areas), \code{nperm} (permutations used) and \code{style}.
#' @references
#' Moran, P. A. P. (1950). Notes on continuous stochastic phenomena.
#' \emph{Biometrika} 37(1/2), 17-23. Laniyonu (2017), on policing practices
#' in gentrifying neighbourhoods, uses the statistic as here, to establish
#' that areal residuals are spatially dependent.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Six areas in a line, each adjacent to the next.
#' nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)
#'
#' # A smooth gradient is strongly positively autocorrelated.
#' set.seed(1)
#' morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 999L)[c("I", "p_value")]
#'
#' # An alternating pattern is negatively autocorrelated.
#' set.seed(1)
#' morani(c(1, 6, 1, 6, 1, 6), nb, nperm = 999L)[c("I", "p_value")]
#'
#' # And the null expectation is not zero.
#' -1 / (6 - 1)
#'
#' # the same line as a binary weight matrix, unstandardised
#' w <- matrix(0, 6, 6)
#' for (i in 1:5) w[i, i + 1] <- w[i + 1, i] <- 1
#' set.seed(1)
#' morani(c(1, 2, 3, 4, 5, 6), w, style = "B", nperm = 999L)$I
#'
#' # a constant variable has no autocorrelation to measure
#' try(morani(c(2, 2, 2), list(2L, c(1L, 3L), 2L)))
#' @export
morani <- function(x, nbrs, style = c("W", "B"), nperm = 9999L) {
  style <- .rmbl_arg(style)
  x <- .rmbl_num(x, "x")
  nperm <- .rmbl_num(nperm, "nperm", integer = TRUE)
  if (length(nperm) != 1L || is.na(nperm) || nperm < 0L) {
    stop("`nperm` must be a single non-negative whole number", call. = FALSE)
  }
  n <- length(x)
  .rmbl_moran_check(x)
  nb <- .rmbl_neighbours(nbrs, n)
  wts <- .rmbl_moran_wts(nb, style)
  len <- lengths(nb)
  start <- c(0L, cumsum(len)[-n])
  idx <- as.integer(unlist(nb, use.names = FALSE)) - 1L
  if (!length(idx)) {
    stop("`nbrs` gives no area any neighbour", call. = FALSE)
  }
  r <- .Call(
    C_rmbl_morans_i,
    x,
    idx,
    as.integer(start),
    as.integer(len),
    as.numeric(wts),
    as.integer(nperm),
    NULL
  )
  .rmbl_cls(.rmbl_moran_result(r, n, style), "rmbl_moran")
}

#' @export
format.rmbl_moran <- function(x, digits = 4L, ...) {
  .rmbl_stat_block(
    "Global Moran's I",
    facts = list(
      `Moran's I` = x$I,
      `Expected, no pattern` = x$expectation,
      `Permutation null` = .rmbl_moran_null(x),
      z = x$z,
      `p-value` = .rmbl_p_fact(x$p_value),
      Permutations = x$nperm,
      `Weight style` = if (identical(x$style, "W")) {
        "W (row-standardised)"
      } else {
        "B (weights as given)"
      },
      `Total weight` = x$W,
      Areas = x$n
    ),
    reading = .rmbl_wrap(.rmbl_moran_reading(x)),
    digits = digits
  )
}

#' @export
format.rmbl_sir <- function(x, digits = 4L, ...) {
  title <- "Standardised incidence ratios"
  need <- c("observed", "expected", "sir", "lower", "upper", "excess")
  fb <- .rmbl_df_fallback(x, title, c(need, "deficit"), digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  tb <- d[intersect(c("area", "observed", "expected", "sir"), names(d))]
  tb$interval <- .rmbl_fmt_ci(d$lower, d$upper, digits)
  tb$finding <- c("", "excess", "deficit")[1L + d$excess + 2L * d$deficit]
  .rmbl_res_block(
    title,
    facts = list(
      Areas = nrow(d),
      Observed = sum(d$observed),
      Expected = sum(d$expected),
      `Overall ratio` = sum(d$observed) / sum(d$expected),
      Interval = "exact Poisson, at the level asked for (default 95%)",
      `Above one` = sum(d$excess, na.rm = TRUE),
      `Below one` = sum(d$deficit, na.rm = TRUE)
    ),
    tables = list(tb),
    reading = paste(
      "A ratio above 1 means more cases than the area's population would",
      "give at the overall rates. An excess or a deficit is an interval",
      "wholly above or below 1 (the significant column is either)."
    ),
    notes = paste(
      "Each interval is a separate test: with many areas some exclude 1 by",
      "chance (scanadj() allows for that)."
    ),
    digits = digits,
    maxrows = 40L
  )
}

#' @export
format.rmbl_ebrates <- function(x, digits = 4L, ...) {
  title <- "Empirical Bayes rates"
  need <- c("observed", "expected", "sir", "eb", "shrinkage", "nu", "alpha")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  flat <- !nrow(d) || is.na(d$nu[1L])
  .rmbl_res_block(
    title,
    facts = list(
      Areas = nrow(d),
      `Overall ratio` = sum(d$observed) / sum(d$expected),
      `Prior shape (nu)` = if (flat) "none" else d$nu[1L],
      `Prior rate (alpha)` = if (flat) "none" else d$alpha[1L],
      Method = "gamma-Poisson, moments (Clayton and Kaldor 1987)"
    ),
    tables = list(d[setdiff(names(d), c("nu", "alpha"))]),
    reading = if (flat) {
      paste(
        "The areas vary no more than chance would make them, so every",
        "estimate is the overall ratio (shrinkage 1)."
      )
    } else {
      paste(
        "Each raw ratio (sir) is pulled toward the overall ratio; shrinkage",
        "is the share of the pull (0 untouched, 1 replaced), largest for",
        "areas with small expected counts. Use eb for maps and rankings,",
        "stdinc() for each area's own evidence."
      )
    },
    digits = digits,
    maxrows = 40L
  )
}

#' @export
format.rmbl_expected <- function(x, digits = 4L, ...) {
  title <- "Expected counts, indirect standardisation"
  need <- c("area", "observed", "population", "expected")
  fb <- .rmbl_df_fallback(x, title, need, digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  .rmbl_res_block(
    title,
    facts = list(
      Areas = nrow(d),
      Observed = sum(d$observed),
      Expected = sum(d$expected),
      Population = sum(d$population)
    ),
    tables = list(d),
    reading = paste(
      "expected is the count an area would have at the overall rate of",
      "each stratum, given its own population in it. stdinc() puts an",
      "interval on the ratio of observed to expected."
    ),
    notes = paste(
      "The expected counts sum to the observed ones: the reference rates",
      "come from the same data."
    ),
    digits = digits,
    maxrows = 40L
  )
}

#' A neighbour list, from a list or from a weight matrix.
#' @param neighbours A list of neighbour indices or an n by n weight matrix.
#' @param n The number of areas.
#' @return A list of neighbour indices, one element per area; from a matrix it
#'   carries the weights in its `weights` attribute.
#' @noRd
.rmbl_neighbours <- function(neighbours, n) {
  if (is.matrix(neighbours)) {
    if (nrow(neighbours) != n || ncol(neighbours) != n) {
      stop(sprintf("a weight matrix must be %d by %d", n, n), call. = FALSE)
    }
    if (anyNA(neighbours) || !all(is.finite(neighbours))) {
      stop("a weight matrix must be finite", call. = FALSE)
    }
    nb <- lapply(seq_len(n), function(i) {
      j <- which(neighbours[i, ] != 0)
      j[j != i] # an area is not its own neighbour
    })
    # the magnitudes travel with the indices
    attr(nb, "weights") <- lapply(seq_len(n), function(i) {
      as.numeric(neighbours[i, nb[[i]]])
    })
    return(nb)
  }
  if (!is.list(neighbours)) {
    stop(
      .rmbl_fn(),
      "`nbrs` must be a list of neighbour indices or a weight matrix",
      call. = FALSE
    )
  }
  if (length(neighbours) != n) {
    stop(
      .rmbl_fn(),
      sprintf(
        "`nbrs` has %d entries for %d areas",
        length(neighbours),
        n
      ),
      call. = FALSE
    )
  }
  lapply(seq_along(neighbours), function(i) {
    v <- as.integer(neighbours[[i]])
    v <- v[!is.na(v)]
    if (length(v) && (any(v < 1L) || any(v > n))) {
      stop(
        sprintf("area %d names a neighbour outside 1..%d", i, n),
        call. = FALSE
      )
    }
    # an area is not its own neighbour; keeping it would put the
    # variable's own value on both sides of every product
    v[v != i]
  })
}

#' stdinc()'s complete rows: those with both an observed and an expected count.
#' @param obs,expd The counts, NA kept.
#' @return A logical vector, TRUE for a complete row.
#' @noRd
.ar_complete <- function(obs, expd) {
  ok <- !is.na(obs) & !is.na(expd)
  if (!any(ok)) {
    stop(
      "stdinc: no area has both an observed and an expected count",
      call. = FALSE
    )
  }
  ok
}

#' Checks counts as .rmbl_finite_input() does, keeping the missing values.
#'
#' The caller drops the incomplete rows itself, across every vector at once.
#' @param x The argument's value.
#' @param what The argument's name, for its errors.
#' @param min_n The least count of non-missing values the check accepts.
#' @return A double vector, NA where `x` is missing.
#' @noRd
.ar_keep_na <- function(x, what, min_n = 0L) {
  v <- .rmbl_num_input(x, what)
  .rmbl_finite_input(v, what, nonneg = TRUE, min_n = min_n)
  v
}

#' Builds the data frame of empirical Bayes estimates, with an `area` column
#' when areas are named.
#' @param area The area labels, or NULL.
#' @param observed The observed counts.
#' @param expected The expected counts.
#' @param theta The standardised incidence ratios.
#' @param eb The empirical Bayes estimates.
#' @param shrink The shrinkage factors.
#' @param nu The prior's shape.
#' @param alpha The prior's rate.
#' @return A data frame with one row per area.
#' @noRd
.eb_frame <- function(area, observed, expected, theta, eb, shrink, nu, alpha) {
  out <- data.frame(
    observed = observed,
    expected = expected,
    sir = theta,
    eb = eb,
    shrinkage = shrink,
    nu = nu,
    alpha = alpha,
    stringsAsFactors = FALSE
  )
  if (!is.null(area)) {
    out <- cbind(area = as.character(area), out, stringsAsFactors = FALSE)
  }
  .rmbl_cls(out, "rmbl_ebrates")
}

#' Refuses the inputs of ebrates() it cannot shrink.
#' @param obs,expd The observed and expected counts.
#' @param area The area labels, or NULL.
#' @return NULL, invisibly.
#' @noRd
.eb_check <- function(obs, expd, area) {
  if (length(obs) != length(expd)) {
    stop("ebrates: `obs` and `expd` must be the same length", call. = FALSE)
  }
  if (
    !is.null(area) &&
      (!is.atomic(area) || is.matrix(area) || length(area) != length(obs))
  ) {
    stop(
      "ebrates: `area` must be NULL or one label per area (as many as `obs`)",
      call. = FALSE
    )
  }
  # counts: finite and non-negative, as sir() requires of the same inputs
  if (anyNA(obs) || !all(is.finite(obs)) || any(obs < 0)) {
    stop("`obs` must be finite, non-negative counts", call. = FALSE)
  }
  if (anyNA(expd) || !all(is.finite(expd))) {
    stop("`expd` must be finite", call. = FALSE)
  }
  if (any(expd <= 0)) {
    stop("ebrates: `expd` must be positive", call. = FALSE)
  }
  if (length(obs) < 2L) {
    stop(
      "shrinkage borrows strength across areas, so it needs at least two",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Refuses a variable morani() cannot autocorrelate.
#' @param x The variable, one value per area.
#' @return NULL, invisibly.
#' @noRd
.rmbl_moran_check <- function(x) {
  if (length(x) < 3L) {
    stop("Moran's I needs at least three areas", call. = FALSE)
  }
  if (anyNA(x)) {
    stop("`x` must not contain missing values", call. = FALSE)
  }
  if (length(unique(x)) < 2L) {
    stop(
      "`x` is constant: Moran's I is undefined (no variance to autocorrelate)",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' The weights morani() passes to the native statistic, in neighbour order.
#' @param nb The neighbour list (.rmbl_neighbours()), its weights as an
#'   attribute when a matrix was given.
#' @param style "W" (row standardised) or "B" (as given).
#' @return A numeric vector, one weight per neighbour pair.
#' @noRd
.rmbl_moran_wts <- function(nb, style) {
  # A weight matrix carries magnitudes (inverse distance, a
  # pre-standardised matrix); they are used as given under style "B" and
  # row-standardised under "W". A neighbour list is binary. Reducing a
  # matrix to which(w != 0) threw the magnitudes away and gave a wrong I
  # with no warning.
  w_in <- attr(nb, "weights")
  if (!is.null(w_in) && any(unlist(w_in) < 0, na.rm = TRUE)) {
    # a negative weight is not a spatial weight: under style "W" a row
    # divided by its (negative) total flips sign, and negating a whole
    # matrix left I unchanged
    stop("spatial weights must be non-negative", call. = FALSE)
  }
  if (!is.null(w_in)) {
    unlist(
      lapply(w_in, function(w) {
        if (!length(w)) {
          numeric(0)
        } else if (identical(style, "W")) {
          (if (sum(w) > 0) w / sum(w) else w * 0)
        } else {
          w
        }
      }),
      use.names = FALSE
    )
  } else if (identical(style, "W")) {
    # row standardisation divides each area's weights by their own total,
    # so an area with many neighbours does not count for more
    unlist(
      lapply(nb, function(v) {
        if (length(v)) rep(1 / length(v), length(v)) else numeric(0)
      }),
      use.names = FALSE
    )
  } else {
    rep(1, sum(lengths(nb)))
  }
}

#' The morani() result from the native statistic and its permutation null.
#' @param r The native result (I, null, W).
#' @param n The number of areas.
#' @param style The weight style.
#' @return As for morani().
#' @noRd
.rmbl_moran_result <- function(r, n, style) {
  null <- r$null
  null <- null[is.finite(null)]
  expectation <- -1 / (n - 1)
  p <- if (length(null)) {
    # two-sided, measured from the null's own centre; the observed value
    # counts in its own null, so the p-value cannot be exactly zero
    (1 + sum(abs(null - expectation) >= abs(r$I - expectation))) /
      (1 + length(null))
  } else {
    NA_real_
  }
  list(
    I = r$I,
    expectation = expectation,
    nullmean = if (length(null)) mean(null) else NA_real_,
    nullsd = if (length(null)) stats::sd(null) else NA_real_,
    z = if (length(null) > 1L && stats::sd(null) > 0) {
      (r$I - mean(null)) / stats::sd(null)
    } else {
      NA_real_
    },
    p_value = p,
    W = r$W,
    n = n,
    nperm = length(null),
    style = style
  )
}

#' The permutation null of a morani() result, as one fact.
#' @param x A morani() result.
#' @return One string.
#' @noRd
.rmbl_moran_null <- function(x) {
  if (!length(x$nullmean) || is.na(x$nullmean)) {
    return("none (no permutations)")
  }
  sprintf(
    "mean %s, sd %s",
    .rmbl_fmt_num(x$nullmean),
    .rmbl_fmt_num(x$nullsd)
  )
}

#' What a morani() result says, in words, at the 5% level.
#' @param x The morani() result to read.
#' @return One string.
#' @noRd
.rmbl_moran_reading <- function(x) {
  p <- x$p_value
  if (!length(p) || is.na(p)) {
    return("With no permutations there is no p-value to judge the pattern by.")
  }
  pt <- paste0("(p ", .rmbl_p_txt(p), "):")
  if (p >= 0.05) {
    return(paste(
      "No clear spatial pattern",
      pt,
      "neighbouring areas are no more alike, or unlike, than a random",
      "arrangement of the same values would make them."
    ))
  }
  if (x$I > x$expectation) {
    paste(
      "Clustered",
      pt,
      "neighbouring areas have more similar values than a random",
      "arrangement of the same values would give."
    )
  } else {
    paste(
      "Dispersed",
      pt,
      "neighbouring areas differ more than a random arrangement would",
      "give, like a checkerboard."
    )
  }
}
