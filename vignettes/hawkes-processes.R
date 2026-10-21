## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 3.5)
library(rmoriebricklayer)


## ----simulate-----------------------------------------------------------------
simhwk <- function(mu, alpha, beta, horizon, seed = 1) {
  set.seed(seed)
  t <- 0
  events <- numeric(0)
  while (t < horizon) {
    lambdamax <- mu + alpha * beta * sum(exp(-beta * (t - events)))
    t <- t + stats::rexp(1, lambdamax)
    if (t >= horizon) break
    lambdat <- mu + alpha * beta * sum(exp(-beta * (t - events)))
    if (stats::runif(1) <= lambdat / lambdamax) events <- c(events, t)
  }
  events
}
times <- simhwk(mu = 1, alpha = 0.5, beta = 2, horizon = 300)
length(times)


## ----fit----------------------------------------------------------------------
fit <- chwkfit(times, hor = 300, kernel = "exponential")
fit$theta
fit$braratio


## ----kernels------------------------------------------------------------------
sapply(c("exponential", "weibull", "lomax"), function(k) {
  chwkfit(times, 300, kernel = k)$aic
})


## ----sinus--------------------------------------------------------------------
chwkfit(times, 300, kernel = "exponential", base = "sinusoidal")$aic


## ----residuals----------------------------------------------------------------
U <- chwkres(times, 300, "exponential", fit$theta)
stats::ks.test(U, "punif")$p.value


## ----qq-----------------------------------------------------------------------
plot(stats::qunif(stats::ppoints(length(U))), sort(U), pch = 20, cex = .6,
     xlab = "uniform quantiles", ylab = "rescaled residuals",
     main = "Time-rescaling check")
abline(0, 1, col = 2)


## ----jitter-------------------------------------------------------------------
days <- c(0, 0, 0, 1, 3, 3)
chwkjit(days)
anyDuplicated(chwkjit(days))


## ----nll----------------------------------------------------------------------
chwknll(times, 300, "exponential", fit$theta)
chwknll(times, 300, "exponential", fit$theta * 1.5)

