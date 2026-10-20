testthat::skip_on_cran()  # battery: runs in CI and locally; CRAN runs the correctness core
# Code bugs the 0.5.13 documentation pass found while reading the code against its docs.

test_that("usecpstmpl escapes the name and source into valid JSON", {
  d <- usecpstmpl(file.path(withr::local_tempdir(), "t"), name = 'say "hi" \\ back')
  prov <- loadprov(file.path(d, "data_provenance.json"))
  expect_identical(prov$name, 'say "hi" \\ back')
  expect_error(usecpstmpl(file.path(withr::local_tempdir(), "u"), name = c("a", "b")),
               "`name` must be a single non-empty string")
})

test_that("rvkfetch returns no URLs, not a crash, for DER with no children", {
  r <- rvkfetch(list(list(der = as.raw(c(0x30, 0x00)))))
  expect_length(r$crls, 0L)
})

test_that("cnormpdf refuses a non-positive sd and vector mean or sd", {
  expect_equal(cnormpdf(c(-1, 0, 2), mean = 0.5, sd = 2), stats::dnorm(c(-1, 0, 2), 0.5, 2))
  expect_error(cnormpdf(0, sd = 0), "`sd` must be a single positive number")
  expect_error(cnormpdf(0, sd = -1), "`sd` must be a single positive number")
  expect_error(cnormpdf(0, mean = c(0, 1)), "`mean` must be a single finite number")
})

test_that("an id_pattern column with year_col has n unnamed ids, and refuses a length mismatch", {
  ctx <- list(year = c(2023, 2023, 2024))
  ids <- mksyncol(list(type = "id_pattern", pattern = "{year}-{seq:05d}", year_col = "year"),
                               n = 3, ctx = ctx)
  expect_identical(ids, c("2023-00001", "2023-00002", "2024-00001"))
  expect_error(mksyncol(list(type = "id_pattern", pattern = "{year}-{seq:05d}", year_col = "year"),
                                     n = 5, ctx = ctx), "has 3 values but n = 5")
})

test_that("sir refuses a confidence level outside (0, 1)", {
  expect_error(stdinc(3, 5, conflvl = 2), "strictly between 0 and 1")
  expect_error(stdinc(3, 5, conflvl = c(0.9, 0.95)), "strictly between 0 and 1")
  expect_equal(stdinc(3, 5)$lower, stats::qgamma(0.025, 3) / 5)
})

test_that("shrs() and rtcalc() keep the names of a named vector as a label column", {
  s <- shrs(c(a = 3, b = 7))
  expect_identical(s$label, c("a", "b"))
  expect_equal(s$share, c(30, 70))
  r <- rtcalc(c(a = 3, b = 7), c(100, 200))
  expect_identical(r$label, c("a", "b"))
  expect_false("label" %in% names(shrs(c(3, 7))))   # unnamed input: no label column
})

## ---- integrity scheme 2 (0.5.13): Merkle domain separation, chain labels, R-version-free payloads ----

# Fixtures made by the OLD code: the Merkle values by the package as built before scheme 2 (C code
# of fde3929), the chain by fde3929's R/chain.R. They stand for artifacts already published.
# the root of the chunks a to e
old_root <- "d71f8983ad4ee170f8129f1ebcdd7440be7798d8e1c80420bf11f1eced610dba"
old_proof3 <- list(sibling = c("18ac3e7343f016890c510e93f935261169d9e3f565436429830faf0934f4f8e4",
                               "e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a",
                               "3f79bb7b435b05321651daefd374cdc681dc06faa65e374e38337b88ca046dea"),
                   side = c("right", "left", "right"))
old_chain <- structure(list(entries = list(
  list(label = "run-1", payload = "f89f2c93435f42ab69280483e49d7244ea4de920c6f6144061c057ab4e176eef",
       prev = "0000000000000000000000000000000000000000000000000000000000000000",
       digest = "5b237af0277ddd8a8aca0ee3d9590e781f027afb0638ebe52708515cbcc3a746"),
  list(label = "run-2", payload = "5f25269b2531f80c29d88e06411c3839983975b3cdfc13e8a294a92863d076a2",
       prev = "5b237af0277ddd8a8aca0ee3d9590e781f027afb0638ebe52708515cbcc3a746",
       digest = "236fa889cf1549f8829aad9ba2504f1cdb0ebfe65ec20f08466f3237028145e1")),
  genesis = "0000000000000000000000000000000000000000000000000000000000000000"),
  class = c("bricklayer_chain", "list"))
old_seal <- "884178a5f03a0f6ba81250cdc30de473a67656039b7f7e4f6cfdf385d62ba385"

test_that("an interior Merkle node no longer verifies as a leaf (scheme 2, RFC 6962 prefixes)", {
  ch <- c("a", "b", "c", "d")
  l <- mrklvs(ch)
  pr <- mrkprf(ch, 1)
  root <- mrkroot(ch)
  node <- c(.rmbl_hex_to_raw(l[1]), .rmbl_hex_to_raw(l[2]))
  forged <- list(sibling = pr$sibling[-1], side = pr$side[-1])
  expect_false(mrkvrf(node, c(forged, scheme = 2L), root))
  expect_false(suppressWarnings(mrkvrf(node, forged, root)))
  expect_false(mrkvrf(node, forged, root, scheme = 2))
  # the scheme-2 construction, by hand
  lf <- function(x) csha256(c(as.raw(0), charToRaw(x)))
  nd <- function(a, b) csha256(c(as.raw(1), .rmbl_hex_to_raw(a), .rmbl_hex_to_raw(b)))
  expect_identical(root, nd(nd(lf("a"), lf("b")), nd(lf("c"), lf("d"))))
  expect_identical(mrkroot(c("a", "b", "c")), nd(nd(lf("a"), lf("b")), lf("c")))
  expect_identical(pr$scheme, 2L)
  for (i in 1:4) expect_true(mrkvrf(ch[i], mrkprf(ch, i), root))
  expect_error(mrkroot(ch, scheme = 3), "`scheme` must be 1 or 2")
})

test_that("roots and proofs made by 0.5.12 still verify, with a warning, and scheme = 2 refuses them", {
  ch <- c("a", "b", "c", "d", "e")
  expect_identical(mrkroot(ch, scheme = 1), old_root)
  expect_identical(mrkprf(ch, 3, scheme = 1)[c("sibling", "side")], old_proof3)
  expect_warning(ok <- mrkvrf("c", old_proof3, old_root), "weaker scheme 1")
  expect_true(ok)
  expect_false(suppressWarnings(mrkvrf("x", old_proof3, old_root)))
  expect_false(mrkvrf("c", old_proof3, old_root, scheme = 2))
  expect_true(mrkvrf("c", old_proof3, old_root, scheme = 1))
  # a scheme-2 proof checked against an old root, or the other way round, fails
  expect_false(mrkvrf("c", mrkprf(ch, 3), old_root))
  expect_false(mrkvrf("c", mrkprf(ch, 3), mrkroot(ch), scheme = 1))
})

test_that("a report records the Merkle scheme of its root", {
  r <- cpsrpt(data.frame(x = 1:5), chunks = c("a", "b"))
  expect_identical(r$digest$merkle_scheme, 2L)
  expect_identical(r$digest$merkle_root, mrkroot(c("a", "b")))
})

test_that("a chain entry's label is covered by its digest (scheme 2)", {
  ch <- chnapp(chnapp(chnnew(), "manifest 1", label = "run-1"), "manifest 2", label = "run-2")
  expect_true(chnvrf(ch)$valid)
  expect_identical(ch$entries[[1]]$scheme, 2L)
  edited <- ch
  edited$entries[[1]]$label <- "run-X"
  expect_false(chnvrf(edited)$valid)
  expect_identical(chnvrf(edited)$broken_at, 1L)
  na <- ch
  na$entries[[2]]$label <- "NA"
  expect_false(chnvrf(na)$valid)   # an NA label is not the text "NA"
  dropped <- ch
  dropped$entries[[1]]$scheme <- NULL    # a scheme-2 link does not recompute under scheme 1
  expect_false(suppressWarnings(chnvrf(dropped))$valid)
  expect_true(is.na(chnseal(edited)))
})

test_that("a chain sealed by 0.5.12 still verifies and seals to the same value, with a warning", {
  expect_warning(chk <- chnvrf(old_chain), "sealed by rmoriebricklayer 0.5.12 or earlier")
  expect_true(chk$valid)
  expect_identical(suppressWarnings(chnseal(old_chain)), old_seal)
  expect_no_warning(format(old_chain))
  # appending to it adds a scheme-2 entry; the old ones keep their rules
  more <- chnapp(old_chain, "manifest 3", label = "run-3")
  expect_identical(more$entries[[3]]$scheme, 2L)
  expect_true(suppressWarnings(chnvrf(more))$valid)
})

test_that("a chain payload does not depend on the R version that serialized it", {
  obj <- list(run = 2, mean = 2.5)
  b <- serialize(obj, NULL, version = 2L, xdr = TRUE)
  other <- b
  other[7:10] <- as.raw(c(0x00, 0x04, 0x05, 0x00))   # as R 4.5.0 would write it
  expect_false(identical(csha256(b), csha256(other)))   # the 0.5.12 payload moved
  zero <- function(x) {
    x[7:10] <- as.raw(0L)
    csha256(x)
  }
  expect_identical(.rmbl_entry_digest(obj), zero(b))
  expect_identical(.rmbl_entry_digest(obj), zero(other))
  expect_identical(.rmbl_entry_digest("text"), csha256("text"))
})

## ---- correctness ----

test_that("every confidence level outside (0, 1) is refused with one message", {
  msg <- "`conflvl` must be a single number strictly between 0 and 1"
  y <- c(10, 12, 15, 11, 18, 20)
  d <- data.frame(year = 2018:2023, n = y, pop = 1000)
  expect_error(trndtst(y, conflvl = 2), msg, fixed = TRUE)
  expect_error(cnttrnd(y, conflvl = 2), msg, fixed = TRUE)
  expect_error(caseflow(c(10, 12, 11), c(9, 12, 10), conflvl = 2), msg, fixed = TRUE)
  expect_error(lifetbl(c(0, 1, 2, 3), c(5, 3, 2), conflvl = 0), msg, fixed = TRUE)
  expect_error(dispmix(matrix(c(5, 3, 2, 4), 2), conflvl = 1), msg, fixed = TRUE)
  expect_error(clrdcmp(c(90, 20, 19, 60), c(100, 50, 20, 140), c("m", "s", "m", "s"),
                                       c("A", "A", "B", "B"), conflvl = -1), msg, fixed = TRUE)
  expect_error(rtcalc(c(3, 7), c(100, 200), conflvl = 2), msg, fixed = TRUE)
  expect_error(rtcalc(d, n, pop, conflvl = 2), msg, fixed = TRUE)
  expect_error(shrs(c(3, 7), conflvl = 2), msg, fixed = TRUE)
  expect_error(ratechg(d, n, pop, year, conflvl = 2), msg, fixed = TRUE)
  expect_error(yoy(d, "n", "year", conflvl = 2), msg, fixed = TRUE)
  expect_error(staysmry(c(1, 2, 3), conflvl = c(0.9, 0.95)), msg, fixed = TRUE)
  expect_error(anltab(d, "n", "year", conflvl = 2), msg, fixed = TRUE)
  toy <- data.frame(s = rep(c("a", "b"), each = 6), p = rep(1:4, each = 3), y = c(3, 5, 4, 6, 8, 7, 2, 1, 3, 9, 8, 10),
                    g = rep(c("x", "y", "z"), 4), w = c(10, 12, 9, 11, 10, 8, 20, 18, 22, 19, 21, 20))
  des <- svydes(toy, w = "w", strata = "s", psu = "p")
  expect_error(svyest(des, toy, "y", conflvl = 2), msg, fixed = TRUE)
  expect_error(svycmp(des, toy, "y", by = "g", conflvl = 2), msg, fixed = TRUE)
  # the internal interval helpers refuse it too, rather than returning NaN
  expect_error(.share_wilson(3, 10, 2), msg, fixed = TRUE)
  expect_error(.rate_ratio_ci(3, 4, 10, 10, 2), msg, fixed = TRUE)
  expect_error(.yoy_ratio_ci(3, 4, 2), msg, fixed = TRUE)
  expect_error(.jx_ratio_ci(3, 4, 2), msg, fixed = TRUE)
  expect_error(.rmbl_sen_ci(1:5, c(1, 3, 2, 5, 4), 10, 2), msg, fixed = TRUE)
  expect_error(.svy_ci(1, 0.1, 10, "mean", "wald", 2), msg, fixed = TRUE)
  expect_false(is.nan(cnttrnd(y)$lower))
})

test_that("mnfrcmp reports a statistic that returns NA, NaN or Inf instead of crashing", {
  m <- suppressMessages(recrd(mkmnf(list(a = 1), env = FALSE), "x", obs = 1, expd = 1))
  r <- mnfrcmp(m, 1, list(x = function(d) NA_real_))
  expect_identical(r$results$status, "DIFFER")
  expect_false(r$ok)
  expect_identical(mnfrcmp(m, 1, list(x = function(d) Inf))$results$status, "DIFFER")
  mi <- suppressMessages(recrd(mkmnf(list(), FALSE), "x", obs = Inf, expd = Inf))
  expect_identical(mnfrcmp(mi, 1, list(x = function(d) Inf))$results$status, "MATCH")
  mn <- suppressMessages(recrd(mkmnf(list(), FALSE), "x", obs = NaN, expd = 1))
  expect_identical(mnfrcmp(mn, 1, list(x = function(d) NaN))$results$status, "MATCH")
  expect_identical(mnfrcmp(mn, 1, list(x = function(d) NA_real_))$results$status, "DIFFER")
})

test_that("recrd() refuses a vector value in words", {
  m <- mkmnf(list(), FALSE)
  expect_error(recrd(m, "v", c(1, 2), c(1, 2)), "`obs` must be a single value, got 2")
  expect_error(recrd(m, "v", 1, numeric(0)), "`expd` must be a single value, got 0")
  expect_error(recrd(m, "v", c("a", "b"), "a"), "`obs` must be a single value")
})

test_that("the stock-and-flow measures refuse a length mismatch or a vector where one number is meant", {
  expect_error(stkflow(days = c(1, 2, 3), people = c(1, 2, 3), t = c(1, 2)),
               "`t` must be length 1 or the same length as `days`")
  expect_error(stkflow(days = c(1, 2), people = c(1, 2), prd = c("a", "b", "c")), "`prd` must have one label")
  expect_error(stkflow(days = c(1, 2), people = c(1, 2), expo = 10, per = c(1, 2)),
               "`per` must be a single number")
  expect_equal(stkflow(days = c(10, 20), people = c(1, 2), t = c(5, 10))$adp, c(2, 2))
  expect_error(adp(c(10, 20), t = c(1, 2)), "`t` must be a single number, got 2 values")
  expect_error(alos(c(10, 20), n = c(1, 2)), "`n` must be a single number, got 2 values")
  expect_error(admits(c(10, 20), 5), "`adp` must be a single number")
  expect_error(admits(10, c(5, 6)), "`alos` must be a single number")
  expect_error(admits(10, 5, t = c(1, 2)), "`t` must be a single number")
  expect_error(adpcnts(1:3, t = c(1, 2)), "`t` must be a single number")
  expect_equal(adp(c(10, 20), t = 30), 1)
})

test_that("profcols() leaves non-finite values out of the numeric statistics", {
  p <- profcols(data.frame(x = c(1, 2, Inf, -Inf, NA)))
  expect_identical(p$ninf, 2L)
  expect_equal(c(p$mean, p$min, p$max, p$median), c(1.5, 1, 2, 1.5))
  expect_true(is.finite(p$q50))
  all_inf <- profcols(data.frame(x = c(Inf, -Inf)))
  expect_true(is.na(all_inf$mean) && is.na(all_inf$max) && is.na(all_inf$q50))
  expect_identical(all_inf$ninf, 2L)
})

test_that("the exponential Hawkes fit does not stop at the worse optimum with the decay on its bound", {
  set.seed(1)
  t <- sort(stats::runif(400, 0, 100))
  f <- chwkfit(t, 100)
  expect_lt(f$nll, -156.4)
  expect_false("beta" %in% f$atbound)
  em <- chwkfit(t, 100, meth = "em")
  expect_equal(f$nll, em$nll, tolerance = 1e-4)
  # the data-driven start alone is the one that stopped on the bound
  one <- chwkfit(t, 100, start = c(log(2.4), 0.4, 4))
  expect_true("beta" %in% one$atbound)
  expect_gt(one$nll, f$nll)
})

test_that("reservoir sampling is the same on every platform, and refuses NA seeds and fractional sizes", {
  # golden values from an independent implementation of mt19937_64 (checked against the C++
  # standard's 10000th output) with Lemire's bounded draw
  expect_identical(rsvidx(100, 5, seed = 42), c(14, 31, 40, 45, 58))
  expect_identical(rsvidx(1000, 5, seed = 1), c(33, 67, 304, 630, 638))
  expect_identical(rsvidx(26, 4, seed = 2), c(13, 18, 19, 26))
  expect_error(rsvidx(10, 3, seed = NA), "`seed` must be a whole number")
  expect_error(rsvidx(10, 3, seed = -1), "`seed` must be a whole number")
  expect_error(rsvidx(10, 3, seed = 1.5), "`seed` must be a whole number")
  expect_error(rsvidx(10.5, 3), "`n` must be a single non-negative whole number")
  expect_error(rsvidx(10, 3.5), "`k` must be a single non-negative whole number")
  expect_error(.Call(C_rmbl_reservoir, 10, 3, NA_real_), "`seed` must be a whole number")
  expect_error(.Call(C_rmbl_reservoir, 10.5, 3, 1), "whole numbers")
})

test_that("cbootmean refuses NA, negative and fractional seeds and a fractional B", {
  expect_error(cbootmean(1:3, B = 10, seed = -1), "`seed` must be a whole number")
  expect_error(cbootmean(1:3, B = 10, seed = NA), "`seed` must be a whole number")
  expect_error(cbootmean(1:3, B = 10, seed = 2.5), "`seed` must be a whole number")
  expect_error(cbootmean(1:3, B = 2.5), "`B` must be a single whole number >= 1")
  expect_error(.Call(C_rmbl_bootstrap_mean, 1:3 + 0, 10, -1), "`seed` must be a whole number")
  expect_error(.Call(C_rmbl_bootstrap_mean, 1:3 + 0, NA_real_, 1), "`B` must be a whole number")
  expect_error(.Call(C_rmbl_uniforms, 3, NA_real_), "`seed` must be a whole number")
  expect_length(cbootmean(1:3, B = 10, seed = 0), 10L)
})

test_that("cnormlpdf, cgamcdf and ctrmmean refuse or answer the edge cases", {
  expect_error(cnormlpdf(0, mean = c(0, 1)), "`mean` must be a single finite number")
  expect_error(cnormlpdf(0, sd = c(1, 2)), "`sd` must be a single positive number")
  expect_error(cnormlpdf(0, sd = 0), "`sd` must be a single positive number")
  expect_equal(cnormlpdf(c(-1, 2), 0.3, 1.7), stats::dnorm(c(-1, 2), 0.3, 1.7, log = TRUE))
  expect_identical(cgamcdf(2, c(0, Inf)), c(0, 1))
  expect_equal(cgamcdf(2, c(-1, 3, Inf)), stats::pgamma(c(-1, 3, Inf), 2))
  expect_error(ctrmmean(1:10, trim = 0.7), "`trim` must be a single number in \\[0, 0.5\\]")
  expect_error(cwinsmean(1:10, trim = -0.1), "`trim` must be a single number")
  expect_error(ctrmmean(1:10, trim = c(0.1, 0.2)), "`trim` must be a single number")
  expect_equal(ctrmmean(c(1:9, 100), 0.1), mean(c(1:9, 100), trim = 0.1))
})

test_that("anltab() warns that rounding and suppression apply only to counts", {
  d <- data.frame(year = 2018:2023, n = c(10, 12, 15, 11, 18, 20))
  expect_warning(anltab(d, "n", "year", units = "continuous", rnd = 5), "apply only to counts")
  expect_warning(anltab(d, "n", "year", units = "percent", suplim = 5), "apply only to counts")
  expect_no_warning(anltab(d, "n", "year", rnd = 5))
})

test_that("provenance errors name loadprov(), which exists", {
  expect_error(citecps("not a list"), "loadprov()", fixed = TRUE)
  expect_false(exists("read_provenance", envir = asNamespace("rmoriebricklayer")))
})

test_that("capdeps gives NA, not \"\", as the library of a package that is not installed", {
  d <- capdeps(c("stats", "notapkgxyz123"))
  expect_true(is.na(d$library[d$package == "notapkgxyz123"]))
  # the library is the directory the package is in, not its parent
  expect_identical(d$library[d$package == "stats"], dirname(system.file(package = "stats")))
})

test_that("the hot-spot tie note names each period with its own count", {
  x <- c(rep(0.5, 5), 1.5, 2.5,  0.5, 1.5, 2.5,  rep(0.5, 4), 1.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5)
  p <- c(rep("A", 7), rep("B", 3), rep("C", length(x) - 10))
  h <- hotpers(x, rep(0.5, length(x)), p, cell = 1, top = 0.1, xy = "planar")
  expect_output(print(h), "period B: 3 cells tied", fixed = TRUE)
})

test_that("instcli() refuses an empty or malformed name", {
  d <- withr::local_tempdir()
  for (bad in list(character(), NA_character_, "", "a/b", 1)) {
    expect_error(instcli(dir = d, name = bad), "`name` must be one or more command names")
  }
  expect_length(list.files(d), 0L)
})

test_that("yoymd() right-aligns every numeric column", {
  md <- yoymd(yoy(data.frame(year = 2019:2021, n = c(4, 5, 6)), "n", "year"), NULL)
  rule <- strsplit(md, "\n", fixed = TRUE)[[1L]][2L]
  cells <- trimws(strsplit(rule, "|", fixed = TRUE)[[1L]][-1L])
  # year | n | previous | change | change % | interval | note
  expect_identical(endsWith(cells, ":"), c(FALSE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
})

test_that("with direction = \"neutral\" a rise or a fall is drawn in the neutral colour", {
  expect_identical(.yoy_verdict_class(c("up", "down", "worse", "better", "flat", NA)),
                   c("flat", "flat", "bad", "good", "flat", "flat"))
  y <- yoy(data.frame(year = 2019:2021, n = c(4, 8, 2)), "n", "year")
  rd <- function(z) {
    f <- tempfile(fileext = ".html")
    yoyhtml(z, f)
    paste(readLines(f, warn = FALSE), collapse = "\n")
  }
  html <- rd(y)
  expect_false(grepl("<tr class=\"(bad|good)\"", html))
  y2 <- yoy(data.frame(year = 2019:2021, n = c(4, 8, 2)), "n", "year", dir = "lower")
  expect_true(grepl("<tr class=\"bad\"", rd(y2), fixed = TRUE))
  pal <- .yoy_pal("diverging")
  out <- capture.output(print(y, color = TRUE))
  expect_false(any(grepl(.yoy_ansi(pal$bad), out, fixed = TRUE)))
  expect_false(any(grepl(.yoy_ansi(pal$good), out, fixed = TRUE)))
})

test_that("a malformed certificate is an error without the call", {
  e <- tryCatch(certprs(as.raw(c(0x30, 0x03, 1, 2))), error = function(e) e)
  expect_null(conditionCall(e))
  e2 <- tryCatch(.Call(C_rmbl_rsa_recover, raw(0), raw(0), raw(0)), error = function(e) e)
  expect_null(conditionCall(e2))
})

test_that("the LLM wait label is drawn where the console says, so RStudio gets it on stdout", {
  skip_on_cran()
  withr::local_options(morie.quiet = NULL, morie.progress = TRUE)
  withr::defer(.Call(C_rmbl_wait_label, "", FALSE, FALSE))
  # the RStudio console, as .bl_console() describes it: redraws, colours, frames on stdout
  local_mocked_bindings(.bl_console = function(tty = NULL) {
    list(dynamic = TRUE, colors = 1L, unicode = FALSE, out = "stdout", width = 80L)
  }, .bl_post_json = function(...) {
    Sys.sleep(0.8)
    invisible(.Call(C_rmbl_check_interrupt))   # a poll: draws the spinner frame
    list(status = 200L, json = list(choices = list(list(message = list(content = "fine"), finish_reason = "stop"))))
  })
  rt <- list(name = "own endpoint", api = "openai", base = "http://localhost:1/v1", model = "m", local = TRUE)
  err <- capture.output(type = "message", out <- capture.output(
    res <- .bl_llm_chat(rt, "m", list(list(role = "user", content = "hi")))))
  expect_identical(res$text, "fine")
  expect_match(paste(out, collapse = ""), "m is thinking", fixed = TRUE)
  expect_false(any(grepl("m is thinking", err, fixed = TRUE)))
})
