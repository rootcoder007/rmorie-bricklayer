# A process started from a non-interactive shell's background job inherits SIGINT as
# ignored (POSIX), and R keeps an inherited SIG_IGN: a test that sends the process its own
# SIGINT can then never see the interrupt, which says nothing about the code under test.
# Linux shows the mask in /proc; elsewhere the test proceeds.
skip_if_sigint_ignored <- function() {
  if (!file.exists("/proc/self/status")) return(invisible(TRUE))  # not Linux: nothing to read
  status <- tryCatch(suppressWarnings(readLines("/proc/self/status", warn = FALSE)), error = function(e) character())
  ign <- sub("^SigIgn:\\s*", "", grep("^SigIgn:", status, value = TRUE))
  if (length(ign) == 1L && nzchar(ign)) {
    low <- strtoi(substr(ign, nchar(ign), nchar(ign)), 16L)
    testthat::skip_if(bitwAnd(low, 2L) == 2L,
                      "SIGINT is ignored in this process (inherited from a background job)")
  }
  invisible(TRUE)
}

# Run `expr_text` in a fresh R child whose SIGINT disposition is reset to the default (bash
# by a python3 launcher), with a helper that sends it SIGINT after `after` seconds. Returns "interrupt",
# "returned", or "inconclusive" (the helper could not run in time). Works where this process
# inherited SIGINT as ignored, which skip_if_sigint_ignored() would otherwise skip over.
interrupt_probe <- function(expr_text, after = 1, timeout = 120) {
  marker <- tempfile("probe-")
  code <- sprintf(paste(
    "suppressMessages(library(rmoriebricklayer));",
    "system2('bash', c('-c', shQuote(sprintf('sleep %s; kill -INT %%d && touch %s', Sys.getpid()))), wait = FALSE);",
    "got <- tryCatch({ %s; 'returned' }, interrupt = function(e) 'interrupt');",
    "for (i in 1:20) if (file.exists('%s')) break else Sys.sleep(0.1);",
    "cat(if (!file.exists('%s') && got == 'returned') 'inconclusive' else got, '\\n')"),
    after, marker, expr_text, marker, marker)
  script <- tempfile(fileext = ".R")
  writeLines(code, script)
  lib <- paste(.libPaths(), collapse = .Platform$path.sep)
  # a non-interactive shell cannot undo an inherited SIG_IGN (POSIX), python can: reset to
  # the default disposition, then exec Rscript under a hard timeout
  launcher <- paste(
    "import os, signal, sys; signal.signal(signal.SIGINT, signal.SIG_DFL);",
    "os.environ['R_LIBS'] = sys.argv[1];",
    "os.execvp('timeout', ['timeout', sys.argv[2], sys.argv[3], '--vanilla', sys.argv[4]])")
  args <- c("-c", shQuote(launcher), shQuote(lib), as.integer(timeout),
            shQuote(file.path(R.home("bin"), "Rscript")), shQuote(script))
  out <- suppressWarnings(system2(Sys.which("python3"), args, stdout = TRUE, stderr = TRUE))
  ans <- trimws(out)
  ans <- ans[ans %in% c("interrupt", "returned", "inconclusive")]
  if (length(ans)) ans[[1L]] else paste("inconclusive:", paste(utils::tail(out, 3), collapse = " | "))
}
