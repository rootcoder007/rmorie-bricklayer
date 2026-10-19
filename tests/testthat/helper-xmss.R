# A known-answer test re-derives a published key (the RFC 8391 reference seeds) and signs
# its index 0 by design; every other test file in the session may have signed that key too.
# This clears cpssign()'s record of used indices -- for tests only.
# the package exports xmssfgt(); tests call that one

# the tests must not touch the user's own index file: every test session records its used
# indices in a file of its own (tests of the file itself set their own path)
options(rmoriebricklayer.xmssidxfile = tempfile("xmss-index-", fileext = ".json"))

# the id a key has in the used-index record: a fingerprint of its secret seed (review of 52a8883)
xmss_kid <- function(k) rmoriebricklayer:::.rmbl_xmss_ids(k)$id

# R code in a separate Rscript process, not a fork: a forked child of a covr-instrumented session
# that is killed leaves a partial coverage trace (covr's merge then fails), and forked children
# on macOS can die soon after they start. `out` captures the child's standard output.
rscript_bg <- function(code, wait = FALSE, out = FALSE) {
  rscript <- file.path(R.home("bin"), "Rscript")
  lib <- paste(.libPaths(), collapse = .Platform$path.sep)
  pre <- sprintf(paste0(".libPaths(strsplit('%s', '%s', fixed = TRUE)[[1]]); ",
                        "suppressMessages(library(rmoriebricklayer)); "), lib, .Platform$path.sep)
  # from a file, not -e: R's front-end script on macOS eats one level of backslashes from a -e
  # argument, so a served body holding "\\/" reached the child as "\/" (an unrecognized escape)
  # and the server died before answering (the Wayback snapshot test, macOS CI of 1.0.0)
  f <- tempfile("child-", fileext = ".R")
  writeLines(paste0(pre, code), f)
  system2(rscript, shQuote(f), wait = wait, stdout = out, stderr = FALSE)
}

# wait until every file exists and is not empty
wait_files <- function(files, seconds = 60) {
  for (w in seq_len(seconds * 10)) {
    if (all(file.exists(files)) && all(file.size(files) > 0)) return(TRUE)
    Sys.sleep(0.1)
  }
  FALSE
}
