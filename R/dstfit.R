# SPDX-License-Identifier: AGPL-3.0-or-later
# Candidate distributions for one numeric column, fitted by maximum likelihood in base R and ranked
# by AIC, with goodness-of-fit statistics, bootstrap intervals and a Hill tail-index estimate.

#' The candidate families: their checks, maximum likelihood fits and d/p/q/r functions.
#'
#' Each entry has `disc` (a count family), `need` (what the data must be,
#' in words), `ok` (whether the data are), `fit` (the estimates, named),
#' `d` (the log density or mass), `p`, `q` and `r`. The
#' families without a closed-form estimate are fitted by optim() on an unbounded scale.
#' @return A named list of families.
#' @noRd
.dst_fams <- function() {
  pos <- function(x) all(x > 0)
  cnt <- function(x) all(x >= 0 & x == round(x))
  ml <- function(nll, start, back) {
    o <- stats::optim(start, nll, method = "Nelder-Mead", control = list(maxit = 4000L, reltol = 1e-12))
    o <- stats::optim(o$par, nll, method = "BFGS", control = list(maxit = 500L, reltol = 1e-14))
    back(o$par)
  }
  lg <- function(p) log(p / (1 - p))
  il <- function(z) 1 / (1 + exp(-z))
  dzip <- function(x, p) {
    ifelse(x == 0, log(p[[1L]] + (1 - p[[1L]]) * stats::dpois(0, p[[2L]])),
           log(1 - p[[1L]]) + stats::dpois(x, p[[2L]], log = TRUE))
  }
  dzinb <- function(x, p) {
    ifelse(x == 0, log(p[[1L]] + (1 - p[[1L]]) * stats::dnbinom(0, size = p[[2L]], mu = p[[3L]])),
           log(1 - p[[1L]]) + stats::dnbinom(x, size = p[[2L]], mu = p[[3L]], log = TRUE))
  }
  p0 <- function(x) min(max(mean(x == 0) - stats::dpois(0, mean(x)), 0.05), 0.9)
  list(
    normal = list(disc = FALSE, need = "numbers", ok = function(x) TRUE,
      fit = function(x) c(mean = mean(x), sd = sqrt(mean((x - mean(x))^2))),
      d = function(x, p) stats::dnorm(x, p[[1L]], p[[2L]], log = TRUE),
      p = function(q, p) stats::pnorm(q, p[[1L]], p[[2L]]), q = function(u, p) stats::qnorm(u, p[[1L]], p[[2L]]),
      r = function(n, p) stats::rnorm(n, p[[1L]], p[[2L]])),
    lognormal = list(disc = FALSE, need = "every value above 0", ok = pos,
      fit = function(x) c(meanlog = mean(log(x)), sdlog = sqrt(mean((log(x) - mean(log(x)))^2))),
      d = function(x, p) stats::dlnorm(x, p[[1L]], p[[2L]], log = TRUE),
      p = function(q, p) stats::plnorm(q, p[[1L]], p[[2L]]), q = function(u, p) stats::qlnorm(u, p[[1L]], p[[2L]]),
      r = function(n, p) stats::rlnorm(n, p[[1L]], p[[2L]])),
    exponential = list(disc = FALSE, need = "no value below 0", ok = function(x) all(x >= 0),
      fit = function(x) c(rate = 1 / mean(x)),
      d = function(x, p) stats::dexp(x, p[[1L]], log = TRUE),
      p = function(q, p) stats::pexp(q, p[[1L]]), q = function(u, p) stats::qexp(u, p[[1L]]),
      r = function(n, p) stats::rexp(n, p[[1L]])),
    gamma = list(disc = FALSE, need = "every value above 0", ok = pos,
      fit = function(x) {
        m <- mean(x)
        v <- mean((x - m)^2)
        ml(function(z) -sum(stats::dgamma(x, exp(z[[1L]]), exp(z[[2L]]), log = TRUE)), log(c(m^2 / v, m / v)),
           function(z) c(shape = exp(z[[1L]]), rate = exp(z[[2L]])))
      },
      d = function(x, p) stats::dgamma(x, p[[1L]], p[[2L]], log = TRUE),
      p = function(q, p) stats::pgamma(q, p[[1L]], p[[2L]]), q = function(u, p) stats::qgamma(u, p[[1L]], p[[2L]]),
      r = function(n, p) stats::rgamma(n, p[[1L]], p[[2L]])),
    weibull = list(disc = FALSE, need = "every value above 0", ok = pos,
      fit = function(x) {
        ml(function(z) -sum(stats::dweibull(x, exp(z[[1L]]), exp(z[[2L]]), log = TRUE)), c(log(1.2), log(mean(x))),
           function(z) c(shape = exp(z[[1L]]), scale = exp(z[[2L]])))
      },
      d = function(x, p) stats::dweibull(x, p[[1L]], p[[2L]], log = TRUE),
      p = function(q, p) stats::pweibull(q, p[[1L]], p[[2L]]), q = function(u, p) stats::qweibull(u, p[[1L]], p[[2L]]),
      r = function(n, p) stats::rweibull(n, p[[1L]], p[[2L]])),
    t = list(disc = FALSE, need = "numbers", ok = function(x) TRUE,
      fit = function(x) {
        s0 <- max(stats::mad(x), stats::sd(x) / 10)
        ml(function(z) -sum(stats::dt((x - z[[1L]]) / exp(z[[2L]]), exp(z[[3L]]), log = TRUE) - z[[2L]]),
           c(stats::median(x), log(s0), log(5)),
           function(z) c(location = z[[1L]], scale = exp(z[[2L]]), df = exp(z[[3L]])))
      },
      d = function(x, p) stats::dt((x - p[[1L]]) / p[[2L]], p[[3L]], log = TRUE) - log(p[[2L]]),
      p = function(q, p) stats::pt((q - p[[1L]]) / p[[2L]], p[[3L]]),
      q = function(u, p) p[[1L]] + p[[2L]] * stats::qt(u, p[[3L]]),
      r = function(n, p) p[[1L]] + p[[2L]] * stats::rt(n, p[[3L]])),
    pareto = list(disc = FALSE, need = "every value above 0", ok = pos,
      fit = function(x) c(xmin = min(x), alpha = length(x) / sum(log(x / min(x)))),
      d = function(x, p) ifelse(x >= p[[1L]], log(p[[2L]]) + p[[2L]] * log(p[[1L]]) - (p[[2L]] + 1) * log(x), -Inf),
      p = function(q, p) ifelse(q < p[[1L]], 0, 1 - (p[[1L]] / q)^p[[2L]]),
      q = function(u, p) p[[1L]] * (1 - u)^(-1 / p[[2L]]),
      r = function(n, p) p[[1L]] * stats::runif(n)^(-1 / p[[2L]])),
    beta = list(disc = FALSE, need = "every value between 0 and 1, exclusive", ok = function(x) all(x > 0 & x < 1),
      fit = function(x) {
        m <- mean(x)
        v <- mean((x - m)^2)
        k <- max(m * (1 - m) / v - 1, 0.1)
        ml(function(z) -sum(stats::dbeta(x, exp(z[[1L]]), exp(z[[2L]]), log = TRUE)), log(c(m * k, (1 - m) * k)),
           function(z) c(shape1 = exp(z[[1L]]), shape2 = exp(z[[2L]])))
      },
      d = function(x, p) stats::dbeta(x, p[[1L]], p[[2L]], log = TRUE),
      p = function(q, p) stats::pbeta(q, p[[1L]], p[[2L]]), q = function(u, p) stats::qbeta(u, p[[1L]], p[[2L]]),
      r = function(n, p) stats::rbeta(n, p[[1L]], p[[2L]])),
    poisson = list(disc = TRUE, need = "counts (whole numbers, 0 or more)", ok = cnt,
      fit = function(x) c(lambda = mean(x)),
      d = function(x, p) stats::dpois(x, p[[1L]], log = TRUE),
      p = function(q, p) stats::ppois(q, p[[1L]]), q = function(u, p) stats::qpois(u, p[[1L]]),
      r = function(n, p) stats::rpois(n, p[[1L]])),
    negbin = list(disc = TRUE, need = "counts (whole numbers, 0 or more)", ok = cnt,
      fit = function(x) {
        # the estimate of mu is the mean whatever the size, so the size is a one-dimensional search
        m <- mean(x)
        o <- stats::optimize(function(z) -sum(stats::dnbinom(x, size = exp(z), mu = m, log = TRUE)), c(-10, 15))
        c(size = exp(o$minimum), mu = m)
      },
      d = function(x, p) stats::dnbinom(x, size = p[[1L]], mu = p[[2L]], log = TRUE),
      p = function(q, p) stats::pnbinom(q, size = p[[1L]], mu = p[[2L]]),
      q = function(u, p) stats::qnbinom(u, size = p[[1L]], mu = p[[2L]]),
      r = function(n, p) stats::rnbinom(n, size = p[[1L]], mu = p[[2L]])),
    zip = list(disc = TRUE, need = "counts with at least one zero", ok = function(x) cnt(x) && any(x == 0),
      fit = function(x) {
        ml(function(z) -sum(dzip(x, c(il(z[[1L]]), exp(z[[2L]])))), c(lg(p0(x)), log(max(mean(x[x > 0]), 0.1))),
           function(z) c(pi = il(z[[1L]]), lambda = exp(z[[2L]])))
      },
      d = dzip,
      p = function(q, p) ifelse(q < 0, 0, p[[1L]] + (1 - p[[1L]]) * stats::ppois(q, p[[2L]])),
      q = function(u, p) ifelse(u <= p[[1L]], 0, stats::qpois(pmax(0, (u - p[[1L]]) / (1 - p[[1L]])), p[[2L]])),
      r = function(n, p) ifelse(stats::runif(n) < p[[1L]], 0, stats::rpois(n, p[[2L]]))),
    zinb = list(disc = TRUE, need = "counts with at least one zero", ok = function(x) cnt(x) && any(x == 0),
      fit = function(x) {
        ml(function(z) -sum(dzinb(x, c(il(z[[1L]]), exp(z[[2L]]), exp(z[[3L]])))),
           c(lg(p0(x)), 0, log(max(mean(x[x > 0]), 0.1))),
           function(z) c(pi = il(z[[1L]]), size = exp(z[[2L]]), mu = exp(z[[3L]])))
      },
      d = dzinb,
      p = function(q, p) ifelse(q < 0, 0, p[[1L]] + (1 - p[[1L]]) * stats::pnbinom(q, size = p[[2L]], mu = p[[3L]])),
      q = function(u, p) {
        ifelse(u <= p[[1L]], 0, stats::qnbinom(pmax(0, (u - p[[1L]]) / (1 - p[[1L]])), size = p[[2L]], mu = p[[3L]]))
      },
      r = function(n, p) ifelse(stats::runif(n) < p[[1L]], 0, stats::rnbinom(n, size = p[[2L]], mu = p[[3L]])))
  )
}

#' The goodness-of-fit statistics of one fitted family.
#'
#' Kolmogorov-Smirnov: for a continuous family the largest gap between the empirical
#' and fitted distribution functions on either side of each value; for a count family
#' the largest gap over the support 0 to max(x). Anderson-Darling: continuous families
#' only (NA for counts).
#' @param x The data, sorted.
#' @param f The family.
#' @param p The estimates.
#' @return A named numeric vector: ks and ad.
#' @noRd
.dst_gof <- function(x, f, p) {
  n <- length(x)
  if (f$disc) {
    k <- 0:max(x)
    return(c(ks = max(abs(stats::ecdf(x)(k) - f$p(k, p))), ad = NA_real_))
  }
  u <- pmin(pmax(f$p(x, p), 1e-300), 1 - 1e-16)
  i <- seq_len(n)
  c(ks = max(i / n - u, u - (i - 1) / n),
    ad = -n - mean((2 * i - 1) * (log(u) + log(1 - rev(u)))))
}

#' Fits one family, NULL when the optimiser fails or the likelihood is not finite.
#' @param f The family.
#' @param x The data.
#' @return The estimates, or NULL.
#' @noRd
.dst_fit1 <- function(f, x) {
  p <- tryCatch(suppressWarnings(f$fit(x)), error = function(e) NULL)
  if (is.null(p) || !all(is.finite(p)) || !is.finite(sum(f$d(x, p)))) NULL else p
}

#' Fit and rank candidate distributions
#'
#' Fits candidate distributions to one numeric variable by maximum likelihood, ranks
#' them by AIC, and reports for each the BIC, a Kolmogorov-Smirnov distance, an
#' Anderson-Darling statistic and percentile bootstrap intervals for its parameters. A
#' Hill estimate of the tail index is added for positive data. Everything is base R.
#'
#' @details The families and their parameters: `normal` (`mean`, `sd`),
#'   `lognormal` (`meanlog`, `sdlog`), `exponential` (rate), `gamma`
#'   (shape, rate), `weibull` (shape, scale), `t` (location, scale, df: a
#'   location-scale Student t), `pareto` (`xmin`, `alpha`,
#'   with `xmin` the smallest
#'   value, its maximum likelihood estimate), `beta` (shape1, shape2) for
#'   proportions, and for counts `poisson` (lambda), `negbin` (size, mu),
#'   `zip` (pi, lambda) and `zinb` (pi, size, mu), the zero-inflated
#'   forms with `pi` the share of structural zeros. The normal, lognormal,
#'   exponential, Pareto and Poisson estimates are closed form; the negative binomial
#'   searches its size alone (its mu estimate is the mean); the rest are maximised by
#'   `optim()` on a log or logit scale, Nelder-Mead then BFGS.
#'
#' With `fams = NULL` every family the data allow is fitted: for whole numbers
#' of 0 or more the count families; otherwise the positive families for values above 0
#' (`exponential` for values of 0 or more) and `beta` for values strictly
#' between 0 and 1; and `normal` and `t` always. A family named in
#' `fams` that the data do not allow is refused. A fit that fails (the optimiser
#' stops at a non-finite likelihood) is a row with `converged = FALSE` and no
#' statistics.
#'
#' AIC is \eqn{2k - 2\ell} and BIC \eqn{k \log n - 2\ell}. The Kolmogorov-Smirnov and
#' Anderson-Darling statistics use the fitted parameters, so their usual null
#' distributions do not apply; they rank fits, they are not tests. The bootstrap
#' resamples the data `nboot` times and refits; the interval is the percentile
#' interval at `conflvl`. The Hill estimator uses the `k` largest values
#' (default \eqn{\lfloor\sqrt n\rfloor}): \eqn{\hat\alpha = k / \sum_{i \le k}
#' \log(x_{(n-i+1)} / x_{(n-k)})}, with the asymptotic interval \eqn{\hat\alpha (1 \pm
#' z / \sqrt k)}.
#'
#' Missing values are dropped and counted (`nmiss`). Errors: `x` not
#' numeric, an infinite value, fewer than five values, all values equal, an unknown
#' family or one the data do not allow. The bootstrap is seeded with `seed` for
#' this call only; the session's random stream is left as it was.
#'
#' @param x Numeric vector, the variable.
#' @param fams Character vector of families (see Details), or `NULL` for every
#'   family the data allow.
#' @param nboot Whole number, default 200: bootstrap resamples (0 for none).
#' @param conflvl Number in (0, 1), default 0.95: the bootstrap and Hill interval
#'   level.
#' @param seed Whole number, default 1: the seed of the bootstrap.
#' @param k Whole number or `NULL`: the upper order statistics of the Hill
#'   estimate.
#' @param ... For `print()` and `plot()`: see
#'   [plot.rmbl_dstfit()].
#' @return A list of class `c("rmbl_dstfit", "list")`:
#'   \describe{
#'     \item{`table`}{data frame, one row per family ranked by AIC:
#'       `rank`, `family`, `npar`, `loglik`, `aic`,
#'       `bic`, `ks`, `ad`, `converged` and `params`
#'       (the estimates as text).}
#'     \item{`fits`}{named list of the estimates (named numeric vectors) of the
#'       converged fits.}
#'     \item{`boot`}{data frame: `family`, `param`,
#'       `estimate`, `lower`, `upper` (`NA` without a
#'       bootstrap).}
#'     \item{`hill`}{list: `k`, `alpha`, `lower`,
#'       `upper`, or `NULL` for data that are not all positive or fewer
#'       than ten values.}
#'     \item{`x`, `nmiss`, `discrete`, `conflvl`}{the data
#'       used, the count dropped, whether the data are counts, and the level.}
#'   }
#' @seealso [plot.rmbl_dstfit()] for the density, QQ, PP
#'   and tail plots; [mksyncol()] with `type = "fitted"`
#'   for a synthetic sample from a fit.
#' @references Hill BM (1975). A simple general approach to inference about the tail of
#'   a distribution. \emph{Annals of Statistics} 3, 1163--1174.
#'   \doi{10.1214/aos/1176343247}
#'
#' Anderson TW, Darling DA (1954). A test of goodness of fit. \emph{JASA} 49, 765--769.
#' \doi{10.1080/01621459.1954.10501232}
#' @examples
#' set.seed(1)
#' x <- stats::rgamma(300, shape = 2, rate = 0.5)
#' f <- dstfit(x, nboot = 50)
#' f
#' f$fits$gamma
#'
#' # counts with extra zeros
#' n <- ifelse(stats::runif(300) < 0.3, 0, stats::rpois(300, 4))
#' dstfit(n, nboot = 0)$table[, c("family", "aic")]
#'
#' # a family the data do not allow
#' try(dstfit(c(-1, 2, 3, 4, 5), fams = "gamma"))
#' @export
#' @srrstats {G2.1} `x` is checked to be numeric and finite, and `fams` against the families the data allow.
#' @srrstats {G2.13} Missing values are dropped and their count returned as `nmiss`.
#' @srrstats {G5.6} test-dstfit.R recovers the parameters of seeded gamma, Weibull, negative binomial and
#'   zero-inflated samples within tolerance.
dstfit <- function(x, fams = NULL, nboot = 200L, conflvl = 0.95, seed = 1L, k = NULL) {
  if (!is.numeric(x) || is.object(x)) stop("dstfit: `x` must be a numeric vector", call. = FALSE)
  if (any(is.infinite(x))) stop("dstfit: `x` has an infinite value", call. = FALSE)
  nmiss <- sum(is.na(x))
  x <- sort(as.numeric(x[!is.na(x)]))
  if (length(x) < 5L) stop("dstfit: `x` needs at least five values that are not missing", call. = FALSE)
  if (length(unique(x)) < 2L) stop("dstfit: every value of `x` is the same; there is no distribution to fit",
                                   call. = FALSE)
  nboot <- .rmbl_scalar(nboot, "nboot", 0, 1e5, integer = TRUE)
  conflvl <- .rmbl_conf_level(conflvl)
  all <- .dst_fams()
  disc <- all(x >= 0 & x == round(x))
  if (is.null(fams)) {
    fams <- names(all)[vapply(all, function(f) f$ok(x), NA) & (vapply(all, `[[`, NA, "disc") | !disc |
                                                                 names(all) %in% c("normal", "t"))]
  }
  fams <- .rmbl_arg(fams, names(all), several = TRUE)
  for (nm in fams) {
    if (!all[[nm]]$ok(x)) stop(sprintf("dstfit: `%s` needs %s", nm, all[[nm]]$need), call. = FALSE)
  }
  n <- length(x)
  fits <- list()
  rows <- list()
  for (nm in fams) {
    f <- all[[nm]]
    p <- .dst_fit1(f, x)
    if (is.null(p)) {
      rows[[nm]] <- data.frame(family = nm, npar = NA_integer_, loglik = NA_real_, aic = NA_real_, bic = NA_real_,
                               ks = NA_real_, ad = NA_real_, converged = FALSE, params = "", stringsAsFactors = FALSE)
      next
    }
    fits[[nm]] <- p
    ll <- sum(f$d(x, p))
    g <- .dst_gof(x, f, p)
    rows[[nm]] <- data.frame(family = nm, npar = length(p), loglik = ll, aic = 2 * length(p) - 2 * ll,
               bic = log(n) * length(p) - 2 * ll, ks = g[["ks"]], ad = g[["ad"]], converged = TRUE,
               params = paste(sprintf("%s = %s", names(p), format(signif(p, 4))), collapse = ", "),
               stringsAsFactors = FALSE)
  }
  tab <- do.call(rbind, rows)
  tab <- tab[order(tab$aic, na.last = TRUE), , drop = FALSE]
  tab <- cbind(rank = seq_len(nrow(tab)), tab)
  rownames(tab) <- NULL
  fits <- fits[intersect(tab$family, names(fits))]
  boot <- .dst_boot(x, all, fits, nboot, conflvl, seed)
  structure(list(table = tab, fits = fits, boot = boot, hill = .dst_hill(x, k, conflvl), x = x, nmiss = nmiss,
                 discrete = disc, conflvl = conflvl), class = c("rmbl_dstfit", "list"))
}

#' Percentile bootstrap intervals of the fitted parameters.
#' @param x The data.
#' @param all The families.
#' @param fits The estimates of the converged fits.
#' @param nboot The number of resamples.
#' @param conflvl The level.
#' @param seed The seed.
#' @return A data frame: family, param, estimate, lower, upper.
#' @noRd
.dst_boot <- function(x, all, fits, nboot, conflvl, seed) {
  if (nboot > 0L) .rmbl_local_seed(seed)
  a <- (1 - conflvl) / 2
  do.call(rbind, c(list(data.frame(family = character(), param = character(), estimate = numeric(),
                                   lower = numeric(), upper = numeric(), stringsAsFactors = FALSE)),
                   lapply(names(fits), function(nm) {
    p <- fits[[nm]]
    b <- if (nboot > 0L) {
      vapply(seq_len(nboot), function(i) {
        q <- .dst_fit1(all[[nm]], sample(x, replace = TRUE))
        if (is.null(q)) rep(NA_real_, length(p)) else q
      }, p)
    }
    lim <- if (is.null(b)) matrix(NA_real_, 2L, length(p)) else
      apply(matrix(b, nrow = length(p)), 1L, stats::quantile, c(a, 1 - a), na.rm = TRUE, names = FALSE)
    data.frame(family = nm, param = names(p), estimate = unname(p), lower = lim[1L, ], upper = lim[2L, ],
               stringsAsFactors = FALSE)
  })))
}

#' The Hill estimate of the tail index, NULL for data that are not all positive or
#' under ten values.
#' @param x The data, sorted.
#' @param k The number of upper order statistics, or NULL.
#' @param conflvl The level.
#' @return A list, or NULL.
#' @noRd
.dst_hill <- function(x, k, conflvl) {
  n <- length(x)
  if (n < 10L || any(x <= 0)) return(NULL)
  k <- if (is.null(k)) floor(sqrt(n)) else .rmbl_scalar(k, "k", 2, n - 1, integer = TRUE)
  top <- rev(x)[seq_len(k)]
  alpha <- k / sum(log(top / rev(x)[k + 1L]))
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  list(k = as.integer(k), alpha = alpha, lower = alpha * (1 - z / sqrt(k)), upper = alpha * (1 + z / sqrt(k)))
}

#' @rdname dstfit
#' @export
print.rmbl_dstfit <- function(x, ...) {
  t <- x$table
  cat(sprintf("Distributions fitted to %d values%s, ranked by AIC\n\n", length(x$x),
              if (x$nmiss) sprintf(" (%d missing dropped)", x$nmiss) else ""))
  show <- t[, c("rank", "family", "npar", "loglik", "aic", "bic", "ks", "ad")]
  print(format(show, digits = 4), row.names = FALSE)
  cat("\n")
  for (i in which(t$converged)) cat(sprintf("  %-12s %s\n", t$family[i], t$params[i]))
  if (!is.null(x$hill)) {
    cat(sprintf("\nHill tail index %.3g (%.3g to %.3g), from the %d largest values\n", x$hill$alpha,
                x$hill$lower, x$hill$upper, x$hill$k))
  }
  invisible(x)
}

#' Plot fitted distributions
#'
#' Four views of a [dstfit()] result: the histogram (or, for
#' counts, the observed proportions) with each fitted density or mass over it; a QQ
#' plot and a PP plot per family; and the empirical survival function on log-log axes
#' with each fitted survival curve, where a power law is a straight line.
#' @param x A [dstfit()] result.
#' @param ... Further arguments to the first `plot()` call.
#' @param which One of `"density"`, `"qq"`, `"pp"` or
#'   `"tail"`.
#' @param fams Families to draw; default the three best by AIC.
#' @param main,col,palette The title, colours, and a [blpal()]
#'   palette name.
#' @return The data drawn, invisibly: a data frame with `family`, `x` and
#'   `y` (and for `qq` and `pp` the empirical value in `y`
#'   against the fitted one in `x`).
#' @examples
#' set.seed(2)
#' f <- dstfit(stats::rlnorm(200), nboot = 0)
#' plot(f)
#' plot(f, which = "qq")
#' plot(f, which = "pp", fams = "lognormal")
#' plot(f, which = "tail")
#' try(plot(f, fams = "beta"))
#' @export
plot.rmbl_dstfit <- function(x, ..., which = c("density", "qq", "pp", "tail"), fams = NULL, main = NULL,
                             col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_dstfit")
  which <- .rmbl_arg(which)
  if (is.null(fams)) fams <- utils::head(names(x$fits), 3L)
  bad <- setdiff(fams, names(x$fits))
  if (length(bad)) stop(sprintf("plot: no converged fit for %s", paste(bad, collapse = ", ")), call. = FALSE)
  all <- .dst_fams()
  y <- x$x
  cols <- .bl_cols(length(fams) + 1L, col, palette)
  if (which %in% c("qq", "pp")) return(.dst_panels(x, fams, which, main, cols, ...))
  op <- .bl_par(NULL)
  on.exit(graphics::par(op), add = TRUE)
  if (which == "tail") {
    s <- y[y > 0]
    if (length(s) < 2L) stop("plot: the tail plot needs at least two values above 0", call. = FALSE)
    u <- sort(unique(s))
    emp <- 1 - stats::ecdf(s)(u) + 1 / length(s)
    graphics::plot(u, emp, log = "xy", type = "n", xlab = "", ylab = "", main = "", ...)
    .bl_grid(NULL)
    graphics::points(u, emp, pch = 21, bg = cols[1L], col = "white")
    out <- data.frame(family = "data", x = u, y = emp, stringsAsFactors = FALSE)
    for (i in seq_along(fams)) {
      sf <- pmax(1 - all[[fams[i]]]$p(u, x$fits[[fams[i]]]), 1e-300)
      graphics::lines(u, sf, col = cols[i + 1L], lwd = 2)
      out <- rbind(out, data.frame(family = fams[i], x = u, y = sf, stringsAsFactors = FALSE))
    }
    .bl_ylab("Share at or above (log)")
    .bl_xlab("Value (log)")
    .bl_title(.bl_main(main, "Tail: survival on log-log axes"))
  } else if (x$discrete) {
    k <- 0:max(y)
    obs <- as.numeric(table(factor(y, levels = k))) / length(y)
    mids <- .bl_barplot(obs, names.arg = k, col = grDevices::adjustcolor(cols[1L], 0.6), labels = FALSE, ...)
    out <- data.frame(family = "data", x = k, y = obs, stringsAsFactors = FALSE)
    for (i in seq_along(fams)) {
      pm <- exp(all[[fams[i]]]$d(k, x$fits[[fams[i]]]))
      graphics::lines(mids, pm, col = cols[i + 1L], lwd = 2, type = "o", pch = 19, cex = 0.7)
      out <- rbind(out, data.frame(family = fams[i], x = k, y = pm, stringsAsFactors = FALSE))
    }
    .bl_ylab("Proportion")
    .bl_title(.bl_main(main, "Observed counts and fitted mass"))
  } else {
    h <- graphics::hist(y, breaks = "FD", plot = FALSE)
    g <- seq(min(y), max(y), length.out = 200L)
    dens <- lapply(fams, function(f) exp(all[[f]]$d(g, x$fits[[f]])))
    top <- max(h$density, unlist(dens)[is.finite(unlist(dens))])
    graphics::plot(range(h$breaks), c(0, top), type = "n", xlab = "", ylab = "", main = "", ...)
    .bl_grid(NULL)
    graphics::rect(utils::head(h$breaks, -1L), 0, h$breaks[-1L], h$density,
                   col = grDevices::adjustcolor(cols[1L], 0.35), border = "white")
    out <- data.frame(family = "data", x = h$mids, y = h$density, stringsAsFactors = FALSE)
    for (i in seq_along(fams)) {
      graphics::lines(g, dens[[i]], col = cols[i + 1L], lwd = 2.2)
      out <- rbind(out, data.frame(family = fams[i], x = g, y = dens[[i]], stringsAsFactors = FALSE))
    }
    .bl_ylab("Density")
    .bl_title(.bl_main(main, "Histogram and fitted densities"))
  }
  graphics::legend("topright", c("data", fams), col = cols, lwd = c(NA, rep(2, length(fams))),
                   pch = c(15, rep(NA, length(fams))), bty = "n", cex = 0.85)
  invisible(out)
}

#' The QQ or PP panels of a dstfit() plot, one per family.
#' @param x The fit.
#' @param fams The families.
#' @param which "qq" or "pp".
#' @param main The title, or NULL.
#' @param cols The colours.
#' @param ... Further arguments to plot().
#' @return The data drawn, invisibly.
#' @noRd
.dst_panels <- function(x, fams, which, main, cols, ...) {
  all <- .dst_fams()
  y <- x$x
  n <- length(y)
  op <- .bl_panels_begin(length(fams))
  on.exit(graphics::par(op), add = TRUE)
  on.exit(.bl_panels_abort(), add = TRUE)
  out <- NULL
  for (i in seq_along(fams)) {
    f <- all[[fams[i]]]
    p <- x$fits[[fams[i]]]
    pp <- (seq_len(n) - 0.5) / n
    if (which == "qq") {
      a <- f$q(pp, p)
      b <- y
    } else {
      a <- pp
      b <- f$p(y, p)
    }
    graphics::par(mar = c(4, 4.2, 3, 1))
    graphics::plot(a, b, type = "n", xlab = "", ylab = "", main = "", ...)
    .bl_grid(NULL)
    graphics::abline(0, 1, col = "#8C8C8C", lty = 2)
    graphics::points(a, b, pch = 21, bg = cols[i + 1L], col = "white", cex = 0.9)
    .bl_xlab(if (which == "qq") "Fitted quantile" else "Plotting position")
    .bl_ylab(if (which == "qq") "Observed value" else "Fitted probability")
    .bl_title(if (is.null(main)) sprintf("%s: %s", toupper(which), fams[i]) else main)
    out <- rbind(out, data.frame(family = fams[i], x = a, y = b, stringsAsFactors = FALSE))
  }
  attr(out, "plnkey") <- .bl_panels_end()
  invisible(out)
}
