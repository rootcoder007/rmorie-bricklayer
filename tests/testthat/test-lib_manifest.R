# SPDX-License-Identifier: AGPL-3.0-or-later
# Reproducibility manifests: the comparisons recorded and the summary written.

mk <- function() {
  man <- mkmnf(list(project = "demo", author = "A. Author"), env = FALSE)
  # a session that generated synthetic data marks every manifest synthetic
  man$meta$synthetic <- FALSE
  man
}

test_that("recrd() records PASS, DIFFER and INFO", {
  man <- mk()
  man <- suppressMessages(recrd(man, "m", obs = 1.0001, expd = 1, tol = 0.001))
  expect_identical(man$results$m$status, "PASS")
  man <- suppressMessages(recrd(man, "s", obs = 2.5, expd = 2, tol = 0.01))
  expect_identical(man$results$s$status, "DIFFER")
  expect_equal(man$results$s$diff, 0.5, tolerance = 1e-12)
  man <- suppressMessages(recrd(man, "c", obs = "CA", expd = "CA"))
  expect_identical(man$results$c$status, "INFO")
  expect_true(is.na(man$results$c$diff))
  man <- suppressMessages(recrd(man, "y", obs = 5, expd = 5, syn = TRUE))
  expect_identical(man$results$y$status, "INFO")
  expect_match(man$results$y$note, "synthetic", fixed = TRUE)
  expect_length(man$results, 4L)
  expect_message(recrd(mk(), "z", obs = 1, expd = 1), "z", fixed = TRUE)
})

test_that("recrd() refuses vectors and a manifest that is not one", {
  man <- mk()
  expect_error(recrd(man, "v", obs = 1:2, expd = 1), "`obs` must be a single")
  expect_error(recrd(man, "v", obs = 1, expd = numeric()), "`expd` must be")
  expect_error(recrd(data.frame(), "v", obs = 1, expd = 1), "mkmnf")
  expect_identical(.rmbl_recrd_status(FALSE, NA_real_, 1), "INFO")
  expect_identical(.rmbl_recrd_status(TRUE, 0, 1), "INFO")
  expect_identical(.rmbl_recrd_status(FALSE, 2, 1), "DIFFER")
})

test_that("wrsmrytxt() writes every section asked for", {
  man <- suppressMessages(recrd(mk(), "m", obs = 1, expd = 1))
  d <- withr::local_tempdir()
  writeLines("x", file.path(d, "a.csv"))
  p <- wrsmrytxt(
    man,
    d,
    list(data = "/data/x.csv"),
    whatwasdone = "ran the models",
    contact = "someone",
    lic = "CC-BY"
  )
  expect_identical(p, file.path(d, "SUMMARY.txt"))
  txt <- readLines(p)
  expect_true("Project:   demo" %in% txt)
  expect_true(any(grepl("^Data: +/data/x.csv$", txt)))
  expect_true("PASS:         1" %in% txt)
  expect_true("  a.csv" %in% txt)
  expect_true("ran the models" %in% txt)
  expect_true("Contact: someone" %in% txt)
  expect_true("Licence: CC-BY" %in% txt)
  expect_error(wrsmrytxt(man, file.path(d, "nope"), list()), "not a directory")
  expect_error(wrsmrytxt(man, d, list(), contact = 1), "`contact` must be text")
  expect_error(wrsmrytxt("x", d, list()), "mkmnf")
})

test_that("recrd names obs and expd; mkmnf checks env", {
  m <- mkmnf(list(), env = FALSE)
  f <- function() 1
  expect_error(recrd(m, "a", f, 1), "recrd: `obs` must be data")
  expect_error(recrd(m, "a", 1, f), "recrd: `expd` must be data")
  expect_error(mkmnf(list(), env = "yes"), "mkmnf: `env` must be TRUE or")
  expect_null(mkmnf(list(), env = FALSE)$environment)
})

# ---- the manifest prints as a box; its JSON is unchanged ---------------------

test_that("mkmnf() carries a class and writes the same bytes as a list", {
  m <- mkmnf(list(project = "p", n = 1.5), env = TRUE)
  expect_s3_class(m, c("rmbl_manifest", "list"))
  expect_s3_class(m$environment, "rmbl_capenv")
  m <- suppressMessages(recrd(m, "rows", 10, 10))
  plain <- unclass(m)
  plain$environment <- unclass(plain$environment)
  expect_identical(
    tojs(m, auto_unbox = TRUE, pretty = TRUE),
    tojs(plain, auto_unbox = TRUE, pretty = TRUE)
  )
  expect_identical(mnfcanon(m), mnfcanon(plain))
  f1 <- tempfile(fileext = ".json")
  f2 <- tempfile(fileext = ".json")
  wrmnfjs(m, f1)
  wrmnfjs(plain, f2)
  expect_identical(readBin(f1, "raw", 1e6), readBin(f2, "raw", 1e6))
  wrmnfjs(m, f1, canon = TRUE)
  wrmnfjs(plain, f2, canon = TRUE)
  expect_identical(readBin(f1, "raw", 1e6), readBin(f2, "raw", 1e6))
  expect_box2(m, "Run manifest", c("project p", "All 1 cross-checks"))
  m2 <- suppressMessages(recrd(m, "mean", 2.5, 2.4))
  expect_box2(m2, "Run manifest", "1 of 2 cross-checks differ")
  expect_box2(mkmnf(list(), env = FALSE), "Run manifest", "No cross-checks")
})

test_that("a manifest without its lists prints as a list", {
  m <- structure(list(meta = "x"), class = c("rmbl_manifest", "list"))
  expect_identical(format(m), utils::capture.output(print(unclass(m))))
})
