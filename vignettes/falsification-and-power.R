## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----falsify------------------------------------------------------------------
set.seed(1)
d <- data.frame(x = rnorm(200))
d$y <- 0.8 * d$x + rnorm(200)

real <- cpsfals(d, function(z) cor(z$x, z$y), trt = "x", n = 199, seed = 42)
real$controls[, c("control", "passed")]


## ----falsify-fake-------------------------------------------------------------
fake <- cpsfals(d, function(z) 0.5, trt = "x", n = 199, seed = 42)
fake$controls[fake$controls$control == "permutation", "passed"]


## ----power--------------------------------------------------------------------
set.seed(1)
d <- data.frame(x = rnorm(120), y = rnorm(120))
inj <- function(z, size) {
  z$y <- z$y + size * z$x
  z
}

pw <- cpspwr(d, function(z) cor(z$x, z$y), inj,
                    sizes = c(0, 0.3, 0.6), trt = "x",
                    n = 99, reps = 5, seed = 42)
pw$curve


## ----power-zero---------------------------------------------------------------
pw$curve[pw$curve$size == 0, "rate"]


## ----family-------------------------------------------------------------------
set.seed(1)
d <- data.frame(x = rnorm(150))
d$y <- 0.6 * d$x + rnorm(150)
d$a <- rnorm(150)
d$b <- rnorm(150)
fam <- list(
  real    = cpsfals(d, function(z) cor(z$x, z$y), trt = "x", n = 199, seed = 1),
  noisea = cpsfals(d, function(z) cor(z$a, z$y), trt = "a", n = 199, seed = 2),
  noiseb = cpsfals(d, function(z) cor(z$b, z$y), trt = "b", n = 199, seed = 3)
)
falsfam(fam)


## ----family-p-----------------------------------------------------------------
falsfam(c(a = 0.01, b = 0.04, c = 0.2, d = 0.5))$results


## ----evalue-------------------------------------------------------------------
evlrr(2)                       # needs a confounder associated by 3.41 with both
evlrr(0.5)                     # a protective effect is inverted; same answer
evlrr(2, lo = 0.9, hi = 4.4)   # an interval that includes the null needs nothing
evlrr(3, lo = 2.1, hi = 4.3)   # a strong result with a limit well above the null


## ----indigenous-falsify-------------------------------------------------------
hi <- indiex("health")
s <- hi[hi$period == "2019/2022" & hi$age == "Total, 18 years and over" &
          hi$quality == "ok", ]
fn <- s[s$group == "First Nations", ]
ni <- s[s$group == "Non-Indigenous", ]
both <- merge(fn, ni, by = "indicator", suffixes = c("fn", "ni"))
se <- function(l, u) (u - l) / (2 * 1.96)
z <- (both$estimatefn - both$estimateni) /
  sqrt(se(both$lowerfn, both$upperfn)^2 + se(both$lowerni, both$upperni)^2)
p <- stats::setNames(2 * stats::pnorm(-abs(z)), both$indicator)
res <- falsfam(p, meth = "holm")
head(res)


## ----falsification-plots, fig.width = 7, fig.height = 4.5---------------------
plot(real)
plot(fake)
plot(pw)

