## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## -----------------------------------------------------------------------------
seg <- data.frame(
  EndFiscalYear = rep(2019:2023, each = 2),
  Gender = rep(c("Female", "Male"), 5),
  NumberOfPlacements = c(31, 402, 28, 377, 12, 190, 19, 268, 24, 331)
)


## -----------------------------------------------------------------------------
y <- yoy(seg,
  value = NumberOfPlacements,
  prd = EndFiscalYear,
  by = "Gender",
  dir = "lower"
)
y


## -----------------------------------------------------------------------------
stats::poisson.test(c(331, 268), c(1, 1))$conf.int


## -----------------------------------------------------------------------------
gap <- data.frame(year = c(2019, 2020, 2022, 2023), n = c(100, 120, 140, 150))
yoy(gap, value = n, prd = year)


## -----------------------------------------------------------------------------
tiny <- data.frame(year = 2019:2021, n = c(2, 20, 25))
as.data.frame(yoy(tiny, value = n, prd = year))[, c("year", "pctchg",
                                                     "pctlo", "pctup")]


## -----------------------------------------------------------------------------
as.data.frame(yoy(tiny, value = n, prd = year, minbase = 20))$flag


## -----------------------------------------------------------------------------
rate <- data.frame(year = 2019:2023, share = c(4.1, 4.6, 5.2, 5.0, 5.4))
yoy(rate, value = share, prd = year, units = "percent")


## -----------------------------------------------------------------------------
m <- stats::ts(c(10:21, 20:31), start = c(2021, 1), frequency = 12)
head(as.data.frame(yoy(m, minbase = 0))[12:14, c("period", "value",
                                                  "previous", "change")], 3)


## -----------------------------------------------------------------------------
yoysmry(y)


## -----------------------------------------------------------------------------
stops <- data.frame(
  division = c("North", "South", "East"),
  stops = c(412, 77, 3),
  residents = c(120000, 41000, 9500))

rtcalc(stops, stops, residents, by = "division", per = "100k")


## -----------------------------------------------------------------------------
shrs(stops, stops, by = "division")


## -----------------------------------------------------------------------------
d <- data.frame(
  year = rep(2021:2023, each = 2),
  division = rep(c("North", "South"), 3),
  stops = c(400, 70, 430, 66, 455, 61),
  residents = c(120000, 41000, 122000, 41500, 125000, 42000))

ratechg(d, stops, residents, year, by = "division", per = "100k")


## -----------------------------------------------------------------------------
dir <- tempdir()
for (ext in c("csv", "tsv", "json", "md", "html", "pdf")) {
  f <- file.path(dir, paste0("placements.", ext))
  yoywr(y, f, title = "Placements by gender")
  cat(sprintf("%-5s %6d bytes\n", ext, file.size(f)))
}


## -----------------------------------------------------------------------------
cat(yoycsv(y, NULL, digits = 1L))


## -----------------------------------------------------------------------------
cat(yoymd(yoy(gap, value = n, prd = year), NULL))


## -----------------------------------------------------------------------------
yoypals()


## ----include = FALSE----------------------------------------------------------
unlink(file.path(dir, paste0("placements.",
                             c("csv", "tsv", "json", "md", "html", "pdf"))))


## ----indigenous-yoy-----------------------------------------------------------
hi <- indiex("health")
m <- hi[hi$age == "Total, 18 years and over" &
          hi$indicator == "Perceived mental health, very good or excellent", ]
# yoy() steps through consecutive periods: number the two survey cycles 1 and 2
m$cycle <- match(m$period, c("2015/2018", "2019/2022"))
for (g in unique(m$group)) {
  s <- m[m$group == g, ]
  print(as.data.frame(yoy(s, value = estimate, prd = cycle, units = "percent"))[
    2, c("value", "previous", "ppchg", "verdict")])
}


## ----yoy-plot, fig.width = 7, fig.height = 4.5--------------------------------
plot(y)

