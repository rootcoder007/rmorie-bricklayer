test_that("rgncov splits the population by whether a unit is present", {
  cov <- rgncov(
    reg = c("A", "B", "C", "D"),
    pop = c(1200000, 800000, 450000, 90000),
    units = c(3, 0, 1, 0)
  )
  a <- attr(cov, "coverage")
  expect_equal(a$regions, 4L)
  expect_equal(a$withunit, 2L)
  expect_equal(a$witunit, 2L)
  expect_equal(a$units, 4)
  expect_equal(a$totalpop, 2540000)
  expect_equal(a$covpop, 1650000)
  expect_equal(a$uncpop, 890000)
  expect_equal(round(a$covshr, 4), round(100 * 1650000 / 2540000, 4))
  ## the two halves must exhaust the population
  expect_equal(
    a$covpop + a$uncpop,
    a$totalpop
  )
})

test_that("rgncov orders by units then population", {
  cov <- rgncov(
    c("small", "big", "none"),
    c(10, 900, 5000),
    c(1, 1, 0)
  )
  expect_equal(cov$region, c("big", "small", "none"))
})

test_that("rgncov rejects input it cannot summarise", {
  expect_error(rgncov(c("A", "A"), c(1, 2), c(1, 0)), "must not repeat")
  expect_error(rgncov(c("A", "B"), c(1, 2), c(1)), "same length")
  expect_error(
    rgncov(c("A", "B"), c(1, -2), c(1, 0)),
    "non-negative"
  )
  expect_error(
    rgncov(c("A", "B"), c(1, 2), c(1.5, 0)),
    "whole numbers"
  )
  expect_error(rgncov(c("A", NA), c(1, 2), c(1, 0)), "missing")
})

test_that("printing rgncov says the share is not a denominator", {
  cov <- rgncov(c("A", "B"), c(100, 300), c(1, 0))
  out <- paste(utils::capture.output(print(cov)), collapse = " ")
  expect_match(out, "not a denominator")
  expect_match(out, "catchment")
})

test_that("rgnmapintg finds duplicates, gaps and unknown regions", {
  cw <- data.frame(
    inst = c("North", "South", "East"),
    cd = c("3557", "3520", "3506"),
    stringsAsFactors = FALSE
  )
  known <- c("3557", "3520", "3506")
  ok <- rgnmapintg(cw, "inst", "cd", regs = known)
  expect_true(all(ok$pass))
  expect_equal(nrow(ok), 3L)

  dup <- rbind(cw, cw[1, ])
  expect_equal(rgnmapintg(dup, "inst", "cd", known)$observed[1], 1)

  gap <- cw
  gap$cd[2] <- ""
  expect_equal(rgnmapintg(gap, "inst", "cd", known)$observed[2], 1)

  wrong <- cw
  wrong$cd[3] <- "2406"
  expect_equal(rgnmapintg(wrong, "inst", "cd", known)$observed[3], 1)

  ## without a reference geography the third check is not offered at all,
  ## rather than passing vacuously
  expect_equal(nrow(rgnmapintg(cw, "inst", "cd")), 2L)
})

test_that("rgnmapintg errors on a column that is not there", {
  cw <- data.frame(inst = "North", cd = "3557", stringsAsFactors = FALSE)
  expect_error(rgnmapintg(cw, "facility", "cd"), "no column")
  expect_error(rgnmapintg(cw, "inst", "division"), "no column")
})

test_that("rgnmapcmp reports agreement and the first disagreement", {
  pub <- data.frame(
    inst = c("North", "South"),
    cd = c("3557", "3520"),
    stringsAsFactors = FALSE
  )
  same <- rgnmapcmp(pub, pub, "inst")
  expect_true(all(same$mismatched == 0))
  expect_true(all(same$first == ""))

  obs <- pub
  obs$cd[2] <- "3521"
  diff <- rgnmapcmp(pub, obs, "inst")
  cd <- diff[diff$column == "cd", ]
  expect_equal(cd$mismatched, 1)
  expect_match(cd$first, "South")
  expect_match(cd$first, "3521")
})

test_that("rgnmapcmp counts units present on one side only", {
  pub <- data.frame(
    inst = c("North", "South"),
    cd = c("3557", "3520"),
    stringsAsFactors = FALSE
  )
  obs <- pub[1, ]
  rows <- rgnmapcmp(pub, obs, "inst")
  rows <- rows[rows$column == "rows", ]
  expect_equal(rows$mismatched, 1)
  expect_match(rows$first, "published only")
})

test_that("rgnmapcmp tolerates a numeric round trip through text", {
  pub <- data.frame(inst = "North", lat = 46.55004065, stringsAsFactors = FALSE)
  obs <- data.frame(
    inst = "North",
    lat = as.numeric(format(46.55004065, digits = 15)),
    stringsAsFactors = FALSE
  )
  cmp <- rgnmapcmp(pub, obs, "inst", cols = "lat")
  expect_equal(cmp$mismatched[cmp$column == "lat"], 0)
})

test_that("rgnmapalt separates documented from unexplained", {
  cw <- data.frame(
    inst = c("North", "South", "Hill"),
    cd = c("3557", "3520", "3506"),
    stringsAsFactors = FALSE
  )
  route <- c("North" = "3557", "South" = "3520", "Hill" = "3519")

  d <- rgnmapalt(cw, "inst", "cd", route, known = "Hill")
  expect_equal(nrow(d), 1L)
  expect_true(d$known)
  expect_equal(sum(!d$known), 0L)

  route["South"] <- "3521"
  d <- rgnmapalt(cw, "inst", "cd", route, known = "Hill")
  expect_equal(nrow(d), 2L)
  expect_equal(sum(!d$known), 1L)
  expect_equal(d$unit[!d$known], "South")
})

test_that("rgnmapalt skips units the route does not cover", {
  cw <- data.frame(
    inst = c("North", "South"),
    cd = c("3557", "3520"),
    stringsAsFactors = FALSE
  )
  ## the route knows nothing about South, which is not a disagreement
  d <- rgnmapalt(cw, "inst", "cd", c("North" = "3557"))
  expect_equal(nrow(d), 0L)
})

test_that("rgnmapalt accepts the route as a data frame", {
  cw <- data.frame(
    inst = c("North", "South"),
    cd = c("3557", "3520"),
    stringsAsFactors = FALSE
  )
  rt <- data.frame(
    inst = c("North", "South"),
    cd = c("3557", "3599"),
    stringsAsFactors = FALSE
  )
  d <- rgnmapalt(cw, "inst", "cd", rt)
  expect_equal(d$unit, "South")
  expect_equal(d$second, "3599")
})

test_that("rgnmappts returns NULL rather than failing without sf", {
  ## the boundary file does not exist, which is the same answer sf's
  ## absence gives: the caller records the check as unavailable
  expect_null(rgnmappts(
    x = 1,
    y = 2,
    unit = "North",
    bounds = tempfile(),
    fields = "CDUID"
  ))
})

test_that(
  paste0(
    "the region helpers refuse empty units, ",
    "non-frames and missing columns"
  ),
  {
    expect_error(.rmbl_rm_chr(character(0), "unit"), "must not be empty")
    expect_error(
      rgnmapintg("not a frame", "inst", "cd"),
      "must be a data frame"
    )
    pub <- data.frame(
      inst = c("North", "South"),
      cd = c("3557", "3520"),
      stringsAsFactors = FALSE
    )
    expect_error(rgnmapcmp(pub, pub, "inst", cols = "nope"), "missing: nope")
    obs <- rbind(
      pub,
      data.frame(inst = "East", cd = "3599", stringsAsFactors = FALSE)
    )
    rows <- rgnmapcmp(pub, obs, "inst")
    rows <- rows[rows$column == "rows", ]
    expect_match(rows$first, "recomputed only: East")
    expect_error(
      rgnmapalt(pub, "inst", "cd", c("3557", "3599")),
      "named by unit"
    )
  }
)

test_that("rgnmappts assigns points to the polygons that contain them", {
  skip_if_not_installed("sf")
  square <- function(x0) {
    sf::st_polygon(list(rbind(
      c(x0, 0),
      c(x0 + 1, 0),
      c(x0 + 1, 1),
      c(x0, 1),
      c(x0, 0)
    )))
  }
  poly <- sf::st_sf(
    CDUID = c("3520", "3521"),
    geometry = sf::st_sfc(square(0), square(1), crs = 4326)
  )
  bf <- tempfile(fileext = ".geojson")
  sf::st_write(poly, bf, quiet = TRUE)
  out <- rgnmappts(
    x = c(0.5, 1.5, 5),
    y = c(0.5, 0.5, 5),
    unit = c("A", "B", "C"),
    bounds = bf,
    fields = "CDUID"
  )
  expect_identical(out$unit, c("A", "B", "C"))
  expect_identical(out$CDUID, c("3520", "3521", NA))
  expect_identical(out$nreg, c(1L, 1L, 0L))
  expect_error(rgnmappts(1, 1:2, "A", bf, "CDUID"), "same length")
  expect_error(rgnmappts(NA, 1, "A", bf, "CDUID"), "must be complete")
  expect_error(rgnmappts(1, 1, "A", bf, "NOPE"), "no column")
  # without sf the answer is NULL, as it is when the boundary file is missing
  testthat::local_mocked_bindings(
    requireNamespace = function(...) FALSE,
    .package = "base"
  )
  expect_null(rgnmappts(1, 1, "A", bf, "CDUID"))
})
