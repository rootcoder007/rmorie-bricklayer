## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----mk-----------------------------------------------------------------------
y <- c(402, 377, 190, 268, 331)        # five years of placements
trndtst(y)


## ----mk-mono------------------------------------------------------------------
trndtst(c(1, 2, 3, 4, 5))


## ----mk-outlier---------------------------------------------------------------
trndtst(c(100, 100, 100, 100, 900))$p_value


## ----mk-df--------------------------------------------------------------------
d <- data.frame(year = 2019:2023, n = y)
trndtst(d, value = "n", prd = "year")$slope
trndtst(d, value = "n", prd = "year", alt = "decreasing")$p_value


## ----poisson------------------------------------------------------------------
set.seed(3)
y <- stats::rpois(8, lambda = 200 * 0.85^(0:7))   # falling ~15% a year
fit <- cnttrnd(y)
round(fit$rateratio, 3)


## ----offset-------------------------------------------------------------------
cnttrnd(c(20, 25, 30), offset = c(1000, 1500, 2500))$rateratio


## ----step---------------------------------------------------------------------
stepchg(c(100, 104, 98, 60, 63, 58))


## ----step-noise---------------------------------------------------------------
set.seed(2)
stepchg(stats::rnorm(12))$p_value


## ----two-periods--------------------------------------------------------------
h <- indiex("health")
h <- h[h$age == "Total, 18 years and over" &
         h$indicator == "Perceived mental health, very good or excellent", ]
healchg(h, "group", "indicator", "period", "estimate", "lower", "upper",
               from = "2015/2018", to = "2019/2022", qual = "quality")


## ----trc-pace-----------------------------------------------------------------
trcprog()


## ----trend-plot, fig.width = 7, fig.height = 4.5------------------------------
plot(fit)

