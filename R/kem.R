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
#' Generates a key for ML-KEM (FIPS 203), the standardised post-quantum key
#' encapsulation mechanism. It is implemented in this package, with no
#' system dependency.
#'
#' A KEM is not a signature scheme and not a cipher. Encapsulation produces
#' two things: a ciphertext to send, and a 32-byte shared secret to keep.
#' The holder of the decapsulation key recovers the same secret from the
#' ciphertext. What either side then does with that secret -- feed it to a
#' KDF, key an AEAD -- is outside the mechanism.
#'
#' @param level Security level: 512, 768 (the default) or
#' 1024. 768 is the level NIST and the IETF have settled on for general
#' use.
#' @param seed Optional raw vector of 64 seed bytes (
#' `d || z`) . Supplying it makes the key reproducible, which is what
#' the standard's test vectors need; the default draws from the operating
#' system's CSPRNG.
#' @return A list of class `bricklayer_kem_key`: `public`,
#' `secret` (both hex), and `level`.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Key-Encapsulation Mechanism Standard. FIPS 203.
#'   \doi{10.6028/NIST.FIPS.203}
#' @seealso
#' [kem_encapsulate()],
#' [kem_decapsulate()],
#' [kem_sizes()],
#' [fips_keygen()] for the signature schemes.
#' @examples
#' key <- kem_keygen(768)
#' pub <- kem_public_key(key)
#'
#' # the sender holds only the public key
#' sent <- kem_encapsulate(pub)
#' # the recipient recovers the same secret from the ciphertext
#' got <- kem_decapsulate(key, sent$ciphertext)
#' identical(sent$shared, got)
#'
#' # a corrupted ciphertext yields a DIFFERENT secret, not an error
#' bad <- sent$ciphertext
#' substring(bad, 1L, 2L) <- "00"
#' identical(kem_decapsulate(key, bad), got)
#' @export
kem_keygen <- function(level = 768L, seed = NULL) {
  level <- .rmbl_kem_level(level)
  if (is.null(seed)) {
    seed <- random_bytes(64L)
  } else if (!is.raw(seed) || length(seed) != 64L) {
    stop("`seed` must be a raw vector of 64 bytes", call. = FALSE)
  }
  res <- .Call(C_rmbl_mlkem_keygen, level, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              level = level)
  class(out) <- c("bricklayer_kem_key", "list")
  out
}

#' @rdname kem_keygen
#' @param key A key from `kem_keygen()`.
#' @export
kem_public_key <- function(key) {
  if (!inherits(key, "bricklayer_kem_key")) {
    stop("`key` must come from kem_keygen()", call. = FALSE)
  }
  out <- list(public = key$public, level = key$level)
  class(out) <- c("bricklayer_kem_public_key", "list")
  out
}

#' Byte lengths of an ML-KEM parameter set
#'
#' Reports the sizes FIPS 203 fixes, so a caller never has to hard-code
#' them.
#'
#' @param level Security level: 512, 768 or 1024.
#' @return A named integer vector: `encapsulation_key`,
#' `decapsulation_key`, `ciphertext`, `seed` and
#' `shared_secret`, all in bytes.
#' @seealso [kem_keygen()].
#' @examples
#' kem_sizes(768)
#'
#' # the shared secret is 32 bytes at every level: the level buys
#' # security margin, not a longer secret
#' vapply(c(512, 768, 1024),
#'        function(l) kem_sizes(l)[["shared_secret"]], integer(1))
#' @export
kem_sizes <- function(level) {
  .Call(C_rmbl_mlkem_sizes, .rmbl_kem_level(level))
}

#' Encapsulate a shared secret under an ML-KEM key
#'
#' Produces a ciphertext and the 32-byte shared secret it carries. Only the
#' public key is needed, which is the point: the sender never holds
#' anything the recipient has to trust them with.
#'
#' @param key A key or public key from
#' [kem_keygen()] /
#' [kem_public_key()].
#' @param m Optional raw vector of 32 bytes of encapsulation
#' randomness. Supplying it makes the operation reproducible, which is what
#' the standard's test vectors need; the default draws from the operating
#' system's CSPRNG. Reusing it across encapsulations to the same key reuses
#' the shared secret, so supply it only deliberately.
#' @return A list of class `bricklayer_kem_capsule`: `ciphertext`
#' and `shared` (both hex), and `level`.
#' @seealso
#' [kem_decapsulate()],
#' [kem_keygen()].
#' @examples
#' key <- kem_keygen(512)
#' a <- kem_encapsulate(key)
#' nchar(a$ciphertext) / 2 == kem_sizes(512)[["ciphertext"]]
#'
#' # two encapsulations to one key give different secrets
#' b <- kem_encapsulate(key)
#' identical(a$shared, b$shared)
#'
#' # both decapsulate correctly
#' identical(kem_decapsulate(key, a$ciphertext), a$shared)
#' identical(kem_decapsulate(key, b$ciphertext), b$shared)
#' @export
kem_encapsulate <- function(key, m = NULL) {
  level <- .rmbl_kem_key_level(key)
  ek <- .rmbl_hex_or_null(key$public)
  if (is.null(ek)) stop("`key` has no usable public key", call. = FALSE)
  if (is.null(m)) {
    m <- random_bytes(32L)
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
#' Returns the 32-byte shared secret the ciphertext carries, as hex.
#'
#' There is no failure path, and that is deliberate. A ciphertext that was
#' not produced by a correct encapsulation under this key yields a shared
#' secret derived from a value held only inside the decapsulation key -- so
#' it is a real secret, just not the sender's. Whoever sent it learns
#' nothing about whether it was accepted, which is what closes off a
#' chosen-ciphertext attack. The consequence for a caller: a mismatch
#' between the two sides' secrets is the signal that something was wrong,
#' not an error from this function.
#'
#' @param key A key from
#' [kem_keygen()], with its secret half.
#' @param ciphertext Ciphertext from
#' [kem_encapsulate()], hex or raw.
#' @return 64 hex characters: the 32-byte shared secret.
#' @seealso [kem_encapsulate()].
#' @examples
#' key <- kem_keygen(512)
#' sent <- kem_encapsulate(kem_public_key(key))
#' identical(kem_decapsulate(key, sent$ciphertext), sent$shared)
#'
#' # a tampered ciphertext returns a secret, and it is the wrong one
#' bad <- sent$ciphertext
#' substring(bad, 3L, 4L) <- "ff"
#' other <- kem_decapsulate(key, bad)
#' nchar(other) == 64L
#' identical(other, sent$shared)
#' @export
kem_decapsulate <- function(key, ciphertext) {
  level <- .rmbl_kem_key_level(key)
  if (is.null(key[["secret"]])) {
    stop("decapsulation needs a key with its secret half", call. = FALSE)
  }
  dk <- .rmbl_hex_or_null(key$secret)
  if (is.null(dk)) stop("`key` has no usable secret key", call. = FALSE)
  ct <- if (is.raw(ciphertext)) {
    ciphertext
  } else {
    .rmbl_hex_or_null(ciphertext)
  }
  n <- kem_sizes(level)[["ciphertext"]]
  if (is.null(ct) || length(ct) != n) {
    stop(sprintf("`ciphertext` must be %d bytes for ML-KEM-%d", n, level),
         call. = FALSE)
  }
  .rmbl_hexlify(.Call(C_rmbl_mlkem_decaps, level, dk, ct))
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

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_kem_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_kem_public_key <- function(x, ...) {
  c(.rmbl_rule("Public encapsulation key (ML-KEM, FIPS 203)"),
    .rmbl_kv(list(level = sprintf("ML-KEM-%d", x$level),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_kem_public_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

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

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_kem_capsule <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# The three levels FIPS 203 defines, and nothing else. A typo must fail
# rather than select a default: the level is not recorded in the
# ciphertext, so the two sides have to agree by other means.
.rmbl_kem_level <- function(level) {
  level <- suppressWarnings(as.integer(level)[1L])
  if (is.na(level) || !level %in% c(512L, 768L, 1024L)) {
    stop("`level` must be 512, 768 or 1024", call. = FALSE)
  }
  level
}

.rmbl_kem_key_level <- function(key) {
  if (!inherits(key, c("bricklayer_kem_key",
                       "bricklayer_kem_public_key"))) {
    stop("`key` must come from kem_keygen() or kem_public_key()",
         call. = FALSE)
  }
  .rmbl_kem_level(key$level)
}
