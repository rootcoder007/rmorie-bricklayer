# Lines PR #56 added that no other test reached (Codecov patch on 84840ac): each is a behaviour,
# checked here directly.

ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

test_that(".rmbl_arg: NULL takes the first choice", {
  expect_identical(ns(".rmbl_arg")(NULL, c("auto", "own")), "auto")
})

test_that("the native CSV reader: no header, a header past 64 columns, text after a quoted field", {
  split <- function(txt) .Call(ns("C_rmbl_csv_split"), charToRaw(txt), FALSE)
  e <- split("")
  expect_identical(e$names, character())
  expect_identical(e$columns, list())
  expect_identical(split("\n\r\n")$names, character())
  wide <- paste0(paste(sprintf("c%d", 1:150), collapse = ","), "\n", paste(1:150, collapse = ","), "\n")
  w <- split(wide)
  expect_identical(w$names, sprintf("c%d", 1:150))
  expect_length(w$columns, 150L)
  expect_identical(w$columns[[150]], 150L)
  # a blank line before a wide header
  expect_identical(split(paste0("\n", wide))$names, sprintf("c%d", 1:150))
  # text after a closing quote is part of the field, as read.csv() appends it
  expect_identical(split("a,b\n\"x\"y,2\n")$columns[[1L]], "xy")
})

test_that("hurwzeta past the double range is the leading term's infinity, not NaN", {
  v <- suppressWarnings(hurwzeta(-60, 1e10))
  expect_identical(v, -Inf)   # zeta(-60, q) is about -q^61 / 61
})

test_that("vrfpol refuses a list, a complex, a flag, a date or text for a number, by type", {
  for (v in list(list(1e6), 1i, "many", TRUE, factor("a"), Sys.Date())) {
    r <- vrfpol("pm25", pop = v)
    expect_identical(r$status, "error")
    expect_match(r$error, sprintf("pop must be a single number, not %s", class(v)[1L]), fixed = TRUE)
  }
  expect_match(vrfpol("pm25", pop = c(1, 2))$error, "not 2 values", fixed = TRUE)
})

test_that("the route on display: a saved `hosted` is shown as retired", {
  withr::local_envvar(MORIE_LLM_ROUTE = "hosted")
  expect_match(ns(".bl_config_effective")("route"), "retired and ignored", fixed = TRUE)
})

test_that("the answer and message caches create their folder, owner-only", {
  skip_on_os("windows")
  d <- file.path(withr::local_tempdir(), "not", "yet")
  withr::local_options(rmoriebricklayer.llmcachedir = d)
  local_mocked_bindings(.bl_answer_cache_on = function() TRUE, .package = "rmoriebricklayer")
  suppressMessages(ns(".bl_answer_put")(strrep("b", 64), "q", "m", "the answer"))
  expect_true(dir.exists(d))
  expect_identical(as.character(file.info(d)$mode), "700")
  d2 <- file.path(withr::local_tempdir(), "msgs")
  withr::local_options(rmoriebricklayer.llmcachedir = d2)
  rm(list = ls(ns(".bl_ee_memo")), envir = ns(".bl_ee_memo"))
  invisible(suppressMessages(explerr("could not find function")))
  expect_true(length(list.files(d2, pattern = "^messages-.*[.]rds$")) == 1L)
})

test_that("survey: a reordered frame is caught by its digests; an empty frame has none; an id replicate is refused", {
  set.seed(5)
  n <- 40
  d <- data.frame(y = rnorm(n), w = runif(n, 1, 2))
  reps <- sapply(1:6, function(b) d$w * stats::rmultinom(1, n, rep(1, n))[, 1] * n / (n - 1))
  des <- svydes(d, w = d$w, reps = reps, type = "bootstrap")
  d2 <- d[c(2:n, 1L), ]
  rownames(d2) <- NULL
  expect_error(svyest(des, d2, "y"), "not the data frame the design was built on")
  rk <- ns(".svy_rowkey_digests")(d[0])
  expect_identical(rk$cols, character())
  d$id <- as.numeric(seq_len(n)) * 1.5
  r2 <- data.frame(id = d$id, reps, stray = d$id)
  expect_error(svydes(d, w = "w", id = "id", reps = r2, type = "bootstrap"), "the id")
})

test_that("reading a large set of messages is announced first, by size and not by name", {
  big <- ns(".bl_ee_big")
  expect_false(big("rmoriebricklayer"))
  expect_true(big("rmoriebricklayer", limit = 10L))
  d <- withr::local_tempdir()
  withr::local_options(rmoriebricklayer.llmcachedir = d)
  local_mocked_bindings(.bl_answer_cache_on = function() TRUE, .bl_ee_big = function(pkgs, limit = 5000L) TRUE,
                        .package = "rmoriebricklayer")
  rm(list = ls(ns(".bl_ee_memo")), envir = ns(".bl_ee_memo"))
  expect_message(ns(".bl_ee_table")("rmoriebricklayer"), "Reading the messages of rmoriebricklayer")
  # the table built under the mock is not left for the tests after this one
  rm(list = ls(ns(".bl_ee_memo")), envir = ns(".bl_ee_memo"))
})

test_that("ask and explain-error read this package unless told otherwise; no other package is named", {
  withr::local_envvar(RMBL_PACKAGES = NA)
  expect_identical(ns(".bl_kn_default_packages")(), "rmoriebricklayer")
  withr::local_envvar(RMBL_PACKAGES = " rmoriebricklayer , stats,,stats ")
  expect_identical(ns(".bl_kn_default_packages")(), c("rmoriebricklayer", "stats"))
  withr::local_envvar(RMBL_PACKAGES = "rmoriebricklayer,no.such.pkg")
  expect_error(explerr("x"), "not installed: no.such.pkg")
  withr::local_envvar(RMBL_PACKAGES = NA)
  # the code names no package built on this one
  src <- unlist(lapply(ls(asNamespace("rmoriebricklayer"), all.names = TRUE), function(n) {
    f <- get(n, envir = asNamespace("rmoriebricklayer"))
    if (is.function(f)) deparse(f) else character()
  }))
  expect_false(any(grepl("\"rmorie\"|\"rmoriedata\"", src)))
})

test_that("a settings folder an earlier version left open is made owner-only", {
  skip_on_os("windows")
  d <- file.path(withr::local_tempdir(), "morie")
  dir.create(d)
  Sys.chmod(d, "0777", use_umask = FALSE)
  ns(".bl_private_dir")(d)
  expect_identical(as.character(file.info(d)$mode), "700")
  # through the settings writer
  withr::local_envvar(XDG_CONFIG_HOME = dirname(d))
  Sys.chmod(d, "0777", use_umask = FALSE)
  llmcfg(ollama.model = "m1")
  expect_identical(as.character(file.info(d)$mode), "700")
})

test_that("config set changes only the setting it sets; the rest of llm.json is kept as written", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
  p <- ns(".bl_config_path")()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  raw <- paste0('{"note": 0.13436424411240122, "list": ["x"], "": "empty", "big": 9007199254740993,',
                ' "ollama.model": "old"}')
  writeLines(raw, p, sep = "")
  llmcfg(ollama.model = "qwen3:8b")
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  for (keep in c("0.13436424411240122", '["x"]', '"": "empty"', "9007199254740993")) {
    expect_true(grepl(keep, txt, fixed = TRUE), info = keep)
  }
  expect_identical(ns(".bl_read_config")()[["ollama.model"]], "qwen3:8b")
  expect_false(grepl('"old"', txt, fixed = TRUE))
  # removing a setting leaves the others too
  llmcfg(ollama.model = NA)
  txt <- paste(readLines(p, warn = FALSE), collapse = "\n")
  expect_true(grepl("0.13436424411240122", txt, fixed = TRUE))
  expect_null(ns(".bl_read_config")()[["ollama.model"]])
  # a new file starts empty and gets the one setting
  unlink(p)
  llmcfg(ollama.model = "m2")
  expect_identical(ns(".bl_read_config")()[["ollama.model"]], "m2")
})

test_that("the native CSV reader reads as read.csv() does at the edges the stress tests found", {
  rc <- function(txt) {
    f <- tempfile(fileext = ".csv")
    writeBin(charToRaw(txt), f)
    utils::read.csv(f, stringsAsFactors = FALSE, skipNul = TRUE)
  }
  ours <- function(txt) ns(".bl_csv_from_bytes")(charToRaw(txt))
  same <- c(padded_header = "a , b ,c\n1,2,3\n",
            Operational_Capacity = " Operational_Capacity ,x\n10,1\n",
            quoted_padded_header = "\" a \",b\n1,2\n",
            crlf_in_quotes = "a,b\n\"x\r\ny\",2\n",
            cr_in_quotes = "a,b\n\"x\ry\",2\n",
            empty_quote_line_2col = "a,b\n1,2\n\"\"\n3,4\n",
            empty_quote_line_1col = "a\n1\n\"\"\n3\n",
            space_then_quoted = "a,b\n \"x\",2\n",
            quoted_then_space = "a,b\n\"x\" ,2\n",
            padded_data = "a,b\n x ,2\n")
  for (k in names(same)) expect_identical(ours(same[[k]]), rc(same[[k]]), label = k)
  # a quote inside an unquoted field: read.csv() swallows the rest of the file; refused in words
  expect_error(ours("a,b\nab\"c,2\n3,4\n"), "a quote inside an unquoted field")
})

test_that("a .csv.gz that is plain text, or that inflates past the in-memory size, reads as read.csv() reads it", {
  txt <- "a,b\n1,x\n2,y\n"
  plain <- tempfile(fileext = ".csv.gz")
  writeBin(charToRaw(txt), plain)
  ref <- utils::read.csv(gzfile(plain), stringsAsFactors = FALSE, skipNul = TRUE)
  expect_identical(ns(".bl_read_csv_gz")(plain), ref)
  gz <- tempfile(fileext = ".csv.gz")
  con <- gzfile(gz, "wb")
  writeLines(c("a,b", sprintf("%d,%s", 1:2000, "v")), con)
  close(con)
  ref <- utils::read.csv(gzfile(gz), stringsAsFactors = FALSE, skipNul = TRUE)
  expect_identical(ns(".bl_read_csv_gz")(gz), ref)
  # under a tiny in-memory size the same table goes the streamed way, with the same result
  expect_identical(ns(".bl_read_csv_gz")(gz, in_memory = 100), ref)
  expect_identical(ns(".bl_read_csv_gz")(plain, in_memory = 5),
                   utils::read.csv(gzfile(plain), stringsAsFactors = FALSE))
})

test_that("survey: rows reordered within strata are refused; a permuted outcome is not a reorder", {
  set.seed(9)
  n <- 60
  d <- data.frame(y = rnorm(n), w = runif(n, 1, 3), st = rep(1:3, each = 20), psu = rep(1:12, each = 5))
  des <- svydes(d, w = d$w, strata = "st", psu = "psu")
  # the rows of each PSU reversed: strata and PSU columns exactly as they were, y and w moved
  o <- unlist(lapply(split(seq_len(n), d$psu), rev), use.names = FALSE)
  d2 <- d[o, ]
  attr(d2, "row.names") <- seq_len(n)
  expect_identical(d2$st, d$st)
  expect_identical(d2$psu, d$psu)
  expect_error(svyest(des, d2, "y"), "not the data frame")
  # a permutation test: y permuted, everything else in place
  d3 <- d
  d3$y <- sample(d3$y)
  expect_s3_class(svyest(des, d3, "y"), "data.frame")
  # y reversed and a column added
  d4 <- d
  d4$y <- rev(d4$y)
  d4$extra <- 1
  expect_s3_class(svyest(des, d4, "y"), "data.frame")
})

test_that("survey: stray replicate columns are refused or said, genuine ones pass in silence", {
  set.seed(11)
  m <- 30
  n <- m * 4
  psu <- rep(seq_len(m), each = 4)
  w <- rep(exp(rnorm(m)), each = 4) * 25
  d <- data.frame(y = rnorm(n), w = w, pid = seq_len(n))
  boot <- sapply(1:40, function(b) {
    k <- stats::rmultinom(1, m, rep(1, m))[, 1]
    w * k[psu]
  })
  jk <- sapply(seq_len(m), function(j) {
    f <- rep(m / (m - 1), m)
    f[j] <- 0
    w * f[psu]
  })
  expect_silent(svydes(d, w = "w", reps = boot, type = "bootstrap"))
  expect_silent(svydes(d, w = "w", reps = jk, type = "jk1"))
  # the weight itself beside bootstrap replicates of 30 PSUs: more equal replicates than chance draws
  expect_warning(svydes(d, w = "w", reps = cbind(boot, as.numeric(w)), type = "bootstrap"),
                 "equal the full-sample weight")
  # a copy of the weight a rounding error off, under a jackknife: refused; under the bootstrap: said
  expect_error(svydes(d, w = "w", reps = cbind(jk, w * (1 + 1e-11)), type = "jk1"),
               "a copy of the full-sample weight")
  expect_warning(svydes(d, w = "w", reps = cbind(boot, round(w, 2) + 0.001), type = "bootstrap"),
                 "within 1% of the full-sample weight")
  # a constant beside jackknife replicates: one value on every row, which no multiplier of a varying
  # weight is (a jackknife replicate that leaves no row out is genuine on a subset or post-stratified)
  expect_warning(svydes(d, w = "w", reps = cbind(jk, rep(7, n)), type = "jk1"),
                 "one value on every row")
  # a jackknife on a subset whose left-out PSU is elsewhere: the weight times one factor, in silence
  expect_silent(svydes(d, w = "w", reps = cbind(jk, w * m / (m - 1)), type = "jk1"))
  # multipliers in place of the weights (the weights here average about 40)
  mult <- boot / w
  expect_warning(svydes(d, w = "w", reps = mult, type = "bootstrap"), "multipliers")
  # a second column named like the id, holding other values: refused
  r2 <- data.frame(pid = d$pid, boot, pid = rev(d$pid), check.names = FALSE)
  expect_error(svydes(d, w = "w", id = "pid", reps = r2, type = "bootstrap"),
               "has the id's name but not its values")
  # the weight beside the replicates under its own name, 1e-13 off: the weight, set aside
  r3 <- data.frame(w = w * (1 + 1e-13), jk)
  expect_silent(des <- svydes(d, w = "w", reps = r3, type = "jk1"))
  expect_equal(length(des$reps), m)
})

test_that("hurwzeta with a whole q beside the trivial zeros matches mpmath at the exact doubles", {
  # mpmath zeta(s, q) at 60 digits; s and the references are C99 hex floats (statistics stress test
  # of 5e1dce5: 5.4e-8 relative at q = 2 near s = -30)
  ref <- data.frame(
    s = c("-0x1.e000010c6f7a1p+4", "-0x1.e000000044b83p+4", "-0x1.e000000000119p+4", "-0x1.ep+4",
          "-0x1.e000010c6f7a1p+4", "-0x1.e000000044b83p+4"),
    q = c(2, 2, 2, 2, 7, 7),
    v = c("0x1.2aca793b1cb81p+7", "-0x1.b2ff657204b01p-1", "-0x1.ffec5216e9183p-1", "-0x1.0000000000000p+0",
          "-0x1.7818195336b14p+77", "-0x1.7817ed39b28cbp+77"),
    stringsAsFactors = FALSE)
  for (i in seq_len(nrow(ref))) {
    s <- as.numeric(ref$s[[i]])
    want <- as.numeric(ref$v[[i]])
    got <- hurwzeta(s, ref$q[[i]])
    expect_lt(abs(got - want) / abs(want), 1e-13, label = sprintf("zeta(%s, %g)", ref$s[[i]], ref$q[[i]]))
  }
})

test_that("knox close pairs match brute force with a far outlier and with a tiny band", {
  brute <- function(x, y, r) {
    n <- length(x)
    p <- utils::combn(n, 2)
    d <- sqrt(((x[p[1, ]] - x[p[2, ]]) / r)^2 + ((y[p[1, ]] - y[p[2, ]]) / r)^2)
    k <- d <= 1
    paste(p[1, k], p[2, k])
  }
  ours <- function(x, y, r) {
    cp <- ns(".jx_close_pairs")(x, y, r, 1e7)
    sort(paste(pmin(cp$i, cp$j), pmax(cp$i, cp$j)))
  }
  set.seed(3)
  x <- runif(200, 0, 10)
  y <- runif(200, 0, 10)
  expect_identical(ours(x, y, 0.7), sort(brute(x, y, 0.7)))
  # one far outlier, and one beside it
  x2 <- c(x, 1e300, 1e300)
  y2 <- c(y, 0, 0.1)
  expect_identical(ours(x2, y2, 0.7), sort(brute(x2, y2, 0.7)))
  # a band of 1e-300 on points spread over 1e-299: every index overflows, every pair compared
  x3 <- runif(60, 0, 1e-299)
  y3 <- runif(60, 0, 1e-299)
  expect_identical(ours(x3, y3, 2e-300), sort(brute(x3, y3, 2e-300)))
  # knoxtst itself runs with the outlier
  t2 <- c(runif(200, 0, 100), 1, 2)
  expect_s3_class(suppressMessages(knoxtst(x2, y2, t2, spcbands = c(0.3, 0.7), tmbands = c(5, 10), nsim = 19L,
                                             xy = "planar")),
                  "rmbl_knox")
})

test_that("a period whose hot set a tie empties has no overlap to report, before or after", {
  # 10 cells; period A: cell 1 busiest (k = 1); period B: three cells tied at the top (left out);
  # period C: cell 1 busiest again
  x <- c(rep(0.5, 5), 1.5, 2.5,  0.5, 1.5, 2.5,  rep(0.5, 4), 1.5, 3.5, 4.5, 5.5, 6.5, 7.5, 8.5, 9.5)
  y <- rep(0.5, length(x))
  p <- c(rep("A", 7), rep("B", 3), rep("C", length(x) - 10))
  h <- hotpers(x, y, p, cell = 1, top = 0.1, xy = "planar")
  d <- h$periods
  expect_identical(d$tiedout[d$period == "B"], 3L)
  expect_identical(d$hotcells[d$period == "B"], 0L)
  expect_true(is.na(d$jacpre[d$period == "B"]))
  expect_true(is.na(d$jacpre[d$period == "C"]))
  expect_output(print(h), "left out of the hot set")
})

test_that("column-name arguments that are NULL, empty or missing are refused in words", {
  d <- data.frame(y = rnorm(30), d = rnorm(30), x = rnorm(30), inc = runif(30), e = runif(30))
  for (bad in list(NULL, character(), NA_character_, "")) {
    expect_error(plrcf(d, bad, "d", "x"), "`y` must name one column")
    expect_error(plrcf(d, "y", "d", bad), "`covs` must name one or more columns")
    expect_error(exprspplr(d, "y", bad, "x"), "`expo` must name one column")
    expect_error(expconcidx(d, "e", bad), "`income` must name one column")
    expect_error(polbrdarea(d, areacol = bad), "`areacol` must name one column")
  }
  expect_error(plrcf(d, c("y", "x"), "d", "x"), "`y` must name one column")
})

test_that("messy data with duplicate column names is inspected, not refused; svydes minds only its columns", {
  d <- data.frame(a = c(1, NA, 1), a = c(2, 2, 2), b = c(1, 2, 1), check.names = FALSE)
  ms <- misssmry(d)
  expect_identical(unname(ms[["n_missing"]]), 1)
  expect_identical(unname(ms[["n_cols"]]), 3)
  dr <- duprows(rbind(d, d[1, ]))
  expect_true(nrow(dr) >= 2L)
  expect_error(duprows(d, "a"), "two columns named a")
  expect_identical(nrow(duprows(d, "b")), 2L)
  sd <- data.frame(y = rnorm(6), w = 1:6, junk = 1, junk = 2, check.names = FALSE)
  expect_s3_class(svydes(sd, w = "w"), "rmbl_svy_design")
  sd2 <- data.frame(y = rnorm(6), w = 1:6, w = 6:1, check.names = FALSE)
  expect_error(svydes(sd2, w = "w"), "two columns named w")
})

test_that("a Ctrl-C (or a time limit) during a GET is raised at once, not lost (network stress test of 5e1dce5)", {
  skip_on_os("windows")
  skip_on_cran()
  port <- 20000L + sample.int(20000L, 1L)
  srv <- tryCatch(serverSocket(port), error = function(e) NULL)   # listens, never answers
  skip_if(is.null(srv), "no local port")
  on.exit(close(srv), add = TRUE)
  # R checks a setTimeLimit() limit where it checks for Ctrl-C, and the GET's callback takes both the
  # same way: an elapsed limit is the Ctrl-C without a signal (a signal sent to a child depends on
  # what the test run has done to SIGINT). The old callback took it and the GET came back as a plain
  # failure (status -1), and a Wayback run polled on past its limit
  t0 <- Sys.time()
  setTimeLimit(elapsed = 1.5, transient = TRUE)
  r <- tryCatch(.Call(asNamespace("rmoriebricklayer")$C_rmbl_http_get, sprintf("http://127.0.0.1:%d/x", port),
                      30L, character(), TRUE),
                interrupt = function(e) "INTERRUPTED", error = function(e) "STOPPED")
  setTimeLimit(elapsed = Inf)
  expect_true(identical(r, "INTERRUPTED") || identical(r, "STOPPED"),
              info = paste(utils::capture.output(str(r)), collapse = " "))
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
})

test_that("the lines of PR #56 codecov left unhit are reached (patch coverage of 610b335)", {
  # hurwzeta's Fourier route at a trivial zero: the cosine series is exactly 0
  expect_identical(hurwzeta(-6, 1), 0)
  expect_identical(hurwzeta(-8, 0.5), 0)
  # and off a zero, by the duplication formula zeta(s, q) + zeta(s, q + 1/2) = 2^s zeta(s, 2 q)
  expect_equal(hurwzeta(-5.5, 0.3) + hurwzeta(-5.5, 0.8), 2^-5.5 * hurwzeta(-5.5, 0.6), tolerance = 1e-10)
  # knoxtst: a point too far out to index is compared with every other one, within maxprs
  set.seed(1)
  x <- c(runif(19), 1e300)
  expect_error(knoxtst(x, runif(20), 1:20, spcbands = 0.1, tmbands = 2, nsim = 19,
                         xy = "planar", maxprs = 10),
               "too far out for the largest distance band", fixed = TRUE)
  # two columns with one name are refused in words
  d <- data.frame(a = 1:3, b = 4:6)
  names(d) <- c("a", "a")
  expect_error(anltab(d, "a", "a"), "has two columns named a", fixed = TRUE)
  names(d) <- c("a", "")
  expect_error(anltab(d, "a", "a"), "must have a name", fixed = TRUE)
  # a file named .gz that is plain CSV, larger than the in-memory limit, is read streamed
  p <- tempfile(fileext = ".csv.gz")
  on.exit(unlink(p), add = TRUE)
  write.csv(data.frame(u = 1:5, v = letters[1:5]), p, row.names = FALSE)
  got <- asNamespace("rmoriebricklayer")$.bl_read_csv_gz(p, in_memory = 10)
  expect_identical(got, utils::read.csv(p))
  # gzip data that is damaged is an error, not a fall back to the streamed reader
  writeBin(as.raw(c(0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3, 1:8)), p)
  expect_error(asNamespace("rmoriebricklayer")$.bl_read_csv_gz(p), "not valid gzip data", fixed = TRUE)
  # a complex column takes part in the survey row key
  set.seed(2)
  s <- data.frame(y = rnorm(30), w = runif(30, 1, 2), z = complex(real = 1:30, imaginary = 30:1))
  des <- svydes(s, w = "w")
  expect_s3_class(svyest(des, s, "y"), "data.frame")
  s2 <- s[c(2, 1, 3:30), ]
  rownames(s2) <- NULL   # a reorder the row names do not show
  expect_error(svyest(des, s2, "y"), "not the data frame the design was built on", fixed = TRUE)
})

test_that("a Ctrl-C while a table is split or inflated is R's interrupt, soon (network stress test of 5e1dce5)", {
  skip_on_cran()
  ns <- asNamespace("rmoriebricklayer")
  # an argument check's R error inside a guarded entry jumped past the barrier and left its depth
  # raised, so every later interrupt here was dropped as an ordinary error (in the full test run)
  for (i in 1:3) {
    expect_error(.Call(ns$C_rmbl_http_download, "https://example.org/", tempfile(), 5L, 1L, NULL, 1e6, FALSE),
                 "must be a character vector")
  }
  # an elapsed time limit is seen where a Ctrl-C is: both reach the reader's poll the same way, and the
  # limit stops it as R's own error, which tryCatch() catches (an interrupt halted Rscript; re-test of
  # the b617a3f CRAN stress fixes, finding 1)
  bytes <- rep(charToRaw("1,2,3,4,5,6,7,8,9,10\n"), 3e6)
  bytes <- c(charToRaw(paste0(paste0("c", 1:10, collapse = ","), "\n")), bytes)
  t0 <- Sys.time()
  setTimeLimit(elapsed = 0.3, transient = TRUE)
  r <- tryCatch(.Call(ns$C_rmbl_csv_split, bytes, FALSE), interrupt = function(e) "INTERRUPTED",
                error = function(e) conditionMessage(e))
  setTimeLimit(elapsed = Inf)
  expect_match(r, "elapsed time limit")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
  p <- tempfile(fileext = ".gz")
  on.exit(unlink(p), add = TRUE)
  con <- gzfile(p, "wb")
  for (i in 1:4) writeBin(raw(2^26), con)
  close(con)
  z <- readBin(p, "raw", file.size(p))
  t0 <- Sys.time()
  setTimeLimit(elapsed = 0.02, transient = TRUE)
  r <- tryCatch(.Call(ns$C_rmbl_gunzip_checked, z, 2^31), interrupt = function(e) "INTERRUPTED",
                error = function(e) conditionMessage(e))
  setTimeLimit(elapsed = Inf)
  expect_match(r, "elapsed time limit")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 5)
})

test_that("short records under a wide header are refused, not filled out (network stress test of 5e1dce5)", {
  ns <- asNamespace("rmoriebricklayer")
  bytes <- charToRaw(paste0(paste0("c", 1:2000, collapse = ","), "\n", strrep("1\n", 20000)))
  expect_error(.Call(ns$C_rmbl_csv_split, bytes, FALSE), "mostly filling short records", fixed = TRUE)
  # a ragged table of ordinary size is still filled, as read.csv(fill = TRUE) fills it
  ok <- ns$.bl_csv_from_bytes(charToRaw("a,b,c\n1,2\n3,4,5\n"))
  expect_identical(ok, utils::read.csv(text = "a,b,c\n1,2\n3,4,5\n"))
})

test_that("an unknown verb that looks like a key is not printed back (network stress test of 5e1dce5)", {
  key <- paste0("sk-ant-api03-", strrep("A", 40), "\r")
  msg <- asNamespace("rmoriebricklayer")$.bl_unknown_verb(key, "rmbl")
  expect_false(grepl("AAAAAAAAAAAAAAAAAAAAAAAA", msg, fixed = TRUE))
  expect_match(msg, "an argument like a key, not shown", fixed = TRUE)
  expect_match(asNamespace("rmoriebricklayer")$.bl_unknown_verb("conifg", "rmbl"),
               "'conifg'.*did you mean `rmbl config`")
})

test_that("a replicate column on another scale than the weight is said (statistics stress test of 5e1dce5)", {
  skip_if_not_installed("survey")
  data(api, package = "survey", envir = environment())
  set.seed(7)
  bs <- survey::as.svrepdesign(survey::svydesign(id = ~1, weights = ~pw, data = apisrs),
                               type = "bootstrap", replicates = 15)
  rw <- stats::weights(bs, "analysis")
  d <- apisrs
  for (b in 1:15) d[[paste0("bw", b)]] <- rw[, b]
  expect_warning(svydes(d, w = "pw", reps = c(paste0("bw", 1:15), "api99"), type = "bootstrap"),
                 "replicate api99 is .* times the full-sample weight on a typical row")
  expect_no_warning(svydes(d, w = "pw", reps = paste0("bw", 1:15), type = "bootstrap"))
})

test_that("the prompt's interrupt check returns at once when no Ctrl-C is pending (network stress test of 5e1dce5)", {
  expect_null(.Call(asNamespace("rmoriebricklayer")$C_rmbl_check_interrupt))
})
