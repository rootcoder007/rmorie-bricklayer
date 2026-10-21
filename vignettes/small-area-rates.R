## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 3.8)
library(rmoriebricklayer)


## ----expected-----------------------------------------------------------------
d <- data.frame(
  region = rep(c("North", "South", "East"), each = 2),
  age = rep(c("18 to 24", "25 to 49"), 3),
  n = c(30, 45, 12, 60, 8, 20),
  pop = c(1000, 6000, 900, 9000, 400, 3500)
)
expcnts(d$n, d$pop, d$region)


## ----expected-strata----------------------------------------------------------
expcnts(d$n, d$pop, d$region, strata = d$age)


## ----direct-------------------------------------------------------------------
r <- agestd(events = c(4, 9, 11, 6, 3, 40, 70, 90, 80, 60),
                     pop = c(9000, 8000, 6000, 4000, 2000, 300000, 320000, 350000, 340000, 300000),
                     std = c(30, 25, 20, 15, 10),
                     grp = rep(c("Inuit", "Non-Indigenous"), each = 5))
r
rategap(r, "Inuit", "Non-Indigenous")


## ----sir----------------------------------------------------------------------
stdinc(obs = c(30, 12, 3), expd = c(20, 14, 5),
    area = c("North", "South", "East"))


## ----sir3---------------------------------------------------------------------
stdinc(3, 5)


## ----eb-----------------------------------------------------------------------
ebrates(obs = c(30, 45, 2), expd = c(25, 50, 0.5),
         area = c("North", "South", "Tiny"))


## ----funnel-------------------------------------------------------------------
fnllim(c(2, 20, 200))


## ----funnel-plot--------------------------------------------------------------
e <- seq(2, 200, length.out = 60)
lim <- fnllim(e)
plot(e, lim$upper_95, type = "l", ylim = c(0, 3), xlab = "expected count",
     ylab = "observed / expected", main = "Funnel limits")
lines(e, lim$lower_95)
lines(e, lim$upper_998, lty = 2)
lines(e, lim$lower_998, lty = 2)
abline(h = 1, col = "grey")
points(c(20, 14, 5), c(30, 12, 3) / c(20, 14, 5), pch = 19, col = 2)


## ----moran--------------------------------------------------------------------
nb <- list(2L, c(1L, 3L), c(2L, 4L), c(3L, 5L), c(4L, 6L), 5L)   # six areas in a line

set.seed(1)
morani(c(1, 2, 3, 4, 5, 6), nb, nperm = 999L)[c("I", "p_value")]   # a gradient

set.seed(1)
morani(c(1, 6, 1, 6, 1, 6), nb, nperm = 999L)[c("I", "p_value")]   # alternating


## ----moran-null---------------------------------------------------------------
-1 / (6 - 1)

