# Lines the final-audit fixes left unexercised: every refusal in words, the survey design's
# replicate edges, the simplex solver's fallback, the transport seams through the mocked spinner.

test_that("audit coverage: refusals in words across the input guards", {
  expect_error(.rmbl_df_names(NULL), "must be a data frame, not NULL")
  expect_error(.rmbl_df_names(list(a = 1)), "must be a data frame, not list")
  expect_identical(.rmbl_with_seed(NULL, 1 + 1), 2)
  expect_error(advdif2d(matrix(1, 4, 4), u = 1e200, v = 0, kx = 0, ky = 0, dx = 1e-200, dy = 1, dt = 1, nsteps = 1),
               "stability number is not finite")
  # 1e299, not 1e300: valgrind has no 80-bit long double, and R's parser reads 1e300 one ulp above it
  expect_error(advdif2d(matrix(1, 4, 4), u = 1e150, v = 0, kx = 0, ky = 0, dx = 1e-150, dy = 1, dt = 1, nsteps = 1e299),
               "amount of work is not finite")
  expect_error(cpsbndl(tempdir(), man = NULL, key = NULL, files = 1), "`files` must be file names")
  expect_error(declbld(list(1)), "`x` must be a vector of codes")
  expect_error(chwknll(c(1, 2), 10), "`par` must be the kernel parameters")
  expect_error(.rmbl_falsify_eval(function(d) list(1), data.frame(), "the data"), "returned something else")
  expect_error(.rmbl_ind_cols(data.frame(a = 1), y = NULL), "`y` must name a column of `data`")
  expect_error(vrfcps(tempdir(), provfile = "p.json", dfile = 1), "`dfile` must be")
  expect_error(mksyncol(list(type = "sample", values = 1:2), 5, basep = 2), "probabilities between 0 and 1")
  expect_error(.rmbl_learner(function(x) x), "`lrn` must be a learner name")
  d <- data.frame(t = rep(0:1, each = 5), age = 1:10)
  expect_error(baltab(d, "t", NULL), "`covs` must name one column at least")
  expect_error(pubbnd(1:3, supmar = 1), "`supmar` must be the text markers")
  expect_error(shrs(list()), "`x` must be finite counts")
  expect_error(shrs(c(NA, NA)), "`x` must be finite counts")
  for (f in list(ruleinset, rulebtw, rulenull, ruleuniq, rulerx, ruleincr, rulemad)) {
    expect_error(f(), "`col` must name a column")
  }
  expect_error(trchlthgap(health = 1), "`health` must be a data frame of indicators")
  seg <- data.frame(EndFiscalYear = 2019:2023, n = c(402, 377, 190, 268, 331))
  y <- yoy(seg, value = n, prd = EndFiscalYear)
  expect_error(yoylbl(y, list()), "`labels` must be a function of the periods or a vector")
})

test_that("audit coverage: the policy functions' column guards and the panel grid", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  p <- polex()
  expect_error(wcb(p, "district", "month", "crmrate", "nope", reps = 99), "`trtd` \\(nope\\) is not a column")
  expect_error(plnpois(p, "district", "month", "crimes", "reformed", offset = "nope"),
               "`offset` \\(nope\\) is not a column")
  expect_error(plnpois(p, "district", "month", "crimes", "reformed", offset = "district"),
               "`offset` must be a finite numeric column")
  expect_error(synctl(p, "district", "month", "crmrate", treunit = list(), adopt = 13), "`treunit` is not a unit")
  expect_error(loounit(p, "district", "month", "crmrate", "reformed", units = list()), "`units` must be unit labels")
  es <- list(
    "Crime rate" = evstudy(p, "district", "month", "crmrate", "refmonth", leads = 3, lags = 4),
    "Arrest rate" = evstudy(p, "district", "month", "arrrate", "refmonth", leads = 3, lags = 4))
  r <- plotevgrid(es, main = "Two outcomes")
  expect_s3_class(r, "data.frame")
  expect_setequal(unique(r$panel), names(es))
  expect_true(all(c("evtm", "estimate", "lower", "upper") %in% names(r)))
})

test_that("audit coverage: the simplex solver's single column, singular system and fallback", {
  expect_identical(.rmbl_simplex_ls(matrix(1:3, 3), c(1, 2, 3)), 1)
  # two identical columns: the KKT system is singular, the projected-gradient fallback shares them
  A <- cbind(c(1, 0), c(1, 0), c(0, 1))
  w <- .rmbl_simplex_ls(A, c(1, 1))
  expect_equal(sum(w), 1)
  expect_true(all(w >= 0))
  expect_equal(w[3], 0.5, tolerance = 1e-6)
  expect_equal(w[1], w[2], tolerance = 1e-6)
  # random problems: on the simplex, and no better point along any edge
  for (s in 1:12) {
    set.seed(s)
    A <- matrix(stats::rnorm(60), 10)
    b <- stats::rnorm(10)
    w <- .rmbl_simplex_ls(A, b)
    expect_equal(sum(w), 1, tolerance = 1e-10)
    expect_true(all(w >= -1e-12))
    obj <- sum((A %*% w - b)^2)
    for (j in seq_along(w)) {
      e <- numeric(length(w))
      e[j] <- 1
      wj <- 0.999 * w + 0.001 * e
      expect_gte(sum((A %*% wj - b)^2) + 1e-9, obj)
    }
  }
})

test_that("audit coverage: the EM for missing data gives up on a singular observed block", {
  X <- cbind(a = c(1, 2, 3, 4, NA, 6), b = c(1, 2, 3, 4, 5, NA), c = c(1, 2, 3, 4, 5, 6) * 2)
  expect_null(.rmbl_em_mvn(X, ridge = 0))
})

test_that("audit coverage: the survey design's replicate matrix edges", {
  set.seed(3)
  n <- 40
  d <- data.frame(y = stats::rnorm(n), w = stats::runif(n, 1, 2))
  R <- replicate(6, d$w * tabulate(sample(n, replace = TRUE), n))
  # an integer matrix goes the data-frame way
  Ri <- matrix(as.integer(round(R)), n)
  expect_s3_class(suppressWarnings(svydes(d, "w", reps = Ri, type = "bootstrap")), "rmbl_svy_design")
  # the weight itself under its own name is dropped; under its name with other values it is refused
  Rw <- cbind(w = d$w, R)
  des <- svydes(d, "w", reps = Rw, type = "bootstrap")
  expect_identical(ncol(des$reps), 6L)
  expect_error(svydes(d, "w", reps = cbind(w = d$w * 1.5, R), type = "bootstrap"),
               "has the full weight's name but not its values")
  expect_error(svydes(d, "w", reps = as.data.frame(R)[1:10, ], type = "bootstrap"), "one row per row")
  Rna <- as.data.frame(R)
  Rna[1, 1] <- NA
  expect_error(svydes(d, "w", reps = Rna, type = "bootstrap"), "finite, non-negative and not missing")
  # replicates of zeros: scaled by one for the degrees of freedom
  z <- suppressWarnings(svydes(d, "w", reps = data.frame(r1 = rep(0, n), r2 = rep(0, n)), type = "bootstrap"))
  expect_s3_class(z, "rmbl_svy_design")
  # JKn: one factor k/(k - 1) within 1% of the weight, carried by one replicate where k are genuine
  n2 <- 400
  h <- rep(1:200, each = 2)
  psu <- rep(1:2, 200)
  dd <- data.frame(y = stats::rnorm(n2), w = rep(1, n2))
  reps <- vapply(1:200, function(k) {
    r <- dd$w
    r[h == k & psu == 1] <- 0
    r[h == k & psu == 2] <- 2
    r
  }, numeric(n2))
  reps <- cbind(reps, dd$w * 201 / 200)
  expect_warning(svydes(dd, "w", reps = reps, type = "jkn", rscales = rep(0.5, 201)),
                 "rescaled copy of the full-sample weight")
})

test_that("audit coverage: the JSON codec's scalar classes, digits and the R parser's buffers", {
  expect_identical(as.character(tojs(structure(1, class = c("scalar", "numeric")))), "1")
  expect_error(tojs(1, digits = "a"), "`digits` must be one number")
  expect_error(tojs(1, digits = c(1, 2)), "`digits` must be one number")
  expect_error(tojs(1, digits = TRUE), "`digits` must be one number")
  expect_identical(.rmbl_json_parse(paste0("\"", strrep("\\n", 40), "\"")), strrep("\n", 40))
  expect_identical(.rmbl_json_parse("\"a\\nb\""), "a\nb")
  expect_equal(unlist(.rmbl_json_parse("[1e+5, 2E-2]")), c(1e5, 0.02))
  # a URL: the same transport as every fetch, behind the spinner
  local_mocked_bindings(.rmbl_check_public_url = function(url, what, ...) url,
                        .bl_net = function(url, expr) list(status = 404L, bytes = 0, error = ""))
  expect_error(fromjs("https://example.org/a.json"), "answered HTTP 404")
  local_mocked_bindings(.bl_net = function(url, expr) list(status = -1L, bytes = 0, error = "no route"))
  expect_error(fromjs("https://example.org/a.json"), "no route")
  local_mocked_bindings(.bl_net = function(url, expr) list(status = 200L, bytes = 0, error = ""))
  expect_error(suppressWarnings(fromjs("https://example.org/a.json")))
})

test_that("audit coverage: the fetch seams through the mocked spinner", {
  dest <- tempfile()
  local_mocked_bindings(.bl_net = function(url, expr) 0L)
  expect_identical(blfetch("https://example.org/a.csv", dest), "live")
  local_mocked_bindings(.bl_net = function(url, expr) 1L)
  expect_identical(blfetch("https://example.org/a.csv", dest), "wayback")
  local_mocked_bindings(.bl_net = function(url, expr) -2L)
  expect_error(blfetch("https://example.org/a.csv", dest), "could not be saved there")
  local_mocked_bindings(.bl_net = function(url, expr) "https://web.archive.org/web/2024/https://example.org/")
  expect_identical(wbsnpnat("https://example.org/"), "https://web.archive.org/web/2024/https://example.org/")
  local_mocked_bindings(.bl_net = function(url, expr) "")
  expect_null(wbsnpnat("https://example.org/"))
  # a download with headers whose address the transport cannot reach fails in the transport's words
  local_mocked_bindings(.rmbl_check_public_url = function(url, what, ...) url)
  expect_error(bldl("https://192.0.2.1/x.csv", tempfile(), headers = c(Accept = "text/csv"), tmout = 1,
                    quiet = TRUE))
})

test_that("audit coverage: rgnmappts() refuses the wrong unit, field and crs shapes", {
  skip_if_not_installed("sf")
  gj <- tempfile(fileext = ".geojson")
  writeLines(paste0(
    '{"type":"FeatureCollection","features":[',
    '{"type":"Feature","properties":{"CDUID":"A"},"geometry":',
    '{"type":"Polygon","coordinates":[[[-80,43],[-79,43],[-79,44],[-80,44],[-80,43]]]}}]}'), gj)
  expect_error(rgnmappts(c(-79.5, -78.5), c(43.5, 43.5), unit = "one", gj, "CDUID"), "one non-empty name per point")
  expect_error(rgnmappts(-79.5, 43.5, "a", gj, fields = 1), "`fields` must name columns")
  expect_error(rgnmappts(-79.5, 43.5, "a", gj, "CDUID", crs = list()), "`crs` must be one EPSG")
})

test_that("audit coverage: the R parser's buffers, the scalar class and the download seam", {
  nat <- asNamespace("rmoriebricklayer")$.rmbl_native
  old <- nat$json
  nat$json <- FALSE
  on.exit(nat$json <- old, add = TRUE)
  expect_identical(.rmbl_json_parse(paste0("\"", strrep("\\n", 40), "\"")), strrep("\n", 40))
  expect_identical(.rmbl_json_parse("\"a\\nb\""), "a\nb")
  expect_equal(unlist(.rmbl_json_parse("[1e+5, 2E-2]")), c(1e5, 0.02))
  nat$json <- old
  x2 <- structure(1, class = c("scalar", "numeric"))
  x1 <- structure(1, class = "scalar")
  expect_identical(as.character(tojs(list(a = x2, b = x1))), "{\"a\":1,\"b\":1}")
  # the transport answered: an HTTP error in words, a body with its size announced on the way
  local_mocked_bindings(.rmbl_check_public_url = function(url, what, ...) url,
                        .bl_http_download = function(url, dest, tmout, headers, draw, maxbytes, head_only) {
                          list(status = 404L, bytes = 0, error = "")
                        })
  expect_error(bldl("https://example.org/x.csv", tempfile(), quiet = TRUE), "answered HTTP 404")
  local_mocked_bindings(.bl_http_download = function(url, dest, tmout, headers, draw, maxbytes, head_only) {
    writeLines("a,b", dest)
    draw(2, 4)
    draw(4, 4)
    list(status = 200L, bytes = 4, error = "")
  })
  dest <- tempfile()
  expect_silent(bldl("https://example.org/x.csv", dest, quiet = TRUE))
  expect_identical(readLines(dest), "a,b")
  out <- capture.output(bldl("https://example.org/x.csv", dest, quiet = FALSE, tty = FALSE), type = "message")
  expect_true(any(grepl(basename(dest), out, fixed = TRUE)))
})

test_that("audit coverage: the simplex solver lets a column back in and polishes a fallback", {
  set.seed(3)
  A <- matrix(stats::rnorm(16), 4)
  b <- stats::rnorm(4) * 3
  w <- .rmbl_simplex_ls(A, b)
  expect_equal(sum(w), 1, tolerance = 1e-10)
  expect_true(all(w >= -1e-12))
  # duplicate columns the optimum does not use: the fallback's answer is polished on its support
  w <- .rmbl_simplex_ls(cbind(c(1, 0), c(1, 0), c(0, 1)), c(0, 5))
  expect_equal(w, c(0, 0, 1), tolerance = 1e-8)
})

test_that("audit coverage: a record set whose columns simplify to different lengths is refused", {
  local_mocked_bindings(.rmbl_json_simplify = function(x, ...) if (identical(unlist(x), c(1, 2))) c(1, 2) else 1:3)
  recs <- list(list(a = 1, b = 3), list(a = 2, b = 4))
  expect_error(.rmbl_json_simplify_df(recs, c("a", "b"), flatten = FALSE, simplifyMatrix = FALSE),
               "Elements not of equal length: 2 3")
})

test_that("audit coverage: native guards reached by a direct call", {
  expect_error(.Call(C_rmbl_morans_i, 1:3, c(1L, 0L, 2L, 1L), c(0L, 1L, 3L), c(1L, 2L, 1L), c(1, 1, 1, 1),
                     0L, NULL), "Moran's I takes double")
  expect_error(.Call(C_rmbl_theil_sen, as.numeric(1:20001), as.numeric(1:20001)),
               "exceeds the 20000-point limit")
  z <- strrep("00", 32)
  expect_false(.Call(C_rmbl_xmss_verify, z, z, 0L, 0L, charToRaw("m"), z, z, z))
  expect_false(.Call(C_rmbl_xmss_verify, z, z, 2L, 0L, charToRaw("m"), z, z, z))
})

test_that("re-check of 1.0.0: the battery's last raw errors are refused in words", {
  expect_error(blcli("version", out = 1), "`out` must be a function")
  expect_error(dlogin(token = function(x) x), "`token` must be one string")
  cp <- structure(data.frame(), class = c("rmbl_census_profile", "data.frame"))
  expect_error(cnscwb(cp, groups = NULL), "`groups` must name one group or more")
  expect_error(cnscwb(cp, groups = character(0)), "`groups` must name one group or more")
  expect_error(cnscwb(cp, groups = c("a", "")), "`groups` must name one group or more")
  expect_error(rtcalc(Inf, 100), "`x` and `pop` must be finite counts")
  expect_error(rtcalc(3, Inf), "`x` and `pop` must be finite counts")
  expect_error(recrd(data.frame(), "n", 1, 1), "`man` must be a manifest from mkmnf\\(\\)")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_error(plotfnl(c(1, 2, 3), c(1, 2, 3), target = 1e308), "below 1e300")
  expect_error(stkflow(c(10, 20), c(2, 3), per = 1e308, expo = c(100, 100)), "`per` must be at most 1e12")
  # a grouped key with punctuation on its last group is still a key
  expect_true(.bl_key_shaped("key is abcd1234efgh ijkl5678mnop qrst9012uvwx?"))
  expect_true(.bl_key_shaped("abcd1234efgh ijkl5678mnop qrst9012uvwx, why?"))
  expect_false(.bl_bare_question("key is abcd1234efgh ijkl5678mnop qrst9012uvwx?"))
  expect_false(.bl_key_shaped("describe the drift test?"))
  # the neighbouring shapes: every group punctuated, quoted, joined by dashes, dots or underscores,
  # no-break spaces or tabs between the groups, zero-width characters inside one
  for (s in c("abcd1234efgh, ijkl5678mnop, qrst9012uvwx.", "\"abcd1234efgh\" \"ijkl5678mnop\" \"qrst9012uvwx\"",
              "abcd1234efgh-ijkl5678mnop-qrst9012uvwx", "abcd1234efgh.ijkl5678mnop.qrst9012uvwx",
              "abcd1234efgh\tijkl5678mnop\tqrst9012uvwx?", "abcd1234efgh\u00a0ijkl5678mnop\u00a0qrst9012uvwx?",
              "abcd12\u200b34efgh ijkl5678mnop qrst9012uvwx?", "ABCD1234EFGH IJKL5678MNOP QRST9012UVWX!")) {
    expect_true(.bl_key_shaped(s), info = s)
    expect_false(.bl_bare_question(s), info = s)
  }
  for (s in c("compare 2019 2020 2021 totals for the ocj table?",
              "is table 35100177 the same as 35100026 and 35100003?",
              "describe the drift test for cafe1234 and beef5678?")) {
    expect_false(.bl_key_shaped(s), info = s)
    expect_true(.bl_bare_question(s), info = s)
  }
})
