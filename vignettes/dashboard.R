## ----setup, include = FALSE---------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 4, dpi = 72)
library(rmoriebricklayer)


## -----------------------------------------------------------------------------
rmbldemo()


## -----------------------------------------------------------------------------
court <- rmbldemo("court")
plndid(court, unit = "court", time = "month", y = "delay", trtd = "reformed")


## -----------------------------------------------------------------------------
wait <- rmbldemo("waits")$days
fit <- dstfit(wait, nboot = 50)
fit$table[, c("rank", "family", "aic", "ks")]
plot(fit, which = "qq", fams = c("gamma", "weibull"))


## -----------------------------------------------------------------------------
led <- ldgrread(system.file("extdata", "ledger_sample.json", package = "rmoriebricklayer"))
led
ldgrchk(led)[, c("check", "ok", "severity")]

