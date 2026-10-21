## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 4, dpi = 72)
library(rmoriebricklayer)


## ----data---------------------------------------------------------------------
p <- polex()
head(p)


## ----did----------------------------------------------------------------------
plndid(p, "district", "month", "crmrate", "reformed")


## ----trends, fig.height = 3.5-------------------------------------------------
plot(cohtrnd(p, "district", "month", "crmrate", "refmonth", win = c(-10, 10)))


## ----event, fig.height = 3.5--------------------------------------------------
es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 4, lags = 6)
es
plot(es)


## ----bacon, fig.height = 3.5--------------------------------------------------
b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
tapply(b$weight, b$type, sum)
plot(b)


## ----cs, fig.height = 3.5-----------------------------------------------------
s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 99, seed = 1)
s$overall
plot(s)


## ----switching----------------------------------------------------------------
swtdid(p, "district", "month", "crmrate", "reformed", reps = 99, seed = 1)


## ----perm, fig.height = 3-----------------------------------------------------
r <- perminf(p, "district", "month", c("crmrate", "arrrate"), "refmonth",
                           cl = "region")
r
plot(r, type = "histogram")


## ----loo, fig.height = 3.5----------------------------------------------------
plot(loounit(p, "district", "month", "crmrate", "reformed"))


## ----grid, fig.height = 3.5---------------------------------------------------
plotevgrid(list(
  "Crime rate" = es,
  "Arrest rate" = evstudy(p, "district", "month", "arrrate", "refmonth", leads = 4,
                              lags = 6)), style = "stata")


## ----pois---------------------------------------------------------------------
plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop")


## ----synth, fig.height = 3.5--------------------------------------------------
p13 <- p[is.na(p$refmonth) | p$district == "D13", ]
sc <- synctl(p13, "district", "month", "crmrate", "D13", adopt = 13)
sc
plot(sc)


## ----measures-----------------------------------------------------------------
d <- data.frame(city = rep(c("A", "B"), each = 3), year = 2024,
                offence = rep(c("homicide", "robbery", "burglary"), 2),
                n = c(5, 120, 300, 2, 90, 410), pop = rep(c(250000, 180000), each = 3))
sevidx(d, "city", "year", "offence", "n",
               w = c(homicide = 25, robbery = 8, burglary = 4), pop = "pop")
cmlrisk(16:20, c(900, 1400, 1700, 1600, 1400), rep(1e5, 5))


## ----wild---------------------------------------------------------------------
wcb(p, "district", "month", "crmrate", "reformed", cl = "region")


## ----sens---------------------------------------------------------------------
tse(es, seed = 1)


## ----covs---------------------------------------------------------------------
set.seed(4)
p$x1 <- rnorm(20)[match(p$district, unique(p$district))]
stgatt(p, "district", "month", "crmrate", "refmonth", covs = "x1", reps = 49,
              seed = 1)$overall
m <- mtchdid(p, "district", "month", "crmrate", "refmonth", ratio = 2)
m$estimate


## ----sdid, fig.height = 3.5---------------------------------------------------
sd <- syndid(p13, "district", "month", "crmrate", "refmonth", reps = 50, seed = 1)
sd
plot(sd)


## ----power, fig.height = 3.5--------------------------------------------------
pw <- plnpwr(p[p$month <= 12, ], "district", "month", "crmrate", ntrt = 10,
                  adopt = 7:10, eff = c(0, 0.5, 1, 1.5), reps = 40, seed = 1)
pw
plot(pw)


## ----indigenous-policy--------------------------------------------------------
hi <- indiex("health")
x <- hi[hi$age == "Total, 18 years and over" &
          hi$indicator == "Perceived mental health, very good or excellent", ]
gaps <- do.call(rbind, lapply(split(x, x$period), function(p) {
  cbind(period = p$period[1],
        indgap(p, "group", "estimate", "lower", "upper")[
          , c("group", "difference", "diflo", "difup")])
}))
rownames(gaps) <- NULL
gaps

