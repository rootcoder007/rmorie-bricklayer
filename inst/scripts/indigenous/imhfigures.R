# First Nations, Metis and Inuit mental wellness from published Statistics Canada tables: every figure
# is drawn by the package's own plot methods, from the tables bundled with it (indiex()).
# Run: Rscript imhfigures.R [output directory, default "figures"]
library(rmoriebricklayer)
out <- commandArgs(TRUE)[1L]
if (is.na(out)) out <- "figures"
dir.create(out, showWarnings = FALSE, recursive = TRUE)
fig <- function(name, width = 6.5, height = 4, expr) {
  grDevices::pdf(file.path(out, paste0(name, ".pdf")), width = width, height = height, pointsize = 9)
  on.exit(grDevices::dev.off())
  force(expr)
}
h <- indiex("health")

# Figure 1: perceived mental health against non-Indigenous adults, both survey cycles
fig("fig1_gaps", 6.5, 3.4, {
  op <- graphics::par(mfrow = c(1, 2))
  for (p in c("2015/2018", "2019/2022")) {
    mh <- h[h$period == p & h$age == "Total, 18 years and over" &
              h$indicator == "Perceived mental health, very good or excellent", ]
    plot(indgap(mh, "group", "estimate", "lower", "upper", qual = "quality"),
         main = p)
  }
  graphics::par(op)
})

# Figure 2: the whole rating distribution, each group against the Metis distribution
r <- indiex("mentalhealth")
r <- r[r$region == "Canada", ]
fig("fig2_ratings", 6.5, 3.6, {
  plot(ordcmp(r, "group", "rating", "estimate", "lower", "upper",
                       lvls = c("Fair or poor", "Good", "Very good", "Excellent"), ref = "M\u00e9tis",
                       qual = "quality"),
       main = "Self-rated mental health, 2017 Aboriginal Peoples Survey")
})

# Figure 3: wellness beside distress, and the two continua
wb <- indiex("wellbeing")
w <- welprof(wb, "group", "indicator", "estimate", "lower", "upper",
                      well = c("Life satisfaction rating of 8, 9 or 10",
                                   "Sense of meaning and purpose rating of 8, 9 or 10",
                                   "Always or often has a hopeful outlook"),
                      distress = c("Life satisfaction rating between 0 and 5", "Rarely or never has a hopeful outlook"),
                      qual = "quality")
fig("fig3_wellness", 6.5, 3.6, {
  op <- graphics::par(mfrow = c(1, 2))
  plot(w, main = "Wellness and distress, 2024")
  plot(dualcont(w, "Always or often has a hopeful outlook", "Life satisfaction rating between 0 and 5"),
       main = "Hope and low life satisfaction, by group")
  graphics::par(op)
})

# Figure 4: holistic balance across four domains
dom <- c("Perceived health, very good or excellent" = "physical",
         "Perceived mental health, very good or excellent" = "mental",
         "Life satisfaction, satisfied or very satisfied" = "emotional",
         "Sense of belonging to local community, somewhat strong or very strong" = "community")
d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator %in% names(dom), ]
d$domain <- dom[d$indicator]
fig("fig4_balance", 6.5, 3.6, {
  plot(holbal(d, "group", "domain", "estimate", "lower", "upper", qual = "quality"),
       main = "Holistic balance, adults, 2019/2022")
})

# Figure 5: change over the pandemic years, wellness and distress indicators
hh <- h[h$age == "Total, 18 years and over", ]
ind <- c("Perceived mental health, very good or excellent",
         "Sense of belonging to local community, somewhat strong or very strong", "Mood disorder", "Anxiety disorder")
fig("fig5_change", 6.5, 3.8, {
  plot(healchg(hh[hh$indicator %in% ind, ], "group", "indicator", "period", "estimate", "lower", "upper",
                      from = "2015/2018", to = "2019/2022", qual = "quality",
                      well = c("Perceived mental health, very good or excellent",
                                   "Sense of belonging to local community, somewhat strong or very strong")),
       main = "Change from 2015/2018 to 2019/2022")
})

# Figure 6: suicidal thoughts in the past year, age-standardised
si <- indiex("suicide")
si <- si[si$measure == "Seriously contemplated suicide in the past 12 months" & si$age != "Total, 15 years and over", ]
si <- si[order(si$group, si$age), ]
fig("fig6_suicidal", 6.5, 2.8, {
  plot(stdprev(si$estimate, si$lower, si$upper, std = c(20, 18, 17, 17, 28), grp = si$group,
                              qual = si$quality),
       main = "Seriously contemplated suicide in the past 12 months, age-standardised")
})

# Figure 7: language and mental health across provinces and territories
p <- cnsprof(indiex("censuspop"))
know <- "Total - Knowledge of Indigenous languages for the population in private households - 25% sample data"
la <- profshr(p, "Indigenous languages", know)
la <- la[la$age == "Total - Age groups" & la$group == "First Nations" & la$geo != "Canada" &
           la$residence == "Total - Residence on or off reserve", ]
mh2 <- indiex("mentalhealth")
mh2 <- mh2[mh2$rating == "Excellent or very good" & mh2$group == "First Nations", ]
both <- merge(la[c("geo", "estimate", "lower", "upper")], mh2[c("region", "estimate", "lower", "upper")],
              by.x = "geo", by.y = "region", suffixes = c("_lang", "_mh"))
fig("fig7_connection", 6.5, 4, {
  plot(connassoc(both, "geo", "estimate_lang", "estimate_mh", "lower_lang", "upper_lang",
                              "lower_mh", "upper_mh"),
       xlab = "First Nations: knowledge of an Indigenous language (%)",
       ylab = "First Nations: mental health excellent or very good (%)",
       main = "Language and mental health by province and territory")
})

# Figure 8: Community Well-Being from public census figures
cw <- cnscwb(p, cnsprof(indiex("censushh")))
fig("fig8_cwb", 6.5, 4.4, plot(cw, main = "Community Well-Being, 2021 Census"))

# Figure 9: Call to Action 19 gaps on the disadvantage-ratio scale
fig("fig9_trc", 6.5, 4.6, plot(trchlthgap(), main = "Call to Action 19: gaps against non-Indigenous people"))
cat("FIGURES_DONE\n")
