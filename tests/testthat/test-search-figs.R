# The figures of Frost (1996), The Theory of Search: each draws, returns its
# data, and shows the values the book's text states.

test_that("every figure draws and returns what it drew", {
  tab <- srchfig()
  expect_identical(nrow(tab), 36L)
  expect_false(anyDuplicated(tab$fig) > 0L)
  expect_setequal(unique(tab$how), c("model", "schematic", "approximation"))
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  # 6-6 runs 1,250 optimisations; its own test draws it
  for (f in setdiff(tab$fig, "6-6")) {
    d <- expect_invisible(srchfig(f))
    expect_false(is.null(d), info = f)
  }
  expect_identical(srchfig(5, 8), srchfig("5-8"))
  expect_error(
    srchfig("9-9"),
    "srchfig: `fig` must be one of the book's figures"
  )
  expect_error(srchfig(5, 1.5), "`num` must be a whole number")
  expect_error(
    srchfig(c("3-1", "3-2")),
    "`fig` must be a single non-empty string"
  )
})

test_that("chapter 3: the containment values of the text", {
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  E <- sqrt(2 * log(2))
  expect_equal(E, 1.1774, tolerance = 1e-4)
  expect_equal(round(srchfig("3-2")$poc, 2), c(0.39, 0.47))
  p3 <- srchfig("3-3")$poc
  expect_equal(p3[1], 0.5, tolerance = 1e-12)
  expect_equal(round(p3[2], 4), 0.5791)
  # the book rounds E to 1.1774 before multiplying by 1.1: 0.6477 to its
  # rounding
  expect_equal(srchfig("3-5")$poc, c(0.5677, 0.6477), tolerance = 2e-4)
  # SSPM: POS of the first search with a 79% POD
  expect_equal(round(0.6477 * 0.79, 4), 0.5117)
  m <- srchfig("3-4")
  expect_equal(
    round(100 * m$poc, 2),
    rbind(c(1.42, 9.08, 1.42), c(9.08, 57.91, 9.08), c(1.42, 9.08, 1.42))
  )
  expect_equal(round(srchfig("3-9")$poc, 4), 0.7610)
  # within one standard deviation of a line datum
  ml <- datumpmap(0:1, c(-1, 1), "corridor", c(0, 0), end = c(1, 0))
  expect_equal(round(ml$poc[1, 1], 4), 0.6827)
  m10 <- srchfig("3-10")
  expect_equal(round(100 * m10$poc[, 1], 1), c(0.2, 2.2, 5.2, 2.2, 0.2))
  expect_equal(sd(as.vector(m10$poc[3, ])), 0)
  expect_equal(srchfig("3-12")$poc, matrix(0.05, 4, 5))
  m14 <- srchfig("3-14")
  expect_equal(100 * m14$poc[4, ], c(3, 4, 5, 6, 2))
  expect_equal(m14$outside, 0)
  d <- srchfig("3-13")
  expect_named(d, c("x", "y", "poc"))
})

test_that("chapter 4: sweep width is the area under every curve", {
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  for (f in c("4-2", "4-4", "4-5")) {
    d <- srchfig(f)
    expect_equal(
      sum(diff(d$x) * (d$p[-1] + d$p[-nrow(d)]) / 2),
      1,
      tolerance = 1e-6,
      info = f
    )
  }
  expect_equal(max(srchfig("4-4")$p), 0.5)
  expect_equal(max(srchfig("4-5")$p), 0.25)
  p41 <- srchfig("4-1")
  expect_length(p41, 4L)
  d <- p41[[4]]
  expect_equal(
    sum(diff(d$x) * (d$p[-1] + d$p[-nrow(d)]) / 2),
    1,
    tolerance = 0.02
  )
  # the inverse cube curve: areas A (missed inside W) and B (seen outside W) are
  # equal
  xs <- seq(0, 400, by = 0.0005)
  p <- as.numeric(ltrlrng(xs, 1))
  inn <- xs <= 0.5
  a <- sum(diff(xs[inn]) * ((1 - p[inn])[-1] + (1 - p[inn])[-sum(inn)]) / 2)
  b <- sum(diff(xs[!inn]) * (p[!inn][-1] + p[!inn][-sum(!inn)]) / 2)
  # the tail beyond 400: p(x) is about W^2 / (4 pi x^2) there
  expect_equal(a, b + 1 / (4 * pi * 400), tolerance = 1e-3)
  expect_named(srchfig("4-7"), c("x", "p"))
  # navigation error keeps the sweep width (Frost, equation 5-16)
  xn <- seq(-30, 30, by = 0.005)
  for (md in c("definite", "mbeta", "invcube")) {
    expect_equal(
      swpwdth(ltrlrng(xn, 1, md, m = 0.5, navsd = 0.6)),
      1,
      tolerance = 0.03,
      info = md
    )
  }
  expect_lt(as.numeric(ltrlrng(0, 1, navsd = 1)), as.numeric(ltrlrng(0, 1)))
  expect_equal(
    as.numeric(ltrlrng(0, 1, "definite", navsd = 1)),
    2 * stats::pnorm(0.5) - 1,
    tolerance = 1e-15
  )
})

test_that("chapter 5: the PODs the text computes", {
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(
    round(as.numeric(srchpod(c(0.5, 1, 2))), 4),
    c(0.3935, 0.6321, 0.8647)
  )
  expect_equal(as.numeric(srchpod(c(1, 2), "mbeta", m = 0.5)), c(0.75, 0.9375))
  expect_equal(
    round(as.numeric(srchpod(c(0.5, 1, 2), "mbeta", m = 0.25)), 4),
    c(0.4375, 0.6836, 0.8999)
  )
  expect_equal(as.numeric(srchpod(0.2, "mbeta", m = 0.25)), 0.2)
  expect_equal(
    round(as.numeric(srchpod(c(0.5, 1, 1.5), "invcube")), 2),
    c(0.47, 0.79, 0.94)
  )
  expect_equal(round(as.numeric(srchpod(1, "invcube")), 4), 0.7899)
  # coverage needed for a 79% POD: 0.79, 1.0 and 1.56
  need <- function(md) {
    stats::uniroot(
      function(cv) as.numeric(srchpod(cv, md)) - 0.7899,
      c(0.01, 5),
      tol = 1e-10
    )$root
  }
  expect_equal(
    round(c(need("definite"), need("invcube"), need("random")), 2),
    c(0.79, 1, 1.56)
  )
  # the M-Beta formula is the parallel sweep wherever tracks overlap a whole
  # number of times
  expect_equal(
    pswppod(1, 1, "mbeta", m = 0.5, npts = 2001),
    0.75,
    tolerance = 1e-3
  )
  expect_equal(
    pswppod(1, 0.5, "mbeta", m = 0.5, npts = 2001),
    0.9375,
    tolerance = 1e-3
  )
  between <- function(d, S) mean(d$pod[d$x > 0 & d$x < S])
  expect_equal(between(srchfig("5-3"), 2), 0.5, tolerance = 0.02)
  expect_equal(between(srchfig("5-4"), 1), 1)
  expect_equal(between(srchfig("5-6"), 2), 0.5, tolerance = 0.02)
  d <- srchfig("5-7")
  expect_setequal(unique(d$model), c("mbeta", "definite", "random"))
  expect_setequal(unique(d$m[d$model == "mbeta"]), c(0.5, 0.25))
  expect_equal(d$pod[d$model == "mbeta" & d$m == 0.5 & d$coverage == 1], 0.75)
  expect_identical(unique(srchfig("5-1")$model), "random")
  d9 <- srchfig("5-9")
  expect_identical(nrow(unique(d9[c("W", "navsd")])), 2L)
  # the book's peaks: about 100% under ideal conditions and about 31% under poor
  # ones
  expect_gt(max(d9$p[d9$cond == "ideal"]), 0.99)
  expect_equal(max(d9$p[d9$cond == "poor"]), 0.31, tolerance = 0.1)
  expect_named(srchfig("5-2"), c("x", "y"))
})

test_that("chapter 6: the optimal search squares the text reports", {
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_equal(round(srchfig("6-1")$poc, 4), c(1, 0.6094, 0.4630))
  expect_identical(srchfig("6-2"), srchfig("6-1"))
  # trials at coverage 0.5 and 1.5 with 4 E^2 of effort
  E <- sqrt(2 * log(2))
  sq <- function(f) (2 * stats::pnorm(f * E) - 1)^2
  # the book reads these from a four-place normal table
  expect_equal(sq(sqrt(2)), 0.8172, tolerance = 3e-4)
  expect_equal(sq(sqrt(2 / 3)), 0.4405, tolerance = 3e-4)
  o4 <- optsqr(4)
  expect_equal(round(o4$factor, 2), 1.02)
  expect_equal(
    round(c(o4$poc, o4$coverage, o4$pod, o4$pos), c(2, 2, 2, 3)),
    c(0.59, 0.96, 0.77, 0.458)
  )
  o2 <- optsqr(2)
  expect_equal(
    round(c(o2$factor, o2$poc, o2$coverage, o2$pod, o2$pos), 2),
    c(0.81, 0.44, 0.76, 0.66, 0.29)
  )
  o8 <- optsqr(8)
  expect_equal(
    round(c(o8$factor, o8$poc, o8$coverage, o8$pod, o8$pos), 2),
    c(1.29, 0.76, 1.21, 0.87, 0.66)
  )
  expect_named(
    o4,
    c(
      "search",
      "effort",
      "releff",
      "cumeff",
      "factor",
      "side",
      "poc",
      "coverage",
      "pod",
      "pos",
      "cumpos"
    )
  )
  expect_equal(optsqr(16, E = 2)$factor, o4$factor)
  expect_equal(optsqr(16, E = 2)$side, 2 * o4$factor * 2)
  s <- optsqr(c(4, 4))
  expect_equal(
    s$cumpos[2],
    1 - (1 - s$pos[1]) * (1 - s$pos[2]),
    tolerance = 1e-12
  )
  expect_gt(s$factor[2], s$factor[1])
  expect_lt(optsqr(4, "random")$pos, o4$pos)
  expect_equal(
    optsqr(4, "mbeta", m = 1)$pos,
    optsqr(4, "definite")$pos,
    tolerance = 1e-6
  )
  expect_error(optsqr(-1), "optsqr: `effort` must be positive")
  expect_error(optsqr(1, E = 0), "`E` must be positive")
  d3 <- srchfig("6-3")
  expect_setequal(unique(d3$model), c("invcube", "random"))
  expect_lte(max(d3$cumeff), 18)
  set.seed(5)
  before <- .Random.seed
  d6 <- srchfig("6-6")
  expect_identical(.Random.seed, before)
  expect_true(all(d6$cumeff <= 100 & d6$factor > 0))
  skip_on_cran()
  expect_identical(d6, srchfig("6-6"))
  expect_false(identical(d6, srchfig("6-6", seed = 2)))
})

test_that(
  paste0(
    "the general plot arguments and the new datums refuse what cannot be ",
    "drawn"
  ),
  {
    pdf(NULL)
    on.exit(grDevices::dev.off(), add = TRUE)
    m <- datumpmap(seq(-3, 3), seq(-3, 3))
    for (v in c("map", "persp", "both", "cells")) {
      expect_named(plot(m, view = v), c("x", "y", "poc"))
    }
    expect_error(plot(m, view = "globe"), "`view` must be one of")
    expect_error(
      plot(m, view = "cells", digits = 7),
      "`digits` must be between 0 and 6"
    )
    expect_error(
      plot(datumpmap(0:1, 0:1), view = "persp"),
      "at least two cells in x and in y"
    )
    expect_silent(plot(
      datumpmap(0:4, 0:3, "general", wts = matrix(1, 3, 4)),
      view = "both"
    ))
    expect_silent(plot(datumpmap(
      0:4,
      0:3,
      "general",
      wts = matrix(1:12, 3, 4)
    )))
    # inside a layout the caller set, "both" uses the next two panels and leaves
    # the layout as it was
    op <- graphics::par(mfrow = c(2L, 2L))
    plot(m, view = "both")
    expect_identical(graphics::par("mfrow"), c(2L, 2L))
    expect_identical(graphics::par("mfg")[1:2], c(1L, 2L))
    graphics::par(op)
    mv <- datumpmap(-3:3, 0:10, "corridor", c(0, 0), end = c(0, 10))
    expect_equal(mv$poc[, 4], rep(mv$poc[1, 4], 10))
    expect_equal(
      sum(mv$poc[1, ]) * 10,
      2 * stats::pnorm(3) - 1,
      tolerance = 1e-12
    )
    expect_error(
      datumpmap(0:2, 0:2, "corridor", c(0, 0), end = c(1, 1)),
      "must run along x or along y"
    )
    expect_error(
      datumpmap(0:2, 0:2, "corridor", c(0, 0), end = c(0, 0)),
      "`center` and `end` to differ"
    )
    expect_error(datumpmap(0:2, 0:2, "general"), "needs `wts`")
    expect_error(
      datumpmap(0:2, 0:2, "general", wts = matrix(1, 3, 2)),
      "one row per y cell \\(2\\)"
    )
    expect_error(
      datumpmap(0:2, 0:2, "general", wts = matrix(0, 2, 2)),
      "at least one positive weight"
    )
    expect_error(
      datumpmap(0:2, 0:2, "general", wts = matrix(-1, 2, 2)),
      "`wts` must be at least 0"
    )
    d <- plot(ltrlrng(0, 1, "mbeta", m = 0.5, navsd = 0.2), equiv = TRUE)
    expect_named(d, c("x", "p"))
    expect_named(
      plot(ltrlrng(0, 1, "definite"), spacing = 1.5),
      c("x", "p", "p2", "pod")
    )
    expect_error(plot(ltrlrng(0, 1), spacing = 0), "`spacing` must be positive")
    d <- plot(srchpod(1, "mbeta", m = 0.4), cmax = 3)
    expect_identical(max(d$coverage), 3)
    expect_identical(
      unique(d$model),
      c("mbeta", "random", "definite", "invcube")
    )
    expect_error(plot(srchpod(1), cmax = -1), "`cmax` must be positive")
    expect_error(
      plot(srchpod(1), models = "magic"),
      "`models` must be one or more of"
    )
    expect_output(print(ltrlrng(1, 1, navsd = 0.5)), "navigation error sd 0.5")
    expect_output(print(srchpod(1, "mbeta", m = 0.5)), "M = 0.5")
  }
)

test_that("every figure leaves the device layout as it found it", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  before <- graphics::par(c("mfrow", "oma", "mar"))
  for (f in srchfig()$fig) {
    srchfig(f)
    expect_identical(graphics::par(c("mfrow", "oma", "mar")), before, info = f)
  }
})

test_that("every figure's own-numbers recipe runs", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  tab <- srchfig()
  expect_identical(nrow(tab), 36L)
  expect_false(anyNA(tab$yours))
  for (i in seq_len(nrow(tab))) {
    expect_no_error(
      eval(parse(text = tab$yours[i]), envir = new.env()),
      message = tab$fig[i]
    )
  }
})
