# A known-answer test re-derives a published key (the RFC 8391 reference seeds) and signs
# its index 0 by design; every other test file in the session may have signed that key too.
# This clears capsule_sign()'s record of used indices -- for tests only.
# the package exports xmss_forget_used_indices(); tests call that one

# the tests must not touch the user's own index file: every test session records its used
# indices in a file of its own (tests of the file itself set their own path)
options(rmoriebricklayer.xmss_index_file = tempfile("xmss-index-", fileext = ".json"))

# the id a key has in the used-index record: a fingerprint of its secret seed (review of 52a8883)
xmss_kid <- function(k) rmoriebricklayer:::.rmbl_xmss_ids(k)$id
