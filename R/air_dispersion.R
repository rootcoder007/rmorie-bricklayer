# SPDX-License-Identifier: AGPL-3.0-or-later
# Atmospheric dispersion: Pasquill-Gifford sigmas, Briggs plume rise, Gaussian
# plume and puff, an explicit Eulerian solver and a Lagrangian random walk.
# The formulas are those of rmorie's AirDispersion module and morie's
# airdisp; only the random-number seam differs (see lagrprt()).

#' One finite number (or a vector of them) for the dispersion inputs.
#' @param x The value passed by the user.
#' @param what The argument's name, used in the error message.
#' @param min The smallest value accepted.
#' @param positive Whether the value must be above zero.
#' @param scalar Whether a single number is required.
#' @param whole Whether the value must be a whole number.
#' @return A double vector.
#' @noRd
.ad_num <- function(x, what, min = -Inf, positive = FALSE, scalar = TRUE, whole = FALSE) {
  if (is.logical(x) && !all(is.na(x))) stop(.rmbl_fn(), sprintf("`%s` must be numeric, not logical", what),
                                            call. = FALSE)
  v <- .rmbl_num_input(x, what, allow_null = FALSE)
  if (scalar && length(v) != 1L) {
    stop(sprintf("`%s` must be a single number", what), call. = FALSE)
  }
  if (!length(v) || anyNA(v) || any(!is.finite(v))) {
    stop(sprintf("`%s` must be finite, with no missing values", what), call. = FALSE)
  }
  if (positive && any(v <= 0)) stop(.rmbl_fn(), sprintf("`%s` must be positive", what), call. = FALSE)
  if (any(v < min)) stop(sprintf("`%s` must be at least %s", what, format(min)), call. = FALSE)
  # 1e308 overflowed the arithmetic to Inf and NaN and failed in R's words (final audit of 1.0.0)
  if (any(abs(v) > 1e300)) stop(sprintf("`%s` must be below 1e300 in size", what), call. = FALSE)
  if (whole && any(v != round(v))) {
    stop(sprintf("`%s` must be a whole number", what), call. = FALSE)
  }
  v
}

#' Warns about receptors below the ground or above the mixing lid.
#'
#' A receptor below the ground or above the mixing lid is outside the model: the reflection
#' images still return a number there, so it is said.
#' @param R The receptors as an n x 3 matrix.
#' @param mixing_height The mixing height, or a non-finite value for none.
#' @return NULL, invisibly.
#' @noRd
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

#' Checks the mixing height and warns when the release is above it.
#' @param mixing_height The mixing height, or NULL for no lid.
#' @param h The release height.
#' @return The mixing height, or NULL.
#' @noRd
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
#' @description
#' Six standard models of how a pollutant released into the air spreads
#' downwind, for exposure estimates around a stack, a fire or an industrial
#' site (for example when relating air quality to health or justice
#' outcomes by neighbourhood):
#' \itemize{
#'   \item \code{pgsig()}: how wide and how tall a plume has grown at a
#'     given distance, by atmospheric stability class;
#'   \item \code{briggs()}: how far a hot plume rises above the
#'     stack top;
#'   \item \code{gplume()}: the steady concentration at receptor
#'     points from a continuous release;
#'   \item \code{gspuff()}: the concentration from a single
#'     instantaneous release, some time after it;
#'   \item \code{advdif2d()}: a concentration field on a grid
#'     moved by wind and spread by diffusion, step by step;
#'   \item \code{lagrprt()}: the same physics as a random walk
#'     of many particles.
#' }
#' They are screening models with textbook assumptions (flat terrain,
#' steady uniform wind, no chemistry or deposition), not regulatory model
#' runs.
#'
#' @details
#' \code{pgsig()}: Briggs (1973) fits of the Pasquill-Gifford dispersion
#' coefficients by stability class A-F, rural
#' \code{sigmay = a_y x (1 + 0.0001 x)^(-1/2)} (urban: 0.0004) and
#' \code{sigmaz = a_z x (1 + b_z x)^(e_z)}.
#' \code{briggs()}: buoyancy flux
#' \code{F = g v_s d^2 (T_s - T_a) / (4 T_s)}; final rise
#' \code{21.425 F^(3/4) / u} with \code{x_f = 49 F^(5/8)} when \code{F < 55},
#' else \code{38.71 F^(3/5) / u} with \code{x_f = 119 F^(2/5)}, for classes A-D;
#' \code{2.6 (F / (u s))^(1/3)} with \code{s = g (dtheta/dz) / T_a} and
#' \code{x_f = 2.0715 u / sqrt(s)} for E and F; transitional rise
#' \code{1.6 F^(1/3) x^(2/3) / u} before \code{x_f} (EPA ISC3).
#' \code{gplume()}:
#' \code{Q / (2 pi u sigmay sigmaz) exp(-y^2 / (2 sigmay^2)) V},
#' with \code{V} the vertical term with ground reflection and, under a mixing
#' lid, \code{nimg} pairs of image terms.
#' \code{gspuff()}: an instantaneous release with \code{sigma_x = sigmay}
#' evaluated at the travel distance \code{u t}.
#' \code{advdif2d()}: explicit upwind advection, central
#' diffusion, forward Euler, zero boundaries. The explicit scheme is stable
#' when \code{|u dt/dx| + |v dt/dy| + 2 (kx dt/dx^2 + ky dt/dy^2) <= 1}
#' (the von Neumann bound for upwind advection with forward-time
#' centred-space diffusion); that sum is returned as
#' \code{stabn} with \code{stable}. A call outside the bound is
#' not run as given: each step is split into enough sub-steps of a smaller
#' \code{dt} to satisfy it (reported as \code{substeps} and \code{dt}),
#' with a warning, so the field is a solution over the same physical time
#' rather than a numerical explosion. The separate \code{cfl} and
#' \code{difn} are reported for reference; each below 1 is
#' necessary, not sufficient.
#' \code{lagrprt()}: the random walk
#' \code{x + u dt + sqrt(2 K dt) xi} (Thomson 1987) with an optional counting
#' grid.
#'
#' The stability classes run from \code{"A"} (very unstable, sunny with
#' light wind) through \code{"D"} (neutral, overcast or windy) to
#' \code{"F"} (stable, clear night with light wind). Units are SI: metres,
#' seconds, kelvin; with \code{q} in g/s, \code{gplume()} returns
#' g/m^3, and with \code{mass} in g, \code{gspuff()} returns g/m^3.
#' The plume is not defined at or upwind of the source: a receptor with
#' \eqn{x \le 0} gets 0. The plume's \code{h} is the effective height,
#' the stack height plus the rise from \code{briggs()}.
#'
#' Every physical input is checked: emission rates, masses, heights and
#' distances are non-negative, wind speed, travel time and grid steps
#' positive, \code{nimg} a whole number up to 1,000, the stack as hot
#' as the air or hotter (temperatures below 150 are refused as probably
#' Celsius), and \code{x0}, \code{y0} single numbers; a release above
#' \code{mixh} warns, and so does a receptor below ground or above
#' the lid (the reflection terms give mirror values there). Unknown
#' stability classes or settings are errors.
#'
#' Cost: \code{gplume()} and \code{gspuff()} are fast for
#' thousands of receptors. \code{advdif2d()} is an R loop at
#' roughly 0.8 million cell updates a second, and both grid models refuse a
#' run above \code{maxwork} cell or particle updates. The particle walk
#' is reproducible from \code{seed} and does not touch R's random number
#' stream. Progress bars are shown in an interactive session.
#'
#' @param x Downwind distance(s) in metres.
#' @param stab Pasquill stability class, one of \code{"A"} to \code{"F"}.
#' @param set \code{"rural"} (the default) or \code{"urban"}: which set
#'   of Briggs coefficients to use.
#' @param u Wind speed in m/s (the x velocity for the grid models).
#' @param diam,exitvel,stktmp,ambtmp Stack diameter (m),
#'   exit velocity (m/s), stack gas and ambient temperatures (K).
#'   Only buoyant rise is modelled: a stack at the air's temperature (within half a
#'   kelvin) has zero rise, and momentum rise from the exit velocity is not added.
#' @param dthdz Potential temperature gradient (K/m) for the stable
#'   classes; the defaults are 0.020 (E) and 0.035 (F).
#' @param g Gravitational acceleration in m/s^2, default 9.80616.
#' @param q Emission rate (mass per second, for example g/s).
#' @param h Effective stack height (m): physical height plus plume rise.
#' @param rcpt A matrix with columns x, y, z, or a list of length-3
#'   vectors.
#' @param mixh Mixing-lid height in metres, or \code{NULL} (the
#'   default) for no lid. Under a lid the plume is reflected between the
#'   ground and the lid.
#' @param nimg Whole number, default 3: the number of lid image pairs
#'   (0 to 1,000). The terms decay quickly; a few are enough.
#' @param mass Puff mass (for example g).
#' @param t Time since release (s).
#' @param c0 Initial concentration grid: a non-negative numeric matrix, one
#'   row per x cell and one column per y cell.
#' @param v Wind velocity along y (m/s), may be negative.
#' @param kx,ky Eddy diffusivities along x and y (m^2/s), non-negative.
#' @param dx,dy Grid spacings (m), positive.
#' @param dt Time step (s), positive.
#' @param nsteps Whole number of time steps (0 returns the start).
#' @param source Source grid (concentration per unit time), or \code{NULL}.
#' @param maxwork The most cell updates (cells x steps x sub-steps; for
#'   \code{lagrprt()}, particles x steps) a run may take, 100
#'   million by default (a few minutes of the explicit loop); \code{Inf} lifts it. The
#'   same physical run costs the same whether the caller sub-steps it or the scheme does,
#'   so the cap reads the same either way.
#' @param n Whole number of particles, at most 100 million.
#' @param x0,y0 Release point (m).
#' @param seed Number, default 0: the seed of the particle random walk.
#' @param grid \code{NULL}, or \code{c(xmin, x_max, y_min, y_max, nx, ny)}
#'   to count particles into a concentration grid.
#' @param normals A function \code{(n, seed, stream)} returning \code{n}
#'   standard normals; step \code{k} (from 0) draws streams \code{2k} for x
#'   and \code{2k + 1} for y. The default draws from the package's shared
#'   uniform stream (\code{\link{cunif}}) through the normal quantile.
#'   rmorie's \code{LagrangianParticles()} uses its own Philox stream, so its
#'   paths differ from the default here; pass its generator to reproduce them.
#' @return \code{pgsig()}: a list with \code{sigmay} and \code{sigmaz}.
#'   \code{briggs()}: a list with \code{flux}, \code{finalrise},
#'   \code{xfinal} and \code{rise} (at each \code{x}). \code{gplume()}
#'   and \code{gspuff()}: a numeric vector of concentrations, one per
#'   receptor. \code{advdif2d()}: a list with \code{field},
#'   \code{mass}, \code{cfl}, \code{difn},
#'   \code{stabn}, \code{stable}, \code{dt}, \code{substeps} and
#'   the axes, as a list of class \code{rmbl_field} that \code{plot()}
#'   draws as an image; \code{lagrprt()} a list of class
#'   \code{rmbl_particles} that \code{plot()} draws as points, with
#'   \code{x}, \code{y} (final particle positions), \code{mean_x},
#'   \code{meany}, \code{grid} (as given) and, with a grid,
#'   \code{concentration} (an \code{nx} by \code{ny} matrix of particle
#'   density per unit area, summing to the share of particles inside the grid
#'   divided by the cell area).
#' @references Briggs, G. A. (1973). Diffusion estimation for small emissions.
#'   ATDL Contribution 79. Briggs, G. A. (1975). Plume rise predictions.
#'   American Meteorological Society. Turner, D. B. (1970). Workbook of
#'   Atmospheric Dispersion Estimates. EPA AP-26. Seinfeld, J. H. and Pandis,
#'   S. N. (2016). Atmospheric Chemistry and Physics, 3rd ed. Thomson, D. J.
#'   (1987). Criteria for the selection of stochastic models of particle
#'   trajectories in turbulent flows. Journal of Fluid Mechanics 180, 529-556.
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # plume widths 1 km downwind: neutral, then very stable, rural and urban
#' pgsig(1000, "D")
#' pgsig(c(500, 1000, 2000), "F", set = "urban")
#'
#' # rise of a hot plume, and the effective height it gives a 50 m stack
#' rise <- briggs(c(100, 1000), u = 4, diam = 1, exitvel = 12,
#'                           stktmp = 420, ambtmp = 285)
#' rise$rise
#' heff <- 50 + rise$finalrise
#'
#' # ground-level concentration (g/m^3) from 100 g/s along the centreline
#' rec <- cbind(x = c(500, 1000, 2000, 8000), y = 0, z = 0)
#' gplume(100, u = 4, h = heff, rcpt = rec)
#'
#' # under a 120 m mixing lid the far receptor sees a trapped plume
#' gplume(100, u = 4, h = heff, rcpt = rec, mixh = 120)
#'
#' # a 1 kg puff, 10 minutes after release, at the puff centre
#' gspuff(1000, u = 3, h = 10, rcpt = rbind(c(1800, 0, 0)), t = 600)
#'
#' # a small grid: a blob moved by wind and spread by diffusion
#' c0 <- matrix(0, 15, 15)
#' c0[4, 8] <- 1
#' f <- advdif2d(c0, u = 1, v = 0, kx = 0.5, ky = 0.5,
#'                             dx = 1, dy = 1, dt = 0.2, nsteps = 20)
#' f$stable
#' round(f$mass, 3)
#'
#' # 2,000 particles, counted on a grid
#' p <- lagrprt(2000, x0 = 0, y0 = 0, u = 1, v = 0, kx = 1, ky = 1,
#'                           dt = 1, nsteps = 10, seed = 1,
#'                           grid = c(-10, 30, -20, 20, 8, 8))
#' c(p$mean_x, p$meany)
#'
#' # inputs that cannot be right are refused
#' try(pgsig(100, "G"))
#' try(briggs(100, u = 4, diam = 1, exitvel = 12,
#'                       stktmp = 150 + 5, ambtmp = 20))
#' @export
pgsig <- function(x, stab = "D", set = "rural") {
  .rmbl_no_fn(stability = stab)
  cls <- .ad_class(stab)
  set <- .ad_setting(set)
  x <- .ad_num(x, "x", min = 0, scalar = FALSE)
  rural <- rbind(A = c(0.22, 0.20, 0, 0), B = c(0.16, 0.12, 0, 0),
                 C = c(0.11, 0.08, 0.0002, -0.5), D = c(0.08, 0.06, 0.0015, -0.5),
                 E = c(0.06, 0.03, 0.0003, -1), F = c(0.04, 0.016, 0.0003, -1))
  urban <- rbind(A = c(0.32, 0.24, 0.001, 0.5), B = c(0.32, 0.24, 0.001, 0.5),
                 C = c(0.22, 0.20, 0, 0), D = c(0.16, 0.14, 0.0003, -0.5),
                 E = c(0.11, 0.08, 0.0015, -0.5), F = c(0.11, 0.08, 0.0015, -0.5))
  co <- if (set == "rural") rural[cls, ] else urban[cls, ]
  cy <- if (set == "rural") 0.0001 else 0.0004
  list(sigmay = co[[1L]] * x * (1 + cy * x)^-0.5,
       sigmaz = co[[2L]] * x * (1 + co[[3L]] * x)^co[[4L]])
}

#' @rdname pgsig
#' @export
briggs <- function(x, u, diam, exitvel, stktmp, ambtmp,
                              stab = "D", dthdz = NULL, g = 9.80616) {
  .rmbl_no_fn(stability = stab)
  cls <- .ad_class(stab)
  if (!is.numeric(u) || length(u) != 1L || !is.finite(u) || u <= 0) {
    stop("`u` must be a single positive wind speed", call. = FALSE)
  }
  x <- .ad_num(x, "x", min = 0, scalar = FALSE)
  diam <- .ad_num(diam, "diameter", positive = TRUE)
  exitvel <- .ad_num(exitvel, "exitvel", positive = TRUE)
  stktmp <- .ad_num(stktmp, "stktmp", positive = TRUE)
  ambtmp <- .ad_num(ambtmp, "ambtmp", positive = TRUE)
  if (stktmp < 150 || ambtmp < 150) {
    stop(sprintf(paste("temperatures are in kelvin: stktmp %s and ambtmp %s look like degrees",
                       "Celsius (ambient air is about 290 K)"), format(stktmp), format(ambtmp)),
         call. = FALSE)
  }
  g <- .ad_num(g, "g", positive = TRUE)
  if (stktmp < ambtmp - 0.5) {
    stop("`stktmp` is below `ambtmp`: Briggs' formulas describe a buoyant plume, so ",
         "the stack must be as hot as the air or hotter (equal gives no rise)", call. = FALSE)
  }
  # within half a kelvin of the air there is no buoyancy to speak of: zero rise, not a cliff
  if (stktmp < ambtmp) stktmp <- ambtmp
  if (!is.null(dthdz)) dthdz <- .ad_num(dthdz, "dthdz", positive = TRUE)
  F_ <- g * exitvel * diam^2 * (stktmp - ambtmp) / (4 * stktmp)
  if (cls %in% c("E", "F")) {
    lapse <- if (!is.null(dthdz)) dthdz else if (cls == "E") 0.020 else 0.035
    s <- g * lapse / ambtmp
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
  list(flux = F_, finalrise = final, xfinal = xf, rise = rise)
}

#' Checks a Pasquill stability class.
#' @param stability The class passed by the user.
#' @return The class in upper case.
#' @noRd
.ad_class <- function(stability) {
  cls <- toupper(as.character(stability))
  if (length(cls) != 1L || is.na(cls) || !cls %in% c("A", "B", "C", "D", "E", "F")) {
    stop("`stability` must be one of the Pasquill classes \"A\" to \"F\"", call. = FALSE)
  }
  cls
}

#' Checks that the setting is \code{"rural"} or \code{"urban"}.
#' @param setting The setting passed by the user.
#' @return `setting`.
#' @noRd
.ad_setting <- function(setting) {
  if (!is.character(setting) || length(setting) != 1L || !setting %in% c("rural", "urban")) {
    stop("`setting` must be \"rural\" or \"urban\"", call. = FALSE)
  }
  setting
}

#' Vertical term: ground reflection, plus image pairs under a mixing lid.
#' @param z The receptor heights.
#' @param h The release height.
#' @param sz The vertical dispersion coefficients.
#' @param lid The mixing height, or NULL for no lid.
#' @param n_images The number of image pairs under the lid.
#' @return The vertical term at each receptor.
#' @noRd
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

#' Receptors as an n x 3 matrix, from a matrix or a list of coordinate triples.
#' @param r The receptors: a matrix, a data frame, a list of triples or a vector of x, y, z in turn.
#' @return An n x 3 matrix.
#' @noRd
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

#' @rdname pgsig
#' @export
gplume <- function(q, u, h, rcpt, stab = "D", set = "rural",
                           mixh = NULL, nimg = 3) {
  q <- .ad_num(q, "q", min = 0)
  u <- .ad_num(u, "u", positive = TRUE)
  h <- .ad_num(h, "h", min = 0)
  nimg <- .ad_check_images(nimg)
  mixh <- .ad_lid(mixh, h)
  R <- .ad_rec(rcpt)
  .ad_receptor_heights(R, mixh)
  nr <- nrow(R)
  pg <- blprog("Gaussian plume", nr)
  on.exit(pg$done(), add = TRUE)
  every <- max(1L, nr %/% 500L)
  vapply(seq_len(nr), function(i) {
    if (i %% every == 0L) pg$update(i, sprintf("receptor %d/%d", i, nr))
    x <- R[i, 1L]
    if (x <= 0) return(0)
    s <- pgsig(x, stab, set)
    sy <- s$sigmay
    sz <- s$sigmaz
    q / (2 * pi * u * sy * sz) * exp(-(R[i, 2L]^2) / (2 * sy * sy)) *
      .ad_vertical(R[i, 3L], h, sz, mixh, nimg)
  }, 0)
}

#' @rdname pgsig
#' @export
gspuff <- function(mass, u, h, rcpt, t, stab = "D", set = "rural",
                          mixh = NULL, nimg = 3) {
  mass <- .ad_num(mass, "mass", min = 0)
  u <- .ad_num(u, "u", positive = TRUE)
  h <- .ad_num(h, "h", min = 0)
  t <- .ad_num(t, "t", positive = TRUE)
  nimg <- .ad_check_images(nimg)
  mixh <- .ad_lid(mixh, h)
  .ad_receptor_heights(.ad_rec(rcpt), mixh)
  R <- .ad_rec(rcpt)
  s <- pgsig(u * t, stab, set)
  sy <- s$sigmay
  sz <- s$sigmaz
  k <- mass / ((2 * pi)^1.5 * sy * sy * sz)
  nr <- nrow(R)
  pg <- blprog("Gaussian puff", nr)
  on.exit(pg$done(), add = TRUE)
  every <- max(1L, nr %/% 500L)
  vapply(seq_len(nr), function(i) {
    if (i %% every == 0L) pg$update(i, sprintf("receptor %d/%d", i, nr))
    k * exp(-(R[i, 1L] - u * t)^2 / (2 * sy * sy)) * exp(-(R[i, 2L]^2) / (2 * sy * sy)) *
      .ad_vertical(R[i, 3L], h, sz, mixh, nimg)
  }, 0)
}

#' @rdname pgsig
#' @section Boundary: the outermost ring of cells is held at zero (an open boundary):
#'   mass
#'   that reaches it leaves the domain and \code{mass} falls accordingly. Pad \code{c0}
#'   with
#'   empty cells so the plume of interest stays inside the ring.
#' @export
advdif2d <- function(c0, u, v, kx, ky, dx, dy, dt, nsteps, source = NULL, maxwork = 1e8) {
  .rmbl_no_fn(source = source)
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
  nsteps <- .ad_num(nsteps, "nsteps", min = 0, whole = TRUE)
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
  work <- as.numeric(nx) * ny * nsteps * substeps
  if (!is.finite(work)) stop("the amount of work is not finite: check nsteps and the grid", call. = FALSE)
  if (!is.numeric(maxwork) || length(maxwork) != 1L || is.na(maxwork) || maxwork <= 0) {
    stop("advdif2d: `maxwork` must be a single positive number (Inf lifts the cap)", call. = FALSE)
  }
  if (work > maxwork) {
    minutes <- work / 8e5 / 60   # about 0.8 million cell updates a second in the explicit loop
    stop(sprintf(paste("this run updates %s cells x steps x sub-steps (%d x %d cells, %s steps, %s sub-steps per",
                       "step%s), above maxwork = %s: about %s minutes of the explicit loop. Pass maxwork = Inf",
                       "to run it anyway, or use a coarser grid, fewer steps or a shorter total time"),
                 format(work, big.mark = ",", scientific = FALSE), nx, ny,
                 format(nsteps, big.mark = ",", scientific = FALSE),
                 format(substeps, big.mark = ",", scientific = FALSE),
                 if (substeps > 1) sprintf(" from a stability number of %s", format(stab, digits = 4)) else "",
                 format(maxwork, big.mark = ",", scientific = FALSE),
                 format(round(minutes, 1), big.mark = ",")), call. = FALSE)
  }
  # a count R can loop over, whatever maxwork allows: 1e300 died in seq_len() (review of 02a38be)
  if (nsteps > .Machine$integer.max) stop("advdif2d: `nsteps` must be at most 2^31 - 1", call. = FALSE)
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
    nsteps <- nsteps * substeps
  }
  pg <- blprog("advection-diffusion", nsteps)
  on.exit(pg$done(), add = TRUE)
  for (step in seq_len(nsteps)) {
    pg$update(step - 1L, sprintf("step %d/%s", step, format(nsteps, big.mark = ",", scientific = FALSE)))
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
                 difn = 2 * (dxn + dyn), stabn = stab, stable = stab <= 1,
                 dt = dt, substeps = substeps,
                 x = seq_len(nx) * dx, y = seq_len(ny) * dy, dx = dx, dy = dy,
                 units = "concentration",
                 title = sprintf("Advection-diffusion after %s steps of dt = %s",
                                 format(nsteps, big.mark = ",", scientific = FALSE), format(dt))),
            class = "rmbl_field")
}

#' Draws standard normals from the package's shared uniform stream.
#'
#' Standard normals from the package's shared uniform stream: one stream per
#' (seed, stream) pair, through the normal quantile. The uniforms are kept
#' strictly inside (0, 1) so the quantile is finite.
#' @param n The number of draws.
#' @param seed The seed.
#' @param stream The stream within the seed.
#' @return A vector of `n` normals.
#' @noRd
.rmbl_normals <- function(n, seed = 0, stream = 0) {
  if (n == 0L) return(numeric(0))
  s <- (as.numeric(seed) * 65536 + as.numeric(stream)) %% 2147483647
  u <- cunif(n, seed = as.integer(s))
  eps <- .Machine$double.eps
  stats::qnorm(pmin(pmax(u, eps), 1 - eps))
}

#' @rdname pgsig
#' @export
lagrprt <- function(n, x0, y0, u, v, kx, ky, dt, nsteps, seed = 0, grid = NULL,
                                 normals = NULL, maxwork = 1e8) {
  seed <- .rmbl_r_seed(seed)
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
  nsteps <- .ad_num(nsteps, "nsteps", min = 0, whole = TRUE)
  if (!is.numeric(maxwork) || length(maxwork) != 1L || is.na(maxwork) || maxwork <= 0) {
    stop("lagrprt: `maxwork` must be a single positive number (Inf lifts the cap)", call. = FALSE)
  }
  # the same cap as advdif2d(): particles x steps (nsteps = 1e9 built a 7.5 GB
  # index vector and would have run for about 32 hours, review of 52a8883)
  if (n * nsteps > maxwork) {
    stop(sprintf(paste("this run moves %s particles x %s steps, above maxwork = %s; pass maxwork = Inf",
                       "to run it anyway"), format(n, big.mark = ","),
                 format(nsteps, big.mark = ",", scientific = FALSE),
                 format(maxwork, big.mark = ",", scientific = FALSE)), call. = FALSE)
  }
  # a count R can loop over, whatever maxwork allows: 1e300 died in seq_len() (review of 02a38be)
  if (nsteps > .Machine$integer.max) stop("lagrprt: `nsteps` must be at most 2^31 - 1", call. = FALSE)
  # a function, or NULL; what it returns is checked every step: a name went to match.fun() and a
  # wrong length was recycled into the positions silently (CRAN stress test of b617a3f)
  draw <- if (is.null(normals)) {
    .rmbl_normals
  } else if (is.function(normals)) {
    function(n, seed, stream) {
      # called as normals(n, seed, stream): a function that takes other arguments is said so
      z <- tryCatch(normals(n, seed, stream), error = function(e) {
        stop(sprintf("`normals` failed when called as normals(n, seed, stream): %s", conditionMessage(e)),
             call. = FALSE)
      })
      if (!is.numeric(z) || length(z) != n || any(!is.finite(z))) {
        stop(sprintf("`normals` must return %d finite numbers; it returned %s", n,
                     if (is.numeric(z)) sprintf("%d, %d of them finite", length(z), sum(is.finite(z)))
                     else paste("a", class(z)[[1L]])), call. = FALSE)
      }
      as.numeric(z)
    }
  } else {
    stop("`normals` must be a function (n, seed, stream) or NULL", call. = FALSE)
  }
  xs <- rep(x0, n)
  ys <- rep(y0, n)
  fx <- sqrt(2 * kx * dt)
  fy <- sqrt(2 * ky * dt)
  pg <- blprog("particles", nsteps)
  on.exit(pg$done(), add = TRUE)
  # a step can be a few microseconds (one particle): the bar hears of every thousandth
  every <- max(1, nsteps %/% 1000)
  for (step in seq_len(nsteps)) {
    if (step %% every == 0) {
      pg$update(step - 1L, sprintf("step %s/%s", format(step, big.mark = ",", scientific = FALSE),
                                   format(nsteps, big.mark = ",", scientific = FALSE)))
    }
    k <- step - 1
    xs <- xs + u * dt + fx * draw(n, seed, 2 * k)
    ys <- ys + v * dt + fy * draw(n, seed, 2 * k + 1)
  }
  out <- list(x = xs, y = ys, mean_x = sum(xs) / n, meany = sum(ys) / n, grid = grid)
  if (!is.null(grid)) {
    if (length(grid) != 6L) stop("`grid` must be c(xmin, x_max, y_min, y_max, nx, ny)", call. = FALSE)
    grid <- .ad_num(grid, "grid", scalar = FALSE)
    if (grid[2L] <= grid[1L] || grid[4L] <= grid[3L] || grid[5L] < 1 || grid[6L] < 1 ||
          grid[5L] != round(grid[5L]) || grid[6L] != round(grid[6L])) {
      stop("`grid` needs xmin < x_max, y_min < y_max and whole positive nx, ny", call. = FALSE)
    }
    if (grid[5L] * grid[6L] > maxwork) {
      stop(sprintf(paste("a %s x %s grid has %s cells, above maxwork = %s; pass maxwork = Inf to allocate it",
                         "anyway"), format(grid[5L], big.mark = ","), format(grid[6L], big.mark = ","),
                   format(grid[5L] * grid[6L], big.mark = ",", scientific = FALSE),
                   format(maxwork, big.mark = ",", scientific = FALSE)), call. = FALSE)
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

#' Checks the number of image pairs under the mixing lid.
#'
#' The lid's image terms shrink geometrically: past a few pairs they add nothing but time, and
#' 1e9 of them took about 480 s per receptor (review of 52a8883)
#' @param n_images The value passed by the user.
#' @return The number of image pairs.
#' @noRd
.ad_check_images <- function(n_images) {
  n_images <- .ad_num(n_images, "n_images", min = 0, whole = TRUE)
  if (n_images > 1000) {
    stop("`nimg` must be at most 1,000: the image terms decay geometrically and more add only time", call. = FALSE)
  }
  n_images
}
