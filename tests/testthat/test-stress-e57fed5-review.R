# Review of e57fed5 (2026-10-13): every finding, with the reviewer's reproducer as the first check
# of each block, then its siblings. Values are checked against independent computations (the survey
# package, SRS Wilson, a brute-force count, zeta'(-2)) rather than this package's own output.

ns <- function(f) get(f, envir = asNamespace("rmoriebricklayer"))
ext <- function(f) utils::read.csv(system.file("extdata", f, package = "rmoriebricklayer"), stringsAsFactors = FALSE)

# ---- E1, E13: the C progress renderer -------------------------------------------------------

test_that("E1: the spinner frame stays in its table for any time, nanoseconds included", {
  sp <- function(t, u = TRUE) .Call(ns("C_rmbl_progress_spinner"), t, u)
  braille <- vapply(0:9, function(k) sp(k / 10), "")
  expect_length(unique(braille), 10L)
  for (t in c(9.3e17, 1.76e18, 1e300, .Machine$double.xmax, -5, Inf, NaN, 0)) {
    expect_true(sp(t) %in% braille, info = format(t))
    expect_true(sp(t, FALSE) %in% c("|", "/", "-", "\\"), info = format(t))
  }
  # the frame follows tenths of a second, ten braille frames, four ASCII ones
  expect_identical(sp(1.25), braille[3])
  expect_identical(sp(0.35, FALSE), "\\")
  expect_identical(sp(0.15, FALSE), "/")
})

test_that("E13: a bar wider than an int is drawn at the widest bar, not with an undefined cast", {
  fr <- function(w) .Call(ns("C_rmbl_progress_frame"), 0.5, 1, w, FALSE, FALSE, TRUE, c(10, 20, 30))
  expect_identical(nchar(fr(3e9)), 200L)
  expect_identical(nchar(fr(200)), 200L)
  expect_identical(nchar(fr(1)), 1L)
  expect_error(fr(0), "at least 1")
  expect_error(fr(NA_real_), "at least 1")
})

# ---- E8: the gzip reader --------------------------------------------------------------------

gz <- function(x) memCompress(x, "gzip")   # zlib format, not gzip: only for the "not gzip" case
gzip_bytes <- function(raw_text) {
  f <- tempfile(fileext = ".gz")
  con <- gzfile(f, "wb")
  writeBin(raw_text, con)
  close(con)
  readBin(f, "raw", file.size(f))
}

test_that("E8: many members and bombs are refused holding little memory; output may reach the limit", {
  g <- function(x, lim = 2^30) .Call(ns("C_rmbl_gunzip_checked"), x, lim)
  empty <- gzip_bytes(raw(0))
  one <- gzip_bytes(charToRaw("x"))
  expect_identical(length(g(rep(empty, 5000))), 0L)
  expect_identical(rawToChar(g(rep(one, 1000))), strrep("x", 1000))
  expect_error(g(rep(empty, 100001)), "more than 100000 gzip members")
  # 64 MiB of zeros in a few kilobytes: refused at a 1 MiB limit at once
  z <- gzip_bytes(raw(2^26))
  expect_lt(length(z), 2^17)
  expect_error(g(z, 2^20), "more than the size limit")
  # the limit is the most that is taken: exactly the limit passes, one byte less refuses
  expect_identical(length(g(z, 2^26)), as.integer(2^26))
  expect_error(g(z, 2^26 - 1), "more than the size limit")
})

test_that("E8: each kind of damage is named for what it is", {
  g <- function(x) .Call(ns("C_rmbl_gunzip_checked"), x, 2^30)
  good <- gzip_bytes(charToRaw(strrep("abc,def\n", 500)))
  n <- length(good)
  crc <- good
  crc[n - 7L] <- as.raw(bitwXor(as.integer(crc[n - 7L]), 1L))
  expect_error(g(crc), "CRC-32")
  isize <- good
  isize[n - 3L] <- as.raw(bitwXor(as.integer(isize[n - 3L]), 1L))
  expect_error(g(isize), "length trailer")
  expect_error(g(good[seq_len(n - 3L)]), "truncated")
  expect_error(g(c(good, charToRaw("xyz"))), "bytes after the end")
  expect_identical(rawToChar(g(c(good, raw(8)))), strrep("abc,def\n", 500))
  expect_error(g(gz(charToRaw("zlib, not gzip"))), "no gzip magic number")
  expect_error(g(charToRaw("plain text")), "no gzip magic number")
  hdr <- good
  hdr[3L] <- as.raw(7L)   # an unknown compression method in the header
  expect_error(g(hdr), "damaged gzip header|not valid gzip data")
})

# ---- E9, E2 and the other survey findings ----------------------------------------------------

svy_data <- function() {
  set.seed(3)
  n <- 60
  d <- data.frame(id = 1:n, y = rnorm(n), w = runif(n, 1, 3), g = rep(c("a", "b"), 30))
  reps <- sapply(1:20, function(r) d$w * tabulate(sample(n, replace = TRUE), n))
  list(d = d, reps = reps, rdf = data.frame(id = d$id, w = d$w, reps))
}

test_that("E9: the full weight, the id or a data column is never taken as a replicate", {
  s <- svy_data()
  d <- s$d
  ok <- survey_design(d, weights = "w", replicates = s$reps)
  se <- survey_estimate(ok, d, "y")$se
  # the replicate file with its id and full weight beside the replicates: by name both are dropped
  with_id <- survey_design(d, weights = "w", replicates = s$rdf, id = "id")
  expect_equal(survey_estimate(with_id, d, "y")$se, se, tolerance = 1e-14)
  # the weight given as a vector cannot be recognised by name: it is refused by value for a jackknife
  # (a bootstrap replicate that draws every PSU once is the full weight, legitimately: accepted)
  expect_error(survey_design(d, weights = d$w, replicates = s$rdf, id = "id", type = "jk1"), "the full-sample weight")
  # for a bootstrap it is kept, and said when more replicates equal the weight than chance draws
  # (statistics stress test of 5e1dce5)
  expect_warning(des_w <- survey_design(d, weights = d$w, replicates = cbind(w = d$w, s$reps)),
                 "equal the full-sample weight")
  expect_s3_class(des_w, "rmbl_svy_design")
  # no id: the id column is the row number
  expect_error(survey_design(d, weights = "w", replicates = s$rdf[, -2]), "the row number")
  expect_error(survey_design(d, weights = "w", replicates = c("w")), "not a replicate weight")
  expect_error(survey_design(d, weights = "w", replicates = data.frame(a = s$reps[, 1], b = letters[1:2])),
               "not numbers")
  # BRR replicates come in Hadamard orders: a stray column makes 13
  expect_error(survey_design(d, weights = "w", replicates = s$reps[, 1:13], type = "brr"), "Hadamard")
  # a matrix with a class of its own is read as the matrix it is
  m <- structure(s$reps, class = c("repweights", "matrix"))
  expect_equal(survey_estimate(survey_design(d, weights = "w", replicates = m), d, "y")$se, se, tolerance = 1e-14)
  # F1: the replicates taken out of the analysis file itself, by name or as its columns
  dd <- cbind(d, stats::setNames(as.data.frame(s$reps), paste0("bw", 1:20)))
  by_name <- survey_design(dd, weights = "w", replicates = paste0("bw", 1:20))
  by_cols <- survey_design(dd, weights = "w", replicates = dd[paste0("bw", 1:20)])
  expect_equal(survey_estimate(by_cols, dd, "y")$se, survey_estimate(by_name, dd, "y")$se, tolerance = 1e-14)
  # but a stray column of the file beside them is still refused
  expect_error(survey_design(dd, weights = "w", replicates = dd[c(paste0("bw", 1:20), "id")]), "the row number")
  # the replicates are exactly the columns given: a column of `data` passed under its own name is a
  # replicate because it was asked for (the explicit contract; review of 46de6a9, H1/H5), one passed
  # under another name is refused, and nothing is guessed from values
  dd$meals <- runif(nrow(dd), 0, 100)
  # (a column on another scale than the weight is said: statistics stress test of 5e1dce5)
  expect_warning(des_m <- survey_design(dd, weights = "w", replicates = dd[c(paste0("bw", 1:20), "meals")]),
                 "replicate meals is .* times the full-sample weight on a typical row")
  expect_s3_class(des_m, "rmbl_svy_design")
  expect_error(survey_design(dd, weights = "w", replicates = cbind(dd[paste0("bw", 1:20)], zz = dd$meals)),
               "column meals of `data`")
  # an unnamed matrix of the same columns is a replicate set
  expect_equal(survey_estimate(survey_design(dd, weights = "w", replicates = unname(as.matrix(dd[paste0("bw", 1:20)]))),
                               dd, "y")$se, survey_estimate(by_name, dd, "y")$se, tolerance = 1e-14)
  # the exact refusals: the row number, the id, the full weight for a jackknife (a bootstrap replicate
  # that draws every PSU once is the weight, legitimately); nothing else is guessed
  expect_error(survey_design(d, weights = "w", replicates = cbind(s$reps, seq_len(nrow(d)))), "the row number")
  expect_error(survey_design(d, weights = "w", replicates = cbind(s$reps, d$w), type = "jk1"), "the full-sample weight")
  expect_warning(survey_design(d, weights = "w", replicates = cbind(s$reps, d$w)), "equal the full-sample weight")
  expect_warning(survey_design(d, weights = "w", replicates = cbind(s$reps, d$w * (1 + 1e-15)), type = "bootstrap"),
                 "equal the full-sample weight")
  # genuine sets with a dominant PSU, a jackknife replicate constant on a subset, rounded in a file
  w3 <- rep(c(900, 50, 50), each = 20)
  jk <- sapply(1:3, function(k) w3 * ifelse(rep(1:3, each = 20) == k, 0, 3 / 2))
  expect_s3_class(survey_design(data.frame(y = d$y, w = w3), weights = "w", replicates = jk, type = "jk1"),
                  "rmbl_svy_design")
  sub <- cbind(d$w * 25 / 24, d$w * 25 / 24, d$w * c(rep(0, 30), rep(25 / 24, 30)))
  expect_s3_class(survey_design(d, weights = "w", replicates = sub, type = "jk1"), "rmbl_svy_design")
  expect_s3_class(survey_design(d, weights = "w", replicates = round(s$reps, 4)), "rmbl_svy_design")
  # a second column with the id's name and other values is refused, as one with the weight's name is
  # (it was kept as a replicate; NEWS said refused; statistics stress test of 5e1dce5)
  r_id <- s$rdf
  names(r_id)[3] <- "id"
  expect_error(survey_design(d, weights = "w", replicates = r_id, id = "id"), "has the id's name but not its values")
  # F2: a genuine replicate under the weight's name is refused, not dropped; the weight itself is set aside
  r2 <- as.data.frame(s$reps)
  names(r2)[1] <- "w"
  expect_error(survey_design(d, weights = "w", replicates = r2), "has the full weight's name but not its values")
  r3 <- cbind(w = d$w, as.data.frame(s$reps))
  expect_equal(survey_estimate(survey_design(d, weights = "w", replicates = r3), d, "y")$se, se, tolerance = 1e-14)
})

test_that("E2: Wilson at 0% and 100% is SRS Wilson at the respondents, not a point", {
  d <- data.frame(y = factor(rep(c("b", "a", "b"), c(40, 20, 20))), g = rep(c("s1", "s2"), each = 40), w = 1)
  e <- as.data.frame(survey_estimate(survey_design(d, weights = "w"), d, "y", by = "g", stat = "proportion"))
  ref <- stats::prop.test(40, 40, correct = FALSE)$conf.int
  full <- e[e$g == "s1" & e$level == "b", ]
  expect_equal(full$lower, ref[1], tolerance = 1e-12)
  expect_identical(full$upper, 1)
  none <- e[e$g == "s1" & e$level == "a", ]
  expect_identical(none$lower, 0)
  expect_equal(none$upper, 1 - ref[1], tolerance = 1e-12)
  # the logit interval does not exist at the ends either and takes the same
  l <- as.data.frame(survey_estimate(survey_design(d, weights = "w"), d, "y", by = "g", stat = "proportion",
                                     ci = "logit"))
  expect_equal(l$lower[l$g == "s1" & l$level == "b"], ref[1], tolerance = 1e-12)
})

test_that("the Wilson degrees-of-freedom factor is (t_(n-1) / t_df)^2, as SAS documents", {
  set.seed(9)
  d <- data.frame(y = rbinom(40, 1, 0.3), s = rep(1:4, each = 10), p = rep(1:8, each = 5), w = runif(40, 1, 2))
  des <- survey_design(d, weights = "w", strata = "s", psu = "p")
  e <- survey_estimate(des, d, "y", stat = "proportion", levels = "1", df = "design")
  p <- e$estimate
  n <- e$n
  deff <- e$se^2 / (p * (1 - p) / (n - 1))
  ne <- min(n / deff * (stats::qt(0.975, n - 1) / stats::qt(0.975, 8 - 4))^2, n)
  z <- stats::qnorm(0.975)
  mid <- (p + z^2 / (2 * ne)) / (1 + z^2 / ne)
  half <- z / (1 + z^2 / ne) * sqrt(p * (1 - p) / ne + z^2 / (4 * ne^2))
  expect_equal(c(e$lower, e$upper), c(mid - half, mid + half), tolerance = 1e-12)
})

test_that("JKn and the replicate design's degrees of freedom agree with the survey package", {
  skip_if_not_installed("survey")
  data(api, package = "survey", envir = environment())
  ds <- survey::svydesign(id = ~dnum, strata = ~stype, weights = ~pw, data = apiclus2, nest = TRUE)
  jk <- survey::as.svrepdesign(ds, type = "JKn")
  ours <- survey_design(apiclus2, weights = "pw", replicates = stats::weights(jk, "analysis"), type = "jkn",
                        rscales = jk$rscales, mse = jk$mse)
  expect_equal(survey_estimate(ours, apiclus2, "api00")$se, unname(survey::SE(survey::svymean(~api00, jk))),
               tolerance = 1e-10)
  expect_identical(as.numeric(ns(".svy_df")(ours)), as.numeric(survey::degf(jk)))
  expect_error(survey_design(apiclus2, weights = "pw", replicates = stats::weights(jk, "analysis"), type = "jkn"),
               "needs `rscales`")
  # BRR needs two PSUs a stratum: the survey package's own scd data (three strata of two)
  data(scd, package = "survey", envir = environment())
  sd <- survey::svydesign(data = scd, prob = ~1, id = ~ambulance, strata = ~ESA, nest = TRUE)
  br <- survey::as.svrepdesign(sd, type = "BRR")
  ob <- survey_design(scd, weights = rep(1, nrow(scd)), replicates = stats::weights(br, "analysis"), type = "brr")
  expect_identical(as.numeric(ns(".svy_df")(ob)), as.numeric(survey::degf(br)))
  expect_equal(survey_estimate(ob, scd, "alive")$se, unname(survey::SE(survey::svymean(~alive, br))), tolerance = 1e-12)
  expect_identical(ns(".svy_df")(survey_design(scd, weights = rep(1, nrow(scd)),
                                              replicates = stats::weights(br, "analysis"), type = "brr", degf = 2)), 2)
  expect_error(survey_design(apiclus2, weights = "pw", strata = "stype", degf = 0), "at least 1")
})

test_that("the data must be the design's rows in the design's order", {
  s <- svy_data()
  des <- survey_design(s$d, weights = "w", replicates = s$reps)
  expect_error(survey_estimate(des, s$d[sample(nrow(s$d)), ], "y"), "not the data frame the design was built on")
  # the same rows reordered with their row names reset: caught by the values, not the names
  shuffled <- s$d[sample(nrow(s$d)), ]
  rownames(shuffled) <- NULL
  expect_error(survey_estimate(des, shuffled, "y"), "not the data frame")
  # a tibble (row names always 1..n) with a vector weight: nothing named to compare, so the columns'
  # values are (review of 46de6a9); a column changed afterwards is not a reorder
  tb <- structure(s$d, class = c("tbl_df", "tbl", "data.frame"))
  dv <- survey_design(tb, weights = tb$w, replicates = s$reps)
  se0 <- survey_estimate(dv, tb, "y")$se
  tb2 <- tb[sample(nrow(tb)), ]
  # a real tibble's row names are 1..n after any reorder: without this the shuffled names caught it
  # and the test passed on builds that never compared the values (statistics stress test of 5e1dce5)
  attr(tb2, "row.names") <- seq_len(nrow(tb2))
  expect_identical(attr(tb2, "row.names"), attr(tb, "row.names"))
  expect_error(survey_estimate(dv, tb2, "y"), "not the data frame")
  tb3 <- tb
  tb3$y <- tb3$y * 2
  expect_equal(survey_estimate(dv, tb3, "y")$se, 2 * se0, tolerance = 1e-12)
  dl <- survey_design(tb, weights = tb$w, strata = tb$g)
  expect_error(survey_estimate(dl, tb2, "y"), "not the data frame")
  d2 <- s$d
  d2$w <- rev(d2$w)
  expect_error(survey_estimate(des, d2, "y"), "not the data frame")
  expect_error(survey_estimate(des, s$d[-1, ], "y"), "must be the data frame")
})

test_that("a variance with nothing to estimate it from is flagged, not reported as zero", {
  # one PSU in all: nothing to estimate a variance from, whatever is done with a lonely PSU
  d <- data.frame(y = c(1, 2, 3, 4), s = 1, p = 1, w = 1)
  for (lp in c("remove", "adjust")) {
    e <- survey_estimate(survey_design(d, weights = "w", strata = "s", psu = "p", lonely_psu = lp), d, "y")
    expect_true(is.na(e$se), info = lp)
    expect_match(e$flag, "no stratum has two PSUs", info = lp)
  }
  # a census (every PSU in every stratum sampled) has no sampling variance: zero is right
  cen <- survey_design(d, weights = "w", strata = "s", psu = "p", fpc = c(1, 1, 1, 1))
  expect_identical(survey_estimate(cen, d, "y")$se, 0)
  # two strata of one PSU each, adjusted: centred on the mean PSU total, a variance there is
  d2 <- data.frame(y = c(1, 2, 3, 4), s = c(1, 1, 2, 2), p = c(1, 1, 2, 2), w = 1)
  expect_gt(survey_estimate(survey_design(d2, weights = "w", strata = "s", psu = "p", lonely_psu = "adjust"), d2,
                            "y")$se, 0)
  # a certainty stratum with one PSU is not a lonely PSU
  d3 <- data.frame(y = c(1, 2, 3, 4, 5), s = c(1, 2, 2, 2, 2), p = c(1, 2, 2, 3, 3), w = 1,
                   f = c(1, 0.5, 0.5, 0.5, 0.5))
  expect_silent(survey_estimate(survey_design(d3, weights = "w", strata = "s", psu = "p", fpc = "f"), d3, "y"))
  # all-zero weights in a domain are said as such
  s <- svy_data()
  dz <- s$d
  dz$w[dz$g == "b"] <- 0
  rz <- s$reps
  rz[dz$g == "b", ] <- 0
  ez <- survey_estimate(survey_design(dz, weights = "w", replicates = rz), dz, "y", by = "g")
  expect_match(ez$flag[ez$g == "b"], "weights are all zero")
})

test_that("survey arguments are refused in words", {
  s <- svy_data()
  des <- survey_design(s$d, weights = "w", replicates = s$reps)
  expect_identical(nrow(survey_estimate(des, s$d, "y", by = character(0))), 1L)
  expect_error(survey_estimate(des, s$d, "y", conf_level = NA), "between 0 and 1")
  expect_error(survey_compare(des, s$d, "y", by = "g", ref = c("a", "b")), "one domain label")
  expect_error(survey_estimate(des, s$d, "y", by = 1), "name columns")
})

# ---- E3 and the location siblings ----------------------------------------------------------

test_that("E3: knox_test drops (0, 0) as crime_density and hotspot_persistence do", {
  b <- ext("tps_break_enter_d14_2024.csv")
  t <- as.Date(b$occ_date)
  k0 <- knox_test(b$lon, b$lat, t, 100, 7, nsim = 99, seed = 1)
  b2 <- b
  b2$lon[1:20] <- 0
  b2$lat[1:20] <- 0
  expect_message(k1 <- knox_test(b2$lon, b2$lat, t, 100, 7, nsim = 99, seed = 1), "20 incidents at \\(0, 0\\)")
  k2 <- knox_test(b$lon[-(1:20)], b$lat[-(1:20)], t[-(1:20)], 100, 7, nsim = 99, seed = 1)
  expect_identical(k1$table, k2$table)
  expect_lt(k1$table$observed[1], k0$table$observed[1] + 1)
  # a brute-force count of the close pairs agrees
  p <- ns(".jx_project")(b$lon, b$lat, stats::median(b$lon), stats::median(b$lat))
  dd <- as.matrix(stats::dist(cbind(p$x, p$y))) * 1000
  dt <- abs(outer(as.numeric(t), as.numeric(t), "-"))
  expect_identical(k0$table$observed[1], sum((dd <= 100 & dt <= 7)[upper.tri(dd)]))
})

test_that("points across the antimeridian are one place; distances past a continent are said", {
  set.seed(4)
  lon <- c(runif(30, 179.9, 180), runif(30, -180, -179.9))
  lat <- runif(60, -17.1, -17)
  kd <- crime_density(lon, lat, n_grid = 40)
  expect_lt(max(kd$bandwidth), 5)
  # one piece, in order, a degree either side of the antimeridian (nodes past 180 keep their
  # continued values so image() can draw them; review of 29a55d8, F4)
  expect_false(is.unsorted(kd$lon))
  expect_true(all(abs(abs(kd$lon) - 180) < 1))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_s3_class(plot(kd), "data.frame")
  # F4: incidents near the antimeridian without crossing it, whose grid runs past 180
  set.seed(3)
  near <- crime_density(runif(60, 179.5, 179.99), runif(60, -17.2, -16.8), n_grid = 40)
  expect_false(is.unsorted(near$lon))
  expect_s3_class(plot(near), "data.frame")
  # every incident lies on its map: the points are in the grid's own frame (review of 46de6a9)
  for (kd_ in list(kd, near)) {
    expect_true(all(kd_$points$lon >= min(kd_$lon) & kd_$points$lon <= max(kd_$lon)))
    expect_true(all(kd_$points$lat >= min(kd_$lat) & kd_$points$lat <= max(kd_$lat)))
  }
  h <- hotspot_persistence(lon, lat, rep(1:2, 30), cell = 1)
  expect_true(all(abs(h$cells$x) > 179))
  k <- knox_test(lon, lat, 1:60, 1000, 3, nsim = 19, seed = 1)
  expect_gt(k$table$expected[1], 0)
  expect_warning(crime_density(c(-79, -60, 2, 30), c(43, 45, 48, 50)), "accurate for a city or a region")
  expect_error(crime_density(lon, lat, bandwidth = 1e6), "half the earth")
  expect_warning(crime_density(lon, lat, bandwidth = 500, n_grid = 40), "one blur")
})

test_that("knox_test max_pairs is a number of at least one", {
  b <- ext("tps_break_enter_d14_2024.csv")[1:50, ]
  t <- as.Date(b$occ_date)
  expect_error(knox_test(b$lon, b$lat, t, 100, 7, nsim = 19, max_pairs = NA), "max_pairs")
  expect_error(knox_test(b$lon, b$lat, t, 100, 7, nsim = 19, max_pairs = "abc"), "numeric")
  expect_error(knox_test(b$lon, b$lat, t, 100, 7, nsim = 19, max_pairs = 0), "at least 1")
  expect_s3_class(knox_test(b$lon, b$lat, t, 100, 7, nsim = 19, max_pairs = "1e6"), "rmbl_knox")
})

test_that("hot spots made by ties are counted and said", {
  set.seed(2)
  x <- runif(200, 0, 10)
  y <- runif(200, 0, 10)
  h <- hotspot_persistence(x, y, rep(1:2, 100), cell = 0.1, coords = "planar")
  # every cell holds one incident: a tie that would make all of them hot is left out, and the
  # counts say so (100 of 100 were "hot"; reviews of e57fed5 and 46de6a9)
  expect_true(all(h$periods$tied_out > 0))
  expect_true(all(h$periods$hot_cells <= 2 * h$hot_k))   # only cells that stand out above the tie
  expect_true(all(h$periods$tied_in == 0L))
  out <- capture.output(print(h))
  expect_true(any(grepl("too even", out, fixed = TRUE)))
  h2 <- hotspot_persistence(c(rep(1, 50), x[1:10]), c(rep(1, 50), y[1:10]), rep(1:2, 30), cell = 1, coords = "planar")
  expect_false(any(grepl("too even", capture.output(print(h2)), fixed = TRUE)))
})

# ---- E4: one rate band for every pollution entry point ---------------------------------------

test_that("E4: pollution_burden, by_area and mortality_displaced keep verify_pollution's rate band", {
  expect_error(pollution_burden(25, 1, 0.5, 1e6, "PM2.5"), "high_rate = TRUE")
  expect_error(pollution_burden(25, 1, 8e-8, 1e6, "PM2.5"), "rare_outcome = TRUE")
  expect_error(pollution_burden(25, 1, 1e-300, 1e6, "PM2.5"), "100 billion")
  expect_error(pollution_burden(25, 1, 800, 1e6, "PM2.5"), "per 100,000")
  expect_error(pollution_burden(25, 1, 0.008, 1e6, "PM2.5", rare_outcome = NA), "TRUE or FALSE")
  common <- pollution_burden(25, 1, 0.5, 1e6, "PM2.5", high_rate = TRUE)
  expect_equal(common$baseline_cases, 5e5)
  rare <- pollution_burden(25, 1, 8e-8, 1e6, "PM2.5", rare_outcome = TRUE)
  expect_equal(rare$baseline_cases, 0.08)
  expect_identical(pollution_burden(25, 1, 0, 1e6, "PM2.5")$attributable_cases, 0)
  expect_error(mortality_displaced(10, 1e6, 0.5, 0.01), "high_rate")
  expect_error(mortality_displaced(10, 1e6, 8e-8, 0.01), "rare_outcome")
  expect_equal(mortality_displaced(10, 1e6, 0.5, 0.01, high_rate = TRUE), 0.5 * 1e6 * (1 - exp(-0.1)))
  t <- data.frame(fsa = c("A", "B"), exposure = c(28, 18), population = c(4e4, 6e4), baseline_rate = c(0.008, 0.5))
  expect_error(pollution_burden_by_area(t), "high_rate")
  expect_identical(nrow(pollution_burden_by_area(t, high_rate = TRUE)), 2L)
  # verify_pollution draws the same line on its rate per 100,000
  args <- list("no2", exposure_mean = 25, exposure_prevalence = 1)
  hi <- do.call(verify_pollution, c(args, baseline_rate = 5e4))
  expect_identical(hi$status, "assumption_failure")
  expect_true(any(grepl("high_rate = TRUE", vapply(hi$assumptions, `[[`, "", "note"), fixed = TRUE)))
  expect_identical(do.call(verify_pollution, c(args, baseline_rate = 5e4, high_rate = TRUE))$status, "ok")
  expect_identical(do.call(verify_pollution, c(args, high_rate = "yes"))$status, "error")
  expect_error(pollution_report_text(list(status = "ok", inputs = 1)), "not a complete verify_pollution")
})

# ---- E5: the bundled data ------------------------------------------------------------------

test_that("E5: one row per occurrence, every one located, as the Service publishes them", {
  b <- ext("tps_break_enter_d14_2024.csv")
  expect_identical(nrow(b), 508L)
  expect_false(anyDuplicated(b$event_id) > 0)
  expect_false(any(apply(is.na(b), 1, all)))
  expect_true(all(is.finite(b$lon) & is.finite(b$lat)))
  expect_true(all(substr(b$occ_date, 1, 4) == "2024"))
  expect_identical(sum(b$offence_records), 513L)
  expect_identical(sum(b$offence_records == 2L), 5L)
  courts <- ext("ocj_courts.csv")
  expect_false(2026 %in% courts$year)
  expect_true(nzchar(system.file("COPYRIGHTS", package = "rmoriebricklayer")))
})

# ---- E10: the manifest ---------------------------------------------------------------------

test_that("E10: an empty dataset list does not replace a manifest that lists tables", {
  d <- withr::local_tempdir()
  local_mocked_bindings(.bl_data_cache_dir = function() d)
  good <- sprintf('{"datasets": [{"key": "db/t", "sha256": "%s"}]}', strrep("0", 64))
  writeLines(good, file.path(d, "manifest.json"))
  # a table the manifest does not list is not loaded unverified (no digest had meant "accept")
  f <- file.path(d, "db__x.csv.gz")
  writeLines("a\n666", f)
  expect_error(ns(".bl_data_check_sha")("db/x", f, cached = TRUE), "not listed")
  expect_true(file.exists(f))
  Sys.setFileTime(file.path(d, "manifest.json"), Sys.time() - 3 * 86400)
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) writeLines('{"datasets": []}', dest))
  expect_error(bricklayer_data_manifest(refresh = TRUE), "lists no tables")
  expect_identical(readLines(file.path(d, "manifest.json")), good)
})

# ---- E12: the lock --------------------------------------------------------------------------

test_that("E12: the lock is released however its holder ends", {
  d <- withr::local_tempdir()
  p <- file.path(d, "rec.txt")
  with_lock <- ns(".rmbl_xmss_with_lock")
  expect_error(with_lock(p, function() stop("inside")), "inside")
  # released: taken again at once
  t0 <- proc.time()[["elapsed"]]
  expect_identical(with_lock(p, function() "again"), "again")
  expect_lt(proc.time()[["elapsed"]] - t0, wall_limit(2))
  # the lock is taken and f() run in one C frame whose cleanup is the release: no R-level handler
  # for an interrupt to cut short (review of 29a55d8, G6)
  src <- paste(deparse(with_lock), collapse = "\n")
  expect_match(src, "C_rmbl_flock_with", fixed = TRUE)
  expect_false(grepl("on.exit", src, fixed = TRUE))
})

# ---- the 02a38be leftovers -----------------------------------------------------------------

test_that("hurwitz_zeta: accurate beside the trivial zeros and for a huge q", {
  # mpmath zeta() at 60 digits, at the exact doubles z + e (hex floats both ways): the earlier check
  # against a first-order series could not see the loss in sinpi() beside -1 (review of 46de6a9, F5)
  ref <- c("-0x1.fffffffbb47dp+0" = "-0x1.0bd3d5ef008bbp-35", "-0x1.0000000036f9cp+1" = "0x1.ac86230f7688dp-39",
           "-0x1.fffffffffee68p+0" = "-0x1.12479a7f26a4ap-45", "-0x1.00000000000e1p+1" = "0x1.b675312d78035p-49",
           "-0x1.fffffffffffd3p+0" = "-0x1.5ec427579363ap-52", "-0x1.0000000000002p+1" = "0x1.f2de15d1e2a96p-56",
           "-0x1.7ffffffeed1f4p+2" = "-0x1.9f289f0130298p-38", "-0x1.800000001b7cep+2" = "0x1.4c207f3453ea2p-41",
           "-0x1.7fffffffffb9ap+2" = "-0x1.a92905ae0d99dp-48", "-0x1.8000000000071p+2" = "0x1.555622921a6d1p-51",
           "-0x1.7fffffffffff5p+2" = "-0x1.09d1cde551be8p-54", "-0x1.8000000000001p+2" = "0x1.82a588935fa0ep-58",
           "-0x1.3fffffff768fap+3" = "-0x1.4d04d0f350402p-36", "-0x1.400000000dbe7p+3" = "0x1.0a6a40c52cf72p-39",
           "-0x1.3fffffffffdcdp+3" = "-0x1.550aa3361be41p-46", "-0x1.4000000000038p+3" = "0x1.0f6121ee20db0p-49",
           "-0x1.3fffffffffffap+3" = "-0x1.d138cc73a5eccp-53", "-0x1.4000000000001p+3" = "0x1.3625dda26ea00p-55",
           "-0x1.bfffffff768fap+3" = "-0x1.40ae5ba61ff67p-32", "-0x1.c00000000dbe7p+3" = "0x1.008b7c88dc2d3p-35",
           "-0x1.bfffffffffdcdp+3" = "-0x1.486816cf80041p-42", "-0x1.c000000000038p+3" = "0x1.05534842e7207p-45",
           "-0x1.bfffffffffffap+3" = "-0x1.bffc7be06777fp-49", "-0x1.c000000000001p+3" = "0x1.2aa852959a536p-51")
  for (i in seq_along(ref)) {
    s <- as.numeric(names(ref)[i])   # R reads C99 hex floats exactly
    expect_equal(hurwitz_zeta(s) / as.numeric(ref[[i]]), 1, tolerance = 1e-12, info = names(ref)[i])
  }
  expect_identical(hurwitz_zeta(-4), 0)
  expect_equal(hurwitz_zeta(-11), 691 / 32760, tolerance = 1e-13)
  # -B5(q)/5 with q^5 past the double range while the value is not
  expect_equal(hurwitz_zeta(-4, 5e61), -exp(5 * log(5e61) - log(5)), tolerance = 1e-12)
  expect_true(is.finite(hurwitz_zeta(-4, 5e61)))
})

test_that("an empty schema checks nothing and is said; a field of a dataset's own is not a typo", {
  df <- data.frame(a = 1)
  expect_identical(validate_schema(df, list(schema = list()))$schema_empty$severity, "warning")
  expect_error(apply_schema_validation(df, list(schema = list())), "schema is empty")
  iss <- validate_schema(df, list(schema = list(structural_invariants = list(min_data_cols = 1))))
  expect_null(iss$schema_field_min_data_cols)
  iss2 <- validate_schema(df, list(schema = list(structural_invariants = list(min_data_row = 1))))
  expect_identical(iss2$schema_field_min_data_row$severity, "fatal")
  iss3 <- validate_schema(df, list(schema = list(structural_invariants = list(min_data_rwos = 1))))
  expect_identical(iss3$schema_field_min_data_rwos$severity, "fatal")
})

test_that("drift_calibrate needs at least one split", {
  d <- data.frame(a = rnorm(40))
  expect_error(drift_calibrate(d, n = 0), "at least 1")
  expect_error(drift_calibrate(d, n = NA), "at least 1")
})

test_that("printing keeps joined scripts, emoji forms and flags, and drops what hides text", {
  pr <- ns(".rmbl_printable")
  hindi <- "\u0915\u094d\u200d\u0937"
  persian <- "\u0645\u06cc\u200c\u062e\u0648\u0627\u0647\u0645"
  family <- "\U0001F468\u200d\U0001F469\u200d\U0001F467"
  heart <- "\u2764\ufe0f"
  scotland <- "\U0001F3F4\U000E0067\U000E0062\U000E0073\U000E0063\U000E0074\U000E007F"
  for (x in c(hindi, persian, family, heart, scotland)) expect_identical(pr(x), x)
  expect_identical(pr("a\U000E0041b"), "ab")
  expect_identical(pr(paste0("a\u202eb\u200bc", "\033[31md")), "abcd")
})

test_that("the status of a key stored for another address says so", {
  st_other <- list(state = "other_address", key = NULL, saved_for = "https://a.example", now = "https://b.example")
  local_mocked_bindings(.bl_hosted_key_state = function() st_other,
                        .bl_hosted_base = function() "https://b.example",
                        .bl_hosted_key = function() NULL,
                        .bl_own_base = function() NULL, .bl_ollama_base = function() NULL)
  out <- character()
  ns(".bl_cli_doctor")(function(x) out <<- c(out, x))
  expect_true(any(grepl("data key: issued for https://a.example, so not sent to https://b.example", out, fixed = TRUE)))
  local_mocked_bindings(.bl_hosted_key_state = function() list(state = "ok", key = "k"))
  out <- character()
  ns(".bl_cli_doctor")(function(x) out <<- c(out, x))
  expect_true(any(grepl("data key: stored", out, fixed = TRUE)))
})


test_that("replicate columns without names, rscales checked, a design from before the data check", {
  s <- svy_data()
  rep_df <- as.data.frame(s$reps)
  names(rep_df) <- rep("", ncol(rep_df))
  des <- survey_design(s$d, weights = "w", replicates = rep_df)
  expect_length(des$reps, 20L)
  expect_error(survey_design(s$d, weights = "w", replicates = s$reps, type = "jkn", rscales = rep(1, 3)),
               "20 finite non-negative numbers")
  expect_error(survey_design(s$d, weights = "w", replicates = s$reps, rscales = rep(-1, 20)), "non-negative")
  # an object saved before 0.5.12 carries no data check: it is taken as it is
  old <- survey_design(s$d, weights = "w", replicates = s$reps)
  old$check <- NULL
  expect_equal(survey_estimate(old, s$d, "y")$se, survey_estimate(des, s$d, "y")$se)
})
