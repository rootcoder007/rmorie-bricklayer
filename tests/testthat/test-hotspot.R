test_that("hot spots, concentration and persistence match a grid worked by hand", {
  # planar cells of side 1: three periods, cells A=(0,0), B=(1,0), C=(0,1), D=(5,5)
  pts <- list(
    p1 = c(rep("A", 5), rep("B", 3), "C"),
    p2 = c(rep("A", 4), "B", rep("C", 3)),
    p3 = c(rep("D", 6), "A"))
  at <- list(A = c(0.5, 0.5), B = c(1.5, 0.5), C = c(0.5, 1.5), D = c(5.5, 5.5))
  per <- rep(names(pts), lengths(pts))
  xy <- do.call(rbind, at[unlist(pts)])
  h <- hotpers(xy[, 1], xy[, 2], per, cell = 1, top = 0.25, xy = "planar")
  d <- h$periods
  expect_equal(h$ncells, 4L)
  expect_equal(h$hotk, 1L)
  expect_identical(d$period, c("p1", "p2", "p3"))
  expect_equal(d$incidents, c(9, 8, 7))
  expect_equal(d$actcells, c(3L, 3L, 2L))
  # half of 9 incidents: cell A alone holds 5; half of 8: A holds 4
  expect_equal(d$cellsforhalf, c(1L, 1L, 1L))
  expect_equal(d$shrforhalf, c(0.25, 0.25, 0.25))
  # hot: A in p1 and p2, D in p3
  expect_equal(d$hotcells, c(1L, 1L, 1L))
  expect_equal(d$hotshr, c(5 / 9, 4 / 8, 6 / 7))
  expect_equal(d$jacpre, c(NA, 1, 0))
  # the grid is anchored at the smallest coordinate (0.5, 0.5): cell A is centred on (1, 1)
  cl <- h$cells
  expect_equal(cl$perhot[cl$x == 1 & cl$y == 1], 2)
  expect_equal(cl$perhot[cl$x == 6], 1)
  expect_equal(sum(cl$incidents), 24)
  # every cell tied at the cut is hot
  ht <- hotpers(c(0.5, 1.5, 0.5, 1.5), c(0.5, 0.5, 0.5, 0.5), c(1, 1, 2, 2), cell = 1, top = 0.5,
                            xy = "planar")
  expect_equal(ht$periods$hotcells, c(2L, 2L))
  expect_equal(ht$periods$jacpre, c(NA, 1))
  expect_match(utils::capture.output(print(h))[1], "4 active cells")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(plot(h)$period, d$period)
})

test_that("hot spots on longitude and latitude use kilometres and give centres back in degrees", {
  b <- read.csv(system.file("extdata", "tps_break_enter_d14_2024.csv", package = "rmoriebricklayer"))
  b <- b[!is.na(b$lon), ]
  h <- hotpers(b$lon, b$lat, quarters(as.Date(b$occ_date)), cell = 0.3)
  expect_equal(sum(h$periods$incidents), nrow(b))
  expect_true(all(abs(h$cells$x - median(b$lon)) < 0.2))
  expect_true(all(abs(h$cells$y - median(b$lat)) < 0.2))
  expect_equal(sum(h$cells$incidents), nrow(b))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(nrow(plot(h, main = "x")), 4L)
})

test_that("hot spot inputs that cannot be gridded are refused", {
  expect_error(hotpers(1:3, 1:3, 1:2), "same length")
  expect_error(hotpers(1:3, 1:3, 1:3, cell = 0), "positive")
  expect_error(hotpers(1:3, 1:3, 1:3, top = 2), "share")
  expect_error(hotpers(c(200, 1), c(1, 1), 1:2), "not a longitude")
  expect_error(hotpers(c(1, NA), c(1, 1), 1:2, xy = "planar"), "at least two")
  # a period with no incident in a cell set: no hot share, no overlap
  h <- hotpers(c(0.5, 0.5, NA), c(0.5, 0.5, 1), c(1, 1, 2), cell = 1, xy = "planar")
  expect_equal(nrow(h$periods), 1L)
})

test_that("a rate over time draws one panel per group on a shared scale", {
  d <- data.frame(g = rep(c("a", "b"), each = 4), year = rep(2020:2023, 2), n = c(30, 35, 28, 40, 60, 55, 70, 66),
                  pop = rep(c(1000, 2000), each = 4))
  r <- rtcalc(d, count = n, pop = pop, by = c("g", "year"), per = 100)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- plot(r, period = "year")
  expect_equal(p$rate, r$rate)
  expect_identical(unique(p$group), c("a", "b"))
  r1 <- rtcalc(d[d$g == "a", ], count = n, pop = pop, by = "year", per = 100)
  expect_identical(unique(plot(r1, period = "year", main = "One")$group), "All")
  expect_error(plot(r, period = "nope"), "by` columns")
  big <- data.frame(g = rep(letters[1:17], each = 2), year = rep(1:2, 17), n = 5, pop = 100)
  expect_error(plot(rtcalc(big, count = n, pop = pop, by = c("g", "year")), period = "year"), "16 groups")
})
