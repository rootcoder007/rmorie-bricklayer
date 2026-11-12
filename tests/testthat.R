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
# On a machine or container with under 3 GB the batches are three files: under
# covr a batch of eight reached 1.1 GB beside the checker's own 500 MB.
mem_gb <- function() {
  cap <- Inf
  for (f in c(
    "/sys/fs/cgroup/memory.max",
    "/sys/fs/cgroup/memory/memory.limit_in_bytes"
  )) {
    v <- suppressWarnings(as.numeric(
      tryCatch(readLines(f, 1L, warn = FALSE), error = function(e) NA)
    ))
    if (length(v) == 1L && !is.na(v) && v > 0) cap <- min(cap, v)
  }
  mi <- tryCatch(
    readLines("/proc/meminfo", warn = FALSE),
    error = function(e) character()
  )
  kb <- suppressWarnings(as.numeric(
    sub("^MemTotal:\\s+(\\d+) kB$", "\\1", grep("^MemTotal:", mi, value = TRUE))
  ))
  if (length(kb) == 1L && !is.na(kb)) cap <- min(cap, kb * 1024)
  cap / 1024^3
}
size <- if (mem_gb() < 3) "3" else "8"
batch <- suppressWarnings(as.integer(Sys.getenv("RMBL_TEST_BATCH", size)))
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
  # Under covr every R process that loaded the package leaves a trace file of
  # all its counters (about 40 MB once read), and covr reads them all before
  # it adds them up: 52 files took 2.06 GB, which stopped pkgcheck on a 2 GB
  # machine after every test had passed. Adding each batch into one file as
  # the suite goes gives covr the same counts in one file. Anything not as
  # expected (another covr layout, recorded tests) leaves the files alone.
  squash <- function() {
    dir <- dirname(find.package("rmoriebricklayer"))
    fs <- list.files(dir, "^covr_trace_", full.names = TRUE)
    if (length(fs) < 2L) {
      return(invisible(NULL))
    }
    acc <- readRDS(fs[1L])
    if (!is.environment(acc) || exists("tests", acc, inherits = FALSE)) {
      return(invisible(NULL))
    }
    for (f in fs[-1L]) {
      x <- readRDS(f)
      if (!is.environment(x) || exists("tests", x, inherits = FALSE)) {
        return(invisible(NULL))
      }
      for (k in ls(x, all.names = TRUE)) {
        if (exists(k, acc, inherits = FALSE)) {
          acc[[k]]$value <- acc[[k]]$value + x[[k]]$value
        } else {
          acc[[k]] <- x[[k]]
        }
      }
    }
    tmp <- tempfile("sq_", tmpdir = dir)
    saveRDS(acc, tmp)
    unlink(fs[-1L])
    file.rename(tmp, fs[1L])
    invisible(NULL)
  }
  covr <- nzchar(Sys.getenv("R_COVR"))
  failed <- character()
  for (g in groups) {
    # test file names are letters, digits, "_", "-" and "."; only "." is special
    esc <- gsub(".", "\\.", g, fixed = TRUE)
    filter <- paste0("^(", paste(esc, collapse = "|"), ")$")
    Sys.setenv(RMBL_TEST_FILTER = filter)
    if (!identical(system2(rscript, shQuote(child)), 0L)) failed <- c(failed, g)
    if (covr) try(squash(), silent = TRUE)
  }
  if (length(failed)) {
    stop("tests failed in: ", toString(failed), call. = FALSE)
  }
} else if (full) {
  testthat::test_check("rmoriebricklayer")
}
