# SPDX-License-Identifier: AGPL-3.0-or-later
# Atmospheric dispersion: Pasquill-Gifford sigmas, Briggs plume rise, Gaussian
# plume and puff, an explicit Eulerian solver and a Lagrangian random walk.
# The formulas are those of rmorie's AirDispersion module and morie's
# airdisp; only the random-number seam differs (see lagrangian_particles()).

# One finite number (or a vector of them) for the dispersion inputs.
.ad_num <- function(x, what, min = -Inf, positive = FALSE, scalar = TRUE, whole = FALSE) {
  if (is.logical(x) && !all(is.na(x))) stop(sprintf("`%s` must be numeric, not logical", what), call. = FALSE)
  v <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (scalar && length(v) != 1L) {
    stop(sprintf("`%s` must be a single number", what), call. = FALSE)
  }
  if (!length(v) || anyNA(v) || any(!is.finite(v))) {
    stop(sprintf("`%s` must be finite, with no missing values", what), call. = FALSE)
  }
  if (positive && any(v <= 0)) stop(sprintf("`%s` must be positive", what), call. = FALSE)
  if (any(v < min)) stop(sprintf("`%s` must be at least %s", what, format(min)), call. = FALSE)
  if (whole && any(v != round(v))) {
    stop(sprintf("`%s` must be a whole number", what), call. = FALSE)
  }
  v
}

# A receptor below the ground or above the mixing lid is outside the model: the reflection
# images still return a number there, so it is said.
.ad_receptor_heights <- function(R, mixing_height) {
  z <- R[, 3L]
  if (any(z < 0)) {
    warning(sprintf(paste("%d receptor(s) below ground level (z < 0): the plume is reflected at the ground,",
                          "so these values are mirror images"), sum(z < 0)), call. = FALSE)
  }
  if (is.finite(mixing_height) && any(z > mixing_height)) {
    warning(sprintf(paste("%d receptor(s) above the mixing height %s: the lid reflects the plume,",
                          "so these values are not concentrations in the free atmosphere"),
                    sum(z > mixing_height), format(mixing_height)), call. = FALSE)
  }
  invisible(NULL)
}

.ad_lid <- function(mixing_height, h) {
  if (is.null(mixing_height)) return(NULL)
  lid <- .ad_num(mixing_height, "mixing_height", positive = TRUE)
  if (h > lid) {
    warning(sprintf(paste("release height %s is above the mixing height %s:",
                          "the plume is above the lid and the reflection terms do not describe it"),
                    format(h), format(lid)), call. = FALSE)
  }
  lid
}

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
#' diffusion, forward Euler, zero boundaries. The explicit scheme is stable
#' when \code{|u dt/dx| + |v dt/dy| + 2 (kx dt/dx^2 + ky dt/dy^2) <= 1}
#' (the von Neumann bound for upwind advection with forward-time
#' centred-space diffusion); that sum is returned as
#' \code{stability_number} with \code{stable}. A call outside the bound is
#' not run as given: each step is split into enough sub-steps of a smaller
#' \code{dt} to satisfy it (reported as \code{substeps} and \code{dt}),
#' with a warning, so the field is a solution over the same physical time
#' rather than a numerical explosion. The separate \code{cfl} and
#' \code{diffusion_number} are reported for reference; each below 1 is
#' necessary, not sufficient.
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
#'   Only buoyant rise is modelled: a stack at the air's temperature (within half a
#'   kelvin) has zero rise, and momentum rise from the exit velocity is not added.
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
#' @param max_work The most cell updates (cells x steps x sub-steps; for
#'   \code{lagrangian_particles()}, particles x steps) a run may take, 100
#'   million by default (a few minutes of the explicit loop); \code{Inf} lifts it. The
#'   same physical run costs the same whether the caller sub-steps it or the scheme does,
#'   so the cap reads the same either way.
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
#'   \code{mass}, \code{cfl}, \code{diffusion_number},
#'   \code{stability_number}, \code{stable}, \code{dt}, \code{substeps} and
#'   the axes, as a list of class \code{rmbl_field} that \code{plot()}
#'   draws as an image; \code{lagrangian_particles()} a list of class
#'   \code{rmbl_particles} (positions, means and the counting grid) that
#'   \code{plot()} draws as points. Every physical input is
#'   checked: emission rates, masses, heights and distances are non-negative,
#'   wind speed, travel time and grid steps positive, \code{n_images} a
#'   whole number up to 1,000, the stack as hot as the air or hotter,
#'   and \code{x0}, \code{y0}
#'   single numbers; a release above \code{mixing_height} warns.
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
  x <- .ad_num(x, "x", min = 0, scalar = FALSE)
  rural <- rbind(A = c(0.22, 0.20, 0, 0), B = c(0.16, 0.12, 0, 0),
                 C = c(0.11, 0.08, 0.0002, -0.5), D = c(0.08, 0.06, 0.0015, -0.5),
                 E = c(0.06, 0.03, 0.0003, -1), F = c(0.04, 0.016, 0.0003, -1))
  urban <- rbind(A = c(0.32, 0.24, 0.001, 0.5), B = c(0.32, 0.24, 0.001, 0.5),
                 C = c(0.22, 0.20, 0, 0), D = c(0.16, 0.14, 0.0003, -0.5),
                 E = c(0.11, 0.08, 0.0015, -0.5), F = c(0.11, 0.08, 0.0015, -0.5))
  co <- if (setting == "rural") rural[cls, ] else urban[cls, ]
  cy <- if (setting == "rural") 0.0001 else 0.0004
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
  x <- .ad_num(x, "x", min = 0, scalar = FALSE)
  diameter <- .ad_num(diameter, "diameter", positive = TRUE)
  exit_velocity <- .ad_num(exit_velocity, "exit_velocity", positive = TRUE)
  stack_temp <- .ad_num(stack_temp, "stack_temp", positive = TRUE)
  ambient_temp <- .ad_num(ambient_temp, "ambient_temp", positive = TRUE)
  if (stack_temp < 150 || ambient_temp < 150) {
    stop(sprintf(paste("temperatures are in kelvin: stack_temp %s and ambient_temp %s look like degrees",
                       "Celsius (ambient air is about 290 K)"), format(stack_temp), format(ambient_temp)),
         call. = FALSE)
  }
  g <- .ad_num(g, "g", positive = TRUE)
  if (stack_temp < ambient_temp - 0.5) {
    stop("`stack_temp` is below `ambient_temp`: Briggs' formulas describe a buoyant plume, so ",
         "the stack must be as hot as the air or hotter (equal gives no rise)", call. = FALSE)
  }
  # within half a kelvin of the air there is no buoyancy to speak of: zero rise, not a cliff
  if (stack_temp < ambient_temp) stack_temp <- ambient_temp
  if (!is.null(dtheta_dz)) dtheta_dz <- .ad_num(dtheta_dz, "dtheta_dz", positive = TRUE)
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
  q <- .ad_num(q, "q", min = 0)
  u <- .ad_num(u, "u", positive = TRUE)
  h <- .ad_num(h, "h", min = 0)
  n_images <- .ad_check_images(n_images)
  mixing_height <- .ad_lid(mixing_height, h)
  R <- .ad_rec(receptors)
  .ad_receptor_heights(R, mixing_height)
  nr <- nrow(R)
  pg <- bricklayer_progress("Gaussian plume", nr)
  on.exit(pg$done(), add = TRUE)
  every <- max(1L, nr %/% 500L)
  vapply(seq_len(nr), function(i) {
    if (i %% every == 0L) pg$update(i, sprintf("receptor %d/%d", i, nr))
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
  mass <- .ad_num(mass, "mass", min = 0)
  u <- .ad_num(u, "u", positive = TRUE)
  h <- .ad_num(h, "h", min = 0)
  t <- .ad_num(t, "t", positive = TRUE)
  n_images <- .ad_check_images(n_images)
  mixing_height <- .ad_lid(mixing_height, h)
  .ad_receptor_heights(.ad_rec(receptors), mixing_height)
  R <- .ad_rec(receptors)
  s <- pg_sigmas(u * t, stability, setting)
  sy <- s$sigma_y
  sz <- s$sigma_z
  k <- mass / ((2 * pi)^1.5 * sy * sy * sz)
  nr <- nrow(R)
  pg <- bricklayer_progress("Gaussian puff", nr)
  on.exit(pg$done(), add = TRUE)
  every <- max(1L, nr %/% 500L)
  vapply(seq_len(nr), function(i) {
    if (i %% every == 0L) pg$update(i, sprintf("receptor %d/%d", i, nr))
    k * exp(-(R[i, 1L] - u * t)^2 / (2 * sy * sy)) * exp(-(R[i, 2L]^2) / (2 * sy * sy)) *
      .ad_vertical(R[i, 3L], h, sz, mixing_height, n_images)
  }, 0)
}

#' @rdname pg_sigmas
#' @section Boundary: the outermost ring of cells is held at zero (an open boundary): mass
#'   that reaches it leaves the domain and \code{mass} falls accordingly. Pad \code{c0} with
#'   empty cells so the plume of interest stays inside the ring.
#' @export
advection_diffusion_2d <- function(c0, u, v, kx, ky, dx, dy, dt, n_steps, source = NULL, max_work = 1e8) {
  if (!is.matrix(c0) || !is.numeric(c0)) {
    stop("`c0` must be a numeric matrix (one row per x cell, one column per y cell)", call. = FALSE)
  }
  cm <- unname(c0) * 1
  if (anyNA(cm) || any(!is.finite(cm))) {
    stop("`c0` must be a finite numeric matrix", call. = FALSE)
  }
  if (any(cm < 0)) stop("`c0` must be non-negative: it is a concentration field", call. = FALSE)
  nx <- nrow(cm)
  ny <- ncol(cm)
  if (!is.null(source) && !identical(dim(as.matrix(source)), dim(cm))) {
    stop("`source` must have the dimensions of `c0`", call. = FALSE)
  }
  if (!is.null(source) && (!is.numeric(source) || anyNA(source) || any(!is.finite(as.numeric(source))))) {
    stop("`source` must be a finite numeric matrix", call. = FALSE)
  }
  if (!is.null(source) && any(as.numeric(source) < 0)) {
    stop("`source` must be non-negative: it is an emission rate, like `c0`", call. = FALSE)
  }
  u <- .ad_num(u, "u")
  v <- .ad_num(v, "v")
  kx <- .ad_num(kx, "kx", min = 0)
  ky <- .ad_num(ky, "ky", min = 0)
  dx <- .ad_num(dx, "dx", positive = TRUE)
  dy <- .ad_num(dy, "dy", positive = TRUE)
  dt <- .ad_num(dt, "dt", positive = TRUE)
  n_steps <- .ad_num(n_steps, "n_steps", min = 0, whole = TRUE)
  ax <- u * dt / dx
  ay <- v * dt / dy
  dxn <- kx * dt / (dx * dx)
  dyn <- ky * dt / (dy * dy)
  # the explicit upwind + FTCS scheme is stable when the advection and diffusion
  # numbers together stay within the unit interval; cfl < 1 alone is not enough
  stab <- abs(ax) + abs(ay) + 2 * (dxn + dyn)
  if (!is.finite(stab)) stop("the stability number is not finite: check u, v, kx, ky, dx, dy and dt", call. = FALSE)
  # the sub-steps that satisfy the bound; the fudge that rounded 10,000 up to 10,001 is gone
  # ceiling(stab) sub-steps of dt / ceiling(stab) give a stability number stab / ceiling(stab) <= 1
  substeps <- if (stab > 1) ceiling(stab) else 1
  # the cost of a run is its work, cells x steps x sub-steps, whether the caller wrote the small
  # time step or the stability bound forced it: the same physics costs the same, so one cap
  # applies to every run and reads the same for both spellings of it
  work <- as.numeric(nx) * ny * n_steps * substeps
  if (!is.finite(work)) stop("the amount of work is not finite: check n_steps and the grid", call. = FALSE)
  if (!is.numeric(max_work) || length(max_work) != 1L || is.na(max_work) || max_work <= 0) {
    stop("`max_work` must be a single positive number (Inf lifts the cap)", call. = FALSE)
  }
  if (work > max_work) {
    minutes <- work / 8e5 / 60   # about 0.8 million cell updates a second in the explicit loop
    stop(sprintf(paste("this run updates %s cells x steps x sub-steps (%d x %d cells, %s steps, %s sub-steps per",
                       "step%s), above max_work = %s: about %s minutes of the explicit loop. Pass max_work = Inf",
                       "to run it anyway, or use a coarser grid, fewer steps or a shorter total time"),
                 format(work, big.mark = ",", scientific = FALSE), nx, ny,
                 format(n_steps, big.mark = ",", scientific = FALSE),
                 format(substeps, big.mark = ",", scientific = FALSE),
                 if (substeps > 1) sprintf(" from a stability number of %s", format(stab, digits = 4)) else "",
                 format(max_work, big.mark = ",", scientific = FALSE),
                 format(round(minutes, 1), big.mark = ",")), call. = FALSE)
  }
  # a count R can loop over, whatever max_work allows: 1e300 died in seq_len() (review of 02a38be)
  if (n_steps > .Machine$integer.max) stop("`n_steps` must be at most 2^31 - 1", call. = FALSE)
  substeps <- as.integer(substeps)
  if (stab > 1) {
    # the same physical time, taken in enough sub-steps to satisfy the bound:
    # the result is then a solution rather than a numerical explosion
    warning(sprintf(paste("explicit scheme outside its stability bound",
                          "(|u dt/dx| + |v dt/dy| + 2 (kx dt/dx^2 + ky dt/dy^2) = %.3f > 1):",
                          "each step is taken as %d sub-steps of dt/%d; pass a smaller dt to silence this"),
                    stab, substeps, substeps), call. = FALSE)
    dt <- dt / substeps
    ax <- u * dt / dx
    ay <- v * dt / dy
    dxn <- kx * dt / (dx * dx)
    dyn <- ky * dt / (dy * dy)
    stab <- abs(ax) + abs(ay) + 2 * (dxn + dyn)
    n_steps <- n_steps * substeps
  }
  pg <- bricklayer_progress("advection-diffusion", n_steps)
  on.exit(pg$done(), add = TRUE)
  for (step in seq_len(n_steps)) {
    pg$update(step - 1L, sprintf("step %d/%s", step, format(n_steps, big.mark = ",", scientific = FALSE)))
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
  structure(list(field = cm, mass = sum(cm) * dx * dy, cfl = abs(ax) + abs(ay),
                 diffusion_number = 2 * (dxn + dyn), stability_number = stab, stable = stab <= 1,
                 dt = dt, substeps = substeps,
                 x = seq_len(nx) * dx, y = seq_len(ny) * dy, dx = dx, dy = dy,
                 units = "concentration",
                 title = sprintf("Advection-diffusion after %s steps of dt = %s",
                                 format(n_steps, big.mark = ",", scientific = FALSE), format(dt))),
            class = "rmbl_field")
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
                                 normals = NULL, max_work = 1e8) {
  n <- .ad_num(n, "n", positive = TRUE, whole = TRUE)
  if (n > 1e8) stop("`n` must be at most 100 million particles", call. = FALSE)
  n <- as.integer(n)
  x0 <- .ad_num(x0, "x0")
  y0 <- .ad_num(y0, "y0")
  u <- .ad_num(u, "u")
  v <- .ad_num(v, "v")
  kx <- .ad_num(kx, "kx", min = 0)
  ky <- .ad_num(ky, "ky", min = 0)
  dt <- .ad_num(dt, "dt", positive = TRUE)
  n_steps <- .ad_num(n_steps, "n_steps", min = 0, whole = TRUE)
  if (!is.numeric(max_work) || length(max_work) != 1L || is.na(max_work) || max_work <= 0) {
    stop("`max_work` must be a single positive number (Inf lifts the cap)", call. = FALSE)
  }
  # the same cap as advection_diffusion_2d(): particles x steps (n_steps = 1e9 built a 7.5 GB
  # index vector and would have run for about 32 hours, review of 52a8883)
  if (n * n_steps > max_work) {
    stop(sprintf(paste("this run moves %s particles x %s steps, above max_work = %s; pass max_work = Inf",
                       "to run it anyway"), format(n, big.mark = ","),
                 format(n_steps, big.mark = ",", scientific = FALSE),
                 format(max_work, big.mark = ",", scientific = FALSE)), call. = FALSE)
  }
  # a count R can loop over, whatever max_work allows: 1e300 died in seq_len() (review of 02a38be)
  if (n_steps > .Machine$integer.max) stop("`n_steps` must be at most 2^31 - 1", call. = FALSE)
  draw <- if (is.null(normals)) .rmbl_normals else match.fun(normals)
  xs <- rep(x0, n)
  ys <- rep(y0, n)
  fx <- sqrt(2 * kx * dt)
  fy <- sqrt(2 * ky * dt)
  pg <- bricklayer_progress("particles", n_steps)
  on.exit(pg$done(), add = TRUE)
  # a step can be a few microseconds (one particle): the bar hears of every thousandth
  every <- max(1, n_steps %/% 1000)
  for (step in seq_len(n_steps)) {
    if (step %% every == 0) {
      pg$update(step - 1L, sprintf("step %s/%s", format(step, big.mark = ",", scientific = FALSE),
                                   format(n_steps, big.mark = ",", scientific = FALSE)))
    }
    k <- step - 1
    xs <- xs + u * dt + fx * draw(n, seed, 2 * k)
    ys <- ys + v * dt + fy * draw(n, seed, 2 * k + 1)
  }
  out <- list(x = xs, y = ys, mean_x = sum(xs) / n, mean_y = sum(ys) / n, grid = grid)
  if (!is.null(grid)) {
    if (length(grid) != 6L) stop("`grid` must be c(x_min, x_max, y_min, y_max, nx, ny)", call. = FALSE)
    grid <- .ad_num(grid, "grid", scalar = FALSE)
    if (grid[2L] <= grid[1L] || grid[4L] <= grid[3L] || grid[5L] < 1 || grid[6L] < 1 ||
          grid[5L] != round(grid[5L]) || grid[6L] != round(grid[6L])) {
      stop("`grid` needs x_min < x_max, y_min < y_max and whole positive nx, ny", call. = FALSE)
    }
    if (grid[5L] * grid[6L] > max_work) {
      stop(sprintf(paste("a %s x %s grid has %s cells, above max_work = %s; pass max_work = Inf to allocate it",
                         "anyway"), format(grid[5L], big.mark = ","), format(grid[6L], big.mark = ","),
                   format(grid[5L] * grid[6L], big.mark = ",", scientific = FALSE),
                   format(max_work, big.mark = ",", scientific = FALSE)), call. = FALSE)
    }
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
  structure(out, class = c("rmbl_particles", "list"))
}

# the lid's image terms shrink geometrically: past a few pairs they add nothing but time, and
# 1e9 of them took about 480 s per receptor (review of 52a8883)
.ad_check_images <- function(n_images) {
  n_images <- .ad_num(n_images, "n_images", min = 0, whole = TRUE)
  if (n_images > 1000) {
    stop("`n_images` must be at most 1,000: the image terms decay geometrically and more add only time", call. = FALSE)
  }
  n_images
}
