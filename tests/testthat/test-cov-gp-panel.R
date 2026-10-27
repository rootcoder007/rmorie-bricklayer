# SPDX-License-Identifier: AGPL-3.0-or-later
# Panel, policy-evaluation and survey branches no other test reached (most of
# the panel tests skip on CRAN, where goodpractice measures).

test_that("bacondcmp() decomposes the staggered example panel", {
  b <- bacondcmp(polex(), "district", "month", "crmrate", "reformed")
  expect_s3_class(b, "rmbl_bacon")
  expect_equal(sum(b$weight), 1, tolerance = testthat::testthat_tolerance())
  expect_setequal(
    unique(b$type),
    c("earlier vs later", "later vs earlier", "treated vs never")
  )
  expect_equal(
    attr(b, "twfe"), sum(b$weight * b$estimate),
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(.rmbl_bacon_dbar(Inf, 10L), 0)
  expect_identical(.rmbl_bacon_dbar(9, 10L), 0.2)
})

test_that("stgatt() and swtdid() take the clusters from a column", {
  p <- polex()
  s <- stgatt(
    p,
    "district",
    "month",
    "crmrate",
    "refmonth",
    cl = "region",
    reps = 9,
    seed = 1
  )
  expect_true(is.finite(s$overall$estimate))
  expect_lt(s$overall$estimate, 0)
  sw <- swtdid(
    p,
    "district",
    "month",
    "crmrate",
    "reformed",
    cl = "region",
    reps = 9,
    seed = 1
  )
  expect_identical(sw$term, c("effect", "placebo"))
  expect_true(all(is.finite(sw$se)))
})

test_that("wcb() with a covariate and Rademacher draws, not enumerated", {
  w <- wcb(
    polex(),
    "district",
    "month",
    "crmrate",
    "reformed",
    covs = "arrrate",
    cl = "region",
    reps = 9,
    seed = 1
  )
  expect_false(w$enumerated)
  expect_identical(w$draws, 9L)
  expect_identical(w$clusters, 4L)
  expect_gt(w$p_value, 0)
  expect_lte(w$p_value, 1)
  vm <- .rmbl_wcb_vmat(FALSE, "rademacher", 5, 3, 1)
  expect_identical(dim(vm), c(5L, 3L))
  expect_true(all(vm %in% c(-1, 1)))
})

test_that("plnpwr() with no effect large enough has no MDE", {
  pre <- polex()
  pre <- pre[pre$month <= 12, ]
  pw <- plnpwr(
    pre,
    "district",
    "month",
    "crmrate",
    ntrt = 10,
    adopt = 7:10,
    eff = 0,
    reps = 10,
    seed = 1
  )
  expect_true(is.na(attr(pw, "mde")))
  expect_output(
    print(pw),
    "Minimum detectable effect +beyond the effects tried"
  )
  expect_identical(.rmbl_pw_mde(c(1, 2), c(0.9, 1), 0.8), 1)
  expect_identical(.rmbl_pw_mde(c(1, 2), c(0.1, 0.2), 0.8), NA_real_)
})

test_that("tse() for one event time prints that event time", {
  es <- evstudy(
    polex(),
    "district",
    "month",
    "crmrate",
    "refmonth",
    leads = 3,
    lags = 4
  )
  ts <- tse(es, target = 2, draws = 200, seed = 1)
  expect_identical(attr(ts, "target"), 2)
  expect_output(print(ts), "Target +event-time 2")
})

test_that("aipwcf() with a design of no degrees of freedom uses the normal", {
  set.seed(2)
  n <- 200
  a <- data.frame(age = runif(n, 18, 70))
  a$belong <- rbinom(n, 1, plogis(-1 + 0.03 * a$age))
  a$wb <- 50 + 5 * a$belong + 0.2 * a$age + rnorm(n)
  a$w <- 1
  a$r1 <- runif(n, 0.5, 1.5)
  a$r2 <- a$r1 # two equal replicates: rank 1, no degrees of freedom
  dd <- svydes(a, w = "w", reps = c("r1", "r2"))
  expect_identical(.svy_df(dd), 0L)
  r <- aipwcf(a, "wb", "belong", "age", lrn = "ols", des = dd)
  expect_equal(
    r$lower, r$estimate - stats::qnorm(0.975) * r$se,
    tolerance = testthat::testthat_tolerance()
  )
  expect_equal(
    r$upper, r$estimate + stats::qnorm(0.975) * r$se,
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("more replicates than rows: the degrees of freedom from a list", {
  d <- data.frame(w = c(1, 2, 3), y = c(1, 0, 1))
  for (j in 1:5) {
    d[[paste0("r", j)]] <- d$w * c(1, 2, 0.5)[(0:2 + j) %% 3 + 1]
  }
  des <- svydes(d, w = "w", reps = paste0("r", 1:5))
  expect_type(des$reps, "list")
  expect_identical(des$degf, 2L)
  reps <- lapply(1:5, function(j) d[[paste0("r", j)]])
  expect_identical(
    .svy_reps_degf(reps, 5L, 3L),
    .svy_reps_degf(do.call(cbind, reps), 5L, 3L)
  )
})

test_that("a replicate design centred on the replicate mean says so", {
  d <- data.frame(w = c(1, 2, 3), y = c(1, 0, 1))
  for (j in 1:5) {
    d[[paste0("r", j)]] <- d$w * c(1, 2, 0.5)[(0:2 + j) %% 3 + 1]
  }
  des <- svydes(d, w = "w", reps = paste0("r", 1:5), mse = FALSE)
  expect_output(print(des), "Centring +on the replicate mean")
})

test_that("with infinite design df the edge and Wilson intervals use z", {
  expect_equal(
    .svy_ci_edge(0, 50, 0.95, Inf),
    .svy_ci_edge(0, 50, 0.95, 1e12),
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(.svy_ci_edge(0, 50, 0.95, Inf)$lower, 0)
  expect_equal(
    .svy_ci_wilson(0.3, 100, 0.05, 0.95, Inf),
    .svy_ci_wilson(0.3, 100, 0.05, 0.95, 1e12),
    tolerance = testthat::testthat_tolerance()
  )
  w <- .svy_ci_wilson(0.3, 100, 0.05, 0.95, Inf)
  expect_lt(w$lower, 0.3)
  expect_gt(w$upper, 0.3)
})
