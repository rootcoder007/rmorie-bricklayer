# First Nations, Metis and Inuit methods: each against an exact reference

test_that("sctidy() keeps the quality flags and never keeps a suppressed value", {
  d <- data.frame(GEO = "Canada", VALUE = c("45.8", "12", "", "3", "7"), STATUS = c("", "E", "x", "F", ".."))
  t <- sctidy(d)
  expect_s3_class(t, "rmbl_statcan")
  expect_identical(as.character(t$quality), c("ok", "E", "x", "F", ".."))
  expect_identical(t$VALUE, c(45.8, 12, NA, NA, NA))
  expect_error(sctidy(data.frame(a = 1)), "no VALUE column, nor census columns")
  expect_error(sctidy(1), "must be a data frame or a table key")
})

test_that("sctidy() makes a census table's wide layout long", {
  w <- data.frame(REF_DATE = 2021, GEO = "Canada", `Age (20)` = c("Total - Age", "0 to 14 years"),
                  Coordinate = c("1.1", "1.2"),
                  `Indigenous identity (9):First Nations (North American Indian)[4]` = c(1048405, 300000),
                  Symbol = c("", "x"), `Indigenous identity (9):Inuk (Inuit)[6]` = c(70540, 22000),
                  Symbol = c("E", ""), check.names = FALSE)
  t <- sctidy(w)
  expect_identical(t[["Indigenous identity (9)"]],
                   rep(c("First Nations (North American Indian)", "Inuk (Inuit)"), each = 2))
  expect_identical(t$VALUE, c(1048405, NA, 70540, 22000))
  expect_identical(as.character(t$quality), c("ok", "x", "E", "ok"))
  expect_identical(t[["Age (20)"]], rep(c("Total - Age", "0 to 14 years"), 2))
  e <- scests(t)
  expect_identical(nrow(e), 4L)
  expect_false("Coordinate" %in% names(e))
  # one label, two members: told apart by the member number in the coordinate
  du <- data.frame(REF_DATE = 2021, GEO = "Canada", DGUID = "2021A000011124",
                   `Household type (16)` = c("Without children", "Without children", "Total"),
                   Coordinate = c("1.3", "1.7", "1.1"), `Tenure (8):Owner[2]` = c(5, 6, 11), Symbol = "",
                   check.names = FALSE)
  tu <- sctidy(du)
  expect_identical(tu[["Household type (16)"]], c("Without children [3]", "Without children [7]", "Total"))
  expect_identical(nrow(scests(tu)), 3L)
  bad <- data.frame(`A (2):x[1]` = 1, `B (2):y[1]` = 2, check.names = FALSE)
  expect_error(sctidy(bad), "more than one dimension")
})

test_that("indgap() works the ratio and difference from the published intervals", {
  d <- data.frame(g = c("First Nations", "Metis", "Total Indigenous", "Inuit", "Non-Indigenous"),
                  est = c(45.8, 52.8, 49, 47.8, 61.5), lo = c(43.9, 50.6, 47.5, 43.1, 61),
                  hi = c(47.7, 55, 50.5, 52.5, 62), q = c("", "", "", "E", ""))
  r <- indgap(d, "g", "est", "lo", "hi", qual = "q")
  z <- stats::qnorm(0.975)
  se <- function(l, h) (h - l) / (2 * z)
  fn <- r[r$group == "First Nations", ]
  expect_equal(fn$difference, 45.8 - 61.5)
  expect_equal(fn$diflo, (45.8 - 61.5) - z * sqrt(se(43.9, 47.7)^2 + se(61, 62)^2))
  sl <- sqrt(((log(47.7) - log(43.9)) / (2 * z))^2 + ((log(62) - log(61)) / (2 * z))^2)
  expect_equal(fn$ratioup, exp(log(45.8 / 61.5) + z * sl))
  expect_true(r$usewithcau[r$group == "Inuit"])
  expect_identical(r$poogrp, c(FALSE, FALSE, TRUE, FALSE))
  d$q[2] <- "F"
  expect_true(is.na(indgap(d, "g", "est", "lo", "hi", qual = "q")$ratio[2]))
  expect_error(indgap(d, "g", "est", "lo", "hi", ref = "zz"), "exactly one row")
  d2 <- d
  d2$lo[1] <- 50
  expect_warning(r2 <- indgap(d2, "g", "est", "lo", "hi"), "does not contain the estimate for: First Nations")
  expect_true(is.na(r2$difference[1]))
  d4 <- d
  d4$lo[5] <- 62.5
  expect_error(indgap(d4, "g", "est", "lo", "hi"), "reference group's published interval")
  d3 <- d
  d3$q <- c("", "", "", "", "x")
  expect_error(indgap(d3, "g", "est", "lo", "hi", qual = "q"), "reference estimate is suppressed")
  expect_error(indgap(d, "zz", "est", "lo", "hi"), "column `zz` not found")
  expect_error(indgap(d, "g", "est", "lo", "hi", qual = "zz"), "column `zz` not found")
  expect_error(indgap(1, "g", "est", "lo", "hi"), "`data` must be a data frame")
})

test_that("agestd(): one age group gives the exact Poisson interval; weights apply", {
  r <- agestd(7, 10000, 1, per = 1)
  expect_equal(r$rate, 7 / 10000)
  expect_equal(r$lower, stats::qgamma(0.025, 7) / 10000, tolerance = 1e-12)
  expect_equal(r$upper, stats::qgamma(0.975, 8) / 10000, tolerance = 1e-12)
  z0 <- agestd(0, 5000, 1, per = 1)
  expect_identical(z0$lower, 0)
  expect_equal(z0$upper, stats::qgamma(0.975, 1) / 5000, tolerance = 1e-12)
  std <- c(3, 2, 1)
  r2 <- agestd(c(1, 4, 9), c(1000, 2000, 1500), std)
  expect_equal(r2$rate, sum(std / sum(std) * c(1, 4, 9) / c(1000, 2000, 1500)) * 1e5)
  expect_lt(r2$lower, r2$rate)
  expect_gt(r2$upper, r2$rate)
  expect_error(agestd(c(1, 2), c(10, 20), c(1, 1, 1)), "has 2 age groups")
  expect_error(agestd(c(1, -2), c(10, 20), c(1, 1)), "non-negative whole numbers")
  expect_error(agestd(c(1, 2), c(10, 0), c(1, 1)), "`pop` must be positive")
  expect_error(agestd(c(1, 2), c(10, 20), c(0, 0)), "not all zero")
  expect_error(agestd(c(1, 2), c(10, 20, 30), c(1, 1)), "same length")
  expect_error(agestd(c(1, 2), c(10, 20), c(1, 1), grp = "a"), "one label per row")
})

test_that("rategap(): ratio and difference of two standardised rates", {
  r <- agestd(c(5, 9, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1),
                       grp = c("Inuit", "Inuit", "Non-Indigenous", "Non-Indigenous"))
  g <- rategap(r, "Inuit", "Non-Indigenous")
  y1 <- r$rate[1] / 1e5
  y0 <- r$rate[2] / 1e5
  expect_equal(g$ratio, y1 / y0)
  v <- attr(r, "var")
  expect_equal(g$difup, (y1 - y0 + stats::qnorm(0.975) * sqrt(sum(v))) * 1e5)
  expect_error(rategap(data.frame(), "a", "b"), "must come from agestd")
  expect_error(rategap(r, "zz", "Inuit"), "is not a group")
  r0 <- agestd(c(0, 0, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1),
                        grp = c("a", "a", "b", "b"))
  expect_error(rategap(r0, "a", "b"), "both rates above zero")
})

test_that("genexpo() codes 0, 1, 2 and keeps what is not known unknown", {
  expect_identical(genexpo(c(TRUE, FALSE, TRUE, NA, FALSE, NA, TRUE),
                                       c(TRUE, FALSE, FALSE, TRUE, NA, NA, NA)),
                   c(2L, 0L, 1L, NA, NA, NA, NA))
  expect_identical(genexpo(c(TRUE, FALSE, TRUE, NA, FALSE, NA, TRUE),
                                       c(TRUE, FALSE, FALSE, TRUE, NA, NA, NA), partial = "lowerbnd"),
                   c(2L, 0L, 1L, 1L, NA, NA, 1L))
  expect_error(genexpo(1, TRUE), "`parent` must be TRUE, FALSE or NA")
  expect_error(genexpo(TRUE, c(TRUE, FALSE)), "same length")
})

test_that("exptrnd(): odds ratios by hand, the trend test as prop.trend.test gives it", {
  r <- exptrnd(c(60, 95, 70), c(500, 520, 300))
  expect_equal(r$orratio[3], (70 / 230) / (60 / 440))
  se <- sqrt(1 / 70 + 1 / 230 + 1 / 60 + 1 / 440)
  expect_equal(r$lower[3], exp(log((70 / 230) / (60 / 440)) - stats::qnorm(0.975) * se))
  expect_equal(attr(r, "trend")$p.value, stats::prop.trend.test(c(60, 95, 70), c(500, 520, 300), 0:2)$p.value)
  expect_no_warning(r0 <- exptrnd(c(0, 5), c(10, 10)))
  expect_equal(r0$orratio[2], (5.5 / 5.5) / (0.5 / 10.5))
  expect_error(exptrnd(c(1, 20), c(10, 10)), "0 <= cases <= n")
  expect_error(exptrnd(1, 10), "two levels at least")
  expect_error(exptrnd(c(1, 2), c(10, 10), dose = c(1, 0)), "strictly increasing")
})

test_that("trccmpl() and trcprog(): the counts the reports state, the exact rate interval", {
  tc <- trccmpl()
  expect_identical(tc$completed, c(8L, 0L, 3L, 2L))
  expect_identical(tail(tc$cumulative, 1), 13L)
  p <- trcprog()
  span <- 2023 - 2015.96
  expect_equal(p$rate, 13 / span)
  expect_equal(p$ratelo, stats::qgamma(0.025, 13) / span)
  expect_equal(p$rateup, stats::qgamma(0.975, 14) / span)
  expect_equal(p$cmplby, 2023 + 81 / (13 / span))
  expect_identical(trcprog(94, 2030)$cmplby, 2031)
  expect_identical(trcprog(0, 2020)$cmplbylate, Inf)
  expect_error(trcprog(c(5, 3), c(2020, 2021)), "cumulative counts")
  expect_error(trcprog(1, c(2020, 2021)), "one count per year")
  expect_error(trcprog(1, 2010), "after `start`")
})

test_that("indtabs() lists the mirrored tables, and searches them", {
  man <- list(datasets = list(
    list(key = "statcan_indigenous/tbl_13100924", rows = 413100,
         meta = list(description = "Health indicators ... perceived mental health",
                     license = "Statistics Canada Open Licence",
                     source = "https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1310092401")),
    list(key = "census2021_ipp/x2021003_pop", rows = 2, meta = list(description = "Indigenous Population Profile")),
    list(key = "hib/cpads", rows = 1, meta = list(description = "other"))))
  local_mocked_bindings(dmnf = function(refresh = FALSE) man)
  t <- indtabs()
  expect_identical(t$key, c("statcan_indigenous/tbl_13100924", "census2021_ipp/x2021003_pop"))
  expect_identical(nrow(indtabs("mental health")), 1L)
  expect_error(indtabs(1), "`pat` must be a single non-empty string")
})
