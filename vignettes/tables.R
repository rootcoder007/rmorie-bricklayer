## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----statcan------------------------------------------------------------------
pyll <- data.frame(GEO = rep(c("Inuit Nunangat", "Rest of Canada"), each = 5),
                   Characteristics = rep(c("Number of potential years of life lost",
                                           "Crude rate of potential years of life lost",
                                           "Age-standardized rate of potential years of life lost",
                                           "Low 95% confidence interval, potential years of life lost",
                                           "High 95% confidence interval, potential years of life lost"), 2),
                   VALUE = c(5000, 900, 1100, 1000, 1200, 7000, 800, 950, 870, 1030), STATUS = "")
scests(pyll)[, c("GEO", "measure", "estimate", "lower", "upper")]


## -----------------------------------------------------------------------------
bands <- prsbands(c("1", "2 to 5", "6 to 10", "Greater than 10"))
bands


## -----------------------------------------------------------------------------
bandvals(bands)


## -----------------------------------------------------------------------------
counts <- c(1200, 430, 110, 38)
bandsens(bands, counts)


## -----------------------------------------------------------------------------
placements <- expbands(bands, counts, openupcap = 25)
ginicoef(placements)
topshr(placements, c(0.01, 0.05, 0.1))


## -----------------------------------------------------------------------------
c(ten = 1 - 1 / 10, thousand = 1 - 1 / 1000)


## -----------------------------------------------------------------------------
fit <- hilltlidx(placements, xmin = 1)
c(alpha = round(fit$alpha, 2), ks = round(fit$ks, 3),
  reliable = fit$reliable)


## -----------------------------------------------------------------------------
y <- c(402, 377, 190, 268, 331)
tt <- trndtst(y)
c(tau = tt$tau, p = round(tt$p_value, 4), slope = tt$slope)
tt$method


## -----------------------------------------------------------------------------
ct <- cnttrnd(y)
c(rateratio = round(ct$rateratio, 3),
  lower = round(ct$lower, 3), upper = round(ct$upper, 3),
  dispersion = round(ct$dispersion, 2))


## -----------------------------------------------------------------------------
sc <- stepchg(c(100, 104, 98, 60, 63, 58), x = 2018:2023)
c(after = sc$breakafter, before = sc$before, aftermean = sc$after,
  p = round(sc$p_value, 4))


## -----------------------------------------------------------------------------
(1 + 2 * factorial(3)^2) / (1 + factorial(6))


## -----------------------------------------------------------------------------
cw <- data.frame(
  facility = c("North Jail", "South Jail", "Hill Jail", "Lake Jail"),
  region   = c("3557", "3520", "3553", "3520"),
  stringsAsFactors = FALSE
)
pop <- data.frame(
  region     = c("3557", "3520", "3553", "3552", "3519"),
  population = c(114094, 3025647, 171568, 22746, 1173334),
  stringsAsFactors = FALSE
)


## -----------------------------------------------------------------------------
rgnmapintg(cw, "facility", "region", regs = pop$region)


## -----------------------------------------------------------------------------
bad <- cw
bad$region[3] <- "2406"          # a code from another province
rgnmapintg(bad, "facility", "region", regs = pop$region)


## -----------------------------------------------------------------------------
recomputed <- cw
recomputed$region[2] <- "3519"
rgnmapcmp(cw, recomputed, "facility")


## -----------------------------------------------------------------------------
route <- c("North Jail" = "3557", "South Jail" = "3520",
           "Hill Jail" = "3552", "Lake Jail" = "3520")
rgnmapalt(cw, "facility", "region", route,
                       known = "Hill Jail")


## -----------------------------------------------------------------------------
route["South Jail"] <- "3599"    # an assignment nobody documented
d <- rgnmapalt(cw, "facility", "region", route,
                            known = "Hill Jail")
d
sum(!d$known)


## -----------------------------------------------------------------------------
length(route)


## -----------------------------------------------------------------------------
units <- vapply(pop$region, function(r) sum(cw$region == r), numeric(1))
cov <- rgncov(pop$region, pop$population, units)
cov


## -----------------------------------------------------------------------------
a <- attr(cov, "coverage")
c(covered = a$covpop, uncovered = a$uncpop,
  share = round(a$covshr, 1))


## -----------------------------------------------------------------------------
d <- expand.grid(
  region = c("Central", "Eastern", "Northern", "Toronto", "Western"),
  age = c("18 to 24", "25 to 49", "50+"),
  stringsAsFactors = FALSE
)
d$pop <- rep(c(4000, 3000, 800, 5000, 2500), 3) *
  rep(c(0.3, 0.55, 0.15), each = 5)
set.seed(13)
rate <- c(Central = 0.006, Eastern = 0.011, Northern = 0.010,
          Toronto = 0.016, Western = 0.012)
d$n <- rpois(nrow(d), lambda = d$pop * rate[d$region])


## -----------------------------------------------------------------------------
e <- expcnts(d$n, d$pop, d$region, strata = d$age)
e


## -----------------------------------------------------------------------------
c(observed = sum(e$observed), expected = sum(e$expected))


## -----------------------------------------------------------------------------
stdinc(e$observed, e$expected, e$area)


## -----------------------------------------------------------------------------
ebrates(e$observed, e$expected, e$area)


## -----------------------------------------------------------------------------
fnllim(c(5, 20, 50, 200))


## -----------------------------------------------------------------------------
nb <- list(c(2L, 4L), c(1L, 3L), c(2L, 5L), c(1L, 5L), c(3L, 4L))
set.seed(1)
mi <- morani(e$observed / e$expected, nb, nperm = 999L)
c(I = round(mi$I, 3), expectation = round(mi$expectation, 3),
  p = mi$p_value)


## -----------------------------------------------------------------------------
-1 / (5 - 1)


## ----indigenous-tables--------------------------------------------------------
le <- indiex("lifeexp")
inuit <- le[le$group == "Inuit", ]
inuit[, c("period", "estimate", "lower", "upper")]
trndtst(inuit$estimate, x = 1:3)$p_value


## ----tables-plots, fig.width = 7, fig.height = 4.5----------------------------
plot(ct)
plot(cov)

