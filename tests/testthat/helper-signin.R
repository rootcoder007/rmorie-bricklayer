# Sign-in tests that are about the GitHub or email flow skip the
# terms-and-profile step (its own tests are in test-signin-profile.R): the step
# returns nothing, so the requests are as before.
local_no_signin_profile <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    .bl_signin_profile = function(...) list(),
    .package = "rmoriebricklayer",
    .env = env
  )
}
