# Lines of 1.0.0 the suite had not reached in the policy estimators (codecov of 186bc3ef): the refusals
# of the panel helpers, the rarer branches of the staggered, switching and count estimators, the
# matching and synthetic designs, and the plots built on them. Each test names the lines it reaches.

# a balanced panel of `nu` units over `nt` periods; `g` is each unit's first treated period (Inf: never)
.cp_pan <- function(g, nt = 6L, seed = 1L) {
  nu <- length(g)
  d <- expand.grid(t = seq_len(nt), u = seq_len(nu))
  d <- d[c("u", "t")]
  d$g <- g[d$u]
  d$tr <- as.numeric(d$t >= d$g)
  d$y <- d$u + 0.5 * d$t + 2 * d$tr + .rmbl_with_seed(seed, stats::rnorm(nrow(d), 0, 0.3))
  d
}

.cp_dev <- function(env = parent.frame()) {
  grDevices::pdf(NULL)
  withr::defer(grDevices::dev.off(), envir = env)
}

# ---- R/policy_evaluation.R: the panel helpers ---------------------------------------------------------

test_that("the panel helpers refuse a missing unit column, a unit with NA and a bad first-treated column", {
  p <- polex()
  # reaches .rmbl_panel's refusal of a unit column that is not in the data
  expect_error(plndid(p, "zz", "month", "crmrate", "reformed"), "`unit` \\(zz\\) is not a column")
  # reaches .rmbl_panel's refusal of a unit with NA
  pn <- p
  pn$district[1] <- NA
  expect_error(plndid(pn, "district", "month", "crmrate", "reformed"), "`unit` must have no NA")
  # .rmbl_first_treated: `ftreat` (%s) is not a column / must be numeric / the same in every row
  expect_error(evstudy(p, "district", "month", "crmrate", "zz"), "`ftreat` \\(zz\\) is not a column")
  expect_error(evstudy(transform(p, rc = as.character(refmonth)), "district", "month", "crmrate", "rc"),
               "`ftreat` must be numeric")
  pv <- p
  pv$refmonth[pv$district == "D01"][2] <- 5
  expect_error(evstudy(pv, "district", "month", "crmrate", "refmonth"), "the same in every row of a unit")
})

test_that(".rmbl_demean() with no fixed effect returns the matrix as given", {
  # reaches .rmbl_demean's early return when there is no fixed effect
  x <- matrix(c(1, 5, 2, 9), 2)
  expect_identical(.rmbl_demean(x, list()), x)
})

test_that("clusters, covariates and weights are refused in words", {
  p <- polex()
  p$one <- 1
  # reaches .rmbl_ols_cr1's refusal of fewer than two clusters
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", cl = "one"), "two clusters at least")
  # .rmbl_cluster: `cluster` (%s) is not a column / must have no NA
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", cl = "zz"), "`cluster` \\(zz\\) is not a column")
  pc <- p
  pc$region[3] <- NA
  expect_error(plndid(pc, "district", "month", "crmrate", "reformed", cl = "region"), "`cluster` must have no NA")
  # reaches .rmbl_covariates's refusal naming the covariates not in the data
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", covs = c("arrrate", "zz")),
               "not columns of `data`: zz")
  # .rmbl_weights: `weights` (%s) is not a column / must be 0 or more, with no NA
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", w = "zz"), "`weights` \\(zz\\) is not a column")
  p$wneg <- -1
  expect_error(plndid(p, "district", "month", "crmrate", "reformed", w = "wneg"), "must be 0 or more")
})

test_that("two-way clustering clips a negative eigenvalue of V_a + V_b - V_ab to zero", {
  # reaches .rmbl_ols_cr1's clipping of the negative eigenvalues of the two-way variance at zero
  n <- 24
  withr::local_seed(1)
  x <- cbind(a = stats::rnorm(n), b = stats::rnorm(n))
  y <- stats::rnorm(n)
  c1 <- rep(1:3, length.out = n)
  c2 <- rep(1:4, each = 6)
  br <- solve(crossprod(x))
  e <- as.vector(y - x %*% qr.coef(qr(x), y))
  m <- function(cc) br %*% crossprod(rowsum(x * e, cc)) %*% br
  raw <- m(c1) + m(c2) - m(paste(c1, c2))
  expect_lt(min(eigen(raw, symmetric = TRUE)$values), 0)
  f <- .rmbl_ols_cr1(y, x, list(c1, c2), 1)
  ev <- eigen(f$vcov, symmetric = TRUE)$values
  expect_gte(min(ev), -1e-12)
  expect_identical(f$clusters, 3L)
  expect_identical(dimnames(f$vcov), list(c("a", "b"), c("a", "b")))
})

# ---- plndid, evstudy -----------------------------------------------------------------------------------

test_that("plndid() reads a logical treatment as 0 and 1", {
  # reaches plndid's reading of a logical treatment as numbers
  p <- polex()
  p$rl <- p$reformed == 1
  expect_equal(plndid(p, "district", "month", "crmrate", "rl")$estimate,
               plndid(p, "district", "month", "crmrate", "reformed")$estimate)
})

test_that("evstudy() refuses a bad `bin`, takes covariates, and has no pre-trend test without a lead", {
  p <- polex()
  # reaches evstudy's refusal of a `bin` that is not TRUE or FALSE
  expect_error(evstudy(p, "district", "month", "crmrate", "refmonth", bin = NA), "`bin` must be TRUE or FALSE")
  # reaches evstudy's binding of the covariates to the event-time dummies
  e0 <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 2, lags = 2)
  ec <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 2, lags = 2, covs = "arrrate")
  expect_identical(ec$evtm, e0$evtm)
  expect_false(isTRUE(all.equal(ec$estimate, e0$estimate)))
  expect_identical(dim(attr(ec, "vcov")), c(4L, 4L))
})

test_that("evstudy() with one lead, the reference period, has no pre-trend test", {
  # reaches evstudy's empty pre-trend test (F and p NA, df1 zero) when no lead is estimated
  p <- polex()
  e1 <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 1, lags = 2)
  pt <- attr(e1, "pretrend")
  expect_true(is.na(pt$F) && is.na(pt$p_value))
  expect_identical(pt$df1, 0L)
  expect_identical(pt$df2, attr(e1, "clusters") - 1L)
  # reaches tse's refusal when only the reference period precedes adoption
  expect_error(tse(e1), "need one lead at least")
})

# ---- stgatt --------------------------------------------------------------------------------------------

test_that("stgatt() refuses a panel whose units are all treated from the first period", {
  # reaches stgatt's "no unit is first treated within the panel" refusal
  d <- .cp_pan(c(1, 1, 1, Inf))
  expect_error(stgatt(d, "u", "t", "y", "g", reps = 0), "no unit is first treated within the panel")
})

test_that("stgatt(): a bootstrap draw it cannot estimate is left out of the standard errors", {
  # reaches stgatt's bootstrap draw that cannot be estimated, which returns NULL and is dropped
  d <- .cp_pan(c(3, Inf, Inf, Inf))
  r <- stgatt(d, "u", "t", "y", "g", ctrl = "never", reps = 30, seed = 2)
  expect_equal(r$attgt$estimate[r$attgt$period == 3],
               with(d, (mean(y[u == 1 & t == 3]) - mean(y[u == 1 & t == 2])) -
                      (mean(y[u > 1 & t == 3]) - mean(y[u > 1 & t == 2]))))
  expect_true(all(is.finite(r$attgt$se)))
  expect_gt(r$overall$se, 0)
})

test_that("stgatt(), not-yet-treated: a period with no comparison is skipped, and none at all is refused", {
  # reaches .rmbl_cs skipping a period with no comparison unit
  d <- .cp_pan(c(3, 3, 5, 5))
  r <- stgatt(d, "u", "t", "y", "g", ctrl = "notyet", reps = 0)
  a3 <- r$attgt[r$attgt$cohort == 3, ]
  expect_identical(a3$period, c(2, 3, 4))
  expect_false(any(r$attgt$cohort == 5 & r$attgt$period >= 5))
  # reaches .rmbl_cs's "no cohort has a comparison group in any period" refusal
  expect_error(stgatt(.cp_pan(c(3, 3, 3)), "u", "t", "y", "g", ctrl = "notyet", reps = 0),
               "no cohort has a comparison group in any period")
})

test_that("stgatt() with a covariate constant among the comparison units refuses the regression", {
  # reaches .rmbl_drdid's refusal of covariates collinear among the comparison units
  d <- .cp_pan(c(3, 3, Inf, Inf, Inf))
  d$k <- 1
  expect_error(stgatt(d, "u", "t", "y", "g", ctrl = "never", covs = "k", reps = 0),
               "collinear among the comparison units")
})

test_that("stgatt(meth = \"wooldridge\") with no never-treated unit uses the last cohort as comparison", {
  # reaches .rmbl_etwfe's choice of the last cohort as the comparison, the dropping of its rows after
  # it adopts, and the "cell is collinear with the fixed effects" refusal: after the last cohort adopts,
  # only the first cohort is left, and its cells are the period effects
  d <- .cp_pan(c(2, 2, 2, 4, 4, 4), nt = 5L)
  expect_error(stgatt(d, "u", "t", "y", "g", meth = "wooldridge", ctrl = "notyet", reps = 0),
               "collinear with the fixed effects")
  d2 <- .cp_pan(c(3, 3, 6, 6), nt = 6L)
  r <- stgatt(d2, "u", "t", "y", "g", meth = "wooldridge", ctrl = "notyet", reps = 0)
  expect_identical(unique(r$attgt$cohort), 3)
  expect_equal(r$attgt$period, 3:6)
  # reaches .rmbl_etwfe's "no treated cohort-period cell" refusal: the one cohort is its own comparison
  expect_error(stgatt(.cp_pan(c(3, 3, 3)), "u", "t", "y", "g", meth = "wooldridge", ctrl = "notyet",
                      reps = 0), "no treated cohort-period cell")
})

# ---- bacondcmp, swtdid ---------------------------------------------------------------------------------

test_that("bacondcmp() refuses a bad treatment, an unbalanced panel and no treated unit", {
  d <- .cp_pan(c(3, 5, Inf, Inf))
  # bacondcmp: `trtd` (%s) is not a column / must be 0 or 1 / balanced panel / no unit is ever treated
  expect_error(bacondcmp(d, "u", "t", "y", "zz"), "`trtd` \\(zz\\) is not a column")
  expect_error(bacondcmp(transform(d, tr = 2), "u", "t", "y", "tr"), "`trtd` must be 0 or 1")
  expect_error(bacondcmp(d[-1, ], "u", "t", "y", "tr"), "must be a balanced panel")
  expect_error(bacondcmp(transform(d, tr = 0), "u", "t", "y", "tr"), "no unit is ever treated")
})

test_that("bacondcmp(): a unit treated in every period gives no treated-versus-never comparison", {
  # reaches bacondcmp skipping a cohort treated in every period (its share of treated time is one)
  d <- .cp_pan(c(1, 4, Inf, Inf))
  b <- bacondcmp(d, "u", "t", "y", "tr")
  tv <- b[b$type == "treated vs never", ]
  expect_identical(tv$treated, 4L)
  expect_equal(sum(b$weight), 1)
  expect_false(any(b$type == "earlier vs later"))
})

test_that("swtdid() refuses what it cannot take, and a leaver gives a placebo against a stayer", {
  d <- .cp_pan(c(3, Inf, Inf))
  # swtdid: `trtd` (%s) is not a column / must be 0 or 1 / balanced panel
  expect_error(swtdid(d, "u", "t", "y", "zz"), "`trtd` \\(zz\\) is not a column")
  expect_error(swtdid(transform(d, tr = 3), "u", "t", "y", "tr"), "`trtd` must be 0 or 1")
  expect_error(swtdid(d[-2, ], "u", "t", "y", "tr"), "must be a balanced panel")
  # reaches swtdid's placebo term of a leaver against a stayer (the pl and p1 branch of est)
  s <- data.frame(u = rep(1:2, each = 4), t = rep(1:4, 2), tr = c(1, 1, 0, 0, 1, 1, 1, 1),
                  y = c(1, 3, 4, 9, 2, 7, 11, 12))
  r <- swtdid(s, "u", "t", "y", "tr", reps = 0)
  y <- matrix(s$y, 2, byrow = TRUE)
  expect_equal(r$estimate[1], (y[2, 3] - y[2, 2]) - (y[1, 3] - y[1, 2]))
  expect_equal(r$estimate[2], (y[2, 2] - y[2, 1]) - (y[1, 2] - y[1, 1]))
  expect_identical(r$switchers, c(1, 1))
})

# ---- perminf, stpdnpv ----------------------------------------------------------------------------------

test_that("perminf() with every unit adopting in the first period has no comparison to permute", {
  # reaches the NA statistic of perminf for a treatment that never varies, and then the plndid refusal
  d <- .cp_pan(c(1, 1, 1, 1))
  expect_error(perminf(d, "u", "t", "y", "g", reps = 9), "never varies")
})

test_that("stpdnpv() refuses a null with no complete draw", {
  # reaches stpdnpv's "no complete draw" refusal
  expect_error(stpdnpv(c(1, 2), matrix(c(NA, 1, 2, NA), 2)), "`null` has no complete draw")
})

# ---- plnpois -------------------------------------------------------------------------------------------

test_that("plnpois() refuses a bad treatment column and a regressor collinear with another", {
  d <- .cp_pan(c(3, 3, Inf, Inf))
  d$y <- round(exp(d$y / 4))
  # plnpois: `trtd` (%s) is not a column / must be numeric with no NA
  expect_error(plnpois(d, "u", "t", "y", "zz"), "`trtd` \\(zz\\) is not a column")
  expect_error(plnpois(transform(d, tc = as.character(tr)), "u", "t", "y", "tc"), "numeric with no NA")
  # reaches plnpois's reading of a logical treatment as numbers
  expect_equal(plnpois(transform(d, tl = tr == 1), "u", "t", "y", "tl")$estimate,
               plnpois(d, "u", "t", "y", "tr")$estimate)
  # reaches plnpois's "regressor is collinear with the fixed effects" refusal
  expect_error(plnpois(transform(d, t2 = tr), "u", "t", "y", "tr", covs = "t2"), "collinear with the fixed effects")
})

test_that("plnpois(family = \"negbin\") on Poisson counts warns that theta is at its bound", {
  # reaches plnpois's "no overdispersion" warning, theta at its bound
  d <- expand.grid(t = 1:6, u = 1:8)
  d$tr <- as.numeric(d$u <= 4 & d$t >= 4)
  d$y <- .rmbl_with_seed(3, stats::rpois(nrow(d), 20 * exp(0.3 * d$tr)))
  expect_warning(r <- plnpois(d, "u", "t", "y", "tr", family = "negbin"), "theta is at its bound")
  expect_gt(attr(r, "theta"), exp(14))
  expect_equal(r$estimate, plnpois(d, "u", "t", "y", "tr")$estimate, tolerance = 1e-4)
})

test_that("plnpois() says so when the count model does not converge", {
  # reaches the warning "the count model did not converge": an offset spread over 20 log units sends
  # the IRLS fit past its iteration limit
  d <- expand.grid(t = 1:6, u = 1:6)
  d$tr <- as.numeric(d$u <= 3 & d$t >= 4)
  withr::with_seed(1, {
    d$y <- stats::rpois(nrow(d), 5)
    d$o <- stats::rnorm(nrow(d), 0, 20)
  })
  seen <- character()
  withCallingHandlers(plnpois(d, "u", "t", "y", "tr", offset = "o"), warning = function(w) {
    seen <<- c(seen, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_true("the count model did not converge" %in% seen)
})

# ---- synctl, sevidx, piperate, cmlrisk, bufasgn --------------------------------------------------------

test_that("synctl() refuses a bad placebo flag, an unbalanced panel and too few donors", {
  d <- .cp_pan(c(4, Inf, Inf), nt = 6L)
  # reaches synctl's refusal of a `plac` that is not TRUE or FALSE
  expect_error(synctl(d, "u", "t", "y", 1, 4, plac = NA), "`plac` must be TRUE or FALSE")
  # synctl: balanced panel; two donor units at least
  expect_error(synctl(d[-5, ], "u", "t", "y", 1, 4), "must be a balanced panel")
  expect_error(synctl(d[d$u <= 2, ], "u", "t", "y", 1, 4), "two donor units at least")
})

test_that("sevidx(), piperate(), cmlrisk() and bufasgn() refuse what they cannot use", {
  d <- data.frame(city = "A", year = 2024, offence = c("homicide", "robbery"), n = c(1, 5))
  # sevidx: `%s` (%s) is not a column; `w` must be numbers named by offence
  expect_error(sevidx(d, "city", "yr", "offence", "n", c(homicide = 1)), "`time` \\(yr\\) is not a column")
  expect_error(sevidx(d, "city", "year", "offence", "n", c(1, 2)), "`w` must be numbers named by offence")
  # piperate: counts must not be negative; `grp` must be one per count
  expect_error(piperate(c(1, -1), c(2, 2)), "counts must not be negative")
  expect_error(piperate(1:3, 1:3, win = 1, grp = c("a", "b")), "`grp` must be one per count")
  # cmlrisk: lengths, signs, atrisk, dthrate, and events plus deaths beyond the cohort
  expect_error(cmlrisk(1:2, 1, c(10, 10)), "must match")
  expect_error(cmlrisk(1:2, c(-1, 1), c(10, 10)), "counts must be 0 or more")
  expect_error(cmlrisk(1:2, c(1, 1), c(10, 10), atrisk = c(10, 0)), "`atrisk` must be one per age")
  expect_error(cmlrisk(1:2, c(1, 1), c(10, 10), dthrate = c(0.1, 1)), "`dthrate` must be one per age")
  expect_error(cmlrisk(1:2, c(50, 0), c(100, 100), dthrate = c(0.6, 0)),
               "events and deaths exceed the cohort at age 1")
  # bufasgn: one site and one comparison point at least; no NA
  expect_error(bufasgn(0, 0, numeric(), numeric(), 1, 1, radius = 1), "one site and one comparison point")
  expect_error(bufasgn(NA, 0, 0, 0, 1, 1, radius = 1), "coordinates must have no NA")
})

# ---- R/panel_causal.R ----------------------------------------------------------------------------------

.cp_dml <- function() {
  d <- .cp_pan(rep(Inf, 6), nt = 6L)
  d$x1 <- .rmbl_with_seed(5, stats::rnorm(nrow(d)))
  d$d <- 0.5 * d$x1 + .rmbl_with_seed(6, stats::rnorm(nrow(d)))
  d
}

test_that("plndml(): an outcome with no variation gives the lasso a unit penalty path and a zero effect", {
  # reaches .rmbl_lasso_lambdas setting the largest penalty to one when the outcome has no variation
  d <- .cp_dml()
  d$y <- 0
  r <- plndml(d, "u", "t", "y", "d", "x1", folds = 3)
  expect_equal(r$estimate, 0)
  expect_equal(.rmbl_lasso_lambdas(cbind(d$x1), rep(0, nrow(d)), 3L)[1], 1)
})

test_that("plndml() with one covariate in the poly2 basis adds its square only", {
  # reaches .rmbl_poly2's return for a single covariate (the column and its square)
  expect_identical(colnames(.rmbl_poly2(cbind(a = 1:3))), c("a", "a^2"))
  d <- .cp_dml()
  r <- plndml(d, "u", "t", "y", "d", "x1", lrn = "ols", basis = "poly2", folds = 3)
  expect_true(is.finite(r$estimate) && r$se > 0)
})

test_that("plndml() refuses a bad treatment, missing values, too few units, two-way clusters, no variation", {
  d <- .cp_dml()
  # plndml: `trt` (%s) is not a column
  expect_error(plndml(d, "u", "t", "y", "zz", "x1"), "`trt` \\(zz\\) is not a column")
  # plndml: the outcome, treatment and covariates must have no NA
  dn <- d
  dn$x1[2] <- NA
  expect_error(plndml(dn, "u", "t", "y", "d", "x1"), "must have no NA")
  # plndml: fewer units than folds
  expect_error(plndml(d, "u", "t", "y", "d", "x1", folds = 7), "fewer units than folds")
  # plndml: the refusal of two cluster columns
  expect_error(plndml(d, "u", "t", "y", "d", "x1", folds = 3, cl = c("u", "t")), "names one column for plndml")
  # plndml, one(): the treatment has no variation left after the covariates
  expect_error(plndml(transform(d, d = x1), "u", "t", "y", "d", "x1", lrn = "ols", folds = 3),
               "no variation left after the covariates")
})

test_that("mtchdid() refuses an unbalanced panel and adoption in the first period", {
  d <- .cp_pan(c(4, 4, Inf, Inf, Inf))
  # mtchdid: must be a balanced panel; no period before the first adoption to match on
  expect_error(mtchdid(d[-1, ], "u", "t", "y", "g"), "must be a balanced panel")
  expect_error(mtchdid(.cp_pan(c(1, 1, Inf, Inf)), "u", "t", "y", "g"), "no period before the first adoption")
  # mtchdid: `exact` (%s) is not a column; no treated unit has a comparison unit in its exact group
  expect_error(mtchdid(d, "u", "t", "y", "g", exact = "zz"), "`exact` \\(zz\\) is not a column")
  d$grp <- ifelse(d$u <= 2, "a", "b")
  expect_error(mtchdid(d, "u", "t", "y", "g", exact = "grp"), "no treated unit has a comparison unit")
})

test_that("mtchdid(): covariates join the matching features, a singular covariance is pseudo-inverted", {
  # reaches mtchdid's covariate features (their pre-period means bound to the outcomes) and the
  # eigen pseudo-inverse used when the pooled covariance cannot be solved:
  # the mean of the pre-period outcomes, as a covariate, is a combination of the other features: the
  # pooled covariance is singular, and the pseudo-inverse gives the distances of the outcomes alone
  p <- polex()
  p$cr2 <- p$crmrate
  full <- mtchdid(p, "district", "month", "crmrate", "refmonth")
  m <- mtchdid(p, "district", "month", "crmrate", "refmonth", covs = "cr2")
  expect_identical(m$balance$feature, c(paste0("y_", 1:12), "cr2"))
  expect_equal(m$matches$distance, full$matches$distance, tolerance = 1e-6)
  expect_identical(m$matches$control, full$matches$control)
})

test_that("mtchdid() balance with one matched comparison unit gives NA tests, not an error", {
  d <- data.frame(g = c(1, 1, 0), x = c(1, 2, 5))
  b <- baltab(d, "g", "x")
  expect_true(is.na(b$p_value))
  p <- polex()
  m <- mtchdid(p, "district", "month", "crmrate", "refmonth", caliper = 5)
  expect_identical(length(unique(m$matches$treated)), 1L)
})

test_that("mtchdid(caliper =): matches beyond the caliper are dropped, and none left is refused", {
  # reaches mtchdid's caliper: the scalar check, the matches kept within caliper times the SD of the
  # distances, the zero weight of a treated unit left unmatched, and the "no match within" refusal
  p <- polex()
  full <- mtchdid(p, "district", "month", "crmrate", "refmonth")
  m <- mtchdid(p, "district", "month", "crmrate", "refmonth", caliper = 6)
  expect_identical(nrow(full$matches), 15L)
  expect_identical(nrow(m$matches), 3L)
  kept <- full$matches[full$matches$treated %in% m$matches$treated, ]
  expect_equal(m$matches$distance, kept$distance)
  expect_error(mtchdid(p, "district", "month", "crmrate", "refmonth", caliper = 0), "no match within the caliper")
})

test_that("syndid() refuses an unbalanced panel, one never-treated unit and a single pre-period", {
  d <- .cp_pan(c(4, Inf, Inf, Inf))
  # syndid: balanced panel; two never-treated units; two periods before adoption and one after
  expect_error(syndid(d[-1, ], "u", "t", "y", "g"), "must be a balanced panel")
  expect_error(syndid(d[d$u <= 2, ], "u", "t", "y", "g"), "two never-treated units at least")
  expect_error(syndid(.cp_pan(c(2, Inf, Inf)), "u", "t", "y", "g"), "two periods before adoption")
})

test_that("syndid(): a jackknife that drops the only weighted donor leaves that draw out", {
  # reaches the NA jackknife draw of syndid when the dropped donor held all the unit weight:
  # the flat donor gets all the weight, the other moves against the treated path
  b <- 3 * sin(1:8)
  mk <- function(u, y, g) data.frame(u = u, t = 1:8, y = y, g = g)
  d <- rbind(mk(1, b + c(rep(0, 5), 2, 2, 2), 6), mk(2, b + 1 + c(rep(0, 5), 2, 2, 2), 6),
             mk(3, rep(0, 8), Inf), mk(4, -0.05 * b, Inf))
  s <- syndid(d, "u", "t", "y", "g", reps = 2)
  expect_identical(s$method, "jackknife")
  expect_equal(unname(s$unitwts), c(1, 0))
  expect_true(is.finite(s$se) && s$se < 1e-8)
})

test_that("wcb() refuses a bad treatment and two-way clusters, and gives an unbounded random-weight interval", {
  p <- polex()
  # wcb: `trtd` must be 0 or 1; `cl` names one column here
  expect_error(wcb(transform(p, reformed = 2), "district", "month", "crmrate", "reformed"), "must be 0 or 1")
  expect_error(wcb(p, "district", "month", "crmrate", "reformed", cl = c("region", "month")),
               "`cl` names one column here")
  # reaches wcb's infinite bound when no value is rejected however far out (random Webb weights,
  # 19 draws: the lower bound is -Inf on R-release; a build whose arithmetic moves a tied draw
  # by 1e-12 gives 1/19 against 0/19 and a finite bound, so only the shape is asserted)
  w <- wcb(p, "district", "month", "crmrate", "reformed", cl = "region", wtype = "webb", reps = 19, seed = 1)
  expect_false(w$enumerated)
  expect_true(w$lower == -Inf || w$lower < w$estimate)
  expect_true(w$upper == Inf || w$upper > w$estimate)
})

test_that("tse() refuses negative magnitudes, no lead, and no post period", {
  p <- polex()
  es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3, lags = 2)
  # tse: `mbar` must be non-negative numbers
  expect_error(tse(es, mbar = -1), "`mbar` must be non-negative")
  # (the one-lead refusal is in the skipped evstudy(leads = 1) test above)
  # tse: no post-period effect to bound
  e0 <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3, lags = 0, ref = 0)
  expect_error(tse(e0), "no post-period effect to bound")
})

test_that("plnpwr() refuses no adoption period and two-way clusters, and picks its own effects", {
  pre <- polex()
  pre <- pre[pre$month <= 8, ]
  # plnpwr: `adopt` must be periods; `cl` names one column here
  expect_error(plnpwr(pre, "district", "month", "crmrate", ntrt = 5, adopt = numeric()), "`adopt` must be periods")
  expect_error(plnpwr(pre, "district", "month", "crmrate", ntrt = 5, adopt = 5, cl = c("region", "month")),
               "`cl` names one column here")
  # reaches plnpwr's default grid of six effects up to twice the outcome SD
  pw <- plnpwr(pre, "district", "month", "crmrate", ntrt = 5, adopt = 5, reps = 10, seed = 1)
  expect_equal(pw$effect, seq(0, 2 * stats::sd(pre$crmrate), length.out = 6L))
})

.cp_aipw <- function(n = 200) {
  d <- data.frame(age = .rmbl_with_seed(1, stats::runif(n, 18, 70)))
  d$t <- .rmbl_with_seed(2, stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age)))
  d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
  d
}

test_that("aipwcf() refuses no covariate and too few treated rows, and takes the poly2 basis", {
  d <- .cp_aipw()
  # aipwcf: `covs` must name one column at least
  expect_error(aipwcf(d, "y", "t", NULL), "`covs` must name one column at least")
  # aipwcf: too few treated or untreated rows for the folds
  d2 <- d
  d2$t <- c(1, 1, 1, rep(0, nrow(d) - 3))
  expect_error(aipwcf(d2, "y", "t", "age", lrn = "ols"), "too few treated or untreated rows")
  # reaches aipwcf's poly2 basis
  r <- aipwcf(d, "y", "t", "age", lrn = "ols", basis = "poly2", seed = 4)
  expect_lt(abs(r$estimate - 3), 4 * r$se)
})

test_that("the overlap plot of an AIPW result without a trim attribute draws the default 0.01 lines", {
  # reaches plot.rmbl_aipw's default trim of 0.01 when the result carries no trim attribute
  .cp_dev()
  r <- aipwcf(.cp_aipw(), "y", "t", "age", lrn = "ols", seed = 4)
  attr(r, "trim") <- NULL
  ln <- NULL
  local_mocked_bindings(abline = function(...) ln <<- list(...), .package = "graphics")
  o <- plot(r)
  expect_identical(ln$v, c(0.01, 0.99))
  expect_identical(unique(o$arm), c("treated", "untreated"))
})

# ---- R/policy_plots.R ----------------------------------------------------------------------------------

test_that("plotevgrid() stacks the panels' estimates with their names", {
  # reaches plotevgrid's binding of each panel's estimates with its name
  .cp_dev()
  p <- polex()
  es <- list(crime = evstudy(p, "district", "month", "crmrate", "refmonth", leads = 2, lags = 2),
             arrest = evstudy(p, "district", "month", "arrrate", "refmonth", leads = 2, lags = 2))
  g <- plotevgrid(es, main = "Two outcomes")
  expect_identical(unique(g$panel), c("crime", "arrest"))
  expect_equal(g$estimate[g$panel == "arrest"], es$arrest$estimate)
})

test_that("loounit() leaves out each treated unit when no units are named", {
  # reaches loounit's default of every treated unit
  d <- .cp_pan(c(3, 4, Inf, Inf, Inf))
  l <- loounit(d, "u", "t", "y", "tr")
  expect_identical(l$dropped, c("1", "2"))
  expect_equal(l$estimate[1], plndid(d[d$u != 1, ], "u", "t", "y", "tr")$estimate)
})

test_that("cohtrnd() refuses a panel with no treated unit", {
  # reaches cohtrnd's "no unit is ever treated" refusal
  expect_error(cohtrnd(.cp_pan(c(Inf, Inf, Inf)), "u", "t", "y", "g", win = c(-2, 2)), "no unit is ever treated")
})

test_that("the policy plots fit their own or the caller's title to the panel", {
  # reaches the title lines (.bl_title of the default or given title) of the event-study, synthetic
  # control, synthetic DiD, power, AIPW (both types), Bacon, permutation (both types), leave-one-out
  # and cohort-trend plots
  seen <- character()
  local_mocked_bindings(.bl_title = function(title) {
    seen <<- c(seen, as.character(title))
    invisible(title)
  }, .package = "rmoriebricklayer")
  .cp_dev()
  p <- polex()
  d <- .cp_pan(c(4, 4, Inf, Inf, Inf), nt = 6L)
  es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 2, lags = 2)
  plot(es)
  plot(es, main = "t-es")
  sc <- synctl(d, "u", "t", "y", 1, 4)
  plot(sc)
  plot(sc, main = "t-sc")
  sd <- syndid(d, "u", "t", "y", "g", reps = 2)
  plot(sd, main = "t-sd")
  pw <- plnpwr(p[p$month <= 8, ], "district", "month", "crmrate", ntrt = 5, adopt = 5, eff = c(0, 5),
               reps = 10, seed = 1)
  plot(pw, main = "t-pw")
  ai <- aipwcf(.cp_aipw(), "y", "t", "age", lrn = "ols", seed = 4)
  plot(ai, main = "t-ai1")
  plot(ai, type = "estimate", main = "t-ai2")
  plot(bacondcmp(d, "u", "t", "y", "tr"), main = "t-bc")
  pm <- perminf(d, "u", "t", "y", "g", reps = 9, seed = 1)
  plot(pm, main = "t-pm1")
  plot(pm, type = "histogram", main = "t-pm2")
  plot(loounit(d, "u", "t", "y", "tr"), main = "t-lo")
  plot(cohtrnd(d, "u", "t", "y", "g", win = c(-3, 2), ma = 1), main = "t-ct")
  expect_true(all(c("Event study", paste("Synthetic control:", sc$treunit)) %in% seen))
  expect_true(all(c("t-es", "t-sc", "t-sd", "t-pw", "t-ai1", "t-ai2", "t-bc", "t-lo", "t-ct") %in% seen))
  expect_true(any(grepl("t-pm", seen)))
})

# ---- R/plots.R and R/trc.R -----------------------------------------------------------------------------

test_that("a legend under a log-scale panel is placed at the data value of the axis position", {
  # reaches .bl_legend_below's conversion of the position to data units on log axes (both axes)
  .cp_dev()
  graphics::plot(c(1, 100), c(1, 1000), log = "xy")
  usr <- graphics::par("usr")
  got <- NULL
  local_mocked_bindings(legend = function(x, y, ...) got <<- c(x, y), .package = "graphics")
  .bl_legend_below(legend = "a", pch = 19)
  inch <- graphics::par("csi") * 4.8
  y <- usr[3L] - inch / graphics::par("pin")[2L] * (usr[4L] - usr[3L])
  expect_equal(got, c(10^mean(usr[1:2]), 10^y))
})

test_that("trchlthgap() adds the suicidal-thoughts gap when the table carries reference rows", {
  # reaches trchlthgap's suicidal-thoughts gap, added when the table has the reference group
  s <- indiex("suicide")
  r <- s[s$group == "Inuit", ]
  r$group <- "Non-Indigenous"
  r$estimate <- r$estimate / 2
  r$lower <- r$lower / 2
  r$upper <- r$upper / 2
  g <- trchlthgap(health = NULL, lifeexp = NULL, infmort = NULL, suiide = rbind(s, r))
  expect_identical(unique(g$indicator), "suicide")
  expect_identical(unique(g$period), "2017")
  inu <- g[g$group == "Inuit", ]
  expect_equal(inu$disratio, 2, tolerance = 1e-8)
})
