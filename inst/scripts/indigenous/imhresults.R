# First Nations, Metis and Inuit health, mental health and wellness from published Statistics Canada
# tables bundled with the package (indiex()): every estimator run on the same tables, results printed.
# Run: Rscript imhresults.R > imhresults.txt
library(rmoriebricklayer)
options(width = 140, digits = 4)
h <- indiex("health")
mh <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator == "Perceived mental health, very good or excellent", ]
cat("== GAP perceived MH\n"); print(indgap(mh, "group", "estimate", "lower", "upper", qual = "quality")[, c("group","estimate","refest","difference","diflo","difup","ratio","ratiolo","ratioup")])
cat("== DISTINCTIONS\n"); print(dstntst(mh[mh$group != "Non-Indigenous", ], "group", "estimate", "lower", "upper"))
r <- indiex("mentalhealth"); r <- r[r$region == "Canada", ]
cat("== ORDINAL\n"); print(ordcmp(r, "group", "rating", "estimate", "lower", "upper", lvls = c("Fair or poor","Good","Very good","Excellent"), ref = "M\u00e9tis", qual = "quality"))
oc2 <- r; cat("== ORDINAL ref FN\n"); print(ordcmp(r, "group", "rating", "estimate", "lower", "upper", lvls = c("Fair or poor","Good","Very good","Excellent"), ref = "First Nations", qual = "quality"))
si <- indiex("suicide"); si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" & si$age != "Total, 15 years and over", ]; si <- si[order(si$group, si$age), ]
cat("== SI crude totals\n"); print(indiex("suicide")[indiex("suicide")$age=="Total, 15 years and over",])
cat("== SI standardised\n"); print(stdprev(si$estimate, si$lower, si$upper, std = c(20, 18, 17, 17, 28), grp = si$group, qual = si$quality))
wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper", well = c("Life satisfaction rating of 8, 9 or 10","Sense of meaning and purpose rating of 8, 9 or 10","Always or often has a hopeful outlook"), distress = c("Life satisfaction rating between 0 and 5","Rarely or never has a hopeful outlook"), qual = "quality")
cat("== WELLNESS\n"); print(w[, c("group","indicator","side","estimate","lower","upper")]); print(frmaud(w))
cat("== DUAL\n"); print(dualcont(w, "Always or often has a hopeful outlook", "Life satisfaction rating between 0 and 5"))
dom <- c("Perceived health, very good or excellent" = "physical", "Perceived mental health, very good or excellent" = "mental", "Life satisfaction, satisfied or very satisfied" = "emotional", "Sense of belonging to local community, somewhat strong or very strong" = "community")
d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator %in% names(dom), ]; d$domain <- dom[d$indicator]
cat("== BALANCE\n"); print(holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality")); print(attr(holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality"), "domains"))
cat("== BALANCE weights community x2\n"); print(holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality", w = c(physical=1, mental=1, emotional=1, community=2))[, c("group","level","balance","ballo","balup")])
cat("== CONTINUUM\n"); print(mhcont(wb, "group", "indicator", "estimate", "lower", "upper", hope = "Always or often has a hopeful outlook", meaning = "Sense of meaning and purpose rating of 8, 9 or 10", purp = "Sense of meaning and purpose rating of 8, 9 or 10", qual = "quality")[, c("group","indicator","estimate","lower","upper","shared")])
hh <- h[h$age == "Total, 18 years and over", ]
cat("== HEALING\n"); print(healchg(hh[hh$indicator %in% c("Perceived mental health, very good or excellent","Sense of belonging to local community, somewhat strong or very strong","Mood disorder","Anxiety disorder"),], "group","indicator","period","estimate","lower","upper", from="2015/2018", to="2019/2022", qual="quality", well=c("Perceived mental health, very good or excellent","Sense of belonging to local community, somewhat strong or very strong")))
mr <- indiex("mentalhealth"); mr <- mr[mr$rating == "Excellent or very good" & mr$region != "Canada", ]
pair <- merge(mr[mr$group == "First Nations", ], mr[mr$group == "M\u00e9tis", ], by = "region", suffixes = c("_fn", "_me"))
cat("== CONNECTION FN-Metis\n"); print(connassoc(pair, "region", "estimate_fn", "estimate_me", "lower_fn", "upper_fn", "lower_me", "upper_me"))
p <- cnsprof(indiex("censuspop"))
know <- "Total - Knowledge of Indigenous languages for the population in private households - 25% sample data"
la <- profshr(p, "Indigenous languages", know); la <- la[la$age == "Total - Age groups" & la$group == "First Nations" & la$geo != "Canada" & la$residence == "Total - Residence on or off reserve", ]
mh2 <- indiex("mentalhealth"); mh2 <- mh2[mh2$rating == "Excellent or very good" & mh2$group == "First Nations", ]
both <- merge(la[c("geo","estimate","lower","upper")], mh2[c("region","estimate","lower","upper")], by.x="geo", by.y="region", suffixes=c("_lang","_mh"))
cat("== CONTINUITY\n"); print(both); print(connassoc(both, "geo", "estimate_lang", "estimate_mh", "lower_lang", "upper_lang", "lower_mh", "upper_mh"))
fc <- profshr(p, "Foster children", "Total - Children in census families"); fc <- fc[fc$geo=="Canada" & fc$age=="0 to 14 years" & fc$group %in% c("First Nations","M\u00e9tis","Inuit","Non-Indigenous"),]
cat("== FOSTER\n"); print(fc[, c("residence","group","numerator","denominator","estimate","lower","upper")])
la2 <- profshr(p, "Indigenous languages", know); cat("== LANG Canada\n"); print(la2[la2$geo=="Canada" & la2$residence=="Total - Residence on or off reserve" & la2$group %in% c("First Nations","M\u00e9tis","Inuit"), c("age","group","estimate","lower","upper")])
cat("== STANDARD\n"); print(cnsstd(p))
hd <- cnsprof(indiex("censushh")); cw <- cnscwb(p, hd)
cat("== CWB\n"); print(cw[, c("geo","group","population","income","education","housing","labour","cwb")])
cat("== TRC gaps\n"); g <- trchlthgap(); print(g[, c("indicator","measure","period","group","estimate","refest","disratio","lower","upper","worse")])
cat("== TRC progress\n"); print(trcprog())
cat("== EXPOSURE example\n"); print(exptrnd(c(60,95,70), c(500,520,300))); print(attr(exptrnd(c(60,95,70), c(500,520,300)), "trend"))
