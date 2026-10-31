# SPDX-License-Identifier: AGPL-3.0-or-later
# test_check() attaches testthat and the package itself.

# On CRAN (NOT_CRAN unset) no test runs, so the CRAN check stays inside its time
# budget. CI sets NOT_CRAN=true and r-universe sets MY_UNIVERSE; both run the full
# suite. A coverage run (covr sets R_COVR, as goodpractice's does) runs the full
# suite too, so it measures every line.
if (nzchar(Sys.getenv("R_COVR"))) {
  Sys.setenv(NOT_CRAN = "true")
}
if (
  identical(Sys.getenv("NOT_CRAN"), "true") || nzchar(Sys.getenv("MY_UNIVERSE"))
) {
  testthat::test_check("rmoriebricklayer")
}
