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

test_that("rmbl pack starts a project and builds its bundle", {
  d <- withr::local_tempdir()
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  p <- file.path(d, "proj")
  r <- run("pack", "--new", p, "--title", "Shell study", "--author", "Me",
           "--contact", "me@example.org")
  expect_identical(r$status, 0L)
  expect_match(r$text, "Bundle project", fixed = TRUE)
  cfg <- fromjs(file.path(p, "config.json"), simplifyVector = FALSE)
  expect_identical(cfg$project$title, "Shell study")
  expect_identical(run("pack", "--new", file.path(d, "p2"))$status, 0L)
  r <- run("pack", p, "--dest", d, "--version", "3")
  expect_identical(r$status, 0L)
  expect_match(r$text, "proj_v3.zip", fixed = TRUE)
  expect_true(file.exists(file.path(d, "proj_v3.zip")))
  r <- run("pack", p, "--dest", d, "--version", "3")
  expect_identical(r$status, 1L)
  expect_match(r$text, "overwrite", fixed = TRUE)
  expect_identical(
    run("pack", p, "--dest", d, "--version", "3", "--overwrite")$status, 0L
  )
  csv <- file.path(d, "x.csv")
  writeLines(c("group,value", "a,1"), csv)
  expect_identical(run("pack", p, "--dest", d, "--data", csv)$status, 0L)
  expect_true(file.exists(file.path(d, "proj_v1_with_data.zip")))
  withr::with_dir(d, expect_identical(run("pack", p)$status, 0L))
  expect_true(file.exists(file.path(d, "proj_v1.zip")))
  r <- run("pack")
  expect_identical(r$status, 2L)
  expect_match(r$text, "pack DIR", fixed = TRUE)
  expect_identical(run("pack", "help")$status, 0L)
  expect_identical(run("pack", "--help")$status, 0L)
  expect_identical(run("pack", p, "--bogus")$status, 2L)
})

# the project's config.json with project$name set to `name`
set_name <- function(p, name) {
  f <- file.path(p$dir, "config.json")
  cfg <- fromjs(f, simplifyVector = FALSE)
  cfg$project$name <- name
  writeLines(tojs(cfg, auto_unbox = TRUE), f)
}

test_that("project$name is a plain name, never a path", {
  p <- bndl_proj()
  top <- withr::local_tempdir()
  dest <- file.path(top, "a", "b")
  dir.create(dest, recursive = TRUE)
  for (bad in c("../../ESC_NAME", "a/b", "..", ".hidden", "a..b",
                strrep("n", 65L), "a\\b", "x y")) {
    set_name(p, bad)
    expect_error(mkbndl(p$dir, dest), "project\\$name in config.json")
  }
  expect_length(list.files(top, recursive = TRUE, all.files = TRUE), 0L)
  expect_length(list.files(tempdir(), "^ESC_NAME"), 0L)
  set_name(p, "fine.name-1_x")
  expect_identical(basename(mkbndl(p$dir, dest)$path),
                   "fine.name-1_x_v1.zip")
  # without a name in config.json the folder's name is made plain
  set_name(p, "")
  q <- file.path(withr::local_tempdir(), "my study (draft)")
  file.copy(p$dir, dirname(q), recursive = TRUE)
  file.rename(file.path(dirname(q), "demo"), q)
  expect_identical(basename(mkbndl(q, dest)$path), "my_study__draft__v1.zip")
  expect_error(mkbndl(p$dir, dest, version = "../1"), "`version` may hold")
  expect_error(mkbndlproj(withr::local_tempdir(), name = ".."),
               "`name` may hold")
})

test_that("mkbndl does not follow symbolic links out of the project", {
  skip_on_os("windows")
  p <- bndl_proj()
  out <- withr::local_tempdir()
  writeLines("outside secret", file.path(out, "secret.txt"))
  dir.create(file.path(out, "dir"))
  writeLines("x", file.path(out, "dir", "inner.txt"))
  file.symlink(file.path(out, "secret.txt"), file.path(p$dir, "file_out"))
  file.symlink(file.path(out, "dir"), file.path(p$dir, "dir_out"))
  file.symlink(p$dir, file.path(p$dir, "loop"))
  writeLines("a,b", file.path(p$dir, "real.csv"))
  file.symlink(file.path(p$dir, "real.csv"), file.path(p$dir, "link_in.csv"))
  expect_warning(
    b <- mkbndl(p$dir, withr::local_tempdir()),
    "symbolic links to a folder or out of the project: dir_out, file_out, loop"
  )
  inside <- sub("^demo_v1/", "", b$files)
  expect_true(all(c("real.csv", "link_in.csv") %in% inside))
  expect_false(any(grepl("file_out|dir_out|loop|inner|secret", inside)))
})

test_that("files that look like credentials are left out unless asked", {
  p <- bndl_proj()
  sec <- c("llm.json", "credentials.json", "id_rsa", "secrets.yaml",
           "api_key.txt", "token.txt", "client_secret_123.json", "key.pem",
           "store.p12", "openai_key.txt", "github_pat.txt", "access_token",
           "aws_credentials", "gcloud_adc.json", "my.env", "kube.config",
           "kubeconfig", "keys.R")
  for (f in sec) writeLines("fake", file.path(p$dir, f))
  writeLines(c("-----BEGIN PRIVATE KEY-----", "fake",
               "-----END PRIVATE KEY-----"), file.path(p$dir, "key.pem"))
  ok <- c("cert.pem", "id_rsa.pub", "tokens_per_doc.csv", "authors.txt",
          "keyboard.csv", "monkey.R", "patients.R", "environment.R",
          "credentials_policy.md", "keys_to_success.md", "token_notes.Rmd",
          "secret_sauce.html")
  writeLines(c("-----BEGIN CERTIFICATE-----", "fake"),
             file.path(p$dir, "cert.pem"))
  for (f in ok[-1L]) writeLines("x", file.path(p$dir, f))
  dest <- withr::local_tempdir()
  got <- new.env()
  got$w <- character()
  b <- withCallingHandlers(
    mkbndl(p$dir, dest),
    warning = function(cnd) {
      got$w <- c(got$w, conditionMessage(cnd))
      invokeRestart("muffleWarning")
    }
  )
  w <- got$w
  expect_length(w, 1L)
  expect_match(w, "look like credentials (pass secrets = TRUE", fixed = TRUE)
  for (f in sec) expect_match(w, f, fixed = TRUE)
  inside <- sub("^demo_v1/", "", b$files)
  expect_false(any(sec %in% inside))
  expect_true(all(ok %in% inside))
  expect_silent(b2 <- mkbndl(p$dir, dest, overwrite = TRUE, secrets = TRUE))
  expect_true(all(sec %in% sub("^demo_v1/", "", b2$files)))
  expect_error(mkbndl(p$dir, dest, overwrite = TRUE, secrets = NA),
               "secrets")
})

test_that("an interrupted build leaves no zip and keeps the old one", {
  p <- bndl_proj()
  dest <- withr::local_tempdir()
  old <- mkbndl(p$dir, dest)
  sha <- sha256file(old$path)
  local_mocked_bindings(.bndl_zip = function(base, top, zip, ...) {
    writeBin(as.raw(1:10), zip)
    stop("interrupted")
  })
  expect_error(mkbndl(p$dir, dest, overwrite = TRUE), "interrupted")
  expect_identical(sha256file(old$path), sha)
  expect_error(mkbndl(p$dir, dest, version = "2"), "interrupted")
  expect_identical(list.files(dest), "demo_v1.zip")
})

test_that("more entries than a plain zip counts are refused", {
  base <- withr::local_tempdir()
  dir.create(file.path(base, "t"))
  for (i in 1:3) file.create(file.path(base, "t", i))
  zip <- file.path(base, "t.zip")
  expect_error(ns$.bndl_zip(base, "t", zip, nmax = 3L),
               "4 files and folders, more than a plain zip holds \\(3\\)")
  expect_length(ns$.bndl_zip(base, "t", zip, nmax = 4L), 4L)
})

test_that("rmbl pack --secrets packs what looks like credentials", {
  p <- bndl_proj()
  writeLines("fake", file.path(p$dir, "llm.json"))
  d <- withr::local_tempdir()
  run <- function(...) {
    rec <- new.env()
    rec$buf <- character()
    st <- suppressWarnings(
      blcli(c(...), out = function(s) rec$buf <- c(rec$buf, s))
    )
    list(status = st, text = paste(rec$buf, collapse = ""))
  }
  expect_identical(run("pack", p$dir, "--dest", d)$status, 0L)
  expect_false("demo_v1/llm.json" %in% utils::unzip(
    file.path(d, "demo_v1.zip"), list = TRUE)$Name)
  r <- run("pack", p$dir, "--dest", d, "--overwrite", "--secrets")
  expect_identical(r$status, 0L)
  expect_true("demo_v1/llm.json" %in% utils::unzip(
    file.path(d, "demo_v1.zip"), list = TRUE)$Name)
  expect_match(.bl_verb_usage("pack", "rmbl"), "--secrets", fixed = TRUE)
})

test_that("the runner stops in words on a bad config.json or no manifest", {
  skip_on_cran()
  withr::local_envvar(R_TESTS = NA, BRICKLAYER_SYNTHETIC = NA)
  rs <- file.path(R.home("bin"), "Rscript")
  unpack <- function(p) {
    b <- mkbndl(p$dir, withr::local_tempdir(.local_envir = parent.frame()))
    out <- withr::local_tempdir(.local_envir = parent.frame())
    utils::unzip(b$path, exdir = out)
    file.path(out, sub("[.]zip$", "", basename(b$path)))
  }
  run <- function(st) {
    r <- suppressWarnings(system2(
      rs, c(shQuote(file.path(st, "setup_and_run.R")), "--quick",
            "--synthetic"),
      stdout = TRUE, stderr = TRUE
    ))
    list(status = attr(r, "status") %||% 0L, text = paste(r, collapse = "\n"))
  }
  st <- unpack(bndl_proj())
  for (cfg in c('{"project": {"name": "a", "name": "b"}}', '{"project": ')) {
    writeLines(cfg, file.path(st, "config.json"))
    r <- run(st)
    expect_identical(r$status, 2L)
    expect_match(r$text, "ERROR: config.json could not be read", fixed = TRUE)
    expect_false(grepl("namespace", r$text, fixed = TRUE))
  }
  # an analysis that writes no manifest: exit 8, not 0
  p <- bndl_proj()
  writeLines("cat('no manifest here\\n')", file.path(p$dir, "analysis.R"))
  st <- unpack(p)
  r <- run(st)
  expect_identical(r$status, 8L)
  expect_match(r$text, "NOT completed", fixed = TRUE)
})

test_that("a rename that fails, a bad name and an over-long path", {
  p <- bndl_proj()
  dest <- withr::local_tempdir()
  local_mocked_bindings(file.rename = function(from, to) FALSE,
                        .package = "base")
  expect_error(mkbndl(p$dir, dest), "could not write")
  expect_length(list.files(dest), 0L)
  expect_false(ns$.bndl_plain(NA_character_))
  expect_false(ns$.bndl_plain(c("a", "b")))
  f <- withr::local_tempfile(lines = "x")
  expect_error(ns$.bndl_zip_entry(f, strrep("a", 70000L), c(0, 33)),
               "too long for a zip")
})

test_that("the runner downloads only with the package; files are checked", {
  skip_on_cran()
  withr::local_envvar(R_TESTS = NA, BRICKLAYER_SYNTHETIC = NA)
  rs <- file.path(R.home("bin"), "Rscript")
  b <- mkbndl(bndl_proj()$dir, withr::local_tempdir())
  out <- withr::local_tempdir()
  utils::unzip(b$path, exdir = out)
  st <- file.path(out, sub("[.]zip$", "", basename(b$path)))
  run <- function(...) {
    r <- suppressWarnings(system2(
      rs, c(shQuote(file.path(st, "setup_and_run.R")), "--quick", ...),
      stdout = TRUE, stderr = TRUE
    ))
    list(status = attr(r, "status") %||% 0L, text = paste(r, collapse = "\n"))
  }
  # no data and no rmoriebricklayer to download with: refused, exit 5
  empty <- withr::local_tempdir()
  base <- normalizePath(.Library)
  skip_if(nzchar(system.file(package = "rmoriebricklayer", lib.loc = base)),
          "rmoriebricklayer is in R's own library")
  libs <- c(R_LIBS = empty, R_LIBS_USER = empty, R_LIBS_SITE = empty)
  # on some systems (Windows CI) the child still sees the package through
  # a site library; then it has a downloader, and the config has no
  # address: refused all the same, exit 5, never a raw R error
  seen <- withr::with_envvar(libs, suppressWarnings(system2(
    rs, c("-e", shQuote(paste0("cat(nzchar(system.file(package=",
                               "'rmoriebricklayer')))"))),
    stdout = TRUE, stderr = FALSE
  )))
  withr::with_envvar(libs, {
    r <- run()
  })
  expect_identical(r$status, 5L)
  if (identical(seen, "TRUE")) {
    expect_match(r$text, "no download URL available", fixed = TRUE)
  } else {
    expect_match(r$text,
                 "downloads only through the rmoriebricklayer package",
                 fixed = TRUE)
  }
  expect_no_match(r$text, "must be a single non-empty string", fixed = TRUE)
  # with the package (this session's libraries) and still no address
  r <- run()
  expect_identical(r$status, 5L)
  expect_match(r$text, "no download URL available", fixed = TRUE)
  # a file in data/ is found; a pinned digest it does not match stops it
  csv <- c("group,value", "a,4", "b,6")
  dir.create(file.path(st, "data"))
  writeLines(csv, file.path(st, "data", "data.csv"))
  pf <- file.path(st, "data_provenance.json")
  prov <- fromjs(pf, simplifyVector = FALSE)
  prov$resource$sha256 <- strrep("0", 64L)
  writeLines(tojs(prov, auto_unbox = TRUE), pf)
  r <- run()
  expect_identical(r$status, 7L)
  expect_match(r$text, "SHA256 differs from the pinned provenance",
               fixed = TRUE)
  ext <- file.path(withr::local_tempdir(), "given.csv")
  writeLines(csv, ext)
  expect_identical(run("--data", shQuote(ext))$status, 7L)
  prov$resource$sha256 <- sha256file(ext)
  writeLines(tojs(prov, auto_unbox = TRUE), pf)
  r <- run()
  expect_identical(r$status, 0L)
  expect_match(r$text, "SHA256 matches the pinned provenance", fixed = TRUE)
  expect_match(r$text, file.path("data", "data.csv"), fixed = TRUE)
})

test_that("too many files are refused before anything is copied", {
  p <- bndl_proj()
  many <- c("analysis.R", sprintf("f/%05d.txt", seq_len(70000L)))
  copied <- new.env()
  copied$n <- 0L
  local_mocked_bindings(.bndl_project_files = function(...) many)
  local_mocked_bindings(
    file.copy = function(...) {
      copied$n <- copied$n + 1L
      TRUE
    },
    .package = "base"
  )
  expect_error(mkbndl(p$dir, withr::local_tempdir()),
               "70\\d+ files and folders, more than a plain zip holds")
  expect_identical(copied$n, 0L)
  expect_identical(.bndl_dirs(c("a/b/c.R", "a/d.R", "e.R")), c("a/b", "a"))
})

test_that("a project of too many files is refused before it is walked", {
  p <- bndl_proj()
  local_mocked_bindings(
    .bndl_count = function(pdir) 70000,
    .bndl_walk = function(pdir) stop("walked")
  )
  expect_error(mkbndl(p$dir, withr::local_tempdir()),
               "70000 files and folders, more than a plain zip holds")
})

test_that("links are found on Unix and, by their real path, on Windows", {
  skip_on_os("windows")
  d <- withr::local_tempdir()
  dir.create(file.path(d, "real"))
  file.symlink(file.path(d, "real"), file.path(d, "ln"))
  file.symlink(d, file.path(d, "up"))
  p <- file.path(d, c("real", "ln", "up"))
  expect_identical(.bndl_islink(p), c(FALSE, TRUE, TRUE))
  expect_identical(.bndl_islink(p, win = TRUE), c(FALSE, TRUE, TRUE))
  expect_identical(.bndl_islink(character()), logical())
})

test_that("66,000 files are counted and refused in seconds", {
  skip_on_cran()
  p <- bndl_proj()
  dir.create(file.path(p$dir, "many"))
  file.create(file.path(p$dir, "many", sprintf("f%05d.txt", 1:66000)))
  # what is never packed is not counted
  dir.create(file.path(p$dir, "results_1"))
  file.create(file.path(p$dir, "results_1", "x.csv"))
  file.symlink(p$dir, file.path(p$dir, "loop"))
  n <- .bndl_count(p$dir)
  # the top entries but results_1 (the link itself counted, not followed)
  expect_identical(n, length(list.files(p$dir)) - 1 + 66000)
  t <- system.time(
    expect_error(mkbndl(p$dir, withr::local_tempdir()),
                 "more than a plain zip holds")
  )[["elapsed"]]
  expect_lt(t, 5)
})
