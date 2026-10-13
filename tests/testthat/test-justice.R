# Courts and police-reported crime (R/justice.R). Every number is checked against an independent
# computation: binom.test() limits, survival::survfit(), the score equation behind Goodman's
# intervals, chisq.test(), a hand-written Cochran-Armitage statistic, MASS::kde2d(), brute-force
# pair counts and a full enumeration of permutations.

ext <- function(f) read.csv(system.file("extdata", f, package = "rmoriebricklayer"))

# ---- case_flow --------------------------------------------------------------------------------

test_that("case_flow(): clearance and its exact interval agree with binom.test()", {
  r <- c(120, 95, 130, 80, 0)
  d <- c(110, 101, 128, 92, 4)
  cf <- case_flow(r, d, window = 2)
  expect_s3_class(cf, "rmbl_case_flow")
  expect_equal(cf$clearance[1:4], d[1:4] / r[1:4])
  expect_true(is.na(cf$clearance[5]))
  for (i in 1:4) {
    ci <- stats::binom.test(d[i], d[i] + r[i])$conf.int
    expect_equal(c(cf$lower[i], cf$upper[i]), as.vector(ci / (1 - ci)), tolerance = 1e-12)
  }
  # disposed but nothing received: the ratio is unbounded above
  expect_identical(cf$upper[5], Inf)
  expect_equal(cf$net, r - d)
  expect_equal(cf$cumulative_net, cumsum(r - d))
  expect_true(is.na(cf$rolling_clearance[1]))
  expect_equal(cf$rolling_clearance[2:5], (d[1:4] + d[2:5]) / (r[1:4] + r[2:5]))
  ci <- stats::binom.test(d[3] + d[4], d[3] + d[4] + r[3] + r[4], conf.level = 0.9)$conf.int
  cf90 <- case_flow(r, d, window = 2, conf_level = 0.9)
  expect_equal(c(cf90$rolling_lower[4], cf90$rolling_upper[4]), as.vector(ci / (1 - ci)), tolerance = 1e-12)
  # nothing received and nothing disposed: no ratio and no interval
  z <- case_flow(c(0, 5), c(0, 5), window = 1)
  expect_true(is.na(z$clearance[1]) && is.na(z$lower[1]) && is.na(z$upper[1]))
  expect_equal(z$rolling_clearance, c(NA, 1))
})

test_that("case_flow(): pending gives the change and the periods to clear at the recent pace", {
  f <- ext("ocj_flow_ontario.csv")
  cf <- case_flow(f$received, f$disposed, pending = f$pending, period = f$month)
  expect_identical(nrow(cf), 24L)
  expect_equal(cf$pending_change, c(NA, diff(f$pending)))
  pace <- vapply(1:24, function(i) mean(f$disposed[max(1, i - 11):i]), 0)
  expect_equal(cf$periods_to_clear, f$pending / pace)
  # the published series (2026 edition, April 2024 to March 2026): 497,393 received and
  # 489,448 disposed over the 24 months
  expect_equal(sum(cf$received), 497393)
  expect_equal(sum(cf$disposed), 489448)
  expect_null(cf$cumulative_net)
  out <- capture.output(print(cf))
  expect_true(any(grepl(sprintf("clearance %.3f", 489448 / 497393), out, fixed = TRUE)))
  expect_true(any(grepl("Pending at the end: 148,473", out, fixed = TRUE)))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(cf)
  expect_equal(drawn$clearance, cf$clearance)
  expect_silent(plot(cf, what = "clearance", main = "Ontario"))
  expect_silent(plot(cf, what = "flow"))
  expect_silent(plot(cf, main = "Ontario Court of Justice, criminal cases"))
  # numeric periods and labels that are neither numbers nor months draw too
  expect_silent(plot(case_flow(f$received[1:6], f$disposed[1:6], period = 2001:2006, window = 3)))
  expect_silent(plot(case_flow(f$received[1:3], f$disposed[1:3], period = c("a", "b", "c"), window = 1)))
  expect_silent(plot(case_flow(f$received[1:3], f$disposed[1:3], period = c("2024-01-05", "2024-02-05", "2024-03-05"))))
})

test_that("case_flow(): bad input is refused in words", {
  expect_error(case_flow(numeric(0), numeric(0)), "empty")
  expect_error(case_flow(1:3, 1:2), "must have 3 values")
  expect_error(case_flow(c(1, -1), 1:2), "non-negative")
  expect_error(case_flow(c(1, NA), 1:2), "missing")
  expect_error(case_flow("a", 1), "numeric")
  expect_error(case_flow(1:2, 1:2, pending = 1), "must have 2")
  expect_error(case_flow(1:2, 1:2, period = c(1, 1)), "repeated")
  expect_error(case_flow(1:2, 1:2, period = c(1, NA)), "missing")
  expect_error(case_flow(1:2, 1:2, period = 1:3), "2 values")
  expect_error(case_flow(1:2, 1:2, window = 0), "at least 1")
  expect_error(case_flow(1:2, 1:2, window = 1.5), "whole number")
  expect_error(case_flow(1:2, 1:2, conf_level = 1), "between 0 and 1")
  expect_error(case_flow(1:2, 1:2, conf_level = c(0.9, 0.95)), "single number")
  expect_error(case_flow(c(1, Inf), 1:2), "finite")
})

# ---- life_table -------------------------------------------------------------------------------

test_that("life_table(): with no censoring it is Kaplan-Meier at the band edges (survival::survfit)", {
  skip_if_not_installed("survival")
  ev <- c(30, 12, 9, 5, 4)
  br <- c(0, 2, 4, 7, 10, 15)
  lt <- life_table(br, ev, conf_type = "log-log")
  tm <- rep(br[-1], ev)
  fit <- survival::survfit(survival::Surv(tm, rep(1, length(tm))) ~ 1, conf.type = "log-log")
  s <- summary(fit, times = br[-1])
  expect_equal(lt$survival, s$surv, tolerance = 1e-12)
  ok <- lt$survival > 0
  expect_equal(lt$se[ok], s$std.err[ok], tolerance = 1e-10)
  expect_equal(lt$conf_lower[ok], s$lower[ok], tolerance = 1e-10)
  expect_equal(lt$conf_upper[ok], s$upper[ok], tolerance = 1e-10)
  for (ct in c("log", "plain")) {
    fit2 <- survival::survfit(survival::Surv(tm, rep(1, length(tm))) ~ 1, conf.type = ct)
    s2 <- summary(fit2, times = br[-1])
    lt2 <- life_table(br, ev, conf_type = ct)
    expect_equal(lt2$conf_lower[ok], s2$lower[ok], tolerance = 1e-10, info = ct)
    expect_equal(lt2$conf_upper[ok], s2$upper[ok], tolerance = 1e-10, info = ct)
  }
  # the last band holds every remaining case: survival 0, no interval
  expect_identical(utils::tail(lt$survival, 1), 0)
  expect_true(is.na(utils::tail(lt$conf_lower, 1)))
})

test_that("life_table(): censored cases count as at risk for half their band (Cutler-Ederer)", {
  br <- c(0, 1, 2, 3, Inf)
  d <- c(10, 8, 5, 7)
  w <- c(4, 6, 2, 3)
  lt <- life_table(br, d, censored = w, conf_type = "plain")
  n <- sum(d + w)
  surv <- 1
  gw <- 0
  for (j in 1:4) {
    nj <- n - sum(d[seq_len(j - 1)] + w[seq_len(j - 1)])
    np <- nj - w[j] / 2
    q <- d[j] / np
    surv <- surv * (1 - q)
    if (q < 1) gw <- gw + q / (np * (1 - q))
    expect_equal(lt$entering[j], nj)
    expect_equal(lt$at_risk[j], np)
    expect_equal(lt$q[j], q)
    expect_equal(lt$survival[j], surv)
    if (j < 4) {
      expect_equal(lt$se[j], surv * sqrt(gw))
      expect_equal(lt$hazard[j], d[j] / (1 * (np - d[j] / 2)))
      z <- stats::qnorm(0.975)
      expect_equal(lt$conf_lower[j], max(surv - z * surv * sqrt(gw), 0))
    }
  }
  # an open band has no hazard
  expect_true(is.na(lt$hazard[4]))
  expect_equal(life_table(br, d, censored = 0)$censored, rep(0, 4))
})

test_that("life_table(): the median is interpolated inside its band, or reported as open", {
  lt <- life_table(c(0, 10, 20), c(30, 70))
  # survival 1 -> 0.7 -> 0: crosses 0.5 in the second band, 10 + 10 * (0.7 - 0.5) / 0.7
  expect_equal(as.numeric(attr(lt, "median")), 10 + 10 * 0.2 / 0.7)
  expect_true(any(grepl("Median time: 12.9", capture.output(print(lt)), fixed = TRUE)))
  lt2 <- life_table(c(0, 10, Inf), c(30, 70))
  expect_identical(as.numeric(attr(lt2, "median")), Inf)
  expect_match(attr(attr(lt2, "median"), "note"), "open band")
  expect_true(any(grepl("open band", capture.output(print(lt2)))))
  lt3 <- life_table(c(0, 10, 20), c(10, 20), censored = c(0, 70))
  expect_match(attr(attr(lt3, "median"), "note"), "never falls")
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (x in list(lt, lt2, lt3)) {
    drawn <- plot(x)
    expect_equal(drawn$survival, c(1, x$survival))
  }
  expect_silent(plot(life_table(c(0, Inf), 5)))
})

test_that("life_table(): published band labels give the same table as the edges", {
  d <- ext("ocj_time_to_disposition.csv")
  f <- ext("ocj_flow_ontario.csv")
  ev <- unlist(d[24, c("under_10", "m10_15", "m15_18", "over_18")]) * f$disposed[24]
  a <- life_table(c(0, 10, 15, 18, Inf), ev)
  b <- life_table(c("Under 10 Months", "Between 10-15 Months", "Between 15-18 Months", "Over 18 Months"), ev)
  expect_equal(as.data.frame(a), as.data.frame(b))
  # the published shares are rounded and need not add to one; the table takes them as counts,
  # so the share still open after 10 months is one less the first share over their sum
  expect_equal(a$survival[1], 1 - d$under_10[24] / sum(ev / f$disposed[24]), tolerance = 1e-12)
  expect_error(life_table(c("Under 10", "12-15"), 1:2), "contiguous")
  expect_error(life_table(c("Over 10", "10-15"), 1:2), "only the last band")
  expect_error(life_table(c("ten", "10-15"), 1:2), "could not read")
})

test_that("life_table(): bad input is refused in words", {
  expect_error(life_table(1, 1), "at least two")
  expect_error(life_table(c(0, 2, 1), 1:2), "increasing")
  expect_error(life_table(c(0, Inf, 5), 1:2), "increasing|only the last")
  expect_error(life_table(c(-Inf, 1, 2), 1:2), "only the last")
  expect_error(life_table(c(0, 1, 2), 1), "must have 2")
  expect_error(life_table(c(0, 1, 2), c(1, -1)), "non-negative")
  expect_error(life_table(c(0, 1, 2), c(0, 0)), "no cases")
  expect_error(life_table(c(0, 1, 2), 1:2, censored = 1:3), "must have 2")
  expect_error(life_table(c(0, 1, 2), 1:2, conf_level = 2), "between 0 and 1")
  expect_error(life_table(c(0, 1, 2), 1:2, conf_type = "logit"), "should be one of")
})

# ---- disposition_mix --------------------------------------------------------------------------

test_that("disposition_mix(): Goodman limits solve the score equation with A = chi-square(alpha/k)", {
  x <- ext("ocj_dispositions.csv")
  m <- disposition_mix(x[, -(1:2)], period = x$year)
  expect_s3_class(m, "rmbl_disposition_mix")
  k <- 7
  a <- stats::qchisq(1 - 0.05 / k, 1)
  for (r in c(1, 9, 20, 28)) {
    s <- m$shares[r, ]
    f <- function(p) (p - s$share)^2 - a * p * (1 - p) / s$total
    lo <- stats::uniroot(f, c(1e-12, s$share), tol = 1e-14)$root
    hi <- stats::uniroot(f, c(s$share, 1 - 1e-12), tol = 1e-14)$root
    expect_equal(c(s$lower, s$upper), c(lo, hi), tolerance = 1e-8)
  }
  # the shares of each period add to one and use the published totals
  tot <- tapply(m$shares$share, m$shares$period, sum)
  expect_equal(as.vector(tot), rep(1, 12))
  # the 2022 provincial total of cases disposed
  expect_equal(m$shares$total[m$shares$period == 2022][1], 209961)
})

test_that("disposition_mix(): homogeneity matches chisq.test() and the trend matches Cochran-Armitage", {
  x <- ext("ocj_dispositions.csv")
  cnt <- as.matrix(x[, -(1:2)])
  m <- disposition_mix(x[, -(1:2)], period = x$year)
  ct <- suppressWarnings(stats::chisq.test(cnt, correct = FALSE))
  expect_equal(m$homogeneity$statistic, unname(ct$statistic))
  expect_equal(m$homogeneity$df, 66)
  expect_equal(m$homogeneity$cramers_v, sqrt(unname(ct$statistic) / (sum(cnt) * 6)))
  tot <- rowSums(cnt)
  sc <- 1:12
  for (j in 1:7) {
    xj <- cnt[, j]
    pbar <- sum(xj) / sum(tot)
    num <- sum(sc * (xj - tot * pbar))^2
    den <- pbar * (1 - pbar) * (sum(tot * sc^2) - sum(tot * sc)^2 / sum(tot))
    expect_equal(m$trend$statistic[j], num / den, tolerance = 1e-9, info = colnames(cnt)[j])
  }
  expect_equal(m$trend$p_holm, stats::p.adjust(m$trend$p_value, "holm"))
  expect_equal(m$trend$change[1], unname(cnt[12, 1] / tot[12] - cnt[1, 1] / tot[1]))
  # years as scores: 2020 and 2023 are missing from the series, and the scores say so
  m2 <- disposition_mix(x[, -(1:2)], period = x$year, scores = x$year)
  expect_false(isTRUE(all.equal(m$trend$statistic, m2$trend$statistic)))
  out <- capture.output(print(m))
  expect_true(any(grepl(sprintf("chi-square %.1f on 66 df", m$homogeneity$statistic), out, fixed = TRUE)))
  expect_true(any(grepl("Cochran-Armitage", out, fixed = TRUE)))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(m)
  expect_equal(drawn$share, m$shares$share)
})

test_that("disposition_mix(): one or two periods, empty outcomes, and bad input", {
  one <- disposition_mix(matrix(c(5, 3, 2), 1, dimnames = list(NULL, c("a", "b", "c"))))
  expect_null(one$homogeneity)
  expect_null(one$trend)
  expect_equal(one$shares$share, c(0.5, 0.3, 0.2))
  two <- disposition_mix(rbind(c(5, 5), c(8, 2)), period = c("x", "y"))
  expect_false(is.null(two$homogeneity))
  expect_null(two$trend)
  expect_identical(two$outcome, c("outcome_1", "outcome_2"))
  # an outcome that never happens is left out of the chi-square and has no trend
  three <- disposition_mix(cbind(a = c(5, 6, 7), b = c(5, 4, 3), c = 0))
  expect_equal(three$homogeneity$df, 2)
  expect_true(is.na(three$trend$statistic[3]))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_silent(plot(one))
  expect_silent(plot(disposition_mix(rbind(c(5, 5), c(8, 2), c(6, 4)), period = c("2024-01", "2024-02", "2024-03"))))
  expect_silent(plot(two))
  expect_output(print(one), "Outcome shares")
  expect_error(disposition_mix(data.frame(a = 1:2, b = c("x", "y"))), "not numeric")
  expect_error(disposition_mix(list(1, 2)), "numeric matrix")
  expect_error(disposition_mix(matrix(1:3, 3)), "two outcomes")
  expect_error(disposition_mix(rbind(c(1, 2), c(0, 0))), "has no cases")
  expect_error(disposition_mix(rbind(c(1, -2), c(1, 1))), "non-negative")
  expect_error(disposition_mix(rbind(1:2, 2:3, 3:4), scores = c(1, 1, 1)), "not all equal")
  expect_error(disposition_mix(rbind(1:2, 2:3, 3:4), scores = 1:2), "3 finite")
  expect_error(disposition_mix(rbind(1:2, 2:3), period = c(1, 1)), "repeated")
})

# ---- crime_density ----------------------------------------------------------------------------

test_that("crime_density(): the binned surface agrees with the direct sum (MASS::kde2d)", {
  skip_if_not_installed("MASS")
  set.seed(42)
  x <- c(stats::rnorm(150, 0, 800), stats::rnorm(80, 2000, 300))
  y <- c(stats::rnorm(150, 0, 600), stats::rnorm(80, 1500, 300))
  kd <- crime_density(x, y, bandwidth = c(0.4, 0.3), n_grid = 300, coords = "planar")
  px <- (x - stats::median(x)) / 1000
  py <- (y - stats::median(y)) / 1000
  ref <- MASS::kde2d(px, py, h = 4 * c(0.4, 0.3), n = 300, lims = c(range(kd$x), range(kd$y)))
  expect_equal(kd$x, ref$x)
  expect_equal(max(abs(kd$field - 230 * ref$z)) / max(kd$field), 0, tolerance = 2e-3)
  cell <- diff(kd$x[1:2]) * diff(kd$y[1:2])
  expect_equal(sum(kd$field) * cell, 230, tolerance = 1e-3)
  expect_true(kd$regions$area_km2[1] < kd$regions$area_km2[2])
  expect_equal(kd$regions$coverage, c(0.5, 0.9))
  # weights scale the surface
  kd2 <- crime_density(x, y, weights = rep(2, 230), bandwidth = c(0.4, 0.3), n_grid = 300, coords = "planar")
  expect_equal(kd2$field, 2 * kd$field)
  # the default bandwidth is Scott's rule, sd * n^(-1/6) in each direction
  kd3 <- crime_density(x, y, n_grid = 60, coords = "planar")
  expect_equal(kd3$bandwidth, c(stats::sd(px), stats::sd(py)) * 230^(-1 / 6))
})

test_that("crime_density(): degrees are projected to kilometres and unlocated incidents dropped", {
  b <- ext("tps_break_enter_d14_2024.csv")
  # every one of the 508 occurrences has a published location (the all-NA row 515 of the file before
  # 0.5.12 was a subsetting artefact; review of e57fed5, E5); an unlocated one is dropped and said
  expect_message(kd <- crime_density(c(b$lon, NA), c(b$lat, NA), n_grid = 80), "1 incident without a usable location")
  expect_identical(kd$n, 508L)
  expect_identical(kd$dropped, 1L)
  expect_identical(length(kd$lon), 80L)
  # one kilometre north is 1/6371.0088 radians of latitude
  expect_equal(diff(kd$lat[1:2]) / diff(kd$y[1:2]), 180 / pi / 6371.0088)
  expect_equal(diff(kd$lon[1:2]) / diff(kd$x[1:2]), 180 / pi / 6371.0088 / cos(kd$centre[["lat"]] * pi / 180))
  expect_message(crime_density(c(b$lon[1:20], 0), c(b$lat[1:20], 0), n_grid = 40), "1 incident")
  out <- capture.output(print(kd))
  expect_true(any(grepl("508 incidents (1 without a location dropped)", out, fixed = TRUE)))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(kd)
  expect_equal(drawn$density, as.vector(kd$field))
  expect_silent(plot(kd, points = FALSE, palette = "sequential"))
  expect_silent(plot(crime_density(b$lon[2:60], b$lat[2:60], n_grid = 50, coverage = 0.75)))
  expect_silent(plot(crime_density(c(0, 1000, 500, 200), c(0, 300, 900, 100), bandwidth = 0.3, coords = "planar")))
})

test_that("crime_density(): bad input is refused in words", {
  expect_error(crime_density(1:3, 1:2), "same length")
  expect_error(crime_density("a", 1), "numeric")
  expect_error(crime_density(c(200, 10), c(1, 2)), "not a longitude")
  expect_error(suppressMessages(crime_density(c(1, NA), c(1, 2))), "at least two")
  expect_error(crime_density(c(1, 1, 1), c(1, 2, 3)), "do not spread")
  expect_error(crime_density(1:3, 1:3, bandwidth = -1), "positive")
  expect_error(crime_density(1:3, 1:3, bandwidth = 1:3), "one or two")
  expect_error(crime_density(1:3, 1:3, n_grid = 5), "10 to 2000")
  expect_error(crime_density(1:3, 1:3, coverage = 1), "strictly between")
  expect_error(crime_density(1:3, 1:3, weights = c(1, -1, 1)), "non-negative")
  expect_error(crime_density(1:3, 1:3, weights = c(0, 0, 0)), "positive weight")
  expect_warning(crime_density(c(0, 50, 100), c(0, 50, 100), bandwidth = 0.001, n_grid = 10, coords = "planar"),
                 "wider than the bandwidth")
})

# ---- knox_test --------------------------------------------------------------------------------

knox_brute <- function(x, y, t, sb, tb) {
  n <- length(x)
  o <- matrix(0, length(sb), length(tb))
  sc <- numeric(length(sb))
  tc <- numeric(length(tb))
  for (i in 1:(n - 1)) for (j in (i + 1):n) {
    d <- sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2)
    dt <- abs(t[i] - t[j])
    s <- if (d <= sb[length(sb)]) which(d <= sb)[1] else NA
    u <- if (dt <= tb[length(tb)]) which(dt <= tb)[1] else NA
    if (!is.na(s)) sc[s] <- sc[s] + 1
    if (!is.na(u)) tc[u] <- tc[u] + 1
    if (!is.na(s) && !is.na(u)) o[s, u] <- o[s, u] + 1
  }
  list(o = o, e = outer(sc, tc) / (n * (n - 1) / 2))
}

test_that("knox_test(): observed and expected counts match a brute-force count over all pairs", {
  set.seed(7)
  n <- 120
  x <- stats::runif(n, 0, 2000)
  y <- stats::runif(n, 0, 2000)
  t <- sample(0:90, n, replace = TRUE)
  # a coincident pair and a same-day pair land in the first bands
  x[2] <- x[1]
  y[2] <- y[1]
  t[2] <- t[1]
  sb <- c(150, 300, 600)
  tb <- c(3, 10, 30)
  kn <- knox_test(x, y, t, sb, tb, nsim = 99, seed = 3, coords = "planar")
  br <- knox_brute(x, y, t, sb, tb)
  expect_equal(kn$table$observed, as.vector(br$o))
  expect_equal(kn$table$expected, as.vector(br$e))
  expect_equal(kn$table$ratio, as.vector(br$o / br$e))
  expect_true(all(kn$table$p_value > 0 & kn$table$p_value <= 1))
  expect_equal(kn$table$p_value * 100, round(kn$table$p_value * 100))
})

test_that("knox_test(): the expected count is the exact mean over every permutation of the times", {
  x <- c(0, 50, 90, 400, 420)
  y <- c(0, 20, 60, 10, 300)
  t <- c(0, 2, 9, 3, 20)
  sb <- c(100, 500)
  tb <- c(4, 25)
  kn <- knox_test(x, y, t, sb, tb, nsim = 19, seed = 1, coords = "planar")
  perms <- as.matrix(expand.grid(rep(list(1:5), 5)))
  perms <- perms[apply(perms, 1, function(p) length(unique(p)) == 5), ]
  expect_identical(nrow(perms), 120L)
  tot <- 0
  for (k in seq_len(nrow(perms))) tot <- tot + knox_brute(x, y, t[perms[k, ]], sb, tb)$o
  expect_equal(kn$table$expected, as.vector(tot / 120))
})

test_that("knox_test(): seeds, dates, degrees and the near-repeat signal in the shipped excerpt", {
  b <- ext("tps_break_enter_d14_2024.csv")
  b <- b[!is.na(b$lon), ]
  had <- exists(".Random.seed", globalenv())
  set.seed(11)
  before <- .Random.seed
  k1 <- knox_test(b$lon, b$lat, as.Date(b$occ_date), c(100, 200), c(7, 14), nsim = 99, seed = 5)
  expect_identical(.Random.seed, before)
  k2 <- knox_test(b$lon, b$lat, as.POSIXct(paste(b$occ_date, "12:00"), tz = "UTC"), c(100, 200), c(7, 14),
                  nsim = 99, seed = 5)
  expect_equal(k1$table, k2$table)
  # break-ins within 100 m and a week of each other: the published near-repeat pattern
  expect_gt(k1$table$ratio[1], 1.5)
  expect_lt(k1$table$p_value[1], 0.05)
  out <- capture.output(print(k1))
  expect_true(any(grepl("0-100 m", out, fixed = TRUE)))
  expect_true(any(grepl("not adjusted", out, fixed = TRUE)))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(k1)
  expect_equal(drawn$ratio, k1$table$ratio)
  # a cell with nothing expected is drawn and printed as a dash
  k3 <- knox_test(c(0, 10, 5000), c(0, 0, 0), c(0, 100, 200), c(20, 40), c(1, 2), nsim = 19, coords = "planar")
  expect_true(all(is.na(k3$table$ratio)))
  expect_true(any(grepl(" - ", capture.output(print(k3)), fixed = TRUE)))
  expect_silent(plot(k3))
  expect_silent(plot(k1, palette = "diverging", main = "D14"))
})

test_that("knox_test(): bad input is refused in words", {
  expect_error(knox_test(1:3, 1:2, 1:3, 1, 1), "same length")
  expect_error(knox_test(c(1, NA, 3), 1:3, 1:3, 1, 1, coords = "planar"), "finite")
  expect_error(knox_test(1:3, 1:3, 1:3, c(2, 1), 1, coords = "planar"), "increasing")
  expect_error(knox_test(1:3, 1:3, 1:3, 1, 0, coords = "planar"), "positive")
  expect_error(knox_test(1:3, 1:3, 1:3, 1, 1, nsim = 5, coords = "planar"), "at least 19")
  expect_error(knox_test(1:2, 1:2, 1:2, 1, 1, coords = "planar"), "three incidents")
  expect_error(knox_test(c(500, 1, 2), 1:3, 1:3, 1, 1), "not longitudes")
  expect_error(knox_test(1:3, 1:3, 1:3, 1, 1, seed = "x", coords = "planar"), "numeric")
  expect_error(knox_test(1:3, 1:3, 1:3, 1, 1, seed = 1:2, coords = "planar"), "single whole number")
  expect_error(knox_test(rep(0, 50), rep(0, 50), 1:50, 10, 5, max_pairs = 100, coords = "planar"),
               "candidate pairs")
})

# ---- layout on small and large devices -------------------------------------------------------

test_that("panels follow the device: one row when wide, a grid when small", {
  dev <- function(w, h, n) {
    grDevices::pdf(NULL, width = w, height = h)
    on.exit(grDevices::dev.off())
    .bl_panel_grid(n)
  }
  expect_identical(dev(9, 6, 2), c(1L, 2L))
  expect_identical(dev(9, 6, 4), c(2L, 2L))
  expect_identical(dev(12, 4, 3), c(1L, 3L))
  expect_identical(dev(4, 8, 2), c(2L, 1L))
  # four panels on a 3.5 by 3 inch device: no grid has room for the margins, so the squarest
  expect_identical(dev(3.5, 3, 4), c(2L, 2L))
  expect_identical(dev(5, 5, 1), c(1L, 1L))
})

test_that("the y title sits outside the tick labels, or is left off when there is no room", {
  grDevices::pdf(NULL, width = 6, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(4, 7, 2, 1), las = 1)
  graphics::plot(1:5, c(21000, 23000, 22000, 25000, 24000), ylab = "")
  expect_identical(.bl_ylab("Count"), "Count")
  # a title longer than the plot is tall is shortened with an ellipsis
  long <- strrep("Disposed per case received ", 6)
  expect_match(.bl_ylab(long), "[.][.][.]$")
  expect_null(.bl_ylab(NULL))
  graphics::par(mar = c(4, 2, 2, 1))
  graphics::plot(1:5, c(21000, 23000, 22000, 25000, 24000), ylab = "")
  expect_null(.bl_ylab("Count"))
})

test_that("the panel key is measured at the size it is drawn, so it wraps instead of running off", {
  grDevices::pdf(NULL, width = 3.5, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(2, 2), oma = c(2.4, 0, 0, 0), mar = c(1, 1, 1, 1))
  for (i in 1:4) graphics::plot(1)
  lines <- .bl_panel_key(c("A: Average daily population", "B: Average length of stay (days)"))
  expect_length(lines, 2L)
  expect_true(all(graphics::strwidth(lines, units = "inches", cex = 0.8 / graphics::par("cex")) <=
                    graphics::par("din")[1] * 0.96))
})

test_that("every new plot draws on a small, a middling and a large device without a warning", {
  f <- ext("ocj_flow_ontario.csv")
  d <- ext("ocj_time_to_disposition.csv")
  x <- ext("ocj_dispositions.csv")
  b <- ext("tps_break_enter_d14_2024.csv")
  b <- b[!is.na(b$lon), ][1:150, ]
  objs <- list(case_flow(f$received, f$disposed, pending = f$pending, period = f$month),
               life_table(c(0, 10, 15, 18, Inf), unlist(d[24, 2:5]) * f$disposed[24]),
               disposition_mix(x[, -(1:2)], period = x$year),
               crime_density(b$lon, b$lat, n_grid = 60),
               knox_test(b$lon, b$lat, as.Date(b$occ_date), c(100, 200), c(7, 14), nsim = 19, seed = 1),
               stock_flow(days = c(1350000, 1460000, 1510000), people = c(30000, 32000, 31000), period = 2021:2023))
  for (sz in list(c(3.5, 3), c(5, 4), c(9, 6))) {
    grDevices::pdf(NULL, width = sz[1], height = sz[2])
    for (o in objs) expect_no_warning(plot(o))
    grDevices::dev.off()
  }
})

# ---- clearance_decomposition ----------------------------------------------------------------

test_that("clearance_decomposition(): the rate and mix effects add exactly to the change (Kitagawa)", {
  g <- ext("ocj_offence_groups.csv")
  g <- g[g$year %in% c(2014, 2022), ]
  cd <- clearance_decomposition(g$disposed, g$received, g$offence_group, g$year)
  expect_s3_class(cd, "rmbl_clearance_decomposition")
  o <- cd$overall
  a <- g[g$year == 2014, ]
  b <- g[g$year == 2022, ]
  b <- b[match(a$offence_group, b$offence_group), ]
  expect_equal(o$rate_a, sum(a$disposed) / sum(a$received))
  expect_equal(o$rate_b, sum(b$disposed) / sum(b$received))
  expect_equal(o$rate_effect + o$mix_effect, o$change, tolerance = 1e-10)
  expect_equal(sum(cd$groups$rate_effect), o$rate_effect)
  expect_equal(sum(cd$groups$mix_effect), o$mix_effect)
  # independently: the rate effect is the rate change at the average mix, and the standardised
  # rates apply the 2022 rates to the 2014 and to the average mix
  wa <- a$received / sum(a$received)
  wb <- b$received / sum(b$received)
  ra <- a$disposed / a$received
  rb <- b$disposed / b$received
  expect_equal(o$rate_effect, sum((wa + wb) / 2 * rb) - sum((wa + wb) / 2 * ra))
  expect_equal(o$standardised_on_base, sum(wa * rb))
  expect_equal(o$standardised_on_average, sum((wa + wb) / 2 * rb))
  # the published 2014 and 2022 totals: the aggregate fell while the rates at a fixed mix rose
  expect_identical(cd$simpson$type, "mix")
  expect_lt(o$change, 0)
  expect_gt(o$rate_effect, 0)
  expect_identical(c(cd$simpson$up, cd$simpson$down), c(4L, 2L))
  # a part's mix term is negative when work moved toward a part below the average rate
  person <- cd$groups[cd$groups$group == "Crimes Against the Person", ]
  expect_lt(person$mix_effect, 0)
  expect_gt(person$weight_b, person$weight_a)
})

test_that("clearance_decomposition(): each part's interval is poisson.test()'s exact interval", {
  g <- ext("ocj_offence_groups.csv")
  g <- g[g$year %in% c(2014, 2022), ]
  cd <- clearance_decomposition(g$disposed, g$received, g$offence_group, g$year, conf_level = 0.9)
  for (i in seq_len(nrow(cd$groups))) {
    r <- cd$groups[i, ]
    ref <- stats::poisson.test(c(r$numerator_b, r$numerator_a), c(r$denominator_b, r$denominator_a),
                               conf.level = 0.9)
    expect_equal(c(r$lower, r$upper), as.vector(ref$conf.int), tolerance = 1e-10, info = r$group)
    expect_equal(r$rate_ratio, unname(ref$estimate), info = r$group)
  }
  crude <- cd$rate_ratio[cd$rate_ratio$estimate == "crude", ]
  ref <- stats::poisson.test(c(sum(cd$groups$numerator_b), sum(cd$groups$numerator_a)),
                             c(sum(cd$groups$denominator_b), sum(cd$groups$denominator_a)), conf.level = 0.9)
  expect_equal(c(crude$lower, crude$upper), as.vector(ref$conf.int), tolerance = 1e-10)
})

test_that("clearance_decomposition(): the Mantel-Haenszel ratio and its Greenland-Robins variance", {
  # one part: the MH ratio is the crude ratio and the variance of its log is 1/a + 1/b
  one <- clearance_decomposition(c(40, 90), c(100, 150), c("g", "g"), c(1, 2))
  mh <- one$rate_ratio[2, ]
  expect_equal(mh$ratio, (90 / 150) / (40 / 100))
  z <- stats::qnorm(0.975)
  expect_equal(c(mh$lower, mh$upper), mh$ratio * exp(c(-1, 1) * z * sqrt(1 / 40 + 1 / 90)))
  expect_equal(mh$p_value, 2 * stats::pnorm(-abs(log(mh$ratio)) / sqrt(1 / 40 + 1 / 90)))
  # many parts with a common ratio: the MH estimate agrees with the Poisson regression with a term
  # per part, the maximum-likelihood estimate of the same common ratio
  set.seed(5)
  k <- 8
  den_a <- round(stats::runif(k, 2000, 20000))
  den_b <- round(stats::runif(k, 2000, 20000))
  rate <- stats::runif(k, 0.3, 1.2)
  na <- stats::rpois(k, den_a * rate)
  nb <- stats::rpois(k, den_b * rate * 1.1)
  cd <- clearance_decomposition(c(na, nb), c(den_a, den_b), rep(letters[1:k], 2), rep(c("a", "b"), each = k))
  d <- data.frame(n = c(na, nb), t = c(den_a, den_b), part = factor(rep(1:k, 2)), b = rep(0:1, each = k))
  fit <- stats::glm(n ~ part + b + offset(log(t)), family = stats::poisson(), data = d)
  expect_equal(cd$rate_ratio$ratio[2], unname(exp(stats::coef(fit)["b"])), tolerance = 2e-3)
  se_glm <- sqrt(diag(stats::vcov(fit)))["b"]
  se_mh <- log(cd$rate_ratio$upper[2] / cd$rate_ratio$ratio[2]) / z
  expect_equal(se_mh, unname(se_glm), tolerance = 0.02)
})

test_that("clearance_decomposition(): the MH interval covers the common ratio about as often as it should", {
  set.seed(11)
  k <- 5
  den <- c(400, 900, 1500, 300, 700)
  rate <- c(0.5, 0.8, 1, 0.6, 0.9)
  hits <- vapply(1:400, function(i) {
    na <- stats::rpois(k, den * rate)
    nb <- stats::rpois(k, den * 1.3 * rate * 1.2)
    rr <- clearance_decomposition(c(na, nb), c(den, den * 1.3), rep(1:k, 2), rep(1:2, each = k))$rate_ratio[2, ]
    rr$lower <= 1.2 && 1.2 <= rr$upper
  }, logical(1))
  expect_gt(mean(hits), 0.92)
  expect_lt(mean(hits), 0.98)
})

test_that("clearance_decomposition(): a reversal in every part, no reversal, and the base argument", {
  # both parts clear more in B, but B's work moved to the slow part: the aggregate falls
  full <- clearance_decomposition(numerator = c(90, 20, 19, 70), denominator = c(100, 100, 20, 280),
                                  group = c("fast", "slow", "fast", "slow"), compare = c("A", "A", "B", "B"))
  expect_identical(full$simpson$type, "full")
  expect_true(all(full$groups$rate_b > full$groups$rate_a))
  expect_lt(full$overall$change, 0)
  expect_true(any(grepl("every part moved the other way", capture.output(print(full)))))
  none <- clearance_decomposition(c(50, 60, 55, 70), c(100, 100, 100, 100), c("x", "y", "x", "y"), c(1, 1, 2, 2))
  expect_identical(none$simpson$type, "none")
  expect_true(any(grepl("No reversal", capture.output(print(none)))))
  flip <- clearance_decomposition(c(50, 60, 55, 70), c(100, 100, 100, 100), c("x", "y", "x", "y"), c(1, 1, 2, 2),
                                  base = 2)
  expect_identical(flip$compare, c(2, 1))
  expect_equal(flip$overall$change, -none$overall$change)
  # a part that does not change has no arrow; an unchanged aggregate is not a reversal
  same <- clearance_decomposition(c(5, 5, 5, 5), c(10, 10, 10, 10), c("x", "y", "x", "y"), c(1, 1, 2, 2))
  expect_identical(same$simpson$type, "none")
  pdf(NULL, width = 9, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_silent(plot(same))
  expect_silent(plot(full, main = "Constructed reversal"))
})

test_that("clearance_decomposition(): the plot adapts to the device and draws what it is asked", {
  g <- ext("ocj_offence_groups.csv")
  g <- g[g$year %in% c(2014, 2022), ]
  cd <- clearance_decomposition(g$disposed, g$received, g$offence_group, g$year)
  out <- capture.output(print(cd))
  expect_true(any(grepl("Simpson's paradox through the mix", out, fixed = TRUE)))
  expect_true(any(grepl("Mantel-Haenszel", out, fixed = TRUE)))
  for (sz in list(c(3.5, 3), c(5, 4), c(9, 5))) {
    grDevices::pdf(NULL, width = sz[1], height = sz[2])
    expect_no_warning(drawn <- plot(cd))
    # drawn in order of rate (lowest at the bottom); the same parts, the same values
    expect_equal(drawn$rate_b[match(cd$groups$group, drawn$group)], cd$groups$rate_b)
    expect_identical(drawn$group, drawn$group[order((drawn$rate_a + drawn$rate_b) / 2)])
    expect_no_warning(plot(cd, what = "mix"))
    expect_no_warning(plot(cd, what = c("rates", "mix", "effects")))
    expect_no_warning(plot(cd, what = "effects", main = "Effects"))
    expect_no_warning(plot(cd, what = "rates", main = "Rates"))
    expect_no_warning(plot(cd, what = c("rates", "effects")))
    grDevices::dev.off()
  }
  # courts across the Toronto consolidation: the court_series column lines the years up
  c <- ext("ocj_courts.csv")
  c <- stats::aggregate(cbind(received, disposed) ~ year + court_series, c, sum)
  c <- c[c$year %in% c(2012, 2024), ]
  c <- c[c$court_series %in% names(which(table(c$court_series) == 2)), ]
  cc <- clearance_decomposition(c$disposed, c$received, c$court_series, c$year)
  expect_equal(cc$overall$rate_effect + cc$overall$mix_effect, cc$overall$change, tolerance = 1e-10)
  expect_true("Toronto" %in% cc$groups$group)
})

test_that("clearance_decomposition(): bad input is refused in words", {
  expect_error(clearance_decomposition(numeric(0), numeric(0), character(0), character(0)), "empty")
  expect_error(clearance_decomposition(1:2, 1:2, "a", 1:2), "same length")
  expect_error(clearance_decomposition(1:2, 1:2, c("a", NA), 1:2), "missing")
  expect_error(clearance_decomposition(1:3, 1:3, c("a", "a", "a"), 1:3), "exactly two")
  expect_error(clearance_decomposition(1:2, 1:2, c("a", "a"), 1:2, base = 3), "one of the two")
  expect_error(clearance_decomposition(1:3, 1:3, c("a", "a", "b"), c(1, 1, 2)), "more than once")
  expect_error(clearance_decomposition(1:3, 1:3, c("a", "b", "a"), c(1, 1, 2)), "only one comparison")
  expect_error(clearance_decomposition(1:2, c(0, 1), c("a", "a"), 1:2), "zero denominator")
  expect_error(clearance_decomposition(c(-1, 1), 1:2, c("a", "a"), 1:2), "non-negative")
  expect_error(clearance_decomposition(1:2, 1:2, c("a", "a"), 1:2, conf_level = 0), "between 0 and 1")
})

test_that("row labels are wrapped at a space, or cut when there is none", {
  grDevices::pdf(NULL, width = 4, height = 4)
  on.exit(grDevices::dev.off(), add = TRUE)
  w <- .bl_label_wrap(c("short", "Crimes Against the Person Today", strrep("x", 60)))
  expect_identical(w$labels[1], "short")
  expect_match(w$labels[2], "\n", fixed = TRUE)
  expect_match(w$labels[3], "[.][.][.]$")
  expect_gt(w$mar, 1)
})

test_that("a subset of a case-flow or life-table result prints as a plain table", {
  cf <- case_flow(c(10, 12, 9), c(9, 13, 9), window = 2)
  expect_output(print(cf[2:3, c("period", "clearance")]), "clearance")
  lt <- life_table(c(0, 1, 2), c(3, 4))
  expect_output(print(lt[1, c("lower", "survival")]), "survival")
})


test_that("clearance_decomposition(): many parts are drawn as the ones that moved it most, the rest summed", {
  c <- ext("ocj_courts.csv")
  c <- stats::aggregate(cbind(received, disposed) ~ year + court_series, c, sum)
  c <- c[c$year %in% c(2012, 2024), ]
  c <- c[c$court_series %in% names(which(table(c$court_series) == 2)), ]
  cc <- clearance_decomposition(c$disposed, c$received, c$court_series, c$year)
  grDevices::pdf(NULL, width = 12, height = 5.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(cc, max_parts = 10)
  expect_identical(nrow(drawn), 10L)
  other <- drawn[grepl("^Other parts", drawn$group), ]
  expect_identical(other$group, sprintf("Other parts (%d)", nrow(cc$groups) - 9L))
  # the summed row's rate comes from the summed counts, not an average of rates
  rest <- cc$groups[!cc$groups$group %in% drawn$group, ]
  expect_equal(other$rate_a, sum(rest$numerator_a) / sum(rest$denominator_a))
  expect_equal(other$rate_effect, sum(rest$rate_effect))
  # the shown parts are the ones with the largest contributions
  kept <- setdiff(drawn$group, other$group)
  big <- cc$groups$group[order(-(abs(cc$groups$rate_effect) + abs(cc$groups$mix_effect)))][1:9]
  expect_setequal(kept, big)
  # a small device shows fewer parts than max_parts asks for
  grDevices::pdf(NULL, width = 3.5, height = 3)
  small <- plot(cc)
  grDevices::dev.off()
  expect_lt(nrow(small), 20L)
  expect_error(plot(cc, max_parts = 1), "at least 2")
})

test_that("row labels shrink before they are cut, and are cut only past the room", {
  grDevices::pdf(NULL, width = 3.5, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  f <- rmoriebricklayer:::.jx_row_labels(c("Crimes Against the Person", "Federal Statute"), 30)
  expect_identical(f$labels, c("Crimes Against the Person", "Federal Statute"))
  expect_lt(f$cex, 1)
  g <- rmoriebricklayer:::.jx_row_labels(c(strrep("verylongword", 8), "b"), 30)
  expect_match(g$labels[1], "[.][.][.]")
})

test_that("a period-over-period plot says why a row has no percentage", {
  # the first period and a zero base have no percentage; every other row has one, small bases included
  y <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 420, 0, 450)), value = "n", period = "year")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  drawn <- plot(y)
  expect_identical(is.finite(drawn$pct_change), c(FALSE, TRUE, TRUE, TRUE, FALSE))
  calls <- character()
  local_mocked_bindings(text = function(x, y, labels, ...) calls <<- c(calls, labels), .package = "graphics")
  plot(y)
  expect_true(any(grepl("first period", calls)))
  expect_true(any(grepl("no percentage: previous period is zero", calls)))
})
