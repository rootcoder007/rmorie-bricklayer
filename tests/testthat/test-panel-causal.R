# Panel causal estimation: learners, DML with fixed effects, matching, synthetic DiD, the wild cluster
# bootstrap, trend sensitivity and power, each against an exact reference

.pc <- function() policy_example()

test_that("the lasso satisfies its optimality conditions, and ridge and OLS predict", {
  x <- .rmbl_with_seed(1, matrix(stats::rnorm(200 * 6), 200))
  y <- 2 * x[, 1] - x[, 3] + .rmbl_with_seed(2, stats::rnorm(200))
  lam <- 0.1
  b <- .rmbl_lasso_path(x, y, lam)[, 1]
  sc <- .rmbl_scale_fit(x)
  z <- sweep(sweep(x, 2L, sc$mu), 2L, sc$sd, "/")
  bz <- b[-1] * sc$sd
  r <- (y - mean(y)) - z %*% bz
  g <- as.vector(crossprod(z, r)) / nrow(z)
  on <- abs(bz) > 1e-8
  expect_equal(g[on], lam * sign(bz[on]), tolerance = 1e-6)
  expect_true(all(abs(g[!on]) <= lam + 1e-6))
  expect_equal(b[1], mean(y) - sum(b[-1] * sc$mu))
  expect_identical(length(.rmbl_lasso_cv(x, y, x[1:5, ])), 5L)
  pr <- .rmbl_ridge_gcv(x, y, x[1:5, ])
  expect_lt(max(abs(pr - .rmbl_ols_learner(x, y, x[1:5, ]))), 0.2)
  f <- .rmbl_learner(function(xtr, ytr, xte) rep(0, nrow(xte)))
  expect_identical(f(x, y, x[1:3, ]), c(0, 0, 0))
  expect_error(.rmbl_learner(function(xtr, ytr, xte) 1)(x, y, x[1:3, ]), "one prediction per test row")
  expect_identical(colnames(.rmbl_poly2(cbind(a = 1:3, b = 4:6))), c("a", "b", "a^2", "b^2", "a:b"))
})

.dml_data <- function() {
  p <- .pc()
  p$u1 <- 6 + sin(p$month / 6) + .rmbl_with_seed(3, stats::rnorm(nrow(p), 0, 0.5))
  p$u2 <- .rmbl_with_seed(4, stats::rnorm(nrow(p)))
  p$d <- 0.5 * p$u1 + p$u2^2 + .rmbl_with_seed(5, stats::rnorm(nrow(p)))
  p$y <- 1.5 * p$d + p$u1 + 2 * p$u2^2 + .rmbl_with_seed(6, stats::rnorm(nrow(p))) +
    as.integer(factor(p$district)) / 4
  p
}

test_that("dml_panel(): the partialling-out estimate and its clustered error, by hand", {
  p <- .dml_data()
  r <- dml_panel(p, "district", "month", "y", "d", c("u1", "u2"), learner = "ols", folds = 5, seed = 1)
  pu <- as.integer(factor(p$district))
  uu <- unique(pu)
  f <- .rmbl_with_seed(1L, sample(rep_len(1:5, length(uu))))[match(pu, uu)]
  fes <- list(unit = pu, time = as.integer(factor(p$month)))
  yt <- as.vector(.rmbl_demean(p$y, fes))
  dt <- as.vector(.rmbl_demean(p$d, fes))
  xt <- .rmbl_demean(cbind(p$u1, p$u2), fes)
  u <- v <- numeric(length(yt))
  for (k in 1:5) {
    tr <- f != k
    u[!tr] <- yt[!tr] - cbind(1, xt[!tr, ]) %*% stats::lm.fit(cbind(1, xt[tr, ]), yt[tr])$coefficients
    v[!tr] <- dt[!tr] - cbind(1, xt[!tr, ]) %*% stats::lm.fit(cbind(1, xt[tr, ]), dt[tr])$coefficients
  }
  th <- sum(u * v) / sum(v^2)
  s <- rowsum(v * (u - th * v), pu)
  expect_equal(r$estimate, th, tolerance = 1e-10)
  expect_equal(r$se, sqrt(20 / 19 * sum(s^2)) / sum(v^2), tolerance = 1e-10)
  # a quadratic confounder: the poly2 basis, built before demeaning, removes it
  rq <- dml_panel(p, "district", "month", "y", "d", c("u1", "u2"), learner = "ridge", basis = "poly2")
  expect_lt(abs(rq$estimate - 1.5), 3 * rq$se)
  expect_gt(abs(r$estimate - 1.5), 10 * r$se)
  rr <- dml_panel(p, "district", "month", "y", "d", c("u1", "u2"), learner = "ols", repeats = 3)
  expect_identical(attr(rr, "repeats"), 3L)
  expect_output(print(rr), "out-of-fold R-squared")
  expect_error(dml_panel(p, "district", "month", "y", "d", NULL), "one column at least")
  p$c0 <- 1
  expect_error(dml_panel(p, "district", "month", "y", "d", "c0"), "no covariate varies")
})

test_that("balance_table() is Welch's test, and the standardised difference uses the treated SD", {
  d <- data.frame(t = rep(0:1, each = 30), x = c(1:30, (1:30) * 1.5 + 3))
  b <- balance_table(d, "t", "x")
  tt <- stats::t.test(d$x[d$t == 1], d$x[d$t == 0])
  expect_equal(b$p_value, tt$p.value, tolerance = 1e-10)
  expect_equal(b$smd, (mean(d$x[d$t == 1]) - mean(d$x[d$t == 0])) / stats::sd(d$x[d$t == 1]))
  d$w <- 1
  expect_equal(balance_table(d, "t", "x", weights = "w")$p_value, tt$p.value, tolerance = 1e-10)
  expect_error(balance_table(transform(d, t = 2), "t", "x"), "0 and 1")
})

test_that("matched_did(): Mahalanobis matches with the pooled covariance, weights, and the weighted DiD", {
  p <- .pc()
  m <- matched_did(p, "district", "month", "crime_rate", "reform_month", ratio = 2)
  u <- unique(p$district)
  y <- t(sapply(u, function(k) p$crime_rate[p$district == k & p$month < 13]))
  tr <- !is.na(p$reform_month[match(u, p$district)])
  s <- ((sum(tr) - 1) * stats::cov(y[tr, ]) + (sum(!tr) - 1) * stats::cov(y[!tr, ])) / (length(u) - 2)
  dd <- sqrt(stats::mahalanobis(y[!tr, ], y[which(tr)[1], ], s))
  first <- m$matches[m$matches$treated == u[which(tr)[1]], ]
  expect_identical(first$control, u[!tr][order(dd)[1:2]])
  expect_equal(sum(m$weights$weight[!tr]), sum(tr))
  expect_true(all(m$weights$weight[tr] == 1))
  expect_identical(nrow(m$balance), 12L)
  p$half <- ifelse(as.integer(sub("D", "", p$district)) %% 2 == 0, "even", "odd")
  me <- matched_did(p, "district", "month", "crime_rate", "reform_month", exact = "half")
  expect_identical(p$half[match(me$matches$treated, p$district)], p$half[match(me$matches$control, p$district)])
  mf <- matched_did(p, "district", "month", "crime_rate", "reform_month", covariance = "full")
  df <- sqrt(stats::mahalanobis(y[!tr, ], y[which(tr)[1], ], stats::cov(y)))
  expect_identical(mf$matches$control[mf$matches$treated == u[which(tr)[1]]], u[!tr][which.min(df)])
  expect_output(print(m), "Largest")
  expect_error(matched_did(p[!is.na(p$reform_month), ], "district", "month", "crime_rate", "reform_month"),
               "never-treated")
})

test_that("synthetic_did(): simplex weights and the estimate from them", {
  p <- .pc()
  p1 <- p[is.na(p$reform_month) | p$reform_month == 13, ]
  s <- synthetic_did(p1, "district", "month", "crime_rate", "reform_month", reps = 20, seed = 1)
  expect_equal(sum(s$unit_weights), 1)
  expect_equal(sum(s$time_weights), 1)
  expect_true(all(s$unit_weights >= 0) && all(s$time_weights >= 0))
  y <- t(sapply(unique(p1$district), function(k) p1$crime_rate[p1$district == k]))
  rownames(y) <- unique(p1$district)
  tr <- rownames(y) %in% unique(p1$district[!is.na(p1$reform_month)])
  pre <- 1:12
  y1 <- y[tr, , drop = FALSE]
  y0 <- y[!tr, , drop = FALSE]
  ref <- (mean(y1[, -pre]) - sum(s$time_weights * colMeans(y1[, pre]))) -
    sum(s$unit_weights * (rowMeans(y0[, -pre]) - y0[, pre] %*% s$time_weights))
  expect_equal(s$estimate, ref)
  expect_identical(s$method, "jackknife")
  expect_gt(s$se, 0)
  one <- p1[is.na(p1$reform_month) | p1$district == "D01", ]
  s1 <- synthetic_did(one, "district", "month", "crime_rate", "reform_month", reps = 20, seed = 1)
  expect_identical(s1$method, "placebo")
  expect_output(print(s1), "Unit weights")
  expect_identical(nrow(plot(s1)), 36L)
  expect_error(synthetic_did(p, "district", "month", "crime_rate", "reform_month"), "one adoption date")
})

test_that("wild_cluster_bootstrap(): full enumeration, ties counted, and an honest unbounded interval", {
  p <- .pc()
  w <- wild_cluster_bootstrap(p, "district", "month", "crime_rate", "reformed", cluster = "region", reps = 999)
  expect_true(w$enumerated)
  expect_identical(w$draws, 16L)
  expect_equal(w$p_value * 16, round(w$p_value * 16))
  expect_gte(w$p_value, 2 / 16)
  expect_identical(c(w$lower, w$upper), c(-Inf, Inf))
  ws <- wild_cluster_bootstrap(p, "district", "month", "crime_rate", "reformed", cluster = "region",
                               ties = "strict")
  expect_equal(ws$p_value, w$p_value - 2 / 16)
  expect_true(is.finite(ws$lower) || ws$p_value > 0.05)
  w2 <- wild_cluster_bootstrap(p, "district", "month", "crime_rate", "reformed", reps = 199, seed = 1,
                               weights_type = "webb")
  expect_false(w2$enumerated)
  expect_lt(w2$p_value, 0.05)
  expect_true(w2$lower < w2$estimate && w2$estimate < w2$upper && w2$upper < 0)
  expect_equal(w2$estimate, did_panel(p, "district", "month", "crime_rate", "reformed")$estimate)
})

test_that("trend_sensitivity(): the relative-magnitudes bounds by hand", {
  p <- .pc()
  es <- event_study(p, "district", "month", "crime_rate", "reform_month", leads = 3, lags = 4)
  s <- trend_sensitivity(es, mbar = c(0, 1), draws = 500, seed = 1)
  b <- es$estimate
  names(b) <- es$event_time
  post <- as.character(0:4)
  dmax <- max(abs(diff(b[c("-3", "-2", "-1")])))
  expect_equal(s$lower_bound[1], mean(b[post]))
  expect_equal(s$upper_bound[2] - s$lower_bound[2], 2 * dmax * mean(0:4 + 1))
  expect_true(all(s$lower <= s$lower_bound & s$upper >= s$upper_bound))
  s0 <- trend_sensitivity(es, mbar = 1, target = 0, draws = 200, seed = 1)
  expect_equal(s0$upper_bound - s0$lower_bound, 2 * dmax)
  expect_output(print(s), "Breakdown")
  expect_error(trend_sensitivity(es, target = 9), "post-period event time")
  expect_error(trend_sensitivity(data.frame()), "event_study")
})

test_that("panel_power(): size near alpha, power rising with the effect, and the MDE", {
  p <- .pc()
  pre <- p[p$month <= 12, ]
  pw <- panel_power(pre, "district", "month", "crime_rate", n_treated = 10, adoption = 7:10,
                    effects = c(0, 1, 3), reps = 20, seed = 2)
  expect_lte(attr(pw, "size"), 0.25)
  expect_true(all(diff(pw$power) >= -0.1))
  expect_true(is.finite(attr(pw, "mde")) && attr(pw, "mde") <= 3)
  expect_output(print(pw), "Minimum detectable")
  expect_identical(nrow(plot(pw)), 3L)
  expect_error(panel_power(pre, "district", "month", "crime_rate", n_treated = 10, adoption = 1), "before it")
})

test_that("aipw_crossfit(): the doubly robust score by hand, for the ATE and the ATT", {
  n <- 600
  d <- data.frame(age = .rmbl_with_seed(1, stats::runif(n, 18, 70)))
  d$t <- .rmbl_with_seed(2, stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age)))
  d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
  r <- aipw_crossfit(d, "y", "t", "age", learner = "ols", seed = 4)
  f <- .rmbl_with_seed(4L, sample(rep_len(1:5, n)))
  m1 <- m0 <- e <- numeric(n)
  x <- cbind(1, d$age)
  for (k in 1:5) {
    tr <- f != k
    m1[!tr] <- x[!tr, ] %*% stats::lm.fit(x[tr & d$t == 1, ], d$y[tr & d$t == 1])$coefficients
    m0[!tr] <- x[!tr, ] %*% stats::lm.fit(x[tr & d$t == 0, ], d$y[tr & d$t == 0])$coefficients
    e[!tr] <- stats::plogis(x[!tr, ] %*% stats::glm.fit(x[tr, ], d$t[tr], family = stats::binomial())$coefficients)
  }
  e <- pmin(pmax(e, 0.01), 0.99)
  a <- m1 - m0 + d$t * (d$y - m1) / e - (1 - d$t) * (d$y - m0) / (1 - e)
  expect_equal(r$estimate, mean(a), tolerance = 1e-10)
  expect_equal(r$se, sqrt(sum((a - mean(a))^2) / n^2), tolerance = 1e-10)
  expect_lt(abs(r$estimate - 3), 4 * r$se)
  rt <- aipw_crossfit(d, "y", "t", "age", estimand = "ATT", learner = "ols", seed = 4)
  p1 <- mean(d$t)
  at <- (d$t * (d$y - m0) - e * (1 - d$t) * (d$y - m0) / (1 - e)) / p1
  expect_equal(rt$estimate, mean(at), tolerance = 1e-10)
  d$w <- 1
  expect_equal(aipw_crossfit(d, "y", "t", "age", learner = "ols", seed = 4, weights = "w")$estimate, r$estimate)
  expect_output(print(r), "Propensities from")
  expect_error(aipw_crossfit(transform(d, t = 2), "y", "t", "age"), "0 and 1")
})

test_that("aipw_crossfit(design =): one fit gives the replicate standard error of a refit per replicate", {
  n <- 400
  d <- data.frame(age = .rmbl_with_seed(1, stats::runif(n, 18, 70)))
  d$t <- .rmbl_with_seed(2, stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age)))
  d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
  d$w <- .rmbl_with_seed(5, stats::runif(n, 0.5, 2))
  d$age[c(7, 90)] <- NA                       # rows outside the domain, kept in the design
  reps <- paste0("bsw", 1:20)
  m <- .rmbl_with_seed(6, matrix(stats::rpois(n * 20, 1), n))
  for (b in 1:20) d[[reps[b]]] <- d$w * m[, b]
  des <- survey_design(d, weights = "w", replicates = reps)
  for (est in c("ATE", "ATT")) {
    r <- aipw_crossfit(d, "y", "t", "age", estimand = est, learner = "ols", seed = 4, design = des)
    full <- aipw_crossfit(d, "y", "t", "age", estimand = est, learner = "ols", seed = 4, weights = "w")
    th <- vapply(reps, function(b) {
      aipw_crossfit(d, "y", "t", "age", estimand = est, learner = "ols", seed = 4, weights = b)$estimate
    }, numeric(1))
    expect_equal(r$estimate, full$estimate, tolerance = 1e-12)
    expect_equal(r$se, sqrt(mean((th - full$estimate)^2)), tolerance = 1e-10)
    q <- stats::qt(0.975, 19)
    expect_equal(c(r$lower, r$upper), r$estimate + c(-1, 1) * q * r$se, tolerance = 1e-12)
    expect_identical(attr(r, "variance"), "bootstrap")
    expect_output(print(r), "survey design \\(bootstrap\\), one fit")
  }
  expect_identical(attr(full, "variance"), "influence")
  tl <- survey_design(d, weights = "w", strata = rep(1:4, each = n / 4), psu = rep(1:40, each = n / 40))
  rl <- aipw_crossfit(d, "y", "t", "age", learner = "ols", seed = 4, design = tl)
  expect_equal(rl$estimate, aipw_crossfit(d, "y", "t", "age", learner = "ols", seed = 4, weights = "w")$estimate,
               tolerance = 1e-12)
  expect_true(is.finite(rl$se) && rl$se > 0)
  expect_error(aipw_crossfit(d, "y", "t", "age", weights = "w", design = des), "not both")
  expect_error(aipw_crossfit(d, "y", "t", "age", design = list()), "survey_design")
  expect_error(aipw_crossfit(d[-1, ], "y", "t", "age", design = des), "built on")
})
