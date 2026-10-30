# SPDX-License-Identifier: AGPL-3.0-or-later
# test_check() attaches testthat and the package itself.

# On CRAN (NOT_CRAN unset) only three quick files run (core helpers, manifests,
# spread statistics; about half a second), so the CRAN check stays inside its time
# budget. CI sets NOT_CRAN=true and r-universe sets MY_UNIVERSE; both run the full
# suite. A coverage run (covr sets R_COVR, as goodpractice's does) runs the full
# suite too, with the tests CRAN skips, so it measures every line.
if (nzchar(Sys.getenv("R_COVR"))) {
  Sys.setenv(NOT_CRAN = "true")
}
core <- c("core", "manifest", "spread")
if (
  identical(Sys.getenv("NOT_CRAN"), "true") || nzchar(Sys.getenv("MY_UNIVERSE"))
) {
  testthat::test_check("rmoriebricklayer")
} else {
  testthat::test_check(
    "rmoriebricklayer",
    filter = paste0("^(", paste(core, collapse = "|"), ")$")
  )
}
