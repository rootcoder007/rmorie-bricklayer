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
# World in Data publishes (Ember yearly electricity data, 2024 or 2025 for
# all but a few rows whose latest year is older, among them Ukraine (2022); each row carries its year),
# sub-national zones (Canadian provinces, US balancing authorities,
# Australian states, Indian and Japanese regions, ...) from Electricity Maps'
# 2024 yearly file as redistributed by Green Algorithms data v3.1, and the
# world average. Every row carries its year, its basis (lifecycle) and source.
.rmbl_ci_cache <- new.env(parent = emptyenv())

#' Returns the path of a file the package installs under extdata.
#' @param name The file name.
#' @return The full path; an error when the file is missing.
#' @noRd
.rmbl_extdata <- function(name) {
  system.file("extdata", name, package = "rmoriebricklayer", mustWork = TRUE)
}

#' Reads the bundled carbon-intensity table once and keeps it in the cache.
#' @return The table as a data frame.
#' @noRd
.rmbl_ci_table <- function() {
  if (is.null(.rmbl_ci_cache$tab)) {
    .rmbl_ci_cache$tab <- utils::read.csv(
      .rmbl_extdata("carbon_intensity.csv"), stringsAsFactors = FALSE, na.strings = character(0),
      colClasses = c("character", "character", "character", "numeric", "integer", "character",
                     "character"))
  }
  .rmbl_ci_cache$tab
}

#' Reads the bundled time-zone to country table once and keeps it in the cache.
#' @return The table as a data frame.
#' @noRd
.rmbl_tz_table <- function() {
  if (is.null(.rmbl_ci_cache$tz)) {
    .rmbl_ci_cache$tz <- utils::read.csv(.rmbl_extdata("timezone_countries.csv"), stringsAsFactors = FALSE,
                                         na.strings = character(0), colClasses = "character")
  }
  .rmbl_ci_cache$tz
}

#' Finds the row of a location key in the carbon-intensity table.
#'
#' Row index of a location key in the table: by code (CA, CA-ON, US-CAL-CISO),
#' by ISO 3166-1 alpha-3 (CAN), or by name (Canada); NA when none matches.
#' @param key The location key: a code, an ISO 3166-1 alpha-3 code or a name.
#' @param tab The carbon-intensity table.
#' @return The row index, or NA.
#' @noRd
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
#' data (the latest year each grid reports: 2025 or 2024 for nearly all, older
#' for a few grids, Ukraine (2022) among them, named in \code{year}), sub-national zones
#' from
#' Electricity
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
#' the location with \code{\link{dtctloc}}.
#'
#' @section Provenance and licence of the table:
#' The country rows are Ember's yearly electricity data as published by Our
#' World in Data (CC BY 4.0); the sub-national zones and the Canadian
#' provinces come from the Electricity Maps yearly files redistributed in
#' the Green Algorithms data repository (v3.1), under that repository's
#' terms, and the default PUE from the same repository. Every row names its
#' source and year. Values are reproduced unchanged: Ember reports three
#' small diesel grids (Montserrat, Saint Helena, Uzbekistan) at exactly
#' 1000 gCO2e/kWh and Turkmenistan's gas fleet at 1306, and the table does
#' not round or cap them. Kosovo appears once, under the code \code{XK}.
#'
#' @param loc A location code, alpha-3 code or name; a number in
#'   gCO2e/kWh, returned as a user-supplied value; or \code{NULL} to detect
#'   the location from the environment, time zone or locale.
#' @return \code{co2int()}: a list with \code{g_per_kwh},
#'   \code{location}, \code{name}, \code{year}, \code{basis}, \code{source}
#'   and \code{note} (a character vector, empty unless a fallback or detection
#'   was involved). \code{co2inttab()}: the full table as a data
#'   frame with the same columns plus \code{iso3}.
#' @references Ember (2026). Yearly Electricity Data, via Our World in Data,
#'   \url{https://ourworldindata.org/grapher/carbon-intensity-electricity}.
#'   Electricity Maps (2025). 2024 Yearly Carbon Intensity Data, via Green
#'   Algorithms data v3.1. Lannelongue, L., Grealey, J. and Inouye, M. (2021).
#'   Green Algorithms: quantifying the carbon footprint of computation.
#'   Advanced Science 8(12), 2100707.
#' @examples
#' co2int("CA-ON")
#' co2int("Canada")$year
#' co2int("CA-XX")$note
#' co2int(120)$source
#' nrow(co2inttab())
#' # the Canadian provinces in the table, lowest intensity first
#' tab <- co2inttab()
#' ca <- tab[startsWith(tab$location, "CA-"), c("location", "name", "g_per_kwh", "year")]
#' head(ca[order(ca$g_per_kwh), ])
#' # a location the table does not know is an error, not a silent world average
#' try(co2int("Atlantis"))
#' @export
co2int <- function(loc = "WORLD") {
  if (is.numeric(loc)) {
    if (length(loc) != 1L || !is.finite(loc) || loc < 0) {
      stop("a numeric `loc` must be a single non-negative gCO2e/kWh value", call. = FALSE)
    }
    return(list(g_per_kwh = as.numeric(loc), location = "user", name = "user-supplied",
                year = NA_integer_, basis = "user", source = "user-supplied carbon intensity",
                note = character(0)))
  }
  note <- character(0)
  if (is.null(loc)) {
    det <- dtctloc()
    loc <- det$location
    note <- c(note, sprintf("location %s via %s", det$location, det$method))
  }
  if (!is.character(loc) || length(loc) != 1L || is.na(loc)) {
    stop("`loc` must be a single location code or name, a number in gCO2e/kWh, or NULL",
         call. = FALSE)
  }
  tab <- .rmbl_ci_table()
  i <- .rmbl_ci_match(loc, tab)
  if (is.na(i) && grepl("-", loc, fixed = TRUE)) {
    country <- sub("-.*$", "", loc)
    i <- .rmbl_ci_match(country, tab)
    if (!is.na(i)) {
      note <- c(note, sprintf("no row for zone %s; its country %s used", toupper(loc),
                              tab$location[i]))
    }
  }
  if (is.na(i)) {
    stop(sprintf(paste("Unknown location '%s'. Use a code, alpha-3 code or name from",
                       "co2inttab(), or pass a number in gCO2e/kWh."), loc),
         call. = FALSE)
  }
  list(g_per_kwh = tab$g_per_kwh[i], location = tab$location[i], name = tab$name[i],
       year = tab$year[i], basis = tab$basis[i], source = tab$source[i], note = note)
}

#' @rdname co2int
#' @export
co2inttab <- function() .rmbl_ci_table()

#' Where is this computation running?
#'
#' Finds a location code for \code{\link{co2int}} without any
#' network access, in this order:
#' \enumerate{
#'   \item the \code{RMBL_LOCATION} environment variable (any code or name the
#'     table knows);
#'   \item \code{CODECARBON_COUNTRY_ISO_CODE} (alpha-3), the codecarbon variable,
#'     so a machine already configured for codecarbon needs nothing more;
#'   \item the system time zone, mapped to its country through the IANA zone
#'     tables (\code{America/Toronto} is Canada, \code{Europe/Berlin} Germany);
#'   \item the territory in the locale (\code{en_CA.UTF-8} is Canada).
#' }
#' When none of these yields a location in
#' the table the answer is \code{"WORLD"}, and the method says so, so a report
#' never silently applies one country's grid to another's computation.
#'
#' The zone table (\code{inst/extdata/timezone_countries.csv}, built by
#' \code{tools/build_timezones.R} from the IANA database) holds every zone
#' of \code{zone.tab}, which names exactly one country per zone
#' (\code{Europe/Stockholm} is Sweden even though the database now keeps
#' its rules under \code{Europe/Berlin}), plus the aliases and old names of
#' the \code{backward} file under their own country: the country of the zone
#' the alias stood for before the database merged it (\code{Iceland} is
#' \code{Atlantic/Reykjavik}, Iceland, not Abidjan's Ivory Coast), the
#' link target's country when that target serves a single country
#' (\code{Asia/Calcutta}, \code{US/Eastern}), and a reviewed list for the
#' rest (\code{Atlantic/Jan_Mayen}, \code{America/Coral_Harbour},
#' \code{Canada/Eastern}). Every geographic zone \code{OlsonNames()} lists
#' resolves to a country or territory; a territory the carbon table has no
#' row of its own for (Monaco, Jersey, Vaduz, the Antarctic stations) uses
#' the grid of the country it draws on or the world average, and the method
#' says which. The \code{Etc/}, \code{UTC}, fixed-offset and generic zones
#' (\code{CET}, \code{EST}, \code{WET}) name no country and fall through
#' to the locale.
#'
#' @param envloc,codloc,tz,locale The inputs, exposed so a
#'   caller or a test can supply them; the defaults read the running session.
#' @return A list with \code{location} (a code present in
#'   \code{co2inttab()}) and \code{method} (how it was found).
#' @examples
#' dtctloc()
#' dtctloc(envloc = "", codloc = "", tz = "Europe/Paris")
#' dtctloc(envloc = "", codloc = "", tz = "",
#'                 locale = "en_IN.UTF-8")
#' # an explicit setting wins over everything else
#' dtctloc(envloc = "CA-QC", tz = "Europe/Paris")
#' # nothing usable: the world average, and the method says so
#' dtctloc(envloc = "", codloc = "", tz = "UTC", locale = "C")
#' @export
dtctloc <- function(envloc = Sys.getenv("RMBL_LOCATION"),
                            codloc = Sys.getenv("CODECARBON_COUNTRY_ISO_CODE"),
                            tz = Sys.timezone(), locale = Sys.getlocale("LC_TIME")) {
  for (nm in c("envloc", "codloc", "tz", "locale")) {
    v <- get(nm)
    if (!is.null(v) && !(is.character(v) && length(v) <= 1L)) {
      stop(sprintf("`%s` must be one string (or NULL)", nm), call. = FALSE)
    }
  }
  tab <- .rmbl_ci_table()
  known <- function(key) {
    if (is.null(key) || length(key) != 1L || is.na(key) || !nzchar(key)) return(NA_character_)
    i <- .rmbl_ci_match(key, tab)
    if (is.na(i)) NA_character_ else tab$location[i]
  }
  loc <- known(envloc)
  if (!is.na(loc)) return(list(location = loc, method = "RMBL_LOCATION environment variable"))
  if (length(envloc) == 1L && !is.na(envloc) && nzchar(envloc)) {
    warning(sprintf(paste("RMBL_LOCATION='%s' is not a location co2inttab() knows",
                          "(code, alpha-3 or name); it is ignored"), envloc), call. = FALSE)
  }
  loc <- known(codloc)
  if (!is.na(loc)) return(list(location = loc, method = "CODECARBON_COUNTRY_ISO_CODE environment variable"))
  if (length(tz) == 1L && !is.na(tz) && nzchar(tz)) {
    tzt <- .rmbl_tz_table()
    # the posix/ and right/ trees repeat every zone; strip them before the lookup
    key <- sub("^(posix|right)/", "", tz)
    terr <- tzt$location[match(key, tzt$tz)]
    loc <- known(terr)
    if (!is.na(loc)) return(list(location = loc, method = sprintf("system time zone %s", tz)))
    # the zone resolves to a territory the carbon table has no row for (Monaco, Jersey, the
    # Antarctic stations): the territory's grid is its administering or neighbouring country's,
    # or the world average, never the locale's country
    if (length(terr) == 1L && !is.na(terr)) {
      loc <- .rmbl_territory_location(terr, known)
      return(list(location = loc,
                  method = sprintf("system time zone %s (territory %s has no row of its own; %s)", tz, terr,
                                   if (identical(loc, "WORLD")) "world average" else paste("grid of", loc))))
    }
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

# Territories the time-zone table names that the carbon-intensity table has no row for, with
# the country whose grid they draw on (an enclave or dependency) or none (an island state and
# Antarctica take the world average).
.rmbl_territory_proxy <- c(
  AD = "ES", AI = "AG", BL = "GP", BQ = "NL", CC = "AU", CX = "AU", GG = "FR", IM = "GB", IO = "GB",
  JE = "FR", LI = "CH", MC = "FR", MF = "GP", MP = "GU", NF = "AU", PN = "GB", SJ = "NO", SM = "IT",
  SX = "NL", UM = "US", VA = "IT", WF = "NC",
  AQ = NA_character_, MH = NA_character_, NU = NA_character_, TF = NA_character_, TK = NA_character_,
  TV = NA_character_
)

#' Picks the carbon-intensity location for a territory.
#'
#' The grid a territory draws on: its proxy country when the carbon table has that row, the world
#' average when the territory has no proxy or the proxy itself is missing from the table.
#' @param terr The territory's two-letter code.
#' @param known A function that maps a country code to its location in the table, or NA.
#' @param proxies The named vector of proxy countries.
#' @return A location code, \code{"WORLD"} when no proxy is known.
#' @noRd
.rmbl_territory_location <- function(terr, known, proxies = .rmbl_territory_proxy) {
  proxy <- proxies[terr]
  loc <- if (is.na(proxy)) NA_character_ else known(unname(proxy))
  if (is.na(loc)) "WORLD" else loc
}

# ---- RAPL -------------------------------------------------------------------

#' Lists the package-level RAPL domains under a powercap directory.
#'
#' The package-level RAPL domains under a powercap directory: directories named
#' intel-rapl:N (not the :N:M subdomains, which are parts of the package and
#' would count the same energy twice), whose `name` starts with \code{"package"}.
#' @param rapl_dir The powercap directory.
#' @return The domain directories, possibly none.
#' @noRd
.rapl_domains <- function(rapl_dir) {
  if (!dir.exists(rapl_dir)) return(character(0))
  d <- list.files(rapl_dir, pattern = "^intel-rapl:[0-9]+$", full.names = TRUE)
  keep <- vapply(d, function(p) {
    nm <- tryCatch(readLines(file.path(p, "name"), n = 1L, warn = FALSE), error = function(e) "")
    file.exists(file.path(p, "energy_uj")) && length(nm) == 1L && startsWith(nm, "package")
  }, logical(1))
  d[keep]
}

#' Reads the energy counters of the RAPL package domains.
#'
#' Energy counters (microjoules) of the package domains, or NULL when any is
#' unreadable (on Linux 5.10 and later the files are root-only by default).
#' @param domains The domain directories from `.rapl_domains()`.
#' @return A list with `uj` (the counters) and `max` (their wrap-around ranges), or NULL.
#' @noRd
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
#' common answer for an ordinary user, and \code{\link{co2fp}}
#' then falls back to its model.
#'
#' @details
#' A domain counts when it is a directory named \code{intel-rapl:N} (the
#' \code{intel-rapl:N:M} subdomains are parts of a package and would count
#' the same energy twice) whose \code{name} file starts with
#' \code{"package"} and whose \code{energy_uj} file holds a number. Every
#' such domain must be readable: if any is not, the answer is \code{FALSE}.
#' Only files under \code{rapldir} are read; nothing is written. On macOS
#' and Windows there is no such directory and the answer is \code{FALSE}.
#' Errors when \code{rapldir} is not a single non-missing string.
#'
#' @param rapldir Character scalar, the powercap directory; default
#'   \code{"/sys/class/powercap"}, the Linux location. Another path is useful
#'   for testing against a copy of the directory tree.
#' @return A logical scalar: \code{TRUE} when every CPU-package energy counter
#'   under \code{rapldir} is readable, \code{FALSE} otherwise (including
#'   when the directory does not exist).
#' @seealso \code{\link{co2fp}}
#' @examples
#' raplok()
#'
#' # a fake powercap tree with one readable package domain (Linux names the domain
#' # "intel-rapl:0"; a colon is not allowed in a Windows file name)
#' if (.Platform$OS.type != "windows") {
#'   d <- file.path(tempfile(), "intel-rapl:0")
#'   dir.create(d, recursive = TRUE)
#'   writeLines("package-0", file.path(d, "name"))
#'   writeLines("123456789", file.path(d, "energy_uj"))
#'   raplok(dirname(d))
#' }
#'
#' # a folder that does not exist is simply FALSE; a non-path is an error
#' raplok(file.path(tempdir(), "no-such-dir"))
#' try(raplok(NA_character_))
#' @export
raplok <- function(rapldir = "/sys/class/powercap") {
  if (!is.character(rapldir) || length(rapldir) != 1L || is.na(rapldir)) {
    stop("`rapldir` must be a single directory path", call. = FALSE)
  }
  !is.null(.rapl_read(.rapl_domains(rapldir)))
}

# ---- memory and cores ---------------------------------------------------------

#' Reads the machine's total memory in gigabytes.
#' @param meminfo The Linux meminfo file.
#' @param sysname The operating system's name, as `Sys.info()` gives it.
#' @param sysctl The path of the sysctl program, used on macOS.
#' @return The memory in GB, or NA when it cannot be read.
#' @noRd
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

#' Counts the CPU seconds between two proc.time() readings.
#'
#' CPU seconds between two proc.time() readings, children included. Windows
#' reports the child times as NA, which would have turned every figure NA.
#' @param t0 The `proc.time()` reading at the start.
#' @param t1 The `proc.time()` reading at the end.
#' @return The CPU seconds used, never negative.
#' @noRd
.rmbl_cpu_seconds <- function(t0, t1) {
  parts <- c("user.self", "sys.self", "user.child", "sys.child")
  d <- unname(t1[parts]) - unname(t0[parts])
  max(sum(d[is.finite(d)]), 0)
}

#' Counts the machine's logical cores.
#' @return The number of cores, or NA.
#' @noRd
.rmbl_cores <- function() {
  tryCatch(parallel::detectCores(logical = TRUE), error = function(e) NA_integer_)
}

# ---- utilisation ----------------------------------------------------------------

#' Reads the whole machine's idle and total CPU time on Linux.
#'
#' Whole-machine CPU accounting from the first line of /proc/stat (Linux):
#' idle + iowait jiffies and the total, or NULL where the file is absent.
#' @param proc_stat The path of the stat file, normally /proc/stat.
#' @return A named vector with `idle` and `total` jiffies, or NULL.
#' @noRd
.proc_stat_cpu <- function(proc_stat) {
  l <- tryCatch(suppressWarnings(readLines(proc_stat, n = 1L, warn = FALSE)), error = function(e) character(0))
  if (length(l) != 1L || !startsWith(l, "cpu ")) return(NULL)
  v <- suppressWarnings(as.numeric(strsplit(trimws(l), "\\s+")[[1]][-1]))
  if (length(v) < 4L || anyNA(v)) return(NULL)
  c(idle = v[4] + if (length(v) >= 5L) v[5] else 0, total = sum(v))
}

#' Scales the CPU's power to a utilisation.
#'
#' CPU power at a utilisation u, as a fraction of the CPU's power P: Green
#' Algorithms' linear scaling, or codecarbon's curve for the matching mode (a
#' floor at 10% of P when tracking a process; 0.1 + 0.9 u^3 for the machine).
#' @param p The CPU's power.
#' @param u The utilisation, a fraction from 0 to 1.
#' @param load_curve \code{"linear"} for Green Algorithms' scaling, anything else for
#' codecarbon's curve.
#' @param usage_mode \code{"machine"} or \code{"process"}.
#' @return The power drawn, in the units of `p`.
#' @noRd
.cpu_load_power <- function(p, u, load_curve, usage_mode) {
  if (load_curve == "linear") return(p * u)
  if (usage_mode == "machine") p * (0.1 + 0.9 * u^3) else max(p * u, 0.1 * p)
}

# ---- the footprint ------------------------------------------------------------

#' Energy and carbon footprint of a computation
#'
#' Evaluates \code{expr} and reports the electricity it used and the
#' CO2-equivalent that electricity implies, by one of two methods, for the
#' grid it ran on, offline. Use it to report the energy and emissions of an
#' analysis next to its results (as journals and funders increasingly ask),
#' or to compare two ways of running the same computation. The result keeps
#' the value of \code{expr}, and lists every figure that was assumed rather
#' than measured.
#'
#' @details
#' \strong{Measured} (\code{method = "rapl"}): the CPU package energy
#' counters (RAPL, microjoules, read from \code{rapldir}) before and after,
#' with wrap-around handled through \code{max_energy_range_uj}. This is what
#' codecarbon does on Linux; the counters cover the CPU packages only, so
#' memory is still modelled. Available when \code{\link{raplok}()} is
#' \code{TRUE}.
#'
#' \strong{Modelled} (\code{method = "model"}): the Green Algorithms formula
#' (Lannelongue, Grealey and Inouye 2021),
#' \deqn{E = t \,(P_{cpu}\, u + M\, P_{mem})\, PUE}
#' with \eqn{t} the running time, \eqn{P_{cpu}} the CPU's thermal design
#' power in watts, \eqn{u} its utilisation, \eqn{M} the memory in GB,
#' \eqn{P_{mem} = 0.3725} W/GB and \eqn{PUE} the data-centre overhead. When
#' the CPU's power is unknown (\code{cpupwrw = NULL}) the fallback is
#' codecarbon's: 50% of a constant 85 W, that is 42.5 W charged for the whole
#' running time whatever the measured utilisation (the utilisation is still
#' reported, but not applied).
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
#' \code{loadcur} chooses how power scales with that utilisation: linearly
#' (Green Algorithms) or along codecarbon's curves, a floor at 10% of
#' \eqn{P_{cpu}} for a process and \eqn{0.1 + 0.9 u^3} for a machine, so a
#' figure can be made comparable with either tool.
#'
#' Cross-checked against codecarbon 3.3.1 on one workload with the same forced
#' inputs: memory energy identical (5.96 W for 16 GB), CPU energy within 8%.
#' \code{loadcur = "codecarbon"} reproduces its power-from-load curves, so
#' what remains of the difference is the load measurement itself (codecarbon
#' samples the load during the run; this function integrates the CPU time).
#'
#' Emissions are \eqn{E \times} the carbon intensity of the location
#' (\code{\link{co2int}}: a bundled table of every country at its
#' latest published year and of sub-national zones, so no network access is
#' needed anywhere). With \code{location = NULL} the location is detected
#' from the environment, the time zone or the locale
#' (\code{\link{dtctloc}}) and the detection is recorded. Every
#' default that stood in for a measurement is listed in \code{assumptions}, so
#' a report can say what was measured and what was assumed.
#'
#' The energy figures include the PUE factor (CPU, memory and total alike).
#' The running time has a floor of the CPU time divided by the cores, so a
#' computation faster than the clock's resolution does not come out at zero.
#' Short computations (well under a second) give figures dominated by timer
#' resolution; measure a representative workload.
#'
#' Every argument is checked, and the carbon intensity looked up, before
#' \code{expr} is evaluated, so a bad argument never costs the computation.
#' Errors: an unknown \code{loc}; \code{pue} below 1 or not a single
#' finite number; \code{cpupwrw} or \code{cores} not a single positive
#' number (\code{cores} also whole); \code{memgb} or
#' \code{mempwrwpergb} negative; \code{usage} other than
#' \code{"process"}, \code{"machine"} or one number in \eqn{[0, 1]};
#' \code{method = "rapl"} where the counters are not readable. An error
#' inside \code{expr} propagates unchanged. Nothing is written and nothing is
#' fetched.
#'
#' @param expr The expression to evaluate. It is evaluated once, in the
#'   calling environment, when the function reaches it (lazily, as a
#'   promise).
#' @param loc The location, passed to \code{\link{co2int}}. It is a location
#'   code, alpha-3 code or name, a number in gCO2e/kWh, or \code{NULL} (the
#'   default) to detect it.
#' @param meth Character scalar: \code{"auto"} (the default; RAPL when
#'   readable, else the model), \code{"rapl"} (measured; an error when the
#'   counters are not readable) or \code{"model"} (always the Green
#'   Algorithms model).
#' @param cpupwrw The CPU's total thermal design power in watts (the
#'   model's \eqn{P_{cpu}}); \code{NULL} uses codecarbon's unknown-CPU fallback.
#' @param usage \code{"process"} (measured from this process's CPU time),
#'   \code{"machine"} (measured from the whole machine's CPU accounting), or a
#'   number in between 0 and 1. \code{NULL} means \code{"process"}.
#' @param loadcur Character scalar: \code{"linear"} (the default; power
#'   proportional to utilisation, as Green Algorithms) or \code{"codecarbon"}
#'   (codecarbon's curves, see Details). Applies only when
#'   \code{cpupwrw} is given.
#' @param cores Number of logical cores the process utilisation is measured
#'   against; \code{NULL} detects it.
#' @param memgb Memory charged to the computation in GB; \code{NULL}
#'   detects the machine's total memory where it can, else assumes 8 GB.
#' @param mempwrwpergb Memory power per GB (default 0.3725 W/GB,
#'   Green Algorithms; codecarbon v2 used 0.375).
#' @param pue Power usage effectiveness: 1 for a laptop or desktop (default);
#'   1.67 is the Green Algorithms default for a data centre, 1.56 the Uptime
#'   Institute 2024 global average. Must be a single number of at least 1.
#' @param rapldir Character scalar, the powercap directory holding the RAPL
#'   domains; default \code{"/sys/class/powercap"} (Linux).
#' @param procstat Character scalar, the kernel CPU accounting file read for
#'   \code{usage = "machine"}; default \code{"/proc/stat"} (Linux).
#' @return A list of class \code{rmbl_footprint} with elements \code{value}
#'   (the result of \code{expr}), \code{durs} (numeric, wall seconds),
#'   \code{cputms} (numeric, CPU seconds of this process and its
#'   children), \code{usage} (numeric in \eqn{[0, 1]}, the utilisation),
#'   \code{usagemode} (\code{"process"}, \code{"machine"} or
#'   \code{"fixed"}), \code{cores} (integer), \code{memgb} (numeric),
#'   \code{enekwh} (a list of numerics \code{cpu}, \code{memory} and
#'   \code{total}, in kWh, PUE included), \code{co2eg} (numeric, grams of
#'   CO2-equivalent), \code{co2int} (the list returned by
#'   \code{\link{co2int}}, with its year and source), \code{method}
#'   (\code{"rapl"} or \code{"model"}, the method actually used),
#'   \code{assumptions} (character vector of every default or fallback that
#'   stood in for a measurement) and \code{citations} (character vector).
#'   The print method shows a three-line summary.
#' @references Lannelongue, L., Grealey, J. and Inouye, M. (2021). Green
#'   Algorithms: quantifying the carbon footprint of computation. Advanced
#'   Science 8(12), 2100707. Courty, B. et al. (2024). CodeCarbon: estimate
#'   and track carbon emissions from machine learning computing.
#'   \doi{10.5281/zenodo.4658424}. Lacoste, A., Luccioni, A., Schmidt, V. and
#'   Dandres, T. (2019). Quantifying the carbon emissions of machine learning.
#'   arXiv:1910.09700.
#' @examples
#' fp <- co2fp(sum(sqrt(seq_len(2e5))), loc = "CA-ON")
#' fp$enekwh$total
#' fp$co2eg
#' fp$co2int$year
#' fp$assumptions
#' print(fp)
#' # wherever you are, offline: the location is detected and recorded
#' co2fp(1 + 1, cpupwrw = 45, memgb = 8)$assumptions
#' # the whole machine's utilisation, on codecarbon's machine curve
#' co2fp(1 + 1, loc = "FR", usage = "machine", loadcur = "codecarbon",
#'                   cpupwrw = 45, memgb = 8)$usagemode
#' # a fixed utilisation and a data-centre PUE, with a carbon intensity given as a number
#' fp2 <- co2fp(sum(sqrt(seq_len(2e5))), loc = 30, usage = 0.5,
#'                          cpupwrw = 65, memgb = 16, pue = 1.67, meth = "model")
#' fp2$enekwh
#' fpeqv(fp2$co2eg)
#' # a bad argument is refused before the expression runs
#' try(co2fp(Sys.sleep(10), pue = 0.9))
#' @export
co2fp <- function(expr, loc = NULL, meth = c("auto", "rapl", "model"),
                              cpupwrw = NULL, usage = "process",
                              loadcur = c("linear", "codecarbon"), cores = NULL,
                              memgb = NULL, mempwrwpergb = 0.3725, pue = 1,
                              rapldir = "/sys/class/powercap", procstat = "/proc/stat") {
  meth <- .rmbl_arg(meth)
  loadcur <- .rmbl_arg(loadcur)
  ci <- co2int(loc)
  # every argument is checked before `expr` runs, so a bad argument never costs the computation
  if (!is.numeric(pue) || length(pue) != 1L || !is.finite(pue) || pue < 1) {
    stop("`pue` must be a single number >= 1", call. = FALSE)
  }
  num_arg <- function(x, what, positive = FALSE) {
    if (is.null(x)) return(NULL)
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 0 || (positive && x <= 0)) {
      stop(sprintf("`%s` must be a single %s number", what, if (positive) "positive" else "non-negative"),
           call. = FALSE)
    }
    as.numeric(x)
  }
  cpupwrw <- num_arg(cpupwrw, "cpupwrw", positive = TRUE)
  cores <- num_arg(cores, "cores", positive = TRUE)
  if (!is.null(cores) && cores != round(cores)) stop("`cores` must be a whole number", call. = FALSE)
  memgb <- num_arg(memgb, "memgb")
  mempwrwpergb <- num_arg(mempwrwpergb, "mempwrwpergb")
  if (!is.character(rapldir) || length(rapldir) != 1L || is.na(rapldir)) {
    stop("`rapldir` must be a single path", call. = FALSE)
  }
  if (!is.character(procstat) || length(procstat) != 1L || is.na(procstat)) {
    stop("`procstat` must be a single path", call. = FALSE)
  }
  if (is.null(usage)) usage <- "process"
  if (length(usage) != 1L) {
    stop("`usage` takes one value: \"process\", \"machine\" or a single number in [0, 1]", call. = FALSE)
  }
  if (is.character(usage)) {
    usage_mode <- .rmbl_arg(usage, c("process", "machine"))
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

  domains <- if (meth != "model") .rapl_domains(rapldir) else character(0)
  before <- if (meth != "model") .rapl_read(domains) else NULL
  if (meth == "rapl" && is.null(before)) {
    stop("RAPL energy counters are not readable here (see raplok()); use method = \"model\"",
         call. = FALSE)
  }
  used <- if (is.null(before)) "model" else "rapl"
  stat0 <- if (usage_mode == "machine") .proc_stat_cpu(procstat) else NULL
  if (usage_mode == "machine" && is.null(stat0)) {
    usage_mode <- "process"
    assumptions <- c(assumptions, "machine CPU accounting unreadable (no /proc/stat); process utilisation used")
  }

  t0 <- proc.time()
  value <- expr
  t1 <- proc.time()
  after <- if (used == "rapl") .rapl_read(domains) else NULL
  stat1 <- if (usage_mode == "machine") .proc_stat_cpu(procstat) else NULL

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
  # a run faster than the elapsed clock's resolution read 0 s of wall time against a millisecond of
  # CPU time, and its energy came out exactly 0: the work took at least its CPU time spread over
  # the cores
  if (is.finite(cpu_t) && cpu_t > 0) {
    wall <- max(wall, cpu_t / max(1, cores))
    hours <- wall / 3600
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
    if (is.null(cpupwrw)) {
      cpupwrw <- 85 * 0.5
      assumptions <- c(assumptions, "CPU power unknown: 85 W x 50% (codecarbon fallback)")
      e_cpu_kwh <- hours * cpupwrw / 1000
    } else {
      # cpupwrw was checked (single, finite, positive) before `expr` ran
      e_cpu_kwh <- hours * .cpu_load_power(cpupwrw, usage, loadcur, usage_mode) / 1000
      if (loadcur == "codecarbon") {
        assumptions <- c(assumptions, sprintf("codecarbon %s load curve applied to the CPU power",
                                              if (usage_mode == "machine") "machine" else "process"))
      }
    }
  }

  if (is.null(memgb)) {
    memgb <- .rmbl_total_memory_gb()
    if (is.na(memgb)) {
      memgb <- 8
      assumptions <- c(assumptions, "memory size unknown: 8 GB assumed")
    } else {
      assumptions <- c(assumptions, sprintf("memory charged: the machine's total %.1f GB", memgb))
    }
  }
  e_mem_kwh <- hours * memgb * mempwrwpergb / 1000
  total <- (e_cpu_kwh + e_mem_kwh) * pue
  if (pue > 1) assumptions <- c(assumptions, sprintf("PUE %.2f applied", pue))

  structure(list(
    value = value,
    durs = wall,
    cputms = cpu_t,
    usage = usage,
    usagemode = usage_mode,
    cores = as.integer(cores),
    memgb = memgb,
    enekwh = list(cpu = e_cpu_kwh * pue, memory = e_mem_kwh * pue, total = total),
    co2eg = total * ci$g_per_kwh,
    co2int = ci,
    method = used,
    assumptions = assumptions,
    citations = cites
  ), class = "rmbl_footprint")
}

#' @export
print.rmbl_footprint <- function(x, ...) {
  cat(sprintf("Computation footprint (%s): %.3f s wall, %.3f s CPU, utilisation %.2f (%s) on %d cores\n",
              if (x$method == "rapl") "measured, RAPL" else "modelled", x$durs, x$cputms,
              x$usage, x$usagemode, x$cores))
  cat(sprintf("  energy: %.3g kWh (cpu %.3g, memory %.3g)\n", x$enekwh$total, x$enekwh$cpu,
              x$enekwh$memory))
  ci <- x$co2int
  cat(sprintf("  CO2e:   %.3g g at %.4g gCO2e/kWh (%s%s)\n", x$co2eg, ci$g_per_kwh, ci$name,
              if (is.na(ci$year)) "" else sprintf(", %d", ci$year)))
  if (length(x$assumptions)) cat("  assumed:", paste(x$assumptions, collapse = "; "), "\n")
  invisible(x)
}

#' Everyday equivalents of a quantity of CO2-equivalent
#'
#' Converts grams of CO2-equivalent into two everyday comparisons:
#' kilometres driven in an average European passenger car (175 gCO2/km) and
#' tree-months of carbon sequestration (917 gCO2 per tree per month), the two
#' comparisons the Green Algorithms calculator prints, with their sources.
#' Use it to make the \code{co2eg} of \code{\link{co2fp}}
#' easier to read in a report.
#'
#' @details
#' The conversions are plain divisions: \eqn{\mathrm{km} = g / 175} and
#' \eqn{\mathrm{tree\ months} = g / 917}. Both factors are averages and the
#' comparisons are illustrations, not offsets: a tree-month is the carbon one
#' mature tree takes up in a month, not a promise that planting one cancels
#' the emission. Errors when \code{co2eg} is not a single finite,
#' non-negative number.
#'
#' @param co2eg Numeric scalar, grams of CO2-equivalent; finite and
#'   non-negative (for example the \code{co2eg} element of a
#'   \code{\link{co2fp}} result).
#' @return A list with \code{carkm} (numeric, kilometres),
#'   \code{treemon} (numeric) and \code{sources} (named character vector,
#'   \code{car} and \code{tree}, naming each factor's source).
#' @references Green Algorithms data v3.1, context.csv: car factor from
#'   Helmers et al. (2019) Atmospheric Environment and UK BEIS 2019 conversion
#'   factors; tree sequestration from Bernal et al. (2018) via the same file.
#' @seealso \code{\link{co2fp}}
#' @examples
#' fpeqv(1200)
#'
#' # the footprint of a small computation, in everyday terms
#' fp <- co2fp(sum(sqrt(seq_len(2e5))), loc = "CA-ON",
#'                         cpupwrw = 45, memgb = 8)
#' unlist(fpeqv(fp$co2eg)[c("carkm", "treemon")])
#'
#' # a vector is refused: convert one total at a time
#' try(fpeqv(c(10, 20)))
#' @export
fpeqv <- function(co2eg) {
  if (!is.numeric(co2eg) || length(co2eg) != 1L || !is.finite(co2eg) || co2eg < 0) {
    stop("`co2eg` must be a single non-negative number", call. = FALSE)
  }
  list(carkm = co2eg / 175, treemon = co2eg / 917,
       sources = c(car = "175 gCO2/km, European passenger car (Green Algorithms context.csv)",
                   tree = "917 gCO2 per tree-month (Green Algorithms context.csv)"))
}
