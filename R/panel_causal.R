# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Causal estimation on panels beyond two-way fixed effects: double machine learning with fixed effects,
# matching before difference in differences, synthetic difference in differences, the wild cluster
# bootstrap for few clusters, sensitivity to violations of parallel trends, and design-based power.
# Base R only; each checked against its reference implementation in the tests or the vignette.

# ---- learners --------------------------------------------------------------------------------------

# Columns scaled by their training moments (1/n), the convention of glmnet
.rmbl_scale_fit <- function(x) {
  mu <- colMeans(x)
  sdv <- sqrt(colMeans(sweep(x, 2L, mu)^2))
  sdv[!is.finite(sdv) | sdv <= 1e-12] <- 1
  list(mu = mu, sd = sdv)
}

# The lasso by cyclic coordinate descent: (1/2n) ||y - a - X b||^2 + lambda ||b||_1 on standardised X,
# along a decreasing path of lambda (warm starts). Returns the coefficients at each lambda, on the
# original scale, with the intercept first.
.rmbl_lasso_path <- function(x, y, lambda) {
  sc <- .rmbl_scale_fit(x)
  z <- sweep(sweep(x, 2L, sc$mu), 2L, sc$sd, "/")
  my <- mean(y)
  r <- y - my
  n <- nrow(z)
  p <- ncol(z)
  b <- numeric(p)
  out <- matrix(0, p + 1L, length(lambda))
  for (l in seq_along(lambda)) {
    lam <- lambda[l]
    for (it in 1:10000) {
      dmax <- 0
      for (j in seq_len(p)) {
        bj <- b[j]
        g <- sum(z[, j] * r) / n + bj
        nb <- sign(g) * max(abs(g) - lam, 0)
        if (nb != bj) {
          r <- r - z[, j] * (nb - bj)
          b[j] <- nb
          dmax <- max(dmax, abs(nb - bj))
        }
      }
      if (dmax < 1e-9) break
    }
    beta <- b / sc$sd
    out[, l] <- c(my - sum(beta * sc$mu), beta)
  }
  out
}

.rmbl_lasso_lambdas <- function(x, y, n_lambda = 60L) {
  sc <- .rmbl_scale_fit(x)
  z <- sweep(sweep(x, 2L, sc$mu), 2L, sc$sd, "/")
  lmax <- max(abs(crossprod(z, y - mean(y)))) / nrow(z)
  if (!is.finite(lmax) || lmax <= 0) lmax <- 1
  exp(seq(log(lmax), log(lmax * if (nrow(x) > ncol(x)) 1e-4 else 1e-2), length.out = n_lambda))
}

# lasso with lambda chosen by K-fold cross-validation (the minimum of the mean squared error)
.rmbl_lasso_cv <- function(xtr, ytr, xte, k = 5L) {
  lam <- .rmbl_lasso_lambdas(xtr, ytr)
  f <- rep_len(seq_len(k), nrow(xtr))[order(stats::runif(nrow(xtr)))]
  err <- matrix(0, k, length(lam))
  for (i in seq_len(k)) {
    b <- .rmbl_lasso_path(xtr[f != i, , drop = FALSE], ytr[f != i], lam)
    pred <- cbind(1, xtr[f == i, , drop = FALSE]) %*% b
    err[i, ] <- colMeans((ytr[f == i] - pred)^2)
  }
  best <- lam[which.min(colMeans(err))]
  b <- .rmbl_lasso_path(xtr, ytr, lam[lam >= best])
  as.vector(cbind(1, xte) %*% b[, ncol(b)])
}

# ridge with the penalty chosen by generalised cross-validation, through the SVD of standardised X
.rmbl_ridge_gcv <- function(xtr, ytr, xte) {
  sc <- .rmbl_scale_fit(xtr)
  z <- sweep(sweep(xtr, 2L, sc$mu), 2L, sc$sd, "/")
  my <- mean(ytr)
  s <- svd(z)
  uy <- crossprod(s$u, ytr - my)
  n <- nrow(z)
  lam <- 10^seq(-4, 4, length.out = 81) * n
  gcv <- vapply(lam, function(l) {
    f <- s$d^2 / (s$d^2 + l)
    fit <- s$u %*% (f * uy)
    n * sum((ytr - my - fit)^2) / (n - sum(f))^2
  }, numeric(1L))
  l <- lam[which.min(gcv)]
  beta <- s$v %*% ((s$d / (s$d^2 + l)) * uy)
  zt <- sweep(sweep(xte, 2L, sc$mu), 2L, sc$sd, "/")
  as.vector(my + zt %*% beta)
}

.rmbl_ols_learner <- function(xtr, ytr, xte) {
  q <- qr(cbind(1, xtr))
  b <- qr.coef(q, ytr)
  b[is.na(b)] <- 0
  as.vector(cbind(1, xte) %*% b)
}

.rmbl_learner <- function(learner) {
  if (is.function(learner)) {
    # called as learner(xtr, ytr, xte): a function of fewer arguments failed in R's words
    # ("unused arguments"; final audit of 1.0.0)
    fm <- names(formals(learner))
    if (!"..." %in% fm && length(fm) < 3L) {
      stop("`lrn` must be a learner name or a function(xtr, ytr, xte) returning one prediction per test row",
           call. = FALSE)
    }
    return(function(xtr, ytr, xte) {
      p <- learner(xtr, ytr, xte)
      if (!is.numeric(p) || length(p) != nrow(xte) || anyNA(p)) {
        stop("a learner function must return one prediction per test row", call. = FALSE)
      }
      as.numeric(p)
    })
  }
  learner <- .rmbl_arg(learner, c("lasso", "ridge", "ols"))
  switch(learner, lasso = .rmbl_lasso_cv, ridge = .rmbl_ridge_gcv, ols = .rmbl_ols_learner)
}

# squares and pairwise products of the columns, so the penalised learners can find a nonlinear fit
.rmbl_poly2 <- function(x) {
  p <- ncol(x)
  nm <- colnames(x)
  sq <- x^2
  colnames(sq) <- paste0(nm, "^2")
  if (p < 2L) return(cbind(x, sq))
  pr <- utils::combn(p, 2L)
  ia <- vapply(seq_len(ncol(pr)), function(k) x[, pr[1L, k]] * x[, pr[2L, k]], numeric(nrow(x)))
  ia <- matrix(ia, nrow(x), dimnames = list(NULL, paste0(nm[pr[1L, ]], ":", nm[pr[2L, ]])))
  cbind(x, sq, ia)
}

# ---- double machine learning with fixed effects ----------------------------------------------------

#' Double machine learning for panels with fixed effects
#'
#' The effect of a treatment (continuous or binary) on an outcome in a unit-by-period
#' panel, with unit and period fixed effects removed and the confounding through
#' covariates fitted by a machine learner, cross-fitted by unit, with an orthogonal
#' (Neyman) score and errors clustered by unit.
#'
#' @details The model is the partially linear panel model
#' \deqn{Y_{it} = \theta D_{it} + g(X_{it}) + \alpha_i + \gamma_t + \varepsilon_{it}.}{Y_it =
#' theta D_it + g(X_it) + a_i + c_t + e_it.} Following Clarke and Polselli (2025), the
#' fixed effects are removed by the within transformation (\eqn{\tilde Y},
#' \eqn{\tilde D}, \eqn{\tilde X}), and
#' \eqn{\ell(\tilde X) = E(\tilde Y \mid \tilde X)} and
#' \eqn{m(\tilde X) = E(\tilde D \mid \tilde X)} are fitted by the learner on \eqn{K}
#' folds of units (all of a unit's periods in one fold, so a unit's own errors never
#' help predict it). With the out-of-fold residuals \eqn{U = \tilde Y - \hat\ell} and
#' \eqn{V = \tilde D - \hat m}, the partialling-out estimator is
#' \deqn{\hat\theta = \sum V U / \sum V^2,}{theta = sum V U / sum V^2,}
#' the solution of the Neyman-orthogonal score \eqn{(U - \theta V) V} of Chernozhukov
#' et al. (2018). Its variance is the cluster-robust sandwich over units,
#' \deqn{\hat V = \frac{G}{G - 1} \frac{\sum_g \big(\sum_{i \in g} V_i (U_i - \hat\theta
#' V_i)\big)^2}{(\sum V^2)^2},}{V = G/(G-1) sum_g (sum V (U - theta V))^2 / (sum
#' V^2)^2,} with t on \eqn{G - 1} degrees of freedom. Folds are drawn with
#' \code{seed}; \code{nrep} repeated splits are combined by the median of the
#' estimates and of the variances plus the squared deviations from it (Chernozhukov et
#' al. 2018, section 3.4).
#'
#' Learners, all in base R: \code{"lasso"} (coordinate descent, penalty by 5-fold
#' cross-validation), \code{"ridge"} (penalty by generalised cross-validation),
#' \code{"ols"}, or a function returning predictions (for example a random forest
#' from another package), called as \code{function(x_train, y_train, x_test)}.
#' \code{basis = "poly2"} adds squares and pairwise products of the covariates, built
#' from the covariates as observed and then demeaned, so a confounding that is a
#' combination of them is removed exactly. The demeaned features are what the learners
#' see: a covariate fixed within a unit is absorbed by the unit effect and carries no
#' information. A learner given only the demeaned covariates (a random forest, say)
#' approximates a nonlinear confounding less well; the poly2 basis, or a basis of the
#' user's own as further covariates, is the remedy.
#'
#' @inheritParams plndid
#' @param trt Column name of the treatment (continuous, or 0/1).
#' @param covs Column names of the time-varying covariates.
#' @param lrn \code{"lasso"} (default), \code{"ridge"}, \code{"ols"}, or a
#'   function.
#' @param basis \code{"linear"} (default) or \code{"poly2"}.
#' @param folds Cross-fitting folds of units (default 5).
#' @param nrep Repeated sample splits (default 1).
#' @param seed Seed for the folds (default 1).
#' @return A data frame of class \code{rmbl_dml}: \code{estimate}, \code{se},
#'   \code{lower}, \code{upper}, \code{t}, \code{p_value}; attributes \code{n},
#'   \code{clusters}, \code{learner}, \code{folds}, \code{repeats}, and \code{r2} (the
#'   out-of-fold R-squared of the two nuisance fits).
#' @references Chernozhukov V, Chetverikov D, Demirer M, Duflo E, Hansen C, Newey W,
#'   Robins J (2018). Double/debiased machine learning for treatment and structural
#'   parameters. The Econometrics Journal 21(1):C1-C68. \doi{10.1111/ectj.12097}
#'
#' Clarke PS, Polselli A (2025). Double machine learning for static panel models with
#' fixed effects. The Econometrics Journal 29:69-86. \doi{10.1093/ectj/utaf011}
#' @seealso \code{\link{plrcf}} (one cross-section),
#'   \code{\link{stgatt}} with covariates (doubly robust difference in
#'   differences).
#' @examples
#' p <- polex()
#' set.seed(9)
#' p$unemployment <- 6 + sin(p$month / 6) + stats::rnorm(nrow(p), 0, 0.5)
#' p$patrols <- 0.5 * p$unemployment + p$reformed + stats::rnorm(nrow(p))
#' plndml(p, "district", "month", "crmrate", "patrols",
#'           c("unemployment", "arrrate"), lrn = "ridge")
#' @export
plndml <- function(data, unit, time, y, trt, covs, fe = c("unit", "time"),
                      lrn = "lasso", basis = c("linear", "poly2"), folds = 5L, nrep = 1L, seed = 1L,
                      cl = NULL, conflvl = 0.95) {
  conflvl <- .rmbl_conf_level(conflvl)
  fe <- .rmbl_arg(fe, c("unit", "time"), several = TRUE)
  basis <- .rmbl_arg(basis)
  folds <- .rmbl_scalar(folds, "folds", 2, 100, integer = TRUE)
  nrep <- .rmbl_scalar(nrep, "nrep", 1, 1000, integer = TRUE)
  # the fold draws are seeded from `seed` plus the repetition: text or NULL reached that sum
  seed <- if (is.null(seed)) sample.int(2^30, 1L) else .rmbl_r_seed(seed)
  fit_fun <- .rmbl_learner(lrn)
  p <- .rmbl_panel(data, unit, time, y)
  v <- .rmbl_colnames(trt, "trt")
  if (!v %in% names(data)) stop(sprintf("`trt` (%s) is not a column of `data`", v), call. = FALSE)
  d <- .rmbl_num(data[[v]], "trt")
  x <- .rmbl_covariates(data, covs)
  if (is.null(x)) stop("`covs` must name one column at least", call. = FALSE)
  if (anyNA(d) || anyNA(x) || anyNA(p$y)) stop("the outcome, treatment and covariates must have no NA", call. = FALSE)
  if (length(unique(p$u)) < folds) stop("fewer units than folds", call. = FALSE)
  fes <- list()
  if ("unit" %in% fe) fes$unit <- p$u
  if ("time" %in% fe) fes$time <- as.integer(factor(p$t))
  yt <- as.vector(.rmbl_demean(p$y, fes))
  dt <- as.vector(.rmbl_demean(d, fes))
  # the basis is built from the covariates as observed and then demeaned: a confounder g(X) that is
  # a combination of the basis functions is then removed exactly (the square of a demeaned covariate
  # is not the demeaned square)
  if (basis == "poly2") x <- .rmbl_poly2(x)
  xt <- .rmbl_demean(x, fes)
  colnames(xt) <- colnames(x)
  keep <- apply(xt, 2L, stats::sd) > 1e-10
  if (!any(keep)) stop("no covariate varies within units and periods", call. = FALSE)
  xt <- xt[, keep, drop = FALSE]
  .cl <- .rmbl_cluster(data, cl, p)
  if (is.list(.cl)) stop("`cl` names one column for plndml()", call. = FALSE)
  uu <- unique(p$u)
  one <- function(r) {
    f <- .rmbl_with_seed(seed + r - 1L, sample(rep_len(seq_len(folds), length(uu))))[match(p$u, uu)]
    ly <- md <- numeric(length(yt))
    .rmbl_with_seed(seed + 1000L + r, {
      for (k in seq_len(folds)) {
        tr <- f != k
        ly[!tr] <- fit_fun(xt[tr, , drop = FALSE], yt[tr], xt[!tr, , drop = FALSE])
        md[!tr] <- fit_fun(xt[tr, , drop = FALSE], dt[tr], xt[!tr, , drop = FALSE])
      }
    })
    uu_ <- yt - ly
    vv <- dt - md
    den <- sum(vv^2)
    if (den <= 1e-10 * max(1, sum(dt^2))) {
      stop("the treatment has no variation left after the covariates", call. = FALSE)
    }
    th <- sum(vv * uu_) / den
    s <- rowsum(vv * (uu_ - th * vv), .cl)
    g <- nrow(s)
    list(theta = th, var = g / (g - 1) * sum(s^2) / den^2, g = g,
         r2 = c(outcome = 1 - sum(uu_^2) / sum(yt^2), treatment = 1 - sum(vv^2) / sum(dt^2)))
  }
  runs <- lapply(seq_len(nrep), one)
  ths <- vapply(runs, `[[`, numeric(1L), "theta")
  th <- stats::median(ths)
  va <- stats::median(vapply(runs, `[[`, numeric(1L), "var") + (ths - th)^2)
  se <- sqrt(va)
  g <- runs[[1L]]$g
  tq <- stats::qt(1 - (1 - conflvl) / 2, g - 1L)
  out <- data.frame(estimate = th, se = se, lower = th - tq * se, upper = th + tq * se, t = th / se,
                    p_value = 2 * stats::pt(-abs(th / se), g - 1L))
  attr(out, "n") <- length(yt)
  attr(out, "clusters") <- g
  attr(out, "learner") <- if (is.function(lrn)) "user function" else lrn
  attr(out, "folds") <- folds
  attr(out, "repeats") <- nrep
  attr(out, "r2") <- runs[[1L]]$r2
  attr(out, "conflvl") <- conflvl
  class(out) <- c("rmbl_dml", "data.frame")
  out
}

#' @export
print.rmbl_dml <- function(x, ...) {
  cat(sprintf("Double machine learning with fixed effects (%s, %d folds of units, %d split%s)\n",
              attr(x, "learner"), attr(x, "folds"), attr(x, "repeats"), if (attr(x, "repeats") > 1L) "s" else ""))
  print(format(as.data.frame(x), digits = 4L), row.names = FALSE)
  r2 <- attr(x, "r2")
  cat(sprintf("%d observations, %d clusters; out-of-fold R-squared: outcome %.3f, treatment %.3f\n",
              attr(x, "n"), attr(x, "clusters"), r2[["outcome"]], r2[["treatment"]]))
  invisible(x)
}

# ---- balance and matching --------------------------------------------------------------------------

#' A covariate balance table
#'
#' Means of each covariate in the treated and comparison groups, their standardised
#' mean difference, and Welch's test, optionally weighted (after matching or
#' weighting).
#'
#' @details The standardised mean difference is \eqn{(\bar x_1 - \bar x_0) / s_1} with
#' \eqn{s_1} the unweighted standard deviation in the treated group (the convention
#' for the effect on the treated, so that it does not move when weights change the
#' comparison group); \eqn{|SMD| < 0.1} is the usual threshold for balance. With
#' weights the means are weighted and the test uses the weighted variances and Kish's
#' effective sample sizes.
#'
#' @param data A data frame, one row per unit.
#' @param grp Column name of the 0/1 group (1 = treated).
#' @param covs Column names to compare.
#' @param w Optional column name of weights.
#' @return A data frame of class \code{rmbl_balance}: \code{covariate},
#'   \code{meantrtd}, \code{meanctl}, \code{smd}, \code{p_value}.
#' @references Welch BL (1947). The generalization of 'Student's' problem when several
#'   different population variances are involved. Biometrika 34(1-2):28-35.
#'   \doi{10.1093/biomet/34.1-2.28}
#' @examples
#' d <- data.frame(t = rep(0:1, each = 50),
#'                 age = c(stats::rnorm(50, 30), stats::rnorm(50, 33)))
#' baltab(d, "t", "age")
#' @export
baltab <- function(data, grp, covs, w = NULL) {
  .rmbl_df_names(data)
  g <- .rmbl_num(data[[.rmbl_colnames(grp, "grp")]], "grp")
  if (anyNA(g) || !all(g %in% c(0, 1)) || length(unique(g)) < 2L) stop("`grp` must be 0 and 1", call. = FALSE)
  x <- .rmbl_covariates(data, covs)
  if (is.null(x)) stop("`covs` must name one column at least", call. = FALSE)
  .w <- .rmbl_weights(data, w)
  rows <- lapply(colnames(x), function(v) {
    a <- x[g == 1, v]
    b <- x[g == 0, v]
    wa <- .w[g == 1]
    wb <- .w[g == 0]
    ma <- sum(wa * a) / sum(wa)
    mb <- sum(wb * b) / sum(wb)
    # unbiased with reliability weights; the sample variance (n - 1) when the weights are 1
    va <- sum(wa * (a - ma)^2) / (sum(wa) - sum(wa^2) / sum(wa))
    vb <- sum(wb * (b - mb)^2) / (sum(wb) - sum(wb^2) / sum(wb))
    na <- sum(wa)^2 / sum(wa^2)
    nb <- sum(wb)^2 / sum(wb^2)
    se <- sqrt(va / na + vb / nb)
    df <- (va / na + vb / nb)^2 / ((va / na)^2 / (na - 1) + (vb / nb)^2 / (nb - 1))
    s1 <- stats::sd(a)
    data.frame(covariate = v, meantrtd = ma, meanctl = mb,
               # a group of one unit has no spread: NA, not an error (mtchdid() with a tight caliper)
               smd = if (isTRUE(s1 > 0)) (ma - mb) / s1 else NA_real_,
               p_value = if (isTRUE(se > 0)) 2 * stats::pt(-abs((ma - mb) / se), df) else NA_real_)
  })
  out <- do.call(rbind, rows)
  class(out) <- c("rmbl_balance", "data.frame")
  out
}

#' Difference in differences after matching on pre-treatment trajectories
#'
#' Matches each treated unit to the comparison units most like it before treatment
#' (its outcomes in the pre-period and, optionally, covariates), within an exact
#' grouping if given, and estimates the difference in differences on the matched
#' sample with the matching weights.
#'
#' @details Each unit is described by its outcome in each pre-period (the periods
#' before the first adoption) and the pre-period means of the covariates. Distances
#' are Mahalanobis, with the pooled within-group covariance of those features
#' (\code{covariance = "pooled"}, as \code{MatchIt} computes it) or their covariance
#' in the whole sample (\code{"full"}, as \code{stats::mahalanobis()} is usually given
#' it); each treated unit takes its \code{ratio} nearest comparison units, with
#' replacement (so the matches do not depend on the order of the treated units), only
#' within its \code{exact} group, and only within \code{caliper} (in units of the
#' distance's standard deviation) if given. A comparison unit's weight is the sum over
#' the treated units it serves of \eqn{1/\code{ratio}}. The estimate is
#' \code{\link{plndid}} on the matched units with those weights, with errors
#' clustered by unit; matching on pre-period outcomes makes parallel trends more
#' credible but can bring in regression to the mean when the treated were chosen for
#' an unusual pre-period (Daw and Hatfield 2018).
#'
#' @inheritParams evstudy
#' @param covs Optional covariate columns to match on (their pre-period means).
#' @param ratio Comparison units per treated unit (default 1).
#' @param exact Optional column name: match only within its values (a region, a
#'   district).
#' @param caliper Optional maximum distance, in standard deviations of the distances.
#' @param covm \code{"pooled"} (default; the pooled within-group covariance) or
#'   \code{"full"} (the whole sample's).
#' @return A list of class \code{rmbl_matched_did}: \code{estimate} (a
#'   \code{\link{plndid}} result), \code{matches} (treated unit, comparison unit,
#'   distance), \code{weights} (per unit), \code{balance} (a
#'   \code{\link{baltab}} of the matching features before and after).
#' @references Daw JR, Hatfield LA (2018). Matching and regression to the mean in
#'   difference-in-differences analysis. Health Services Research 53(6):4138-4156.
#'   \doi{10.1111/1475-6773.12993}
#'
#' Applied with spatial nearest-facility matching within judicial districts: Zorro
#' Medina A (2020). The failed war on pre-trial detention: evidence from a
#' quasi-experimental reform. \doi{10.2139/ssrn.3686855}
#' @examples
#' p <- polex()
#' m <- mtchdid(p, "district", "month", "crmrate", "refmonth", ratio = 2)
#' m$estimate
#' m$balance
#' @export
mtchdid <- function(data, unit, time, y, ftreat, covs = NULL, ratio = 1L, exact = NULL,
                        caliper = NULL, covm = c("pooled", "full"), conflvl = 0.95) {
  ratio <- .rmbl_scalar(ratio, "ratio", 1, 100, integer = TRUE)
  covm <- .rmbl_arg(covm)
  p <- .rmbl_panel(data, unit, time, y)
  g <- .rmbl_first_treated(data, ftreat, p)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel", call. = FALSE)
  o <- order(p$u, p$t)
  gu <- g[o][seq(1L, by = nt, length.out = nu)]
  tr <- is.finite(gu)
  if (!any(tr) || all(tr)) stop("need treated and never-treated units", call. = FALSE)
  pre <- p$tl < min(gu[tr])
  if (!any(pre)) stop("no period before the first adoption to match on", call. = FALSE)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE)
  feat <- ym[, pre, drop = FALSE]
  colnames(feat) <- paste0("y_", p$tl[pre])
  if (!is.null(covs)) {
    cv <- .rmbl_covariates(data, covs)[o, , drop = FALSE]
    pm <- vapply(colnames(cv), function(v) rowMeans(matrix(cv[, v], nu, nt, byrow = TRUE)[, pre, drop = FALSE]),
                 numeric(nu))
    feat <- cbind(feat, matrix(pm, nu, dimnames = list(NULL, colnames(cv))))
  }
  ex <- rep("all", nu)
  if (!is.null(exact)) {
    v <- .rmbl_colnames(exact, "exact")
    if (!v %in% names(data)) stop(sprintf("`exact` (%s) is not a column of `data`", v), call. = FALSE)
    ex <- as.character(data[[v]][o][seq(1L, by = nt, length.out = nu)])
  }
  # the pooled within-group covariance (MatchIt's convention for the Mahalanobis distance), or the
  # covariance of the whole sample
  n1 <- sum(tr)
  n0 <- sum(!tr)
  sg <- if (covm == "full") stats::cov(feat) else
    ((n1 - 1) * stats::cov(feat[tr, , drop = FALSE]) + (n0 - 1) * stats::cov(feat[!tr, , drop = FALSE])) /
      (n1 + n0 - 2)
  sgi <- tryCatch(solve(sg), error = function(e) {
    ev <- eigen(sg, symmetric = TRUE)
    keep <- ev$values > 1e-10 * max(ev$values)
    ev$vectors[, keep, drop = FALSE] %*% diag(1 / ev$values[keep], sum(keep)) %*% t(ev$vectors[, keep, drop = FALSE])
  })
  w <- numeric(nu)
  w[tr] <- 1
  rows <- list()
  dall <- c()
  for (i in which(tr)) {
    cands <- which(!tr & ex == ex[i])
    if (!length(cands)) next
    dd <- sqrt(stats::mahalanobis(feat[cands, , drop = FALSE], feat[i, ], sgi, inverted = TRUE))
    dall <- c(dall, dd)
    ord <- order(dd)[seq_len(min(ratio, length(cands)))]
    rows[[length(rows) + 1L]] <- data.frame(treated = p$ul[i], control = p$ul[cands[ord]], distance = dd[ord],
                                            stringsAsFactors = FALSE)
  }
  mt <- do.call(rbind, rows)
  if (is.null(mt)) stop("no treated unit has a comparison unit in its exact group", call. = FALSE)
  if (!is.null(caliper)) {
    caliper <- .rmbl_scalar(caliper, "caliper", 0)
    mt <- mt[mt$distance <= caliper * stats::sd(dall), , drop = FALSE]
    if (!nrow(mt)) stop("no match within the caliper", call. = FALSE)
    w[tr & !p$ul %in% mt$treated] <- 0
  }
  k <- table(mt$treated)
  for (r in seq_len(nrow(mt))) {
    j <- match(mt$control[r], p$ul)
    w[j] <- w[j] + 1 / k[[mt$treated[r]]]
  }
  wu <- w[p$u]
  keep <- wu > 0
  d2 <- data[keep, , drop = FALSE]
  d2$.rmbl_w <- wu[keep]
  d2$.rmbl_d <- as.numeric(p$t[keep] >= g[keep])
  est <- plndid(d2, unit, time, y, ".rmbl_d", w = ".rmbl_w", conflvl = conflvl)
  fd <- data.frame(.rmbl_g = as.numeric(tr), feat, check.names = FALSE)
  before <- baltab(fd, ".rmbl_g", colnames(feat))
  fd$.rmbl_w <- w
  after <- baltab(fd[w > 0, ], ".rmbl_g", colnames(feat), w = ".rmbl_w")
  bal <- data.frame(feature = before$covariate, smdbef = before$smd, smdafter = after$smd)
  out <- list(estimate = est, matches = mt, weights = data.frame(unit = p$ul, weight = w), balance = bal)
  class(out) <- "rmbl_matched_did"
  out
}

#' @export
print.rmbl_matched_did <- function(x, ...) {
  cat(sprintf("Matched difference in differences: %d treated units, %d comparison units used\n",
              length(unique(x$matches$treated)), length(unique(x$matches$control))))
  print(x$estimate)
  b <- x$balance
  cat(sprintf("Largest |standardised difference| before matching %.3f, after %.3f\n",
              max(abs(b$smdbef), na.rm = TRUE), max(abs(b$smdafter), na.rm = TRUE)))
  invisible(x)
}

# ---- synthetic difference in differences -----------------------------------------------------------

# min over the simplex (with a free intercept) of (1/n) ||A w - b||^2 + zeta^2 ||w||^2; A rows are the
# fitting points, columns the candidates. The intercept is removed by centring the columns.
.rmbl_sdid_weights <- function(a, b, zeta) {
  ac <- sweep(a, 2L, colMeans(a))
  bc <- b - mean(b)
  n <- nrow(a)
  aug <- rbind(ac / sqrt(n), diag(zeta, ncol(a)))
  .rmbl_simplex_ls(aug, c(bc / sqrt(n), numeric(ncol(a))))
}

#' Synthetic difference in differences
#'
#' Arkhangelsky et al.'s estimator for units adopting a policy at one date: comparison
#' units weighted so their pre-period path parallels the treated units', pre-periods
#' weighted so they predict the post-period, and the difference in differences taken
#' with both weights.
#'
#' @details With \eqn{N_0} comparison units, \eqn{N_1} treated, \eqn{T_0} pre-periods
#' and \eqn{T_1} post-periods, the unit weights solve
#' \deqn{\min_{\omega_0, \omega \in \Delta} \frac{1}{T_0}\sum_{t \le T_0}\Big(\omega_0 +
#' \sum_j \omega_j Y_{jt} - \bar Y_{1t}\Big)^2 + \zeta^2 \|\omega\|^2,}{min (1/T0)
#' sum_t (w0 + sum_j w_j Y_jt - Ybar_1t)^2 + zeta^2 ||w||^2,} with
#' \eqn{\zeta = (N_1 T_1)^{1/4} \hat\sigma} and \eqn{\hat\sigma} the standard
#' deviation of the comparison units' first differences before adoption; the time
#' weights solve the same problem across comparison units, predicting each unit's
#' post-period mean from its pre-periods, with \eqn{\zeta = 10^{-6}\hat\sigma}. The
#' estimate is
#' \deqn{\hat\tau = \Big(\bar Y_{1,post} - \sum_t \lambda_t \bar Y_{1t}\Big) - \sum_j
#' \omega_j \Big(\bar Y_{j,post} - \sum_t \lambda_t Y_{jt}\Big).}{tau = (Y1post - sum
#' lambda Y1t) - sum_j w_j (Yjpost - sum lambda Yjt).} The weights are the exact
#' solutions of these convex problems (the \code{synthdid} package runs Frank-Wolfe
#' and then sparsifies, so its estimate differs slightly). The standard error is the
#' placebo one when there is one treated unit (each set of \eqn{N_1} comparison units
#' in turn treated as if adopting, weights re-estimated), else the jackknife over
#' units with the weights held fixed (Arkhangelsky et al. 2021, algorithms 3 and 4).
#'
#' @inheritParams evstudy
#' @param reps Placebo replications (default 200).
#' @param seed Optional seed for the placebo draws.
#' @return A list of class \code{rmbl_synthdid}: \code{estimate}, \code{se},
#'   \code{lower}, \code{upper}, \code{unitwts}, \code{tmwts},
#'   \code{method} (\code{"placebo"} or \code{"jackknife"}), \code{paths} (treated and
#'   weighted comparison means by period). \code{plot()} draws the paths.
#' @references Arkhangelsky D, Athey S, Hirshberg DA, Imbens GW, Wager S (2021).
#'   Synthetic difference-in-differences. American Economic Review 111(12):4088-4118.
#'   \doi{10.1257/aer.20190159}
#' @examples
#' p <- polex()
#' p1 <- p[is.na(p$refmonth) | p$refmonth == 13, ]
#' syndid(p1, "district", "month", "crmrate", "refmonth", reps = 50, seed = 1)
#' @export
syndid <- function(data, unit, time, y, ftreat, reps = 200L, seed = NULL, conflvl = 0.95) {
  conflvl <- .rmbl_conf_level(conflvl)
  reps <- .rmbl_scalar(reps, "reps", 2, 1e5, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, y)
  g <- .rmbl_first_treated(data, ftreat, p)
  nu <- length(p$ul)
  nt <- length(p$tl)
  if (length(p$y) != nu * nt) stop("`data` must be a balanced panel", call. = FALSE)
  o <- order(p$u, p$t)
  ym <- matrix(p$y[o], nu, nt, byrow = TRUE, dimnames = list(p$ul, p$tl))
  gu <- g[o][seq(1L, by = nt, length.out = nu)]
  tr <- is.finite(gu)
  if (length(unique(gu[tr])) != 1L) {
    stop("syndid() takes one adoption date: keep one cohort and the never-treated units", call. = FALSE)
  }
  if (sum(!tr) < 2L) stop("need two never-treated units at least", call. = FALSE)
  t0 <- sum(p$tl < gu[tr][1L])
  if (t0 < 2L || t0 >= nt) stop("need two periods before adoption and one after", call. = FALSE)
  fit <- function(y0, y1) {
    n0 <- nrow(y0)
    n1 <- nrow(y1)
    t1 <- nt - t0
    pre <- seq_len(t0)
    sigma <- stats::sd(as.vector(apply(y0[, pre, drop = FALSE], 1L, diff)))
    zo <- (n1 * t1)^(1 / 4) * sigma
    zl <- 1e-6 * sigma
    om <- .rmbl_sdid_weights(t(y0[, pre, drop = FALSE]), colMeans(y1[, pre, drop = FALSE]), zo)
    la <- .rmbl_sdid_weights(y0[, pre, drop = FALSE], rowMeans(y0[, -pre, drop = FALSE]), zl)
    tau <- (mean(y1[, -pre]) - sum(la * colMeans(y1[, pre, drop = FALSE]))) -
      sum(om * (rowMeans(y0[, -pre, drop = FALSE]) - as.vector(y0[, pre, drop = FALSE] %*% la)))
    list(tau = tau, omega = om, lambda = la)
  }
  y0 <- ym[!tr, , drop = FALSE]
  y1 <- ym[tr, , drop = FALSE]
  f <- fit(y0, y1)
  n1 <- nrow(y1)
  if (n1 == 1L) {
    method <- "placebo"
    taus <- .rmbl_with_seed(seed, vapply(seq_len(reps), function(r) {
      k <- sample(nrow(y0), n1)
      fit(y0[-k, , drop = FALSE], y0[k, , drop = FALSE])$tau
    }, numeric(1L)))
    se <- sqrt((reps - 1) / reps) * stats::sd(taus)
  } else {
    method <- "jackknife"
    pre <- seq_len(t0)
    est_fixed <- function(om, y0j, y1j) {
      (mean(y1j[, -pre]) - sum(f$lambda * colMeans(y1j[, pre, drop = FALSE]))) -
        sum(om * (rowMeans(y0j[, -pre, drop = FALSE]) - as.vector(y0j[, pre, drop = FALSE] %*% f$lambda)))
    }
    jk <- c(vapply(seq_len(nrow(y0)), function(j) {
      om <- f$omega[-j]
      if (sum(om) <= 0) return(NA_real_)
      est_fixed(om / sum(om), y0[-j, , drop = FALSE], y1)
    }, numeric(1L)), vapply(seq_len(n1), function(j) est_fixed(f$omega, y0, y1[-j, , drop = FALSE]), numeric(1L)))
    jk <- jk[is.finite(jk)]
    n <- length(jk)
    se <- sqrt((n - 1) / n * sum((jk - mean(jk))^2))
  }
  z <- stats::qnorm(1 - (1 - conflvl) / 2)
  paths <- data.frame(time = p$tl, treated = colMeans(y1), synthetic = as.vector(crossprod(f$omega, y0)))
  out <- list(estimate = f$tau, se = se, lower = f$tau - z * se, upper = f$tau + z * se,
              unitwts = stats::setNames(f$omega, rownames(y0)),
              tmwts = stats::setNames(f$lambda, p$tl[seq_len(t0)]),
              method = method, paths = paths, adoption = gu[tr][1L])
  class(out) <- "rmbl_synthdid"
  out
}

#' @export
print.rmbl_synthdid <- function(x, ...) {
  cat(sprintf("Synthetic difference in differences: %.4g (%s s.e. %.4g; %.4g to %.4g)\n", x$estimate, x$method,
              x$se, x$lower, x$upper))
  w <- sort(x$unitwts[x$unitwts > 1e-4], decreasing = TRUE)
  cat("Unit weights:", paste(sprintf("%s %.3f", names(w), w), collapse = ", "), "\n")
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_synthdid <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_synthdid")
  d <- x$paths
  cl <- .bl_cols(2L, col, palette)
  graphics::matplot(d$time, cbind(d$treated, d$synthetic), type = "l", lty = c(1, 2), col = cl, lwd = 2,
                    xlab = "Period", ylab = "Outcome",
                    main = "", ...)
  .bl_title(.bl_main(main, "Synthetic difference in differences"))
  graphics::abline(v = x$adoption, lty = 3, col = "#9A9A9A")
  graphics::legend("topleft", c("Treated", "Weighted comparison"), lty = c(1, 2), col = cl, lwd = 2, bty = "n")
  invisible(d)
}

# ---- the wild cluster bootstrap --------------------------------------------------------------------

#' The wild cluster bootstrap for a difference in differences with few clusters
#'
#' A p-value and confidence interval for the treatment effect of
#' \code{\link{plndid}} that stay accurate when there are few clusters (a policy
#' assigned to a handful of districts or states), where the cluster-robust t test
#' over-rejects.
#'
#' @details This is the restricted wild cluster bootstrap (WCR) of Cameron, Gelbach
#' and Miller (2008). The model is fitted with the null \eqn{\beta = \beta_0} imposed;
#' each bootstrap outcome is the restricted fit plus its residuals multiplied, cluster
#' by cluster, by a random sign (Rademacher) or by one of Webb's six values; the
#' cluster-robust t statistic is recomputed each time. The p-value is the share of
#' bootstrap \eqn{|t^*|} at least \eqn{|t|}. With \code{ties = "count"} (the default)
#' a draw that equals \eqn{|t|} counts: the sign patterns that reproduce the data are
#' among the draws, as the observed assignment is in a permutation test, and the test
#' is exact at its level. With \code{"strict"} only draws above \eqn{|t|} count, as
#' \code{fwildclusterboot} does; under full enumeration this gives a smaller p-value
#' (the two sign patterns that reproduce \eqn{|t|} are left out). With Rademacher
#' weights and \eqn{2^G \le} \code{reps} every sign pattern is enumerated (as
#' \code{fwildclusterboot} does); with very few clusters (under about 12) Webb's
#' weights, which have more distinct values, are better. The interval collects the
#' \eqn{\beta_0} not rejected at \eqn{1 -} \code{conflvl}, found by bisection with
#' the same draws; it is unbounded when no value can be rejected (with Rademacher
#' weights and \eqn{G} clusters the smallest attainable p-value is \eqn{2/2^G}, so
#' four clusters can never reject at 5\%: that is the honest answer, not a failure of
#' the method).
#'
#' @inheritParams plndid
#' @param reps Bootstrap replications (default 9999).
#' @param wtype \code{"rademacher"} (default) or \code{"webb"}.
#' @param seed Optional seed.
#' @param ties \code{"count"} (default) or \code{"strict"}: whether a bootstrap
#'   \eqn{|t^*|} equal to \eqn{|t|} counts against the null.
#' @return A data frame of class \code{rmbl_wild} with the columns \code{estimate},
#'   \code{t}, \code{p_value}, \code{lower}, \code{upper}, \code{clusters},
#'   \code{draws} and \code{enumerated}.
#' @references Cameron AC, Gelbach JB, Miller DL (2008). Bootstrap-based improvements
#'   for inference with clustered errors. Review of Economics and Statistics
#'   90(3):414-427. \doi{10.1162/rest.90.3.414}
#'
#' Webb MD (2023). Reworking wild bootstrap-based inference for clustered errors.
#' Canadian Journal of Economics 56(3):839-858. \doi{10.1111/caje.12661}
#'
#' Roodman D, Nielsen MO, MacKinnon JG, Webb MD (2019). Fast and wild: bootstrap
#' inference in Stata using boottest. The Stata Journal 19(1):4-60.
#' \doi{10.1177/1536867X19830877}
#' @examples
#' p <- polex()
#' # the reform was assigned to four regions: four clusters
#' wcb(p, "district", "month", "crmrate", "reformed",
#'                        cl = "region", wtype = "webb", reps = 299,
#'                        seed = 1)
#' @export
wcb <- function(data, unit, time, y, trtd, covs = NULL, cl = NULL,
                                   reps = 9999L, wtype = c("rademacher", "webb"), seed = NULL,
                                   ties = c("count", "strict"), conflvl = 0.95) {
  wtype <- .rmbl_arg(wtype)
  ties <- .rmbl_arg(ties)
  conflvl <- .rmbl_conf_level(conflvl)
  reps <- .rmbl_scalar(reps, "reps", 9, 1e6, integer = TRUE)
  p <- .rmbl_panel(data, unit, time, y)
  v <- .rmbl_colnames(trtd, "trtd")
  if (!v %in% names(data)) stop(sprintf("`trtd` (%s) is not a column of `data`", v), call. = FALSE)
  d <- as.numeric(data[[v]])
  if (anyNA(d) || !all(d %in% c(0, 1))) stop("`trtd` must be 0 or 1", call. = FALSE)
  .cl <- .rmbl_cluster(data, cl, p)
  if (is.list(.cl)) stop("`cl` names one column here", call. = FALSE)
  fes <- list(unit = p$u, time = as.integer(factor(p$t)))
  x <- cbind(treated = d, .rmbl_covariates(data, covs))
  xd <- .rmbl_demean(x, fes)
  yd <- as.vector(.rmbl_demean(p$y, fes))
  kfe <- .rmbl_k_fe(fes, .cl)
  n <- length(yd)
  gl <- sort(unique(.cl))
  G <- length(gl)
  gi <- match(.cl, gl)
  bread <- solve(crossprod(xd))
  kk <- ncol(xd) + kfe
  adj <- G / (G - 1) * (n - 1) / (n - kk)
  tstat <- function(yy, b0) {
    b <- bread %*% crossprod(xd, yy)
    e <- yy - xd %*% b
    s <- rowsum(xd * as.vector(e), gi)
    se <- sqrt((bread %*% crossprod(s) %*% bread)[1L, 1L] * adj)
    (b[1L] - b0) / se
  }
  t_obs <- tstat(yd, 0)
  b_hat <- (bread %*% crossprod(xd, yd))[1L]
  enumerate <- wtype == "rademacher" && 2^G <= reps
  vmat <- if (enumerate) {
    as.matrix(expand.grid(rep(list(c(-1, 1)), G)))
  } else {
    vals <- if (wtype == "webb") c(-sqrt(3 / 2), -1, -sqrt(1 / 2), sqrt(1 / 2), 1, sqrt(3 / 2)) else c(-1, 1)
    .rmbl_with_seed(seed, matrix(sample(vals, reps * G, replace = TRUE), reps, G))
  }
  xr <- xd[, -1L, drop = FALSE]
  pval <- function(b0) {
    y0 <- yd - b0 * xd[, 1L]
    fitr <- if (ncol(xr)) as.vector(xr %*% qr.coef(qr(xr), y0)) else numeric(n)
    ur <- y0 - fitr
    t0 <- tstat(yd, b0)
    ts <- apply(vmat, 1L, function(vv) tstat(fitr + b0 * xd[, 1L] + ur * vv[gi], b0))
    if (ties == "count") mean(abs(ts) >= abs(t0) - 1e-12) else mean(abs(ts) > abs(t0) + 1e-12)
  }
  pv <- pval(0)
  alpha <- 1 - conflvl
  se0 <- abs(b_hat / t_obs)
  find <- function(dir) {
    lo <- b_hat
    hi <- b_hat + dir * se0
    k <- 0
    while (pval(hi) > alpha && k < 12) {
      hi <- b_hat + dir * (abs(hi - b_hat) * 2)
      k <- k + 1
    }
    # no value is rejected however far out: the interval is unbounded on this side (with Rademacher
    # weights and G clusters the smallest p-value is 2 / 2^G, so with 4 clusters nothing is rejected
    # at 5%)
    if (pval(hi) > alpha) return(dir * Inf)
    for (i in 1:30) {
      mid <- (lo + hi) / 2
      if (pval(mid) > alpha) lo <- mid else hi <- mid
    }
    (lo + hi) / 2
  }
  # under enumeration the sign patterns +1 and -1 reproduce |t| exactly, so p is at least 2 / 2^G:
  # when that exceeds alpha no value can be rejected and the interval is the whole line
  unbounded <- ties == "count" && enumerate && 2 / nrow(vmat) > alpha
  out <- data.frame(estimate = b_hat, t = t_obs, p_value = pv, lower = if (unbounded) -Inf else find(-1),
                    upper = if (unbounded) Inf else find(1), clusters = G,
                    draws = nrow(vmat), enumerated = enumerate)
  class(out) <- c("rmbl_wild", "data.frame")
  out
}

# ---- sensitivity to parallel trends ----------------------------------------------------------------

#' How far parallel trends can fail before an effect disappears
#'
#' Bounds on the effects of an \code{\link{evstudy}} when the trend after adoption
#' may depart from parallel by up to \eqn{\bar M} times the largest departure seen
#' before it (Rambachan and Roth's relative magnitudes), with a conservative interval
#' and the "breakdown" \eqn{\bar M} at which the interval first includes zero.
#'
#' @details Let \eqn{\delta_e} be the bias of the event-time coefficient
#' \eqn{\beta_e}, with \eqn{\delta_{-1} = 0} at the reference period and the
#' pre-period biases identified by the leads. The relative-magnitudes restriction is
#' \eqn{|\delta_{e+1} - \delta_e| \le \bar M D}, with
#' \eqn{D = \max_{s < 0} |\delta_{s+1} - \delta_s|} the largest change between
#' consecutive pre-periods. The bias at post-period \eqn{e \ge 0} is then at most
#' \eqn{(e + 1)\bar M D} in absolute value, so the identified set for the effect
#' \eqn{\tau_e} is \eqn{\beta_e \pm (e + 1)\bar M D}, and for the average post-period
#' effect the average of those. The interval draws \eqn{(\beta^*)} from the normal
#' distribution of the estimates (with the event study's cluster-robust covariance),
#' computes the bounds for each, and takes the \eqn{\alpha/2} quantile of the lower
#' bound and the \eqn{1 - \alpha/2} quantile of the upper: by Bonferroni it covers the
#' identified set, and so the effect, with probability at least \code{conflvl}. It
#' is conservative; Rambachan and Roth's conditional and hybrid intervals (the
#' \code{HonestDiD} package) are shorter.
#'
#' @param x An \code{\link{evstudy}} result with one lead at least.
#' @param mbar The values of \eqn{\bar M} (default 0, 0.5, 1, 1.5, 2).
#' @param target \code{"average"} (the mean of the post-period effects, default) or an
#'   event time.
#' @param draws Normal draws for the interval (default 5000).
#' @param seed Optional seed.
#' @return A data frame of class \code{rmbl_sensitivity}: \code{mbar},
#'   \code{lowerbnd}, \code{upbound} (the identified set at the estimates),
#'   \code{lower}, \code{upper} (the interval); attribute \code{breakdown} (the
#'   smallest \eqn{\bar M} whose interval includes 0, found by bisection; \code{Inf}
#'   if none up to 10).
#' @references Rambachan A, Roth J (2023). A more credible approach to parallel
#'   trends. Review of Economic Studies 90(5):2555-2591. \doi{10.1093/restud/rdad018}
#' @examples
#' p <- polex()
#' es <- evstudy(p, "district", "month", "crmrate", "refmonth",
#'                   leads = 3, lags = 4)
#' tse(es, seed = 1)
#' @export
tse <- function(x, mbar = c(0, 0.5, 1, 1.5, 2), target = "average", draws = 5000L, seed = NULL) {
  if (!inherits(x, "rmbl_event_study") || is.null(attr(x, "vcov"))) {
    stop("`x` must come from evstudy()", call. = FALSE)
  }
  if (!is.numeric(mbar) || anyNA(mbar) || any(mbar < 0)) stop("`mbar` must be non-negative numbers", call. = FALSE)
  draws <- .rmbl_scalar(draws, "draws", 100, 1e6, integer = TRUE)
  et <- x$evtm
  ks <- et[x$se > 0]
  v <- attr(x, "vcov")
  b <- x$estimate[match(ks, et)]
  ref <- et[x$se == 0 & x$estimate == 0]
  pre <- sort(c(ks[ks < 0], ref))
  if (length(pre) < 2L) stop("need one lead at least besides the reference period", call. = FALSE)
  post <- ks[ks >= 0]
  if (!length(post)) stop("no post-period effect to bound", call. = FALSE)
  tgt <- post
  if (!identical(target, "average")) {
    tgt <- .rmbl_scalar(target, "target", integer = TRUE)
    if (!tgt %in% post) stop("`target` must be a post-period event time of `x`", call. = FALSE)
  }
  k <- mean(tgt + 1)
  # the bounds are linear in Mbar: centre -/+ Mbar * D * mean(e + 1), with D the largest pre-period change
  parts <- function(bmat) {
    full <- cbind(bmat, 0)
    colnames(full) <- c(ks, ref)
    pc <- full[, as.character(pre), drop = FALSE]
    list(centre = rowMeans(full[, as.character(tgt), drop = FALSE]),
         dmax = apply(abs(pc[, -1L, drop = FALSE] - pc[, -ncol(pc), drop = FALSE]), 1L, max))
  }
  bs <- .rmbl_with_seed(seed, {
    l <- chol(v + diag(1e-12, nrow(v)))
    matrix(stats::rnorm(draws * length(b)), draws) %*% l + matrix(b, draws, length(b), byrow = TRUE)
  })
  pt <- parts(matrix(b, 1L))
  dr <- parts(bs)
  one <- function(m) {
    c(pt$centre - m * pt$dmax * k, pt$centre + m * pt$dmax * k,
      stats::quantile(dr$centre - m * dr$dmax * k, 0.025, names = FALSE),
      stats::quantile(dr$centre + m * dr$dmax * k, 0.975, names = FALSE))
  }
  tab <- t(vapply(mbar, one, numeric(4L)))
  out <- data.frame(mbar = mbar, lowerbnd = tab[, 1L], upbound = tab[, 2L], lower = tab[, 3L], upper = tab[, 4L])
  # the interval only widens as Mbar grows, so the breakdown is found by bisection
  covers <- function(m) {
    r <- one(m)
    r[3L] <= 0 && r[4L] >= 0
  }
  bd <- if (covers(0)) 0 else Inf
  if (bd > 0 && covers(10)) {
    lo <- 0
    hi <- 10
    for (it in 1:40) {
      mid <- (lo + hi) / 2
      if (covers(mid)) hi <- mid else lo <- mid
    }
    bd <- hi
  }
  attr(out, "breakdown") <- bd
  attr(out, "target") <- target
  class(out) <- c("rmbl_sensitivity", "data.frame")
  out
}

#' @export
print.rmbl_sensitivity <- function(x, ...) {
  cat(sprintf("Sensitivity of the %s effect to departures from parallel trends (relative magnitudes)\n",
              if (identical(attr(x, "target"), "average")) "average post-period" else
                paste("event-time", attr(x, "target"))))
  print(format(as.data.frame(x), digits = 4L), row.names = FALSE)
  cat(sprintf("Breakdown: the interval first includes 0 at Mbar = %s\n", format(attr(x, "breakdown"))))
  invisible(x)
}

# ---- design-based power ----------------------------------------------------------------------------

#' Power and minimum detectable effect of a difference-in-differences design
#'
#' Simulates the design on real untreated data: assigns adoption at random to units
#' (or clusters) as the study would, adds an effect of known size, estimates
#' \code{\link{plndid}}, and counts rejections; so the serial correlation and the
#' clustering of the real data are carried, as formula-based power calculations do
#' not.
#'
#' @details In each replication, \code{ntrt} units (or clusters, with
#' \code{cl}) are drawn at random and given adoption dates drawn from
#' \code{adopt}; \code{effect} is added to their outcomes from adoption on; the
#' cluster-robust t test of \code{\link{plndid}} at level \code{alpha} is counted
#' as a rejection. With \code{effect = 0} the rejection rate is the test's actual size
#' on these data, which should be near \code{alpha}: a larger one means the errors are
#' understated (too few clusters, say), and the power figures are then optimistic too.
#' The minimum detectable effect is where the power curve crosses \code{power},
#' by linear interpolation (Burlig, Preonas and Woerman 2020).
#'
#' @inheritParams plndid
#' @param ntrt Units (or clusters) to treat in each replication.
#' @param adopt Adoption periods to draw from.
#' @param eff Effect sizes to try (default a grid from 0 to two standard
#'   deviations of the outcome).
#' @param reps Replications per effect size (default 200).
#' @param alpha Test level (default 0.05).
#' @param power For the minimum detectable effect (default 0.8).
#' @param seed Optional seed.
#' @return A data frame of class \code{rmbl_power}: \code{effect}, \code{power};
#'   attributes \code{mde} and \code{size} (the rejection rate at effect 0).
#' @references Burlig F, Preonas L, Woerman M (2020). Panel data and experimental
#'   design. Journal of Development Economics 144:102458.
#'   \doi{10.1016/j.jdeveco.2020.102458}
#' @examples
#' p <- polex()
#' pre <- p[p$month <= 12, ]
#' pw <- plnpwr(pre, "district", "month", "crmrate", ntrt = 10, adopt = 7:10,
#'                   eff = c(0, 1, 2, 3), reps = 30, seed = 1)
#' pw
#' plot(pw)
#' @export
plnpwr <- function(data, unit, time, y, ntrt, adopt, eff = NULL, cl = NULL,
                        reps = 200L, alpha = 0.05, power = 0.8, seed = NULL) {
  p <- .rmbl_panel(data, unit, time, y)
  reps <- .rmbl_scalar(reps, "reps", 10, 1e5, integer = TRUE)
  alpha <- .rmbl_scalar(alpha, "alpha", 1e-6, 0.5)
  power <- .rmbl_scalar(power, "power", 0.01, 0.999)
  adopt <- .rmbl_num(adopt, "adopt")
  if (!length(adopt) || anyNA(adopt)) stop("`adopt` must be periods", call. = FALSE)
  if (any(adopt <= min(p$tl) | adopt > max(p$tl))) {
    stop("`adopt` must leave a period before it and fall within the panel", call. = FALSE)
  }
  .cl <- .rmbl_cluster(data, cl, p)
  if (is.list(.cl)) stop("`cl` names one column here", call. = FALSE)
  ucl <- unique(.cl)
  ntrt <- .rmbl_scalar(ntrt, "ntrt", 1, length(ucl) - 1, integer = TRUE)
  if (is.null(eff)) eff <- seq(0, 2 * stats::sd(p$y), length.out = 6L)
  eff <- .rmbl_num(eff, "eff")
  sim <- function(.eff) {
    mean(vapply(seq_len(reps), function(r) {
      tr <- sample(ucl, ntrt)
      at <- stats::setNames(if (length(adopt) == 1L) rep(adopt, ntrt) else
        sample(adopt, ntrt, replace = TRUE), tr)
      a <- at[as.character(.cl)]
      dd <- data
      dd$.rmbl_d <- as.numeric(!is.na(a) & p$t >= a)
      dd[[y]] <- p$y + .eff * dd$.rmbl_d
      r1 <- tryCatch(plndid(dd, unit, time, y, ".rmbl_d", cl = cl), error = function(e) NULL)
      !is.null(r1) && is.finite(r1$p_value[1L]) && r1$p_value[1L] < alpha
    }, logical(1L)))
  }
  pw <- .rmbl_with_seed(seed, vapply(eff, sim, numeric(1L)))
  out <- data.frame(effect = eff, power = pw)
  mde <- NA_real_
  ok <- which(pw >= power)
  if (length(ok)) {
    i <- ok[1L]
    mde <- if (i == 1L) eff[1L] else
      eff[i - 1L] + (power - pw[i - 1L]) / (pw[i] - pw[i - 1L]) * (eff[i] - eff[i - 1L])
  }
  attr(out, "mde") <- mde
  attr(out, "size") <- if (0 %in% eff) pw[eff == 0][1L] else NA_real_
  attr(out, "alpha") <- alpha
  class(out) <- c("rmbl_power", "data.frame")
  out
}

#' @export
print.rmbl_power <- function(x, ...) {
  print(format(as.data.frame(x), digits = 3L), row.names = FALSE)
  if (is.finite(attr(x, "size"))) cat(sprintf("Size (rejections with no effect): %.3f at alpha %.3f\n", attr(x, "size"),
                                              attr(x, "alpha")))
  cat(sprintf("Minimum detectable effect at this power: %s\n",
              if (is.finite(attr(x, "mde"))) format(signif(attr(x, "mde"), 4)) else "beyond the effects tried"))
  invisible(x)
}

#' @rdname plot-methods
#' @export
plot.rmbl_power <- function(x, ..., main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_power")
  d <- as.data.frame(x)
  cl <- .bl_cols(1L, col, palette)
  graphics::plot(d$effect, d$power, type = "b", pch = 19, col = cl, ylim = c(0, 1), xlab = "Effect size",
                 ylab = "Power", main = "", ...)
  .bl_title(.bl_main(main, "Power of the design"))
  graphics::abline(h = 0.8, lty = 2, col = "#9A9A9A")
  if (is.finite(attr(x, "mde"))) graphics::abline(v = attr(x, "mde"), lty = 3, col = cl)
  invisible(d)
}

#' @param threshold For \code{rmbl_balance}: the absolute standardised difference
#'   drawn as the line of acceptable balance (default 0.1).
#' @param after For \code{rmbl_balance}: optionally a second \code{\link{baltab}}
#'   on the same covariates (after weighting or matching), drawn beside the first.
#' @rdname plot-methods
#' @export
plot.rmbl_balance <- function(x, ..., threshold = 0.1, after = NULL, main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_balance")
  threshold <- .rmbl_scalar(threshold, "threshold", 0)
  if (!is.null(after)) {
    .rmbl_plot_check(after, "rmbl_balance")
    if (!setequal(after$covariate, x$covariate)) stop("`after` must be on the same covariates as `x`", call. = FALSE)
  }
  o <- order(abs(x$smd), na.last = FALSE)
  cv <- x$covariate[o]
  b <- abs(x$smd[o])
  a <- if (is.null(after)) NULL else abs(after$smd[match(cv, after$covariate)])
  cl <- .bl_cols(2L, col, palette)
  k <- length(cv)
  lim <- c(0, max(c(b, a, threshold), na.rm = TRUE) * 1.08)
  op <- graphics::par(mar = c(4.5, max(4, min(16, max(nchar(cv)) * 0.55)), 3, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(b, seq_len(k), xlim = lim, ylim = c(0.5, k + 0.5), yaxt = "n", pch = 19, col = cl[1L],
                 xlab = "", ylab = "", main = "", ...)
  .bl_title(.bl_main(main, "Covariate balance"))
  .bl_xlab("Absolute standardised difference")
  .bl_row_labels(seq_len(k), cv, cex = 0.8)
  graphics::abline(h = seq_len(k), col = "#EEEEEE")
  graphics::abline(v = threshold, lty = 2, col = "#9A9A9A")
  if (!is.null(a)) {
    graphics::segments(b, seq_len(k), a, seq_len(k), col = "#BBBBBB")
    graphics::points(a, seq_len(k), pch = 17, col = cl[2L])
    graphics::legend(.bl_free_corner(c(b, a), c(seq_len(k), seq_len(k))), c("before", "after"),
                     pch = c(19, 17), col = cl, bty = "n", cex = 0.85)
  }
  graphics::points(b, seq_len(k), pch = 19, col = cl[1L])
  invisible(data.frame(covariate = cv, before = b, after = if (is.null(a)) NA_real_ else a))
}

#' @rdname plot-methods
#' @export
plot.rmbl_aipw <- function(x, ..., type = c("overlap", "estimate"), main = NULL, col = NULL, palette = NULL) {
  .rmbl_plot_check(x, "rmbl_aipw")
  type <- .rmbl_arg(type)
  cl <- .bl_cols(2L, col, palette)
  if (type == "estimate") {
    graphics::plot(x$estimate, 1, xlim = range(c(0, x$lower, x$upper)), ylim = c(0.5, 1.5), yaxt = "n", pch = 19,
                   col = cl[1L], xlab = sprintf("%s (%g%% confidence interval)", x$estimand,
                                                100 * attr(x, "conflvl")),
                   ylab = "", main = "", ...)
    .bl_title(.bl_main(main, "Cross-fitted AIPW estimate"))
    graphics::segments(x$lower, 1, x$upper, 1, lwd = 2, col = cl[1L])
    graphics::abline(v = 0, lty = 2, col = "#9A9A9A")
    return(invisible(as.data.frame(x)))
  }
  p <- attr(x, "propensity", exact = TRUE)
  if (is.null(p)) stop("this result has no propensities to draw; re-run aipwcf()", call. = FALSE)
  dens <- lapply(c(1, 0), function(arm) {
    s <- p[p$treated == arm, ]
    # the bandwidth from the unweighted values (density() picks it so anyway, with a warning)
    stats::density(s$propensity, bw = stats::bw.nrd0(s$propensity), weights = s$weight / sum(s$weight),
                   from = 0, to = 1, n = 256)
  })
  ymax <- max(dens[[1L]]$y, dens[[2L]]$y)
  graphics::plot(dens[[1L]]$x, dens[[1L]]$y, type = "n", xlim = c(0, 1), ylim = c(0, ymax * 1.05),
                 xlab = "Out-of-fold propensity", ylab = "Weighted density",
                 main = "", ...)
  .bl_title(.bl_main(main, "Overlap of the two groups"))
  for (i in 2:1) {
    graphics::polygon(c(0, dens[[i]]$x, 1), c(0, dens[[i]]$y, 0), border = cl[i],
                      col = grDevices::adjustcolor(cl[i], alpha.f = 0.25))
  }
  tr <- attr(x, "trim", exact = TRUE)
  if (is.null(tr)) tr <- 0.01
  graphics::abline(v = c(tr, 1 - tr), lty = 3, col = "#9A9A9A")
  graphics::legend(.bl_free_corner(c(dens[[1L]]$x, dens[[2L]]$x), c(dens[[1L]]$y, dens[[2L]]$y)),
                   c("treated", "untreated"), fill = grDevices::adjustcolor(cl, alpha.f = 0.25), border = cl,
                   bty = "n", cex = 0.85)
  invisible(data.frame(arm = rep(c("treated", "untreated"), each = 256L),
                       propensity = c(dens[[1L]]$x, dens[[2L]]$x), density = c(dens[[1L]]$y, dens[[2L]]$y)))
}

# ---- augmented inverse probability weighting, cross-fitted -----------------------------------------

#' Cross-fitted augmented inverse probability weighting for a binary treatment
#'
#' The average effect of a binary treatment (on everyone, or on the treated) from one
#' row per person, with the outcome and the propensity fitted by learners on other
#' folds, combined in the doubly robust (Neyman-orthogonal) score of Robins, Rotnitzky
#' and Zhao; with survey or sampling weights if given.
#'
#' @details With \eqn{\hat\mu_d(X)} the outcome fitted among those with treatment
#' \eqn{d} and \eqn{\hat e(X)} the propensity, both out of fold, the score for the
#' average effect is
#' \deqn{\psi = \hat\mu_1 - \hat\mu_0 + \frac{D (Y - \hat\mu_1)}{\hat e} - \frac{(1 - D)(Y -
#' \hat\mu_0)}{1 - \hat e} - \theta,}{psi = mu1 - mu0 + D (Y - mu1)/e - (1 - D)(Y -
#' mu0)/(1 - e) - theta,} and for the effect on the treated
#' \deqn{\psi = \frac{D (Y - \hat\mu_0) - \hat e (1 - D)(Y - \hat\mu_0)/(1 - \hat e)}{P(D =
#' 1)} - \frac{D}{P(D = 1)}\theta.}{psi = (D (Y - mu0) - e (1 - D)(Y - mu0)/(1 - e)) /
#' P(D = 1) - D theta / P(D = 1).} \eqn{\hat\theta} solves the weighted mean of the
#' score at zero; its variance is the weighted mean of \eqn{\psi^2} over \eqn{n}, the
#' influence-function variance of Chernozhukov et al. (2018). Propensities are clipped
#' to \code{[trim, 1 - trim]}. The estimator is consistent when either the outcome or
#' the propensity model is right, and with cross-fitting the learners can be flexible
#' (lasso or ridge on a second-order basis, or any learner function).
#'
#' The average effect equals \code{DoubleML}'s interactive regression model given the
#' same folds and learners; for the effect on the treated, \code{DoubleML} estimates
#' \eqn{P(D = 1)} within each fold and this function in the whole sample, so the two
#' differ slightly.
#'
#' The propensity learner is logistic regression on the covariates (with
#' \code{basis = "poly2"}, on their squares and products too). With \code{w}
#' the point estimate is design-weighted, but the standard error treats the weights as
#' fixed and the sample as independent.
#'
#' For a complex survey, pass the design from \code{\link{svydes}} instead: its
#' weight gives the point estimate and its replicate weights (or strata and primary
#' sampling units) the standard error, with the variance formula of the replicate
#' type, the confidence interval on the design's degrees of freedom. The learners are
#' fitted once, without the weights, which enter only the average of the scores, so
#' each replicate estimate is the replicate-weighted average of the same cross-fitted
#' scores: the same numbers as re-running the function on every replicate weight, from
#' one fit instead of one per replicate. Rows with a missing value are left out as a
#' domain (their scores count as zero in every replicate), not dropped from the design.
#'
#' @param data A data frame, one row per person.
#' @param y,trt Column names: the outcome and the 0/1 treatment.
#' @param covs Column names of the confounders (numeric; code categories as
#'   indicators).
#' @param estd \code{"ATE"} (default) or \code{"ATT"}.
#' @param lrn The outcome learner (as in \code{\link{plndml}}).
#' @param basis \code{"linear"} (default) or \code{"poly2"}.
#' @param w Optional column name of survey or sampling weights.
#' @param des Optional survey design from \code{\link{svydes}}, built on
#'   \code{data}, in place of \code{w}: the standard error then comes from its
#'   replicate weights or its strata and primary sampling units.
#' @param folds Cross-fitting folds (default 5).
#' @param trim Propensity clipping (default 0.01).
#' @param seed Seed for the folds (default 1).
#' @param conflvl Confidence level (default 0.95).
#' @return A data frame of class \code{rmbl_aipw}: \code{estimand}, \code{estimate},
#'   \code{se}, \code{lower}, \code{upper}, \code{p_value}; attributes \code{n},
#'   \code{treated}, \code{psrange}, \code{trimmed} (how many propensities
#'   were clipped), \code{variance} (\code{"influence"}, or the design's type) and
#'   \code{propensity} (a data frame of each row's out-of-fold propensity before
#'   clipping, its treatment and its weight, which \code{plot()} draws).
#' @references Robins JM, Rotnitzky A, Zhao LP (1994). Estimation of regression
#'   coefficients when some regressors are not always observed. Journal of the
#'   American Statistical Association 89(427):846-866.
#'   \doi{10.1080/01621459.1994.10476818}
#'
#' Chernozhukov V et al. (2018), see \code{\link{plndml}}.
#' @seealso \code{\link{plrcf}}, \code{\link{plndml}},
#'   \code{\link{baltab}}.
#' @examples
#' set.seed(2)
#' n <- 800
#' d <- data.frame(age = runif(n, 18, 70), income = rlnorm(n, 10, 0.5))
#' d$belong <- rbinom(n, 1, plogis(-2 + 0.03 * d$age + 0.2 * log(d$income)))
#' d$wellbeing <- 50 + 5 * d$belong + 0.2 * d$age + 2 * log(d$income) +
#'   rnorm(n, 0, 8)
#' aipwcf(d, "wellbeing", "belong", c("age", "income"), lrn = "ols")
#' # with 50 bootstrap replicate weights: one fit, the replicate standard error
#' d$w <- runif(n, 0.5, 2)
#' reps <- sapply(1:50, function(b) d$w * rpois(n, 1))
#' colnames(reps) <- paste0("bsw", 1:50)
#' d <- cbind(d, reps)
#' des <- svydes(d, w = "w", reps = colnames(reps))
#' aipwcf(d, "wellbeing", "belong", c("age", "income"), lrn = "ols",
#'               des = des)
#' @export
aipwcf <- function(data, y, trt, covs, estd = c("ATE", "ATT"), lrn = "lasso",
                          basis = c("linear", "poly2"), w = NULL, des = NULL, folds = 5L, trim = 0.01,
                          seed = 1L, conflvl = 0.95) {
  estd <- .rmbl_arg(estd)
  basis <- .rmbl_arg(basis)
  conflvl <- .rmbl_conf_level(conflvl)
  folds <- .rmbl_scalar(folds, "folds", 2, 100, integer = TRUE)
  trim <- .rmbl_scalar(trim, "trim", 0, 0.49)
  fit_fun <- .rmbl_learner(lrn)
  .rmbl_df_names(data)
  .y <- .rmbl_num(data[[.rmbl_colnames(y, "y")]], "y")
  d <- .rmbl_num(data[[.rmbl_colnames(trt, "trt")]], "trt")
  x <- .rmbl_covariates(data, covs)
  if (is.null(x)) stop("`covs` must name one column at least", call. = FALSE)
  if (!is.null(des)) {
    if (!inherits(des, "rmbl_svy_design")) stop("`des` must come from svydes()", call. = FALSE)
    if (!is.null(w)) stop("give `w` or `des`, not both", call. = FALSE)
    .svy_check_data(des, data)
    .w <- des$weights
  } else {
    .w <- .rmbl_weights(data, w)
  }
  ok <- is.finite(.y) & is.finite(d) & stats::complete.cases(x) & is.finite(.w)
  .y <- .y[ok]
  d <- d[ok]
  x <- x[ok, , drop = FALSE]
  .w <- .w[ok]
  if (!all(d %in% c(0, 1)) || length(unique(d)) < 2L) stop("`trt` must be 0 and 1", call. = FALSE)
  if (basis == "poly2") x <- .rmbl_poly2(x)
  n <- length(.y)
  if (min(sum(d), sum(1 - d)) < 2L * folds) stop("too few treated or untreated rows for the folds", call. = FALSE)
  f <- .rmbl_with_seed(seed, sample(rep_len(seq_len(folds), n)))
  m1 <- m0 <- e <- numeric(n)
  .rmbl_with_seed(seed + 1000L, {
    for (k in seq_len(folds)) {
      tr <- f != k
      te <- !tr
      t1 <- tr & d == 1
      t0 <- tr & d == 0
      m1[te] <- fit_fun(x[t1, , drop = FALSE], .y[t1], x[te, , drop = FALSE])
      m0[te] <- fit_fun(x[t0, , drop = FALSE], .y[t0], x[te, , drop = FALSE])
      g <- suppressWarnings(stats::glm.fit(cbind(1, x[tr, , drop = FALSE]), d[tr], family = stats::binomial()))
      b <- g$coefficients
      b[is.na(b)] <- 0
      e[te] <- stats::plogis(as.vector(cbind(1, x[te, , drop = FALSE]) %*% b))
    }
  })
  rng <- range(e)
  pr <- e
  nt <- sum(e < trim | e > 1 - trim)
  e <- pmin(pmax(e, trim), 1 - trim)
  sw <- sum(.w)
  if (estd == "ATE") {
    a <- m1 - m0 + d * (.y - m1) / e - (1 - d) * (.y - m0) / (1 - e)
    th <- sum(.w * a) / sw
    psi <- a - th
  } else {
    p1 <- sum(.w * d) / sw
    a <- (d * (.y - m0) - e * (1 - d) * (.y - m0) / (1 - e)) / p1
    th <- sum(.w * a) / sum(.w * d / p1)
    psi <- a - d / p1 * th
  }
  if (is.null(des)) {
    wn <- .w / mean(.w)
    se <- sqrt(sum((wn * psi)^2) / n^2)
  } else {
    # theta = sum(w num) / sum(w den) over the rows used; the other rows are outside the domain
    num <- den <- numeric(length(ok))
    num[ok] <- if (estd == "ATE") a else a * p1
    den[ok] <- if (estd == "ATE") 1 else d
    r <- .svy_core(des, cbind(num), cbind(den))
    se <- sqrt(r$V[1L, 1L])
    df <- .svy_df(des)
  }
  if (is.null(des) || !is.finite(df) || df <= 0) df <- Inf
  z <- stats::qt(1 - (1 - conflvl) / 2, df)
  out <- data.frame(estimand = estd, estimate = th, se = se, lower = th - z * se, upper = th + z * se,
                    p_value = 2 * stats::pt(-abs(th / se), df), stringsAsFactors = FALSE)
  attr(out, "n") <- n
  attr(out, "treated") <- sum(d)
  attr(out, "psrange") <- rng
  attr(out, "trimmed") <- nt
  attr(out, "conflvl") <- conflvl
  attr(out, "variance") <- if (is.null(des)) "influence" else des$type
  attr(out, "propensity") <- data.frame(propensity = pr, treated = d, weight = .w)
  attr(out, "trim") <- trim
  class(out) <- c("rmbl_aipw", "data.frame")
  out
}

#' @export
print.rmbl_aipw <- function(x, ...) {
  cat(sprintf("Cross-fitted AIPW, %s: %d rows, %d treated\n", x$estimand, attr(x, "n"), attr(x, "treated")))
  print(format(as.data.frame(x)[-1L], digits = 4L), row.names = FALSE)
  r <- attr(x, "psrange")
  cat(sprintf("Propensities from %.3f to %.3f; %d clipped\n", r[1L], r[2L], attr(x, "trimmed")))
  v <- attr(x, "variance")
  if (!is.null(v) && v != "influence") cat(sprintf("Standard error from the survey design (%s), one fit\n", v))
  invisible(x)
}
