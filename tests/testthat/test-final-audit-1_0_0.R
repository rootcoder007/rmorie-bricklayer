# The final pre-CRAN audit of 1.0.0: one test per finding, each failing on the code the audit read.

# ---- #2: the streamed CSV path refuses a ragged row ---------------------------------------------

test_that("#2: the streamed CSV reader refuses a ragged row as the in-memory path does", {
  f <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a,b", "1,2", "3,4,5"), f)
  # before the fix: names a, b, row names 1 and 3, the data shifted one column left
  expect_error(.bl_read_csv_streamed(f), "record 3 has 3 fields, the header 2")
  writeLines(c("a,b", "1,2", "3,4"), f)
  r <- .bl_read_csv_streamed(f)
  expect_identical(names(r), c("a", "b"))
  expect_identical(nrow(r), 2L)
  # a quoted comma is one field; a gzip file reads the same way
  writeLines(c("a,b", "1,\"x,y\"", "3,4"), f)
  expect_identical(.bl_read_csv_streamed(f)$b[[1L]], "x,y")
  g <- withr::local_tempfile(fileext = ".csv.gz")
  con <- gzfile(g, "wt")
  writeLines(c("a,b", "1,2", "3,4,5"), con)
  close(con)
  expect_error(.bl_read_csv_streamed(g), "record 3 has 3 fields")
})

# ---- #3, #3b: the survey reorder check --------------------------------------------------------

test_that("#3: a swap of two rows beside one edited cell is a reorder, a permuted column is not", {
  set.seed(1)
  n <- 60L
  d <- data.frame(id = seq_len(n), g = rep(c("a", "b"), each = n / 2), x = stats::rnorm(n),
                  m = sample(10:90, n, TRUE), w = stats::runif(n, 1, 3), stringsAsFactors = FALSE)
  R <- matrix(d$w, n, 30) * matrix(stats::rpois(n * 30, 1), n, 30)
  des <- svydes(d, "w", reps = R, type = "bootstrap")
  built <- svyest(des, d, "x")$se
  # the swap alone and the edit alone
  sw <- d[c(2L, 1L, 3:n), ]
  expect_error(svyest(des, sw, "x"), "not the data frame the design was built on")
  ed <- d
  ed$m[5L] <- ed$m[5L] + 1L
  expect_type(svyest(des, ed, "x")$se, "double")
  # the swap and the edit together: the rows moved outnumber the row changed. The edit turns the
  # integer column into a double one, which changed every row's code before the fix
  both <- sw
  both$m[5L] <- both$m[5L] + 1
  expect_error(svyest(des, both, "x"), "not the data frame the design was built on")
  rownames(both) <- NULL
  expect_error(svyest(des, both, "x"), "not the data frame the design was built on")
  # a permuted outcome (a permutation test) changes rows and moves none: it passes
  pm <- d
  pm$x <- sample(pm$x)
  expect_type(svyest(des, pm, "x")$se, "double")
  # a design built before the keys were kept falls back to the per-column reading
  old <- des
  old$check$rowkeys$keys <- NULL
  expect_type(svyest(old, ed, "x")$se, "double")
})

test_that("#3b: -0 and every NaN code as one value, and an integer column codes as its double", {
  C <- asNamespace("rmoriebricklayer")
  expect_identical(.Call(C$C_rmbl_svy_dblcode, c(-0, NaN, NA, 1)), .Call(C$C_rmbl_svy_dblcode, c(0, NA, NA, 1)))
  expect_false(anyNA(.Call(C$C_rmbl_svy_dblcode, c(-0, NaN, NA, Inf, -Inf))))
  a <- .svy_rowkey_digests(data.frame(v = c(1L, NA, 3L)))
  b <- .svy_rowkey_digests(data.frame(v = c(1, NA, 3)))
  expect_identical(a$keys, b$keys)
  # a column of -0 and the rows reordered among them: refused, where the NA keys hid it
  set.seed(2)
  n <- 40L
  d <- data.frame(z = c(rep(-0, 10), stats::runif(n - 10)), y = stats::rnorm(n), w = stats::runif(n, 1, 2))
  R <- matrix(d$w, n, 20) * matrix(stats::rpois(n * 20, 1), n, 20)
  des <- svydes(d, "w", reps = R, type = "bootstrap")
  x <- d[c(10:1, 11:n), ]
  rownames(x) <- NULL
  expect_error(svyest(des, x, "y", stat = "total"), "not the data frame the design was built on")
})

# ---- #8: the design's degrees of freedom -------------------------------------------------------

test_that("#8: the rank is read from the smaller Gram matrix, and a huge replicate is scaled first", {
  set.seed(3)
  n <- 12L
  w <- stats::runif(n, 1, 3)
  d <- data.frame(w = w, y = stats::rnorm(n))
  # B > n: the n x n product (a B x B one asked for gigabytes at B = 1e5)
  B <- 500L
  R <- matrix(w, n, B) * matrix(stats::rpois(n * B, 1), n, B)
  t <- system.time(des <- svydes(d, "w", reps = R, type = "bootstrap"))[["elapsed"]]
  expect_lte(des$degf, n - 1L)
  expect_lt(t, wall_limit(5))
  # B <= n: the B x B product, the same rank
  R2 <- R[, 1:6]
  expect_identical(svydes(d, "w", reps = R2, type = "bootstrap")$degf, qr(R2)$rank - 1L)
  # a replicate near the double's range no longer overflows eigen()
  R3 <- R[, 1:6]
  R3[1L, 1L] <- 1e308
  expect_no_error(suppressWarnings(svydes(d, "w", reps = R3, type = "bootstrap")))
})

# ---- #9: the replicate contract's edges ---------------------------------------------------------

test_that("#9: a Fay replicate equal to the weight is said, not refused", {
  set.seed(4)
  n <- 20L
  w <- rep(2, n)
  R <- matrix(w, n, 4)
  R[1:10, 2] <- w[1:10] * 1.7
  R[11:20, 2] <- w[11:20] * 0.3
  R[1:10, 3] <- w[1:10] * 0.3
  R[11:20, 3] <- w[11:20] * 1.7
  R[, 4] <- w * c(rep(1.7, 5), rep(0.3, 15))
  expect_warning(svydes(data.frame(w = w, y = stats::rnorm(n)), "w", reps = R, type = "fay", rho = 0.3),
                 "replicate V1 is the full-sample weight: genuine on a domain")
})

test_that("#9: k/(k - 1) on every row with no row out is said under JK1 and JKn", {
  set.seed(5)
  n <- 30L
  w <- stats::runif(n, 1, 2)
  psu <- rep(1:15, each = 2)
  jk1 <- vapply(1:15, function(k) ifelse(psu == k, 0, w * 15 / 14), numeric(n))
  expect_no_warning(svydes(data.frame(w = w, y = stats::rnorm(n)), "w", reps = jk1, type = "jk1"))
  # the full data plus a column that is w * 15/14 on every row: a rescaled copy, said
  expect_warning(svydes(data.frame(w = w, y = stats::rnorm(n)), "w", reps = cbind(jk1, w * 15 / 14), type = "jk1"),
                 "that 16 replicates carry and leaves no row out")
  # the same factor on a domain subset whose PSUs lie outside some replicates: k of them carry it,
  # with or without a row out, and nothing is said
  sub <- psu <= 5
  jsub <- jk1[sub, ]
  expect_no_warning(svydes(data.frame(w = w[sub], y = stats::rnorm(sum(sub))), "w", reps = jsub, type = "jk1"))
  # within 1% of the weight and k/(k - 1) for a k the set allows (B/(B - 1) with B = 16): said, not
  # refused, where w * 1.004 and w * 1.006 are refused as copies
  expect_warning(svydes(data.frame(w = w, y = stats::rnorm(n)), "w", reps = cbind(jk1, w * 16 / 15), type = "jkn",
                        rscales = rep(14 / 15, 16L)),
                 "scales every row by one factor")
  expect_error(svydes(data.frame(w = w, y = stats::rnorm(n)), "w", reps = cbind(jk1, w * 1.004), type = "jkn",
                      rscales = rep(14 / 15, 16L)),
               "a copy of the full-sample weight")
})

test_that("#9: one JKn replicate equal to the weight is refused, all are refused, two are kept", {
  set.seed(6)
  n <- 24L
  w <- stats::runif(n, 1, 2)
  strat <- rep(1:3, each = 8)
  psu <- rep(1:12, each = 2)
  jkn <- vapply(1:12, function(k) {
    s <- strat[psu == k][[1L]]
    f <- ifelse(strat == s, 4 / 3, 1)
    ifelse(psu == k, 0, w * f)
  }, numeric(n))
  d <- data.frame(w = w, y = stats::rnorm(n))
  expect_no_warning(svydes(d, "w", reps = jkn, type = "jkn", rscales = rep(3 / 4, 12L)))
  expect_error(svydes(d, "w", reps = cbind(jkn, V13 = w), type = "jkn", rscales = rep(3 / 4, 13L)),
               "the full-sample weight")
  # two equal to the weight look like a stratum left out of a subset: kept, without a word
  expect_no_warning(svydes(d, "w", reps = cbind(jkn, V13 = w, V14 = w), type = "jkn", rscales = rep(3 / 4, 14L)))
  expect_error(svydes(d, "w", reps = cbind(V1 = w, V2 = w, V3 = w), type = "jkn", rscales = rep(3 / 4, 3L)),
               "every replicate is the full-sample weight")
})

# ---- #4: the manifest is read with a bound on its decoded size ---------------------------------

test_that("#4: a gzip body that decodes past the cap is refused without being decoded whole", {
  gz <- withr::local_tempfile(fileext = ".gz")
  con <- gzfile(gz, "wb")
  z <- raw(2^20)
  for (i in 1:40) writeBin(z, con)
  close(con)
  expect_lt(file.size(gz), 2^20)
  t <- system.time(expect_error(.bl_read_text_capped(gz, 8 * 2^20), "holds more than 8388608 bytes once decoded"))
  expect_lt(t[["elapsed"]], wall_limit(5))
  # a small compressed manifest reads whole; a plain one too, with CRLF lines joined as readLines() did
  con <- gzfile(gz, "wt")
  writeLines(c("{\"datasets\":", " []}"), con)
  close(con)
  expect_identical(.bl_read_text_capped(gz, 2^20), "{\"datasets\":\n []}")
  f <- withr::local_tempfile()
  writeBin(charToRaw("{\"a\": 1,\r\n \"b\": 2}\r\n"), f)
  expect_identical(.bl_read_text_capped(f, 2^20), "{\"a\": 1,\n \"b\": 2}")
  # the cached manifest goes through the same reader
  d <- withr::local_tempdir()
  withr::local_envvar(XDG_CACHE_HOME = d)
  p <- file.path(.bl_data_cache_dir(), "manifest.json")
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines("{\"datasets\": [{\"key\": \"demo/x\"}]}", p)
  Sys.setFileTime(p, Sys.time())
  expect_identical(dmnf()$datasets[[1L]]$key, "demo/x")
})

# ---- #5: the JSON fast path ---------------------------------------------------------------------

test_that("#5: big integers, duplicate keys and deep nesting are the fast path's, not the R parser's", {
  C <- asNamespace("rmoriebricklayer")
  big <- paste0("[", paste(rep("1", 1e5), collapse = ","), ", 9007199254740993]")
  t <- system.time(expect_warning(r <- fromjs(big), "integer 9007199254740993 exceeds 2\\^53"))[["elapsed"]]
  expect_lt(t, wall_limit(3))
  expect_identical(r[[length(r)]], 9007199254740992)
  expect_identical(fromjs("[9007199254740993]", bigint_as_char = TRUE)[[1L]], "9007199254740993")
  expect_no_warning(fromjs("[9007199254740993]", bigint_warn = FALSE))
  # sixteen digits that a double holds exactly: no warning; a leading zero does not count
  expect_no_warning(expect_identical(fromjs("[9007199254740994]")[[1L]], 9007199254740994))
  expect_no_warning(expect_identical(fromjs("[-9007199254740992]")[[1L]], -9007199254740992))
  expect_identical(fromjs("[-9007199254740993]", bigint_as_char = TRUE)[[1L]], "-9007199254740993")
  # a 17-digit number far beyond 2^53 that the double does not hold
  expect_warning(fromjs("[12345678901234567]"), "exceeds 2\\^53")
  # a duplicate key: the R parser's words and position, in a small document and a large one
  expect_error(fromjs('{"a": 1, "a": 2}'), 'duplicate key "a" at character 17')
  expect_identical(unlist(fromjs('{"a": 1, "a": 2}', duplicate_keys = "keep")), c(a = 1L, a = 2L))
  dup <- paste0("{", paste(sprintf('"k%d": %d', 1:60000, 1:60000), collapse = ","), ', "k7": 0}')
  t <- system.time(expect_error(fromjs(dup), 'duplicate key "k7"'))[["elapsed"]]
  expect_lt(t, wall_limit(3))
  # a huge object whose repeat is late: the sorted scan names it
  late <- paste0("{", paste(sprintf('"k%d": 1', 1:5000), collapse = ","), ', "k4999": 2}')
  expect_error(fromjs(late), 'duplicate key "k4999"')
  deep <- paste0(strrep("[", 150), strrep("]", 150))
  expect_error(fromjs(deep), "nesting deeper than 100 levels at character 101")
  # a syntax error past 128 KiB is refused here, with its place; a small one still reads the R parser
  bad <- paste0("[", paste(rep("1", 1e5), collapse = ","), ", @]")
  t <- system.time(expect_error(fromjs(bad), "unexpected character at character 200003"))[["elapsed"]]
  expect_lt(t, wall_limit(3))
  expect_error(fromjs("[1, @]"), "at character 5")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), ", 1.5e]")), "invalid number at character")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), ", \"a]")), "unterminated or invalid string")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), "]]")), "trailing characters")
  expect_error(fromjs(paste0("{", paste(sprintf('"k%d": 1', 1:60000), collapse = ","), ", 3: 1}")),
               "expected a key in double quotes")
  expect_error(fromjs(paste0("{", paste(sprintf('"k%d": 1', 1:60000), collapse = ","), ', "x" 1}')), "expected ':'")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), " 1]")), "expected ',' or '\\]'")
  big <- paste0("{", paste(sprintf('"k%d": 1', 1:60000), collapse = ","), ' "x": 1}')
  expect_error(fromjs(big), "expected ',' or '\\}'")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), ",")), "unexpected end of the text")
  expect_error(fromjs(paste0("[", paste(rep("1", 1e5), collapse = ","), ", 9007199254740993.0]")),
               "a whole number beyond 2\\^53 written as a decimal")
  # the direct .Call refuses bytes that are not UTF-8 instead of handing back an invalid CHARSXP
  expect_error(.Call(C$C_rmbl_json_fast, rawToChar(as.raw(c(0x22, 0xff, 0x22))), FALSE, FALSE), "not valid UTF-8")
  expect_error(.Call(C$C_rmbl_json_fast, rawToChar(as.raw(c(0x22, 0xc0, 0x80, 0x22))), FALSE, FALSE), "not valid UTF-8")
  bad <- rawToChar(as.raw(c(0x22, 0xed, 0xa0, 0x80, 0x22)))
  expect_error(.Call(C$C_rmbl_json_fast, bad, FALSE, FALSE), "not valid UTF-8")
  expect_error(.Call(C$C_rmbl_json_fast, rawToChar(as.raw(c(0x22, 0xf0, 0x9f))), FALSE, FALSE), "not valid UTF-8")
  expect_identical(fromjs('{"é": "ü\\u00e9\\ud83d\\ude00"}')[[1L]], "üé\U0001f600")
})

# ---- #6, #7: the command line's near-miss and key rules --------------------------------------

test_that("#6: a trailing question mark does not send a near-miss command to a model", {
  for (x in c("dat list?", "conifg set openai.api_key?", "modles --route openai?", "dcotor please?")) {
    expect_false(.bl_bare_question(x), info = x)
  }
  expect_true(.bl_bare_question("what does config do?"))
  expect_true(.bl_bare_question("doctor says the data is fine, is it?"))
})

test_that("#7: key shapes that reached a model are keys", {
  expect_true(.bl_key_shaped("abc123.def456.ghi789_jkl012mno345"))
  expect_true(.bl_key_shaped("FAKEKXsOCOxzNZfl"))
  expect_true(.bl_key_shaped("abcd1234efgh ijkl5678mnop qrst9012uvwx"))
  expect_false(.bl_key_shaped("survey_design_replicates"))
  expect_false(.bl_key_shaped("population2021 is the table"))
  expect_false(.bl_key_shaped("Rmoriebricklayer"))
  k <- paste0("sk-", strrep("a1b2c3d4e5f", 4))
  kz <- paste0(substring(k, 1, 11), "​", substring(k, 12))
  expect_false(.bl_bare_question(paste("why", kz)))
})

test_that("#7: a model name is a name, not a key", {
  for (m in c("gpt-4o-mini", "claude-sonnet-4-5", "llama3.1:8b", "mistral-large-latest", "o3-mini-2025-01-31")) {
    expect_identical(.bl_model_name(m), m)
  }
  for (m in c("bf3RrVH-ZUyZo5t-u075Nfn-0JumknD", "123e4567-e89b-12d3-a456-426614174000", "FAKEKXsOCOxzNZfl",
              "Iiduwvbghimq8817", "abcDEF123ghiJKL", "sk-proj-abcdefghijklmnop", "a1B2c3D4e5F6g7H8i9")) {
    expect_error(.bl_model_name(m), "looks like a key", info = m)
  }
  expect_null(.bl_model_name(NULL))
  expect_error(.bl_model_name(c("a", "b")), "one model name")
})

# ---- #11: the long tail -----------------------------------------------------------------------

test_that("#11: col = is checked by the field, density, Knox and leave-one-out plots", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  set.seed(7)
  b <- data.frame(lon = stats::runif(60, -80, -79), lat = stats::runif(60, 43, 44), t = sample(1:30, 60, TRUE))
  expect_error(plot(knoxtst(b$lon, b$lat, b$t, 0.1, 3), col = "notacolor"), "`col` must be colours")
  expect_error(plot(crmdens(b$lon, b$lat), col = "notacolor"), "`col` must be colours")
  expect_no_error(plot(crmdens(b$lon, b$lat), col = c("white", "red")))
  c0 <- matrix(0, 15, 15)
  c0[4, 8] <- 1
  f <- advdif2d(c0, u = 1, v = 0, kx = 0.5, ky = 0.5, dx = 1, dy = 1, dt = 0.2, nsteps = 5)
  expect_error(plot(f, col = "notacolor"), "`col` must be colours")
  expect_no_error(plot(f, col = c("white", "blue")))
  p <- polex()
  lo <- loounit(p, "district", "month", "crmrate", "reformed")
  expect_error(plot(lo, col = "notacolor"), "`col` must be colours")
  expect_no_error(plot(lo, col = "steelblue"))
  expect_no_error(plot(lo, palette = "grey"))
})

test_that("#11: smrystat() on an accumulator, stepchg() near the double's range, fylbl() of a half year", {
  expect_error(onlsmry(c(1, 2, 3, NA, Inf)), "`x` has infinite values")
  acc <- onlsmry(c(1, NA, 3))
  acc$state[3L] <- NaN
  expect_true(is.nan(smrystat(acc)[["skewness"]]))
  r <- stepchg(c(1e300, -1e300, 1e300, 1e300, -1e300, 1), nperm = 100)
  expect_true(is.finite(r$statistic))
  expect_true(is.finite(r$p_value))
  expect_error(fylbl(2024.5), "whole years")
  expect_identical(fylbl(2024), "2023/24")
})

test_that("#11: an interrupt a native call took and a handler swallowed is raised again", {
  expect_null(.bl_unless_interrupted(simpleError("something else")))
  expect_identical(.bl_unless_interrupted(simpleError("x"), "v"), "v")
  seen <- withRestarts(
    tryCatch(.bl_unless_interrupted(simpleError("C_rmbl_http_download: interrupted")),
             interrupt = function(i) "interrupt"),
    abort = function() "aborted")
  expect_identical(seen, "interrupt")
  seen <- withRestarts(.bl_unless_interrupted(simpleError("interrupted")), abort = function() "aborted")
  expect_identical(seen, "aborted")
})

test_that("wall_limit() widens a bound on a loaded machine and under covr", {
  withr::local_envvar(NOT_CRAN = "true", R_COVR = "true")
  expect_identical(wall_limit(2), 100)
  withr::local_envvar(NOT_CRAN = "false", R_COVR = NA)
  expect_identical(wall_limit(2), 100)
  withr::local_envvar(NOT_CRAN = "true", R_COVR = NA)
  expect_gte(wall_limit(2), 2)
})

test_that("#3: the row-key digests read a column as a set without sorting it", {
  h <- function(x) .Call(C_rmbl_svy_msethash, x)
  x <- c(3, 1, 2, 2, -0, NA, NaN, 1e300)
  expect_identical(nchar(h(x)), 32L)
  expect_identical(h(x), h(rev(x)))
  expect_identical(h(x), h(sample(x)))
  # -0 is 0 and every NaN is NA, as the row keys read them
  expect_identical(h(c(0, 1)), h(c(-0, 1)))
  expect_identical(h(c(NaN, 1)), h(c(NA_real_, 1)))
  # a value edited, added or dropped changes the digest
  expect_false(h(x) == h(replace(x, 1, 3.0000001)))
  expect_false(h(x) == h(x[-1]))
  expect_false(h(x) == h(c(x, 0)))
  expect_identical(h(numeric()), h(numeric()))
  expect_false(h(numeric()) == h(0))
  expect_error(h(1L), "double vector")
  # a reorder of the data is still told from an edit, and the same keys come back in another order
  d <- data.frame(y = c(1, 2, 3, 4), w = c(1, 1, 2, 2), g = c("a", "b", "a", "b"))
  k1 <- .svy_rowkey_digests(d)
  k2 <- .svy_rowkey_digests(d[4:1, ])
  expect_identical(k1$sorted, k2$sorted)
  expect_false(identical(k1$ordered, k2$ordered))
  expect_identical(k1$colsor, k2$colsor)
  d$y[2] <- 2.5
  k3 <- .svy_rowkey_digests(d)
  expect_false(identical(k1$sorted, k3$sorted))
  expect_false(identical(k1$colsor[["y"]], k3$colsor[["y"]]))
  expect_identical(k1$colsor[["w"]], k3$colsor[["w"]])
})

test_that("#3: one replicate column is read against the weight in one native pass", {
  s <- function(r, w, idv = NULL, rn = NULL) .Call(C_rmbl_svy_colsumm, as.numeric(r), as.numeric(w), idv, rn)
  w <- c(1.5, 2, 3, 4)
  x <- s(w, w)
  expect_true(x$same)
  expect_identical(x$maxrel, 0)
  expect_false(x$anyzero)
  expect_false(x$const)
  expect_false(x$isid)
  expect_false(x$isrow)
  expect_identical(x$hk, 1:4)
  expect_equal(x$fullfac, 1)
  # a jackknife replicate: one row out, the others scaled by 4/3
  r <- c(0, w[-1] * 4 / 3)
  x <- s(r, w)
  expect_false(x$same)
  expect_true(x$anyzero)
  expect_identical(x$hk, 2:4)
  expect_equal(x$fullfac, 4 / 3)
  expect_equal(x$maxrel, 1)
  # the row numbers, the row names and the id's values are recognised
  expect_true(s(1:4, w)$isrow)
  expect_true(s(c(10, 20, 30, 40), w, rn = c(10, 20, 30, 40))$isrow)
  expect_false(s(c(10, 20, 30, 40), w)$isrow)
  expect_true(s(c(7, 7, 8, 9), w, idv = c(7, 7, 8, 9))$isid)
  expect_false(s(c(7, 7, 8, 9), w, idv = c(7, 7, 8, 10))$isid)
  expect_true(s(c(5, 5, 5, 5), w)$const)
  # factors that differ by row: no single factor
  expect_true(is.na(s(c(1, 2, 3, 5), w)$fullfac))
  # no row kept: no factor and no rows
  x <- s(c(0, 0, 0, 0), w)
  expect_true(is.na(x$fullfac))
  expect_identical(x$hk, integer())
  expect_true(x$const)
  # a weight of zero is floored, not divided by
  x <- s(c(1, 2, 3, 4), c(0, 2, 3, 4))
  expect_true(is.finite(x$maxrel))
  expect_identical(x$hk, 2:4)
  # the first 4,096 rows kept, no more
  n <- 10000
  x <- s(rep(2, n), rep(1, n))
  expect_identical(x$hk, 1:4096)
  expect_equal(x$fullfac, 2)
  expect_identical(s(numeric(), numeric())$maxrel, 0)
  expect_error(s(1:3, 1:2), "one length")
  expect_error(.Call(C_rmbl_svy_colsumm, 1L, 1, NULL, NULL), "double vectors")
  # an id of another length or type is ignored, not read out of bounds
  expect_false(s(w, w, idv = c(1, 2))$isid)
  expect_false(s(w, w, idv = 1:4)$isid)
})

test_that("#3: the linearized variance centres each stratum in place and matches survey", {
  skip_if_not_installed("survey")
  set.seed(31)
  n <- 400
  d <- data.frame(y = rnorm(n), x = runif(n, 1, 2), w = runif(n, 1, 3),
                  s = rep(1:8, each = 50), p = rep(1:80, each = 5),
                  g = sample(c("a", "b", "c"), n, TRUE), stringsAsFactors = FALSE)
  des <- svydes(d, "w", strata = "s", psu = "p")
  sd <- survey::svydesign(ids = ~p, strata = ~s, weights = ~w, data = d)
  for (stat in c("mean", "total")) {
    e <- svyest(des, d, "y", by = "g", stat = stat)
    f <- if (stat == "mean") survey::svyby(~y, ~g, sd, survey::svymean) else survey::svyby(~y, ~g, sd, survey::svytotal)
    expect_equal(e$estimate, unname(f$y), tolerance = 1e-10)
    expect_equal(e$se, unname(survey::SE(f)), tolerance = 1e-8)
  }
  e <- svyest(des, d, "y", by = "g", stat = "ratio", den = "x")
  f <- survey::svyby(~y, ~g, sd, survey::svyratio, denominator = ~x)
  expect_equal(e$estimate, unname(f[[2L]]), tolerance = 1e-10)
  expect_equal(e$se, unname(survey::SE(f)), tolerance = 1e-8)
  e <- svyest(des, d, "g", stat = "proportion")
  f <- survey::svymean(~g, sd)
  expect_equal(e$estimate, unname(as.numeric(f)), tolerance = 1e-10)
  expect_equal(e$se, unname(survey::SE(f)), tolerance = 1e-8)
  # a lonely PSU adjusted: centred on the grand mean, as survey does
  d2 <- d[!(d$s == 1 & d$p != 1), ]
  old <- options(survey.lonely.psu = "adjust")
  on.exit(options(old), add = TRUE)
  e <- svyest(svydes(d2, "w", strata = "s", psu = "p", lonely = "adjust"), d2, "y", by = "g")
  f <- survey::svyby(~y, ~g, survey::svydesign(ids = ~p, strata = ~s, weights = ~w, data = d2), survey::svymean)
  expect_equal(e$se, unname(survey::SE(f)), tolerance = 1e-8)
})

test_that("#3: domains beyond one block of columns get the same variance as the closed form", {
  # one block holds floor(2^24 / n) columns: 16,385 rows and 1,024 domains are two blocks
  set.seed(32)
  n <- 16385L
  d <- data.frame(y = rnorm(n), w = runif(n, 1, 3), h = sample(sprintf("h%04d", 1:1024), n, TRUE),
                  stringsAsFactors = FALSE)
  des <- svydes(d, "w")
  e <- svyest(des, d, "y", by = "h")
  expect_identical(nrow(e), 1024L)
  # each row its own PSU in one stratum: se^2 = n/(n - 1) * sum((z - mean z)^2) over every row, with
  # z = w (y - est) / sum(w) on the domain's rows and 0 elsewhere
  est <- tapply(d$w * d$y, d$h, sum) / tapply(d$w, d$h, sum)
  D <- tapply(d$w, d$h, sum)
  z <- d$w * (d$y - est[d$h]) / D[d$h]
  s2 <- tapply(z^2, d$h, sum)
  zbar <- tapply(z, d$h, sum) / n
  se <- sqrt(n / (n - 1) * (s2 - n * zbar^2))
  expect_equal(e$estimate, as.numeric(est[e$h]), tolerance = 1e-12)
  expect_equal(e$se, as.numeric(se[e$h]), tolerance = 1e-10)
})

test_that("battery: shrs() refuses a total that is not one number", {
  stops <- data.frame(division = c("N", "S"), stops = c(4, 6))
  expect_error(shrs(1e308, stops, by = "division"), "`total` must be NULL, one finite non-negative number")
  expect_error(shrs(stops, stops, total = stops), "`total` must be NULL, a column name or one finite")
  expect_error(shrs(stops, stops, total = c(1, 2)), "`total` must be NULL")
  expect_error(shrs(stops, stops, total = Inf), "`total` must be NULL")
  expect_error(shrs(stops, stops, total = -1), "`total` must be NULL")
  expect_error(shrs(stops, stops, total = NA_character_), "`total` must be NULL")
  expect_error(shrs(c(5, 2), total = NaN), "`total` must be NULL")
  expect_equal(shrs(stops, stops, by = "division", total = 20)$share, c(20, 30))
  expect_equal(shrs(c(5, 2), total = 10L)$share, c(50, 20))
})
