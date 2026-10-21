## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 3.6)
library(rmoriebricklayer)


## ----sigmas-------------------------------------------------------------------
pgsig(1000, "D")
pgsig(1000, "D", set = "urban")


## ----rise---------------------------------------------------------------------
r <- briggs(c(100, 500, 2000), u = 4, diam = 1, exitvel = 12,
                       stktmp = 420, ambtmp = 285)
r$flux
r$finalrise
r$rise


## ----plume--------------------------------------------------------------------
x <- seq(200, 5000, by = 100)
h <- 30 + r$finalrise
cd <- gplume(q = 100, u = 4, h = h, rcpt = cbind(x, 0, 0), stab = "D")
cb <- gplume(q = 100, u = 4, h = h, rcpt = cbind(x, 0, 0), stab = "B")
plot(x, cd, type = "l", xlab = "downwind distance (m)", ylab = "concentration (g/m^3)",
     main = "Ground-level centreline concentration")
lines(x, cb, col = 2)
legend("topright", c("class D (neutral)", "class B (unstable)"), col = 1:2, lty = 1, bty = "n")


## ----particles----------------------------------------------------------------
p <- lagrprt(n = 500, x0 = 0, y0 = 0, u = 1, v = 0, kx = 0.5, ky = 0.5,
                          dt = 1, nsteps = 50, seed = 1, grid = c(0, 100, -30, 30, 20, 12))
c(mean_x = p$mean_x, meany = p$meany)


## ----crf----------------------------------------------------------------------
crfpm25(12)$rr
exp(log(1.08) * (12 - 5.8) / 10)          # the same, by hand
crfpm25(12, y = "ihd")$rr
crfno2(25)$rr


## ----crf-vec------------------------------------------------------------------
v <- crfpm25(c(6, 10, 15, 22))
v$rr
v$extra$rrperunit


## ----paf----------------------------------------------------------------------
attrfrac(crfno2(25)$rr, expoprev = 1)
mortdisp(expdel = 10, pop = 1e6, brate = 0.008,
                    betaperunit = log(1.02) / 10)


## ----burden-------------------------------------------------------------------
b <- polbrdn(expomean = 25, expoprev = 1, brate = 0.008,
                      pop = 1e6, poll = "NO2")
c(rr = b$extra$rr, paf = b$paf, attributable = b$attrcases)
b$citation


## ----area---------------------------------------------------------------------
areas <- data.frame(fsa = c("M6H", "M5V", "M4W", "M1B"), exposure = c(28, 18, 15, 24),
                    population = c(40000, 60000, 25000, 70000), brate = 0.008)
polbrdarea(areas)


## ----equity-------------------------------------------------------------------
d <- data.frame(exposure = c(30, 27, 22, 18, 14), income = 1:5)
e <- expconcidx(d, "exposure", "income")
e$concidx
e$interpretation


## ----plr----------------------------------------------------------------------
set.seed(1)
n <- 300
sim <- data.frame(income = rnorm(n), density = rnorm(n))
sim$no2 <- 20 - 2 * sim$income + 3 * sim$density + rnorm(n)
sim$asthmarate <- 5 + 0.3 * sim$no2 - 0.5 * sim$income + rnorm(n)
fit <- exprspplr(sim, y = "asthmarate", expo = "no2",
                             confs = c("income", "density"), nboot = 30)
c(ate = fit$ate, lower = fit$cilobs, upper = fit$ciupbs)


## ----verify-------------------------------------------------------------------
r <- vrfpol("no2", demo = TRUE, reg = "demo", years = "2024")
r$status
cat(polrpttxt(r))


## ----verify-fail--------------------------------------------------------------
bad <- vrfpol("pm25", expomean = -3, expoprev = 0.5)
bad$status
attr(bad, "exitstat")
none <- vrfpol("pm25")
none$status
attr(none, "exitstat")


## ----footprint----------------------------------------------------------------
raplok()
fp <- co2fp(sum(sqrt(seq_len(3e5))), loc = "CA-ON", cpupwrw = 45,
                        memgb = 16)
print(fp)
fp$assumptions


## ----usage--------------------------------------------------------------------
busy <- function() sum(sqrt(seq_len(2e5)))
a <- co2fp(busy(), loc = "CA-ON", cpupwrw = 45, memgb = 16)
b <- co2fp(busy(), loc = "CA-ON", cpupwrw = 45, memgb = 16,
                       usage = "machine", loadcur = "codecarbon")
rbind(prolin = c(usage = a$usage, cpukwh = a$enekwh$cpu),
      maccod = c(usage = b$usage, cpukwh = b$enekwh$cpu))
b$usagemode


## ----ci-----------------------------------------------------------------------
co2int("CA-ON")[c("g_per_kwh", "year", "source")]
co2int("Kenya")[c("location", "g_per_kwh", "year")]
co2int("CA-XX")$note
tab <- co2inttab()
nrow(tab)
table(nchar(tab$location) == 2, tab$year)[, c("2024", "2025")]


## ----detect-------------------------------------------------------------------
dtctloc()
dtctloc(envloc = "", codloc = "", tz = "Asia/Kolkata")
co2fp(1 + 1, cpupwrw = 45, memgb = 16)$assumptions[1]


## ----equiv--------------------------------------------------------------------
fpeqv(fp$co2eg * 1e4)   # if this ran ten thousand times


## ----indigenous-air-----------------------------------------------------------
cp <- indiex("censuspop")
tot <- cp[cp$GEO_LEVEL != "Country" & cp$AGE_GROUP == "Total - Age groups" &
            cp$RESIDENCE == "Total - Residence on or off reserve" &
            grepl("^Total - Average age", cp$CHARACTERISTIC_NAME), ]
pop <- stats::setNames(tot$FIRST_NATIONS, tot$GEO_NAME)
head(pop[order(-pop)], 5)
# relative risk of all-cause mortality from PM2.5, and the share of deaths attributable to
# the excess above the guideline if the whole population breathes the scenario level
sapply(c(8, 12), function(conc) {
  rr <- crfpm25(conc, refconc = 5)$rr
  c(pm25 = conc, rr = rr, attributable = attrfrac(rr, 1))
})

