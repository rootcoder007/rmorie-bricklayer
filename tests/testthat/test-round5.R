# Fixes for the round-5 fresh-user findings (2026-10-03): one test per finding.

.cap <- function(...) {
  txt <- character()
  status <- bricklayer_cli(c(...), out = function(s) txt <<- c(txt, s))
  list(status = status, text = paste(txt, collapse = ""))
}

test_that("VERB --help prints the verb's usage and never runs it", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_KEY = NA)
  for (v in c("logout", "doctor", "models", "bundle", "functions", "describe", "examples", "data", "login", "ask")) {
    r <- .cap(v, "--help")
    expect_equal(r$status, 0L, info = v)
    expect_match(r$text, paste0("^usage: rmoriebricklayer ", v), info = v)
  }
  expect_equal(.cap("data", "pull", "--help")$status, 0L)
  expect_match(.cap("--version")$text, "^rmoriebricklayer [0-9]")
})

test_that("messages name the command the user typed", {
  withr::local_envvar(RMBL_PROG = "rmbl")
  r <- .cap("nosuch")
  expect_equal(r$status, 2L)
  expect_match(r$text, "^rmbl: unknown verb 'nosuch' \\(try: rmbl help\\)")
})

test_that("usage errors exit 2, an unknown function 1", {
  expect_equal(.cap("bundle")$status, 2L)
  expect_equal(.cap("ask")$status, 2L)
  r <- .cap("describe", "nosuchfn")
  expect_equal(r$status, 1L)
  expect_match(r$text, "no help page for 'nosuchfn'")
  expect_equal(.cap("examples", "nosuchfn")$status, 1L)
  expect_equal(.cap("login", "--code", "123456")$status, 2L)
  withr::local_options(rlang_interactive = FALSE)
  expect_equal(.cap("login", "--token")$status, 2L)
})

test_that("a pasted key the gateway refuses is not stored; an address is checked first", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_KEY = NA, MORIE_HOSTED_BASE_URL = NA)
  local_mocked_bindings(.bl_models_reply = function(base, key, timeout = 10) list(status = 401L, body = raw(0)))
  r <- .cap("login", "--token", "sk-bad")
  expect_equal(r$status, 1L)
  expect_match(r$text, "did not accept that key")
  expect_null(.bl_hosted_key())
  expect_error(bricklayer_llm_login(email = "notanemail"), "'notanemail' is not an email address")
})

test_that("a refused key is said as such, and the gateway's key fragment is never printed", {
  withr::local_envvar(MORIE_HOSTED_KEY = "sk-x", MORIE_HOSTED_BASE_URL = NA)
  local_mocked_bindings(.bl_models_reply = function(base, key, timeout = 10) list(status = 401L, body = raw(0)))
  expect_match(.cap("models")$text, "rejected the stored key")
  st <- bricklayer_llm_status()
  expect_match(st$detail[1], "key rejected by the gateway")
  res <- list(status = 401L, json = list(error = list(
    message = "Authentication Error, Received API Key = sk-...abcd, Key Hash (Token) =1234"
  )))
  expect_error(.bl_reply_error(res, "the hosted MORIE LLM tier"), "rejected your key")
  res$status <- 400L
  e <- tryCatch(.bl_reply_error(res, "the hosted MORIE LLM tier"), error = conditionMessage)
  expect_false(grepl("sk-|Key Hash|abcd", e))
})

test_that("models without jsonlite: the native JSON parser reads the list", {
  withr::local_envvar(MORIE_HOSTED_KEY = "sk-x", MORIE_HOSTED_BASE_URL = NA, MORIE_HOSTED_MODEL = NA)
  local_mocked_bindings(.bl_models_reply = function(base, key, timeout = 10) {
    list(status = 200L, body = charToRaw('{"data":[{"id":"a"},{"id":"minimax-m3:cloud"}]}'))
  })
  m <- bricklayer_llm_models()
  expect_equal(as.character(m), c("a", "minimax-m3:cloud"))
  expect_equal(attr(m, "default"), "minimax-m3:cloud")
})

test_that("SIU dates must exist; day-first ordinals and abbreviations read; NA is NA", {
  expect_equal(bricklayer_siu_iso_date(c("February 30, 2020", "February 29, 2020", "2nd February 2018",
                                         "22nd of March 2019", "3rd June, 2019", "Aug 3, 2017", "Sept. 5, 2019", NA)),
               c("", "2020-02-29", "2018-02-02", "2019-03-22", "2019-06-03", "2017-08-03", "2019-09-05", NA))
  expect_error(bricklayer_parse_siu(NA), "not NA")
  expect_equal(trimws(bricklayer_siu_text("<p>&rsquo;x&#x2019; &hellip; &mdash;&#x2014;</p>")), "'x' ... ----")
})

test_that("bricklayer_fetch names the cause before downloading anything", {
  expect_error(bricklayer_fetch("not a url", tempfile()), "is not an http\\(s\\) URL")
  expect_error(bricklayer_fetch("ftp://example.com/x", tempfile()), "is not an http\\(s\\) URL")
  expect_error(bricklayer_fetch("https://example.com/", "/nonexistent-dir-r5/x"), "its directory does not exist")
  expect_error(bricklayer_fetch("https://example.com/", tempfile(), timeout = -1), "positive number of seconds")
  expect_error(wayback_snapshot_url_native(""), "single non-empty string")
  expect_error(sha256_file("nosuch-file-r5"), "is not a file")
})

test_that("data pull to an unwritable path says so, without an R warning", {
  local_mocked_bindings(bricklayer_data_load = function(key) data.frame(a = 1))
  expect_silent(r <- .cap("data", "pull", "hib/x", "--out", "/nonexistent-dir-r5/x.csv"))
  expect_equal(r$status, 1L)
  expect_match(r$text, "cannot write /nonexistent-dir-r5/x.csv")
})

test_that("yoy compares a biennial series step to step, and an inserted year is 'no data'", {
  b <- yoy(data.frame(year = c(2015, 2017, 2019, 2021), n = c(100, 120, 90, 130)), value = "n", period = "year")
  expect_equal(b$previous, c(NA, 100, 120, 90))
  g <- yoy(data.frame(year = c(2020, 2021, 2023), n = c(5, 8, 20)), value = "n", period = "year")
  expect_equal(g$flag[g$year == 2022], "no data")
})

test_that("report_analysis prints years without a thousands separator and says points for percents", {
  d <- data.frame(year = rep(2020:2023, 2), grp = rep(c("a", "b"), each = 4),
                  pct = c(10, 12, 15, 11, 30, 28, 25, 27))
  a <- analyse_table(d, value = "pct", period = "year", by = "grp", units = "percent")
  f <- tempfile(fileext = ".md")
  report_analysis(a, f)
  txt <- paste(readLines(f), collapse = "\n")
  expect_false(grepl("2,02", txt, fixed = TRUE))
  expect_match(txt, "percentage points")
  expect_false(grepl("conditional-binomial", txt, fixed = TRUE))
})

test_that("friendly_download does not leak url()'s warning and says when no snapshot exists", {
  local_mocked_bindings(.bl_fetch_file = function(url, dest) {
    warning("cannot open URL 'x': HTTP status was '404 Not Found'")
    stop("cannot open the connection")
  }, wayback_snapshot_url = function(url, timestamp = NULL) NULL)
  msgs <- character()
  keep <- function(m) {
    msgs <<- c(msgs, conditionMessage(m))
    invokeRestart("muffleMessage")
  }
  expect_no_warning(withCallingHandlers(ok <- friendly_download("https://example.com/x", tempfile()), message = keep))
  expect_false(ok)
  expect_true(any(grepl("404 Not Found", msgs)))
  expect_true(any(grepl("no snapshot of it", msgs)))
})
