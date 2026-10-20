# rmbl sign with an XMSS key: the key file as the key's state (RFC 10033), state files, sectors,
# reservation, stale copies, index reuse on verify, the exhaustion warning, and morie reading a
# key the command line advanced. Nothing here reads standard input: the prompt reader is mocked.

xrun <- function(args) {
  acc <- new.env()
  acc$txt <- character()
  st <- blcli(args, out = function(s) acc$txt <- c(acc$txt, s))
  list(status = st, out = paste(acc$txt, collapse = ""))
}

x_no_stdin <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(.bl_readline = function(...) stop("a test read standard input"),
                                  .package = "rmoriebricklayer", .env = env)
}

# a folder of n capsules, each a CSV and a plain provenance naming it
xcaps <- function(n = 1L, env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  for (i in seq_len(n)) {
    d <- file.path(root, sprintf("c%d", i))
    dir.create(d)
    utils::write.csv(data.frame(x = seq_len(i + 2L)), file.path(d, "data.csv"), row.names = FALSE)
    writeLines('{"resource": {"filename": "data.csv"}}', file.path(d, "data_provenance.json"))
  }
  root
}

xkeyfile <- function(height = 3L, dir = NULL, env = parent.frame()) {
  dir <- dir %||% withr::local_tempdir(.local_envir = env)
  kf <- file.path(dir, "key.json")
  writeLines(tojs(unclass(pqckg(height)), auto_unbox = TRUE), kf)
  kf
}

xread <- function(f) fromjs(paste(readLines(f, warn = FALSE), collapse = "\n"), simplifyVector = FALSE)

xsign <- function(root, kf, ...) xrun(c("sign", root, "--scheme", "xmss-sha256", "--key-file", kf, "--overwrite", ...))

# the indices of the XMSS signatures in the bundles under root
xidx <- function(root) sort(xmssidxseen(root)$index)

xfpr <- function(kf) {
  k <- xread(kf)
  rmoriebricklayer:::.rmbl_xmss_fpr(paste0(k$root, k$pubseed))
}

test_that("rmbl sign rewrites the key file atomically, with the state, before it signs", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  r <- xsign(root, kf)
  expect_identical(r$status, 0L)
  expect_match(r$out, "xmss state in .*key.json: indices 0 to 0 reserved in sector 0 of 1, generation 1; 7 left")
  k <- xread(kf)
  expect_equal(k$next_index, 1L)
  expect_identical(k$used$format, "rmbl-xmss-state/1")
  expect_identical(k$used$key, xfpr(kf))
  expect_equal(k$used$highest, 0L)
  expect_equal(k$used$generation, 1L)
  expect_match(k$used$writer, "^[0-9a-f]{16}$")
  expect_equal(k$used$reserved$to, 0L)
  if (.Platform$OS.type == "unix") expect_identical(as.character(file.mode(kf)), "600")
  expect_identical(list.files(dirname(kf), pattern = "[.]tmp$"), character(0))
  # the verify report names the index and the key fingerprint
  expect_match(r$out, sprintf("xmss index 0, key %s", xfpr(kf)), fixed = TRUE)
  r <- xsign(root, kf, "--json")
  expect_identical(r$status, 0L)
  j <- fromjs(sub("^[^{]*", "", r$out))
  expect_identical(j$status, "ok")
  expect_true("xmss_index" %in% j$checks$check)
  expect_equal(xread(kf)$next_index, 2L)
  expect_equal(xread(kf)$used$generation, 2L)
  expect_identical(xidx(root), 1L)
})

test_that("a crash before the rename leaves the old key file, and no bundle is written", {
  x_no_stdin()
  # a write that cannot even start stops the signature
  expect_error(rmoriebricklayer:::.rmbl_xmss_put(file.path(tempfile(), "x.json"), "{}"),
               "could not write the XMSS state", fixed = TRUE)
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  before <- readLines(kf)
  testthat::local_mocked_bindings(.rmbl_xmss_put = function(p, txt) {
    writeLines(txt, paste0(p, ".xmss-crash.tmp"))   # the temporary file is written, the rename never happens
    stop("simulated crash before the rename", call. = FALSE)
  }, .package = "rmoriebricklayer")
  r <- xsign(root, kf)
  expect_identical(r$status, 1L)
  expect_match(r$out, "simulated crash before the rename", fixed = TRUE)
  expect_identical(readLines(kf), before)
  expect_false(file.exists(file.path(root, "c1", "capsule_bundle.json")))
})

test_that("the reservation is in the key file before the first bundle is signed", {
  x_no_stdin()
  root <- xcaps(2L)
  kf <- xkeyfile(4L)
  got <- new.env()
  testthat::local_mocked_bindings(cpsbndl = function(dir, man, key, ...) {
    got$highest <- xread(kf)$used$highest
    got$index <- key$next_index
    stop("stopped at the first signature", call. = FALSE)
  }, .package = "rmoriebricklayer")
  r <- xsign(root, kf, "--reserve", "5")
  expect_identical(r$status, 1L)
  expect_equal(got$highest, 4L)
  expect_identical(got$index, 0L)
})

test_that("--reserve signs several capsules from one block; the unused indices are lost", {
  x_no_stdin()
  root <- xcaps(2L)
  kf <- xkeyfile(4L)
  r <- xsign(root, kf, "--reserve", "5")
  expect_identical(r$status, 0L)
  expect_identical(xidx(root), c(0L, 1L))
  expect_equal(xread(kf)$used$highest, 4L)
  expect_equal(xread(kf)$next_index, 5L)
  # a reservation smaller than the run is taken as one index per capsule
  r <- xsign(root, kf, "--reserve", "1")
  expect_identical(r$status, 0L)
  expect_identical(xidx(root), c(5L, 6L))
  expect_identical(xsign(root, kf, "--reserve", "0")$status, 2L)
  expect_match(xsign(root, kf, "--reserve", "x")$out, "--reserve takes a whole number from 1, not 'x'", fixed = TRUE)
  # an index outside the block is not signed
  k <- rmoriebricklayer:::.rmbl_xmss_key_json(paste(readLines(kf), collapse = "\n"), "k")$key
  id <- rmoriebricklayer:::.rmbl_xmss_ids(k)$id
  assign(id, c(20L, 20L), envir = rmoriebricklayer:::.rmbl_xmss_block)
  withr::defer(rm(list = id, envir = rmoriebricklayer:::.rmbl_xmss_block))
  k$next_index <- 10L
  expect_error(cpssign("m", k), "outside the block this run reserved (20 to 20)", fixed = TRUE)
})

test_that("a key file that cannot be rewritten is refused, and --state-file keeps the state elsewhere", {
  x_no_stdin()
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["effective_user"]], "root"), "root writes read-only files")
  root <- xcaps(1L)
  kd <- withr::local_tempdir()
  kf <- xkeyfile(3L, kd)
  Sys.chmod(kf, "0400")
  r <- xsign(root, kf)
  expect_identical(r$status, 2L)
  expect_match(r$out, "cannot be rewritten", fixed = TRUE)
  expect_match(r$out, "RFC 10033, section 4", fixed = TRUE)
  expect_match(r$out, "--state-file FILE", fixed = TRUE)
  Sys.chmod(kf, "0600")
  Sys.chmod(kd, "0500")
  withr::defer(Sys.chmod(kd, "0700"))
  expect_identical(xsign(root, kf)$status, 2L)
  before <- readLines(kf)
  sf <- file.path(withr::local_tempdir(), "state.json")
  r <- xsign(root, kf, "--state-file", sf)
  expect_identical(r$status, 0L)
  expect_identical(readLines(kf), before)
  s <- xread(sf)
  expect_equal(s$highest, 0L)
  expect_identical(s$key, xfpr(kf))
  r <- xsign(root, kf, "--state-file", sf)
  expect_identical(r$status, 0L)
  expect_identical(xidx(root), 1L)
  expect_equal(xread(sf)$generation, 2L)
})

test_that("--state-file must be an absolute path to a writable regular file, and must belong to the key", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  r <- xsign(root, kf, "--state-file", "state.json")
  expect_identical(r$status, 2L)
  expect_match(r$out, "state.json is a relative path", fixed = TRUE)
  td <- withr::local_tempdir()
  expect_match(xsign(root, kf, "--state-file", td)$out, "is a directory", fixed = TRUE)
  if (.Platform$OS.type == "unix") {
    expect_match(xsign(root, kf, "--state-file", "/dev/null")$out, "is a device or other special file", fixed = TRUE)
  }
  expect_match(xsign(root, kf, "--state-file", file.path(td, "no", "such", "state.json"))$out, "is not writable",
               fixed = TRUE)
  # a key in RMBL_KEY has nowhere to keep its state but a state file
  withr::local_envvar(RMBL_KEY = paste(readLines(kf), collapse = "\n"))
  r <- xrun(c("sign", root, "--scheme", "xmss-sha256", "--overwrite"))
  expect_identical(r$status, 2L)
  expect_match(r$out, "needs --state-file FILE", fixed = TRUE)
  expect_match(r$out, "Use ML-DSA in CI", fixed = TRUE)
  sf <- file.path(td, "state.json")
  withr::local_envvar(RMBL_KEY = paste(readLines(kf), collapse = "\n"))
  r <- xrun(c("sign", root, "--scheme", "xmss-sha256", "--overwrite", "--state-file", sf))
  expect_identical(r$status, 0L)
  expect_equal(xread(sf)$highest, 0L)
  # the state of another key, or a damaged state, is not used
  k2 <- xkeyfile(3L)
  r <- xsign(root, k2, "--state-file", sf)
  expect_identical(r$status, 1L)
  expect_match(r$out, "does not hold the XMSS state of this key", fixed = TRUE)
  writeLines("{\"format\": \"rmbl-xmss-state/1\"", sf)
  expect_match(xsign(root, kf, "--state-file", sf)$out, "cannot be trusted", fixed = TRUE)
  # the options of the XMSS state are for an XMSS key
  writeLines("the shared secret", k2)
  r <- xrun(c("sign", root, "--key-file", k2, "--overwrite", "--state-file", sf))
  expect_identical(r$status, 2L)
  expect_match(r$out, "--state-file is for --scheme xmss-sha256 only", fixed = TRUE)
})

test_that("a key file that is not an XMSS key, or is damaged, is refused before anything is written", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- withr::local_tempfile(fileext = ".json")
  writeLines(tojs(unclass(fipskg("ML-DSA-44")), auto_unbox = TRUE), kf)
  r <- xsign(root, kf)
  expect_identical(r$status, 1L)
  expect_match(r$out, "the key is not an xmss-sha256 key", fixed = TRUE)
  k <- unclass(pqckg(2L))
  k$next_index <- 9L
  writeLines(tojs(k, auto_unbox = TRUE), kf)
  expect_match(xsign(root, kf)$out, "not a whole number in range", fixed = TRUE)
  k$next_index <- 0L
  k$skprf <- "00"
  writeLines(tojs(k, auto_unbox = TRUE), kf)
  expect_match(xsign(root, kf)$out, "the key: ", fixed = TRUE)
  expect_false(file.exists(file.path(root, "c1", "capsule_bundle.json")))
  # nothing to sign: refused before the state is touched
  e <- withr::local_tempdir()
  kx <- xkeyfile(2L)
  expect_identical(xsign(e, kx)$status, 1L)
  expect_null(xread(kx)$used)
  r <- xrun(c("sign", root, "--scheme", "xmss-sha256", "--key-file", kx))
  expect_identical(r$status, 0L)
  r <- xrun(c("sign", root, "--scheme", "xmss-sha256", "--key-file", kx))
  expect_identical(r$status, 1L)
  expect_match(r$out, "capsule_bundle.json already exists", fixed = TRUE)
  expect_false(grepl("blcli: ", r$out, fixed = TRUE))
  expect_equal(xread(kx)$used$highest, 0L)
})

test_that("sectors split the indices into disjoint ranges, each with its own state", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(4L)   # 16 indices, 4 sectors of 4
  expect_identical(xsign(root, kf, "--sectors", "4", "--sector-index", "1")$status, 0L)
  expect_identical(xidx(root), 4L)
  expect_identical(xsign(root, kf, "--sector-index", "1")$status, 0L)   # the split is in the state
  expect_identical(xidx(root), 5L)
  r <- xsign(root, kf, "--sectors", "4", "--sector-index", "2")
  expect_identical(r$status, 0L)
  expect_match(r$out, "indices 8 to 8 reserved in sector 2 of 4", fixed = TRUE)
  s <- xread(kf)$used$sectors
  expect_equal(s$count, 4L)
  expect_equal(s$highest[["1"]], 5L)
  expect_equal(s$highest[["2"]], 8L)
  expect_equal(xread(kf)$next_index, 9L)
  expect_identical(suppressMessages(xsign(root, kf, "--sectors", "4", "--sector-index", "1", "--reserve", "2"))$status,
                   0L)
  r <- xsign(root, kf, "--sectors", "4", "--sector-index", "1")
  expect_identical(r$status, 1L)
  expect_match(r$out, "the key is exhausted in sector 1 of 4 (indices 4 to 7): 0 left", fixed = TRUE)
  # a sector by name: SHA-256 of the name and the key fingerprint, modulo the count
  nm <- "runner-a"
  want <- strtoi(substr(tolower(csha256(charToRaw(paste0(nm, xfpr(kf))))), 1L, 7L), 16L) %% 4L
  r <- xsign(root, kf, "--sectors", "4", "--sector", nm)
  if (want == 1L) {
    expect_identical(r$status, 1L)
  } else {
    expect_identical(r$status, 0L)
    expect_true(xidx(root) %/% 4L == want)
  }
  # refusals
  expect_match(xsign(root, kf, "--sectors", "3", "--sector-index", "0")$out, "power of two from 2 to 8", fixed = TRUE)
  expect_match(xsign(root, kf, "--sectors", "16", "--sector-index", "0")$out, "power of two", fixed = TRUE)
  expect_match(xsign(root, kf, "--sectors", "2", "--sector-index", "0")$out, "split into 4 sectors, not 2",
               fixed = TRUE)
  expect_match(xsign(root, kf)$out, "give --sector NAME or --sector-index I", fixed = TRUE)
  expect_match(xsign(root, kf, "--sector-index", "9")$out, "below the 4 sectors, not 9", fixed = TRUE)
  expect_identical(xsign(root, kf, "--sectors", "4", "--sector", "a", "--sector-index", "0")$status, 2L)
  expect_match(xsign(root, kf, "--sectors", "4")$out, "--sectors K needs --sector NAME", fixed = TRUE)
  expect_identical(xsign(root, kf, "--sectors", "1", "--sector-index", "0")$status, 2L)
  k2 <- xkeyfile(4L)
  expect_match(xsign(root, k2, "--sector-index", "1")$out, "need --sectors K", fixed = TRUE)
  # the key file's next_index moved past the sector state (signed outside rmbl sign): refused
  k <- xread(kf)
  k$next_index <- 15L
  writeLines(tojs(k, auto_unbox = TRUE, digits = NA), kf)
  expect_match(xsign(root, kf, "--sector-index", "3")$out, "signed outside rmbl sign", fixed = TRUE)
})

test_that("two copies of a key, each in its own sector, never sign one index", {
  x_no_stdin()
  ka <- xkeyfile(3L)   # 8 indices, 2 sectors of 4
  kb <- file.path(withr::local_tempdir(), "key.json")
  file.copy(ka, kb)
  ra <- xcaps(1L)
  rb <- xcaps(1L)
  got <- integer()
  for (i in 1:4) {
    expect_identical(suppressMessages(xsign(ra, ka, "--sectors", "2", "--sector-index", "0"))$status, 0L)
    expect_identical(suppressMessages(xsign(rb, kb, "--sectors", "2", "--sector-index", "1"))$status, 0L)
    got <- c(got, xidx(ra), xidx(rb))
  }
  expect_identical(sort(got), 0:7)
  expect_identical(xsign(ra, ka, "--sector-index", "0")$status, 1L)
})

test_that("a stale copy of the key file is refused", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  copy <- file.path(withr::local_tempdir(), "key.json")
  file.copy(kf, copy)
  expect_identical(xsign(root, kf)$status, 0L)
  r <- xsign(root, copy)
  expect_identical(r$status, 1L)
  expect_match(r$out, "stale copy of the key: index 0 of it was already signed", fixed = TRUE)
  expect_identical(xidx(root), 0L)
  # through the seen-log, when the bundles are elsewhere
  log <- withr::local_tempfile(fileext = ".log")
  expect_identical(xsign(root, kf, "--seen-log", log)$status, 0L)
  expect_match(readLines(log)[[1L]], "^# rmoriebricklayer xmss seen-log 1")
  expect_length(readLines(log), 2L)
  other <- xcaps(1L)
  r <- xsign(other, copy, "--seen-log", log)
  expect_identical(r$status, 1L)
  expect_match(r$out, "stale copy of the key: index 1", fixed = TRUE)
  expect_false(file.exists(file.path(other, "c1", "capsule_bundle.json")))
  # a state another host wrote last is named
  k <- xread(kf)
  k$used$writer <- "0000000000000000"
  writeLines(tojs(k, auto_unbox = TRUE, digits = NA), kf)
  r <- xsign(root, kf, "--seen-log", log)
  expect_identical(r$status, 0L)
  expect_match(r$out, "note: the state was last written on another host (0000000000000000", fixed = TRUE)
  expect_length(readLines(log), 3L)
})

test_that("verify fails an XMSS index one key signed twice, under the path or in a seen-log", {
  x_no_stdin()
  root <- withr::local_tempdir()
  key <- pqckg(height = 2L)
  mk <- function(nm, v) {
    d <- file.path(root, nm)
    dir.create(d)
    writeLines(c("x", v), file.path(d, "data.csv"))
    writeLines('{"resource": {"filename": "data.csv"}}', file.path(d, "data_provenance.json"))
    d
  }
  d1 <- mk("one", "1")
  d2 <- mk("two", "2")
  b1 <- cpsseal(root, key, glob = "*one*")
  expect_identical(nrow(b1), 1L)
  s <- xmssidxseen(root)
  expect_identical(s$reused, FALSE)
  # a stale copy signs index 0 again (its record forgotten, as on another machine)
  xmssfgt(key)
  invisible(cpsseal(root, key, glob = "*two*"))
  s <- xmssidxseen(root)
  expect_identical(s$index, c(0L, 0L))
  expect_identical(s$reused, c(TRUE, TRUE))
  r <- xrun(c("verify", root, "--json"))
  expect_identical(r$status, 1L)
  j <- fromjs(r$out)
  bad <- j$checks[j$checks$check == "xmss_index", ]
  expect_identical(nrow(bad), 2L)
  expect_false(any(bad$ok))
  expect_match(bad$detail[[1L]], "xmss index reused: index 0 of key [0-9a-f]{16} also made another signature")
  expect_match(xrun(c("verify", root))$out, "signed this XMSS index twice", fixed = TRUE)
  # one bundle copied to two places is not a reuse
  unlink(d2, recursive = TRUE)
  d3 <- file.path(root, "three")
  dir.create(d3)
  file.copy(list.files(d1, full.names = TRUE), d3)
  expect_identical(xmssidxseen(root)$reused, c(FALSE, FALSE))
  expect_identical(xrun(c("verify", root))$status, 0L)
  # a seen-log line with another signature at the index fails the row
  log <- withr::local_tempfile()
  writeLines(c("# a log", "", sprintf("%s\t0\t0123456789abcdef\telsewhere", s$key[[1L]])), log)
  r <- xrun(c("verify", root, "--seen-log", log, "--json"))
  expect_identical(r$status, 1L)
  expect_true("elsewhere" %in% xmssidxseen(root, log)$where)
  chk <- cpsbndlvrf(file.path(d1, "capsule_bundle.json"), d1, seen = xmssidxseen(root, log))
  expect_false(chk$ok)
  expect_true(cpsbndlvrf(file.path(d1, "capsule_bundle.json"), d1, seen = xmssidxseen(root))$ok)
  expect_identical(nrow(xmssidxseen(file.path(d1, "capsule_bundle.json"))), 1L)
  # refusals
  expect_error(cpsbndlvrf(file.path(d1, "capsule_bundle.json"), d1, seen = list()),
               "cpsbndlvrf: `seen` must be what xmssidxseen() returns", fixed = TRUE)
  expect_error(xmssidxseen(file.path(root, "nope")), "xmssidxseen: `path` is not an existing", fixed = TRUE)
  expect_error(xmssidxseen(root, NA_character_), "`seenlog` must be file paths", fixed = TRUE)
  expect_error(xmssidxseen(root, root), "is a directory", fixed = TRUE)
  writeLines("not a line", log)
  expect_error(xmssidxseen(root, log), "has 1 malformed line(s)", fixed = TRUE)
  expect_identical(xrun(c("verify", root, "--seen-log", log))$status, 2L)
  expect_identical(nrow(xmssidxseen(withr::local_tempdir())), 0L)
  hm <- xcaps(1L)
  invisible(cpsseal(hm, "a shared secret"))   # an hmac bundle has no index
  expect_identical(nrow(xmssidxseen(hm)), 0L)
  expect_identical(nrow(xmssidxseen(root, tempfile())), 2L)
  expect_error(cpschk(root, seenlog = NA), "seenlog", fixed = TRUE)
})

test_that("the exhaustion warning comes at --warn-left, by default a tenth of the range", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  expect_message(r <- xsign(root, kf, "--warn-left", "7"), "signatures nearing exhaustion: 7 left in sector 0 of 1")
  expect_match(r$out, "warning: signatures nearing exhaustion", fixed = TRUE)
  expect_match(xsign(root, kf, "--warn-left", "-1")$out, "--warn-left takes a whole number from 0", fixed = TRUE)
  k4 <- xkeyfile(4L)
  r <- xsign(root, k4, "--reserve", "14")
  expect_false(grepl("nearing exhaustion", r$out, fixed = TRUE))
  expect_message(r <- xsign(root, k4), "1 left in sector 0 of 1 \\(--warn-left 1\\)")
  expect_message(r <- xsign(root, k4), "0 left in sector 0 of 1")
  expect_identical(r$status, 0L)
  r <- xsign(root, k4)
  expect_identical(r$status, 1L)
  expect_match(r$out, "the key is exhausted in sector 0 of 1 (indices 0 to 15): 0 left, and this run needs 1",
               fixed = TRUE)
})

test_that("RMBL_XMSS_INDEX_FILE is read and updated when it is set, and only then", {
  x_no_stdin()
  root <- xcaps(1L)
  kf <- xkeyfile(3L)
  rec <- file.path(withr::local_tempdir(), "used.txt")
  withr::local_envvar(RMBL_XMSS_INDEX_FILE = rec)
  expect_identical(xsign(root, kf)$status, 0L)
  k <- rmoriebricklayer:::.rmbl_xmss_key_json(paste(readLines(kf), collapse = "\n"), "k")$key
  id <- rmoriebricklayer:::.rmbl_xmss_ids(k)$id
  expect_identical(readLines(rec), paste0(id, "\t0"))
  writeLines(paste0(id, "\t5"), rec)
  expect_identical(xsign(root, kf)$status, 0L)
  expect_identical(xidx(root), 6L)
  expect_identical(readLines(rec), paste0(id, "\t6"))
  withr::local_envvar(RMBL_XMSS_INDEX_FILE = NA)
  expect_null(rmoriebricklayer:::.rmbl_xmss_index_file(cli = TRUE))
})

test_that("cpsseal() signs several capsules with one XMSS key at consecutive indices", {
  root <- xcaps(3L)
  key <- pqckg(height = 3L)
  s <- cpsseal(root, key)
  expect_identical(nrow(s), 3L)
  expect_identical(xidx(root), 0:2)
  expect_true(cpschk(root, pubkey = paste0(key$root, key$pubseed), fp = FALSE)$status == "ok")
})

test_that("a key the command line advanced still loads and signs in morie", {
  py <- Sys.getenv("MORIE_PYTHON", Sys.which("python3"))
  skip_if(!nzchar(py), "no python")
  ok <- suppressWarnings(system2(py, c("-c", shQuote("import morie.capsule._pq")), stdout = FALSE, stderr = FALSE))
  skip_if(ok != 0L, "morie is not importable")
  x_no_stdin()
  root <- xcaps(2L)
  kf <- xkeyfile(3L)
  expect_identical(xsign(root, kf, "--reserve", "3")$status, 0L)
  rec <- withr::local_tempfile(fileext = ".txt")
  code <- paste("import json, os, sys", "from morie.capsule import _pq",
                "k = _pq.read_key(sys.argv[1])", "s = _pq.sign(b'from morie', k)",
                "print(s['index'], k['next_index'], k['used']['highest'])", sep = "\n")
  pf <- withr::local_tempfile(fileext = ".py")
  writeLines(code, pf)
  out <- withr::with_envvar(c(RMBL_XMSS_INDEX_FILE = rec), system2(py, c(shQuote(pf), shQuote(kf)), stdout = TRUE))
  expect_identical(out, "3 4 2")
})
