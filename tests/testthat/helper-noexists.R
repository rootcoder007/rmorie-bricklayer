# SPDX-License-Identifier: AGPL-3.0-or-later
# A stand-in for base::exists() that says FALSE to rmoriebricklayer's own
# code only, for tests of what a staged bundle (no compiled code, no
# installed helpers) does. Mocking exists() to FALSE for every caller also
# blinds testthat, cli and rlang, which call it themselves: on R 4.1 the test
# then dies with "object 'expr' not found" before it checks anything.
local_pkg_lacks_everything <- function(env = parent.frame()) {
  real <- base::exists
  ns <- asNamespace("rmoriebricklayer")
  testthat::local_mocked_bindings(
    exists = function(x, ...) {
      if (identical(topenv(parent.frame()), ns)) {
        return(FALSE)
      }
      args <- list(...)
      if (!length(args)) {
        # the caller's frame, as exists(x) with no envir means
        args$envir <- parent.frame()
      }
      do.call(real, c(list(x), args))
    },
    .package = "base",
    .env = env
  )
}
