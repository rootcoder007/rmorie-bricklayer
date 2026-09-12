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
#' The count each area would have if it experienced the overall rate in
#' every stratum, given its own composition. Comparing observed against
#' this rather than against a raw rate removes the part of the difference
#' that is explained by who the area holds.
#'
#' @param counts Observed counts.
#' @param population Population at risk, the same length
#' as `counts`.
#' @param area Area label for each row.
#' @param strata Optional stratum label for each row -- an
#' age band, a gender, or their interaction. With strata the
#' standardisation is indirect in the usual sense: the overall
#' stratum-specific rates are applied to each area's own stratum
#' populations.
#' @return A data frame with one row per area: `observed`,
#' `population` and `expected`.
#' @details
#' Without strata the expected count is just the area's population times
#' the overall rate, which adjusts for size but not for composition. The
#' two are worth distinguishing: a region holding disproportionately many
#' young men will show an excess on the first and may show none on the
#' second, and only the second is evidence about the region.
#' @references
#' Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling*. Chapman and Hall/CRC. Chapter 1 sets out the convention used
#' here: the expected counts come from applying the overall population rate
#' to each area, and the standardised incidence ratio is the ratio of count
#' to expected.
#'
#' Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods Using
#' R*. Springer, on the distinction between indirect standardisation, which
#' applies the reference's stratum-specific rates to the study population,
#' and direct standardisation, which does the reverse.
#' @seealso
#' [sir()], [eb_rates()],
#' [funnel_limits()]
#' @examples
#' d <- data.frame(
#'   region = rep(c("North", "South", "East"), each = 2),
#'   age = rep(c("18 to 24", "25 to 49"), 3),
#'   n = c(30, 45, 12, 60, 8, 20),
#'   pop = c(1000, 6000, 900, 9000, 400, 3500)
#' )
#'
#' # Adjusting for size only.
#' expected_counts(d$n, d$pop, d$region)
#'
#' # Adjusting for size AND age composition, which is the comparison
#' # that says something about the region.
#' expected_counts(d$n, d$pop, d$region, strata = d$age)
#' @export
expected_counts <- function(counts, population, area, strata = NULL) {
  counts <- as.numeric(counts)
  population <- as.numeric(population)
  area <- as.character(area)
  n <- length(counts)
  if (length(population) != n || length(area) != n) {
    stop("`counts`, `population` and `area` must be the same length",
         call. = FALSE)
  }
  if (any(counts < 0, na.rm = TRUE)) {
    stop("`counts` must be non-negative", call. = FALSE)
  }
  if (any(population <= 0, na.rm = TRUE)) {
    stop("`population` must be positive", call. = FALSE)
  }
  if (is.null(strata)) {
    strata <- rep("all", n)
  } else {
    strata <- as.character(strata)
    if (length(strata) != n) {
      stop("`strata` must be the same length as `counts`", call. = FALSE)
    }
  }
  ok <- !is.na(counts) & !is.na(population) & !is.na(area) & !is.na(strata)
  counts <- counts[ok]
  population <- population[ok]
  area <- area[ok]
  strata <- strata[ok]
  # the reference rate in each stratum, over every area at once
  num <- tapply(counts, strata, sum)
  den <- tapply(population, strata, sum)
  rate <- num / den
  expected_row <- population * rate[match(strata, names(rate))]
  areas <- sort(unique(area))
  data.frame(area = areas,
             observed = as.numeric(tapply(counts, area, sum)[areas]),
             population = as.numeric(tapply(population, area,
                                            sum)[areas]),
             expected = as.numeric(tapply(expected_row, area,
                                          sum)[areas]),
             stringsAsFactors = FALSE)
}

#' Standardised incidence ratio, with an exact interval
#'
#' The ratio of observed to expected, with the exact Poisson interval for
#' it. A ratio of one is the overall experience; above one is an excess.
#'
#' @param observed Observed counts.
#' @param expected Expected counts, from
#' [expected_counts()].
#' @param area Optional labels.
#' @param conf_level Confidence level.
#' @return A data frame with `observed`, `expected`, `sir`,
#' `lower`, `upper` and `excess` -- whether the interval
#' excludes one.
#' @details
#' The interval is the exact Poisson one, from the relation between the
#' Poisson and gamma distributions, and so is identical to
#' `stats::poisson.test` 's. It is the interval to use here because
#' the counts that matter are small: a normal approximation on an observed
#' count of three is not an interval, it is a decoration.
#' @references
#' Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling*. Chapman and Hall/CRC, Chapter 1.
#' @seealso
#' [eb_rates()],
#' [funnel_limits()]
#' @examples
#' sir(observed = c(30, 12, 3), expected = c(20, 14, 5),
#'     area = c("North", "South", "East"))
#'
#' # An observed count of three carries almost no information, and the
#' # interval says so rather than hiding it.
#' sir(3, 5)
#' @export
sir <- function(observed, expected, area = NULL, conf_level = 0.95) {
  observed <- as.numeric(observed)
  expected <- as.numeric(expected)
  if (length(expected) == 1L) expected <- rep(expected, length(observed))
  if (length(observed) != length(expected)) {
    stop("`observed` and `expected` must be the same length", call. = FALSE)
  }
  if (any(observed < 0, na.rm = TRUE)) {
    stop("`observed` must be non-negative", call. = FALSE)
  }
  if (any(expected <= 0, na.rm = TRUE)) {
    stop("`expected` must be positive", call. = FALSE)
  }
  a <- 1 - conf_level
  # the exact Poisson interval, via the gamma relation: an observed
  # count of zero has a lower limit of exactly zero rather than a
  # negative one
  lo <- ifelse(observed == 0, 0,
               stats::qgamma(a / 2, shape = observed)) / expected
  hi <- stats::qgamma(1 - a / 2, shape = observed + 1) / expected
  out <- data.frame(observed = observed, expected = expected,
                    sir = observed / expected, lower = lo, upper = hi,
                    excess = lo > 1 | hi < 1,
                    stringsAsFactors = FALSE)
  if (!is.null(area)) {
    out <- cbind(area = as.character(area), out, stringsAsFactors = FALSE)
  }
  out
}

#' Empirical Bayes rates, shrunk toward the overall experience
#'
#' A small area's rate is mostly noise, so ranking areas by their raw rates
#' puts the smallest areas at both ends of the table by construction. This
#' borrows strength across areas: each rate is pulled toward the overall
#' one by an amount that depends on how little information the area
#' carries.
#'
#' @param observed Observed counts.
#' @param expected Expected counts.
#' @param area Optional labels.
#' @return A data frame with the raw `sir`, the shrunk `eb`, the
#' `shrinkage` applied (zero means untouched, one means replaced by
#' the overall rate), and the fitted prior's `nu` and `alpha`.
#' @details
#' The Clayton-Kaldor construction: the area-specific relative risks are
#' taken to come from a gamma prior, whose two parameters are estimated
#' from the observed and expected counts by the method of moments, and the
#' posterior mean `(O + nu) / (E + alpha)` is reported. Where the
#' expected count is large the data dominate and the estimate barely moves;
#' where it is small the prior does, which is the intended behaviour and
#' not a defect.
#'
#' When the between-area variance estimate comes out at or below zero there
#' is no evidence of any real variation between areas, and every estimate
#' collapses to the overall rate. That is reported through `shrinkage`
#' rather than hidden.
#' @references
#' Clayton, D. and Kaldor, J. (1987). Empirical Bayes estimates of
#' age-standardized relative risks for use in disease mapping.
#' *Biometrics* 43(3), 671-681.
#'
#' Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling*. Chapman and Hall/CRC, which cites Clayton and Kaldor as the
#' empirical-Bayes approximation in the development of Bayesian disease
#' mapping.
#' @seealso
#' [sir()], [funnel_limits()]
#' @examples
#' # Three areas, one of them tiny. The tiny area's raw ratio is
#' # extreme; its shrunk one is not.
#' eb_rates(observed = c(30, 45, 2), expected = c(25, 50, 0.5),
#'          area = c("North", "South", "Tiny"))
#' @export
eb_rates <- function(observed, expected, area = NULL) {
  observed <- as.numeric(observed)
  expected <- as.numeric(expected)
  if (length(observed) != length(expected)) {
    stop("`observed` and `expected` must be the same length", call. = FALSE)
  }
  if (any(expected <= 0, na.rm = TRUE)) {
    stop("`expected` must be positive", call. = FALSE)
  }
  n <- length(observed)
  if (n < 2L) {
    stop("shrinkage borrows strength across areas, so it needs at least two",
         call. = FALSE)
  }
  theta <- observed / expected
  esum <- sum(expected)
  # the overall relative risk, which is the prior's mean
  m <- sum(observed) / esum
  # and its variance, by the method of moments; the subtracted term is
  # the part of the spread in theta that the Poisson sampling alone
  # would produce, so what is left is the between-area variation
  s2 <- sum(expected * (theta - m)^2) / esum - m / (esum / n)
  s2 <- max(s2, 0)
  if (s2 <= 0) {
    # no evidence of real variation between areas: every estimate is the
    # overall rate, and the shrinkage is total
    return(.eb_frame(area, observed, expected, theta,
                     rep(m, n), rep(1, n), NA_real_, NA_real_))
  }
  alpha <- m / s2
  nu <- m^2 / s2
  eb <- (observed + nu) / (expected + alpha)
  # the weight the DATA carry, so shrinkage is one minus it
  w <- expected / (expected + alpha)
  .eb_frame(area, observed, expected, theta, eb, 1 - w, nu, alpha)
}

.eb_frame <- function(area, observed, expected, theta, eb, shrink,
                      nu, alpha) {
  out <- data.frame(observed = observed, expected = expected,
                    sir = theta, eb = eb, shrinkage = shrink,
                    nu = nu, alpha = alpha, stringsAsFactors = FALSE)
  if (!is.null(area)) {
    out <- cbind(area = as.character(area), out, stringsAsFactors = FALSE)
  }
  out
}

#' Funnel-plot control limits
#'
#' The limits within which an area's ratio would fall, given its expected
#' count, if it were no different from the overall experience. A funnel
#' plot is the alternative to a league table: it shows directly that a
#' small area's ratio can wander far from one without meaning anything.
#'
#' @param expected Expected counts to compute limits at.
#' @param target The ratio the limits are centred on. One is
#' the overall experience.
#' @param levels Two-sided coverage levels for the limit
#' pairs.
#' @return A data frame of `expected`, `level`, `lower` and
#' `upper` on the ratio scale.
#' @details
#' The limits are exact Poisson quantiles divided by the expected count, so
#' they are the discrete counterpart of the usual normal funnel and stay
#' correct at the small expected counts where the normal version goes below
#' zero.
#' @references
#' *Advanced Statistics in Criminology and Criminal Justice* discusses
#' the funnel plot as the display of the relationship between an estimate
#' and the sample size behind it.
#'
#' Lawson, A. B. *Using R for Bayesian Spatial and Spatio-Temporal Health
#' Modeling*. Chapman and Hall/CRC, on the Poisson counts these limits are
#' built from.
#' @seealso
#' [sir()], [eb_rates()]
#' @examples
#' # The funnel narrows as the expected count grows, which is the whole
#' # point: a ratio of 2 means nothing at an expected count of 2 and a
#' # great deal at an expected count of 200.
#' funnel_limits(c(2, 20, 200))
#' @export
funnel_limits <- function(expected, target = 1,
                          levels = c(0.95, 0.998)) {
  expected <- as.numeric(expected)
  if (any(expected <= 0, na.rm = TRUE)) {
    stop("`expected` must be positive", call. = FALSE)
  }
  target <- as.numeric(target)[1L]
  if (is.na(target) || target <= 0) {
    stop("`target` must be positive", call. = FALSE)
  }
  levels <- sort(as.numeric(levels))
  if (any(levels <= 0 | levels >= 1)) {
    stop("`levels` must lie strictly inside (0, 1)", call. = FALSE)
  }
  grid <- expand.grid(expected = expected, level = levels)
  a <- 1 - grid$level
  mu <- target * grid$expected
  # the exact Poisson quantiles at the two tails, on the ratio scale
  grid$lower <- stats::qpois(a / 2, lambda = mu) / grid$expected
  grid$upper <- stats::qpois(1 - a / 2, lambda = mu) / grid$expected
  grid[order(grid$level, grid$expected), , drop = FALSE]
}

#' Global Moran's I over a neighbour list
#'
#' Spatial autocorrelation for an areal variable, with a permutation
#' p-value. A neighbour list is required and is not invented: an
#' administrative extract keyed on a region ships no geometry, and guessing
#' adjacency would make the answer a property of the guess.
#'
#' @param x The variable, one value per area.
#' @param neighbours Either a list with one integer
#' vector of neighbour indices per area, or a square weight matrix.
#' @param style `"W"` row-standardises the weights, so
#' each area's neighbours carry a total weight of one; `"B"` leaves
#' them binary. Row standardisation is the usual choice, and stops an area
#' with many neighbours from dominating.
#' @param n_perm Permutations for the null distribution.
#' @return A list with `I`, its expectation under the null (
#' `-1/(n-1)`, which is not zero), the permutation mean and standard
#' deviation, a `z` score, `p_value`, and `W`, the total
#' weight.
#' @details
#' The expectation of I under the null is `-1/(n - 1)`, not zero, so a
#' small negative I is what independence looks like in a small set of
#' areas. The p-value comes from permuting the values over the areas, which
#' needs no distributional assumption -- and with a handful of regions no
#' distributional assumption is safe.
#' @references
#' Moran, P. A. P. (1950). Notes on continuous stochastic phenomena.
#' *Biometrika* 37(1/2), 17-23. (Not in the local corpus; cited from the
#' published paper. The corpus does carry applied uses of the statistic,
#' including Laniyonu (2017) on policing practices in gentrifying
#' neighbourhoods, where it is used exactly as here -- to establish that
#' areal residuals are spatially dependent.)
#' @examples
#' # Six areas in a line, each adjacent to the next.
#' nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)
#'
#' # A smooth gradient is strongly positively autocorrelated.
#' set.seed(1)
#' morans_i(c(1, 2, 3, 4, 5, 6), nb, n_perm = 999L)[c("I", "p_value")]
#'
#' # An alternating pattern is negatively autocorrelated.
#' set.seed(1)
#' morans_i(c(1, 6, 1, 6, 1, 6), nb, n_perm = 999L)[c("I", "p_value")]
#'
#' # And the null expectation is not zero.
#' -1 / (6 - 1)
#' @export
morans_i <- function(x, neighbours, style = c("W", "B"),
                     n_perm = 9999L) {
  style <- match.arg(style)
  x <- as.numeric(x)
  n <- length(x)
  if (n < 3L) stop("Moran's I needs at least three areas", call. = FALSE)
  if (anyNA(x)) {
    stop("`x` must not contain missing values", call. = FALSE)
  }
  nb <- .rmbl_neighbours(neighbours, n)
  # row standardisation divides each area's weights by their own total,
  # so an area with many neighbours does not count for more
  wts <- if (identical(style, "W")) {
    unlist(lapply(nb, function(v) {
      if (!length(v)) numeric(0) else rep(1 / length(v), length(v))
    }), use.names = FALSE)
  } else {
    rep(1, sum(lengths(nb)))
  }
  len <- lengths(nb)
  start <- c(0L, cumsum(len)[-n])
  idx <- as.integer(unlist(nb, use.names = FALSE)) - 1L
  if (!length(idx)) {
    stop("`neighbours` gives no area any neighbour", call. = FALSE)
  }
  r <- .Call(C_rmbl_morans_i, x, idx, as.integer(start), as.integer(len),
             as.numeric(wts), as.integer(n_perm), NULL)
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
  list(I = r$I, expectation = expectation,
       null_mean = if (length(null)) mean(null) else NA_real_,
       null_sd = if (length(null)) stats::sd(null) else NA_real_,
       z = if (length(null) && stats::sd(null) > 0) {
         (r$I - mean(null)) / stats::sd(null)
       } else {
         NA_real_
       },
       p_value = p, W = r$W, n = n, n_perm = length(null), style = style)
}

# A neighbour list, from a list or from a weight matrix.
.rmbl_neighbours <- function(neighbours, n) {
  if (is.matrix(neighbours)) {
    if (nrow(neighbours) != n || ncol(neighbours) != n) {
      stop(sprintf("a weight matrix must be %d by %d", n, n),
           call. = FALSE)
    }
    return(lapply(seq_len(n), function(i) which(neighbours[i, ] != 0)))
  }
  if (!is.list(neighbours)) {
    stop("`neighbours` must be a list of neighbour indices or a weight matrix",
         call. = FALSE)
  }
  if (length(neighbours) != n) {
    stop(sprintf("`neighbours` has %d entries for %d areas",
                 length(neighbours), n), call. = FALSE)
  }
  lapply(seq_along(neighbours), function(i) {
    v <- as.integer(neighbours[[i]])
    v <- v[!is.na(v)]
    if (length(v) && (any(v < 1L) || any(v > n))) {
      stop(sprintf("area %d names a neighbour outside 1..%d", i, n),
           call. = FALSE)
    }
    # an area is not its own neighbour; keeping it would put the
    # variable's own value on both sides of every product
    v[v != i]
  })
}
