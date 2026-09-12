# The last few branches: the SIU fetch-failure path, HyperLogLog's
# small-register bias constants, and the C-level argument guards.

test_that("a failed SIU fetch returns NULL rather than erroring", {
  # bricklayer_fetch_parse_siu() is the convenience wrapper that fetches
  # and then parses. A network failure must leave the caller with NULL,
  # not an exception, because a capsule build that cannot reach one
  # report should carry on and record the gap.
  testthat::local_mocked_bindings(
    bricklayer_fetch_siu = function(...) stop("network unreachable")
  )
  expect_message(res <- bricklayer_fetch_parse_siu("12-TCD-001"),
                 "could not fetch SIU report")
  expect_null(res)

  # a fetch that claims success but writes nothing is also NULL, since
  # there is no file to parse
  testthat::local_mocked_bindings(
    bricklayer_fetch_siu = function(drid, dest, ...) invisible(dest)
  )
  expect_null(bricklayer_fetch_parse_siu("12-TCD-002"))
})

test_that("HyperLogLog uses its published constant at every register size", {
  # alpha_m is tabulated for m = 16, 32 and 64 and only then given by
  # the general formula. Those three cases correspond to p = 4, 5 and 6,
  # which the main suite never exercises because it uses p >= 10.
  set.seed(1)
  x <- as.character(seq_len(500))
  for (p in 4:8) {
    reg <- distinct_sketch(x, p = p)
    expect_length(reg, 2^p)
    est <- distinct_count(reg)
    expect_true(is.finite(est))
    expect_gt(est, 0)
    # a tiny register count is a poor estimator, but it must still be in
    # the right order of magnitude rather than absurd
    expect_lt(est, 500 * 20)
  }
  # the estimate improves as the register count grows: with 16 registers
  # the relative error is around 26%, with 16384 it is under 1%
  true_n <- 20000L
  y <- as.character(seq_len(true_n))
  err <- vapply(c(4L, 8L, 14L), function(p) {
    abs(distinct_count(distinct_sketch(y, p = p)) - true_n) / true_n
  }, 0)
  expect_lt(err[3], err[1])
  expect_lt(err[3], 0.05)
  # every register set merges with another of the same size
  a <- distinct_sketch(y[1:10000], p = 6L)
  b <- distinct_sketch(y[10001:20000], p = 6L)
  expect_length(sketch_merge(a, b), 64L)
  expect_true(is.finite(distinct_count(sketch_merge(a, b))))
  # an all-zero register set is an empty sketch
  expect_equal(distinct_count(integer(64)), 0, tolerance = 1e-9)
})

test_that("the C-level guards reject malformed arguments", {
  # the moment accumulators must be the five-entry layout
  acc <- online_summary(stats::rnorm(20))
  expect_error(.Call(rmoriebricklayer:::C_rmbl_moments_merge,
                     acc$state, c(1, 2, 3)), "5 entries")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_moments_merge,
                     c(1, 2), acc$state), "5 entries")
  # a valid merge is unaffected
  merged <- .Call(rmoriebricklayer:::C_rmbl_moments_merge,
                  acc$state, acc$state)
  expect_length(merged, 5L)
  expect_equal(merged[1], 40)

  # the weighted moments need matching lengths, checked in C as well as R
  expect_error(.Call(rmoriebricklayer:::C_rmbl_weighted,
                     c(1, 2, 3), c(1, 2)), "same length")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_cor_spearman,
                     c(1, 2, 3), c(1, 2)), "same length")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_psi,
                     c(0.5, 0.5), c(1), 1e-6), "same length")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_ipw,
                     c(1, 0), c(0.5), 0.01, 0.99), "same length")
  # the covariance kernel needs an actual matrix
  expect_error(.Call(rmoriebricklayer:::C_rmbl_cov_matrix, 1:6),
               "must be a matrix")
  # the bootstrap needs at least one replicate
  expect_error(.Call(rmoriebricklayer:::C_rmbl_bootstrap_mean,
                     c(1, 2, 3), 0, 1), "at least 1")
  # BLAKE2b's length and key bounds
  expect_error(.Call(rmoriebricklayer:::C_rmbl_blake2b, "x", NULL, 0L),
               "between 1 and 64")
  # PBKDF2's bounds
  expect_error(.Call(rmoriebricklayer:::C_rmbl_pbkdf2, "p", "s", 0L, 32L),
               "at least 1")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_pbkdf2, "p", "s", 1L, 0L),
               "between 1 and 1024")
  # the OS random source's request size
  expect_error(.Call(rmoriebricklayer:::C_rmbl_os_random, 0L),
               "between 1 and")
  # and the reservoir's
  expect_error(.Call(rmoriebricklayer:::C_rmbl_reservoir, -1, 1, 1),
               "non-negative")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_reservoir, 10, -1, 1),
               "non-negative")
  # the Merkle proof index
  expect_error(.Call(rmoriebricklayer:::C_rmbl_merkle_proof,
                     list(charToRaw("a"), charToRaw("b")), 5L),
               "between 1 and")
  # the C layer takes bytes, so it refuses anything that is not a list
  # of raw vectors rather than coercing it to text and hashing that
  expect_error(.Call(rmoriebricklayer:::C_rmbl_merkle_root, c("a", "b")),
               "list of raw vectors")
  expect_error(.Call(rmoriebricklayer:::C_rmbl_merkle_root, list("a")),
               "must be a raw vector")
})

test_that("an empty Merkle tree and sketch degrade rather than error", {
  expect_true(is.na(.Call(rmoriebricklayer:::C_rmbl_merkle_root, list())))
  expect_true(is.na(merkle_root(character(0))))
  expect_equal(distinct_count(integer(0)), 0)
  expect_length(reservoir_indices(0, 0), 0L)
  # a single-leaf tree needs no proof
  expect_length(merkle_proof("solo", 1)$sibling, 0L)
  # an accumulator with nothing in it reports nothing rather than zero
  e <- summary_stats(online_summary())
  expect_equal(e[["n"]], 0)
  expect_true(is.nan(e[["mean"]]))
})
