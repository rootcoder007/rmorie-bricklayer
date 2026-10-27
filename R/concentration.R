# Concentration, and association in a contingency table.
#
# The recurring question about an administrative table is whether a few
# units account for most of the total: a handful of individuals holding
# most of the placements, one region holding most of the days. That is a
# concentration measure, and the honest ones come with their own caveats
# -- a Gini computed from banded data inherits the band assumption, and a
# tail index fitted to twelve observations is a number with no precision.

#' Concentration of a total across units
#'
#' Measures how unevenly a total is spread across units: whether a few
#' people account for most of the placements, or a few regions for most of
#' the days. \code{ginicoef()} gives the Gini coefficient, \code{lorenzc()} the
#' points of the Lorenz curve (for plotting, for example with
#' [plotlrnz()]), and \code{topshr()} the share of the
#' total held by
#' the largest units (\dQuote{the top 1% of people account for 20% of the
#' days}). The three are computed in compiled code from the same sorted
#' values.
#'
#' @param x Numeric vector of non-negative values, one per unit (for example
#'   the days or the count of placements of each person). \code{NA} values
#'   are dropped; \code{Inf}, negative values and non-numeric input are
#'   errors.
#' @param na.rm Logical. Missing values are dropped whatever its value; the
#'   argument exists so the call reads the same as base R's. Default
#'   \code{TRUE}.
#' @return \code{ginicoef()}: a numeric scalar in \code{[0, 1 - 1/n]}.
#'   \code{lorenzc()}: a data frame with numeric columns \code{population}
#'   (cumulative share of units, from 0 to 1) and \code{value} (cumulative
#'   share of the total, units in ascending order), \code{n + 1} rows
#'   including the origin. \code{topshr()}: a data frame with columns
#'   \code{fraction} (the requested fraction of units), \code{units} (how
#'   many of the largest units that fraction is) and \code{share} (the share
#'   of the total those units hold).
#'    It has class \code{c("rmbl_gini", "rmbl_measure", "numeric")}, so it
#'   prints as a box with its inputs (kept in attribute \code{"lakner"});
#'   arithmetic, \code{[}, \code{c()} and \code{as.numeric()} give plain
#'   numbers.
#' @details
#' Gini is the mean absolute difference between pairs of units over twice
#' the mean, \eqn{G = \sum_i \sum_j |x_i - x_j| / (2 n^2 \bar{x})}, which is
#' also twice the area between the Lorenz curve and the diagonal. Zero is a
#' perfectly even spread; the maximum for \code{n} units is \code{1 - 1/n},
#' not 1, so a Gini near 1 requires many units as well as an uneven spread.
#'
#' A Gini computed from banded or rounded data inherits that coarsening:
#' compare with [bandsens()] when the values are
#' bands. For a tail
#' that a few units dominate, [hilltlidx()] says
#' whether the largest
#' values follow a power law.
#'
#' Errors: \code{x} not numeric, with \code{Inf} or a negative value, or with
#' no non-missing value; \code{ginicoef()} when every value is zero (the Gini of
#' a zero total is undefined); \code{topshr()} when \code{fractions} is not
#' numeric, is empty, has \code{NA} or lies outside \code{[0, 1]}.
#' @references
#' Hedderich, J. and Sachs, L. (2020). *Applied Statistics: Methods Using
#' R*. Springer-Verlag, Berlin Heidelberg. Section 3.14, p. 117, gives the
#' construction used here: the units are placed at equal intervals on the
#' horizontal axis and the cumulated, ascendingly ordered shares of the
#' total on the vertical one, so that the curve is the diagonal exactly
#' when p percent of the units account for p percent of the total, and sags
#' further the greater the concentration.
#' @seealso
#' [hilltlidx()],
#' [bandsens()]
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # Ten units holding one each: no concentration.
#' ginicoef(rep(1, 10))
#'
#' # One unit holding everything: the maximum for ten units.
#' ginicoef(c(rep(0, 9), 1))
#' 1 - 1 / 10
#'
#' placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
#' ginicoef(placements)
#'
#' # What the most frequent few account for.
#' topshr(placements, c(0.01, 0.05, 0.1))
#'
#' head(lorenzc(placements))
#'
#' # missing values are dropped
#' ginicoef(c(1, NA, 3))
#'
#' # a zero total has no Gini coefficient
#' try(ginicoef(c(0, 0, 0)))
#' @name concentration
#' @export
#' @srrstats {G2.1} .rmbl_conc_input/.rmbl_num_input refuse character, factor,
#'   list and data frame input; test-tables.R:165 ginicoef(c("a","b")) errors.
#' @srrstats {G2.1a} @param x says "Numeric vector of non-negative values"; it
#'   also says Inf, negative and non-numeric input are errors.
#' @srrstats {G2.16} Inf is refused and NaN/NA dropped by .rmbl_conc_input;
#'   test-input-contracts.R ginicoef(Inf) errors "finite", topshr(NaN) errors.
#' @srrstats {G5.4a} test-tables.R checks closed forms: Gini = 1 - 1/n for n =
#'   2..100, 0 for equal values, scale invariance, and 1 - 2*area of the Lorenz
#'   curve.
#' @srrstats {G5.8} Edge cases tested in test-tables.R and
#'   test-input-contracts.R; see G5.8a-d.
#' @srrstats {G5.8a} ginicoef(numeric(0)) errors "no values" (test-tables.R:162,
#'   test-input-contracts.R:30).
#' @srrstats {G5.8b} Character input refused (test-tables.R:165);
#'   test-input-contracts.R loops 17 kernels over "abc", list and data frame.
ginicoef <- function(x, na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  if (all(x == 0, na.rm = TRUE)) {
    stop(
      "every value is zero: the Gini coefficient of a zero total is undefined",
      call. = FALSE
    )
  }
  .rmbl_measure(
    .Call(C_rmbl_gini, x),
    "gini",
    list(n = length(x), total = sum(x), top = max(x))
  )
}

#' @export
format.rmbl_gini <- function(x, ...) {
  if (!.lk_ok(x, c("n", "total", "top")) || length(x) != 1L) {
    return(.lk_plain(x, ...))
  }
  m <- attr(x, "lakner")
  g <- .rmbl_measure_plain(x)
  .an_block(
    "Gini coefficient",
    facts = list(
      `Gini coefficient` = .rmbl_fmt_num(g),
      Units = .rmbl_fmt_num(m$n),
      Total = .rmbl_fmt_num(m$total),
      `Largest unit` = sprintf(
        "%s (%.1f%% of the total)",
        .rmbl_fmt_num(m$top),
        100 * m$top / m$total
      ),
      `Most for n units` = .rmbl_fmt_num(1 - 1 / m$n)
    ),
    reading = .rmbl_gini_reading(g, m$n),
    notes = c(
      "0 when every unit holds the same, 1 - 1/n when one unit holds it all;",
      "doubling every value leaves it unchanged. It says how unequal, not",
      "which units: topshr() and lorenzc() show where the total sits."
    )
  )
}

#' @rdname concentration
#' @export
lorenzc <- function(x, na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  r <- .Call(C_rmbl_lorenz, x)
  data.frame(population = r$population, value = r$value)
}

#' @param fracs Numeric vector of fractions of the units, each in
#'   \code{[0, 1]}: for each one the share of the total held by that fraction
#'   of units, taking the largest units first. Default
#'   \code{c(0.01, 0.05, 0.1, 0.25)}.
#' @rdname concentration
#' @export
topshr <- function(x, fracs = c(0.01, 0.05, 0.1, 0.25), na.rm = TRUE) {
  x <- .rmbl_conc_input(x)
  f <- .rmbl_conc_fracs(fracs)
  r <- .Call(C_rmbl_top_share, x, f)
  .rmbl_cls(
    data.frame(fraction = f, units = r$units, share = r$share),
    "rmbl_top_share"
  )
}

#' Tail index of a heavy-tailed count
#'
#' The Clauset-Shalizi-Newman maximum-likelihood estimator for a discrete
#' power law above a threshold. An exponent near 2 or below means the mean
#' is barely defined and the observed maximum is not informative about the
#' next one, which is the substantive point when a few units dominate a
#' total. Use it on counts per unit (placements per person, incidents per
#' address) to judge whether the largest values are a heavy tail rather than
#' a few outliers, and read \code{ks} and \code{reliable} before quoting the
#' exponent.
#'
#' @details
#' For a power law \eqn{p(x) \propto x^{-\alpha}} above \eqn{x_{min}}:
#' \itemize{
#'   \item discrete data, exact (the default): the log-likelihood of the
#'     zeta distribution truncated at \eqn{x_{min}},
#'     \eqn{-n \log \zeta(\alpha, x_{min}) - \alpha \sum \log x_i}, is
#'     maximised over \eqn{\alpha} in \eqn{(1.0001, 25)} with
#'     \code{stats::optimize()}; \eqn{\zeta} is
#'     [hurwzeta()]. The
#'     standard error comes from the observed information, by a numerical
#'     second derivative.
#'   \item continuous data (\code{discrete = FALSE}): the Hill estimator
#'     \eqn{\hat\alpha = 1 + n / \sum \log(x_i / x_{min})}, with standard
#'     error \eqn{(\hat\alpha - 1)/\sqrt{n}}.
#'   \item discrete data with \code{approx = TRUE}: the same closed form with
#'     \eqn{x_{min} - 1/2} in place of \eqn{x_{min}}.
#' }
#' \code{ks} is the Kolmogorov-Smirnov distance between the fitted
#' distribution and the tail, computed once per distinct value so that ties
#' (most counts are ties) are handled correctly.
#'
#' Only finite positive values of \code{x} are used; the rest are dropped
#' silently. When the tail has fewer than \code{mintl} values, or every
#' tail value is the same, \code{alpha} is \code{NA} and \code{method} says
#' why. An estimate at the optimiser's bound is flagged in \code{method} and
#' is not \code{reliable}. Errors: no positive finite value in \code{x};
#' \code{xmin} that is not a single positive number (logical, factor and text
#' are refused); \code{discrete} or \code{approx} not \code{TRUE} or
#' \code{FALSE}.
#'
#' @param x Numeric vector of positive values, one per unit.
#' @param xmin Numeric scalar or \code{NULL} (the default): the threshold at
#' and above which the power law is fitted. A power law is a statement about
#' the tail, so a threshold is required; \code{NULL} takes the 50th largest
#' value (which leaves at least 50 observations in the tail), or the
#' minimum if there are fewer than 50 values.
#' @param discrete Logical scalar, default \code{TRUE}: whether the quantity
#' is integer-valued.
#' A count is, and then the likelihood maximised is the zeta
#' distribution's, whose normalising constant is a Hurwitz zeta.
#' @param approx Logical scalar, default \code{FALSE}. For discrete data,
#' whether to use the
#' closed-form continuity-corrected estimator instead of maximising the
#' exact likelihood. It is much faster and much worse: the correction is an
#' asymptotic approximation in `xmin`, and at `xmin = 1` --
#' where administrative counts start -- it returns about 2.0 from data
#' generated with an exponent of 2.5. Off by default for that reason.
#' @param mintl Integer scalar, default \code{3}: the fewest tail
#' observations for which an estimate is reported at all (values below 2 are
#' raised to 2). Below it there is nothing to estimate from and \code{alpha}
#' is \code{NA}.
#' @return A list with \code{alpha} (numeric, the exponent), \code{se} (its
#' standard error), \code{xmin} (the threshold used), \code{ntl}
#' (integer, the number of values at or above it), \code{ks}, \code{reliable}
#' (logical) and \code{method} (character, the estimator used or why there is
#' no estimate). \code{ks} is the
#' Kolmogorov-Smirnov distance between the fitted tail and the data: a
#' large value means the tail is not a power law, whatever `alpha`
#' came out as. `reliable` is `FALSE` when fewer than 50
#' observations lie in the tail, which is the sample size Clauset, Shalizi
#' and Newman give as the point below which the estimate should not be
#' leaned on -- it is reported rather than enforced, because the right
#' response to a short tail is a wider interval, not a refusal.
#' @references
#' Clauset, A., Shalizi, C. R. and Newman, M. E. J. (2009). Power-law
#' distributions in empirical data. *SIAM Review* 51(4), 661-703. The
#' estimator and its threshold guidance are theirs; the continuity
#' correction they give in closed form is an asymptotic approximation in
#' `xmin`, which is why the exact likelihood is maximised here
#' instead. (Not in the local corpus; cited from the published paper.)
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # A continuous Pareto tail with exponent 2.5.
#' set.seed(1)
#' x <- (1 - stats::runif(5000))^(-1 / 1.5)
#' round(hilltlidx(x, xmin = 1, discrete = FALSE)$alpha, 2)
#'
#' # A discrete power law, where the exact likelihood is needed: the
#' # closed-form correction is badly biased at a threshold of one.
#' k <- 1:10000
#' p <- k^(-2.5) / sum(k^(-2.5))
#' set.seed(2)
#' z <- sample(k, 5000, replace = TRUE, prob = p)
#' c(exact = round(hilltlidx(z, xmin = 1)$alpha, 2),
#'   approx = round(hilltlidx(z, xmin = 1, approx = TRUE)$alpha, 2))
#'
#' # A short tail still returns an estimate, marked as not to be leaned
#' # on, and with a standard error that says the same thing.
#' short <- hilltlidx(c(3, 4, 5, 9), xmin = 3)
#' c(alpha = round(short$alpha, 2), n = short$ntl,
#'   reliable = short$reliable)
#'
#' # Below `mintl` there is nothing to estimate from.
#' hilltlidx(c(3, 4), xmin = 3)$alpha
#'
#' # the threshold has to be positive
#' try(hilltlidx(z, xmin = 0))
#' @export
hilltlidx <- function(
  x,
  xmin = NULL,
  discrete = TRUE,
  approx = FALSE,
  mintl = 3L
) {
  .hill_check_flags(discrete, approx)
  mintl <- .rmbl_scalar(mintl, "mintl", 1, integer = TRUE)
  x <- .hill_positive(x, xmin)
  xmin <- .hill_xmin(x, xmin)
  tail <- x[x >= xmin]
  n <- length(tail)
  mintl <- max(2L, as.integer(mintl)[1L])
  if (n < mintl) {
    return(.hill_none(xmin, n, "too few tail observations"))
  }
  if (length(unique(tail)) == 1L) {
    # every tail value equal: no slope to fit, and the zeta likelihood just
    # pushes alpha to the optimiser's bound
    return(.hill_none(
      xmin,
      n,
      "not estimable: every tail value equals xmin"
    ))
  }
  if (isTRUE(discrete) && !isTRUE(approx)) {
    return(.hill_zeta(tail, xmin))
  }
  .hill_closed(tail, xmin, discrete)
}

#' Hurwitz zeta function
#'
#' Computes the Hurwitz zeta function
#' \eqn{\zeta(s, q) = \sum_{k \ge 0} (q + k)^{-s}} for a vector of exponents
#' \code{s} and one lower limit \code{q}. It is the normalising constant of
#' the discrete power law truncated below at \code{q}, which is why it is
#' here (see [hilltlidx()]); \code{zeta(s, 1)} is the
#' Riemann zeta.
#'
#' @details
#' For \eqn{s > 1} and \eqn{q > 0} the series is evaluated in compiled code
#' by Euler-Maclaurin summation: direct terms, the integral of the tail, and
#' Bernoulli-number corrections. For \eqn{s < 1} the value is the analytic
#' continuation: exact Bernoulli polynomials for whole \eqn{s > -5}
#' (\eqn{\zeta(-n, q) = -B_{n+1}(q)/(n+1)}), Riemann's functional equation at
#' \eqn{q = 1}, Hurwitz's Fourier series for \eqn{s \le -5}, Hermite's
#' integral (by \code{stats::integrate()}) for \eqn{-5 < s < 1}, and the
#' asymptotic series for large \eqn{q}, with the shift
#' \eqn{\zeta(s, q) = q^{-s} + \zeta(s, q + 1)} to move \eqn{q} into range.
#' A negative non-integer \code{q} uses the reflection of its negative terms.
#'
#' Values that do not exist are \code{NA}, not errors: \code{s = 1} (a pole),
#' \code{q} zero or a negative integer (poles), a fractional \code{s} with a
#' negative \code{q} (a complex value), and a non-finite \code{s}. Errors
#' when \code{s} or \code{q} is logical or not numeric, and when \code{q} is
#' not a single finite number.
#'
#' @param s Numeric vector of exponents. The series converges for \code{s > 1};
#'   below 1 the value is the analytic continuation (so \code{hurwzeta(0.5,
#'   0.5)} is \eqn{-0.6049}), and \code{s = 1} is a pole (\code{NA}).
#' @param q Numeric scalar, the lower limit; default \code{1} (the Riemann
#' zeta). Any real number but zero or a negative integer (poles, \code{NA}). For
#' a negative non-integer \code{q} the value is real only for a whole \code{s};
#' a fractional \code{s} gives \code{NA}.
#' @return A numeric vector the length of \code{s}.
#' @references
#' The Euler-Maclaurin expansion used here -- direct terms to `q + N`,
#' then the integral tail, then the Bernoulli-number corrections -- is the
#' standard evaluation; see Abramowitz, M. and Stegun, I. A.
#' *Handbook of Mathematical Functions*, Sec. 23.2. (Not in the local
#' corpus; cited from the published reference. The implementation is
#' checked against `pi^2/6`, `pi^4/90`, Apery's constant and the
#' shift identity, which is stronger evidence than the citation.)
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # The Riemann zeta at even integers has a closed form.
#' c(hurwzeta(2), pi^2 / 6)
#' c(hurwzeta(4), pi^4 / 90)
#'
#' # Apery's constant.
#' hurwzeta(3)
#'
#' # Shifting the lower limit removes exactly the leading term.
#' hurwzeta(2.5, 3) - hurwzeta(2.5, 4)
#' 3^-2.5
#'
#' # Outside the domain of convergence there is no value to return.
#' hurwzeta(1)
#'
#' # several exponents at once, including the analytic continuation
#' hurwzeta(c(2, 0.5, -1))  # -1/12 at s = -1
#'
#' # one lower limit per call
#' try(hurwzeta(2, q = c(1, 2)))
#' @export
hurwzeta <- function(s, q = 1) {
  q <- .rmbl_hurwitz_q(s, q)
  s <- .rmbl_num_input(s, "s")
  if (q > 0) {
    return(.rmbl_hurwitz_any(s, q))
  }
  if (q == round(q)) {
    return(rep(NA_real_, length(s)))
  } # a pole, like s = 1: no value to return
  .rmbl_hurwitz_negq(s, q)
}

#' Association in a contingency table
#'
#' Cramer's V, with the bias correction of Bergsma (2013) available, and
#' the small-expected-count condition reported rather than assumed away.
#' Use it to say how strongly two categorical variables are associated (0 is
#' none, 1 is complete), for example region by outcome in a cross-tabulation,
#' on a scale that does not depend on the number of rows and columns.
#'
#' @details
#' With \eqn{\chi^2} the Pearson statistic (no continuity correction),
#' \eqn{n} the total, \eqn{r} rows and \eqn{k} columns, \eqn{\phi^2 =
#' \chi^2/n} and the uncorrected \eqn{V = \sqrt{\phi^2 / \min(r-1, k-1)}}.
#' Bergsma's correction replaces \eqn{\phi^2} with
#' \eqn{\max(0, \phi^2 - (r-1)(k-1)/(n-1))} and \eqn{r, k} with
#' \eqn{r - (r-1)^2/(n-1)} and \eqn{k - (k-1)^2/(n-1)}.
#'
#' Empty rows and columns (an unused factor level) are dropped first, and
#' \code{method} says so. When fewer than two rows or columns remain, every
#' statistic is \code{NA}. When any expected count is below
#' \code{minexp}, the p-value comes from
#' \code{stats::chisq.test(simulate.p.value = TRUE, B = 10000)} under
#' \code{seed}, and the caller's random number stream is restored afterwards.
#'
#' Errors: \code{tbl} \code{NULL}, not numeric, or with a negative or
#' non-finite count; \code{biascor} not \code{TRUE} or \code{FALSE};
#' \code{minexp} not a single non-negative number.
#'
#' @param tbl A table or matrix of non-negative counts, at least 2 by 2
#' after empty rows and columns are dropped.
#' @param biascor Logical scalar, default \code{TRUE}: whether to apply
#' Bergsma's
#' correction, which removes most of V's upward bias in a sparse table.
#' Worth having: uncorrected V on a sparse table reports association that
#' is an artefact of the table's size.
#' @param minexp Numeric scalar, default \code{5}: the expected count
#' below which the chi-square approximation is treated as unreliable.
#' Reported, and it switches the p-value to the Monte Carlo one; it does not
#' stop the calculation.
#' @return A list with \code{v} (numeric, Cramer's V), \code{chisq} (the
#' Pearson statistic), \code{df} (integer), \code{p_value}, \code{n} (the
#' total count), \code{minexp} (the smallest expected count in the
#' table), \code{cellsbelow} (integer), the number of
#' cells whose expected count falls under the threshold. When any does,
#' `p_value` comes from a Monte Carlo permutation instead of the
#' chi-square approximation, and `method` says which was used.
#' @references
#' Bergsma, W. (2013). A bias-correction for Cramer's V and Tschuprow's T.
#' *Journal of the Korean Statistical Society* 42(3), 323-328. (Not in
#' the local corpus; cited from the published paper.)
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' tbl <- rbind(c(120, 80), c(40, 160))
#' cramerv(tbl)
#'
#' # No association gives a V near zero.
#' cramerv(rbind(c(100, 100), c(100, 100)))$v
#'
#' # A sparse table's uncorrected V overstates the association.
#' sparse <- rbind(c(3, 1), c(1, 3))
#' c(raw = cramerv(sparse, biascor = FALSE)$v,
#'   corrected = cramerv(sparse)$v)
#'
#' # small expected counts: a Monte Carlo p-value, and the method says so
#' cramerv(sparse)$method
#'
#' # an unused level is dropped
#' cramerv(rbind(c(30, 10), c(0, 0), c(12, 28)))$method
#'
#' # negative counts are refused
#' try(cramerv(rbind(c(-1, 2), c(1, 2))))
#' @param seed Integer scalar, default \code{1}: the seed for the Monte Carlo
#'   branch; the caller's random number stream is restored afterwards.
#' @export
cramerv <- function(tbl, biascor = TRUE, minexp = 5, seed = 1L) {
  .rmbl_no_fn(tbl = tbl)
  .cramerv_check(tbl, biascor, minexp)
  m <- as.matrix(tbl)
  # an unused factor level is an empty row or column: it carries no
  # information and made every expected count on that margin zero (NaN
  # statistic, NaN V). drfthomog() already drops them; so does this.
  dropped <- sum(rowSums(m) == 0) + sum(colSums(m) == 0)
  m <- m[rowSums(m) > 0, colSums(m) > 0, drop = FALSE]
  if (any(dim(m) < 2L)) {
    return(.rmbl_cls(.cramerv_small(m, dropped), "rmbl_cramerv"))
  }
  # negative counts were refused above, and a table with an empty margin
  # has just been dropped, so what is left has a positive total
  n <- sum(m)
  ct <- suppressWarnings(stats::chisq.test(m, correct = FALSE))
  chi <- as.numeric(ct$statistic)
  r <- nrow(m)
  k <- ncol(m)
  below <- sum(ct$expected < minexp)
  # the chi-square approximation rests on the expected counts; when it
  # does not hold, permute instead of reporting a p-value the table
  # cannot support
  method <- "chi-square approximation"
  p <- as.numeric(ct$p.value)
  if (below > 0L) {
    sim <- .rmbl_with_seed(
      seed,
      suppressWarnings(
        stats::chisq.test(m, simulate.p.value = TRUE, B = 10000L)
      )
    )
    p <- as.numeric(sim$p.value)
    method <- "Monte Carlo permutation (small expected counts)"
  }
  if (dropped) {
    method <- paste0(method, "; ", dropped, " empty row(s)/column(s) dropped")
  }
  v <- .cramerv_v(chi / n, r, k, n, biascor)
  .rmbl_cls(list(
    v = v,
    chisq = chi,
    df = as.integer(ct$parameter),
    p_value = p,
    n = n,
    minexp = min(ct$expected),
    cellsbelow = below,
    method = method
  ), "rmbl_cramerv")
}

#' @export
format.rmbl_top_share <- function(x, digits = 4L, ...) {
  title <- "Top shares of a total"
  fb <- .rmbl_df_fallback(x, title, c("fraction", "units", "share"), digits)
  if (!is.null(fb)) {
    return(fb)
  }
  d <- .rmbl_plain(x)
  tb <- data.frame(
    top = paste0(.rmbl_fmt_num(100 * d$fraction, digits), "%"),
    units = d$units,
    share = paste0(.rmbl_fmt_num(100 * d$share, digits), "%"),
    stringsAsFactors = FALSE
  )
  .rmbl_res_block(
    title,
    facts = list(Fractions = nrow(d)),
    tables = list(tb),
    reading = if (nrow(d)) {
      sprintf(
        paste(
          "The top %s of units (%s of them) hold %s of the total; with",
          "equal shares they would hold %s."
        ),
        tb$top[1L],
        .rmbl_fmt_num(d$units[1L]),
        tb$share[1L],
        tb$top[1L]
      )
    },
    digits = digits
  )
}

#' @export
format.rmbl_tail_index <- function(x, digits = 4L, ...) {
  est <- length(x$alpha) && !is.na(x$alpha)
  .rmbl_stat_block(
    "Power-law tail index",
    facts = list(
      `Tail exponent (alpha)` = if (est) x$alpha else "not estimated",
      `Standard error` = if (est) x$se,
      `Threshold (xmin)` = x$xmin,
      `Tail observations` = x$ntl,
      `KS distance` = if (est) x$ks,
      Reliable = if (isTRUE(x$reliable)) "yes" else "no",
      Method = x$method
    ),
    reading = .rmbl_wrap(.hill_reading(x, est)),
    digits = digits
  )
}

#' @export
format.rmbl_cramerv <- function(x, digits = 4L, ...) {
  .rmbl_stat_block(
    "Cramer's V",
    facts = list(
      `Cramer's V` = if (is.na(x$v)) "not available" else x$v,
      `Chi-square` = x$chisq,
      df = x$df,
      `p-value` = .rmbl_p_fact(x$p_value),
      Observations = x$n,
      `Smallest expected` = x$minexp,
      `Cells below minimum` = x$cellsbelow,
      Method = x$method
    ),
    reading = .rmbl_wrap(.cramerv_reading(x)),
    digits = digits
  )
}

#' Checks the values a concentration measure is computed from.
#' @param x The values passed by the user.
#' @return `x` as finite, non-negative doubles.
#' @noRd
.rmbl_conc_input <- function(x) {
  # .rmbl_finite_input() has already refused non-numeric and negative
  # values: a negative value has no place in a share of a total
  x <- .rmbl_num(.rmbl_finite_input(x, "x", nonneg = TRUE), "x")
  if (all(is.na(x))) {
    stop(
      "`x` has no values: a concentration measure of nothing is undefined",
      call. = FALSE
    )
  }
  x
}

#' hilltlidx()'s `discrete` and `approx`, checked.
#' @param discrete,approx As for hilltlidx().
#' @noRd
.hill_check_flags <- function(discrete, approx) {
  for (flag in c("discrete", "approx")) {
    v <- if (flag == "discrete") discrete else approx
    if (!is.logical(v) || length(v) != 1L || is.na(v)) {
      stop(
        sprintf("hilltlidx: `%s` must be TRUE or FALSE", flag),
        call. = FALSE
      )
    }
  }
  invisible(NULL)
}

#' hilltlidx()'s threshold: the one given, checked, or the 50th largest value
#' (everything, when there are fewer).
#' @param x The positive finite values.
#' @param xmin As for hilltlidx().
#' @return The threshold.
#' @noRd
.hill_xmin <- function(x, xmin) {
  if (is.null(xmin)) {
    # enough of a tail to estimate from, or everything if there is not
    s <- sort(x, decreasing = TRUE)
    xmin <- if (length(s) >= 50L) s[50L] else min(s)
  }
  xmin <- .rmbl_num(xmin, "xmin")
  if (length(xmin) != 1L) {
    stop("`xmin` must be a single threshold", call. = FALSE)
  }
  if (is.na(xmin) || xmin <= 0) {
    stop("`xmin` must be positive", call. = FALSE)
  }
  xmin
}

#' hilltlidx()'s result when no tail index can be fitted.
#' @param xmin The threshold.
#' @param n The tail's size.
#' @param method Why.
#' @return The result list.
#' @noRd
.hill_none <- function(xmin, n, method) {
  .rmbl_cls(list(
    alpha = NA_real_,
    se = NA_real_,
    xmin = xmin,
    ntl = n,
    ks = NA_real_,
    reliable = FALSE,
    method = method
  ), "rmbl_tail_index")
}

#' The exact discrete (zeta) maximum-likelihood tail index.
#'
#' The zeta distribution truncated below at xmin:
#'   p(k) = k^-alpha / zeta(alpha, xmin),  k = xmin, xmin + 1, ...
#' so the log-likelihood is
#'   -n log zeta(alpha, xmin) - alpha * sum log k
#' which has no closed-form maximiser and is concave in alpha, so one
#' univariate maximisation settles it.
#' @param tail The values at or above the threshold, not all equal.
#' @param xmin The threshold.
#' @return hilltlidx()'s result list.
#' @noRd
.hill_zeta <- function(tail, xmin) {
  n <- length(tail)
  logsum <- sum(log(tail)) # finite: the tail is finite and positive
  nll <- function(a) {
    z <- .rmbl_hurwitz(a, xmin)
    if (!is.finite(z) || z <= 0) {
      return(.Machine$double.xmax)
    }
    n * log(z) + a * logsum
  }
  bounds <- c(1.0001, 25)
  opt <- stats::optimize(nll, interval = bounds, tol = 1e-9)
  alpha <- opt$minimum
  at_bound <- alpha <= bounds[1L] + 1e-3 || alpha >= bounds[2L] - 1e-3
  # the observed information, by a central difference on the score:
  # the second derivative of the log-likelihood has no simple form
  # because it needs the zeta's derivatives in the exponent
  h <- 1e-4
  d2 <- (nll(alpha + h) - 2 * nll(alpha) + nll(alpha - h)) / h^2
  se <- if (is.finite(d2) && d2 > 0) sqrt(1 / d2) else NA_real_
  method <- "exact discrete (zeta) maximum likelihood"
  ks <- .hill_zeta_ks(tail, alpha, xmin)
  if (at_bound) {
    method <- paste0(method, " (alpha at the optimiser bound; not a fit)")
  }
  .rmbl_cls(list(
    alpha = alpha,
    se = se,
    xmin = xmin,
    ntl = n,
    ks = ks,
    reliable = n >= 50L && !at_bound,
    method = method
  ), "rmbl_tail_index")
}

#' Computes the Hurwitz zeta function for any order but the pole.
#'
#' zeta(s, q) for q > 0 and every s but the pole s = 1. Three regimes:
#'  * s > 1: the C series.
#'  * s <= -5: Hurwitz's formula for 0 < f <= 1, with t = 1 - s >= 6, zeta(s, f)
#'      = 2 Gamma(t) / (2 pi)^t * sum_k cos(pi (2 k f - t / 2)) / k^t, which
#'      converges absolutely and fast; cospi() keeps the exact zeros (zeta(-2n)
#'      = 0).
#'  * -5 < s < 1: Hermite's integral at 1 <= q < 2, zeta(s, q) is q^-s / 2 plus
#'      q^(1 - s) / (s - 1) plus twice the integral over t from 0 to infinity of
#'      sin(s atan(t / q)) (q^2 + t^2)^(-s / 2) / (e^(2 pi t) - 1), whose
#'      integrand is smooth and small there. Any other q is moved into range
#'      first: up by zeta(s, q) = q^-s + zeta(s, q + 1), down by zeta(s, q) =
#'      zeta(s, f) - sum_{j < N} (f + j)^-s (the sum dominates, nothing
#'      cancels), and past q = max(40, 2 |s|) the asymptotic series at q itself
#'      is used (terms fall like (|s| / (2 pi q))^2k). The Euler-Maclaurin shift
#'      used before summed M = |s| + 20 terms of size M^-s and cancelled them
#'      against a small result: 1e-6 relative error at s = -4.9 and every digit
#'      lost below s = -5 (zeta(-15) came back as -2.3e7, review of 02a38be,
#'      C1).
#' @param s The orders, a numeric vector.
#' @param q The shift, a positive number.
#' @return A double vector the length of `s`; NA where `s` is not finite or is
#'   1.
#' @noRd
.rmbl_hurwitz_any <- function(s, q) {
  out <- rep(NA_real_, length(s))
  hi <- is.finite(s) & s > 1
  if (any(hi)) {
    out[hi] <- .rmbl_hurwitz(s[hi], q)
  }
  for (i in which(is.finite(s) & s < 1)) {
    out[[i]] <- .rmbl_hurwitz_below_one(s[[i]], q)
  }
  out
}

#' zeta(s, q) at a whole s in (-5, 1), by the Bernoulli polynomial.
#' @param si The whole s.
#' @param q The shift.
#' @return The value.
#' @noRd
.rmbl_hurwitz_negint <- function(si, q) {
  # zeta(-n, q) = -B_{n+1}(q) / (n + 1) exactly: a polynomial of degree at
  # most five, with no cancellation through q + 1 (zeta(-4, 1e-8) = 3.3e-10 is
  # a small difference of O(1) values)
  m <- 1 - si
  bk <- c(1, -1 / 2, 1 / 6, 0, -1 / 30, 0)[seq_len(m + 1)]
  direct <- -sum(choose(m, 0:m) * bk * q^(m - 0:m)) / m
  if (is.finite(direct)) {
    return(direct)
  }
  # q^m past the double range while the value itself is not (q = 5e61, s = -4
  # is -6.25e307): q^m / m factored out in logarithms
  -exp(m * log(q) - log(m)) * sum(choose(m, 0:m) * bk * q^(-(0:m)))
}

#' Computes the Hurwitz zeta function for one order below one.
#' @param si The order, a number below 1.
#' @param q The shift, a positive number.
#' @return A number.
#' @noRd
.rmbl_hurwitz_below_one <- function(si, q) {
  # zeta(s, 1/2) = (2^s - 1) zeta(s) exactly, and zeta(s) is accurate beside its
  # trivial zeros, where the Fourier series lost relative digits (34% near s =
  # -32 at b617a3f, 3.6e-5 at -32 + 1e-10 since; CRAN stress test of b617a3f).
  # expm1() keeps 2^s - 1 exact beside s = 0
  if (q == 0.5) {
    return(expm1(si * log(2)) * .rmbl_hurwitz_below_one(si, 1))
  }
  if (q == 1 && si < 0) {
    return(.rmbl_zeta_reflect(si))
  }
  if (si == round(si) && si > -5) {
    return(.rmbl_hurwitz_negint(si, q))
  }
  if (q >= max(40, 2 * abs(si))) {
    return(.rmbl_hurwitz_em(si, q, 0))
  }
  if (si <= -5 && q == round(q) && q >= 2) {
    # a whole q: zeta(s, q) = zeta(s) - sum_{k < q} k^-s, exactly, with zeta(s)
    # by the functional equation, which is accurate beside the trivial zeros.
    # The Fourier route lost 5.4e-8 relative at q = 2 near s = -30 (statistics
    # stress test of 5e1dce5)
    return(.rmbl_hurwitz_below_one(si, 1) - sum((seq_len(q - 1))^(-si)))
  }
  if (si <= -5) {
    N <- ceiling(q) - 1
    f <- q - N # 0 < f <= 1
    return(
      .rmbl_hurwitz_fourier(si, f) -
        if (N > 0) sum((f + (seq_len(N) - 1))^(-si)) else 0
    )
  }
  if (q < 1) {
    # step up into [1, 2)
    n <- ceiling(1 - q)
    up <- q + (seq_len(n) - 1)
    return(sum(up^(-si)) + .rmbl_hurwitz_hermite(si, q + n))
  }
  N <- floor(q) - 1
  f <- q - N # 1 <= f < 2
  .rmbl_hurwitz_hermite(si, f) -
    if (N > 0) sum((f + (seq_len(N) - 1))^(-si)) else 0
}

#' Computes the Hurwitz zeta function by Hurwitz's Fourier series, for an order
#' of -5 or less.
#' @param si The order.
#' @param f The shift, in (0, 1].
#' @return A number.
#' @noRd
.rmbl_hurwitz_fourier <- function(si, f) {
  t <- 1 - si
  # tail sum_{k > K} k^-t below 1e-18
  K <- min(1e5, max(50, ceiling((1e-18 * (t - 1))^(1 / (1 - t)))))
  k <- seq_len(K)
  # 2 k f reduced modulo 2 before t / 2 is taken off: cospi(2 k f - t / 2) lost
  # the digits of a small cosine to the rounding of 2 k f - t / 2 for large k
  series <- sum(cospi((2 * k * f) %% 2 - t / 2) / k^t)
  if (series == 0) {
    0
  } else {
    sign(series) * 2 * exp(lgamma(t) - t * log(2 * pi) + log(abs(series)))
  }
}

#' Computes the Hurwitz zeta function by Hermite's integral, for an order
#' between -5 and 1.
#' @param si The order.
#' @param q The shift, in [1, 2).
#' @return A number.
#' @noRd
.rmbl_hurwitz_hermite <- function(si, q) {
  g <- function(t) {
    sin(si * atan(t / q)) * (q * q + t * t)^(-si / 2) / expm1(2 * pi * t)
  }
  I <- stats::integrate(
    g,
    0,
    Inf,
    rel.tol = 2e-14,
    abs.tol = 0,
    subdivisions = 500L
  )$value
  q^(-si) / 2 + q^(1 - si) / (si - 1) + 2 * I
}

.rmbl_b2k <- c(
  1 / 6,
  -1 / 30,
  1 / 42,
  -1 / 30,
  5 / 66,
  -691 / 2730,
  7 / 6,
  -3617 / 510,
  43867 / 798,
  -174611 / 330,
  854513 / 138,
  -236364091 / 2730
)

#' Computes sin(pi x) with an exact argument reduction.
#'
#' sin(pi x) with the reduction done exactly: x - round(x) is exact (Sterbenz)
#' and the sign alternates with the integer.
#' @param x The argument of sin(pi * x), any real number.
#' @return sin(pi x).
#' @noRd
.rmbl_sinpi <- function(x) {
  k <- round(x)
  s <- sinpi(x - k)
  if (k %% 2 == 0) s else -s
}

#' Computes the Hurwitz zeta function by the Euler-Maclaurin formula.
#'
#' Euler-Maclaurin after M direct terms (M = 0: the asymptotic series at q
#' itself)
#' @param si The order.
#' @param q The shift.
#' @param M The number of terms summed directly before the series.
#' @return A number.
#' @noRd
.rmbl_hurwitz_em <- function(si, q, M) {
  x <- q + M
  # q + (n - 1): (q + n) - 1 lost a tiny q (C2)
  val <- if (M > 0) sum((q + (seq_len(M) - 1))^(-si)) else 0
  lead <- x^(1 - si) / (si - 1)
  # past the double range the value is the leading term's sign at infinity, not
  # NaN from Inf - Inf
  if (is.infinite(lead)) {
    return(lead)
  }
  val <- val + lead + x^(-si) / 2
  poch <- si
  for (k in seq_along(.rmbl_b2k)) {
    j <- 2 * k
    if (k > 1) {
      poch <- poch * (si + j - 3) * (si + j - 2)
    }
    val <- val + .rmbl_b2k[[k]] / factorial(j) * poch * x^(-si - j + 1)
  }
  val
}

#' Computes the Hurwitz zeta function by the C series, for orders above one.
#' @param s The orders.
#' @param q The shift.
#' @return A double vector.
#' @noRd
.rmbl_hurwitz <- function(s, q) {
  .Call(C_rmbl_hurwitz_zeta, as.numeric(s), as.numeric(q))
}

#' Computes the Kolmogorov-Smirnov distance between a sample and a fitted
#' distribution.
#'
#' Kolmogorov-Smirnov distance between a sample and a fitted
#' distribution function, evaluated once per DISTINCT value.
#'
#' seq_along(sort(x)) / n is not the empirical distribution function when
#' there are ties: it steps through a tied block instead of jumping once
#' at its end, so at the first member of the block it reads near zero.
#' Counts are almost all ties -- at an exponent of 2.5 three quarters of
#' the draws are the value one -- so this reported every good fit as a
#' terrible one.
#' @param x The sample.
#' @param cdf The fitted distribution function.
#' @param continuous Whether the fit is continuous, so the left limits of the
#'   empirical function count too.
#' @return The distance, or NA when there is nothing to compare.
#' @noRd
.rmbl_ks_discrete <- function(x, cdf, continuous = FALSE) {
  n <- length(x)
  if (!n) {
    return(NA_real_)
  }
  u <- sort(unique(x))
  cnt <- tabulate(match(x, u), nbins = length(u))
  hi <- cumsum(cnt) / n
  theo <- cdf(u)
  ok <- is.finite(theo)
  if (!any(ok)) {
    return(NA_real_)
  }
  d <- abs(hi[ok] - theo[ok])
  if (isTRUE(continuous)) {
    # For a CONTINUOUS fit the supremum can also be attained just below
    # a jump of the empirical function, where it still holds its
    # previous value while the fitted one has moved on.
    lo <- c(0, hi[-length(hi)])
    d <- c(d, abs(lo[ok] - theo[ok]))
  }
  # For a STEP fit both functions jump at the same support points, so
  # just below a jump both hold their previous values and that point is
  # already covered by the previous one. Including the left limit
  # against the right value there compares F_n(u-) with F(u), which
  # differs by the whole point mass at u -- at an exponent of 2.5 that
  # is three quarters of the distribution, and every good fit was
  # reported as a terrible one.
  max(d)
}

#' cramerv()'s table and options, checked.
#' @param tbl,biascor,minexp As for cramerv().
#' @noRd
.cramerv_check <- function(tbl, biascor, minexp) {
  # "abc" silently meant FALSE, and an NA threshold failed deep inside (review
  # of 52a8883)
  if (!is.logical(biascor) || length(biascor) != 1L || is.na(biascor)) {
    stop("`biascor` must be TRUE or FALSE", call. = FALSE)
  }
  if (
    !is.numeric(minexp) ||
      length(minexp) != 1L ||
      !is.finite(minexp) ||
      minexp < 0
  ) {
    stop("`minexp` must be a single non-negative number", call. = FALSE)
  }
  if (
    is.null(tbl) ||
      !is.numeric(as.matrix(tbl)) ||
      !all(is.finite(as.matrix(tbl))) ||
      any(as.matrix(tbl) < 0)
  ) {
    stop(
      "`tbl` must be a matrix or table of finite non-negative counts",
      call. = FALSE
    )
  }
  invisible(NULL)
}

#' Cramer's V from phi-squared, optionally bias-corrected.
#' @param phi2 Phi-squared.
#' @param r,k The table's rows and columns.
#' @param n Its total.
#' @param biascor As for cramerv().
#' @return V.
#' @noRd
.cramerv_v <- function(phi2, r, k, n, biascor) {
  if (!isTRUE(biascor)) {
    return(sqrt(phi2 / min(r - 1, k - 1)))
  }
  # Bergsma (2013): correct phi-squared and the dimensions for the bias
  # that makes V rise with the table's size rather than its association
  phi2c <- max(0, phi2 - (r - 1) * (k - 1) / (n - 1))
  rc <- r - (r - 1)^2 / (n - 1)
  kc <- k - (k - 1)^2 / (n - 1)
  den <- min(rc - 1, kc - 1)
  if (den <= 0) NA_real_ else sqrt(phi2c / den)
}

#' topshr()'s `fracs`, checked.
#' @param fracs The value passed.
#' @return The shares as a double vector.
#' @noRd
.rmbl_conc_fracs <- function(fracs) {
  if (
    is.factor(fracs) ||
      is.character(fracs) ||
      is.logical(fracs) ||
      !is.numeric(fracs)
  ) {
    stop("`fracs` must be numeric shares in [0, 1]", call. = FALSE)
  }
  f <- as.numeric(fracs)
  if (!length(f) || anyNA(f) || any(f < 0 | f > 1)) {
    stop("`fracs` must be shares in [0, 1]", call. = FALSE)
  }
  f
}

#' hilltlidx()'s `x`, its positive finite values, once `xmin` is known to be
#' numeric.
#' @param x,xmin As for hilltlidx().
#' @return The positive finite values of `x`.
#' @noRd
.hill_positive <- function(x, xmin) {
  # a factor's level code is not a threshold (xmin = factor("3") fitted from 1,
  # review of 52a8883)
  if (is.logical(xmin) || is.factor(xmin) || is.character(xmin)) {
    stop("`xmin` must be numeric, not logical, a factor or text", call. = FALSE)
  }
  x <- .rmbl_num(x, "x")
  x <- x[is.finite(x) & x > 0]
  if (!length(x)) {
    stop("`x` has no positive finite values to fit a tail to", call. = FALSE)
  }
  x
}

#' The closed-form tail fit of hilltlidx(): continuous, or
#' continuity-corrected for a discrete tail.
#' @param tail The tail values, not all equal.
#' @param xmin The threshold.
#' @param discrete As for hilltlidx().
#' @return hilltlidx()'s result.
#' @noRd
.hill_closed <- function(tail, xmin, discrete) {
  n <- length(tail)
  # the continuous Hill estimator, and its continuity-corrected discrete
  # cousin: closed form, exact for a continuous Pareto tail, and only
  # asymptotically right in xmin for a discrete one
  denom <- if (isTRUE(discrete) && xmin > 0.5) xmin - 0.5 else xmin
  # the tail is finite, positive, at or above xmin and not all equal (caught
  # above), so the log-ratio sum is finite and positive
  ssum <- sum(log(tail / denom))
  alpha <- 1 + n / ssum
  # the asymptotic standard error of the Hill estimator
  se <- (alpha - 1) / sqrt(n)
  # goodness of fit: the fitted tail's own distribution function against
  # the empirical one. alpha without this is a number fitted to whatever
  # shape the data had.
  ks <- .rmbl_ks_discrete(
    tail,
    function(q) 1 - (q / denom)^(1 - alpha),
    continuous = !isTRUE(discrete)
  )
  .rmbl_cls(list(
    alpha = alpha,
    se = se,
    xmin = xmin,
    ntl = n,
    ks = ks,
    reliable = n >= 50L,
    method = if (isTRUE(discrete)) {
      "continuity-corrected closed form (approximate)"
    } else {
      "continuous Hill maximum likelihood"
    }
  ), "rmbl_tail_index")
}

#' hurwzeta()'s `q`, checked (and that neither argument is logical).
#' @param s,q As for hurwzeta().
#' @return `q` as one finite number.
#' @noRd
.rmbl_hurwitz_q <- function(s, q) {
  if (is.logical(q) || is.logical(s)) {
    stop("`s` and `q` must be numeric, not logical", call. = FALSE)
  }
  q <- .rmbl_num_input(q, "q", allow_null = FALSE)
  if (length(q) != 1L || !is.finite(q)) {
    stop("`q` must be a single finite number", call. = FALSE)
  }
  q
}

#' The Hurwitz zeta at a negative, non-integer `q`.
#' @param s The exponents.
#' @param q The shift, negative and not a whole number.
#' @return A numeric vector, NA where `s` is not a whole number other than 1.
#' @noRd
.rmbl_hurwitz_negq <- function(s, q) {
  # q = -N + f with 0 < f < 1. The terms (q + n)^-s with q + n < 0 have absolute
  # values 1 - f, 2 - f, ..., N - f, so for a whole s their sum is (-1)^s
  # (zeta(s, 1 - f) - zeta(s, N + 1 - f)) and the rest is zeta(s, f): no
  # billion-term sum, and none of the cancellation that summed the terms one by
  # one lost every digit (s = 5 at q = -99999.5 came back as 0, review of
  # 52a8883, A7). For a fractional s a negative base has a complex power.
  f <- q - floor(q)
  N <- -floor(q)
  vapply(
    s,
    function(si) {
      if (!is.finite(si) || si != round(si) || si == 1) {
        return(NA_real_)
      }
      sgn <- if (si %% 2 == 0) 1 else -1
      # the two terms that cancel (exactly, for an odd s at f = 1/2) are added
      # first, the small tail last
      (.rmbl_hurwitz_any(si, f) + sgn * .rmbl_hurwitz_any(si, 1 - f)) -
        sgn * .rmbl_hurwitz_any(si, N + 1 - f)
    },
    numeric(1)
  )
}

#' The Kolmogorov-Smirnov fit of a zeta tail, for .hill_zeta().
#' @param tail The tail values.
#' @param alpha The fitted exponent.
#' @param xmin The threshold.
#' @return As for .rmbl_ks_discrete().
#' @noRd
.hill_zeta_ks <- function(tail, alpha, xmin) {
  # zeta(alpha, q) / zeta(alpha, xmin) is P(X >= q), so the
  # distribution function at an integer k is 1 - P(X >= k + 1).
  # Using P(X >= k) instead omits the whole point mass at k, which at
  # a threshold of one is about three quarters of the distribution --
  # the fit would be reported as terrible however good it was.
  denom_z <- .rmbl_hurwitz(alpha, xmin)
  cdf <- function(q) {
    1 -
      vapply(
        q + 1,
        function(v) {
          .rmbl_hurwitz(alpha, v) / denom_z
        },
        0
      )
  }
  .rmbl_ks_discrete(tail, cdf)
}

#' Riemann's zeta at a negative s, by its functional equation.
#' @param si One exponent, below zero.
#' @return zeta(si).
#' @noRd
.rmbl_zeta_reflect <- function(si) {
  # Riemann's zeta by its functional equation, zeta(s) = 2^s pi^(s-1) sin(pi s
  # / 2) Gamma(1-s) zeta(1-s): sinpi() is exact at the trivial zeros and
  # accurate beside them, where the general route lost the relative digits of
  # a value near zero (3.5e-7 at s = -2 + 1e-7; review of e57fed5). zeta(1 -
  # s) has 1 - s > 1, the C series. sinpi(x) beside x = -1 is sin(pi * x) in
  # R, which carries the absolute error of pi * x (about 2e-16) into a value
  # of order the distance from -1: the distance is taken first, exactly (si /
  # 2 + 1 is exact there, Sterbenz), and sinpi of that is accurate (review of
  # 46de6a9, F5: sin(pi * x) was off by up to 8.9% at -2 +/- 1e-15, on glibc
  # as on other libms)
  sp <- .rmbl_sinpi(si / 2)
  if (sp == 0) {
    return(0)
  }
  lmag <- si *
    log(2) +
    (si - 1) * log(pi) +
    lgamma(1 - si) +
    log(abs(.rmbl_hurwitz(1 - si, 1)))
  sign(sp) * exp(lmag + log(abs(sp)))
}

#' cramerv()'s result for a table with fewer than two rows or columns left.
#' @param m The table, its empty rows and columns dropped.
#' @param dropped How many were dropped.
#' @return cramerv()'s result, every statistic missing.
#' @noRd
.cramerv_small <- function(m, dropped) {
  list(
    v = NA_real_,
    chisq = NA_real_,
    df = NA_integer_,
    p_value = NA_real_,
    n = sum(m),
    minexp = NA_real_,
    cellsbelow = NA_integer_,
    method = if (dropped) {
      "table too small after dropping empty rows/columns"
    } else {
      "table too small"
    }
  )
}

#' What a hilltlidx() result says, in words.
#' @param x A hilltlidx() result.
#' @param est Whether an exponent was estimated.
#' @return One string.
#' @noRd
.hill_reading <- function(x, est) {
  if (!est) {
    return(paste0("No exponent was estimated (", x$method, ")."))
  }
  a <- .rmbl_fmt_num(x$alpha)
  out <- if (x$alpha <= 2) {
    paste(
      "An exponent of", a, "(2 or below) means the mean is barely defined:",
      "the largest values dominate the total, and the observed maximum says",
      "little about the next one."
    )
  } else {
    paste(
      "An exponent of", a, "(above 2): a heavy tail, but one with a",
      "defined mean."
    )
  }
  if (!isTRUE(x$reliable)) {
    out <- paste(out, "The estimate is flagged as not reliable.")
  }
  out
}

#' What a cramerv() result says, in words, at the 5% level.
#' @param x A cramerv() result.
#' @return One string.
#' @noRd
.cramerv_reading <- function(x) {
  if (is.na(x$v)) {
    return(paste(
      "There is no association to measure: the table needs two rows and",
      "two columns with counts."
    ))
  }
  lead <- paste(
    "V =", .rmbl_fmt_num(x$v), "on a scale from 0 (the row says nothing",
    "about the column) to 1 (the row fixes the column)"
  )
  if (is.na(x$p_value)) {
    return(paste0(lead, "."))
  }
  if (x$p_value < 0.05) {
    paste0(
      lead, "; an association this strong is unlikely to be chance (p ",
      .rmbl_p_txt(x$p_value), ")."
    )
  } else {
    paste0(
      lead, "; an association this size could be chance (p ",
      .rmbl_p_txt(x$p_value), ")."
    )
  }
}
