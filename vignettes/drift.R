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
  value = rnorm(500),
  size  = runif(500, 1, 10),
  grade = sample(c("a", "b", "c"), 500, TRUE),
  stringsAsFactors = FALSE
)

current <- data.frame(
  value = rnorm(500),
  size  = runif(500, 1, 10),
  grade = sample(c("a", "b", "c"), 500, TRUE),
  stringsAsFactors = FALSE
)


## -----------------------------------------------------------------------------
dgstobj(reference) == dgstobj(current)


## -----------------------------------------------------------------------------
cpsdrft(reference, current)


## -----------------------------------------------------------------------------
moved <- current
moved$size <- moved$size * 3
moved$grade[1:200] <- "z"

cpsdrft(reference, moved)


## ----drift-plot, fig.width = 6, fig.height = 3.5------------------------------
d <- cpsdrft(reference, moved)
plot(d)


## ----drift-columns, fig.width = 7, fig.height = 3.5---------------------------
plot(d, what = "columns", cols = c("size", "grade"))


## ----drift-fingerprint, fig.width = 5, fig.height = 4.5-----------------------
plot(d, what = "fingerprint")


## ----drift-html---------------------------------------------------------------
f <- file.path(tempdir(), "drift.html")
drfthtml(d, f, title = "Pinned against fetched")
file.exists(f)


## -----------------------------------------------------------------------------
a <- data.frame(v = rnorm(80))
b <- data.frame(v = rnorm(80))

# Two draws from the SAME distribution.
cpsdrft(a, b)$columns[, c("p_value", "psi")]


## -----------------------------------------------------------------------------
x <- sample(c("p", "q", "r"), 300, TRUE)
y <- sample(c("p", "q", "r"), 300, TRUE)

# The homogeneity test is the more conservative, and the correct one here.
c(homogeneity = drfthomog(x, y)[["p_value"]],
  goooffit = drftchisq(y, x)[["p_value"]])


## -----------------------------------------------------------------------------
# A quantity spanning several orders of magnitude.
benfordtst(10^runif(2000, 0, 6))


## -----------------------------------------------------------------------------
# Leading digits drawn uniformly -- not what measurement looks like.
benfordtst(as.numeric(paste0(sample(1:9, 2000, TRUE), "000")))


## -----------------------------------------------------------------------------
schema <- infsch(reference)
schema


## -----------------------------------------------------------------------------
# It accepts the data it learned from.
length(valsch(reference, list(schema = schema)))

# And catches the rescaled column, which is now outside its pinned range.
issues <- valsch(moved, list(schema = schema))
issues[["rangesize"]]$message


## ----indigenous-drift---------------------------------------------------------
hi <- indiex("health")
a <- hi$estimate[hi$period == "2015/2018"]
b <- hi$estimate[hi$period == "2019/2022"]
drftks(a[is.finite(a)], b[is.finite(b)])

