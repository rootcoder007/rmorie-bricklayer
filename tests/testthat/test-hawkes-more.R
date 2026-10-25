# chwksim() and plothwk(): simulation from a fitted Hawkes process and its three
# views.

test_that("a simulation from a fit has the fit's mean number of events", {
  fit <- list(
    kernel = "exponential",
    baseline = "constant",
    basepar = log(1),
    braratio = 0.5,
    kerpar = c(beta = 2),
    horizon = 400,
    theta = c(0, 0.5, 2)
  )
  before <- if (exists(".Random.seed", globalenv())) {
    get(".Random.seed", globalenv())
  }
  n <- vapply(1:30, function(s) length(chwksim(fit, seed = s)), 1)
  # stationary mean: baseline / (1 - branching ratio) per unit time, less the
  # edge at the horizon
  expect_equal(mean(n) / 400, 2, tolerance = 0.08)
  if (!is.null(before)) {
    expect_identical(get(".Random.seed", globalenv()), before)
  }
  s <- chwksim(fit, hor = 50, seed = 3)
  expect_false(is.unsorted(s))
  expect_true(all(s <= 50))
  expect_true(all(attr(s, "generation") >= 0L))
  expect_identical(chwksim(fit, seed = 9), chwksim(fit, seed = 9))
  for (k in list(
    list("weibull", c(alpha = 1.5, lambda = 0.5)),
    list("gamma", c(alpha = 2, beta = 4)),
    list("lomax", c(alpha = 3, c = 1))
  )) {
    fk <- fit
    fk$kernel <- k[[1L]]
    fk$kerpar <- k[[2L]]
    expect_true(length(chwksim(fk, hor = 100)) > 50)
  }
  fs <- fit
  fs$baseline <- "sinusoidal"
  fs$basepar <- c(0, 0.5, 0.3, -0.2)
  expect_true(length(chwksim(fs, hor = 365)) > 100)
  expect_error(
    chwksim(list(a = 1)),
    "chwksim: `fit` must be a chwkfit\\(\\) result"
  )
})

test_that("the intensity, QQ and tree views draw and return their data", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  set.seed(31)
  times <- sort(stats::runif(150, 0, 100))
  fit <- chwkfit(times, 100)
  i <- plothwk(fit, times, ngrid = 50)
  expect_identical(nrow(i), 50L)
  expect_true(all(i$lambda >= exp(fit$basepar[[1L]]) - 1e-12))
  q <- plothwk(fit, times, "qq")
  expect_equal(q$residual, sort(chwkres(times, 100, "exponential", fit$theta)))
  tr <- plothwk(fit, times, "tree")
  expect_identical(nrow(tr), 150L)
  expect_identical(tr$parent[1L], 0L)
  expect_true(all(tr$parent < seq_len(150)))
  expect_true(all(tr$generation[tr$parent == 0L] == 0L))
  fs <- chwkfit(times, 100, base = "sinusoidal")
  expect_s3_class(plothwk(fs, times, ngrid = 20), "data.frame")
  fk <- fit
  for (k in list(
    list("weibull", c(1.5, 2)),
    list("gamma", c(2, 1)),
    list("lomax", c(3, 2))
  )) {
    fk$kernel <- k[[1L]]
    fk$kerpar <- k[[2L]]
    expect_s3_class(plothwk(fk, times, ngrid = 20), "data.frame")
  }
  expect_error(plothwk(fit, c(1, NA)), "none missing")
  expect_error(
    plothwk(fit, seq(0, 100, length.out = 5001), "tree"),
    "at most 5,000"
  )
})
