# SPDX-License-Identifier: AGPL-3.0-or-later
# test_check() attaches testthat and the package itself.

# On CRAN (NOT_CRAN unset) no test runs, so the CRAN check stays inside its
# time budget. CI sets NOT_CRAN=true and r-universe sets MY_UNIVERSE; both run
# the full suite. A coverage run (covr sets R_COVR, as goodpractice's does)
# runs the full suite too, so it measures every line.
if (nzchar(Sys.getenv("R_COVR"))) {
  Sys.setenv(NOT_CRAN = "true")
}
full <- identical(Sys.getenv("NOT_CRAN"), "true") ||
  nzchar(Sys.getenv("MY_UNIVERSE"))

# One R process never gives memory back, so the whole suite in one process
# peaks near 1.8 GB (2 GB and more under covr), which a small checking machine
# kills. The full suite therefore runs in batches of 8 files, each in a fresh R
# process, so the peak is the largest batch's (under 1 GB; batches of 25 reached
# 2 GB with R CMD check alongside). covr still counts every line:
# each process that loads the instrumented package writes its own trace file,
# and covr merges them all. RMBL_TEST_BATCH=0 runs it in one process.
batch <- suppressWarnings(as.integer(Sys.getenv("RMBL_TEST_BATCH", "8")))
split_run <- full && !is.na(batch) && batch > 0
if (split_run) {
  files <- sort(list.files("testthat", "^test.*\\.[rR]$"))
  names <- sub("^test[-_]?", "", sub("\\.[rR]$", "", files))
  groups <- split(names, ceiling(seq_along(names) / batch))
  rscript <- file.path(R.home("bin"), "Rscript")
  # a child R must not read R CMD check's startup file (R_TESTS); set here,
  # not through system2(env =), which Windows ignores
  Sys.unsetenv("R_TESTS")
  child <- tempfile(fileext = ".R")
  writeLines(c(
    "testthat::test_dir(",
    "  'testthat', package = 'rmoriebricklayer', load_package = 'installed',",
    "  filter = Sys.getenv('RMBL_TEST_FILTER'),",
    "  reporter = testthat::check_reporter(), stop_on_failure = TRUE",
    ")"
  ), child)
  failed <- character()
  for (g in groups) {
    # test file names are letters, digits, "_", "-" and "."; only "." is special
    esc <- gsub(".", "\\.", g, fixed = TRUE)
    filter <- paste0("^(", paste(esc, collapse = "|"), ")$")
    Sys.setenv(RMBL_TEST_FILTER = filter)
    if (!identical(system2(rscript, shQuote(child)), 0L)) failed <- c(failed, g)
  }
  if (length(failed)) {
    stop("tests failed in: ", paste(failed, collapse = ", "), call. = FALSE)
  }
} else if (full) {
  testthat::test_check("rmoriebricklayer")
}
