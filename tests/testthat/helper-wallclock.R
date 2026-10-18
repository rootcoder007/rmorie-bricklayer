# A wall-clock upper bound. CRAN runs the tests under valgrind too, 20 to 50 times slower (19 s against
# a bound of 15, 30 s against 10; CRAN stress test of 0.5.14): there the bound is 50 times wider, which
# still catches the quadratic or exponential blowups these bounds are for. Off CRAN it is as written.
wall_limit <- function(s) if (identical(Sys.getenv("NOT_CRAN"), "true")) s else 50 * s
