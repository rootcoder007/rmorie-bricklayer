# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The CTR_DRBG of NIST SP 800-90A Rev. 1 with AES-256 and no derivation function: deterministic
# random bits from 48 bytes of entropy. It is the generator the NIST post-quantum known-answer
# tests are written with, so a seed from one of their .rsp files reproduces their randomness.

#' A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP 800-90A)
#'
#' Creates the counter-mode DRBG of NIST SP 800-90A Rev. 1, section 10.2.1,
#' with AES-256 and no derivation function, implemented in this package (no
#' system library). From the same entropy, personalization and additional
#' inputs it returns the same bytes, which is what reproducible key generation
#' and known-answer tests need; for keys meant to stay secret, seed it from
#' [random_bytes()] (the default) or use
#' [random_bytes()] directly.
#'
#' It reproduces all 720 AES-256 no-df vectors of NIST's DRBG validation suite
#' (without reseeding, with reseeding, and with prediction resistance; the
#' package's tests check a sample of them), and it is the `randombytes()` of
#' NIST's `rng.c`, with which most post-quantum submissions wrote their
#' known-answer files: `drbg_new(as.raw(0:47))` followed by
#' `drbg_generate(d, 48)` gives the `seed` of their vector 0. AES runs in
#' constant time: the S-box is computed (an inversion in GF(2^8) and the affine
#' map) rather than looked up, and on x86-64 processors with AES-NI the rounds
#' use those instructions.
#'
#' The generator is an object that changes as it is used: every
#' [drbg_generate()] and
#' [drbg_reseed()] advances it in place.
#'
#' @param entropy Entropy input: 48 bytes, raw or hex. `NULL` (the default)
#'   draws them from the operating system's CSPRNG.
#' @param personalization Optional personalization string of up to 48 bytes, raw or hex.
#' @return An object of class `bricklayer_drbg`. Its state (Key, V) is not printed.
#' @references NIST SP 800-90A Rev. 1 (2015). Recommendation for Random Number Generation
#'   Using Deterministic Random Bit Generators, section 10.2.1. \doi{10.6028/NIST.SP.800-90Ar1}
#'
#'   NIST FIPS 197 (2001, updated 2023). Advanced Encryption Standard (AES).
#'   \doi{10.6028/NIST.FIPS.197-upd1}
#' @seealso [drbg_generate()], [drbg_reseed()],
#'   [random_bytes()].
#' @examples
#' # NIST's rng.c, as the post-quantum known-answer files use it: vector 0's seed
#' d <- drbg_new(as.raw(0:47))
#' drbg_generate(d, 48)
#'
#' # the same inputs give the same bytes; a personalization string separates streams
#' a <- drbg_new(as.raw(1:48), personalization = charToRaw("session 1"))
#' b <- drbg_new(as.raw(1:48), personalization = charToRaw("session 2"))
#' identical(drbg_generate(a, 16), drbg_generate(b, 16))
#'
#' # seeded from the operating system
#' d <- drbg_new()
#' length(drbg_generate(d, 32))
#' @export
drbg_new <- function(entropy = NULL, personalization = NULL) {
  entropy <- if (is.null(entropy)) random_bytes(48L) else .rmbl_drbg_input(entropy, "entropy", 48L, exact = TRUE)
  pers <- .rmbl_drbg_input(personalization, "personalization", 48L)
  st <- .Call(C_rmbl_drbg_instantiate, entropy, pers)
  d <- new.env(parent = emptyenv())
  d$key <- st$key
  d$v <- st$v
  d$reseed_counter <- 1
  class(d) <- "bricklayer_drbg"
  d
}

#' Draw bytes from a DRBG
#'
#' Generates `n` bytes (SP 800-90A's Generate function) and advances the generator.
#'
#' @param drbg A generator from [drbg_new()].
#' @param n Number of bytes, 1 to 65536 (the standard's limit per request for
#'   AES: 2^19 bits).
#' @param additional Optional additional input of up to 48 bytes, raw or hex, mixed into the
#'   state before and after the output.
#' @return A raw vector of `n` bytes.
#' @seealso [drbg_new()], [drbg_reseed()].
#' @examples
#' d <- drbg_new(as.raw(0:47))
#' x <- drbg_generate(d, 16)
#' y <- drbg_generate(d, 16)
#' identical(x, y)  # the state moved on
#'
#' # additional input changes the output and the state
#' e <- drbg_new(as.raw(0:47))
#' identical(drbg_generate(e, 16, additional = "00ff"), x)
#' @export
drbg_generate <- function(drbg, n, additional = NULL) {
  .rmbl_drbg_check(drbg)
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 1L || n > 65536L) {
    stop("`n` must be a single integer between 1 and 65536", call. = FALSE)
  }
  if (drbg$reseed_counter > 2^48) {
    stop("the generator has served 2^48 requests since it was seeded: reseed it (drbg_reseed())",
         call. = FALSE)
  }
  st <- .Call(C_rmbl_drbg_generate, drbg$key, drbg$v, as.integer(n),
              .rmbl_drbg_input(additional, "additional", 48L))
  drbg$key <- st$key
  drbg$v <- st$v
  drbg$reseed_counter <- drbg$reseed_counter + 1
  st$out
}

#' Reseed a DRBG
#'
#' Mixes fresh entropy into the generator (SP 800-90A's Reseed function) and
#' resets its request count.
#'
#' @inheritParams drbg_generate
#' @param entropy Entropy input: 48 bytes, raw or hex; `NULL` draws them from
#'   the operating system's CSPRNG.
#' @param additional Optional additional input of up to 48 bytes, raw or hex.
#' @return `drbg`, invisibly, reseeded in place.
#' @seealso [drbg_new()], [drbg_generate()].
#' @examples
#' d <- drbg_new(as.raw(0:47))
#' drbg_reseed(d, as.raw(48:95))
#' drbg_generate(d, 8)
#' @export
drbg_reseed <- function(drbg, entropy = NULL, additional = NULL) {
  .rmbl_drbg_check(drbg)
  entropy <- if (is.null(entropy)) random_bytes(48L) else .rmbl_drbg_input(entropy, "entropy", 48L, exact = TRUE)
  st <- .Call(C_rmbl_drbg_reseed, drbg$key, drbg$v, entropy, .rmbl_drbg_input(additional, "additional", 48L))
  drbg$key <- st$key
  drbg$v <- st$v
  drbg$reseed_counter <- 1
  invisible(drbg)
}

#' @export
format.bricklayer_drbg <- function(x, ...) {
  c(.rmbl_rule("Deterministic random bit generator"),
    .rmbl_kv(list(mechanism = "CTR_DRBG, AES-256, no derivation function (SP 800-90A)",
                  "requests since seeding" = format(x$reseed_counter - 1, scientific = FALSE),
                  state = "<withheld>")),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_drbg <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

.rmbl_drbg_check <- function(drbg) {
  if (!inherits(drbg, "bricklayer_drbg") || !is.environment(drbg) ||
      !is.raw(drbg$key) || length(drbg$key) != 32L || !is.raw(drbg$v) || length(drbg$v) != 16L) {
    stop("`drbg` must come from drbg_new()", call. = FALSE)
  }
}

# raw or hex; NULL is the empty string; at most `max` bytes (exactly, when `exact`)
.rmbl_drbg_input <- function(x, what, max, exact = FALSE) {
  if (is.null(x)) return(raw(0))
  r <- if (is.raw(x)) x else if (is.character(x) && length(x) == 1L) .rmbl_hex_or_null(x) else NULL
  if (is.null(r) || (exact && length(r) != max) || length(r) > max) {
    stop(sprintf("`%s` must be %s %d bytes, raw or hex", what, if (exact) "exactly" else "at most", max),
         call. = FALSE)
  }
  r
}

# "aesni" or "portable"; `portable = TRUE` forces the portable cipher, FALSE restores the
# hardware path (the tests run the vectors through both)
.rmbl_aes_backend <- function(portable = NA) {
  .Call(C_rmbl_aes_backend, as.logical(portable))
}
