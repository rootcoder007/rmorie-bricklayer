# Policy evaluation on panels: every estimator against an exact reference

.pe <- function() policy_example()

# CR1 by hand, from lm() with dummies: the reference for did_panel() and event_study()
.cr1 <- function(fit, cl, terms, k) {
  x <- stats::model.matrix(fit)
  e <- stats::residuals(fit)
  b <- solve(crossprod(x))
  s <- rowsum(x * e, cl)
  g <- nrow(s)
  n <- nrow(x)
  v <- b %*% crossprod(s) %*% b * g / (g - 1) * (n - 1) / (n - k)
  sqrt(diag(v))[terms]
}

test_that("did_panel(): the two-way estimate and its CR1 error, as lm() with dummies gives them", {
  p <- .pe()
  r <- did_panel(p, "district", "month", "crime_rate", "reformed")
  f <- stats::lm(crime_rate ~ reformed + factor(district) + factor(month), p)
  expect_equal(r$estimate, unname(stats::coef(f)["reformed"]), tolerance = 1e-10)
  # K: the regressor, the 35 month effects, the constant; district effects nest in the clusters
  expect_equal(r$se, unname(.cr1(f, p$district, "reformed", 1 + 35 + 1)), tolerance = 1e-8)
  expect_equal(r$p_value, 2 * stats::pt(-abs(r$t), 19))
  expect_identical(attr(r, "clusters"), 20L)
  pre <- p$crime_rate[p$region == "R4" & p$month < 13]
  expect_equal(attr(r, "control_mean"), mean(pre))
  expect_equal(attr(r, "relative_effect"), r$estimate / mean(pre))
  expect_output(print(r), "relative to the comparison units")
  # the 2 x 2 case is the difference of four means
  d <- data.frame(u = rep(1:4, each = 2), t = rep(1:2, 4), y = c(1, 2, 3, 5, 2, 7, 4, 10),
                  tr = c(0, 0, 0, 0, 0, 1, 0, 1))
  expect_equal(did_panel(d, "u", "t", "y", "tr")$estimate, ((5 + 6) / 2) - ((1 + 2) / 2))
  # an unbalanced panel, and the cross-section with period effects
  pu <- p[-c(3, 50, 77), ]
  fu <- stats::lm(crime_rate ~ reformed + factor(district) + factor(month), pu)
  expect_equal(did_panel(pu, "district", "month", "crime_rate", "reformed")$estimate,
               unname(stats::coef(fu)["reformed"]), tolerance = 1e-8)
  ft <- stats::lm(crime_rate ~ reformed + factor(month), p)
  expect_equal(did_panel(p, "district", "month", "crime_rate", "reformed", fixed_effects = "time")$estimate,
               unname(stats::coef(ft)["reformed"]), tolerance = 1e-10)
  # weights: weighted least squares with dummies
  p$w <- .rmbl_with_seed(1, stats::runif(nrow(p), 0.5, 2))
  fw <- stats::lm(crime_rate ~ reformed + factor(district) + factor(month), p, weights = w)
  expect_equal(did_panel(p, "district", "month", "crime_rate", "reformed", weights = "w")$estimate,
               unname(stats::coef(fw)["reformed"]), tolerance = 1e-8)
  # two-way clustering: V_a + V_b - V_ab, all with the smaller dimension's factor; the month
  # effects nest in the month clusters, so K is the regressor and the constant
  tw <- did_panel(p, "district", "month", "crime_rate", "reformed", cluster = c("district", "month"))
  x <- stats::model.matrix(f)
  b <- solve(crossprod(x))
  e <- stats::residuals(f)
  vm <- function(g) (b %*% crossprod(rowsum(x * e, g)) %*% b)["reformed", "reformed"]
  ref2 <- (vm(p$district) + vm(p$month) - vm(paste(p$district, p$month))) * 20 / 19 * 719 / 718
  expect_equal(tw$se, sqrt(ref2), tolerance = 1e-8)
  # a linear combination and its delta-method error
  p$expo <- pmin(pmax(p$month - ifelse(is.na(p$reform_month), Inf, p$reform_month), 0), 12)
  cb <- did_panel(p, "district", "month", "crime_rate", "reformed", covariates = "expo",
                  combine = c(treated = 1, expo = 12))
  a12 <- c(1, 12)
  expect_equal(attr(cb, "combined")$estimate, sum(a12 * cb$estimate))
  expect_equal(attr(cb, "combined")$se, sqrt(as.numeric(t(a12) %*% attr(cb, "vcov") %*% a12)))
  expect_error(did_panel(p, "district", "month", "crime_rate", "reformed", combine = c(zz = 1)), "named by")
  expect_error(did_panel(p, "district", "month", "crime_rate", "reformed", cluster = c("a", "b", "c")),
               "two for two-way")
  rc <- did_panel(p, "district", "month", "crime_rate", "reformed", covariates = "arrest_rate")
  expect_identical(rc$term, c("treated", "arrest_rate"))
})

test_that("did_panel() refuses what it cannot estimate", {
  p <- .pe()
  expect_error(did_panel(p, "district", "month", "crime_rate", "zz"), "is not a column")
  expect_error(did_panel(transform(p, reformed = 2), "district", "month", "crime_rate", "reformed"), "0 or 1")
  expect_error(did_panel(transform(p, reformed = 0), "district", "month", "crime_rate", "reformed"), "never varies")
  expect_error(did_panel(rbind(p, p[1, ]), "district", "month", "crime_rate", "reformed"), "more than one row")
  expect_error(did_panel(p, "district", "month", "crime_rate", "reformed", fixed_effects = "unit"), "include")
  expect_error(did_panel(p, "district", "month", "crime_rate", "reformed", covariates = "reformed"), "collinear")
  expect_error(did_panel(transform(p, month = as.character(month)), "district", "month", "crime_rate",
                         "reformed"), "numeric")
})

test_that("event_study(): leads and lags as lm() with binned dummies, and the Wald pre-trend test", {
  p <- .pe()
  es <- event_study(p, "district", "month", "crime_rate", "reform_month", leads = 3, lags = 4)
  k <- ifelse(is.na(p$reform_month), NA, pmin(pmax(p$month - p$reform_month, -3), 4))
  for (j in c(-3, -2, 0:4)) p[[paste0("k", j)]] <- as.numeric(!is.na(k) & k == j)
  f <- stats::lm(crime_rate ~ `k-3` + `k-2` + k0 + k1 + k2 + k3 + k4 + factor(district) + factor(month), p)
  cf <- stats::coef(f)[c("`k-3`", "`k-2`", "k0", "k1", "k2", "k3", "k4")]
  expect_equal(es$estimate[es$event_time != -1], unname(cf), tolerance = 1e-10)
  expect_identical(es$estimate[es$event_time == -1], 0)
  se <- .cr1(f, p$district, names(cf), 7 + 35 + 1)
  expect_equal(es$se[es$event_time != -1], unname(se), tolerance = 1e-8)
  pt <- attr(es, "pretrend")
  x <- stats::model.matrix(f)
  b <- solve(crossprod(x))
  s <- rowsum(x * stats::residuals(f), p$district)
  v <- (b %*% crossprod(s) %*% b * 20 / 19 * 719 / (720 - 43))[c("`k-3`", "`k-2`"), c("`k-3`", "`k-2`")]
  w <- as.numeric(t(cf[1:2]) %*% solve(v, cf[1:2]))
  expect_equal(pt$F, w / 2, tolerance = 1e-8)
  expect_equal(pt$p_value, stats::pf(w / 2, 2, 19, lower.tail = FALSE), tolerance = 1e-8)
  expect_output(print(es), "Leads jointly zero")
  expect_identical(nrow(plot(es)), nrow(es))
  # without binning, periods beyond the window are dropped, not pooled
  nb <- event_study(.pe(), "district", "month", "crime_rate", "reform_month", leads = 2, lags = 2, bin = FALSE)
  expect_identical(nb$event_time, -2:2)
  expect_error(event_study(.pe(), "district", "month", "crime_rate", "reform_month", leads = 30, lags = 2,
                           bin = FALSE), "no observation at event time")
  expect_error(event_study(transform(.pe(), reform_month = NA), "district", "month", "crime_rate",
                           "reform_month"), "no unit is ever treated")
})

test_that("staggered_att(): Callaway-Sant'Anna cells by hand, Wooldridge as lm(), and the aggregates", {
  p <- .pe()
  s <- staggered_att(p, "district", "month", "crime_rate", "reform_month", reps = 0)
  m <- function(rg, t) mean(p$crime_rate[p$region %in% rg & p$month == t])
  # cohort 19 at month 20, base month 18; not yet treated by month 20: regions R3 (25) and R4 (never)
  ref <- (m("R2", 20) - m("R2", 18)) - (m(c("R3", "R4"), 20) - m(c("R3", "R4"), 18))
  expect_equal(s$att_gt$estimate[s$att_gt$cohort == 19 & s$att_gt$period == 20], ref)
  # a pre-period cell uses the period before as its base (a one-period placebo)
  pre <- (m("R3", 10) - m("R3", 9)) - (m(c("R1", "R2", "R4"), 10) - m(c("R1", "R2", "R4"), 9))
  expect_equal(s$att_gt$estimate[s$att_gt$cohort == 25 & s$att_gt$period == 10], pre)
  sn <- staggered_att(p, "district", "month", "crime_rate", "reform_month", control = "never", reps = 0)
  refn <- (m("R2", 20) - m("R2", 18)) - (m("R4", 20) - m("R4", 18))
  expect_equal(sn$att_gt$estimate[sn$att_gt$cohort == 19 & sn$att_gt$period == 20], refn)
  post <- s$att_gt[s$att_gt$event_time >= 0, ]
  expect_equal(s$overall$estimate, sum(post$n_cohort * post$estimate) / sum(post$n_cohort))
  e0 <- s$att_gt[s$att_gt$event_time == 0, ]
  expect_equal(s$dynamic$estimate[s$dynamic$event_time == 0], mean(e0$estimate))
  w <- staggered_att(p, "district", "month", "crime_rate", "reform_month", method = "wooldridge", reps = 0)
  p$cell <- ifelse(!is.na(p$reform_month) & p$month >= p$reform_month, paste0(p$reform_month, "_", p$month), "0")
  p$cell <- stats::relevel(factor(p$cell), "0")
  f <- stats::lm(crime_rate ~ cell + factor(district) + factor(month), p)
  cf <- stats::coef(f)[paste0("cell", w$att_gt$cohort, "_", w$att_gt$period)]
  expect_equal(w$att_gt$estimate, unname(cf), tolerance = 1e-8)
  # covariates: the doubly robust cell by hand (Sant'Anna and Zhao 2020)
  q <- .pe()
  q$x1 <- .rmbl_with_seed(7, stats::rnorm(20))[match(q$district, unique(q$district))]
  q$crime_rate <- q$crime_rate + 2 * q$x1 * q$month / 36
  sx <- staggered_att(q, "district", "month", "crime_rate", "reform_month", reps = 0, covariates = "x1")
  u <- unique(q$district)
  grp <- q$reform_month[match(u, q$district)]
  k <- grp %in% c(19, 25) | is.na(grp)
  yy <- function(t) q$crime_rate[q$month == t][match(u, q$district[q$month == t])]
  dy <- (yy(20) - yy(18))[k]
  d <- as.numeric(grp[k] %in% 19)
  x <- cbind(1, q$x1[match(u, q$district)][k])
  m <- as.vector(x %*% stats::lm.fit(x[d == 0, ], dy[d == 0])$coefficients)
  ps <- stats::glm.fit(x, d, family = stats::binomial())$fitted.values
  w <- ps * (1 - d) / (1 - ps)
  ref <- sum(d * (dy - m)) / sum(d) - sum(w * (dy - m)) / sum(w)
  expect_equal(sx$att_gt$estimate[sx$att_gt$cohort == 19 & sx$att_gt$period == 20], ref, tolerance = 1e-10)
  sr <- staggered_att(q, "district", "month", "crime_rate", "reform_month", reps = 0, covariates = "x1",
                      est_method = "reg")
  expect_equal(sr$att_gt$estimate[sr$att_gt$cohort == 19 & sr$att_gt$period == 20], mean((dy - m)[d == 1]))
  expect_error(staggered_att(q, "district", "month", "crime_rate", "reform_month", method = "wooldridge",
                             covariates = "x1"), "callaway_santanna")
  b <- staggered_att(.pe(), "district", "month", "crime_rate", "reform_month", reps = 30, seed = 2)
  expect_true(all(is.finite(b$att_gt$se)) && is.finite(b$overall$se))
  expect_identical(b$overall, staggered_att(.pe(), "district", "month", "crime_rate", "reform_month", reps = 30,
                                            seed = 2)$overall)
  expect_output(print(b), "Callaway-Sant'Anna")
  expect_identical(nrow(plot(b)), nrow(b$dynamic))
  expect_error(staggered_att(.pe()[-1, ], "district", "month", "crime_rate", "reform_month"), "balanced")
  nv <- .pe()
  nv <- nv[!is.na(nv$reform_month), ]
  expect_error(staggered_att(nv, "district", "month", "crime_rate", "reform_month", control = "never"),
               "no never-treated unit")
})

test_that("bacon_decomposition(): the weighted comparisons add up to the two-way estimate exactly", {
  p <- .pe()
  b <- bacon_decomposition(p, "district", "month", "crime_rate", "reformed")
  expect_equal(sum(b$weight), 1)
  expect_equal(attr(b, "twfe"), did_panel(p, "district", "month", "crime_rate", "reformed")$estimate,
               tolerance = 1e-10)
  expect_setequal(unique(b$type), c("treated vs never", "earlier vs later", "later vs earlier"))
  m <- function(rg, t) mean(p$crime_rate[p$region %in% rg & p$month %in% t])
  ref <- (m("R1", 13:36) - m("R1", 1:12)) - (m("R4", 13:36) - m("R4", 1:12))
  expect_equal(b$estimate[b$type == "treated vs never" & b$treated == 13], ref)
  expect_output(print(b), "later vs earlier")
  # with no never-treated unit the decomposition is still exact
  nv <- p[!is.na(p$reform_month), ]
  bn <- bacon_decomposition(nv, "district", "month", "crime_rate", "reformed")
  expect_equal(attr(bn, "twfe"), did_panel(nv, "district", "month", "crime_rate", "reformed")$estimate,
               tolerance = 1e-10)
  off <- p
  off$reformed[off$district == "D01" & off$month == 30] <- 0
  expect_error(bacon_decomposition(off, "district", "month", "crime_rate", "reformed"), "stay on")
})

test_that("switching_did(): with treatment that stays on, it equals the not-yet-treated effect at adoption", {
  p <- .pe()
  sw <- switching_did(p, "district", "month", "crime_rate", "reformed", reps = 0)
  s <- staggered_att(p, "district", "month", "crime_rate", "reform_month", reps = 0)
  expect_equal(sw$estimate[1], s$dynamic$estimate[s$dynamic$event_time == 0])
  expect_identical(sw$switchers, c(15, 15))
  # units that switch off: the stayers' change minus the leavers'
  d <- data.frame(u = rep(1:4, each = 2), t = rep(1:2, 4), y = c(5, 3, 5, 6, 1, 1, 1, 2),
                  tr = c(1, 0, 1, 1, 0, 0, 0, 0))
  expect_equal(switching_did(d, "u", "t", "y", "tr", reps = 0)$estimate[1], 1 - (-2))
  b <- switching_did(p, "district", "month", "crime_rate", "reformed", reps = 20, seed = 1)
  expect_true(all(is.finite(b$se)))
  expect_error(switching_did(transform(p, reformed = 0), "district", "month", "crime_rate", "reformed"),
               "no unit switches")
})

test_that("permutation_inference(): every assignment of the stages, and the stepdown", {
  p <- .pe()
  r <- permutation_inference(p, "district", "month", c("crime_rate", "arrest_rate"), "reform_month",
                             cluster = "region", reps = 199)
  expect_true(all(r$exact))
  expect_identical(r$assignments, c(24L, 24L))
  expect_equal(r$p_value * 24, round(r$p_value * 24))
  expect_true(all(r$p_stepdown >= r$p_value))
  expect_equal(r$estimate[1], did_panel(p, "district", "month", "crime_rate", "reformed")$estimate)
  rr <- permutation_inference(p, "district", "month", "crime_rate", "reform_month", reps = 49, seed = 1,
                              statistic = "estimate")
  expect_false(rr$exact)
  expect_equal(rr$p_value * 50, round(rr$p_value * 50))
  expect_identical(rr$p_stepdown, rr$p_value)
  expect_identical(nrow(.rmbl_multiset_perms(c(1, 1, 2, 3))), 12L)
  rs <- permutation_inference(p, "district", "month", "crime_rate", "reform_month", cluster = "region",
                              ties = "strict")
  expect_equal(rs$p_value, r$p_value[1] - 1 / 24)
  expect_error(permutation_inference(p, "district", "month", "crime_rate", "reform_month",
                                     cluster = "month"), "same for every unit of a cluster")
})

test_that("stepdown_pvalues(): Westfall-Young by hand", {
  null <- matrix(c(1, 3, 0.5, 2, 0.1, 0.2, 4, 1, 1.5), ncol = 3, byrow = TRUE)
  obs <- c(2.5, 0.4, 1.2)
  # order: 1 (2.5), 3 (1.2), 2 (0.4); successive maxima per draw over the remaining set
  q1 <- apply(abs(null), 1L, max)
  q2 <- pmax(abs(null[, 3]), abs(null[, 2]))
  q3 <- abs(null[, 2])
  p1 <- mean(q1 >= 2.5)
  p3 <- max(p1, mean(q2 >= 1.2))
  p2 <- max(p3, mean(q3 >= 0.4))
  expect_equal(stepdown_pvalues(obs, null), c(p1, p2, p3))
  expect_error(stepdown_pvalues(1:2, matrix(1, 2, 3)), "one column per observed")
  expect_error(stepdown_pvalues(c(1, NA), matrix(1, 2, 2)), "no NA")
})

test_that("fe_poisson(): the coefficient of glm() with dummies, and units with no count dropped", {
  p <- .pe()
  r <- fe_poisson(p, "district", "month", "crimes", "reformed", offset = "log_population")
  f <- stats::glm(crimes ~ reformed + factor(district) + factor(month) + offset(log_population),
                  family = stats::poisson(), data = p)
  expect_equal(r$estimate, unname(stats::coef(f)["reformed"]), tolerance = 1e-7)
  expect_equal(r$rate_ratio, exp(r$estimate))
  expect_identical(attr(r, "dropped_units"), 0L)
  p$crimes[p$district == "D02"] <- 0
  expect_identical(attr(fe_poisson(p, "district", "month", "crimes", "reformed"), "dropped_units"), 1L)
  expect_error(fe_poisson(transform(p, crimes = -1), "district", "month", "crimes", "reformed"), "counts")
  # the negative binomial: overdispersed counts, the maximum likelihood of NB2 with dummies
  q <- .pe()
  q$crimes <- .rmbl_with_seed(5, stats::rnbinom(nrow(q), size = 4, mu = q$crimes + 1))
  nb <- fe_poisson(q, "district", "month", "crimes", "reformed", family = "negbin")
  th <- attr(nb, "theta")
  expect_true(th > 1 && th < 20)
  X <- cbind(1, q$reformed, stats::model.matrix(~ factor(q$district) + factor(q$month))[, -1])
  nll <- function(b) {
    mu <- exp(X %*% b)
    -sum(stats::dnbinom(q$crimes, size = th, mu = mu, log = TRUE))
  }
  f0 <- stats::glm.fit(X, q$crimes, family = .rmbl_negbin_family(th))
  g <- stats::optim(f0$coefficients, nll, method = "BFGS", control = list(reltol = 1e-14))
  expect_equal(nb$estimate, unname(g$par[2]), tolerance = 1e-5)
  prof <- function(lt) -sum(stats::dnbinom(q$crimes, size = exp(lt), mu = f0$fitted.values, log = TRUE))
  expect_equal(log(th), stats::optimize(prof, c(-5, 10))$minimum, tolerance = 1e-3)
})

test_that("synthetic_control(): weights on the simplex that satisfy the optimality conditions", {
  p <- .pe()
  p1 <- p[is.na(p$reform_month) | p$district == "D13", ]
  s <- synthetic_control(p1, "district", "month", "crime_rate", "D13", 13)
  w <- s$weights
  expect_equal(sum(w), 1)
  expect_true(all(w >= 0))
  ym <- t(sapply(names(w), function(u) p1$crime_rate[p1$district == u & p1$month < 13]))
  y1 <- p1$crime_rate[p1$district == "D13" & p1$month < 13]
  g <- as.vector(2 * ym %*% (crossprod(ym, w) - y1))
  act <- w > 1e-6
  # KKT: equal gradient on the donors used, no smaller one on the donors left out
  tol <- 1e-8 * max(abs(g))
  expect_lt(diff(range(g[act])), tol)
  expect_true(all(g[!act] >= min(g[act]) - tol))
  expect_equal(s$p_value, 1 / 6)
  expect_equal(s$path$gap, s$path$treated - s$path$synthetic)
  expect_output(print(s), "Placebo-in-space")
  expect_identical(nrow(plot(s)), 36L)
  expect_true(is.na(synthetic_control(p1, "district", "month", "crime_rate", "D13", 13, placebo = FALSE)$p_value))
  expect_error(synthetic_control(p1, "district", "month", "crime_rate", "D99", 13), "not a unit")
  expect_error(synthetic_control(p1, "district", "month", "crime_rate", "D13", 2), "two periods before")
})

test_that("severity_index(), pipeline_rate(), cumulative_risk() and buffer_assign() by hand", {
  d <- data.frame(city = rep(c("A", "B"), each = 3), year = 2024,
                  offence = rep(c("homicide", "robbery", "burglary"), 2),
                  n = c(5, 120, 300, 2, 90, 410), pop = rep(c(250000, 180000), each = 3))
  w <- c(homicide = 25, robbery = 8, burglary = 4)
  s <- severity_index(d, "city", "year", "offence", "n", weights = w, population = "pop")
  expect_equal(s$unweighted[1], (5 + 120 + 300) / 2.5)
  expect_equal(s$weighted[1], (25 * 5 + 8 * 120 + 4 * 300) / 2.5)
  expect_true(is.na(severity_index(d[-1, ], "city", "year", "offence", "n", w)$weighted[1]))
  expect_error(severity_index(d, "city", "year", "offence", "n", c(arson = 1)), "not an offence")
  expect_error(severity_index(rbind(d, d[1, ]), "city", "year", "offence", "n", w), "appears twice")

  r <- pipeline_rate(1:24, rep(10, 24), window = 12, lag = 3)
  expect_true(all(is.na(r$rate[1:14])))
  expect_equal(r$rate[15], sum(4:15) / 120)
  expect_equal(pipeline_rate(c(2, 3), c(4, 0), window = 1)$rate, c(0.5, NA))
  g <- pipeline_rate(c(1, 2, 3, 4), c(2, 2, 2, 2), window = 1, group = c("a", "a", "b", "b"))
  expect_identical(g$index, c(1L, 2L, 1L, 2L))
  expect_error(pipeline_rate(1:3, 1:2), "same length")

  cr <- cumulative_risk(16:18, c(10, 20, 30), c(1000, 1000, 1000))
  h <- c(10 / 1000, 20 / (1000 * 0.99), 30 / (1000 * (1 - 0.01 - 0.02)))
  expect_equal(cr$hazard, h)
  expect_equal(cr$cumulative_risk, 1 - cumprod(1 - h))
  expect_true(all(cr$lower < cr$cumulative_risk & cr$cumulative_risk < cr$upper))
  cm <- cumulative_risk(16:17, c(10, 20), c(1000, 1000), at_risk = c(1000, 990), death_rate = c(0.01, 0.01))
  expect_equal(cm$cumulative_risk, c(0.01, 0.01 + (1 - 0.01 - 0.01) * 20 / 990))
  expect_error(cumulative_risk(c(2, 1), c(1, 1), c(10, 10)), "increasing")
  expect_error(cumulative_risk(1, 20, 10), "more first events")

  a <- buffer_assign(c(0, 100, 2000, 5000), c(0, 0, 0, 0), 0, 0, c(2000, 5000), c(0, 0), radius = 330)
  expect_identical(a$group, c("treated", "treated", "comparison", "comparison"))
  b <- buffer_assign(800, 0, 0, 0, 900, 0, radius = 330)
  expect_identical(b$group, "excluded")
  expect_error(buffer_assign(1, 1:2, 0, 0, 1, 1, 10), "same length")
})

test_that("policy_example() is reproducible and has the effect it was built with", {
  expect_identical(policy_example(), policy_example())
  p <- policy_example()
  expect_identical(nrow(p), 720L)
  expect_identical(sort(unique(p$reform_month)), c(13, 19, 25))
  expect_lt(abs(did_panel(p, "district", "month", "crime_rate", "reformed")$estimate + 3), 0.5)
})
