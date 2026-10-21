## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")


## -----------------------------------------------------------------------------
library(rmoriebricklayer)
otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))
otis


## -----------------------------------------------------------------------------
a <- anltab(otis, value = "individuals", prd = "year",
                   by = c("table", "group"))
a


## -----------------------------------------------------------------------------
a$change[, c("table", "group", "year", "value", "previous",
             "pctchg", "pctlo", "pctup", "padj",
             "significant")]


## -----------------------------------------------------------------------------
b <- anltab(otis, value = "individuals", prd = "year",
                   by = c("table", "group"), rnd = 5)
b$change[!is.na(b$change$previous),
         c("group", "year", "pctchg", "pctlo", "pctup",
           "compctlo", "compctup")]


## -----------------------------------------------------------------------------
a$trend


## -----------------------------------------------------------------------------
drftcal(otis, n = 10)


## -----------------------------------------------------------------------------
sf <- stkflow(days = c(21900, 23725, 20440), people = c(300, 325, 280),
                 prd = c(2022, 2023, 2024), t = 365)
sf


## -----------------------------------------------------------------------------
sf <- stkflow(days = c(21900, 23725, 20440), people = c(300, 325, 280),
                 prd = c(2022, 2023, 2024), t = 365)
sf


## -----------------------------------------------------------------------------
d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
list.files(d)
cat(readLines(file.path(d, "analysis.R"))[1:12], sep = "\n")


## ----getting-started-plots, fig.width = 7, fig.height = 4.5-------------------
plot(a)
plot(sf)

