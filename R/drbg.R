# SPDX-License-Identifier: AGPL-3.0-or-later
#
# The CTR_DRBG of NIST SP 800-90A Rev. 1 with AES-256 and no derivation
# function: deterministic random bits from 48 bytes of entropy. It is the
# generator the NIST post-quantum known-answer tests are written with, so a seed
# from one of their .rsp files reproduces their randomness.

#' A deterministic random bit generator: AES-256 CTR_DRBG (NIST SP 800-90A)
#'
#' Creates the counter-mode DRBG of NIST SP 800-90A Rev. 1, section 10.2.1,
#' with AES-256 and no derivation function, implemented in this package (no
#' system library). From the same entropy, personalization and additional
#' inputs it returns the same bytes, which is what reproducible key generation
#' and known-answer tests need; for keys meant to stay secret, seed it from
#' [rndbytes()] (the default) or use
#' [rndbytes()] directly.
#'
#' It reproduces all 720 AES-256 no-df vectors of NIST's DRBG validation suite
#' (without reseeding, with reseeding, and with prediction resistance; the
#' package's tests check a sample of them), and it is the `randombytes()` of
#' NIST's `rng.c`, with which most post-quantum submissions wrote their
#' known-answer files: `drbgnew(as.raw(0:47))` followed by
#' `drbggen(d, 48)` gives the `seed` of their vector 0. AES runs in
#' constant time: the S-box is computed (an inversion in GF(2^8) and the affine
#' map) rather than looked up, and on x86-64 processors with AES-NI the rounds
#' use those instructions. Both paths are checked under valgrind memcheck with
#' the entropy input marked secret (`inst/ctcheck`, case `drbg-portable` and
#' `drbg-aesni`).
#'
#' The generator is an object that changes as it is used: every
#' [drbggen()] and
#' [drbgrsd()] advances it in place.
#'
#' The generator is an environment, so copies share one state. It is not
#' meant to be saved: a generator restored from \code{saveRDS()} or inherited
#' by a forked process reseeds itself from the operating system on its next
#' use, so two processes never replay the same stream (and such a stream is
#' then no longer reproducible). Errors when \code{entropy} is not exactly 48
#' bytes or \code{person} is longer than 48 bytes, or either is
#' neither a raw vector nor one hexadecimal string.
#'
#' @param entropy Entropy input: exactly 48 bytes, as a raw vector or one
#'   string of 96 hexadecimal digits. \code{NULL} (the default) draws them from
#'   the operating system's CSPRNG through [rndbytes()].
#' @param person Optional personalization string of up to 48 bytes,
#'   raw or hex; \code{NULL} (the default) is the empty string. Different
#'   personalization strings give independent streams from the same entropy.
#' @return An object of class \code{bricklayer_drbg} (an environment holding
#'   the 32-byte Key, the 16-byte V, the request count and the process id). Its
#'   state (Key, V) is not printed.
#' @references NIST SP 800-90A Rev. 1 (2015). Recommendation for Random Number
#'   Generation Using Deterministic Random Bit Generators, section 10.2.1.
#'   \doi{10.6028/NIST.SP.800-90Ar1}
#'
#'   NIST FIPS 197 (2001, updated 2023). Advanced Encryption Standard (AES).\cr
#'   \doi{10.6028/NIST.FIPS.197-upd1}
#' @seealso [drbggen()],
#'   [drbgrsd()],
#'   [rndbytes()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' # NIST's rng.c, as the post-quantum known-answer files use it: vector 0's
#' # seed
#' d <- drbgnew(as.raw(0:47))
#' drbggen(d, 48)
#'
#' # the same inputs give the same bytes; a personalization string separates
#' # streams
#' a <- drbgnew(as.raw(1:48), person = charToRaw("session 1"))
#' b <- drbgnew(as.raw(1:48), person = charToRaw("session 2"))
#' identical(drbggen(a, 16), drbggen(b, 16))
#'
#' # seeded from the operating system
#' d <- drbgnew()
#' length(drbggen(d, 32))
#'
#' # the entropy must be exactly 48 bytes
#' try(drbgnew(as.raw(1:16)))
#' @section Security:
#' The implementation is hand-written. Its standardised schemes are checked
#' byte for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
#' suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
#' operation that touches a secret under valgrind memcheck with the secret
#' marked undefined (the ctgrind method), so a branch or a memory address
#' that depends on it is a reported error, and afterwards scans the dead
#' stack for copies of the secret. Both checks run in CI on every change,
#' with GCC and with Clang. Timing is also measured on x86-64 and arm64
#' hardware (`inst/dudect`) and power leakage is assessed in simulation under
#' the value and the transition models (`inst/tvla`) for the masked ML-KEM
#' and ML-DSA kernels; this scheme is not masked. These are checks of this
#' code on those compilers; the README's security section lists what each
#' check does and does not cover.
#' @export
drbgnew <- function(entropy = NULL, person = NULL) {
  # the generator is an environment and is not meant to be serialised:
  # a copy restored in another process reseeds itself on first use
  entropy <- if (is.null(entropy)) {
    rndbytes(48L)
  } else {
    .rmbl_drbg_input(entropy, "entropy", 48L, exact = TRUE)
  }
  pers <- .rmbl_drbg_input(person, "person", 48L)
  st <- .Call(C_rmbl_drbg_instantiate, entropy, pers)
  d <- new.env(parent = emptyenv())
  d$key <- st$key
  d$v <- st$v
  d$reseed_counter <- 1
  d$pid <- Sys.getpid()
  class(d) <- "bricklayer_drbg"
  d
}

#' Draw bytes from a DRBG
#'
#' Generates \code{n} bytes (SP 800-90A's Generate function) and advances the
#' generator. Use it to draw reproducible random bytes from a generator made
#' by [drbgnew()]: the same seed and the same sequence of calls
#' give the same
#' bytes on every platform, which is what known-answer tests and reproducible
#' key generation need.
#'
#' @details
#' Each call encrypts the counter V under Key with AES-256 to produce the
#' output, then updates (Key, V) with the additional input, so the next call
#' gives different bytes and earlier outputs cannot be recovered from the new
#' state. The generator is changed in place. When the generator was created or
#' last reseeded in another process (a fork, or a copy restored from a file),
#' it first reseeds itself from the operating system. After \eqn{2^{48}}
#' requests since seeding the standard requires a reseed, and the call errors
#' until [drbgrsd()] is called.
#'
#' Errors: \code{drbg} not made by [drbgnew()]; \code{n} not a
#' single whole
#' number from 1 to 65536; \code{addl} longer than 48 bytes or neither raw
#' nor hex.
#'
#' @param drbg A generator from [drbgnew()].
#' @param n Integer scalar, the number of bytes, 1 to 65536 (the standard's
#'   limit per request for AES: 2^19 bits).
#' @param addl Optional additional input of up to 48 bytes, raw or hex,
#'   mixed into the state before and after the output. Default \code{NULL}
#'   (none).
#' @return A raw vector of \code{n} bytes.
#' @seealso [drbgnew()],
#'   [drbgrsd()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- drbgnew(as.raw(0:47))
#' x <- drbggen(d, 16)
#' y <- drbggen(d, 16)
#' identical(x, y)  # the state moved on
#'
#' # additional input changes the output and the state
#' e <- drbgnew(as.raw(0:47))
#' identical(drbggen(e, 16, addl = "00ff"), x)
#'
#' # random integers in 1..6 from the bytes (rejection keeps them uniform)
#' r <- as.integer(drbggen(drbgnew(as.raw(0:47)), 64))
#' head(r[r < 252] %% 6 + 1, 10)
#'
#' # one request is at most 65536 bytes
#' try(drbggen(d, 70000))
#' @export
drbggen <- function(drbg, n, addl = NULL) {
  .rmbl_drbg_check(drbg)
  n <- .rmbl_num(n, "n", integer = TRUE)
  if (length(n) != 1L || is.na(n) || n < 1L || n > 65536L) {
    stop("`n` must be a single integer between 1 and 65536", call. = FALSE)
  }
  if (drbg$reseed_counter > 2^48) {
    stop(
      "the generator has served 2^48 requests since it was seeded: ",
      "reseed it (drbgrsd())",
      call. = FALSE
    )
  }
  # a forked child (parallel::mclapply) inherits the parent's (Key, V) and
  # would replay the parent's stream; so would a generator restored from
  # saveRDS(). A process change reseeds from the operating system first.
  if (!identical(drbg$pid, Sys.getpid())) {
    drbgrsd(drbg)
  }
  st <- .Call(
    C_rmbl_drbg_generate,
    drbg$key,
    drbg$v,
    as.integer(n),
    .rmbl_drbg_input(addl, "addl", 48L)
  )
  drbg$key <- st$key
  drbg$v <- st$v
  drbg$reseed_counter <- drbg$reseed_counter + 1
  st$out
}

#' Reseed a DRBG
#'
#' Mixes fresh entropy into the generator (SP 800-90A's Reseed function) and
#' resets its request count. Use it after many requests (the standard requires
#' a reseed after \eqn{2^{48}}), to add prediction resistance before a sensitive
#' draw, or to replay a known-answer test that reseeds with given entropy.
#'
#' @details
#' The new (Key, V) is derived from the old state, the 48 entropy bytes and the
#' additional input, so the stream after the reseed depends on everything that
#' went before. The request count is reset to 1 and the generator is marked as
#' belonging to the current process. Errors: \code{drbg} not made by
#' [drbgnew()]; \code{entropy} not exactly 48 bytes;
#' \code{addl} longer
#' than 48 bytes; either not raw or hex.
#'
#' @inheritParams drbggen
#' @param entropy Entropy input: exactly 48 bytes, raw or hex; \code{NULL} (the
#'   default) draws them from the operating system's CSPRNG.
#' @param addl Optional additional input of up to 48 bytes, raw or hex;
#'   default \code{NULL} (none).
#' @return \code{drbg}, invisibly, reseeded in place.
#' @seealso [drbgnew()],
#'   [drbggen()].
#' @examplesIf isTRUE(getOption("rmbl.examples"))
#' d <- drbgnew(as.raw(0:47))
#' drbgrsd(d, as.raw(48:95))
#' drbggen(d, 8)
#'
#' # a reseed with given entropy is reproducible
#' d2 <- drbgnew(as.raw(0:47))
#' drbgrsd(d2, as.raw(48:95))
#' identical(drbggen(d2, 8),
#'           drbggen(drbgrsd(drbgnew(as.raw(0:47)), as.raw(48:95)), 8))
#'
#' # fresh entropy from the operating system, with additional input
#' drbgrsd(d, addl = charToRaw("before key generation"))
#'
#' # the entropy must be exactly 48 bytes
#' try(drbgrsd(d, as.raw(1:10)))
#' @export
drbgrsd <- function(drbg, entropy = NULL, addl = NULL) {
  .rmbl_drbg_check(drbg)
  entropy <- if (is.null(entropy)) {
    rndbytes(48L)
  } else {
    .rmbl_drbg_input(entropy, "entropy", 48L, exact = TRUE)
  }
  st <- .Call(
    C_rmbl_drbg_reseed,
    drbg$key,
    drbg$v,
    entropy,
    .rmbl_drbg_input(addl, "addl", 48L)
  )
  drbg$key <- st$key
  drbg$v <- st$v
  drbg$reseed_counter <- 1
  drbg$pid <- Sys.getpid()
  invisible(drbg)
}

#' @export
format.bricklayer_drbg <- function(x, ...) {
  .rmbl_stat_block(
    "Deterministic random bit generator",
    facts = list(
      Mechanism = "CTR_DRBG, AES-256, no derivation function (SP 800-90A)",
      `Requests since seeding` = format(
        x$reseed_counter - 1,
        scientific = FALSE
      ),
      Process = x$pid,
      State = "<withheld>"
    ),
    reading = paste(
      "The same entropy and personalisation give the same bytes; the state",
      "itself is never printed. drbgrsd() mixes in fresh entropy."
    )
  )
}

#' Checks that an object is a DRBG state made by drbgnew().
#' @param drbg The object passed by the user.
#' @noRd
.rmbl_drbg_check <- function(drbg) {
  if (
    !inherits(drbg, "bricklayer_drbg") ||
      !is.environment(drbg) ||
      !is.raw(drbg$key) ||
      length(drbg$key) != 32L ||
      !is.raw(drbg$v) ||
      length(drbg$v) != 16L
  ) {
    stop("`drbg` must come from drbgnew()", call. = FALSE)
  }
}

#' Reads a DRBG input given as raw bytes or hex.
#'
#' Raw or hex; NULL is the empty string; at most `max` bytes (exactly, when
#' `exact`)
#' @param x The input, raw, one hex string, or NULL.
#' @param what The argument name, used in the error message.
#' @param max The largest number of bytes accepted.
#' @param exact Whether the input must be exactly `max` bytes.
#' @return A raw vector.
#' @noRd
.rmbl_drbg_input <- function(x, what, max, exact = FALSE) {
  if (is.null(x)) {
    return(raw(0))
  }
  r <- if (is.raw(x)) {
    x
  } else if (is.character(x) && length(x) == 1L) {
    .rmbl_hex_or_null(x)
  } else {
    NULL
  }
  if (is.null(r) || (exact && length(r) != max) || length(r) > max) {
    stop(
      sprintf(
        "`%s` must be %s %d bytes, raw or hex",
        what,
        if (exact) "exactly" else "at most",
        max
      ),
      call. = FALSE
    )
  }
  r
}
