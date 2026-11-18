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
  # the temporary of a write cut short is refused, as the check reports it
  expect_match(s5_msg(cpsbndl(a, mkmnf(list(), env = FALSE), "k")),
               "is not part of the capsule and is safe to delete")
  unlink(file.path(a, ".rmbl-0a1b.tmp"))
  b <- cpsbndl(a, mkmnf(list(), env = FALSE), "k")
  p <- vapply(b$files, `[[`, "", "path")
  expect_true(all(c("alias/s.txt", "sub/s.txt", ".hid/.x") %in% p))
  expect_true(any(endsWith(p, "l30/deep.txt")))
  expect_false(any(grepl("rmbl-", p, fixed = TRUE)))
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
  .bl_bnd_write_real <- .bl_bnd_write
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
  # what was put back leaves nothing in the way: the seal runs again
  local_mocked_bindings(.bl_bnd_write = .bl_bnd_write_real)
  expect_identical(nrow(cpsseal(r, "k")), 1L)
  expect_identical(cpschk(r, key = "k", fp = FALSE)$status, "ok")
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

# Names that are not ASCII on the path, one rule for a bundle's names, empty
# folders, links out of a search, and a seal whose tree always checks.

s10_u <- function(...) rawToChar(as.raw(c(...)))
s10_cli <- function(args, key = "k") {
  withr::local_envvar(RMBL_KEY = key)
  rec <- new.env()
  rec$txt <- character()
  st <- blcli(args, out = function(s) rec$txt <- c(rec$txt, s))
  list(status = st, out = paste(rec$txt, collapse = ""))
}
# every entry under a folder: its name, mode, link target and bytes
s10_state <- function(root) {
  f <- list.files(root, recursive = TRUE, all.files = TRUE,
                  include.dirs = TRUE, no.. = TRUE)
  p <- .rmbl_jpath(root, f)
  i <- file.info(p, extra_cols = FALSE)
  md <- rep("", length(p))
  reg <- !is.na(i$isdir) & !i$isdir
  md[reg] <- unname(tools::md5sum(p[reg]))
  sort(paste(f, format(i$mode), Sys.readlink(p), md, sep = "|"))
}
# a random capsule tree: one or two capsules, sub-folders to two levels,
# names mostly fine and some a bundle refuses, empty folders, links that stay
# inside, a read-only or unreadable data file, a folder that cannot be
# written to
s10_tree <- function(root, good, bad, dirs, mode) {
  for (i in seq_len(sample(2L, 1L))) {
    d <- s5_capsule(root, sprintf("c%d", i))
    for (j in seq_len(sample(0:4, 1L))) {
      sub <- d
      for (p in sample(dirs, sample(0:2, 1L), replace = TRUE)) {
        sub <- .rmbl_jpath(sub, p)
      }
      dir.create(sub, recursive = TRUE, showWarnings = FALSE)
      if (stats::runif(1L) < 0.8) {
        nm <- sample(if (stats::runif(1L) < 0.85) good else bad, 1L)
        # a file system that refuses the name (macOS, for bytes that are
        # not UTF-8) warns as well as failing: the name is then left out
        try(suppressWarnings(writeLines("v", .rmbl_jpath(sub, nm))),
            silent = TRUE)
      }
    }
    if (stats::runif(1L) < 0.3) {
      file.symlink("data.csv", file.path(d, "ln.csv"))
    }
    if (stats::runif(1L) < 0.3 && dir.exists(file.path(d, "sub"))) {
      file.symlink("sub", file.path(d, "lnd"))
    }
    if (mode && stats::runif(1L) < 0.25) {
      Sys.chmod(file.path(d, "data.csv"), sample(c("444", "000"), 1L))
    }
    if (mode && stats::runif(1L) < 0.1) {
      Sys.chmod(d, "555")
    }
  }
}
s10_writable <- function(root) {
  Sys.chmod(list.dirs(root), "755")
  Sys.chmod(list.files(root, recursive = TRUE, all.files = TRUE,
                       full.names = TRUE), "644")
}
s10_warns <- function(expr) {
  seen <- new.env()
  seen$w <- character()
  r <- withCallingHandlers(
    tryCatch(expr, error = function(e) e),
    warning = function(x) {
      seen$w <- c(seen$w, conditionMessage(x))
      invokeRestart("muffleWarning")
    }
  )
  list(value = r, warnings = seen$w)
}

test_that("names that are not ASCII anywhere on a path go through it all", {
  withr::local_options(morie.progress = FALSE)
  e <- s10_u(0xc3, 0xa9)
  top <- withr::local_tempdir()
  # above the capsule, the capsule, a sub-folder and a file: an accent, a
  # Cyrillic letter (its byte 0x81 is no Latin-1 character) and an emoji
  root <- file.path(top, paste0("donn", e, "es"))
  skip_if_not(isTRUE(dir.create(root)))
  d <- s5_capsule(root, paste0(s10_u(0xd0, 0x81), "lka"))
  fig <- file.path(d, paste0(s10_u(0xf0, 0x9f, 0x98, 0x80), "fig"))
  dir.create(fig)
  writeLines("y", file.path(fig, paste0("caf", e, ".txt")))
  man <- mkmnf(list(), env = FALSE)
  r <- s10_warns(cpsbndl(d, man, "k"))
  expect_length(r$warnings, 0L)
  expect_length(r$value$files, 3L)
  expect_true(cpsbndlvrf(r$value, d, key = "k")$ok)
  unlink(attr(r$value, "path"))
  expect_identical(nrow(cpsseal(root, "k")), 1L)
  r <- s10_warns(cpschk(root, key = "k", fp = FALSE))
  expect_length(r$warnings, 0L)
  expect_identical(r$value$status, "ok")
  b <- file.path(d, "capsule_bundle.json")
  expect_true(cpsbndlvrf(b, d, key = "k")$ok)
  expect_identical(nrow(xmssidxseen(root)), 0L)
  expect_identical(s10_cli(c("sign", root, "--overwrite"))$status, 0L)
  expect_identical(s10_cli(c("verify", root))$status, 0L)
  # an XMSS seal, whose signature the search finds again
  withr::local_options(
    rmoriebricklayer.xmssidxfile = withr::local_tempfile()
  )
  cpsseal(root, pqckg(height = 2L), overwrite = TRUE)
  expect_identical(nrow(xmssidxseen(root)), 1L)
  expect_true(cpsbndlvrf(b, d)$ok)
})

test_that("a byte that is not UTF-8 is shown as <xx>, by validUTF8()", {
  cases <- list(
    c(0x61, 0xf8, 0x88, 0x80, 0x80, 0x80), c(0x61, 0xfc, 0x84, 0x80, 0x80,
                                             0x80, 0x80),
    c(0x61, 0xf4, 0x90, 0x80, 0x80), c(0x61, 0xed, 0xa0, 0x80),
    c(0x61, 0xc0, 0xaf), c(0x61, 0xe0, 0x80, 0xaf), c(0x61, 0x80),
    c(0x61, 0xe2, 0x82), c(0x61, 0xf0, 0x9f, 0x98), c(0x61, 0xff)
  )
  want <- c(
    "a<f8><88><80><80><80>", "a<fc><84><80><80><80><80>",
    "a<f4><90><80><80>", "a<ed><a0><80>", "a<c0><af>", "a<e0><80><af>",
    "a<80>", "a<e2><82>", "a<f0><9f><98>", "a<ff>"
  )
  for (i in seq_along(cases)) {
    s <- rawToChar(as.raw(cases[[i]]))
    expect_false(validUTF8(s))
    expect_no_warning(expect_identical(.rmbl_esc8(s), want[[i]]))
    expect_no_warning(expect_identical(.bl_names(s), want[[i]]))
    # text in the session: in a Latin-1 locale these bytes are Latin-1
    expect_no_warning(expect_false(.rmbl_nontext(.rmbl_ctl_escape(s))))
    expect_no_warning(expect_identical(toascii(s), "a"))
  }
  # text is kept, U+FFFE and U+FFFF too: validUTF8() is the rule
  ok <- c(0x61, 0xef, 0xbf, 0xbe, 0xef, 0xbf, 0xbf, 0xc3, 0xa9)
  s <- rawToChar(as.raw(c(ok, 0x80, 0x62)))
  expect_identical(charToRaw(.rmbl_esc8(s)),
                   c(as.raw(ok), charToRaw("<80>b")))
  expect_identical(charToRaw(.rmbl_esc8(s, drop = TRUE)),
                   as.raw(c(ok, 0x62)))
  expect_identical(Encoding(.rmbl_esc8(s)), "UTF-8")
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  d <- s5_capsule(root)
  cpsseal(root, "k")
  bad <- .rmbl_jpath(d, rawToChar(as.raw(cases[[1L]])))
  skip_if_not(isTRUE(tryCatch(file.create(bad), warning = function(w) FALSE,
                              error = function(e) FALSE)))
  r <- s10_warns(cpschk(root, key = "k", fp = FALSE))
  expect_length(r$warnings, 0L)
  expect_identical(r$value$status, "error")
  expect_true(any(grepl(want[[1L]], r$value$rows$detail, fixed = TRUE)))
  r <- s10_warns(cpsbndl(d, mkmnf(list(), env = FALSE), "k"))
  expect_length(r$warnings, 0L)
  expect_match(conditionMessage(r$value), want[[1L]], fixed = TRUE)
})

test_that("one rule for a bundle's names: what is bundled verifies", {
  why <- .rmbl_relwhy
  fine <- c("a.csv", "d/e.txt", ".hidden", "sub/~lock", "x...y", "con2.txt",
            "COM10", "a b.txt", "conx/y")
  expect_identical(why(fine, strict = TRUE), rep("", length(fine)))
  out <- c("", "/x", "\\x", "~x", "c:x", "a//b", "a/./b", "a/../b", "a/",
           ".", "..", "a\\\\b", "x\\.\\y")
  expect_true(all(nzchar(why(out))))
  win <- c("a\\b", "a:b", "a?b", "a*b", "a\"b", "a<b", "a|b", "a\tb", "a.",
           "a ", "d./x", "con", "CON.txt", "nul.tar.gz", "LPT9", "com1/x",
           s10_u(0x61, 0xe9))
  expect_true(all(nzchar(why(win, strict = TRUE))))
  # the check alone takes them, so a bundle made before still verifies
  expect_identical(why(win[c(1L, 3L, 4L, 9L)]), rep("", 4L))
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  for (n in c("~notes.txt", "c:raw.csv", "a\\\\b", "x\\.\\y", "\\lead",
              "con.txt", "trail.", "t\tab")) {
    root <- withr::local_tempdir()
    d <- s5_capsule(root)
    writeLines("z", file.path(d, n))
    b0 <- s10_state(root)
    e <- s5_msg(cpsseal(root, "k"))
    expect_match(e, "cannot be listed in a bundle", fixed = TRUE)
    expect_match(e, "^cpsseal: ")
    expect_identical(s10_state(root), b0)
    expect_match(s5_msg(cpsbndl(d, mkmnf(list(), env = FALSE), "k")),
                 "^cpsbndl: .*cannot be listed")
  }
  root <- withr::local_tempdir()
  d <- s5_capsule(root)
  expect_match(
    s5_msg(cpsbndl(d, mkmnf(list(), env = FALSE), "k", files = "./data.csv")),
    "an empty, . or .. part"
  )
})

test_that("an empty folder is no content: a capsule with one checks", {
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  d <- s5_capsule(root)
  dir.create(file.path(d, "output"))
  dir.create(file.path(d, "deep", "er", "est"), recursive = TRUE)
  dir.create(file.path(d, "ign", ".rmbl-cache"), recursive = TRUE)
  dir.create(file.path(d, "ign", ".git"))
  cpsseal(root, "k")
  expect_identical(cpschk(root, key = "k", fp = FALSE)$status, "ok")
  dir.create(file.path(d, "later"))
  expect_identical(cpschk(root, key = "k", fp = FALSE)$status, "ok")
  writeLines("x", file.path(d, "later", "f.txt"))
  x <- cpschk(root, key = "k", fp = FALSE)
  expect_identical(x$status, "error")
  expect_true(any(grepl("later/f.txt", x$rows$detail, fixed = TRUE)))
  unlink(file.path(d, "later"), recursive = TRUE)
  # a temporary left by a write cut short is refused before the seal, as
  # the check reports it
  writeLines("x", file.path(d, "deep", ".rmbl-0a1b.tmp"))
  b0 <- s10_state(root)
  expect_match(s5_msg(cpsseal(root, "k", overwrite = TRUE)),
               "safe to delete; delete it and run again: .*one/deep/[.]rmbl-")
  expect_identical(s10_state(root), b0)
})

test_that("a search reports a link out of the folder searched", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- withr::local_tempdir()
  s5_capsule(root)
  cpsseal(root, "k")
  far <- withr::local_tempdir()
  dir.create(file.path(far, "private"))
  s5_capsule(far, "elsewhere")
  skip_if_not(file.symlink(far, file.path(root, "shared")))
  Sys.chmod(file.path(far, "private"), "000")
  withr::defer(Sys.chmod(file.path(far, "private"), "755"))
  # not followed (the unreadable folder behind it fails nothing), and named
  x <- cpschk(root, key = "k", fp = FALSE)
  row <- x$rows[x$rows$check == "links_not_followed", ]
  expect_false(row$ok)
  expect_identical(row$severity, "warn")
  expect_match(row$detail, "was not followed.*: [^ ]*shared$")
  # told, not refused: the capsules of the tree are sound, and a project
  # library or a shared data folder is such a link
  expect_false(identical(x$status, "error"))
  expect_true(all(x$rows$ok[x$rows$check != "links_not_followed"]))
  expect_warning(xmssidxseen(root), "^xmssidxseen: .*: [^ ]*shared$")
  expect_warning(cpsseal(root, "k", overwrite = TRUE),
                 "^cpsseal: .*was not followed")
  expect_false(identical(cpschk(root, key = "k", fp = FALSE)$status, "error"))
  unlink(file.path(root, "shared"))
  # a folder under the path that cannot be read is refused in the words of
  # the function called
  skip_if(file.access(file.path(far, "private"), 4L) == 0L)
  dir.create(file.path(root, "locked"))
  Sys.chmod(file.path(root, "locked"), "000")
  withr::defer(Sys.chmod(file.path(root, "locked"), "755"))
  expect_match(s5_msg(cpschk(root, key = "k")), "^cpschk: .*cannot be read")
  expect_match(s5_msg(cpsseal(root, "k")), "^cpsseal: .*cannot be read")
  expect_match(s5_msg(xmssidxseen(root)), "^xmssidxseen: .*cannot be read")
})

test_that("the seal's look-ahead refuses what the check would fail", {
  skip_on_os("windows")
  skip_if(identical(Sys.info()[["effective_user"]], "root"))
  withr::local_options(morie.progress = FALSE)
  mk <- function(n = 3L) {
    root <- withr::local_tempdir(.local_envir = parent.frame())
    for (i in seq_len(n)) s5_capsule(root, sprintf("c%02d", i))
    root
  }
  # a provenance or a bundle that cannot be written to
  root <- mk()
  pf <- file.path(root, "c03", "data_provenance.json")
  Sys.chmod(pf, "444")
  b0 <- s10_state(root)
  expect_match(s5_msg(cpsseal(root, "k")), "c03/data_provenance.json: it c")
  expect_identical(s10_state(root), b0)
  Sys.chmod(pf, "644")
  cpsseal(root, "k")
  bf <- file.path(root, "c03", "capsule_bundle.json")
  Sys.chmod(bf, "444")
  b0 <- s10_state(root)
  e <- s5_msg(cpsseal(root, "k", overwrite = TRUE))
  expect_match(e, "c03/capsule_bundle.json: it cannot be written to")
  expect_false(grepl("put back", e, fixed = TRUE))
  expect_identical(s10_state(root), b0)
  # a manifest that fails its schema, a data file that does not read
  root <- mk()
  writeLines("{\"inputs\": 5}", file.path(root, "c02", "manifest.json"))
  b0 <- s10_state(root)
  expect_match(s5_msg(cpsseal(root, "k")),
               "c02: the check would fail .*schema: manifest.json")
  expect_identical(s10_state(root), b0)
  root <- mk()
  close(file(file.path(root, "c02", "data.csv"), "w"))
  expect_match(s5_msg(cpsseal(root, "k")), "c02: .*data_readable")
  # a provenance or manifest that is no JSON is named
  root <- mk()
  writeLines("{oops", file.path(root, "c02", "data_provenance.json"))
  expect_match(s5_msg(cpsseal(root, "k")),
               "^cpsseal: .*c02/data_provenance.json: ")
  root <- mk()
  file.create(file.path(root, "c03", "manifest.json"))
  expect_match(s5_msg(cpsseal(root, "k")), "^cpsseal: .*c03/manifest.json: ")
})

test_that("the run verb reads UTF-8 as UTF-8 in every locale", {
  f <- withr::local_tempfile(fileext = ".csv")
  cafe <- as.raw(c(0x63, 0x61, 0x66, 0xc3, 0xa9))
  writeBin(c(as.raw(c(0xef, 0xbb, 0xbf)), charToRaw("a,b\n"), cafe,
             charToRaw(",1\n")), f)
  r <- s10_warns(.bl_run_value(f))
  expect_length(r$warnings, 0L)
  expect_named(r$value, c("a", "b"))
  expect_identical(charToRaw(r$value$a), cafe)
  expect_identical(Encoding(r$value$a), "UTF-8")
  for (bom in list(c(0xff, 0xfe), c(0xfe, 0xff), c(0xff, 0xfe, 0, 0),
                   c(0, 0, 0xfe, 0xff))) {
    writeBin(c(as.raw(bom), charToRaw("a,b\n")), f)
    expect_match(s5_msg(.bl_run_value(f)), "is UTF-16 or UTF-32 text")
  }
})

test_that("whatever cpsseal() seals passes the check, in C and UTF-8", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  withr::local_seed(10L)
  u <- s10_u
  good <- c("a.csv", "b.txt", ".hid", "sp ace.txt", u(0x63, 0xc3, 0xa9),
            u(0xd0, 0x81, 0x6b), u(0xf0, 0x9f, 0x98, 0x80))
  bad <- c("~notes.txt", "c:raw.csv", "a\\b", "\\lead", "con.txt", "trail.",
           "t\tab", "q?.txt", u(0x6c, 0xe9), u(0x61, 0xf8, 0x88, 0x80, 0x80,
                                                 0x80), ".rmbl-0a1b.tmp")
  dirs <- c("sub", "deep", u(0x64, 0xc3, 0xa9), ".git", ".rmbl-cache", "x:y")
  root0 <- withr::local_tempdir()
  mode <- !identical(Sys.info()[["effective_user"]], "root")
  locs <- c("C", "C.UTF-8")
  n <- c(sealed = 0L, refused = 0L)
  for (k in seq_len(40L)) {
    root <- file.path(root0, k)
    s10_tree(root, good, bad, dirs, mode)
    b0 <- s10_state(root)
    r <- s10_warns(cpsseal(root, "k"))
    expect_length(r$warnings, 0L)
    after <- s10_state(root)
    s10_writable(root)
    if (inherits(r$value, "error")) {
      n[["refused"]] <- n[["refused"]] + 1L
      expect_identical(after, b0, info = conditionMessage(r$value))
      expect_false(grepl("translating|invalid|multibyte",
                         conditionMessage(r$value)))
      next
    }
    n[["sealed"]] <- n[["sealed"]] + 1L
    for (loc in locs) {
      old <- Sys.getlocale("LC_CTYPE")
      if (!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", loc)))) next
      x <- s10_warns(cpschk(root, key = "k", fp = FALSE))
      Sys.setlocale("LC_CTYPE", old)
      expect_length(x$warnings, 0L)
      expect_identical(x$value$status, "ok", info = paste(loc, k))
    }
    expect_identical(s10_cli(c("verify", root))$status, 0L)
  }
  expect_true(all(n > 0L))
})

test_that("a seal killed half way is run again once its temporaries go", {
  skip_on_os("windows")
  skip_on_cran()
  root <- withr::local_tempdir()
  s5_capsule(root, "a")
  s5_capsule(root, "b")
  # the second bundle's write kills the process, as SIGKILL would: the
  # first capsule is sealed and the copies the seal keeps are left behind
  code <- sprintf(paste0(
    "options(morie.progress = FALSE); ns <- asNamespace('rmoriebricklayer'); ",
    "n <- 0L; w <- ns$.bl_bnd_write; ",
    "unlockBinding('.bl_bnd_write', ns); ",
    "assign('.bl_bnd_write', function(bundle, path) { n <<- n + 1L; ",
    "if (n == 2L) tools::pskill(Sys.getpid(), tools::SIGKILL); ",
    "w(bundle, path) }, envir = ns); cpsseal('%s', 'k')"
  ), root)
  rscript_bg(code, wait = TRUE)
  left <- list.files(root, "^[.]rmbl-.*[.]tmp$", recursive = TRUE,
                     all.files = TRUE)
  skip_if(!length(left))
  e <- s5_msg(cpsseal(root, "k", overwrite = TRUE))
  expect_match(e, "safe to delete; delete it and run again", fixed = TRUE)
  for (f in left) expect_match(e, f, fixed = TRUE)
  unlink(file.path(root, left))
  expect_identical(nrow(cpsseal(root, "k", overwrite = TRUE)), 2L)
  expect_identical(cpschk(root, key = "k", fp = FALSE)$status, "ok")
})

test_that("a bundle made before the stricter names still verifies", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  d <- withr::local_tempdir()
  # names 1.1.0 bundled and its check took, which a bundle now refuses
  nm <- c("ab:c.csv", "a\\b", "trail.", "q?.txt", "con.txt", "t\tab")
  for (n in nm) writeLines(n, file.path(d, n))
  m <- mkmnf(list(), env = FALSE)
  expect_match(s5_msg(cpsbndl(d, m, "k")), "cannot be listed in a bundle")
  # written as cpsbndl() of 1.1.0 wrote it
  files <- lapply(sort(nm), function(n) {
    p <- file.path(d, n)
    list(path = n, sha256 = sha256file(p), size_bytes = file.size(p))
  })
  payload <- list(files = files, manifest_digest = mnfdgst(m),
                  bundled_utc = "2026-10-01T00:00:00Z")
  att <- cpsatst(list(meta = payload, results = list()), "k")
  b <- structure(c(payload, list(attestation = att)),
                 class = c("bricklayer_bundle", "list"))
  path <- file.path(d, "capsule_bundle.json")
  .bl_bnd_write(b, path)
  v <- cpsbndlvrf(path, d, man = m, key = "k")
  expect_true(v$ok)
  expect_true(all(paste0("file:", nm) %in% v$checks$check))
})

# ---- round 11 ----

s11_tree <- function(n = 1L) {
  root <- withr::local_tempdir(.local_envir = parent.frame())
  for (i in seq_len(n)) s5_capsule(root, sprintf("c%02d", i))
  root
}

test_that("a relative path under a folder that is not UTF-8 seals", {
  skip_on_os("windows")
  # R before 4.2 stops in file.path() on a name it cannot translate
  skip_if(getRversion() < "4.2.0")
  withr::local_options(morie.progress = FALSE)
  base <- withr::local_tempdir()
  lat <- tryCatch(
    suppressWarnings(.rmbl_jpath(base, rawToChar(as.raw(c(0x6c, 0xe9))))),
    error = function(e) NULL
  )
  skip_if(is.null(lat) || !isTRUE(suppressWarnings(dir.create(lat))))
  s5_capsule(.rmbl_jpath(lat, "tree"), "c1")
  withr::local_dir(.rmbl_jpath(lat, "tree"))
  r <- s10_warns(cpsseal(".", "k"))
  expect_length(r$warnings, 0L)
  expect_s3_class(r$value, "data.frame")
  x <- cpschk(".", key = "k", fp = FALSE)
  expect_identical(x$status, "ok")
})

test_that("every leftover temporary is named, however many", {
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(25L)
  left <- sprintf("c%02d/.rmbl-%04x.tmp", 1:25, 1:25)
  for (f in left) writeLines("x", file.path(root, f))
  e <- s5_msg(cpsseal(root, "k"))
  for (f in left) expect_true(grepl(f, e, fixed = TRUE))
  expect_false(grepl("more", e, fixed = TRUE))
})

test_that("a capsule linked in from inside the tree is checked", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  big <- s5_capsule(file.path(root, "store"), "big")
  cpsseal(root, "k")
  skip_if_not(file.symlink(big, file.path(root, "linked")))
  x <- cpschk(root, key = "k", fp = FALSE)
  expect_identical(x$status, "ok")
  # each real folder once: the linked capsule is not checked twice
  expect_length(x$capsules, 2L)
  utils::write.csv(data.frame(x = 7:9), file.path(big, "data.csv"),
                   row.names = FALSE)
  expect_identical(cpschk(root, key = "k", fp = FALSE)$status, "error")
})

test_that("a capsule behind a link out of the tree is reported", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  ext <- s11_tree(1L)
  cpsseal(ext, "k")
  root <- s11_tree(1L)
  cpsseal(root, "k")
  skip_if_not(file.symlink(file.path(ext, "c01"), file.path(root, "big")))
  x <- cpschk(root, key = "k", fp = FALSE)
  expect_false(identical(x$status, "error"))
  expect_true(any(x$rows$check == "links_not_followed" & !x$rows$ok))
  # a warning: the default verify passes, and --fail-on warn does not
  expect_identical(s10_cli(c("verify", root))$status, 0L)
  expect_identical(s10_cli(c("verify", root, "--fail-on", "warn"))$status, 1L)
  expect_identical(s10_cli(c("report", root))$status, 0L)
  expect_warning(cpsseal(root, "k", overwrite = TRUE),
                 "^cpsseal: .*not followed.*: [^ ]*big$")
  expect_false(identical(cpschk(root, key = "k", fp = FALSE)$status, "error"))
})

test_that("link refusals in a tree of capsules are headed and placed", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  for (k in list(c("..", "up"), c("nowhere", "dangling"))) {
    root <- s11_tree(3L)
    skip_if_not(file.symlink(k[[1L]], file.path(root, "c02", k[[2L]])))
    b0 <- s10_state(root)
    e <- s5_msg(cpsseal(root, "k"))
    expect_match(e, "^cpsseal: .*c02: ")
    expect_identical(s10_state(root), b0)
  }
  expect_match(e, "lead nowhere")
})

test_that("a byte-order mark is dropped the same way in every locale", {
  d <- withr::local_tempdir()
  w <- function(nm, b) {
    f <- file.path(d, nm)
    writeBin(as.raw(b), f)
    f
  }
  bom <- c(0xef, 0xbb, 0xbf)
  f1 <- w("a.csv", c(bom, 0x0a))
  f2 <- w("b.csv", c(bom, 0x20, 0x20, 0x0a, 0x20, 0x0a))
  f3 <- w("c.csv", c(bom, bom, charToRaw("a,b\nx,1\n")))
  one <- function() {
    list(s5_msg(.bl_run_value(f1)), s5_msg(.bl_run_value(f2)),
         .bl_run_value(f3))
  }
  old <- Sys.getlocale("LC_CTYPE")
  withr::defer(Sys.setlocale("LC_CTYPE", old))
  got <- lapply(c("C", "C.UTF-8"), function(l) {
    if (!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", l)))) {
      return(NULL)
    }
    r <- one()
    r[1:2] <- lapply(r[1:2], function(x) sub(": [^:]*$", "", x))
    r
  })
  got <- Filter(Negate(is.null), got)
  expect_match(got[[1L]][[1L]], "only blank lines|is empty")
  expect_match(got[[1L]][[2L]], "only blank lines")
  expect_named(got[[1L]][[3L]], c("a", "b"))
  if (length(got) == 2L) {
    expect_identical(got[[1L]], got[[2L]])
  }
})

test_that("names one system takes for one are refused when bundling", {
  withr::local_options(morie.progress = FALSE)
  u <- function(...) intToUtf8(c(...))
  sets <- list(c("A.txt", "a.txt"), c("sub/x", "SUB/x"),
               c(u(0xe9), u(0x65, 0x301)), u(0x43, 0x4f, 0x4d, 0xb9),
               c(u(0x4c, 0x50, 0x54, 0xb3, 0x2e, 0x74)))
  m <- mkmnf(list(), env = FALSE)
  for (s in sets) {
    d <- withr::local_tempdir()
    for (f in s) {
      # by its bytes: a name marked UTF-8 is translated in a C locale
      p <- .rmbl_jpath(d, rawToChar(charToRaw(f)))
      suppressWarnings(dir.create(dirname(p), showWarnings = FALSE))
      suppressWarnings(file.create(p))
    }
    n <- length(list.files(d, recursive = TRUE, all.files = TRUE))
    skip_if(n < length(s), "the file system holds only one of the names")
    expect_match(s5_msg(cpsbndl(d, m, "k")), "^cpsbndl: .*(one name|reserves)")
  }
  # distinct names stay distinct
  d <- withr::local_tempdir()
  for (f in c("a.txt", "b.txt", "resume.txt")) writeLines(f, file.path(d, f))
  expect_s3_class(cpsbndl(d, m, "k"), "bricklayer_bundle")
})

test_that("the caseless match is Unicode's, whatever the locale", {
  u <- function(...) intToUtf8(c(...))
  k <- .rmbl_caseless(c("A.TXT", "a.txt", u(0xc9), u(0x65, 0x301),
                        u(0x212b), u(0xe5), u(0x1d6), u(0x75, 0x308, 0x304),
                        u(0xac00), u(0x1100, 0x1161), u(0x3a3), u(0x3c2)))
  expect_identical(k[[1L]], k[[2L]])
  expect_identical(k[[3L]], k[[4L]])
  expect_identical(k[[5L]], k[[6L]])
  expect_identical(k[[7L]], k[[8L]])
  expect_identical(k[[9L]], k[[10L]])
  expect_identical(k[[11L]], k[[12L]])
  expect_false(identical(.rmbl_caseless("e"), .rmbl_caseless(u(0xe9))))
  expect_length(.rmbl_clash(c("a/b", "a/c", "A")), 1L)
  expect_length(.rmbl_clash(c("a/b", "a/c")), 0L)
})

test_that("a bundle made before the clash rule still verifies", {
  skip_on_os(c("windows", "mac"))
  withr::local_options(morie.progress = FALSE)
  d <- withr::local_tempdir()
  nm <- c("A.txt", "a.txt")
  for (n in nm) writeLines(n, file.path(d, n))
  m <- mkmnf(list(), env = FALSE)
  files <- lapply(nm, function(n) {
    p <- file.path(d, n)
    list(path = n, sha256 = sha256file(p), size_bytes = file.size(p))
  })
  payload <- list(files = files, manifest_digest = mnfdgst(m),
                  bundled_utc = "2026-10-01T00:00:00Z")
  att <- cpsatst(list(meta = payload, results = list()), "k")
  b <- structure(c(payload, list(attestation = att)),
                 class = c("bricklayer_bundle", "list"))
  path <- file.path(d, "capsule_bundle.json")
  .bl_bnd_write(b, path)
  expect_true(cpsbndlvrf(path, d, man = m, key = "k")$ok)
})

test_that("ASCII case is folded by bytes, whatever the locale", {
  u <- function(...) intToUtf8(c(...))
  expect_identical(.rmbl_lower(c("I", "i", u(0x130), u(0x131), NA)),
                   c("i", "i", u(0x130), u(0x131), NA))
  expect_identical(.rmbl_upper(c("I", "i", u(0x130), u(0x131))),
                   c("I", "I", u(0x130), u(0x131)))
  bad <- rawToChar(as.raw(c(0x41, 0xff)))
  expect_identical(charToRaw(.rmbl_lower(bad)), as.raw(c(0x61, 0xff)))
  expect_identical(.rmbl_ci("^file://[a-z]\\.x$"),
                   "^[fF][iI][lL][eE]://[a-zA-Z]\\.[xX]$")
  expect_identical(.rmbl_ci("\\p{L}[[:alpha:]]"), "\\p{L}[[:alpha:]]")
  expect_identical(.rmbl_relwhy("I:data.csv"), "it starts with a drive letter")
  old <- Sys.getlocale("LC_CTYPE")
  withr::defer(Sys.setlocale("LC_CTYPE", old))
  skip_if(!nzchar(suppressWarnings(Sys.setlocale("LC_CTYPE", "tr_TR.UTF-8"))),
          "no Turkish locale")
  expect_identical(.rmbl_relwhy("I:data.csv"), "it starts with a drive letter")
  expect_identical(.rmbl_lower("I"), "i")
  expect_true(grepl(.rmbl_ci("^file://"), "FILE://x", perl = TRUE))
})

test_that("a CSV with no final newline seals and checks under warn = 2", {
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  writeBin(charToRaw("a,b\n1,2"), file.path(root, "c01", "data.csv"))
  r <- s10_warns(cpsseal(root, "k"))
  expect_length(r$warnings, 0L)
  expect_s3_class(r$value, "data.frame")
  withr::local_options(warn = 2)
  expect_identical(cpschk(root, key = "k", fp = FALSE)$status, "ok")
})

test_that("a CSV is read a block of rows at a time, as read.csv() counts", {
  d <- withr::local_tempdir()
  shapes <- c("a,b\n1,2\n3,4\n", "a,b\n1,2\n3\n", "a,b\n1,2\n3,4,5\n",
              "a,b\n1,2\n1,2\n1,2\n1,2\n1,2\n1,2\n3,4,5\n1,2\n",
              "a,b\n1,2,3\n4,5,6\n", "a,b\n\"x\ny\",2\n3,4\n",
              "a,b\n\n\n1,2\n", "a,b\n", "a;b\n1;2\n", "a,b\n1,2",
              "\n\na,b\n1,2\n3,4\n5,6\n7,8\n9,0\n1,1\n2,2\n")
  for (i in seq_along(shapes)) {
    f <- file.path(d, sprintf("s%02d.csv", i))
    writeBin(charToRaw(shapes[[i]]), f)
    want <- nrow(suppressWarnings(utils::read.csv(f, row.names = NULL)))
    for (b in c(1L, 2L, 3L, 65536L)) {
      expect_identical(.vc_csv_scan(f, b), list(n = want, why = NULL))
    }
  }
  writeBin(charToRaw("a\n1,2,3\n"), f)
  expect_match(.vc_csv_scan(f)$why, "more columns than column names")
  file.create(f)
  expect_match(.vc_csv_scan(f)$why, "no lines available")
})

test_that("a CSV that does not read says why, in the seal and the check", {
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  writeBin(charToRaw("a\n1,2,3\n"), file.path(root, "c01", "data.csv"))
  expect_match(s5_msg(cpsseal(root, "k")),
               "data_readable: .*does not read as a CSV: more columns")
})

test_that("a file or link changed while it is hashed stops the seal", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  d <- file.path(root, "c01")
  ln <- file.path(d, "ln")
  skip_if_not(file.symlink("data.csv", ln))
  out <- withr::local_tempfile()
  writeLines("outside", out)
  orig <- sha256file
  st <- new.env()
  st$n <- 0L
  bundling <- function() {
    any(vapply(sys.calls(), function(x) identical(x[[1L]], quote(cpsbndl)),
               NA))
  }
  local_mocked_bindings(sha256file = function(path) {
    if (bundling() && st$n == 0L) {
      st$n <- 1L
      unlink(ln)
      file.symlink(out, ln)
    }
    orig(path)
  })
  b0 <- s10_state(root)
  e <- s5_msg(cpsseal(root, "k"))
  expect_match(e, "^cpsbndl: .*changed.*: ln;")
  # all put back; the link is as the other process left it
  keep <- function(x) x[!startsWith(x, "c01/ln|")]
  expect_identical(keep(s10_state(root)), keep(b0))
  expect_false(file.exists(file.path(d, "capsule_bundle.json")))
})

test_that("a file rewritten after it was hashed stops the seal", {
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  d <- file.path(root, "c01")
  writeLines("v1", file.path(d, "notes.txt"))
  orig <- sha256file
  st <- new.env()
  st$n <- 0L
  local_mocked_bindings(sha256file = function(path) {
    r <- orig(path)
    if (grepl("notes[.]txt$", path, useBytes = TRUE) && st$n == 0L) {
      st$n <- 1L
      writeLines("v2 changed", file.path(d, "notes.txt"))
    }
    r
  })
  # read once: expect_match() evaluates its object twice
  e <- s5_msg(cpsseal(root, "k"))
  expect_match(e, "changed while.*notes.txt")
  expect_false(file.exists(file.path(d, "capsule_bundle.json")))
})

test_that("a refusal or a failed check exits 1, a usage error 2", {
  skip_on_os("windows")
  withr::local_options(morie.progress = FALSE)
  root <- s11_tree(1L)
  cpsseal(root, "k")
  lk <- file.path(root, "locked")
  dir.create(lk)
  Sys.chmod(lk, "000")
  withr::defer(Sys.chmod(lk, "755"))
  skip_if(file.access(lk, 4L) == 0L)
  for (v in c("verify", "report", "drift")) {
    expect_identical(s10_cli(c(v, root))$status, 1L)
  }
  expect_identical(s10_cli(c("sign", root, "--overwrite"))$status, 1L)
  expect_identical(s10_cli(c("verify", file.path(root, "nope")))$status, 2L)
  expect_identical(s10_cli(c("verify", root, "--psi-warn", "x"))$status, 2L)
})

test_that("a bad second argument is refused in the package's words", {
  expect_match(s5_msg(blfetch("https://example.invalid/x", tempfile(),
                              tmout = sum)), "`tmout` must be")
  r <- s5_msg(qltyrcd("E", suppr = rawToChar(as.raw(c(0x61, 0xff)))))
  # the byte ff is a letter in a Latin-1 locale, and the flag is text there
  if (isTRUE(l10n_info()[["Latin-1"]])) {
    expect_identical(r, "E")
  } else {
    expect_match(r, "^qltyrcd: `suppr` must be")
  }
  expect_match(s5_msg(rcdmnf("x", "x", map = -Inf)), "^rcdmnf: `map` must")
})

# the settings a session may carry; none may change what the package does
s11_settings <- list(
  scipen_neg = list(opt = list(scipen = -100)),
  scipen_pos = list(opt = list(scipen = 100)),
  outdec = list(opt = list(OutDec = ",")),
  warn2 = list(opt = list(warn = 2, warnPartialMatchArgs = TRUE,
                          warnPartialMatchAttr = TRUE,
                          warnPartialMatchDollar = TRUE)),
  saf = list(opt = list(stringsAsFactors = TRUE)),
  tz = list(tz = "Pacific/Kiritimati")
)

# runs `f` under one setting (R takes a scipen of -100 as -9, and says so;
# stringsAsFactors = TRUE is deprecated, and says so)
s11_under <- function(s, f) {
  if (!is.null(s$tz)) {
    withr::local_timezone(s$tz)
  }
  old <- suppressWarnings(options(s$opt))
  withr::defer(options(old))
  f()
}

# a capsule whose files are written byte for byte; `pin` pins its
# provenance by hand, at a fixed time, so a seal changes no byte of it
s11_fixed <- function(root, pin) {
  unlink(root, recursive = TRUE)
  d <- file.path(root, "c1")
  dir.create(d, recursive = TRUE)
  f <- file.path(d, "data.csv")
  writeLines(c("x,y", "1.5,1", "5.5,2", "12345.25,3"), f)
  writeLines(paste0(
    '{"resource": {"filename": "data.csv", "row_count_data_rows": 3',
    if (pin) {
      sprintf(paste0(', "sha256": "%s", "size_bytes": %d, ',
                     '"retrieved_utc": "2026-11-01T00:00:00Z"'),
              sha256file(f), file.size(f))
    },
    "}}"
  ), file.path(d, "data_provenance.json"))
  d
}

# one pass of the capsule verbs, the root and the times of signing taken out
s11_pass <- function(root) {
  d <- s11_fixed(root, FALSE)
  m <- mkmnf(list(n = 12345.5, p = 1e-7), env = FALSE)
  b <- cpsbndl(d, m, "k", path = file.path(root, "b.json"))
  v <- cpsbndlvrf(attr(b, "path"), d, man = m, key = "k")
  unlink(attr(b, "path"))
  s <- cpsseal(root, "k")
  pinned <- readLines(file.path(d, "data_provenance.json"))
  d <- s11_fixed(root, TRUE)
  cpsseal(root, "k")
  x <- cpschk(root, key = "k", fp = FALSE)
  # the signature and the manifest the seal makes record the time
  sig <- x$rows$detail[x$rows$check %in% c("attestation:signature",
                                           "attestation:manifest_digest")]
  sig <- sig[nzchar(sig)]
  out <- list(b$files, b$manifest_digest, v$ok, v$checks$check, s, pinned,
              x$rows, format(x), format(x, fmt = "json"),
              format(x, fmt = "text"),
              s10_cli(c("verify", root, "--no-footprint")),
              s10_cli(c("verify", root, "--json", "--no-footprint")),
              .bl_run_value(file.path(d, "data.csv")))
  rapply(out, function(t) {
    for (g in sig) {
      t <- gsub(g, "<sig>", t, fixed = TRUE)
    }
    gsub("[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z", "<utc>",
         gsub(root, "<root>", t, fixed = TRUE))
  }, classes = "character", how = "replace")
}

test_that("no session setting changes what the capsule verbs do", {
  skip_on_cran()
  withr::local_options(morie.progress = FALSE)
  root <- file.path(withr::local_tempdir(), "t")
  want <- s11_pass(root)
  for (nm in names(s11_settings)) {
    got <- s11_under(s11_settings[[nm]], function() s11_pass(root))
    expect_identical(got, want, label = nm)
  }
})

test_that("the arms of round 11 that no other test takes", {
  # a bracket that ends the pattern, and one that is a letter of its class
  expect_identical(.rmbl_ci("a["), "[aA][")
  expect_identical(.rmbl_ci("[a[b]"), "[aA[bB]")
  expect_true(grepl(.rmbl_ci("[a[b]"), "B", perl = TRUE))
  # a Hangul syllable with a final consonant, and one without
  k <- .rmbl_caseless(c("\uac01", "\uac00"))
  expect_identical(nchar(k, "chars"), c(3L, 2L))
  # a warning other than the missing final newline is a reason, not noise
  expect_error(.vc_quiet(function() warning("boom")), "boom")
  expect_identical(.vc_quiet(function() {
    warning("incomplete final line found")
    1L
  }), 1L)
  # a gzip CSV is read whole through its inflated copy, which is removed
  d <- withr::local_tempdir()
  gz <- file.path(d, "b.csv.gz")
  con <- gzfile(gz, "w")
  writeLines(c("x", "1", "2"), con)
  close(con)
  before <- list.files(tempdir())
  expect_identical(.vc_csv_whole(gz)$x, 1:2)
  expect_identical(list.files(tempdir()), before)
  # a table that could not be read whole fails the schema check, with the reason
  acc <- new.env()
  .vc_frame_checks(acc, list(n = 3L, df = "no memory"),
                   list(schema = list(a = 1)))
  got <- do.call(rbind, acc$checks)
  expect_identical(got$check, "schema_valid")
  expect_false(got$ok)
  expect_match(got$detail,
               "could not be read whole for the schema check: no memory")
})

test_that("a file named through a link that leaves the folder is refused", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  out <- withr::local_tempdir()
  writeLines("x", file.path(out, "f.txt"))
  skip_if_not(file.symlink(out, file.path(d, "lk")))
  expect_error(.bl_bnd_select(d, "lk/f.txt", file.path(d, "bundle.json")),
               "through a link that leaves the capsule folder.*lk/f.txt")
})

test_that("a count in a dashboard box and a title given to a fit plot", {
  skip_if_not_installed("bslib")
  skip_if_not_installed("shiny")
  ui <- .bl_vbox_ui(list(n = 12345, est = 1, lo = 0, up = 2, conf = 0.95))
  expect_match(paste(as.character(ui), collapse = ""), "12,345", fixed = TRUE)
  none <- .bl_vbox_ui(list(est = 1))
  expect_match(paste(as.character(none), collapse = ""), "Not reported",
               fixed = TRUE)
})

test_that("what the review of round 11 found is as it was before it", {
  # a quote left open at the end of a table is read.csv()'s to warn of
  expect_identical(.vc_quiet(function() {
    warning("EOF within quoted string")
    2L
  }), 2L)
  # the user's own pattern: accented letters in either case, and the
  # constructs of a regular expression
  # a manifest of its own: the test asks no network for one
  man <- list(datasets = list(
    list(key = "statcan_indigenous/a", rows = 1,
         meta = list(description = "First Nations, M\u00e9tis and Inuit")),
    list(key = "census2021_ipp/b", rows = 1,
         meta = list(description = "Population profile"))
  ))
  local_mocked_bindings(dmnf = function(refresh = FALSE) man)
  n <- nrow(indtabs("M\u00e9tis"))
  expect_identical(n, 1L)
  expect_identical(nrow(indtabs("M\u00c9TIS")), n)
  expect_silent(indtabs("M\u00e9tis"))
  expect_identical(s10_cli(c("functions", "(?i)capsule"))$status, 0L)
  # two spellings of one label that differ by an accented capital
  h <- audcats(data.frame(g = c("M\u00e9tis", "M\u00c9TIS", "Inuit"),
                          stringsAsFactors = FALSE))$hazards
  expect_match(paste(h, collapse = " "), "M\u00c9TIS", fixed = TRUE)
})

test_that("a clash of names is told with its capsule, and found in one pass", {
  d <- withr::local_tempdir()
  expect_error(.bl_bnd_names(c("A.txt", "a.txt"), dir = d),
               paste0(basename(d), ": names that differ only by case"))
  expect_error(.bl_bnd_names(c("A.txt", "a.txt")),
               "names that differ only by case")
  # many names at once give what one name at a time gives, marks that open
  # or close a name included
  u <- function(...) intToUtf8(c(...))
  x <- c(u(0x301, 0x41), u(0x41, 0x327, 0x301), u(0xc9), u(0x65, 0x301),
         u(0xac01), u(0x130), "plain.TXT", u(0x327, 0x301))
  one <- vapply(x, .rmbl_caseless, "", USE.NAMES = FALSE)
  expect_identical(.rmbl_caseless(x), one)
  expect_identical(.rmbl_caseless(rev(x)), rev(one))
  expect_identical(one[[3L]], one[[4L]])
  nfd <- function(u) .rmbl_nfdv(u, .rmbl_uc_tab())$u
  expect_identical(nfd(c(0x41L, 0x327L, 0x301L)),
                   nfd(c(0x41L, 0x301L, 0x327L)))
})

test_that("a pattern and a label fold accented letters outside UTF-8 too", {
  u <- function(...) intToUtf8(c(...))
  lo <- paste0("M", u(0xe9), "tis")
  up <- paste0("M", u(0xc9), "TIS")
  x <- c(paste(up, "people"), lo, "metis", NA)
  want <- c(TRUE, TRUE, FALSE, FALSE)
  expect_identical(.rmbl_grepl_ci(lo, x, utf8 = FALSE), want)
  # text typed where the session is not UTF-8 carries no mark
  raw <- lo
  Encoding(raw) <- "unknown"
  expect_identical(.rmbl_grepl_ci(raw, x, utf8 = FALSE), want)
  # the constructs of a regular expression still work, and plain ASCII
  # goes the way it always went
  expect_identical(.rmbl_grepl_ci(paste0("^m", u(0xc9), "t(is|ex)$"), x,
                                  utf8 = FALSE),
                   c(FALSE, TRUE, FALSE, FALSE))
  expect_identical(.rmbl_grepl_ci("^META", c("metadata", "x"), utf8 = FALSE),
                   c(TRUE, FALSE))
  expect_identical(.rmbl_grepl_ci("^META", c("metadata", "x"), utf8 = TRUE),
                   c(TRUE, FALSE))
  # labels: valid UTF-8 by Unicode, anything else by its letters A to Z
  bad <- rawToChar(as.raw(c(0x41, 0xff)))
  f <- .rmbl_fold(c(lo, up, NA, "ABC", bad))
  expect_identical(f[[1L]], f[[2L]])
  expect_identical(f[[3L]], NA_character_)
  expect_identical(f[[4L]], "abc")
  expect_identical(f[[5L]], rawToChar(as.raw(c(0x61, 0xff))))
})
