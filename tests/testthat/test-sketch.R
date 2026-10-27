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

  acc <- onlsmry()
  for (i in seq(1, 1000, by = 100)) {
    acc <- smryupd(acc, x[i:(i + 99)])
  }
  s <- smrystat(acc)
  expect_named(s, c("n", "mean", "variance", "sd", "skewness", "kurtosis"))
  expect_identical(s[["n"]], 1000)
  # exact agreement with base R, block by block
  expect_equal(s[["mean"]], mean(x), tolerance = testthat::testthat_tolerance())
  expect_equal(s[["variance"]], stats::var(x), tolerance = 1e-12)
  expect_equal(s[["sd"]], stats::sd(x), tolerance = 1e-12)
  # and with the batch kernel, on all four moments
  m <- cmom(x)
  expect_equal(
    s[["mean"]],
    m[["mean"]],
    tolerance = testthat::testthat_tolerance()
  )
  expect_identical(s[["variance"]], m[["variance"]])
  expect_equal(
    s[["skewness"]],
    m[["skewness"]],
    tolerance = testthat::testthat_tolerance()
  )
  expect_equal(
    s[["kurtosis"]],
    m[["kurtosis"]],
    tolerance = testthat::testthat_tolerance()
  )

  # the block size cannot change the answer
  for (bs in c(1L, 7L, 333L, 1000L)) {
    a2 <- onlsmry()
    for (i in seq(1, 1000, by = bs)) {
      a2 <- smryupd(a2, x[i:min(1000, i + bs - 1L)])
    }
    expect_equal(
      smrystat(a2)[["variance"]],
      stats::var(x),
      tolerance = testthat::testthat_tolerance()
    )
    expect_equal(
      smrystat(a2)[["skewness"]],
      m[["skewness"]],
      tolerance = testthat::testthat_tolerance()
    )
  }

  # a single-shot constructor is the same as one update
  expect_equal(
    smrystat(onlsmry(x)),
    s,
    tolerance = testthat::testthat_tolerance()
  )
})

test_that("accumulators merge in any order and handle empty blocks", {
  set.seed(42)
  x <- stats::rnorm(600)
  a <- onlsmry(x[1:250])
  b <- onlsmry(x[251:600])
  ab <- smrymrg(a, b)
  ba <- smrymrg(b, a)

  expect_equal(smrystat(ab)[["mean"]], mean(x), tolerance = 1e-12)
  expect_equal(
    smrystat(ab)[["variance"]],
    stats::var(x),
    tolerance = testthat::testthat_tolerance()
  )
  # merging is symmetric in its arguments
  expect_identical(smrystat(ba)[["variance"]], smrystat(ab)[["variance"]])
  expect_identical(smrystat(ba)[["mean"]], smrystat(ab)[["mean"]])
  # and associative across three parts
  p1 <- onlsmry(x[1:200])
  p2 <- onlsmry(x[201:400])
  p3 <- onlsmry(x[401:600])
  expect_equal(
    smrystat(smrymrg(smrymrg(p1, p2), p3)),
    smrystat(smrymrg(p1, smrymrg(p2, p3))),
    tolerance = testthat::testthat_tolerance()
  )

  # an empty accumulator is the identity for the merge
  e <- onlsmry()
  expect_identical(smrystat(smrymrg(a, e)), smrystat(a))
  expect_identical(smrystat(smrymrg(e, a)), smrystat(a))
  # and reports nothing rather than zero
  es <- smrystat(e)
  expect_identical(es[["n"]], 0)
  expect_true(is.nan(es[["mean"]]))
  expect_true(is.nan(es[["variance"]]))
  # an empty or all-NA block leaves the accumulator untouched
  expect_identical(smrystat(smryupd(a, numeric(0))), smrystat(a))
  expect_identical(smrystat(smryupd(a, c(NA, NA))), smrystat(a))
  # NA inside a block is dropped, not propagated
  expect_identical(smrystat(onlsmry(c(x[1:10], NA)))[["mean"]], mean(x[1:10]))
  # too few observations for a moment gives NaN, not a fabricated number
  expect_true(is.nan(smrystat(onlsmry(c(1, 2)))[["skewness"]]))
  expect_identical(smrystat(onlsmry(5))[["n"]], 1)
  expect_output(print(a), "Accumulated summary")

  expect_error(smryupd(list(), 1), "onlsmry")
  expect_error(smrystat(list()), "onlsmry")
  expect_error(smrymrg(a, list()), "onlsmry")
})

test_that("the reservoir samples uniformly and reproducibly", {
  idx <- rsvidx(1000, 5, seed = 1)
  expect_length(idx, 5L)
  expect_true(all(idx >= 1 & idx <= 1000))
  expect_length(unique(idx), 5L)
  # sorted, so it can drive a single forward pass over a file
  expect_identical(idx, sort(idx))
  # reproducible, and dependent on the seed
  expect_identical(rsvidx(1000, 5, seed = 1), idx)
  expect_false(identical(rsvidx(1000, 5, seed = 2), idx))
  # R's own stream is untouched
  set.seed(5)
  before <- stats::runif(1)
  set.seed(5)
  invisible(rsvidx(100, 10, seed = 9))
  expect_identical(stats::runif(1), before)

  # k at or above the stream length returns the whole stream
  expect_identical(rsvidx(3, 3), c(1, 2, 3))
  expect_identical(rsvidx(3, 10), c(1, 2, 3))
  expect_length(rsvidx(0, 5), 0L)
  expect_length(rsvidx(10, 0), 0L)

  # UNIFORMITY: every position must be retained about equally often.
  # Algorithm R's guarantee is exactly this, and a naive "keep the first
  # k" or "keep the last k" would fail it badly.
  n <- 20L
  k <- 4L
  counts <- integer(n)
  for (s in seq_len(2000L)) {
    hit <- rsvidx(n, k, seed = s)
    counts[hit] <- counts[hit] + 1L
  }
  expect_identical(sum(counts), 2000L * k)
  expected <- 2000L * k / n
  # a chi-square goodness-of-fit against the uniform inclusion rate
  chi <- sum((counts - expected)^2 / expected)
  expect_lt(chi, stats::qchisq(0.999, df = n - 1L))
  # and no position is grossly favoured
  expect_true(all(abs(counts - expected) / expected < 0.25))

  # sampling a vector returns its elements
  expect_identical(
    rsvsmp(letters, 4, seed = 2),
    letters[rsvidx(26, 4, seed = 2)]
  )
  expect_length(rsvsmp(1:100, 7, seed = 3), 7L)
  expect_true(all(rsvsmp(1:100, 7, seed = 3) %in% 1:100))

  expect_error(rsvidx(-1, 5), "non-negative")
  expect_error(rsvidx(10, -1), "non-negative")
})

test_that("HyperLogLog estimates cardinality within its error bound", {
  set.seed(43)
  # the published relative standard error is 1.04 / sqrt(m)
  p <- 12L
  m <- 2^p
  rse <- 1.04 / sqrt(m)
  for (true_n in c(1000L, 20000L, 100000L)) {
    x <- as.character(seq_len(true_n))
    est <- dstncnt(dstnskch(x, p = p))
    # inside four standard errors, which a broken sketch would not be
    expect_lt(abs(est - true_n) / true_n, 4 * rse)
  }

  # repeated values do not inflate the count
  x <- sample(1:5000, 50000, replace = TRUE)
  est <- dstncnt(dstnskch(x, p = 14L))
  expect_lt(abs(est - length(unique(x))) / length(unique(x)), 0.05)

  # small cardinalities go through linear counting and are near-exact
  expect_equal(
    dstncnt(dstnskch(c("a", "b", "c", "a", "b"))),
    3,
    tolerance = 0.01
  )
  expect_equal(dstncnt(dstnskch(as.character(1:50))), 50, tolerance = 0.02)
  expect_identical(dstncnt(dstnskch(character(0))), 0)
  expect_equal(dstncnt(dstnskch("only")), 1, tolerance = 0.01)
  # NA carries no value to count
  expect_equal(dstncnt(dstnskch(c("a", NA, "b"))), 2, tolerance = 0.01)

  # the sketch is deterministic, which is what makes a capsule
  # reproducible
  expect_identical(dstnskch(x, p = 10L), dstnskch(x, p = 10L))
  # registers are the right size and non-negative
  expect_length(dstnskch(x, p = 10L), 1024L)
  expect_true(all(dstnskch(x, p = 10L) >= 0))
  # numbers and strings agree when they render the same
  expect_identical(dstnskch(1:100), dstnskch(as.character(1:100)))

  # chunks fold into one sketch, and independent sketches merge, both
  # giving the same answer as one pass
  one <- dstnskch(x, p = 12L)
  folded <- dstnskch(x[1:25000], p = 12L)
  folded <- dstnskch(x[25001:50000], p = 12L, regstr = folded)
  expect_identical(folded, one)
  merged <- skchmrg(
    dstnskch(x[1:25000], p = 12L),
    dstnskch(x[25001:50000], p = 12L)
  )
  expect_identical(merged, one)
  expect_identical(dstncnt(merged), dstncnt(one))
  # merging is the element-wise maximum, so it is idempotent
  expect_identical(skchmrg(one, one), one)

  expect_error(dstnskch(x, p = 3L), "between 4 and 20")
  expect_error(dstnskch(x, p = 21L), "between 4 and 20")
  expect_error(dstnskch(x, p = 10L, regstr = 1:5), "2\\^p entries")
  expect_error(skchmrg(1:4, 1:8), "same number of registers")
})

test_that("onlsmry names itself when x is not numeric", {
  expect_error(onlsmry("a"), "onlsmry: `x` must be numeric")
  expect_s3_class(onlsmry(1:3), "bricklayer_online")
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("an accumulated summary prints as a box", {
  a <- onlsmry(c(1, 2, 3, 4))
  o1_expect_box(o1_box(a), a, "Accumulated summary", c("Mean", "2.5"))
})
