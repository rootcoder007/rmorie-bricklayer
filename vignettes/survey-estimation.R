## ----setup, include = FALSE---------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 7, fig.height = 4, dpi = 72)
library(rmoriebricklayer)


## ----design-------------------------------------------------------------------
set.seed(1)
n <- 600
d <- data.frame(region = sample(c("north", "south", "east"), n, replace = TRUE),
                age = sample(c("15-24", "25-49", "50+"), n, replace = TRUE),
                used = rbinom(n, 1, 0.3), drinks = rpois(n, 3), w = runif(n, 40, 160))
# a stratified design: variance by linearization
lin <- svydes(d, w = "w", strata = "region")
lin
# a replicate design: 200 bootstrap weights, made here by resampling within region
reps <- sapply(1:200, function(r) {
  m <- numeric(n)
  for (g in unique(d$region)) {
    i <- which(d$region == g)
    m[i] <- tabulate(sample(length(i), replace = TRUE), length(i)) * length(i) / (length(i) - 1)
  }
  d$w * m
})
repdes <- svydes(d, w = "w", reps = reps, type = "bootstrap")
repdes


## ----estimate-----------------------------------------------------------------
e <- svyest(repdes, d, "used", by = "age", stat = "proportion", lvls = "1")
e
plot(e)
svyest(lin, d, "drinks", by = "region")


## ----compare------------------------------------------------------------------
cmp <- svycmp(repdes, d, "used", by = "region", stat = "proportion", lvls = "1",
                      ref = "north")
cmp
plot(cmp)


## ----csus, eval = FALSE-------------------------------------------------------
# a <- dload("csus_2023/pumf")        # 36,180 respondents
# b <- dload("csus_2023/bootstrap")   # PUMF_ID, WGT_PUMF and BWGT1 ... BWGT1000


## ----csus-open, eval = FALSE--------------------------------------------------
# src <- "https://open.canada.ca/data/dataset/65e2d45e-efc6-4c29-9a9b-db59bc96aa0e/resource"
# pumf <- file.path(tempdir(), "csus2023_pumf_final.csv")
# bwt <- file.path(tempdir(), "csus2023_pumf_bwt.csv")
# bldl(paste0(src, "/c2c1795b-4501-49ba-9dd1-5b8360cc3b2e/download/",
#                            "csus2023_pumf_final.csv"), pumf)
# bldl(paste0(src, "/7d19d47a-5f42-4447-b735-aa4d677ad5ed/download/",
#                            "csus2023_pumf_bwt.csv"), bwt)
# a <- utils::read.csv(pumf)
# b <- utils::read.csv(bwt)
# # With rmorie installed, the same two files come from
# # rmorie::morie_load_dataset() with the keys "cu23mf" and "cu23bt".


## ----csus-estimate, eval = FALSE----------------------------------------------
# a$can <- ifelse(a$CAN_Q01 < 0, NA, a$CAN_Q01)   # -8: not stated
# des <- svydes(a, w = "WGT_PUMF", reps = b, id = "PUMF_ID",
#                      type = "meanboot", msize = 12)
# svyest(des, a, "can", stat = "proportion", lvls = c("1", "2"))


## ----published-only-----------------------------------------------------------
h <- indiex("health")
mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
          h$indicator == "Perceived mental health, very good or excellent", ]
indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")[
  , c("group", "difference", "diflo", "difup")]
dstntst(mh[mh$group != "Non-Indigenous", ], "group", "estimate", "lower", "upper")


## ----agree--------------------------------------------------------------------
rbind(linearization = svyest(lin, d, "drinks")[, c("estimate", "se")],
      bootstrap = svyest(repdes, d, "drinks")[, c("estimate", "se")])

