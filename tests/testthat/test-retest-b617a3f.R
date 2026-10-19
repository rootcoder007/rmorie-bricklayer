# Re-test of the b617a3f CRAN stress fixes: the items it found partial or not fixed.

ns <- function(f) get(f, envir = asNamespace("rmoriebricklayer"))

test_that("finding 1: a time limit during a POST is an error tryCatch() catches, not an interrupt", {
  skip_on_os("windows")
  skip_on_cran()
  port <- 20000L + sample.int(20000L, 1L)
  srv <- tryCatch(serverSocket(port), error = function(e) NULL)   # listens, never answers
  skip_if(is.null(srv), "no local port")
  on.exit(close(srv), add = TRUE)
  t0 <- Sys.time()
  setTimeLimit(elapsed = 1.5, transient = TRUE)
  r <- tryCatch(.Call(asNamespace("rmoriebricklayer")$C_rmbl_http_post, sprintf("http://127.0.0.1:%d/x", port),
                      as.raw(1:3), "text/plain", 20L, character(), TRUE),
                interrupt = function(e) "INTERRUPTED", error = function(e) conditionMessage(e))
  setTimeLimit(elapsed = Inf)
  expect_match(r, "elapsed time limit")
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  # the poll has nothing left over: the next call runs
  expect_identical(sum(1:3), 6L)
})

test_that("finding 3: a command typed as one argument, tab- or space-joined, is not a question", {
  bq <- ns(".bl_bare_question")
  for (q in c("cnfig\tset\topenai.key", "cnfig set openai.key", "config set openai.key", "logn --token",
              "doctor now", "descibe svydes")) {
    expect_false(bq(q), info = q)
  }
  # questions still are, a verb word in them included
  for (q in c("how do I set the openai key?", "describe the drift test?", "what does cpsdrft do?",
              "is this right?", "explain svydes please")) {
    expect_true(bq(q), info = q)
  }
  expect_match(ns(".bl_unknown_verb")("cnfig set openai.key", "rmbl"), "did you mean `rmbl config`", fixed = TRUE)
  expect_match(ns(".bl_unknown_verb")("cnfig\tset\topenai.key", "rmbl"), "did you mean `rmbl config`", fixed = TRUE)
})

# JK1 on n units, each its own PSU: replicate b zeroes unit b and scales the rest by n / (n - 1)
jk1 <- function(w) {
  n <- length(w)
  sapply(seq_len(n), function(b) {
    r <- w * n / (n - 1)
    r[b] <- 0
    r
  })
}

test_that("JK1 on a domain subset: replicates whose PSU is outside are no copy (within 1% from 101 PSUs)", {
  set.seed(11)
  n <- 120L
  w <- runif(n, 5, 50)
  R <- jk1(w)
  keep <- 1:60
  d <- data.frame(y = rnorm(60))
  expect_silent(des <- svydes(d, w = w[keep], reps = R[keep, ], type = "jk1"))
  expect_s3_class(des, "rmbl_svy_design")
  # a copy of the weight, exact or jittered, is still refused on the full data
  dd <- data.frame(y = rnorm(n))
  expect_error(svydes(dd, w = w, reps = cbind(R, w), type = "jk1"), "the full-sample weight")
  expect_error(svydes(dd, w = w, reps = cbind(R, w * (1 + runif(n, -0.004, 0.004))), type = "jk1"),
               "within 1% on every row")
  # a replicate that leaves no row out and is no k / (k - 1) rescale is said
  expect_warning(svydes(dd, w = w, reps = cbind(R, w * runif(n, 1.05, 1.5)), type = "jk1"),
                 "leaves no row out")
})

test_that("JKn: one replicate equal to the weight is a copy; a left-out stratum's two or more are not", {
  set.seed(12)
  w <- runif(12, 5, 50)
  st <- rep(1:3, each = 4)
  R <- sapply(seq_len(12), function(b) {
    r <- w
    h <- st == st[[b]]
    r[h] <- w[h] * 4 / 3
    r[b] <- 0
    r
  })
  rs <- rep(3 / 4, 12)
  d <- data.frame(y = rnorm(12))
  expect_silent(svydes(d, w = w, reps = R, type = "jkn", rscales = rs))
  expect_error(svydes(d, w = w, reps = cbind(R, w), type = "jkn", rscales = c(rs, 1)),
               "the full-sample weight")
  # a stratum subset: stratum 3's rows alone, so the replicates of strata 1 and 2 equal the weight
  k <- st == 3
  expect_silent(svydes(d[k, , drop = FALSE], w = w[k], reps = R[k, ], type = "jkn", rscales = rs))
})

test_that("post-stratified or calibrated sets: replicates equal or close to the weight are accepted", {
  set.seed(13)
  n <- 40L
  w <- runif(n, 5, 50)
  # each replicate scales each row by its own factor, as calibration does; two come back to the weight
  R <- sapply(seq_len(30), function(b) w * runif(n, 0.6, 1.4))
  R[, 1] <- w
  R[, 2] <- w * (1 + runif(n, -0.003, 0.003))
  d <- data.frame(y = rnorm(n))
  for (tp in c("jk1", "brr", "bootstrap")) {
    reps <- if (tp == "brr") R[, 1:28] else R
    expect_silent(svydes(d, w = w, reps = reps, type = tp))
  }
})

test_that("finding 4: a provider-prefixed key shorter than 24 characters is never a question", {
  bq <- ns(".bl_bare_question")
  k <- "sk-sVau8MGU1achkc82m2vR"   # 23 characters
  for (q in c(paste0("is ", k, " valid?"), paste0(k, ", is this ok?"), paste0("my key is ", k, "?"),
              "check gsk_7Hq2Zp9Lm4Rx8Tn?", "is hf_k3J9sPq2Wm7Xv4 ok?")) {
    expect_false(bq(q), info = q)
  }
  # a prefix with no digit in what follows is a word, not a key
  expect_true(bq("how do I use sk-learn models?"))
})

test_that("CSV reader: a byte-order mark after the header, and a header of blanks or a mark alone", {
  ours <- ns(".bl_csv_from_bytes")
  ref <- function(b) {
    f <- withr::local_tempfile(fileext = ".csv")
    writeBin(b, f)
    suppressWarnings(utils::read.csv(f, stringsAsFactors = FALSE, skipNul = TRUE))
  }
  same <- function(t) expect_identical(ours(charToRaw(t)), ref(charToRaw(t)), info = encodeString(t))
  # read.csv() drops a mark at the start of a line below the header only in a UTF-8 locale; the
  # reader drops it everywhere, so these five are compared there (C-locale check of 1.0.0)
  if (l10n_info()[["UTF-8"]]) {
    same("b,a\n﻿T\n")             # the mark is no part of the first field
    same("c\n﻿null\nF\n")
    same("\"h\"\n﻿\n")             # a line of the mark alone is a blank line
    same("a\n\n﻿x\n")              # after blank lines too
    same("a\n\"﻿x\"\n")            # inside the opening quote
  }
  same("a\nx\n﻿\n2\n")           # past the first row it is text
  same("\n \n1\n2\n")                 # a header of blanks: no columns, the rows are row names
  same("\n﻿\nx\nb\n")            # a header of the mark alone, the same
  same("\"\"\nx\nb\n")                # a header of "" alone, the same
})

test_that("survey: a partly named replicate matrix refuses a data column; permuted outcomes are no reorder", {
  set.seed(14)
  m <- 30
  w <- runif(m, 5, 50)
  jk <- sapply(seq_len(m), function(j) {
    f <- rep(m / (m - 1), m)
    f[j] <- 0
    w * f
  })
  d <- data.frame(y = rnorm(m), y2 = rnorm(m), w = w, z = runif(m) * 40, s = rep(1:3, 10))
  R <- cbind(jk, d$z)
  colnames(R) <- c(paste0("r", 1:m), "")
  expect_error(svydes(d, w = "w", reps = R, type = "jk1"), "column z of `data`", fixed = TRUE)
  des <- svydes(d, w = "w", reps = jk, type = "jk1")
  p <- d
  p$y <- sample(p$y)
  p$y2 <- sample(p$y2)
  expect_s3_class(svyest(des, p, "y"), "data.frame")
  # the rows themselves reordered are still refused
  expect_error(svyest(des, d[c(2:m, 1), ], "y"), "not the data frame the design was built on")
})

test_that("hostile arguments: a data frame, a function or a vector where one value goes is refused in words", {
  df <- data.frame(a = 1:2)
  worded <- function(expr) {
    e <- tryCatch({
      force(expr)
      NULL
    }, error = function(e) e)
    expect_s3_class(e, "error")
    expect_null(conditionCall(e))
  }
  worded(cgamcdf(2, df))
  worded(ccorr(1:3, 1:4))
  worded(cunif(Inf, 1))
  worded(cbootmean(1:5, B = 1e10))
  worded(morani(c(1, 2, 3), list(2, c(1, 3), 2), nperm = NULL))
  worded(perdays("tomorrow", "2024-01-01"))
  worded(siutxt(1))
  worded(csha256(function(x) x))
  worded(svyest(list(), data.frame(), "y", lvls = mean))
  worded(chgenv(1, 2))
  worded(recrd(list(), name = NULL, obs = 1, expd = 1))
  worded(yoycsv(structure(list(), class = "rmbl_yoy"), file = 1))
  worded(blpal(n = df))
  worded(rsvidx(10, Inf))
  worded(usecpstmpl(NA))
  worded(mksyncol(list(type = "sample"), n = 5))
})
