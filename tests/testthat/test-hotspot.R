test_that(
  paste0(
    "hot spots, concentration and ",
    "persistence match a grid worked by hand"
  ),
  {
    # planar cells of side 1: three periods, cells A=(0,0), B=(1,0), C=(0,1),
    # D=(5,5)
    pts <- list(
      p1 = c(rep("A", 5), rep("B", 3), "C"),
      p2 = c(rep("A", 4), "B", rep("C", 3)),
      p3 = c(rep("D", 6), "A")
    )
    at <- list(
      A = c(0.5, 0.5),
      B = c(1.5, 0.5),
      C = c(0.5, 1.5),
      D = c(5.5, 5.5)
    )
    per <- rep(names(pts), lengths(pts))
    xy <- do.call(rbind, at[unlist(pts)])
    h <- hotpers(xy[, 1], xy[, 2], per, cell = 1, top = 0.25, xy = "planar")
    d <- h$periods
    expect_equal(h$ncells, 4L, tolerance = 1e-8)
    expect_equal(h$hotk, 1L, tolerance = 1e-8)
    expect_identical(d$period, c("p1", "p2", "p3"))
    expect_equal(d$incidents, c(9, 8, 7), tolerance = 1e-8)
    expect_equal(d$actcells, c(3L, 3L, 2L), tolerance = 1e-8)
    # half of 9 incidents: cell A alone holds 5; half of 8: A holds 4
    expect_equal(d$cellsforhalf, c(1L, 1L, 1L), tolerance = 1e-8)
    expect_equal(d$shrforhalf, c(0.25, 0.25, 0.25))
    # hot: A in p1 and p2, D in p3
    expect_equal(d$hotcells, c(1L, 1L, 1L), tolerance = 1e-8)
    expect_equal(d$hotshr, c(5 / 9, 4 / 8, 6 / 7), tolerance = 1e-8)
    expect_equal(d$jacpre, c(NA, 1, 0), tolerance = 1e-8)
    # the grid is anchored at the smallest coordinate (0.5, 0.5): cell A is
    # centred on (1, 1)
    cl <- h$cells
    expect_equal(cl$perhot[cl$x == 1 & cl$y == 1], 2, tolerance = 1e-8)
    expect_equal(cl$perhot[cl$x == 6], 1, tolerance = 1e-8)
    expect_equal(sum(cl$incidents), 24, tolerance = 1e-8)
    # every cell tied at the cut is hot
    ht <- hotpers(
      c(0.5, 1.5, 0.5, 1.5),
      c(0.5, 0.5, 0.5, 0.5),
      c(1, 1, 2, 2),
      cell = 1,
      top = 0.5,
      xy = "planar"
    )
    expect_equal(ht$periods$hotcells, c(2L, 2L), tolerance = 1e-8)
    expect_equal(ht$periods$jacpre, c(NA, 1), tolerance = 1e-8)
    expect_true(any(grepl(
      "Active cells +4 ",
      utils::capture.output(print(h))
    )))
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    expect_identical(plot(h)$period, d$period)
  }
)

test_that(
  paste0(
    "hot spots on longitude and latitude use kilometres and give centres ",
    "back in degrees"
  ),
  {
    b <- read.csv(system.file(
      "extdata",
      "tps_break_enter_d14_2024.csv",
      package = "rmoriebricklayer"
    ))
    b <- b[!is.na(b$lon), ]
    h <- hotpers(b$lon, b$lat, quarters(as.Date(b$occ_date)), cell = 0.3)
    expect_equal(sum(h$periods$incidents), nrow(b), tolerance = 1e-8)
    expect_true(all(abs(h$cells$x - median(b$lon)) < 0.2))
    expect_true(all(abs(h$cells$y - median(b$lat)) < 0.2))
    expect_equal(sum(h$cells$incidents), nrow(b), tolerance = 1e-8)
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    expect_equal(nrow(plot(h, main = "x")), 4L, tolerance = 1e-8)
  }
)

test_that("hot spot inputs that cannot be gridded are refused", {
  expect_error(hotpers(1:3, 1:3, 1:2), "same length")
  expect_error(hotpers(1:3, 1:3, 1:3, cell = 0), "positive")
  expect_error(hotpers(1:3, 1:3, 1:3, top = 2), "share")
  expect_error(hotpers(c(200, 1), c(1, 1), 1:2), "not a longitude")
  expect_error(hotpers(c(1, NA), c(1, 1), 1:2, xy = "planar"), "at least two")
  # a period with no incident in a cell set: no hot share, no overlap
  h <- hotpers(
    c(0.5, 0.5, NA),
    c(0.5, 0.5, 1),
    c(1, 1, 2),
    cell = 1,
    xy = "planar"
  )
  expect_equal(nrow(h$periods), 1L, tolerance = 1e-8)
})

test_that("a rate over time draws one panel per group on a shared scale", {
  d <- data.frame(
    g = rep(c("a", "b"), each = 4),
    year = rep(2020:2023, 2),
    n = c(30, 35, 28, 40, 60, 55, 70, 66),
    pop = rep(c(1000, 2000), each = 4),
    stringsAsFactors = FALSE
  )
  r <- rtcalc(d, count = n, pop = pop, by = c("g", "year"), per = 100)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- plot(r, period = "year")
  expect_equal(p$rate, r$rate, tolerance = 1e-8)
  expect_identical(unique(p$group), c("a", "b"))
  r1 <- rtcalc(d[d$g == "a", ], count = n, pop = pop, by = "year", per = 100)
  expect_identical(unique(plot(r1, period = "year", main = "One")$group), "All")
  expect_error(plot(r, period = "nope"), "by` columns")
  big <- data.frame(
    g = rep(letters[1:17], each = 2),
    year = rep(1:2, 17),
    n = 5,
    pop = 100
  )
  expect_error(
    plot(
      rtcalc(big, count = n, pop = pop, by = c("g", "year")),
      period = "year"
    ),
    "16 groups"
  )
})

test_that(
  paste0(
    "a rate over time puts the period on ",
    "its own scale with an axis title"
  ),
  {
    d <- data.frame(year = c(2020, 2022, 2023), n = c(30, 35, 28), pop = 1000)
    r <- rtcalc(d, count = n, pop = pop, by = "year", per = 100)
    rec <- new.env()
    rec$seen <- character()
    testthat::local_mocked_bindings(.bl_xlab = function(xlab) {
      rec$seen <- c(rec$seen, xlab)
    })
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    p <- plot(r, period = "year")
    expect_identical(rec$seen, "Period")
    expect_equal(p$period, c(2020, 2022, 2023), tolerance = 1e-8)
    # the gap year keeps its place: the axis runs on the years themselves
    expect_identical(
      graphics::par("usr")[1:2] > 2019 & graphics::par("usr")[1:2] < 2024,
      c(TRUE, TRUE)
    )
    plot(r, period = "year", xlab = "Year of release")
    expect_identical(rec$seen[2L], "Year of release")
  }
)

test_that("plot() of a hotpers() result leaves par() as it was (B2)", {
  set.seed(4)
  h <- hotpers(
    stats::runif(200, 0, 10),
    stats::runif(200, 0, 10),
    rep(c("p1", "p2", "p3", "p4"), 50),
    cell = 2,
    xy = "planar"
  )
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p0 <- graphics::par(no.readonly = TRUE)
  plot(h)
  p1 <- graphics::par(no.readonly = TRUE)
  for (k in c("mar", "mai", "pin", "plt", "col", "fg", "cex", "mfrow")) {
    expect_identical(p1[[k]], p0[[k]], info = k)
  }
})

# ---- boxed printouts -------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("hotpers() prints as a box", {
  set.seed(3)
  h <- hotpers(stats::runif(200), stats::runif(200),
    rep(1:3, length.out = 200), cell = 0.3, xy = "planar")
  .o2_check(h, "Hot spots", c("Active cells", "By period", "jacpre"))
})

# ---- result-driven reading -------------------------------------------------

test_that("hotpers()'s reading says whether the hot spots persist", {
  p <- data.frame(hotshr = c(0.3, 0.4), jacpre = c(NA, 0.8))
  r <- .hp_reading(p, 3L, 5L)
  expect_match(r[1L], "30.0% to 40.0%", fixed = TRUE)
  expect_match(r[2L], "the hot spots persist", fixed = TRUE)
  p$jacpre <- c(NA, 0.05)
  expect_match(.hp_reading(p, 0L, 5L)[2L], "do not persist", fixed = TRUE)
  set.seed(3)
  h <- hotpers(stats::runif(200, 0, 10), stats::runif(200, 0, 10),
    rep(2023:2024, 100), cell = 2, top = 0.2, xy = "planar")
  expect_match(paste(format(h), collapse = " "), "overlap with the period",
    fixed = TRUE)
})
