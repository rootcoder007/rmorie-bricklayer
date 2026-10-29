otis <- read.csv(system.file(
  "extdata",
  "otis_a01_individuals.csv",
  package = "rmoriebricklayer"
))

test_that("pubbnd turns rounding and suppression into intervals", {
  b <- pubbnd(c(120, 35, 0), rnd = 5)
  expect_equal(b$lower, c(117.5, 32.5, 0))
  expect_equal(b$upper, c(122.5, 37.5, 2.5))
  expect_true(all(b$status == "rounded"))
  # random rounding to base 5 moves a cell by up to 4
  r <- pubbnd(15, rnd = 5, rndkind = "random")
  expect_identical(c(r$lower, r$upper), c(11, 19))
  # suppressed cells: explicit "<k" or a mark with a limit
  s <- pubbnd(c("120", "x", "<5", "1,250"), rnd = 5, suplim = 5)
  expect_identical(
    s$status,
    c("rounded", "suppressed", "suppressed", "rounded")
  )
  expect_identical(s$upper[2:3], c(4, 4))
  expect_identical(s$value[4], 1250)
  expect_true(is.na(s$value[2]))
  expect_error(pubbnd("x"), "limit")
  expect_error(pubbnd("abc"), "cannot read")
  expect_identical(pubbnd(7)$status, "exact")
})

test_that("chgenv is the exact image of the input intervals", {
  now <- pubbnd(c(45, 120), rnd = 5)
  prev <- pubbnd(c(40, 100), rnd = 5)
  e <- chgenv(now, prev)
  expect_identical(e$chglo, c(42.5 - 42.5, 117.5 - 102.5))
  expect_identical(e$chgup, c(47.5 - 37.5, 122.5 - 97.5))
  expect_identical(e$pctlo[1], 100 * (42.5 / 42.5 - 1))
  expect_identical(e$pctup[1], 100 * (47.5 / 37.5 - 1))
  # a previous cell that could be zero has no finite percent bound
  z <- chgenv(pubbnd("<5"), pubbnd("<5"))
  expect_true(is.na(z$pctup))
  # the envelope contains the point estimate
  expect_true(all(e$pctlo <= 100 * (c(45, 120) / c(40, 100) - 1)))
  expect_true(all(e$pctup >= 100 * (c(45, 120) / c(40, 100) - 1)))
})

test_that("yoybnd widens the sampling interval, never narrows it", {
  y <- yoy(otis, value = "individuals", prd = "year", by = c("table", "group"))
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
  y <- yoy(otis, value = "individuals", prd = "year", by = c("table", "group"))
  yp <- yoypv(y)
  i <- which(!is.na(yp$previous))[1]
  expect_identical(
    yp$p_value[i],
    binom.test(yp$value[i], yp$value[i] + yp$previous[i])$p.value
  )
  s <- scanadj(y, alpha = 0.05)
  ok <- !is.na(s$p_value)
  expect_identical(s$padj[ok], p.adjust(s$p_value[ok], "BH"))
  expect_true(all(s$padj[ok] >= s$p_value[ok]))
  expect_s3_class(s, "rmbl_yoy")
  expect_identical(attr(s, "scanadj")$tests, sum(ok))
  # a plain data frame with p-values is adjusted too; one without is refused
  d <- data.frame(p_value = c(0.01, 0.04, 0.5))
  expect_identical(scanadj(d)$padj, p.adjust(d$p_value, "BH"))
  expect_error(scanadj(data.frame(a = 1)), "p_value")
  # continuous units carry no exact test
  yc <- yoy(
    otis,
    value = "individuals",
    prd = "year",
    by = c("table", "group"),
    units = "continuous"
  )
  expect_error(yoypv(yc), "count units")
})

test_that("ratechg carries the earlier count and exposure, and adjusts", {
  d <- data.frame(
    year = rep(2022:2024, each = 2),
    site = rep(c("A", "B"), 3),
    n = c(30, 60, 45, 58, 50, 90),
    pop = c(1000, 2000, 1000, 2100, 1100, 2000),
    stringsAsFactors = FALSE
  )
  rc <- ratechg(d, count = "n", pop = "pop", prd = "year", by = "site")
  expect_true(all(
    c("precnt", "prepop") %in%
      names(rc)
  ))
  expect_identical(rc$precnt[rc$site == "A" & rc$year == 2023], 30)
  s <- scanadj(rc)
  i <- which(rc$site == "A" & rc$year == 2023)
  expect_identical(s$p_value[i], binom.test(45, 75, p = 1000 / 2000)$p.value)
  expect_s3_class(s, "rmbl_rate_change")
})

test_that("drftcal reports a false-alarm rate on identical data", {
  set.seed(2)
  d <- data.frame(
    a = rnorm(300),
    b = sample(letters[1:3], 300, TRUE),
    c = rpois(300, 4)
  )
  cal <- drftcal(d, n = 8, alpha = 0.01)
  expect_s3_class(cal, "rmbl_drift_calibration")
  expect_identical(nrow(cal$columns), 3L)
  far <- cal$columns$falsealarmrate
  expect_true(all(far >= 0 & far <= 1))
  expect_gte(cal$anyflag, 0)
  expect_lte(cal$anyflag, 1)
  expect_identical(cal$alphafam, 0.01 / 3)
  expect_output(print(cal), "Identical re-fetches")
  expect_error(drftcal(d[1:2, ]), "four rows")
})

test_that("anltab runs the whole workflow on the shipped table", {
  a <- anltab(
    otis,
    value = "individuals",
    prd = "year",
    by = c("table", "group")
  )
  expect_s3_class(a, "bricklayer_analysis")
  expect_s3_class(a$change, "rmbl_yoy")
  expect_true(all(
    c("p_value", "padj", "significant") %in%
      names(a$change)
  ))
  expect_null(a$rates)
  expect_null(a$drift)
  expect_identical(nrow(a$trend), 5L)
  expect_true(all(a$trend$periods == 3))
  # three periods: Mann-Kendall p can never be below 1/3
  expect_true(all(a$trend$trndp >= 1 / 3 - 1e-12, na.rm = TRUE))
  expect_identical(a$meta$periods, 2023:2025)
  expect_output(print(a), "5 comparison|comparison")
})

test_that("anltab with bounds, exposure and a prior capsule", {
  d <- otis
  d$pop <- c(rep(25000, 9), rep(21000, 6))
  prior <- d
  prior$individuals <- round(prior$individuals * 0.9)
  a <- anltab(
    d,
    value = "individuals",
    prd = "year",
    by = c("table", "group"),
    pop = "pop",
    prior = prior,
    rnd = 5,
    alpha = 0.05
  )
  expect_true("compctlo" %in% names(a$change))
  expect_s3_class(a$rates, "rmbl_rate")
  expect_s3_class(a$ratechg, "rmbl_rate_change")
  expect_true("padj" %in% names(a$ratechg))
  expect_s3_class(a$drift$columns, "data.frame")
  expect_true("individuals" %in% a$drift$columns$column)
  expect_output(print(a), "Publication bounds")
  expect_output(print(a), "Drift vs prior")
  expect_error(anltab(d, value = "nope", prd = "year"), "not found")
})

test_that("rptanl writes Markdown and self-contained HTML", {
  a <- anltab(
    otis,
    value = "individuals",
    prd = "year",
    by = c("table", "group"),
    rnd = 5
  )
  md <- rptanl(a)
  expect_match(md, "^# Analysis of a published table")
  expect_match(md, "## Change between periods")
  expect_match(md, "compctlo")
  expect_match(md, "## Trend over the series")
  f <- tempfile(fileext = ".html")
  rptanl(a, f, title = "OTIS")
  html <- readLines(f, warn = FALSE)
  expect_match(html[1], "<!DOCTYPE html>")
  expect_true(any(grepl("<table>", html, fixed = TRUE)))
  expect_true(any(grepl("<title>OTIS</title>", html, fixed = TRUE)))
  expect_false(any(grepl("http://|https://", html)))
  g <- tempfile(fileext = ".md")
  rptanl(a, g)
  expect_match(readLines(g, warn = FALSE)[1], "^# ")
  expect_error(rptanl(otis), "anltab")
})

test_that("the capsule template runs as written on the shipped example", {
  d <- usecpstmpl(tempfile("capsule-"), ex = TRUE)
  expect_setequal(
    list.files(d),
    c("analysis.R", "data_provenance.json", "README.md")
  )
  prov <- loadprov(file.path(d, "data_provenance.json"))
  expect_true(file.exists(prov$source$url))
  expect_error(usecpstmpl(d), "not empty")
  skip_on_cran()
  res <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(d, "analysis.R"))),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_true(
    file.exists(file.path(d, "results", "manifest.json")),
    info = paste(res, collapse = "\n")
  )
  expect_true(file.exists(file.path(d, "results", "report.html")))
  # the first run pinned the bytes into the provenance, in the form vrfcps()
  # reads
  prov2 <- loadprov(file.path(d, "data_provenance.json"))
  expect_identical(prov2$source$sha256, sha256file(prov$source$url))
  expect_identical(prov2$resource$sha256, prov2$source$sha256)
  expect_true(file.exists(file.path(d, prov2$resource$filename)))
  expect_true(vrfcps(d)$ok)
  # a second run sees the pin and goes through again
  res2 <- system2(
    file.path(R.home("bin"), "Rscript"),
    c(shQuote(file.path(d, "analysis.R"))),
    stdout = TRUE,
    stderr = TRUE
  )
  expect_true(
    any(grepl("results in", res2, fixed = TRUE)),
    info = paste(res2, collapse = "\n")
  )
})

test_that("rptanl() renders a percent analysis", {
  d <- data.frame(
    year = rep(2019:2022, each = 2),
    g = rep(c("a", "b"), 4),
    share = c(50, 52, 53, 55, 54, 57, 58, 60),
    stringsAsFactors = FALSE
  )
  a <- anltab(d, value = "share", prd = "year", by = "g", units = "percent")
  txt <- rptanl(a)
  expect_type(txt, "character")
  expect_match(paste(txt, collapse = "\n"), "ppchg")
})

test_that("anltab() refuses an infinite or zero rounding base (C7)", {
  d <- data.frame(year = 2019:2021, n = c(10, 12, 15))
  expect_error(
    anltab(d, "n", "year", rnd = Inf),
    "`rnd` must be one positive number, finite, or NULL"
  )
  expect_error(anltab(d, "n", "year", rnd = 0), "`rnd` must be one positive")
  expect_error(
    anltab(d, "n", "year", suplim = Inf),
    "`suplim` must be one non-negative number, finite, or NULL"
  )
})

test_that("anltab() orders text periods as yoy() reads them (C18)", {
  d <- data.frame(
    p = c("2020 Q2", "2020 Q1", "2020 Q4", "2020 Q3"),
    n = 1:4,
    stringsAsFactors = FALSE
  )
  a <- anltab(d, "n", "p")
  expect_identical(a$change$p, c("2020 Q1", "2020 Q2", "2020 Q3", "2020 Q4"))
  expect_identical(a$change$previous, c(NA, 2, 1, 4))
  expect_identical(a$meta$periods, a$change$p)
  # the trend runs Q1 to Q4: 2, 1, 4, 3
  expect_equal(c(a$trend$first, a$trend$last), c(2, 3), tolerance = 0)
})

# ---- boxed printouts ---------------------------------------------------------

# print() of a result in an 80-column ASCII console: the lines, whether the
# value was visible, and the value.
.o2_box <- function(x, ...) {
  withr::local_options(rmoriebricklayer.width = 80, rmoriebricklayer.numcol = 1)
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  out <- utils::capture.output({
    r <- withVisible(print(x, ...))
  })
  list(out = out, vis = r$visible, value = r$value)
}

# The checks every boxed printout passes: an ASCII box under its title, no
# line past the console, print() returning its argument invisibly, format()
# giving character lines that hold the facts.
.o2_check <- function(x, title, facts = character(0)) {
  b <- .o2_box(x)
  testthat::expect_false(b$vis)
  testthat::expect_identical(b$value, x)
  testthat::expect_true(startsWith(b$out[1L], paste0("+-- ", title, " -")))
  testthat::expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  testthat::expect_true(all(nchar(b$out) <= 80L))
  txt <- format(x)
  testthat::expect_type(txt, "character")
  # the text with the box and the wrapping taken out, for phrases
  flat <- gsub("[| ]+", " ", paste(b$out, collapse = " "))
  for (f in facts) {
    testthat::expect_true(grepl(f, flat, fixed = TRUE), info = f)
  }
  invisible(b$out)
}

test_that("anltab() prints as a box of facts", {
  rd <- data.frame(
    g = c("a", "b", "a", "b"),
    yr = c(1, 1, 2, 2),
    n = c(3, 40, 5, 60),
    stringsAsFactors = FALSE
  )
  .o2_check(anltab(rd, "n", "yr", by = "g"), "Analysis of a published table",
    c("Periods", "2 (1 to 2)", "comparison(s)", "Trend"))
})

test_that("rptanl() Markdown tables hold no raw control bytes", {
  d <- data.frame(
    group = c(paste0("A\033[31mR", "\u009b", "2J"),
              paste0("B", "\u202e", "C")),
    pct = c(20, 1.25),
    n = c(12000, 3),
    stringsAsFactors = FALSE
  )
  names(d)[1L] <- "gr\033oup"
  md <- .md_table(d, digits = 1L)
  expect_false(grepl("[\001-\010\013-\037\177]", md, useBytes = TRUE))
  expect_false(grepl(paste0("\u009b", "|", "\u202e"), md))
  # each number on its own: 20 stays 20, not 20.00000
  expect_match(md, "| 20 |", fixed = TRUE)
  expect_match(md, "| 12,000 |", fixed = TRUE)
  expect_identical(.md_num1(c(20, 2023, NA), big = FALSE),
                   c("20", "2023", ""))
})
