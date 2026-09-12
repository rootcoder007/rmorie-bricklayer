# SPDX-License-Identifier: AGPL-3.0-or-later
#
# One-pass summaries for capsule members larger than memory. The moment
# accumulator is EXACT -- chunked accumulation and a single batch pass
# agree -- while the cardinality sketch trades a bounded relative error
# for fixed memory.

#' Exact summary statistics accumulated in blocks
#'
#' An accumulator for the mean, variance, skewness and kurtosis of a column
#' that does not fit in memory. Feed it blocks with
#' [summary_update()] and read the result with
#' [summary_stats()].
#'
#' The merge is EXACT, not approximate: it uses Chan, Golub and LeVeque's
#' parallel combination of central sums, extended to the third and fourth
#' moments by Terriberry, so accumulating a column in blocks gives the same
#' answer as [core_moments()] over the whole
#' column at once. That is what makes it usable for a capsule member of any
#' size: memory stays constant in the number of blocks.
#'
#' The object is a plain list and is copied on assignment like any other R
#' value, so `update` returns the new accumulator and you must keep
#' it: `acc <- summary_update(acc, block)`.
#'
#' @param x Numeric vector: the first block, or `NULL` for an
#' empty accumulator.
#' @param acc,a,b Accumulators from `online_summary()`.
#' @return `online_summary()`, `summary_update()` and
#' `summary_merge()` return an object of class
#' `bricklayer_online`; `summary_stats()` returns a named numeric
#' with `n`, `mean`, `variance`, `sd`, `skewness`
#' and `kurtosis`.
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
#' # Which is exactly the batch answer, not an approximation to it.
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
  x <- as.numeric(x)
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
#' Vitter's Algorithm R: draws `k` items from a stream, each item
#' equally likely to be retained, in a single pass and using memory
#' proportional to `k` rather than to the stream's length. Use it to
#' take a fair sample of a capsule member you cannot hold, or whose length
#' you do not know in advance.
#'
#' `reservoir_indices()` returns the retained positions, so the same
#' sample can be applied to a file read line by line.
#' `reservoir_sample()` applies it to a vector in memory.
#'
#' The stream is sampled with the core's own generator seeded by
#' `seed`, not R's, so the sample is reproducible and R's random
#' stream is left alone -- a capsule whose sample changed between runs
#' would not be reproducible.
#'
#' @param x Vector to sample from.
#' @param n Length of the stream.
#' @param k Sample size. Values above the stream length give the
#' whole stream.
#' @param seed Seed for the core's generator (default 42).
#' @return `reservoir_indices()` a sorted numeric vector of 1-based
#' positions; `reservoir_sample()` the corresponding elements of
#' `x`.
#' @references Vitter JS (1985). Random sampling with a reservoir.
#'   *ACM Transactions on Mathematical Software* 11(1), 37--57.
#'   \doi{10.1145/3147.3165}
#' @examples
#' # A reproducible sample of 5 from 1000.
#' reservoir_indices(1000, 5, seed = 1)
#' reservoir_sample(letters, 4, seed = 2)
#'
#' # Reproducible, and independent of R's own RNG.
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
#' @name rmbl_reservoir
#' @export
reservoir_indices <- function(n, k, seed = 42L) {
  n <- as.numeric(n)
  k <- as.numeric(k)
  if (length(n) != 1L || is.na(n) || n < 0) {
    stop("`n` must be a single non-negative number", call. = FALSE)
  }
  if (length(k) != 1L || is.na(k) || k < 0) {
    stop("`k` must be a single non-negative number", call. = FALSE)
  }
  .Call(C_rmbl_reservoir, n, k, as.numeric(seed))
}

#' @rdname rmbl_reservoir
#' @export
reservoir_sample <- function(x, k, seed = 42L) {
  idx <- reservoir_indices(length(x), k, seed)
  x[idx]
}

#' Distinct-value count in fixed memory
#'
#' HyperLogLog: estimates how many distinct values a column holds using a
#' fixed 4-byte register per bucket -- 64 KB at the default `p = 14`
#' -- regardless of the column's length or cardinality. Exact counting
#' needs memory proportional to the number of distinct values, which is the
#' thing you cannot afford on a capsule member of unknown size.
#'
#' The estimate carries a relative standard error of about
#' `1.04 / sqrt(2^p)`, so 0.8% at the default. It is an ESTIMATE: use
#' `length(unique(x))` when the column fits in memory and an exact
#' answer matters. Below roughly `2.5 * 2^p` distinct values the
#' estimator switches to linear counting, which is near-exact in that
#' range.
#'
#' Values are hashed with the package's SHA-256, so the sketch is identical
#' on every platform and across sessions.
#'
#' @param x A vector; coerced to character, since distinctness is
#' compared on the rendered value. `NA` is skipped.
#' @param p Log2 of the register count, 4 to 20 (default 14).
#' @param registers Registers from a previous call, to
#' fold another chunk into the same sketch.
#' @return `distinct_sketch()` an integer vector of registers;
#' `distinct_count()` a length-1 numeric estimate;
#' `sketch_merge()` the element-wise maximum of two register sets.
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
#' @name rmbl_distinct
#' @export
distinct_sketch <- function(x, p = 14L, registers = NULL) {
  p <- as.integer(p)
  if (length(p) != 1L || is.na(p) || p < 4L || p > 20L) {
    stop("`p` must be a single integer between 4 and 20", call. = FALSE)
  }
  if (!is.null(registers)) {
    registers <- as.integer(registers)
    if (length(registers) != bitwShiftL(1L, p)) {
      stop("`registers` must have 2^p entries, from a sketch with the ",
           "same `p`", call. = FALSE)
    }
  }
  .Call(C_rmbl_hll_add, as.character(x), p, registers)
}

#' @rdname rmbl_distinct
#' @export
distinct_count <- function(registers) {
  registers <- as.integer(registers)
  if (length(registers) == 0L) return(0)
  .Call(C_rmbl_hll_count, registers)
}

#' @param a,b Register sets to merge.
#' @rdname rmbl_distinct
#' @export
sketch_merge <- function(a, b) {
  a <- as.integer(a)
  b <- as.integer(b)
  if (length(a) != length(b)) {
    stop("both sketches must have the same number of registers", call. = FALSE)
  }
  # A register holds the longest leading-zero run seen for its bucket, so
  # the union of two streams is the element-wise maximum.
  pmax(a, b)
}
