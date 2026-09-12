# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Missingness that is not random is the failure mode that quietly
# invalidates a capsule. Dropping incomplete rows is unbiased only when
# the data are missing completely at random; when they are not, complete
# cases are a biased sample and every downstream estimate inherits the
# bias. Little's test asks whether the MCAR assumption is tenable, which
# requires maximum-likelihood estimates of the mean and covariance under
# missingness -- and those require EM, since the likelihood has no
# closed form once the pattern of observation varies by row.

# ML estimates of a multivariate normal mean and covariance from data
# with missing entries, by expectation-maximisation (Dempster, Laird &
# Rubin 1977; the MVN case is Little & Rubin 2002 ch. 11).
#
# E-step: for each row, the missing entries are replaced by their
#   conditional expectation given the observed ones, and the conditional
#   COVARIANCE of those entries is accumulated separately. Imputing the
#   conditional mean alone and then taking a sample covariance is the
#   classic error -- it understates the variance, because it treats an
#   estimate as if it were an observation.
# M-step: the completed first and second moments give the next estimates.
#
# Returns the estimates plus the iteration count, or NULL when the
# problem is degenerate.
.rmbl_em_mvn <- function(X, max_iter = 500L, tol = 1e-7, ridge = 1e-8) {
  n <- nrow(X)
  p <- ncol(X)
  obs <- !is.na(X)

  # Start from the pairwise-complete moments, which is a consistent
  # starting point even when no row is complete.
  mu <- vapply(seq_len(p), function(j) mean(X[obs[, j], j]), numeric(1))
  if (anyNA(mu)) return(NULL)
  S <- stats::cov(X, use = "pairwise.complete.obs")
  S[!is.finite(S)] <- 0
  diag(S) <- ifelse(is.finite(diag(S)) & diag(S) > 0, diag(S), 1)
  S <- .rmbl_make_pd(S, ridge)

  solve_safe <- function(M) {
    tryCatch(solve(M), error = function(e) {
      tryCatch(solve(M + diag(ridge * max(1, mean(diag(M))), nrow(M))),
               error = function(e2) NULL)
    })
  }

  iter <- 0L
  for (it in seq_len(max_iter)) {
    iter <- it
    T1 <- numeric(p)              # accumulated first moments
    T2 <- matrix(0, p, p)         # accumulated second moments
    for (i in seq_len(n)) {
      o <- which(obs[i, ])
      m <- which(!obs[i, ])
      xi <- numeric(p)
      Ci <- matrix(0, p, p)
      if (length(o) == p) {
        xi <- X[i, ]
      } else if (length(o) == 0L) {
        # a row with nothing observed contributes only the prior
        xi <- mu
        Ci <- S
      } else {
        Soo_inv <- solve_safe(S[o, o, drop = FALSE])
        if (is.null(Soo_inv)) return(NULL)
        B <- S[m, o, drop = FALSE] %*% Soo_inv
        xi[o] <- X[i, o]
        xi[m] <- mu[m] + as.numeric(B %*% (X[i, o] - mu[o]))
        # the conditional covariance of the imputed block
        Ci[m, m] <- S[m, m, drop = FALSE] -
          B %*% S[o, m, drop = FALSE]
      }
      T1 <- T1 + xi
      T2 <- T2 + outer(xi, xi) + Ci
    }
    mu_new <- T1 / n
    S_new <- T2 / n - outer(mu_new, mu_new)
    S_new <- (S_new + t(S_new)) / 2          # keep it exactly symmetric
    S_new <- .rmbl_make_pd(S_new, ridge)

    delta <- max(max(abs(mu_new - mu)), max(abs(S_new - S)))
    mu <- mu_new
    S <- S_new
    if (is.finite(delta) && delta < tol) break
  }
  list(mu = mu, sigma = S, iterations = iter)
}

# Nudge a symmetric matrix to positive definiteness by flooring its
# eigenvalues. EM can land on a numerically indefinite estimate on the
# way to convergence, and inverting that would end the run.
.rmbl_make_pd <- function(S, ridge = 1e-8) {
  S <- (S + t(S)) / 2
  ev <- tryCatch(eigen(S, symmetric = TRUE), error = function(e) NULL)
  if (is.null(ev)) return(S + diag(ridge, nrow(S)))
  floor_val <- ridge * max(1, max(abs(ev$values)))
  if (min(ev$values) >= floor_val) return(S)
  vals <- pmax(ev$values, floor_val)
  ev$vectors %*% diag(vals, length(vals)) %*% t(ev$vectors)
}

#' Little's test for data missing completely at random
#'
#' Tests the MCAR assumption: that whether a value is missing is
#' unrelated to any value in the data, observed or not.
#'
#' The assumption matters because it is what licenses the easy options.
#' Dropping incomplete rows is unbiased under MCAR and biased otherwise;
#' mean imputation understates variance under MCAR and distorts the
#' centre as well otherwise. A small p-value here says the easy options
#' are not available.
#'
#' # How it works
#'
#' Rows are grouped by their pattern of missingness. If missingness is
#' unrelated to the values, then each pattern's observed-variable means
#' should agree with the overall estimates, up to sampling error. The
#' statistic sums those disagreements,
#' \deqn{d^2 = \sum_j n_j (\bar{x}_j - \hat{\mu}_j)'
#'   \hat{\Sigma}_j^{-1} (\bar{x}_j - \hat{\mu}_j),}
#' over the variables observed in pattern \eqn{j}, and is compared with a
#' chi-square distribution on \eqn{\sum_j p_j - p} degrees of freedom.
#'
#' The overall \eqn{\hat\mu} and \eqn{\hat\Sigma} are the
#' MAXIMUM-LIKELIHOOD estimates under multivariate normality WITH the
#' missing data, obtained by expectation-maximisation -- not the
#' complete-case estimates, which would already embed the bias the test
#' is looking for.
#'
#' # What it cannot do
#'
#' A large p-value is NOT evidence that the data are MCAR; it is a
#' failure to detect a departure, and the test has little power on small
#' samples or with many patterns. The test also assumes multivariate
#' normality, so on markedly non-normal columns a rejection may be
#' telling you about the distribution rather than the missingness.
#'
#' Neither this test nor any other can distinguish missing-at-random from
#' missing-NOT-at-random, because that distinction depends on the values
#' that were never observed. Only knowledge of how the data were
#' collected settles it.
#'
#' @param data A data frame or numeric matrix. Non-numeric columns are
#'   dropped with a warning, since the statistic is defined on moments.
#' @param max_iter Maximum EM iterations (default 500).
#' @param tol Convergence tolerance on the largest parameter change
#'   (default 1e-7).
#' @return A list of class `bricklayer_mcar`: `statistic`, `df`,
#'   `p_value`, `n_patterns`, `n_used`, `n_vars`, `iterations`,
#'   `mu`, `sigma`, and `note` (a caveat when the test is degenerate).
#'   With complete data `df` is 0 and `p_value` is `NA` -- there is
#'   nothing to test.
#' @references Little RJA (1988). A test of missing completely at random
#'   for multivariate data with missing values. *Journal of the American
#'   Statistical Association* 83(404), 1198--1202.
#'   \doi{10.1080/01621459.1988.10478722}
#'
#'   Dempster AP, Laird NM, Rubin DB (1977). Maximum likelihood from
#'   incomplete data via the EM algorithm. *Journal of the Royal
#'   Statistical Society B* 39(1), 1--38.
#' @seealso [missingness_pattern()] for the patterns themselves,
#'   [missingness_summary()] for the rates.
#' @examples
#' set.seed(1)
#' n <- 300
#' x <- stats::rnorm(n)
#' y <- x + stats::rnorm(n)
#'
#' # Missing completely at random: a coin flip decides, so the test
#' # should not reject.
#' mcar <- data.frame(x = x, y = y)
#' mcar$y[sample(n, 90)] <- NA
#' mcar_test(mcar)
#'
#' # Missing depending on the OTHER, observed variable: not MCAR, and
#' # detectable, because the pattern's mean of x is shifted.
#' mar <- data.frame(x = x, y = y)
#' mar$y[x > 0.4] <- NA
#' mcar_test(mar)
#'
#' # Complete data has one pattern and nothing to test.
#' mcar_test(data.frame(a = x, b = y))$df
#'
#' # The EM estimates are the ML ones: with no missingness they are the
#' # column means and the ML (1/n) covariance.
#' fit <- mcar_test(data.frame(a = x, b = y))
#' all.equal(fit$mu, c(mean(x), mean(y)), check.attributes = FALSE)
#' @export
mcar_test <- function(data, max_iter = 500L, tol = 1e-7) {
  if (is.matrix(data)) data <- as.data.frame(data)
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame or a numeric matrix", call. = FALSE)
  }
  num <- vapply(data, is.numeric, logical(1))
  if (!all(num)) {
    dropped <- names(data)[!num]
    warning(sprintf("dropping non-numeric column(s): %s",
                    paste(dropped, collapse = ", ")), call. = FALSE)
    data <- data[, num, drop = FALSE]
  }
  if (ncol(data) < 2L) {
    stop("Little's test needs at least two numeric columns", call. = FALSE)
  }

  X <- as.matrix(data)
  storage.mode(X) <- "double"
  # A wholly missing column carries no information and makes every
  # pattern's submatrix singular.
  all_na_col <- apply(is.na(X), 2L, all)
  if (any(all_na_col)) X <- X[, !all_na_col, drop = FALSE]
  # A wholly missing row belongs to no pattern with observed variables.
  keep_row <- !apply(is.na(X), 1L, all)
  X <- X[keep_row, , drop = FALSE]

  n <- nrow(X)
  p <- ncol(X)
  if (p < 2L || n < 2L) {
    stop("too few complete columns or rows remain for Little's test",
         call. = FALSE)
  }

  fit <- .rmbl_em_mvn(X, max_iter = max_iter, tol = tol)
  if (is.null(fit)) {
    stop("the EM estimates did not converge to a usable covariance: the ",
         "columns may be collinear, or a pattern may have too few rows",
         call. = FALSE)
  }

  obs <- !is.na(X)
  codes <- apply(obs, 1L, function(r) paste0(as.integer(r), collapse = ""))
  patterns <- unique(codes)

  d2 <- 0
  df_sum <- 0
  used <- 0L
  skipped <- 0L
  for (code in patterns) {
    rows <- which(codes == code)
    o <- which(obs[rows[1L], ])
    pj <- length(o)
    if (pj == 0L) next
    nj <- length(rows)
    # The pattern's observed-variable means, against the ML estimates.
    xbar <- colMeans(X[rows, o, drop = FALSE])
    diff <- xbar - fit$mu[o]
    Sj <- fit$sigma[o, o, drop = FALSE]
    Sj_inv <- tryCatch(solve(Sj), error = function(e) NULL)
    if (is.null(Sj_inv)) {
      skipped <- skipped + 1L
      next
    }
    d2 <- d2 + nj * as.numeric(t(diff) %*% Sj_inv %*% diff)
    df_sum <- df_sum + pj
    used <- used + nj
  }

  df <- df_sum - p
  note <- NA_character_
  if (df <= 0) {
    note <- paste0("df is ", df, ": with a single missingness pattern there ",
                   "is nothing to test. A complete table trivially ",
                   "satisfies MCAR.")
  }
  if (skipped > 0L) {
    note <- paste(stats::na.omit(c(note, sprintf(
      "%d pattern(s) were skipped: their observed variables were collinear.",
      skipped))), collapse = " ")
  }
  out <- list(statistic = d2,
              df = df,
              p_value = if (df > 0) {
                1 - core_gamma_cdf(df / 2, d2 / 2)
              } else {
                NA_real_
              },
              n_patterns = length(patterns),
              n_used = used,
              n_vars = p,
              iterations = fit$iterations,
              mu = stats::setNames(fit$mu, colnames(X)),
              sigma = fit$sigma,
              note = note)
  class(out) <- c("bricklayer_mcar", "list")
  out
}

#' @export
format.bricklayer_mcar <- function(x, ...) {
  g <- .rmbl_glyphs()
  verdict <- if (is.na(x$p_value)) {
    paste0(g$warn, " no test possible")
  } else if (x$p_value < 0.05) {
    paste0(g$bad, " MCAR rejected: the missingness is related to the data")
  } else {
    paste0(g$ok, " no departure from MCAR detected")
  }
  lines <- c(.rmbl_rule("Little's MCAR test"),
             paste0("  ", verdict),
             "",
             .rmbl_kv(list(
               statistic = formatC(x$statistic, format = "f", digits = 3),
               df = x$df,
               "p-value" = .rmbl_fmt_p(x$p_value),
               patterns = x$n_patterns,
               variables = x$n_vars,
               "rows used" = x$n_used,
               "EM iterations" = x$iterations)))
  if (!is.na(x$note)) {
    lines <- c(lines, "", paste0("  ", g$warn, " ", x$note))
  }
  if (!is.na(x$p_value) && x$p_value >= 0.05) {
    lines <- c(lines, "",
               paste0("  Not evidence OF MCAR: a large p-value is a failure ",
                      "to detect a"),
               "  departure, and this test has little power on small samples.")
  }
  c(lines, .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_mcar <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}
