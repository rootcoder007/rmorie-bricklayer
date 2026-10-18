# The 1.0.0 review of the Indigenous estimators: each fix, pinned

test_that("quality_recode() maps another agency's flags onto ok, E and x", {
  expect_identical(quality_recode(c("", "*", "**", "np", NA), suppressed = c("**", "np"), caution = "*"),
                   c("ok", "E", "x", "x", "ok"))
  expect_identical(quality_recode(c("E", "F", "..")), c("E", "x", "x"))
  expect_error(quality_recode("a", suppressed = "a", caution = "a"), "both suppressed and caution")
  expect_error(quality_recode(list(1)), "vector of flags")
  expect_error(quality_recode("a", suppressed = 1), "must be flags")
})

test_that("unknown quality flags warn and count as ok", {
  expect_warning(q <- .rmbl_qflags(c("", "E", "zz", NA)), "\"zz\" not recognised")
  expect_identical(q, c("ok", "E", "ok", "ok"))
  expect_silent(.rmbl_qflags(c("x", "..", "...", "F")))
})

test_that("limits_from() builds limits from a standard error, a CV or a margin of error", {
  z <- stats::qnorm(0.975)
  r <- limits_from(c(40, 10), se = c(2, 1))
  expect_equal(r$lower, c(40, 10) - z * c(2, 1))
  expect_equal(r$upper, c(40, 10) + z * c(2, 1))
  expect_equal(limits_from(40, cv = 5)$se, 2)
  expect_equal(limits_from(40, moe = stats::qnorm(0.95) * 2)$se, 2)
  expect_equal(limits_from(40, moe = z * 2, moe_level = 0.95)$se, 2)
  expect_error(limits_from(40), "give one of")
  expect_error(limits_from(40, se = 1, cv = 1), "give one of")
  expect_error(limits_from(c(1, 2, 3), se = c(1, 2)), "one per estimate")
  expect_error(limits_from(40, se = -1), "must not be negative")
})

test_that("indigenous_gap() refuses duplicate groups and warns on a total as the reference", {
  d <- data.frame(g = c("A", "A", "R"), est = c(10, 11, 12), lo = c(9, 10, 11), hi = c(11, 12, 13))
  expect_error(indigenous_gap(d, "g", "est", "lo", "hi", reference = "R"), "appears twice")
  d2 <- data.frame(g = c("A", "Total, all persons"), est = c(10, 12), lo = c(9, 11), hi = c(11, 13))
  expect_warning(indigenous_gap(d2, "g", "est", "lo", "hi", reference = "Total, all persons"), "total")
  d3 <- data.frame(g = c(" A", "B", "R"), est = c(10, 11, 12), lo = c(9, 10, 11), hi = c(11, 12, 13))
  r <- indigenous_gap(d3, "g", "est", "lo", "hi", reference = "R", pooled_groups = "B")
  expect_identical(r$group, c("A", "B"))
  expect_identical(r$pooled_group, c(FALSE, TRUE))
})

test_that("rate_gap() refuses a group against itself; exposure_trend() refuses a constant outcome", {
  x <- age_standardise(c(5, 9, 2, 3), c(1000, 1200, 2000, 2500), c(1, 1), group = c("a", "a", "b", "b"))
  expect_error(rate_gap(x, "a", "a"), "itself|same|differ")
  expect_error(exposure_trend(c(0, 0, 0), c(10, 10, 10)), "no trend to test")
  expect_error(exposure_trend(c(10, 10, 10), c(10, 10, 10)), "no trend to test")
})

test_that("holistic_balance(): the interval holds the estimate, and proportions are refused", {
  d <- data.frame(g = rep(c("A", "B"), each = 4), dom = rep(c("physical", "emotional", "mental", "spiritual"), 2),
                  pct = c(50, 52, 48, 51, 80, 70, 20, 30), lo = c(45, 47, 43, 46, 75, 65, 15, 25),
                  hi = c(55, 57, 53, 56, 85, 75, 25, 35))
  r <- holistic_balance(d, "g", "dom", "pct", "lo", "hi", reps = 1000, seed = 2)
  expect_true(all(r$balance_lower <= r$balance & r$balance <= r$balance_upper))
  expect_true(all(r$balance_lower >= 0 & r$balance_upper <= 1))
  p <- d
  p[c("pct", "lo", "hi")] <- p[c("pct", "lo", "hi")] / 100
  expect_error(holistic_balance(p, "g", "dom", "pct", "lo", "hi"), "percent|proportion")
})

test_that("connection_association(): the Monte Carlo p-value is (b + 1) / (R + 1)", {
  big <- data.frame(p = 1:12, x = 1:12, y = 1:12)
  r <- connection_association(big, "p", "x", "y", reps = 999)
  expect_false(r$exact)
  expect_gt(r$p_value, 0)
  expect_equal(r$p_value * 1000, round(r$p_value * 1000), tolerance = 1e-9)
})

test_that("healing_change(): with `distress` given, an indicator in neither list is other", {
  d <- data.frame(g = "A", ind = rep(c("well", "ill", "income"), each = 2), per = rep(c("t1", "t2"), 3),
                  est = c(50, 55, 20, 18, 30, 31), lo = c(46, 51, 18, 16, 28, 29), hi = c(54, 59, 22, 20, 32, 33))
  r <- healing_change(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2", wellness = "well", distress = "ill")
  expect_identical(r$side[match(c("well", "ill", "income"), r$indicator)], c("wellness", "distress", "other"))
  r2 <- healing_change(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2", wellness = "well")
  expect_identical(r2$side[r2$indicator == "income"], "distress")
  d$lo[1] <- 52
  expect_warning(healing_change(d, "g", "ind", "per", "est", "lo", "hi", "t1", "t2"), "t1")
})

test_that("community_index() keeps its confidence level", {
  d <- data.frame(g = rep(c("A", "B"), each = 2), ind = rep(c("u", "v"), 2), est = c(40, 20, 50, 10),
                  lo = c(36, 17, 46, 8), hi = c(44, 23, 54, 12))
  ci <- community_index(d, "g", "ind", "est", "lo", "hi", weights = c(u = 1, v = -1), conf_level = 0.9)
  expect_identical(attr(ci, "conf_level"), 0.9)
})

test_that("standardise_prevalence() caps the limit at `scale`, which may be Inf", {
  s <- standardise_prevalence(c(98, 99), c(95, 96), c(100, 100), c(0.5, 0.5))
  expect_lte(s$upper, 100)
  r <- standardise_prevalence(c(98, 99), c(95, 96), c(101, 102), c(0.5, 0.5), scale = Inf)
  expect_gt(r$upper, 100)
})

test_that("profile_share(): rounding base and the on-reserve full canvass", {
  p <- census_profile(indigenous_example("census_population"))
  a <- profile_share(p, "Foster children", "Total - Children in census families")
  b <- profile_share(p, "Foster children", "Total - Children in census families", rounding_base = 1)
  ok <- is.finite(a$lower) & is.finite(b$lower) & a$estimate > 0
  expect_true(all(b$upper[ok] - b$lower[ok] <= a$upper[ok] - a$lower[ok] + 1e-12))
  on <- a$residence == "On reserve" & ok
  if (any(on)) {
    c4 <- profile_share(p, "Foster children", "Total - Children in census families", sample_fraction = 0.5)
    expect_equal(c4$lower[on], a$lower[on])
  }
  expect_error(profile_share(p, "Foster children", rounding_base = 0), "rounding_base")
})

test_that("census_cwb(): min_population and the DGUID column", {
  p <- census_profile(indigenous_example("census_population"))
  h <- census_profile(indigenous_example("census_households"))
  cw <- census_cwb(p, h, min_population = 65)
  expect_true("dguid" %in% names(cw))
  expect_true(all(is.na(cw$cwb[is.finite(cw$population) & cw$population < 65])))
  expect_error(census_cwb(p, h, min_population = -1), "min_population")
})

test_that("trc_health_gaps(): a different reference, and duplicates warn", {
  hi <- indigenous_example("health_indicators")
  g <- trc_health_gaps(hi, NULL, NULL, NULL)
  expect_true(all(c("disadvantage_ratio", "lower", "upper") %in% names(g)))
  expect_error(trc_health_gaps(hi, NULL, NULL, NULL, reference = "Nobody"), "\"Nobody\"")
  dup <- rbind(hi, hi[hi$indicator == "Diabetes", ])
  expect_warning(g2 <- trc_health_gaps(dup, NULL, NULL, NULL), "Diabetes .*more than one row per group")
  expect_false("Diabetes" %in% g2$measure)
})
