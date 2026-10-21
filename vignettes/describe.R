## ----setup, include = FALSE---------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)
set.seed(1)


## -----------------------------------------------------------------------------
reference <- data.frame(
  id = 1:300,
  score = stats::runif(300, 0, 10),
  grade = sample(c("a", "b", "c"), 300, TRUE),
  stringsAsFactors = FALSE
)

fresh <- reference
fresh$score <- stats::runif(300, 0, 10)

cpsrpt(fresh, ref = reference,
               schema = infsch(reference))


## -----------------------------------------------------------------------------
broken <- fresh
broken$score <- broken$score * 5
broken$grade[1:100] <- "z"
broken$dead <- NA_real_
broken$flat <- 7

report <- cpsrpt(broken, ref = reference,
                         schema = infsch(reference))
report


## -----------------------------------------------------------------------------
report$verdict
summary(report)


## -----------------------------------------------------------------------------
cat(head(rptmd(report), 12), sep = "\n")


## -----------------------------------------------------------------------------
messy <- data.frame(
  clean = stats::rnorm(200),
  bimodal = c(stats::rnorm(100, -3), stats::rnorm(100, 3)),
  skewed = c(stats::rexp(199), 500),
  zeros = c(rep(0, 50), stats::runif(150))
)
profcols(messy)[, c("column", "mean", "median", "sd", "mad")]


## -----------------------------------------------------------------------------
profcols(messy)[, c("column", "hist")]


## -----------------------------------------------------------------------------
structural <- data.frame(
  id = 1:20,
  a = c(rep(NA, 6), 7:20),
  b = c(rep(NA, 6), 7:20)
)
scattered <- data.frame(
  id = 1:20,
  a = c(rep(NA, 6), 7:20),
  b = c(1:14, rep(NA, 6))
)

c(structural = sum(is.na(structural$a)), scattered = sum(is.na(scattered$a)))


## -----------------------------------------------------------------------------
misspat(structural)


## -----------------------------------------------------------------------------
misspat(scattered)


## -----------------------------------------------------------------------------
missruns(data.frame(
  outage = c(1, 2, rep(NA, 8), 11:20),
  sporadic = c(1, NA, 3, NA, 5, NA, 7:20)
), minrun = 2)


## -----------------------------------------------------------------------------
gappy <- data.frame(
  complete = 1:100,
  early = c(rep(NA, 30), 31:100),
  random = ifelse(stats::runif(100) < 0.3, NA, 1),
  late = c(1:70, rep(NA, 30))
)
missgrid(gappy, height = 10)


## -----------------------------------------------------------------------------
n <- 400
x <- stats::rnorm(n)
y <- x + stats::rnorm(n)

# Missing on a coin flip: nothing to find.
mcar <- data.frame(x = x, y = y)
mcar$y[sample(n, 120)] <- NA
mcartst(mcar)


## -----------------------------------------------------------------------------
# Missing whenever x is large: the complete cases are a biased sample,
# and that is detectable because the pattern's mean of x is shifted.
mar <- data.frame(x = x, y = y)
mar$y[x > 0.4] <- NA
mcartst(mar)


## -----------------------------------------------------------------------------
people <- data.frame(heightcm = stats::rnorm(300, 170, 10))
people$weightkg <- people$heightcm * 0.5 + stats::rnorm(300, 0, 5)

# Inside both marginal ranges, outside the cloud.
people[1, ] <- list(heightcm = 150, weightkg = 140)

range(people$heightcm)
range(people$weightkg)


## -----------------------------------------------------------------------------
head(mahaoutl(people), 3)


## -----------------------------------------------------------------------------
many <- people
many[1:8, ] <- list(heightcm = rep(150, 8), weightkg = rep(140, 8))

c(robust = mahaoutl(many, robust = TRUE)$distance[1],
  classical = mahaoutl(many, robust = FALSE)$distance[1])


## -----------------------------------------------------------------------------
benfordtst(10^stats::runif(2000, 0, 6))


## -----------------------------------------------------------------------------
benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))


## ----indigenous-describe------------------------------------------------------
hi <- indiex("health")
profcols(hi[, c("estimate", "lower", "upper")])
table(hi$quality, useNA = "ifany")


## ----describe-plots, fig.width = 7, fig.height = 5----------------------------
op <- par(mfrow = c(2, 2), mar = c(4, 4, 2, 1))
for (nm in names(messy)) {
  x <- messy[[nm]]
  if (nm == "skewed") {
    hist(log10(x), breaks = 30, col = blpal()[2], main = "skewed (log10 scale)", xlab = "log10(value)")
  } else {
    hist(x, breaks = 30, col = blpal()[2], main = nm, xlab = "value")
  }
}
par(op)
plotecdf(c(reference$score, fresh$score),
         rep(c("reference", "fresh"), c(nrow(reference), nrow(fresh))),
         main = "Fresh scores against the reference")

