# SPDX-License-Identifier: AGPL-3.0-or-later
# Search theory for search and rescue planning: lateral range curves and sweep width, probability
# of detection from coverage, parallel sweeps with navigation error, probability of success with
# Bayesian updating of containment, datum probability maps and the optimal allocation of effort.
# The formulas are those of rmorie's SearchTheory module (LateralRange() and the rest);
# tests/testthat/test-search.R holds the two to 1e-12.

#' Stops with the calling function's name and a formatted message.
#' @param fmt A sprintf() format.
#' @param ... Values for the format.
#' @return Does not return.
#' @noRd
.sr_stop <- function(fmt, ...) stop(.rmbl_fn(), sprintf(fmt, ...), call. = FALSE)

#' Checks a numeric search input and returns it as a double vector.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param scalar Whether a single number is required.
#' @param min,max The range accepted.
#' @param positive Whether the value must be above zero.
#' @param whole Whether the value must be a whole number.
#' @return A double vector, with the dimensions of `x` kept.
#' @noRd
.sr_num <- function(x, what, scalar = TRUE, min = -Inf, max = Inf, positive = FALSE, whole = FALSE) {
  if (is.logical(x) && !all(is.na(x))) .sr_stop("`%s` must be numeric, not logical", what)
  v <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (!length(v)) .sr_stop("`%s` must have at least one value", what)
  if (scalar && length(v) != 1L) .sr_stop("`%s` must be a single number", what)
  if (anyNA(v) || any(!is.finite(v))) .sr_stop("`%s` must be finite, with no missing values", what)
  if (positive && any(v <= 0)) .sr_stop("`%s` must be positive", what)
  if (any(v < min | v > max)) {
    .sr_stop("`%s` must be %s", what, if (is.finite(max)) sprintf("between %s and %s", format(min), format(max))
             else sprintf("at least %s", format(min)))
  }
  if (whole && any(v != round(v))) .sr_stop("`%s` must be a whole number", what)
  if (!is.null(dim(x))) dim(v) <- dim(x) else names(v) <- names(x)
  v
}

#' Checks that grid edges or abscissae strictly increase.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @return A double vector.
#' @noRd
.sr_incr <- function(x, what) {
  v <- .sr_num(x, what, scalar = FALSE)
  if (length(v) < 2L || is.unsorted(v, strictly = TRUE)) {
    .sr_stop("`%s` must hold at least two strictly increasing values", what)
  }
  v
}

#' Checks containment probabilities: each in \[0, 1\], at least one positive, summing to at most 1.
#' @param poc The value passed by the user.
#' @return A double vector, with the dimensions of `poc` kept.
#' @noRd
.sr_poc <- function(poc) {
  poc <- .sr_num(poc, "poc", scalar = FALSE, min = 0, max = 1)
  if (sum(poc) > 1 + 1e-9) .sr_stop("`poc` must sum to at most 1, got %s", format(sum(poc)))
  if (!any(poc > 0)) .sr_stop("`poc` must have at least one cell with a positive probability")
  poc
}

#' The lateral range curve without input checks.
#' @param x Lateral ranges.
#' @param W Sweep width.
#' @param model \code{"invcube"}, \code{"definite"} or \code{"mbeta"}.
#' @param m The M-Beta height.
#' @return Detection probabilities, one per `x`.
#' @noRd
.sr_lr <- function(x, W, model, m) {
  a <- abs(x)
  switch(model,
    definite = ifelse(a <= W / 2, 1, 0),
    mbeta = ifelse(a <= W / (2 * m), m, 0),
    invcube = ifelse(a == 0, 1, 1 - exp(-W^2 / (4 * pi * a^2)))
  )
}

#' The lateral range curve seen through a normal cross-track navigation error.
#'
#' The convolution of the curve with a normal of standard deviation `navsd` (Frost 1996, equation 5-14):
#' exact for the rectangular curves, the trapezoid rule on 641 points over 8 standard deviations either
#' side for the inverse cube.
#' @param x Lateral ranges.
#' @param W Sweep width.
#' @param model \code{"invcube"}, \code{"definite"} or \code{"mbeta"}.
#' @param m The M-Beta height.
#' @param navsd The navigation error's standard deviation.
#' @return Detection probabilities, one per `x`.
#' @noRd
.sr_lr_nav <- function(x, W, model, m, navsd) {
  if (navsd == 0) return(.sr_lr(x, W, model, m))
  if (model != "invcube") {
    h <- if (model == "mbeta") m else 1
    r <- W / (2 * h)
    return(h * (stats::pnorm((x + r) / navsd) - stats::pnorm((x - r) / navsd)))
  }
  # trapezoid over +-8 sd: Gauss-Hermite rippled once the error is as wide as the curve
  t <- seq(-8, 8, length.out = 641) * navsd
  w <- stats::dnorm(t, sd = navsd) * (t[2L] - t[1L])
  drop(matrix(.sr_lr(outer(x, t, "-"), W, model, m), length(x)) %*% w)
}

#' Gauss-Hermite or Gauss-Legendre nodes and weights by the Golub-Welsch eigenvalue method.
#' @param n The number of nodes.
#' @param kind \code{"hermite"} or \code{"legendre"}.
#' @return A list with nodes `t` and weights `w`.
#' @noRd
.sr_gauss <- function(n, kind) {
  i <- seq_len(n - 1)
  b <- if (kind == "hermite") sqrt(i / 2) else i / sqrt(4 * i^2 - 1)
  J <- matrix(0, n, n)
  J[cbind(i + 1, i)] <- b
  J[cbind(i, i + 1)] <- b
  e <- eigen(J, symmetric = TRUE)
  o <- order(e$values)
  list(t = e$values[o], w = (if (kind == "hermite") sqrt(pi) else 2) * e$vectors[1, o]^2)
}

#' POD from coverage without input checks.
#' @param cv Coverages.
#' @param model \code{"random"}, \code{"definite"}, \code{"invcube"} or \code{"mbeta"}.
#' @param m The M-Beta height.
#' @return The PODs.
#' @noRd
.sr_pod <- function(cv, model, m = 1) {
  switch(model,
    random = 1 - exp(-cv),
    definite = pmin(cv, 1),
    invcube = 2 * stats::pnorm(sqrt(pi) * cv / 2 * sqrt(2)) - 1,
    mbeta = ifelse(cv < m, cv, 1 - (1 - m)^(cv / m))
  )
}

#' A model's name for a title.
#' @param model The model code.
#' @return A string.
#' @noRd
.sr_model_name <- function(model) {
  c(invcube = "inverse cube", definite = "definite range", mbeta = "M-Beta", random = "random search",
    corridor = "corridor", general = "generalized", point = "point", line = "line", area = "area")[[model]]
}

#' Search theory for search and rescue planning
#'
#' @description
#' The quantities a search and rescue planner works with (Koopman's search
#' theory, as used in the U.S. Coast Guard and IAMSAR planning methods):
#' \itemize{
#'   \item \code{ltrlrng()} (lateral range): the probability that a sensor
#'     passing at distance \code{x} detects the object, under the inverse
#'     cube, definite range or M-Beta model with sweep width \code{W};
#'   \item \code{swpwdth()} (sweep width): the area under a sampled lateral
#'     range curve;
#'   \item \code{srchpod()} (search POD): the probability of detection from
#'     coverage, for random search, a definite-range sweep and an inverse
#'     cube parallel sweep;
#'   \item \code{pswppod()} (parallel sweep POD): the POD of a parallel sweep
#'     at track spacing \code{S}, computed for any model, with optional
#'     normal navigation error;
#'   \item \code{srchscs()} (search success): the probability of success,
#'     the cumulative POD of repeated searches and the containment
#'     probabilities updated after an unsuccessful search;
#'   \item \code{datumpmap()} (datum probability map): the probability that
#'     each grid cell contains the object, for a point, line or area datum;
#'   \item \code{optcrcsrch()} (optimal circular search): Koopman's optimal
#'     effort for a circular normal datum;
#'   \item \code{opteffort()} (optimal effort): the allocation of a fixed
#'     effort over cells that maximises the probability of success.
#' }
#'
#' @details
#' Coverage is \code{C = W z / A}: sweep width times track length over the
#' area searched (for a parallel sweep, \code{W / S}). The lateral range
#' curves are: definite range, \code{p(x) = 1} for \code{|x| <= W / 2};
#' M-Beta, \code{p(x) = m} for \code{|x| <= W / (2 m)}; inverse cube,
#' \code{p(x) = 1 - exp(-W^2 / (4 pi x^2))}. Each has area \code{W}, the
#' sweep width. \code{swpwdth()} integrates by the trapezoid rule.
#'
#' With \code{navsd > 0}, \code{ltrlrng()} gives the expected curve seen
#' through a normal cross-track navigation error: the convolution of the curve
#' with that normal (Frost 1996, equation 5-14), exact for the rectangular
#' curves and by the trapezoid rule for the inverse cube. Its
#' area is still \code{W}; the curve is lower and wider.
#'
#' \code{srchpod()}: random search \code{1 - exp(-C)}; definite range
#' \code{min(C, 1)}; inverse cube parallel sweep
#' \code{erf(sqrt(pi) C / 2)} (Koopman 1956); M-Beta parallel sweep
#' \code{C} for \code{C < M} and \code{1 - (1 - M)^(C / M)} above it
#' (Frost 1996, equation 5-11), which is exact wherever the tracks overlap a
#' whole number of times.
#'
#' \code{pswppod()} integrates over one track spacing (Simpson's rule on
#' \code{npts} points) the probability that at least one of the tracks
#' \code{-ntrk, ..., ntrk} detects the object; for the inverse cube model the
#' tracks beyond \code{ntrk} are added in closed form from
#' \code{sum_k 1 / (x - k S)^2 = (pi / S)^2 / sin^2(pi x / S)}. With
#' \code{navsd > 0} the lateral range curve is averaged over a normal
#' cross-track error (40-point Gauss-Hermite quadrature). Without navigation
#' error the inverse cube result equals \code{srchpod(W / S, "invcube")}.
#'
#' \code{srchscs()}: the probability of success is
#' \code{POS = sum(POC * POD)}; after an unsuccessful search the containment
#' probabilities become \code{POC (1 - POD) / (1 - POS)} (Bayes). With several
#' searches (\code{pod} a matrix, one row per search) the update is applied in
#' turn and the cumulative POD is \code{1 - prod(1 - POD)} per area. When a
#' search is certain to succeed (\code{POS = 1}) the update is undefined: it
#' is returned as \code{NA}, with a warning.
#'
#' \code{datumpmap()}: a point datum is a circular normal of standard
#' deviation \code{sigma} about \code{center}; a line datum the same spread
#' along the segment from \code{center} to \code{end} (Gauss-Legendre
#' quadrature on \code{nodes} points); an area datum a uniform distribution
#' over the rectangle with corners \code{center} and \code{end}; a corridor
#' datum normal across the segment from \code{center} to \code{end} and
#' uniform along it, with nothing beyond its ends (Frost 1996, figure 3-8;
#' the segment must run along x or along y); a general datum the cell weights
#' \code{wts} scaled to sum to 1. The share of the probability outside the
#' grid is returned as \code{outside}.
#'
#' \code{optcrcsrch()}: with effort (track length) \code{L}, the optimal
#' search of a circular normal datum covers a disc of radius
#' \code{R = (4 sigma^2 W L / pi)^(1/4)}, and succeeds with probability
#' \code{1 - (1 + u) exp(-u)}, \code{u = R^2 / (2 sigma^2)} (Koopman 1957).
#'
#' \code{opteffort()}: under random search detection the optimal effort in
#' cell \code{i} is \code{z_i = (A_i / W) log(r_i / lambda)} where
#' \code{r_i = POC_i W / A_i} exceeds \code{lambda}, and 0 elsewhere; the
#' Lagrange multiplier \code{lambda} is found by bisection on its logarithm so
#' that the efforts add up to \code{effort} (Stone 1975, chapter 2).
#'
#' Every input is checked: numbers must be finite and of the right length,
#' sweep widths, spacings and standard deviations positive, probabilities in
#' \[0, 1\] and containment probabilities summing to at most 1; unknown models
#' and datum types are errors.
#'
#' @param x Numeric vector: lateral ranges (distances from the track), any
#'   sign. For \code{swpwdth()}, strictly increasing abscissae, or an
#'   \code{rmbl_ltrlrng} object (then \code{p} is taken from it).
#' @param W Positive number: the sweep width.
#' @param model For \code{ltrlrng()} and \code{pswppod()}: \code{"invcube"}
#'   (the default), \code{"definite"} or \code{"mbeta"}. For
#'   \code{srchpod()}: \code{"random"} (the default), \code{"definite"},
#'   \code{"invcube"} or \code{"mbeta"}.
#' @param m Number in (0, 1]: the M-Beta detection probability inside its
#'   range. Default 1.
#' @param p Numeric vector in \[0, 1\]: the lateral range curve at \code{x}.
#' @param coverage Non-negative numeric vector of coverages.
#' @param S Positive number: the track spacing.
#' @param navsd Non-negative number: the standard deviation of the
#'   cross-track navigation error, in the units of \code{x}. Default 0.
#' @param npts,ntrk Whole numbers: the quadrature points across one spacing
#'   (at least 3, raised to the next odd number; default 2001) and the tracks
#'   on each side (at least 1; default 60).
#' @param poc Numeric vector or matrix in \[0, 1\], summing to at most 1: the
#'   probability that each area contains the object. For \code{opteffort()}
#'   also an \code{rmbl_datummap} object from \code{datumpmap()}.
#' @param pod Numeric vector in \[0, 1\], one per area, or a matrix with one
#'   row per search and one column per area.
#' @param xedg,yedg Strictly increasing numeric vectors: the cell edges of the
#'   grid.
#' @param datum \code{"point"} (the default), \code{"line"}, \code{"area"},
#'   \code{"corridor"} or \code{"general"}.
#' @param center Two numbers: the datum point, the start of a line datum or a
#'   corner of an area datum. Default \code{c(0, 0)}.
#' @param sigma Positive number: the standard deviation of the circular normal
#'   position error.
#' @param end Two numbers: the end of a line datum or the opposite corner of
#'   an area datum; \code{NULL} for a point datum.
#' @param nodes Whole number from 2 to 1000: Gauss-Legendre nodes along a line
#'   datum. Default 64.
#' @param effort Non-negative number: the total effort, as track length.
#' @param area Positive numeric vector, one per cell: the cell areas. May be
#'   \code{NULL} when \code{poc} is an \code{rmbl_datummap}.
#' @param tol Positive number: the bisection tolerance on log lambda.
#' @param wts For \code{datum = "general"}: a non-negative matrix of cell
#'   weights, one row per \code{y} cell and one column per \code{x} cell.
#' @return \code{ltrlrng()}: a numeric vector of class \code{rmbl_ltrlrng}
#'   (the detection probabilities, with the inputs as attributes;
#'   \code{as.numeric()} drops them). \code{srchpod()}: a numeric vector of
#'   class \code{rmbl_srchpod}. \code{swpwdth()} and \code{pswppod()}: one
#'   number. \code{srchscs()}: a list of class \code{rmbl_srchscs} with
#'   \code{pos} (the probability of success), \code{posarea} (per area),
#'   \code{pocupd} (the updated containment probabilities) and
#'   \code{cumpod} (the cumulative POD per area). \code{datumpmap()}: a list
#'   of class \code{rmbl_datummap} with \code{poc}, a matrix with one row
#'   per \code{y} cell and one column per \code{x} cell, \code{outside}, and
#'   the inputs. \code{optcrcsrch()}: a list of class \code{rmbl_optcrc} with
#'   \code{radius}, \code{pos} and \code{cntrdns} (the coverage at the
#'   centre). \code{opteffort()}: a list of class \code{rmbl_opteffort} with
#'   \code{effort}, \code{coverage} and \code{pod} per cell (a matrix when
#'   \code{poc} is one), \code{pos} and \code{lambda}. Every class has a
#'   \code{print()} method, and \code{plot()} draws the lateral range curve
#'   (\code{equiv = TRUE} adds the equivalent definite-range rectangle,
#'   \code{spacing} a second track), the POD by coverage for any of the
#'   models (\code{models}, \code{m}, \code{cmax}), the map as an image with
#'   contours, a surface banded by height, the surface and its top view side
#'   by side (the device's two panels, or the
#'   next two of a layout the caller set with \code{par(mfrow = )}), or its
#'   cells with their percentages (\code{view}), and the allocation (see
#'   \code{\link{plot-methods}}). \code{\link{srchfig}} draws every figure of
#'   Frost (1996) with them.
#' @references Koopman, B. O. (1946). Search and Screening. OEG Report 56,
#'   Operations Evaluation Group, Office of the Chief of Naval Operations.
#'
#'   Koopman, B. O. (1956). The theory of search. I. Kinematic bases.
#'   Operations Research 4(3), 324-346. \doi{10.1287/opre.4.3.324}
#'
#'   Koopman, B. O. (1956). The theory of search. II. Target detection.
#'   Operations Research 4(5), 503-531. \doi{10.1287/opre.4.5.503}
#'
#'   Koopman, B. O. (1957). The theory of search. III. The optimum
#'   distribution of searching effort. Operations Research 5(5), 613-626.
#'   \doi{10.1287/opre.5.5.613}
#'
#'   Frost, J. R. (1996). The Theory of Search: A Simplified Explanation.
#'   Soza and Company and U.S. Coast Guard Office of Search and Rescue.
#'
#'   Stone, L. D. (1975). Theory of Optimal Search. Academic Press.
#' @srrstats {G1.0} Koopman (1946, 1956, 1957), Frost (1996) and Stone (1975) are cited in @references.
#' @srrstats {G1.3} @details defines coverage, the lateral range curves, sweep width, POD, POC and POS with their
#'   formulas.
#' @srrstats {G2.0} Scalars (W, S, m, navsd, sigma, effort, tol) must have length one, `center` and `end` two,
#'   `p` the length of `x`, `area` and the columns of `pod` the length of `poc`.
#' @srrstats {G2.1} Each @param gives the type and range accepted; character, factor and logical input is
#'   refused.
#' @srrstats {G2.2} A vector given for a single-valued parameter is refused, not silently truncated.
#' @srrstats {G2.3a} `model` and `datum` are matched by .rmbl_arg(), which names the accepted values.
#' @srrstats {G2.13} Missing values are refused, with the argument named (test-search.R).
#' @srrstats {G2.16} Inf, -Inf and NaN are refused, with the argument named (test-search.R).
#' @srrstats {G5.4} test-search.R compares every function with rmorie's SearchTheory module on a grid of inputs
#'   at 1e-12 and with closed forms.
#' @srrstats {G5.4a} Closed forms checked: random search 1 - exp(-C), the inverse cube sweep width on a truncated
#'   range, the definite-range sweep POD W/S, Koopman's circular normal POS 1 - 2/e at u = 1.
#' @srrstats {G5.8} test-search.R triggers every refusal and matches its message.
#' @srrstats {G5.8a} Zero-length inputs are refused ("must have at least one value").
#' @srrstats {G5.8b} Character, factor and logical inputs are refused.
#' @srrstats {G5.8d} Out-of-range inputs are refused: probabilities outside \[0, 1\], containment summing above
#'   1, an area datum of zero width; a certain search warns that the update is undefined.
#' @srrstats {EA4.0} Every result is double, as a vector, matrix or list of doubles with a class.
#' @srrstats {EA6.0} test-search.R checks classes, dimensions, names and values of every result.
#' @examples
#' # inverse cube detection 0.5, 1 and 2 sweep widths off the track
#' ltrlrng(c(0.5, 1, 2), W = 1)
#' plot(ltrlrng(seq(-3, 3, by = 0.5), W = 2))
#'
#' # the area under the curve is the sweep width
#' xs <- seq(-200, 200, by = 0.01)
#' swpwdth(xs, ltrlrng(xs, W = 1, model = "definite"))
#'
#' # POD at coverage 1 under the three models
#' srchpod(1)
#' srchpod(c(0.5, 1, 2), model = "invcube")
#' plot(srchpod(c(0.5, 1, 1.5)))
#' # the book's M-Beta curves against random search and the definite range
#' plot(srchpod(1, "mbeta", m = 0.5), models = c("random", "definite", "mbeta"),
#'      m = c(0.5, 0.25))
#' # the expected curve under a navigation error as large as half the sweep width
#' plot(ltrlrng(0, W = 1, navsd = 0.5), equiv = TRUE)
#'
#' # a parallel sweep at spacing 1.3 W, without and with navigation error
#' pswppod(1, 1.3)
#' pswppod(1, 1.3, navsd = 0.3, npts = 201)
#'
#' # three areas searched once; the containment after finding nothing
#' srchscs(c(0.5, 0.3, 0.2), c(0.8, 0.5, 0))
#'
#' # a point datum on a 10 x 10 grid, and the best use of 30 units of track
#' m <- datumpmap(seq(-5, 5), seq(-5, 5), sigma = 2)
#' plot(m)
#' plot(m, view = "both")
#' # the book's line datum: normal across the line, uniform along it
#' plot(datumpmap(0:10, seq(-3, 3, by = 1.2), "corridor", c(0, 0), end = c(10, 0)),
#'      view = "cells", digits = 1)
#' a <- opteffort(m, W = 1, effort = 30)
#' a$pos
#' plot(a)
#' optcrcsrch(sigma = 2, W = 1, effort = 30)$pos
#'
#' # inputs that cannot be right are refused
#' try(ltrlrng(1, W = -1))
#' try(srchscs(c(0.8, 0.8), c(0.5, 0.5)))
#' @export
ltrlrng <- function(x, W, model = c("invcube", "definite", "mbeta"), m = 1, navsd = 0) {
  model <- .rmbl_arg(model)
  x <- .sr_num(x, "x", scalar = FALSE)
  W <- .sr_num(W, "W", positive = TRUE)
  m <- .sr_num(m, "m", positive = TRUE, min = 0, max = 1)
  navsd <- .sr_num(navsd, "navsd", min = 0)
  structure(as.vector(.sr_lr_nav(as.vector(x), W, model, m, navsd)), x = as.vector(x), W = W, model = model,
            m = m, navsd = navsd, class = "rmbl_ltrlrng")
}

#' @rdname ltrlrng
#' @export
swpwdth <- function(x, p = NULL) {
  if (inherits(x, "rmbl_ltrlrng") && is.null(p)) {
    p <- as.vector(unclass(x))
    x <- attr(x, "x")
  }
  x <- .sr_incr(x, "x")
  p <- .sr_num(p, "p", scalar = FALSE, min = 0, max = 1)
  if (length(p) != length(x)) .sr_stop("`p` must have one value per `x` (%d), got %d", length(x), length(p))
  sum(diff(x) * (p[-1] + p[-length(p)]) / 2)
}

#' @rdname ltrlrng
#' @export
srchpod <- function(coverage, model = c("random", "definite", "invcube", "mbeta"), m = 1) {
  model <- .rmbl_arg(model)
  cv <- as.vector(.sr_num(coverage, "coverage", scalar = FALSE, min = 0))
  m <- .sr_num(m, "m", positive = TRUE, min = 0, max = 1)
  structure(.sr_pod(cv, model, m), coverage = cv, model = model, m = m, class = "rmbl_srchpod")
}

#' @rdname ltrlrng
#' @export
pswppod <- function(W, S, model = c("invcube", "definite", "mbeta"), m = 1, navsd = 0, npts = 2001,
                    ntrk = 60) {
  model <- .rmbl_arg(model)
  W <- .sr_num(W, "W", positive = TRUE)
  S <- .sr_num(S, "S", positive = TRUE)
  m <- .sr_num(m, "m", positive = TRUE, min = 0, max = 1)
  navsd <- .sr_num(navsd, "navsd", min = 0)
  npts <- .sr_num(npts, "npts", min = 3, max = 1e5, whole = TRUE)
  ntrk <- .sr_num(ntrk, "ntrk", min = 1, max = 1e4, whole = TRUE)
  if (npts %% 2 == 0) npts <- npts + 1
  gh <- if (navsd > 0) .sr_gauss(40L, "hermite")
  # the lateral range curve at each track's offset, averaged over the navigation error when there is one
  lr <- function(d) {
    if (is.null(gh)) return(.sr_lr(d, W, model, m))
    drop(matrix(.sr_lr(outer(d, sqrt(2) * navsd * gh$t, "+"), W, model, m), length(d)) %*% gh$w) / sqrt(pi)
  }
  h <- S / (npts - 1)
  ks <- -ntrk:ntrk
  vals <- vapply(seq_len(npts) - 1, function(i) {
    x <- i * h
    dd <- x - ks * S
    miss <- prod(1 - lr(dd))
    if (model == "invcube" && miss > 0) {
      near <- sum(1 / dd[dd != 0]^2)
      sn <- sin(pi * x / S)
      full <- if (sn != 0) (pi / S)^2 / sn^2 else near
      miss <- miss * exp(-W^2 / (4 * pi) * max(0, full - near))
    }
    1 - miss
  }, 0)
  odd <- seq(2, npts - 1, by = 2)
  even <- seq(3, npts - 2, by = 2)
  (vals[1] + vals[npts] + 4 * sum(vals[odd]) + 2 * sum(vals[even])) * h / 3 / S
}

#' @rdname ltrlrng
#' @export
srchscs <- function(poc, pod) {
  poc <- as.vector(.sr_poc(poc))
  pod <- .sr_num(pod, "pod", scalar = FALSE, min = 0, max = 1)
  D <- if (is.matrix(pod)) pod else matrix(pod, 1)
  if (ncol(D) != length(poc)) {
    .sr_stop("`pod` must have one value (or column) per area of `poc` (%d), got %d", length(poc), ncol(D))
  }
  cur <- poc
  for (k in seq_len(nrow(D))) {
    pos <- sum(cur * D[k, ])
    if (1 - pos <= 0) {
      warning("srchscs: the search is certain to find the object (POS = 1), so the updated containment ",
              "is undefined and returned as NA", call. = FALSE)
      cur[] <- NA_real_
      break
    }
    cur <- cur * (1 - D[k, ]) / (1 - pos)
  }
  cum <- 1 - apply(1 - D, 2, prod)
  structure(list(pos = sum(poc * cum), posarea = poc * cum, pocupd = cur, cumpod = cum, poc = poc,
                 nsrch = nrow(D)),
            class = "rmbl_srchscs")
}

#' @rdname ltrlrng
#' @export
datumpmap <- function(xedg, yedg, datum = c("point", "line", "area", "corridor", "general"), center = c(0, 0),
                      sigma = 1, end = NULL, nodes = 64, wts = NULL) {
  datum <- .rmbl_arg(datum)
  xedg <- .sr_incr(xedg, "xedg")
  yedg <- .sr_incr(yedg, "yedg")
  center <- .sr_num(center, "center", scalar = FALSE)
  if (length(center) != 2L) .sr_stop("`center` must be two numbers, x and y")
  sigma <- .sr_num(sigma, "sigma", positive = TRUE)
  if (datum %in% c("line", "area", "corridor")) {
    if (is.null(end)) .sr_stop("a %s datum needs `end`, two numbers", datum)
    end <- .sr_num(end, "end", scalar = FALSE)
    if (length(end) != 2L) .sr_stop("`end` must be two numbers, x and y")
  }
  nodes <- .sr_num(nodes, "nodes", min = 2, max = 1000, whole = TRUE)
  nx <- length(xedg) - 1
  ny <- length(yedg) - 1
  cell <- function(px, py) {
    outer(diff(stats::pnorm((yedg - py) / sigma)), diff(stats::pnorm((xedg - px) / sigma)))
  }
  grid <- switch(datum,
    point = cell(center[1], center[2]),
    line = {
      gl <- .sr_gauss(nodes, "legendre")
      Reduce(`+`, lapply(seq_along(gl$t), function(k) {
        f <- (gl$t[k] + 1) / 2
        gl$w[k] / 2 * cell(center[1] + f * (end[1] - center[1]), center[2] + f * (end[2] - center[2]))
      }))
    },
    corridor = {
      # ponytail: along x or y only; an oblique corridor needs a 2-D integral over each cell
      hz <- center[2] == end[2]
      if (!hz && center[1] != end[1]) .sr_stop("a corridor datum must run along x or along y")
      if (identical(center, end)) .sr_stop("a corridor datum needs `center` and `end` to differ")
      along <- function(e, a, b) pmax(0, pmin(b, e[-1]) - pmax(a, e[-length(e)])) / (b - a)
      across <- function(e, c0) diff(stats::pnorm((e - c0) / sigma))
      if (hz) {
        xr <- sort(c(center[1], end[1]))
        outer(across(yedg, center[2]), along(xedg, xr[1], xr[2]))
      } else {
        yr <- sort(c(center[2], end[2]))
        outer(along(yedg, yr[1], yr[2]), across(xedg, center[1]))
      }
    },
    general = {
      if (is.null(wts)) .sr_stop("a general datum needs `wts`, a matrix of cell weights")
      w <- .sr_num(wts, "wts", scalar = FALSE, min = 0)
      if (!identical(dim(w), c(as.integer(ny), as.integer(nx)))) {
        .sr_stop("`wts` must be a matrix with one row per y cell (%d) and one column per x cell (%d)", ny, nx)
      }
      if (!any(w > 0)) .sr_stop("`wts` must have at least one positive weight")
      w / sum(w)
    },
    area = {
      xr <- sort(c(center[1], end[1]))
      yr <- sort(c(center[2], end[2]))
      if (diff(xr) <= 0 || diff(yr) <= 0) .sr_stop("an area datum needs `center` and `end` to differ in x and in y")
      ox <- pmax(0, pmin(xr[2], xedg[-1]) - pmax(xr[1], xedg[-(nx + 1)]))
      oy <- pmax(0, pmin(yr[2], yedg[-1]) - pmax(yr[1], yedg[-(ny + 1)]))
      outer(oy, ox) / (diff(xr) * diff(yr))
    }
  )
  structure(list(poc = grid, outside = 1 - sum(grid), xedg = xedg, yedg = yedg, datum = datum, center = center,
                 end = end, sigma = sigma),
            class = "rmbl_datummap")
}

#' @rdname ltrlrng
#' @export
optcrcsrch <- function(sigma, W, effort) {
  sigma <- .sr_num(sigma, "sigma", positive = TRUE)
  W <- .sr_num(W, "W", positive = TRUE)
  effort <- .sr_num(effort, "effort", min = 0)
  R <- (4 * sigma^2 * W * effort / pi)^0.25
  u <- R^2 / (2 * sigma^2)
  structure(list(radius = R, pos = 1 - (1 + u) * exp(-u), cntrdns = R^2 / (2 * sigma^2 * W), sigma = sigma,
                 W = W, total = effort),
            class = "rmbl_optcrc")
}

#' @rdname ltrlrng
#' @export
opteffort <- function(poc, area = NULL, W, effort, tol = 1e-14) {
  edges <- NULL
  if (inherits(poc, "rmbl_datummap")) {
    edges <- list(xedg = poc$xedg, yedg = poc$yedg)
    if (is.null(area)) area <- outer(diff(poc$yedg), diff(poc$xedg))
    poc <- poc$poc
  }
  poc <- .sr_poc(poc)
  if (is.null(area)) .sr_stop("`area` must be given, one positive number per cell")
  area <- .sr_num(area, "area", scalar = FALSE, positive = TRUE)
  if (length(area) != length(poc)) .sr_stop("`area` must have one value per cell of `poc` (%d), got %d",
                                            length(poc), length(area))
  W <- .sr_num(W, "W", positive = TRUE)
  effort <- .sr_num(effort, "effort", min = 0)
  tol <- .sr_num(tol, "tol", positive = TRUE)
  r <- poc * W / area
  total <- function(lam) sum(ifelse(r / lam > 1, area / W * log(r / lam), 0))
  lo <- log(min(r[poc > 0])) - 50
  # ponytail: rmorie's floor, lowered only for an effort it cannot hold (average coverage above 50)
  while (total(exp(lo)) <= effort) lo <- lo - 50
  hi <- log(max(r))
  for (it in 1:400) {
    mid <- (lo + hi) / 2
    if (total(exp(mid)) > effort) lo <- mid else hi <- mid
    if (hi - lo < tol) break
  }
  lam <- exp((lo + hi) / 2)
  z <- ifelse(r / lam > 1, area / W * log(r / lam), 0)
  cov <- W * z / area
  pod <- 1 - exp(-cov)
  structure(c(list(effort = z, coverage = cov, pod = pod, pos = sum(poc * pod), lambda = lam, poc = poc,
                   W = W, total = effort), edges),
            class = "rmbl_opteffort")
}

# ---- print methods ---------------------------------------------------------------------------

#' @export
print.rmbl_ltrlrng <- function(x, ...) {
  d <- data.frame(range = attr(x, "x"), pod = signif(as.vector(unclass(x)), 6))
  .rmbl_print_table("Lateral range curve", utils::head(d, 20L),
                    notes = sprintf("%s model, sweep width W = %s%s%s", .sr_model_name(attr(x, "model")),
                                    format(attr(x, "W")),
                                    if (attr(x, "model") == "mbeta") sprintf(", m = %s", format(attr(x, "m"))) else "",
                                    if (isTRUE(attr(x, "navsd") > 0)) sprintf(", navigation error sd %s",
                                                                              format(attr(x, "navsd"))) else ""),
                    footer = if (nrow(d) > 20L) sprintf("... and %d more", nrow(d) - 20L), ...)
  invisible(x)
}

#' @export
print.rmbl_srchpod <- function(x, ...) {
  d <- data.frame(coverage = attr(x, "coverage"), pod = signif(as.vector(unclass(x)), 6))
  .rmbl_print_table("Probability of detection", utils::head(d, 20L),
                    notes = sprintf("%s model%s", .sr_model_name(attr(x, "model")),
                                    if (attr(x, "model") == "mbeta") sprintf(", M = %s", format(attr(x, "m"))) else ""),
                    footer = if (nrow(d) > 20L) sprintf("... and %d more", nrow(d) - 20L), ...)
  invisible(x)
}

#' @export
print.rmbl_srchscs <- function(x, ...) {
  d <- data.frame(area = seq_along(x$poc), poc = signif(x$poc, 4), cumpod = signif(x$cumpod, 4),
                  posarea = signif(x$posarea, 4), pocupd = signif(x$pocupd, 4))
  .rmbl_print_table("Probability of success", d,
                    notes = sprintf("POS %.4g after %d search%s", x$pos, x$nsrch, if (x$nsrch == 1L) "" else "es"),
                    ...)
  invisible(x)
}

#' @export
print.rmbl_datummap <- function(x, ...) {
  p <- x$poc
  xc <- x$xedg[-1] - diff(x$xedg) / 2
  yc <- x$yedg[-1] - diff(x$yedg) / 2
  o <- utils::head(order(p, decreasing = TRUE), 5L)
  d <- data.frame(x = xc[col(p)[o]], y = yc[row(p)[o]], poc = signif(p[o], 4))
  .rmbl_print_table(sprintf("Datum probability map (%s datum)", x$datum), d,
                    notes = c(sprintf("%d x %d cells (x by y); %.1f%% of the probability lies outside the grid",
                                      ncol(p), nrow(p), 100 * x$outside),
                              "The most likely cells:"), ...)
  invisible(x)
}

#' @export
print.rmbl_optcrc <- function(x, ...) {
  cat(.rmbl_rule("Optimal search of a circular normal datum"), "\n")
  cat(.rmbl_kv(list(sigma = x$sigma, W = x$W, effort = x$total, radius = signif(x$radius, 6),
                    pos = signif(x$pos, 6), cntrdns = signif(x$cntrdns, 6))), sep = "\n")
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' @export
print.rmbl_opteffort <- function(x, ...) {
  used <- which(as.vector(x$effort) > 0)
  o <- utils::head(used[order(as.vector(x$poc)[used], decreasing = TRUE)], 20L)
  d <- data.frame(cell = o, poc = signif(as.vector(x$poc)[o], 4), effort = signif(as.vector(x$effort)[o], 4),
                  coverage = signif(as.vector(x$coverage)[o], 4), pod = signif(as.vector(x$pod)[o], 4))
  .rmbl_print_table("Optimal allocation of effort", d,
                    notes = sprintf("POS %.4g from effort %s over %d of %d cells (W = %s)", x$pos, format(x$total),
                                    length(used), length(x$poc), format(x$W)),
                    footer = if (length(used) > 20L) sprintf("... and %d more cells", length(used) - 20L), ...)
  invisible(x)
}

# ---- plot methods ----------------------------------------------------------------------------

#' Draws lateral range curves on an open frame.
#'
#' The curve over `xs` (with its step edges kept sharp), optionally the dashed definite-range
#' rectangle of the same sweep width with the missed area A inside it and the detected area B
#' outside it shaded (Frost 1996, figure 4-7), or a second track at `spacing` with the combined
#' detection probability between them.
#' @param xs Lateral ranges.
#' @param W,model,m,navsd The curve.
#' @param cols Three colours.
#' @param equiv Whether to draw the equivalent definite-range rectangle and the A and B areas.
#' @param spacing NULL, or the distance to a second track.
#' @return A data frame of what was drawn.
#' @noRd
.sr_draw_lr <- function(xs, W, model, m, navsd, cols, equiv = FALSE, spacing = NULL) {
  if (model != "invcube" && navsd == 0) {
    r <- W / (2 * (if (model == "mbeta") m else 1))
    e <- c(-r, r, if (!is.null(spacing)) spacing + c(-r, r))
    xs <- sort(unique(c(xs, e, e - 1e-9 * W, e + 1e-9 * W)))
  }
  p <- .sr_lr_nav(xs, W, model, m, navsd)
  if (equiv) {
    # Frost's figure 4-7: A, missed inside the sweep width (light), B, seen outside it (dark)
    inn <- abs(xs) <= W / 2
    graphics::polygon(c(xs[inn], rev(xs[inn])), c(p[inn], rep(1, sum(inn))), col = "#E3E3E3", border = NA)
    for (o in list(xs < -W / 2, xs > W / 2)) {
      graphics::polygon(c(xs[o], rev(xs[o])), c(p[o], rep(0, sum(o))), col = "#9A9A9A", border = NA)
    }
    graphics::rect(-W / 2, 0, W / 2, 1, border = "#3D4350", lty = 2)
    ax <- c(-0.38, 0.38) * W
    graphics::text(ax, 0.86, "A", font = 2, col = "#1F2430")
    graphics::text(c(-0.62, 0.62) * W, 0.07, "B", font = 2, col = "#1F2430")
    graphics::arrows(c(-0.3, 0.3) * W, 0.2, c(-0.5, 0.5) * W, 0.2, length = 0.07)
    graphics::text(0, 0.2, "SWEEP WIDTH", cex = 0.7)
    graphics::text(0, 1.11, "Missed within the sweep width (A)", cex = 0.75, xpd = NA)
    graphics::arrows(c(-0.3, 0.3) * W, 1.08, ax, 0.9, length = 0.06, xpd = NA)
  }
  if (is.null(spacing)) {
    .bl_line(xs, p, cols[1L], label = FALSE, points = FALSE)
    return(data.frame(x = xs, p = p))
  }
  p2 <- .sr_lr_nav(xs - spacing, W, model, m, navsd)
  pod <- 1 - (1 - p) * (1 - p2)
  graphics::polygon(c(xs[1L], xs, xs[length(xs)]), c(0, pod, 0), col = grDevices::adjustcolor(cols[3L], 0.25),
                    border = NA)
  graphics::lines(xs, p, col = cols[1L], lwd = 2.4)
  graphics::lines(xs, p2, col = cols[2L], lwd = 2.4, lty = 2)
  graphics::abline(v = c(0, spacing), col = "#8C8C8C", lty = 3)
  data.frame(x = xs, p = p, p2 = p2, pod = pod)
}

#' @rdname plot-methods
#' @param equiv Whether to draw the equivalent definite-range rectangle and the A and B areas
#'   (figure 4-7 of the book).
#' @param spacing NULL, or the distance to a second track, drawn beside the first.
#' @usage \method{plot}{rmbl_ltrlrng}(x, ..., equiv = FALSE, spacing = NULL,
#'   main = NULL, col = NULL, palette = NULL)
#' @export
plot.rmbl_ltrlrng <- function(x, ..., equiv = FALSE, spacing = NULL, main = NULL, col = NULL, palette = NULL) {
  if (!is.numeric(x) || is.null(attr(x, "W"))) .sr_stop("`x` must be an rmbl_ltrlrng object, as ltrlrng() returns")
  W <- attr(x, "W")
  model <- attr(x, "model")
  m <- attr(x, "m")
  navsd <- attr(x, "navsd") %||% 0
  if (!is.null(spacing)) spacing <- .sr_num(spacing, "spacing", positive = TRUE)
  lim <- max(2 * W, 1.25 * W / (2 * (if (model == "mbeta") m else 1)), abs(attr(x, "x"))) + 3 * navsd
  xs <- seq(-lim, lim + (spacing %||% 0), length.out = 801)
  cols <- .bl_cols(3, col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(range(xs), c(0, if (isTRUE(equiv)) 1.13 else 1.05), type = "n", xlab = "", ylab = "", main = "",
                 ...)
  .bl_ylab("Probability of detection")
  .bl_xlab(if (isTRUE(equiv)) "Lateral range (B: detected outside the sweep width)" else
    "Lateral range (distance from the track)")
  .bl_title(.bl_main(main, sprintf("Lateral range curve, %s, W = %s%s", .sr_model_name(model), format(W),
                                   if (navsd > 0) sprintf(", navigation error %s", format(navsd)) else "")))
  .bl_grid(NULL)
  if (!equiv && is.null(spacing)) graphics::abline(v = c(-W, W) / 2, col = "#8C8C8C", lty = 2)
  d <- .sr_draw_lr(xs, W, model, m, navsd, cols, equiv = isTRUE(equiv), spacing = spacing)
  if (is.null(spacing)) {
    graphics::points(attr(x, "x"), as.vector(unclass(x)), pch = 21, bg = cols[2L], col = "white", lwd = 1.5, cex = 1.4)
  }
  invisible(d)
}

#' Draws POD-by-coverage curves on an open frame.
#' @param cs Coverages.
#' @param models Model codes.
#' @param ms M-Beta heights, one curve each when \code{"mbeta"} is among the models.
#' @param cols Colours, one per curve.
#' @return A data frame of the curves: model, m, coverage, pod.
#' @noRd
.sr_draw_pod <- function(cs, models, ms, cols) {
  spec <- do.call(rbind, lapply(models, function(md) {
    data.frame(model = md, m = if (md == "mbeta") ms else NA_real_)
  }))
  cs <- sort(unique(c(cs, ms[ms <= max(cs)])))
  d <- do.call(rbind, lapply(seq_len(nrow(spec)), function(k) {
    data.frame(model = spec$model[k], m = spec$m[k], coverage = cs,
               pod = .sr_pod(cs, spec$model[k], if (is.na(spec$m[k])) 1 else spec$m[k]))
  }))
  cols <- rep_len(cols, nrow(spec))
  for (k in rev(seq_len(nrow(spec)))) {
    s <- d[d$model == spec$model[k] & (is.na(d$m) | d$m %in% spec$m[k]), ]
    if (k == 1L) {
      .bl_line(s$coverage, s$pod, cols[1L], label = FALSE, points = FALSE)
    } else {
      graphics::lines(s$coverage, s$pod, col = cols[k], lwd = 2, lty = 1 + (k - 1L) %% 5L)
    }
  }
  lab <- ifelse(spec$model == "mbeta", sprintf("M-Beta (M = %s)", as.character(spec$m)),
                vapply(spec$model, .sr_model_name, ""))
  graphics::legend("bottomright", legend = lab, col = cols, lwd = c(2.4, rep(2, nrow(spec) - 1L)),
                   lty = c(1, 1 + seq_len(nrow(spec) - 1L) %% 5L), bty = "n", cex = 0.8, inset = 0.02)
  d
}

#' @rdname plot-methods
#' @param models Model codes (\code{"random"}, \code{"definite"}, \code{"invcube"},
#'   \code{"mbeta"}), one curve each; NULL
#'   draws the fitted model.
#' @param m M-Beta heights, one curve each when \code{"mbeta"} is among the models.
#' @param cmax The largest coverage drawn.
#' @usage \method{plot}{rmbl_srchpod}(x, ..., models = NULL, m = NULL, cmax = NULL,
#'   main = NULL, col = NULL, palette = NULL)
#' @export
plot.rmbl_srchpod <- function(x, ..., models = NULL, m = NULL, cmax = NULL, main = NULL, col = NULL,
                              palette = NULL) {
  if (!is.numeric(x) || is.null(attr(x, "coverage"))) {
    .sr_stop("`x` must be an rmbl_srchpod object, as srchpod() returns")
  }
  cv <- attr(x, "coverage")
  mod <- attr(x, "model")
  m0 <- attr(x, "m") %||% 1
  if (is.null(models)) models <- c(mod, setdiff(c("random", "definite", "invcube"), mod))
  models <- .rmbl_arg(models, c("random", "definite", "invcube", "mbeta"), several = TRUE)
  ms <- if (is.null(m)) m0 else .sr_num(m, "m", scalar = FALSE, positive = TRUE, min = 0, max = 1)
  cmax <- if (is.null(cmax)) max(2, 1.1 * cv) else .sr_num(cmax, "cmax", positive = TRUE)
  cols <- .bl_cols(length(models) + length(ms), col, palette)
  op <- .bl_par(c(0, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(c(0, cmax), c(0, 1.05), type = "n", xlab = "", ylab = "", main = "", ...)
  .bl_ylab("Probability of detection")
  .bl_xlab("Coverage")
  .bl_title(.bl_main(main, "Probability of detection by coverage"))
  .bl_grid(NULL)
  d <- .sr_draw_pod(seq(0, cmax, length.out = 201), models, ms, cols)
  if (mod %in% models) {
    graphics::points(cv, .sr_pod(cv, mod, m0), pch = 21, bg = cols[match(mod, models)], col = "white", lwd = 1.5,
                     cex = 1.4)
  }
  invisible(d)
}

#' Cell centres of a map.
#' @param e Cell edges.
#' @return The centres.
#' @noRd
.sr_mid <- function(e) e[-1L] - diff(e) / 2

#' Draws a datum map as an image with contours and the datum marked, on a new frame.
#' @param x An rmbl_datummap.
#' @param contours The number of contour levels.
#' @param cols The image colours.
#' @param ... Arguments to image().
#' @return NULL, invisibly.
#' @noRd
.sr_draw_map <- function(x, contours, cols, ...) {
  xc <- .sr_mid(x$xedg)
  yc <- .sr_mid(x$yedg)
  z <- t(x$poc)
  graphics::image(x$xedg, x$yedg, z, col = cols, xlab = "x", ylab = "", main = "", ...)
  .bl_ylab("y")
  if (contours > 0 && length(xc) > 1L && length(yc) > 1L && diff(range(z)) > 0) {
    graphics::contour(xc, yc, z, nlevels = contours, add = TRUE, col = "#333333", labcex = 0.7)
  }
  mark <- "#D55E00"
  switch(x$datum,
    point = graphics::points(x$center[1], x$center[2], pch = 3, cex = 1.6, lwd = 2, col = mark),
    line = , corridor = graphics::segments(x$center[1], x$center[2], x$end[1], x$end[2], lwd = 2.4, col = mark),
    area = graphics::rect(x$center[1], x$center[2], x$end[1], x$end[2], lwd = 2, border = mark),
    general = NULL
  )
  invisible(NULL)
}

#' The book's height bands: blue base, maroon, yellow, cyan, purple, salmon, steel blue, lavender top.
#' @return Eight colours, low to high.
#' @noRd
.sr_bands <- function() c("#7B7BEE", "#6B1F4F", "#FFFFB3", "#A6DCE0", "#4B0E7E", "#F0897A", "#3E7DB6", "#C9C9F2")

#' The band of each value: the lowest band below 6% of the peak, seven equal bands above it.
#' @param v Densities.
#' @param top The peak density.
#' @param n The number of colours.
#' @return Band numbers from 1 to n.
#' @noRd
.sr_band_of <- function(v, top, n) {
  pmin(n, findInterval(v / top, c(-Inf, 0.06 + (0:(n - 2)) * 0.94 / (n - 1))))
}

#' A datum map's density on its cell centres (rows x cells, columns y cells).
#' @param x An rmbl_datummap.
#' @return A matrix.
#' @noRd
.sr_density <- function(x) t(x$poc / outer(diff(x$yedg), diff(x$xedg)))

#' Draws a datum map's probability density as a surface banded by height, mesh drawn.
#' @param x An rmbl_datummap.
#' @param cols The band colours, low to high.
#' @return The density matrix, invisibly.
#' @noRd
.sr_draw_persp <- function(x, cols) {
  dens <- .sr_density(x)
  nx <- nrow(dens)
  ny <- ncol(dens)
  if (nx < 2L || ny < 2L) .sr_stop("a surface needs at least two cells in x and in y")
  mid <- (dens[-1L, -1L] + dens[-nx, -1L] + dens[-1L, -ny] + dens[-nx, -ny]) / 4
  k <- .sr_band_of(mid, max(dens), length(cols))
  graphics::persp(.sr_mid(x$xedg), .sr_mid(x$yedg), dens, theta = -35, phi = 28, expand = 0.6,
                  col = cols[k], border = if (nx * ny <= 6400L) "#1F2430" else NA, lwd = 0.3, box = FALSE,
                  zlim = c(0, 1.05 * max(dens)))
  invisible(dens)
}

#' Draws the top view of a datum map: its cells coloured by the same height bands, mesh drawn.
#' @param x An rmbl_datummap.
#' @param cols The band colours, low to high.
#' @return NULL, invisibly.
#' @noRd
.sr_draw_top <- function(x, cols) {
  dens <- .sr_density(x)
  k <- matrix(.sr_band_of(dens, max(dens), length(cols)), nrow(dens))
  graphics::image(x$xedg, x$yedg, k, col = cols, breaks = seq_len(length(cols) + 1L) - 0.5, axes = FALSE,
                  xlab = "", ylab = "", main = "", asp = 1)
  if (length(dens) <= 6400L) {
    graphics::segments(x$xedg, min(x$yedg), x$xedg, max(x$yedg), col = "#1F2430", lwd = 0.3)
    graphics::segments(min(x$xedg), x$yedg, max(x$xedg), x$yedg, col = "#1F2430", lwd = 0.3)
  }
  graphics::rect(min(x$xedg), min(x$yedg), max(x$xedg), max(x$yedg), border = "#1F2430")
  invisible(NULL)
}

#' Draws a datum map as its cells with their probabilities written in them, on a new frame.
#'
#' The text is sized to the cells (never wider than 80% of one); a corridor datum's line is drawn with
#' its label, and the values of the cells it crosses are set below it.
#' @param x An rmbl_datummap.
#' @param digits Decimal places of the percentages.
#' @param shade NULL, or the row and column of a cell to shade.
#' @param circle NULL, or c(x, y, radius) of a dashed circle, its radius marked \code{"E"}.
#' @return The text size used, invisibly.
#' @noRd
.sr_draw_cells <- function(x, digits, shade = NULL, circle = NULL) {
  graphics::plot(range(x$xedg), range(x$yedg), type = "n", asp = 1, axes = FALSE, xlab = "", ylab = "", main = "")
  ny <- nrow(x$poc)
  nx <- ncol(x$poc)
  if (!is.null(shade)) {
    graphics::rect(x$xedg[shade[2]], x$yedg[shade[1]], x$xedg[shade[2] + 1L], x$yedg[shade[1] + 1L], col = "#D9D9D9",
                   border = NA)
  }
  lab <- sprintf(paste0("%.", digits, "f%%"), 100 * as.vector(x$poc))
  cw <- min(diff(x$xedg))
  ch <- min(diff(x$yedg))
  cex <- min(1.2, 0.8 * cw / max(graphics::strwidth(lab, cex = 1)), 0.45 * ch / graphics::strheight("0", cex = 1))
  yt <- rep(.sr_mid(x$yedg), nx)
  line <- if (x$datum == "corridor") x$center[2] else NA_real_
  if (!is.na(line) && x$center[2] == x$end[2]) {
    on <- rep(x$yedg[-(ny + 1L)] < line & x$yedg[-1L] > line, nx)
    yt[on] <- (line + rep(x$yedg[-(ny + 1L)], nx)[on]) / 2
    graphics::segments(min(x$xedg), line, max(x$xedg), line, lwd = 2)
    graphics::arrows(min(x$xedg) - 0.6 * cw, line, min(x$xedg), line, length = 0.06, xpd = NA)
    graphics::text(min(x$xedg) - 0.6 * cw, line, "Datum\nline", pos = 2, cex = 0.8 * cex, xpd = NA)
  }
  graphics::rect(rep(x$xedg[-(nx + 1L)], each = ny), rep(x$yedg[-(ny + 1L)], nx), rep(x$xedg[-1L], each = ny),
                 rep(x$yedg[-1L], nx), border = "#1F2430", lwd = 2)
  graphics::text(rep(.sr_mid(x$xedg), each = ny), yt, lab, cex = cex, col = "#1F2430")
  if (!is.null(circle)) {
    a <- seq(0, 2 * pi, length.out = 181)
    graphics::lines(circle[1] + circle[3] * cos(a), circle[2] + circle[3] * sin(a), lty = 2, col = "#1F2430")
    graphics::arrows(circle[1], circle[2], circle[1] + circle[3] * cos(-pi / 4), circle[2] + circle[3] * sin(-pi / 4),
                     length = 0.05)
    graphics::text(circle[1] + 0.35 * circle[3], circle[2] - 0.55 * circle[3], "E", font = 3, cex = cex)
  }
  invisible(cex)
}

#' @rdname plot-methods
#' @param view \code{"map"} (the top view), \code{"persp"} (the surface),
#'   \code{"both"} (side by side,
#'   in the book's colour bands) or \code{"cells"} (the probability map as a grid of
#'   percentages).
#' @param digits Decimal places of the percentages in the \code{"cells"} view.
#' @usage \method{plot}{rmbl_datummap}(x, ..., view = c("map", "persp", "both", "cells"),
#'   contours = 8L, digits = 2, main = NULL, col = NULL, palette = NULL)
#' @export
plot.rmbl_datummap <- function(x, ..., view = c("map", "persp", "both", "cells"), contours = 8L, digits = 2,
                               main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_datummap")
  view <- .rmbl_arg(view)
  digits <- .sr_num(digits, "digits", min = 0, max = 6, whole = TRUE)
  cols <- if (!is.null(col)) .bl_cols(length(col), col) else blpal(palette %||% "sequential", 64)
  # the surface and its top view take the book's height bands unless colours are given
  bands <- if (is.null(col) && is.null(palette)) .sr_bands() else cols
  op <- .bl_par(x$yedg)
  on.exit(graphics::par(op), add = TRUE)
  ttl <- .bl_main(main, sprintf("Probability of containment, %s datum", .sr_model_name(x$datum)))
  # "both" takes the device as two panels, unless the caller set a layout: then the next two of its panels
  own <- view == "both" && prod(graphics::par("mfrow")) == 1L
  if (own) {
    op2 <- graphics::par(mfrow = c(1L, 2L), oma = c(0, 0, 1.8, 0))
    on.exit(graphics::par(op2), add = TRUE)
  }
  if (view %in% c("persp", "both")) {
    .sr_draw_persp(x, bands)
    .bl_title(if (view == "both") "Probability density" else ttl)
  }
  if (view == "both") {
    .sr_draw_top(x, bands)
    .bl_title("Top view")
  }
  if (view == "map") {
    .sr_draw_map(x, contours, cols, ...)
    .bl_title(ttl)
  }
  if (view == "cells") {
    .sr_draw_cells(x, digits)
    .bl_title(ttl)
  }
  if (own) graphics::mtext(ttl, side = 3, outer = TRUE, font = 2, line = 0.3, col = "#1F2430")
  xc <- .sr_mid(x$xedg)
  yc <- .sr_mid(x$yedg)
  invisible(data.frame(x = rep(xc, times = length(yc)), y = rep(yc, each = length(xc)), poc = as.vector(t(x$poc))))
}

#' @rdname plot-methods
#' @export
plot.rmbl_opteffort <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_opteffort")
  ttl <- .bl_main(main, sprintf("Optimal effort, POS %.3f", x$pos))
  if (!is.null(x$xedg)) {
    xc <- .sr_mid(x$xedg)
    yc <- .sr_mid(x$yedg)
    z <- t(matrix(x$effort, length(yc), length(xc)))
    cols <- if (!is.null(col)) .bl_cols(length(col), col) else blpal(palette %||% "sequential", 64)
    op <- .bl_par(yc)
    on.exit(graphics::par(op), add = TRUE)
    graphics::image(x$xedg, x$yedg, z, col = c("#F4F5F7", cols), xlab = "x", ylab = "", main = "", ...)
    .bl_title(ttl)
    .bl_ylab("y")
    if (length(xc) > 1L && length(yc) > 1L && any(z > 0)) {
      graphics::contour(xc, yc, z, levels = max(z) * 1e-9, drawlabels = FALSE, add = TRUE, col = "#D55E00", lwd = 2)
    }
    return(invisible(data.frame(x = rep(xc, times = length(yc)), y = rep(yc, each = length(xc)),
                                effort = as.vector(z))))
  }
  e <- as.vector(x$effort)
  lab <- names(x$poc) %||% as.character(seq_along(e))
  cols <- .bl_cols(1, col, palette)
  op <- .bl_par(e)
  on.exit(graphics::par(op), add = TRUE)
  .bl_barplot(e, names.arg = lab, col = cols, xlab = "", ylab = "", main = "", ...)
  .bl_title(ttl)
  .bl_ylab("Effort (track length)")
  .bl_xlab("Cell")
  invisible(data.frame(cell = lab, effort = e, pod = as.vector(x$pod)))
}
