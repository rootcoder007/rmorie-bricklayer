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
  expect_false(isTRUE(row$ok) || isTRUE(row$pass))
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
  bad <- file.path(d, "caf\xe9.txt")
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
  for (f in list(fipskg, fipssz)) {
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
