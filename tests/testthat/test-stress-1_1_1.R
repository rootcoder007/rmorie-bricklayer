test_that("jsgzdec refuses a damaged gzip member at once", {
  enc <- jsgzenc(list(a = seq_len(5000)), raw = TRUE)
  bad <- enc
  mid <- 11:(length(bad) - 8L)
  bad[mid] <- rev(bad[mid])
  expect_error(jsgzdec(bad), "jsgzdec: `txt` is")
  expect_identical(jsgzdec(enc)$a, seq_len(5000))
})

test_that("jsunser says an object without a type is not jsser's", {
  msg <- "not JSON written by jsser"
  expect_error(jsunser("{\"a\":1}"), msg)
  expect_error(jsunser("{\"type\":null}"), msg)
  expect_error(jsunser("{\"type\":[\"a\",\"b\"]}"), msg)
  expect_error(jsunser("{\"type\":\"list\",\"value\":[1]}"), msg)
  expect_identical(jsunser(jsser(list(a = 1, b = NULL))), list(a = 1, b = NULL))
})

test_that("bldl does not wait past tmout between attempts", {
  got <- new.env()
  got$slept <- numeric()
  got$n <- 0L
  local_mocked_bindings(
    .bl_sleep = function(s) got$slept <- c(got$slept, s),
    .bl_http_download = function(...) {
      got$n <- got$n + 1L
      list(status = 503L, retry_after = "99999", bytes = 0, error = "")
    }
  )
  a <- list(tmout = 30, hdr_lines = character(), maxbytes = 1e6)
  expect_error(
    .bl_dl_net("https://example.org/x", tempfile(), a, NULL, TRUE, "x"),
    "answered HTTP 503"
  )
  expect_identical(got$n, 1L)
  expect_length(got$slept, 0L)
  # a wait that fits is still taken
  a$tmout <- 3600
  expect_error(
    .bl_dl_net("https://example.org/x", tempfile(), a, NULL, TRUE, "x"),
    "answered HTTP 503"
  )
  expect_identical(got$slept, c(60, 60, 60))
})

test_that("migrate leaves calls of a name the script defines", {
  src <- c(
    "rate <- function(x) x",
    "rate(2)",
    "y <- rate(3)",
    "rmoriebricklayer::rate(d)",
    "share(d)"
  )
  r <- .bl_migrate_text(src)
  expect_identical(r$lines[1:3], src[1:3])
  expect_identical(r$lines[4], "rmoriebricklayer::rtcalc(d)")
  expect_identical(r$lines[5], "shrs(d)")
})

test_that("svydes takes a replicate column with no positive entry", {
  d <- data.frame(y = 1:4, w = 1, r1 = 0, r2 = c(2, 2, 0, 0))
  expect_no_error(
    suppressWarnings(svydes(d, w = "w", reps = c("r1", "r2"), type = "jk1"))
  )
})

test_that("removed commands and functions say they were removed", {
  expect_match(.bl_unknown_verb("login", "rmbl"), "removed in 1.1.1")
  expect_match(.bl_unknown_verb("logout", "rmbl"), "no sign-in")
  expect_match(.bl_unknown_verb("lgin", "rmbl"), "unknown verb")
  expect_null(.bl_gone("doctor"))
  run <- function(a) {
    got <- new.env()
    st <- blcli(a, out = function(...) got$txt <- c(got$txt, paste0(...)))
    list(st = st, txt = paste(got$txt, collapse = ""))
  }
  r <- run(c("archive", "find", "x"))
  expect_identical(r$st, 2L)
  expect_match(r$txt, "archive find` was removed in 1.1.1")
  r <- run(c("help", "login"))
  expect_identical(r$st, 2L)
  expect_match(r$txt, "removed in 1.1.1")
  expect_match(run(c("help", "nosuchtopic"))$txt, "no help topic")
  r <- run(c("describe", "arcfind"))
  expect_identical(r$st, 1L)
  expect_match(r$txt, "archive.rmorie.com")
  expect_match(run(c("describe", "nosuchfn"))$txt, "no help page")
  expect_match(
    run(c("describe", "yoy"))$txt,
    "1.0.0 name of yoychg() (renamed in 1.1.1)",
    fixed = TRUE
  )
  expect_match(
    .bl_old_note(.bl_old_row("rate")),
    "0.5.x name of rtcalc() (renamed in 1.0.0)",
    fixed = TRUE
  )
  r <- run(c("functions", "xyz["))
  expect_identical(r$st, 1L)
  expect_match(r$txt, "is not a regular expression")
})

test_that("a folder that cannot be made is refused in words", {
  skip_on_os("windows")
  skip_if(file.access("/", 2L) == 0L, "the root folder is writable")
  expect_error(usecpstmpl("/nonexistent/dir/file"), "cannot create the folder")
  expect_error(mkbndlproj("/nonexistent/dir/file"), "cannot create the folder")
  d <- file.path(withr::local_tempdir(), "a")
  expect_null(.rmbl_mkdir(d, "dir"))
  expect_true(dir.exists(d))
})

test_that("blcli refuses a primitive as out", {
  expect_error(blcli("version", out = sum), "must be a function that writes")
})

test_that("a model reply whose content is a number is not a reply", {
  bad <- list(choices = list(list(message = list(content = 42))))
  expect_error(.bl_llm_parse(list(api = "openai"), bad), "wrong type")
  ok <- list(choices = list(list(message = list(content = "hi"))))
  expect_identical(.bl_llm_parse(list(api = "openai"), ok)$text, "hi")
})

test_that("siuprs does not warn on bytes that are not UTF-8", {
  h <- rawToChar(as.raw(c(
    charToRaw("<html><body><p>caf"),
    0xe9,
    charToRaw("</p></body></html>")
  )))
  expect_no_warning(r <- siuprs(h))
  expect_type(r, "character")
})

test_that("data with no subcommand is a usage line, and a bad key is refused", {
  local_mocked_bindings(
    dtabs = function(...) stop("the table list was downloaded"),
    dload = function(...) stop("a table was downloaded")
  )
  run <- function(a) {
    got <- new.env()
    st <- blcli(a, out = function(...) got$txt <- c(got$txt, paste0(...)))
    list(st = st, txt = paste(got$txt, collapse = ""))
  }
  r <- run("data")
  expect_identical(r$st, 2L)
  expect_match(r$txt, "^usage: ")
  for (k in c("../../up/tbl", "/abs/tbl", "-x", "a b")) {
    r <- run(c("data", "pull", k))
    expect_identical(r$st, 2L, info = k)
    expect_match(r$txt, "is not a table key", info = k)
  }
})

test_that("blfetch says why the live address was not reached", {
  expect_error(
    .bl_fetch_fail(-10L, "https://example.org/x", "f", "TLS: unexpected eof"),
    "could not reach https://example.org/x (TLS: unexpected eof); ",
    fixed = TRUE
  )
  expect_error(
    .bl_fetch_fail(-10L, "https://example.org/x", "f"),
    "could not reach https://example.org/x; ",
    fixed = TRUE
  )
  expect_error(
    .bl_fetch_fail(-5030L, "https://example.org/x", "f", "ignored"),
    "answered HTTP 503; ",
    fixed = TRUE
  )
})

test_that("child processes of the tests keep their session folders here", {
  skip_on_os("windows")
  expect_identical(Sys.getenv("TMPDIR"), file.path(tempdir(), "kids"))
})
