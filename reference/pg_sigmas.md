# Atmospheric dispersion: sigmas, plume rise, plume, puff, grid and particles

Six standard models of how a pollutant released into the air spreads
downwind, for exposure estimates around a stack, a fire or an industrial
site (for example when relating air quality to health or justice
outcomes by neighbourhood):

- `pg_sigmas()`: how wide and how tall a plume has grown at a given
  distance, by atmospheric stability class;

- `briggs_plume_rise()`: how far a hot plume rises above the stack top;

- `gaussian_plume()`: the steady concentration at receptor points from a
  continuous release;

- `gaussian_puff()`: the concentration from a single instantaneous
  release, some time after it;

- `advection_diffusion_2d()`: a concentration field on a grid moved by
  wind and spread by diffusion, step by step;

- `lagrangian_particles()`: the same physics as a random walk of many
  particles.

They are screening models with textbook assumptions (flat terrain,
steady uniform wind, no chemistry or deposition), not regulatory model
runs.

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

advection_diffusion_2d(
  c0,
  u,
  v,
  kx,
  ky,
  dx,
  dy,
  dt,
  n_steps,
  source = NULL,
  max_work = 1e+08
)

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
  normals = NULL,
  max_work = 1e+08
)
```

## Arguments

- x:

  Downwind distance(s) in metres.

- stability:

  Pasquill stability class, one of `"A"` to `"F"`.

- setting:

  `"rural"` (the default) or `"urban"`: which set of Briggs coefficients
  to use.

- u:

  Wind speed in m/s (the x velocity for the grid models).

- diameter, exit_velocity, stack_temp, ambient_temp:

  Stack diameter (m), exit velocity (m/s), stack gas and ambient
  temperatures (K). Only buoyant rise is modelled: a stack at the air's
  temperature (within half a kelvin) has zero rise, and momentum rise
  from the exit velocity is not added.

- dtheta_dz:

  Potential temperature gradient (K/m) for the stable classes; the
  defaults are 0.020 (E) and 0.035 (F).

- g:

  Gravitational acceleration in m/s^2, default 9.80616.

- q:

  Emission rate (mass per second, for example g/s).

- h:

  Effective stack height (m): physical height plus plume rise.

- receptors:

  A matrix with columns x, y, z, or a list of length-3 vectors.

- mixing_height:

  Mixing-lid height in metres, or `NULL` (the default) for no lid. Under
  a lid the plume is reflected between the ground and the lid.

- n_images:

  Whole number, default 3: the number of lid image pairs (0 to 1,000).
  The terms decay quickly; a few are enough.

- mass:

  Puff mass (for example g).

- t:

  Time since release (s).

- c0:

  Initial concentration grid: a non-negative numeric matrix, one row per
  x cell and one column per y cell.

- v:

  Wind velocity along y (m/s), may be negative.

- kx, ky:

  Eddy diffusivities along x and y (m^2/s), non-negative.

- dx, dy:

  Grid spacings (m), positive.

- dt:

  Time step (s), positive.

- n_steps:

  Whole number of time steps (0 returns the start).

- source:

  Source grid (concentration per unit time), or `NULL`.

- max_work:

  The most cell updates (cells x steps x sub-steps; for
  `lagrangian_particles()`, particles x steps) a run may take, 100
  million by default (a few minutes of the explicit loop); `Inf` lifts
  it. The same physical run costs the same whether the caller sub-steps
  it or the scheme does, so the cap reads the same either way.

- n:

  Whole number of particles, at most 100 million.

- x0, y0:

  Release point (m).

- seed:

  Number, default 0: the seed of the particle random walk.

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
image; `lagrangian_particles()` a list of class `rmbl_particles` that
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws as
points, with `x`, `y` (final particle positions), `mean_x`, `mean_y`,
`grid` (as given) and, with a grid, `concentration` (an `nx` by `ny`
matrix of particle density per unit area, summing to the share of
particles inside the grid divided by the cell area).

## Details

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

The stability classes run from `"A"` (very unstable, sunny with light
wind) through `"D"` (neutral, overcast or windy) to `"F"` (stable, clear
night with light wind). Units are SI: metres, seconds, kelvin; with `q`
in g/s, `gaussian_plume()` returns g/m^3, and with `mass` in g,
`gaussian_puff()` returns g/m^3. The plume is not defined at or upwind
of the source: a receptor with \\x \le 0\\ gets 0. The plume's `h` is
the effective height, the stack height plus the rise from
`briggs_plume_rise()`.

Every physical input is checked: emission rates, masses, heights and
distances are non-negative, wind speed, travel time and grid steps
positive, `n_images` a whole number up to 1,000, the stack as hot as the
air or hotter (temperatures below 150 are refused as probably Celsius),
and `x0`, `y0` single numbers; a release above `mixing_height` warns,
and so does a receptor below ground or above the lid (the reflection
terms give mirror values there). Unknown stability classes or settings
are errors.

Cost: `gaussian_plume()` and `gaussian_puff()` are fast for thousands of
receptors. `advection_diffusion_2d()` is an R loop at roughly 0.8
million cell updates a second, and both grid models refuse a run above
`max_work` cell or particle updates. The particle walk is reproducible
from `seed` and does not touch R's random number stream. Progress bars
are shown in an interactive session.

## Boundary

the outermost ring of cells is held at zero (an open boundary): mass
that reaches it leaves the domain and `mass` falls accordingly. Pad `c0`
with empty cells so the plume of interest stays inside the ring.

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
# plume widths 1 km downwind: neutral, then very stable, rural and urban
pg_sigmas(1000, "D")
#> $sigma_y
#> [1] 76.27701
#> 
#> $sigma_z
#> [1] 37.94733
#> 
pg_sigmas(c(500, 1000, 2000), "F", setting = "urban")
#> $sigma_y
#> [1]  50.20790  92.96697 163.97832
#> 
#> $sigma_z
#> [1] 30.23716 50.59644 80.00000
#> 

# rise of a hot plume, and the effective height it gives a 50 m stack
rise <- briggs_plume_rise(c(100, 1000), u = 4, diameter = 1, exit_velocity = 12,
                          stack_temp = 420, ambient_temp = 285)
rise$rise
#> [1] 18.22335 28.88281
h_eff <- 50 + rise$final_rise

# ground-level concentration (g/m^3) from 100 g/s along the centreline
rec <- cbind(x = c(500, 1000, 2000, 8000), y = 0, z = 0)
gaussian_plume(100, u = 4, h = h_eff, receptors = rec)
#> [1] 2.120279e-05 3.168716e-04 3.826280e-04 1.051326e-04

# under a 120 m mixing lid the far receptor sees a trapped plume
gaussian_plume(100, u = 4, h = h_eff, receptors = rec, mixing_height = 120)
#> [1] 2.120279e-05 3.172063e-04 4.073068e-04 1.738501e-04

# a 1 kg puff, 10 minutes after release, at the puff centre
gaussian_puff(1000, u = 3, h = 10, receptors = rbind(c(1800, 0, 0)), t = 600)
#> [1] 0.0001266794

# a small grid: a blob moved by wind and spread by diffusion
c0 <- matrix(0, 15, 15)
c0[4, 8] <- 1
f <- advection_diffusion_2d(c0, u = 1, v = 0, kx = 0.5, ky = 0.5,
                            dx = 1, dy = 1, dt = 0.2, n_steps = 20)
f$stable
#> [1] TRUE
round(f$mass, 3)
#> [1] 0.962

# 2,000 particles, counted on a grid
p <- lagrangian_particles(2000, x0 = 0, y0 = 0, u = 1, v = 0, kx = 1, ky = 1,
                          dt = 1, n_steps = 10, seed = 1,
                          grid = c(-10, 30, -20, 20, 8, 8))
c(p$mean_x, p$mean_y)
#> [1] 10.033977334 -0.003237509

# inputs that cannot be right are refused
try(pg_sigmas(100, "G"))
#> Error : `stability` must be one of the Pasquill classes "A" to "F"
try(briggs_plume_rise(100, u = 4, diameter = 1, exit_velocity = 12,
                      stack_temp = 150 + 5, ambient_temp = 20))
#> Error : temperatures are in kelvin: stack_temp 155 and ambient_temp 20 look like degrees Celsius (ambient air is about 290 K)
```
