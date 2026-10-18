# Person-level evidence on First Nations, Metis and Inuit mental wellness.
# CCHS 2019-2020 PUMF (Statistics Canada Open Licence): does a strong sense of belonging to the local
# community go with better perceived mental health among First Nations, Metis and Inuit adults, once
# age, sex, education, household income, food security, household size and province are held equal?
# Cross-fitted AIPW (rmoriebricklayer::aipw_crossfit) with the survey weight; the standard error from
# Statistics Canada's 1,000 bootstrap weights (svydes(type = "bootstrap")), from one fit.
suppressMessages(library(rmoriebricklayer))
# Run: Rscript imhperson.R <CCHS 2019-2020 PUMF directory> [output directory, default "."]
# The directory holds the PUMF CSV (pumf_cchs.csv) and its bootstrap weights (cchs_escc_bsw.csv),
# as Statistics Canada distributes them.
cl <- commandArgs(TRUE)
if (!length(cl)) stop("give the CCHS 2019-2020 PUMF directory: Rscript imhperson.R <dir> [outdir]", call. = FALSE)
dir <- cl[1L]
outdir <- if (length(cl) > 1L) cl[2L] else "."
f <- list.files(dir, "pumf_cchs.csv", recursive = TRUE, full.names = TRUE)
b <- list.files(dir, "cchs_escc_bsw.csv", recursive = TRUE, full.names = TRUE)
keep <- c("ADM_RNO1", "SDC_015", "DHHGAGE", "DHH_SEX", "EHG2DVH3", "INCDGHH", "FSCDVHF2", "GEOGPRV", "DHHDGHSZ",
          "GEN_030", "GENDVMHI", "GENDVSWL", "WTS_M")
hdr <- names(utils::read.csv(f, nrows = 1))
wcol <- intersect(c("WTS_M", "FWGT"), hdr)
d <- utils::read.csv(f, colClasses = ifelse(hdr %in% c(keep, wcol), NA, "NULL"))
bw <- utils::read.csv(b)
d <- merge(d, bw, by = "ADM_RNO1")
w0 <- if ("FWGT" %in% names(d)) "FWGT" else wcol[1]
d <- d[d$DHHGAGE >= 2 & d$GEN_030 %in% 1:4 & d$GENDVMHI %in% 0:4 & d$SDC_015 %in% 1:2, ]
d$belong <- as.numeric(d$GEN_030 %in% 1:2)
d$mh_good <- as.numeric(d$GENDVMHI >= 3)
ind <- function(v, lv, nm) {
  m <- vapply(lv, function(l) as.numeric(v == l), numeric(length(v)))
  colnames(m) <- paste0(nm, "_", lv)
  m
}
reg <- ifelse(d$GEOGPRV %in% 10:13, "atl", ifelse(d$GEOGPRV == 24, "qc", ifelse(d$GEOGPRV == 35, "on",
         ifelse(d$GEOGPRV %in% 46:47, "mbsk", ifelse(d$GEOGPRV == 48, "ab", ifelse(d$GEOGPRV == 59, "bc", "north"))))))
x <- cbind(ind(d$DHHGAGE, 3:5, "age"), female = as.numeric(d$DHH_SEX == 2), ind(d$EHG2DVH3, c(2, 3, 9), "edu"),
           ind(d$INCDGHH, c(2:5, 9), "inc"), ind(d$FSCDVHF2, c(1:3, 6, 9), "fs"),
           ind(reg, c("qc", "on", "mbsk", "ab", "bc", "north"), "reg"), alone = as.numeric(d$DHHDGHSZ == 1))
x <- x[, colSums(x) > 0, drop = FALSE]
covs <- colnames(x)
dd <- data.frame(d[c("mh_good", "belong", w0, grep("^BSW", names(d), value = TRUE), "SDC_015")], x)
out <- c()
res <- list()
say <- function(...) {
  s <- sprintf(...)
  cat(s, "\n")
  out <<- c(out, s)
}
for (grp in c(1, 2)) {
  g <- dd[dd$SDC_015 == grp, ]
  lab <- if (grp == 1) "First Nations, Metis and Inuit adults" else "Non-Indigenous adults"
  say("== %s: %d respondents, %d with a strong sense of belonging", lab, nrow(g), sum(g$belong))
  wm <- function(y, w) sum(w * y) / sum(w)
  raw <- wm(g$mh_good[g$belong == 1], g[[w0]][g$belong == 1]) - wm(g$mh_good[g$belong == 0], g[[w0]][g$belong == 0])
  reps <- grep("^BSW", names(g), value = TRUE)
  # the unadjusted difference's bootstrap standard error, from the same replicate weights
  rawb <- vapply(reps, function(r) wm(g$mh_good[g$belong == 1], g[[r]][g$belong == 1]) -
                   wm(g$mh_good[g$belong == 0], g[[r]][g$belong == 0]), numeric(1))
  raw_se <- sqrt(mean((rawb - raw)^2))
  # Statistics Canada's bootstrap weights: one fit, the replicate variance mean((theta_b - theta)^2)
  des <- svydes(g, w = w0, reps = reps, type = "bootstrap")
  fit <- aipwcf(g, "mh_good", "belong", covs, lrn = "ridge", des = des, seed = 11)
  se <- fit$se
  say("Unadjusted weighted difference in the share with very good or excellent mental health: %.1f points (bootstrap s.e. %.1f; 95%% CI %.1f to %.1f)",
      100 * raw, 100 * raw_se, 100 * (raw - 1.96 * raw_se), 100 * (raw + 1.96 * raw_se))
  say("AIPW average effect: %.1f points (bootstrap s.e. %.1f; 95%% CI %.1f to %.1f); %d replicates",
      100 * fit$estimate, 100 * se, 100 * fit$lower, 100 * fit$upper, length(reps))
  say("Propensity range %.3f to %.3f, %d clipped", attr(fit, "psrange")[1], attr(fit, "psrange")[2],
      attr(fit, "trimmed"))
  bt <- baltab(g, "belong", covs, w = w0)
  say("Largest weighted |standardised difference| between the groups before adjustment: %.3f (%s)",
      max(abs(bt$smd), na.rm = TRUE), bt$covariate[which.max(abs(bt$smd))])
  # balance after inverse-probability weighting with the clipped out-of-fold propensities
  pr <- attr(fit, "propensity")
  e <- pmin(pmax(pr$propensity, 0.01), 0.99)
  g$wipw <- g[[w0]] * ifelse(g$belong == 1, 1 / e, 1 / (1 - e))
  bta <- baltab(g, "belong", covs, w = "wipw")
  say("Largest |standardised difference| after inverse-probability weighting: %.3f (%s)",
      max(abs(bta$smd), na.rm = TRUE), bta$covariate[which.max(abs(bta$smd))])
  res[[lab]] <- list(fit = fit, raw = raw, raw_se = raw_se, before = bt, after = bta)
}

# Figures 10-12 and the results text, in the output directory
figdir <- outdir
dir.create(figdir, showWarnings = FALSE, recursive = TRUE)
nice <- c(age_3 = "Age 35-49", age_4 = "Age 50-64", age_5 = "Age 65 and over", female = "Female",
          edu_2 = "Secondary diploma", edu_3 = "Post-secondary", edu_9 = "Education not stated",
          inc_2 = "Household income group 2", inc_3 = "Household income group 3", inc_4 = "Household income group 4",
          inc_5 = "Household income group 5", inc_9 = "Income not stated", fs_1 = "Food insecurity: marginal",
          fs_2 = "Food insecurity: moderate", fs_3 = "Food insecurity: severe", fs_6 = "Food security not asked",
          fs_9 = "Food security not stated", reg_qc = "Quebec", reg_on = "Ontario", reg_mbsk = "Manitoba, Saskatchewan",
          reg_ab = "Alberta", reg_bc = "British Columbia", reg_north = "Territories", alone = "Lives alone")
relabel_cov <- function(b) { b$covariate <- ifelse(b$covariate %in% names(nice), nice[b$covariate], b$covariate); b }
pdf_fig <- function(name, w, h) grDevices::pdf(file.path(figdir, name), width = w, height = h, pointsize = 9)

# Figure 10: unadjusted and AIPW differences, both groups, 95% bootstrap intervals
pdf_fig("fig10_aipw.pdf", 6.5, 2.8)
est <- unlist(lapply(res, function(r) c(r$raw, r$fit$estimate))) * 100
lo <- unlist(lapply(res, function(r) c(r$raw - 1.96 * r$raw_se, r$fit$lower))) * 100
hi <- unlist(lapply(res, function(r) c(r$raw + 1.96 * r$raw_se, r$fit$upper))) * 100
labs <- c(paste(names(res)[1], c("unadjusted", "AIPW")), paste(names(res)[2], c("unadjusted", "AIPW")))
op <- graphics::par(mar = c(4.2, 17, 2.5, 1), las = 1)
yy <- rev(seq_along(est))
graphics::plot(est, yy, xlim = range(0, lo, hi), ylim = c(0.5, length(est) + 0.5), yaxt = "n", pch = c(1, 19, 1, 19),
               xlab = "Difference in very good or excellent mental health (points)",
               ylab = "", main = "Strong sense of belonging and mental health")
graphics::segments(lo, yy, hi, yy, lwd = 2)
graphics::abline(v = 0, lty = 2, col = "grey50")
graphics::axis(2, at = yy, labels = labs, tick = FALSE, cex.axis = 0.85)
graphics::par(op)
grDevices::dev.off()

# Figure 11: overlap of the out-of-fold propensities
pdf_fig("fig11_overlap.pdf", 6.5, 3)
op <- graphics::par(mfrow = c(1, 2))
for (nm in names(res)) plot(res[[nm]]$fit, main = nm)
graphics::par(op)
grDevices::dev.off()

# Figure 12: covariate balance before and after weighting
pdf_fig("fig12_balance.pdf", 6.5, 8)
op <- graphics::par(mfrow = c(2, 1))
for (nm in names(res)) plot(relabel_cov(res[[nm]]$before), after = relabel_cov(res[[nm]]$after), main = nm)
graphics::par(op)
grDevices::dev.off()
writeLines(out, file.path(outdir, "imhresults_person.txt"))
