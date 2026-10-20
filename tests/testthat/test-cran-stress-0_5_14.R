testthat::skip_on_cran()  # battery: runs in CI and locally; CRAN runs the correctness core
# Findings of the CRAN stress test of 0.5.14 (r-universe tarball, git 1c19b00), each with its fix.

ns <- function(f) get(f, envir = asNamespace("rmoriebricklayer"))

test_that("#4: an argument error raised inside a C++ entry point leaves nothing behind and reads as before", {
  C <- function(f) asNamespace("rmoriebricklayer")[[f]]
  expect_error(.Call(C("C_rmbl_uniforms"), NaN, 1), "`n` must be")
  expect_error(.Call(C("C_rmbl_merkle_root"), list(1, "a"), 1L), "^each chunk must be a raw vector$")
  expect_error(.Call(C("C_rmbl_http_get"), NA_character_, 5L, "a: b", FALSE), "`url` must be a non-missing string")
  # the message carries no call (the barrier raises it, as the package's R errors are raised)
  e <- tryCatch(.Call(C("C_rmbl_merkle_root"), list(1), 1L), error = function(e) e)
  expect_null(conditionCall(e))
})

test_that("#7: the reservoir loop answers an interrupt", {
  skip_on_cran()
  skip_on_os("windows")
  skip_if(!nzchar(Sys.which("python3")), "python3 runs the probe")
  # 3e9 items took 37.9 s through a Ctrl-C; the loop now takes it
  r <- interrupt_probe("rsvidx(3e9, 1)", after = 1)
  skip_if(startsWith(r, "inconclusive"), r)
  expect_identical(r, "interrupt")
})

test_that("stepchg(): an enumerated null counts the observed ordering once", {
  r <- stepchg(c(1, 2, 1, 2, 5, 6))
  expect_match(r$method, "exact over all 720 orderings")
  # every ordering scored, the observed one among them: a multiple of 1/720
  expect_equal(r$p_value * 720, round(r$p_value * 720), tolerance = 1e-9)
  # drawn permutations keep the +1
  set.seed(1)
  r2 <- stepchg(c(1, 2, 1, 2, 5, 6, 7, 8, 9, 10), nperm = 99)
  expect_equal(r2$p_value * 100, round(r2$p_value * 100), tolerance = 1e-9)
})

test_that("trndtst(): a constant series has p = 1 at every length", {
  expect_identical(trndtst(rep(3, 6))$p_value, 1)
  expect_identical(trndtst(rep(3, 12))$p_value, 1)
  expect_identical(trndtst(rep(3, 40), alt = "increasing")$p_value, 1)
})

test_that("cnttrnd(): zeros at one end have no finite trend, and say so", {
  expect_warning(r <- cnttrnd(c(0, 0, 5)), "no finite estimate")
  expect_identical(r$rateratio, Inf)
  expect_true(is.na(r$lower) && is.na(r$upper) && is.na(r$p_value))
  expect_warning(r <- cnttrnd(c(5, 0, 0)), "reported as 0")
  expect_identical(r$rateratio, 0)
  # an ordinary series is untouched
  expect_silent(r <- cnttrnd(c(20, 18, 15, 13, 12)))
  expect_true(is.finite(r$rateratio) && r$rateratio < 1)
})

test_that("valrules(): a table of no rows fails no row-wise rule", {
  rl <- list(rul("present", function(v) !is.na(v), col = "a"),
             rul("one row at least", function(d) nrow(d) > 0))
  out <- valrules(data.frame(a = numeric()), rl)
  expect_identical(names(out), "one row at least")
})

test_that("onlsmry(): values far from zero keep their digits", {
  set.seed(1)
  x <- 1e8 + stats::rnorm(1000)
  a <- onlsmry()
  for (i in seq(1, 1000, by = 100)) a <- smryupd(a, x[i:(i + 99)])
  expect_lt(abs(smrystat(a)[["variance"]] / stats::var(x) - 1), 1e-9)
  expect_lt(abs(smrystat(onlsmry(x))[["variance"]] / stats::var(x) - 1), 1e-13)
})

test_that("seeds: knoxtst() and cpsfals() take every seed up to 2^53 - 1", {
  set.seed(2)
  n <- 30
  expect_s3_class(knoxtst(stats::runif(n), stats::runif(n), stats::runif(n), 0.2, 0.2, nsim = 19, seed = 2^40),
                  "rmbl_knox")
  expect_error(knoxtst(stats::runif(n), stats::runif(n), stats::runif(n), 0.2, 0.2, nsim = 19, seed = -2^31),
               "from -2147483647 to 2\\^53 - 1")
  d <- data.frame(y = stats::rnorm(20), x = stats::rnorm(20))
  f <- cpsfals(d, function(z) stats::cor(z$x, z$y), n = 19, seed = 2^40, trt = "x")
  expect_identical(f$seed, 2^40)
})

test_that("the URL gate refuses 6to4 and Teredo addresses that carry a private one", {
  chk <- function(u) .Call(asNamespace("rmoriebricklayer")$C_rmbl_url_check, u, FALSE, FALSE, FALSE)
  expect_match(chk("https://[2002:7f00:1::]/"), "local or private")
  expect_match(chk("https://[2002:a00:7::]/"), "local or private")       # 10.0.0.7
  expect_match(chk("https://[2001:0:4136:e378::1]/"), "local or private")  # Teredo
  expect_match(chk("https://[64:ff9b:1::a00:7]/"), "local or private")
  expect_identical(chk("https://[2002:808:808::]/"), "")                 # 8.8.8.8 is public
  expect_identical(chk("https://[2606:4700:4700::1111]/"), "")
})

test_that("wbsave() sends no address on your own network to the public archive", {
  for (u in c("https://10.0.0.7/", "http://192.168.1.2/a", "https://intranet/", "https://printer.local/x")) {
    expect_error(wbsave(u, ak = "a", sk = "b"), "not a public address", info = u)
  }
})

test_that("the manifest is fetched with a size cap", {
  got <- NULL
  local_mocked_bindings(.bl_data_get = function(path, dest, timeout = 600, max_bytes = 2^31) {
    got <<- max_bytes
    writeLines('{"datasets": [{"key": "a/b"}]}', dest)
  })
  withr::local_options(rmoriebricklayer.dcache = withr::local_tempdir())
  dmnf(refresh = TRUE)
  expect_identical(got, 32 * 2^20)
})

test_that("JSON: the native path parses what the R parser parses, and gives way on what it says", {
  P <- ns(".rmbl_json_parse")
  nat <- ns(".rmbl_native")
  slow <- function(t, ...) {
    nat$json <- FALSE
    on.exit(nat$json <- NULL)
    tryCatch(P(t, ...), error = function(e) conditionMessage(e), warning = function(w) conditionMessage(w))
  }
  fast <- function(t, ...) {
    nat$json <- NULL
    tryCatch(P(t, ...), error = function(e) conditionMessage(e), warning = function(w) conditionMessage(w))
  }
  docs <- c('{"a":1,"b":[true,false,null],"c":{"d":"\\u00e9\\ud83d\\ude00"}}', '[1.5,-0,2147483648,1e400]',
            '"a\\nb\\"c\\\\"', '{}', '[]', '[[[]]]', 'null', '{"a":1,"a":2}', '[01]', '{"a" 1}', '"\\ud83d"',
            '"\\u0000"', '9007199254740993', '9.007199254740993e15', '[1,]', paste0(strrep("[", 101), strrep("]", 101)),
            '"été 中"', ' [ 1 , 2 ] ', '[1] x', '"tab\there"')
  for (d in docs) {
    expect_identical(fast(d), slow(d), info = d)
    expect_identical(fast(d, duplicate_keys = "keep", bigint_as_char = TRUE),
                     slow(d, duplicate_keys = "keep", bigint_as_char = TRUE), info = d)
  }
  # a large reply in well under a second (85 s for 15 MiB before)
  big <- paste0("[", paste(rep('{"id":12,"name":"abcdefghij","v":[0.25,1e-3,true]}', 50000), collapse = ","), "]")
  t <- system.time(v <- P(big))[["elapsed"]]
  expect_length(v, 50000L)
  expect_lt(t, wall_limit(5))
})

test_that("CSV: NUL bytes are dropped before quotes are read, as read.csv(skipNul = TRUE) drops them", {
  ours <- ns(".bl_csv_from_bytes")
  ref <- function(b) {
    f <- withr::local_tempfile(fileext = ".csv")
    writeBin(b, f)
    suppressWarnings(utils::read.csv(f, stringsAsFactors = FALSE, skipNul = TRUE))
  }
  B <- as.raw(c(0xEF, 0xBB, 0xBF))
  z <- as.raw(0)
  cases <- list(c(charToRaw("a\n\""), z, charToRaw("\"\n")),                 # a line of "" with a NUL: blank
                c(charToRaw("a\n\"x\""), z, charToRaw("\"y\"\n")),            # "x"<NUL>"y" is "x""y"
                c(charToRaw("a,c\n"), z, B, charToRaw("\n")),                 # a NUL before the mark
                c(charToRaw("a\n\"\""), B, charToRaw("\nq\n")),               # the mark after an empty ""
                charToRaw("a,b\n\"x\"y\",z\",1\n"),                          # a reopened quote holds the comma
                charToRaw("a,b\n\"x\"y\"\r\n\"q,1\n"))
  # read.csv() drops a mark at the start of a line only in a UTF-8 locale; the reader drops it
  # everywhere, so the two mark cases are compared there (C-locale check of 1.0.0)
  mark <- c(FALSE, FALSE, TRUE, TRUE, FALSE, FALSE)
  for (i in seq_along(cases)) {
    if (mark[i] && !l10n_info()[["UTF-8"]]) next
    b <- cases[[i]]
    expect_identical(ours(b), ref(b), info = encodeString(rawToChar(b[b != z])))
  }
  expect_error(ours(charToRaw("a\n\"x\"y\"\n")), "never closes")
})

test_that("CLI: three-letter and hyphenated near misses, short lines naming a file, dense keys", {
  bq <- ns(".bl_bare_question")
  for (q in c("dat list", "xplain-rror?", "urls.txt?", "my urls.txt", "is AbCdEf1234567890 my key?",
              "check k3j9sq2wab7x_m4n8pq1zrt5v_c9d2 ok?")) {
    expect_false(bq(q), info = q)
  }
  for (q in c("how do I fit a survey design?", "what is population2021 in census?",
              "are there functions for rates?", "how do I read my data.csv file into R?")) {
    expect_true(bq(q), info = q)
  }
  expect_error(llmask("why?", model = "AbCdEf1234567890xyz"), "looks like a key")
  expect_error(llmask("why?", model = "sk-sVau8MGU1achkc82m2vR"), "looks like a key")
})

test_that("svydes(): a post-stratified JK1 set on a post-stratum subset is accepted", {
  set.seed(5)
  # 15 PSUs of 4 rows; post-strata cut across them; the replicates post-stratified to fixed totals
  psu <- rep(1:15, each = 4)
  st <- rep(c("E", "H", "M", "E"), 15)
  st[psu > 10 & st == "H"] <- "E"
  w <- stats::runif(60, 5, 15)
  tot <- tapply(w, st, sum)
  post <- function(v) {
    s <- tapply(v, st, sum)
    v * as.numeric(tot[st] / s[st])
  }
  w0 <- post(w)
  R <- sapply(1:15, function(j) post(ifelse(psu == j, 0, w * 15 / 14)))
  y <- stats::rnorm(60)
  d <- data.frame(y = y, w = w0, st = st)
  h <- st == "H"
  des <- svydes(d[h, ], "w", reps = R[h, ], type = "jk1")
  est <- svyest(des, d[h, ], "y")
  th <- sum(w0[h] * y[h]) / sum(w0[h])
  tb <- apply(R[h, ], 2, function(r) sum(r * y[h]) / sum(r))
  expect_equal(est$se, sqrt(14 / 15 * sum((tb - th)^2)), tolerance = 1e-10)
  # an unadjusted set with the weight passed beside it is still refused
  J <- sapply(1:15, function(j) ifelse(psu == j, 0, w * 15 / 14))
  # (unnamed: a column named as the weight is set aside, as documented)
  expect_error(svydes(data.frame(y = y, w = w), "w", reps = unname(cbind(J, w)), type = "jk1"),
               "full-sample weight")
})

test_that("hostile arguments: each is refused in words, with no call (a battery of 38,836 calls, 306 functions)", {
  worded <- function(expr) {
    e <- tryCatch({
      force(expr)
      NULL
    }, error = function(e) e)
    expect_s3_class(e, "error")
    expect_null(conditionCall(e))
  }
  df <- data.frame(a = 1:2)
  worded(ctkyfnc(1:10, k = "x"))
  worded(csdev(1:10, ddof = df))
  worded(cmad(1:10, const = list(1)))
  worded(stepchg(c(1, 2, 1, 2, 5, 6), nperm = NULL))
  worded(stepchg(c(1, 2, 1, 2, 5, 6), minseg = NA))
  worded(mcartst(data.frame(a = c(1, NA, 3, 4), b = c(2, 3, NA, 5)), maxit = NA))
  worded(hilltlidx(c(1, 2, 3, 10, 20, 50), mintl = "x"))
  worded(scanadj(data.frame(p_value = c(0.01, 0.2)), meth = NA))
  worded(scanadj(data.frame(p_value = c(0.01, 0.2)), alpha = NULL))
  worded(bldl("https://example.org/a", tempfile(), size = df))
  worded(explerr("`x` must be numeric", n = list(1)))
  worded(tojs(1:3, pretty = NA_real_))
  worded(jsunser("1"))
  worded(fromjs(NA_character_))
  worded(mksyncsv(list(columns = list(a = list(type = "normal"))), tempfile(), nrows = 2^31))
  worded(fylbl(2024, sep = function(x) x))
  worded(deccodes(c("1", "2"), c(`1` = "a", `2` = "b"), keepna = NA))
  worded(cipw(c(0, 1, 1), c(0.2, 0.5, 0.7), trimlo = NA))
  worded(fnllim(c(10, 20), lvls = list(0.95)))
  worded(missgrid(data.frame(a = c(1, NA)), width = NA))
  e <- new.env()
  worded(asciifb(e))
  worded(cpsatst(list(), key = NULL, note = e))
  set.seed(4)
  d <- data.frame(y = stats::rnorm(20), x = stats::rnorm(20))
  worded(cpspwr(d, function(z) stats::cor(z$x, z$y), function(z, s) z, trt = "x", reps = Sys.Date()))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  worded(plotlrnz(c(1, 2, 3, 10), col = 1e10))
  worded(plotlrnz(c(1, 2, 3, 10), col = "not a colour"))
  worded(plotlrnz(c(1, 2, 3, 10), main = list("a")))
})

test_that("a Hawkes horizon is no allocation: constant baselines need no grid, a sinusoidal one is capped", {
  set.seed(1)
  times <- sort(stats::runif(60, 0, 2^31))
  r <- chwkres(times, 2^31, kernel = "exponential", par = c(log(60 / 2^31), 0.2, 1e-6))
  expect_length(r, 60L)
  expect_error(chwkres(times, 2^31, kernel = "exponential", base = "sinusoidal",
                                     par = c(log(60 / 2^31), 0, 0, 0, 0.2, 1e-6)), "at most 4194304 days")
})

test_that("a time limit ends cpsfals() and cpspwr(); the statistic's own errors are NA", {
  slow <- function(z) {
    Sys.sleep(0.05)
    stats::cor(z$x, z$y)
  }
  set.seed(5)
  d <- data.frame(y = stats::rnorm(30), x = stats::rnorm(30))
  t0 <- proc.time()[["elapsed"]]
  r <- tryCatch({
    setTimeLimit(elapsed = 1, transient = TRUE)
    cpsfals(d, slow, trt = "x", n = 999)
  }, error = function(e) conditionMessage(e), finally = setTimeLimit())
  expect_match(r, "time limit")
  expect_lt(proc.time()[["elapsed"]] - t0, wall_limit(10))
})

test_that("the survey row keys from C are the keys the R arithmetic made", {
  old <- function(v) {
    fold <- function(x) x - 2147483647 * floor(x / 2147483647)
    # the value, not its bits: -0 is 0 and every NaN is NA (final audit of 1.0.0, #3b)
    v[v == 0] <- 0
    v[is.nan(v)] <- NA_real_
    b <- readBin(writeBin(v, raw()), "integer", n = 2L * length(v))
    fold(fold(b[c(TRUE, FALSE)]) * 65599 + b[c(FALSE, TRUE)])
  }
  C <- asNamespace("rmoriebricklayer")
  v <- c(stats::rnorm(1000), NA, NaN, Inf, -Inf, 0, -0, 1e308, .Machine$double.xmin)
  expect_identical(.Call(C$C_rmbl_svy_dblcode, v), old(v))
  expect_false(anyNA(.Call(C$C_rmbl_svy_dblcode, v)))
  expect_identical(.Call(C$C_rmbl_svy_dblcode, c(-0, NaN)), .Call(C$C_rmbl_svy_dblcode, c(0, NA)))
  expect_identical(.Call(C$C_rmbl_sha256_real, v), csha256(writeBin(v, raw())))
})

test_that("every new refusal is reached (one call per branch)", {
  w <- function(expr, pat) expect_error(expr, pat)
  d <- data.frame(v = c(10, 12, 15), p = 2020:2022)
  w(anltab(d, "v", "p", by = 1), "`by` must be one or more column names")
  w(anltab(d, "v", "p", suplim = -1), "`suplim` must be one non-negative number")
  w(stdinc(c(1, 2), c(1, 2), area = c("a", "b", "c")), "`area` must be NULL or one label per area")
  w(ebrates(c(1, 2), c(1, 2), area = c("a", "b", "c")), "`area` must be NULL or one label per area")
  w(bandvals(c("0-9", "10+"), openupfac = -1), "`openupfac` must be one positive number")
  w(bandsens(c("0-9", "10+"), c(5, 3), stat = 1), "`stat` must be a function")
  f <- tempfile()
  writeLines("x", f)
  w(usecpstmpl(f), "is a file, not a directory")
  cat_d <- data.frame(g = c("a", "b"))
  w(audcats(cat_d, cols = 1), "`cols` must be column names")
  w(audcats(cat_d, cols = "zz"), "`cols` names no column of `data`: zz")
  w(orchk(matrix(1:4, 2, dimnames = list(c("a", "b"), NULL)), ref = c("a", "b"), rptd = 1),
    "`ref` must be one group label")
  w(wrrcdmnf(structure(list(), class = "bricklayer_recode_manifest"), NULL), "`path` must be a file path")
  w(relbl(as.raw(1:2), c(a = "b")), "`x` must be a vector of labels")
  w(xfrvrf(c(1, 2), c(`1` = 1), codebook = list(a = 1)), "`codebook` must be a named vector")
  w(dtctloc(envloc = c("a", "b")), "`envloc` must be one string")
  w(cunif(3e9, 1), "`n` must be at most 2147483647")
  w(rsvidx(10, 3e9), "`k` must be at most 2147483647")
  w(capenv(1), "`pkgs` must be package names")
  w(valsch(data.frame(a = 1), prov = 1), "`prov` must be a provenance list")
  w(recrd(1, "a", 1, 1), "`man` must be a manifest")
  w(wrmnfjs(1, tempfile()), "`man` must be a manifest")
  m <- mkmnf(list(project = "t"), env = FALSE)
  w(wrsmrytxt(m, tempfile(), character()), "`outdir` is not a directory")
  w(wrsmrytxt(m, tempdir(), character(), contact = 1), "`contact` must be text")
  w(mksyncol(1, 3), "`spec` must be a column spec list")
  w(mksyncol(list(type = "normal"), -1), "`n` must be a single non-negative whole number")
  w(mksyncsv(list(columns = list()), tempfile(), nrows = 0), "`nrows` must be one whole number of rows")
  w(llmmdls(route = 1), "`route` must be a single route name")
  w(llmask("why?", model = 1), "`model` must be one model name")
  ed <- data.frame(y = stats::rnorm(20), e = stats::rnorm(20), c1 = stats::rnorm(20))
  w(exprspplr(ed, "y", "e", "c1", estr = "no_such_function_zz"), "`estr` names no function")
  w(exprspplr(ed, "y", "e", "c1", estr = 1), "`estr` must be a function")
  w(exprspplr(ed, "y", "e", "c1", estr = function(x) x), "`estr` failed on the full sample")
  w(vrfpol(1), "`poll` must be one pollutant name")
  w(falsfam(list()), "`x` must hold at least one")
  w(profcols(data.frame(a = 1:3), qnts = 2), "`qnts` must be probabilities")
  pb <- pubbnd(c(10, 20), rnd = 5)
  w(chgenv(pb, pb, pop = c(1, 2, 3)), "`pop` must be one number or one per row")
  w(shrs(data.frame(n = 1:3)), "`count` must name the column")
  w(cpsrpt(data.frame(a = 1:3), maxrowsoutl = -1), "`maxrowsoutl` must be one non-negative")
  w(stepchg(1:6, x = matrix(1:6)), "`x` must be one time or position")
  w(certchnvrf(NULL, NULL, attm = "now"), "`attm` must be a single date-time")
  w(yoy(d, "v", "p", by = 1), "`by` must be one or more column names")
  w(yoy(c(1, 2, 3), value = 1), "for a numeric `x`")
  w(yoy(c(1, 2, 3), prd = 1:2), "`prd` must have one entry per value")
  y <- yoy(c(10, 12, 15))
  w(yoyhtml(y, NULL), "`file` must be a file path or a connection")
  w(yoyhtml(y, tempfile(fileext = ".html"), sub = 1), "`sub` must be a single string")
  w(yoyhtml(y, tempfile(fileext = ".html"), notes = 1), "`notes` must be text")
  w(yoypdf(y, tempfile(fileext = ".pdf"), sub = 1), "`sub` must be a single string")
  w(yoypdf(y, tempfile(fileext = ".pdf"), notes = 1), "`notes` must be text")
  set.seed(1)
  w(lagrprt(10, 0, 0, 1, 0, 1, 1, 1, 2, normals = function(x) x), "`normals` failed when called")
  if (requireNamespace("sf", quietly = TRUE)) {
    w(rgnmappts(1, 1, "u", bounds = 1, fields = "a"), "`bounds` must be the path of one")
  }
})

test_that("compiled refusals and branches: JSON escapes, invalid UTF-8, CSV CR in a reopened quote, discard prefix", {
  C <- asNamespace("rmoriebricklayer")
  P <- C$.rmbl_json_parse
  expect_identical(P('"a\\rb\\bc\\fd\\u20ac"'), "a\rb\bc\fd€")
  expect_error(.Call(C$C_rmbl_json_fast, c("a", "b"), FALSE, FALSE), "`txt` must be one string")
  bad <- rawToChar(as.raw(c(0x22, 0xff, 0x22)))
  expect_type(tryCatch(P(bad), error = function(e) "refused"), "character")
  expect_match(.Call(C$C_rmbl_url_check, "https://[100::1]/", FALSE, FALSE, FALSE), "local or private")
  ours <- C$.bl_csv_from_bytes
  expect_identical(ours(charToRaw("a,b\n\"x\"y\"\r\nz\",1\n"))$a, "xy\nz")
  expect_error(.Call(C$C_rmbl_siu_to_iso_date, 1), "single non-NA character string")
  expect_error(.Call(C$C_rmbl_hawkes_rescaled, c(1, 2), 5e6, 1L, c(0, 0, 0, 0), 0.2, 0L, 1),
               "at most 4194304 days")
})

test_that("the last branches: a frame spec, a lone CR in a reopened quote, a bare header, an empty replicate", {
  expect_error(mksyncol(data.frame(type = "normal"), 3), "`spec` must be a column spec list")
  expect_error(mksyncol(list(1, 2), 3), "`spec` must be a column spec list")
  ours <- get(".bl_csv_from_bytes", asNamespace("rmoriebricklayer"))
  expect_identical(ours(charToRaw("a,b\n\"x\"y\"\rz\",1\n"))$a, "xy\nz")
  expect_silent(h <- ours(charToRaw("\"\"\nx")))
  expect_identical(dim(h), c(1L, 0L))
  expect_error(ours(charToRaw("\"\"")), "the CSV cannot be read: first five rows are empty")
  expect_error(get(".rmbl_json_parse", asNamespace("rmoriebricklayer"))(rawToChar(as.raw(c(0x5b, 0xff, 0x5d)))),
               "not valid UTF-8")
  set.seed(8)
  n <- 40
  w <- stats::runif(n, 1, 3)
  B <- sapply(1:20, function(b) w * stats::rpois(n, 1))
  B[, 3] <- 0
  d <- data.frame(y = stats::rnorm(n), w = w)
  expect_s3_class(suppressWarnings(svydes(d, "w", reps = B, type = "bootstrap")), "rmbl_svy_design")
  J <- sapply(1:n, function(j) {
    r <- w * n / (n - 1)
    r[j] <- 0
    r
  })
  J[, 2] <- 0
  r <- tryCatch(suppressWarnings(svydes(d, "w", reps = J, type = "jkn")), error = function(e) e)
  expect_true(inherits(r, "rmbl_svy_design") || inherits(r, "error"))
})
