# cpsplant(), cpsspec() and recevid(): evidence that an analysis is right

plant_data <- function(n = 200) {
  set.seed(11)
  d <- data.frame(x = stats::rbinom(n, 1, 0.5), z = stats::rnorm(n))
  d$y <- 2 * d$x + d$z + stats::rnorm(n)
  d
}
dm <- function(df) mean(df$y[df$x == 1]) - mean(df$y[df$x == 0])

test_that("a correct statistic recovers every planted effect", {
  d <- plant_data()
  p <- cpsplant(d, dm, y = "y", trt = "x", n = 40, seed = 3)
  expect_s3_class(p, "rmbl_plant")
  expect_true(p$ok)
  expect_identical(p$table$effect, c(0, 0.5, 1))
  expect_true(all(abs(p$table$bias) < 0.2))
  expect_equal(p$tol, 0.1)
  expect_gt(p$observed, 1.5)
  expect_box2(p, "Planted-effect recovery: passed",
              c("recovered every planted effect", "shuffles the outcome"))
  # reproducible from its seed; the session's stream is untouched
  set.seed(99)
  before <- stats::runif(1)
  set.seed(99)
  q <- cpsplant(d, dm, y = "y", trt = "x", n = 40, seed = 3)
  expect_identical(stats::runif(1), before)
  expect_identical(q$table, p$table)
})

test_that("a statistic with a bug, or one that invents an effect, fails", {
  d <- plant_data()
  doubled <- cpsplant(d, function(df) 2 * dm(df), y = "y", trt = "x",
                      n = 40, seed = 3)
  expect_false(doubled$ok)
  expect_identical(doubled$table$passed, c(TRUE, FALSE, FALSE))
  expect_box2(doubled, "Planted-effect recovery: FAILED",
              c("missed at least one planted effect", "FAIL"))
  # always finds an effect of 1: caught by the planted 0
  shifted <- cpsplant(d, function(df) dm(df) + 1, y = "y", trt = "x",
                      n = 40, seed = 3)
  expect_false(shifted$table$passed[1L])
})

test_that("logical, factor and two-level text treatments are coded 0/1", {
  d <- plant_data(120)
  d$lg <- d$x == 1
  d$fc <- factor(ifelse(d$x == 1, "drug", "placebo"),
                 levels = c("placebo", "drug"))
  d$ch <- ifelse(d$x == 1, "b", "a")
  for (v in c("lg", "fc", "ch")) {
    s <- function(df) {
      t <- .rmbl_plant_code(df[[v]], v)
      mean(df$y[t == 1]) - mean(df$y[t == 0])
    }
    expect_true(cpsplant(d, s, y = "y", trt = v, n = 20, seed = 1)$ok,
                info = v)
  }
  # a continuous treatment and a slope
  d$dose <- stats::runif(nrow(d), 0, 3)
  sl <- function(df) stats::coef(stats::lm(y ~ dose, df))[["dose"]]
  expect_true(cpsplant(d, sl, y = "y", trt = "dose", n = 20, seed = 1)$ok)
})

test_that("cpsplant refuses what it cannot check", {
  d <- plant_data(20)
  expect_error(cpsplant(d[1:3, ], dm, "y", "x"), "4 rows")
  expect_error(cpsplant(d, "dm", "y", "x"), "function")
  expect_error(cpsplant(d, dm, "nope", "x"), "not a column")
  expect_error(cpsplant(d, dm, "y", "nope"), "not a column")
  d$t3 <- rep(c("a", "b", "c"), length.out = nrow(d))
  expect_error(cpsplant(d, dm, "y", "t3"), "two levels")
  d$yc <- as.character(d$y)
  expect_error(cpsplant(d, dm, "yc", "x"), "numeric")
  d$lst <- I(as.list(seq_len(nrow(d))))
  expect_error(cpsplant(d, dm, "y", "lst"), "numeric, logical")
  expect_error(cpsplant(d, dm, "y", "x", effects = c(0, NA)), "finite")
  expect_error(cpsplant(d, dm, "y", "x", n = 2), "at least 5")
  expect_error(cpsplant(d, dm, "y", "x", tol = -1), "at least 0")
  expect_error(cpsplant(d, function(df) NA, "y", "x"), "finite number")
})

test_that("specifications that agree are robust; one that flips is not", {
  set.seed(2)
  d <- data.frame(x = stats::rnorm(300), z = stats::rnorm(300))
  d$y <- 0.5 * d$x + 0.3 * d$z + stats::rnorm(300)
  sp <- cpsspec(d, list(
    adjusted = function(df) stats::coef(stats::lm(y ~ x + z, df))[["x"]],
    simple = function(df) stats::coef(stats::lm(y ~ x, df))[["x"]]
  ))
  expect_true(sp$ok)
  expect_identical(sp$share, 1)
  expect_identical(sp$table$spec, c("adjusted", "simple"))
  expect_box2(sp, "Specification check: robust",
              c("2 of 2", "does not hang on one analytic choice"))
  flip <- cpsspec(d, list(main = function(df) 0.4,
                          other = function(df) -0.1,
                          third = function(df) 0.2))
  expect_false(flip$ok)
  expect_equal(flip$share, 2 / 3)
  expect_box2(flip, "Specification check: FRAGILE",
              c("DIFFERENT", "depends on the analytic choices"))
  expect_error(cpsspec(d, list(a = function(df) 1)), "two or more")
  expect_error(cpsspec(d, list(function(df) 1, function(df) 2)), "named")
  expect_error(cpsspec(d, list(a = 1, b = 2)), "functions")
  expect_error(cpsspec(d[0, ], list(a = mean, b = mean)), "rows")
})

test_that("recevid writes each kind of evidence into the manifest", {
  d <- plant_data()
  man <- mkmnf(list(project = "evidence test"), env = FALSE)
  man <- recevid(man, cpsplant(d, dm, "y", "x", n = 20, seed = 1))
  sp <- cpsspec(d, list(a = dm, b = function(df) dm(df) * 0.9))
  man <- recevid(man, sp)
  fs <- cpsfals(d, dm, trt = "x", n = 19, seed = 1)
  man <- recevid(man, fs, grp = "falsification")
  txt <- paste(capture.output(print(man)), collapse = " ")
  expect_match(txt, "planted effect 0.5 recovered", fixed = TRUE)
  expect_match(txt, "specifications agreeing in sign", fixed = TRUE)
  expect_match(txt, "falsification control", fixed = TRUE)
  expect_error(recevid(man, list()), "cpsplant")
})
