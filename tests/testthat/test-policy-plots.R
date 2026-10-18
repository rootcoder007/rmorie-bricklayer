# The policy-evaluation figures: each draws and returns what it drew

.pp <- function() policy_example()

test_that("event studies draw in both styles, alone and in a grid", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  es <- event_study(p, "district", "month", "crime_rate", "reform_month", leads = 3, lags = 4)
  expect_identical(nrow(plot(es, style = "stata", shade_post = TRUE, ref_line = 0)), nrow(es))
  s <- staggered_att(p, "district", "month", "crime_rate", "reform_month", reps = 0)
  expect_identical(nrow(plot(s, style = "stata")), nrow(s$dynamic))
  g <- plot_event_grid(list(Crime = es, Staggered = s), main = "Two outcomes")
  expect_identical(unique(g$panel), c("Crime", "Staggered"))
  expect_error(plot_event_grid(list(es)), "named list")
  expect_error(plot(es, style = "zz"), "style")
})

test_that("the Bacon scatter, the permutation distributions and leave-one-out draw", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  b <- bacon_decomposition(p, "district", "month", "crime_rate", "reformed")
  expect_identical(nrow(plot(b)), nrow(b))
  r <- permutation_inference(p, "district", "month", c("crime_rate", "arrest_rate"), "reform_month",
                             cluster = "region")
  expect_identical(nrow(plot(r)), 2L)
  expect_identical(nrow(plot(r, type = "histogram")), 2L)
  l <- leave_one_out(p, "district", "month", "crime_rate", "reformed", units = c("D01", "D02", "D03"))
  expect_identical(l$dropped, c("D01", "D02", "D03"))
  q <- p[p$district != "D02", ]
  expect_equal(l$estimate[2], did_panel(q, "district", "month", "crime_rate", "reformed")$estimate)
  expect_identical(nrow(plot(l)), 3L)
  expect_error(leave_one_out(p, "district", "month", "crime_rate", "reformed", units = "D99"), "units of")
})

test_that("cohort_trends(): moving average, scaled to 1 before adoption", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- .pp()
  ct <- cohort_trends(p, "district", "month", "crime_rate", "reform_month", window = c(-6, 6), ma = 3)
  expect_true(all(ct$value[ct$event_time == -1] == 1))
  m <- tapply(p$crime_rate[p$reform_month %in% 13], p$month[p$reform_month %in% 13], mean)
  ma <- stats::filter(m, rep(1 / 3, 3), sides = 1)
  expect_equal(ct$value[ct$cohort == 13 & ct$event_time == 2], as.numeric(ma[15] / ma[12]))
  raw <- cohort_trends(p, "district", "month", "crime_rate", "reform_month", ma = 1, normalise = FALSE)
  expect_equal(raw$value[raw$cohort == 19 & raw$event_time == 0], mean(p$crime_rate[p$reform_month %in% 19 &
                                                                                       p$month == 19]))
  expect_identical(nrow(plot(ct)), nrow(ct))
  expect_error(cohort_trends(p, "district", "month", "crime_rate", "reform_month", window = c(0, 3)), "window")
})
