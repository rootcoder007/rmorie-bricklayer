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

test_that("migrate reads a definition only where it is in reach", {
  mig <- function(...) .bl_migrate_text(c(...))$lines
  # defined inside a function, as a parameter, in local(): the top level's
  # call is the package's
  expect_identical(
    mig("f <- function() { rate <- function(x) x; rate(5) }", "rate(d)"),
    c("f <- function() { rate <- function(x) x; rate(5) }", "rtcalc(d)")
  )
  expect_identical(
    mig("g <- function(rate) rate(1)", "rate(d)"),
    c("g <- function(rate) rate(1)", "rtcalc(d)")
  )
  expect_identical(
    mig("local({ yoy <- function(d) d; yoy(1) })", "yoy(d)"),
    c("local({ yoy <- function(d) d; yoy(1) })", "yoychg(d)")
  )
  # a definition through a string, a backquoted name, or <<- from a function
  own <- list(
    c("assign(\"yoy\", function(d) d)", "yoy(1)"),
    c("`rate` <- function(x) x", "rate(1)"),
    c("setGeneric(\"share\", function(x) standardGeneric(\"share\"))",
      "share(1)"),
    c("f <- function() rate <<- function(x) x", "rate(2)"),
    c("rate <- function(x) x", "lapply(1:3, rate)",
      "do.call(\"rate\", list(1))")
  )
  for (src in own) {
    expect_identical(mig(src), src, info = src[1L])
  }
  expect_identical(.bl_pd_scopes(utils::getParseData(
    parse(text = "x", keep.source = TRUE)
  ), 1L), 0L)
})

test_that("bldl gives each further attempt what is left of tmout", {
  got <- new.env()
  got$t <- integer()
  local_mocked_bindings(
    .bl_sleep = function(s) Sys.sleep(0.6),
    .bl_http_download = function(url, dest, tmout, ...) {
      got$t <- c(got$t, tmout)
      list(status = 503L, retry_after = "1", bytes = 0, error = "")
    }
  )
  a <- list(tmout = 3, hdr_lines = character(), maxbytes = 1e6)
  expect_error(
    .bl_dl_net("https://example.org/x", tempfile(), a, NULL, TRUE, "x"),
    "answered HTTP 503"
  )
  expect_identical(got$t[1L], 3L)
  expect_true(all(diff(got$t) <= 0L))
  expect_lt(got$t[length(got$t)], 3L)
  expect_true(all(got$t >= 1L))
})

test_that("jsunser, jsser and jsgzenc refuse what the other cannot read", {
  msg <- "not JSON written by jsser"
  expect_error(jsunser("{\"type\":\"nonsense\"}"), "an unknown type: nonsense")
  expect_error(
    jsunser("{\"type\":\"double\",\"value\":\"x\"}"),
    "a value that is not double"
  )
  expect_error(jsunser("{\"type\":\"list\",\"value\":5,\"attributes\":7}"), msg)
  nest <- function(d) {
    x <- list()
    for (i in seq_len(d)) x <- list(x)
    x
  }
  expect_identical(jsunser(jsser(nest(40))), nest(40))
  expect_error(jsser(nest(60)), "nested too deeply for jsser")
  expect_error(jsser(nest(3000)), "nested too deeply for jsser")
  expect_identical(.rmbl_json_depth(1), 0L)
  expect_identical(.rmbl_json_depth(list(list(1), 2)), 2L)
})

test_that("a table key is db/table, checked before any download", {
  local_mocked_bindings(
    dload = function(...) stop("a table was downloaded")
  )
  for (k in c("a/b/c", "abc", strrep("a/", 150), "a//b")) {
    got <- new.env()
    st <- blcli(
      c("data", "pull", k),
      out = function(...) got$txt <- c(got$txt, paste0(...))
    )
    expect_identical(st, 2L, info = k)
    expect_match(paste(got$txt, collapse = ""), "is not a table key")
    expect_lt(nchar(paste(got$txt, collapse = "")), 200L)
  }
})

test_that("the launchers keep a failure's own status", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  invisible(utils::capture.output(suppressMessages(instcli(dir = d))))
  for (f in c(
    file.path(d, "rmbl"),
    system.file("bin", "rmbl", package = "rmoriebricklayer")
  )) {
    txt <- paste(readLines(f), collapse = "\n")
    expect_match(txt, "trap 'rc=130' INT", fixed = TRUE, info = f)
    expect_false(grepl("exec Rscript", txt, fixed = TRUE), info = f)
    expect_false(grepl("200", txt, fixed = TRUE), info = f)
  }
})

test_that("dload reads part of a table: columns, a row cap, a filter", {
  f <- tempfile(fileext = ".csv.gz")
  d <- data.frame(
    id = 1:40,
    `Geo (3)` = rep(c("Ontario", "Quebec"), 20),
    val = (1:40) / 4,
    txt = rep(c("a,b", "c \"q\"", NA, "d"), 10),
    check.names = FALSE
  )
  con <- gzfile(f, "wt")
  utils::write.csv(d, con, row.names = FALSE)
  close(con)
  full <- .bl_read_csv_gz(f)
  # whole, in pieces smaller than the table: the full reader's data frame
  expect_identical(.bl_csv_part(f, NULL, Inf, NULL, piece = 7L), full)
  # columns by the manifest's name or the data frame's, and a row cap
  got <- .bl_csv_part(f, c("Geo (3)", "val"), 5, NULL, piece = 3L)
  expect_identical(got, full[1:5, c("Geo..3.", "val")])
  expect_identical(.bl_csv_part(f, "Geo..3.", 2, NULL)[[1L]], full[[2L]][1:2])
  # a filter sees typed columns, piece by piece
  q <- function(x) x$Geo..3. == "Quebec" & x$val > 5
  ref <- full[full$Geo..3. == "Quebec" & full$val > 5, ]
  rownames(ref) <- NULL
  expect_identical(.bl_csv_part(f, NULL, Inf, q, piece = 6L), ref)
  expect_identical(.bl_csv_part(f, "id", 3, q, piece = 6L)$id, ref$id[1:3])
  none <- .bl_csv_part(f, NULL, Inf, function(x) rep(FALSE, nrow(x)))
  expect_identical(dim(none), c(0L, 4L))
  expect_error(.bl_csv_part(f, "nope", Inf, NULL), "no column nope")
  expect_error(
    .bl_csv_part(f, NULL, Inf, function(x) TRUE),
    "TRUE or FALSE for each row"
  )
  # a join cut short leaves no file under the final name
  p <- file.path(withr::local_tempdir(), c("1", "2"))
  writeBin(as.raw(1:3), p[1L])
  writeBin(as.raw(4:5), p[2L])
  dest <- paste0(p[1L], ".out")
  .bl_data_join(p, dest)
  expect_identical(readBin(dest, "raw", 10L), as.raw(1:5))
  expect_false(file.exists(paste0(dest, ".join")))
  unlink(dest)
  missing <- c(p[1L], file.path(dirname(p[1L]), "no"))
  expect_error(suppressWarnings(.bl_data_join(missing, dest)))
  expect_false(file.exists(dest))
  expect_false(file.exists(paste0(dest, ".join")))
  # the parts are freed as they are joined
  expect_false(any(file.exists(p)))
  # a write that fails (a full disk: writeBin() only warns) is an error in
  # words, and leaves no file
  writeBin(as.raw(1:3), p[1L])
  local_mocked_bindings(
    .bl_write_raw = function(buf, out) warning("problem writing to connection")
  )
  expect_error(.bl_data_join(p[1L], dest), "is full or cannot be written")
  expect_error(.bl_data_join(p[1L], dest), "rmoriebricklayer.dcache")
  expect_false(file.exists(dest))
  expect_false(file.exists(paste0(dest, ".join")))
  expect_false(.bl_csv_part_args(NULL, Inf, NULL))
  expect_true(.bl_csv_part_args("a", Inf, NULL))
  expect_true(.bl_csv_part_args(NULL, 3, NULL))
  expect_true(.bl_csv_part_args(NULL, Inf, identity))
  expect_error(.bl_csv_part_args(1, Inf, NULL), "column names")
  expect_error(.bl_csv_part_args(NULL, 0, NULL), "whole number of rows")
  expect_error(.bl_csv_part_args(NULL, 1.5, NULL), "whole number of rows")
  expect_error(.bl_csv_part_args(NULL, Inf, 3), "must be a function")
})

test_that("dload says how large a table is before reading it whole", {
  big <- list(datasets = list(
    list(key = "a/big", rows = 9e7, columns = as.list(letters[1:16])),
    list(key = "a/small", rows = 10, columns = as.list(letters[1:3]))
  ))
  local_mocked_bindings(dmnf = function(...) big)
  expect_message(.bl_data_big_note("a/big"), "90,000,000 rows and 16 columns")
  expect_message(.bl_data_big_note("a/big"), "`cols`, `n` or `keep`")
  expect_no_message(.bl_data_big_note("a/small"))
  expect_no_message(.bl_data_big_note("a/unknown"))
})
