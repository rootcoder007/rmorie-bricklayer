# The footprint of a computation: the model recomputed, RAPL read from a
# mocked powercap tree, and every fallback named in the assumptions.

mock_rapl <- function(uj = 1e6, max_uj = 2^32, name = "package-0") {
  skip_on_os("windows")   # the Linux domain names carry a colon, which Windows paths cannot
  d <- tempfile("powercap")
  dir.create(file.path(d, "intel-rapl:0"), recursive = TRUE)
  dir.create(file.path(d, "intel-rapl:0:0"), recursive = TRUE)      # a subdomain: must be ignored
  writeLines(name, file.path(d, "intel-rapl:0", "name"))
  writeLines(format(uj, scientific = FALSE), file.path(d, "intel-rapl:0", "energy_uj"))
  writeLines(format(max_uj, scientific = FALSE), file.path(d, "intel-rapl:0", "max_energy_range_uj"))
  writeLines("core", file.path(d, "intel-rapl:0:0", "name"))
  writeLines("12345", file.path(d, "intel-rapl:0:0", "energy_uj"))
  d
}

test_that("carbon_intensity: a bundled offline table at each location's latest year; code, alpha-3 or name", {
  tab <- carbon_intensity_table()
  expect_true(all(c("location", "iso3", "name", "g_per_kwh", "year", "basis", "source") %in% names(tab)))
  expect_gte(nrow(tab), 350)
  expect_equal(nrow(tab), length(unique(tab$location)))
  expect_true(all(is.finite(tab$g_per_kwh) & tab$g_per_kwh > 0))
  expect_true(all(tab$year >= 2009 & tab$year <= 2026))
  expect_true(all(nzchar(tab$source)))
  expect_true(all(tab$basis == "lifecycle"))
  # every country at Our World in Data's latest published year (Ember data, 2024 or 2025)
  countries <- tab[nchar(tab$location) == 2L, ]
  expect_gte(nrow(countries), 200)
  expect_gte(mean(countries$year >= 2024), 0.97)   # a few territories stop earlier in both sources
  expect_true(all(grepl("Our World in Data|Electricity Maps", countries$source)))
  expect_match(carbon_intensity("Lesotho")$source, "Electricity Maps")   # 2024 there beats OWID's 2022
  # the sub-national zones come from Electricity Maps' 2024 yearly file
  zones <- tab[grepl("-", tab$location, fixed = TRUE) & !startsWith(tab$location, "OWID"), ]
  expect_gte(nrow(zones), 100)
  expect_true(all(zones$year == 2024))
  expect_true(all(grepl("Electricity Maps", zones$source)))
  expect_true(all(c("CA-ON", "CA-QC", "CA-AB", "CA-BC", "US-CAL-CISO", "AU-NSW", "IN-NO", "JP-TK") %in% zones$location))
  expect_true(all(c("WORLD", "CA", "US", "GB", "DE", "FR", "IN", "CN", "BR", "NG", "KE", "VN") %in% tab$location))
  expect_equal(carbon_intensity("NA")$name, "Namibia")   # the string "NA" is a country, not a missing value

  w <- carbon_intensity("world")
  expect_equal(w$g_per_kwh, 458.29)
  expect_equal(w$year, 2025L)
  expect_match(w$source, "Ember")
  on <- carbon_intensity("CA-ON")
  expect_equal(on$g_per_kwh, 90.97)
  expect_equal(on$year, 2024L)
  expect_match(on$source, "Electricity Maps")
  expect_length(on$note, 0)
  # the same row three ways
  expect_equal(carbon_intensity("CAN")$g_per_kwh, carbon_intensity("CA")$g_per_kwh)
  expect_equal(carbon_intensity("canada")$location, "CA")
  expect_equal(carbon_intensity(" Canada ")$location, "CA")
  # an unknown zone falls back to its country and says so
  fb <- carbon_intensity("CA-XX")
  expect_equal(fb$location, "CA")
  expect_match(fb$note, "no row for zone CA-XX; its country CA used")
  u <- carbon_intensity(120)
  expect_equal(u$g_per_kwh, 120)
  expect_equal(u$location, "user")
  expect_true(is.na(u$year))
  expect_error(carbon_intensity("XX"), "Unknown location")
  expect_error(carbon_intensity("XX-YY"), "Unknown location")
  expect_error(carbon_intensity(-1), "non-negative")
  expect_error(carbon_intensity(c("CA", "US")), "single location")
  expect_error(carbon_intensity(NA_character_), "single location")
})

test_that("detect_location: environment, codecarbon's variable, time zone, locale, then the world", {
  d <- detect_location(env_location = "ca-on", codecarbon_location = "FRA", tz = "Europe/Berlin", locale = "en_GB")
  expect_equal(d$location, "CA-ON")
  expect_match(d$method, "RMBL_LOCATION")
  d <- detect_location(env_location = "", codecarbon_location = "FRA", tz = "Europe/Berlin", locale = "en_GB.UTF-8")
  expect_equal(d$location, "FR")
  expect_match(d$method, "CODECARBON_COUNTRY_ISO_CODE")
  d <- detect_location(env_location = "", codecarbon_location = "", tz = "Europe/Berlin", locale = "en_GB.UTF-8")
  expect_equal(d$location, "DE")
  expect_match(d$method, "time zone Europe/Berlin")
  expect_equal(detect_location("", "", tz = "America/Toronto", locale = "")$location, "CA")
  expect_equal(detect_location("", "", tz = "Asia/Kolkata", locale = "")$location, "IN")
  d <- detect_location(env_location = "", codecarbon_location = "", tz = "Not/AZone", locale = "en_GB.UTF-8")
  expect_equal(d$location, "GB")
  expect_match(d$method, "locale en_GB")
  expect_equal(detect_location("", "", tz = "", locale = "fr_CA")$location, "CA")
  d <- detect_location(env_location = "Atlantis", codecarbon_location = "", tz = "UTC", locale = "C.UTF-8")
  expect_equal(d$location, "WORLD")
  expect_match(d$method, "fallback")
  expect_equal(detect_location("", "", tz = NA_character_, locale = NA_character_)$location, "WORLD")
  # the live session resolves to a row of the table
  live <- detect_location()
  expect_true(live$location %in% carbon_intensity_table()$location)
  # and NULL in carbon_intensity() goes through it, recording the detection
  withr::local_envvar(RMBL_LOCATION = "SE")
  ci <- carbon_intensity(NULL)
  expect_equal(ci$location, "SE")
  expect_match(ci$note, "location SE via RMBL_LOCATION")
  fp <- compute_footprint(1 + 1, method = "model", cpu_power_w = 65, usage = 1, memory_gb = 8)
  expect_equal(fp$carbon_intensity$location, "SE")
  expect_match(fp$assumptions[1], "location SE via RMBL_LOCATION")
  expect_match(fp$citations[3], "Ember.*Sweden, 2025")
})

test_that("utilisation: measured per process or per machine, fixed by number, and codecarbon's load curves", {
  stat <- tempfile("stat")
  writeLines("cpu  100 0 100 700 100 0 0 0 0 0", stat)
  # the whole machine: 500 jiffies elapsed, 100 idle -> 0.8 busy
  fp <- compute_footprint({
    writeLines("cpu  300 0 300 800 100 0 0 0 0 0", stat)
    1
  }, location = 100, method = "model", usage = "machine", cpu_power_w = 50, memory_gb = 0, proc_stat = stat)
  expect_equal(fp$usage_mode, "machine")
  expect_equal(fp$usage, 0.8)
  expect_equal(fp$energy_kwh$cpu, fp$duration_s / 3600 * 50 * 0.8 / 1000)
  # codecarbon's machine curve: 0.1 + 0.9 u^3
  writeLines("cpu  100 0 100 700 100 0 0 0 0 0", stat)
  fp <- compute_footprint({
    writeLines("cpu  300 0 300 800 100 0 0 0 0 0", stat)
    1
  }, location = 100, method = "model", usage = "machine", load_curve = "codecarbon", cpu_power_w = 50,
  memory_gb = 0, proc_stat = stat)
  expect_equal(fp$energy_kwh$cpu, fp$duration_s / 3600 * 50 * (0.1 + 0.9 * 0.8^3) / 1000)
  expect_match(paste(fp$assumptions, collapse = ";"), "codecarbon machine load curve")
  # no change in the counters: utilisation 0, not NaN
  fp <- compute_footprint(1, location = 100, method = "model", usage = "machine", cpu_power_w = 50,
                          memory_gb = 0, proc_stat = stat)
  expect_equal(fp$usage, 0)
  # no /proc/stat (macOS, Windows): the process figure, and the assumption says so
  fp <- compute_footprint(1, location = 100, method = "model", usage = "machine", cpu_power_w = 50,
                          memory_gb = 0, proc_stat = file.path(stat, "missing"))
  expect_equal(fp$usage_mode, "process")
  expect_match(fp$assumptions, "no /proc/stat")
  writeLines("cpu  1 2", stat)   # too few fields
  expect_null(.proc_stat_cpu(stat))
  writeLines("not a cpu line", stat)
  expect_equal(compute_footprint(1, location = 100, method = "model", usage = "machine", cpu_power_w = 50,
                                 memory_gb = 0, proc_stat = stat)$usage_mode, "process")
  # a process measurement is in [0, 1] and is the default (NULL too)
  fp <- compute_footprint(sum(sqrt(seq_len(2e4))), location = 100, method = "model", cpu_power_w = 50, memory_gb = 0)
  expect_equal(fp$usage_mode, "process")
  expect_true(fp$usage >= 0 && fp$usage <= 1)
  expect_equal(compute_footprint(1, location = 100, method = "model", usage = NULL, cpu_power_w = 50,
                                 memory_gb = 0)$usage_mode, "process")
  # fixed: linear vs codecarbon's 10% floor for a process
  lin <- compute_footprint(1, location = 100, method = "model", usage = 0.05, cpu_power_w = 50, memory_gb = 0)
  cc <- compute_footprint(1, location = 100, method = "model", usage = 0.05, cpu_power_w = 50, memory_gb = 0,
                          load_curve = "codecarbon")
  expect_equal(lin$usage_mode, "fixed")
  expect_equal(lin$energy_kwh$cpu, lin$duration_s / 3600 * 50 * 0.05 / 1000)
  expect_equal(cc$energy_kwh$cpu, cc$duration_s / 3600 * 50 * 0.10 / 1000)
  expect_match(paste(cc$assumptions, collapse = ";"), "codecarbon process load curve")
  cc2 <- compute_footprint(1, location = 100, method = "model", usage = 0.5, cpu_power_w = 50, memory_gb = 0,
                           load_curve = "codecarbon")
  expect_equal(cc2$energy_kwh$cpu, cc2$duration_s / 3600 * 50 * 0.5 / 1000)
  expect_error(compute_footprint(1, usage = "sometimes", location = 100), "process")
  expect_error(compute_footprint(1, usage = c(0.1, 0.2), location = 100), "single number")
  expect_error(compute_footprint(1, usage = NA_real_, location = 100), "single number")
  expect_error(compute_footprint(1, load_curve = "cubic", location = 100), "arg")
  unlink(stat)
})

test_that("the model: E = t (P u + M p) PUE, with the assumptions it had to make", {
  fp <- compute_footprint({
    s <- sum(sqrt(seq_len(5e4)))
    s
  }, location = "CA-ON", method = "model", cpu_power_w = 65, usage = 0.5, memory_gb = 16, pue = 1)
  expect_s3_class(fp, "rmbl_footprint")
  expect_equal(fp$value, sum(sqrt(seq_len(5e4))))
  h <- fp$duration_s / 3600
  expect_equal(fp$energy_kwh$cpu, h * 65 * 0.5 / 1000)
  expect_equal(fp$energy_kwh$memory, h * 16 * 0.3725 / 1000)
  expect_equal(fp$energy_kwh$total, fp$energy_kwh$cpu + fp$energy_kwh$memory)
  expect_equal(fp$co2e_g, fp$energy_kwh$total * carbon_intensity("CA-ON")$g_per_kwh)
  expect_equal(fp$method, "model")
  expect_equal(fp$usage, 0.5)
  expect_length(fp$assumptions, 0L)
  # PUE scales every term and is recorded
  fp2 <- compute_footprint(1 + 1, method = "model", cpu_power_w = 65, usage = 0.5, memory_gb = 16, pue = 1.67)
  expect_equal(fp2$energy_kwh$total, (fp2$duration_s / 3600) * (65 * 0.5 + 16 * 0.3725) / 1000 * 1.67)
  expect_match(paste(fp2$assumptions, collapse = ";"), "PUE 1.67")
  # the unknown-CPU fallback is codecarbon's 85 W x 50%, not scaled by usage, and is named
  fp3 <- compute_footprint(1 + 1, method = "model", memory_gb = 8, usage = 1)
  expect_equal(fp3$energy_kwh$cpu, (fp3$duration_s / 3600) * 42.5 / 1000)
  expect_match(paste(fp3$assumptions, collapse = ";"), "85 W x 50%")
  # measured utilisation lies in [0, 1] and the core count is an integer
  fp4 <- compute_footprint(sum(sqrt(seq_len(2e5))), method = "model", cpu_power_w = 65, memory_gb = 8)
  expect_true(fp4$usage >= 0 && fp4$usage <= 1)
  expect_true(is.integer(fp4$cores) && fp4$cores >= 1L)
  # memory detection either reads the machine or assumes 8 GB, and says which
  fp5 <- compute_footprint(1 + 1, method = "model", cpu_power_w = 65, usage = 1)
  expect_true(fp5$memory_gb > 0)
  expect_match(paste(fp5$assumptions, collapse = ";"), "memory")
  expect_error(compute_footprint(1, method = "model", pue = 0.5), "pue")
  expect_error(compute_footprint(1, method = "model", usage = 2, memory_gb = 8), "usage")
  expect_error(compute_footprint(1, method = "model", cpu_power_w = -5, usage = 1, memory_gb = 8), "cpu_power_w")
  expect_error(compute_footprint(1, method = "model", location = "XX"), "Unknown location")
})

test_that("RAPL: package domains are read, subdomains ignored, wrap-around handled, memory still modelled", {
  d <- mock_rapl(uj = 1e6)
  expect_true(rapl_available(d))
  expect_false(rapl_available(tempfile()))
  f <- file.path(d, "intel-rapl:0", "energy_uj")
  fp <- compute_footprint({
    writeLines("3600000000", f)
    42
  }, location = 100, method = "rapl", memory_gb = 0, rapl_dir = d)
  expect_equal(fp$method, "rapl")
  expect_equal(fp$value, 42)
  # 3.6e9 - 1e6 microjoules = 3599 J = 3599 / 3.6e6 kWh
  expect_equal(fp$energy_kwh$cpu, (3.6e9 - 1e6) * 1e-6 / 3.6e6)
  expect_equal(fp$energy_kwh$memory, 0)
  expect_equal(fp$co2e_g, fp$energy_kwh$total * 100)
  # auto picks RAPL when it is readable
  expect_equal(compute_footprint(1, method = "auto", memory_gb = 0, rapl_dir = d)$method, "rapl")
  # a counter that wrapped is unwound with its range
  writeLines(format(2^32 - 100, scientific = FALSE), f)
  w <- compute_footprint({
    writeLines("50", f)
    1
  }, method = "rapl", memory_gb = 0, rapl_dir = d)
  expect_equal(w$energy_kwh$cpu, 150 * 1e-6 / 3.6e6)
  # a wrapped counter with no known range falls back to the model and says so
  unlink(file.path(d, "intel-rapl:0", "max_energy_range_uj"))
  writeLines("1000", f)
  nw <- compute_footprint({
    writeLines("5", f)
    1
  }, method = "rapl", cpu_power_w = 65, usage = 1, memory_gb = 0, rapl_dir = d)
  expect_equal(nw$method, "model")
  expect_match(paste(nw$assumptions, collapse = ";"), "wrapped")
  # counters that vanish mid-run fall back as well
  writeLines("1000", f)
  gone <- compute_footprint({
    unlink(f)
    1
  }, method = "rapl", cpu_power_w = 65, usage = 1, memory_gb = 0, rapl_dir = d)
  expect_equal(gone$method, "model")
  expect_match(paste(gone$assumptions, collapse = ";"), "unreadable")
  # a non-package domain, or an unreadable counter, means RAPL is not available
  d2 <- mock_rapl(name = "psys")
  expect_false(rapl_available(d2))
  d3 <- mock_rapl()
  writeLines("not-a-number", file.path(d3, "intel-rapl:0", "energy_uj"))
  expect_false(rapl_available(d3))
  expect_error(compute_footprint(1, method = "rapl", rapl_dir = d3), "not readable")
  unlink(c(d, d2, d3), recursive = TRUE)
})

test_that("print and equivalents", {
  fp <- compute_footprint(1 + 1, method = "model", cpu_power_w = 65, usage = 1, memory_gb = 8, location = "CA")
  out <- utils::capture.output(print(fp))
  expect_match(out[1], "^Computation footprint \\(modelled\\)")
  expect_match(out[1], "utilisation 1.00 \\(fixed\\)")
  expect_match(out[3], "Canada, 2025")
  expect_equal(fp$usage_mode, "fixed")
  fpu <- compute_footprint(1 + 1, method = "model", cpu_power_w = 65, usage = 1, memory_gb = 8, location = 100)
  expect_match(utils::capture.output(print(fpu))[3], "user-supplied\\)")
  eq <- footprint_equivalents(1750)
  expect_equal(eq$car_km, 10)
  expect_equal(eq$tree_months, 1750 / 917)
  expect_error(footprint_equivalents(-1), "non-negative")
  expect_error(footprint_equivalents(c(1, 2)), "single")
})

test_that("seams: memory from /proc/meminfo or sysctl, core count fallback, assumptions printed", {
  mi <- tempfile("meminfo")
  writeLines(c("MemTotal:       16777216 kB", "MemFree:         1234 kB"), mi)
  expect_equal(.rmbl_total_memory_gb(meminfo = mi, sysname = "Linux"), 16)
  writeLines("MemTotal:       garbage", mi)
  expect_true(is.na(.rmbl_total_memory_gb(meminfo = mi, sysname = "Linux")))
  # the macOS branch runs sysctl -n hw.memsize; a stand-in sysctl answers 16 GiB, a broken one nothing
  none <- file.path(mi, "none")
  expect_true(is.na(.rmbl_total_memory_gb(meminfo = none, sysname = "Darwin", sysctl = "")))
  expect_true(is.na(.rmbl_total_memory_gb(meminfo = none, sysname = "Plan9")))
  if (.Platform$OS.type == "unix") {
    fake <- tempfile("sysctl")
    writeLines(c("#!/bin/sh", "echo 17179869184"), fake)
    Sys.chmod(fake, "0755")
    expect_equal(.rmbl_total_memory_gb(meminfo = none, sysname = "Darwin", sysctl = fake), 16)
    writeLines(c("#!/bin/sh", "echo no such oid"), fake)
    expect_true(is.na(.rmbl_total_memory_gb(meminfo = none, sysname = "Darwin", sysctl = fake)))
    writeLines(c("#!/bin/sh", "exit 1"), fake)
    expect_true(is.na(.rmbl_total_memory_gb(meminfo = none, sysname = "Darwin", sysctl = fake)))
    unlink(fake)
  }
  # the machine counters vanish during the run: back to the process figure, and said so
  st <- tempfile("stat")
  writeLines("cpu  100 0 100 700 100 0 0 0 0 0", st)
  fp <- compute_footprint({
    unlink(st)
    1
  }, location = 100, method = "model", usage = "machine", cpu_power_w = 50, memory_gb = 0, proc_stat = st)
  expect_equal(fp$usage_mode, "process")
  expect_match(paste(fp$assumptions, collapse = ";"), "became unreadable")
  # memory size unknown anywhere: 8 GB assumed, and said so
  local_mocked_bindings(.rmbl_total_memory_gb = function(...) NA_real_)
  fp <- compute_footprint(1 + 1, location = 100, method = "model", cpu_power_w = 50, usage = 1)
  expect_equal(fp$memory_gb, 8)
  expect_match(paste(fp$assumptions, collapse = ";"), "memory size unknown: 8 GB assumed")
  expect_true(is.finite(.rmbl_cores()) && .rmbl_cores() >= 1)
  local_mocked_bindings(.rmbl_cores = function() NA_integer_)
  fp <- compute_footprint(1 + 1, location = 100, method = "model", cpu_power_w = 50, memory_gb = 8)
  expect_equal(fp$cores, 1L)
  expect_match(paste(fp$assumptions, collapse = ";"), "core count unknown; 1 assumed")
  out <- utils::capture.output(print(fp))
  expect_match(out[4], "^  assumed: .*core count unknown")
  unlink(mi)
})
