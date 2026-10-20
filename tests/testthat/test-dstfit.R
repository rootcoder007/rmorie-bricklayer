# dstfit(): maximum likelihood fits against closed forms and MASS::fitdistr, the ranking, the
# bootstrap, the Hill estimate, the plots and the synthetic sample.

test_that("the closed-form and optimised estimates are the maximum likelihood ones", {
  set.seed(11)
  x <- stats::rgamma(400, shape = 2, rate = 0.5)
  f <- dstfit(x, nboot = 0)
  expect_s3_class(f, "rmbl_dstfit")
  expect_equal(unname(f$fits$normal), c(mean(x), sqrt(mean((x - mean(x))^2))))
  expect_equal(unname(f$fits$exponential), 1 / mean(x))
  expect_equal(unname(f$fits$lognormal[1L]), mean(log(x)))
  expect_equal(unname(f$fits$pareto), c(min(x), length(x) / sum(log(x / min(x)))))
  skip_if_not_installed("MASS")
  expect_equal(unname(f$fits$gamma), unname(suppressWarnings(MASS::fitdistr(x, "gamma"))$estimate), tolerance = 1e-4)
  expect_equal(unname(f$fits$weibull), unname(suppressWarnings(MASS::fitdistr(x, "weibull"))$estimate),
               tolerance = 1e-4)
  # the gamma is the best fit to gamma data, and the table is ranked by AIC
  expect_true("gamma" %in% f$table$family[1:2])
  expect_false(is.unsorted(f$table$aic))
  expect_equal(f$table$bic - f$table$aic, (log(400) - 2) * f$table$npar)
  y <- stats::rnbinom(500, size = 2, mu = 5)
  g <- dstfit(y, fams = c("negbin", "poisson"), nboot = 0)
  expect_equal(unname(g$fits$negbin), unname(MASS::fitdistr(y, "negative binomial")$estimate), tolerance = 1e-4)
  expect_identical(g$table$family[1L], "negbin")
  expect_true(is.na(g$table$ad[1L]))
})

test_that("zero-inflated counts, proportions and the t are recovered", {
  set.seed(12)
  n <- ifelse(stats::runif(2000) < 0.3, 0, stats::rpois(2000, 4))
  f <- dstfit(n, fams = c("zip", "poisson", "zinb"), nboot = 0)
  expect_equal(unname(f$fits$zip), c(0.3, 4), tolerance = 0.06)
  expect_true(f$table$family[1L] %in% c("zip", "zinb"))
  b <- dstfit(stats::rbeta(2000, 2, 5), fams = "beta", nboot = 0)
  expect_equal(unname(b$fits$beta), c(2, 5), tolerance = 0.08)
  tt <- dstfit(3 + 2 * stats::rt(3000, 4), fams = "t", nboot = 0)
  expect_equal(unname(tt$fits$t), c(3, 2, 4), tolerance = 0.1)
  # the default families follow the data
  expect_setequal(dstfit(c(0, 1, 2, 2, 3, 5), nboot = 0)$table$family,
                  c("normal", "t", "poisson", "negbin", "zip", "zinb"))
  expect_true("beta" %in% dstfit(c(0.1, 0.2, 0.4, 0.5, 0.9), nboot = 0)$table$family)
})

test_that("the bootstrap is seeded for the call and covers the estimate", {
  set.seed(13)
  x <- stats::rexp(200, 3)
  before <- .Random.seed
  a <- dstfit(x, fams = "exponential", nboot = 99, seed = 4)
  expect_identical(.Random.seed, before)
  b <- dstfit(x, fams = "exponential", nboot = 99, seed = 4)
  expect_identical(a$boot, b$boot)
  expect_true(a$boot$lower < a$boot$estimate && a$boot$estimate < a$boot$upper)
  expect_true(is.na(dstfit(x, fams = "exponential", nboot = 0)$boot$lower))
  # a resample whose refit fails is left out of the interval
  calls <- 0L
  real <- asNamespace("rmoriebricklayer")$.dst_fit1
  local_mocked_bindings(.dst_fit1 = function(f, x) {
    calls <<- calls + 1L
    if (calls %% 2L == 0L) NULL else real(f, x)
  })
  expect_true(is.finite(dstfit(x, fams = "exponential", nboot = 20)$boot$lower))
})

test_that("the Hill estimate recovers a Pareto tail index", {
  set.seed(14)
  x <- stats::runif(5000)^(-1 / 1.5)
  h <- dstfit(x, fams = "pareto", nboot = 0, k = 500)$hill
  expect_equal(h$alpha, 1.5, tolerance = 0.1)
  expect_identical(h$k, 500L)
  expect_true(h$lower < h$alpha && h$alpha < h$upper)
  expect_null(dstfit(c(-1, 0, 1, 2, 3, 4, 5, 6, 7, 8), nboot = 0)$hill)
  expect_equal(unname(dstfit(x, fams = "pareto", nboot = 0)$fits$pareto[2L]), 1.5, tolerance = 0.06)
})

test_that("bad input is refused, and a failed fit is a row", {
  expect_error(dstfit("a"), "dstfit: `x` must be a numeric vector")
  expect_error(dstfit(c(1, Inf, 2, 3, 4)), "infinite")
  expect_error(dstfit(c(1, 2, NA)), "at least five")
  expect_error(dstfit(rep(2, 6)), "the same")
  expect_error(dstfit(c(-1, 2, 3, 4, 5), fams = "gamma"), "dstfit: `gamma` needs every value above 0")
  expect_error(dstfit(1:6, fams = "nope"))
  f <- dstfit(c(1:9, NA), nboot = 0)
  expect_identical(f$nmiss, 1L)
  local_mocked_bindings(.dst_fit1 = function(f, x) NULL)
  g <- dstfit(1:6, fams = "normal", nboot = 0)
  expect_false(g$table$converged)
  expect_length(g$fits, 0L)
  expect_error(plot(g, fams = "normal"), "no converged fit")
})

test_that("a fit whose likelihood is not finite does not count", {
  fam <- list(fit = function(x) c(m = 0), d = function(x, p) rep(-Inf, length(x)))
  expect_null(asNamespace("rmoriebricklayer")$.dst_fit1(fam, 1:5))
  fam$fit <- function(x) stop("no")
  expect_null(asNamespace("rmoriebricklayer")$.dst_fit1(fam, 1:5))
})

test_that("print and the four plots draw and return what they drew", {
  set.seed(15)
  f <- dstfit(stats::rlnorm(150), nboot = 10)
  g <- dstfit(stats::rpois(150, 3), nboot = 0)
  expect_output(print(f), "ranked by AIC")
  expect_output(print(f), "Hill tail index")
  expect_output(print(dstfit(c(-2, -1, 0, 1, 2, 3), nboot = 0)), "ranked by AIC")
  expect_output(print(dstfit(c(1:9, NA), nboot = 0)), "1 missing dropped")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (w in c("density", "qq", "pp", "tail")) {
    a <- plot(f, which = w)
    expect_s3_class(a, "data.frame")
    expect_true(all(c("family", "x", "y") %in% names(a)))
    expect_s3_class(plot(g, which = w), "data.frame")
  }
  expect_identical(unique(plot(f, which = "qq", fams = "lognormal")$family), "lognormal")
  expect_error(plot(dstfit(c(-3, -2, -1, 0, 1), nboot = 0), which = "tail"), "two values above 0")
  expect_error(plot(f, fams = "beta"), "no converged fit for beta")
})

test_that("mksyncol() draws a synthetic sample from a fit", {
  set.seed(16)
  f <- dstfit(stats::rexp(300, 2), nboot = 0)
  s <- mksyncol(list(type = "fitted", fit = f, family = "exponential"), 4000)
  expect_length(s, 4000L)
  expect_equal(mean(s), 1 / f$fits$exponential[[1L]], tolerance = 0.06)
  expect_length(mksyncol(list(type = "fitted", fit = f), 3), 3L)
  expect_error(mksyncol(list(type = "fitted", fit = 1), 3), "needs `fit`, a dstfit\\(\\) result")
  expect_error(mksyncol(list(type = "fitted", fit = f, family = "beta"), 3), "no converged beta")
  fams <- asNamespace("rmoriebricklayer")$.dst_fams()
  # every family's random, quantile and distribution functions agree
  pars <- list(normal = c(1, 2), lognormal = c(0, 0.5), exponential = 2, gamma = c(2, 1), weibull = c(1.5, 2),
               t = c(0, 1, 5), pareto = c(1, 2), beta = c(2, 3), poisson = 3, negbin = c(2, 4), zip = c(0.3, 3),
               zinb = c(0.3, 2, 4))
  for (nm in names(pars)) {
    r <- fams[[nm]]$r(4000, pars[[nm]])
    med <- fams[[nm]]$q(0.5, pars[[nm]])
    expect_equal(mean(r <= med), fams[[nm]]$p(med, pars[[nm]]), tolerance = 0.04, info = nm)
    expect_equal(exp(fams[[nm]]$d(med, pars[[nm]])) > 0, TRUE, info = nm)
  }
  expect_identical(fams$pareto$p(0.5, c(1, 2)), 0)
  expect_identical(fams$pareto$d(0.5, c(1, 2)), -Inf)
  expect_identical(fams$zip$p(-1, c(0.3, 3)), 0)
  expect_identical(fams$zinb$p(-1, c(0.3, 2, 4)), 0)
  expect_identical(fams$zip$q(0.1, c(0.3, 3)), 0)
})
