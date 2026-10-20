# The pre-CRAN audit of 30bed8e (stats, plotting and data reading), each finding reproduced first.

# a result an alias returned, in its 1.0.0 names again
nn <- function(x) rmoriebricklayer:::.rmbl_new_names(x)

test_that("rate, rate_change, share and yoy_summary are S3 generics again, with the old arguments", {
  for (g in c("rate", "rate_change", "share", "yoy_summary")) {
    expect_true(utils::isS3stdGeneric(get(g, asNamespace("rmoriebricklayer"))), info = g)
  }
  d <- data.frame(n = c(5, 8, 3), pop = c(1000, 1200, 900), g = c("a", "b", "c"))
  expect_identical(nn(rate(d, count = "n", population = "pop", by = "g")),
                   rtcalc(d, count = "n", pop = "pop", by = "g"))
  expect_identical(nn(rate(10, population = 1000)), rtcalc(10, pop = 1000))
  # conf_level reaches the method instead of vanishing in `...`
  expect_identical(rate(d, count = "n", pop = "pop", conf_level = 0.5)$lower,
                   rtcalc(d, count = "n", pop = "pop", conflvl = 0.5)$lower)
  expect_equal(share(c(1, 2, 3), conf_level = 0.5)$lower, c(8.85, 21.9, 36.7), tolerance = 0.01)
  expect_identical(nn(share(d, count = "n", conf_level = 0.5)), shrs(d, count = "n", conflvl = 0.5))
  # bare column names still read as columns through the old generic
  expect_identical(nn(rate(d, n, pop, by = "g")), rtcalc(d, count = "n", pop = "pop", by = "g"))
  ch <- data.frame(year = rep(2019:2021, 2), g = rep(c("a", "b"), each = 3), n = c(4, 6, 9, 3, 2, 5),
                   pop = 1000)
  expect_identical(nn(rate_change(ch, count = "n", population = "pop", period = "year", by = "g",
                               conf_level = 0.9, min_count = 3)),
                   ratechg(ch, count = "n", pop = "pop", prd = "year", by = "g", conflvl = 0.9, mincnt = 3))
  expect_error(rate_change(1:3), "data frame")
  y <- yoy(data.frame(year = 2019:2022, n = c(10, 12, 9, 15)), value = "n", prd = "year")
  expect_identical(nn(yoy_summary(y)), yoysmry(y))
  expect_error(yoy_summary(1), "yoy")
  # a method written for the old generic dispatches
  local({
    rate.mycls <- function(x, ...) "mine"
    registerS3method("rate", "mycls", rate.mycls, envir = asNamespace("rmoriebricklayer"))
    expect_identical(nn(rate(structure(1, class = "mycls"))), "mine")
  })
})

test_that("old argument names after `...` still work: plot of a clearance decomposition", {
  cd <- clrdcmp(num = c(90, 20, 19, 60), den = c(100, 50, 20, 140),
                grp = c("minor", "serious", "minor", "serious"), cmp = c("A", "A", "B", "B"))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_silent(plot(cd, max_parts = 3))
  expect_error(plot(cd, max_parts = 3, maxparts = 3), "not both")
})

test_that("yoy() takes its 0.5.x argument names and values; giving both is refused", {
  seg <- data.frame(year = 2019:2022, n = c(10, 12, 9, 15))
  new <- yoy(seg, value = "n", prd = "year", minbase = 11, conflvl = 0.5, dir = "higher")
  expect_identical(nn(yoy(seg, value = "n", period = "year", min_base = 11, conf_level = 0.5,
                       direction = "higher_is_better")), new)
  expect_identical(nn(yoy(seg, value = n, period = year, dir = "higher", minbase = 11, conflvl = 0.5)), new)
  expect_identical(yoy(seg, value = "n", prd = "year", dir = "lower_is_better"),
                   yoy(seg, value = "n", prd = "year", dir = "lower"))
  expect_error(yoy(seg, value = "n", period = "year", prd = "year"),
               "yoy: give `prd` or its 0.5.x name `period`, not both")
  expect_identical(nn(yoy(c(10, 12, 9), period = 2001:2003)), yoy(c(10, 12, 9), prd = 2001:2003))
  expect_identical(nn(yoy(c(10L, 12L, 9L), period = 2001:2003)), yoy(c(10L, 12L, 9L), prd = 2001:2003))
  tsx <- stats::ts(c(10, 12, 9, 15, 11, 13, 12, 14), frequency = 4, start = 2020)
  expect_identical(nn(yoy(tsx, conf_level = 0.5)), yoy(tsx, conflvl = 0.5))
})

test_that("yearly, quarterly and monthly Date periods compare on calendar steps", {
  y <- yoy(data.frame(d = as.Date(c("2019-01-01", "2020-01-01", "2021-01-01")), n = c(10, 12, 15)),
           value = "n", prd = "d")
  expect_identical(nrow(y), 3L)
  expect_identical(y$previous, c(NA, 10, 12))
  y0 <- yoy(data.frame(d = as.Date(c("2019-01-01", "2020-01-01", "2021-01-01")), n = c(10, 12, 15)),
            value = "n", prd = "d", complete = FALSE)
  expect_identical(y0$previous, c(NA, 10, 12))
  # a missing year is inserted as one row, not 365 days
  yg <- yoy(data.frame(d = as.Date(c("2018-07-01", "2019-07-01", "2021-07-01")), n = c(5, 6, 8)),
            value = "n", prd = "d")
  expect_identical(format(yg$d), c("2018-07-01", "2019-07-01", "2020-07-01", "2021-07-01"))
  expect_identical(yg$flag[3:4], c("no data", "no comparison period"))
  m <- data.frame(d = seq(as.Date("2020-01-15"), by = "month", length.out = 40), n = 1:40 + 10)
  y12 <- yoy(m, value = "n", prd = "d", lag = 12)
  expect_identical(nrow(y12), 40L)
  expect_identical(sum(!is.na(y12$previous)), 28L)
  # a month missing: complete = TRUE puts it back, complete = FALSE leaves the gap uncompared
  yc <- yoy(m[-5, ], value = "n", prd = "d")
  expect_identical(c(nrow(yc), sum(!is.na(yc$previous))), c(40L, 38L))
  yn <- yoy(m[-5, ], value = "n", prd = "d", complete = FALSE)
  expect_identical(c(nrow(yn), sum(!is.na(yn$previous))), c(39L, 37L))
  q <- data.frame(d = seq(as.Date("2020-01-01"), by = "3 months", length.out = 8), n = 1:8)
  expect_identical(yoy(q, value = "n", prd = "d", lag = 4)$previous, c(rep(NA, 4), 1:4 + 0))
  me <- data.frame(d = seq(as.Date("2020-02-01"), by = "month", length.out = 6) - 1, n = 1:6)
  expect_identical(yoy(me[-3, ], value = "n", prd = "d")$d, me$d)
  # daily and weekly data keep the grid of days
  wk <- data.frame(d = as.Date("2020-01-06") + 7 * c(0, 1, 3), n = c(3, 4, 5))
  expect_identical(nrow(yoy(wk, value = "n", prd = "d")), 4L)
  # the plot draws every period
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_identical(nrow(plot(y12, what = "value")), 40L)
  expect_identical(sum(is.finite(plot(y12)$pctchg)), 28L)
})

test_that("svydes JKn keeps a replicate of a large stratum on a domain (rscales)", {
  skip_if_not_installed("survey")
  set.seed(3)
  d <- data.frame(st = c(rep("S1", 150), rep("S2", 6)), psu = c(1:150, rep(151:153, each = 2)),
                  y = stats::rnorm(156, 10), w = stats::runif(156, 1, 3))
  rp <- survey::as.svrepdesign(survey::svydesign(ids = ~psu, strata = ~st, weights = ~w, data = d),
                               type = "JKn")
  a <- stats::weights(rp, "analysis")
  k <- sort(sample(156, 78))
  z <- svydes(d[k, ], w = d$w[k], reps = a[k, ], type = "jkn", rscales = rp$rscales)
  rs <- survey::svrepdesign(data = d[k, ], repweights = a[k, ], weights = d$w[k], type = "JKn",
                            scale = 1, rscales = rp$rscales, combined.weights = TRUE, mse = TRUE)
  expect_silent(z <- svydes(d[k, ], w = d$w[k], reps = a[k, ], type = "jkn", rscales = rp$rscales))
  expect_equal(svyest(z, d[k, ], "y")$se, unname(survey::SE(survey::svymean(~y, rs))), tolerance = 1e-10)
  # a copy within 1% that is not 1 / rscale is still refused
  bad <- a[k, ]
  bad[, 2] <- d$w[k] * 1.004
  expect_error(svydes(d[k, ], w = d$w[k], reps = bad, type = "jkn", rscales = rp$rscales), "copy")
})

test_that("stepchg rescales tiny series and refuses periods that are not numbers or dates", {
  set.seed(1)
  y <- c(stats::rnorm(20, 10), stats::rnorm(20, 15))
  a <- stepchg(y, seed = 1, nperm = 99)
  b <- stepchg(y * 1e-200, seed = 1, nperm = 99)
  expect_identical(b$breakafter, a$breakafter)
  expect_identical(b$p_value, a$p_value)
  expect_equal(b$difference, a$difference * 1e-200)
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = as.character(40:35)), "stepchg: `x` must be numbers or dates")
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = factor(1:6)), "stepchg: `x` must be numbers or dates")
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, NA, 3:6)), "stepchg: `x` has a missing period")
  expect_silent(stepchg(c(1, NA, 3, 4, 5, 6, 7), x = c(1, NA, 3:7), nperm = 9))
})

test_that("text periods are drawn in time order", {
  ax <- rmoriebricklayer:::.bl_period_axis(c("2019/20", "2021/22", "2020/21"))
  expect_identical(ax$tlab[order(ax$ticks)], c("2019/20", "2020/21", "2021/22"))
  expect_identical(ax$at, c(1L, 3L, 2L))
  ord <- rmoriebricklayer:::.bl_period_order
  expect_identical(ord(c("2020-03", "2019-11", "2020-01")), c("2019-11", "2020-01", "2020-03"))
  expect_identical(ord(c("2020Q2", "2019Q4", "2020Q1")), c("2019Q4", "2020Q1", "2020Q2"))
  expect_identical(ord(c("2021", "2019")), c("2019", "2021"))
  expect_identical(ord(c("b", "a")), c("a", "b"))
  f <- factor(c("lo", "hi"), levels = c("lo", "hi"))
  expect_identical(rmoriebricklayer:::.bl_period_axis(f)$at, 1:2)
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  r <- plot(yoy(data.frame(fy = c("2019/20", "2021/22", "2020/21"), grp = c("A", "A", "B"),
                           n = c(10, 20, 30)), value = "n", prd = "fy", by = "grp"))
  # A: 2019/20 and 2021/22, B: 2020/21, each at its period's slot (groups sit side by side)
  expect_identical(round(r$at), c(1, 3, 2))
})

test_that("plot(yoy()) labels a period after a gap, and refuses a result with no values", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  seen <- new.env()
  rec <- function(ax, est, lower, upper, main, ylab, xlab, cols, ref = NULL, note = NULL, ...) {
    seen$note <- c(seen$note, list(note))
    seq_along(est)
  }
  local_mocked_bindings(.bl_time_interval = rec, .package = "rmoriebricklayer")
  d1 <- data.frame(year = 2015:2022, n = c(0, 10, 0, 5, NA, 12, 15, 9))
  plot(yoy(d1, value = "n", prd = "year"))
  why <- seen$note[[1]]
  expect_identical(why[1], "first period: nothing to compare with")
  expect_identical(why[5], "no data")
  expect_identical(why[6], "no data in the previous period")
  # an ordered factor with a missing level, and a gap inside a group with complete = FALSE
  lv <- c("q1", "q2", "q3", "q4")
  of <- data.frame(q = factor(c("q1", "q2", "q4"), levels = lv, ordered = TRUE), n = c(3, 4, 6))
  plot(yoy(of, value = "n", prd = "q"))
  expect_identical(seen$note[[2]][4], "no data in the previous period")
  g <- data.frame(year = c(2019, 2020, 2022, 2019, 2020, 2021), grp = rep(c("A", "B"), each = 3),
                  n = c(5, 6, 7, 2, 3, 4))
  plot(yoy(g, value = "n", prd = "year", by = "grp", complete = FALSE))
  w <- seen$note[[3]]
  expect_identical(sum(w == "first period: nothing to compare with"), 2L)
  expect_identical(sum(w == "no data in the previous period"), 1L)
  expect_error(plot(yoy(data.frame(year = 2019:2022, n = NA_real_), value = "n", prd = "year")),
               "plot: no period has a value")
})

test_that("refusals name the current arguments and the function", {
  expect_error(rtcalc(10, pop = 0), "rtcalc: `pop` must be positive")
  ch <- data.frame(year = 2019:2020, n = c(4, 6), pop = c(0, 1000))
  expect_error(ratechg(ch, count = "n", pop = "pop", prd = "year"), "ratechg: `pop` must be positive")
  dd <- data.frame(y = stats::rnorm(20), e = stats::rnorm(20), c = stats::rnorm(20))
  expect_error(exprspplr(dd, "y", "e", "c", estr = function(a) 1),
               "exprspplr: `estr` failed on the full sample, called as estr\\(data, y, expo, confs\\)")
  expect_error(blcli(NA_character_), "blcli: `args` must be a character vector")
  expect_error(blcli(function() 1), "blcli: `args` must be a character vector")
  expect_error(dlogin(email = function() 1), "dlogin: `email` must be one string")
  od <- tempfile()
  dir.create(od)
  writeLines("", file.path(od, "x"))
  expect_error(instcli(dir = file.path(od, "x", "bin")), "instcli: `dir` .* cannot be created or written")
})

test_that("the readers of the renamed options take the 0.5.x names", {
  ns <- asNamespace("rmoriebricklayer")
  d <- tempfile("old-opts-")
  dir.create(d)
  idx <- file.path(d, "idx.txt")
  withr::local_options(rmoriebricklayer.dcache = NULL, rmoriebricklayer.data_cache = d,
                       rmoriebricklayer.xmssidxfile = NULL, rmoriebricklayer.xmss_index_file = idx,
                       rmoriebricklayer.maxcsvbytes = NULL, rmoriebricklayer.max_csv_bytes = 10,
                       rmoriebricklayer.llmcache = NULL, rmoriebricklayer.llm_cache = TRUE,
                       rmoriebricklayer.llmcachedir = NULL, rmoriebricklayer.llm_cache_dir = d,
                       rmoriebricklayer.llmcachedays = NULL, rmoriebricklayer.llm_cache_days = 30,
                       rmoriebricklayer.llmcachemax = NULL, rmoriebricklayer.llm_cache_max = 200L)
  expect_identical(normalizePath(ns$.bl_data_cache_dir()), normalizePath(d))
  expect_identical(ns$.rmbl_max_csv_bytes(), 10)
  expect_identical(basename(ns$.rmbl_xmss_index_file()), "idx.txt")
  withr::local_envvar(TESTTHAT = "false", `_R_CHECK_PACKAGE_NAME_` = "", MORIE_LLM_CACHE = "")
  local_mocked_bindings(.bl_person_watching = function() TRUE, .package = "rmoriebricklayer")
  withr::local_options(morie.quiet = FALSE)
  expect_true(ns$.bl_answer_cache_on())
  key <- strrep("a", 64)
  writeLines("{}", file.path(d, paste0(key, ".json")))
  withr::local_options(rmoriebricklayer.llm_cache_days = -1)
  expect_null(ns$.bl_answer_get(key))
  expect_false(file.exists(file.path(d, paste0(key, ".json"))))
  writeLines("{}", file.path(d, paste0(key, ".json")))
  writeLines("{}", file.path(d, paste0(strrep("b", 64), ".json")))
  withr::local_options(rmoriebricklayer.llm_cache_days = 30, rmoriebricklayer.llm_cache_max = 1L)
  ns$.bl_answer_prune(d)
  expect_length(list.files(d, pattern = "[.]json$"), 1L)
  withr::local_options(rmoriebricklayer.llm_cache = FALSE)
  expect_false(ns$.bl_answer_cache_on())
  expect_identical(normalizePath(ns$.bl_answer_dir()), normalizePath(d))
  expect_null(ns$.bl_answer_get("nokey"))
  expect_silent(ns$.bl_answer_prune(d))
  expect_identical(ns$.bl_check_email("A@Example.org"), "a@example.org")
  expect_error(stepchg(c(1, 2, 3, 4, 5, 6), x = c(1, 3, 2, 4, 5, 6)), "stepchg: `x` must be strictly increasing")
})
