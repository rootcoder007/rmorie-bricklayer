# SPDX-License-Identifier: AGPL-3.0-or-later

# The file digest, the ASCII fallbacks for text and the URL gate.

test_that("sha256file() hashes a file and refuses what is not one", {
  f <- withr::local_tempfile()
  writeBin(charToRaw("abc"), f)
  expect_identical(
    sha256file(f),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  e <- withr::local_tempfile()
  file.create(e)
  expect_identical(
    sha256file(e),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
  expect_error(sha256file(tempdir()), "is not a file")
  expect_error(sha256file(file.path(tempdir(), "no-such-file")), "not a file")
  expect_error(sha256file(c("a", "b")), "sha256file: `path` is not a file")
  expect_error(sha256file(NA_character_), "is not a file")
  expect_error(sha256file(1), "sha256file: `path` is not a file")
  # a path holding a byte that is not text is named with it shown as <ff>
  skip_if_not(isTRUE(l10n_info()[["UTF-8"]]))
  e <- tryCatch(sha256file("no-such-\xff"), error = conditionMessage)
  expect_true(validUTF8(e))
  expect_match(e, "no-such-<ff> is not a file", fixed = TRUE)
})

test_that("toascii() folds accents and drops what has no ASCII form", {
  expect_identical(toascii("Angéla"), "Angela")
  expect_identical(toascii(c("a", NA)), c("a", ""))
  expect_true(all(validUTF8(toascii("ßæ"))))
  # the base-R fallback, without stringi, gives the same answers on Latin
  expect_identical(
    .to_ascii_fallback(c("École", "Straße", "Œuvre")),
    c("Ecole", "Strasse", "OEuvre")
  )
  tab <- .to_ascii_table()
  expect_identical(nchar(tab$from), nchar(tab$to))
})

test_that("asciifb() keeps valid text and folds only broken bytes", {
  expect_identical(asciifb("Angéla"), "Angéla")
  expect_identical(asciifb("Angéla", force = TRUE), "Angela")
  bad <- rawToChar(as.raw(c(0x61, 0xff, 0x62)))
  expect_identical(asciifb(c("ok", bad)), c("ok", "ab"))
})

test_that("wrtxtfb() writes the text as UTF-8 lines", {
  f <- withr::local_tempfile(fileext = ".txt")
  expect_identical(wrtxtfb(c("one", "Angéla"), f), f)
  expect_identical(
    readBin(f, "raw", 100),
    charToRaw(enc2utf8("one\nAngéla\n"))
  )
})

test_that("the URL gate admits https and refuses local or plain addresses", {
  expect_identical(
    .rmbl_check_public_url("https://example.org/a"),
    "https://example.org/a"
  )
  expect_error(.rmbl_check_public_url(""), "url is empty")
  expect_error(.rmbl_check_public_url("example.org"), "has no URL scheme")
  expect_error(
    .rmbl_check_public_url("http://example.org/", allow_http = FALSE),
    "must be an https:// URL, not http://"
  )
  expect_error(
    .rmbl_check_public_url("https://127.0.0.1/", what = "src"),
    "src points at a local or private address"
  )
  expect_identical(
    .rmbl_check_public_url("file:///tmp/x", allow_file = TRUE),
    "file:///tmp/x"
  )
})

test_that("the base-R URL check stands in for the C validator", {
  why <- function(u) .rmbl_url_why_base(u, FALSE, FALSE)
  expect_identical(why("https://example.org/x"), "")
  expect_identical(why("ftp://example.org/"), "scheme ftp is not allowed")
  expect_identical(why("http://example.org/"), "plain http is not allowed")
  expect_identical(
    .rmbl_url_why_base("http://localhost:8080/", FALSE, TRUE),
    ""
  )
  expect_identical(why("https://10.1.2.3/"), "a local or private address")
  expect_identical(why("https://192.168.0.1/"), "a local or private address")
  expect_identical(why("https://8.8.8.8/"), "")
  expect_identical(why("https://2130706433/"), "a local or private address")
  expect_identical(why("https://[::1]/"), "a local or private address")
  expect_identical(why("https://intranet/"), "a single-label host")
  expect_identical(why("https://printer.local/"), "a local name")
  expect_true(.rmbl_private_v4("172.20.0.1"))
  expect_false(.rmbl_private_v4("172.32.0.1"))
  expect_identical(.rmbl_host_why("example.org", FALSE), "")
})

test_that("the streamed SHA-256 refuses a directory by name", {
  d <- withr::local_tempdir()
  expect_error(.rmbl_sha256_stream(d), "is a directory, not a file")
})

test_that(".rmbl_wfile() writes a file whole or not at all", {
  d <- withr::local_tempdir()
  p <- file.path(d, "a.txt")
  .rmbl_wfile(p, c("x", "y"))
  expect_identical(readLines(p), c("x", "y"))
  .rmbl_wfile(p, as.raw(1:3))
  expect_identical(readBin(p, "raw", 10L), as.raw(1:3))
  # a short write, a warning while writing and a failed write are the
  # package's error; the old file stays and no temporary is left
  expect_error(
    .rmbl_wfile(p, function(con) writeBin(raw(4), con), size = 9),
    "could not write .*4 of 9 bytes were written.*the file is unchanged"
  )
  expect_error(
    .rmbl_wfile(p, function(con) warning("no room")),
    "could not write .*[(]no room[)]; the file is unchanged"
  )
  expect_error(
    .rmbl_wfile(p, function(con) writeBin("x", 1L)),
    "could not write"
  )
  # the package's own refusal inside the writer is passed on as it is
  expect_error(
    .rmbl_wfile(p, function(con) stop("too large", call. = FALSE)),
    "^too large$"
  )
  expect_identical(readBin(p, "raw", 10L), as.raw(1:3))
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "a.txt")
  expect_error(
    .rmbl_wfile(file.path(d, "b.txt"), function(con) warning("no room")),
    "nothing was left there"
  )
  expect_false(file.exists(file.path(d, "b.txt")))
  expect_error(.rmbl_wfile(d, "x"), "it is a folder")
  expect_error(
    .rmbl_wfile(file.path(d, "no", "a.txt"), "x"),
    "its folder does not exist"
  )
  if (file.exists("/dev/zero")) {
    expect_error(.rmbl_wfile("/dev/zero", "x"), "not a regular file")
  }
  # a connection still gets the text, as before
  expect_identical(
    utils::capture.output(.rmbl_wlines(c("a", "b"), stdout())),
    c("a", "b")
  )
})

test_that(".rmbl_wfile() keeps modes and refuses what it may not replace", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  p <- file.path(d, "a.txt")
  .rmbl_wfile(p, "x")
  Sys.chmod(p, "640", use_umask = FALSE)
  .rmbl_wfile(p, "y")
  expect_identical(format(file.info(p)$mode), "640")
  q <- file.path(d, "secret")
  .rmbl_wfile(q, function(con) writeBin(charToRaw("s"), con), private = TRUE)
  expect_identical(format(file.info(q)$mode), "600")
  .rmbl_wfile(q, charToRaw("t"), private = TRUE)
  expect_identical(format(file.info(q)$mode), "600")
  Sys.chmod(p, "444", use_umask = FALSE)
  if (file.access(p, 2L) != 0L) {
    expect_error(.rmbl_wfile(p, "z"), "it cannot be written to")
  }
  Sys.chmod(p, "644", use_umask = FALSE)
  ro <- file.path(d, "ro")
  dir.create(ro)
  Sys.chmod(ro, "555", use_umask = FALSE)
  on.exit(Sys.chmod(ro, "755", use_umask = FALSE), add = TRUE)
  if (file.access(ro, 2L) != 0L) {
    expect_error(
      .rmbl_wfile(file.path(ro, "a"), "x"),
      "its folder cannot be written to"
    )
  }
})

test_that("a write cut short by a file-size limit leaves the old file", {
  skip_on_os("windows")
  skip_if_lowmem()
  d <- withr::local_tempdir()
  p <- file.path(d, "bundle.json")
  writeLines("old", p)
  code <- paste0(
    "r <- tryCatch(rmoriebricklayer:::.rmbl_wfile(", deparse(p),
    ", strrep('x', 40000)), error = function(e) conditionMessage(e)); ",
    "cat(r)"
  )
  sh <- paste0(
    "trap '' XFSZ; ulimit -f 8; exec ",
    shQuote(file.path(R.home("bin"), "Rscript")),
    " --vanilla -e ", shQuote(code)
  )
  # under covr the child saves its trace as it exits, under the same limit:
  # cut at 4096 bytes in the run's folder, it stopped the merge of every
  # trace ("error reading from connection"); it goes to a folder of its own
  out <- withr::with_envvar(
    c(R_TESTS = NA, R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep),
      COVERAGE_DIR = withr::local_tempdir()),
    system2("sh", c("-c", shQuote(sh)), stdout = TRUE, stderr = FALSE)
  )
  expect_match(paste(out, collapse = "\n"), "the file is unchanged")
  expect_identical(readLines(p), "old")
  expect_identical(list.files(d, all.files = TRUE, no.. = TRUE), "bundle.json")
})

test_that(".rmbl_wappend() and .rmbl_fcopy() write whole files", {
  d <- withr::local_tempdir()
  q <- file.path(d, "log")
  .rmbl_wappend(q, "a\n")
  .rmbl_wappend(q, c("b", "\n"))
  expect_identical(readLines(q), c("a", "b"))
  src <- file.path(d, "src.bin")
  writeBin(as.raw(0:255), src)
  Sys.setFileTime(src, as.POSIXct("2020-01-02 03:04:05", tz = "UTC"))
  dst <- file.path(d, "dst.bin")
  .rmbl_fcopy(src, dst, date = TRUE)
  expect_identical(readBin(dst, "raw", 300L), as.raw(0:255))
  expect_equal(
    as.numeric(file.mtime(dst)),
    as.numeric(file.mtime(src)),
    tolerance = 1
  )
  # a device has no end: refused before anything is copied
  if (file.exists("/dev/zero")) {
    expect_error(
      .rmbl_fcopy("/dev/zero", file.path(d, "z"), "data"),
      "`data` is not a regular file"
    )
    expect_false(file.exists(file.path(d, "z")))
  }
})

test_that("the writer works where there is no compiled code (a bundle)", {
  # a bundle sources lib_helpers.R and aaa_input_guards.R into plain R
  e <- new.env(parent = baseenv())
  for (f in c(".rmbl_path_kind", ".rmbl_wfile", ".rmbl_wconn", ".rmbl_fn",
              ".rmbl_discard", ".rmbl_eol", ".rmbl_wtarget", ".rmbl_wput",
              ".rmbl_wdiscard", ".rmbl_wconn_fill")) {
    g <- get(f)
    environment(g) <- e
    assign(f, g, envir = e)
  }
  d <- withr::local_tempdir()
  p <- file.path(d, "a.txt")
  expect_identical(e$.rmbl_path_kind(d), "directory")
  expect_identical(e$.rmbl_path_kind(p), "missing")
  e$.rmbl_wfile(p, c("x", "y"))
  expect_identical(readLines(p), c("x", "y"))
  expect_identical(e$.rmbl_path_kind(p), "regular")
})

test_that("output can be discarded, and text ends lines as before", {
  # /dev/null (NUL on Windows) is a target, not a device to refuse
  null <- if (.Platform$OS.type == "windows") "NUL" else "/dev/null"
  expect_identical(.rmbl_wfile(null, "x"), null)
  expect_identical(.rmbl_wfile(null, function(con) writeBin(raw(3), con)), null)
  expect_true(.rmbl_discard("/dev/null"))
  expect_false(.rmbl_discard(file.path(tempdir(), "null")))
  m <- mkmnf(list(x = 1), env = FALSE)
  if (!identical(null, "NUL")) {
    expect_identical(wrmnfjs(m, null), null)
  }
  # what a text connection writes on Windows, so files keep their bytes
  b <- charToRaw("a\nb\n\nc")
  expect_identical(.rmbl_eol(b, win = FALSE), b)
  expect_identical(
    .rmbl_eol(b, win = TRUE),
    charToRaw("a\r\nb\r\n\r\nc")
  )
  expect_identical(.rmbl_eol(charToRaw("abc"), win = TRUE), charToRaw("abc"))
  expect_identical(.rmbl_eol(raw(0), win = TRUE), raw(0))
  # a CSV through a text connection ends lines as write.csv() to a path did
  d <- withr::local_tempdir()
  a <- file.path(d, "a.csv")
  b2 <- file.path(d, "b.csv")
  df <- data.frame(x = 1:2, y = c("p", "q"))
  utils::write.csv(df, a, row.names = FALSE)
  .rmbl_wfile(b2, function(con) {
    utils::write.csv(df, con, row.names = FALSE)
  }, binary = FALSE)
  expect_identical(readBin(b2, "raw", 100L), readBin(a, "raw", 100L))
})

test_that("the temporary of a cut-short write is no content", {
  expect_true(.rmbl_leftover(".rmbl-1a2b3c.tmp"))
  expect_true(.rmbl_leftover("sub/.rmbl-ff.tmp"))
  expect_false(.rmbl_leftover("rmbl-1a.tmp"))
  expect_false(.rmbl_leftover(".rmbl-1a.tmp.csv"))
  dir <- withr::local_tempdir()
  writeLines("x", file.path(dir, "a.csv"))
  left <- file.path(dir, ".rmbl-1a2b3c.tmp")
  writeLines("half a bundle", left)
  m <- mkmnf(list(x = 1), env = FALSE)
  bp <- file.path(withr::local_tempdir(), "b.json")
  b <- cpsbndl(dir, m, "a secret", path = bp)
  expect_identical(
    vapply(b$files, function(e) e$path, ""),
    "a.csv"
  )
  r <- cpsbndlvrf(bp, dir, man = m, key = "a secret")
  expect_false(r$ok)
  expect_match(
    r$checks$detail[r$checks$check == "no_unlisted_files"],
    paste0(
      "left over from an interrupted write, not part of the capsule ",
      "(remove it): .rmbl-1a2b3c.tmp"
    ),
    fixed = TRUE
  )
  unlink(left)
  expect_true(cpsbndlvrf(bp, dir, man = m, key = "a secret")$ok)
})
