## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----parse--------------------------------------------------------------------
prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
prsbands(c("18 to 24", "25 to 49", "50+"))


## ----parse-bad----------------------------------------------------------------
prsbands(c("3", "unknown", "not stated"))


## ----values-------------------------------------------------------------------
b <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
bandvals(b, rule = "midpoint", openupcap = 20)
bandvals(b, rule = "geometric", openupcap = 20)


## ----expand-------------------------------------------------------------------
x <- expbands(c("1", "2 to 5", "Greater than 5"), cnts = c(10, 4, 2),
                  openupcap = 12)
table(x)
ginicoef(x)


## ----gini---------------------------------------------------------------------
ginicoef(rep(1, 10))             # no concentration
ginicoef(c(rep(0, 9), 1))        # one unit holds everything
1 - 1 / 10                   # the maximum for ten units

placements <- c(rep(1, 1200), rep(3, 430), rep(8, 110), rep(20, 38))
ginicoef(placements)
topshr(placements, c(0.01, 0.05, 0.1))
head(lorenzc(placements))


## ----sens---------------------------------------------------------------------
counts <- c(1200, 430, 110, 38)
bandsens(b, counts)
bandsens(b, counts, stat = mean)


## ----hill---------------------------------------------------------------------
k <- 1:10000
p <- k^(-2.5) / sum(k^(-2.5))
set.seed(2)
z <- sample(k, 5000, replace = TRUE, prob = p)
c(exact = round(hilltlidx(z, xmin = 1)$alpha, 2),
  approx = round(hilltlidx(z, xmin = 1, approx = TRUE)$alpha, 2))


## ----hill-short---------------------------------------------------------------
short <- hilltlidx(c(3, 4, 5, 9), xmin = 3)
c(alpha = round(short$alpha, 2), n = short$ntl, reliable = short$reliable)


## ----indigenous-concentration-------------------------------------------------
cp <- indiex("censuspop")
tot <- cp[cp$GEO_LEVEL != "Country" & cp$AGE_GROUP == "Total - Age groups" &
            cp$RESIDENCE == "Total - Residence on or off reserve" &
            grepl("^Total - Average age", cp$CHARACTERISTIC_NAME), ]
ginicoef(tot$FIRST_NATIONS)
topshr(tot$FIRST_NATIONS, fracs = c(0.25, 0.5))


## ----bands-lorenz-plot, fig.width = 8, fig.height = 4-------------------------
op <- par(mfrow = c(1, 2))
barplot(counts, names.arg = b$label, col = blpal()[2], main = "Counts by band", ylab = "count")
plotlrnz(placements, main = "Concentration of placements")
par(op)

