# Energy and carbon footprint of a computation

Evaluates `expr` and reports the electricity it used and the
CO2-equivalent that electricity implies, by one of two methods, for the
grid it ran on, offline. Use it to report the energy and emissions of an
analysis next to its results (as journals and funders increasingly ask),
or to compare two ways of running the same computation. The result keeps
the value of `expr`, and lists every figure that was assumed rather than
measured.

## Usage

``` r
co2fp(
  expr,
  loc = NULL,
  meth = c("auto", "rapl", "model"),
  cpupwrw = NULL,
  usage = "process",
  loadcur = c("linear", "codecarbon"),
  cores = NULL,
  memgb = NULL,
  mempwrwpergb = 0.3725,
  pue = 1,
  rapldir = "/sys/class/powercap",
  procstat = "/proc/stat"
)
```

## Arguments

- expr:

  The expression to evaluate. It is evaluated once, in the calling
  environment, when the function reaches it (lazily, as a promise).

- loc:

  The location, passed to
  [`co2int`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md).
  It is a location code, alpha-3 code or name, a number in gCO2e/kWh, or
  `NULL` (the default) to detect it.

- meth:

  Character scalar: `"auto"` (the default; RAPL when readable, else the
  model), `"rapl"` (measured; an error when the counters are not
  readable) or `"model"` (always the Green Algorithms model).

- cpupwrw:

  The CPU's total thermal design power in watts (the model's
  \\P\_{cpu}\\); `NULL` uses codecarbon's unknown-CPU fallback.

- usage:

  `"process"` (measured from this process's CPU time), `"machine"`
  (measured from the whole machine's CPU accounting), or a number in
  between 0 and 1. `NULL` means `"process"`.

- loadcur:

  Character scalar: `"linear"` (the default; power proportional to
  utilisation, as Green Algorithms) or `"codecarbon"` (codecarbon's
  curves, see Details). Applies only when `cpupwrw` is given.

- cores:

  Number of logical cores the process utilisation is measured against;
  `NULL` detects it.

- memgb:

  Memory charged to the computation in GB; `NULL` detects the machine's
  total memory where it can, else assumes 8 GB.

- mempwrwpergb:

  Memory power per GB (default 0.3725 W/GB, Green Algorithms; codecarbon
  v2 used 0.375).

- pue:

  Power usage effectiveness: 1 for a laptop or desktop (default); 1.67
  is the Green Algorithms default for a data centre, 1.56 the Uptime
  Institute 2024 global average. Must be a single number of at least 1.

- rapldir:

  Character scalar, the powercap directory holding the RAPL domains;
  default `"/sys/class/powercap"` (Linux).

- procstat:

  Character scalar, the kernel CPU accounting file read for
  `usage = "machine"`; default `"/proc/stat"` (Linux).

## Value

A list of class `rmbl_footprint` with elements `value` (the result of
`expr`), `durs` (numeric, wall seconds), `cputms` (numeric, CPU seconds
of this process and its children), `usage` (numeric in \\\[0, 1\]\\, the
utilisation), `usagemode` (`"process"`, `"machine"` or `"fixed"`),
`cores` (integer), `memgb` (numeric), `enekwh` (a list of numerics
`cpu`, `memory` and `total`, in kWh, PUE included), `co2eg` (numeric,
grams of CO2-equivalent), `co2int` (the list returned by
[`co2int`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md),
with its year and source), `method` (`"rapl"` or `"model"`, the method
actually used), `assumptions` (character vector of every default or
fallback that stood in for a measurement) and `citations` (character
vector). The print method shows a three-line summary.

## Details

**Measured** (`method = "rapl"`): the CPU package energy counters (RAPL,
microjoules, read from `rapldir`) before and after, with wrap-around
handled through `max_energy_range_uj`. This is what codecarbon does on
Linux; the counters cover the CPU packages only, so memory is still
modelled. Available when
[`raplok()`](https://rootcoder007.github.io/rmorie-bricklayer/reference/raplok.md)
is `TRUE`.

**Modelled** (`method = "model"`): the Green Algorithms formula
(Lannelongue, Grealey and Inouye 2021), \$\$E = t \\(P\_{cpu}\\ u + M\\
P\_{mem})\\ PUE\$\$ with \\t\\ the running time, \\P\_{cpu}\\ the CPU's
thermal design power in watts, \\u\\ its utilisation, \\M\\ the memory
in GB, \\P\_{mem} = 0.3725\\ W/GB and \\PUE\\ the data-centre overhead.
When the CPU's power is unknown (`cpupwrw = NULL`) the fallback is
codecarbon's: 50% of a constant 85 W, that is 42.5 W charged for the
whole running time whatever the measured utilisation (the utilisation is
still reported, but not applied).

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
Algorithms calculator asks for it. `loadcur` chooses how power scales
with that utilisation: linearly (Green Algorithms) or along codecarbon's
curves, a floor at 10% of \\P\_{cpu}\\ for a process and \\0.1 + 0.9
u^3\\ for a machine, so a figure can be made comparable with either
tool.

Cross-checked against codecarbon 3.3.1 on one workload with the same
forced inputs: memory energy identical (5.96 W for 16 GB), CPU energy
within 8%. `loadcur = "codecarbon"` reproduces its power-from-load
curves, so what remains of the difference is the load measurement itself
(codecarbon samples the load during the run; this function integrates
the CPU time).

Emissions are \\E \times\\ the carbon intensity of the location
([`co2int`](https://rootcoder007.github.io/rmorie-bricklayer/reference/co2int.md):
a bundled table of every country at its latest published year and of
sub-national zones, so no network access is needed anywhere). With
`location = NULL` the location is detected from the environment, the
time zone or the locale
([`dtctloc`](https://rootcoder007.github.io/rmorie-bricklayer/reference/dtctloc.md))
and the detection is recorded. Every default that stood in for a
measurement is listed in `assumptions`, so a report can say what was
measured and what was assumed.

The energy figures include the PUE factor (CPU, memory and total alike).
The running time has a floor of the CPU time divided by the cores, so a
computation faster than the clock's resolution does not come out at
zero. Short computations (well under a second) give figures dominated by
timer resolution; measure a representative workload.

Every argument is checked, and the carbon intensity looked up, before
`expr` is evaluated, so a bad argument never costs the computation.
Errors: an unknown `loc`; `pue` below 1 or not a single finite number;
`cpupwrw` or `cores` not a single positive number (`cores` also whole);
`memgb` or `mempwrwpergb` negative; `usage` other than `"process"`,
`"machine"` or one number in \\\[0, 1\]\\; `method = "rapl"` where the
counters are not readable. An error inside `expr` propagates unchanged.
Nothing is written and nothing is fetched.

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
fp <- co2fp(sum(sqrt(seq_len(2e5))), loc = "CA-ON")
fp$enekwh$total
#> [1] 2.684234e-08
fp$co2eg
#> [1] 2.441847e-06
fp$co2int$year
#> [1] 2024
fp$assumptions
#> [1] "CPU power unknown: 85 W x 50% (codecarbon fallback)"
#> [2] "memory charged: the machine's total 15.6 GB"        
print(fp)
#> ╭── Computation footprint (modelled) ─────────────────────────────────────────╮
#> │   Time         0.002 s wall, 0.002 s CPU                                    │
#> │   Utilisation  utilisation 0.25 (process) on 4 cores                        │
#> │   Memory       15.6 GB                                                      │
#> │   Energy       2.68e-08 kWh (cpu 2.36e-08, memory 3.23e-09)                 │
#> │   CO2e         2.44e-06 g at 90.97 gCO2e/kWh (Canada, Ontario, 2024)        │
#> │   Source       Electricity Maps (2025). Canada 2024 Yearly Carbon           │
#> │                Intensity Data (Version January 27, 2025). Electricity Maps  │
#> │                (via Green Algorithms data v3.1)                             │
#> │                                                                             │
#> │   An estimate of the energy this computation used and the emissions of      │
#> │   making it on the local grid; fpeqv() puts the grams in everyday terms.    │
#> │                                                                             │
#> │   assumed: CPU power unknown: 85 W x 50% (codecarbon fallback); memory      │
#> │   charged: the machine's total 15.6 GB                                      │
#> ╰─────────────────────────────────────────────────────────────────────────────╯
# wherever you are, offline: the location is detected and recorded
co2fp(1 + 1, cpupwrw = 45, memgb = 8)$assumptions
#> [1] "location WORLD via fallback, no location found in environment, time zone or locale"
# the whole machine's utilisation, on codecarbon's machine curve
co2fp(
  1 + 1,
  loc = "FR",
  usage = "machine",
  loadcur = "codecarbon",
  cpupwrw = 45,
  memgb = 8
)$usagemode
#> [1] "machine"
# a fixed utilisation and a data-centre PUE, with a carbon intensity given as
# a number
fp2 <- co2fp(
  sum(sqrt(seq_len(2e5))),
  loc = 30,
  usage = 0.5,
  cpupwrw = 65,
  memgb = 16,
  pue = 1.67,
  meth = "model"
)
fp2$enekwh
#> $cpu
#> [1] 4.522917e-08
#> 
#> $memory
#> [1] 8.294333e-09
#> 
#> $total
#> [1] 5.35235e-08
#> 
fpeqv(fp2$co2eg)
#> ╭── Footprint in everyday terms ────────────────────────────────────────╮
#> │   Car travel   9.175e-09 km                                           │
#> │   Tree uptake  1.751e-09 tree-months                                  │
#> │                                                                       │
#> │   The same emissions as driving a European passenger car this far, or │
#> │   what this many trees take up in a month.                            │
#> │                                                                       │
#> │   car: 175 gCO2/km, European passenger car (Green Algorithms          │
#> │   context.csv). tree: 917 gCO2 per tree-month (Green Algorithms       │
#> │   context.csv).                                                       │
#> ╰───────────────────────────────────────────────────────────────────────╯
# a bad argument is refused before the expression runs
try(co2fp(Sys.sleep(10), pue = 0.9))
#> Error : `pue` must be a single number >= 1
```
