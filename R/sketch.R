# SPDX-License-Identifier: AGPL-3.0-or-later
#
# One-pass summaries for capsule members larger than memory. The moment
# accumulator is exact algebra -- chunked accumulation and a single batch pass
# agree to rounding -- while the cardinality sketch trades a bounded relative error
# for fixed memory.

#' Summary statistics accumulated in blocks
#'
#' An accumulator for the count, mean, variance, skewness and kurtosis of a
#' numeric column that does not fit in memory, or that arrives in pieces
#' (a file read in chunks, results from several machines). Start one with
#' \code{online_summary()}, feed it blocks with \code{summary_update()},
#' combine two with \code{summary_merge()} and read the result with
#' \code{summary_stats()}.
#'
#' @details
#' The merge is exact algebra, not an approximation: it uses Chan, Golub and
#' LeVeque's parallel combination of central sums, extended to the third and
#' fourth moments by Terriberry, so accumulating a column in blocks gives the
#' answer of [core_moments()]
#' over the whole column at once, to the rounding of
#' double arithmetic. Each block's sums are taken in two passes, as
#' \code{var()} takes them, so values far from zero keep their digits:
#' values near \eqn{10^8} with a spread of 1, in blocks of 100, give the
#' variance of \code{var()} to a relative \eqn{10^{-11}} (one pass lost
#' nine digits).
#' That is what makes it usable for a capsule member of any
#' size: memory stays constant in the number of blocks.
#'
#' The state is \eqn{(n, \bar{x}, M_2, M_3, M_4)} with
#' \eqn{M_k = \sum (x_i - \bar{x})^k}. \code{summary_stats()} reports the
#' sample variance \eqn{M_2 / (n - 1)}, the moment skewness
#' \eqn{g_1 = (M_3/n) / (M_2/n)^{3/2}} and the excess kurtosis
#' \eqn{g_2 = (M_4/n) / (M_2/n)^2 - 3} (the biased moment estimators, without
#' small-sample correction). \code{NA} values are dropped from every block.
#' Undefined quantities are \code{NaN}: the mean for \eqn{n = 0}, the variance
#' for \eqn{n < 2}, the skewness for \eqn{n < 3} and the kurtosis for
#' \eqn{n < 4}, and both shape statistics for a constant column.
#'
#' The object is a plain list and is copied on assignment like any other R
#' value, so \code{summary_update()} returns the new accumulator and you must
#' keep it: \code{acc <- summary_update(acc, block)}.
#'
#' Errors: a block that is not numeric; an accumulator that does not come
#' from \code{online_summary()}.
#'
#' @param x Numeric vector: the first block, or \code{NULL} (the default) for
#'   an empty accumulator; for \code{summary_update()}, the next block.
#' @param acc,a,b Accumulators from \code{online_summary()}.
#' @return \code{online_summary()}, \code{summary_update()} and
#'   \code{summary_merge()} return an object of class
#'   \code{c("bricklayer_online", "list")} (its \code{state} element is the
#'   numeric vector described in Details); \code{summary_stats()} returns a
#'   named numeric vector with \code{n}, \code{mean}, \code{variance},
#'   \code{sd}, \code{skewness} and \code{kurtosis} (excess).
#' @references Chan TF, Golub GH, LeVeque RJ (1983). Algorithms for
#' computing the sample variance: analysis and recommendations.
#'   *The American Statistician* 37(3), 242--247.
#'   \doi{10.1080/00031305.1983.10483115}
#' @seealso [core_moments()] for the single-pass
#' batch version.
#' @examples
#' set.seed(1)
#' x <- stats::rnorm(1000)
#'
#' # Accumulate in blocks of 100.
#' acc <- online_summary()
#' for (i in seq(1, 1000, by = 100)) {
#'   acc <- summary_update(acc, x[i:(i + 99)])
#' }
#' summary_stats(acc)
#'
#' # The batch answer to rounding (the formulas are exact; the arithmetic is double):
#' all.equal(summary_stats(acc)[["variance"]], stats::var(x))
#' all.equal(summary_stats(acc)[["mean"]], mean(x))
#'
#' # Two accumulators built independently can be merged, so blocks can be
#' # processed in any order or on different machines.
#' a <- summary_update(online_summary(), x[1:400])
#' b <- summary_update(online_summary(), x[401:1000])
#' all.equal(summary_stats(summary_merge(a, b)), summary_stats(acc))
#'
#' # An empty accumulator reports nothing rather than zero.
#' summary_stats(online_summary())
#'
#' # NA values are skipped; text is refused
#' summary_stats(online_summary(c(1, NA, 3)))[c("n", "mean")]
#' try(online_summary(c("1", "2")))
#' @name rmbl_online
#' @export
online_summary <- function(x = NULL) {
  acc <- structure(list(state = c(0, 0, 0, 0, 0)),
                   class = c("bricklayer_online", "list"))
  if (is.null(x)) return(acc)
  summary_update(acc, x)
}

#' @rdname rmbl_online
#' @export
summary_update <- function(acc, x) {
  if (!inherits(acc, "bricklayer_online")) {
    stop("`acc` must come from online_summary()", call. = FALSE)
  }
  x <- .rmbl_num(x, "x")
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(acc)
  block <- .Call(C_rmbl_moments_acc, x)
  acc$state <- .Call(C_rmbl_moments_merge, acc$state, block)
  acc
}

#' @rdname rmbl_online
#' @export
summary_merge <- function(a, b) {
  if (!inherits(a, "bricklayer_online") ||
      !inherits(b, "bricklayer_online")) {
    stop("both arguments must come from online_summary()", call. = FALSE)
  }
  a$state <- .Call(C_rmbl_moments_merge, a$state, b$state)
  a
}

#' @rdname rmbl_online
#' @export
summary_stats <- function(acc) {
  if (!inherits(acc, "bricklayer_online")) {
    stop("`acc` must come from online_summary()", call. = FALSE)
  }
  s <- acc$state
  n <- s[1L]
  variance <- if (n > 1) s[3L] / (n - 1) else NaN
  m2 <- if (n > 0) s[3L] / n else NaN
  skew <- if (n > 2 && s[3L] > 0) (s[4L] / n) / m2^1.5 else NaN
  kurt <- if (n > 3 && s[3L] > 0) (s[5L] / n) / (m2 * m2) - 3 else NaN
  c(n = n, mean = if (n > 0) s[2L] else NaN, variance = variance,
    sd = sqrt(variance), skewness = skew, kurtosis = kurt)
}

#' @export
print.bricklayer_online <- function(x, ...) {
  s <- summary_stats(x)
  cat(.rmbl_rule("Accumulated summary"), "\n")
  cat(.rmbl_kv(list(
    n = format(s[["n"]], big.mark = ","),
    mean = formatC(s[["mean"]], format = "g", digits = 6),
    sd = formatC(s[["sd"]], format = "g", digits = 6),
    skewness = formatC(s[["skewness"]], format = "g", digits = 4),
    kurtosis = formatC(s[["kurtosis"]], format = "g", digits = 4))),
    sep = "\n")
  cat(.rmbl_rule(), "\n")
  invisible(x)
}

#' Uniform sample of a stream in one pass
#'
#' Vitter's Algorithm R: draws \code{k} items from a stream, each item
#' equally likely to be retained, in a single pass and using memory
#' proportional to \code{k} rather than to the stream's length. Use it to
#' take a fair sample of a capsule member you cannot hold, or whose length
#' you do not know in advance.
#'
#' \code{reservoir_indices()} returns the retained positions, so the same
#' sample can be applied to a file read line by line.
#' \code{reservoir_sample()} applies it to a vector in memory.
#'
#' @details
#' The first \code{k} items fill the reservoir; item \eqn{i > k} then
#' replaces a uniformly chosen slot with probability \eqn{k / i}, so after
#' \eqn{n} items every item is in the sample with probability \eqn{k / n}
#' (Vitter 1985). The positions are returned sorted.
#'
#' The stream is sampled with the core's own generator seeded by
#' \code{seed}, not R's, so the sample is reproducible and R's random
#' stream is left alone -- a capsule whose sample changed between runs
#' would not be reproducible. The generator is C++ \code{std::mt19937_64},
#' whose output sequence the C++ standard fixes, and each draw is Lemire's
#' unbiased multiply-and-reject on its 64-bit outputs (Lemire 2019), so the
#' same seed gives the same sample on every platform and C++ library.
#' Versions up to 0.5.12 drew with \code{std::uniform_int_distribution},
#' whose algorithm differs between C++ libraries, so their samples for a
#' seed differ from these.
#'
#' Errors: \code{n} or \code{k} not one non-negative whole number;
#' \code{n} above \eqn{2^{53}}; \code{k} above \eqn{10^8}; \code{seed}
#' not a whole number from 0 to below \eqn{2^{53}} (\code{NA} included).
#'
#' @param x Vector to sample from.
#' @param n Length of the stream, one non-negative number.
#' @param k Sample size, one non-negative number. Values above the stream
#'   length give the whole stream; 0 gives an empty result.
#' @param seed Seed for the core's generator, a whole number from 0 to below
#'   \eqn{2^{53}} (default 42).
#' @return \code{reservoir_indices()} a sorted numeric (double) vector of
#'   1-based positions, of length \code{min(k, n)}; \code{reservoir_sample()}
#'   the corresponding elements of \code{x}, in their original order.
#' @references Vitter JS (1985). Random sampling with a reservoir.
#'   *ACM Transactions on Mathematical Software* 11(1), 37--57.
#'   \doi{10.1145/3147.3165}
#'
#'   Lemire D (2019). Fast random integer generation in an interval.
#'   *ACM Transactions on Modeling and Computer Simulation* 29(1), 3.
#'   \doi{10.1145/3230636}
#' @examples
#' # A reproducible sample of 5 from 1000.
#' reservoir_indices(1000, 5, seed = 1)
#' reservoir_sample(letters, 4, seed = 2)
#'
#' # Reproducible on every platform, and independent of R's own RNG.
#' identical(reservoir_indices(1000, 5, seed = 1),
#'           reservoir_indices(1000, 5, seed = 1))
#'
#' # Asking for more than the stream holds returns the whole stream.
#' reservoir_indices(3, 10)
#'
#' # Every item is equally likely: over many seeds the retained positions
#' # are spread uniformly rather than favouring the start or the end.
#' hits <- unlist(lapply(1:400, function(s) reservoir_indices(50, 5, s)))
#' round(mean(hits))          # near the midpoint, 25.5
#'
#' # sample rows of a data frame
#' df <- data.frame(id = 1:20, v = (1:20)^2)
#' df[reservoir_indices(nrow(df), 3, seed = 7), ]
#'
#' # a negative size is refused
#' try(reservoir_indices(10, -1))
#' @name rmbl_reservoir
#' @export
reservoir_indices <- function(n, k, seed = 42L) {
  n <- .rmbl_num(n, "n")
  k <- .rmbl_num(k, "k")
  if (length(n) != 1L || is.na(n) || !is.finite(n) || n < 0 || n != floor(n)) {
    stop("`n` must be a single non-negative whole number", call. = FALSE)
  }
  if (length(k) != 1L || is.na(k) || !is.finite(k) || k < 0 || k != floor(k)) {
    stop("`k` must be a single non-negative whole number", call. = FALSE)
  }
  if (k > .Machine$integer.max) stop("`k` must be at most 2147483647", call. = FALSE)
  seed <- .rmbl_seed(seed)
  .Call(C_rmbl_reservoir, n, k, seed)
}

#' @rdname rmbl_reservoir
#' @export
reservoir_sample <- function(x, k, seed = 42L) {
  .rmbl_no_fn(x = x)
  idx <- reservoir_indices(length(x), k, seed)
  x[idx]
}

#' Distinct-value count in fixed memory
#'
#' HyperLogLog: estimates how many distinct values a column holds using a
#' fixed 4-byte register per bucket -- 64 KB at the default \code{p = 14}
#' -- regardless of the column's length or cardinality. Exact counting
#' needs memory proportional to the number of distinct values, which is the
#' thing you cannot afford on a capsule member of unknown size.
#' \code{distinct_sketch()} builds or extends the registers,
#' \code{distinct_count()} turns them into an estimate, and
#' \code{sketch_merge()} combines two sketches.
#'
#' @details
#' Each value is hashed and the first \code{p} bits pick one of \eqn{m = 2^p}
#' registers; the register keeps the longest run of leading zeros (plus one)
#' seen in the remaining bits. The estimate is the bias-corrected harmonic
#' mean \eqn{\alpha_m m^2 / \sum_j 2^{-M_j}} of Flajolet et al. (2007).
#'
#' The estimate carries a relative standard error of about
#' \code{1.04 / sqrt(2^p)}, so 0.8% at the default. It is an ESTIMATE: use
#' \code{length(unique(x))} when the column fits in memory and an exact
#' answer matters. Below roughly \code{2.5 * 2^p} distinct values the
#' estimator switches to linear counting, which is near-exact in that
#' range (the estimate of one value is about 1.00003, not 1).
#'
#' Values are hashed with the package's SHA-256, so the sketch is identical
#' on every platform and across sessions. Values are compared as text
#' (\code{as.character()}), so \code{1}, \code{1.0} and \code{"1"} are one
#' value. Long vectors are processed in blocks of a million with a progress
#' bar on stderr unless \code{options(morie.quiet = TRUE)}; the registers are
#' the same as in one pass. Since a register only keeps a maximum, folding
#' chunks with \code{registers} and merging separate sketches with
#' \code{sketch_merge()} give the same registers as one sketch of all the
#' data.
#'
#' Errors: \code{p} not a whole number from 4 to 20; \code{registers} not of
#' length \eqn{2^p}; registers that are not whole numbers from 0 to 64; two
#' sketches of different sizes.
#'
#' @param x A vector; coerced to character, since distinctness is
#'   compared on the rendered value. \code{NA} is skipped.
#' @param p Log2 of the register count, a whole number from 4 to 20
#'   (default 14, so 16,384 registers). Larger \code{p} is more precise and
#'   uses more memory.
#' @param registers Registers from a previous call (with the same \code{p}),
#'   to fold another chunk into the same sketch; \code{NULL} (the default)
#'   starts a new one. For \code{distinct_count()}, the registers to estimate
#'   from.
#' @return \code{distinct_sketch()} an integer vector of \eqn{2^p} registers;
#'   \code{distinct_count()} a length-1 numeric estimate (0 for an empty or
#'   \code{NULL} sketch); \code{sketch_merge()} the element-wise maximum of two
#'   register sets, an integer vector.
#' @references Flajolet P, Fusy E, Gandouet O, Meunier F (2007).
#' HyperLogLog: the analysis of a near-optimal cardinality estimation
#' algorithm. *Analysis of Algorithms 2007*, 137--156.
#' @examples
#' set.seed(1)
#' x <- sample(1:5000, 200000, replace = TRUE)
#'
#' # Close to the true 5000 distinct values, in fixed memory.
#' distinct_count(distinct_sketch(x))
#' length(unique(x))
#'
#' # Small cardinalities are near-exact, via linear counting.
#' distinct_count(distinct_sketch(c("a", "b", "c", "a", "b")))
#'
#' # Chunks fold into one sketch, so a file can be counted block by
#' # block, and two independent sketches can be merged.
#' s <- distinct_sketch(x[1:100000])
#' s <- distinct_sketch(x[100001:200000], registers = s)
#' distinct_count(s)
#'
#' a <- distinct_sketch(x[1:100000])
#' b <- distinct_sketch(x[100001:200000])
#' distinct_count(sketch_merge(a, b))
#'
#' # An empty input has no distinct values.
#' distinct_count(distinct_sketch(character(0)))
#'
#' # a smaller sketch: less memory, more error
#' distinct_count(distinct_sketch(x, p = 8))
#'
#' # sketches of different sizes cannot be merged
#' try(sketch_merge(distinct_sketch(1:10, p = 4), distinct_sketch(1:10, p = 5)))
#' @name rmbl_distinct
#' @export
distinct_sketch <- function(x, p = 14L, registers = NULL) {
  .rmbl_no_fn(x = x)
  p <- .rmbl_num(p, "p", integer = TRUE)
  if (length(p) != 1L || is.na(p) || p < 4L || p > 20L) {
    stop("`p` must be a single integer between 4 and 20", call. = FALSE)
  }
  if (!is.null(registers)) {
    registers <- .rmbl_num(registers, "registers", integer = TRUE)
    if (length(registers) != bitwShiftL(1L, p)) {
      stop("`registers` must have 2^p entries, from a sketch with the ",
           "same `p`", call. = FALSE)
    }
  }
  # in blocks of a million, so a long vector shows its progress (a register keeps its maximum,
  # so the blocks give exactly the registers of one pass)
  n <- length(x)
  if (n <= 1e6) return(.Call(C_rmbl_hll_add, as.character(x), p, registers))
  pg <- bricklayer_progress("distinct sketch", n)
  on.exit(pg$done(), add = TRUE)
  for (s in seq.int(1, n, by = 1e6)) {
    e <- min(n, s + 1e6 - 1)
    registers <- .Call(C_rmbl_hll_add, as.character(x[s:e]), p, registers)
    pg$update(e, sprintf("%s of %s values", .bl_n(e), .bl_n(n)))
  }
  registers
}

#' @rdname rmbl_distinct
#' @export
distinct_count <- function(registers) {
  if (is.null(registers) || length(registers) == 0L) return(0)
  registers <- .rmbl_registers(registers, "registers")
  .Call(C_rmbl_hll_count, registers)
}

#' @param a,b Register sets to merge.
#' @rdname rmbl_distinct
#' @export
sketch_merge <- function(a, b) {
  a <- .rmbl_registers(a, "a")
  b <- .rmbl_registers(b, "b")
  if (length(a) != length(b)) {
    stop("both sketches must have the same number of registers", call. = FALSE)
  }
  # A register holds the longest leading-zero run seen for its bucket, so
  # the union of two streams is the element-wise maximum.
  pmax(a, b)
}

# HyperLogLog registers: non-negative integers.
.rmbl_registers <- function(r, what) {
  r <- .rmbl_num_input(r, what)
  if (any(!is.finite(r)) || any(r < 0) || any(r > 64) || any(r != floor(r))) {
    stop(sprintf("`%s` must be non-negative integer registers", what),
      call. = FALSE
    )
  }
  as.integer(r)
}
