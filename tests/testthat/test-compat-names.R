# Every 0.5.13 name 1.0.0 renamed still works: the alias has the old formals and forwards each of
# them to the new function under the new argument name. The map ships in inst/compat/.

.alias_map <- function() {
  p <- system.file("compat", "compat_names_map.tsv", package = "rmoriebricklayer")
  expect_true(nzchar(p))
  utils::read.delim(p, stringsAsFactors = FALSE, na.strings = character())
}

# old value -> new value per argument, from the map's `values` column ("arg:old=new;...")
.alias_values <- function(v) {
  if (!nzchar(v)) return(list())
  p <- strsplit(strsplit(v, ";", fixed = TRUE)[[1]], "[:=]")
  p <- Filter(function(z) z[1] != "...", p)
  out <- list()
  for (z in p) out[[z[1]]] <- c(out[[z[1]]], stats::setNames(z[3], z[2]))
  out
}

test_that("every alias exists, is exported and keeps the old formals", {
  m <- .alias_map()
  expect_gt(nrow(m), 290L)
  ns <- getNamespaceExports("rmoriebricklayer")
  for (i in seq_len(nrow(m))) {
    expect_true(m$old[i] %in% ns, info = m$old[i])
    expect_true(m$new[i] %in% ns, info = m$new[i])
    expect_identical(as.character(names(formals(get(m$old[i], asNamespace("rmoriebricklayer"))))),
                     strsplit(m$old_args[i], ",", fixed = TRUE)[[1]], info = m$old[i])
  }
})

test_that("every alias forwards each old argument under the new name", {
  m <- .alias_map()
  for (i in seq_len(nrow(m))) {
    old <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1]]
    new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
    if (!length(old)) new <- character()
    # one value per old formal (a dummy for `...`), the target replaced by a recorder that
    # reads the names it was called with and never forces a promise
    args <- stats::setNames(as.list(seq_along(old)), old)
    args[old == "..."] <- NULL
    seen <- new.env()
    rec <- function(...) {
      seen$names <- as.character(...names())
      invisible(NULL)
    }
    do.call(testthat::with_mocked_bindings,
            c(list(code = bquote(do.call(.(m$old[i]), .(args)))), stats::setNames(list(rec), m$new[i]),
              list(.package = "rmoriebricklayer")))
    want <- new[old != "..."]
    expect_identical(seen$names, want, info = m$old[i])
  }
})

test_that("every alias called with its defaults hands the target values it allows", {
  m <- .alias_map()
  ns <- asNamespace("rmoriebricklayer")
  ntr <- 0L
  for (i in seq_len(nrow(m))) {
    f <- get(m$old[i], ns)
    fo <- formals(f)
    old <- names(fo)
    new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
    # a dummy only where the old formal has no default; the rest are the alias's own defaults
    need <- old[vapply(seq_along(fo), function(k) is.name(fo[[k]]) && !nzchar(as.character(fo[[k]])), NA)]
    need <- setdiff(need, "...")
    args <- stats::setNames(as.list(seq_along(need)), need)
    vals <- .alias_values(m$values[i])
    tnew <- new[match(names(vals), old)]
    seen <- new.env()
    rec <- function(...) {
      seen$names <- as.character(...names())
      seen$vals <- lapply(tnew, function(n) ...elt(match(n, ...names())))
      invisible(NULL)
    }
    do.call(testthat::with_mocked_bindings,
            c(list(code = bquote(do.call(.(m$old[i]), .(args)))), stats::setNames(list(rec), m$new[i]),
              list(.package = "rmoriebricklayer")))
    expect_identical(seen$names, new[old != "..."], info = m$old[i])
    tf <- formals(get(m$new[i], ns))
    for (k in seq_along(vals)) {
      allowed <- eval(tf[[tnew[k]]], baseenv())
      info <- paste(m$old[i], names(vals)[k])
      # the old default arrives as the target's own default, and each renamed value is allowed:
      # a choice vector lists the allowed values; a single default is one of them (the others,
      # such as outcome "chiast", are run below)
      expect_identical(seen$vals[[k]], allowed, info = info)
      if (length(allowed) > 1L) expect_true(all(vals[[k]] %in% allowed), info = info)
      else expect_true(allowed %in% vals[[k]], info = info)
      expect_false(any(names(vals[[k]]) %in% allowed), info = info)
      ntr <- ntr + length(vals[[k]])
    }
  }
  expect_gte(ntr, 8L)
})

test_that("an alias really reaches the new function", {
  f <- tempfile()
  writeLines("abc", f)
  expect_identical(crc32_file(f), crc32file(f))
  expect_identical(gini(c(1, 2, 3, 10)), ginicoef(c(1, 2, 3, 10)))
  expect_identical(rule_not_null("x"), rulenull("x"))
})

# a result an alias returned, in its 1.0.0 names again
nn <- function(x) rmoriebricklayer:::.rmbl_new_names(x)

test_that("old defaults and old allowed values work end to end", {
  d <- data.frame(w = 1:4, y = 1:4)
  expect_s3_class(survey_design(d, weights = "w"), "rmbl_svy_design")
  expect_identical(survey_design(d, weights = "w", type = "mean_bootstrap")$type,
                   svydes(d, w = "w", type = "meanboot")$type)
  expect_identical(nn(crf_no2(20)), crfno2(20))
  expect_identical(nn(crf_pm25(20)), crfpm25(20))
  expect_identical(nn(crf_no2(20, outcome = "all_cause_mortality")), crfno2(20, y = "allcause"))
  tab <- data.frame(year = 2018:2022, n = c(10, 12, 9, 15, 14))
  expect_identical(nn(analyse_table(tab, value = "n", period = "year")),
                   anltab(tab, value = "n", prd = "year"))
  expect_identical(nn(analyse_table(tab, value = "n", period = "year", direction = "higher_is_better")),
                   anltab(tab, value = "n", prd = "year", dir = "higher"))
  expect_identical(nn(pollution_burden(5, 1, 0.008, 1e5)), polbrdn(5, 1, 0.008, 1e5))
  at <- data.frame(fsa = c("A", "B"), exposure = c(5, 8), population = c(1e4, 2e4),
                   baseline_rate = c(0.005, 0.006))
  expect_identical(nn(pollution_burden_by_area(at)),
                   polbrdarea(at, basratecol = "baseline_rate"))
  expect_identical(nn(verify_pollution("NO2", demo = TRUE)), vrfpol("NO2", demo = TRUE))
  # an allowed value renamed that no default shows
  expect_identical(nn(crf_no2(20, outcome = "childhood_asthma")), crfno2(20, y = "chiast"))
  expect_identical(nn(pollution_burden(5, 1, 0.008, 1e5, outcome = "childhood_asthma")),
                   polbrdn(5, 1, 0.008, 1e5, y = "chiast"))
  expect_identical(nn(pollution_burden_by_area(at, outcome = "childhood_asthma")),
                   polbrdarea(at, basratecol = "baseline_rate", y = "chiast"))
  expect_identical(nn(verify_pollution("NO2", outcome = "childhood_asthma", demo = TRUE)),
                   vrfpol("NO2", y = "chiast", demo = TRUE))
})

test_that("0.5.x option names are still read", {
  ns <- asNamespace("rmoriebricklayer")
  withr::local_options(rmoriebricklayer.dcache = NULL, rmoriebricklayer.data_cache = "old")
  expect_identical(ns$.rmbl_getopt("dcache"), "old")
  withr::local_options(rmoriebricklayer.dcache = "new")
  expect_identical(ns$.rmbl_getopt("dcache"), "new")
  expect_identical(ns$.rmbl_getopt("nosuch", 3), 3)
  withr::local_options(rmoriebricklayer.maxcsvbytes = NULL, rmoriebricklayer.max_csv_bytes = NULL)
  expect_identical(ns$.rmbl_getopt("maxcsvbytes", 2^30), 2^30)
  expect_length(ns$.rmbl_old_options, 9L)
})

test_that("old plot values are translated", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- yoy(data.frame(year = 2019:2022, n = c(10, 12, 9, 15)), value = "n", prd = "year")
  expect_identical(plot(y, what = "pct_change"), plot(y, what = "pctchg"))
  sf <- stkflow(days = c(100200, 104000, 99000), people = c(9800, 9500, 9900), prd = 2023:2025,
                expo = c(15e6, 15.5e6, 16e6))
  expect_identical(plot(sf, what = c("flow_rate", "stock_rate")), plot(sf, what = c("flowrate", "stkrate")))
  tab <- data.frame(year = 2018:2022, n = c(10, 12, 9, 15, 14), pop = 1000)
  a <- anltab(tab, value = "n", prd = "year", pop = "pop")
  expect_identical(plot(a, which = "rate_change"), plot(a, which = "ratechg"))
})

test_that("old argument names passed through ... are renamed", {
  b <- c("0-4", "5-9", "10+")
  expect_identical(expand_bands(b, c(1, 2, 3), open_upper_cap = 12),
                   expbands(b, c(1, 2, 3), openupcap = 12))
  # names the alias forwards untouched
  expect_null(rmoriebricklayer:::.rmbl_alias_dots(c(a = "b")))
  expect_null(rmoriebricklayer:::.rmbl_alias_dots(c(a = "b"), 1, x = 2))
})

test_that("every alias whose `...` carries 0.5.x names renames each of them", {
  m <- .alias_map()
  m <- m[grepl("(^|;)\\.\\.\\.:", m$values), ]
  expect_gte(nrow(m), 4L)
  for (i in seq_len(nrow(m))) {
    p <- strsplit(strsplit(m$values[i], ";", fixed = TRUE)[[1]], "[:=]")
    p <- Filter(function(z) z[1] == "...", p)
    old <- strsplit(m$old_args[i], ",", fixed = TRUE)[[1]]
    new <- strsplit(m$new_args[i], ",", fixed = TRUE)[[1]]
    args <- stats::setNames(as.list(seq_along(old)), old)
    args[old == "..."] <- NULL
    args <- c(args, stats::setNames(as.list(seq_along(p)), vapply(p, `[`, "", 2L)), list(9))
    seen <- new.env()
    rec <- function(...) {
      seen$names <- as.character(...names())
      invisible(NULL)
    }
    do.call(testthat::with_mocked_bindings,
            c(list(code = bquote(do.call(.(m$old[i]), .(args)))), stats::setNames(list(rec), m$new[i]),
              list(.package = "rmoriebricklayer")))
    expect_identical(seen$names, c(new[old != "..."], vapply(p, `[`, "", 3L), ""), info = m$old[i])
  }
})

test_that("results come back under their 0.5.x names through an alias", {
  ns <- asNamespace("rmoriebricklayer")
  out <- function(topic, x, visible = TRUE) ns$.rmbl_alias_out(topic, list(value = x, visible = visible))
  # a data frame: columns renamed back, class and attributes kept, marked for the methods
  d <- structure(data.frame(year = 1:2, pctchg = c(1, 2), pctlo = 0), class = c("rmbl_yoy", "data.frame"),
                 yoy = list(conflvl = 0.95, minbase = 0))
  o <- out("yoy", d)
  expect_identical(names(o), c("year", "pct_change", "pct_lower"))
  expect_identical(class(o), c("rmbl_old", "rmbl_yoy", "data.frame"))
  expect_identical(names(attr(o, "yoy")), c("conf_level", "min_base"))
  expect_identical(nn(o), d)
  # a classed list, nested data frames and a renamed attribute
  cf <- structure(list(tab = data.frame(rolclr = 1, cumnet = 2), inner = list(penchg = 3)),
                  class = "rmbl_case_flow", caseflow = list(conflvl = 0.9))
  o <- out("case_flow", cf)
  expect_identical(names(o$tab), c("rolling_clearance", "cumulative_net"))
  expect_identical(names(o$inner), "pending_change")
  expect_identical(names(attr(o, "case_flow")), "conf_level")
  expect_identical(nn(o), cf)
  # a named vector and a matrix: renamed, no class to mark
  expect_identical(names(out("kem_sizes", c(public = 1L, ciphertext = 2L, shared = 3L))),
                   c("encapsulation_key", "ciphertext", "shared_secret"))
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
  fr <- frequency_table(data.frame(g = c("a", "a", "b")), "g")
  expect_true("pct_valid" %in% names(fr))
  expect_output(print(fr), "Frequency table")
  pl <- rmoriebricklayer:::.rmbl_alias_out("frequency_table", list(value = data.frame(pctvalid = 1),
                                                                    visible = TRUE))
  expect_output(print(pl), "pct_valid")
  expect_s3_class(summary(pl), "table")
  expect_identical(format(pl), format(data.frame(pct_valid = 1)))
  # an alias given a translated result reads it in the 1.0.0 names, and writes the 0.5.x header
  txt <- yoy_csv(y, NULL)
  expect_match(txt, "year,value,previous,change,pct_change", fixed = TRUE)
  f <- tempfile(fileext = ".csv")
  expect_invisible(yoy_csv(y, f))
  expect_identical(names(utils::read.csv(f, comment.char = "#"))[5], "pct_change")
  expect_match(yoy_tsv(y, NULL), "pct_change", fixed = TRUE)
  h <- tempfile(fileext = ".html")
  yoy_write(y, h)
  expect_true(file.exists(h))
  expect_identical(yoy_markdown(y, NULL), yoymd(y1, NULL))
  # a text with no header row is left as it is
  hdr <- rmoriebricklayer:::.rmbl_alias_header
  expect_identical(hdr(list(value = "# only a comment", visible = TRUE), NULL, c(a = "b")), "# only a comment")
  # a 1.0.0 call is never translated
  expect_identical(class(yoysmry(y1)), "data.frame")
})
