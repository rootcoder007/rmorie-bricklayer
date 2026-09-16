test_that("region_coverage splits the population by whether a unit is present", {
  cov <- region_coverage(region = c("A", "B", "C", "D"),
                         population = c(1200000, 800000, 450000, 90000),
                         units = c(3, 0, 1, 0))
  a <- attr(cov, "coverage")
  expect_equal(a$regions, 4L)
  expect_equal(a$with_unit, 2L)
  expect_equal(a$without_unit, 2L)
  expect_equal(a$units, 4)
  expect_equal(a$total_population, 2540000)
  expect_equal(a$covered_population, 1650000)
  expect_equal(a$uncovered_population, 890000)
  expect_equal(round(a$covered_share, 4), round(100 * 1650000 / 2540000, 4))
  ## the two halves must exhaust the population
  expect_equal(a$covered_population + a$uncovered_population,
               a$total_population)
})

test_that("region_coverage orders by units then population", {
  cov <- region_coverage(c("small", "big", "none"), c(10, 900, 5000),
                         c(1, 1, 0))
  expect_equal(cov$region, c("big", "small", "none"))
})

test_that("region_coverage rejects input it cannot summarise", {
  expect_error(region_coverage(c("A", "A"), c(1, 2), c(1, 0)), "must not repeat")
  expect_error(region_coverage(c("A", "B"), c(1, 2), c(1)), "same length")
  expect_error(region_coverage(c("A", "B"), c(1, -2), c(1, 0)),
               "non-negative")
  expect_error(region_coverage(c("A", "B"), c(1, 2), c(1.5, 0)),
               "whole numbers")
  expect_error(region_coverage(c("A", NA), c(1, 2), c(1, 0)), "missing")
})

test_that("printing region_coverage says the share is not a denominator", {
  cov <- region_coverage(c("A", "B"), c(100, 300), c(1, 0))
  out <- paste(utils::capture.output(print(cov)), collapse = " ")
  expect_match(out, "not a denominator")
  expect_match(out, "catchment")
})

test_that("region_map_integrity finds duplicates, gaps and unknown regions", {
  cw <- data.frame(inst = c("North", "South", "East"),
                   cd = c("3557", "3520", "3506"), stringsAsFactors = FALSE)
  known <- c("3557", "3520", "3506")
  ok <- region_map_integrity(cw, "inst", "cd", regions = known)
  expect_true(all(ok$pass))
  expect_equal(nrow(ok), 3L)

  dup <- rbind(cw, cw[1, ])
  expect_equal(region_map_integrity(dup, "inst", "cd", known)$observed[1], 1)

  gap <- cw; gap$cd[2] <- ""
  expect_equal(region_map_integrity(gap, "inst", "cd", known)$observed[2], 1)

  wrong <- cw; wrong$cd[3] <- "2406"
  expect_equal(region_map_integrity(wrong, "inst", "cd", known)$observed[3], 1)

  ## without a reference geography the third check is not offered at all,
  ## rather than passing vacuously
  expect_equal(nrow(region_map_integrity(cw, "inst", "cd")), 2L)
})

test_that("region_map_integrity errors on a column that is not there", {
  cw <- data.frame(inst = "North", cd = "3557", stringsAsFactors = FALSE)
  expect_error(region_map_integrity(cw, "facility", "cd"), "no column")
  expect_error(region_map_integrity(cw, "inst", "division"), "no column")
})

test_that("region_map_compare reports agreement and the first disagreement", {
  pub <- data.frame(inst = c("North", "South"), cd = c("3557", "3520"),
                    stringsAsFactors = FALSE)
  same <- region_map_compare(pub, pub, "inst")
  expect_true(all(same$mismatched == 0))
  expect_true(all(same$first == ""))

  obs <- pub; obs$cd[2] <- "3521"
  diff <- region_map_compare(pub, obs, "inst")
  cd <- diff[diff$column == "cd", ]
  expect_equal(cd$mismatched, 1)
  expect_match(cd$first, "South")
  expect_match(cd$first, "3521")
})

test_that("region_map_compare counts units present on one side only", {
  pub <- data.frame(inst = c("North", "South"), cd = c("3557", "3520"),
                    stringsAsFactors = FALSE)
  obs <- pub[1, ]
  rows <- region_map_compare(pub, obs, "inst")
  rows <- rows[rows$column == "rows", ]
  expect_equal(rows$mismatched, 1)
  expect_match(rows$first, "published only")
})

test_that("region_map_compare tolerates a numeric round trip through text", {
  pub <- data.frame(inst = "North", lat = 46.55004065, stringsAsFactors = FALSE)
  obs <- data.frame(inst = "North",
                    lat = as.numeric(format(46.55004065, digits = 15)),
                    stringsAsFactors = FALSE)
  cmp <- region_map_compare(pub, obs, "inst", cols = "lat")
  expect_equal(cmp$mismatched[cmp$column == "lat"], 0)
})

test_that("region_map_second_route separates documented from unexplained", {
  cw <- data.frame(inst = c("North", "South", "Hill"),
                   cd = c("3557", "3520", "3506"), stringsAsFactors = FALSE)
  route <- c("North" = "3557", "South" = "3520", "Hill" = "3519")

  d <- region_map_second_route(cw, "inst", "cd", route, known = "Hill")
  expect_equal(nrow(d), 1L)
  expect_true(d$known)
  expect_equal(sum(!d$known), 0L)

  route["South"] <- "3521"
  d <- region_map_second_route(cw, "inst", "cd", route, known = "Hill")
  expect_equal(nrow(d), 2L)
  expect_equal(sum(!d$known), 1L)
  expect_equal(d$unit[!d$known], "South")
})

test_that("region_map_second_route skips units the route does not cover", {
  cw <- data.frame(inst = c("North", "South"), cd = c("3557", "3520"),
                   stringsAsFactors = FALSE)
  ## the route knows nothing about South, which is not a disagreement
  d <- region_map_second_route(cw, "inst", "cd", c("North" = "3557"))
  expect_equal(nrow(d), 0L)
})

test_that("region_map_second_route accepts the route as a data frame", {
  cw <- data.frame(inst = c("North", "South"), cd = c("3557", "3520"),
                   stringsAsFactors = FALSE)
  rt <- data.frame(inst = c("North", "South"), cd = c("3557", "3599"),
                   stringsAsFactors = FALSE)
  d <- region_map_second_route(cw, "inst", "cd", rt)
  expect_equal(d$unit, "South")
  expect_equal(d$second, "3599")
})

test_that("region_map_from_points returns NULL rather than failing without sf", {
  ## the boundary file does not exist, which is the same answer sf's
  ## absence gives: the caller records the check as unavailable
  expect_null(region_map_from_points(x = 1, y = 2, unit = "North",
                                    boundaries = tempfile(),
                                    fields = "CDUID"))
})
