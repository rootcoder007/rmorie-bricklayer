# battery: runs in CI and locally; CRAN runs the correctness core
testthat::skip_on_cran()
# Every plot method draws without error on a null device and returns the data
# it drew; palettes and options behave; the dispersion field helpers agree
# with the point functions they wrap.

with_dev <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

test_that("palettes and plot options", {
  expect_length(blpal(), 8L)
  expect_length(blpal("okabe", 11), 11L)
  expect_identical(blpal("grey", 2), c("#252525", "#636363"))
  expect_length(blpal("sequential", 7), 7L)
  expect_identical(blpal("diverging", 1), "#2166AC")
  expect_error(blpal("okabe", 0), "positive")
  expect_error(blpal("neon"), "must be one of")
  old <- plotopt()
  expect_identical(old$palette, "okabe")
  on.exit(options(rmoriebricklayer.plot = NULL), add = TRUE)
  expect_invisible(plotopt(palette = "grey", grid = FALSE))
  expect_identical(plotopt()$palette, "grey")
  expect_false(plotopt()$grid)
  expect_error(plotopt(size = 3), "plot options are")
  expect_error(plotopt(3), "plot options are")
  expect_error(plotopt(palette = "neon"), "must be one of")
  # a value the plots cannot use is refused, and nothing is stored
  expect_error(plotopt(grid = "x"), "`grid` must be TRUE or FALSE")
  expect_error(plotopt(grid = NA), "`grid` must be TRUE or FALSE")
  expect_error(plotopt(cex = -1), "`cex` must be one positive number")
  expect_error(plotopt(las = 7), "`las` must be 0, 1, 2 or 3")
  expect_error(plotopt(bg = "notacolour"), "`bg` must be one colour")
  expect_error(plotopt(panel = 1:2), "`panel` must be one colour, or NA")
  expect_false(plotopt()$grid)
  expect_invisible(plotopt(panel = NA, bg = "#FFFFFF", las = 0, cex = 1.2))
  expect_true(is.na(plotopt()$panel))
  # set by hand with options(): an unusable entry keeps its default
  set <- getOption("rmoriebricklayer.plot")
  options(rmoriebricklayer.plot = list(grid = "x", cex = 2, palette = "neon"))
  expect_true(plotopt()$grid)
  expect_identical(plotopt()$cex, 2)
  expect_identical(plotopt()$palette, "okabe")
  options(rmoriebricklayer.plot = set)
  with_dev({
    graphics::plot.new()
    expect_false(.bl_grid(NULL))
    expect_true(.bl_grid(TRUE))
    expect_true(.bl_grid(TRUE, side = "x"))
  })
  expect_identical(.bl_cols(3, col = "red"), rep("red", 3))
  # an all-missing interval chart still draws (a unit window) rather than
  # erroring
  with_dev(.bl_dot_interval(
    c("a", "b"),
    c(NA, NA),
    c(NA, NA),
    c(NA, NA),
    "m",
    "x",
    c("black", "black")
  ))
  with_dev(.bl_dot_interval("a", 2, 2, 2, "m", "x", "black"))
  expect_identical(
    .bl_cols(2, palette = "grey"),
    c("#252525", "#636363")
  )
})

test_that("stock and flow", {
  sf <- stkflow(
    days = c(13500, 14600, 15100),
    people = c(300, 320, 310),
    prd = 2021:2023,
    expo = 1e5
  )
  d <- with_dev(plot(sf))
  expect_named(d, c("period", "adp", "alos", "people", "days"))
  expect_identical(d$alos, sf$alos)
  d2 <- with_dev(plot(
    sf,
    what = c("flowrate", "stkrate"),
    col = "red",
    main = "x"
  ))
  expect_named(d2, c("period", "flowrate", "stkrate"))
  expect_error(with_dev(plot(sf, what = "nothing")), "must be one or more of")
})

test_that("period-over-period change", {
  # bases large enough for a percentage change
  big <- yoy(
    data.frame(year = 2019:2023, n = c(400, 420, 390, 460, 450)),
    value = "n",
    prd = "year"
  )
  d <- with_dev(plot(big))
  expect_identical(nrow(d), 5L)
  expect_identical(d$pctchg, big$pctchg)
  expect_true(any(is.finite(d$pctchg)))
  # small counts draw their percentages like any other
  small <- yoy(
    data.frame(year = 2019:2023, n = c(10, 12, 11, 15, 14)),
    value = "n",
    prd = "year"
  )
  ds <- with_dev(plot(small))
  expect_identical(ds$pctchg, small$pctchg)
  expect_identical(is.finite(ds$pctchg), c(FALSE, TRUE, TRUE, TRUE, TRUE))
  # only zero bases leave no percentage at all: the counts are drawn instead of
  # an empty frame
  y <- yoy(
    data.frame(year = 2019:2021, n = c(0, 0, 5)),
    value = "n",
    prd = "year"
  )
  expect_identical(with_dev(plot(y))$value, y$value)
  v <- with_dev(plot(y, what = "value", col = "black"))
  expect_identical(v$value, y$value)
  seg <- data.frame(
    year = rep(2021:2023, 2),
    g = rep(c("a", "b"), each = 3),
    n = c(500, 600, 700, 900, 800, 1000),
    stringsAsFactors = FALSE
  )
  yg <- yoy(seg, value = "n", prd = "year", by = "g")
  dg <- with_dev(plot(yg))
  expect_true(all(grepl("^(a|b): ", dg$label)))
  vg <- with_dev(plot(yg, what = "value"))
  expect_identical(nrow(vg), 6L)
  expect_identical(
    with_dev(plot(yg, col = "grey"))$verdict,
    as.character(yg$verdict)
  )
})

test_that("rates, shares and rate change", {
  d <- data.frame(
    division = rep(c("n", "e", "w"), 2),
    year = rep(2022:2023, each = 3),
    stops = c(120, 90, 60, 150, 85, 70),
    residents = c(1e4, 8e3, 5e3, 1e4, 8e3, 5e3),
    stringsAsFactors = FALSE
  )
  r <- rtcalc(
    d[d$year == 2023, ],
    count = "stops",
    pop = "residents",
    by = "division"
  )
  dr <- with_dev(plot(r))
  expect_identical(dr$rate, r$rate)
  expect_identical(
    nrow(with_dev(plot(rtcalc(d, count = "stops", pop = "residents")))),
    1L
  )
  s <- shrs(d[d$year == 2023, ], count = "stops", by = "division")
  expect_identical(with_dev(plot(s))$share, s$share)
  rc <- ratechg(
    d,
    count = "stops",
    pop = "residents",
    prd = "year",
    by = "division"
  )
  drc <- with_dev(plot(rc))
  expect_identical(drc$pctchg, rc$pctchg)
  rc0 <- ratechg(d, count = "stops", pop = "residents", prd = "year")
  expect_identical(nrow(with_dev(plot(rc0, col = "navy"))), nrow(rc0))
})

test_that("band sensitivity, drift calibration and drift", {
  b <- prsbands(c("0-17", "18-24", "25-44", "45+"))
  s <- bandsens(b, c(10, 20, 30, 40), caps = c(60, 70, 80, 90))
  expect_identical(with_dev(plot(s))$cap, s$cap)
  set.seed(1)
  dd <- data.frame(a = rnorm(400), b = sample(letters[1:3], 400, TRUE))
  cal <- drftcal(dd, n = 3L)
  pc <- with_dev(plot(cal))
  expect_identical(pc$column, c(cal$columns$column, "any column"))
  expect_identical(
    pc$falsealarmrate,
    c(cal$columns$falsealarmrate, cal$anyflag)
  )
  # the exact interval over the splits: 0 of 3 still allows
  # up to 1 - 0.025^(1/3)
  z <- which(pc$falsealarmrate == 0)[1]
  expect_equal(
    pc$upper[z],
    1 - 0.025^(1 / 3),
    tolerance = testthat::testthat_tolerance()
  )
  expect_true(all(
    pc$lower <= pc$falsealarmrate & pc$falsealarmrate <= pc$upper
  ))
  dr <- cpsdrft(dd, transform(dd, a = a + 3))
  pd <- with_dev(plot(dr))
  expect_setequal(pd$column, dr$columns$column)
  expect_identical(nrow(with_dev(plot(dr, col = "red"))), nrow(dr$columns))
})

test_that("Benford, power, falsification", {
  bf <- benfordtst(c(1, 12, 123, 1234, 2, 23, 3, 31, 4, 45, 5, 6, 7, 8, 9))
  d <- with_dev(plot(bf))
  expect_identical(d$expected, log10(1 + 1 / (1:9)))
  expect_equal(sum(d$observed), 1, tolerance = 1e-12)
  set.seed(2)
  dd <- data.frame(x = rnorm(60), y = rnorm(60))
  shift <- function(z, s) {
    z$y <- z$y + s * z$x
    z
  }
  pw <- cpspwr(
    dd,
    function(z) cor(z$x, z$y),
    inject = shift,
    trt = "x",
    sizes = c(0, 0.5),
    n = 19,
    reps = 3,
    seed = 1
  )
  expect_equal(with_dev(plot(pw))$size, c(0, 0.5))
  fk <- cpsfals(dd, function(z) cor(z$x, z$y), trt = "x", n = 29, seed = 1)
  expect_type(fk$permutation, "double")
  pf <- with_dev(plot(fk))
  expect_identical(nrow(pf), sum(is.finite(fk$permutation)))
  fk$permutation <- c(NA_real_, NaN)
  expect_identical(nrow(with_dev(plot(fk))), 0L)
})

test_that("frequencies, missingness, coverage, outliers, correlations", {
  ft <- freqtbl(
    data.frame(g = c("a", "b", "b", "c", "c", "c"), stringsAsFactors = FALSE),
    "g"
  )
  expect_identical(with_dev(plot(ft))$n, ft$n)
  expect_identical(nrow(with_dev(plot(ft, col = "red"))), nrow(ft))
  mp <- misspat(data.frame(a = c(1, NA, 3, NA), b = c(NA, NA, 1, 2)))
  expect_identical(with_dev(plot(mp))$n_rows, mp$n_rows)
  cov <- rgncov(c("a", "b", "c"), c(100, 200, 300), c(1L, 0L, 2L))
  expect_identical(with_dev(plot(cov))$hasunit, cov$hasunit)
  expect_identical(nrow(with_dev(plot(cov, col = "black"))), 3L)
  set.seed(4)
  d <- data.frame(h = rnorm(100), w = rnorm(100))
  d$h[1] <- 15
  o <- mahaoutl(d)
  po <- with_dev(plot(o))
  expect_true(po$outlier[po$row == 1])
  expect_identical(nrow(with_dev(plot(o, col = "red"))), 100L)
  tc <- topcors(data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20)))
  expect_identical(nrow(with_dev(plot(tc))), nrow(tc))
  ct <- cortbl(data.frame(a = 1:20, b = (1:20)^2, c = rev(1:20)))
  pc <- with_dev(plot(ct, col = "grey"))
  expect_identical(nrow(pc), 3L)
  expect_true(all(diff(abs(pc$correlation)) <= 1e-12))
})

test_that("rounding envelopes", {
  prev <- pubbnd(c(10, 20), rnd = 5)
  expect_s3_class(prev, "rmbl_bounds")
  expect_identical(with_dev(plot(prev))$value, prev$value)
  rownames(prev) <- c("north", "south")
  expect_identical(nrow(with_dev(plot(prev, col = "navy"))), 2L)
})

test_that("air pollution: curve, burden, equity, report", {
  crf <- crfno2(25)
  d <- with_dev(plot(crf))
  expect_identical(nrow(d), 200L)
  expect_identical(d$rr[d$exposure <= 10], rep(1, sum(d$exposure <= 10)))
  d2 <- with_dev(plot(crfpm25(20, y = "ihd"), exposure = c(0, 5.8, 20)))
  expect_identical(d2$rr[1:2], c(1, 1))
  expect_identical(d2$rr[3], 1 + 1.91 * (1 - exp(-0.14 * (20 - 5.8)^0.49)))
  b <- polbrdn(25, 1, 0.008, 1e6, poll = "NO2")
  pb <- with_dev(plot(b))
  expect_identical(pb$value, c(b$basecases, b$attrcases))
  eq <- expconcidx(
    data.frame(exposure = c(4, 1, 8, 2), income = c(2, 1, 4, 3)),
    "exposure",
    "income"
  )
  pe <- with_dev(plot(eq))
  expect_identical(pe$exposure[4], 1)
  eq$extra$curve <- NULL
  expect_error(with_dev(plot(eq)), "older object")
  r <- vrfpol("no2", demo = TRUE)
  pr <- with_dev(plot(r))
  expect_named(pr, c("crf", "burden", "plnkey"))
  r2 <- vrfpol("no2", expomean = 25, expoprev = 1)
  expect_named(with_dev(plot(r2, main = "x")), c("crf", "burden", "plnkey"))
  bad <- vrfpol("no2", expomean = Inf, expoprev = 1)
  expect_identical(with_dev(plot(bad))$status, "assumption_failure")
  err <- vrfpol("no2", expcsv = tempfile())
  expect_identical(with_dev(plot(err))$status, "error")
})

test_that("the footprint", {
  # long enough to measure: the CPU and memory emissions add to the total, all
  # in grams
  fp <- co2fp(
    for (i in 1:30) {
      sum(sqrt(seq_len(2e5)))
    },
    loc = "CA",
    cpupwrw = 45,
    memgb = 8
  )
  d <- with_dev(plot(fp))
  expect_identical(d$quantity, c("CPU", "memory", "total"))
  expect_identical(d$value[d$quantity == "total"], fp$co2eg)
  expect_equal(sum(d$value[d$quantity != "total"]), fp$co2eg, tolerance = 1e-8)
  # too short to time: the plot says so instead of drawing empty bars
  z <- fp
  z$co2eg <- 0
  z$enekwh <- list(cpu = 0, memory = 0, total = 0)
  expect_identical(with_dev(plot(z))$value, c(0, 0, 0))
})

test_that("fields and particles", {
  f <- plmfld(100, 5, 50, x = c(100, 500, 1000), y = c(-50, 0, 50))
  expect_s3_class(f, "rmbl_field")
  expect_identical(dim(f$field), c(3L, 3L))
  expect_identical(
    f$field[2, 2],
    gplume(100, 5, 50, data.frame(x = 500, y = 0, z = 0))
  )
  expect_identical(f$dx, 450) # the median step
  d <- with_dev(plot(f))
  expect_identical(nrow(d), 9L)
  expect_identical(d$value, as.vector(f$field))
  expect_identical(
    nrow(with_dev(plot(f, contours = 0, col = grDevices::grey.colors(5)))),
    9L
  )
  f1 <- plmfld(100, 5, 50, x = 500, y = 0)
  expect_true(is.na(f1$dx))
  expect_identical(nrow(with_dev(plot(f1))), 1L)
  c0 <- matrix(0, 11, 11)
  c0[6, 6] <- 1
  a <- advdif2d(c0, 0.1, 0.1, 0.1, 0.1, 1, 1, 0.5, 4)
  expect_identical(nrow(with_dev(plot(a))), 121L)
  p <- lagrprt(50, 0, 0, 1, 0.5, 1, 1, 1, 10, grid = c(-10, 30, -10, 20, 8, 6))
  expect_identical(nrow(with_dev(plot(p))), 50L)
  p0 <- lagrprt(50, 0, 0, 1, 0.5, 1, 1, 1, 10)
  expect_identical(nrow(with_dev(plot(p0, col = "black"))), 50L)
})

test_that("trend and the whole analysis", {
  ct <- cnttrnd(c(5, 7, 6, 9, 12, 11))
  expect_s3_class(ct, "rmbl_count_trend")
  d <- with_dev(plot(ct))
  expect_identical(d$fitted, ct$fitted)
  ct$data <- NULL
  expect_error(with_dev(plot(ct)), "older object")
  otis <- data.frame(
    year = rep(2020:2023, each = 2),
    g = rep(c("a", "b"), 4),
    n = c(10, 20, 12, 22, 11, 25, 15, 24),
    pop = rep(c(1000, 2000), 4),
    stringsAsFactors = FALSE
  )
  a <- anltab(otis, value = "n", prd = "year", by = "g", pop = "pop")
  out <- with_dev(plot(a))
  expect_named(out, c("change", "rates", "ratechg"))
  a0 <- anltab(otis, value = "n", prd = "year", by = "g")
  expect_named(with_dev(plot(a0)), "change")
  expect_length(with_dev(plot(a0, which = "rates")), 0L)
})

test_that("Lorenz and funnel plots", {
  x <- c(1, 1, 2, 3, 5, 8, 13)
  d <- with_dev(plotlrnz(x))
  expect_identical(d, lorenzc(x))
  expect_identical(
    nrow(with_dev(plotlrnz(lorenzc(x), main = "given"))),
    nrow(lorenzc(x))
  )
  hand <- data.frame(population = c(0.5, 1), value = c(0.2, 1))
  expect_identical(nrow(with_dev(plotlrnz(hand))), 3L)
  f <- with_dev(plotfnl(
    obs = c(4, 20, 50, 2),
    expd = c(5, 22, 40, 20),
    area = c("a", "b", "c", "d")
  ))
  expect_identical(f$ratio, c(4, 20, 50, 2) / c(5, 22, 40, 20))
  expect_true(f$outside[4])
  lim <- fnllim(c(5, 20, 22, 40), lvls = c(0.95, 0.998))
  outer <- lim[lim$level == 0.998, ]
  expect_identical(
    f$outside,
    f$ratio > outer$upper[match(f$expected, outer$expected)] |
      f$ratio < outer$lower[match(f$expected, outer$expected)]
  )
  expect_true(all(is.na(
    with_dev(plotfnl(c(4, 20), c(5, 22), col = "red"))$area
  )))
  expect_error(plotfnl(c(1, 2), c(1, 2, 3)), "same length")
})

test_that(
  paste0(
    "panel titles fit: letters and a key on a narrow device, full titles on ",
    "a wide one"
  ),
  {
    sf <- stkflow(
      days = c(13500, 14600, 15100),
      people = c(300, 320, 310),
      prd = 2021:2023
    )
    grDevices::pdf(NULL, width = 4, height = 3)
    narrow <- plot(sf)
    grDevices::dev.off()
    expect_gte(length(attr(narrow, "plnkey")), 1L)
    expect_match(attr(narrow, "plnkey")[1], "^A: ")
    grDevices::pdf(NULL, width = 20, height = 5)
    wide <- plot(sf)
    grDevices::dev.off()
    expect_length(attr(wide, "plnkey"), 0L)
    expect_false(.bl_state$active)
    # a long title in a single narrow plot wraps instead of overrunning
    grDevices::pdf(NULL, width = 3, height = 3)
    graphics::plot.new()
    t <- .bl_title(paste(
      rep("a wide title", 8),
      collapse = " "
    ))
    grDevices::dev.off()
    expect_match(t, "a wide title")
    grDevices::pdf(NULL, width = 5, height = 4)
    graphics::plot.new()
    expect_gt(
      .bl_left_margin(c(13500, 15100)),
      .bl_left_margin(c(1, 9))
    )
    expect_equal(.bl_left_margin(numeric(0)), 4.5)
    expect_gt(
      .bl_left_margin(
        labels = c("a very long row label", "b")
      ),
      4.5
    )
    r <- vrfpol("no2", demo = TRUE)
    rep <- plot(r)
    grDevices::dev.off()
    expect_type(rep$plnkey, "character")
  }
)

test_that("a long axis title shrinks or wraps instead of overrunning", {
  grDevices::pdf(NULL, width = 2.5, height = 3)
  graphics::plot.new()
  expect_identical(.bl_xlab("x"), "x")
  expect_identical(
    .bl_xlab(paste(
      rep("cumulative share of people", 3),
      collapse = " "
    )),
    paste(rep("cumulative share of people", 3), collapse = " ")
  )
  expect_null(.bl_xlab(NULL))
  grDevices::dev.off()
})

test_that(
  paste0(
    "an empty title draws nothing and string width falls back without a ",
    "device"
  ),
  {
    expect_null(.bl_title(NULL))
    expect_identical(.bl_title(""), "")
    grDevices::pdf(NULL)
    w <- .bl_strwidth("abcd")
    grDevices::dev.off()
    expect_true(is.finite(w))
    expect_gt(w, 0)
    # strwidth() cannot answer (no device, or a device that returns no width):
    # the width comes from the character height instead
    grDevices::pdf(NULL)
    testthat::local_mocked_bindings(
      strwidth = function(...) stop("no device"),
      .package = "graphics"
    )
    f <- .bl_strwidth("abcd", cex = 2)
    testthat::local_mocked_bindings(
      strwidth = function(...) NA_real_,
      .package = "graphics"
    )
    g <- .bl_strwidth("abcd", cex = 2)
    csi <- graphics::par("csi")
    grDevices::dev.off()
    expect_identical(f, 4 * 0.55 * csi * 2)
    expect_identical(g, f)
  }
)

test_that("axis titles wrap and shrink until every line fits, never cut", {
  grDevices::pdf(NULL, width = 2.2, height = 3)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(1:2)
  got <- NULL
  te <- environment()
  local_mocked_bindings(
    title = function(xlab = NULL, cex.lab = 1, ...) {
      assign("got", list(xlab, cex.lab), envir = te)
    },
    .package = "graphics"
  )
  .bl_xlab(
    "NO2 (micrograms per cubic metre) over the whole study period"
  )
  lines <- strsplit(got[[1]], "\n", fixed = TRUE)[[1]]
  # every word is kept
  expect_identical(
    paste(lines, collapse = " "),
    "NO2 (micrograms per cubic metre) over the whole study period"
  )
  expect_lte(length(lines), 3L) # two where they fit; a 2-inch panel needs three
  expect_true(all(
    graphics::strwidth(lines, units = "inches", cex = got[[2]]) <=
      graphics::par("pin")[1] * 0.98
  ))
})

test_that(
  paste0(
    "a row note fits its panel, falling ",
    "back to the part before the colon"
  ),
  {
    grDevices::pdf(NULL, width = 2, height = 3)
    on.exit(grDevices::dev.off(), add = TRUE)
    said <- NULL
    te <- environment()
    local_mocked_bindings(
      text = function(x, y, labels, cex = 1, ...) {
        assign("said", list(labels, cex), envir = te)
      },
      .package = "graphics"
    )
    .bl_dot_interval(
      c("a", "b"),
      c(NA, 5),
      c(NA, 1),
      c(NA, 9),
      "m",
      "x",
      c("red", "blue"),
      ref = 0,
      note = c("no percentage: previous period is zero", NA)
    )
    expect_identical(said[[1]], "no percentage")
    expect_gte(said[[2]], 0.6)
  }
)

test_that(
  paste0(
    "a drift calibration with no false alarms still draws each rate and its ",
    "interval"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    cal <- structure(
      list(
        columns = data.frame(
          column = c("a", "b"),
          falsealarmrate = c(0, 0),
          stringsAsFactors = FALSE
        ),
        anyflag = 0,
        alpha = 0.01,
        n = 3L
      ),
      class = "rmbl_drift_calibration"
    )
    seg <- NULL
    te <- environment()
    local_mocked_bindings(
      segments = function(x0, y0, x1, ...) {
        assign("seg", cbind(x0, x1), envir = te)
      },
      .package = "graphics"
    )
    d <- plot(cal)
    expect_identical(nrow(seg), 3L)
    expect_true(all(seg[, 2] > 0.7))
    expect_identical(d$column, c("a", "b", "any column"))
  }
)

test_that("a label that fits is never cut, however long", {
  grDevices::pdf(NULL, width = 12, height = 5)
  on.exit(grDevices::dev.off(), add = TRUE)
  lab <- "withdrawn stayed before trial" # 29 characters
  expect_identical(
    .bl_label_fit(lab, cex = 0.75)$labels,
    lab
  )
})

test_that("a panel key that wraps stays inside the outer margin", {
  grDevices::pdf(NULL, width = 5, height = 4)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 3), oma = c(2.4, 0, 0, 0))
  at <- numeric()
  te <- environment()
  local_mocked_bindings(
    mtext = function(text, side, outer, line, cex, ...) {
      assign("at", c(at, line + cex / graphics::par("cex")), envir = te)
    },
    .package = "graphics"
  )
  .bl_panel_key(c(
    "A: Concentration-response, NO2 (allcause)",
    "B: NO2: PAF 2.7%, 137 attributable",
    "C: Concentration curve (index -0.065)"
  ))
  expect_true(all(at <= 2.4))
})

test_that(
  paste0(
    "the panel is the plot region filled, crossed by white major and minor ",
    "lines"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::plot(0:10, 0:10, type = "n")
    r <- NULL
    hs <- list()
    vs <- list()
    te <- environment()
    local_mocked_bindings(
      rect = function(...) assign("r", list(...), envir = te),
      abline = function(...) {
        a <- list(...)
        if (!is.null(a$h)) {
          h <- list(at = a$h, col = a$col, lwd = a$lwd)
          assign("hs", c(hs, list(h)), envir = te)
        }
        if (!is.null(a$v)) {
          v <- list(at = a$v, col = a$col, lwd = a$lwd)
          assign("vs", c(vs, list(v)), envir = te)
        }
      },
      .package = "graphics"
    )
    .bl_grid(NULL)
    expect_identical(r$col, "#EEF1F6")
    expect_identical(hs[[2]]$at, graphics::axTicks(2))
    expect_equal(hs[[2]]$lwd, 1.4)
    expect_identical(
      hs[[1]]$at,
      graphics::axTicks(2)[-1] - diff(graphics::axTicks(2)) / 2
    )
    expect_identical(hs[[2]]$col, "white")
    # across the other way for side = "x"
    hs <- list()
    vs <- list()
    .bl_grid(NULL, side = "x")
    expect_identical(vs[[2]]$at, graphics::axTicks(1))
    expect_equal(hs[[1]]$lwd, 0.6)
    # no panel colour: grey lines on white; grid off: nothing but the fill
    withr::local_options(rmoriebricklayer.plot = list(panel = NA))
    r <- NULL
    hs <- list()
    .bl_grid(NULL)
    expect_null(r)
    expect_identical(hs[[1]]$col, "#DDDDDD")
    hs <- list()
    expect_false(.bl_grid(FALSE))
    expect_length(hs, 0L)
  }
)

test_that(
  paste0(
    "bars are drawn on the panel, with ",
    "room for and a label at each end"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    said <- NULL
    te <- environment()
    local_mocked_bindings(
      text = function(x, y, labels, pos = NULL, ...) {
        assign("said", list(labels, pos), envir = te)
      },
      .package = "graphics"
    )
    m <- .bl_barplot(
      c(3, -2, 5),
      names.arg = c("a", "b", "c"),
      col = "red",
      border = NA
    )
    expect_length(m, 3L)
    expect_identical(said[[1]], c("3", "-2", "5"))
    expect_identical(said[[2]], c(3, 1, 3))
    # the axis runs past the longest bar and below the most negative one
    usr <- graphics::par("usr")
    expect_gt(usr[4], 5.5)
    expect_lt(usr[3], -2.5)
    # the panel was drawn once: the method's own .bl_grid() call after the bars
    # is skipped
    expect_true(.bl_grid(NULL))
    expect_false(isTRUE(.bl_state$plndone))
    # horizontal, labelled to the side; a limit the caller set is kept
    said <- NULL
    .bl_barplot(
      c(1, -1),
      horiz = TRUE,
      xlim = c(-4, 4),
      col = "red"
    )
    expect_identical(said[[2]], c(4, 2))
    expect_identical(graphics::par("usr")[1:2], c(-4, 4))
    # too many bars to label
    said <- NULL
    .bl_barplot(1:30, col = "red")
    expect_null(said)
    .bl_barplot(1:3, col = "red", labels = FALSE)
    expect_null(said)
  }
)

test_that(
  paste0(
    "a line has its fill, halo and labelled ",
    "end; a dense one drops its points"
  ),
  {
    grDevices::pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    graphics::plot(c(0, 50), c(0, 10), type = "n")
    pts <- 0L
    poly <- 0L
    said <- NULL
    te <- environment()
    local_mocked_bindings(
      points = function(x, ...) assign("pts", pts + length(x), envir = te),
      polygon = function(...) assign("poly", poly + 1L, envir = te),
      text = function(x, y, labels, ...) assign("said", labels, envir = te),
      .package = "graphics"
    )
    .bl_line(1:3, c(2, 4, 6), "red")
    expect_identical(pts, 4L) # three points and the emphasised end
    expect_identical(poly, 1L)
    expect_identical(said, "6")
    pts <- 0L
    .bl_line(
      1:40,
      seq(0, 1, length.out = 40),
      "red",
      fill = FALSE,
      label = FALSE
    )
    expect_identical(pts, 1L) # the end only
    pts <- 0L
    .bl_line(
      1:3,
      c(1, 2, 3),
      "red",
      points = FALSE,
      label = FALSE
    )
    expect_identical(pts, 0L)
    expect_null(.bl_line(NA_real_, NA_real_, "red"))
  }
)

test_that("a drift calibration takes one colour for every row when asked", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  cal <- structure(
    list(
      columns = data.frame(
        column = c("a", "b"),
        falsealarmrate = c(0, 1 / 3),
        stringsAsFactors = FALSE
      ),
      anyflag = 1 / 3,
      alpha = 0.01,
      n = 3L
    ),
    class = "rmbl_drift_calibration"
  )
  bg <- NULL
  te <- environment()
  local_mocked_bindings(
    points = function(x, y, pch = NULL, bg = NULL, ...) {
      assign("bg", bg, envir = te)
    },
    .package = "graphics"
  )
  d <- plot(cal, col = "purple")
  expect_identical(bg, rep("purple", 3L))
  expect_identical(d$lower[2], stats::binom.test(1, 3)$conf.int[1])
})

# par() before and after a plot, on a fresh device (B1, B2)
.par_kept <- function(expr) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p0 <- graphics::par(c("col", "fg", "mar", "cex", "mfrow", "oma"))
  force(expr)
  p1 <- graphics::par(c("col", "fg", "mar", "cex", "mfrow", "oma"))
  expect_identical(p1, p0)
  expect_identical(p0$col, "black")
}

test_that("plots leave par('col') and par('mar') as they found them (B1, B2)", {
  set.seed(1)
  x <- c(stats::rnorm(30), stats::rnorm(30, 2))
  g <- rep(c("a", "b"), each = 30)
  .par_kept(plotecdf(c(3, 1, 2, 5, 4)))
  .par_kept(plotvln(x, g))
  .par_kept(plotrdg(x, g))
  .par_kept(plotsm(1:12, rep(1:4, 3), rep(c("a", "b", "c"), each = 4)))
  .par_kept(plotbump(1:6, rep(1:3, 2), rep(c("a", "b"), each = 3)))
  .par_kept(plotfnl(c(3, 8, 20), c(5, 10, 18), area = c("p", "q", "r")))
  y <- yoy(data.frame(year = 2019:2022, n = c(5, 7, 6, 9)), "n", "year")
  .par_kept(plot(y))
  # a panel grid reset cex: it comes back too
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(cex = 1.3)
  plotsm(1:8, rep(1:4, 2), rep(c("a", "b"), each = 4))
  expect_identical(graphics::par("cex"), 1.3)
})

test_that("a factor period is placed by its levels (B3)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  prd <- factor(c("late", "early", "mid"), levels = c("early", "mid", "late"))
  d <- plotbump(c(3, 1, 2), prd, c("a", "a", "a"))
  expect_identical(as.character(d$prd), c("early", "mid", "late"))
  h <- plothrz(c(3, 1, 2), prd)
  expect_identical(as.character(h$prd), c("early", "mid", "late"))
})

test_that("plotvln() and plotrdg() name a bad `bw` (B4)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  x <- c(1, 2, 4, 7, 8)
  expect_error(plotvln(x, bw = "wide"), "plotvln: `bw` must be one positive")
  expect_error(plotrdg(x, bw = -1), "plotrdg: `bw` must be one positive")
  expect_error(plotrdg(x, bw = c(1, 2)), "`bw` must be one positive number")
  expect_error(plotrdg(x, bw = NA_real_), "`bw` must be one positive number")
  expect_s3_class(plotrdg(x, bw = "SJ"), "data.frame")
  expect_s3_class(plotvln(x, bw = 0.5), "data.frame")
})

test_that("plotfnl() drops a point missing either count whole (B5)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- plotfnl(c(4, NA, 9), c(5, 10, NA), area = c("p", "q", "r"))
  expect_identical(d$area, "p")
  expect_identical(c(d$observed, d$expected), c(4, 5))
  d2 <- plotfnl(c(NA, 6, 9), c(5, 10, 8))
  expect_identical(d2$observed, c(6, 9))
  expect_identical(d2$expected, c(10, 8))
})

test_that(".bl_par_set() returns one parameter as a named list", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  old <- graphics::par("lty")
  op <- .bl_par_set(lty = "dashed")
  expect_identical(op, list(lty = old))
  expect_identical(graphics::par("lty"), "dashed")
  graphics::par(op)
  expect_identical(graphics::par("lty"), old)
})
