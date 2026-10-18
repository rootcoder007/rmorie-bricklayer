# Mental health and wellbeing methods: each against an exact reference

test_that("statcan_estimates() puts each estimate beside its limits, cell by cell and measure by measure", {
  d <- data.frame(REF_DATE = "2022", GEO = "Canada",
                  `Indigenous identity` = rep(c("First Nations ", "Metis"), each = 5),
                  Statistics = rep(c("Percent", "Low 95% confidence interval", "High 95% confidence interval",
                                     "Number of persons", "Low 95% confidence interval, number of persons"), 2),
                  UOM = rep(c("Percent", "Percent", "Percent", "Persons", "Persons"), 2),
                  VALUE = c(47.1, 45.2, 49.0, 1000, 900, 50.3, 48.1, 52.5, 800, 700),
                  STATUS = c("", "", "", "", "", "F", "", "", "", ""), check.names = FALSE)
  e <- statcan_estimates(d)
  p <- e[e$measure == "Percent", ]
  expect_identical(p[["Indigenous identity"]], c("First Nations", "Metis"))
  expect_identical(p$estimate, c(47.1, NA))
  expect_identical(p$lower, c(45.2, NA))
  expect_identical(p$upper, c(49.0, NA))
  expect_identical(p$ci_source, c("published", NA))
  expect_identical(as.character(p$quality), c("ok", "F"))
  n <- e[e$measure == "Number of persons", ]
  expect_identical(n$estimate, c(1000, 800))
  # a lower limit published without its upper is kept, and the pair is not called published
  expect_identical(n$lower, c(900, 700))
  expect_identical(n$upper, c(NA_real_, NA_real_))
  expect_identical(n$ci_source, c(NA_character_, NA_character_))
  expect_identical(attr(e, "conf_level"), 0.95)
  d3 <- d[c(1:3, 1), ]
  expect_error(statcan_estimates(d3), "two estimates for one cell")
  # one place name, two geographies: told apart by DGUID, not merged
  dg <- data.frame(GEO = "Division No.  1", DGUID = c("2021A00031001", "2021A00034601"), Statistics = "Count",
                   VALUE = c(10, 20), STATUS = "")
  eg <- statcan_estimates(dg)
  expect_identical(eg$DGUID, c("2021A00031001", "2021A00034601"))
  expect_identical(eg$estimate, c(10, 20))
})

test_that("statcan_estimates(): coefficients of variation, standard errors, and limits named in every form", {
  z <- stats::qnorm(0.975)
  cv <- statcan_estimates(data.frame(GEO = "Canada", Characteristics = c("Rate", "Coefficient of variation for rate"),
                                     VALUE = c(12.5, 8), STATUS = ""))
  expect_equal(cv$lower, 12.5 * (1 - z * 0.08))
  expect_identical(cv$ci_source, "cv")
  se <- statcan_estimates(data.frame(GEO = "A", Statistics = c("Average score", "Standard error"), VALUE = c(250, 2),
                                     STATUS = ""))
  expect_equal(se$upper, 250 + z * 2)
  expect_identical(se$ci_source, "se")
  ct <- statcan_estimates(data.frame(GEO = "A", Statistics = c("Count", "Confidence interval lower bound of count",
                                                               "Confidence interval upper bound of count"),
                                     VALUE = c(100, 80, 120), STATUS = ""))
  expect_identical(c(ct$lower, ct$upper), c(80, 120))
  yr <- statcan_estimates(data.frame(GEO = "A",
                                     Statistics = c("2015", "2020", "95% confidence interval lower bound, 2015",
                                                    "95% confidence interval upper bound, 2020"),
                                     VALUE = c(10, 20, 8, 23), STATUS = ""))
  expect_identical(yr$lower, c(8, NA))
  expect_identical(yr$upper, c(NA, 23))
  lim <- statcan_estimates(data.frame(GEO = "A", Statistics = c("Percentage", "95% confidence interval (lower limit)",
                                                                "95% confidence interval (upper limit)"),
                                      VALUE = c(30, 25, 35), STATUS = ""))
  expect_identical(c(lim$lower, lim$upper), c(25, 35))
  # a name that fits three measures: the one whose estimates the limits contain
  py <- data.frame(GEO = rep(c("A", "B"), each = 5),
                   Characteristics = rep(c("Number of potential years of life lost",
                                           "Crude rate of potential years of life lost",
                                           "Age-standardized rate of potential years of life lost",
                                           "Low 95% confidence interval, potential years of life lost",
                                           "High 95% confidence interval, potential years of life lost"), 2),
                   VALUE = c(5000, 900, 1100, 1000, 1200, 7000, 800, 950, 870, 1030), STATUS = "")
  pe <- statcan_estimates(py)
  asr <- pe[pe$measure == "Age-standardized rate of potential years of life lost", ]
  expect_identical(asr$lower, c(1000, 870))
  expect_true(all(is.na(pe$lower[pe$measure != "Age-standardized rate of potential years of life lost"])))
  expect_identical(attr(pe, "unmatched"), character())
  # one cell in 200 whose published limits miss its estimate: the match holds, and the cell is marked
  many <- do.call(rbind, lapply(seq_len(200), function(i) transform(py[1:5, ], GEO = paste0("R", i))))
  many$VALUE[many$GEO == "R7"][3] <- 1300
  me <- statcan_estimates(many)
  ma <- me[me$measure == "Age-standardized rate of potential years of life lost", ]
  expect_identical(attr(me, "unmatched"), character())
  expect_identical(ma$ci_source[ma$GEO == "R7"], "inconsistent")
  expect_identical(sum(ma$ci_source == "published"), 199L)
  # a limit no single measure fits is said, not guessed
  amb <- statcan_estimates(data.frame(GEO = "A", Statistics = c("Men", "Women", "Low 95% confidence interval"),
                                      VALUE = c(10, 12, 5), STATUS = ""))
  expect_identical(attr(amb, "unmatched"), "Low 95% confidence interval")
  # no statistics column: every value its own estimate, with no limits
  nc <- statcan_estimates(data.frame(GEO = c("A", "B"), Gender = "Total", UOM = "Number", VALUE = c(5, 6), STATUS = ""))
  expect_identical(nc$estimate, c(5, 6))
  expect_identical(nc$measure, c("Number", "Number"))
  expect_true(all(is.na(nc$lower)))
})

# shares and Wald limits that imply an effective sample size of exactly n
.wald <- function(p, n) {
  z <- stats::qnorm(0.975)
  s <- sqrt(p * (1 - p) / n)
  list(lo = 100 * (p - z * s), hi = 100 * (p + z * s))
}

test_that("ordinal_compare(): the probability of a higher rating, brute force over every pair", {
  lv <- c("poor", "fair", "good", "excellent")
  p1 <- c(0.1, 0.2, 0.3, 0.4)
  p0 <- c(0.25, 0.25, 0.3, 0.2)
  w1 <- .wald(p1, 400)
  w0 <- .wald(p0, 900)
  d <- data.frame(g = rep(c("A", "R"), each = 4), cat = rep(lv, 2), pct = 100 * c(p1, p0),
                  lo = c(w1$lo, w0$lo), hi = c(w1$hi, w0$hi))
  d <- rbind(d, data.frame(g = "A", cat = "not specified", pct = 3, lo = 2, hi = 4))
  r <- ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R")
  x <- rep(1:4, 100 * p1)
  y <- rep(1:4, 100 * p0)
  cmp <- outer(x, y, function(a, b) (a > b) + 0.5 * (a == b))
  expect_equal(r$prob_better, mean(cmp))
  expect_equal(r$delta, 2 * mean(cmp) - 1)
  expect_equal(r$n_eff, 400)
  expect_equal(r$n_eff_reference, 900)
  # the U-statistic variance from the placements of each sample in the other
  v <- mean((rowMeans(cmp) - mean(cmp))^2) / 400 + mean((colMeans(cmp) - mean(cmp))^2) / 900
  sl <- sqrt(v) / (mean(cmp) * (1 - mean(cmp)))
  expect_equal(r$upper, stats::plogis(stats::qlogis(mean(cmp)) + stats::qnorm(0.975) * sl))
  expect_identical(dim(attr(r, "shares")), c(2L, 4L))
  # identical distributions: one half, interval about it
  d2 <- d[d$cat %in% lv, ]
  d2[d2$g == "A", c("pct", "lo", "hi")] <- d2[d2$g == "R", c("pct", "lo", "hi")]
  r2 <- ordinal_compare(d2, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R")
  expect_equal(r2$prob_better, 0.5)
  expect_lt(r2$lower, 0.5)
  expect_gt(r2$upper, 0.5)
})

test_that("ordinal_compare(): the interval covers at its level over simulated surveys", {
  lv <- c("1", "2", "3", "4")
  p1 <- c(0.15, 0.3, 0.35, 0.2)
  p0 <- c(0.2, 0.3, 0.3, 0.2)
  x <- rep(1:4, 1e3 * p1)
  y <- rep(1:4, 1e3 * p0)
  truth <- mean(outer(x, y, function(a, b) (a > b) + 0.5 * (a == b)))
  withr::local_seed(11)
  hit <- vapply(seq_len(600), function(i) {
    c1 <- tabulate(sample(4, 500, TRUE, p1), 4) / 500
    c0 <- tabulate(sample(4, 700, TRUE, p0), 4) / 700
    w1 <- .wald(c1, 500)
    w0 <- .wald(c0, 700)
    d <- data.frame(g = rep(c("A", "R"), each = 4), cat = rep(lv, 2), pct = 100 * c(c1, c0),
                    lo = c(w1$lo, w0$lo), hi = c(w1$hi, w0$hi))
    r <- ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R")
    r$lower <= truth && truth <= r$upper
  }, NA)
  expect_gt(mean(hit), 0.92)
  expect_lt(mean(hit), 0.98)
})

test_that("ordinal_compare(): suppressed categories, caution and bad arguments", {
  lv <- c("low", "high")
  d <- data.frame(g = rep(c("A", "B", "R"), each = 2), cat = rep(lv, 3), pct = c(40, 60, 30, 70, 50, 50),
                  lo = c(35, 55, 25, 65, 45, 45), hi = c(45, 65, 35, 75, 55, 55), q = c("", "", "F", "", "", "E"))
  r <- ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R", quality = "q")
  expect_true(is.na(r$prob_better[r$group == "B"]))
  expect_true(all(r$use_with_caution))
  expect_error(ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = "low", reference = "R"), "two or more")
  expect_error(ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "Z"), "is not a group")
  expect_error(ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = c("x", "y"), reference = "R"),
               "no row of `data`")
  d$q[5] <- "x"
  expect_error(ordinal_compare(d, "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R", quality = "q"),
               "reference group's distribution")
  expect_error(ordinal_compare(rbind(d, d[1, ]), "g", "cat", "pct", "lo", "hi", levels = lv, reference = "A"),
               "has a category twice")
})

test_that("standardise_prevalence(): weighted mean and the root of the weighted variances", {
  z <- stats::qnorm(0.975)
  r <- standardise_prevalence(c(6, 4, 2), c(5, 3, 1), c(7, 5, 3), standard = c(2, 1, 1))
  expect_equal(r$estimate, sum(c(0.5, 0.25, 0.25) * c(6, 4, 2)))
  expect_equal(r$se, sqrt(sum(c(0.5, 0.25, 0.25)^2 * (1 / z)^2)))
  expect_equal(r$upper, r$estimate + z * r$se)
  r2 <- standardise_prevalence(c(6, 4, 2, 5, 5, 5), c(5, 3, 1, 4, 4, 4), c(7, 5, 3, 6, 6, 6), standard = c(1, 1, 1),
                               group = rep(c("a", "b"), each = 3), quality = c("", "x", "", "E", "", ""))
  expect_true(is.na(r2$estimate[1]))
  expect_true(r2$use_with_caution[2])
  expect_equal(r2$estimate[2], 5)
  expect_warning(r3 <- standardise_prevalence(1, 2, 3, 1), "do not contain their estimate")
  expect_true(is.na(r3$estimate))
  expect_error(standardise_prevalence(c(1, 2), c(0, 1), c(2, 3), c(1, 1, 1)), "has 2 age groups")
  expect_error(standardise_prevalence(c(1, 2), c(0, 1), 3, c(1, 1)), "same length")
  expect_error(standardise_prevalence(1, 0, 2, 1, quality = c("", "")), "one flag per row")
})

.wb <- function() {
  data.frame(group = rep(c("First Nations", "Metis"), each = 4),
             indicator = rep(c("Hopeful", "Total", "Distress", "Satisfied"), 2),
             pct = c(60, 100, 20, 50, 65, 100, 15, 55), lo = c(55, 100, 17, 45, 60, 100, 12, 50),
             hi = c(65, 100, 23, 55, 70, 100, 18, 60), q = c("", "", "", "E", "", "", "", ""))
}

test_that("wellness_profile(): wellness first, totals left out, suppressed values dropped", {
  w <- wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = c("Satisfied", "Hopeful"),
                        distress = "Distress",
                        domain = c(Hopeful = "spiritual", Satisfied = "mental", Distress = "mental"),
                        quality = "q")
  expect_s3_class(w, "rmbl_wellness_profile")
  expect_identical(w$indicator, rep(c("Satisfied", "Hopeful", "Distress"), each = 2))
  expect_identical(w$side, rep(c("wellness", "wellness", "distress"), each = 2))
  expect_identical(w$domain[3], "spiritual")
  expect_true(w$use_with_caution[1])
  expect_error(wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = "Nope",
                                distress = "Distress"),
               "not an indicator")
  expect_error(wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = "Hopeful",
                                distress = "Hopeful"),
               "both one of wellness")
  expect_error(wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = "Hopeful",
                                distress = "Distress", domain = "x"), "named character vector")
})

test_that("dual_continuum(): the strength ratio and its log-normal interval", {
  w <- wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = "Hopeful", distress = "Distress")
  dc <- dual_continuum(w, "Hopeful", "Distress")
  z <- stats::qnorm(0.975)
  sl <- sqrt(((log(65) - log(55)) / (2 * z))^2 + ((log(23) - log(17)) / (2 * z))^2)
  expect_equal(dc$strength_ratio[1], 3)
  expect_equal(dc$ratio_lower[1], exp(log(3) - z * sl))
  expect_error(dual_continuum(w, "Distress", "Distress"), "not a wellness indicator")
  expect_error(dual_continuum(w, "Hopeful", "Hopeful"), "not a distress indicator")
  expect_error(dual_continuum(data.frame(), "a", "b"), "must come from wellness_profile")
})

test_that("holistic_balance(): one when every domain is level; Atkinson's form otherwise", {
  d <- data.frame(g = rep(c("A", "B"), each = 4), dom = rep(c("physical", "emotional", "mental", "spiritual"), 2),
                  pct = c(50, 50, 50, 50, 80, 80, 20, 20), lo = c(47, 47, 47, 47, 77, 77, 17, 17),
                  hi = c(53, 53, 53, 53, 83, 83, 23, 23))
  r <- holistic_balance(d, "g", "dom", "pct", "lo", "hi", reps = 2000)
  expect_equal(r$balance[1], 1)
  expect_equal(r$balance[2], sqrt(0.8 * 0.2) / 0.5)
  expect_equal(r$level, c(50, 50))
  expect_lte(r$balance_upper[1], 1)
  expect_lt(r$balance_upper[2], 1)
  expect_identical(r$weakest_domain[2], "mental")
  expect_identical(holistic_balance(d, "g", "dom", "pct", "lo", "hi", reps = 500, seed = 4)$balance_lower,
                   holistic_balance(d, "g", "dom", "pct", "lo", "hi", reps = 500, seed = 4)$balance_lower)
  wt <- c(physical = 1, emotional = 1, mental = 1, spiritual = 3)
  r2 <- holistic_balance(d, "g", "dom", "pct", "lo", "hi", weights = wt, reps = 500)
  w <- wt / 6
  expect_equal(r2$balance[2], exp(sum(w * log(c(0.8, 0.8, 0.2, 0.2)))) / sum(w * c(0.8, 0.8, 0.2, 0.2)))
  expect_equal(r2$level[2], 100 * sum(w * c(0.8, 0.8, 0.2, 0.2)))
  d$q <- c("", "", "", "x", "", "", "", "")
  expect_true(is.na(holistic_balance(d, "g", "dom", "pct", "lo", "hi", quality = "q", reps = 200)$balance[1]))
  expect_error(holistic_balance(d, "g", "dom", "pct", "lo", "hi", weights = c(a = 1)), "named by the domains")
  expect_error(holistic_balance(d[d$dom == "mental", ], "g", "dom", "pct", "lo", "hi"), "two domains")
  d$pct[1] <- 100
  d$hi[1] <- 100
  expect_error(holistic_balance(d, "g", "dom", "pct", "lo", "hi"), "strictly between 0 and 100")
})

test_that("distinctions_test(): Cochran's Q and I^2, pan-Indigenous rows left out", {
  z <- stats::qnorm(0.975)
  d <- data.frame(g = c("First Nations", "Metis", "Inuit", "Total, Indigenous identity"),
                  y = c(34, 40, 37, 36), lo = c(32, 38, 34, 35), hi = c(36, 42, 40, 37))
  r <- distinctions_test(d, "g", "y", "lo", "hi")
  s <- c(4, 4, 6) / (2 * z)
  w <- 1 / s^2
  m <- sum(w * c(34, 40, 37)) / sum(w)
  q <- sum(w * (c(34, 40, 37) - m)^2)
  expect_equal(r$pooled, m)
  expect_equal(r$q, q)
  expect_identical(r$df, 2L)
  expect_equal(r$p_value, stats::pchisq(q, 2, lower.tail = FALSE))
  expect_equal(r$i2, (q - 2) / q)
  expect_identical(r$left_out, "Total, Indigenous identity")
  expect_output(print(r), "the groups differ")
  r0 <- distinctions_test(data.frame(g = c("a", "b"), y = c(5, 5), lo = c(4, 4), hi = c(6, 6)), "g", "y", "lo", "hi")
  expect_identical(r0$i2, 0)
  expect_output(print(r0), "not evidence that they are the same")
  expect_error(distinctions_test(d[1, ], "g", "y", "lo", "hi"), "two groups at least")
  expect_error(distinctions_test(rbind(d, d[1, ]), "g", "y", "lo", "hi"), "appears twice")
})

test_that("every Indigenous result draws itself and returns what it drew", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  g <- indigenous_gap(data.frame(g = c("First Nations", "Inuit", "Non-Indigenous"), e = c(45, 47, 61),
                                 lo = c(43, 43, 60), hi = c(47, 51, 62), q = c("", "F", "")),
                      "g", "e", "lo", "hi", quality = "q")
  expect_s3_class(g, "rmbl_indigenous_gap")
  expect_identical(nrow(plot(g)), 2L)
  expect_named(plot(g, what = "ratio"), c("group", "ratio", "ratio_lower", "ratio_upper"))
  expect_identical(nrow(plot(age_standardise(c(1, 2), c(100, 200), 1, group = c("a", "b")))), 2L)
  expect_identical(nrow(plot(standardise_prevalence(c(6, 4), c(5, 3), c(7, 5), c(1, 1)))), 1L)
  expect_identical(nrow(plot(exposure_trend(c(60, 95, 70), c(500, 520, 300)))), 3L)
  expect_identical(nrow(plot(trc_progress())), 5L)
  lv <- c("low", "high")
  oc <- ordinal_compare(data.frame(g = rep(c("A", "R"), each = 2), cat = rep(lv, 2), pct = c(40, 60, 50, 50),
                                   lo = c(35, 55, 45, 45), hi = c(45, 65, 55, 55)),
                        "g", "cat", "pct", "lo", "hi", levels = lv, reference = "R")
  expect_identical(dim(plot(oc)), c(2L, 2L))
  w <- wellness_profile(.wb(), "group", "indicator", "pct", "lo", "hi", wellness = "Hopeful", distress = "Distress")
  expect_identical(nrow(plot(w)), 4L)
  expect_identical(nrow(plot(dual_continuum(w, "Hopeful", "Distress"))), 2L)
  hb <- holistic_balance(.wb()[.wb()$indicator != "Total", ], "group", "indicator", "pct", "lo", "hi", reps = 200)
  expect_identical(dim(plot(hb)), c(2L, 3L))
  expect_identical(nrow(plot(distinctions_test(data.frame(g = c("a", "b"), y = c(5, 6), lo = c(4, 5), hi = c(6, 7)),
                                               "g", "y", "lo", "hi"))), 2L)
  expect_error(plot.rmbl_dsr(data.frame()), "rmbl_dsr object")
})
