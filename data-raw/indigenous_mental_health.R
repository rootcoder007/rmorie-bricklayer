# Builds the First Nations, Metis and Inuit mental health excerpts in inst/extdata from the full
# Statistics Canada tables (Statistics Canada Open Licence), as mirrored at the data service under
# statcan_indigenous/tbl_<pid>: 41-10-0067-01, 41-10-0082-01 and 41-10-0021-01. Values unaltered.
# Run from the package root with the three tables downloaded to `dir`.
library(rmoriebricklayer)
dir <- Sys.getenv("RMBL_STATCAN_DIR", "~/tmp/indig")
rd <- function(pid) {
  statcan_estimates(utils::read.csv(gzfile(file.path(dir, sprintf("tbl_%s.csv.gz", pid))), check.names = FALSE,
                                    stringsAsFactors = FALSE, encoding = "UTF-8"))
}
groups <- c("First Nations (North American Indian)" = "First Nations", "Métis" = "Métis",
            "Inuk (Inuit)" = "Inuit")
out <- function(d, file) {
  d$quality <- as.character(d$quality)
  utils::write.csv(d, file.path("inst/extdata", file), row.names = FALSE, fileEncoding = "UTF-8")
}
# 41-10-0067-01: self-perceived mental health, 2022, 15 years and older, every region
e <- rd("41100067")
e <- e[e$measure == "Percent" & e[["Age group"]] == "15 years and older" & e$Gender == "Total, gender" &
         e[["Indigenous identity"]] %in% names(groups) &
         e[["Self-perceived mental health"]] %in% c("Excellent", "Very good", "Good", "Fair or poor",
                                                     "Excellent or very good"), ]
out(data.frame(region = e$GEO, group = unname(groups[e[["Indigenous identity"]]]),
               rating = e[["Self-perceived mental health"]], estimate = e$estimate, lower = e$lower,
               upper = e$upper, quality = e$quality), "indigenous_mental_health.csv")
# 41-10-0082-01: well-being, 2024, Canada
w <- rd("41100082")
w <- w[w$measure == "Percent" & w$Gender == "Total, gender" & !grepl("^Total", w[["Selected characteristics of well-being and impacts of rising prices"]]), ]
out(data.frame(group = sub("Inuk \\(Inuit\\)", "Inuit", w[["Indigenous group"]]), indicator = w[["Selected characteristics of well-being and impacts of rising prices"]],
               estimate = w$estimate, lower = w$lower, upper = w$upper, quality = w$quality),
    "indigenous_wellbeing.csv")
# 41-10-0021-01: suicidal thoughts, 2017, Canada, both sexes, by age
s <- rd("41100021")
s <- s[s$measure == "Percent" & s$GEO == "Canada" & s$Sex == "Both sexes" & s[["Aboriginal identity"]] %in% names(groups) &
         s[["Age group"]] %in% c("15 to 24 years", "25 to 34 years", "35 to 44 years", "45 to 54 years",
                                 "55 years and over", "Total, 15 years and over") &
         s[["Self-perceived mental health and suicidal thoughts"]] %in% c("Seriously contemplated suicide in the past 12 months", "Ever seriously contemplated suicide"), ]
out(data.frame(group = unname(groups[s[["Aboriginal identity"]]]), age = s[["Age group"]], measure = s[["Self-perceived mental health and suicidal thoughts"]],
               estimate = s$estimate, lower = s$lower, upper = s$upper, quality = s$quality),
    "indigenous_suicidal_ideation.csv")
# 13-10-0924-01: health indicators, 2015-2018 and 2019-2022, Canada, both sexes, by age (the table
# behind The Daily of 2025-02-13), with non-Indigenous people for comparison
h <- rd("13100924")
h <- h[h$measure == "Percent", ]
ids <- c(groups, "Non-Indigenous people" = "Non-Indigenous")
h <- h[h$GEO == "Canada" & h$Sex == "Both sexes" & h[["Indigenous Identity"]] %in% names(ids), ]
out(data.frame(period = h$REF_DATE, group = unname(ids[h[["Indigenous Identity"]]]), age = h[["Age group"]],
               indicator = h$Indicators, estimate = h$estimate, lower = h$lower, upper = h$upper,
               quality = h$quality), "indigenous_health_indicators.csv")
