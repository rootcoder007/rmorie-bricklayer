# The LOW findings of the audit of 21478080 (P1 to P8, L7).

test_that("P1: NaN stays NaN, read whole or in parts", {
  f <- tempfile(fileext = ".csv.gz")
  con <- gzfile(f, "wb")
  writeBin(charToRaw("z,y\n1.5,a\nNaN,b\nNA,c\n3,d\n"), con)
  close(con)
  w <- .bl_read_csv_gz(f)
  expect_true(is.nan(w$z[2L]))
  expect_true(is.na(w$z[3L]) && !is.nan(w$z[3L]))
  expect_identical(.bl_csv_part(f, NULL, Inf, NULL, piece = 3L), w)
  expect_identical(.bl_csv_part(f, "z", Inf, NULL)$z, w$z)
  # jsser() writes a complex NaN as "NaN+0i"; jsunser() refused it
  o <- c(NaN + 0i, complex(real = 1, imaginary = NaN), 2i)
  expect_identical(jsunser(jsser(o)), o)
  # rmbl data pull wrote NaN as NA
  d <- data.frame(
    x = c(1.5, NaN, NA),
    z = c(NaN + 0i, 1i, NA),
    s = c("a", "b", NA)
  )
  out <- tempfile(fileext = ".csv")
  .bl_write_pull(d, out)
  back <- utils::read.csv(out)
  expect_true(is.nan(back$x[2L]))
  expect_true(is.na(back$x[3L]) && !is.nan(back$x[3L]))
  expect_true(is.nan(back$z[1L]))
  expect_identical(back$s, d$s)
  plain <- tempfile(fileext = ".csv")
  utils::write.csv(d[3L], plain, row.names = FALSE)
  .bl_write_pull(d[3L], out)
  expect_identical(readLines(out), readLines(plain))
})

test_that("P2: migrate reads assign() as R matches it, backquotes, loops", {
  n <- function(...) .bl_migrate_text(c(...))$n
  expect_identical(
    n('assign(value = function(x) x, x = "yoy", envir = globalenv())',
      "yoy(1)"),
    0L
  )
  expect_identical(n('assign(x = "yoy", function(x) x)', "yoy(1)"), 0L)
  expect_identical(.bl_migrate_text("`yoy`(1)")$lines, "yoychg(1)")
  expect_identical(n("for (yoy in 1:3) print(yoy)", "yoy(1)"), 1L)
  expect_identical(n("yoy <- 3", "yoy(1)"), 1L)
  # a function the script defines is still its own
  expect_identical(n("yoy <- function(x) x", "yoy(1)"), 0L)
  expect_identical(n("`yoy` <- function(x) x", "`yoy`(1)"), 0L)
  # get() finds the loop variable; do.call() looks for a function
  expect_identical(n("for (yoy in 1:3) print(yoy)", 'get("yoy")'), 0L)
  expect_identical(
    n("for (yoy in 1:3) print(yoy)", 'do.call("yoy", list(1))'),
    1L
  )
})

test_that("P3: text that is not valid UTF-8 is refused once, in words", {
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]))
  b <- rawToChar(as.raw(c(0x61, 0xff, 0x62)))
  calls <- list(
    function() jsgzdec(b),
    function() jsb64dec(b),
    function() jsser(b),
    function() bldl(b, tempfile()),
    function() blfetch(b, tempfile()),
    function() sctidy(b),
    function() cunif(b),
    function() clncolnms(b),
    function() prsbands(b),
    function() co2int(b),
    function() capenv(b),
    function() ruledstn(b),
    function() instcli(dir = file.path(tempdir(), b))
  )
  for (i in seq_along(calls)) {
    w <- character()
    e <- tryCatch(
      withCallingHandlers(calls[[i]](), warning = function(x) {
        w <<- c(w, conditionMessage(x))
        invokeRestart("muffleWarning")
      }),
      error = conditionMessage
    )
    expect_length(w, 0L)
    expect_match(e, "not valid UTF-8|outside the base64 alphabet", info = i)
    expect_false(grepl("input string", e), info = i)
  }
  got <- character()
  st <- blcli(b, out = function(...) got <<- c(got, paste0(...)))
  expect_identical(st, 2L)
  expect_length(got, 1L)
  expect_match(got, "argument 1 is not valid text")
})

test_that("P4: migrate on a folder or an unreadable file: one line", {
  got <- character()
  out <- function(...) got <<- c(got, paste0(...))
  d <- withr::local_tempdir()
  expect_no_warning(st <- blcli(c("migrate", d), out = out))
  expect_identical(st, 1L)
  expect_length(got, 1L)
  expect_match(got, "a folder, not an R file")
  f <- file.path(d, "a.R")
  writeLines("yoy(1)", f)
  Sys.chmod(f, "000")
  on.exit(Sys.chmod(f, "644"), add = TRUE)
  skip_if(file.access(f, 4L) == 0L, "this user reads any file")
  got <- character()
  expect_no_warning(st <- blcli(c("migrate", f), out = out))
  expect_identical(st, 1L)
  expect_length(got, 1L)
  expect_match(got, "cannot be read")
})

test_that("P6: a cached manifest that lists no tables is fetched again", {
  d <- withr::local_tempdir()
  withr::local_options(rmoriebricklayer.dcache = d)
  p <- file.path(d, "manifest.json")
  writeLines('{"datasets":[]}', p)
  fetched <- 0L
  local_mocked_bindings(.bl_data_get = function(path, dest, ...) {
    fetched <<- fetched + 1L
    writeLines('{"datasets":[{"key":"db/t"}]}', dest)
    invisible(dest)
  })
  m <- .bl_dmnf_raw()
  expect_identical(fetched, 1L)
  expect_length(m$datasets, 1L)
  writeLines('{"datasets":[]}', p)
  local_mocked_bindings(.bl_data_get = function(...) stop("no connection"))
  expect_error(
    .bl_dmnf_raw(),
    "lists no tables, and a fresh one could not be had: no connection"
  )
})

test_that("P7: jsunser() refuses a class or attribute that does not fit", {
  a <- function(...) {
    paste0('"attributes":{', paste(c(...), collapse = ","), "}")
  }
  chr <- function(nm, v) {
    sprintf(
      '"%s":{"type":"character","value":[%s]}',
      nm,
      paste0('"', v, '"', collapse = ",")
    )
  }
  docs <- c(
    sprintf(
      '{"type":"character","value":["x"],%s}',
      a(chr("class", "Date"))
    ),
    sprintf(
      '{"type":"integer","value":[1,1],%s}',
      a(chr("class", "factor"), chr("levels", c("a", "a")))
    ),
    sprintf(
      '{"type":"integer","value":[1],%s}',
      a(chr("class", "environment"))
    ),
    sprintf('{"type":"integer","value":[1,2,3],%s}', a(chr("names", "a"))),
    sprintf(
      '{"type":"double","value":[1],%s}',
      a(chr("class", c("POSIXct", "POSIXt")), chr("tzone", "No/Such_Zone"))
    ),
    sprintf(
      '{"type":"double","value":[1],%s}',
      a(chr("class", "difftime"), chr("units", "parsecs"))
    )
  )
  for (d in docs) {
    expect_error(jsunser(d), "^jsunser: `txt` is not JSON written by jsser")
  }
  ok <- list(
    as.Date("2020-01-01") + 0:1,
    as.POSIXct("2020-01-01 10:00:00", tz = "UTC"),
    as.difftime(3, units = "mins"),
    factor(c("b", "a")),
    c(a = 1L, b = 2L),
    data.frame(x = 1:2)
  )
  for (o in ok) {
    expect_identical(jsunser(jsser(o)), o)
  }
})

test_that("P8: the js decoders name themselves in every refusal", {
  g <- jsgzenc(list(a = 1))
  r <- jsb64dec(g)
  expect_error(
    jsgzdec(jsb64enc(c(r, r))),
    "^jsgzdec: `txt` holds more than one JSON value"
  )
  bad <- paste0(substr(g, 1L, 4L), "!", substring(g, 6L))
  expect_error(jsgzdec(bad), "^jsgzdec: `txt` holds characters outside")
  expect_error(jsgzdec(paste0(g, g)), "^jsgzdec: ")
  expect_error(jsb64dec("a!b"), "^jsb64dec: `input` holds characters")
  expect_error(jsb64udec("a!b"), "^jsb64udec: ")
  expect_error(jsb64udec("YQ==Yg"), "^jsb64udec: `input` has `=` padding")
  expect_error(
    jsunser('{"type":"raw","value":"!!"}'),
    "^jsunser: `txt` holds characters outside"
  )
})

test_that("L7: a Ctrl-C the launcher saw is 130, even if R ended 0", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  invisible(utils::capture.output(suppressMessages(instcli(dir = d))))
  # a stand-in Rscript that interrupts the launcher, then exits 0, as R does
  # when the Ctrl-C lands as it quits
  fake <- file.path(d, "fake")
  dir.create(fake)
  writeLines(c("#!/bin/sh", "kill -INT $PPID", "sleep 1", "exit 0"),
             file.path(fake, "Rscript"))
  Sys.chmod(file.path(fake, "Rscript"), "0755")
  for (f in c(
    file.path(d, "rmbl"),
    system.file("bin", "rmbl", package = "rmoriebricklayer")
  )) {
    st <- withr::with_envvar(
      c(PATH = paste(fake, Sys.getenv("PATH"), sep = .Platform$path.sep)),
      system2("sh", shQuote(f), stdout = FALSE, stderr = FALSE)
    )
    expect_identical(as.integer(st), 130L, info = f)
  }
})
