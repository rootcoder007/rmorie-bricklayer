# Atmospheric dispersion: sigmas, plume rise, plume, puff, grid and particles

`pg_sigmas()`: Briggs (1973) fits of the Pasquill-Gifford dispersion
coefficients by stability class A-F, rural
`sigma_y = a_y x (1 + 0.0001 x)^(-1/2)` (urban: 0.0004) and
`sigma_z = a_z x (1 + b_z x)^(e_z)`. `briggs_plume_rise()`: buoyancy
flux `F = g v_s d^2 (T_s - T_a) / (4 T_s)`; final rise
`21.425 F^(3/4) / u` with `x_f = 49 F^(5/8)` when `F < 55`, else
`38.71 F^(3/5) / u` with `x_f = 119 F^(2/5)`, for classes A-D;
`2.6 (F / (u s))^(1/3)` with `s = g (dtheta/dz) / T_a` and
`x_f = 2.0715 u / sqrt(s)` for E and F; transitional rise
`1.6 F^(1/3) x^(2/3) / u` before `x_f` (EPA ISC3). `gaussian_plume()`:
`Q / (2 pi u sigma_y sigma_z) exp(-y^2 / (2 sigma_y^2)) V`, with `V` the
vertical term with ground reflection and, under a mixing lid, `n_images`
pairs of image terms. `gaussian_puff()`: an instantaneous release with
`sigma_x = sigma_y` evaluated at the travel distance `u t`.
`advection_diffusion_2d()`: explicit upwind advection, central
diffusion, forward Euler, zero boundaries. The explicit scheme is stable
when `|u dt/dx| + |v dt/dy| + 2 (kx dt/dx^2 + ky dt/dy^2) <= 1` (the von
Neumann bound for upwind advection with forward-time centred-space
diffusion); that sum is returned as `stability_number` with `stable`. A
call outside the bound is not run as given: each step is split into
enough sub-steps of a smaller `dt` to satisfy it (reported as `substeps`
and `dt`), with a warning, so the field is a solution over the same
physical time rather than a numerical explosion. The separate `cfl` and
`diffusion_number` are reported for reference; each below 1 is
necessary, not sufficient. `lagrangian_particles()`: the random walk
`x + u dt + sqrt(2 K dt) xi` (Thomson 1987) with an optional counting
grid.

## Usage

``` r
pg_sigmas(x, stability = "D", setting = "rural")

briggs_plume_rise(
  x,
  u,
  diameter,
  exit_velocity,
  stack_temp,
  ambient_temp,
  stability = "D",
  dtheta_dz = NULL,
  g = 9.80616
)

gaussian_plume(
  q,
  u,
  h,
  receptors,
  stability = "D",
  setting = "rural",
  mixing_height = NULL,
  n_images = 3
)

gaussian_puff(
  mass,
  u,
  h,
  receptors,
  t,
  stability = "D",
  setting = "rural",
  mixing_height = NULL,
  n_images = 3
)

advection_diffusion_2d(c0, u, v, kx, ky, dx, dy, dt, n_steps, source = NULL)

lagrangian_particles(
  n,
  x0,
  y0,
  u,
  v,
  kx,
  ky,
  dt,
  n_steps,
  seed = 0,
  grid = NULL,
  normals = NULL
)
```

## Arguments

- x:

  Downwind distance(s) in metres.

- stability:

  Pasquill stability class, one of `"A"` to `"F"`.

- setting:

  `"rural"` or `"urban"`.

- u:

  Wind speed in m/s (the x velocity for the grid models).

- diameter, exit_velocity, stack_temp, ambient_temp:

  Stack diameter (m), exit velocity (m/s), stack gas and ambient
  temperatures (K).

- dtheta_dz:

  Potential temperature gradient (K/m) for the stable classes; the
  defaults are 0.020 (E) and 0.035 (F).

- g:

  Gravitational acceleration.

- q:

  Emission rate (mass per second).

- h:

  Effective stack height (m).

- receptors:

  A matrix with columns x, y, z, or a list of length-3 vectors.

- mixing_height:

  Mixing-lid height, or `NULL` for no lid.

- n_images:

  Number of lid image pairs.

- mass:

  Puff mass.

- t:

  Time since release (s).

- c0:

  Initial concentration grid (a matrix).

- v:

  Velocity along y.

- kx, ky:

  Eddy diffusivities.

- dx, dy:

  Grid spacings.

- dt:

  Time step.

- n_steps:

  Number of steps.

- source:

  Source grid (concentration per unit time), or `NULL`.

- n:

  Number of particles.

- x0, y0:

  Release point.

- seed:

  Seed of the particle random walk.

- grid:

  `NULL`, or `c(x_min, x_max, y_min, y_max, nx, ny)` to count particles
  into a concentration grid.

- normals:

  A function `(n, seed, stream)` returning `n` standard normals; step
  `k` (from 0) draws streams `2k` for x and `2k + 1` for y. The default
  draws from the package's shared uniform stream
  ([`core_uniforms`](https://rootcoder007.github.io/rmorie-bricklayer/reference/core_uniforms.md))
  through the normal quantile. rmorie's `LagrangianParticles()` uses its
  own Philox stream, so its paths differ from the default here; pass its
  generator to reproduce them.

## Value

`pg_sigmas()`: a list with `sigma_y` and `sigma_z`.
`briggs_plume_rise()`: a list with `flux`, `final_rise`, `x_final` and
`rise` (at each `x`). `gaussian_plume()` and `gaussian_puff()`: a
numeric vector of concentrations, one per receptor.
`advection_diffusion_2d()`: a list with `field`, `mass`, `cfl`,
`diffusion_number`, `stability_number`, `stable`, `dt`, `substeps` and
the axes, as a list of class `rmbl_field` that
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws as an
image; `lagrangian_particles()` a list of class `rmbl_particles`
(positions, means and the counting grid) that
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws as
points. Every physical input is checked: emission rates, masses, heights
and distances are non-negative, wind speed, travel time and grid steps
positive, `n_images` a whole number, the stack hotter than the air, and
`x0`, `y0` single numbers; a release above `mixing_height` warns.
`lagrangian_particles()`: a list with `x`, `y`, `mean_x`, `mean_y` and,
with a grid, `concentration`.

## References

Briggs, G. A. (1973). Diffusion estimation for small emissions. ATDL
Contribution 79. Briggs, G. A. (1975). Plume rise predictions. American
Meteorological Society. Turner, D. B. (1970). Workbook of Atmospheric
Dispersion Estimates. EPA AP-26. Seinfeld, J. H. and Pandis, S. N.
(2016). Atmospheric Chemistry and Physics, 3rd ed. Thomson, D. J.
(1987). Criteria for the selection of stochastic models of particle
trajectories in turbulent flows. Journal of Fluid Mechanics 180,
529-556.

## Examples

``` r
pg_sigmas(1000, "D")
#> $sigma_y
#> [1] 76.27701
#> 
#> $sigma_z
#> [1] 37.94733
#> 
gaussian_plume(100, 5, 50, rbind(c(1000, 0, 0)))
#> [1] 0.0009232376
briggs_plume_rise(c(100, 1000), u = 4, diameter = 1, exit_velocity = 12,
                  stack_temp = 420, ambient_temp = 285)$rise
#> [1] 18.22335 28.88281
```
