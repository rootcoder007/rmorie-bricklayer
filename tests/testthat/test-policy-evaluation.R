testthat::skip_on_cran()  # battery: runs in CI and locally; CRAN runs the correctness core
# Policy evaluation on panels: every estimator against an exact reference

.pe <- function() polex()

# CR1 by hand, from lm() with dummies: the reference for plndid() and evstudy()
.cr1 <- function(fit, cl, terms, k) {
  x <- stats::model.matrix(fit)
  e <- stats::residuals(fit)
  b <- solve(crossprod(x))
  s <- rowsum(x * e, cl)
  g <- nrow(s)
  n <- nrow(x)
  v <- b %*% crossprod(s) %*% b * g / (g - 1) * (n - 1) / (n - k)
  sqrt(diag(v)[terms])
}

test_that("plndid(): the two-way estimate and its CR1 error, as lm() with dummies gives them", {
  p <- .pe()
  r <- plndid(p, "district", "month", "crmrate", "reformed")
  f <- stats::lm(crmrate ~ reformed + factor(district) + factor(month), p)
  expect_equal(r$estimate, unname(stats::coef(f)["reformed"]), tolerance = 1e-10)
  # K: the regressor, the 35 month effects, the constant; district effects nest in the clusters
  expect_equal(r$se, unname(.cr1(f, p$district, "reformed", 1 + 35 + 1)), tolerance = 1e-8)
  expect_equal(r$p_value, 2 * stats::pt(-abs(r$t), 19))
  expect_identical(attr(r, "clusters"), 20L)
  pre <- p$crmrate[p$region == "R4" & p$month < 13]
  expect_equal(attr(r, "ctlmean"), mean(pre))
  expect_equal(attr(r, "releff"), r$estimate / mean(pre))
  expect_output(print(r), "relative to the comparison units")
  # the 2 x 2 case is the difference of four means
  d <- data.frame(u = rep(1:4, each = 2), t = rep(1:2, 4), y = c(1, 2, 3, 5, 2, 7, 4, 10),
                  tr = c(0, 0, 0, 0, 0, 1, 0, 1))
  expect_equal(plndid(d, "u", "t", "y", "tr")$estimate, ((5 + 6) / 2) - ((1 + 2) / 2))
  # an unbalanced panel, and the cross-section with period effects
  pu <- p[-c(3, 50, 77), ]
  fu <- stats::lm(crmrate ~ reformed + factor(district) + factor(month), pu)
  expect_equal(plndid(pu, "district", "month", "crmrate", "reformed")$estimate,
               unname(stats::coef(fu)["reformed"]), tolerance = 1e-8)
  ft <- stats::lm(crmrate ~ reformed + factor(month), p)
  expect_equal(plndid(p, "district", "month", "crmrate", "reformed", fe = "time")$estimate,
               unname(stats::coef(ft)["reformed"]), tolerance = 1e-10)
  # weights: weighted least squares with dummies
  p$w <- .rmbl_with_seed(1, stats::runif(nrow(p), 0.5, 2))
  fw <- stats::lm(crmrate ~ reformed + factor(district) + factor(month), p, weights = w)
  expect_equal(plndid(p, "district", "month", "crmrate", "reformed", w = "w")$estimate,
               unname(stats::coef(fw)["reformed"]), tolerance = 1e-8)
  # two-way clustering: V_a + V_b - V_ab, all with the smaller dimension's factor; the month
  # effects nest in the month clusters, so K is the regressor and the constant
  tw <- plndid(p, "district", "month", "crmrate", "reformed", cl = c("district", "month"))
  x <- stats::model.matrix(f)
  b <- solve(crossprod(x))
  e <- stats::residuals(f)
  vm <- function(g) (b %*% crossprod(rowsum(x * e, g)) %*% b)["reformed", "reformed"]
  ref2 <- (vm(p$district) + vm(p$month) - vm(paste(p$district, p$month))) * 20 / 19 * 719 / 718
  expect_equal(tw$se, sqrt(ref2), tolerance = 1e-8)
  # a linear combination and its delta-method error
  p$expo <- pmin(pmax(p$month - ifelse(is.na(p$refmonth), Inf, p$refmonth), 0), 12)
  cb <- plndid(p, "district", "month", "crmrate", "reformed", covs = "expo",
                  comb = c(treated = 1, expo = 12))
  a12 <- c(1, 12)
  expect_equal(attr(cb, "combined")$estimate, sum(a12 * cb$estimate))
  expect_equal(attr(cb, "combined")$se, sqrt(as.numeric(t(a12) %*% attr(cb, "vcov") %*% a12)))
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", comb = c(zz = 1)), "named by")
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", cl = c("a", "b", "c")),
               "two for two-way")
  rc <- plndid(p, "district", "month", "crmrate", "reformed", covs = "arrrate")
  expect_identical(rc$term, c("treated", "arrrate"))
})

test_that("plndid() refuses what it cannot estimate", {
  p <- .pe()
  expect_error(plndid(p, "district", "month", "crmrate", "zz"), "is not a column")
  expect_error(plndid(transform(p, reformed = 2), "district", "month", "crmrate", "reformed"), "0 or 1")
  expect_error(plndid(transform(p, reformed = 0), "district", "month", "crmrate", "reformed"), "never varies")
  expect_error(plndid(rbind(p, p[1, ]), "district", "month", "crmrate", "reformed"), "more than one row")
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", fe = "unit"), "include")
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", covs = "reformed"), "collinear")
  expect_error(plndid(transform(p, month = as.character(month)), "district", "month", "crmrate",
                         "reformed"), "numeric")
})

test_that("evstudy(): leads and lags as lm() with binned dummies, and the Wald pre-trend test", {
  p <- .pe()
  es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3, lags = 4)
  k <- ifelse(is.na(p$refmonth), NA, pmin(pmax(p$month - p$refmonth, -3), 4))
  for (j in c(-3, -2, 0:4)) p[[paste0("k", j)]] <- as.numeric(!is.na(k) & k == j)
  f <- stats::lm(crmrate ~ `k-3` + `k-2` + k0 + k1 + k2 + k3 + k4 + factor(district) + factor(month), p)
  cf <- stats::coef(f)[c("`k-3`", "`k-2`", "k0", "k1", "k2", "k3", "k4")]
  expect_equal(es$estimate[es$evtm != -1], unname(cf), tolerance = 1e-10)
  expect_identical(es$estimate[es$evtm == -1], 0)
  se <- .cr1(f, p$district, names(cf), 7 + 35 + 1)
  expect_equal(es$se[es$evtm != -1], unname(se), tolerance = 1e-8)
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
  nb <- evstudy(.pe(), "district", "month", "crmrate", "refmonth", leads = 2, lags = 2, bin = FALSE)
  expect_identical(nb$evtm, -2:2)
  expect_error(evstudy(.pe(), "district", "month", "crmrate", "refmonth", leads = 30, lags = 2,
                           bin = FALSE), "no observation at event time")
  expect_error(evstudy(transform(.pe(), refmonth = NA), "district", "month", "crmrate",
                           "refmonth"), "no unit is ever treated")
})

test_that("stgatt(): Callaway-Sant'Anna cells by hand, Wooldridge as lm(), and the aggregates", {
  p <- .pe()
  s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 0)
  m <- function(rg, t) mean(p$crmrate[p$region %in% rg & p$month == t])
  # cohort 19 at month 20, base month 18; not yet treated by month 20: regions R3 (25) and R4 (never)
  ref <- (m("R2", 20) - m("R2", 18)) - (m(c("R3", "R4"), 20) - m(c("R3", "R4"), 18))
  expect_equal(s$attgt$estimate[s$attgt$cohort == 19 & s$attgt$period == 20], ref)
  # a pre-period cell uses the period before as its base (a one-period placebo)
  pre <- (m("R3", 10) - m("R3", 9)) - (m(c("R1", "R2", "R4"), 10) - m(c("R1", "R2", "R4"), 9))
  expect_equal(s$attgt$estimate[s$attgt$cohort == 25 & s$attgt$period == 10], pre)
  sn <- stgatt(p, "district", "month", "crmrate", "refmonth", ctrl = "never", reps = 0)
  refn <- (m("R2", 20) - m("R2", 18)) - (m("R4", 20) - m("R4", 18))
  expect_equal(sn$attgt$estimate[sn$attgt$cohort == 19 & sn$attgt$period == 20], refn)
  post <- s$attgt[s$attgt$evtm >= 0, ]
  expect_equal(s$overall$estimate, sum(post$ncoh * post$estimate) / sum(post$ncoh))
  e0 <- s$attgt[s$attgt$evtm == 0, ]
  expect_equal(s$dynamic$estimate[s$dynamic$evtm == 0], mean(e0$estimate))
  w <- stgatt(p, "district", "month", "crmrate", "refmonth", meth = "wooldridge", reps = 0)
  p$cell <- ifelse(!is.na(p$refmonth) & p$month >= p$refmonth, paste0(p$refmonth, "_", p$month), "0")
  p$cell <- stats::relevel(factor(p$cell), "0")
  f <- stats::lm(crmrate ~ cell + factor(district) + factor(month), p)
  cf <- stats::coef(f)[paste0("cell", w$attgt$cohort, "_", w$attgt$period)]
  expect_equal(w$attgt$estimate, unname(cf), tolerance = 1e-8)
  # covariates: the doubly robust cell by hand (Sant'Anna and Zhao 2020)
  q <- .pe()
  q$x1 <- .rmbl_with_seed(7, stats::rnorm(20))[match(q$district, unique(q$district))]
  q$crmrate <- q$crmrate + 2 * q$x1 * q$month / 36
  sx <- stgatt(q, "district", "month", "crmrate", "refmonth", reps = 0, covs = "x1")
  u <- unique(q$district)
  grp <- q$refmonth[match(u, q$district)]
  k <- grp %in% c(19, 25) | is.na(grp)
  yy <- function(t) q$crmrate[q$month == t][match(u, q$district[q$month == t])]
  dy <- (yy(20) - yy(18))[k]
  d <- as.numeric(grp[k] %in% 19)
  x <- cbind(1, q$x1[match(u, q$district)][k])
  m <- as.vector(x %*% stats::lm.fit(x[d == 0, ], dy[d == 0])$coefficients)
  ps <- stats::glm.fit(x, d, family = stats::binomial())$fitted.values
  w <- ps * (1 - d) / (1 - ps)
  ref <- sum(d * (dy - m)) / sum(d) - sum(w * (dy - m)) / sum(w)
  expect_equal(sx$attgt$estimate[sx$attgt$cohort == 19 & sx$attgt$period == 20], ref, tolerance = 1e-10)
  sr <- stgatt(q, "district", "month", "crmrate", "refmonth", reps = 0, covs = "x1",
                      estmeth = "reg")
  expect_equal(sr$attgt$estimate[sr$attgt$cohort == 19 & sr$attgt$period == 20], mean((dy - m)[d == 1]))
  expect_error(stgatt(q, "district", "month", "crmrate", "refmonth", meth = "wooldridge",
                             covs = "x1"), "csa")
  b <- stgatt(.pe(), "district", "month", "crmrate", "refmonth", reps = 30, seed = 2)
  expect_true(all(is.finite(b$attgt$se)) && is.finite(b$overall$se))
  expect_identical(b$overall, stgatt(.pe(), "district", "month", "crmrate", "refmonth", reps = 30,
                                            seed = 2)$overall)
  expect_output(print(b), "Callaway-Sant'Anna")
  expect_identical(nrow(plot(b)), nrow(b$dynamic))
  expect_error(stgatt(.pe()[-1, ], "district", "month", "crmrate", "refmonth"), "balanced")
  nv <- .pe()
  nv <- nv[!is.na(nv$refmonth), ]
  expect_error(stgatt(nv, "district", "month", "crmrate", "refmonth", ctrl = "never"),
               "no never-treated unit")
})

test_that("bacondcmp(): the weighted comparisons add up to the two-way estimate exactly", {
  p <- .pe()
  b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
  expect_equal(sum(b$weight), 1)
  expect_equal(attr(b, "twfe"), plndid(p, "district", "month", "crmrate", "reformed")$estimate,
               tolerance = 1e-10)
  expect_setequal(unique(b$type), c("treated vs never", "earlier vs later", "later vs earlier"))
  m <- function(rg, t) mean(p$crmrate[p$region %in% rg & p$month %in% t])
  ref <- (m("R1", 13:36) - m("R1", 1:12)) - (m("R4", 13:36) - m("R4", 1:12))
  expect_equal(b$estimate[b$type == "treated vs never" & b$treated == 13], ref)
  expect_output(print(b), "later vs earlier")
  # with no never-treated unit the decomposition is still exact
  nv <- p[!is.na(p$refmonth), ]
  bn <- bacondcmp(nv, "district", "month", "crmrate", "reformed")
  expect_equal(attr(bn, "twfe"), plndid(nv, "district", "month", "crmrate", "reformed")$estimate,
               tolerance = 1e-10)
  off <- p
  off$reformed[off$district == "D01" & off$month == 30] <- 0
  expect_error(bacondcmp(off, "district", "month", "crmrate", "reformed"), "stay on")
})

test_that("swtdid(): with treatment that stays on, it equals the not-yet-treated effect at adoption", {
  p <- .pe()
  sw <- swtdid(p, "district", "month", "crmrate", "reformed", reps = 0)
  s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 0)
  expect_equal(sw$estimate[1], s$dynamic$estimate[s$dynamic$evtm == 0])
  expect_identical(sw$switchers, c(15, 15))
  # units that switch off: the stayers' change minus the leavers'
  d <- data.frame(u = rep(1:4, each = 2), t = rep(1:2, 4), y = c(5, 3, 5, 6, 1, 1, 1, 2),
                  tr = c(1, 0, 1, 1, 0, 0, 0, 0))
  expect_equal(swtdid(d, "u", "t", "y", "tr", reps = 0)$estimate[1], 1 - (-2))
  b <- swtdid(p, "district", "month", "crmrate", "reformed", reps = 20, seed = 1)
  expect_true(all(is.finite(b$se)))
  expect_error(swtdid(transform(p, reformed = 0), "district", "month", "crmrate", "reformed"),
               "no unit switches")
})

test_that("perminf(): every assignment of the stages, and the stepdown", {
  p <- .pe()
  r <- perminf(p, "district", "month", c("crmrate", "arrrate"), "refmonth",
                             cl = "region", reps = 199)
  expect_true(all(r$exact))
  expect_identical(r$assignments, c(24L, 24L))
  expect_equal(r$p_value * 24, round(r$p_value * 24))
  expect_true(all(r$pstpdn >= r$p_value))
  expect_equal(r$estimate[1], plndid(p, "district", "month", "crmrate", "reformed")$estimate)
  rr <- perminf(p, "district", "month", "crmrate", "refmonth", reps = 49, seed = 1,
                              stat = "estimate")
  expect_false(rr$exact)
  expect_equal(rr$p_value * 50, round(rr$p_value * 50))
  expect_identical(rr$pstpdn, rr$p_value)
  expect_identical(nrow(.rmbl_multiset_perms(c(1, 1, 2, 3))), 12L)
  rs <- perminf(p, "district", "month", "crmrate", "refmonth", cl = "region",
                              ties = "strict")
  expect_equal(rs$p_value, r$p_value[1] - 1 / 24)
  expect_error(perminf(p, "district", "month", "crmrate", "refmonth",
                                     cl = "month"), "same for every unit of a cluster")
})

test_that("stpdnpv(): Westfall-Young by hand", {
  null <- matrix(c(1, 3, 0.5, 2, 0.1, 0.2, 4, 1, 1.5), ncol = 3, byrow = TRUE)
  obs <- c(2.5, 0.4, 1.2)
  # order: 1 (2.5), 3 (1.2), 2 (0.4); successive maxima per draw over the remaining set
  q1 <- apply(abs(null), 1L, max)
  q2 <- pmax(abs(null[, 3]), abs(null[, 2]))
  q3 <- abs(null[, 2])
  p1 <- mean(q1 >= 2.5)
  p3 <- max(p1, mean(q2 >= 1.2))
  p2 <- max(p3, mean(q3 >= 0.4))
  expect_equal(stpdnpv(obs, null), c(p1, p2, p3))
  expect_error(stpdnpv(1:2, matrix(1, 2, 3)), "one column per observed")
  expect_error(stpdnpv(c(1, NA), matrix(1, 2, 2)), "no NA")
})

test_that("plnpois(): the coefficient of glm() with dummies, and units with no count dropped", {
  p <- .pe()
  r <- plnpois(p, "district", "month", "crimes", "reformed", offset = "logpop")
  f <- stats::glm(crimes ~ reformed + factor(district) + factor(month) + offset(logpop),
                  family = stats::poisson(), data = p)
  expect_equal(r$estimate, unname(stats::coef(f)["reformed"]), tolerance = 1e-7)
  expect_equal(r$rateratio, exp(r$estimate))
  expect_identical(attr(r, "drounits"), 0L)
  p$crimes[p$district == "D02"] <- 0
  expect_identical(attr(plnpois(p, "district", "month", "crimes", "reformed"), "drounits"), 1L)
  expect_error(plnpois(transform(p, crimes = -1), "district", "month", "crimes", "reformed"), "counts")
  # the negative binomial: overdispersed counts, the maximum likelihood of NB2 with dummies
  q <- .pe()
  q$crimes <- .rmbl_with_seed(5, stats::rnbinom(nrow(q), size = 4, mu = q$crimes + 1))
  nb <- plnpois(q, "district", "month", "crimes", "reformed", family = "negbin")
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

test_that("synctl(): weights on the simplex that satisfy the optimality conditions", {
  p <- .pe()
  p1 <- p[is.na(p$refmonth) | p$district == "D13", ]
  s <- synctl(p1, "district", "month", "crmrate", "D13", 13)
  w <- s$weights
  expect_equal(sum(w), 1)
  expect_true(all(w >= 0))
  ym <- t(sapply(names(w), function(u) p1$crmrate[p1$district == u & p1$month < 13]))
  y1 <- p1$crmrate[p1$district == "D13" & p1$month < 13]
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
  expect_true(is.na(synctl(p1, "district", "month", "crmrate", "D13", 13, plac = FALSE)$p_value))
  expect_error(synctl(p1, "district", "month", "crmrate", "D99", 13), "not a unit")
  expect_error(synctl(p1, "district", "month", "crmrate", "D13", 2), "two periods before")
})

test_that("sevidx(), piperate(), cmlrisk() and bufasgn() by hand", {
  d <- data.frame(city = rep(c("A", "B"), each = 3), year = 2024,
                  offence = rep(c("homicide", "robbery", "burglary"), 2),
                  n = c(5, 120, 300, 2, 90, 410), pop = rep(c(250000, 180000), each = 3))
  w <- c(homicide = 25, robbery = 8, burglary = 4)
  s <- sevidx(d, "city", "year", "offence", "n", w = w, pop = "pop")
  expect_equal(s$unweighted[1], (5 + 120 + 300) / 2.5)
  expect_equal(s$weighted[1], (25 * 5 + 8 * 120 + 4 * 300) / 2.5)
  expect_true(is.na(sevidx(d[-1, ], "city", "year", "offence", "n", w)$weighted[1]))
  expect_error(sevidx(d, "city", "year", "offence", "n", c(arson = 1)), "not an offence")
  expect_error(sevidx(rbind(d, d[1, ]), "city", "year", "offence", "n", w), "appears twice")

  r <- piperate(1:24, rep(10, 24), win = 12, lag = 3)
  expect_true(all(is.na(r$rate[1:14])))
  expect_equal(r$rate[15], sum(4:15) / 120)
  expect_equal(piperate(c(2, 3), c(4, 0), win = 1)$rate, c(0.5, NA))
  g <- piperate(c(1, 2, 3, 4), c(2, 2, 2, 2), win = 1, grp = c("a", "a", "b", "b"))
  expect_identical(g$index, c(1L, 2L, 1L, 2L))
  expect_error(piperate(1:3, 1:2), "same length")

  cr <- cmlrisk(16:18, c(10, 20, 30), c(1000, 1000, 1000))
  h <- c(10 / 1000, 20 / (1000 * 0.99), 30 / (1000 * (1 - 0.01 - 0.02)))
  expect_equal(cr$hazard, h)
  expect_equal(cr$cumrisk, 1 - cumprod(1 - h))
  expect_true(all(cr$lower < cr$cumrisk & cr$cumrisk < cr$upper))
  cm <- cmlrisk(16:17, c(10, 20), c(1000, 1000), atrisk = c(1000, 990), dthrate = c(0.01, 0.01))
  expect_equal(cm$cumrisk, c(0.01, 0.01 + (1 - 0.01 - 0.01) * 20 / 990))
  expect_error(cmlrisk(c(2, 1), c(1, 1), c(10, 10)), "increasing")
  expect_error(cmlrisk(1, 20, 10), "more first events")

  a <- bufasgn(c(0, 100, 2000, 5000), c(0, 0, 0, 0), 0, 0, c(2000, 5000), c(0, 0), radius = 330)
  expect_identical(a$group, c("treated", "treated", "comparison", "comparison"))
  b <- bufasgn(800, 0, 0, 0, 900, 0, radius = 330)
  expect_identical(b$group, "excluded")
  expect_error(bufasgn(1, 1:2, 0, 0, 1, 1, 10), "same length")
})

test_that("polex() is reproducible and has the effect it was built with", {
  expect_identical(polex(), polex())
  p <- polex()
  expect_identical(nrow(p), 720L)
  expect_identical(sort(unique(p$refmonth)), c(13, 19, 25))
  expect_lt(abs(plndid(p, "district", "month", "crmrate", "reformed")$estimate + 3), 0.5)
})
