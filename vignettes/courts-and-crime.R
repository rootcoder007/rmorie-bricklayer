## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 8, fig.height = 4.5)
library(rmoriebricklayer)
ext <- function(f) read.csv(system.file("extdata", f, package = "rmoriebricklayer"))


## ----hub, eval = FALSE--------------------------------------------------------
# clearance <- dload("ocj_statistics/clearance_rate_criminal")
# offences  <- dload("ocj_statistics/offence_based_criminal")
# mci       <- dload("tps_open_data/major_crime_indicators_open_data_0")


## ----flow---------------------------------------------------------------------
f <- ext("ocj_flow_ontario.csv")
cf <- caseflow(f$received, f$disposed, pend = f$pending, prd = f$month)
cf[c(1, 12, 24), c("period", "received", "disposed", "clearance", "rolclr", "pertoclear")]
plot(cf)


## ----life---------------------------------------------------------------------
d <- ext("ocj_time_to_disposition.csv")
last <- nrow(d)
shares <- unlist(d[last, c("under_10", "m10_15", "m15_18", "over_18")])
lt <- lifetbl(c("Under 10 Months", "Between 10-15 Months", "Between 15-18 Months", "Over 18 Months"),
                 events = shares * f$disposed[last])
lt
plot(lt)


## ----mix----------------------------------------------------------------------
x <- ext("ocj_dispositions.csv")
mix <- dispmix(x[, -(1:2)], prd = x$year, scores = x$year)
mix$trend[, c("outcome", "statistic", "pholm", "change")]
plot(mix)


## ----simpson, fig.height = 4.8------------------------------------------------
g <- ext("ocj_offence_groups.csv")
g <- g[g$year %in% c(2014, 2022), ]
cd <- clrdcmp(g$disposed, g$received, g$offence_group, g$year)
cd
plot(cd)
# a group's share of the cases received in a year, as a percentage
caseshare <- function(group, yr) {
  sprintf("%.0f%%", 100 * sum(g$received[g$offence_group == group & g$year == yr]) / sum(g$received[g$year == yr]))
}


## ----courts-------------------------------------------------------------------
c <- ext("ocj_courts.csv")
c <- aggregate(cbind(received, disposed) ~ year + court_series, c, sum)
c <- c[c$year %in% c(2012, 2024), ]
c <- c[c$court_series %in% names(which(table(c$court_series) == 2)), ]
cc <- clrdcmp(c$disposed, c$received, c$court_series, c$year)
cc$overall
cc$simpson$type


## ----density, fig.height = 5.5------------------------------------------------
b <- ext("tps_break_enter_d14_2024.csv")
kd <- crmdens(b$lon, b$lat, ngrid = 150)
kd
plot(kd)


## ----knox---------------------------------------------------------------------
b <- b[!is.na(b$lon), ]
kn <- knoxtst(b$lon, b$lat, as.Date(b$occ_date), spcbands = c(100, 200, 400),
                tmbands = c(7, 14, 28), nsim = 199, seed = 1)
kn
plot(kn)


## ----hotspots, fig.width = 9, fig.height = 4----------------------------------
h <- hotpers(b$lon, b$lat, quarters(as.Date(b$occ_date)), cell = 0.3)
h
plot(h)


## ----indigenous-courts, eval = TRUE-------------------------------------------
le <- indiex("lifeexp")
le[le$period == "2016/2021", c("group", "estimate", "lower", "upper")]

