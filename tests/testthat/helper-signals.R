# A process started from a non-interactive shell's background job inherits SIGINT as
# ignored (POSIX), and R keeps an inherited SIG_IGN: a test that sends the process its own
# SIGINT can then never see the interrupt, which says nothing about the code under test.
# Linux shows the mask in /proc; elsewhere the test proceeds.
skip_if_sigint_ignored <- function() {
  status <- tryCatch(readLines("/proc/self/status", warn = FALSE), error = function(e) character())
  ign <- sub("^SigIgn:\\s*", "", grep("^SigIgn:", status, value = TRUE))
  if (length(ign) == 1L && nzchar(ign)) {
    low <- strtoi(substr(ign, nchar(ign), nchar(ign)), 16L)
    testthat::skip_if(bitwAnd(low, 2L) == 2L,
                      "SIGINT is ignored in this process (inherited from a background job)")
  }
  invisible(TRUE)
}
