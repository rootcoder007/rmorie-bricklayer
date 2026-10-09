# Energy and carbon footprint of a computation

Evaluates `expr` and reports the electricity it used and the
CO2-equivalent that electricity implies, by one of two methods, for the
grid it ran on, offline.

## Usage

``` r
compute_footprint(
  expr,
  location = NULL,
  method = c("auto", "rapl", "model"),
  cpu_power_w = NULL,
  usage = "process",
  load_curve = c("linear", "codecarbon"),
  cores = NULL,
  memory_gb = NULL,
  memory_power_w_per_gb = 0.3725,
  pue = 1,
  rapl_dir = "/sys/class/powercap",
  proc_stat = "/proc/stat"
)
```

## Arguments

- expr:

  The expression to evaluate.

- location:

  Passed to
  [`carbon_intensity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/carbon_intensity.md):
  a location code, alpha-3 code or name, a number in gCO2e/kWh, or
  `NULL` (the default) to detect it.

- method:

  `"auto"` (RAPL when readable, else the model), `"rapl"` or `"model"`.

- cpu_power_w:

  The CPU's total thermal design power in watts (the model's
  \\P\_{cpu}\\); `NULL` uses codecarbon's unknown-CPU fallback.

- usage:

  `"process"` (measured from this process's CPU time), `"machine"`
  (measured from the whole machine's CPU accounting), or a number in
  between 0 and 1. `NULL` means `"process"`.

- load_curve:

  `"linear"` (Green Algorithms) or `"codecarbon"`.

- cores:

  Number of logical cores the process utilisation is measured against;
  `NULL` detects it.

- memory_gb:

  Memory charged to the computation in GB; `NULL` detects the machine's
  total memory where it can, else assumes 8 GB.

- memory_power_w_per_gb:

  Memory power per GB (default 0.3725 W/GB, Green Algorithms; codecarbon
  v2 used 0.375).

- pue:

  Power usage effectiveness: 1 for a laptop or desktop (default); 1.67
  is the Green Algorithms default for a data centre, 1.56 the Uptime
  Institute 2024 global average.

- rapl_dir:

  The powercap directory holding the RAPL domains.

- proc_stat:

  The kernel CPU accounting file read for `usage = "machine"`.

## Value

A list of class `rmbl_footprint`: `value` (the result of `expr`),
`duration_s`, `cpu_time_s`, `usage`, `usage_mode` (`"process"`,
`"machine"` or `"fixed"`), `cores`, `memory_gb`, `energy_kwh` (with
`cpu`, `memory`, `total`), `co2e_g`, `carbon_intensity` (the row used,
with its year and source), `method`, `assumptions` and `citations`.

## Details

**Measured** (`method = "rapl"`): the CPU package energy counters (RAPL,
microjoules, read from `rapl_dir`) before and after, with wrap-around
handled through `max_energy_range_uj`. This is what codecarbon does on
Linux; the counters cover the CPU packages only, so memory is still
modelled. Available when
[`rapl_available()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/rapl_available.md)
is `TRUE`.

**Modelled** (`method = "model"`): the Green Algorithms formula
(Lannelongue, Grealey and Inouye 2021), \$\$E = t \\(P\_{cpu}\\ u + M\\
P\_{mem})\\ PUE\$\$ with \\t\\ the running time, \\P\_{cpu}\\ the CPU's
thermal design power in watts, \\u\\ its utilisation, \\M\\ the memory
in GB, \\P\_{mem} = 0.3725\\ W/GB and \\PUE\\ the data-centre overhead.
When the CPU's power is unknown the fallback is codecarbon's: 50\\
constant 85 W.

**Utilisation** is measured, not assumed, in one of two ways.
`usage = "process"` (the default) is this R process's own CPU time,
children included, divided by the wall time and the core count:
codecarbon's process tracking mode, which charges only what the
computation itself used. `usage = "machine"` is the whole machine's busy
share over the run, from `/proc/stat` on Linux: codecarbon's machine
tracking mode, right when the computation is the only thing the machine
is doing or when the question is what the machine drew. Where
`/proc/stat` is absent the process figure is used and the assumptions
say so. A number between 0 and 1 fixes the utilisation, as the Green
Algorithms calculator asks for it. `load_curve` chooses how power scales
with that utilisation: linearly (Green Algorithms) or along codecarbon's
curves, a floor at 10\\ \\P\_{cpu}\\ for a process and \\0.1 + 0.9 u^3\\
for a machine, so a figure can be made comparable with either tool.

Cross-checked against codecarbon 3.3.1 on one workload with the same
forced inputs: memory energy identical (5.96 W for 16 GB), CPU energy
within 8\\ `load_curve = "codecarbon"` reproduces its power-from-load
curves, so what remains of the difference is the load measurement itself
(codecarbon samples the load during the run; this function integrates
the CPU time).

Emissions are \\E \times\\ the carbon intensity of the location
([`carbon_intensity`](https://rootcoder007.github.io/rmorie-bricklayer/reference/carbon_intensity.md):
a bundled table of every country at its latest published year and of
sub-national zones, so no network access is needed anywhere). With
`location = NULL` the location is detected from the environment, the
time zone or the locale
([`detect_location`](https://rootcoder007.github.io/rmorie-bricklayer/reference/detect_location.md))
and the detection is recorded. Every default that stood in for a
measurement is listed in `assumptions`, so a report can say what was
measured and what was assumed.

## References

Lannelongue, L., Grealey, J. and Inouye, M. (2021). Green Algorithms:
quantifying the carbon footprint of computation. Advanced Science 8(12),
2100707. Courty, B. et al. (2024). CodeCarbon: estimate and track carbon
emissions from machine learning computing.
[doi:10.5281/zenodo.4658424](https://doi.org/10.5281/zenodo.4658424) .
Lacoste, A., Luccioni, A., Schmidt, V. and Dandres, T. (2019).
Quantifying the carbon emissions of machine learning. arXiv:1910.09700.

## Examples

``` r
fp <- compute_footprint(sum(sqrt(seq_len(2e5))), location = "CA-ON")
fp$energy_kwh$total
#> [1] 4.02635e-08
fp$co2e_g
#> [1] 3.662771e-06
fp$carbon_intensity$year
#> [1] 2024
fp$assumptions
#> [1] "CPU power unknown: 85 W x 50% (codecarbon fallback)"
#> [2] "memory charged: the machine's total 15.6 GB"        
print(fp)
#> Computation footprint (modelled): 0.003 s wall, 0.003 s CPU, utilisation 0.25 (process) on 4 cores
#>   energy: 4.03e-08 kWh (cpu 3.54e-08, memory 4.85e-09)
#>   CO2e:   3.66e-06 g at 90.97 gCO2e/kWh (Canada, Ontario, 2024)
#>   assumed: CPU power unknown: 85 W x 50% (codecarbon fallback); memory charged: the machine's total 15.6 GB 
# wherever you are, offline: the location is detected and recorded
compute_footprint(1 + 1, cpu_power_w = 45, memory_gb = 8)$assumptions
#> [1] "location WORLD via fallback, no location found in environment, time zone or locale"
# the whole machine's utilisation, on codecarbon's machine curve
compute_footprint(1 + 1, location = "FR", usage = "machine", load_curve = "codecarbon",
                  cpu_power_w = 45, memory_gb = 8)$usage_mode
#> [1] "machine"
```
