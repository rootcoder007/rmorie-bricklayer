# The 0.5.x names: no longer R functions (the eleven rmoriedata 0.3.x calls are,
# test-compat-0-5.R, and the four S3 generics below), but the command line knows
# each one from the map in inst/compat/: describe, run and migrate
# (R/cli_compat.R). Alias tests do not run on CRAN.
skip_on_cran()

.alias_map <- function() {
  p <- system.file(
    "compat",
    "compat_names_map.tsv",
    package = "rmoriebricklayer"
  )
  expect_true(nzchar(p))
  utils::read.delim(p, stringsAsFactors = FALSE, na.strings = character())
}

# old value -> new value per argument, from the map's `values` column
# ("arg:old=new;...")
.alias_values <- function(v) {
  if (!nzchar(v)) {
    return(list())
  }
  p <- strsplit(strsplit(v, ";", fixed = TRUE)[[1]], "[:=]")
  p <- Filter(function(z) z[1] != "...", p)
  out <- list()
  for (z in p) {
    out[[z[1]]] <- c(out[[z[1]]], stats::setNames(z[3], z[2]))
  }
  out
}

# blcli() with its output collected
.cli <- function(...) {
  buf <- character()
  st <- blcli(c(...), out = function(...) buf <<- c(buf, paste0(...)))
  list(status = st, text = paste(buf, collapse = ""))
}

test_that(
  paste0(
    "every 0.5.x name maps to an export ",
    "that takes the new argument names"
  ),
  {
    m <- .alias_map()
    expect_gt(nrow(m), 290L)
    ns <- getNamespaceExports("rmoriebricklayer")
    for (i in seq_len(nrow(m))) {
      old <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1]]
      new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
      expect_false(m$old[i] %in% ns, info = m$old[i])
      expect_true(m$new[i] %in% ns, info = m$new[i])
      expect_identical(length(old), length(new), info = m$old[i])
      tf <- names(formals(get(m$new[i], asNamespace("rmoriebricklayer"))))
      expect_true(all(new %in% tf), info = m$old[i])
    }
  }
)

test_that(
  paste0(
    "every renamed value is one the new ",
    "function allows, and no old one is"
  ),
  {
    m <- .alias_map()
    ns <- asNamespace("rmoriebricklayer")
    ntr <- 0L
    for (i in seq_len(nrow(m))) {
      vals <- .alias_values(m$values[i])
      old <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1]]
      new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
      tf <- formals(get(m$new[i], ns))
      for (a in names(vals)) {
        allowed <- eval(tf[[new[match(a, old)]]], baseenv())
        info <- paste(m$old[i], a)
        # a choice vector lists the allowed values; a single default is one of
        # them (the others, such as outcome "chiast", are run below)
        if (length(allowed) > 1L) {
          expect_true(all(vals[[a]] %in% allowed), info = info)
        } else {
          expect_true(allowed %in% vals[[a]], info = info)
        }
        expect_false(any(names(vals[[a]]) %in% allowed), info = info)
        ntr <- ntr + length(vals[[a]])
      }
    }
    expect_gte(ntr, 8L)
  }
)

test_that("describe and examples answer for a 0.5.x name", {
  r <- .cli("describe", "admissions")
  expect_identical(r$status, 0L)
  expect_match(
    r$text,
    "admissions() is the 0.5.x name of admits()",
    fixed = TRUE
  )
  expect_match(r$text, "Usage:", fixed = TRUE)
  r <- .cli("describe", "crf_pm25")
  expect_match(r$text, "exposure -> expo", fixed = TRUE)
  expect_match(
    r$text,
    "outcome values: all_cause_mortality -> allcause",
    fixed = TRUE
  )
  expect_match(.cli("examples", "admissions")$text, "admits(", fixed = TRUE)
  expect_identical(.cli("describe", "no_such_name")$status, 1L)
})

test_that(
  paste0(
    "run calls a function by its old name, old arguments and values ",
    "translated"
  ),
  {
    out1 <- function(x) {
      paste0(paste(utils::capture.output(print(x)), collapse = "\n"), "\n")
    }
    r <- .cli("run", "admissions", "--adp", "120", "--alos", "30")
    expect_identical(r$status, 0L)
    expect_identical(
      r$text,
      paste0(
        "(admissions() is now admits())\n",
        out1(admits(adp = 120, alos = 30))
      )
    )
    r <- .cli("run", "core_median", "1,2,30")
    expect_identical(
      r$text,
      paste0("(core_median() is now cmed())\n", out1(cmed(c(1, 2, 30))))
    )
    r <- .cli(
      "run",
      "crf_pm25",
      "--exposure",
      "10",
      "--outcome",
      "all_cause_mortality"
    )
    expect_identical(
      r$text,
      paste0(
        "(crf_pm25() is now crfpm25())\n",
        out1(crfpm25(expo = 10, y = "allcause"))
      )
    )
    # a new name runs as it is; a .csv value is read
    f <- tempfile(fileext = ".csv")
    utils::write.csv(
      data.frame(a = c(1, 2, 3, 4), b = c(2, 1, 4, 3)),
      f,
      row.names = FALSE
    )
    expect_identical(
      .cli("run", "cortbl", f)$text,
      out1(cortbl(utils::read.csv(f)))
    )
    expect_identical(.cli("run", "correlation_table", f)$status, 0L)
    # only this package's functions, old or new
    r <- .cli("run", "system", "ls")
    expect_identical(r$status, 2L)
    expect_match(r$text, "not a function of rmoriebricklayer")
    expect_identical(.cli("run")$status, 2L)
  }
)

test_that("migrate rewrites 0.5.x calls and leaves the rest of the script", {
  mig <- function(x) rmoriebricklayer:::.bl_migrate_text(x)
  src <- c(
    "library(rmoriebricklayer)",
    "a <- admissions(adp = 120, alos = 30)  # admissions() in a comment stays",
    "b <- rmoriebricklayer::crf_pm25(exposure = 10,",
    "  outcome = 'all_cause_mortality')",
    "x <- \"core_median\"; other::core_median(1)",
    "core_median(core_median(1:3))",
    "admits(adp = 1, alos = 2)"
  )
  r <- mig(src)
  expect_identical(
    r$lines,
    c(
      "library(rmoriebricklayer)",
      "a <- admits(adp = 120, alos = 30)  # admissions() in a comment stays",
      "b <- rmoriebricklayer::crfpm25(expo = 10,",
      "  y = 'allcause')",
      "x <- \"core_median\"; other::core_median(1)",
      "cmed(cmed(1:3))",
      "admits(adp = 1, alos = 2)"
    )
  )
  expect_identical(r$n, 7L)
  expect_identical(mig("x <- 1")$n, 0L)
  # the rewrite parses and runs as the old script did
  f <- tempfile(fileext = ".R")
  writeLines(
    c("v <- core_median(c(1, 2, 30))", "w <- admissions(adp = 120, alos = 30)"),
    f
  )
  r <- .cli("migrate", f)
  expect_identical(r$status, 0L)
  expect_match(r$text, "+ v <- cmed(c(1, 2, 30))", fixed = TRUE)
  expect_match(r$text, "2 changes (--write writes them)", fixed = TRUE)
  expect_identical(readLines(f)[1], "v <- core_median(c(1, 2, 30))")
  expect_match(
    .cli("migrate", f, "--write")$text,
    "2 changes written",
    fixed = TRUE
  )
  e <- new.env()
  sys.source(f, envir = e, toplevel.env = asNamespace("rmoriebricklayer"))
  expect_identical(e$v, cmed(c(1, 2, 30)))
  expect_identical(e$w, admits(adp = 120, alos = 30))
  expect_match(.cli("migrate", f)$text, "no 0.5.x names", fixed = TRUE)
  expect_identical(.cli("migrate", tempfile())$status, 1L)
  bad <- tempfile(fileext = ".R")
  writeLines("f(", bad)
  expect_match(
    .cli("migrate", bad)$text,
    "not R code R can parse",
    fixed = TRUE
  )
  expect_identical(.cli("migrate")$status, 2L)
})

# a result an alias returned, in its 1.0.0 names again
nn <- function(x) rmoriebricklayer:::.rmbl_new_names(x)

test_that("0.5.x option names are still read", {
  ns <- asNamespace("rmoriebricklayer")
  withr::local_options(
    rmoriebricklayer.dcache = NULL,
    rmoriebricklayer.data_cache = "old"
  )
  expect_identical(ns$.rmbl_getopt("dcache"), "old")
  withr::local_options(rmoriebricklayer.dcache = "new")
  expect_identical(ns$.rmbl_getopt("dcache"), "new")
  expect_identical(ns$.rmbl_getopt("nosuch", 3), 3)
  withr::local_options(
    rmoriebricklayer.maxcsvbytes = NULL,
    rmoriebricklayer.max_csv_bytes = NULL
  )
  expect_identical(ns$.rmbl_getopt("maxcsvbytes", 2^30), 2^30)
  expect_length(ns$.rmbl_old_options, 9L)
})

test_that("old plot values are translated", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- yoy(
    data.frame(year = 2019:2022, n = c(10, 12, 9, 15)),
    value = "n",
    prd = "year"
  )
  expect_identical(plot(y, what = "pct_change"), plot(y, what = "pctchg"))
  sf <- stkflow(
    days = c(100200, 104000, 99000),
    people = c(9800, 9500, 9900),
    prd = 2023:2025,
    expo = c(15e6, 15.5e6, 16e6)
  )
  expect_identical(
    plot(sf, what = c("flow_rate", "stock_rate")),
    plot(sf, what = c("flowrate", "stkrate"))
  )
  tab <- data.frame(year = 2018:2022, n = c(10, 12, 9, 15, 14), pop = 1000)
  a <- anltab(tab, value = "n", prd = "year", pop = "pop")
  expect_identical(plot(a, which = "rate_change"), plot(a, which = "ratechg"))
})

test_that("results come back under their 0.5.x names through an alias", {
  ns <- asNamespace("rmoriebricklayer")
  out <- function(topic, x, visible = TRUE) {
    ns$.rmbl_alias_out(topic, list(value = x, visible = visible))
  }
  # a data frame: columns renamed back, class and attributes kept, marked for
  # the methods
  d <- structure(
    data.frame(year = 1:2, pctchg = c(1, 2), pctlo = 0),
    class = c("rmbl_yoy", "data.frame"),
    yoy = list(conflvl = 0.95, minbase = 0)
  )
  o <- out("yoy", d)
  expect_identical(names(o), c("year", "pct_change", "pct_lower"))
  expect_identical(class(o), c("rmbl_old", "rmbl_yoy", "data.frame"))
  expect_identical(names(attr(o, "yoy")), c("conf_level", "min_base"))
  expect_identical(nn(o), d)
  # a classed list, nested data frames and a renamed attribute
  cf <- structure(
    list(tab = data.frame(rolclr = 1, cumnet = 2), inner = list(penchg = 3)),
    class = "rmbl_case_flow",
    caseflow = list(conflvl = 0.9)
  )
  o <- out("case_flow", cf)
  expect_identical(names(o$tab), c("rolling_clearance", "cumulative_net"))
  expect_identical(names(o$inner), "pending_change")
  expect_identical(names(attr(o, "case_flow")), "conf_level")
  expect_identical(nn(o), cf)
  # a named vector and a matrix: renamed, no class to mark
  expect_identical(
    names(out("kem_sizes", c(public = 1L, ciphertext = 2L, shared = 3L))),
    c("encapsulation_key", "ciphertext", "shared_secret")
  )
  m <- matrix(1:2, 1, dimnames = list(NULL, c("pctchg", "x")))
  expect_identical(colnames(out("yoy", m)), c("pct_change", "x"))
  # nothing renamed: the result as it was, unmarked; visibility kept
  expect_identical(out("yoy", data.frame(a = 1)), data.frame(a = 1))
  expect_false(withVisible(out("yoy", 1, visible = FALSE))$visible)
  expect_identical(nn(1), 1)
  # an unknown page still renames the 1.0.0 names no 0.5.13 result used
  expect_identical(names(out("no_such_page", list(pctchg = 1))), "pct_change")
})

test_that("a translated result prints, plots and is read back by the aliases", {
  seg <- data.frame(year = 2019:2022, n = c(10, 12, 9, 15))
  y <- yoy(seg, value = "n", period = "year")
  y1 <- yoy(seg, value = "n", prd = "year")
  expect_true("pct_change" %in% names(y))
  expect_false("pct_change" %in% names(y1))
  expect_identical(capture.output(print(y)), capture.output(print(y1)))
  expect_identical(unname(format(y)), unname(format(y1)))
  expect_true("pct_change" %in% names(format(y)))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(unname(plot(y)), unname(plot(y1)))
  expect_true("pct_change" %in% names(plot(y)))
  expect_identical(nn(yoy_summary(y)), yoysmry(y1))
  # no package method: R's own runs on the 0.5.x names
  pl <- rmoriebricklayer:::.rmbl_alias_out(
    "frequency_table",
    list(value = data.frame(pctvalid = 1), visible = TRUE)
  )
  expect_output(print(pl), "pct_valid")
  expect_s3_class(summary(pl), "table")
  expect_identical(format(pl), format(data.frame(pct_valid = 1)))
  # a 1.0.0 call is never translated
  expect_identical(class(yoysmry(y1)), "data.frame")
})
