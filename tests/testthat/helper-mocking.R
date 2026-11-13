# SPDX-License-Identifier: AGPL-3.0-or-later
# local_mocked_bindings() needs the package namespace loaded. devtools::test()
# and R CMD check provide it; a bare testthat::test_dir() does not, and the
# mock call errors there. Guard so those tests skip cleanly instead (N7).
skip_if_cannot_mock <- function() {
  testthat::skip_if_not(
    isNamespaceLoaded("rmoriebricklayer"),
    "local_mocked_bindings needs the package namespace (run via devtools::test)"
  )
}

# bslib compiles the dashboard's theme through sass, which caches it in
# ~/.cache/R/sass: off, so the tests leave nothing in the checking user's home
options(sass.cache = FALSE)

# A table the manifest lists without a digest is used with a warning, once per
# session and table: expected where a test loads one (the record is cleared
# first, as another test in the same process may have warned already).
expect_nodigest <- function(object) {
  rm(list = ls(.bl_data_nodigest), envir = .bl_data_nodigest)
  testthat::expect_warning(object, "without a SHA-256")
}
