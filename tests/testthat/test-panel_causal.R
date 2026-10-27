# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Panel causal estimation: learners, DML with fixed effects, matching, synthetic
# DiD, the wild cluster bootstrap, trend sensitivity and power, each against an
# exact reference

.pc <- function() polex()

test_that(
  paste0(
    "the lasso satisfies its optimality ",
    "conditions, and ridge and OLS predict"
  ),
  {
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
    expect_identical(b[1], mean(y) - sum(b[-1] * sc$mu))
    expect_length(.rmbl_lasso_cv(x, y, x[1:5, ]), 5L)
    pr <- .rmbl_ridge_gcv(x, y, x[1:5, ])
    expect_lt(max(abs(pr - .rmbl_ols_learner(x, y, x[1:5, ]))), 0.2)
    f <- .rmbl_learner(function(xtr, ytr, xte) rep(0, nrow(xte)))
    expect_identical(f(x, y, x[1:3, ]), c(0, 0, 0))
    expect_error(
      .rmbl_learner(function(xtr, ytr, xte) 1)(x, y, x[1:3, ]),
      "one prediction per test row"
    )
    expect_identical(
      colnames(.rmbl_poly2(cbind(a = 1:3, b = 4:6))),
      c("a", "b", "a^2", "b^2", "a:b")
    )
  }
)

.dml_data <- function() {
  p <- .pc()
  p$u1 <- 6 +
    sin(p$month / 6) +
    .rmbl_with_seed(3, stats::rnorm(nrow(p), 0, 0.5))
  p$u2 <- .rmbl_with_seed(4, stats::rnorm(nrow(p)))
  p$d <- 0.5 * p$u1 + p$u2^2 + .rmbl_with_seed(5, stats::rnorm(nrow(p)))
  p$y <- 1.5 *
    p$d +
    p$u1 +
    2 * p$u2^2 +
    .rmbl_with_seed(6, stats::rnorm(nrow(p))) +
    as.integer(factor(p$district)) / 4
  p
}

test_that(
  paste0(
    "plndml(): the partialling-out estimate ",
    "and its clustered error, by hand"
  ),
  {
    p <- .dml_data()
    r <- plndml(
      p,
      "district",
      "month",
      "y",
      "d",
      c("u1", "u2"),
      lrn = "ols",
      folds = 5,
      seed = 1
    )
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
      u[!tr] <- yt[!tr] -
        cbind(1, xt[!tr, ]) %*%
          stats::lm.fit(cbind(1, xt[tr, ]), yt[tr])$coefficients
      v[!tr] <- dt[!tr] -
        cbind(1, xt[!tr, ]) %*%
          stats::lm.fit(cbind(1, xt[tr, ]), dt[tr])$coefficients
    }
    th <- sum(u * v) / sum(v^2)
    s <- rowsum(v * (u - th * v), pu)
    expect_equal(r$estimate, th, tolerance = 1e-10)
    expect_equal(r$se, sqrt(20 / 19 * sum(s^2)) / sum(v^2), tolerance = 1e-10)
    # a quadratic confounder: the poly2 basis, built before demeaning, removes
    # it
    rq <- plndml(
      p,
      "district",
      "month",
      "y",
      "d",
      c("u1", "u2"),
      lrn = "ridge",
      basis = "poly2"
    )
    expect_lt(abs(rq$estimate - 1.5), 3 * rq$se)
    expect_gt(abs(r$estimate - 1.5), 10 * r$se)
    rr <- plndml(
      p,
      "district",
      "month",
      "y",
      "d",
      c("u1", "u2"),
      lrn = "ols",
      nrep = 3
    )
    expect_identical(attr(rr, "repeats"), 3L)
    expect_output(print(rr), "Out-of-fold R-squared")
    expect_error(
      plndml(p, "district", "month", "y", "d", NULL),
      "one column at least"
    )
    p$c0 <- 1
    expect_error(
      plndml(p, "district", "month", "y", "d", "c0"),
      "no covariate varies"
    )
  }
)

test_that(
  paste0(
    "baltab() is Welch's test, and the standardised difference uses the ",
    "treated SD"
  ),
  {
    d <- data.frame(t = rep(0:1, each = 30), x = c(1:30, (1:30) * 1.5 + 3))
    b <- baltab(d, "t", "x")
    tt <- stats::t.test(d$x[d$t == 1], d$x[d$t == 0])
    expect_equal(b$p_value, tt$p.value, tolerance = 1e-10)
    expect_identical(
      b$smd,
      (mean(d$x[d$t == 1]) - mean(d$x[d$t == 0])) / stats::sd(d$x[d$t == 1])
    )
    d$w <- 1
    expect_equal(
      baltab(d, "t", "x", w = "w")$p_value,
      tt$p.value,
      tolerance = 1e-10
    )
    expect_error(baltab(transform(d, t = 2), "t", "x"), "0 and 1")
  }
)

test_that(
  paste0(
    "mtchdid(): Mahalanobis matches with the pooled covariance, weights, ",
    "and the weighted DiD"
  ),
  {
    p <- .pc()
    m <- mtchdid(p, "district", "month", "crmrate", "refmonth", ratio = 2)
    u <- unique(p$district)
    y <- t(vapply(
      u,
      function(k) p$crmrate[p$district == k & p$month < 13],
      numeric(sum(p$district == u[1L] & p$month < 13))
    ))
    tr <- !is.na(p$refmonth[match(u, p$district)])
    s <- ((sum(tr) - 1) *
      stats::cov(y[tr, ]) +
      (sum(!tr) - 1) * stats::cov(y[!tr, ])) /
      (length(u) - 2)
    dd <- sqrt(stats::mahalanobis(y[!tr, ], y[which(tr)[1], ], s))
    first <- m$matches[m$matches$treated == u[which(tr)[1]], ]
    expect_identical(first$control, u[!tr][order(dd)[1:2]])
    expect_equal(
      sum(m$weights$weight[!tr]),
      sum(tr),
      tolerance = testthat::testthat_tolerance()
    )
    expect_true(all(m$weights$weight[tr] == 1))
    expect_identical(nrow(m$balance), 12L)
    p$half <- ifelse(
      as.integer(sub("D", "", p$district, fixed = TRUE)) %% 2 == 0,
      "even",
      "odd"
    )
    me <- mtchdid(p, "district", "month", "crmrate", "refmonth", exact = "half")
    expect_identical(
      p$half[match(me$matches$treated, p$district)],
      p$half[match(me$matches$control, p$district)]
    )
    mf <- mtchdid(p, "district", "month", "crmrate", "refmonth", covm = "full")
    df <- sqrt(stats::mahalanobis(y[!tr, ], y[which(tr)[1], ], stats::cov(y)))
    expect_identical(
      mf$matches$control[mf$matches$treated == u[which(tr)[1]]],
      u[!tr][which.min(df)]
    )
    expect_output(print(m), "Largest")
    expect_error(
      mtchdid(
        p[!is.na(p$refmonth), ],
        "district",
        "month",
        "crmrate",
        "refmonth"
      ),
      "never-treated"
    )
  }
)

test_that("syndid(): simplex weights and the estimate from them", {
  p <- .pc()
  p1 <- p[is.na(p$refmonth) | p$refmonth == 13, ]
  s <- syndid(
    p1,
    "district",
    "month",
    "crmrate",
    "refmonth",
    reps = 20,
    seed = 1
  )
  expect_equal(sum(s$unitwts), 1, tolerance = testthat::testthat_tolerance())
  expect_identical(sum(s$tmwts), 1)
  expect_true(all(s$unitwts >= 0))
  expect_true(all(s$tmwts >= 0))
  y <- t(vapply(
    unique(p1$district),
    function(k) p1$crmrate[p1$district == k],
    numeric(sum(p1$district == p1$district[1L]))
  ))
  rownames(y) <- unique(p1$district)
  tr <- rownames(y) %in% unique(p1$district[!is.na(p1$refmonth)])
  pre <- 1:12
  y1 <- y[tr, , drop = FALSE]
  y0 <- y[!tr, , drop = FALSE]
  ref <- (mean(y1[, -pre]) - sum(s$tmwts * colMeans(y1[, pre]))) -
    sum(s$unitwts * (rowMeans(y0[, -pre]) - y0[, pre] %*% s$tmwts))
  expect_identical(s$estimate, ref)
  expect_identical(s$method, "jackknife")
  expect_gt(s$se, 0)
  one <- p1[is.na(p1$refmonth) | p1$district == "D01", ]
  s1 <- syndid(
    one,
    "district",
    "month",
    "crmrate",
    "refmonth",
    reps = 20,
    seed = 1
  )
  expect_identical(s1$method, "placebo")
  expect_output(print(s1), "Unit weights")
  expect_identical(nrow(plot(s1)), 36L)
  expect_error(
    syndid(p, "district", "month", "crmrate", "refmonth"),
    "one adoption date"
  )
})

test_that(
  paste0(
    "wcb(): full enumeration, ties counted, ",
    "and an honest unbounded interval"
  ),
  {
    p <- .pc()
    w <- wcb(
      p,
      "district",
      "month",
      "crmrate",
      "reformed",
      cl = "region",
      reps = 999
    )
    expect_true(w$enumerated)
    expect_identical(w$draws, 16L)
    expect_identical(w$p_value * 16, round(w$p_value * 16))
    expect_gte(w$p_value, 2 / 16)
    expect_identical(c(w$lower, w$upper), c(-Inf, Inf))
    ws <- wcb(
      p,
      "district",
      "month",
      "crmrate",
      "reformed",
      cl = "region",
      ties = "strict"
    )
    expect_identical(ws$p_value, w$p_value - 2 / 16)
    expect_true(is.finite(ws$lower) || ws$p_value > 0.05)
    w2 <- wcb(
      p,
      "district",
      "month",
      "crmrate",
      "reformed",
      reps = 199,
      seed = 1,
      wtype = "webb"
    )
    expect_false(w2$enumerated)
    expect_lt(w2$p_value, 0.05)
    expect_lt(w2$lower, w2$estimate)
    expect_lt(w2$estimate, w2$upper)
    expect_lt(w2$upper, 0)
    expect_equal(
      w2$estimate,
      plndid(p, "district", "month", "crmrate", "reformed")$estimate,
      tolerance = testthat::testthat_tolerance()
    )
  }
)

test_that("tse(): the relative-magnitudes bounds by hand", {
  p <- .pc()
  es <- evstudy(
    p,
    "district",
    "month",
    "crmrate",
    "refmonth",
    leads = 3,
    lags = 4
  )
  s <- tse(es, mbar = c(0, 1), draws = 500, seed = 1)
  b <- es$estimate
  names(b) <- es$evtm
  post <- as.character(0:4)
  dmax <- max(abs(diff(b[c("-3", "-2", "-1")])))
  expect_identical(s$lowerbnd[1], mean(b[post]))
  expect_equal(
    s$upbound[2] - s$lowerbnd[2],
    2 * dmax * mean(0:4 + 1),
    tolerance = testthat::testthat_tolerance()
  )
  expect_true(all(s$lower <= s$lowerbnd & s$upper >= s$upbound))
  s0 <- tse(es, mbar = 1, target = 0, draws = 200, seed = 1)
  expect_equal(
    s0$upbound - s0$lowerbnd,
    2 * dmax,
    tolerance = testthat::testthat_tolerance()
  )
  expect_output(print(s), "Breakdown")
  expect_error(tse(es, target = 9), "post-period event time")
  expect_error(tse(data.frame()), "evstudy")
})

test_that(
  paste0(
    "plnpwr(): size near alpha, power ",
    "rising with the effect, and the MDE"
  ),
  {
    p <- .pc()
    pre <- p[p$month <= 12, ]
    pw <- plnpwr(
      pre,
      "district",
      "month",
      "crmrate",
      ntrt = 10,
      adopt = 7:10,
      eff = c(0, 1, 3),
      reps = 20,
      seed = 2
    )
    expect_lte(attr(pw, "size"), 0.25)
    expect_true(all(diff(pw$power) >= -0.1))
    expect_true(is.finite(attr(pw, "mde")))
    expect_lte(attr(pw, "mde"), 3)
    expect_output(print(pw), "Minimum detectable")
    expect_identical(nrow(plot(pw)), 3L)
    expect_error(
      plnpwr(pre, "district", "month", "crmrate", ntrt = 10, adopt = 1),
      "before it"
    )
  }
)

test_that(
  paste0(
    "aipwcf(): the doubly robust score by ",
    "hand, for the ATE and the ATT"
  ),
  {
    n <- 600
    d <- data.frame(age = .rmbl_with_seed(1, stats::runif(n, 18, 70)))
    d$t <- .rmbl_with_seed(
      2,
      stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age))
    )
    d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
    r <- aipwcf(d, "y", "t", "age", lrn = "ols", seed = 4)
    f <- .rmbl_with_seed(4L, sample(rep_len(1:5, n)))
    m1 <- m0 <- e <- numeric(n)
    x <- cbind(1, d$age)
    for (k in 1:5) {
      tr <- f != k
      m1[!tr] <- x[!tr, ] %*%
        stats::lm.fit(x[tr & d$t == 1, ], d$y[tr & d$t == 1])$coefficients
      m0[!tr] <- x[!tr, ] %*%
        stats::lm.fit(x[tr & d$t == 0, ], d$y[tr & d$t == 0])$coefficients
      e[!tr] <- stats::plogis(
        x[!tr, ] %*%
          stats::glm.fit(
            x[tr, ],
            d$t[tr],
            family = stats::binomial()
          )$coefficients
      )
    }
    e <- pmin(pmax(e, 0.01), 0.99)
    a <- m1 - m0 + d$t * (d$y - m1) / e - (1 - d$t) * (d$y - m0) / (1 - e)
    expect_equal(r$estimate, mean(a), tolerance = 1e-10)
    expect_equal(r$se, sqrt(sum((a - mean(a))^2) / n^2), tolerance = 1e-10)
    expect_lt(abs(r$estimate - 3), 4 * r$se)
    rt <- aipwcf(d, "y", "t", "age", estd = "ATT", lrn = "ols", seed = 4)
    p1 <- mean(d$t)
    at <- (d$t * (d$y - m0) - e * (1 - d$t) * (d$y - m0) / (1 - e)) / p1
    expect_equal(rt$estimate, mean(at), tolerance = 1e-10)
    d$w <- 1
    expect_identical(
      aipwcf(d, "y", "t", "age", lrn = "ols", seed = 4, w = "w")$estimate,
      r$estimate
    )
    expect_output(print(r), "Propensity range")
    expect_error(aipwcf(transform(d, t = 2), "y", "t", "age"), "0 and 1")
  }
)

test_that("plots of balance and of a cross-fitted AIPW result", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  n <- 400
  d <- data.frame(
    age = .rmbl_with_seed(1, stats::runif(n, 18, 70)),
    inc = .rmbl_with_seed(7, stats::rnorm(n))
  )
  d$t <- .rmbl_with_seed(
    2,
    stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age))
  )
  d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
  b <- baltab(d, "t", c("age", "inc"))
  pb <- plot(b)
  expect_identical(pb$covariate, b$covariate[order(abs(b$smd))])
  expect_identical(pb$before, sort(abs(b$smd)))
  d$w <- ifelse(d$t == 1, 1, 2)
  b2 <- baltab(d, "t", c("age", "inc"), w = "w")
  pa <- plot(b, after = b2)
  expect_identical(pa$after, abs(b2$smd[match(pa$covariate, b2$covariate)]))
  expect_error(plot(b, after = baltab(d, "t", "age")), "same covariates")
  r <- aipwcf(d, "y", "t", "age", lrn = "ols", seed = 4)
  pr <- attr(r, "propensity")
  expect_identical(nrow(pr), as.integer(n))
  expect_identical(range(pr$propensity), attr(r, "psrange"))
  ov <- plot(r)
  expect_identical(unique(ov$arm), c("treated", "untreated"))
  expect_equal(
    sum(ov$density[ov$arm == "treated"]) * diff(ov$propensity[1:2]),
    1,
    tolerance = 0.05
  )
  expect_identical(plot(r, type = "estimate")$estimate, r$estimate)
  attr(r, "propensity") <- NULL
  expect_error(plot(r), "no propensities")
})

test_that(
  paste0(
    "aipwcf(design =): one fit gives the replicate standard error of a ",
    "refit per replicate"
  ),
  {
    n <- 400
    d <- data.frame(age = .rmbl_with_seed(1, stats::runif(n, 18, 70)))
    d$t <- .rmbl_with_seed(
      2,
      stats::rbinom(n, 1, stats::plogis(-2 + 0.04 * d$age))
    )
    d$y <- 10 + 3 * d$t + 0.2 * d$age + .rmbl_with_seed(3, stats::rnorm(n))
    d$w <- .rmbl_with_seed(5, stats::runif(n, 0.5, 2))
    d$age[c(7, 90)] <- NA # rows outside the domain, kept in the design
    reps <- paste0("bsw", 1:20)
    m <- .rmbl_with_seed(6, matrix(stats::rpois(n * 20, 1), n))
    for (b in 1:20) {
      d[[reps[b]]] <- d$w * m[, b]
    }
    des <- svydes(d, w = "w", reps = reps)
    for (est in c("ATE", "ATT")) {
      r <- aipwcf(
        d,
        "y",
        "t",
        "age",
        estd = est,
        lrn = "ols",
        seed = 4,
        des = des
      )
      full <- aipwcf(
        d,
        "y",
        "t",
        "age",
        estd = est,
        lrn = "ols",
        seed = 4,
        w = "w"
      )
      th <- vapply(
        reps,
        function(b) {
          aipwcf(
            d,
            "y",
            "t",
            "age",
            estd = est,
            lrn = "ols",
            seed = 4,
            w = b
          )$estimate
        },
        numeric(1)
      )
      expect_equal(r$estimate, full$estimate, tolerance = 1e-12)
      expect_equal(r$se, sqrt(mean((th - full$estimate)^2)), tolerance = 1e-10)
      q <- stats::qt(0.975, 19)
      expect_equal(
        c(r$lower, r$upper),
        r$estimate + c(-1, 1) * q * r$se,
        tolerance = 1e-12
      )
      expect_identical(attr(r, "variance"), "bootstrap")
      expect_output(print(r), "survey design \\(bootstrap\\), one fit")
    }
    expect_identical(attr(full, "variance"), "influence")
    tl <- svydes(
      d,
      w = "w",
      strata = rep(1:4, each = n / 4),
      psu = rep(1:40, each = n / 40)
    )
    rl <- aipwcf(d, "y", "t", "age", lrn = "ols", seed = 4, des = tl)
    expect_equal(
      rl$estimate,
      aipwcf(d, "y", "t", "age", lrn = "ols", seed = 4, w = "w")$estimate,
      tolerance = 1e-12
    )
    expect_true(is.finite(rl$se))
    expect_gt(rl$se, 0)
    expect_error(aipwcf(d, "y", "t", "age", w = "w", des = des), "not both")
    expect_error(aipwcf(d, "y", "t", "age", des = list()), "svydes")
    expect_error(aipwcf(d[-1, ], "y", "t", "age", des = des), "built on")
  }
)

test_that("plnpwr() and plndml() refuse a missing outcome and an empty panel", {
  p <- .dml_data()
  na <- p
  na$y <- NA_real_
  # an all-NA outcome returned a power of 0 at every effect
  expect_error(
    plnpwr(na, "district", "month", "y", ntrt = 2, adopt = 3),
    "^plnpwr: `y` must have no NA"
  )
  expect_error(
    plndml(p[0, ], "district", "month", "y", "d", c("u1", "u2"), lrn = "ols"),
    "^plndml: `data` has no rows"
  )
})

# ---- boxed printouts ---------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("wcb() refuses a covariate the unit fixed effects absorb", {
  expect_error(
    wcb(polex(), "district", "month", "crmrate", "reformed",
      covs = "logpop", cl = "region", reps = 9),
    "`covs` logpop does not vary within `unit`.*drop it"
  )
  p <- polex()
  p$c2 <- p$population * 2
  expect_error(
    wcb(p, "district", "month", "crmrate", "reformed",
      covs = c("logpop", "c2", "arrrate"), cl = "region", reps = 9),
    "logpop, c2 do not vary"
  )
  # a covariate that varies within units is kept
  expect_s3_class(
    wcb(p, "district", "month", "crmrate", "reformed", covs = "arrrate",
      cl = "region", reps = 9, seed = 1),
    "rmbl_wild"
  )
})

test_that("the panel-causal results print as boxes", {
  p <- polex()
  dm <- plndml(p, "district", "month", "crmrate", "reformed",
    covs = c("logpop", "arrrate"), folds = 2)
  .o2_check(dm, "Double machine learning with fixed effects",
    c("Cross-fitting", "Out-of-fold R-squared", "treatment"))
  p$g <- as.numeric(!is.na(p$refmonth))
  .o2_check(baltab(p, "g", c("logpop", "arrrate")), "Covariate balance",
    c("mean_treated", "Above 0.1"))
  md <- mtchdid(p, "district", "month", "crmrate", "refmonth")
  .o2_check(md, "Matched difference in differences",
    c("Comparison units used", "smd_after"))
  w <- wcb(p, "district", "month", "crmrate", "reformed", cl = "region",
    reps = 99, seed = 1)
  .o2_check(w, "Wild cluster bootstrap", c("every sign pattern", "whole line"))
  es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3,
    lags = 4)
  .o2_check(tse(es, draws = 200, seed = 1), "Sensitivity to parallel trends",
    c("Breakdown", "identified_set", "robust_interval"))
  pw <- plnpwr(p, "district", "month", "crmrate", ntrt = 5, adopt = 20,
    reps = 10, seed = 1)
  .o2_check(pw, "Power of the design", "Minimum detectable effect")
  set.seed(2)
  a <- data.frame(x1 = stats::rnorm(200), x2 = stats::rnorm(200))
  a$d <- stats::rbinom(200, 1, stats::plogis(a$x1))
  a$y <- a$x1 + 2 * a$d + stats::rnorm(200)
  .o2_check(aipwcf(a, "y", "d", c("x1", "x2")), "Cross-fitted AIPW",
    c("Propensity range", "influence function", "The ATE is"))
})

test_that("synthetic difference in differences prints as a box", {
  p <- polex()
  p <- p[p$region %in% c("R1", "R4"), ]
  sd <- syndid(p, "district", "month", "crmrate", "refmonth", reps = 20,
    seed = 1)
  .o2_check(sd, "Synthetic difference in differences",
    c("Standard error", "Unit weights"))
})

# the help pages' own panel: eight towns, 2015 to 2024, four adopting
.own_panel <- function() {
  own <- data.frame(
    town = rep(c("A", "B", "C", "D", "E", "F", "G", "H"), each = 10),
    year = rep(2015:2024, times = 8),
    stringsAsFactors = FALSE
  )
  i <- match(own$town, unique(own$town))
  own$first <- c(2019, 2019, 2021, 2021, NA, NA, NA, NA)[i]
  own$bylaw <- as.integer(!is.na(own$first) & own$year >= own$first)
  own$pop <- c(12, 30, 8, 22, 15, 40, 9, 18)[i] * 1000
  own$county <- rep(c("North", "South"), 4)[i]
  own$income <- 50 + own$year - 2015 + cos(seq_len(80))
  own$rate <- 30 + i + 0.5 * (own$year - 2015) - 4 * own$bylaw +
    0.2 * own$income + sin(seq_len(80))
  own
}

test_that("tse() takes a confidence level", {
  own <- .own_panel()
  es <- evstudy(own, "town", "year", "rate", "first", leads = 3, lags = 3)
  a <- tse(es, seed = 1)
  b <- tse(es, seed = 1, conflvl = 0.95)
  expect_equal(b, a, tolerance = 1e-12)
  expect_identical(attr(a, "conflvl"), 0.95)
  n <- tse(es, seed = 1, conflvl = 0.8)
  expect_equal(n$lowerbnd, a$lowerbnd, tolerance = 1e-12)
  expect_true(all(n$lower >= a$lower & n$upper <= a$upper))
  expect_gte(attr(n, "breakdown"), attr(a, "breakdown"))
  expect_true(any(grepl("80%", format(n), fixed = TRUE)))
  expect_error(tse(es, conflvl = 2), "tse: ")
  expect_error(tse(1), "tse: `x` must come from evstudy")
})

test_that("mtchdid() clusters its standard errors as asked", {
  own <- .own_panel()
  a <- mtchdid(own, "town", "year", "rate", "first")
  expect_identical(mtchdid(own, "town", "year", "rate", "first", cl = NULL),
                   a)
  b <- mtchdid(own, "town", "year", "rate", "first", cl = "county")
  expect_equal(b$estimate$estimate, a$estimate$estimate, tolerance = 1e-12)
  expect_equal(attr(b$estimate, "clusters"), 2, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(b$estimate$se, a$estimate$se)))
})

test_that("the help pages' own panel runs through the panel estimators", {
  own <- .own_panel()
  expect_s3_class(
    plndml(own, "town", "year", "rate", "bylaw", "income", lrn = "ridge"),
    "rmbl_dml"
  )
  own1 <- own[is.na(own$first) | own$first == 2019, ]
  expect_s3_class(
    syndid(own1, "town", "year", "rate", "first", reps = 20, seed = 1),
    "rmbl_synthdid"
  )
  expect_s3_class(wcb(own, "town", "year", "rate", "bylaw", covs = "income"),
                  "rmbl_wild")
  expect_s3_class(
    plnpwr(own[own$year <= 2018, ], "town", "year", "rate", ntrt = 4,
           adopt = 2017:2018, eff = c(0, 2), reps = 10, seed = 1),
    "rmbl_power"
  )
})

# ---- result-driven reading of the sensitivity --------------------------------

test_that("tse()'s reading follows the breakdown value", {
  x <- data.frame(mbar = 0, lowerbnd = -3, upbound = -3, lower = -4,
    upper = -2)
  expect_match(.rmbl_tse_reading(x, 0), "Even with exactly parallel trends",
    fixed = TRUE)
  expect_match(.rmbl_tse_reading(x, Inf), "for every Mbar up to 10",
    fixed = TRUE)
  low <- .rmbl_tse_reading(x, 0.62)
  expect_match(low[1L], "negative effect stays clear of zero", fixed = TRUE)
  expect_match(low[2L], "leans on parallel trends", fixed = TRUE)
  expect_match(.rmbl_tse_reading(x, 1.5)[2L], "It survives a departure",
    fixed = TRUE)
})

test_that("a subset of a panel-causal result prints as a plain table", {
  expect_df_fallback("rmbl_dml", "Double machine learning with fixed effects")
  expect_df_fallback("rmbl_balance", "Covariate balance")
  expect_df_fallback("rmbl_wild", "Wild cluster bootstrap")
  expect_df_fallback("rmbl_sensitivity", "Sensitivity to parallel trends")
  expect_df_fallback("rmbl_power", "Power of the design")
  expect_df_fallback("rmbl_aipw", "Cross-fitted AIPW")
})

test_that("a drawn wild bootstrap says so; the small helpers handle none", {
  w <- wcb(.pc(), "district", "month", "crmrate", "reformed", reps = 19,
    seed = 1, wtype = "webb")
  expect_false(w$enumerated)
  expect_box2(w, "Wild cluster bootstrap", "random draws")
  expect_null(.rmbl_dml_split(NULL, 2L))
  expect_identical(.rmbl_dml_split(5L, 1L), "5 folds of units, 1 split")
  expect_null(.rmbl_max_abs(c(NA, Inf)))
  expect_identical(.rmbl_max_abs(c(-3, 2, NA)), 3)
})
