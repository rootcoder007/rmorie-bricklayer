# Atmospheric dispersion: every formula recomputed in the test body.

test_that("pg_sigmas follows the Briggs fits for rural and urban classes", {
  x <- c(100, 2500)
  r <- pg_sigmas(x, "C")
  expect_equal(r$sigma_y, 0.11 * x / sqrt(1 + 1e-4 * x), tolerance = 1e-12)
  expect_equal(r$sigma_z, 0.08 * x / sqrt(1 + 2e-4 * x), tolerance = 1e-12)
  expect_equal(pg_sigmas(x, "A", "urban")$sigma_z, 0.24 * x * sqrt(1 + 1e-3 * x), tolerance = 1e-12)
  expect_equal(pg_sigmas(x, "a")$sigma_y, 0.22 * x / sqrt(1 + 1e-4 * x), tolerance = 1e-12)
  expect_equal(pg_sigmas(1000, "F")$sigma_z, 0.016 * 1000 * (1 + 0.0003 * 1000)^-1, tolerance = 1e-12)
  expect_error(pg_sigmas(100, "G"), "Pasquill")
  expect_error(pg_sigmas(100, c("A", "B")), "Pasquill")
  expect_error(pg_sigmas(100, "D", "suburban"), "rural")
})

test_that("briggs_plume_rise: buoyant branches, stable branch, transitional rise", {
  F_ <- 9.80616 * 12 * (420 - 285) / (4 * 420)
  r <- briggs_plume_rise(c(10, 1e5), 4, diameter = 1, exit_velocity = 12, stack_temp = 420, ambient_temp = 285)
  expect_equal(r$flux, F_)
  expect_equal(r$rise, c(1.6 * F_^(1 / 3) * 10^(2 / 3) / 4, 21.425 * F_^0.75 / 4), tolerance = 1e-12)
  expect_equal(r$x_final, 49 * F_^(5 / 8), tolerance = 1e-12)
  # a hot, wide stack has F >= 55 and takes the second buoyant branch
  big <- briggs_plume_rise(1e5, 4, diameter = 3, exit_velocity = 20, stack_temp = 500, ambient_temp = 285)
  Fb <- 9.80616 * 20 * 9 * (500 - 285) / (4 * 500)
  expect_true(Fb >= 55)
  expect_equal(big$final_rise, 38.71 * Fb^0.6 / 4, tolerance = 1e-12)
  expect_equal(big$x_final, 119 * Fb^0.4, tolerance = 1e-12)
  s <- 9.80616 * 0.02 / 285
  st <- briggs_plume_rise(1e5, 4, diameter = 1, exit_velocity = 12, stack_temp = 420, ambient_temp = 285,
                          stability = "E")
  expect_equal(st$final_rise, 2.6 * (F_ / (4 * s))^(1 / 3), tolerance = 1e-12)
  expect_equal(st$x_final, 2.0715 * 4 / sqrt(s), tolerance = 1e-12)
  sf <- briggs_plume_rise(1e5, 4, diameter = 1, exit_velocity = 12, stack_temp = 420, ambient_temp = 285,
                          stability = "F")
  expect_equal(sf$final_rise, 2.6 * (F_ / (4 * 9.80616 * 0.035 / 285))^(1 / 3), tolerance = 1e-12)
  custom <- briggs_plume_rise(1e5, 4, 1, 12, 420, 285, stability = "F", dtheta_dz = 0.01)
  expect_equal(custom$final_rise, 2.6 * (F_ / (4 * 9.80616 * 0.01 / 285))^(1 / 3), tolerance = 1e-12)
  expect_error(briggs_plume_rise(10, 0, 1, 12, 420, 285), "wind speed")
})

test_that("gaussian_plume and gaussian_puff reproduce their closed forms", {
  s <- pg_sigmas(800, "D")
  expect_equal(gaussian_plume(10, 3, 0, rbind(c(800, 0, 0)))[1], 10 / (pi * 3 * s$sigma_y * s$sigma_z),
               tolerance = 1e-14)
  # upwind receptors see nothing; a list of receptors is accepted
  expect_equal(gaussian_plume(10, 3, 0, list(c(-5, 0, 0), c(800, 0, 0)))[1], 0)
  # a mixing lid adds image terms; they matter once the plume has grown to the lid's scale
  # (class A at 5 km: sigma_z = 1000 m against a 300 m lid), and not before
  no_lid <- gaussian_plume(10, 3, 50, rbind(c(5000, 0, 0)), stability = "A")
  lid <- gaussian_plume(10, 3, 50, rbind(c(5000, 0, 0)), stability = "A", mixing_height = 300)
  expect_true(lid > no_lid)
  near <- gaussian_plume(10, 3, 50, rbind(c(200, 0, 0)), stability = "D")
  near_lid <- gaussian_plume(10, 3, 50, rbind(c(200, 0, 0)), stability = "D", mixing_height = 300)
  expect_equal(near, near_lid, tolerance = 1e-12)
  # the image sum is the formula
  sz <- pg_sigmas(5000, "A")$sigma_z
  v <- exp(-(0 - 50)^2 / (2 * sz^2)) + exp(-(0 + 50)^2 / (2 * sz^2))
  for (j in 1:3) for (sgn in c(1, -1)) {
    off <- 2 * sgn * j * 300
    v <- v + exp(-(0 - 50 + off)^2 / (2 * sz^2)) + exp(-(0 + 50 + off)^2 / (2 * sz^2))
  }
  expect_equal(lid, 10 / (2 * pi * 3 * pg_sigmas(5000, "A")$sigma_y * sz) * v, tolerance = 1e-12)
  s2 <- pg_sigmas(600, "B", "urban")
  sy <- s2$sigma_y
  sz <- s2$sigma_z
  v <- exp(-49 / (2 * sz^2)) + exp(-169 / (2 * sz^2))
  want <- 5 / ((2 * pi)^1.5 * sy^2 * sz) * exp(-2500 / (2 * sy^2)) * exp(-49 / (2 * sy^2)) * v
  expect_equal(gaussian_puff(5, 2, 10, rbind(c(550, 7, 3)), 300, stability = "B", setting = "urban"), want,
               tolerance = 1e-12)
  expect_error(gaussian_plume(10, 3, 0, matrix(1:4, ncol = 2)), "receptors")
  expect_error(gaussian_plume(10, 3, 0, c(1, 2, 3, 4)), "receptors")
  expect_error(gaussian_plume(10, 3, 0, list(c(1, 2))), "receptors")
  expect_error(gaussian_plume(10, 3, 0, rbind(c(NA, 0, 0))), "receptors")
  # a data frame of receptors works like a matrix
  expect_equal(gaussian_plume(10, 3, 0, data.frame(x = 800, y = 0, z = 0)),
               gaussian_plume(10, 3, 0, rbind(c(800, 0, 0))))
})

test_that("advection_diffusion_2d: pure advection shifts, pure diffusion spreads, source adds", {
  c0 <- matrix(0, 6, 6)
  c0[3, 4] <- 1
  expect_equal(advection_diffusion_2d(c0, 1, 0, 0, 0, 1, 1, 1, 1)$field[4, 4], 1)
  d <- advection_diffusion_2d(c0, 0, 0, 0.1, 0.2, 1, 1, 1, 1)
  expect_equal(c(d$field[3, 4], d$field[2, 4], d$field[3, 5]), c(0.4, 0.1, 0.2), tolerance = 1e-15)
  expect_equal(d$diffusion_number, 2 * (0.1 + 0.2))
  expect_equal(d$cfl, 0)
  # a negative velocity takes the other upwind difference: the mass moves the other way
  n <- advection_diffusion_2d(c0, -1, 0, 0, 0, 1, 1, 1, 1)
  expect_equal(n$field[2, 4], 1)
  expect_equal(n$field[3, 4], 0)
  expect_equal(n$cfl, 1)
  m <- advection_diffusion_2d(c0, 0, -1, 0, 0, 1, 1, 1, 1)$field
  expect_equal(m[3, 3], 1)
  # a source adds source * dt inside the domain
  src <- matrix(0, 6, 6)
  src[4, 4] <- 2
  withsrc <- advection_diffusion_2d(matrix(0, 6, 6), 0, 0, 0, 0, 1, 1, 0.5, 1, source = src)
  expect_equal(withsrc$field[4, 4], 1)
  expect_equal(withsrc$mass, 1)
  expect_error(advection_diffusion_2d(c0, 0, 0, 0, 0, 1, 1, 1, 1, source = matrix(0, 2, 2)), "dimensions")
})

test_that("lagrangian_particles: the random walk, the normals seam, and the counting grid", {
  r <- lagrangian_particles(7, 1, 2, 0.8, 0.1, 0.5, 0.3, 0.7, 3, seed = 5)
  x <- rep(1, 7)
  for (k in 0:2) x <- x + 0.8 * 0.7 + sqrt(2 * 0.5 * 0.7) * rmoriebricklayer:::.rmbl_normals(7, 5, 2 * k)
  expect_equal(r$x, x, tolerance = 1e-12)
  expect_equal(r$mean_x, mean(x))
  # the default normals are standard normal: large-sample moments
  z <- rmoriebricklayer:::.rmbl_normals(20000, 1, 0)
  expect_lt(abs(mean(z)), 0.03)
  expect_lt(abs(stats::sd(z) - 1), 0.03)
  expect_equal(rmoriebricklayer:::.rmbl_normals(0, 1, 0), numeric(0))
  # a user-supplied generator is used verbatim
  zeros <- function(n, seed, stream) rep(0, n)
  det <- lagrangian_particles(3, 0, 0, 1, 2, 0.5, 0.5, 1, 4, normals = zeros)
  expect_equal(det$x, rep(4, 3))
  expect_equal(det$y, rep(8, 3))
  # the grid counts particles into cells, normalised to a density
  g <- lagrangian_particles(10, 0.5, 0.5, 0, 0, 0, 0, 1, 1, grid = c(0, 1, 0, 1, 2, 2), normals = zeros)
  expect_equal(dim(g$concentration), c(2, 2))
  expect_equal(g$concentration[2, 2], 10 / (10 * 0.5 * 0.5))
  expect_equal(sum(g$concentration) * 0.5 * 0.5, 1)
  # particles outside the grid are not counted
  out <- lagrangian_particles(4, 5, 5, 0, 0, 0, 0, 1, 1, grid = c(0, 1, 0, 1, 2, 2), normals = zeros)
  expect_equal(sum(out$concentration), 0)
  expect_error(lagrangian_particles(0, 0, 0, 1, 1, 1, 1, 1, 1), "positive")
  expect_error(lagrangian_particles(2, 0, 0, 1, 1, 1, 1, 1, 1, grid = 1:3), "grid")
})

test_that("receptors as a plain vector of x, y, z triples", {
  v <- gaussian_plume(q = 100, u = 4, h = 50, receptors = c(1000, 0, 0, 2000, 50, 0), stability = "D")
  m <- gaussian_plume(q = 100, u = 4, h = 50, receptors = rbind(c(1000, 0, 0), c(2000, 50, 0)), stability = "D")
  expect_equal(v, m)
  expect_error(gaussian_plume(q = 100, u = 4, h = 50, receptors = c(1000, 0), stability = "D"), "receptor")
})
