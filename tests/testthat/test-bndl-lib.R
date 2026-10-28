# SPDX-License-Identifier: AGPL-3.0-or-later
# The package R files a bundle carries, sourced as the bundle's runner
# sources them: outside the namespace, without the compiled code.

# the bundle's library sourced into a fresh environment whose parent is
# base R, so nothing of the installed package is visible from it
bndl_lib <- function() {
  root <- system.file("bundle", package = "rmoriebricklayer")
  lib <- file.path(root, "lib")
  skip_if(!length(list.files(lib, "[.]R$")), "no bundle/lib installed")
  e <- new.env(parent = baseenv())
  for (f in .bndl_lib_files(root)) {
    sys.source(file.path(lib, f), envir = e, keep.source = FALSE)
  }
  e
}

test_that("a refusal inside a bundle is an error in words", {
  e <- bndl_lib()
  expect_false(exists("csha256", envir = e, mode = "function"))
  expect_identical(e$.rmbl_fn(), "")
  for (bad in c('{"a": 1, "a": 2}', '{"a": ', "[1, 2")) {
    err <- tryCatch(e$fromjs(bad), error = function(x) conditionMessage(x))
    expect_type(err, "character")
    expect_false(grepl("namespace", err, fixed = TRUE))
    expect_true(nzchar(err))
  }
  # the package itself still names the function that refused
  expect_error(fromjs('{"a": '), "fromjs")
})

test_that("the bundle's transports all go through the bundle fetcher", {
  e <- bndl_lib()
  e$.rmbl_bfetch <- function(url, dest, ...) stop("bundle fetcher: ", url)
  dest <- withr::local_tempfile()
  expect_error(e$.bl_fetch_file("https://example.org/d.csv", dest),
               "bundle fetcher: https://example.org/d.csv")
  expect_error(e$.rmbl_fetch_url("https://example.org/m.json", dest),
               "bundle fetcher: https://example.org/m.json")
  expect_error(e$fromjs("https://example.org/m.json"),
               "bundle fetcher: https://example.org/m.json")
  # file:// only when asked for, and a missing file is an error
  src <- withr::local_tempfile(lines = "a,b")
  expect_error(e$.bl_fetch_file(paste0("file://", src), dest),
               "https:// URL")
  e$.bl_fetch_file(paste0("file://", src), dest, allow_file = TRUE)
  expect_identical(readLines(dest), "a,b")
  expect_error(e$.bl_fetch_file(paste0("file://", src, "-no"), dest,
                                allow_file = TRUE), "cannot open")
})

test_that("a bundle hashes a file in chunks, never whole", {
  e <- bndl_lib()
  # the in-memory digest is the pure-R one
  expect_identical(
    e$.rmbl_sha256_hex(charToRaw("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
  e$.rmbl_sha256_raw <- function(...) stop("read the whole file")
  d <- withr::local_tempdir()
  for (n in c(0L, 1L, 55L, 56L, 63L, 64L, 65L, 1000L, 20001L)) {
    f <- file.path(d, sprintf("f%d", n))
    writeBin(as.raw(seq_len(n) %% 256L), f)
    want <- sha256file(f)
    expect_identical(e$.rmbl_sha256_file(f, chunk = 100L), want)
    expect_identical(e$.rmbl_sha256_file(f, chunk = 64L), want)
    expect_identical(e$.rmbl_sha256_bndl(f, base = FALSE), want)
    expect_identical(e$sha256file(f), want)
  }
  if (exists("sha256sum", envir = asNamespace("tools"))) {
    expect_identical(e$.rmbl_sha256_bndl(f, base = TRUE), sha256file(f))
  }
})

test_that("a bundle without the package's downloader does not download", {
  e <- bndl_lib()
  dest <- withr::local_tempfile()
  # the URL policy first, then no downloader: refused, nothing fetched
  expect_error(e$.rmbl_bfetch("http://10.0.0.7/x", dest,
                              dl = function(...) stop("downloaded")),
               "https:// URL")
  expect_error(e$.rmbl_bfetch("https://example.org/x", dest, dl = NULL),
               "install.packages\\(\"rmoriebricklayer\"\\)")
  expect_error(e$.rmbl_bfetch("https://example.org/x", dest, dl = NULL),
               "data/ folder")
  expect_false(file.exists(dest) && file.size(dest) > 0)
  # a package that is missing, or older than 1.0.3, is no downloader
  expect_null(e$.rmbl_bdl("no.such.package.here"))
  if (requireNamespace("digest", quietly = TRUE) &&
        utils::packageVersion("digest") < "1.0.3") {
    expect_null(e$.rmbl_bdl("digest"))
  }
  # an installed rmoriebricklayer 1.0.3 or later lends its bldl()
  expect_identical(e$.rmbl_bdl(),
                   getExportedValue("rmoriebricklayer", "bldl"))
  got <- new.env()
  e$.rmbl_bfetch("https://example.org/x", dest, cap = 7,
                 dl = function(url, dest, ...) {
                   got$a <- list(url = url, ...)
                   writeLines("ok", dest)
                 })
  expect_identical(got$a$url, "https://example.org/x")
  expect_identical(got$a$maxbytes, 7)
  expect_true(got$a$quiet)
  expect_identical(readLines(dest), "ok")
})

test_that("in the namespace the fetcher is bldl(), and fails closed", {
  expect_identical(.rmbl_bdl(), bldl)
  expect_null(.rmbl_bdl("no.such.package.here", own = FALSE))
  expect_identical(.rmbl_bdl(own = FALSE),
                   getExportedValue("rmoriebricklayer", "bldl"))
  expect_match(.rmbl_nodl(), "1.0.3 or later", fixed = TRUE)
  dest <- withr::local_tempfile()
  expect_error(.rmbl_bfetch("https://example.org/x", dest, dl = NULL),
               "downloads only through the rmoriebricklayer package")
  expect_error(.rmbl_bfetch("https://127.0.0.1/x", dest, dl = NULL),
               "local or private")
  got <- new.env()
  expect_invisible(.rmbl_bfetch("https://example.org/y", dest,
                                dl = function(url, dest, ...) {
                                  got$m <- list(...)$maxbytes
                                }))
  expect_identical(got$m, 2147483648)
})

## The same helpers called in the package's namespace, with the network
## and the platform mocked.

test_that(".rmbl_fn() outside a namespace, and its name helpers", {
  e <- new.env(parent = baseenv())
  f <- .rmbl_fn
  environment(f) <- e
  e$.rmbl_fn <- f
  expect_identical(f(), "")
  ns <- asNamespace("rmoriebricklayer")
  s3 <- getNamespaceInfo(ns, "S3methods")
  ex <- getNamespaceExports(ns)
  expect_identical(.rmbl_fnlab(NA_character_, s3, ex), "")
  expect_identical(.rmbl_fnlab(s3[1L, 3L], s3, ex), paste0(s3[1L, 1L], ": "))
  expect_identical(.rmbl_fnlab("fromjs", s3, ex), "fromjs: ")
  expect_identical(.rmbl_fnlab(".rmbl_fn", s3, ex), "")
  expect_identical(
    .rmbl_fnname(quote(rmoriebricklayer::fromjs), fromjs, ns, ex), "fromjs"
  )
  expect_identical(.rmbl_fnname(fromjs, fromjs, ns, ex), "fromjs")
  expect_error(do.call(fromjs, list('{"a": ')), "fromjs: ")
})

test_that("without the compiled code the namespace uses the bundle paths", {
  f <- withr::local_tempfile()
  writeBin(as.raw(0:200), f)
  want <- sha256file(f)
  expect_identical(.rmbl_sha256_file(f, chunk = 7L), want)
  expect_identical(.rmbl_sha256_bndl(f, base = FALSE), want)
  if (exists("sha256sum", envir = asNamespace("tools"))) {
    expect_identical(.rmbl_sha256_bndl(f, base = TRUE), want)
  }
  dest <- withr::local_tempfile()
  local_mocked_bindings(
    .rmbl_bfetch = function(url, dest, ...) {
      writeLines('{"k": 1}', dest)
      invisible(dest)
    }
  )
  local_mocked_bindings(exists = function(x, ...) FALSE, .package = "base")
  expect_identical(sha256file(f), want)
  expect_identical(fromjs("https://example.org/m.json")$k, 1L)
  .bl_fetch_file(paste0("file://", f), dest, allow_file = TRUE)
  expect_identical(unname(tools::md5sum(dest)), unname(tools::md5sum(f)))
  expect_error(.bl_fetch_file(paste0("file://", f, "-no"), dest,
                              allow_file = TRUE), "cannot open the file")
})
