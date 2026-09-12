# One-pass sketches.
#
# The moment accumulator claims to be EXACT, so it is anchored against
# the batch kernel and against base R -- an approximate merge would fail
# these. The reservoir claims uniformity, so it is anchored on the
# inclusion frequency over many seeds. HyperLogLog is approximate by
# construction, so it is anchored on its own published error bound
# rather than on an exact value.

test_that("block accumulation is exact, not approximate", {
  set.seed(41)
  x <- stats::rnorm(1000, mean = 7, sd = 3)

  acc <- online_summary()
  for (i in seq(1, 1000, by = 100)) {
    acc <- summary_update(acc, x[i:(i + 99)])
  }
  s <- summary_stats(acc)
  expect_named(s, c("n", "mean", "variance", "sd", "skewness", "kurtosis"))
  expect_equal(s[["n"]], 1000)
  # exact agreement with base R, block by block
  expect_equal(s[["mean"]], mean(x))
  expect_equal(s[["variance"]], stats::var(x))
  expect_equal(s[["sd"]], stats::sd(x))
  # and with the batch kernel, on all four moments
  m <- core_moments(x)
  expect_equal(s[["mean"]], m[["mean"]])
  expect_equal(s[["variance"]], m[["variance"]])
  expect_equal(s[["skewness"]], m[["skewness"]])
  expect_equal(s[["kurtosis"]], m[["kurtosis"]])

  # the block size cannot change the answer
  for (bs in c(1L, 7L, 333L, 1000L)) {
    a2 <- online_summary()
    for (i in seq(1, 1000, by = bs)) {
      a2 <- summary_update(a2, x[i:min(1000, i + bs - 1L)])
    }
    expect_equal(summary_stats(a2)[["variance"]], stats::var(x))
    expect_equal(summary_stats(a2)[["skewness"]], m[["skewness"]])
  }

  # a single-shot constructor is the same as one update
  expect_equal(summary_stats(online_summary(x)), s)
})

test_that("accumulators merge in any order and handle empty blocks", {
  set.seed(42)
  x <- stats::rnorm(600)
  a <- online_summary(x[1:250])
  b <- online_summary(x[251:600])
  ab <- summary_merge(a, b)
  ba <- summary_merge(b, a)

  expect_equal(summary_stats(ab)[["mean"]], mean(x))
  expect_equal(summary_stats(ab)[["variance"]], stats::var(x))
  # merging is symmetric in its arguments
  expect_equal(summary_stats(ba)[["variance"]],
               summary_stats(ab)[["variance"]])
  expect_equal(summary_stats(ba)[["mean"]], summary_stats(ab)[["mean"]])
  # and associative across three parts
  p1 <- online_summary(x[1:200])
  p2 <- online_summary(x[201:400])
  p3 <- online_summary(x[401:600])
  expect_equal(summary_stats(summary_merge(summary_merge(p1, p2), p3)),
               summary_stats(summary_merge(p1, summary_merge(p2, p3))))

  # an empty accumulator is the identity for the merge
  e <- online_summary()
  expect_equal(summary_stats(summary_merge(a, e)), summary_stats(a))
  expect_equal(summary_stats(summary_merge(e, a)), summary_stats(a))
  # and reports nothing rather than zero
  es <- summary_stats(e)
  expect_equal(es[["n"]], 0)
  expect_true(is.nan(es[["mean"]]))
  expect_true(is.nan(es[["variance"]]))
  # an empty or all-NA block leaves the accumulator untouched
  expect_equal(summary_stats(summary_update(a, numeric(0))),
               summary_stats(a))
  expect_equal(summary_stats(summary_update(a, c(NA, NA))),
               summary_stats(a))
  # NA inside a block is dropped, not propagated
  expect_equal(summary_stats(online_summary(c(x[1:10], NA)))[["mean"]],
               mean(x[1:10]))
  # too few observations for a moment gives NaN, not a fabricated number
  expect_true(is.nan(summary_stats(online_summary(c(1, 2)))[["skewness"]]))
  expect_equal(summary_stats(online_summary(5))[["n"]], 1)
  expect_output(print(a), "Accumulated summary")

  expect_error(summary_update(list(), 1), "online_summary")
  expect_error(summary_stats(list()), "online_summary")
  expect_error(summary_merge(a, list()), "online_summary")
})

test_that("the reservoir samples uniformly and reproducibly", {
  idx <- reservoir_indices(1000, 5, seed = 1)
  expect_length(idx, 5L)
  expect_true(all(idx >= 1 & idx <= 1000))
  expect_equal(length(unique(idx)), 5L)
  # sorted, so it can drive a single forward pass over a file
  expect_equal(idx, sort(idx))
  # reproducible, and dependent on the seed
  expect_identical(reservoir_indices(1000, 5, seed = 1), idx)
  expect_false(identical(reservoir_indices(1000, 5, seed = 2), idx))
  # R's own stream is untouched
  set.seed(5)
  before <- stats::runif(1)
  set.seed(5)
  invisible(reservoir_indices(100, 10, seed = 9))
  expect_equal(stats::runif(1), before)

  # k at or above the stream length returns the whole stream
  expect_equal(reservoir_indices(3, 3), c(1, 2, 3))
  expect_equal(reservoir_indices(3, 10), c(1, 2, 3))
  expect_length(reservoir_indices(0, 5), 0L)
  expect_length(reservoir_indices(10, 0), 0L)

  # UNIFORMITY: every position must be retained about equally often.
  # Algorithm R's guarantee is exactly this, and a naive "keep the first
  # k" or "keep the last k" would fail it badly.
  n <- 20L
  k <- 4L
  counts <- integer(n)
  for (s in seq_len(2000L)) {
    hit <- reservoir_indices(n, k, seed = s)
    counts[hit] <- counts[hit] + 1L
  }
  expect_equal(sum(counts), 2000L * k)
  expected <- 2000L * k / n
  # a chi-square goodness-of-fit against the uniform inclusion rate
  chi <- sum((counts - expected)^2 / expected)
  expect_lt(chi, stats::qchisq(0.999, df = n - 1L))
  # and no position is grossly favoured
  expect_true(all(abs(counts - expected) / expected < 0.25))

  # sampling a vector returns its elements
  expect_equal(reservoir_sample(letters, 4, seed = 2),
               letters[reservoir_indices(26, 4, seed = 2)])
  expect_length(reservoir_sample(1:100, 7, seed = 3), 7L)
  expect_true(all(reservoir_sample(1:100, 7, seed = 3) %in% 1:100))

  expect_error(reservoir_indices(-1, 5), "non-negative")
  expect_error(reservoir_indices(10, -1), "non-negative")
})

test_that("HyperLogLog estimates cardinality within its error bound", {
  set.seed(43)
  # the published relative standard error is 1.04 / sqrt(m)
  p <- 12L
  m <- 2^p
  rse <- 1.04 / sqrt(m)
  for (true_n in c(1000L, 20000L, 100000L)) {
    x <- as.character(seq_len(true_n))
    est <- distinct_count(distinct_sketch(x, p = p))
    # inside four standard errors, which a broken sketch would not be
    expect_lt(abs(est - true_n) / true_n, 4 * rse)
  }

  # repeated values do not inflate the count
  x <- sample(1:5000, 50000, replace = TRUE)
  est <- distinct_count(distinct_sketch(x, p = 14L))
  expect_lt(abs(est - length(unique(x))) / length(unique(x)), 0.05)

  # small cardinalities go through linear counting and are near-exact
  expect_equal(distinct_count(distinct_sketch(c("a", "b", "c", "a", "b"))),
               3, tolerance = 0.01)
  expect_equal(distinct_count(distinct_sketch(as.character(1:50))), 50,
               tolerance = 0.02)
  expect_equal(distinct_count(distinct_sketch(character(0))), 0)
  expect_equal(distinct_count(distinct_sketch("only")), 1, tolerance = 0.01)
  # NA carries no value to count
  expect_equal(distinct_count(distinct_sketch(c("a", NA, "b"))), 2,
               tolerance = 0.01)

  # the sketch is deterministic, which is what makes a capsule
  # reproducible
  expect_identical(distinct_sketch(x, p = 10L), distinct_sketch(x, p = 10L))
  # registers are the right size and non-negative
  expect_length(distinct_sketch(x, p = 10L), 1024L)
  expect_true(all(distinct_sketch(x, p = 10L) >= 0))
  # numbers and strings agree when they render the same
  expect_identical(distinct_sketch(1:100), distinct_sketch(as.character(1:100)))

  # chunks fold into one sketch, and independent sketches merge, both
  # giving the same answer as one pass
  one <- distinct_sketch(x, p = 12L)
  folded <- distinct_sketch(x[1:25000], p = 12L)
  folded <- distinct_sketch(x[25001:50000], p = 12L, registers = folded)
  expect_identical(folded, one)
  merged <- sketch_merge(distinct_sketch(x[1:25000], p = 12L),
                         distinct_sketch(x[25001:50000], p = 12L))
  expect_identical(merged, one)
  expect_equal(distinct_count(merged), distinct_count(one))
  # merging is the element-wise maximum, so it is idempotent
  expect_identical(sketch_merge(one, one), one)

  expect_error(distinct_sketch(x, p = 3L), "between 4 and 20")
  expect_error(distinct_sketch(x, p = 21L), "between 4 and 20")
  expect_error(distinct_sketch(x, p = 10L, registers = 1:5), "2\\^p entries")
  expect_error(sketch_merge(1:4, 1:8), "same number of registers")
})
