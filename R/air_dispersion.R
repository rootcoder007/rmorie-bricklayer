# SPDX-License-Identifier: AGPL-3.0-or-later
# Atmospheric dispersion: Pasquill-Gifford sigmas, Briggs plume rise, Gaussian
# plume and puff, an explicit Eulerian solver and a Lagrangian random walk.
# The formulas are those of rmorie's AirDispersion module and morie's
# airdisp; only the random-number seam differs (see lagrangian_particles()).

#' Atmospheric dispersion: sigmas, plume rise, plume, puff, grid and particles
#'
#' \code{pg_sigmas()}: Briggs (1973) fits of the Pasquill-Gifford dispersion
#' coefficients by stability class A-F, rural
#' \code{sigma_y = a_y x (1 + 0.0001 x)^(-1/2)} (urban: 0.0004) and
#' \code{sigma_z = a_z x (1 + b_z x)^(e_z)}.
#' \code{briggs_plume_rise()}: buoyancy flux
#' \code{F = g v_s d^2 (T_s - T_a) / (4 T_s)}; final rise
#' \code{21.425 F^(3/4) / u} with \code{x_f = 49 F^(5/8)} when \code{F < 55},
#' else \code{38.71 F^(3/5) / u} with \code{x_f = 119 F^(2/5)}, for classes A-D;
#' \code{2.6 (F / (u s))^(1/3)} with \code{s = g (dtheta/dz) / T_a} and
#' \code{x_f = 2.0715 u / sqrt(s)} for E and F; transitional rise
#' \code{1.6 F^(1/3) x^(2/3) / u} before \code{x_f} (EPA ISC3).
#' \code{gaussian_plume()}: \code{Q / (2 pi u sigma_y sigma_z) exp(-y^2 / (2 sigma_y^2)) V},
#' with \code{V} the vertical term with ground reflection and, under a mixing
#' lid, \code{n_images} pairs of image terms.
#' \code{gaussian_puff()}: an instantaneous release with \code{sigma_x = sigma_y}
#' evaluated at the travel distance \code{u t}.
#' \code{advection_diffusion_2d()}: explicit upwind advection, central
#' diffusion, forward Euler, zero boundaries; stable when the reported
#' \code{cfl} is below 1 and \code{diffusion_number} below 1.
#' \code{lagrangian_particles()}: the random walk
#' \code{x + u dt + sqrt(2 K dt) xi} (Thomson 1987) with an optional counting
#' grid.
#'
#' @param x Downwind distance(s) in metres.
#' @param stability Pasquill stability class, one of \code{"A"} to \code{"F"}.
#' @param setting \code{"rural"} or \code{"urban"}.
#' @param u Wind speed in m/s (the x velocity for the grid models).
#' @param diameter,exit_velocity,stack_temp,ambient_temp Stack diameter (m),
#'   exit velocity (m/s), stack gas and ambient temperatures (K).
#' @param dtheta_dz Potential temperature gradient (K/m) for the stable
#'   classes; the defaults are 0.020 (E) and 0.035 (F).
#' @param g Gravitational acceleration.
#' @param q Emission rate (mass per second).
#' @param h Effective stack height (m).
#' @param receptors A matrix with columns x, y, z, or a list of length-3
#'   vectors.
#' @param mixing_height Mixing-lid height, or \code{NULL} for no lid.
#' @param n_images Number of lid image pairs.
#' @param mass Puff mass.
#' @param t Time since release (s).
#' @param c0 Initial concentration grid (a matrix).
#' @param v Velocity along y.
#' @param kx,ky Eddy diffusivities.
#' @param dx,dy Grid spacings.
#' @param dt Time step.
#' @param n_steps Number of steps.
#' @param source Source grid (concentration per unit time), or \code{NULL}.
#' @param n Number of particles.
#' @param x0,y0 Release point.
#' @param seed Seed of the particle random walk.
#' @param grid \code{NULL}, or \code{c(x_min, x_max, y_min, y_max, nx, ny)}
#'   to count particles into a concentration grid.
#' @param normals A function \code{(n, seed, stream)} returning \code{n}
#'   standard normals; step \code{k} (from 0) draws streams \code{2k} for x
#'   and \code{2k + 1} for y. The default draws from the package's shared
#'   uniform stream (\code{\link{core_uniforms}}) through the normal quantile.
#'   rmorie's \code{LagrangianParticles()} uses its own Philox stream, so its
#'   paths differ from the default here; pass its generator to reproduce them.
#' @return \code{pg_sigmas()}: a list with \code{sigma_y} and \code{sigma_z}.
#'   \code{briggs_plume_rise()}: a list with \code{flux}, \code{final_rise},
#'   \code{x_final} and \code{rise} (at each \code{x}). \code{gaussian_plume()}
#'   and \code{gaussian_puff()}: a numeric vector of concentrations, one per
#'   receptor. \code{advection_diffusion_2d()}: a list with \code{field},
#'   \code{mass}, \code{cfl} and \code{diffusion_number}.
#'   \code{lagrangian_particles()}: a list with \code{x}, \code{y},
#'   \code{mean_x}, \code{mean_y} and, with a grid, \code{concentration}.
#' @references Briggs, G. A. (1973). Diffusion estimation for small emissions.
#'   ATDL Contribution 79. Briggs, G. A. (1975). Plume rise predictions.
#'   American Meteorological Society. Turner, D. B. (1970). Workbook of
#'   Atmospheric Dispersion Estimates. EPA AP-26. Seinfeld, J. H. and Pandis,
#'   S. N. (2016). Atmospheric Chemistry and Physics, 3rd ed. Thomson, D. J.
#'   (1987). Criteria for the selection of stochastic models of particle
#'   trajectories in turbulent flows. Journal of Fluid Mechanics 180, 529-556.
#' @examples
#' pg_sigmas(1000, "D")
#' gaussian_plume(100, 5, 50, rbind(c(1000, 0, 0)))
#' briggs_plume_rise(c(100, 1000), u = 4, diameter = 1, exit_velocity = 12,
#'                   stack_temp = 420, ambient_temp = 285)$rise
#' @export
pg_sigmas <- function(x, stability = "D", setting = "rural") {
  cls <- .ad_class(stability)
  setting <- .ad_setting(setting)
  rural <- rbind(A = c(0.22, 0.20, 0, 0), B = c(0.16, 0.12, 0, 0),
                 C = c(0.11, 0.08, 0.0002, -0.5), D = c(0.08, 0.06, 0.0015, -0.5),
                 E = c(0.06, 0.03, 0.0003, -1), F = c(0.04, 0.016, 0.0003, -1))
  urban <- rbind(A = c(0.32, 0.24, 0.001, 0.5), B = c(0.32, 0.24, 0.001, 0.5),
                 C = c(0.22, 0.20, 0, 0), D = c(0.16, 0.14, 0.0003, -0.5),
                 E = c(0.11, 0.08, 0.0015, -0.5), F = c(0.11, 0.08, 0.0015, -0.5))
  co <- if (setting == "rural") rural[cls, ] else urban[cls, ]
  cy <- if (setting == "rural") 0.0001 else 0.0004
  x <- as.numeric(x)
  list(sigma_y = co[[1L]] * x * (1 + cy * x)^-0.5,
       sigma_z = co[[2L]] * x * (1 + co[[3L]] * x)^co[[4L]])
}

#' @rdname pg_sigmas
#' @export
briggs_plume_rise <- function(x, u, diameter, exit_velocity, stack_temp, ambient_temp,
                              stability = "D", dtheta_dz = NULL, g = 9.80616) {
  cls <- .ad_class(stability)
  if (!is.numeric(u) || length(u) != 1L || !is.finite(u) || u <= 0) {
    stop("`u` must be a single positive wind speed", call. = FALSE)
  }
  F_ <- g * exit_velocity * diameter^2 * (stack_temp - ambient_temp) / (4 * stack_temp)
  if (cls %in% c("E", "F")) {
    lapse <- if (!is.null(dtheta_dz)) dtheta_dz else if (cls == "E") 0.020 else 0.035
    s <- g * lapse / ambient_temp
    final <- 2.6 * (F_ / (u * s))^(1 / 3)
    xf <- 2.0715 * u / sqrt(s)
  } else if (F_ < 55) {
    final <- 21.425 * F_^0.75 / u
    xf <- 49 * F_^(5 / 8)
  } else {
    final <- 38.71 * F_^0.6 / u
    xf <- 119 * F_^0.4
  }
  x <- as.numeric(x)
  rise <- ifelse(x >= xf, final, pmin(1.6 * F_^(1 / 3) * x^(2 / 3) / u, final))
  list(flux = F_, final_rise = final, x_final = xf, rise = rise)
}

.ad_class <- function(stability) {
  cls <- toupper(as.character(stability))
  if (length(cls) != 1L || is.na(cls) || !cls %in% c("A", "B", "C", "D", "E", "F")) {
    stop("`stability` must be one of the Pasquill classes \"A\" to \"F\"", call. = FALSE)
  }
  cls
}

.ad_setting <- function(setting) {
  if (length(setting) != 1L || !setting %in% c("rural", "urban")) {
    stop("`setting` must be \"rural\" or \"urban\"", call. = FALSE)
  }
  setting
}

# Vertical term: ground reflection, plus image pairs under a mixing lid.
.ad_vertical <- function(z, h, sz, lid, n_images) {
  tt <- exp(-(z - h)^2 / (2 * sz * sz)) + exp(-(z + h)^2 / (2 * sz * sz))
  if (!is.null(lid)) {
    for (j in seq_len(n_images)) {
      for (sgn in c(1, -1)) {
        off <- 2 * sgn * j * lid
        tt <- tt + exp(-(z - h + off)^2 / (2 * sz * sz)) + exp(-(z + h + off)^2 / (2 * sz * sz))
      }
    }
  }
  tt
}

# Receptors as an n x 3 matrix, from a matrix or a list of coordinate triples.
.ad_rec <- function(r) {
  bad <- function() stop("`receptors` must give x, y, z for at least one receptor", call. = FALSE)
  m <- if (is.list(r) && !is.data.frame(r)) {
    if (!length(r) || any(lengths(r) != 3L)) bad()
    do.call(rbind, lapply(r, as.numeric))
  } else if (is.matrix(r) || is.data.frame(r)) {
    if (ncol(r) != 3L) bad()
    matrix(as.numeric(as.matrix(r)), ncol = 3)
  } else {
    if (!length(r) || length(r) %% 3L != 0L) bad()
    matrix(as.numeric(r), ncol = 3, byrow = TRUE)
  }
  if (!nrow(m) || anyNA(m)) bad()
  m
}

#' @rdname pg_sigmas
#' @export
gaussian_plume <- function(q, u, h, receptors, stability = "D", setting = "rural",
                           mixing_height = NULL, n_images = 3) {
  R <- .ad_rec(receptors)
  vapply(seq_len(nrow(R)), function(i) {
    x <- R[i, 1L]
    if (x <= 0) return(0)
    s <- pg_sigmas(x, stability, setting)
    sy <- s$sigma_y
    sz <- s$sigma_z
    q / (2 * pi * u * sy * sz) * exp(-(R[i, 2L]^2) / (2 * sy * sy)) *
      .ad_vertical(R[i, 3L], h, sz, mixing_height, n_images)
  }, 0)
}

#' @rdname pg_sigmas
#' @export
gaussian_puff <- function(mass, u, h, receptors, t, stability = "D", setting = "rural",
                          mixing_height = NULL, n_images = 3) {
  R <- .ad_rec(receptors)
  s <- pg_sigmas(u * t, stability, setting)
  sy <- s$sigma_y
  sz <- s$sigma_z
  k <- mass / ((2 * pi)^1.5 * sy * sy * sz)
  vapply(seq_len(nrow(R)), function(i) {
    k * exp(-(R[i, 1L] - u * t)^2 / (2 * sy * sy)) * exp(-(R[i, 2L]^2) / (2 * sy * sy)) *
      .ad_vertical(R[i, 3L], h, sz, mixing_height, n_images)
  }, 0)
}

#' @rdname pg_sigmas
#' @export
advection_diffusion_2d <- function(c0, u, v, kx, ky, dx, dy, dt, n_steps, source = NULL) {
  cm <- unname(as.matrix(c0)) * 1
  nx <- nrow(cm)
  ny <- ncol(cm)
  if (!is.null(source) && !identical(dim(as.matrix(source)), dim(cm))) {
    stop("`source` must have the dimensions of `c0`", call. = FALSE)
  }
  ax <- u * dt / dx
  ay <- v * dt / dy
  dxn <- kx * dt / (dx * dx)
  dyn <- ky * dt / (dy * dy)
  for (step in seq_len(n_steps)) {
    nw <- matrix(0, nx, ny)
    for (i in seq_len(max(nx - 2, 0)) + 1) {
      for (j in seq_len(max(ny - 2, 0)) + 1) {
        adv_x <- if (u >= 0) ax * (cm[i, j] - cm[i - 1, j]) else ax * (cm[i + 1, j] - cm[i, j])
        adv_y <- if (v >= 0) ay * (cm[i, j] - cm[i, j - 1]) else ay * (cm[i, j + 1] - cm[i, j])
        dif <- dxn * (cm[i + 1, j] - 2 * cm[i, j] + cm[i - 1, j]) +
          dyn * (cm[i, j + 1] - 2 * cm[i, j] + cm[i, j - 1])
        s <- if (!is.null(source)) source[i, j] * dt else 0
        nw[i, j] <- cm[i, j] - adv_x - adv_y + dif + s
      }
    }
    cm <- nw
  }
  list(field = cm, mass = sum(cm) * dx * dy, cfl = abs(ax) + abs(ay),
       diffusion_number = 2 * (dxn + dyn))
}

# Standard normals from the package's shared uniform stream: one stream per
# (seed, stream) pair, through the normal quantile. The uniforms are kept
# strictly inside (0, 1) so the quantile is finite.
.rmbl_normals <- function(n, seed = 0, stream = 0) {
  if (n == 0L) return(numeric(0))
  s <- (as.numeric(seed) * 65536 + as.numeric(stream)) %% 2147483647
  u <- core_uniforms(n, seed = as.integer(s))
  eps <- .Machine$double.eps
  stats::qnorm(pmin(pmax(u, eps), 1 - eps))
}

#' @rdname pg_sigmas
#' @export
lagrangian_particles <- function(n, x0, y0, u, v, kx, ky, dt, n_steps, seed = 0, grid = NULL,
                                 normals = NULL) {
  n <- as.integer(n)
  if (is.na(n) || n < 1L) stop("`n` must be a positive number of particles", call. = FALSE)
  draw <- if (is.null(normals)) .rmbl_normals else match.fun(normals)
  xs <- rep(as.numeric(x0), n)
  ys <- rep(as.numeric(y0), n)
  fx <- sqrt(2 * kx * dt)
  fy <- sqrt(2 * ky * dt)
  for (k in seq_len(n_steps) - 1) {
    xs <- xs + u * dt + fx * draw(n, seed, 2 * k)
    ys <- ys + v * dt + fy * draw(n, seed, 2 * k + 1)
  }
  out <- list(x = xs, y = ys, mean_x = sum(xs) / n, mean_y = sum(ys) / n)
  if (!is.null(grid)) {
    if (length(grid) != 6L) stop("`grid` must be c(x_min, x_max, y_min, y_max, nx, ny)", call. = FALSE)
    wx <- (grid[2L] - grid[1L]) / grid[5L]
    wy <- (grid[4L] - grid[3L]) / grid[6L]
    conc <- matrix(0, grid[5L], grid[6L])
    ii <- floor((xs - grid[1L]) / wx)
    jj <- floor((ys - grid[3L]) / wy)
    for (p in seq_len(n)) {
      if (ii[p] >= 0 && ii[p] < grid[5L] && jj[p] >= 0 && jj[p] < grid[6L]) {
        conc[ii[p] + 1, jj[p] + 1] <- conc[ii[p] + 1, jj[p] + 1] + 1 / (n * wx * wy)
      }
    }
    out$concentration <- conc
  }
  out
}
