# SPDX-License-Identifier: AGPL-3.0-or-later

#' Fast summary statistics (C backend)
#'
#' @description
#' \code{cmn()}, \code{cvari()} and \code{ccorr()} compute the
#' mean, the sample variance and the Pearson correlation in compiled code.
#' They are thin R wrappers over the kernels in the package's C/C++ core,
#' the same ones that other packages call through
#' \code{LinkingTo: rmoriebricklayer}, so an R result and a compiled
#' result agree exactly. Use them where you want those shared kernels; for
#' everyday work \code{mean()}, \code{var()} and \code{cor()} give the same
#' numbers.
#'
#' @details
#' With \eqn{n} values,
#' \deqn{\bar x = \frac{1}{n}\sum_i x_i, \qquad
#'   s^2 = \frac{1}{n - 1}\sum_i (x_i - \bar x)^2, \qquad
#'   r = \frac{\sum_i (x_i - \bar x)(y_i - \bar y)}
#'   {\sqrt{\sum_i (x_i - \bar x)^2 \sum_i (y_i - \bar y)^2}}.}
#' The variance uses the \eqn{n - 1} (sample) denominator, as
#' \code{\link[stats]{var}} does. The mean is accumulated so that a sum of
#' finite values that would overflow a double (for example two values of
#' \code{1e308}) still gives the finite mean.
#'
#' There is no \code{na.rm}: any \code{NA} or \code{NaN} gives \code{NA} or
#' \code{NaN}; remove missing values first, for example with
#' \code{\link[stats]{na.omit}}. Edge cases return \code{NaN} rather than an
#' error: an empty vector for the mean, fewer than two values for the
#' variance, and a constant vector for the correlation.
#'
#' Errors: input that is a character vector, factor, list or data frame
#' (logical input is accepted and read as 0/1); \code{x} and \code{y} of
#' different lengths in \code{ccorr()}.
#'
#' @param x,y Numeric (or logical) vectors. \code{ccorr()} needs
#'   \code{x} and \code{y} of the same length.
#' @return \code{cmn()}, \code{cvari()} and \code{ccorr()} each
#'   return a length-1 numeric.
#' @seealso \code{\link{cnormpdf}}, \code{\link{csha256}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' ## cmn(): sample mean (NA/NaN propagate; no na.rm)
#' cmn(1:10)                 # 5.5
#' cmn(c(1, 2, NA))          # NA -- call stats::na.omit() first if needed
#' cmn(stats::na.omit(c(1, 2, NA)))
#' cmn(c(1e308, 1e308))      # no overflow
#'
#' ## cvari(): n-1 (sample) variance, matching stats::var()
#' cvari(c(2, 4, 4, 4, 5, 5, 7, 9))
#' all.equal(cvari(1:10), stats::var(1:10))   # agrees with base R
#'
#' ## ccorr(): Pearson correlation of two equal-length vectors
#' ccorr(1:10, (1:10)^2)        # strong positive, near 0.97
#' ccorr(1:10, 10:1)            # perfect negative: -1
#'
#' ## refusals
#' try(cmn(c("1", "2")))     # character input is not coerced
#' try(ccorr(1:3, 1:4))         # lengths differ
#' @useDynLib rmoriebricklayer, .registration = TRUE
#' @name cstat
#' @export
#' @srrstats {G2.2} .rmbl_num_input refuses data frames and lists for a vector argument; test-input-contracts.R:
#'   cmn(data.frame(a = 1)) errors "must be numeric".
#' @srrstats {G2.4b} .rmbl_num_input() converts with as.numeric() after refusing text, factor and list; logical is
#'   read as 0/1 (test-input-contracts.R).
#' @srrstats {G2.15} Never silently drops NA: NA/NaN propagate as documented ("There is no na.rm");
#'   test-input-contracts.R is.na(cmn(c(1, NA))).
#' @srrstats {EA2.6} .rmbl_num_input (R/aaa_input_guards.R) uses as.numeric(), which drops names, dims and extra
#'   attributes before the C kernels; factor, character and list input is refused.
cmn <- function(x) .Call(C_rmbl_mean, .rmbl_num_input(x, "x"))

#' @rdname cstat
#' @export
cvari <- function(x) .Call(C_rmbl_var, .rmbl_num_input(x, "x"))

#' @rdname cstat
#' @export
ccorr <- function(x, y) {
  x <- .rmbl_num_input(x, "x")
  y <- .rmbl_num_input(y, "y")
  if (length(x) != length(y)) stop("ccorr: `x` and `y` must have the same length", call. = FALSE)
  .Call(C_rmbl_cor, x, y)
}

#' Normal density (C backend)
#'
#' @description
#' Evaluates the density of the normal distribution with a given mean and
#' standard deviation at each value of \code{x}, in compiled code. It is the
#' same kernel that other packages reach through
#' \code{LinkingTo: rmoriebricklayer}, and for a positive standard deviation
#' it agrees with \code{\link[stats]{dnorm}}.
#'
#' @details
#' \deqn{f(x) = \frac{1}{\sigma\sqrt{2\pi}}
#'   \exp\left(-\frac{(x - \mu)^2}{2\sigma^2}\right).}
#' The function is vectorised over \code{x} only; \code{mean} must be a single
#' finite number and \code{sd} a single positive number, and anything else is
#' an error (\code{dnorm()} recycles them, and gives \code{Inf} or \code{NaN} for
#' \code{sd = 0} or below).
#' \code{NA} in \code{x} gives \code{NA}; \code{x = Inf} gives 0. Character,
#' factor or list input for \code{x} is an error.
#'
#' @param x Numeric vector of quantiles.
#' @param mean Number, default \code{0}: the mean \eqn{\mu}.
#' @param sd Number, default \code{1}: the standard deviation \eqn{\sigma};
#'   must be positive for a finite result.
#' @return A numeric vector the length of \code{x}.
#' @seealso \code{\link{cstat}}, \code{\link[stats]{dnorm}}.
#' @examplesIf interactive() || identical(Sys.getenv("IN_PKGDOWN"), "true")
#' # Standard normal density at a few quantiles.
#' cnormpdf(c(-1, 0, 1))
#'
#' # Peak of the standard normal is 1/sqrt(2*pi) at x = 0.
#' cnormpdf(0)
#'
#' # Shift and scale via mean and sd.
#' cnormpdf(c(0, 5, 10), mean = 5, sd = 2)
#'
#' # Identical to stats::dnorm().
#' all.equal(cnormpdf(-2:2, 0, 1), stats::dnorm(-2:2, 0, 1))
#'
#' # a non-positive sd and text are refused
#' try(cnormpdf(0, sd = 0))
#' try(cnormpdf("0"))
#' @export
cnormpdf <- function(x, mean = 0, sd = 1) {
  mean <- .rmbl_num(mean, "mean")
  sd <- .rmbl_num(sd, "sd")
  if (length(mean) != 1L || !is.finite(mean)) stop("cnormpdf: `mean` must be a single finite number", call. = FALSE)
  if (length(sd) != 1L || !is.finite(sd) || sd <= 0) stop("cnormpdf: `sd` must be a single positive number",
                                                          call. = FALSE)
  .Call(C_rmbl_normal_pdf, .rmbl_num_input(x, "x"), mean, sd)
}

#' SHA-256 hex digest (C backend)
#'
#' @description
#' Computes the SHA-256 hash (FIPS 180-4) of text or raw bytes with the
#' self-contained implementation in the package's compiled core, and returns
#' it as a 64-character lowercase hexadecimal string. A hash is a short
#' fingerprint: any change to the input changes it, so it is used throughout
#' the package to record exactly which data, mapping or file a result came
#' from. Sibling packages use the same routine through
#' \code{LinkingTo: rmoriebricklayer}.
#'
#' @details
#' For a raw vector the bytes are hashed as one message and one digest is
#' returned. Any other input is converted with \code{as.character()} and each
#' element is hashed separately, as the bytes of the string as stored in
#' memory (no re-encoding). In a UTF-8 session those are the UTF-8 bytes;
#' for a string marked latin1 they are the latin1 bytes, so use
#' \code{enc2utf8()} first when the digest must be the same on every
#' platform. \code{NA} gives \code{NA}. Numbers are hashed through their
#' printed form (\code{1} hashes as \code{"1"}), and a factor through its
#' labels.
#'
#' For a digest of a whole R object, hash its serialization (see the
#' examples) or use \code{\link{dgstobj}}; for BLAKE2b use
#' \code{\link{cblake2b}}.
#'
#' @param x A character vector, or a raw vector. Other atomic vectors are
#'   converted with \code{as.character()}.
#' @return A character vector of 64-character lowercase hex digests: one per
#'   element for character input, length 1 for raw input
#'   (\code{character(0)} for an empty character vector).
#' @references
#' National Institute of Standards and Technology (2015). Secure Hash
#' Standard (SHS). FIPS PUB 180-4.
#' \doi{10.6028/NIST.FIPS.180-4}
#' @examples
#' # Hash a character scalar (NIST test vector for "abc").
#' csha256("abc")
#' # ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
#'
#' # Vectorised over character input: one digest per element.
#' csha256(c("abc", "def", NA))
#'
#' # Raw input hashes the bytes directly; identical to the character form.
#' identical(csha256("abc"), csha256(charToRaw("abc")))
#'
#' # The empty message.
#' csha256(raw(0))
#'
#' # Fingerprint an arbitrary object via its serialization.
#' csha256(serialize(list(a = 1L, b = "x"), NULL))
#' @export
csha256 <- function(x) {
  .rmbl_no_fn(x = x)
  if (is.raw(x)) return(.Call(C_rmbl_sha256, x))
  x <- as.character(x)
  vapply(x, function(s) .Call(C_rmbl_sha256, s), character(1), USE.NAMES = FALSE)
}
