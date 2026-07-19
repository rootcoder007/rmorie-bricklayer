# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fast summary statistics (C backend)
#'
#' Thin R wrappers over the `rmoriebricklayer` compiled core -- the same
#' kernels that sibling packages reach through `LinkingTo:
#' rmoriebricklayer`. NA/NaN values propagate (there is no `na.rm`); call
#' [stats::na.omit()] first if you need NA handling.
#'
#' @param x,y Numeric vectors (coerced with [as.numeric()]).
#' @return `core_mean()`, `core_var()` and `core_cor()` return a length-1
#'   numeric. `core_var()` uses the `n - 1` (sample) denominator, matching
#'   [stats::var()].
#' @examples
#' ## core_mean(): sample mean (NA/NaN propagate; no na.rm)
#' core_mean(1:10)                 # 5.5
#' core_mean(c(2.5, 3.5))          # 3
#' core_mean(c(1, 2, NA))          # NA -- call stats::na.omit() first if needed
#' core_mean(stats::na.omit(c(1, 2, NA)))
#'
#' ## core_var(): n-1 (sample) variance, matching stats::var()
#' core_var(c(2, 4, 4, 4, 5, 5, 7, 9))
#' all.equal(core_var(1:10), stats::var(1:10))   # agrees with base R
#'
#' ## core_cor(): Pearson correlation of two equal-length vectors
#' core_cor(1:10, (1:10)^2)        # strong positive, near 0.97
#' core_cor(1:10, 10:1)            # perfect negative: -1
#' @useDynLib rmoriebricklayer, .registration = TRUE
#' @name rmbl_core_stats
#' @export
core_mean <- function(x) .Call(C_rmbl_mean, as.numeric(x))

#' @rdname rmbl_core_stats
#' @export
core_var <- function(x) .Call(C_rmbl_var, as.numeric(x))

#' @rdname rmbl_core_stats
#' @export
core_cor <- function(x, y) .Call(C_rmbl_cor, as.numeric(x), as.numeric(y))

#' Normal density (C backend)
#'
#' Vectorised over `x`; `mean` and `sd` are length-1.
#'
#' @param x Numeric vector of quantiles.
#' @param mean Distribution mean (length-1, default 0).
#' @param sd Distribution standard deviation (length-1, default 1, > 0).
#' @return A numeric vector the length of `x`. Equivalent to
#'   `stats::dnorm(x, mean, sd)`.
#' @examples
#' # Standard normal density at a few quantiles.
#' core_normal_pdf(c(-1, 0, 1))
#'
#' # Peak of the standard normal is 1/sqrt(2*pi) at x = 0.
#' core_normal_pdf(0)
#'
#' # Shift and scale via `mean` and `sd`.
#' core_normal_pdf(5, mean = 5, sd = 2)       # peak of N(5, 2)
#' core_normal_pdf(c(0, 5, 10), mean = 5, sd = 2)
#'
#' # Identical to stats::dnorm().
#' all.equal(core_normal_pdf(-2:2, 0, 1), stats::dnorm(-2:2, 0, 1))
#' @export
core_normal_pdf <- function(x, mean = 0, sd = 1) {
  .Call(C_rmbl_normal_pdf, as.numeric(x), as.numeric(mean), as.numeric(sd))
}

#' SHA-256 hex digest (C backend)
#'
#' Hashes character or raw input with the self-contained SHA-256 in the
#' `rmoriebricklayer` core. For a character vector each element is hashed
#' as its UTF-8/native bytes; for a raw vector the raw bytes are hashed.
#' This is the same routine sibling packages use for provenance via
#' `LinkingTo: rmoriebricklayer`.
#'
#' @param x A character vector or a raw vector.
#' @return A character vector of 64-character lowercase hex digests (one
#'   per element for character input; length-1 for raw input).
#' @examples
#' # Hash a character scalar (NIST test vector for "abc").
#' core_sha256("abc")
#' # ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
#'
#' # Vectorised over character input: one digest per element.
#' core_sha256(c("abc", "def"))
#'
#' # Raw input hashes the bytes directly; identical to the character form.
#' identical(core_sha256("abc"), core_sha256(charToRaw("abc")))
#'
#' # Fingerprint an arbitrary object via its serialization.
#' core_sha256(serialize(list(a = 1L, b = "x"), NULL))
#' @export
core_sha256 <- function(x) {
  if (is.raw(x)) return(.Call(C_rmbl_sha256, x))
  x <- as.character(x)
  vapply(x, function(s) .Call(C_rmbl_sha256, s), character(1), USE.NAMES = FALSE)
}
