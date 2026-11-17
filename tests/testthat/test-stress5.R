# SPDX-License-Identifier: AGPL-3.0-or-later
# The last round of hostile input before 1.1.1: hidden capsule folders,
# compressed files under the size cap, pipes and devices, names that are not
# text, and refusals that carried raw bytes.

s5_capsule <- function(root, name = "one") {
  d <- file.path(root, name)
  dir.create(d, recursive = TRUE)
  utils::write.csv(data.frame(x = 1:3), file.path(d, "data.csv"),
                   row.names = FALSE)
  writeLines('{"resource": {"filename": "data.csv"}}',
             file.path(d, "data_provenance.json"))
  d
}
s5_msg <- function(expr) tryCatch(expr, error = conditionMessage)

test_that("a capsule in a dot-folder is found; .git and .rmbl-cache are not", {
  root <- withr::local_tempdir()
  names <- c("one", ".two", file.path(".git", "x"),
             file.path(".rmbl-cache", "y"))
  for (n in names) {
    s5_capsule(root, n)
  }
  d <- .bl_capsule_dirs(root)
  expect_setequal(basename(d), c("one", ".two"))
})

test_that("a compressed file is not inflated past the size cap", {
  f <- withr::local_tempfile(fileext = ".json")
  for (open in list(gzfile, bzfile, xzfile)) {
    con <- open(f, "wb")
    writeLines('{"a": 1}', con)
    close(con)
    one <- data.frame(a = 1)
    readers <- list(
      loadprov, idcrdrd, cpsbndlrd,
      function(p) mnfdiff(p, p),
      function(p) vrfrcdmnf(p, one, one)
    )
    for (read in readers) {
      expect_match(
        s5_msg(read(f)),
        "the file is compressed \\((gzip|bzip2|xz)\\)"
      )
    }
  }
  expect_match(s5_msg(loadprov(f)), "decompress it first")
  # the page siuprs() reads is held to its cap by its bytes on disk
  con <- gzfile(f, "wb")
  writeLines("<html></html>", con)
  close(con)
  expect_false(identical(s5_msg(siuprs(f)), "NO"))
})

test_that("a NUL byte is refused by every reader of a JSON file", {
  f <- withr::local_tempfile(fileext = ".json")
  writeBin(c(charToRaw('{"a":1}'), as.raw(0L), charToRaw('{"b":2}')), f)
  expect_error(loadprov(f), "holds a NUL byte")
  expect_error(mnfdiff(f, f), "holds a NUL byte")
  expect_error(idcrdrd(f), "holds a NUL byte")
  writeLines('{"a": 1}', f)
  expect_identical(loadprov(f)$a, 1L)
})

test_that("a data file that is no regular file is not read as a table", {
  root <- withr::local_tempdir()
  d <- s5_capsule(root)
  local_mocked_bindings(
    .rmbl_path_kind = function(path) {
      if (grepl("data\\.csv$", path)) "other" else "regular"
    },
    .package = "rmoriebricklayer"
  )
  x <- vrfcps(d)
  row <- x$checks[x$checks$check == "data_readable", , drop = FALSE]
  expect_identical(nrow(row), 1L)
  expect_false(isTRUE(row$ok))
  expect_false(isTRUE(row$pass))
})

test_that("the command line refuses a device where it reads a file", {
  skip_on_os("windows")
  out <- utils::capture.output(st <- blcli(c("wayback", "/dev/null")))
  expect_identical(st, 1L)
  expect_match(paste(out, collapse = " "), "not a regular file")
  out <- utils::capture.output(
    st <- blcli(c("migrate", "/dev/null")), type = "message"
  )
  out <- c(out, utils::capture.output(blcli(c("migrate", "/dev/null"))))
  expect_match(paste(out, collapse = " "), "not a regular file")
  r <- .bl_migrate_read("/dev/null")
  expect_null(r$lines)
  expect_match(r$why, "a device, a pipe or a socket")
  expect_error(
    .bl_cli_sign_key("", "/dev/null", function(m) stop(m, call. = FALSE)),
    "--key-file: not a regular file"
  )
})

test_that("a file name that is not text is reported, not an error", {
  skip_on_os(c("windows", "mac"))
  root <- withr::local_tempdir()
  d <- s5_capsule(root)
  withr::local_options(morie.progress = FALSE)
  # file.path() itself refuses such a name before R 4.2
  bad <- tryCatch(file.path(d, "caf\xe9.txt"), error = function(e) NULL)
  skip_if(is.null(bad))
  skip_if_not(isTRUE(tryCatch({
    writeLines("e", bad)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)))
  expect_error(cpsseal(root, fipskg("ML-DSA-44")),
               "name is not valid text .*caf<e9>\\.txt")
  unlink(bad)
  cpsseal(root, fipskg("ML-DSA-44"))
  writeLines("e", bad)
  expect_no_warning(v <- cpsbndlvrf(file.path(d, "capsule_bundle.json"), d))
  expect_true(all(validUTF8(v$checks$detail)))
  expect_true(any(grepl("caf<e9>.txt", v$checks$detail, fixed = TRUE)))
  x <- cpschk(root, fp = FALSE)
  expect_identical(x$status, "error")
  expect_no_warning(expect_false(.rmbl_leftover("caf\xe9.txt")))
})

test_that("refusals show control and non-text bytes escaped", {
  # in a Latin-1 session the byte ff is text (y with diaeresis)
  for (f in if (!isTRUE(l10n_info()[["Latin-1"]])) list(fipskg, fipssz)) {
    e <- s5_msg(f("a\xffb"))
    expect_true(validUTF8(e))
    expect_match(e, "unknown scheme 'a<ff>b'", fixed = TRUE)
  }
  for (f in list(sha512file, crc32file, cpsbndlrd, idcrdrd, ldgrread)) {
    e <- s5_msg(f("a\033[2Jb\nc"))
    expect_match(e, "no such file")
    expect_false(grepl("[\033\n]", e))
  }
})

test_that("cblake2b() takes one string or raw bytes as its key", {
  for (k in list(Inf, NaN, 42, TRUE, data.frame(a = 1:2), c("a", "b"),
                 NA_character_)) {
    expect_error(cblake2b("m", key = k), "length-1 character vector or a raw")
  }
  raw_k <- charToRaw("k")
  expect_identical(cblake2b("m", key = "k"), cblake2b("m", key = raw_k))
})

test_that("explerr() is quiet on a very long message", {
  expect_no_warning(x <- explerr(strrep("a", 5000L)))
  expect_no_error(x)
})

test_that("line readers of a named file do not inflate a compressed one", {
  f <- withr::local_tempfile(fileext = ".txt")
  con <- gzfile(f, "wb")
  writeLines(strrep("a", 5000L), con)
  close(con)
  expect_lt(sum(nchar(.rmbl_rlines(f), "bytes")), 200)
  writeLines(c("one", "two"), f)
  expect_identical(.rmbl_rlines(f), c("one", "two"))
  expect_identical(.rmbl_rlines(f, n = 1L), "one")
  # a gzip file given as a list of URLs, a script or a key is not its text
  con <- gzfile(f, "wb")
  writeLines("https://example.org/", con)
  close(con)
  got <- .bl_migrate_read(f)$lines
  expect_false(any(grepl("example.org", got, useBytes = TRUE)))
  expect_null(.rmbl_xmss_bundle_row(f))
})

test_that("a capsule inside another is sealed first, and the tree checks", {
  root <- withr::local_tempdir()
  s5_capsule(root)
  s5_capsule(root, file.path("one", ".sub"))
  s5_capsule(root, file.path("one", "in"))
  withr::local_options(morie.progress = FALSE)
  d <- .bl_seal_dirs(root, FALSE, "")
  expect_identical(basename(d), c(".sub", "in", "one"))
  cpsseal(root, fipskg("ML-DSA-44"))
  expect_identical(cpschk(root, fp = FALSE)$status, "ok")
})

test_that("a file check shows the path as it is without the escaper", {
  # a capsule bundle sources the guards before the printing code
  # the source file is there in a source tree, not under R CMD check
  src <- test_path("..", "..", "R", "aaa_input_guards.R")
  skip_if_not(file.exists(src))
  e <- new.env()
  sys.source(src, envir = e)
  skip_if_not(exists(".rmbl_shown", envir = e, inherits = FALSE))
  environment(e$.rmbl_shown) <- baseenv()
  expect_identical(e$.rmbl_shown("a b"), "a b")
  expect_identical(.rmbl_shown("a\033b"), .rmbl_ctl_escape("a\033b"))
})

test_that("the run verb reads a named file from its bytes, a regular one", {
  d <- withr::local_tempdir()
  g <- file.path(d, "w.csv")
  writeLines(c("a,b", "1,2"), g)
  expect_identical(.bl_run_value(g), data.frame(a = 1L, b = 2L))
  f <- file.path(d, "v.csv")
  con <- gzfile(f, "wb")
  writeLines(c("a", "1"), con)
  close(con)
  expect_match(s5_msg(.bl_run_value(f)), "compressed")
  skip_on_os("windows")
  for (p in file.path(d, c("p.csv", "p.rds"))) {
    skip_if_not(system2("mkfifo", shQuote(p)) == 0L)
    expect_match(s5_msg(.bl_run_value(p)), "not a regular file")
  }
})

test_that("a link that leaves a capsule is refused before any seal", {
  skip_on_os("windows")
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  dir.create(file.path(root, "shared"))
  writeLines("n", file.path(root, "shared", "notes.txt"))
  skip_if_not(file.symlink(file.path(root, "shared"), file.path(a, "ln")))
  withr::local_options(morie.progress = FALSE)
  k <- fipskg("ML-DSA-44")
  expect_match(s5_msg(cpsseal(root, k)), "link that leaves the capsule")
  expect_false(file.exists(file.path(a, "capsule_bundle.json")))
  expect_match(
    s5_msg(cpsbndl(a, mkmnf(list(), env = FALSE), k)),
    "link that leaves the capsule"
  )
  # a link that stays inside is content like any other
  unlink(file.path(a, "ln"))
  file.symlink(file.path(a, "data.csv"), file.path(a, "same.csv"))
  cpsseal(root, k)
  expect_identical(cpschk(root, fp = FALSE)$status, "ok")
})

test_that("a capsule that cannot be sealed stops the seal before the first", {
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  s5_capsule(root, file.path("b", "deep"))
  cc <- s5_capsule(root, "c")
  writeLines('{"resource": {"filename": "../x.csv"}}',
             file.path(cc, "data_provenance.json"))
  withr::local_options(morie.progress = FALSE)
  expect_match(s5_msg(cpsseal(root, fipskg("ML-DSA-44"))),
               "must name the data file")
  expect_false(file.exists(file.path(a, "capsule_bundle.json")))
  expect_false(file.exists(file.path(root, "b", "deep", "capsule_bundle.json")))
  expect_null(loadprov(file.path(a, "data_provenance.json"))$resource$sha256)
})

test_that("cpsseal() checks key, manifest and names before it writes", {
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  b <- s5_capsule(root, "b")
  withr::local_options(morie.progress = FALSE)
  pinned <- function() {
    !is.null(loadprov(file.path(a, "data_provenance.json"))$resource$sha256)
  }
  expect_error(cpsseal(root, NULL))
  expect_false(pinned())
  writeLines("not json", file.path(b, "manifest.json"))
  expect_error(cpsseal(root, fipskg("ML-DSA-44")))
  expect_false(pinned())
  expect_false(file.exists(file.path(a, "capsule_bundle.json")))
})

test_that("a link back into the capsule is refused by its name", {
  skip_on_os("windows")
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  skip_if_not(file.symlink(".", file.path(a, "loop")))
  withr::local_options(morie.progress = FALSE)
  e <- s5_msg(cpsseal(root, fipskg("ML-DSA-44")))
  expect_match(e, "points back into the capsule folder")
  expect_match(e, "loop$")
  expect_false(grepl("loop/loop", e, fixed = TRUE))
})

test_that("the run verb reads a .csv as a table of text", {
  d <- withr::local_tempdir()
  f <- file.path(d, "t.csv")
  writeLines(c("BZh_code,n", "a,1"), f)
  expect_named(.bl_run_value(f), c("BZh_code", "n"))
  file.create(f)
  expect_match(s5_msg(.bl_run_value(f)), "the .csv is empty")
  writeBin(c(charToRaw("a,b\n1,"), as.raw(0L), charToRaw("\n")), f)
  expect_match(s5_msg(.bl_run_value(f)), "NUL byte")
})

s5_snap <- function(root) {
  f <- list.files(root, recursive = TRUE, all.files = TRUE)
  stats::setNames(tools::md5sum(file.path(root, f)), f)
}

test_that("links back to the capsule or above it are refused at once", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  skip_if_not(file.symlink(".", file.path(a, "l1")))
  file.symlink(".", file.path(a, "l2"))
  file.symlink("/", file.path(a, "top"))
  file.symlink("../..", file.path(a, "up"))
  t <- system.time(e <- s5_msg(cpsbndl(a, mkmnf(list(), env = FALSE), "k")))
  expect_lt(t[["elapsed"]], 10)
  expect_match(e, "points back into the capsule folder")
  for (n in c("l1", "l2", "top", "up")) {
    expect_match(e, n, fixed = TRUE)
  }
  expect_match(s5_msg(cpsseal(root, "k")), "points back")
  expect_false(file.exists(file.path(a, "capsule_bundle.json")))
  # a loop to a folder that holds no file of its own
  b <- s5_capsule(root, "b")
  dir.create(file.path(b, "x", "y"), recursive = TRUE)
  writeLines("g", file.path(b, "x", "y", "g.txt"))
  file.symlink("..", file.path(b, "x", "y", "z"))
  e <- s5_msg(cpsbndl(b, mkmnf(list(), env = FALSE), "k"))
  expect_match(e, "points back into the capsule folder.*x/y/z$")
  # the check of a bundle walks the folder the same way, and reports it
  unlink(file.path(b, "x", "y", "z"))
  bn <- cpsbndl(b, mkmnf(list(), env = FALSE), "k")
  file.symlink(".", file.path(b, "x", "lp"))
  v <- cpsbndlvrf(attr(bn, "path"), b, key = "k")
  row <- v$checks[v$checks$check == "no_unlisted_files", ]
  expect_false(row$ok)
  expect_match(row$detail, "points back.*x/lp")
})

test_that("links that stay inside are content, and a deep tree is walked", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  dir.create(file.path(a, "sub"))
  writeLines("s", file.path(a, "sub", "s.txt"))
  skip_if_not(file.symlink("sub", file.path(a, "alias")))
  deep <- do.call(file.path, as.list(c(a, sprintf("l%02d", 1:30))))
  dir.create(deep, recursive = TRUE)
  writeLines("d", file.path(deep, "deep.txt"))
  dir.create(file.path(a, ".hid"))
  writeLines("h", file.path(a, ".hid", ".x"))
  writeLines("t", file.path(a, ".rmbl-0a1b.tmp"))
  b <- cpsbndl(a, mkmnf(list(), env = FALSE), "k")
  p <- vapply(b$files, `[[`, "", "path")
  expect_true(all(c("alias/s.txt", "sub/s.txt", ".hid/.x") %in% p))
  expect_true(any(endsWith(p, "l30/deep.txt")))
  expect_false(any(grepl("rmbl-", p, fixed = TRUE)))
  unlink(file.path(a, ".rmbl-0a1b.tmp"))
  expect_true(cpsbndlvrf(attr(b, "path"), a, key = "k")$ok)
  # through a link to the capsule itself
  ln <- file.path(root, "ln")
  file.symlink(a, ln)
  expect_true(cpsbndlvrf(file.path(ln, "capsule_bundle.json"), ln,
                         key = "k")$ok)
  # pairs of links that list the folders below 2^n times stop at 64
  p <- file.path(a, "g")
  dir.create(p)
  for (i in 1:8) {
    file.symlink("d", file.path(p, "l1"))
    file.symlink("d", file.path(p, "l2"))
    p <- file.path(p, "d")
    dir.create(p)
  }
  t <- system.time(e <- s5_msg(cpsbndl(a, mkmnf(list(), env = FALSE), "k")))
  expect_lt(t[["elapsed"]], 20)
  expect_match(e, "more than 64 times")
})

test_that("a folder that cannot be read is refused, not skipped", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  sd <- file.path(a, "sd")
  dir.create(sd)
  writeLines("z", file.path(sd, "z.txt"))
  Sys.chmod(sd, "000")
  on.exit(Sys.chmod(sd, "755"), add = TRUE)
  skip_if(file.access(sd, 4L) == 0L) # run as root
  expect_match(s5_msg(cpsbndl(a, mkmnf(list(), env = FALSE), "k")),
               "cannot be read \\(permission denied\\).*: sd$")
  expect_match(s5_msg(cpsseal(root, "k")), "cannot be read")
  expect_false(file.exists(file.path(a, "capsule_bundle.json")))
  # a folder under the searched path, outside any capsule
  Sys.chmod(sd, "755")
  hid <- file.path(root, "hid")
  dir.create(hid)
  Sys.chmod(hid, "000")
  on.exit(Sys.chmod(hid, "755"), add = TRUE)
  expect_match(s5_msg(cpsseal(root, "k")), "capsule in it would be missed")
})

test_that("a name that is UTF-8 is bundled by its bytes", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  a <- s5_capsule(root, "a")
  nm <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9)))
  f <- tryCatch(file.path(a, nm), error = function(e) NULL)
  skip_if(is.null(f))
  skip_if_not(isTRUE(tryCatch(file.create(f), warning = function(w) FALSE)))
  # a path marked UTF-8 keeps its bytes for the file system
  u <- nm
  Encoding(u) <- "UTF-8"
  expect_identical(charToRaw(.rmbl_fspath(u)), charToRaw(nm))
  expect_no_warning(s <- cpsseal(root, "k"))
  j <- readBin(file.path(a, "capsule_bundle.json"), "raw", 1e6)
  expect_true(grepl(nm, rawToChar(j), fixed = TRUE, useBytes = TRUE))
  expect_no_warning(x <- cpschk(root, key = "k", fp = FALSE))
  expect_identical(x$status, "ok")
})

test_that("bytes Latin-1 cannot convert are not text", {
  for (b in c(0x81, 0x8d, 0x8f, 0x90, 0x9d)) {
    s <- rawToChar(as.raw(c(0x61, b, 0x62)))
    Encoding(s) <- "latin1"
    expect_true(.rmbl_nontext(s))
    expect_no_warning(e <- .rmbl_ctl_escape(s))
    expect_true(validUTF8(e))
  }
  s <- rawToChar(as.raw(c(0x63, 0x61, 0x66, 0xe9)))
  Encoding(s) <- "latin1"
  expect_false(.rmbl_nontext(s))
  expect_match(.bl_names(rawToChar(as.raw(c(0x61, 0xe9)))), "a<e9>",
               fixed = TRUE)
})

test_that("cpsseal() writes nothing when the key cannot sign them all", {
  withr::local_options(
    morie.progress = FALSE,
    rmoriebricklayer.xmssidxfile = withr::local_tempfile()
  )
  root <- withr::local_tempdir()
  s5_capsule(root, "a")
  s5_capsule(root, "b")
  b0 <- s5_snap(root)
  k <- fipskg("ML-DSA-44")
  expect_match(s5_msg(cpsseal(root, fipspubkey(k))), "public key")
  spent <- pqckg(2)
  invisible(cpsatst(mkmnf(list(), env = FALSE), spent))
  expect_match(s5_msg(cpsseal(root, spent)), "index 0 of this key")
  one <- pqckg(1)
  s <- cpsatst(mkmnf(list(), env = FALSE), one)
  one <- xmssadv(one, s$signature)
  expect_match(s5_msg(cpsseal(root, one)), "1 signatures left and 2")
  expect_identical(s5_snap(root), b0)
  # the index was not spent: the key still seals one capsule
  unlink(file.path(root, "b"), recursive = TRUE)
  expect_identical(nrow(cpsseal(root, one)), 1L)
})

test_that("cpsseal() checks every manifest and file before it writes", {
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  s5_capsule(root, "a")
  b <- s5_capsule(root, "b")
  b0 <- s5_snap(root)
  for (t in c("1", "[]", "[1, 2]", "\"x\"")) {
    writeLines(t, file.path(b, "manifest.json"))
    expect_match(s5_msg(cpsseal(root, "k")), "must hold a JSON object")
  }
  writeLines("{}", file.path(b, "manifest.json"))
  b0 <- s5_snap(root)
  skip_on_os("windows")
  z <- file.path(b, "z.txt")
  writeLines("z", z)
  Sys.chmod(z, "000")
  on.exit(Sys.chmod(z, "644"), add = TRUE)
  skip_if(file.access(z, 4L) == 0L)
  expect_match(s5_msg(cpsseal(root, "k")), "cannot be read")
  Sys.chmod(z, "644")
  expect_identical(s5_snap(root)[names(b0)], b0)
  expect_false(file.exists(file.path(root, "a", "capsule_bundle.json")))
})

test_that("a seal that fails while writing puts every file back", {
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  s5_capsule(root, "a")
  s5_capsule(root, file.path("a", "in"))
  s5_capsule(root, "b")
  cpsseal(root, "k")
  b0 <- s5_snap(root)
  # the second bundle written fails, as on a full disk
  cnt <- new.env()
  cnt$n <- 0L
  local_mocked_bindings(.bl_bnd_write = function(bundle, path) {
    cnt$n <- cnt$n + 1L
    if (cnt$n == 2L) stop("the disk is full", call. = FALSE)
    .rmbl_wlines("{}", path)
  })
  e <- s5_msg(cpsseal(root, "k", overwrite = TRUE))
  expect_match(e, "the disk is full; every file the seal had written")
  expect_identical(s5_snap(root), b0)
  # a provenance pinned before the failed write is put back too
  r <- withr::local_tempdir()
  s5_capsule(r, "a")
  r0 <- s5_snap(r)
  cnt$n <- 1L
  # evaluated once: expect_match() evaluates its argument twice
  e <- s5_msg(cpsseal(r, "k"))
  expect_match(e, "put back")
  expect_identical(s5_snap(r), r0)
})

test_that("the run verb refuses what is no table in its own words", {
  d <- withr::local_tempdir()
  w <- function(n, b) {
    p <- file.path(d, n)
    writeBin(b, p)
    p
  }
  m <- function(p) s5_msg(.bl_run_value(p))
  expect_match(m(w("nl.csv", charToRaw("\n \n"))), "only blank lines")
  zst <- as.raw(c(0x28, 0xb5, 0x2f, 0xfd, 1, 2, 3, 4, 0xc3, 0x28))
  expect_match(m(w("z.csv", zst)), "compressed \\(zstd\\)")
  lz4 <- as.raw(c(0x04, 0x22, 0x4d, 0x18, 1, 2))
  expect_match(m(w("l.csv", lz4)), "compressed \\(lz4\\)")
  # bytes that are not UTF-8 are text only in a Latin-1 session
  b <- w("b.csv", as.raw(c(0x61, 0x2c, 0xff, 0xfe, 0x0a)))
  if (isTRUE(l10n_info()[["Latin-1"]])) {
    expect_s3_class(.bl_run_value(b), "data.frame")
  } else {
    expect_match(m(b), "holds bytes that are not text")
  }
  expect_match(m(w("q.csv", charToRaw("a,b\n\"1,2\n"))),
               "run: the .csv cannot be read as a table \\(")
  # a NUL past the first block is found
  big <- c(rep(charToRaw("a,b\n"), 300000L), as.raw(0L))
  expect_match(m(w("n.csv", big)), "NUL byte")
  expect_match(m(w("e.rds", raw(0))), "the .rds is empty")
  expect_match(m(w("j.rds", charToRaw("not rds"))), "is not an RDS file")
  r <- file.path(d, "t.rds")
  saveRDS(data.frame(x = 1:1000), r)
  b <- readBin(r, "raw", file.size(r))
  expect_match(m(w("c.rds", b[seq_len(length(b) %/% 2L)])),
               "truncated or damaged")
  expect_identical(nrow(.bl_run_value(r)), 1000L)
})
