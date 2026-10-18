# Frameworks put to work: each against an exact reference

test_that("cwbscr(): the four components and their mean, as the methodology sets them", {
  r <- cwbscr(20000, 60, 9, 80, 70, 60, 90)
  expect_equal(r$income, 100 * (log(20000) - log(2650)) / (log(75000) - log(2650)))
  expect_equal(r$education, 2 / 3 * 60 + 1 / 3 * 9)
  expect_equal(r$housing, 75)
  expect_equal(r$labour, 75)
  expect_equal(r$cwb, mean(c(r$income, r$education, r$housing, r$labour)))
  expect_identical(cwbscr(c(1000, 1e6), 50, 5, 50, 50, 50, 50)$income, c(0, 100))
  expect_equal(cwbscr(20000, 60, 9, 80, 70, 60, 90, bounds = c(2000, 40000))$income,
               100 * (log(20000) - log(2000)) / (log(40000) - log(2000)))
  expect_identical(nrow(cwbscr(c(1e4, 2e4, 3e4), 50, 5, 50, 50, 50, 50)), 3L)
  expect_error(cwbscr(1e4, 150, 5, 50, 50, 50, 50), "from 0 to 100")
  expect_error(cwbscr(0, 50, 5, 50, 50, 50, 50), "must be positive")
  expect_error(cwbscr(1e4, c(1, 2), c(1, 2, 3), 50, 50, 50, 50), "one value per community")
  expect_error(cwbscr(1e4, 50, 5, 50, 50, 50, 50, bounds = c(5, 1)), "two increasing")
})

test_that("connassoc(): Spearman's rho, its exact p as cor.test gives it, and the error interval", {
  d <- data.frame(p = letters[1:6], x = c(10, 14, 12, 19, 25, 22), y = c(31, 30, 36, 40, 39, 47),
                  xl = c(8, 12, 10, 17, 23, 20), xh = c(12, 16, 14, 21, 27, 24),
                  yl = c(29, 28, 34, 38, 37, 45), yh = c(33, 32, 38, 42, 41, 49))
  r <- connassoc(d, "p", "x", "y", "xl", "xh", "yl", "yh", reps = 2000)
  ct <- suppressWarnings(stats::cor.test(d$x, d$y, method = "spearman", exact = TRUE))
  expect_equal(r$rho, unname(ct$estimate))
  expect_equal(r$p_value, ct$p.value, tolerance = 1e-8)
  expect_true(r$exact)
  expect_lt(r$rholo, r$rho)
  expect_gt(r$rhoup, r$rho)
  expect_identical(nrow(.rmbl_permutations(5L)), 120L)
  expect_identical(anyDuplicated(apply(.rmbl_permutations(5L), 1L, paste, collapse = "")), 0L)
  expect_output(print(r), "does not show that one causes the other")
  r2 <- connassoc(d, "p", "x", "y")
  expect_true(is.na(r2$rholo))
  expect_output(print(r2), "exact p")
  big <- data.frame(p = 1:12, x = 1:12, y = c(2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11))
  r3 <- connassoc(big, "p", "x", "y", reps = 2000)
  expect_false(r3$exact)
  expect_lt(r3$p_value, 0.01)
  expect_error(connassoc(d[1:2, ], "p", "x", "y"), "three places")
  expect_error(connassoc(d, "p", "x", "y", "xl"), "all four limit columns")
})

.hc <- function() {
  data.frame(g = rep(c("A", "B"), each = 4), ind = rep(c("well", "well", "ill", "ill"), 2),
             per = rep(c("t1", "t2"), 4), est = c(50, 55, 20, 18, 40, 41, 30, 35),
             lo = c(46, 51, 18, 16, 36, 37, 27, 32), hi = c(54, 59, 22, 20, 44, 45, 33, 38),
             q = c("", "", "", "", "", "F", "", "E"))
}

test_that("healchg(): the change between periods and its interval, wellness first", {
  z <- stats::qnorm(0.975)
  r <- healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", from = "t1", to = "t2", well = "well",
                      qual = "q")
  expect_identical(r$indicator, c("well", "well", "ill", "ill"))
  expect_identical(r$side, c("wellness", "wellness", "distress", "distress"))
  expect_equal(r$change[1], 5)
  expect_equal(r$upper[1], 5 + z * sqrt(2 * (8 / (2 * z))^2))
  expect_true(is.na(r$change[2]))
  expect_true(r$usewithcau[4])
  expect_true(all(is.na(healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t2")$side)))
  expect_error(healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t9"), "is not a period")
  expect_error(healchg(rbind(.hc(), .hc()), "g", "ind", "per", "est", "lo", "hi", "t1", "t2"), "appear twice")
  d <- .hc()
  d$ind[d$per == "t2"] <- paste0("other", seq_len(sum(d$per == "t2")))
  expect_error(healchg(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2"), "in both periods")
})

test_that("commidx(): the weighted sum over the sum of absolute weights, never filled", {
  z <- stats::qnorm(0.975)
  d <- data.frame(g = rep(c("A", "B"), each = 3), ind = rep(c("belong", "stress", "drink"), 2),
                  e = c(60, 20, 30, 70, 25, NA), lo = c(56, 18, 27, 66, 22, NA), hi = c(64, 22, 33, 74, 28, NA),
                  q = c("", "", "", "", "", ".."))
  w <- c(belong = 2, stress = -1, drink = -1)
  r <- commidx(d, "g", "ind", "e", "lo", "hi", w = w, qual = "q")
  expect_equal(r$index[1], (2 * 60 - 20 - 30) / 4)
  se <- c(4, 2, 3) / z
  expect_equal(r$upper[1], (2 * 60 - 20 - 30) / 4 + z * sqrt(sum(w^2 * se^2)) / 4)
  expect_true(is.na(r$index[2]))
  expect_identical(attr(r, "weights"), w)
  expect_error(commidx(d, "g", "ind", "e", "lo", "hi"), "set by the community")
  expect_error(commidx(d, "g", "ind", "e", "lo", "hi", w = c(zz = 1)), "not an indicator")
  expect_error(commidx(rbind(d, d[1, ]), "g", "ind", "e", "lo", "hi", w = w), "indicator twice")
})

test_that("mhcont(): proxies per direction, shared and missing ones said", {
  z <- stats::qnorm(0.975)
  d <- data.frame(g = "A", ind = c("hopeful", "belong", "mp", "family"), e = c(50, 60, 40, 70),
                  lo = c(46, 56, 36, 66), hi = c(54, 64, 44, 74))
  r <- mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hopeful", belong = c("belong", "family"),
                                 meaning = "mp", purp = "mp")
  expect_s3_class(r, "rmbl_wellness_profile")
  expect_identical(r$indicator, c("hope", "belonging", "meaning", "purpose"))
  expect_equal(r$estimate[2], 65)
  expect_equal(r$upper[2], 65 + z * sqrt(2 * (8 / (2 * z))^2) / 2)
  expect_identical(r$shared, c(FALSE, FALSE, TRUE, TRUE))
  r2 <- mhcont(d, "g", "ind", "e", "lo", "hi", hope = "hopeful")
  expect_identical(r2$domain[2:4], rep("no published proxy", 3))
  expect_true(all(is.na(r2$estimate[2:4])))
  expect_error(mhcont(d, "g", "ind", "e", "lo", "hi"), "one direction at least")
  expect_error(mhcont(d, "g", "ind", "e", "lo", "hi", hope = "zz"), "not an indicator")
  expect_error(mhcont(d, "g", "ind", "e", "lo", "hi", hope = 1), "must name indicators")
})

test_that("frmaud(): the share of the report that is deficit-framed", {
  d <- data.frame(g = rep(c("A", "B"), each = 3), ind = rep(c("w", "d1", "d2"), 2), e = 1:6, lo = 0:5, hi = 2:7)
  w <- welprof(d[-1, ], "g", "ind", "e", "lo", "hi", well = "w", distress = c("d1", "d2"))
  f <- frmaud(w)
  expect_equal(f$shrdef, 4 / 5)
  expect_identical(f$defonly, "A")
  expect_output(print(f), "Reported on deficits alone: A")
  expect_output(print(f), "pair each with a strength-framed level")
  expect_error(frmaud(data.frame()), "must come from welprof")
})

test_that("the framework results draw themselves", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- data.frame(p = letters[1:4], x = c(1, 3, 2, 4), y = c(2, 3, 1, 5), xl = 0:3, xh = 2:5, yl = c(1, 2, 0, 4),
                  yh = c(3, 4, 2, 6))
  expect_identical(nrow(plot(connassoc(d, "p", "x", "y", "xl", "xh", "yl", "yh", reps = 200))), 4L)
  expect_identical(nrow(plot(connassoc(d, "p", "x", "y"), xlab = "Land", ylab = "Wellness")), 4L)
  expect_error(plot(connassoc(d, "p", "x", "y"), xlab = 1), "`xlab` must be a single non-empty string")
  expect_identical(nrow(plot(healchg(.hc(), "g", "ind", "per", "est", "lo", "hi", "t1", "t2",
                                            well = "well", qual = "q"))), 4L)
  ci <- commidx(.hc()[.hc()$per == "t1", ], "g", "ind", "est", "lo", "hi", w = c(well = 1, ill = -1))
  expect_identical(nrow(plot(ci)), 2L)
  mw <- mhcont(data.frame(g = "A", ind = "h", e = 5, lo = 4, hi = 6), "g", "ind", "e", "lo", "hi",
                                  hope = "h")
  expect_identical(nrow(plot(mw)), 4L)
})
