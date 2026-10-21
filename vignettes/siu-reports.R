## ----include = FALSE----------------------------------------------------------
# chunks run when the vignette is built (R CMD build, r-universe, pkgdown) and are skipped when
# R CMD check re-builds it (R sets _R_CHECK_PACKAGE_NAME_ there), unless NOT_CRAN is true
knitr::opts_chunk$set(eval = identical(Sys.getenv("NOT_CRAN"), "true") ||
                        !nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")))
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(rmoriebricklayer)


## ----schema-------------------------------------------------------------------
sch <- siusch()
head(sch$name, 20)
nrow(sch)


## ----parse--------------------------------------------------------------------
f <- siuprs(system.file("extdata", "siu_synthetic_report.html",
                                      package = "rmoriebricklayer"))
f[["number_of_subject_officials"]]
f[["date_of_incident_iso"]]


## ----text---------------------------------------------------------------------
siutxt("<p>Number of SIU Investigators assigned: 3</p>")


## ----so-----------------------------------------------------------------------
siuso("Subject Officials\nSO #1 Interviewed\nSO #2 Declined interview")


## ----dates--------------------------------------------------------------------
siudate("March 4, 2024")
siudate("not a date")


## ----fetch, eval = FALSE------------------------------------------------------
# f <- siufprs("24-OCI-123")


## ----indigenous-siu, eval = FALSE---------------------------------------------
# fnservices <- c("Nishnawbe-Aski Police Service", "Anishinabek Police Service",
#                  "Treaty Three Police Service", "UCCM Anishnaabe Police Service")
# reports <- lapply(reporturls, siufprs)
# mine <- Filter(function(r) any(grepl(paste(fnservices, collapse = "|"), r$police_service)),
#                reports)
# length(mine)


## ----siu-timeline-plot, fig.width = 7, fig.height = 3.5-----------------------
rpt <- siuprs(siutxt(paste(readLines(system.file("extdata", "siu_synthetic_report.html",
                                                    package = "rmoriebricklayer"), warn = FALSE),
                           collapse = "\n")))
iso <- rpt[grepl("_iso$", names(rpt)) & grepl("^\\d{4}-\\d{2}-\\d{2}$", rpt)]
when <- as.Date(iso)
o <- order(when)
lab <- gsub("_", " ", sub("_iso$", "", names(iso)[o]))
span <- diff(range(when))
op <- par(mar = c(4, 1, 3, 1))
plot(when[o], seq_along(o), pch = 19, col = blpal()[1], yaxt = "n", xaxt = "n", xlab = "", ylab = "",
     xlim = range(when) + c(-0.1, 0.1) * as.numeric(span), ylim = c(0.5, length(o) + 0.5),
     main = "Dates in the synthetic report")
axis.Date(1, when, format = "%Y-%m-%d")
text(when[o], seq_along(o), paste0(lab, "  ", format(when[o])), cex = 0.75,
     pos = ifelse(seq_along(o) < length(o), 4, 2))
par(op)

