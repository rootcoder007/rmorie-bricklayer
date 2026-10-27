# A wall-clock upper bound. CRAN runs the tests under valgrind too, 20 to 50
# times slower (19 s against a bound of 15, 30 s against 10; CRAN stress test of
# 0.5.14): there the bound is 50 times wider, which still catches the quadratic
# or exponential blowups these bounds are for. Off CRAN it is as written. ...
# and under covr, whose instrumented build runs the native code several times
# slower (M9: 2.38 s against a 2 s limit in the coverage leg). covr sets
# R_COVR=true in the session. ... and on a loaded machine: a 2 s bound failed
# twice at a load average of 10 on 2 cores and passed alone (final audit of
# 1.0.0, #10). The bound is widened by the load per core, read from
# /proc/loadavg where there is one (it is what inflates an elapsed time); CPU
# time is not the measure because a wait on a child or the network is part of
# what these bounds catch.
wall_limit <- function(s) {
  if (
    !identical(Sys.getenv("NOT_CRAN"), "true") ||
      identical(Sys.getenv("R_COVR"), "true")
  ) {
    return(50 * s)
  }
  load <- tryCatch(
    as.numeric(strsplit(
      readLines("/proc/loadavg", n = 1L, warn = FALSE),
      " ",
      fixed = TRUE
    )[[1L]][[1L]]),
    error = function(e) NA_real_,
    warning = function(w) NA_real_
  )
  cores <- tryCatch(parallel::detectCores(), error = function(e) NA_integer_)
  if (is.finite(load) && is.finite(cores) && cores > 0 && load > cores) {
    s * min(50, load / cores)
  } else {
    s
  }
}
