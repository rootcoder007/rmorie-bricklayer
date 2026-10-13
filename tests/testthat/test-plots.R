# Every plot method draws without error on a null device and returns the data
# it drew; palettes and options behave; the dispersion field helpers agree
# with the point functions they wrap.

with_dev <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

test_that("palettes and plot options", {
  expect_length(bricklayer_palette(), 8L)
  expect_length(bricklayer_palette("okabe", 11), 11L)
  expect_equal(bricklayer_palette("grey", 2), c("#252525", "#636363"))
  expect_length(bricklayer_palette("sequential", 7), 7L)
  expect_equal(bricklayer_palette("diverging", 1), "#2166AC")
  expect_error(bricklayer_palette("okabe", 0), "positive")
  expect_error(bricklayer_palette("neon"), "arg")
  old <- bricklayer_plot_options()
  expect_equal(old$palette, "okabe")
  on.exit(options(rmoriebricklayer.plot = NULL), add = TRUE)
  expect_invisible(bricklayer_plot_options(palette = "grey", grid = FALSE))
  expect_equal(bricklayer_plot_options()$palette, "grey")
  expect_false(bricklayer_plot_options()$grid)
  expect_error(bricklayer_plot_options(size = 3), "plot options are")
  expect_error(bricklayer_plot_options(3), "plot options are")
  expect_error(bricklayer_plot_options(palette = "neon"), "arg")
  with_dev({
    graphics::plot.new()
    expect_false(rmoriebricklayer:::.bl_grid(NULL))
    expect_true(rmoriebricklayer:::.bl_grid(TRUE))
    expect_true(rmoriebricklayer:::.bl_grid(TRUE, side = "x"))
  })
  expect_equal(rmoriebricklayer:::.bl_cols(3, col = "red"), rep("red", 3))
  # an all-missing interval chart still draws (a unit window) rather than erroring
  with_dev(rmoriebricklayer:::.bl_dot_interval(c("a", "b"), c(NA, NA), c(NA, NA), c(NA, NA), "m", "x",
                                               c("black", "black")))
  with_dev(rmoriebricklayer:::.bl_dot_interval("a", 2, 2, 2, "m", "x", "black"))
  expect_equal(rmoriebricklayer:::.bl_cols(2, palette = "grey"), c("#252525", "#636363"))
})

test_that("stock and flow", {
  sf <- stock_flow(days = c(13500, 14600, 15100), people = c(300, 320, 310), period = 2021:2023,
                   exposure = 1e5)
  d <- with_dev(plot(sf))
  expect_equal(names(d), c("period", "adp", "alos", "people", "days"))
  expect_equal(d$alos, sf$alos)
  d2 <- with_dev(plot(sf, what = c("flow_rate", "stock_rate"), col = "red", main = "x"))
  expect_equal(names(d2), c("period", "flow_rate", "stock_rate"))
  expect_error(with_dev(plot(sf, what = "nothing")), "arg")
})

test_that("period-over-period change", {
  # bases large enough for a percentage change
  big <- yoy(data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)), value = "n", period = "year")
  d <- with_dev(plot(big))
  expect_equal(nrow(d), 5L)
  expect_equal(d$pct_change, big$pct_change)
  expect_true(any(is.finite(d$pct_change)))
  # small counts draw their percentages like any other
  small <- yoy(data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)), value = "n", period = "year")
  ds <- with_dev(plot(small))
  expect_equal(ds$pct_change, small$pct_change)
  expect_identical(is.finite(ds$pct_change), c(FALSE, TRUE, TRUE, TRUE, TRUE))
  # only zero bases leave no percentage at all: the counts are drawn instead of an empty frame
  y <- yoy(data.frame(year = 2019:2021, n = c(0, 0, 5)), value = "n", period = "year")
  expect_equal(with_dev(plot(y))$value, y$value)
  v <- with_dev(plot(y, what = "value", col = "black"))
  expect_equal(v$value, y$value)
  seg <- data.frame(year = rep(2021:2023, 2), g = rep(c("a", "b"), each = 3), n = c(500, 600, 700, 900, 800, 1000))
  yg <- yoy(seg, value = "n", period = "year", by = "g")
  dg <- with_dev(plot(yg))
  expect_true(all(grepl("^(a|b): ", dg$label)))
  vg <- with_dev(plot(yg, what = "value"))
  expect_equal(nrow(vg), 6L)
  expect_equal(with_dev(plot(yg, col = "grey"))$verdict, as.character(yg$verdict))
})

test_that("rates, shares and rate change", {
  d <- data.frame(division = rep(c("n", "e", "w"), 2), year = rep(2022:2023, each = 3),
                  stops = c(120, 90, 60, 150, 85, 70), residents = c(1e4, 8e3, 5e3, 1e4, 8e3, 5e3))
  r <- rate(d[d$year == 2023, ], count = "stops", population = "residents", by = "division")
  dr <- with_dev(plot(r))
  expect_equal(dr$rate, r$rate)
  expect_equal(nrow(with_dev(plot(rate(d, count = "stops", population = "residents")))), 1L)
  s <- share(d[d$year == 2023, ], count = "stops", by = "division")
  expect_equal(with_dev(plot(s))$share, s$share)
  rc <- rate_change(d, count = "stops", population = "residents", period = "year", by = "division")
  drc <- with_dev(plot(rc))
  expect_equal(drc$pct_change, rc$pct_change)
  rc0 <- rate_change(d, count = "stops", population = "residents", period = "year")
  expect_equal(nrow(with_dev(plot(rc0, col = "navy"))), nrow(rc0))
})

test_that("band sensitivity, drift calibration and drift", {
  b <- parse_bands(c("0-17", "18-24", "25-44", "45+"))
  s <- band_sensitivity(b, c(10, 20, 30, 40), caps = c(60, 70, 80, 90))
  expect_equal(with_dev(plot(s))$cap, s$cap)
  set.seed(1)
  dd <- data.frame(a = rnorm(400), b = sample(letters[1:3], 400, TRUE))
  cal <- drift_calibrate(dd, n = 3L)
  pc <- with_dev(plot(cal))
  expect_equal(pc$column, c(cal$columns$column, "any column"))
  expect_equal(pc$false_alarm_rate, c(cal$columns$false_alarm_rate, cal$any_flag))
  # the exact interval over the splits: 0 of 3 still allows up to 1 - 0.025^(1/3)
  z <- which(pc$false_alarm_rate == 0)[1]
  expect_equal(pc$upper[z], 1 - 0.025^(1 / 3))
  expect_true(all(pc$lower <= pc$false_alarm_rate & pc$false_alarm_rate <= pc$upper))
  dr <- capsule_drift(dd, transform(dd, a = a + 3))
  pd <- with_dev(plot(dr))
  expect_equal(pd$column, dr$columns$column)
  expect_equal(nrow(with_dev(plot(dr, col = "red"))), nrow(dr$columns))
})

test_that("Benford, power, falsification", {
  bf <- benford_test(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9))
  d <- with_dev(plot(bf))
  expect_equal(d$expected, log10(1 + 1 / (1:9)))
  expect_equal(sum(d$observed), 1)
  set.seed(2)
  dd <- data.frame(x = rnorm(60), y = rnorm(60))
  shift <- function(z, s) {
    z$y <- z$y + s * z$x
    z
  }
  pw <- capsule_power(dd, function(z) cor(z$x, z$y), inject = shift, treatment = "x",
                      sizes = c(0, 0.5), n = 19, reps = 3, seed = 1)
  expect_equal(with_dev(plot(pw))$size, c(0, 0.5))
  fk <- capsule_falsify(dd, function(z) cor(z$x, z$y), treatment = "x", n = 29, seed = 1)
  expect_true(is.numeric(fk$permutation))
  pf <- with_dev(plot(fk))
  expect_equal(nrow(pf), sum(is.finite(fk$permutation)))
  fk$permutation <- c(NA_real_, NaN)
  expect_equal(nrow(with_dev(plot(fk))), 0L)
})

test_that("frequencies, missingness, coverage, outliers, correlations", {
  ft <- frequency_table(data.frame(g = c("a", "b", "b", "c", "c", "c")), "g")
  expect_equal(with_dev(plot(ft))$n, ft$n)
  expect_equal(nrow(with_dev(plot(ft, col = "red"))), nrow(ft))
  mp <- missingness_pattern(data.frame(a = c(1, NA, 3, NA), b = c(NA, NA, 1, 2)))
  expect_equal(with_dev(plot(mp))$n_rows, mp$n_rows)
  cov <- region_coverage(c("a", "b", "c"), c(100, 200, 300), c(1L, 0L, 2L))
  expect_equal(with_dev(plot(cov))$has_unit, cov$has_unit)
  expect_equal(nrow(with_dev(plot(cov, col = "black"))), 3L)
  set.seed(4)
  d <- data.frame(h = rnorm(100), w = rnorm(100))
  d$h[1] <- 15
  o <- mahalanobis_outliers(d)
  po <- with_dev(plot(o))
  expect_true(po$outlier[po$row == 1])
  expect_equal(nrow(with_dev(plot(o, col = "red"))), 100L)
  tc <- top_correlations(data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20)))
  expect_equal(nrow(with_dev(plot(tc))), nrow(tc))
  ct <- correlation_table(data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20)))
  pc <- with_dev(plot(ct, col = "grey"))
  expect_equal(nrow(pc), 3L)
  expect_true(all(diff(abs(pc$correlation)) <= 1e-12))
})

test_that("rounding envelopes", {
  prev <- published_bounds(c(10, 20), rounding = 5)
  expect_s3_class(prev, "rmbl_bounds")
  expect_equal(with_dev(plot(prev))$value, prev$value)
  rownames(prev) <- c("north", "south")
  expect_equal(nrow(with_dev(plot(prev, col = "navy"))), 2L)
})

test_that("air pollution: curve, burden, equity, report", {
  crf <- crf_no2(25)
  d <- with_dev(plot(crf))
  expect_equal(nrow(d), 200L)
  expect_equal(d$rr[d$exposure <= 10], rep(1, sum(d$exposure <= 10)))
  d2 <- with_dev(plot(crf_pm25(20, outcome = "ihd"), exposure = c(0, 5.8, 20)))
  expect_equal(d2$rr[1:2], c(1, 1))
  expect_equal(d2$rr[3], 1 + 1.91 * (1 - exp(-0.14 * (20 - 5.8)^0.49)))
  b <- pollution_burden(25, 1, 0.008, 1e6, pollutant = "NO2")
  pb <- with_dev(plot(b))
  expect_equal(pb$value, c(b$baseline_cases, b$attributable_cases))
  eq <- exposure_concentration_index(data.frame(exposure = c(4, 1, 8, 2), income = c(2, 1, 4, 3)),
                                     "exposure", "income")
  pe <- with_dev(plot(eq))
  expect_equal(pe$exposure[4], 1)
  eq$extra$curve <- NULL
  expect_error(with_dev(plot(eq)), "older object")
  r <- verify_pollution("no2", demo = TRUE)
  pr <- with_dev(plot(r))
  expect_named(pr, c("crf", "burden", "panel_key"))
  r2 <- verify_pollution("no2", exposure_mean = 25, exposure_prevalence = 1)
  expect_named(with_dev(plot(r2, main = "x")), c("crf", "burden", "panel_key"))
  bad <- verify_pollution("no2", exposure_mean = Inf, exposure_prevalence = 1)
  expect_equal(with_dev(plot(bad))$status, "assumption_failure")
  err <- verify_pollution("no2", exposure_csv = tempfile())
  expect_equal(with_dev(plot(err))$status, "error")
})

test_that("the footprint", {
  # long enough to measure: the CPU and memory emissions add to the total, all in grams
  fp <- compute_footprint(for (i in 1:30) sum(sqrt(seq_len(2e5))), location = "CA", cpu_power_w = 45,
                          memory_gb = 8)
  d <- with_dev(plot(fp))
  expect_identical(d$quantity, c("CPU", "memory", "total"))
  expect_equal(d$value[d$quantity == "total"], fp$co2e_g)
  expect_equal(sum(d$value[d$quantity != "total"]), fp$co2e_g, tolerance = 1e-8)
  # too short to time: the plot says so instead of drawing empty bars
  z <- fp
  z$co2e_g <- 0
  z$energy_kwh <- list(cpu = 0, memory = 0, total = 0)
  expect_equal(with_dev(plot(z))$value, c(0, 0, 0))
})

test_that("fields and particles", {
  f <- plume_field(100, 5, 50, x = c(100, 500, 1000), y = c(-50, 0, 50))
  expect_s3_class(f, "rmbl_field")
  expect_equal(dim(f$field), c(3L, 3L))
  expect_equal(f$field[2, 2], gaussian_plume(100, 5, 50, data.frame(x = 500, y = 0, z = 0)))
  expect_equal(f$dx, 450)   # the median step
  d <- with_dev(plot(f))
  expect_equal(nrow(d), 9L)
  expect_equal(d$value, as.vector(f$field))
  expect_equal(nrow(with_dev(plot(f, contours = 0, col = grDevices::grey.colors(5)))), 9L)
  f1 <- plume_field(100, 5, 50, x = 500, y = 0)
  expect_true(is.na(f1$dx))
  expect_equal(nrow(with_dev(plot(f1))), 1L)
  c0 <- matrix(0, 11, 11)
  c0[6, 6] <- 1
  a <- advection_diffusion_2d(c0, 0.1, 0.1, 0.1, 0.1, 1, 1, 0.5, 4)
  expect_equal(nrow(with_dev(plot(a))), 121L)
  p <- lagrangian_particles(50, 0, 0, 1, 0.5, 1, 1, 1, 10, grid = c(-10, 30, -10, 20, 8, 6))
  expect_equal(nrow(with_dev(plot(p))), 50L)
  p0 <- lagrangian_particles(50, 0, 0, 1, 0.5, 1, 1, 1, 10)
  expect_equal(nrow(with_dev(plot(p0, col = "black"))), 50L)
})

test_that("trend and the whole analysis", {
  ct <- count_trend(c(5, 7, 6, 9, 12, 11))
  expect_s3_class(ct, "rmbl_count_trend")
  d <- with_dev(plot(ct))
  expect_equal(d$fitted, ct$fitted)
  ct$data <- NULL
  expect_error(with_dev(plot(ct)), "older object")
  otis <- data.frame(year = rep(2020:2023, each = 2), g = rep(c("a", "b"), 4),
                     n = c(10, 20, 12, 22, 11, 25, 15, 24), pop = rep(c(1000, 2000), 4))
  a <- analyse_table(otis, value = "n", period = "year", by = "g", population = "pop")
  out <- with_dev(plot(a))
  expect_named(out, c("change", "rates", "rate_change"))
  a0 <- analyse_table(otis, value = "n", period = "year", by = "g")
  expect_named(with_dev(plot(a0)), "change")
  expect_length(with_dev(plot(a0, which = "rates")), 0L)
})

test_that("Lorenz and funnel plots", {
  x <- c(1, 1, 2, 3, 5, 8, 13)
  d <- with_dev(plot_lorenz(x))
  expect_equal(d, lorenz(x))
  expect_equal(nrow(with_dev(plot_lorenz(lorenz(x), main = "given"))), nrow(lorenz(x)))
  hand <- data.frame(population = c(0.5, 1), value = c(0.2, 1))
  expect_equal(nrow(with_dev(plot_lorenz(hand))), 3L)
  f <- with_dev(plot_funnel(observed = c(4, 20, 50, 2), expected = c(5, 22, 40, 20),
                            area = c("a", "b", "c", "d")))
  expect_equal(f$ratio, c(4, 20, 50, 2) / c(5, 22, 40, 20))
  expect_true(f$outside[4])
  lim <- funnel_limits(c(5, 20, 22, 40), levels = c(0.95, 0.998))
  outer <- lim[lim$level == 0.998, ]
  expect_equal(f$outside, f$ratio > outer$upper[match(f$expected, outer$expected)] |
                 f$ratio < outer$lower[match(f$expected, outer$expected)])
  expect_true(all(is.na(with_dev(plot_funnel(c(4, 20), c(5, 22), col = "red"))$area)))
  expect_error(plot_funnel(c(1, 2), c(1, 2, 3)), "same length")
})

test_that("panel titles fit: letters and a key on a narrow device, full titles on a wide one", {
  sf <- stock_flow(days = c(13500, 14600, 15100), people = c(300, 320, 310), period = 2021:2023)
  grDevices::pdf(NULL, width = 4, height = 3)
  narrow <- plot(sf)
  grDevices::dev.off()
  expect_true(length(attr(narrow, "panel_key")) >= 1L)
  expect_match(attr(narrow, "panel_key")[1], "^A: ")
  grDevices::pdf(NULL, width = 20, height = 5)
  wide <- plot(sf)
  grDevices::dev.off()
  expect_length(attr(wide, "panel_key"), 0L)
  expect_false(rmoriebricklayer:::.bl_state$active)
  # a long title in a single narrow plot wraps instead of overrunning
  grDevices::pdf(NULL, width = 3, height = 3)
  graphics::plot.new()
  t <- rmoriebricklayer:::.bl_title(paste(rep("a wide title", 8), collapse = " "))
  grDevices::dev.off()
  expect_match(t, "a wide title")
  grDevices::pdf(NULL, width = 5, height = 4)
  graphics::plot.new()
  expect_gt(rmoriebricklayer:::.bl_left_margin(c(13500, 15100)), rmoriebricklayer:::.bl_left_margin(c(1, 9)))
  expect_equal(rmoriebricklayer:::.bl_left_margin(numeric(0)), 4.5)
  expect_gt(rmoriebricklayer:::.bl_left_margin(labels = c("a very long row label", "b")), 4.5)
  r <- verify_pollution("no2", demo = TRUE)
  rep <- plot(r)
  grDevices::dev.off()
  expect_true(is.character(rep$panel_key))
})

test_that("a long axis title shrinks or wraps instead of overrunning", {
  grDevices::pdf(NULL, width = 2.5, height = 3)
  graphics::plot.new()
  expect_equal(rmoriebricklayer:::.bl_xlab("x"), "x")
  expect_equal(rmoriebricklayer:::.bl_xlab(paste(rep("cumulative share of people", 3), collapse = " ")),
               paste(rep("cumulative share of people", 3), collapse = " "))
  expect_null(rmoriebricklayer:::.bl_xlab(NULL))
  grDevices::dev.off()
})

test_that("an empty title draws nothing and string width falls back without a device", {
  expect_null(rmoriebricklayer:::.bl_title(NULL))
  expect_equal(rmoriebricklayer:::.bl_title(""), "")
  grDevices::pdf(NULL)
  w <- rmoriebricklayer:::.bl_strwidth("abcd")
  grDevices::dev.off()
  expect_true(is.finite(w) && w > 0)
  # strwidth() cannot answer (no device, or a device that returns no width): the width
  # comes from the character height instead
  grDevices::pdf(NULL)
  testthat::local_mocked_bindings(strwidth = function(...) stop("no device"), .package = "graphics")
  f <- rmoriebricklayer:::.bl_strwidth("abcd", cex = 2)
  testthat::local_mocked_bindings(strwidth = function(...) NA_real_, .package = "graphics")
  g <- rmoriebricklayer:::.bl_strwidth("abcd", cex = 2)
  csi <- graphics::par("csi")
  grDevices::dev.off()
  expect_equal(f, 4 * 0.55 * csi * 2)
  expect_equal(g, f)
})

test_that("axis titles wrap and shrink until every line fits, never cut", {
  grDevices::pdf(NULL, width = 2.2, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(1:2)
  got <- NULL
  local_mocked_bindings(title = function(xlab = NULL, cex.lab = 1, ...) got <<- list(xlab, cex.lab),
                        .package = "graphics")
  rmoriebricklayer:::.bl_xlab("NO2 (micrograms per cubic metre) over the whole study period")
  lines <- strsplit(got[[1]], "\n", fixed = TRUE)[[1]]
  # every word is kept
  expect_identical(paste(lines, collapse = " "), "NO2 (micrograms per cubic metre) over the whole study period")
  expect_lte(length(lines), 3L)  # two where they fit; a 2-inch panel needs three
  expect_true(all(graphics::strwidth(lines, units = "inches", cex = got[[2]]) <= graphics::par("pin")[1] * 0.98))
})

test_that("a row note fits its panel, falling back to the part before the colon", {
  grDevices::pdf(NULL, width = 2, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  said <- NULL
  local_mocked_bindings(text = function(x, y, labels, cex = 1, ...) said <<- list(labels, cex), .package = "graphics")
  rmoriebricklayer:::.bl_dot_interval(c("a", "b"), c(NA, 5), c(NA, 1), c(NA, 9), "m", "x",
                                      c("red", "blue"), ref = 0,
                                      note = c("first period: nothing to compare with", NA))
  expect_identical(said[[1]], "first period")
  expect_gte(said[[2]], 0.6)
})

test_that("a drift calibration with no false alarms still draws each rate and its interval", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  cal <- structure(list(columns = data.frame(column = c("a", "b"), false_alarm_rate = c(0, 0)),
                        any_flag = 0, alpha = 0.01, n = 3L), class = "rmbl_drift_calibration")
  seg <- NULL
  local_mocked_bindings(segments = function(x0, y0, x1, ...) seg <<- cbind(x0, x1), .package = "graphics")
  d <- plot(cal)
  expect_equal(nrow(seg), 3L)
  expect_true(all(seg[, 2] > 0.7))
  expect_identical(d$column, c("a", "b", "any column"))
})

test_that("a label that fits is never cut, however long", {
  grDevices::pdf(NULL, width = 12, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  lab <- "withdrawn stayed before trial"  # 29 characters
  expect_identical(rmoriebricklayer:::.bl_label_fit(lab, cex = 0.75)$labels, lab)
})

test_that("a panel key that wraps stays inside the outer margin", {
  grDevices::pdf(NULL, width = 5, height = 4)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 3), oma = c(2.4, 0, 0, 0))
  at <- numeric()
  local_mocked_bindings(mtext = function(text, side, outer, line, cex, ...) {
    at <<- c(at, line + cex / graphics::par("cex"))
  },
  .package = "graphics")
  rmoriebricklayer:::.bl_panel_key(c("A: Concentration-response, NO2 (all_cause_mortality)",
                                     "B: NO2: PAF 2.7%, 137 attributable", "C: Concentration curve (index -0.065)"))
  expect_true(all(at <= 2.4))
})

test_that("the panel is the plot region filled, crossed by white major and minor lines", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(0:10, 0:10, type = "n")
  r <- NULL
  hs <- list()
  vs <- list()
  local_mocked_bindings(rect = function(...) r <<- list(...),
                        abline = function(...) {
                          a <- list(...)
                          if (!is.null(a$h)) hs[[length(hs) + 1L]] <<- list(at = a$h, col = a$col, lwd = a$lwd)
                          if (!is.null(a$v)) vs[[length(vs) + 1L]] <<- list(at = a$v, col = a$col, lwd = a$lwd)
                        }, .package = "graphics")
  rmoriebricklayer:::.bl_grid(NULL)
  expect_identical(r$col, "#EEF1F6")
  expect_equal(hs[[2]]$at, graphics::axTicks(2))
  expect_equal(hs[[2]]$lwd, 1.4)
  expect_equal(hs[[1]]$at, graphics::axTicks(2)[-1] - diff(graphics::axTicks(2)) / 2)
  expect_identical(hs[[2]]$col, "white")
  # across the other way for side = "x"
  hs <- list()
  vs <- list()
  rmoriebricklayer:::.bl_grid(NULL, side = "x")
  expect_equal(vs[[2]]$at, graphics::axTicks(1))
  expect_equal(hs[[1]]$lwd, 0.6)
  # no panel colour: grey lines on white; grid off: nothing but the fill
  withr::local_options(rmoriebricklayer.plot = list(panel = NA))
  r <- NULL
  hs <- list()
  rmoriebricklayer:::.bl_grid(NULL)
  expect_null(r)
  expect_identical(hs[[1]]$col, "#DDDDDD")
  hs <- list()
  expect_false(rmoriebricklayer:::.bl_grid(FALSE))
  expect_length(hs, 0L)
})

test_that("bars are drawn on the panel, with room for and a label at each end", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  said <- NULL
  local_mocked_bindings(text = function(x, y, labels, pos = NULL, ...) said <<- list(labels, pos),
                        .package = "graphics")
  m <- rmoriebricklayer:::.bl_barplot(c(3, -2, 5), names.arg = c("a", "b", "c"), col = "red", border = NA)
  expect_length(m, 3L)
  expect_identical(said[[1]], c("3", "-2", "5"))
  expect_identical(said[[2]], c(3, 1, 3))
  # the axis runs past the longest bar and below the most negative one
  usr <- graphics::par("usr")
  expect_gt(usr[4], 5.5)
  expect_lt(usr[3], -2.5)
  # the panel was drawn once: the method's own .bl_grid() call after the bars is skipped
  expect_true(rmoriebricklayer:::.bl_grid(NULL))
  expect_false(isTRUE(rmoriebricklayer:::.bl_state$panel_done))
  # horizontal, labelled to the side; a limit the caller set is kept
  said <- NULL
  rmoriebricklayer:::.bl_barplot(c(1, -1), horiz = TRUE, xlim = c(-4, 4), col = "red")
  expect_identical(said[[2]], c(4, 2))
  expect_equal(graphics::par("usr")[1:2], c(-4, 4))
  # too many bars to label
  said <- NULL
  rmoriebricklayer:::.bl_barplot(1:30, col = "red")
  expect_null(said)
  rmoriebricklayer:::.bl_barplot(1:3, col = "red", labels = FALSE)
  expect_null(said)
})

test_that("a line has its fill, halo and labelled end; a dense one drops its points", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(c(0, 50), c(0, 10), type = "n")
  pts <- 0L
  poly <- 0L
  said <- NULL
  local_mocked_bindings(points = function(x, ...) pts <<- pts + length(x),
                        polygon = function(...) poly <<- poly + 1L,
                        text = function(x, y, labels, ...) said <<- labels, .package = "graphics")
  rmoriebricklayer:::.bl_line(1:3, c(2, 4, 6), "red")
  expect_equal(pts, 4L)  # three points and the emphasised end
  expect_equal(poly, 1L)
  expect_identical(said, "6")
  pts <- 0L
  rmoriebricklayer:::.bl_line(1:40, seq(0, 1, length.out = 40), "red", fill = FALSE, label = FALSE)
  expect_equal(pts, 1L)  # the end only
  pts <- 0L
  rmoriebricklayer:::.bl_line(1:3, c(1, 2, 3), "red", points = FALSE, label = FALSE)
  expect_equal(pts, 0L)
  expect_null(rmoriebricklayer:::.bl_line(NA_real_, NA_real_, "red"))
})

test_that("a drift calibration takes one colour for every row when asked", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  cal <- structure(list(columns = data.frame(column = c("a", "b"), false_alarm_rate = c(0, 1 / 3)),
                        any_flag = 1 / 3, alpha = 0.01, n = 3L), class = "rmbl_drift_calibration")
  bg <- NULL
  local_mocked_bindings(points = function(x, y, pch = NULL, bg = NULL, ...) bg <<- bg, .package = "graphics")
  d <- plot(cal, col = "purple")
  expect_identical(bg, rep("purple", 3L))
  expect_equal(d$lower[2], stats::binom.test(1, 3)$conf.int[1])
})
