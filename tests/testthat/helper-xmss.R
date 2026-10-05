# A known-answer test re-derives a published key (the RFC 8391 reference seeds) and signs
# its index 0 by design; every other test file in the session may have signed that key too.
# This clears capsule_sign()'s record of used indices -- for tests only.
xmss_forget_used_indices <- function() {
  e <- get(".rmbl_xmss_used", envir = asNamespace("rmoriebricklayer"))
  rm(list = ls(e, all.names = TRUE), envir = e)
}
