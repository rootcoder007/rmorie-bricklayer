# SPDX-License-Identifier: AGPL-3.0-or-later
# The CRAN stress test of b617a3f (PR #56 head, 0.5.12): every finding, HIGH to LOW, as a test.
ns <- function(x) get(x, envir = asNamespace("rmoriebricklayer"))

# a JK1 design on m PSUs, and its replicates on a subset of the PSUs: the replicates that delete a PSU
# outside the subset are all the same column there
jk1_subset <- function(m = 6L, keep = 1:3, per = 5L) {
  set.seed(11)
  psu <- rep(seq_len(m), each = per)
  w <- rep(runif(m, 20, 40), each = per)
  reps <- sapply(seq_len(m), function(j) w * ifelse(psu == j, 0, m / (m - 1)))
  rows <- psu %in% keep
  list(d = data.frame(y = rnorm(sum(rows)), w = w[rows], psu = psu[rows]), reps = reps[rows, , drop = FALSE])
}

test_that("#1: identical genuine replicates passed by name are not each other's stray column", {
  s <- jk1_subset()
  B <- s$reps
  colnames(B) <- paste0("rw", seq_len(ncol(B)))
  expect_true(any(duplicated(t(B))))
  d <- cbind(s$d, as.data.frame(B))
  by_name <- survey_design(d, weights = "w", replicates = colnames(B), type = "jk1")
  by_matrix <- survey_design(s$d, weights = "w", replicates = unname(B), type = "jk1")
  expect_equal(survey_estimate(by_name, d, "y")$se, survey_estimate(by_matrix, s$d, "y")$se, tolerance = 1e-14)
  # a column of data that is not among those passed is still refused when passed under another name
  d$copy <- d$rw1
  expect_error(survey_design(d, weights = "w", replicates = cbind(B[, -1], zz = d$copy), type = "jk1"),
               "column (rw1|copy) of `data`")
})

test_that("#2: a key anywhere in the line is never taken for a question", {
  bq <- ns(".bl_bare_question")
  k <- paste0("sk-ant-api03-", strrep("Ab9_", 6L), "Q")
  for (q in c(paste0(k, "?"), paste0("my key is ", k, ", thanks?"), paste0("key '", k, "'?"),
              paste0("key \"", k, "\"?"), paste0("my key​", k, "?"),
              paste0("is ", strrep("kq7", 9L), " valid?"))) {
    expect_false(bq(q), info = q)
  }
  # near misses of a verb, with the ? apart, a full-width space or a tab
  for (q in c("doctr ?", "doctr  !?", "　doctr?", "doctr\t?", "\"doctr?\"")) expect_false(bq(q), info = q)
  # real questions, function names in them included, and a CJK question with a full-width mark
  for (q in c("how do I use bricklayer_json_base64url_dec?", "explain survey_design please",
              "how do I estimate survey_design_replicates_weights?",
              "调查权重怎么用？")) {
    expect_true(bq(q), info = q)
  }
  # the line for an unknown verb: no key printed, a near miss named through quotes and ?
  expect_match(ns(".bl_unknown_verb")(k, "rmbl"), "an argument like a key, not shown", fixed = TRUE)
  expect_match(ns(".bl_unknown_verb")("\"doctr?\"", "rmbl"), "did you mean `rmbl doctor`", fixed = TRUE)
  expect_false(grepl("\033", ns(".bl_unknown_verb")("do\033]0;x\007ctor", "rmbl"), fixed = TRUE))
})

test_that("#3: rows reordered and then a column dropped or one cell edited are refused", {
  set.seed(3)
  st <- data.frame(stype = rep(c("E", "M", "H"), each = 20), y = rnorm(60), a = rnorm(60), b = runif(60),
                   meals = sample(0:100, 60, TRUE))
  w <- rep(c(10, 20, 30), each = 20)
  des <- survey_design(st, weights = w, strata = "stype")
  o <- unlist(lapply(split(seq_len(60), st$stype), rev))
  x <- st[o, ]
  x1 <- x
  x1$meals <- NULL
  x2 <- x
  x2$a[[1L]] <- NA
  for (z in list(x, x1, x2)) expect_error(survey_estimate(des, z, "y"), "not the data frame the design was built on")
  # a permuted outcome (a permutation test) is not a reorder, nor is a row-name reset
  xp <- st
  xp$y <- sample(xp$y)
  expect_s3_class(survey_estimate(des, xp, "y"), "data.frame")
  sub <- st[st$stype != "H", ]
  ds <- survey_design(sub, weights = "b", strata = "stype")
  s2 <- sub
  rownames(s2) <- NULL
  expect_equal(survey_estimate(ds, s2, "y")$se, survey_estimate(ds, sub, "y")$se)
})

test_that("#7: JKn replicates of other strata equal the weight on a stratum subset, legitimately", {
  set.seed(7)
  s <- rep(1:3, each = 8)
  p <- rep(1:12, each = 2)
  w <- runif(24, 5, 9)
  nh <- 4
  reps <- sapply(1:12, function(j) {
    h <- s[p == j][[1L]]
    f <- ifelse(s == h, ifelse(p == j, 0, nh / (nh - 1)), 1)
    w * f
  })
  rs <- rep((nh - 1) / nh, 12)
  keep <- s == 1
  d <- data.frame(y = rnorm(24), w = w)[keep, ]
  des <- survey_design(d, weights = "w", replicates = reps[keep, ], type = "jkn", rscales = rs)
  expect_true(is.finite(survey_estimate(des, d, "y")$se))
  # every replicate the weight: no variance to read, refused
  expect_error(survey_design(d, weights = "w", replicates = matrix(d$w, nrow(d), 4), type = "jkn",
                             rscales = rep(0.75, 4)), "every replicate is the full-sample weight")
  # under JK1 and BRR the weight itself is still refused
  expect_error(survey_design(d, weights = "w", replicates = cbind(reps[keep, 1:4], d$w), type = "jk1"),
               "the full-sample weight")
})

test_that("#8: a stratified bootstrap with replicates equal to the weight by chance is not warned about", {
  set.seed(8)
  st <- rep(1:4, each = 20)
  p <- rep(1:8, each = 10)
  w <- runif(80, 1, 3)
  # Rao-Wu with n_h - 1 = 1 draw of 2 PSUs a stratum: multipliers 0 or 2, each replicate the weight
  # with chance 1/16 here (counts, not rescaled: 2 draws of 2 PSUs, k in 0..2)
  reps <- sapply(1:200, function(b) {
    k <- unlist(lapply(1:4, function(h) stats::rmultinom(1, 2, c(1, 1))[, 1]))
    w * k[p]
  })
  eq <- sum(apply(reps, 2, function(r) all(r == w)))
  expect_gt(eq, 3)
  expect_silent(survey_design(data.frame(y = rnorm(80), w = w), "w", replicates = reps, type = "bootstrap"))
  # post-stratified or calibrated jackknife replicates on a subset leave no row out: kept in silence
  s <- jk1_subset()
  g <- 1 + 0.05 * sin(seq_len(nrow(s$reps)))
  expect_silent(survey_design(s$d, "w", replicates = s$reps * g, type = "jk1"))
})

test_that("#9: a column a tenth of the weight's scale among the replicates is said", {
  s <- jk1_subset(keep = 1:6)
  expect_warning(survey_design(s$d, "w", replicates = cbind(s$reps, s$d$w / mean(s$d$w)), type = "jk1"),
                 "times the full-sample weight on a typical row")
  # the replicates' set-level note comes first, before the per-replicate lines that would hide it
  expect_warning(survey_design(s$d, "w", replicates = s$reps / s$d$w, type = "jk1"), "^the replicates total")
})

test_that("the survey Rd's recipe for survey's own bootstrap replicates gives survey's SE", {
  skip_if_not_installed("survey")
  set.seed(1)
  dd <- data.frame(s = rep(1:4, each = 30), p = rep(1:12, each = 10), y = rnorm(120), w = runif(120, 1, 3))
  bd <- survey::as.svrepdesign(survey::svydesign(id = ~p, strata = ~s, weights = ~w, data = dd),
                               type = "bootstrap", replicates = 50, compress = FALSE)
  B <- 50
  m <- 3
  ours <- survey_design(dd, "w", replicates = weights(bd, "analysis"), type = "bootstrap",
                        rscales = rep(B * m / ((m - 1) * (B - 1)), B), mse = FALSE)
  expect_equal(survey_estimate(ours, dd, "y")$se, as.numeric(survey::SE(survey::svymean(~y, bd))), tolerance = 1e-10)
})

test_that("#6: bricklayer_data_load()'s reader applies rmoriebricklayer.max_csv_bytes on both paths", {
  rd <- ns(".bl_read_csv_gz")
  g <- tempfile(fileext = ".csv.gz")
  con <- gzfile(g, "w")
  writeLines(c("a", rep("1", 2e5)), con)
  close(con)
  withr::local_options(rmoriebricklayer.max_csv_bytes = 1e5)
  expect_error(rd(g), "decompresses to more than 100,000 bytes")
  expect_error(rd(g, in_memory = 1e4), "decompresses to more than 100,000 bytes")
  withr::local_options(rmoriebricklayer.max_csv_bytes = 1e7)
  expect_identical(nrow(rd(g)), 200000L)
  expect_identical(nrow(rd(g, in_memory = 1e4)), 200000L)   # the streamed path, counted first
  # a plain file under a .gz name, past the limit
  f <- tempfile(fileext = ".csv.gz")
  writeLines(c("a", rep("1", 1000)), f)
  withr::local_options(rmoriebricklayer.max_csv_bytes = 100)
  expect_error(rd(f), "decompresses to more than 100 bytes")
  withr::local_options(rmoriebricklayer.max_csv_bytes = -1)
  expect_error(rd(f), "must be a single non-negative number")
})

test_that("#10 and the CSV parity items: the reader matches read.csv()", {
  same <- function(bytes) {
    f <- tempfile()
    writeBin(bytes, f)
    expect_identical(ns(".bl_csv_from_bytes")(bytes), utils::read.csv(f, stringsAsFactors = FALSE, skipNul = TRUE),
                     info = paste(bytes, collapse = " "))
  }
  same(c(charToRaw("a,b\n1,2\n"), as.raw(c(0, 0)), charToRaw("\n3,4\n")))   # a line of NULs
  same(c(charToRaw("a,b\n1,2\n"), as.raw(c(0, 0, 0))))                       # NULs at the end
  same(charToRaw("a\n00000000000012\n7\n"))                                 # leading zeros: integer
  same(charToRaw("\"\"\n1\n2\n"))                                           # a header of "" alone
  same(charToRaw(" \"a\" ,b\n1,2\n"))                                       # blanks outside header quotes
  same(charToRaw("a\n\"x\"y\"z\"\n"))                                       # quotes after a closing one
  # a header past a million fields is refused before it is held
  expect_error(ns(".bl_csv_from_bytes")(charToRaw(strrep(",", 1e6 + 1))), "more columns than this reader takes")
})

test_that("#4: a POST honours a time limit (and so Ctrl-C) with no wait label on screen", {
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
                interrupt = function(e) "INTERRUPTED", error = function(e) "STOPPED")
  setTimeLimit(elapsed = Inf)
  expect_true(identical(r, "INTERRUPTED") || identical(r, "STOPPED"),
              info = paste(utils::capture.output(str(r)), collapse = " "))
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
})

test_that("#11: the last turn after the tool rounds keeps the tools declared with calls off, on every API", {
  msgs <- list(list(role = "system", content = "s"), list(role = "user", content = "q"),
               list(role = "assistant", content = "", tool_calls = list(list(id = "c", name = "get_help",
                                                                              arguments = list(name = "x")))),
               list(role = "tool", tool_call_id = "c", name = "get_help", content = "page\n\nAnswer now"))
  tools <- list(list(name = "get_help", description = "d", parameters = list(type = "object")))
  req <- ns(".bl_llm_request")
  a <- req(list(api = "anthropic", base = "https://api.anthropic.com"), "m", msgs, tools, 100L, no_calls = TRUE)
  expect_identical(a$body$tool_choice, list(type = "none"))
  expect_length(a$body$tools, 1L)
  roles <- vapply(a$body$messages, function(m) m$role, "")
  expect_false(any(roles[-1L] == "user" & roles[-length(roles)] == "user"))
  g <- req(list(api = "gemini", base = "https://generativelanguage.googleapis.com"), "m", msgs, tools, 100L,
           no_calls = TRUE)
  expect_identical(g$body$toolConfig$functionCallingConfig$mode, "NONE")
  o <- req(list(api = "openai", base = "https://api.openai.com/v1"), "m", msgs, tools, 100L, no_calls = TRUE)
  expect_identical(o$body$tool_choice, "none")
  expect_null(req(list(api = "openai", base = "https://api.openai.com/v1"), "m", msgs, tools, 100L)$body$tool_choice)
})

test_that("an SSE error event is said with its message, and the answer cache keys on the key in use", {
  body <- charToRaw("event: error\ndata: {\"error\": {\"message\": \"overloaded right now\"}}\n\n")
  expect_identical(ns(".bl_sse_error")(body)$error$message, "overloaded right now")
  expect_null(ns(".bl_sse_error")(charToRaw("data: {\"x\": 1}\n")))
  expect_null(ns(".bl_sse_error")(charToRaw("plain text")))
  rt <- list(name = "OpenAI", id = "openai", api = "openai", base = "https://api.openai.com/v1", key = "k1")
  local_mocked_bindings(.bl_post_json = function(...) {
    list(status = 200L, json = list(error = list(message = "overloaded right now")), error = "")
  }, .package = "rmoriebricklayer")
  expect_error(ns(".bl_llm_chat")(rt, "m", list(list(role = "user", content = "q"))), "overloaded right now")
  key <- ns(".bl_answer_key")
  expect_false(identical(key(rt, "m", "q"), key(utils::modifyList(rt, list(key = "k2")), "m", "q")))
})

test_that("hurwitz_zeta(s, 1/2) is (2^s - 1) zeta(s), exact beside the trivial zeros", {
  # mpmath, 50 digits: zeta(-32 + 1e-10, 1/2) = -0.377901212258735
  expect_equal(hurwitz_zeta(-32 + 1e-10, 0.5), -0.377901212258735, tolerance = 1e-12)
  expect_equal(hurwitz_zeta(-32.5, 0.5), 3883945550.81538, tolerance = 1e-12)
  expect_equal(hurwitz_zeta(-0.5, 0.5), (2^-0.5 - 1) * hurwitz_zeta(-0.5, 1), tolerance = 1e-13)
  expect_identical(hurwitz_zeta(0, 0.5), 0)
})

test_that("a point at -1e300 does not wipe out the Knox and hot-spot counts", {
  set.seed(4)
  x <- runif(40)
  y <- runif(40)
  tt <- sample(1:30, 40, TRUE)
  base <- knox_test(x, y, tt, space_bands = 0.2, time_bands = 5, nsim = 19, seed = 1, coords = "planar")
  out <- knox_test(c(x, -1e300), c(y, 0.5), c(tt, 1), space_bands = 0.2, time_bands = 5, nsim = 19, seed = 1,
                   coords = "planar")
  expect_identical(out$table$observed, base$table$observed)
  per <- rep(1:2, 20)
  h0 <- hotspot_persistence(x, y, per, cell = 0.25, coords = "planar")
  h1 <- hotspot_persistence(c(x, -1e300), c(y, 0.5), c(per, 1L), cell = 0.25, coords = "planar")
  expect_identical(nrow(h1$cells), nrow(h0$cells) + 1L)
})

test_that("hostile seeds, normals and plot arguments are refused in words", {
  for (sv in list(NA, Inf, "a", c(1, 2), 1.5, 2^53, -2^31)) {
    expect_error(ns(".rmbl_with_seed")(sv, 1), "`seed` must be a single whole number", info = deparse(sv))
    expect_error(make_synthetic_csv(list(a = "integer"), tempfile(fileext = ".csv"), n_rows = 3, seed = sv),
                 "`seed` must be a single whole number", info = deparse(sv))
  }
  expect_identical(ns(".rmbl_with_seed")(-3, 7), 7)
  # a seed past set.seed()'s 32 bits, up to 2^53: its own stream, the same every time, and the caller's
  # stream untouched; one in the integer range is set.seed()'s
  ws <- ns(".rmbl_with_seed")
  draw <- function(s) ws(s, stats::runif(5))
  set.seed(99)
  before <- stats::runif(3)
  set.seed(99)
  a <- draw(2^40)
  expect_identical(stats::runif(3), before)
  expect_identical(draw(2^40), a)
  expect_false(identical(draw(2^40 + 1), a))
  expect_false(identical(draw(2^53 - 1), a))
  set.seed(42)
  plain <- stats::runif(5)
  expect_identical(draw(42), plain)
  expect_true(all(a >= 0 & a < 1))
  old <- RNGkind("L'Ecuyer-CMRG")
  on.exit(RNGkind(old[[1L]]), add = TRUE)
  expect_error(draw(2^40), "needs R's default generator")
  RNGkind(old[[1L]])
  lp <- function(...) {
    lagrangian_particles(n = 3, x0 = 0, y0 = 0, u = 1, v = 0, kx = 1, ky = 1, dt = 1, n_steps = 2, ...)
  }
  expect_error(lp(normals = "rnorm"), "`normals` must be a function")
  expect_error(lp(normals = function(n, seed, stream) 1), "`normals` must return 3 finite numbers")
  expect_error(lp(normals = function(n, seed, stream) letters[1:n]), "returned a character")
  expect_s3_class(lp(normals = function(n, seed, stream) rep(0, n)), "rmbl_particles")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  meth <- grep("^plot\\.", ls(asNamespace("rmoriebricklayer")), value = TRUE)
  expect_gt(length(meth), 30L)
  for (m in meth) {
    for (bad in list(1, "a", list(), NULL)) {
      expect_error(ns(m)(bad), "`x` must be a", info = m)
    }
  }
})

test_that("the SIU name patterns take a long run of letters in linear time", {
  t0 <- proc.time()[["elapsed"]]
  invisible(.Call(asNamespace("rmoriebricklayer")$C_rmbl_siu_parse_html, paste0("<p>", strrep("A", 2e5))))
  # 225 microseconds a byte before (45 s here); about 2.4 microseconds now
  expect_lt(proc.time()[["elapsed"]] - t0, 15)
})

test_that("an argument error inside an entry point is said as before, after its buffers are freed", {
  expect_error(.Call(asNamespace("rmoriebricklayer")$C_rmbl_http_get, "https://example.org/", 5L,
                     "X-A: 1\r\nX-B: 2", FALSE), "^a request header has a line break")
  expect_error(gini(c(1, -1)), "non-negative")
})

test_that("#5: an interrupt in the fetch pipeline's Wayback lookup or snapshot GET is raised (local servers)", {
  skip_on_os("windows")
  skip_on_cran()
  ns_ <- asNamespace("rmoriebricklayer")
  port <- 20000L + sample.int(20000L, 1L)
  srv <- tryCatch(serverSocket(port), error = function(e) NULL)   # listens, never answers
  skip_if(is.null(srv), "no local port")
  on.exit(close(srv), add = TRUE)
  silent <- sprintf("http://127.0.0.1:%d", port)
  closed <- sprintf("http://127.0.0.1:%d/x", if (port < 39999L) port + 1L else port - 1L)   # refuses at once
  stopped <- function(expr) {
    t0 <- Sys.time()
    setTimeLimit(elapsed = 1.5, transient = TRUE)
    r <- tryCatch(expr, interrupt = function(e) "INTERRUPTED", error = function(e) "STOPPED")
    setTimeLimit(elapsed = Inf)
    expect_true(identical(r, "INTERRUPTED") || identical(r, "STOPPED"), info = paste(format(r), collapse = " "))
    expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), 10)
  }
  # the live GET hangs: stopped there, the lookups never start
  stopped(.Call(ns_$C_rmbl_fetch_fallback, paste0(silent, "/x"), "", tempfile(), 20L, silent))
  # the live GET fails at once, then the availability lookup hangs (the first try)
  stopped(.Call(ns_$C_rmbl_fetch_fallback, closed, "", tempfile(), 20L, silent))
  # a given snapshot that hangs
  stopped(.Call(ns_$C_rmbl_fetch_fallback, closed, paste0(silent, "/snap"), tempfile(), 20L, silent))
  # the lookup alone, as wayback_snapshot_url_native() calls it
  stopped(.Call(ns_$C_rmbl_wayback, "https://example.org/", 20L, silent))
})

test_that("the remaining changed lines: an origin past every point, a row check, the C argument checks", {
  # no point within 2^52 cells of the median: the median is the origin
  expect_identical(ns(".jx_origin")(c(-1e300, 1e300), 1), 0)
  # a column dropped with the rows in order is the same data
  set.seed(2)
  d <- data.frame(y = rnorm(20), a = rnorm(20), b = rnorm(20))
  des <- survey_design(d, weights = rep(2, 20))
  d2 <- d
  d2$b <- NULL
  expect_equal(survey_estimate(des, d2, "y")$se, survey_estimate(des, d, "y")$se)
  # the native uniforms' own checks, said as before
  expect_error(.Call(asNamespace("rmoriebricklayer")$C_rmbl_uniforms, -1, 1), "`n` must be a whole number >= 0")
  # a large result goes through the allocation that unwinds (and one too large for memory says so)
  expect_length(core_uniforms(70000, 1), 70000L)
  expect_error(.Call(asNamespace("rmoriebricklayer")$C_rmbl_uniforms, 4e15, 1), "out of memory")
})

# a child R that answers each request on `port` with `status` and `body`, after reading the whole
# request (closing with it unread resets the connection), and closes; it writes `ready` once it
# listens (a probe connection would be answered too, and the write to the closed probe kill it)
serve_bg <- function(port, status, body, times = 6L) {
  ready <- tempfile("listening-")
  code <- sprintf(paste0(
    "srv <- serverSocket(%dL); on.exit(close(srv)); writeLines('ok', '%s'); for (i in seq_len(%dL)) {",
    "con <- socketAccept(srv, blocking = TRUE, open = 'r+b', timeout = 30);",
    "repeat { l <- readLines(con, n = 1L, warn = FALSE); if (!length(l) || !nzchar(sub('\\\\r$', '', l))) break };",
    "b <- %s;",
    "head <- paste0('HTTP/1.1 ', %s, '\\r\\nContent-Type: application/json\\r\\n',",
    "               'Content-Length: ', nchar(b, 'bytes'), '\\r\\nConnection: close\\r\\n');",
    "writeLines(head, con, sep = '\\r\\n');",
    "writeChar(b, con, eos = NULL); flush(con); close(con) }"),
    port, ready, times, deparse(body), deparse(status))
  rscript_bg(code)
  wait_files(ready, 30)
}

test_that("the Wayback lookup: no snapshot after two failed tries, and a snapshot found (local servers)", {
  skip_on_os("windows")
  skip_on_cran()
  ns_ <- asNamespace("rmoriebricklayer")
  port <- 20000L + sample.int(20000L, 1L)
  skip_if_not(serve_bg(port, "503 Service Unavailable", "{}", times = 4L), "no local server")
  base <- sprintf("http://127.0.0.1:%d", port)
  expect_identical(.Call(ns_$C_rmbl_wayback, "https://example.org/", 10L, base), "")
  # the live URL refused at once, the lookup failing twice: no snapshot, nothing written
  closed <- sprintf("http://127.0.0.1:%d/x", if (port < 39999L) port + 1L else port - 1L)
  code <- .Call(ns_$C_rmbl_fetch_fallback, closed, "", tempfile(), 10L, base)
  expect_lt(code, 0L)
  expect_identical(code %% 10L, 0L)   # no snapshot was found
  port2 <- port + 7L
  found <- paste0('{"archived_snapshots":{"closest":{"available": true,',
                  '"url":"http://web.archive.org/web/2024/https://example.org/"}}}')
  skip_if_not(serve_bg(port2, "200 OK", found, times = 1L), "no local server")
  expect_identical(.Call(ns_$C_rmbl_wayback, "https://example.org/", 10L, sprintf("http://127.0.0.1:%d", port2)),
                   "https://web.archive.org/web/2024/https://example.org/")
})

test_that("#3: a reorder with a column dropped is refused when the named columns cannot show it", {
  set.seed(9)
  d <- data.frame(y = rnorm(20), a = rnorm(20), b = rnorm(20))
  des <- survey_design(d, weights = runif(20, 1, 2))
  x <- d[c(2:20, 1L), ]
  x$b <- NULL
  expect_error(survey_estimate(des, x, "y"), "not the data frame the design was built on")
})
