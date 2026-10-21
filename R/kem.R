# SPDX-License-Identifier: AGPL-3.0-or-later
#
# ML-KEM (FIPS 203): key encapsulation, which answers a different
# question from the signature schemes in sign.R. A signature says who
# produced a capsule; an encapsulation says what key two parties now
# share, so the capsule can travel without being readable.
#
# The asymmetry worth knowing: decapsulation NEVER fails. A corrupted
# ciphertext yields a shared secret derived from a secret held only by
# the recipient, so the sender learns nothing from whether it worked.
# That is the Fujisaki-Okamoto transform's implicit rejection, and it is
# why this API has no error path for a bad ciphertext.

#' Generate an ML-KEM key pair
#'
#' Generates a key pair for ML-KEM (FIPS 203), the standardised post-quantum
#' key encapsulation mechanism, and \code{kempubkey()} strips a key pair
#' down to the half that can be shared. Use them when a capsule, a data file
#' or a credential has to reach one recipient without being readable on the
#' way: the recipient makes the key pair and publishes the public half, and
#' the sender uses it with [kemencap()]. It is
#' implemented in this
#' package, with no system dependency.
#'
#' @details
#' A KEM is not a signature scheme and not a cipher. Encapsulation produces
#' two things: a ciphertext to send, and a 32-byte shared secret to keep.
#' The holder of the decapsulation key recovers the same secret from the
#' ciphertext. What either side then does with that secret -- feed it to a
#' KDF, key an AEAD -- is outside the mechanism.
#'
#' Key generation is ML-KEM.KeyGen of FIPS 203 (Algorithm 19) from the
#' 64-byte seed \eqn{d \| z}: \eqn{d} seeds the K-PKE key and \eqn{z} is the
#' implicit-rejection value kept inside the decapsulation key. With a seed
#' the result is deterministic (the same seed gives the same key, which is
#' how the NIST test vectors are reproduced); without one the seed is drawn
#' with [rndbytes()] from the operating system. The key
#' sizes per level
#' are given by [kemsz()]; the level is not recorded in a
#' ciphertext, so
#' both sides must agree on it.
#'
#' Errors: \code{lvl} other than one whole number 512, 768 or 1024;
#' \code{seed} that is not a raw vector of 64 bytes; \code{key} passed to
#' \code{kempubkey()} that is not from \code{kemkg()}.
#'
#' @param lvl Security level, one whole number: 512 (ML-KEM-512, NIST
#' category 1), 768 (the default, category 3) or 1024 (category 5). 768 is
#' the level NIST and the IETF have settled on for general use.
#' @param seed Optional raw vector of 64 seed bytes (
#' `d || z`) . Supplying it makes the key reproducible, which is what
#' the standard's test vectors need; the default draws from the operating
#' system's CSPRNG.
#' @return \code{kemkg()}: a list of class
#'   \code{c("bricklayer_kem_key", "list")} with \code{public} (character,
#'   the encapsulation key as lower-case hex, 800, 1184 or 1568 bytes),
#'   \code{secret} (character, the decapsulation key as hex, 1632, 2400 or
#'   3168 bytes) and \code{level} (integer). Printing it never shows the
#'   secret. \code{kempubkey()}: a list of class
#'   \code{c("bricklayer_kem_public_key", "list")} with \code{public} and
#'   \code{level} only.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Key-Encapsulation Mechanism Standard. FIPS 203.
#'   \doi{10.6028/NIST.FIPS.203}
#' @seealso
#' [kemencap()],
#' [kemdecap()],
#' [kemsz()],
#' [fipskg()] for the signature schemes.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- kemkg(768)
#' pub <- kempubkey(key)
#'
#' # the sender holds only the public key
#' sent <- kemencap(pub)
#' # the recipient recovers the same secret from the ciphertext
#' got <- kemdecap(key, sent$ciphertext)
#' identical(sent$shared, got)
#'
#' # a corrupted ciphertext yields a DIFFERENT secret, not an error
#' bad <- sent$ciphertext
#' substring(bad, 1L, 2L) <- "00"
#' identical(kemdecap(key, bad), got)
#'
#' # a fixed seed gives the same key every time (for test vectors only)
#' k1 <- kemkg(512, seed = as.raw(0:63))
#' k2 <- kemkg(512, seed = as.raw(0:63))
#' identical(k1$public, k2$public)
#' k1
#'
#' # levels other than the three FIPS 203 defines are refused
#' try(kemkg(256))
#' try(kemkg(768, seed = as.raw(1:10)))
#' @section Security:
#' The implementation is hand-written. Its standardised schemes are checked
#' byte for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
#' suite. Side channels are checked, not assumed: `inst/ctcheck` runs every
#' operation that touches a secret under valgrind memcheck with the secret
#' marked undefined (the ctgrind method), so a branch or a memory address
#' that depends on it is a reported error, and afterwards scans the dead
#' stack for copies of the secret. Both checks run in CI on every change,
#' with GCC and with Clang. Timing is also measured on x86-64 and arm64
#' hardware (`inst/dudect`), power leakage is assessed in simulation under
#' the value and the transition models (`inst/tvla`), and ML-KEM
#' decapsulation and ML-DSA signing are first-order masked by default. These
#' are checks of this code on those compilers and under those leakage
#' models; the README's security section lists what each check does and
#' does not cover.
#' @export
kemkg <- function(lvl = 768L, seed = NULL) {
  lvl <- .rmbl_kem_level(lvl)
  if (is.null(seed)) {
    seed <- rndbytes(64L)
  } else if (!is.raw(seed) || length(seed) != 64L) {
    stop("`seed` must be a raw vector of 64 bytes", call. = FALSE)
  }
  res <- .Call(C_rmbl_mlkem_keygen, lvl, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              level = lvl)
  class(out) <- c("bricklayer_kem_key", "list")
  out
}

#' @rdname kemkg
#' @param key For \code{kempubkey()}: a key pair from \code{kemkg()}.
#' @export
kempubkey <- function(key) {
  if (!inherits(key, "bricklayer_kem_key")) {
    stop("`key` must come from kemkg()", call. = FALSE)
  }
  out <- list(public = key$public, level = key$level)
  class(out) <- c("bricklayer_kem_public_key", "list")
  out
}

#' Byte lengths of an ML-KEM parameter set
#'
#' Reports the byte sizes that FIPS 203 fixes for one ML-KEM parameter set:
#' the public (encapsulation) key, the secret (decapsulation) key, the
#' ciphertext, the key-generation seed and the shared secret. Use it to
#' check a key or ciphertext before storing or sending it, or to size a
#' buffer or a database column, so a caller never has to hard-code the
#' numbers.
#'
#' @details
#' The values come from the native core and are those of FIPS 203, Table 3:
#' \tabular{lrrr}{
#'   \tab 512 \tab 768 \tab 1024 \cr
#'   encapsulation key \tab 800 \tab 1184 \tab 1568 \cr
#'   decapsulation key \tab 1632 \tab 2400 \tab 3168 \cr
#'   ciphertext \tab 768 \tab 1088 \tab 1568 \cr
#'   seed \tab 64 \tab 64 \tab 64 \cr
#'   shared secret \tab 32 \tab 32 \tab 32
#' }
#' Hex strings from [kemkg()] and
#' [kemencap()] are twice these
#' lengths in characters. Error: \code{lvl} other than one whole number
#' 512, 768 or 1024.
#'
#' @param lvl Security level, one whole number: 512, 768 or 1024. There is
#'   no default.
#' @return A named integer vector of five elements, all in bytes:
#'   \code{public} (the encapsulation key), \code{secret} (the
#'   decapsulation key), \code{ciphertext}, \code{seed} and \code{shared}
#'   (the shared secret), named as [kemkg()] and
#'   [kemencap()] name their
#'   results.
#' @seealso [kemkg()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' kemsz(768)
#'
#' # the shared secret is 32 bytes at every level: the level buys
#' # security margin, not a longer secret
#' vapply(c(512, 768, 1024),
#'        function(l) kemsz(l)[["shared"]], integer(1))
#'
#' # check a ciphertext's length before sending it
#' key <- kemkg(768)
#' ct <- kemencap(key)$ciphertext
#' nchar(ct) / 2 == kemsz(768)[["ciphertext"]]
#'
#' # an unknown level is an error, not a default
#' try(kemsz(2048))
#' @export
kemsz <- function(lvl) {
  .Call(C_rmbl_mlkem_sizes, .rmbl_kem_level(lvl))
}

#' Encapsulate a shared secret under an ML-KEM key
#'
#' Produces a ciphertext and the 32-byte shared secret it carries. Only the
#' public key is needed, which is the point: the sender never holds
#' anything the recipient has to trust them with. The sender keeps the
#' shared secret (to derive an encryption key, for example) and sends the
#' ciphertext; the recipient gets the same secret back with
#' [kemdecap()].
#'
#' @details
#' This is ML-KEM.Encaps of FIPS 203 (Algorithm 20) on the 32-byte message
#' \code{m}. Without \code{m}, fresh randomness is drawn with
#' [rndbytes()], so two encapsulations to one key give
#' different
#' ciphertexts and secrets. A full key pair works as well as a public key;
#' only its public half is read.
#'
#' Errors: \code{key} not from [kemkg()] or
#' [kempubkey()]; a key
#' whose public half is not valid hex (\dQuote{key has no usable public key});
#' \code{m} that is not a raw vector of 32 bytes.
#'
#' @param key A key or public key from
#' [kemkg()] /
#' [kempubkey()].
#' @param m Optional raw vector of 32 bytes of encapsulation
#' randomness. Supplying it makes the operation reproducible, which is what
#' the standard's test vectors need; the default draws from the operating
#' system's CSPRNG. Reusing it across encapsulations to the same key reuses
#' the shared secret, so supply it only deliberately.
#' @return A list of class \code{bricklayer_kem_capsule} with
#'   \code{ciphertext} (character, hex, of the length in bytes that
#'   [kemsz()]\code{[["ciphertext"]]} gives: send this), \code{shared}
#'   (character, 64 hex characters, the
#'   32-byte shared secret: keep this) and \code{level} (integer). Printing
#'   it never shows the shared secret.
#' @seealso
#' [kemdecap()],
#' [kemkg()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- kemkg(512)
#' a <- kemencap(key)
#' nchar(a$ciphertext) / 2 == kemsz(512)[["ciphertext"]]
#'
#' # two encapsulations to one key give different secrets
#' b <- kemencap(key)
#' identical(a$shared, b$shared)
#'
#' # both decapsulate correctly
#' identical(kemdecap(key, a$ciphertext), a$shared)
#' identical(kemdecap(key, b$ciphertext), b$shared)
#'
#' # fixed randomness makes the result reproducible (test vectors only)
#' m <- as.raw(1:32)
#' identical(kemencap(key, m = m)$shared, kemencap(key, m = m)$shared)
#'
#' # the randomness must be exactly 32 bytes
#' try(kemencap(key, m = as.raw(1:8)))
#' @export
kemencap <- function(key, m = NULL) {
  level <- .rmbl_kem_key_level(key)
  ek <- .rmbl_hex_or_null(key$public)
  if (is.null(ek)) stop("kemencap: `key` has no usable public key", call. = FALSE)
  if (is.null(m)) {
    m <- rndbytes(32L)
  } else if (!is.raw(m) || length(m) != 32L) {
    stop("`m` must be a raw vector of 32 bytes", call. = FALSE)
  }
  res <- .Call(C_rmbl_mlkem_encaps, level, ek, m)
  out <- list(ciphertext = .rmbl_hexlify(res$ciphertext),
              shared = .rmbl_hexlify(res$shared),
              level = level)
  class(out) <- c("bricklayer_kem_capsule", "list")
  out
}

#' Recover a shared secret from an ML-KEM ciphertext
#'
#' Returns the 32-byte shared secret that a ciphertext from
#' [kemencap()] carries, as hex. This is the
#' recipient's side of the
#' exchange: with the secret half of the key pair, the recipient recovers
#' the same secret the sender kept, and the two can then use it as a common
#' key.
#'
#' @details
#' This is ML-KEM.Decaps of FIPS 203 (Algorithm 21). For a ciphertext of
#' the right length there is no failure path, and that is deliberate. A ciphertext that
#' was
#' not produced by a correct encapsulation under this key yields a shared
#' secret derived from a value held only inside the decapsulation key -- so
#' it is a real secret, just not the sender's. Whoever sent it learns
#' nothing about whether it was accepted, which is what closes off a
#' chosen-ciphertext attack. The consequence for a caller: a mismatch
#' between the two sides' secrets is the signal that something was wrong,
#' not an error from this function.
#'
#' Masked by default. With `masked = TRUE` every value that depends on the
#' secret key is held as two random shares from the moment the key is read
#' (first-order masking): decryption, the decoding of the message, the
#' hashing, the re-encryption with its noise sampling, the comparison with
#' the ciphertext and the choice between the real and the rejection secret.
#' No single intermediate value then depends on the key, which is what defeats
#' first-order power and electromagnetic analysis; `inst/tvla` checks the
#' masked gadgets against that leakage model. The result is identical to the
#' unmasked computation for every ciphertext; it costs about 2.3 to 3.4 times
#' the plain time depending on the CPU (4 ms for ML-KEM-768 on this
#' package's test machine against 1.2 ms plain). `masked = FALSE` runs the
#' plain constant-time decapsulation, and the option
#' `rmoriebricklayer.masked` sets the default for a session.
#'
#' Errors (checked before any decapsulation): \code{key} not from
#' [kemkg()], or a public key only (\dQuote{decapsulation needs a
#' key with its
#' secret half}); a ciphertext that is not hex or raw of the exact length
#' for the key's level, which is
#' [kemsz()]\code{[["ciphertext"]]} bytes (768,
#' 1088 or 1568); \code{masked} not \code{TRUE} or \code{FALSE}.
#'
#' @param key A key from
#' [kemkg()], with its secret half.
#' @param ct The \code{ct} element from
#'   [kemencap()],
#'   as a hex string or a raw vector, of the length for the key's level.
#' @param masked Logical, \code{TRUE} or \code{FALSE}.
#'
#'   \code{rmoriebricklayer.masked}, an option, gives the default when it is set;
#'   otherwise the default is \code{TRUE}.
#'   \code{TRUE} runs the first-order masked decapsulation, \code{FALSE} the plain one.
#'   Both return the same secret.
#' @return A length-1 character vector of 64 lower-case hex characters: the
#'   32-byte shared secret.
#' @seealso [kemencap()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- kemkg(512)
#' sent <- kemencap(kempubkey(key))
#' identical(kemdecap(key, sent$ciphertext), sent$shared)
#'
#' # a tampered ciphertext returns a secret, and it is the wrong one
#' bad <- sent$ciphertext
#' substring(bad, 3L, 4L) <- "ff"
#' other <- kemdecap(key, bad)
#' nchar(other) == 64L
#' identical(other, sent$shared)
#'
#' # the masked and the plain decapsulation agree
#' identical(kemdecap(key, bad, masked = FALSE), other)
#'
#' # a public key alone cannot decapsulate, and a short ciphertext is refused
#' try(kemdecap(kempubkey(key), sent$ciphertext))
#' try(kemdecap(key, "abcd"))
#' @export
kemdecap <- function(key, ct, masked = getOption("rmoriebricklayer.masked", TRUE)) {
  .rmbl_no_fn(ciphertext = ct)
  masked <- .rmbl_masked_flag(masked)
  level <- .rmbl_kem_key_level(key)
  if (is.null(key[["secret"]])) {
    stop("kemdecap: decapsulation needs a key with its secret half", call. = FALSE)
  }
  dk <- .rmbl_hex_or_null(key$secret)
  if (is.null(dk)) stop("`key` has no usable secret key", call. = FALSE)
  .ct <- if (is.raw(ct)) {
    ct
  } else {
    .rmbl_hex_or_null(ct)
  }
  n <- kemsz(level)[["ciphertext"]]
  if (is.null(.ct) || length(.ct) != n) {
    stop(sprintf("`ct` must be %d bytes for ML-KEM-%d", n, level),
         call. = FALSE)
  }
  .rmbl_hexlify(if (masked) {
    .Call(C_rmbl_mlkem_decaps_masked, level, dk, .ct)
  } else {
    .Call(C_rmbl_mlkem_decaps, level, dk, .ct)
  })
}

#' @export
format.bricklayer_kem_key <- function(x, ...) {
  c(.rmbl_rule("Key encapsulation key (ML-KEM, FIPS 203)"),
    .rmbl_kv(list(level = sprintf("ML-KEM-%d", x$level),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L),
                  secret = "<withheld>")),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_key
print.bricklayer_kem_key <- .rmbl_print_via_format

#' @export
format.bricklayer_kem_public_key <- function(x, ...) {
  c(.rmbl_rule("Public encapsulation key (ML-KEM, FIPS 203)"),
    .rmbl_kv(list(level = sprintf("ML-KEM-%d", x$level),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_public_key
print.bricklayer_kem_public_key <- .rmbl_print_via_format

#' @export
format.bricklayer_kem_capsule <- function(x, ...) {
  c(.rmbl_rule("Encapsulated shared secret (ML-KEM, FIPS 203)"),
    .rmbl_kv(list(level = sprintf("ML-KEM-%d", x$level),
                  ciphertext = sprintf("%s... (%d bytes)",
                                       substring(x$ciphertext, 1L, 32L),
                                       nchar(x$ciphertext) %/% 2L),
                  shared = "<withheld>")),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_kem_capsule
print.bricklayer_kem_capsule <- .rmbl_print_via_format

#' Checks an ML-KEM security level.
#'
#' The three levels FIPS 203 defines, and nothing else. A typo must fail
#' rather than select a default: the level is not recorded in the
#' ciphertext, so the two sides have to agree by other means.
#' @param level The level passed by the user.
#' @return The level as an integer.
#' @noRd
.rmbl_kem_level <- function(level) {
  # one whole number: as.integer() read c(512, 768) as 512 and 512.5 as 512
  ok <- is.numeric(level) && length(level) == 1L && !is.na(level) && level == round(level) &&
    level %in% c(512, 768, 1024)
  if (!ok) stop("`level` must be one of 512, 768 or 1024", call. = FALSE)
  as.integer(level)
}

#' Checks that a key came from kemkg() or kempubkey() and returns its level.
#' @param key The key passed by the user.
#' @return The key's level as an integer.
#' @noRd
.rmbl_kem_key_level <- function(key) {
  if (!inherits(key, c("bricklayer_kem_key",
                       "bricklayer_kem_public_key"))) {
    stop("`key` must come from kemkg() or kempubkey()",
         call. = FALSE)
  }
  .rmbl_kem_level(key$level)
}
