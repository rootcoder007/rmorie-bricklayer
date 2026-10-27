# mkbndl() and mkbndlproj(): reproducibility bundles

ns <- asNamespace("rmoriebricklayer")

# a starter project in a fresh folder
bndl_proj <- function(...) {
  d <- file.path(withr::local_tempdir(.local_envir = parent.frame()), "demo")
  mkbndlproj(d, ...)
}

# Unix mode of each entry, read from the zip's central directory
zip_modes <- function(zip) {
  b <- readBin(zip, "raw", file.size(zip))
  sig <- as.raw(c(0x50, 0x4b, 0x01, 0x02))
  at <- which(b == sig[1L])
  at <- at[at + 3L <= length(b)]
  hit <- at[vapply(at, function(i) identical(b[i:(i + 3L)], sig), NA)]
  u <- function(i, n) {
    sum(as.integer(b[i:(i + n - 1L)]) * 256^(seq_len(n) - 1L))
  }
  out <- vapply(hit, function(i) u(i + 38L, 4L) %/% 65536, 0)
  names(out) <- vapply(hit, function(i) {
    rawToChar(b[(i + 46L):(i + 45L + u(i + 28L, 2L))])
  }, "")
  out
}

test_that("mkbndlproj writes a starter project and prints it", {
  p <- bndl_proj(title = "A \"quoted\" title\twith\\ tab", author = "Me")
  expect_s3_class(p, "rmbl_bundle_project")
  expect_identical(p$files, c("config.json", "data_provenance.json",
                              "analysis.R"))
  expect_true(all(file.exists(file.path(p$dir, p$files))))
  cfg <- fromjs(file.path(p$dir, "config.json"), simplifyVector = FALSE)
  expect_identical(cfg$project$title, "A \"quoted\" title\twith\\ tab")
  expect_identical(cfg$project$name, "demo")
  ex <- parse(file.path(p$dir, "analysis.R"))
  expect_gt(length(ex), 5L)
  expect_box2(p, "Bundle project", c("config.json", "mkbndl()"))
})

test_that("mkbndlproj refuses bad input and keeps files", {
  d <- withr::local_tempdir()
  expect_error(mkbndlproj(d, name = "a b"), "letters, digits")
  expect_error(mkbndlproj(d, author = 1), "`author` must be a single")
  mkbndlproj(d, name = "x")
  expect_error(mkbndlproj(d, name = "x"), "overwrite = TRUE")
  expect_s3_class(mkbndlproj(d, name = "x", overwrite = TRUE),
                  "rmbl_bundle_project")
})

test_that("mkbndl packs a project into a zip R can read back", {
  p <- bndl_proj(title = "Demo")
  dir.create(file.path(p$dir, "extra"))
  writeLines("a,b", file.path(p$dir, "extra", "note.csv"))
  dir.create(file.path(p$dir, "results_1"))
  writeLines("old", file.path(p$dir, "results_1", "old.txt"))
  writeLines("zip", file.path(p$dir, "old.zip"))
  dest <- withr::local_tempdir()
  b <- mkbndl(p$dir, dest)
  expect_s3_class(b, "rmbl_bundle")
  expect_identical(basename(b$path), "demo_v1.zip")
  expect_match(b$sha256, "^[0-9a-f]{64}$")
  expect_identical(b$sha256, sha256file(b$path))
  expect_false(b$data)
  inside <- sub("^demo_v1/", "", b$files)
  expect_true(all(c("setup_and_run.R", "lib_interactive.R",
                    "START_HERE.command", "START_HERE.bat",
                    "start_here.sh", "README.md", "SECURITY.md",
                    "INSTRUCTIONS.txt", "analysis.R", "config.json",
                    "extra/note.csv", "lib_manifest.R",
                    "box_readings.R") %in% inside))
  expect_false(any(grepl("results_1|old[.]zip|DATA_NOTICE", inside)))
  # R's own unzip reads it, and every file comes back byte for byte
  out <- withr::local_tempdir()
  utils::unzip(b$path, exdir = out)
  st <- file.path(out, "demo_v1")
  expect_identical(
    unname(tools::md5sum(file.path(st, "analysis.R"))),
    unname(tools::md5sum(file.path(p$dir, "analysis.R")))
  )
  lib <- system.file("bundle", "lib", "lib_manifest.R",
                     package = "rmoriebricklayer")
  if (nzchar(lib)) {
    expect_identical(
      unname(tools::md5sum(file.path(st, "lib_manifest.R"))),
      unname(tools::md5sum(lib))
    )
  }
  # launchers keep their executable bit; data files do not get one
  m <- zip_modes(b$path)
  expect_identical(m[["demo_v1/start_here.sh"]] %% 512, 493)
  expect_identical(m[["demo_v1/START_HERE.command"]] %% 512, 493)
  expect_identical(m[["demo_v1/config.json"]] %% 512, 420)
  expect_identical(m[["demo_v1/"]] %/% 4096, 4)
  # the pages are filled in, with the package's own version
  rd <- readLines(file.path(st, "README.md"), encoding = "UTF-8")
  expect_true(any(grepl(
    as.character(utils::packageVersion("rmoriebricklayer")), rd,
    fixed = TRUE
  )))
  expect_false(any(grepl("{{", rd, fixed = TRUE)))
  expect_true(any(grepl("observed and expected", rd, fixed = TRUE)))
  sec <- readLines(file.path(st, "SECURITY.md"), encoding = "UTF-8")
  expect_true(any(grepl("none: the scripts make no network", sec,
                        fixed = TRUE)))
  expect_box2(b, "Reproducibility bundle",
              c("demo_v1.zip", "not inside", b$sha256))
})

test_that("mkbndl carries the data file and refuses to overwrite", {
  p <- bndl_proj()
  csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(
    data.frame(group = "a", value = 1, stringsAsFactors = FALSE),
    csv,
    row.names = FALSE
  )
  dest <- withr::local_tempdir()
  b <- mkbndl(p$dir, dest, data = csv, version = "2.a-b_c")
  expect_identical(basename(b$path), "demo_v2.a-b_c_with_data.zip")
  expect_true(b$data)
  expect_true(all(c("demo_v2.a-b_c_with_data/data.csv",
                    "demo_v2.a-b_c_with_data/DATA_NOTICE.md") %in% b$files))
  expect_box2(b, "Reproducibility bundle", "inside")
  expect_error(mkbndl(p$dir, dest, data = csv, version = "2.a-b_c"),
               "overwrite = TRUE")
  b2 <- mkbndl(p$dir, dest, data = csv, version = "2.a-b_c",
               overwrite = TRUE)
  expect_identical(b2$path, b$path)
})

test_that("mkbndl builds the shipped OTIS example with its own details", {
  dest <- withr::local_tempdir()
  b <- mkbndl("otis-mrp", dest)
  expect_identical(b$project, "otis-mrp")
  inside <- sub("^otis-mrp_v1/", "", b$files)
  expect_true(all(c("otis_yoy_verify.R", "custody.R", "region_map.R",
                    "print_boxes.R") %in% inside))
  out <- withr::local_tempdir()
  utils::unzip(b$path, exdir = out)
  rd <- readLines(file.path(out, "otis-mrp_v1", "README.md"),
                  encoding = "UTF-8")
  expect_true(any(grepl("of 55 PASS", rd, fixed = TRUE)))
  expect_true(any(grepl("**Supervisor:**", rd, fixed = TRUE)))
  dn <- file.path(out, "otis-mrp_v1", "SECURITY.md")
  expect_true(any(grepl("web.archive.org", readLines(dn))))
})

test_that("mkbndl refuses bad projects and arguments", {
  dest <- withr::local_tempdir()
  expect_error(mkbndl("no-such-example", dest), "otis-mrp")
  expect_error(mkbndl("a/b", dest), "neither a folder")
  empty <- withr::local_tempdir()
  expect_error(mkbndl(empty, dest), "no config.json")
  p <- bndl_proj()
  expect_error(mkbndl(p$dir, file.path(dest, "nope")), "existing folder")
  expect_error(mkbndl(p$dir, dest, version = "1 2"), "letters, digits")
  expect_error(mkbndl(p$dir, dest, data = file.path(dest, "x.csv")),
               "no such file")
  writeLines("# mine", file.path(p$dir, "README.md"))
  expect_error(mkbndl(p$dir, dest), "README.md")
  unlink(file.path(p$dir, c("README.md", "analysis.R")))
  expect_error(mkbndl(p$dir, dest), "analysis script analysis.R")
})

test_that("mkbndl refuses a bundle whose files call what it lacks", {
  p <- bndl_proj()
  cat(".rmbl_not_a_function_anywhere()\n",
      file = file.path(p$dir, "analysis.R"), append = TRUE)
  expect_error(mkbndl(p$dir, withr::local_tempdir()),
               "called but not in the bundle: .rmbl_not_a_function")
})

test_that("the scan checks what the runner sources itself", {
  d <- withr::local_tempdir()
  writeLines("for (lib in c('a.R')) source(lib)",
             file.path(d, "setup_and_run.R"))
  writeLines(c("f <- function() .rmbl_from_b()",
               "g <- function() if (exists(\".rmbl_maybe\")) .rmbl_maybe()",
               "# bundle-scan-guarded: .rmbl_quiet",
               "h <- function() .rmbl_quiet()"),
             file.path(d, "a.R"))
  writeLines(".rmbl_from_b <- function() 1", file.path(d, "b.R"))
  expect_identical(
    ns$.bndl_scan(d),
    "called but not sourced by the runner: .rmbl_from_b"
  )
  unlink(file.path(d, "setup_and_run.R"))
  expect_null(ns$.bndl_scan(d))
  writeLines("x <- 1", file.path(d, "setup_and_run.R"))
  expect_identical(ns$.bndl_runner_libs(file.path(d, "setup_and_run.R")),
                   character())
})

test_that("the bundle library is found installed or in a source tree", {
  r <- withr::local_tempdir()
  root <- file.path(r, "inst", "bundle")
  dir.create(file.path(root, "lib"), recursive = TRUE)
  expect_error(ns$.bndl_lib_dir(root), "reinstall")
  dir.create(file.path(r, "R"))
  writeLines("x", file.path(r, "R", "mkbndl.R"))
  expect_identical(ns$.bndl_lib_dir(root),
                   normalizePath(file.path(r, "R"), winslash = "/"))
  writeLines("x", file.path(root, "lib", "a.R"))
  expect_identical(ns$.bndl_lib_dir(root), file.path(root, "lib"))
  writeLines(c("# c", "", "a.R", " b.R "), file.path(root, "lib.txt"))
  expect_identical(ns$.bndl_lib_files(root), c("a.R", "b.R"))
})

test_that("config values, pages and sizes", {
  expect_identical(ns$.bndl_read(tempfile()), list())
  f <- withr::local_tempfile(fileext = ".json")
  writeLines("\"text\"", f)
  expect_identical(ns$.bndl_read(f), list())
  x <- list(a = list(b = list("v"), c = list("x", "y"), d = ""))
  expect_identical(ns$.bndl_get(x, c("a", "b")), "v")
  expect_identical(ns$.bndl_get(x, c("a", "c"), "def"), "def")
  expect_identical(ns$.bndl_get(x, c("a", "d"), "def"), "def")
  expect_identical(ns$.bndl_get(x, c("a", "b", "z"), "def"), "def")
  cfg <- list(project = list(title = "T"), r_packages = list("a", "b"),
              network = list(endpoints = list("https://x.org/")))
  prov <- list(dataset = list(licence_name = "OGL"),
               resource = list(direct_url = "https://x.org/f.csv"))
  s <- ns$.bndl_subs(cfg, prov, "z.zip")
  expect_null(s$supervisor_line)
  expect_identical(s$packages_line, ", and the R packages `a`, `b`")
  expect_identical(s$licence_attribution,
                   "Contains information licensed under the OGL.")
  expect_identical(s$paper_title, "T")
  expect_identical(s$network_endpoints_table,
                   "- https://x.org/\n- https://x.org/f.csv")
  s2 <- ns$.bndl_subs(list(), list(dataset = list(attribution = "Mine")),
                      "z.zip")
  expect_identical(s2$licence_attribution, "Mine")
  expect_null(s2$packages_line)
  expect_identical(ns$.bndl_subs(list(), list(), "z")$licence_attribution,
                   "See the licence of the source.")
  expect_identical(ns$.bndl_fill("a{{k}}b{{n}}", list(k = 1, n = NULL)),
                   "a1b")
  expect_identical(ns$.bndl_size(10), "10 bytes")
  expect_identical(ns$.bndl_size(2048), "2.0 KB")
  expect_identical(ns$.bndl_size(3 * 1024^2), "3.0 MB")
})

test_that("the zip writer stores, deflates and keeps to its limit", {
  base <- withr::local_tempdir()
  top <- file.path(base, "t")
  dir.create(file.path(top, "sub"), recursive = TRUE)
  file.create(file.path(top, "empty.txt"))
  writeBin(as.raw(c(0x8d, 0x13, 0xf1, 0x5a, 0x07)),
           file.path(top, "noise.bin"))
  writeLines(strrep("abc", 400), file.path(top, "sub", "long.txt"))
  zip <- file.path(base, "t.zip")
  got <- ns$.bndl_zip(base, "t", zip)
  expect_identical(got, c("t/", "t/empty.txt", "t/noise.bin", "t/sub/",
                          "t/sub/long.txt"))
  out <- withr::local_tempdir()
  utils::unzip(zip, exdir = out)
  for (f in c("empty.txt", "noise.bin", "sub/long.txt")) {
    expect_identical(
      unname(tools::md5sum(file.path(out, "t", f))),
      unname(tools::md5sum(file.path(top, f)))
    )
  }
  expect_error(ns$.bndl_zip(base, "t", zip, limit = 10), "larger than")
  expect_identical(ns$.bndl_dos_time(as.POSIXct("1970-01-01 00:00:00")),
                   c(0, 33))
  expect_identical(ns$.bndl_u16(65535), as.raw(c(0xff, 0xff)))
  expect_identical(ns$.bndl_u32(4294967295), as.raw(rep(0xff, 4)))
})

test_that("an unzipped bundle runs on synthetic and on real data", {
  skip_on_cran()
  withr::local_envvar(R_TESTS = NA, BRICKLAYER_SYNTHETIC = NA)
  p <- bndl_proj()
  csv <- file.path(withr::local_tempdir(), "real.csv")
  utils::write.csv(
    data.frame(
      group = rep(c("a", "b"), 50), value = rep(c(4, 6), 50),
      stringsAsFactors = FALSE
    ),
    csv, row.names = FALSE
  )
  b <- mkbndl(p$dir, withr::local_tempdir(), data = csv)
  out <- withr::local_tempdir()
  utils::unzip(b$path, exdir = out)
  st <- file.path(out, sub("[.]zip$", "", basename(b$path)))
  rs <- file.path(R.home("bin"), "Rscript")
  run <- function(...) {
    r <- system2(rs, c(shQuote(file.path(st, "setup_and_run.R")), ...),
                 stdout = TRUE, stderr = TRUE)
    m <- Sys.glob(file.path(st, "results_*", "manifest.json"))
    s <- fromjs(m[length(m)], simplifyVector = FALSE)
    unlink(dirname(m), recursive = TRUE)
    unname(vapply(s$results, function(x) x$status, ""))
  }
  expect_identical(run("--quick"), c("PASS", "PASS"))
  expect_identical(run("--quick", "--synthetic"), c("INFO", "INFO"))
})
