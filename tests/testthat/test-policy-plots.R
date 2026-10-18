# The policy-evaluation figures: each draws and returns what it drew

.pp <- function() polex()

test_that("event studies draw in both styles, alone and in a grid", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  es <- evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3, lags = 4)
  expect_identical(nrow(plot(es, style = "stata", shadepost = TRUE, refline = 0)), nrow(es))
  s <- stgatt(p, "district", "month", "crmrate", "refmonth", reps = 0)
  expect_identical(nrow(plot(s, style = "stata")), nrow(s$dynamic))
  g <- plotevgrid(list(Crime = es, Staggered = s), main = "Two outcomes")
  expect_identical(unique(g$panel), c("Crime", "Staggered"))
  expect_error(plotevgrid(list(es)), "named list")
  expect_error(plot(es, style = "zz"), "style")
})

test_that("the Bacon scatter, the permutation distributions and leave-one-out draw", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  b <- bacondcmp(p, "district", "month", "crmrate", "reformed")
  expect_identical(nrow(plot(b)), nrow(b))
  r <- perminf(p, "district", "month", c("crmrate", "arrrate"), "refmonth",
                             cl = "region")
  expect_identical(nrow(plot(r)), 2L)
  expect_identical(nrow(plot(r, type = "histogram")), 2L)
  l <- loounit(p, "district", "month", "crmrate", "reformed", units = c("D01", "D02", "D03"))
  expect_identical(l$dropped, c("D01", "D02", "D03"))
  q <- p[p$district != "D02", ]
  expect_equal(l$estimate[2], plndid(q, "district", "month", "crmrate", "reformed")$estimate)
  expect_identical(nrow(plot(l)), 3L)
  expect_error(loounit(p, "district", "month", "crmrate", "reformed", units = "D99"), "units of")
})

test_that("cohtrnd(): moving average, scaled to 1 before adoption", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  ct <- cohtrnd(p, "district", "month", "crmrate", "refmonth", win = c(-6, 6), ma = 3)
  expect_true(all(ct$value[ct$evtm == -1] == 1))
  m <- tapply(p$crmrate[p$refmonth %in% 13], p$month[p$refmonth %in% 13], mean)
  ma <- stats::filter(m, rep(1 / 3, 3), sides = 1)
  expect_equal(ct$value[ct$cohort == 13 & ct$evtm == 2], as.numeric(ma[15] / ma[12]))
  raw <- cohtrnd(p, "district", "month", "crmrate", "refmonth", ma = 1, norm = FALSE)
  expect_equal(raw$value[raw$cohort == 19 & raw$evtm == 0], mean(p$crmrate[p$refmonth %in% 19 &
                                                                                       p$month == 19]))
  expect_identical(nrow(plot(ct)), nrow(ct))
  expect_error(cohtrnd(p, "district", "month", "crmrate", "refmonth", win = c(0, 3)), "`win`")
})
