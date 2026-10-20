otis <- read.csv(system.file("extdata", "otis_a01_individuals.csv",
                             package = "rmoriebricklayer"))

test_that("pubbnd turns rounding and suppression into intervals", {
  b <- pubbnd(c(120, 35, 0), rnd = 5)
  expect_equal(b$lower, c(117.5, 32.5, 0))
  expect_equal(b$upper, c(122.5, 37.5, 2.5))
  expect_true(all(b$status == "rounded"))
  # random rounding to base 5 moves a cell by up to 4
  r <- pubbnd(15, rnd = 5, rndkind = "random")
  expect_equal(c(r$lower, r$upper), c(11, 19))
  # suppressed cells: explicit "<k" or a mark with a limit
  s <- pubbnd(c("120", "x", "<5", "1,250"), rnd = 5,
                        suplim = 5)
  expect_equal(s$status, c("rounded", "suppressed", "suppressed", "rounded"))
  expect_equal(s$upper[2:3], c(4, 4))
  expect_equal(s$value[4], 1250)
  expect_true(is.na(s$value[2]))
  expect_error(pubbnd("x"), "limit")
  expect_error(pubbnd("abc"), "cannot read")
  expect_equal(pubbnd(7)$status, "exact")
})

test_that("chgenv is the exact image of the input intervals", {
  now <- pubbnd(c(45, 120), rnd = 5)
  prev <- pubbnd(c(40, 100), rnd = 5)
  e <- chgenv(now, prev)
  expect_equal(e$chglo, c(42.5 - 42.5, 117.5 - 102.5))
  expect_equal(e$chgup, c(47.5 - 37.5, 122.5 - 97.5))
  expect_equal(e$pctlo[1], 100 * (42.5 / 42.5 - 1))
  expect_equal(e$pctup[1], 100 * (47.5 / 37.5 - 1))
  # a previous cell that could be zero has no finite percent bound
  z <- chgenv(pubbnd("<5"), pubbnd("<5"))
  expect_true(is.na(z$pctup))
  # the envelope contains the point estimate
  expect_true(all(e$pctlo <= 100 * (c(45, 120) / c(40, 100) - 1)))
  expect_true(all(e$pctup >= 100 * (c(45, 120) / c(40, 100) - 1)))
})

test_that("yoybnd widens the sampling interval, never narrows it", {
  y <- yoy(otis, value = "individuals", prd = "year",
           by = c("table", "group"))
  yb <- yoybnd(y, rnd = 5)
  ok <- !is.na(yb$pctlo)
  expect_true(all(yb$compctlo[ok] <= yb$pctlo[ok]))
  expect_true(all(yb$compctup[ok] >= yb$pctup[ok]))
  expect_true(all(yb$envpctlo[ok] <= yb$pctchg[ok]))
  expect_true(all(yb$envpctup[ok] >= yb$pctchg[ok]))
  expect_s3_class(yb, "rmbl_yoy")
  expect_error(yoybnd(otis), "yoy\\(\\)")
})

test_that("exact p-values agree with binom.test and adjust over the scan", {
  y <- yoy(otis, value = "individuals", prd = "year",
           by = c("table", "group"))
  yp <- yoypv(y)
  i <- which(!is.na(yp$previous))[1]
  expect_equal(yp$p_value[i],
               binom.test(yp$value[i], yp$value[i] + yp$previous[i])$p.value)
  s <- scanadj(y, alpha = 0.05)
  ok <- !is.na(s$p_value)
  expect_equal(s$padj[ok], p.adjust(s$p_value[ok], "BH"))
  expect_true(all(s$padj[ok] >= s$p_value[ok]))
  expect_s3_class(s, "rmbl_yoy")
  expect_equal(attr(s, "scanadj")$tests, sum(ok))
  # a plain data frame with p-values is adjusted too; one without is refused
  d <- data.frame(p_value = c(0.01, 0.04, 0.5))
  expect_equal(scanadj(d)$padj, p.adjust(d$p_value, "BH"))
  expect_error(scanadj(data.frame(a = 1)), "p_value")
  # continuous units carry no exact test
  yc <- yoy(otis, value = "individuals", prd = "year",
            by = c("table", "group"), units = "continuous")
  expect_error(yoypv(yc), "count units")
})

test_that("ratechg carries the earlier count and exposure, and adjusts", {
  d <- data.frame(year = rep(2022:2024, each = 2), site = rep(c("A", "B"), 3),
                  n = c(30, 60, 45, 58, 50, 90),
                  pop = c(1000, 2000, 1000, 2100, 1100, 2000))
  rc <- ratechg(d, count = "n", pop = "pop", prd = "year",
                    by = "site")
  expect_true(all(c("precnt", "prepop") %in%
                    names(rc)))
  expect_equal(rc$precnt[rc$site == "A" & rc$year == 2023], 30)
  s <- scanadj(rc)
  i <- which(rc$site == "A" & rc$year == 2023)
  expect_equal(s$p_value[i], binom.test(45, 75, p = 1000 / 2000)$p.value)
  expect_s3_class(s, "rmbl_rate_change")
})

test_that("drftcal reports a false-alarm rate on identical data", {
  set.seed(2)
  d <- data.frame(a = rnorm(300), b = sample(letters[1:3], 300, TRUE),
                  c = rpois(300, 4))
  cal <- drftcal(d, n = 8, alpha = 0.01)
  expect_s3_class(cal, "rmbl_drift_calibration")
  expect_equal(nrow(cal$columns), 3)
  far <- cal$columns$falsealarmrate
  expect_true(all(far >= 0 & far <= 1))
  expect_true(cal$anyflag >= 0 && cal$anyflag <= 1)
  expect_equal(cal$alphafam, 0.01 / 3)
  expect_output(print(cal), "identical re-fetches")
  expect_error(drftcal(d[1:2, ]), "four rows")
})

test_that("anltab runs the whole workflow on the shipped table", {
  a <- anltab(otis, value = "individuals", prd = "year",
                     by = c("table", "group"))
  expect_s3_class(a, "bricklayer_analysis")
  expect_s3_class(a$change, "rmbl_yoy")
  expect_true(all(c("p_value", "padj", "significant") %in%
                    names(a$change)))
  expect_null(a$rates)
  expect_null(a$drift)
  expect_equal(nrow(a$trend), 5)
  expect_true(all(a$trend$periods == 3))
  # three periods: Mann-Kendall p can never be below 1/3
  expect_true(all(a$trend$trndp >= 1 / 3 - 1e-12, na.rm = TRUE))
  expect_equal(a$meta$periods, 2023:2025)
  expect_output(print(a), "5 comparison|comparison")
})

test_that("anltab with bounds, exposure and a prior capsule", {
  d <- otis
  d$pop <- c(rep(25000, 9), rep(21000, 6))
  prior <- d
  prior$individuals <- round(prior$individuals * 0.9)
  a <- anltab(d, value = "individuals", prd = "year",
                     by = c("table", "group"), pop = "pop",
                     prior = prior, rnd = 5, alpha = 0.05)
  expect_true("compctlo" %in% names(a$change))
  expect_s3_class(a$rates, "rmbl_rate")
  expect_s3_class(a$ratechg, "rmbl_rate_change")
  expect_true("padj" %in% names(a$ratechg))
  expect_true(is.data.frame(a$drift$columns))
  expect_true("individuals" %in% a$drift$columns$column)
  expect_output(print(a), "publication bounds")
  expect_output(print(a), "drift vs prior")
  expect_error(anltab(d, value = "nope", prd = "year"), "not found")
})

test_that("rptanl writes Markdown and self-contained HTML", {
  a <- anltab(otis, value = "individuals", prd = "year",
                     by = c("table", "group"), rnd = 5)
  md <- rptanl(a)
  expect_match(md, "^# Analysis of a published table")
  expect_match(md, "## Change between periods")
  expect_match(md, "compctlo")
  expect_match(md, "## Trend over the series")
  f <- tempfile(fileext = ".html")
  rptanl(a, f, title = "OTIS")
  html <- readLines(f, warn = FALSE)
  expect_match(html[1], "<!DOCTYPE html>")
  expect_true(any(grepl("<table>", html)))
  expect_true(any(grepl("<title>OTIS</title>", html)))
  expect_false(any(grepl("http://|https://", html)))
  g <- tempfile(fileext = ".md")
  rptanl(a, g)
  expect_match(readLines(g, warn = FALSE)[1], "^# ")
  expect_error(rptanl(otis), "anltab")
})

test_that("the capsule template runs as written on the shipped example", {
  d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  expect_setequal(list.files(d), c("analysis.R", "data_provenance.json",
                                   "README.md"))
  prov <- loadprov(file.path(d, "data_provenance.json"))
  expect_true(file.exists(prov$source$url))
  expect_error(usecpstmpl(d), "not empty")
  skip_on_cran()
  res <- system2(file.path(R.home("bin"), "Rscript"),
                 c(shQuote(file.path(d, "analysis.R"))),
                 stdout = TRUE, stderr = TRUE)
  expect_true(file.exists(file.path(d, "results", "manifest.json")),
              info = paste(res, collapse = "\n"))
  expect_true(file.exists(file.path(d, "results", "report.html")))
  # the first run pinned the bytes into the provenance, in the form vrfcps() reads
  prov2 <- loadprov(file.path(d, "data_provenance.json"))
  expect_identical(prov2$source$sha256, sha256file(prov$source$url))
  expect_identical(prov2$resource$sha256, prov2$source$sha256)
  expect_true(file.exists(file.path(d, prov2$resource$filename)))
  expect_true(vrfcps(d)$ok)
  # a second run sees the pin and goes through again
  res2 <- system2(file.path(R.home("bin"), "Rscript"), c(shQuote(file.path(d, "analysis.R"))),
                  stdout = TRUE, stderr = TRUE)
  expect_true(any(grepl("results in", res2)), info = paste(res2, collapse = "\n"))
})

test_that("rptanl() renders a percent analysis", {
  d <- data.frame(year = rep(2019:2022, each = 2), g = rep(c("a", "b"), 4), share = c(50, 52, 53, 55, 54, 57, 58, 60))
  a <- anltab(d, value = "share", prd = "year", by = "g", units = "percent")
  txt <- rptanl(a)
  expect_true(is.character(txt))
  expect_match(paste(txt, collapse = "\n"), "ppchg")
})
