# Atmospheric dispersion: every formula recomputed in the test body.

test_that("pgsig follows the Briggs fits for rural and urban classes", {
  x <- c(100, 2500)
  r <- pgsig(x, "C")
  expect_equal(r$sigmay, 0.11 * x / sqrt(1 + 1e-4 * x), tolerance = 1e-12)
  expect_equal(r$sigmaz, 0.08 * x / sqrt(1 + 2e-4 * x), tolerance = 1e-12)
  expect_equal(
    pgsig(x, "A", "urban")$sigmaz,
    0.24 * x * sqrt(1 + 1e-3 * x),
    tolerance = 1e-12
  )
  expect_equal(
    pgsig(x, "a")$sigmay,
    0.22 * x / sqrt(1 + 1e-4 * x),
    tolerance = 1e-12
  )
  expect_equal(
    pgsig(1000, "F")$sigmaz,
    0.016 * 1000 * (1 + 0.0003 * 1000)^-1,
    tolerance = 1e-12
  )
  expect_error(pgsig(100, "G"), "Pasquill")
  expect_error(pgsig(100, c("A", "B")), "Pasquill")
  expect_error(pgsig(100, "D", "suburban"), "rural")
})

test_that("briggs: buoyant branches, stable branch, transitional rise", {
  F_ <- 9.80616 * 12 * (420 - 285) / (4 * 420)
  r <- briggs(c(10, 1e5), 4, diam = 1, exitvel = 12, stktmp = 420, ambtmp = 285)
  expect_equal(r$flux, F_, tolerance = 1e-8)
  expect_equal(
    r$rise,
    c(1.6 * F_^(1 / 3) * 10^(2 / 3) / 4, 21.425 * F_^0.75 / 4),
    tolerance = 1e-12
  )
  expect_equal(r$xfinal, 49 * F_^(5 / 8), tolerance = 1e-12)
  # a hot, wide stack has F >= 55 and takes the second buoyant branch
  big <- briggs(1e5, 4, diam = 3, exitvel = 20, stktmp = 500, ambtmp = 285)
  Fb <- 9.80616 * 20 * 9 * (500 - 285) / (4 * 500)
  expect_gte(Fb, 55)
  expect_equal(big$finalrise, 38.71 * Fb^0.6 / 4, tolerance = 1e-12)
  expect_equal(big$xfinal, 119 * Fb^0.4, tolerance = 1e-12)
  s <- 9.80616 * 0.02 / 285
  st <- briggs(
    1e5,
    4,
    diam = 1,
    exitvel = 12,
    stktmp = 420,
    ambtmp = 285,
    stab = "E"
  )
  expect_equal(st$finalrise, 2.6 * (F_ / (4 * s))^(1 / 3), tolerance = 1e-12)
  expect_equal(st$xfinal, 2.0715 * 4 / sqrt(s), tolerance = 1e-12)
  sf <- briggs(
    1e5,
    4,
    diam = 1,
    exitvel = 12,
    stktmp = 420,
    ambtmp = 285,
    stab = "F"
  )
  expect_equal(
    sf$finalrise,
    2.6 * (F_ / (4 * 9.80616 * 0.035 / 285))^(1 / 3),
    tolerance = 1e-12
  )
  custom <- briggs(1e5, 4, 1, 12, 420, 285, stab = "F", dthdz = 0.01)
  expect_equal(
    custom$finalrise,
    2.6 * (F_ / (4 * 9.80616 * 0.01 / 285))^(1 / 3),
    tolerance = 1e-12
  )
  expect_error(briggs(10, 0, 1, 12, 420, 285), "wind speed")
})

test_that("gplume and gspuff reproduce their closed forms", {
  s <- pgsig(800, "D")
  expect_equal(
    gplume(10, 3, 0, rbind(c(800, 0, 0)))[1],
    10 / (pi * 3 * s$sigmay * s$sigmaz),
    tolerance = 1e-14
  )
  # upwind receptors see nothing; a list of receptors is accepted
  expect_equal(
    gplume(10, 3, 0, list(c(-5, 0, 0), c(800, 0, 0)))[1],
    0,
    tolerance = 1e-8
  )
  # a mixing lid adds image terms; they matter once the plume has grown to the
  # lid's scale (class A at 5 km: sigmaz = 1000 m against a 300 m lid), and not
  # before
  no_lid <- gplume(10, 3, 50, rbind(c(5000, 0, 0)), stab = "A")
  lid <- gplume(10, 3, 50, rbind(c(5000, 0, 0)), stab = "A", mixh = 300)
  expect_gt(lid, no_lid)
  near <- gplume(10, 3, 50, rbind(c(200, 0, 0)), stab = "D")
  near_lid <- gplume(10, 3, 50, rbind(c(200, 0, 0)), stab = "D", mixh = 300)
  expect_equal(near, near_lid, tolerance = 1e-12)
  # the image sum is the formula
  sz <- pgsig(5000, "A")$sigmaz
  v <- exp(-(0 - 50)^2 / (2 * sz^2)) + exp(-(0 + 50)^2 / (2 * sz^2))
  for (j in 1:3) {
    for (sgn in c(1, -1)) {
      off <- 2 * sgn * j * 300
      v <- v +
        exp(-(0 - 50 + off)^2 / (2 * sz^2)) +
        exp(-(0 + 50 + off)^2 / (2 * sz^2))
    }
  }
  expect_equal(
    lid,
    10 / (2 * pi * 3 * pgsig(5000, "A")$sigmay * sz) * v,
    tolerance = 1e-12
  )
  s2 <- pgsig(600, "B", "urban")
  sy <- s2$sigmay
  sz <- s2$sigmaz
  v <- exp(-49 / (2 * sz^2)) + exp(-169 / (2 * sz^2))
  want <- 5 /
    ((2 * pi)^1.5 * sy^2 * sz) *
    exp(-2500 / (2 * sy^2)) *
    exp(-49 / (2 * sy^2)) *
    v
  expect_equal(
    gspuff(5, 2, 10, rbind(c(550, 7, 3)), 300, stab = "B", set = "urban"),
    want,
    tolerance = 1e-12
  )
  expect_error(gplume(10, 3, 0, matrix(1:4, ncol = 2)), "rcpt")
  expect_error(gplume(10, 3, 0, c(1, 2, 3, 4)), "rcpt")
  expect_error(gplume(10, 3, 0, list(c(1, 2))), "rcpt")
  expect_error(gplume(10, 3, 0, rbind(c(NA, 0, 0))), "rcpt")
  # a data frame of receptors works like a matrix
  expect_equal(
    gplume(10, 3, 0, data.frame(x = 800, y = 0, z = 0)),
    gplume(10, 3, 0, rbind(c(800, 0, 0))),
    tolerance = 1e-8
  )
})

test_that(
  paste0(
    "advdif2d: pure advection shifts, pure ",
    "diffusion spreads, source adds"
  ),
  {
    c0 <- matrix(0, 6, 6)
    c0[3, 4] <- 1
    expect_equal(
      advdif2d(c0, 1, 0, 0, 0, 1, 1, 1, 1)$field[4, 4],
      1,
      tolerance = 1e-8
    )
    d <- advdif2d(c0, 0, 0, 0.1, 0.2, 1, 1, 1, 1)
    expect_equal(
      c(d$field[3, 4], d$field[2, 4], d$field[3, 5]),
      c(0.4, 0.1, 0.2),
      tolerance = 1e-15
    )
    expect_equal(d$difn, 2 * (0.1 + 0.2), tolerance = 1e-8)
    expect_equal(d$cfl, 0, tolerance = 1e-8)
    # a negative velocity takes the other upwind difference: the mass moves the
    # other way
    n <- advdif2d(c0, -1, 0, 0, 0, 1, 1, 1, 1)
    expect_equal(n$field[2, 4], 1, tolerance = 1e-8)
    expect_equal(n$field[3, 4], 0, tolerance = 1e-8)
    expect_equal(n$cfl, 1, tolerance = 1e-8)
    m <- advdif2d(c0, 0, -1, 0, 0, 1, 1, 1, 1)$field
    expect_equal(m[3, 3], 1, tolerance = 1e-8)
    # a source adds source * dt inside the domain
    src <- matrix(0, 6, 6)
    src[4, 4] <- 2
    withsrc <- advdif2d(matrix(0, 6, 6), 0, 0, 0, 0, 1, 1, 0.5, 1, source = src)
    expect_equal(withsrc$field[4, 4], 1, tolerance = 1e-8)
    expect_equal(withsrc$mass, 1, tolerance = 1e-8)
    expect_error(
      advdif2d(c0, 0, 0, 0, 0, 1, 1, 1, 1, source = matrix(0, 2, 2)),
      "dimensions"
    )
  }
)

test_that("lagrprt: the random walk, the normals seam, and the counting grid", {
  r <- lagrprt(7, 1, 2, 0.8, 0.1, 0.5, 0.3, 0.7, 3, seed = 5)
  x <- rep(1, 7)
  for (k in 0:2) {
    x <- x +
      0.8 * 0.7 +
      sqrt(2 * 0.5 * 0.7) * .rmbl_normals(7, 5, 2 * k)
  }
  expect_equal(r$x, x, tolerance = 1e-12)
  expect_equal(r$mean_x, mean(x), tolerance = 1e-8)
  # the default normals are standard normal: large-sample moments
  z <- .rmbl_normals(20000, 1, 0)
  expect_lt(abs(mean(z)), 0.03)
  expect_lt(abs(stats::sd(z) - 1), 0.03)
  expect_equal(.rmbl_normals(0, 1, 0), numeric(0), tolerance = 1e-8)
  # a user-supplied generator is used verbatim
  zeros <- function(n, seed, stream) rep(0, n)
  det <- lagrprt(3, 0, 0, 1, 2, 0.5, 0.5, 1, 4, normals = zeros)
  expect_equal(det$x, rep(4, 3), tolerance = 1e-8)
  expect_equal(det$y, rep(8, 3), tolerance = 1e-8)
  # the grid counts particles into cells, normalised to a density
  g <- lagrprt(
    10,
    0.5,
    0.5,
    0,
    0,
    0,
    0,
    1,
    1,
    grid = c(0, 1, 0, 1, 2, 2),
    normals = zeros
  )
  expect_equal(dim(g$concentration), c(2, 2), tolerance = 1e-8)
  expect_equal(g$concentration[2, 2], 10 / (10 * 0.5 * 0.5), tolerance = 1e-8)
  expect_equal(sum(g$concentration) * 0.5 * 0.5, 1, tolerance = 1e-8)
  # particles outside the grid are not counted
  out <- lagrprt(
    4,
    5,
    5,
    0,
    0,
    0,
    0,
    1,
    1,
    grid = c(0, 1, 0, 1, 2, 2),
    normals = zeros
  )
  expect_equal(sum(out$concentration), 0, tolerance = 1e-8)
  expect_error(lagrprt(0, 0, 0, 1, 1, 1, 1, 1, 1), "positive")
  expect_error(lagrprt(2, 0, 0, 1, 1, 1, 1, 1, 1, grid = 1:3), "grid")
})

test_that("receptors as a plain vector of x, y, z triples", {
  v <- gplume(
    q = 100,
    u = 4,
    h = 50,
    rcpt = c(1000, 0, 0, 2000, 50, 0),
    stab = "D"
  )
  m <- gplume(
    q = 100,
    u = 4,
    h = 50,
    rcpt = rbind(c(1000, 0, 0), c(2000, 50, 0)),
    stab = "D"
  )
  expect_equal(v, m, tolerance = 1e-8)
  expect_error(
    gplume(q = 100, u = 4, h = 50, rcpt = c(1000, 0), stab = "D"),
    "receptor"
  )
})

test_that("dispersion errors name the user's argument, with the function", {
  expect_error(pgsig(100, stab = mean), "`stab` must be data")
  expect_error(
    briggs(10, 4, 1, 12, 420, 285, stab = mean),
    "`stab` must be data"
  )
  expect_error(pgsig(100, "Z"), "^pgsig: `stab` must be one of")
  expect_error(pgsig(100, "D", "town"), "^pgsig: `set` must be")
  expect_error(
    briggs(10, 4, diam = -1, exitvel = 12, stktmp = 420, ambtmp = 285),
    "^briggs: `diam` must be positive"
  )
  rc <- rbind(c(800, 0, 0))
  expect_error(gplume(10, 3, 0, rc, nimg = 1.5), "^gplume: `nimg` must be")
  expect_error(gplume(10, 3, 0, rc, nimg = 5000), "^gplume: `nimg` must be")
  expect_error(gplume(10, 3, 0, rc, mixh = -1), "^gplume: `mixh` must be")
  expect_error(gplume(10, 3, 0, c(1, 2)), "^gplume: `rcpt` must give")
  # every .ad_num() refusal carries the function's name
  expect_error(gplume(c(1, 2), 3, 0, rc), "^gplume: `q` must be a single")
  expect_error(gplume(NA, 3, 0, rc), "^gplume: `q` must be finite")
  expect_error(gplume(-1, 3, 0, rc), "^gplume: `q` must be at least")
  expect_error(gplume(1e305, 3, 0, rc), "^gplume: `q` must be below")
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

test_that("a dispersion field and particles print as boxes", {
  c0 <- matrix(0, 15, 15)
  c0[4, 8] <- 1
  f <- advdif2d(
    c0,
    u = 1,
    v = 0,
    kx = 0.5,
    ky = 0.5,
    dx = 1,
    dy = 1,
    dt = 0.2,
    nsteps = 20
  )
  expect_box(
    f,
    "Advection-diffusion after 20 steps",
    c("15 x 15 cells", "Stability number", "within the bound")
  )
  f$stable <- FALSE
  f$substeps <- 3L
  expect_box(f, "Advection-diffusion", c("3 sub-steps", "numerical explosion"))
  set.seed(2)
  p <- .lag_result(
    stats::rnorm(200, 10, 4),
    stats::rnorm(200),
    200L,
    c(-10, 30, -20, 20, 8, 8),
    1e8
  )
  expect_box(p, "Lagrangian particles", c("200", "8 x 8 cells", "Peak density"))
  q <- .lag_result(c(1, 2), c(3, 4), 2L, NULL, 1e8)
  txt <- expect_box(q, "Lagrangian particles", "x = 1.5, y = 3.5")
  expect_false(any(grepl("Grid", txt, fixed = TRUE)))
})
