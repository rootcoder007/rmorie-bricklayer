# Search theory: rmorie parity on a grid of inputs, closed forms, refusals,
# print and plot.

.rm <- function(f) getExportedValue("rmorie", f)
.long <- c(
  invcube = "inverse_cube",
  definite = "definite",
  mbeta = "mbeta",
  random = "random"
)

test_that("every function matches rmorie's SearchTheory to 1e-12", {
  skip_if_not_installed("rmorie")
  xs <- c(-3, -0.7, 0, 0.2, 0.5, 1, 2.5, 10)
  for (md in c("invcube", "definite", "mbeta")) {
    for (W in c(0.3, 1, 4)) {
      for (m in c(0.4, 1)) {
        expect_equal(
          as.numeric(ltrlrng(xs, W, md, m)),
          .rm("LateralRange")(xs, W, .long[[md]], m),
          tolerance = 1e-12
        )
      }
    }
  }
  xg <- seq(-5, 5, by = 0.05)
  p <- ltrlrng(xg, 2)
  expect_equal(
    swpwdth(xg, p),
    .rm("SweepWidth")(xg, as.numeric(p)),
    tolerance = 1e-12
  )
  expect_identical(swpwdth(p), swpwdth(xg, p))
  cv <- c(0, 0.1, 0.5, 1, 1.7, 3, 8)
  for (md in c("random", "definite", "invcube")) {
    expect_equal(
      as.numeric(srchpod(cv, md)),
      .rm("SearchPod")(cv, .long[[md]]),
      tolerance = 1e-12
    )
  }
  for (md in c("invcube", "definite", "mbeta")) {
    for (S in c(0.6, 1.3, 3)) {
      for (sd in c(0, 0.25)) {
        expect_equal(
          pswppod(1, S, md, m = 0.8, navsd = sd, npts = 101, ntrk = 20),
          .rm("ParallelSweepPod")(
            1,
            S,
            .long[[md]],
            m = 0.8,
            nav_sd = sd,
            n_points = 101,
            n_tracks = 20
          ),
          tolerance = 1e-12
        )
      }
    }
  }
  expect_equal(
    pswppod(1, 1.3),
    .rm("ParallelSweepPod")(1, 1.3),
    tolerance = 1e-12
  )
  poc <- c(0.4, 0.3, 0.2, 0.05)
  for (pod in list(
    c(0.8, 0.5, 0, 0.3),
    rbind(c(0.8, 0.5, 0, 0.3), c(0.2, 0.6, 0.9, 0.1))
  )) {
    a <- srchscs(poc, pod)
    b <- .rm("SearchSuccess")(poc, pod)
    expect_equal(
      a[c("pos", "posarea", "pocupd", "cumpod")],
      unname(b[c("pos", "pos_by_area", "poc_updated", "cumulative_pod")]),
      tolerance = 1e-12,
      ignore_attr = TRUE
    )
  }
  xe <- seq(-4, 4, by = 0.5)
  ye <- seq(-3, 5, by = 1)
  for (cs in list(
    list("point", c(0.3, 1), NULL),
    list("line", c(-2, -1), c(3, 2)),
    list("area", c(-1, 0), c(2.5, 3.2))
  )) {
    for (sg in c(0.5, 1.5)) {
      a <- datumpmap(xe, ye, cs[[1]], cs[[2]], sg, cs[[3]], nodes = 32)
      b <- .rm("DatumProbabilityMap")(
        xe,
        ye,
        cs[[1]],
        cs[[2]],
        sg,
        cs[[3]],
        nodes = 32
      )
      expect_equal(a$poc, b$poc, tolerance = 1e-12)
      expect_equal(a$outside, b$outside, tolerance = 1e-12)
    }
  }
  for (sg in c(0.5, 2)) {
    for (E in c(0, 1, 30)) {
      a <- optcrcsrch(sg, 1.5, E)
      b <- .rm("OptimalCircularSearch")(sg, 1.5, E)
      expect_equal(
        a[c("radius", "pos", "cntrdns")],
        unname(b),
        tolerance = 1e-12,
        ignore_attr = TRUE
      )
    }
  }
  m <- datumpmap(xe, ye, sigma = 1.5)
  ar <- outer(diff(ye), diff(xe))
  for (E in c(0, 2, 15, 60)) {
    a <- opteffort(m, W = 0.8, effort = E)
    b <- .rm("OptimalEffortAllocation")(m$poc, ar, 0.8, E)
    expect_equal(
      a[c("effort", "coverage", "pod", "pos", "lambda")],
      unname(b),
      tolerance = 1e-12,
      ignore_attr = TRUE
    )
  }
  a <- opteffort(c(0.5, 0.2, 0.1), c(1, 2, 0.5), W = 1, effort = 3)
  b <- .rm("OptimalEffortAllocation")(c(0.5, 0.2, 0.1), c(1, 2, 0.5), 1, 3)
  expect_equal(
    a[c("effort", "coverage", "pod", "pos", "lambda")],
    unname(b),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )
})

test_that("closed forms and hand-checked values", {
  # inverse cube: 1 - exp(-1 / pi) half a sweep width off the track
  expect_equal(as.numeric(ltrlrng(0.5, 1)), 1 - exp(-1 / pi), tolerance = 1e-15)
  expect_equal(
    round(as.numeric(ltrlrng(c(0.5, 1, 2), 1)), 6),
    c(0.272623, 0.076494, 0.019698)
  )
  # its sweep width on [-L, L]: 2 (L p(L) + sqrt(pi a) erfc(sqrt(a) / L)), a =
  # W^2 / (4 pi)
  W <- 1.7
  L <- 40
  a <- W^2 / (4 * pi)
  xs <- seq(-L, L, length.out = 400001)
  exact <- 2 *
    (L *
      (1 - exp(-a / L^2)) +
      sqrt(pi * a) * 2 * stats::pnorm(-sqrt(2 * a) / L))
  expect_equal(swpwdth(ltrlrng(xs, W)), exact, tolerance = 1e-7)
  expect_equal(exact, W, tolerance = 0.02)
  # definite range and M-Beta curves sweep W
  xd <- seq(-3, 3, by = 0.001)
  expect_equal(swpwdth(ltrlrng(xd, 2, "definite")), 2, tolerance = 2e-3)
  expect_equal(swpwdth(ltrlrng(xd, 1, "mbeta", m = 0.5)), 1, tolerance = 2e-3)
  # random search 1 - exp(-C); definite min(C, 1); inverse cube erf(sqrt(pi) C /
  # 2)
  cv <- c(0, 0.5, 1, 2)
  expect_equal(as.numeric(srchpod(cv)), 1 - exp(-cv), tolerance = 1e-15)
  expect_equal(as.numeric(srchpod(cv, "definite")), c(0, 0.5, 1, 1))
  expect_equal(round(as.numeric(srchpod(1, "invcube")), 4), 0.7899)
  # parallel sweeps: inverse cube = erf form, definite range at S >= W is W / S
  expect_equal(
    pswppod(1, 1.3),
    as.numeric(srchpod(1 / 1.3, "invcube")),
    tolerance = 1e-12
  )
  expect_equal(pswppod(1, 2, "definite", npts = 2001), 0.5, tolerance = 1e-3)
  # an even number of points is raised to the next odd one
  expect_identical(pswppod(1, 1.3, npts = 100), pswppod(1, 1.3, npts = 101))
  expect_lt(
    pswppod(1, 1.3, navsd = 0.5, npts = 201),
    pswppod(1, 1.3, npts = 201) + 1e-12
  )
  # Bayes on three areas
  s <- srchscs(c(0.5, 0.3, 0.2), c(0.8, 0.5, 0))
  expect_equal(s$pos, 0.55)
  expect_equal(s$pocupd, c(0.1, 0.15, 0.2) / 0.45, tolerance = 1e-8)
  s2 <- srchscs(c(0.5, 0.5), rbind(c(0.5, 0), c(0.5, 0)))
  expect_equal(s2$cumpod, c(0.75, 0))
  expect_equal(s2$pocupd, c(0.2, 0.8))
  # a point datum on one cell [-1, 1]^2: (2 Phi(1) - 1)^2
  m1 <- datumpmap(c(-1, 1), c(-1, 1))
  expect_equal(m1$poc[1, 1], (2 * stats::pnorm(1) - 1)^2, tolerance = 1e-15)
  m <- datumpmap(c(-1, 0, 1), c(-1, 0, 1))
  expect_equal(round(c(m$poc[1, 1], m$outside), 6), c(0.116516, 0.533935))
  ma <- datumpmap(0:4, 0:2, "area", c(1, 0.5), end = c(3, 1.5))
  expect_equal(sum(ma$poc), 1, tolerance = 1e-8)
  expect_equal(
    ma$poc,
    rbind(c(0, 0.25, 0.25, 0), c(0, 0.25, 0.25, 0)),
    tolerance = 1e-8
  )
  # the segment's probability is that of its midpoint for a tiny line
  ml <- datumpmap(-3:3, -3:3, "line", c(0, 0), end = c(1e-9, 0))
  expect_equal(ml$poc, datumpmap(-3:3, -3:3)$poc, tolerance = 1e-8)
  # Koopman: u = 1 at effort pi sigma^2 / W gives POS 1 - 2 / e
  o <- optcrcsrch(1, 1, pi)
  expect_equal(o$pos, 1 - 2 / exp(1), tolerance = 1e-15)
  expect_equal(o$radius, sqrt(2), tolerance = 1e-15)
  expect_equal(round(optcrcsrch(1, 1, pi / 4)$pos, 6), 0.090204)
  # two equal cells share the effort; a fine grid approaches Koopman's circular
  # optimum
  expect_equal(
    opteffort(c(0.5, 0.5), c(1, 1), 1, 2)$effort,
    c(1, 1),
    tolerance = 1e-10
  )
  g <- seq(-6, 6, by = 0.2)
  fine <- opteffort(datumpmap(g, g), W = 1, effort = pi)
  expect_equal(fine$pos, 1 - 2 / exp(1), tolerance = 5e-3)
  # effort constant over cells is a restriction of Koopman's continuous optimum
  expect_lt(fine$pos, 1 - 2 / exp(1))
  expect_equal(sum(fine$effort), pi, tolerance = 1e-10)
  expect_identical(dim(fine$effort), c(length(g) - 1L, length(g) - 1L))
  # an effort beyond rmorie's bisection floor is still spent in full
  big <- opteffort(c(0.6, 0.4), c(1, 1), 1, 500)
  expect_equal(sum(big$effort), 500, tolerance = 1e-8)
  expect_equal(opteffort(c(0.6, 0.4), c(1, 1), 1, 0)$pos, 0, tolerance = 1e-8)
})

test_that("bad inputs are refused with the function named", {
  expect_error(ltrlrng(1, 1, "bogus"), "ltrlrng: `model` must be one of")
  expect_error(ltrlrng(1, -1), "ltrlrng: `W` must be positive")
  expect_error(ltrlrng(1, c(1, 2)), "`W` must be a single number")
  expect_error(ltrlrng("a", 1), "`x` must be numeric")
  expect_error(ltrlrng(factor(1), 1), "`x` must be numeric")
  expect_error(ltrlrng(TRUE, 1), "`x` must be numeric, not logical")
  expect_error(ltrlrng(numeric(), 1), "`x` must have at least one value")
  expect_error(ltrlrng(c(1, NA), 1), "`x` must be finite")
  expect_error(ltrlrng(NA, 1), "`x` must be finite")
  expect_error(ltrlrng(Inf, 1), "`x` must be finite")
  expect_error(ltrlrng(1, 1, "mbeta", m = 1.5), "`m` must be between 0 and 1")
  expect_error(
    swpwdth(c(2, 1), c(0, 1)),
    "swpwdth: `x` must hold at least two strictly increasing"
  )
  expect_error(swpwdth(1:3, c(0, 1)), "`p` must have one value per `x`")
  expect_error(swpwdth(1:2, c(0, 2)), "`p` must be between 0 and 1")
  expect_error(srchpod(-1), "srchpod: `coverage` must be at least 0")
  expect_error(pswppod(1, 0), "pswppod: `S` must be positive")
  expect_error(pswppod(1, 1, navsd = -1), "`navsd` must be at least 0")
  expect_error(pswppod(1, 1, npts = 3.5), "`npts` must be a whole number")
  expect_error(pswppod(1, 1, ntrk = 0), "`ntrk` must be between 1")
  expect_error(
    srchscs(c(0.8, 0.8), c(0.5, 0.5)),
    "srchscs: `poc` must sum to at most 1"
  )
  expect_error(
    srchscs(c(0, 0), c(0.5, 0.5)),
    "at least one cell with a positive"
  )
  expect_error(
    srchscs(c(0.5, 0.5), c(0.5, 0.5, 0.5)),
    "one value \\(or column\\) per area"
  )
  expect_error(
    srchscs(c(0.5, 0.5), c(0.5, -0.1)),
    "`pod` must be between 0 and 1"
  )
  expect_warning(
    {
      s <- srchscs(1, 1)
    },
    "POS = 1"
  )
  expect_true(is.na(s$pocupd))
  expect_error(datumpmap(1, 1:2), "datumpmap: `xedg` must hold at least two")
  expect_error(datumpmap(1:2, 1:2, center = 1), "`center` must be two numbers")
  expect_error(datumpmap(1:2, 1:2, "line"), "a line datum needs `end`")
  expect_error(
    datumpmap(1:2, 1:2, "line", end = 1),
    "`end` must be two numbers"
  )
  expect_error(
    datumpmap(1:2, 1:2, "area", end = c(0, 1)),
    "differ in x and in y"
  )
  expect_error(datumpmap(1:2, 1:2, sigma = 0), "`sigma` must be positive")
  expect_error(
    datumpmap(1:2, 1:2, "line", end = c(1, 1), nodes = 1),
    "`nodes` must be between 2 and 1000"
  )
  expect_error(datumpmap(1:2, 1:2, "volume"), "`datum` must be one of")
  expect_error(optcrcsrch(1, 1, -1), "optcrcsrch: `effort` must be at least 0")
  expect_error(
    opteffort(c(0.5, 0.5), W = 1, effort = 1),
    "opteffort: `area` must be given"
  )
  expect_error(
    opteffort(c(0.5, 0.5), 1, W = 1, effort = 1),
    "`area` must have one value per cell"
  )
  expect_error(
    opteffort(c(0.5, 0.5), c(1, 0), W = 1, effort = 1),
    "`area` must be positive"
  )
  expect_error(
    opteffort(c(0.5, 0.5), c(1, 1), W = 1, effort = 1, tol = 0),
    "`tol` must be positive"
  )
  expect_error(plot.rmbl_ltrlrng(1), "rmbl_ltrlrng object")
  expect_error(plot.rmbl_srchpod(1), "rmbl_srchpod object")
  expect_error(plot.rmbl_datummap(1), "rmbl_datummap object")
})

test_that("results print and plot", {
  p <- ltrlrng(seq(-30, 30), 2)
  expect_s3_class(p, "rmbl_ltrlrng")
  expect_type(p, "double")
  out <- capture.output(print(p))
  expect_true(any(grepl(
    "inverse cube model, sweep width W = 2",
    out,
    fixed = TRUE
  )))
  expect_true(any(grepl("and 41 more", out, fixed = TRUE)))
  expect_output(print(ltrlrng(1, 1, "mbeta", m = 0.5)), "m = 0.5")
  expect_output(print(srchpod(seq(0, 3, by = 0.1))), "and 11 more")
  expect_output(print(srchpod(1)), "random search model")
  expect_output(
    print(srchscs(c(0.5, 0.3), c(0.8, 0.5))),
    "POS 0.55 after 1 search"
  )
  expect_output(
    print(srchscs(c(0.5, 0.3), rbind(c(0.8, 0.5), c(0.1, 0.1)))),
    "after 2 searches"
  )
  m <- datumpmap(seq(-5, 5), seq(-5, 5), sigma = 2)
  expect_identical(dim(m$poc), c(10L, 10L))
  expect_named(
    m,
    c("poc", "outside", "xedg", "yedg", "datum", "center", "end", "sigma")
  )
  expect_output(print(m), "10 x 10 cells")
  expect_output(print(optcrcsrch(2, 1, 30)), "radius")
  a <- opteffort(m, W = 1, effort = 30)
  expect_output(print(a), "Optimal allocation of effort")
  big <- opteffort(
    datumpmap(seq(-5, 5, 0.5), seq(-5, 5, 0.5), sigma = 3),
    W = 1,
    effort = 300
  )
  expect_output(print(big), "more cells")
  pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  d <- plot(p)
  expect_named(d, c("x", "p"))
  expect_identical(nrow(d), 801L)
  d <- plot(srchpod(c(0.5, 1), "invcube"))
  expect_identical(unique(d$model), c("invcube", "random", "definite"))
  d <- plot(m)
  expect_named(d, c("x", "y", "poc"))
  expect_equal(sum(d$poc), sum(m$poc), tolerance = 1e-8)
  expect_silent(plot(datumpmap(0:4, 0:3, "line", c(0.5, 0.5), end = c(3, 2))))
  expect_silent(plot(datumpmap(0:4, 0:3, "area", c(0.5, 0.5), end = c(3, 2))))
  d <- plot(a)
  expect_named(d, c("x", "y", "effort"))
  expect_equal(sum(d$effort), 30, tolerance = 1e-10)
  d <- plot(opteffort(
    c(a = 0.5, b = 0.3, c = 0.2),
    c(1, 1, 1),
    W = 1,
    effort = 2
  ))
  expect_identical(d$cell, c("a", "b", "c"))
})

test_that("plot() of ltrlrng() checks `equiv` and leaves par() (B1)", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- ltrlrng(seq(-2, 2, by = 0.5), 2)
  expect_error(plot(p, equiv = "yes"), "`equiv` must be TRUE or FALSE")
  p0 <- graphics::par(c("col", "fg", "mar", "cex"))
  plot(p, equiv = TRUE)
  expect_identical(graphics::par(c("col", "fg", "mar", "cex")), p0)
})

# ---- printed boxes -----------------------------------------------------------

# format() gives the plain lines of one titled block; print() draws them as a
# box that fits an 80-column console, ASCII where the console takes no Unicode,
# and returns the object invisibly.
expect_box <- function(x, title, has = character()) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  txt <- format(x)
  expect_type(txt, "character")
  expect_true(grepl(title, txt[1L], fixed = TRUE), info = txt[1L])
  flat <- paste(txt, collapse = "\n")
  for (h in has) {
    expect_true(grepl(h, flat, fixed = TRUE), info = h)
  }
  out <- utils::capture.output(print(x))
  expect_output(expect_invisible(print(x)), "+-- ", fixed = TRUE)
  expect_identical(withr::with_output_sink(nullfile(), print(x)), x)
  expect_match(out[1L], "^\\+-- ")
  expect_match(out[length(out)], "^\\+-+\\+$")
  expect_true(all(nchar(out) == nchar(out[1L])))
  expect_true(all(nchar(out) <= 79L))
  invisible(out)
}

test_that("the search results print as boxes", {
  expect_box(
    ltrlrng(seq(-30, 30), 2),
    "Lateral range curve",
    c("inverse cube", "Sweep width W", "and 41 more", "area under")
  )
  expect_box(
    ltrlrng(1, 1, "mbeta", m = 0.5, navsd = 0.5),
    "Lateral range curve",
    c("m = 0.5", "navigation error sd 0.5")
  )
  expect_box(
    srchpod(1, "mbeta", m = 0.5),
    "Probability of detection",
    c("M-Beta", "M = 0.5")
  )
  expect_box(
    srchscs(c(0.5, 0.3), c(0.8, 0.5)),
    "Probability of success",
    c("Overall POS", "POS 0.55 after 1 search")
  )
  m <- datumpmap(seq(-5, 5), seq(-5, 5), sigma = 2)
  expect_box(m, "Datum probability map", c("10 x 10 cells", "likely cells"))
  expect_box(
    optcrcsrch(2, 1, 30),
    "Optimal search of a circular normal datum",
    c("radius", "chance")
  )
  expect_box(
    opteffort(m, W = 1, effort = 30),
    "Optimal allocation of effort",
    c("Cells searched", "more cells")
  )
})

test_that("srchpod() takes sweep width, effort and area for the coverage", {
  expect_equal(
    as.vector(srchpod(W = 0.6, effort = 12, area = 4, model = "invcube")),
    as.vector(srchpod(0.6 * 12 / 4, "invcube")),
    tolerance = 1e-12
  )
  expect_identical(
    attr(srchpod(W = 2, effort = c(1, 2), area = 4), "coverage"),
    c(0.5, 1)
  )
  m <- datumpmap(0:3, 0:2, center = c(1, 1))
  eff <- matrix(1:6, 2)
  pd <- srchpod(W = 0.5, effort = eff, area = m)
  expect_equal(attr(pd, "coverage"), 0.5 * as.vector(eff),
               tolerance = 1e-12)
  expect_error(srchpod(1, W = 0.6), "srchpod: give either `coverage`")
  expect_error(srchpod(W = 0.6, effort = 1), "srchpod: give `coverage`")
  expect_error(srchpod(), "srchpod: give `coverage`")
  expect_error(
    srchpod(W = 1, effort = 1:2, area = 1:3),
    "srchpod: `effort` and `area` must have the same length"
  )
  expect_error(srchpod(W = 1, effort = -1, area = 1), "srchpod: `effort`")
})

test_that("srchscs() takes a map and an allocation and returns the map", {
  m <- datumpmap(seq(-3, 3), seq(-3, 3), sigma = 1.5)
  a <- opteffort(m, W = 1, effort = 10)
  s <- srchscs(m, a)
  plain <- srchscs(as.vector(m$poc), as.vector(a$pod))
  expect_equal(s$pos, plain$pos, tolerance = 1e-12)
  expect_equal(as.vector(s$map$poc), plain$pocupd, tolerance = 1e-12)
  expect_s3_class(s$map, "rmbl_datummap")
  expect_equal(sum(s$map$poc) + s$map$outside, 1, tolerance = 1e-12)
  expect_null(plain$map)
  # a POD matrix laid out like the map is one search
  expect_equal(srchscs(m, a$pod)$pos, s$pos, tolerance = 1e-12)
  # the updated map plans the next search
  b <- opteffort(s$map, W = 1, effort = 10)
  expect_s3_class(b, "rmbl_opteffort")
  out <- format(s)
  expect_true(any(grepl("updated in $map", out, fixed = TRUE)))
  expect_true(any(grepl("The 20 most likely of 36 cells", out, fixed = TRUE)))
  expect_error(srchscs(m, c(0.5, 0.5)), "srchscs: `pod` must have one value")
})

test_that("the help page's own search runs step by step", {
  own <- datumpmap(seq(-3, 7), seq(-2, 8), center = c(2, 3), sigma = 1.5)
  walked <- matrix(0, nrow(own$poc), ncol(own$poc))
  walked[5:6, 5:6] <- 12
  pd <- srchpod(W = 0.6, effort = walked, area = own, model = "invcube")
  expect_equal(sum(pd > 0), 4L, tolerance = 1e-12)
  day1 <- srchscs(own, pd)
  expect_equal(day1$pos, sum(own$poc * as.vector(pd)), tolerance = 1e-12)
  expect_lt(sum(day1$map$poc[5:6, 5:6]), sum(own$poc[5:6, 5:6]))
  day2 <- opteffort(day1$map, W = 0.6, effort = 40)
  expect_equal(sum(day2$effort), 40, tolerance = 1e-8)
})
