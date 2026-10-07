# SPDX-License-Identifier: AGPL-3.0-or-later
# The energy and carbon footprint of a computation: measured from the CPU's
# RAPL energy counters when the operating system exposes them, otherwise
# modelled from running time, measured utilisation (process or machine) and
# memory with the Green Algorithms method (Lannelongue, Grealey and Inouye
# 2021), and converted to CO2-equivalents with a bundled, offline,
# per-location carbon-intensity table at each location's latest year. The constants and
# fallbacks follow the two reference tools, codecarbon and the Green
# Algorithms calculator, and every one is named in the result's assumptions.

# Carbon intensity of electricity, gCO2e/kWh, bundled for offline use in
# inst/extdata/carbon_intensity.csv: every country at the latest year Our
# World in Data publishes (Ember yearly electricity data, 2024 or 2025),
# sub-national zones (Canadian provinces, US balancing authorities,
# Australian states, Indian and Japanese regions, ...) from Electricity Maps'
# 2024 yearly file as redistributed by Green Algorithms data v3.1, and the
# world average. Every row carries its year, its basis (lifecycle) and source.
.rmbl_ci_cache <- new.env(parent = emptyenv())

.rmbl_extdata <- function(name) {
  system.file("extdata", name, package = "rmoriebricklayer", mustWork = TRUE)
}

.rmbl_ci_table <- function() {
  if (is.null(.rmbl_ci_cache$tab)) {
    .rmbl_ci_cache$tab <- utils::read.csv(
      .rmbl_extdata("carbon_intensity.csv"), stringsAsFactors = FALSE, na.strings = character(0),
      colClasses = c("character", "character", "character", "numeric", "integer", "character",
                     "character"))
  }
  .rmbl_ci_cache$tab
}

.rmbl_tz_table <- function() {
  if (is.null(.rmbl_ci_cache$tz)) {
    .rmbl_ci_cache$tz <- utils::read.csv(.rmbl_extdata("timezone_countries.csv"), stringsAsFactors = FALSE,
                                         na.strings = character(0), colClasses = "character")
  }
  .rmbl_ci_cache$tz
}

# Row index of a location key in the table: by code (CA, CA-ON, US-CAL-CISO),
# by ISO 3166-1 alpha-3 (CAN), or by name (Canada); NA when none matches.
.rmbl_ci_match <- function(key, tab) {
  key <- toupper(trimws(key))
  i <- match(key, tab$location)
  if (is.na(i)) i <- match(key, tab$iso3)
  if (is.na(i)) i <- match(key, toupper(tab$name))
  i
}

#' Carbon intensity of electricity by location, offline, anywhere
#'
#' The grams of CO2-equivalent emitted per kilowatt-hour of electricity at a
#' location, with the year and source of the figure. The table is bundled with
#' the package, so it works offline in any country: every country at the
#' latest year published by Our World in Data from Ember's yearly electricity
#' data (2024 or 2025 as of this release), sub-national zones from Electricity
#' Maps' 2024 yearly data as redistributed in the Green Algorithms data release
#' v3.1 (Canadian provinces and territories, US balancing authorities,
#' Australian states, Indian and Japanese regions, Brazilian and Chilean
#' systems, ...), and the world average. All figures are lifecycle intensities
#' (generation plus upstream), the basis both sources publish.
#'
#' A location is matched by its code (\code{"CA"}, \code{"CA-ON"},
#' \code{"US-CAL-CISO"}), its ISO 3166-1 alpha-3 code (\code{"CAN"}) or its
#' name (\code{"Canada"}), case-insensitively. An unknown sub-national code
#' falls back to its country and says so in \code{note}. \code{NULL} detects
#' the location with \code{\link{detect_location}}.
#'
#' @param location A location code, alpha-3 code or name; a number in
#'   gCO2e/kWh, returned as a user-supplied value; or \code{NULL} to detect
#'   the location from the environment, time zone or locale.
#' @return \code{carbon_intensity()}: a list with \code{g_per_kwh},
#'   \code{location}, \code{name}, \code{year}, \code{basis}, \code{source}
#'   and \code{note} (a character vector, empty unless a fallback or detection
#'   was involved). \code{carbon_intensity_table()}: the full table as a data
#'   frame with the same columns plus \code{iso3}.
#' @references Ember (2026). Yearly Electricity Data, via Our World in Data,
#'   \url{https://ourworldindata.org/grapher/carbon-intensity-electricity}.
#'   Electricity Maps (2025). 2024 Yearly Carbon Intensity Data, via Green
#'   Algorithms data v3.1. Lannelongue, L., Grealey, J. and Inouye, M. (2021).
#'   Green Algorithms: quantifying the carbon footprint of computation.
#'   Advanced Science 8(12), 2100707.
#' @examples
#' carbon_intensity("CA-ON")
#' carbon_intensity("Canada")$year
#' carbon_intensity("CA-XX")$note
#' carbon_intensity(120)$source
#' nrow(carbon_intensity_table())
#' @export
carbon_intensity <- function(location = "WORLD") {
  if (is.numeric(location)) {
    if (length(location) != 1L || !is.finite(location) || location < 0) {
      stop("a numeric `location` must be a single non-negative gCO2e/kWh value", call. = FALSE)
    }
    return(list(g_per_kwh = as.numeric(location), location = "user", name = "user-supplied",
                year = NA_integer_, basis = "user", source = "user-supplied carbon intensity",
                note = character(0)))
  }
  note <- character(0)
  if (is.null(location)) {
    det <- detect_location()
    location <- det$location
    note <- c(note, sprintf("location %s via %s", det$location, det$method))
  }
  if (!is.character(location) || length(location) != 1L || is.na(location)) {
    stop("`location` must be a single location code or name, a number in gCO2e/kWh, or NULL",
         call. = FALSE)
  }
  tab <- .rmbl_ci_table()
  i <- .rmbl_ci_match(location, tab)
  if (is.na(i) && grepl("-", location, fixed = TRUE)) {
    country <- sub("-.*$", "", location)
    i <- .rmbl_ci_match(country, tab)
    if (!is.na(i)) {
      note <- c(note, sprintf("no row for zone %s; its country %s used", toupper(location),
                              tab$location[i]))
    }
  }
  if (is.na(i)) {
    stop(sprintf(paste("Unknown location '%s'. Use a code, alpha-3 code or name from",
                       "carbon_intensity_table(), or pass a number in gCO2e/kWh."), location),
         call. = FALSE)
  }
  list(g_per_kwh = tab$g_per_kwh[i], location = tab$location[i], name = tab$name[i],
       year = tab$year[i], basis = tab$basis[i], source = tab$source[i], note = note)
}

#' @rdname carbon_intensity
#' @export
carbon_intensity_table <- function() .rmbl_ci_table()

#' Where is this computation running?
#'
#' Finds a location code for \code{\link{carbon_intensity}} without any
#' network access, in this order: the \code{RMBL_LOCATION} environment
#' variable (any code or name the table knows); codecarbon's
#' \code{CODECARBON_COUNTRY_ISO_CODE} (alpha-3), so a machine already
#' configured for codecarbon needs nothing more; the system time zone, mapped
#' to its country through the IANA zone table (\code{America/Toronto} is
#' Canada, \code{Europe/Berlin} Germany); the territory in the locale
#' (\code{en_CA.UTF-8} is Canada). When none of these yields a location in
#' the table the answer is \code{"WORLD"}, and the method says so, so a report
#' never silently applies one country's grid to another's computation.
#'
#' @param env_location,codecarbon_location,tz,locale The inputs, exposed so a
#'   caller or a test can supply them; the defaults read the running session.
#' @return A list with \code{location} (a code present in
#'   \code{carbon_intensity_table()}) and \code{method} (how it was found).
#' @examples
#' detect_location()
#' detect_location(env_location = "", codecarbon_location = "", tz = "Europe/Paris")
#' detect_location(env_location = "", codecarbon_location = "", tz = "",
#'                 locale = "en_IN.UTF-8")
#' @export
detect_location <- function(env_location = Sys.getenv("RMBL_LOCATION"),
                            codecarbon_location = Sys.getenv("CODECARBON_COUNTRY_ISO_CODE"),
                            tz = Sys.timezone(), locale = Sys.getlocale("LC_TIME")) {
  tab <- .rmbl_ci_table()
  known <- function(key) {
    if (is.null(key) || length(key) != 1L || is.na(key) || !nzchar(key)) return(NA_character_)
    i <- .rmbl_ci_match(key, tab)
    if (is.na(i)) NA_character_ else tab$location[i]
  }
  loc <- known(env_location)
  if (!is.na(loc)) return(list(location = loc, method = "RMBL_LOCATION environment variable"))
  loc <- known(codecarbon_location)
  if (!is.na(loc)) return(list(location = loc, method = "CODECARBON_COUNTRY_ISO_CODE environment variable"))
  if (length(tz) == 1L && !is.na(tz) && nzchar(tz)) {
    tzt <- .rmbl_tz_table()
    loc <- known(tzt$location[match(tz, tzt$tz)])
    if (!is.na(loc)) return(list(location = loc, method = sprintf("system time zone %s", tz)))
  }
  if (length(locale) == 1L && !is.na(locale)) {
    m <- regmatches(locale, regexpr("^[A-Za-z]{2,3}_[A-Z]{2}", locale))
    if (length(m) == 1L) {
      loc <- known(sub("^.*_", "", m))
      if (!is.na(loc)) return(list(location = loc, method = sprintf("locale %s", locale)))
    }
  }
  list(location = "WORLD", method = "fallback, no location found in environment, time zone or locale")
}

# ---- RAPL -------------------------------------------------------------------

# The package-level RAPL domains under a powercap directory: directories named
# intel-rapl:N (not the :N:M subdomains, which are parts of the package and
# would count the same energy twice), whose `name` starts with "package".
.rapl_domains <- function(rapl_dir) {
  if (!dir.exists(rapl_dir)) return(character(0))
  d <- list.files(rapl_dir, pattern = "^intel-rapl:[0-9]+$", full.names = TRUE)
  keep <- vapply(d, function(p) {
    nm <- tryCatch(readLines(file.path(p, "name"), n = 1L, warn = FALSE), error = function(e) "")
    file.exists(file.path(p, "energy_uj")) && length(nm) == 1L && startsWith(nm, "package")
  }, logical(1))
  d[keep]
}

# Energy counters (microjoules) of the package domains, or NULL when any is
# unreadable (on Linux 5.10 and later the files are root-only by default).
.rapl_read <- function(domains) {
  if (!length(domains)) return(NULL)
  vals <- vapply(domains, function(p) {
    v <- tryCatch(suppressWarnings(as.numeric(readLines(file.path(p, "energy_uj"), n = 1L, warn = FALSE))),
                  error = function(e) NA_real_)
    if (length(v) != 1L) NA_real_ else v
  }, numeric(1))
  if (anyNA(vals)) return(NULL)
  maxes <- vapply(domains, function(p) {
    v <- tryCatch(suppressWarnings(as.numeric(readLines(file.path(p, "max_energy_range_uj"), n = 1L, warn = FALSE))),
                  error = function(e) NA_real_)
    if (length(v) != 1L || is.na(v)) NA_real_ else v
  }, numeric(1))
  list(uj = vals, max = maxes)
}

#' Is CPU energy measurable here?
#'
#' \code{TRUE} when the operating system exposes readable RAPL (Running
#' Average Power Limit) energy counters for at least one CPU package: Linux
#' with the \code{intel_rapl} powercap driver (Intel and, since kernel 5.8,
#' AMD), with read permission on \code{energy_uj}. On most systems since
#' Linux 5.10 that file is readable by root only, so \code{FALSE} is the
#' common answer for an ordinary user, and \code{\link{compute_footprint}}
#' then falls back to its model.
#'
#' @param rapl_dir The powercap directory; the default is the Linux location.
#' @return A single logical.
#' @examples
#' rapl_available()
#' @export
rapl_available <- function(rapl_dir = "/sys/class/powercap") {
  !is.null(.rapl_read(.rapl_domains(rapl_dir)))
}

# ---- memory and cores ---------------------------------------------------------

.rmbl_total_memory_gb <- function(meminfo = "/proc/meminfo", sysname = Sys.info()[["sysname"]],
                                  sysctl = Sys.which("sysctl")) {
  if (file.exists(meminfo)) {
    l <- tryCatch(readLines(meminfo, warn = FALSE), error = function(e) character(0))
    m <- grep("^MemTotal:", l, value = TRUE)
    kb <- suppressWarnings(as.numeric(gsub("[^0-9]", "", m)))
    if (length(kb) == 1L && is.finite(kb) && kb > 0) return(kb / 1024^2)
  }
  if (identical(sysname, "Darwin") && nzchar(sysctl)) {
    b <- tryCatch(suppressWarnings(as.numeric(system2(sysctl, c("-n", "hw.memsize"), stdout = TRUE))),
                  error = function(e) NA_real_)
    if (length(b) == 1L && is.finite(b) && b > 0) return(b / 1024^3)
  }
  NA_real_
}

# CPU seconds between two proc.time() readings, children included. Windows
# reports the child times as NA, which would have turned every figure NA.
.rmbl_cpu_seconds <- function(t0, t1) {
  parts <- c("user.self", "sys.self", "user.child", "sys.child")
  d <- unname(t1[parts]) - unname(t0[parts])
  max(sum(d[is.finite(d)]), 0)
}

.rmbl_cores <- function() {
  tryCatch(parallel::detectCores(logical = TRUE), error = function(e) NA_integer_)
}

# ---- utilisation ----------------------------------------------------------------

# Whole-machine CPU accounting from the first line of /proc/stat (Linux):
# idle + iowait jiffies and the total, or NULL where the file is absent.
.proc_stat_cpu <- function(proc_stat) {
  l <- tryCatch(suppressWarnings(readLines(proc_stat, n = 1L, warn = FALSE)), error = function(e) character(0))
  if (length(l) != 1L || !startsWith(l, "cpu ")) return(NULL)
  v <- suppressWarnings(as.numeric(strsplit(trimws(l), "\\s+")[[1]][-1]))
  if (length(v) < 4L || anyNA(v)) return(NULL)
  c(idle = v[4] + if (length(v) >= 5L) v[5] else 0, total = sum(v))
}

# CPU power at a utilisation u, as a fraction of the CPU's power P: Green
# Algorithms' linear scaling, or codecarbon's curve for the matching mode (a
# floor at 10% of P when tracking a process; 0.1 + 0.9 u^3 for the machine).
.cpu_load_power <- function(p, u, load_curve, usage_mode) {
  if (load_curve == "linear") return(p * u)
  if (usage_mode == "machine") p * (0.1 + 0.9 * u^3) else max(p * u, 0.1 * p)
}

# ---- the footprint ------------------------------------------------------------

#' Energy and carbon footprint of a computation
#'
#' Evaluates \code{expr} and reports the electricity it used and the
#' CO2-equivalent that electricity implies, by one of two methods, for the
#' grid it ran on, offline.
#'
#' \strong{Measured} (\code{method = "rapl"}): the CPU package energy
#' counters (RAPL, microjoules, read from \code{rapl_dir}) before and after,
#' with wrap-around handled through \code{max_energy_range_uj}. This is what
#' codecarbon does on Linux; the counters cover the CPU packages only, so
#' memory is still modelled. Available when \code{\link{rapl_available}()} is
#' \code{TRUE}.
#'
#' \strong{Modelled} (\code{method = "model"}): the Green Algorithms formula
#' (Lannelongue, Grealey and Inouye 2021),
#' \deqn{E = t \,(P_{cpu}\, u + M\, P_{mem})\, PUE}
#' with \eqn{t} the running time, \eqn{P_{cpu}} the CPU's thermal design
#' power in watts, \eqn{u} its utilisation, \eqn{M} the memory in GB,
#' \eqn{P_{mem} = 0.3725} W/GB and \eqn{PUE} the data-centre overhead. When
#' the CPU's power is unknown the fallback is codecarbon's: 50\% of a
#' constant 85 W.
#'
#' \strong{Utilisation} is measured, not assumed, in one of two ways.
#' \code{usage = "process"} (the default) is this R process's own CPU time,
#' children included, divided by the wall time and the core count: codecarbon's
#' process tracking mode, which charges only what the computation itself used.
#' \code{usage = "machine"} is the whole machine's busy share over the run,
#' from \code{/proc/stat} on Linux: codecarbon's machine tracking mode, right
#' when the computation is the only thing the machine is doing or when the
#' question is what the machine drew. Where \code{/proc/stat} is absent the
#' process figure is used and the assumptions say so. A number between 0 and 1
#' fixes the utilisation, as the Green Algorithms calculator asks for it.
#' \code{load_curve} chooses how power scales with that utilisation: linearly
#' (Green Algorithms) or along codecarbon's curves, a floor at 10\% of
#' \eqn{P_{cpu}} for a process and \eqn{0.1 + 0.9 u^3} for a machine, so a
#' figure can be made comparable with either tool.
#'
#' Cross-checked against codecarbon 3.3.1 on one workload with the same forced
#' inputs: memory energy identical (5.96 W for 16 GB), CPU energy within 8\%.
#' \code{load_curve = "codecarbon"} reproduces its power-from-load curves, so
#' what remains of the difference is the load measurement itself (codecarbon
#' samples the load during the run; this function integrates the CPU time).
#'
#' Emissions are \eqn{E \times} the carbon intensity of the location
#' (\code{\link{carbon_intensity}}: a bundled table of every country at its
#' latest published year and of sub-national zones, so no network access is
#' needed anywhere). With \code{location = NULL} the location is detected
#' from the environment, the time zone or the locale
#' (\code{\link{detect_location}}) and the detection is recorded. Every
#' default that stood in for a measurement is listed in \code{assumptions}, so
#' a report can say what was measured and what was assumed.
#'
#' @param expr The expression to evaluate.
#' @param location Passed to \code{\link{carbon_intensity}}: a location code,
#'   alpha-3 code or name, a number in gCO2e/kWh, or \code{NULL} (the
#'   default) to detect it.
#' @param method \code{"auto"} (RAPL when readable, else the model),
#'   \code{"rapl"} or \code{"model"}.
#' @param cpu_power_w The CPU's total thermal design power in watts (the
#'   model's \eqn{P_{cpu}}); \code{NULL} uses codecarbon's unknown-CPU fallback.
#' @param usage \code{"process"} (measured from this process's CPU time),
#'   \code{"machine"} (measured from the whole machine's CPU accounting), or a
#'   number in between 0 and 1. \code{NULL} means \code{"process"}.
#' @param load_curve \code{"linear"} (Green Algorithms) or \code{"codecarbon"}.
#' @param cores Number of logical cores the process utilisation is measured
#'   against; \code{NULL} detects it.
#' @param memory_gb Memory charged to the computation in GB; \code{NULL}
#'   detects the machine's total memory where it can, else assumes 8 GB.
#' @param memory_power_w_per_gb Memory power per GB (default 0.3725 W/GB,
#'   Green Algorithms; codecarbon v2 used 0.375).
#' @param pue Power usage effectiveness: 1 for a laptop or desktop (default);
#'   1.67 is the Green Algorithms default for a data centre, 1.56 the Uptime
#'   Institute 2024 global average.
#' @param rapl_dir The powercap directory holding the RAPL domains.
#' @param proc_stat The kernel CPU accounting file read for
#'   \code{usage = "machine"}.
#' @return A list of class \code{rmbl_footprint}: \code{value} (the result of
#'   \code{expr}), \code{duration_s}, \code{cpu_time_s}, \code{usage},
#'   \code{usage_mode} (\code{"process"}, \code{"machine"} or \code{"fixed"}),
#'   \code{cores}, \code{memory_gb}, \code{energy_kwh} (with \code{cpu},
#'   \code{memory}, \code{total}), \code{co2e_g}, \code{carbon_intensity} (the
#'   row used, with its year and source), \code{method}, \code{assumptions}
#'   and \code{citations}.
#' @references Lannelongue, L., Grealey, J. and Inouye, M. (2021). Green
#'   Algorithms: quantifying the carbon footprint of computation. Advanced
#'   Science 8(12), 2100707. Courty, B. et al. (2024). CodeCarbon: estimate
#'   and track carbon emissions from machine learning computing.
#'   \doi{10.5281/zenodo.4658424}. Lacoste, A., Luccioni, A., Schmidt, V. and
#'   Dandres, T. (2019). Quantifying the carbon emissions of machine learning.
#'   arXiv:1910.09700.
#' @examples
#' fp <- compute_footprint(sum(sqrt(seq_len(2e5))), location = "CA-ON")
#' fp$energy_kwh$total
#' fp$co2e_g
#' fp$carbon_intensity$year
#' fp$assumptions
#' print(fp)
#' # wherever you are, offline: the location is detected and recorded
#' compute_footprint(1 + 1, cpu_power_w = 45, memory_gb = 8)$assumptions
#' # the whole machine's utilisation, on codecarbon's machine curve
#' compute_footprint(1 + 1, location = "FR", usage = "machine", load_curve = "codecarbon",
#'                   cpu_power_w = 45, memory_gb = 8)$usage_mode
#' @export
compute_footprint <- function(expr, location = NULL, method = c("auto", "rapl", "model"),
                              cpu_power_w = NULL, usage = "process",
                              load_curve = c("linear", "codecarbon"), cores = NULL,
                              memory_gb = NULL, memory_power_w_per_gb = 0.3725, pue = 1,
                              rapl_dir = "/sys/class/powercap", proc_stat = "/proc/stat") {
  method <- match.arg(method)
  load_curve <- match.arg(load_curve)
  ci <- carbon_intensity(location)
  if (!is.numeric(pue) || length(pue) != 1L || !is.finite(pue) || pue < 1) {
    stop("`pue` must be a single number >= 1", call. = FALSE)
  }
  if (is.null(usage)) usage <- "process"
  if (is.character(usage)) {
    usage_mode <- match.arg(usage, c("process", "machine"))
  } else if (is.numeric(usage) && length(usage) == 1L && is.finite(usage) && usage >= 0 && usage <= 1) {
    usage_mode <- "fixed"
  } else {
    stop("`usage` must be \"process\", \"machine\" or a single number in [0, 1]", call. = FALSE)
  }
  assumptions <- ci$note
  cites <- c("Lannelongue, Grealey & Inouye (2021) Adv Sci 8:2100707 (energy model, 0.3725 W/GB)",
             "codecarbon (RAPL method; process/machine tracking; 85 W x 50% unknown-CPU fallback)",
             sprintf("carbon intensity: %s (%s, %d)", ci$source, ci$name, ci$year))
  if (is.na(ci$year)) cites <- cites[-3L]

  domains <- if (method != "model") .rapl_domains(rapl_dir) else character(0)
  before <- if (method != "model") .rapl_read(domains) else NULL
  if (method == "rapl" && is.null(before)) {
    stop("RAPL energy counters are not readable here (see rapl_available()); use method = \"model\"",
         call. = FALSE)
  }
  used <- if (is.null(before)) "model" else "rapl"
  stat0 <- if (usage_mode == "machine") .proc_stat_cpu(proc_stat) else NULL
  if (usage_mode == "machine" && is.null(stat0)) {
    usage_mode <- "process"
    assumptions <- c(assumptions, "machine CPU accounting unreadable (no /proc/stat); process utilisation used")
  }

  t0 <- proc.time()
  value <- expr
  t1 <- proc.time()
  after <- if (used == "rapl") .rapl_read(domains) else NULL
  stat1 <- if (usage_mode == "machine") .proc_stat_cpu(proc_stat) else NULL

  wall <- max(unname(t1[["elapsed"]] - t0[["elapsed"]]), 0)
  cpu_t <- .rmbl_cpu_seconds(t0, t1)
  hours <- wall / 3600

  if (is.null(cores)) {
    cores <- .rmbl_cores()
    if (is.na(cores)) {
      cores <- 1L
      assumptions <- c(assumptions, "core count unknown; 1 assumed")
    }
  }
  if (usage_mode == "machine") {
    if (is.null(stat1)) {
      usage_mode <- "process"
      assumptions <- c(assumptions, "machine CPU accounting became unreadable; process utilisation used")
    } else {
      dt <- stat1[["total"]] - stat0[["total"]]
      usage <- if (dt > 0) min(max(1 - (stat1[["idle"]] - stat0[["idle"]]) / dt, 0), 1) else 0
    }
  }
  if (usage_mode == "process") {
    usage <- if (wall > 0) min(max(cpu_t / (wall * cores), 0), 1) else 0
  }

  if (used == "rapl" && !is.null(after)) {
    d <- after$uj - before$uj
    wrapped <- d < 0
    if (any(wrapped)) {
      if (anyNA(before$max[wrapped])) {
        used <- "model"
        assumptions <- c(assumptions, "a RAPL counter wrapped and its range was unknown; modelled instead")
      } else {
        d[wrapped] <- d[wrapped] + before$max[wrapped]
      }
    }
    if (used == "rapl") e_cpu_kwh <- sum(d) * 1e-6 / 3.6e6
  } else if (used == "rapl") {
    used <- "model"
    assumptions <- c(assumptions, "RAPL counters became unreadable during the run; modelled instead")
  }
  if (used == "model") {
    if (is.null(cpu_power_w)) {
      cpu_power_w <- 85 * 0.5
      assumptions <- c(assumptions, "CPU power unknown: 85 W x 50% (codecarbon fallback)")
      e_cpu_kwh <- hours * cpu_power_w / 1000
    } else {
      if (!is.numeric(cpu_power_w) || length(cpu_power_w) != 1L || cpu_power_w <= 0) {
        stop("`cpu_power_w` must be a single positive number of watts", call. = FALSE)
      }
      e_cpu_kwh <- hours * .cpu_load_power(cpu_power_w, usage, load_curve, usage_mode) / 1000
      if (load_curve == "codecarbon") {
        assumptions <- c(assumptions, sprintf("codecarbon %s load curve applied to the CPU power",
                                              if (usage_mode == "machine") "machine" else "process"))
      }
    }
  }

  if (is.null(memory_gb)) {
    memory_gb <- .rmbl_total_memory_gb()
    if (is.na(memory_gb)) {
      memory_gb <- 8
      assumptions <- c(assumptions, "memory size unknown: 8 GB assumed")
    } else {
      assumptions <- c(assumptions, sprintf("memory charged: the machine's total %.1f GB", memory_gb))
    }
  }
  e_mem_kwh <- hours * memory_gb * memory_power_w_per_gb / 1000
  total <- (e_cpu_kwh + e_mem_kwh) * pue
  if (pue > 1) assumptions <- c(assumptions, sprintf("PUE %.2f applied", pue))

  structure(list(
    value = value,
    duration_s = wall,
    cpu_time_s = cpu_t,
    usage = usage,
    usage_mode = usage_mode,
    cores = as.integer(cores),
    memory_gb = memory_gb,
    energy_kwh = list(cpu = e_cpu_kwh * pue, memory = e_mem_kwh * pue, total = total),
    co2e_g = total * ci$g_per_kwh,
    carbon_intensity = ci,
    method = used,
    assumptions = assumptions,
    citations = cites
  ), class = "rmbl_footprint")
}

#' @export
print.rmbl_footprint <- function(x, ...) {
  cat(sprintf("Computation footprint (%s): %.3f s wall, %.3f s CPU, utilisation %.2f (%s) on %d cores\n",
              if (x$method == "rapl") "measured, RAPL" else "modelled", x$duration_s, x$cpu_time_s,
              x$usage, x$usage_mode, x$cores))
  cat(sprintf("  energy: %.3g kWh (cpu %.3g, memory %.3g)\n", x$energy_kwh$total, x$energy_kwh$cpu,
              x$energy_kwh$memory))
  ci <- x$carbon_intensity
  cat(sprintf("  CO2e:   %.3g g at %.4g gCO2e/kWh (%s%s)\n", x$co2e_g, ci$g_per_kwh, ci$name,
              if (is.na(ci$year)) "" else sprintf(", %d", ci$year)))
  if (length(x$assumptions)) cat("  assumed:", paste(x$assumptions, collapse = "; "), "\n")
  invisible(x)
}

#' Everyday equivalents of a quantity of CO2-equivalent
#'
#' Kilometres driven in an average European passenger car (175 gCO2/km) and
#' tree-months of carbon sequestration (917 gCO2 per tree per month), the two
#' comparisons the Green Algorithms calculator prints, with their sources.
#'
#' @param co2e_g Grams of CO2-equivalent.
#' @return A list with \code{car_km}, \code{tree_months} and \code{sources}.
#' @references Green Algorithms data v3.1, context.csv: car factor from
#'   Helmers et al. (2019) Atmospheric Environment and UK BEIS 2019 conversion
#'   factors; tree sequestration from Bernal et al. (2018) via the same file.
#' @examples
#' footprint_equivalents(1200)
#' @export
footprint_equivalents <- function(co2e_g) {
  if (!is.numeric(co2e_g) || length(co2e_g) != 1L || !is.finite(co2e_g) || co2e_g < 0) {
    stop("`co2e_g` must be a single non-negative number", call. = FALSE)
  }
  list(car_km = co2e_g / 175, tree_months = co2e_g / 917,
       sources = c(car = "175 gCO2/km, European passenger car (Green Algorithms context.csv)",
                   tree = "917 gCO2 per tree-month (Green Algorithms context.csv)"))
}
