## ----setup, include = FALSE---------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----sim----------------------------------------------------------------------
set.seed(42)
n <- 2000
sim <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
sim$d <- rbinom(n, 1, plogis(1.5 * sim$x1))
sim$y <- 2 * sim$d + 3 * sim$x1 + sim$x2 + rnorm(n)
mean(sim$y[sim$d == 1]) - mean(sim$y[sim$d == 0])   # biased by x1
fit <- plrcf(sim, "y", "d", c("x1", "x2"))
fit$ate
fit$ate + c(-1.96, 1.96) * fit$se


## ----nsw-load, eval = FALSE---------------------------------------------------
# tr <- dload("nsw_dw/treated")
# ct <- dload("nsw_dw/control")
# ps <- dload("nsw_dw/psid_controls")


## ----nsw-open, eval = FALSE---------------------------------------------------
# cols <- c("treat", "age", "educ", "black", "hisp", "married", "nodegree", "re74", "re75", "re78")
# nber <- function(f) {
#   dest <- file.path(tempdir(), f)
#   bldl(paste0("https://users.nber.org/~rdehejia/data/", f), dest)
#   stats::setNames(utils::read.table(dest), cols)
# }
# tr <- nber("nswre74_treated.txt")
# ct <- nber("nswre74_control.txt")
# ps <- nber("psid_controls.txt")


## ----nsw-fit, eval = FALSE----------------------------------------------------
# x <- c("age", "educ", "black", "hisp", "married", "nodegree", "re74", "re75")
# exp <- rbind(tr, ct)
# obs <- rbind(tr, ps)
# mean(tr$re78) - mean(ct$re78)                 # the experiment
# mean(tr$re78) - mean(ps$re78)                 # treated against the PSID, unadjusted
# plrcf(exp, "re78", "treat", x)
# plrcf(obs, "re78", "treat", x)
# plrcf(obs, "re78", "treat", x, kfol = 10, seed = 2)


## ----overlap-balance----------------------------------------------------------
set.seed(7)
n <- 1500
d <- data.frame(age = runif(n, 18, 70), income = rnorm(n))
d$t <- rbinom(n, 1, plogis(-2 + 0.04 * d$age + 0.5 * d$income))
d$y <- 10 + 3 * d$t + 0.2 * d$age + d$income + rnorm(n)
fit <- aipwcf(d, "y", "t", c("age", "income"), lrn = "ols")
fit
plot(fit)
plot(fit, type = "estimate")
pr <- attr(fit, "propensity")
e <- pmin(pmax(pr$propensity, 0.01), 0.99)
d$ipw <- ifelse(d$t == 1, 1 / e, 1 / (1 - e))
plot(baltab(d, "t", c("age", "income")),
     after = baltab(d, "t", c("age", "income"), w = "ipw"))


## ----indigenous-causal--------------------------------------------------------
hi <- indiex("health")
x <- hi[hi$period == "2019/2022" & hi$age == "Total, 18 years and over" &
          hi$indicator == "Perceived mental health, very good or excellent", ]
indgap(x, "group", "estimate", "lower", "upper", qual = "quality")[
  , c("group", "estimate", "refest", "difference", "diflo",
      "difup")]

