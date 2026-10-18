# Calls to Action 19 and 55: the catalogue and the gaps, against indigenous_gap() itself

test_that("trc_indicators() covers every Call 19 indicator, each with a direction or a reason for none", {
  ti <- trc_indicators()
  c19 <- c("infant mortality", "maternal health", "suicide", "mental health", "addictions", "life expectancy",
           "birth rates", "infant and child health issues", "chronic diseases", "illness and injury incidence",
           "availability of appropriate health services")
  expect_setequal(unique(ti$indicator[ti$call == "19"]), c19)
  expect_true(all(ti$better %in% c("higher", "lower", "")))
  expect_true(all(nzchar(ti$note[!nzchar(ti$better)])))
  expect_setequal(unique(ti$indicator[ti$call == "55"]), c("children in care", "educational attainment",
                                                          "income attainment"))
})

test_that("trc_health_gaps(): each gap is indigenous_gap's ratio, turned so that above 1 is worse", {
  g <- trc_health_gaps()
  expect_s3_class(g, "rmbl_trc_gaps")
  h <- indigenous_example("health_indicators")
  d <- h[h$period == "2019/2022" & h$age == "Total, 18 years and over" & h$indicator == "Mood disorder", ]
  ig <- indigenous_gap(d, "group", "estimate", "lower", "upper", quality = "quality")
  r <- g[g$measure == "Mood disorder" & g$group == "First Nations", ]
  expect_equal(r$times_worse, ig$ratio[ig$group == "First Nations"])
  expect_equal(r$lower, ig$ratio_lower[ig$group == "First Nations"])
  # higher is better: the ratio is inverted, and so is its interval
  le <- indigenous_example("life_expectancy")
  le <- le[le$period == "2016/2021", ]
  il <- indigenous_gap(le, "group", "estimate", "lower", "upper", quality = "quality")
  r2 <- g[g$measure == "Life expectancy at birth" & g$group == "Inuit", ]
  expect_equal(r2$times_worse, 1 / il$ratio[il$group == "Inuit"])
  expect_equal(r2$lower, 1 / il$ratio_upper[il$group == "Inuit"])
  expect_identical(r2$period, "2016/2021")
  expect_true(r2$worse)
  # the latest period with values: infant mortality 2014/2016, not the unavailable 1994/1996
  expect_identical(unique(g$period[g$measure == "Infant mortality rate"]), "2014/2016")
  expect_identical(g$worse, is.finite(g$lower) & g$lower > 1)
  # 41-10-0021 has no non-Indigenous rows, so suicidal thoughts are not among the gaps
  expect_false("Seriously contemplated suicide in the past 12 months" %in% g$measure)
  only <- trc_health_gaps(health = NULL, infant_mortality = NULL, suicidal_ideation = NULL)
  expect_identical(unique(only$measure), "Life expectancy at birth")
  expect_error(trc_health_gaps(NULL, NULL, NULL, NULL), "no table given measures")
  expect_error(trc_health_gaps(health = 1), "`health` must be a data frame")
  expect_error(trc_health_gaps(life_expectancy = 1), "must be data frames or NULL")
  expect_error(trc_health_gaps(suicidal_ideation = 1), "`suicidal_ideation` must be a data frame")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(nrow(plot(g)), sum(is.finite(g$times_worse)))
})
