## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>", fig.width = 6, fig.height = 4, dpi = 72)
library(rmoriebricklayer)


## ----estimates----------------------------------------------------------------
d <- data.frame(REF_DATE = "2022", GEO = "Canada",
                `Indigenous identity` = rep(c("First Nations", "Metis"), each = 4),
                Statistics = rep(c("Number of persons", "Percent", "Low 95% confidence interval",
                                   "High 95% confidence interval"), 2),
                UOM = rep(c("Persons", "Percent", "Percent", "Percent"), 2),
                VALUE = c(415000, 47.1, 45.2, 49.0, 320000, 50.3, 48.1, 52.5),
                STATUS = "", check.names = FALSE)
scests(d)


## ----load, eval = FALSE-------------------------------------------------------
# indtabs("mental health")
# e <- scests("41100067")


## ----gap----------------------------------------------------------------------
h <- indiex("health")
mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" &
          h$indicator == "Perceived mental health, very good or excellent", ]
g <- indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")
g
plot(g)


## ----distinctions-------------------------------------------------------------
dt <- dstntst(mh[mh$group != "Non-Indigenous", ], "group", "estimate", "lower", "upper")
dt
plot(dt)


## ----ordinal------------------------------------------------------------------
r <- indiex("mentalhealth")
r <- r[r$region == "Canada", ]
oc <- ordcmp(r, "group", "rating", "estimate", "lower", "upper",
                      lvls = c("Fair or poor", "Good", "Very good", "Excellent"),
                      ref = "M\u00e9tis", qual = "quality")
oc
plot(oc)


## ----prevalence---------------------------------------------------------------
si <- indiex("suicide")
si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" &
           si$age != "Total, 15 years and over", ]
si <- si[order(si$group, si$age), ]
sp <- stdprev(si$estimate, si$lower, si$upper, std = c(20, 18, 17, 17, 28),
                             grp = si$group, qual = si$quality)
sp
plot(sp)


## ----wellness-----------------------------------------------------------------
wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = c("Life satisfaction rating of 8, 9 or 10",
                                   "Sense of meaning and purpose rating of 8, 9 or 10",
                                   "Always or often has a hopeful outlook"),
                      distress = c("Life satisfaction rating between 0 and 5",
                                   "Rarely or never has a hopeful outlook"),
                      qual = "quality")
plot(w)
frmaud(w)


## ----dual---------------------------------------------------------------------
dc <- dualcont(w, "Always or often has a hopeful outlook", "Life satisfaction rating between 0 and 5")
dc
plot(dc)


## ----balance------------------------------------------------------------------
dom <- c("Perceived health, very good or excellent" = "physical",
         "Perceived mental health, very good or excellent" = "mental",
         "Life satisfaction, satisfied or very satisfied" = "emotional",
         "Sense of belonging to local community, somewhat strong or very strong" = "community")
d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator %in% names(dom), ]
d$domain <- dom[d$indicator]
hb <- holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality")
hb
plot(hb)


## ----continuum----------------------------------------------------------------
mw <- mhcont(wb, "group", "indicator", "estimate", "lower", "upper",
        hope = "Always or often has a hopeful outlook",
        meaning = "Sense of meaning and purpose rating of 8, 9 or 10",
        purp = "Sense of meaning and purpose rating of 8, 9 or 10", qual = "quality")
mw[, c("group", "indicator", "domain", "estimate", "shared")]
plot(mw)


## ----healing------------------------------------------------------------------
hc <- healchg(h[h$age == "Total, 18 years and over", ], "group", "indicator", "period",
                     "estimate", "lower", "upper", from = "2015/2018", to = "2019/2022",
                     qual = "quality",
                     well = c("Perceived mental health, very good or excellent",
                                  "Sense of belonging to local community, somewhat strong or very strong"))
hc <- hc[hc$indicator %in% c("Perceived mental health, very good or excellent",
                             "Sense of belonging to local community, somewhat strong or very strong",
                             "Mood disorder", "Anxiety disorder"), ]
plot(hc)


## ----connection---------------------------------------------------------------
r <- indiex("mentalhealth")
r <- r[r$rating == "Excellent or very good" & r$region != "Canada", ]
pair <- merge(r[r$group == "First Nations", ], r[r$group == "M\u00e9tis", ], by = "region",
              suffixes = c("fn", "me"))
ca <- connassoc(pair, "region", "estimatefn", "estimateme", "lowerfn", "upperfn",
                             "lowerme", "upperme")
ca
plot(ca, xlab = "First Nations: excellent or very good (%)",
     ylab = "M\u00e9tis: excellent or very good (%)")


## ----community----------------------------------------------------------------
h2 <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over", ]
ci <- commidx(h2, "group", "indicator", "estimate", "lower", "upper", qual = "quality",
        w = c("Sense of belonging to local community, somewhat strong or very strong" = 2,
                    "Has a regular healthcare provider" = 1,
                    "Perceived life stress, most days quite a bit or extremely stressful" = -2,
                    "Heavy drinking" = -1))
plot(ci)


## ----census-foster------------------------------------------------------------
p <- cnsprof(indiex("censuspop"))
fc <- profshr(p, "Foster children", "Total - Children in census families")
fc <- fc[fc$geo == "Canada" & fc$age == "0 to 14 years" &
           fc$group %in% c("First Nations", "M\u00e9tis", "Inuit", "Non-Indigenous"), ]
fc[, c("residence", "group", "numerator", "denominator", "estimate", "lower", "upper")]
plot(fc[fc$residence == "Total - Residence on or off reserve", ])


## ----census-language----------------------------------------------------------
know <- "Total - Knowledge of Indigenous languages for the population in private households - 25% sample data"
la <- profshr(p, "Indigenous languages", know)
la[la$geo == "Canada" & la$age == "Total - Age groups" & la$residence == "Total - Residence on or off reserve" &
     la$group %in% c("First Nations", "M\u00e9tis", "Inuit"), c("group", "estimate", "lower", "upper")]


## ----census-standard----------------------------------------------------------
cnsstd(p)


## ----census-cwb---------------------------------------------------------------
h <- cnsprof(indiex("censushh"))
cw <- cnscwb(p, h)
cw[cw$geo %in% c("Canada", "Nunavut"), c("geo", "group", "income", "education", "housing", "labour", "cwb")]
plot(cw)


## ----generations--------------------------------------------------------------
genexpo(parent = c(TRUE, FALSE, TRUE, NA), gparent = c(TRUE, FALSE, FALSE, TRUE))
et <- exptrnd(cases = c(60, 95, 70), n = c(500, 520, 300))
plot(et)


## ----trc-gaps, fig.height = 9-------------------------------------------------
g <- trchlthgap()
g[g$measure %in% c("Life expectancy at birth", "Infant mortality rate"),
  c("measure", "period", "group", "estimate", "refest", "disratio", "lower", "upper")]
plot(g)


## ----trc----------------------------------------------------------------------
p <- trcprog()
p
plot(p)


## ----continuity---------------------------------------------------------------
prof <- cnsprof(indiex("censuspop"))
la <- profshr(prof, "Indigenous languages", know)
la <- la[la$age == "Total - Age groups" & la$group == "First Nations" & la$geo != "Canada" &
           la$residence == "Total - Residence on or off reserve", ]
mh2 <- indiex("mentalhealth")
mh2 <- mh2[mh2$rating == "Excellent or very good" & mh2$group == "First Nations", ]
both <- merge(la[c("geo", "estimate", "lower", "upper")], mh2[c("region", "estimate", "lower", "upper")],
              by.x = "geo", by.y = "region", suffixes = c("lang", "mh"))
cc <- connassoc(both, "geo", "estimatelang", "estimatemh", "lowerlang", "upperlang",
                             "lowermh", "uppermh")
cc
plot(cc, xlab = "First Nations who know an Indigenous language (%)",
     ylab = "First Nations: mental health excellent or very good (%)")


## ----own-data-----------------------------------------------------------------
own <- data.frame(group = c("Aboriginal", "Torres Strait Islander", "Non-Indigenous Australians"),
                  pct = c(31.2, 27.5, 18.9), rse = c(4.1, 22.0, 1.2), flag = c("", "*", ""))
own <- cbind(own, limfrom(own$pct, cv = own$rse)[c("lower", "upper")])
own$quality <- qltyrcd(own$flag, suppr = "**", caution = "*")
indgap(own, "group", "pct", "lower", "upper", ref = "Non-Indigenous Australians",
               qual = "quality")

