# A wall-clock upper bound. CRAN runs the tests under valgrind too, 20 to 50 times slower (19 s against
# a bound of 15, 30 s against 10; CRAN stress test of 0.5.14): there the bound is 50 times wider, which
# still catches the quadratic or exponential blowups these bounds are for. Off CRAN it is as written.
# ... and under covr, whose instrumented build runs the native code several times slower
# (M9: 2.38 s against a 2 s limit in the coverage leg). covr sets R_COVR=true in the session.
wall_limit <- function(s) {
  if (identical(Sys.getenv("NOT_CRAN"), "true") && !identical(Sys.getenv("R_COVR"), "true")) s else 50 * s
}
