# A known-answer test re-derives a published key (the RFC 8391 reference seeds)
# and signs its index 0 by design; every other test file in the session may have
# signed that key too. This clears cpssign()'s record of used indices -- for
# tests only. the package exports xmssfgt(); tests call that one

# the tests must not touch the user's own index file: every test session records
# its used indices in a file of its own (tests of the file itself set their own
# path)
options(
  rmoriebricklayer.xmssidxfile = tempfile("xmss-index-", fileext = ".json")
)

# the id a key has in the used-index record: a fingerprint of its secret seed
# (review of 52a8883)
xmss_kid <- function(k) .rmbl_xmss_ids(k)$id

# R code in a separate Rscript process, not a fork: a forked child of a
# covr-instrumented session that is killed leaves a partial coverage trace
# (covr's merge then fails), and forked children on macOS can die soon after
# they start. `out` captures the child's standard output.
rscript_bg <- function(code, wait = FALSE, out = FALSE) {
  skip_if_lowmem()
  rscript <- file.path(R.home("bin"), "Rscript")
  lib <- paste(.libPaths(), collapse = .Platform$path.sep)
  pre <- sprintf(
    paste0(
      ".libPaths(strsplit('%s', '%s', fixed = TRUE)[[1]]); ",
      "suppressMessages(library(rmoriebricklayer)); "
    ),
    lib,
    .Platform$path.sep
  )
  # from a file, not -e: R's front-end script on macOS eats one level of
  # backslashes from a -e argument, so a served body holding "\\/" reached the
  # child as "\/" (an unrecognized escape) and the server died before answering
  # (the Wayback snapshot test, macOS CI of 1.0.0)
  f <- tempfile("child-", fileext = ".R")
  writeLines(paste0(pre, code), f)
  system2(rscript, shQuote(f), wait = wait, stdout = out, stderr = FALSE)
}

# wait until every file exists and is not empty
wait_files <- function(files, seconds = 60) {
  for (w in seq_len(seconds * 10)) {
    if (all(file.exists(files)) && all(file.size(files) > 0)) {
      return(TRUE)
    }
    Sys.sleep(0.1)
  }
  FALSE
}

# Memory this test process may use, in bytes: the cgroup limit (a container) or
# the machine's RAM, whichever is smaller; Inf when neither can be read.
mem_cap <- function() {
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
  cap
}

# A second R process (a child Rscript or a fork) beside the test session does
# not fit a 2 GB check machine: rOpenSci's pkgcheck holds about 900 MB of its own
# once coverage is done, a test session takes 500 to 800 MB, and a fork or a
# child R that loads the package takes as much again (the kernel killed the run
# in the coverage step and again in R CMD check). Tests that start one skip
# when the machine or container has under 3 GB; CI and the coverage job, on
# larger machines, run them.
skip_if_lowmem <- function() {
  if (mem_cap() < 3 * 1024^3) {
    testthat::skip("a second R process needs more memory than this has")
  }
}
