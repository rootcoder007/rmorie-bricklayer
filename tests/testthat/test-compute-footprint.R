# The footprint of a computation: the model recomputed, RAPL read from a
# mocked powercap tree, and every fallback named in the assumptions.

mock_rapl <- function(uj = 1e6, max_uj = 2^32, name = "package-0") {
  # the Linux domain names carry a colon, which Windows paths cannot
  skip_on_os("windows")
  d <- tempfile("powercap")
  dir.create(file.path(d, "intel-rapl:0"), recursive = TRUE)
  # a subdomain: must be ignored
  dir.create(file.path(d, "intel-rapl:0:0"), recursive = TRUE)
  writeLines(name, file.path(d, "intel-rapl:0", "name"))
  writeLines(
    format(uj, scientific = FALSE),
    file.path(d, "intel-rapl:0", "energy_uj")
  )
  writeLines(
    format(max_uj, scientific = FALSE),
    file.path(d, "intel-rapl:0", "max_energy_range_uj")
  )
  writeLines("core", file.path(d, "intel-rapl:0:0", "name"))
  writeLines("12345", file.path(d, "intel-rapl:0:0", "energy_uj"))
  d
}

test_that(
  paste0(
    "co2int: a bundled offline table at each location's latest year; code, ",
    "alpha-3 or name"
  ),
  {
    tab <- co2inttab()
    expect_true(all(
      c("location", "iso3", "name", "g_per_kwh", "year", "basis", "source") %in%
        names(tab)
    ))
    expect_gte(nrow(tab), 350)
    expect_equal(nrow(tab), length(unique(tab$location)))
    expect_true(all(is.finite(tab$g_per_kwh) & tab$g_per_kwh > 0))
    expect_true(all(tab$year >= 2009 & tab$year <= 2026))
    expect_true(all(nzchar(tab$source)))
    expect_true(all(tab$basis == "lifecycle"))
    # every country at Our World in Data's latest published year (Ember data,
    # 2024 or 2025)
    countries <- tab[nchar(tab$location) == 2L, ]
    expect_gte(nrow(countries), 200)
    # a few territories stop earlier in both sources
    expect_gte(mean(countries$year >= 2024), 0.97)
    expect_true(all(grepl(
      "Our World in Data|Electricity Maps",
      countries$source
    )))
    # 2024 there beats OWID's 2022
    expect_match(co2int("Lesotho")$source, "Electricity Maps")
    # the sub-national zones come from Electricity Maps' 2024 yearly file
    zones <- tab[
      grepl("-", tab$location, fixed = TRUE) &
        !startsWith(tab$location, "OWID"),
    ]
    expect_gte(nrow(zones), 100)
    expect_true(all(zones$year == 2024))
    expect_true(all(grepl("Electricity Maps", zones$source)))
    expect_true(all(
      c(
        "CA-ON",
        "CA-QC",
        "CA-AB",
        "CA-BC",
        "US-CAL-CISO",
        "AU-NSW",
        "IN-NO",
        "JP-TK"
      ) %in%
        zones$location
    ))
    expect_true(all(
      c(
        "WORLD",
        "CA",
        "US",
        "GB",
        "DE",
        "FR",
        "IN",
        "CN",
        "BR",
        "NG",
        "KE",
        "VN"
      ) %in%
        tab$location
    ))
    # the string "NA" is a country, not a missing value
    expect_equal(co2int("NA")$name, "Namibia")

    w <- co2int("world")
    expect_equal(w$g_per_kwh, 458.29)
    expect_equal(w$year, 2025L)
    expect_match(w$source, "Ember")
    on <- co2int("CA-ON")
    expect_equal(on$g_per_kwh, 90.97)
    expect_equal(on$year, 2024L)
    expect_match(on$source, "Electricity Maps")
    expect_length(on$note, 0)
    # the same row three ways
    expect_equal(co2int("CAN")$g_per_kwh, co2int("CA")$g_per_kwh)
    expect_equal(co2int("canada")$location, "CA")
    expect_equal(co2int(" Canada ")$location, "CA")
    # an unknown zone falls back to its country and says so
    fb <- co2int("CA-XX")
    expect_equal(fb$location, "CA")
    expect_match(fb$note, "no row for zone CA-XX; its country CA used")
    u <- co2int(120)
    expect_equal(u$g_per_kwh, 120)
    expect_equal(u$location, "user")
    expect_true(is.na(u$year))
    expect_error(co2int("XX"), "Unknown location")
    expect_error(co2int("XX-YY"), "Unknown location")
    expect_error(co2int(-1), "non-negative")
    expect_error(co2int(c("CA", "US")), "single location")
    expect_error(co2int(NA_character_), "single location")
  }
)

test_that(
  paste0(
    "dtctloc: environment, codecarbon's variable, time zone, locale, then ",
    "the world"
  ),
  {
    d <- dtctloc(
      envloc = "ca-on",
      codloc = "FRA",
      tz = "Europe/Berlin",
      locale = "en_GB"
    )
    expect_equal(d$location, "CA-ON")
    expect_match(d$method, "RMBL_LOCATION")
    d <- dtctloc(
      envloc = "",
      codloc = "FRA",
      tz = "Europe/Berlin",
      locale = "en_GB.UTF-8"
    )
    expect_equal(d$location, "FR")
    expect_match(d$method, "CODECARBON_COUNTRY_ISO_CODE")
    d <- dtctloc(
      envloc = "",
      codloc = "",
      tz = "Europe/Berlin",
      locale = "en_GB.UTF-8"
    )
    expect_equal(d$location, "DE")
    expect_match(d$method, "time zone Europe/Berlin")
    expect_equal(
      dtctloc("", "", tz = "America/Toronto", locale = "")$location,
      "CA"
    )
    expect_equal(
      dtctloc("", "", tz = "Asia/Kolkata", locale = "")$location,
      "IN"
    )
    d <- dtctloc(
      envloc = "",
      codloc = "",
      tz = "Not/AZone",
      locale = "en_GB.UTF-8"
    )
    expect_equal(d$location, "GB")
    expect_match(d$method, "locale en_GB")
    expect_equal(dtctloc("", "", tz = "", locale = "fr_CA")$location, "CA")
    # an unknown RMBL_LOCATION is said so, not skipped in silence
    expect_warning(
      d <- dtctloc(
        envloc = "Atlantis",
        codloc = "",
        tz = "UTC",
        locale = "C.UTF-8"
      ),
      "Atlantis"
    )
    expect_equal(d$location, "WORLD")
    expect_match(d$method, "fallback")
    expect_equal(
      dtctloc("", "", tz = NA_character_, locale = NA_character_)$location,
      "WORLD"
    )
    # the live session resolves to a row of the table
    live <- dtctloc()
    expect_true(live$location %in% co2inttab()$location)
    # and NULL in co2int() goes through it, recording the detection
    withr::local_envvar(RMBL_LOCATION = "SE")
    ci <- co2int(NULL)
    expect_equal(ci$location, "SE")
    expect_match(ci$note, "location SE via RMBL_LOCATION")
    fp <- co2fp(1 + 1, meth = "model", cpupwrw = 65, usage = 1, memgb = 8)
    expect_equal(fp$co2int$location, "SE")
    expect_match(fp$assumptions[1], "location SE via RMBL_LOCATION")
    expect_match(fp$citations[3], "Ember.*Sweden, 2025")
  }
)

test_that(
  paste0(
    "utilisation: measured per process or per machine, fixed by number, and ",
    "codecarbon's load curves"
  ),
  {
    stat <- tempfile("stat")
    writeLines("cpu  100 0 100 700 100 0 0 0 0 0", stat)
    # the whole machine: 500 jiffies elapsed, 100 idle -> 0.8 busy
    fp <- co2fp(
      {
        writeLines("cpu  300 0 300 800 100 0 0 0 0 0", stat)
        1
      },
      loc = 100,
      meth = "model",
      usage = "machine",
      cpupwrw = 50,
      memgb = 0,
      procstat = stat
    )
    expect_equal(fp$usagemode, "machine")
    expect_equal(fp$usage, 0.8)
    expect_equal(fp$enekwh$cpu, fp$durs / 3600 * 50 * 0.8 / 1000)
    # codecarbon's machine curve: 0.1 + 0.9 u^3
    writeLines("cpu  100 0 100 700 100 0 0 0 0 0", stat)
    fp <- co2fp(
      {
        writeLines("cpu  300 0 300 800 100 0 0 0 0 0", stat)
        1
      },
      loc = 100,
      meth = "model",
      usage = "machine",
      loadcur = "codecarbon",
      cpupwrw = 50,
      memgb = 0,
      procstat = stat
    )
    expect_equal(
      fp$enekwh$cpu,
      fp$durs / 3600 * 50 * (0.1 + 0.9 * 0.8^3) / 1000
    )
    expect_match(
      paste(fp$assumptions, collapse = ";"),
      "codecarbon machine load curve"
    )
    # no change in the counters: utilisation 0, not NaN
    fp <- co2fp(
      1,
      loc = 100,
      meth = "model",
      usage = "machine",
      cpupwrw = 50,
      memgb = 0,
      procstat = stat
    )
    expect_equal(fp$usage, 0)
    # no /proc/stat (macOS, Windows): the process figure, and the assumption
    # says so
    fp <- co2fp(
      1,
      loc = 100,
      meth = "model",
      usage = "machine",
      cpupwrw = 50,
      memgb = 0,
      procstat = file.path(stat, "missing")
    )
    expect_equal(fp$usagemode, "process")
    expect_match(fp$assumptions, "no /proc/stat")
    writeLines("cpu  1 2", stat) # too few fields
    expect_null(.proc_stat_cpu(stat))
    writeLines("not a cpu line", stat)
    expect_equal(
      co2fp(
        1,
        loc = 100,
        meth = "model",
        usage = "machine",
        cpupwrw = 50,
        memgb = 0,
        procstat = stat
      )$usagemode,
      "process"
    )
    # a process measurement is in [0, 1] and is the default (NULL too)
    fp <- co2fp(
      sum(sqrt(seq_len(2e4))),
      loc = 100,
      meth = "model",
      cpupwrw = 50,
      memgb = 0
    )
    expect_equal(fp$usagemode, "process")
    expect_true(fp$usage >= 0 && fp$usage <= 1)
    expect_equal(
      co2fp(
        1,
        loc = 100,
        meth = "model",
        usage = NULL,
        cpupwrw = 50,
        memgb = 0
      )$usagemode,
      "process"
    )
    # fixed: linear vs codecarbon's 10% floor for a process
    lin <- co2fp(
      1,
      loc = 100,
      meth = "model",
      usage = 0.05,
      cpupwrw = 50,
      memgb = 0
    )
    cc <- co2fp(
      1,
      loc = 100,
      meth = "model",
      usage = 0.05,
      cpupwrw = 50,
      memgb = 0,
      loadcur = "codecarbon"
    )
    expect_equal(lin$usagemode, "fixed")
    expect_equal(lin$enekwh$cpu, lin$durs / 3600 * 50 * 0.05 / 1000)
    expect_equal(cc$enekwh$cpu, cc$durs / 3600 * 50 * 0.10 / 1000)
    expect_match(
      paste(cc$assumptions, collapse = ";"),
      "codecarbon process load curve"
    )
    cc2 <- co2fp(
      1,
      loc = 100,
      meth = "model",
      usage = 0.5,
      cpupwrw = 50,
      memgb = 0,
      loadcur = "codecarbon"
    )
    expect_equal(cc2$enekwh$cpu, cc2$durs / 3600 * 50 * 0.5 / 1000)
    expect_error(co2fp(1, usage = "sometimes", loc = 100), "process")
    expect_error(co2fp(1, usage = c(0.1, 0.2), loc = 100), "single number")
    expect_error(co2fp(1, usage = NA_real_, loc = 100), "single number")
    expect_error(co2fp(1, loadcur = "cubic", loc = 100), "must be one of")
    unlink(stat)
  }
)

test_that(
  paste0(
    "the model: E = t (P u + M p) PUE, with ",
    "the assumptions it had to make"
  ),
  {
    fp <- co2fp(
      {
        s <- sum(sqrt(seq_len(5e4)))
        s
      },
      loc = "CA-ON",
      meth = "model",
      cpupwrw = 65,
      usage = 0.5,
      memgb = 16,
      pue = 1
    )
    expect_s3_class(fp, "rmbl_footprint")
    expect_equal(fp$value, sum(sqrt(seq_len(5e4))))
    h <- fp$durs / 3600
    expect_equal(fp$enekwh$cpu, h * 65 * 0.5 / 1000)
    expect_equal(fp$enekwh$memory, h * 16 * 0.3725 / 1000)
    expect_equal(fp$enekwh$total, fp$enekwh$cpu + fp$enekwh$memory)
    expect_equal(fp$co2eg, fp$enekwh$total * co2int("CA-ON")$g_per_kwh)
    expect_equal(fp$method, "model")
    expect_equal(fp$usage, 0.5)
    expect_length(fp$assumptions, 0L)
    # PUE scales every term and is recorded
    fp2 <- co2fp(
      1 + 1,
      meth = "model",
      cpupwrw = 65,
      usage = 0.5,
      memgb = 16,
      pue = 1.67
    )
    expect_equal(
      fp2$enekwh$total,
      (fp2$durs / 3600) * (65 * 0.5 + 16 * 0.3725) / 1000 * 1.67
    )
    expect_match(paste(fp2$assumptions, collapse = ";"), "PUE 1.67")
    # the unknown-CPU fallback is codecarbon's 85 W x 50%, not scaled by usage,
    # and is named
    fp3 <- co2fp(1 + 1, meth = "model", memgb = 8, usage = 1)
    expect_equal(fp3$enekwh$cpu, (fp3$durs / 3600) * 42.5 / 1000)
    expect_match(paste(fp3$assumptions, collapse = ";"), "85 W x 50%")
    # measured utilisation lies in [0, 1] and the core count is an integer
    fp4 <- co2fp(
      sum(sqrt(seq_len(2e5))),
      meth = "model",
      cpupwrw = 65,
      memgb = 8
    )
    expect_true(fp4$usage >= 0 && fp4$usage <= 1)
    expect_true(is.integer(fp4$cores) && fp4$cores >= 1L)
    # memory detection either reads the machine or assumes 8 GB, and says which
    fp5 <- co2fp(1 + 1, meth = "model", cpupwrw = 65, usage = 1)
    expect_true(fp5$memgb > 0)
    expect_match(paste(fp5$assumptions, collapse = ";"), "memory")
    expect_error(co2fp(1, meth = "model", pue = 0.5), "pue")
    expect_error(co2fp(1, meth = "model", usage = 2, memgb = 8), "usage")
    expect_error(
      co2fp(1, meth = "model", cpupwrw = -5, usage = 1, memgb = 8),
      "cpupwrw"
    )
    expect_error(co2fp(1, meth = "model", loc = "XX"), "Unknown location")
  }
)

test_that(
  paste0(
    "RAPL: package domains are read, subdomains ignored, wrap-around ",
    "handled, memory still modelled"
  ),
  {
    d <- mock_rapl(uj = 1e6)
    expect_true(raplok(d))
    expect_false(raplok(tempfile()))
    f <- file.path(d, "intel-rapl:0", "energy_uj")
    fp <- co2fp(
      {
        writeLines("3600000000", f)
        42
      },
      loc = 100,
      meth = "rapl",
      memgb = 0,
      rapldir = d
    )
    expect_equal(fp$method, "rapl")
    expect_equal(fp$value, 42)
    # 3.6e9 - 1e6 microjoules = 3599 J = 3599 / 3.6e6 kWh
    expect_equal(fp$enekwh$cpu, (3.6e9 - 1e6) * 1e-6 / 3.6e6)
    expect_equal(fp$enekwh$memory, 0)
    expect_equal(fp$co2eg, fp$enekwh$total * 100)
    # auto picks RAPL when it is readable
    expect_equal(co2fp(1, meth = "auto", memgb = 0, rapldir = d)$method, "rapl")
    # a counter that wrapped is unwound with its range
    writeLines(format(2^32 - 100, scientific = FALSE), f)
    w <- co2fp(
      {
        writeLines("50", f)
        1
      },
      meth = "rapl",
      memgb = 0,
      rapldir = d
    )
    expect_equal(w$enekwh$cpu, 150 * 1e-6 / 3.6e6)
    # a wrapped counter with no known range falls back to the model and says so
    unlink(file.path(d, "intel-rapl:0", "max_energy_range_uj"))
    writeLines("1000", f)
    nw <- co2fp(
      {
        writeLines("5", f)
        1
      },
      meth = "rapl",
      cpupwrw = 65,
      usage = 1,
      memgb = 0,
      rapldir = d
    )
    expect_equal(nw$method, "model")
    expect_match(paste(nw$assumptions, collapse = ";"), "wrapped")
    # counters that vanish mid-run fall back as well
    writeLines("1000", f)
    gone <- co2fp(
      {
        unlink(f)
        1
      },
      meth = "rapl",
      cpupwrw = 65,
      usage = 1,
      memgb = 0,
      rapldir = d
    )
    expect_equal(gone$method, "model")
    expect_match(paste(gone$assumptions, collapse = ";"), "unreadable")
    # a non-package domain, or an unreadable counter, means RAPL is not
    # available
    d2 <- mock_rapl(name = "psys")
    expect_false(raplok(d2))
    d3 <- mock_rapl()
    writeLines("not-a-number", file.path(d3, "intel-rapl:0", "energy_uj"))
    expect_false(raplok(d3))
    expect_error(co2fp(1, meth = "rapl", rapldir = d3), "not readable")
    unlink(c(d, d2, d3), recursive = TRUE)
  }
)

test_that("print and equivalents", {
  fp <- co2fp(
    1 + 1,
    meth = "model",
    cpupwrw = 65,
    usage = 1,
    memgb = 8,
    loc = "CA"
  )
  out <- utils::capture.output(print(fp))
  expect_match(out[1], "^Computation footprint \\(modelled\\)")
  expect_match(out[1], "utilisation 1.00 \\(fixed\\)")
  expect_match(out[3], "Canada, 2025")
  expect_equal(fp$usagemode, "fixed")
  fpu <- co2fp(
    1 + 1,
    meth = "model",
    cpupwrw = 65,
    usage = 1,
    memgb = 8,
    loc = 100
  )
  expect_match(utils::capture.output(print(fpu))[3], "user-supplied\\)")
  eq <- fpeqv(1750)
  expect_equal(eq$carkm, 10)
  expect_equal(eq$treemon, 1750 / 917)
  expect_error(fpeqv(-1), "non-negative")
  expect_error(fpeqv(c(1, 2)), "single")
})

test_that(
  paste0(
    "CPU seconds: children counted, NA child ",
    "times (Windows) counted as zero"
  ),
  {
    t0 <- structure(
      c(1, 0.5, 0, 2, 3),
      names = c("user.self", "sys.self", "elapsed", "user.child", "sys.child")
    )
    t1 <- structure(
      c(3, 1, 10, 2.5, 3),
      names = c("user.self", "sys.self", "elapsed", "user.child", "sys.child")
    )
    expect_equal(.rmbl_cpu_seconds(t0, t1), 3)
    t0[c("user.child", "sys.child")] <- NA
    t1[c("user.child", "sys.child")] <- NA
    expect_equal(.rmbl_cpu_seconds(t0, t1), 2.5)
    expect_equal(.rmbl_cpu_seconds(t1, t0), 0)
    fp <- co2fp(
      sum(sqrt(seq_len(1e5))),
      loc = "CA-ON",
      cpupwrw = 45,
      memgb = 16
    )
    expect_true(is.finite(fp$co2eg) && fp$co2eg >= 0)
    expect_true(is.list(fpeqv(fp$co2eg * 1e4)))
  }
)

test_that(
  paste0(
    "seams: memory from /proc/meminfo or sysctl, core count fallback, ",
    "assumptions printed"
  ),
  {
    mi <- tempfile("meminfo")
    writeLines(c("MemTotal:       16777216 kB", "MemFree:         1234 kB"), mi)
    expect_equal(.rmbl_total_memory_gb(meminfo = mi, sysname = "Linux"), 16)
    writeLines("MemTotal:       garbage", mi)
    expect_true(is.na(.rmbl_total_memory_gb(meminfo = mi, sysname = "Linux")))
    # the macOS branch runs sysctl -n hw.memsize; a stand-in sysctl answers 16
    # GiB, a broken one nothing
    none <- file.path(mi, "none")
    expect_true(is.na(.rmbl_total_memory_gb(
      meminfo = none,
      sysname = "Darwin",
      sysctl = ""
    )))
    expect_true(is.na(.rmbl_total_memory_gb(meminfo = none, sysname = "Plan9")))
    if (.Platform$OS.type == "unix") {
      fake <- tempfile("sysctl")
      writeLines(c("#!/bin/sh", "echo 17179869184"), fake)
      Sys.chmod(fake, "0755")
      expect_equal(
        .rmbl_total_memory_gb(
          meminfo = none,
          sysname = "Darwin",
          sysctl = fake
        ),
        16
      )
      writeLines(c("#!/bin/sh", "echo no such oid"), fake)
      expect_true(is.na(.rmbl_total_memory_gb(
        meminfo = none,
        sysname = "Darwin",
        sysctl = fake
      )))
      writeLines(c("#!/bin/sh", "exit 1"), fake)
      expect_true(is.na(.rmbl_total_memory_gb(
        meminfo = none,
        sysname = "Darwin",
        sysctl = fake
      )))
      unlink(fake)
    }
    # the machine counters vanish during the run: back to the process figure,
    # and said so
    st <- tempfile("stat")
    writeLines("cpu  100 0 100 700 100 0 0 0 0 0", st)
    fp <- co2fp(
      {
        unlink(st)
        1
      },
      loc = 100,
      meth = "model",
      usage = "machine",
      cpupwrw = 50,
      memgb = 0,
      procstat = st
    )
    expect_equal(fp$usagemode, "process")
    expect_match(paste(fp$assumptions, collapse = ";"), "became unreadable")
    # memory size unknown anywhere: 8 GB assumed, and said so
    local_mocked_bindings(.rmbl_total_memory_gb = function(...) NA_real_)
    fp <- co2fp(1 + 1, loc = 100, meth = "model", cpupwrw = 50, usage = 1)
    expect_equal(fp$memgb, 8)
    expect_match(
      paste(fp$assumptions, collapse = ";"),
      "memory size unknown: 8 GB assumed"
    )
    expect_true(is.finite(.rmbl_cores()) && .rmbl_cores() >= 1)
    local_mocked_bindings(.rmbl_cores = function() NA_integer_)
    fp <- co2fp(1 + 1, loc = 100, meth = "model", cpupwrw = 50, memgb = 8)
    expect_equal(fp$cores, 1L)
    expect_match(
      paste(fp$assumptions, collapse = ";"),
      "core count unknown; 1 assumed"
    )
    out <- utils::capture.output(print(fp))
    expect_match(out[4], "^  assumed: .*core count unknown")
    unlink(mi)
  }
)
