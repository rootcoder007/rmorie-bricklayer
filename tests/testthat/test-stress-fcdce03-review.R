# The findings of the fcdce03 review (the fourth pass over the 0.5.12 branch), each reproduced
# the way the review did and then shown closed.

write_bytes <- function(path, bytes) {
  con <- file(path, "wb")
  on.exit(close(con))
  writeBin(bytes, con)
  invisible(path)
}

read_out <- function(f) paste(readLines(f, warn = FALSE), collapse = "")

wait_for <- function(outs, seconds = 30) {
  for (w in seq_len(seconds * 10)) {
    if (all(file.exists(outs)) && all(nzchar(vapply(outs, read_out, "")))) return(TRUE)
    Sys.sleep(0.1)
  }
  FALSE
}

test_that("Z1: a cached table that fails its digest is refused when the manifest cannot be re-read", {
  dest <- withr::local_tempfile(fileext = ".csv.gz")
  writeLines("1,2", dest)
  good <- tolower(csha256(readBin(dest, "raw", file.size(dest))))
  man <- function(first, refreshed) {
    function(refresh = FALSE) {
      if (!refresh) return(list(datasets = list(list(key = "db/t", sha256 = first))))
      if (is.function(refreshed)) refreshed() else list(datasets = list(list(key = "db/t", sha256 = refreshed)))
    }
  }
  # the file matches: accepted without a refresh
  testthat::local_mocked_bindings(dmnf = man(good, function() stop("down")))
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", dest))
  # tampered after the manifest was cached, and the refresh fails (server down): refused, deleted
  writeLines("666,TAMPERED-CACHE", dest)
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", dest), "does not match")
  expect_false(file.exists(dest))
  # tampered, and the refreshed manifest returns 404 (no datasets): refused
  writeLines("666,TAMPERED-CACHE", dest)
  testthat::local_mocked_bindings(dmnf = man(good, function() list(datasets = list())))
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", dest), "does not match")
  expect_false(file.exists(dest))
  # a table rebuilt upstream: the refreshed manifest lists the new digest, so the new file passes
  writeLines("3,4", dest)
  rebuilt <- tolower(csha256(readBin(dest, "raw", file.size(dest))))
  testthat::local_mocked_bindings(dmnf = man(good, rebuilt))
  expect_true(rmoriebricklayer:::.bl_data_check_sha("db/t", dest))
  # a digest that is a list, or not a digest: refused, and the unverified file leaves the cache
  testthat::local_mocked_bindings(dmnf = function(refresh = FALSE) {
    list(datasets = list(list(key = "db/t", sha256 = list(rebuilt, "x"))))
  })
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", dest), "not a SHA-256")
  expect_false(file.exists(dest))
  writeLines("3,4", dest)
  testthat::local_mocked_bindings(dmnf = function(refresh = FALSE) {
    list(datasets = list(list(key = "db/t", sha256 = "sha256:zz")))
  })
  expect_error(rmoriebricklayer:::.bl_data_check_sha("db/t", dest), "not a SHA-256")
  expect_false(file.exists(dest))
})

test_that("Z1 sibling: a MORIE_DATA_URL that is not the document's address is named, not 'run login'", {
  testthat::local_mocked_bindings(.bl_hosted_key = function(...) "sk-x",
                                  .rmbl_services_data = function(...) list(base_url = "https://data.example.org"))
  withr::local_envvar(MORIE_DATA_URL = "https://elsewhere.example.org")
  expect_error(suppressMessages(rmoriebricklayer:::.bl_data_get("/x.csv.gz", tempfile())), "MORIE_DATA_URL")
})

test_that("Z8: two processes signing with copies of one key cannot both take an index", {
  skip_on_cran()
  rscript <- file.path(R.home("bin"), "Rscript")
  skip_if_not(file.exists(rscript))
  idx <- withr::local_tempfile(fileext = ".txt")
  withr::local_options(rmoriebricklayer.xmssidxfile = idx)   # the keys are born into this record
  kf <- withr::local_tempfile(fileext = ".rds")
  k0 <- pqckg(height = 3)
  saveRDS(k0, kf)
  kid0 <- xmss_kid(k0)
  lib <- paste(.libPaths(), collapse = .Platform$path.sep)
  child <- function(key_file, msg, expr) {
    sprintf(paste0("suppressMessages(library(rmoriebricklayer, lib.loc = strsplit('%s', '%s', fixed = TRUE)[[1]]));",
                   "options(rmoriebricklayer.xmssidxfile = '%s'); k <- readRDS('%s'); %s"),
            lib, .Platform$path.sep, idx, key_file, sprintf(expr, msg))
  }
  reserve <- "r <- tryCatch(as.integer(cpssign('%s', k)$index), error = function(e) -1L); cat(r)"
  outs <- c(withr::local_tempfile(fileext = ".out"), withr::local_tempfile(fileext = ".out"))
  for (rounds in 1:3) {
    for (i in 1:2) {
      system2(rscript, c("-e", shQuote(child(kf, c("pay-alice", "pay-mallory")[i], reserve))),
              stdout = outs[i], stderr = FALSE, wait = FALSE)
    }
    expect_true(wait_for(outs))
    got <- as.integer(vapply(outs, read_out, ""))
    expect_false(all(got == 0L), info = paste("both processes signed index 0 in round", rounds))
    expect_true(any(got == 0L) || all(got == -1L))
    unlink(outs)
    writeLines(paste(kid0, -1L, sep = "\t"), idx)   # back to "registered, unused" for the next round
  }
  # two different keys: both records survive
  k1 <- pqckg(height = 3)
  k2 <- pqckg(height = 3)
  saveRDS(k1, kf)
  kf2 <- withr::local_tempfile(fileext = ".rds")
  saveRDS(k2, kf2)
  for (i in 1:2) {
    system2(rscript, c("-e", shQuote(child(c(kf, kf2)[i], "m", "cat(cpssign('%s', k)$index)"))),
            stdout = outs[i], stderr = FALSE, wait = FALSE)
  }
  expect_true(wait_for(outs))
  rec <- rmoriebricklayer:::.rmbl_xmss_record_read(idx)
  kids <- c(xmss_kid(k1), xmss_kid(k2))
  expect_true(all(kids %in% names(rec)))   # neither process wiped the other's line
  expect_identical(unname(rec[kids]), c(0L, 0L))
})

test_that("Z2 and Z3: the record fails closed; the off switch warns; a non-path value is refused", {
  f <- withr::local_tempfile(fileext = ".txt")
  withr::local_options(rmoriebricklayer.xmssidxfile = f)
  k <- pqckg(height = 2)
  s1 <- cpssign("first", k)
  kid <- xmss_kid(k)
  expect_identical(rmoriebricklayer:::.rmbl_xmss_record_read(f), stats::setNames(0L, kid))
  bad_records <- list(sprintf('{"%s": "abc"}', kid), paste0(kid, "\tabc"), paste0(kid, "\t-2"),
                      paste0(kid, "\t1e10"), paste0(kid, "\t[5, 9]"), "{}")
  for (bad in bad_records) {
    xmssfgt()   # the session record: only the file is in play
    writeLines(bad, f)
    expect_error(cpssign("second", k), "malformed line", info = bad)
  }
  # a well-formed record from another session refuses the stale key
  writeLines(paste(kid, 0L, sep = "\t"), f)
  expect_error(cpssign("second", k), "already used")
  # Z2: the record deleted, the session forgotten: a stale key claiming index 0 is refused, and
  # a key from "another machine" must be vouched for before it signs
  xmssfgt()
  expect_error(cpssign("second", k), "not in the used-index record")
  expect_false(file.exists(f))
  elsewhere <- withr::with_options(list(rmoriebricklayer.xmssidxfile = withr::local_tempfile(fileext = ".txt")),
                                   pqckg(height = 2))
  rm(list = xmss_kid(elsewhere), envir = rmoriebricklayer:::.rmbl_xmss_used)
  expect_error(cpssign("x", elsewhere), "not in the used-index record")
  expect_identical(xmssregkey(elsewhere), elsewhere)
  expect_identical(as.integer(cpssign("x", elsewhere)$index), 0L)
  expect_error(xmssregkey(elsewhere), "has signed here before")
  expect_error(xmssregkey("x"), "signing key")
  writeLines(paste(kid, 0L, sep = "\t"), f)
  # the operating-system lock is released after a refusal and after a signature: the next one
  # takes it at once
  k2 <- xmssadv(k, s1)
  expect_identical(as.integer(cpssign("second", k2)$index), 1L)
  # a lock directory left by 0.5.12-pre is not the lock any more and stops nothing
  dir.create(paste0(f, ".lock"))
  Sys.setFileTime(paste0(f, ".lock"), Sys.time() - 3600)
  k3 <- xmssadv(k2, s1)
  expect_identical(as.integer(cpssign("third", k3)$index), 2L)
  expect_true(file.exists(paste0(f, ".flock")))
  # off: every signature warns, and the session alone remembers
  withr::local_options(rmoriebricklayer.xmssidxfile = FALSE)
  k4 <- pqckg(height = 2)
  expect_warning(cpssign("m", k4), "record is off")
  expect_error(suppressWarnings(cpssign("m", k4)), "already used")
  # values that are not paths
  for (v in list(TRUE, "0", "FALSE", "yes")) {
    withr::local_options(rmoriebricklayer.xmssidxfile = v)
    expect_error(rmoriebricklayer:::.rmbl_xmss_index_file(), "not a file path|must be a file path",
                 info = format(v))
  }
})

test_that("xmssadv() checks what it is given and consults the record", {
  f <- withr::local_tempfile(fileext = ".txt")
  withr::local_options(rmoriebricklayer.xmssidxfile = f)
  k <- pqckg(height = 2)
  s <- cpssign("m", k)
  # an edited index outside the key, a foreign signature with the message, and the record's say
  bad <- s
  bad$index <- 25
  expect_error(xmssadv(k, bad), "valid index")
  expect_error(xmssadv(k, s, msg = "other"), "does not verify")
  k2 <- xmssadv(k, s, msg = "m")
  expect_identical(k2$next_index, 1L)
  s2 <- cpssign("m2", k2)
  stale <- k   # a copy from before any signature: the record moves it past index 1
  expect_identical(xmssadv(stale, s)$next_index, 2L)
  # an attestation and an unclassed signature (a recode manifest's) both advance the key
  k3 <- xmssadv(k2, s2)
  a <- cpsatst(list(n = 1), k3)
  k4 <- xmssadv(k3, a)
  expect_identical(k4$next_index, 3L)
  expect_identical(xmssadv(k3, unclass(a$signature))$next_index, 3L)
  expect_warning(xmssadv(k4, cpssign("last", k4)), "all 4 of its one-time indices")
  # forgetting one key resets it to unused and leaves the other's line
  other <- pqckg(height = 2)
  cpssign("o", other)
  xmssfgt(k)
  rec <- rmoriebricklayer:::.rmbl_xmss_record_read(f)
  expect_identical(rec[[xmss_kid(other)]], 0L)
  expect_identical(rec[[xmss_kid(k)]], -1L)
  expect_identical(as.integer(cpssign("again", k)$index), 0L)
  expect_error(xmssfgt("x"), "must be the signing key")
})

test_that("Z11: every example and vignette that signs with XMSS points the record at a temporary file", {
  root <- tryCatch(testthat::test_path("..", ".."), error = function(e) NA)
  skip_if(is.na(root) || !dir.exists(file.path(root, "R")))
  for (f in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) {
    lines <- readLines(f, warn = FALSE)
    for (st in grep("^#' @examples", lines)) {
      en <- st
      while (en < length(lines) && startsWith(lines[en + 1], "#'") && !startsWith(lines[en + 1], "#' @")) {
        en <- en + 1
      }
      block <- lines[st:en]
      if (any(grepl("pqckg(", block, fixed = TRUE))) {
        expect_true(any(grepl("xmssidxfile", block, fixed = TRUE)), info = paste(basename(f), st))
      }
    }
  }
  vdir <- file.path(root, "vignettes")
  if (dir.exists(vdir)) {
    for (v in list.files(vdir, pattern = "[.]Rmd$", full.names = TRUE)) {
      txt <- readLines(v, warn = FALSE)
      if (any(grepl("pqckg(", txt, fixed = TRUE))) {
        expect_true(any(grepl("xmssidxfile", txt, fixed = TRUE)), info = basename(v))
      }
    }
  }
})

test_that("Z4: a Latin-1 or UTF-16 exposure CSV is read whole, never cut at the first non-UTF-8 byte", {
  f <- withr::local_tempfile(fileext = ".csv")
  rows <- c("exposure,income,city", sprintf("%d,%d,Ottawa", rep(c(12, 60), each = 500), seq_len(1000)))
  rows[502] <- "60,3,Montr\xe9al"
  write_bytes(f, charToRaw(paste0(paste(rows, collapse = "\n"), "\n")))
  v <- suppressMessages(vrfpol("pm25", expcsv = f))
  expect_identical(v$status, "ok")
  expect_equal(v$inputs$expomean, 36, tolerance = 1e-12)       # all 1,000 rows (12.1 was the cut file)
  expect_equal(v$inputs$expoprev, 1, tolerance = 1e-12)
  expect_message(vrfpol("pm25", expcsv = f), "read as Latin-1")
  # the same rows as UTF-16LE with a BOM
  g <- withr::local_tempfile(fileext = ".csv")
  rows16 <- rows
  rows16[502] <- "60,3,Montreal"
  u16 <- iconv(list(charToRaw(paste0(paste(rows16, collapse = "\n"), "\n"))),
               from = "UTF-8", to = "UTF-16LE", toRaw = TRUE)[[1L]]
  write_bytes(g, c(as.raw(c(0xff, 0xfe)), u16))
  v16 <- vrfpol("pm25", expcsv = g)
  expect_identical(v16$status, "ok")
  expect_equal(v16$inputs$expomean, 36, tolerance = 1e-12)
  # a UTF-8 BOM still works, and NUL bytes are an error report, not a raw error
  h <- withr::local_tempfile(fileext = ".csv")
  write_bytes(h, c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("exposure\n30\n40\n")))
  expect_identical(vrfpol("pm25", expcsv = h)$status, "ok")
  write_bytes(h, c(charToRaw("exposure\n30\n"), as.raw(0), charToRaw("40\n")))
  vn <- vrfpol("pm25", expcsv = h)
  expect_identical(vn$status, "error")
  expect_match(vn$error, "NUL")
})

test_that("Z9 and Z7: hurwzeta() refuses a q below -1e6 at once; the sibling guards refuse flags and factors", {
  # a q far below zero is summed in closed form now: fast, and to full precision (review of 52a8883)
  t0 <- Sys.time()
  closed <- hurwzeta(2, 0.5) + hurwzeta(2, 0.5) - hurwzeta(2, 1e9 + 0.5)
  expect_equal(hurwzeta(2, q = -1e9 + 0.5), closed, tolerance = 1e-12)
  expect_lt(as.numeric(difftime(Sys.time(), t0, units = "secs")), wall_limit(2))
  expect_equal(hurwzeta(2, q = -0.5), 8.934802200544679, tolerance = 1e-9)
  expect_error(hurwzeta(2, q = TRUE), "logical")
  expect_error(topshr(c(1, 2, 3, 10), factor("0.5")), "numeric")
  expect_error(topshr(c(1, 2, 3, 10), "0.5"), "numeric")
  x <- c(rep(1, 30), 2, 2, 3, 5, 8, 13, 21, 34)
  expect_error(hilltlidx(x, xmin = TRUE), "logical")
  expect_error(hilltlidx(x, discrete = "yes"), "TRUE or FALSE")
  expect_error(hilltlidx(x, approx = NA), "TRUE or FALSE")
})

test_that("Z10: login and logout leave every other byte of credentials.json as it was", {
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_HOSTED_BASE_URL = NA)
  testthat::local_mocked_bindings(.bl_hosted_base = function(...) "https://llm.example.org")
  p <- rmoriebricklayer:::.bl_credentials_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  other <- paste0('"other_pkg": {"f": 3.14159265358979, "big": 12345678901234567890, "": "empty", ',
                  '"x": [1, 2.0, 1e300, null], "nom": "Montréal"}')
  orig <- paste0("{\n  ", other, ",\n  \"tail\": 1.0\n}\n")
  write_bytes(p, charToRaw(orig))
  rmoriebricklayer:::.bl_store_key("sk-new", user = "u@example.org")
  txt <- rmoriebricklayer:::.bl_read_text(p)
  expect_true(grepl(other, txt, fixed = TRUE))
  expect_true(grepl('"tail": 1.0', txt, fixed = TRUE))
  expect_true(grepl('"hosted_key": "sk-new"', txt, fixed = TRUE))
  expect_true(grepl('"hosted_base_url": "https://llm.example.org"', txt, fixed = TRUE))
  expect_identical(rmoriebricklayer:::.bl_read_credentials()$hosted_key, "sk-new")
  # a second login replaces the three members in place
  rmoriebricklayer:::.bl_store_key("sk-again")
  txt <- rmoriebricklayer:::.bl_read_text(p)
  expect_identical(lengths(regmatches(txt, gregexpr("hosted_key", txt, fixed = TRUE))), 1L)
  expect_true(grepl('"hosted_key": "sk-again"', txt, fixed = TRUE))
  expect_true(grepl(other, txt, fixed = TRUE))
  suppressMessages(dlogout())
  txt <- rmoriebricklayer:::.bl_read_text(p)
  expect_false(grepl("hosted_", txt, fixed = TRUE))
  expect_true(grepl(other, txt, fixed = TRUE))
  expect_true(grepl('"tail": 1.0', txt, fixed = TRUE))
  expect_true(is.list(rmoriebricklayer:::.bl_credentials_object(p)))
  # only this package's members: the file goes away
  write_bytes(p, charToRaw('{"hosted_key": "sk-only", "hosted_base_url": "https://llm.example.org"}'))
  suppressMessages(dlogout())
  expect_false(file.exists(p))
  # a file that is not an object is never written over
  write_bytes(p, charToRaw("[1, 2]"))
  expect_error(rmoriebricklayer:::.bl_store_key("sk-x"), "not a JSON object")
  expect_error(dlogout(), "not a JSON object")
  expect_identical(rmoriebricklayer:::.bl_read_text(p), "[1, 2]")
})

test_that("the top-level member scanner reads the shapes other packages write", {
  mem <- rmoriebricklayer:::.bl_json_top_members(' {"a": {"b": [1, {"c": "}"}]}, "": null, "d": "x\\"y", "e": 1e300} ')
  expect_identical(vapply(mem, `[[`, "", "key"), c("a", "", "d", "e"))
  expect_null(rmoriebricklayer:::.bl_json_top_members("[1]"))
  expect_null(rmoriebricklayer:::.bl_json_top_members('{"a": '))
  expect_identical(rmoriebricklayer:::.bl_json_top_members("{}"), list())
})

test_that("M3/Y3 sibling and Z6: NULL population or rate is an error report; a per-person-year rate is caught", {
  v <- vrfpol("pm25", expomean = 25, expoprev = 1, pop = NULL)
  expect_identical(v$status, "error")
  expect_match(v$error, "population")
  v <- vrfpol("pm25", expomean = 25, expoprev = 1, brate = NULL)
  expect_identical(v$status, "error")
  expect_match(v$error, "brate")
  v <- vrfpol("pm25", expomean = 25, expoprev = 1, brate = 0.012)
  expect_identical(v$status, "assumption_failure")
  notes <- vapply(v$assumptions, function(a) a$note, "")
  expect_true(any(grepl("basrateper = 1", notes, fixed = TRUE)))
  expect_true(all(nzchar(notes)))
  d <- vrfpol("pm25", expomean = 25, expoprev = 1, brate = 0.012,
                        basrateper = 1)
  expect_identical(d$status, "ok")
  expect_equal(d$inputs$baserateper100k, 1200)
  z <- vrfpol("pm25", expomean = 25, expoprev = 1, brate = 0)
  expect_identical(z$status, "ok")
  expect_true(any(grepl("measured zero", vapply(z$assumptions, function(a) a$note, ""))))
  bad <- vrfpol("pm25", expomean = 25, expoprev = 1, basrateper = -1)
  expect_identical(bad$status, "error")
})

test_that("L12: every C1 control and bidirectional format character is stripped from the table listing", {
  # U+200C, the zero-width non-joiner, is part of how Persian is written and is kept (review of
  # e57fed5); the controls and the bidirectional formatting characters are not
  chars <- intToUtf8(c(0x80, 0x85, 0x9b, 0x9f, 0x200b, 0x200f, 0x202a, 0x202c, 0x202e,
                       0x2066, 0x2068, 0x2069, 0x1b, 0x0d, 0x09), multiple = TRUE)
  nm <- paste0("Données", paste(chars, collapse = ""), "Montréal")
  tab <- rmoriebricklayer:::.bl_data_tables_df("db/t", nm, 3L, "x")
  txt <- rmoriebricklayer:::.bl_format_data_tables(tab, width = 120)
  for (ch in chars) expect_false(grepl(ch, txt, fixed = TRUE), info = sprintf("U+%04X", utf8ToInt(ch)))
  expect_true(grepl("Données", txt, fixed = TRUE) && grepl("Montréal", txt, fixed = TRUE))
})

test_that("section 1 leftovers: old objects warn on print and bundle read; an edited verifier key is not verified", {
  withr::local_options(rmoriebricklayer.xmssidxfile = withr::local_tempfile(fileext = ".txt"))
  k <- pqckg(height = 2)
  s <- cpssign("m", k)
  old <- s
  old$key_state <- list(sk_seed = k$sk_seed)
  expect_match(paste(format(old), collapse = "\n"), "compromised")
  dir <- withr::local_tempdir()
  writeLines("1,2", file.path(dir, "a.csv"))
  bpath <- file.path(dir, "bundle.json")
  cpsbndl(dir, list(n = 1), xmssadv(k, s), files = "a.csv", path = bpath)
  j <- fromjs(paste(readLines(bpath, warn = FALSE), collapse = "\n"), simplifyVector = FALSE)
  j$attestation$signature$key_state <- list(sk_seed = k$sk_seed)
  writeLines(tojs(j, auto_unbox = TRUE), bpath)
  expect_warning(cpsbndlrd(bpath), "compromised")
  pub <- signpubkey(k)
  bad <- pub
  bad$scheme <- "nope"
  expect_false(cpsvrf("m", s, bad))
  bad$scheme <- NULL
  expect_false(cpsvrf("m", s, bad))
  expect_false(cpsvrf("m", s, unclass(pub)))
  expect_error(cpsvrf("m", s, 42), "needs a key")
})

test_that("section 1 leftovers: vrfpol() takes one exposure source and counts dropped rows", {
  v <- vrfpol("pm25", demo = TRUE, expomean = 25, expoprev = 1)
  expect_identical(v$status, "error")
  expect_match(v$error, "one source")
  v <- vrfpol("pm25", expomean = list(25), expoprev = 1)
  expect_identical(v$status, "error")
  expect_match(v$error, "single number")
  v <- vrfpol("pm25", expomean = 25 + 0i, expoprev = 1)
  expect_identical(v$status, "error")
  f <- withr::local_tempfile(fileext = ".csv")
  # a missing value is dropped and counted; text that is not a number stops the run (52a8883)
  writeLines(c("exposure,income", "30,1", "n/a,2", "40,3", ",4"), f)
  expect_message(v <- vrfpol("pm25", expcsv = f), "2 row\\(s\\) have no exposure value")
  expect_identical(v$status, "ok")
  expect_identical(v$inputs$drorows, 2L)
  writeLines(c("exposure,income", "30,1", "forty,4"), f)
  expect_match(vrfpol("pm25", expcsv = f)$error, "are text")
  # income on one row only: the equity index is skipped, the report still comes
  writeLines(c("exposure,income", "30,1", "40,NA", "35,NA"), f)
  v <- vrfpol("pm25", expcsv = f)
  expect_identical(v$status, "ok")
})

test_that("section 1 leftovers: a long bar label is cut instead of breaking the figure margins", {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  long <- strrep("a very long level name ", 4)
  expect_silent(plot(freqtbl(data.frame(g = c(long, "b", "b")), "g")))
  expect_identical(rmoriebricklayer:::.bl_short_label(c(long, "b", NA)), c(paste0(substr(long, 1, 25), "..."), "b", NA))
})

test_that("section 1 leftovers: own settings without an address are said; the environment wins; keys keep", {
  withr::local_envvar(c(MORIE_LLM_BASE_URL = NA, MORIE_LLM_MODEL = "m1", MORIE_LLM_API_KEY = NA,
                        OLLAMA_HOST = NA, OLLAMA_BASE_URL = "http://10.0.0.5:11434",
                        XDG_CONFIG_HOME = withr::local_tempdir()))
  expect_true(rmoriebricklayer:::.bl_own_configured())
  testthat::local_mocked_bindings(.bl_config_value = function(name) {
    if (identical(name, "OLLAMA_HOST")) "http://saved.example.org:11434" else NULL
  })
  expect_identical(rmoriebricklayer:::.bl_ollama_base(), "http://10.0.0.5:11434")
  testthat::local_mocked_bindings(.bl_config_value = function(name) NULL)
  withr::local_envvar(OLLAMA_BASE_URL = NA)
  expect_identical(rmoriebricklayer:::.bl_ollama_base(), "http://localhost:11434")
})

test_that("section 1 leftovers: own.key with own.url in one call keeps the key", {
  withr::local_envvar(c(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_LLM_BASE_URL = NA, MORIE_LLM_API_KEY = NA))
  llmcfg(own.key = "k1", own.url = "http://127.0.0.1:1234/v1")
  expect_identical(rmoriebricklayer:::.bl_config_value("MORIE_LLM_API_KEY"), "k1")
  expect_match(rmoriebricklayer:::.bl_config_value("MORIE_LLM_BASE_URL"), "127.0.0.1")
})

test_that("section 1 leftovers: an unreadable settings file has a recovery path and does not break doctor", {
  withr::local_envvar(c(XDG_CONFIG_HOME = withr::local_tempdir(), MORIE_LLM_ROUTE = NA))
  p <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines("[1, 2]", p)
  st <- llmstat()
  expect_identical(st$route, "settings")
  expect_identical(st$status, "unreadable")
  expect_match(st$detail, "config reset")
  out <- character()
  s <- blcli("doctor", out = function(x) out <<- c(out, x))
  expect_identical(s, 0L)
  expect_true(any(grepl("unreadable", out)))
  out <- character()
  s <- blcli(c("config", "reset"), out = function(x) out <<- c(out, x))
  expect_identical(s, 0L)
  expect_false(file.exists(p))
  expect_true(any(grepl("moved", out)))
  expect_length(list.files(dirname(p), pattern = "broken-"), 1L)
  expect_identical(llmstat()$route[[1L]], "own endpoint")
  out <- character()
  blcli(c("config", "reset"), out = function(x) out <<- c(out, x))
  expect_true(any(grepl("no settings file", out)))
})

test_that("section 1 leftovers: verbs that take no arguments refuse extras; Ctrl-C exits 130", {
  for (v in c("logout", "doctor", "version")) {
    out <- character()
    s <- blcli(c(v, "extra"), out = function(x) out <<- c(out, x))
    expect_identical(s, 2L, info = v)
    expect_true(any(grepl("takes no arguments", out)), info = v)
  }
  out <- character()
  expect_identical(blcli(c("models", "extra"), out = function(x) out <<- c(out, x)), 2L)
  expect_true(any(grepl("usage: .* models \\[--route ROUTE\\]", out)))
  testthat::local_mocked_bindings(dlogout = function() {
    stop(structure(class = c("interrupt", "condition"), list(message = "", call = NULL)))
  })
  out <- character()
  s <- blcli("logout", out = function(x) out <<- c(out, x))
  expect_identical(s, 130L)
  expect_true(any(grepl("interrupted", out)))
})

test_that("section 1 leftovers: U+061C, U+2028 and U+2029 are stripped; a schema that is not a list is refused", {
  chars <- intToUtf8(c(0x061c, 0x2028, 0x2029), multiple = TRUE)
  nm <- paste0("Données", paste(chars, collapse = ""), "Montréal")
  tab <- rmoriebricklayer:::.bl_data_tables_df("db/t", nm, 3L, "x")
  txt <- rmoriebricklayer:::.bl_format_data_tables(tab, width = 120)
  for (ch in chars) expect_false(grepl(ch, txt, fixed = TRUE), info = sprintf("U+%04X", utf8ToInt(ch)))
  expect_error(valsch(data.frame(a = 1), list(schema = 5)), "must be a list")
  expect_error(schval(data.frame(a = 1), list(schema = "x")), "must be a list")
})

test_that("section 1 leftovers: no cliff at ambient temperature; the island proxies; one inline note keeps the pages", {
  expect_identical(briggs(100, 3, 2, 10, 284.6, 285)$rise, 0)
  expect_error(briggs(100, 3, 2, 10, 284.4, 285), "below")
  expect_gt(briggs(100, 3, 2, 10, 300, 285)$rise, 0)
  expect_identical(dtctloc(tz = "America/Anguilla")$location, "AG")
  expect_identical(dtctloc(tz = "Europe/Jersey")$location, "FR")
  expect_identical(dtctloc(tz = "Europe/Guernsey")$location, "FR")
  d <- data.frame(year = 1985:2024, n = 300 + (0:39) * 7)
  y <- yoy(d, value = "n", prd = "year")
  pages_of <- function(notes) {
    f <- withr::local_tempfile(fileext = ".pdf", .local_envir = parent.frame())
    yoypdf(y, f, notes = notes, height = 8.5)
    bytes <- readBin(f, "raw", file.size(f))
    bytes[bytes == as.raw(0L)] <- as.raw(32L)
    length(gregexpr("/Type /Page[^s]", rawToChar(bytes), useBytes = TRUE)[[1L]])
  }
  expect_identical(pages_of(NULL), pages_of("one short note"))
  expect_gte(rmoriebricklayer:::.yoy_note_line(2), 0.1)
  expect_equal(rmoriebricklayer:::.yoy_note_line(8.5), 0.153)
})

test_that("the branch's refusals that codecov found untested are exercised", {
  # the cap's own argument
  expect_error(advdif2d(matrix(1, 3, 3), 0, 0, 0, 0, 1, 1, 0.1, 1, maxwork = -1), "maxwork")
  expect_error(advdif2d(matrix(1, 3, 3), 0, 0, 0, 0, 1, 1, 0.1, 1, maxwork = c(1, 2)), "maxwork")
  # the member scanner on every malformed shape
  scan <- rmoriebricklayer:::.bl_json_top_members
  expect_null(scan('{"a": "unterminated'))
  expect_null(scan('{"a": [1, 2'))
  expect_null(scan('{"a'))
  expect_null(scan('{"a" 1}'))
  expect_null(scan('{"a": '))
  expect_null(scan('{"a": 1'))
  expect_null(scan('{"a": {"b": "x"'))
  expect_error(rmoriebricklayer:::.bl_credentials_text_set("[1]", "k", "v"), "not a JSON object")
  # the raw credentials reader with and without a file
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
  expect_identical(rmoriebricklayer:::.bl_credentials_raw(), list())
  cred <- rmoriebricklayer:::.bl_credentials_path()
  dir.create(dirname(cred), recursive = TRUE, showWarnings = FALSE)
  writeLines('{"hosted_key": "sk-1", "n": null}', cred)
  raw <- rmoriebricklayer:::.bl_credentials_raw()
  expect_identical(raw$hosted_key, "sk-1")
  expect_true("n" %in% names(raw))
  # the CSV reader's edges
  f <- withr::local_tempfile(fileext = ".csv")
  file.create(f)
  expect_identical(nrow(rmoriebricklayer:::.pollution_read_csv(f)), 0L)
  writeLines(c("", "   "), f)
  expect_identical(nrow(rmoriebricklayer:::.pollution_read_csv(f)), 0L)
  con <- file(f, "wb")
  writeBin(c(as.raw(c(0xff, 0xfe)), as.raw(c(0x41, 0x00, 0x42))), con)   # a UTF-16 BOM with an odd byte count
  close(con)
  expect_error(rmoriebricklayer:::.pollution_read_csv(f), "decoded|UTF-16|incomplete")
  # a signature whose height was edited does not advance the key
  withr::local_options(rmoriebricklayer.xmssidxfile = withr::local_tempfile(fileext = ".txt"))
  k <- pqckg(height = 2)
  s <- cpssign("m", k)
  bad <- s
  bad$height <- 3L
  expect_error(xmssadv(k, bad), "heights differ")
  # the record reader: blank lines only, and a key listed twice keeps its highest index
  rec <- withr::local_tempfile(fileext = ".txt")
  writeLines(c("", "  ", ""), rec)
  expect_identical(rmoriebricklayer:::.rmbl_xmss_record_read(rec), integer(0))
  kid <- xmss_kid(k)
  writeLines(c(paste(kid, 0L, sep = "\t"), paste(kid, 3L, sep = "\t"), paste(kid, 1L, sep = "\t")), rec)
  got <- rmoriebricklayer:::.rmbl_xmss_record_read(rec)
  expect_identical(unname(got), 3L)
  expect_identical(names(got), kid)
})

test_that("a rename that fails is an error for the record, the credentials file and the settings reset", {
  # the record is replaced in C (rmbl_flock.c): a non-empty directory in its place cannot be
  # renamed over, a real failure rather than a mocked one
  rec <- withr::local_tempfile(fileext = ".txt")
  dir.create(file.path(rec, "inside"), recursive = TRUE)
  expect_error(rmoriebricklayer:::.rmbl_xmss_record_write(rec, stats::setNames(1L, "k")), "could not write")
  testthat::local_mocked_bindings(file.rename = function(from, to) FALSE, .package = "base")
  cred <- withr::local_tempfile(fileext = ".json")
  expect_error(rmoriebricklayer:::.bl_write_private_text(cred, "{}"), "could not write")
  withr::local_envvar(XDG_CONFIG_HOME = withr::local_tempdir())
  p <- rmoriebricklayer:::.bl_config_path()
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  writeLines("[1]", p)
  expect_error(rmoriebricklayer:::.bl_config_reset(), "could not move")
  expect_error(rmoriebricklayer:::.bl_config_reset(force = TRUE), "could not move")
})

test_that("a live lock held by another process is waited for and then reported", {
  skip_on_cran()
  skip_on_os("windows")
  rec <- withr::local_tempfile(fileext = ".txt")
  ready <- withr::local_tempfile()
  # another process holds the operating-system lock for longer than the 10 s wait
  done <- withr::local_tempfile()
  rscript_bg(sprintf(paste0("f <- .Call(rmoriebricklayer:::C_rmbl_flock_acquire, '%s', 0L); ",
                            "writeLines('held', '%s'); Sys.sleep(16); ",
                            ".Call(rmoriebricklayer:::C_rmbl_flock_release, f); writeLines('done', '%s')"),
                     paste0(rec, ".flock"), ready, done))
  skip_if_not(wait_files(ready), "the lock-holding process did not start")
  t0 <- Sys.time()
  expect_error(rmoriebricklayer:::.rmbl_xmss_with_lock(rec, function() TRUE), "could not lock")
  expect_gte(as.numeric(difftime(Sys.time(), t0, units = "secs")), 9)
  expect_true(wait_files(done))
  expect_true(rmoriebricklayer:::.rmbl_xmss_with_lock(rec, function() TRUE))
})
