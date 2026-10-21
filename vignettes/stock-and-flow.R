## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----adp----------------------------------------------------------------------
# Lakner's worked example: 3,000 inmates served 13,500 detention days in a year
adp(13500)

# per-person days over a 30-day period give the same total
adp(c(10, 20, 30), t = 30)


## ----alos---------------------------------------------------------------------
# Lakner: 2,700 inmates admitted and released served 12,150 detention days
alos(12150, 2700)


## ----admissions---------------------------------------------------------------
alosimplied <- 25 * 365 / 1750
round(alosimplied, 1)
admits(25, alosimplied)


## ----stockflow----------------------------------------------------------------
stkflow(
  days = c(115674, 126121), people = c(12647, 9608),
  prd = c("2023", "2025"),
  expo = c(15495050, 16256538)
)


## ----stays--------------------------------------------------------------------
stays <- c(rep(1, 40), rep(3, 30), rep(10, 20), 60, 90, 120)
staysmry(stays)
staysmry(stays)[, c("mean", "median", "max")]


## ----periods------------------------------------------------------------------
perdays("2024-04-01", "2025-03-31")
fylbl(2024)


## ----indigenous-stock---------------------------------------------------------
cp <- indiex("censuspop")
fc <- cp[cp$GEO_NAME == "Canada" & cp$AGE_GROUP == "0 to 14 years" &
           cp$RESIDENCE == "Total - Residence on or off reserve", ]
kids <- fc[grepl("Total - Children in census families", fc$CHARACTERISTIC_NAME),
           c("FIRST_NATIONS", "NON_IND")]
fost <- fc[grepl("Foster children", fc$CHARACTERISTIC_NAME), c("FIRST_NATIONS", "NON_IND")]
round(100 * unlist(fost) / unlist(kids), 2)


## ----stock-flow-plots, fig.width = 8, fig.height = 4--------------------------
op <- par(mfrow = c(1, 2))
per1000 <- unlist(fost) / unlist(kids) * 1000
barplot(per1000, names.arg = c("First Nations", "non-Indigenous"), col = blpal()[1:2],
        ylab = "per 1,000 children", main = "Children in foster care")
hist(stays, breaks = 30, col = blpal()[2], xlab = "length of stay", main = "Lengths of stay")
par(op)

