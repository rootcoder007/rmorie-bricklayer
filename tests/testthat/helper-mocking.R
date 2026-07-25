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
