# SPDX-License-Identifier: AGPL-3.0-or-later
#
# HQC-KEM: the code-based key encapsulation NIST selected in March 2025 to
# stand beside ML-KEM (kem.R). The two rest on unrelated problems --
# decoding random quasi-cyclic codes against module lattices -- which is the
# point of having both: a break of one leaves the other standing.
#
# The same asymmetry as ML-KEM: decapsulation never fails on a bad
# ciphertext. It returns a secret derived from a value only the recipient
# holds (implicit rejection), so the sender cannot learn whether a forgery
# was accepted. What does fail loudly is a malformed KEY, because that is
# the holder's own corrupted data rather than an attacker's probe.

#' Generate an HQC key pair
#'
#' Generates a key for HQC (Hamming Quasi-Cyclic), the code-based key
#' encapsulation mechanism NIST selected for standardisation in March 2025
#' (NIST IR 8545) as a second KEM next to ML-KEM. It is implemented in this
#' package, with no system dependency.
#'
#' The implementation follows the HQC specification of 2025-08-22 and is byte
#' for byte the scheme of the authors' reference implementation v5.0.0: all
#' 300 official known-answer vectors are reproduced (the package's tests check
#' them). It runs in constant time with respect to secrets -- no secret
#' reaches a branch, a memory index or a variable shift, checked with
#' valgrind -- wipes its secret intermediates, and gives the same bytes on
#' little- and big-endian machines. On x86-64 processors with PCLMULQDQ and on
#' ARMv8 with the crypto extension the polynomial products use the carry-less
#' multiply instruction; elsewhere a portable constant-time product.
#'
#' NIST's FIPS 207 (HQC-KEM) is still a draft. It is expected to shorten the
#' decapsulation key to its 32-byte seed; the encapsulation key, ciphertext
#' and shared secret of the final standard may differ from these, so keep
#' keys and ciphertexts tagged with the scheme and level they belong to.
#'
#' @param level Security level, as a NIST category: 1, 3 (the default) or 5
#' (HQC-1, HQC-3, HQC-5; 128, 192 and 256 are accepted for the same three).
#' Level 3 matches the category of ML-KEM-768, [kem_keygen()]'s default.
#' @param seed Optional raw vector of 32 bytes (`seed_KEM`). Supplying it makes
#' the key reproducible, which is what the known-answer tests need; the
#' default draws from the operating system's CSPRNG.
#' @return A list of class `bricklayer_hqc_key`: `public`, `secret` (both
#' hex) and `level`. The secret key is the specification's
#' `ek || seed_dk || sigma || seed_KEM`.
#' @references Gaborit, P., Aguilar-Melchor, C., Aragon, N., Bettaieb, S.,
#' Bidoux, L., Blazy, O., Deneuville, J.-C., Persichetti, E., Zemor, G.,
#' et al. (2025). Hamming Quasi-Cyclic (HQC), specification of 2025-08-22;
#' reference implementation v5.0.0. <https://pqc-hqc.org/>
#'
#' Alagic, G. et al. (2025). Status Report on the Fourth Round of the NIST
#' Post-Quantum Cryptography Standardization Process. NIST IR 8545.
#' \doi{10.6028/NIST.IR.8545}
#' @seealso
#' [hqc_encapsulate()],
#' [hqc_decapsulate()],
#' [hqc_sizes()],
#' [kem_keygen()] for ML-KEM.
#' @examples
#' key <- hqc_keygen(1)
#' pub <- hqc_public_key(key)
#'
#' # the sender holds only the public key
#' sent <- hqc_encapsulate(pub)
#' # the recipient recovers the same secret from the ciphertext
#' got <- hqc_decapsulate(key, sent$ciphertext)
#' identical(sent$shared, got)
#'
#' # a corrupted ciphertext yields a DIFFERENT secret, not an error
#' bad <- sent$ciphertext
#' substring(bad, 1L, 2L) <- if (substring(bad, 1L, 2L) == "00") "01" else "00"
#' identical(hqc_decapsulate(key, bad), got)
#'
#' # a reproducible key from a fixed seed
#' identical(hqc_keygen(1, seed = as.raw(1:32))$public,
#'           hqc_keygen(1, seed = as.raw(1:32))$public)
#' @export
hqc_keygen <- function(level = 3L, seed = NULL) {
  level <- .rmbl_hqc_level(level)
  if (is.null(seed)) {
    seed <- random_bytes(32L)
  } else if (!is.raw(seed) || length(seed) != 32L) {
    stop("`seed` must be a raw vector of 32 bytes", call. = FALSE)
  }
  res <- .Call(C_rmbl_hqc_keygen, level, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              level = level)
  class(out) <- c("bricklayer_hqc_key", "list")
  out
}

#' @rdname hqc_keygen
#' @param key A key from `hqc_keygen()`.
#' @export
hqc_public_key <- function(key) {
  if (!inherits(key, "bricklayer_hqc_key")) {
    stop("`key` must come from hqc_keygen()", call. = FALSE)
  }
  out <- list(public = key$public, level = key$level)
  class(out) <- c("bricklayer_hqc_public_key", "list")
  out
}

#' Byte lengths of an HQC parameter set
#'
#' Reports the sizes the HQC specification fixes, so a caller never has to
#' hard-code them.
#'
#' @param level Security level: 1, 3 or 5 (or 128, 192, 256).
#' @return A named integer vector: `encapsulation_key`, `decapsulation_key`,
#' `ciphertext`, `seed` (key generation), `message` and `salt`
#' (encapsulation randomness) and `shared_secret`, all in bytes.
#' @seealso [hqc_keygen()], [kem_sizes()] for ML-KEM.
#' @examples
#' hqc_sizes(1)
#'
#' # code-based keys and ciphertexts are larger than ML-KEM's at the same
#' # category; the shared secret is 32 bytes at every level
#' rbind(HQC = hqc_sizes(3)[c("encapsulation_key", "ciphertext")],
#'       ML_KEM = kem_sizes(768)[c("encapsulation_key", "ciphertext")])
#' @export
hqc_sizes <- function(level) {
  .Call(C_rmbl_hqc_sizes, .rmbl_hqc_level(level))
}

#' Encapsulate a shared secret under an HQC key
#'
#' Produces a ciphertext and the 32-byte shared secret it carries. Only the
#' public key is needed.
#'
#' @param key A key or public key from [hqc_keygen()] / [hqc_public_key()].
#' @param m,salt Optional raw vectors of encapsulation randomness: `m` of
#' [hqc_sizes()]`["message"]` bytes (16, 24 or 32) and `salt` of 16 bytes.
#' Supplying them makes the operation reproducible, which is what the
#' known-answer tests need; the default draws both from the operating
#' system's CSPRNG. Reusing them for the same key repeats the shared secret,
#' so supply them only deliberately.
#' @return A list of class `bricklayer_hqc_capsule`: `ciphertext` and
#' `shared` (both hex), and `level`.
#' @seealso [hqc_decapsulate()], [hqc_keygen()].
#' @examples
#' key <- hqc_keygen(1)
#' a <- hqc_encapsulate(key)
#' nchar(a$ciphertext) / 2 == hqc_sizes(1)[["ciphertext"]]
#'
#' # two encapsulations to one key give different secrets
#' b <- hqc_encapsulate(key)
#' identical(a$shared, b$shared)
#'
#' # both decapsulate correctly
#' identical(hqc_decapsulate(key, a$ciphertext), a$shared)
#' identical(hqc_decapsulate(key, b$ciphertext), b$shared)
#' @export
hqc_encapsulate <- function(key, m = NULL, salt = NULL) {
  level <- .rmbl_hqc_key_level(key)
  ek <- .rmbl_hex_or_null(key$public)
  sz <- hqc_sizes(level)
  if (is.null(ek) || length(ek) != sz[["encapsulation_key"]]) {
    stop(sprintf("`key` has no usable HQC-%d public key (%d bytes)", level,
                 sz[["encapsulation_key"]]), call. = FALSE)
  }
  if (is.null(m)) {
    m <- random_bytes(sz[["message"]])
  } else if (!is.raw(m) || length(m) != sz[["message"]]) {
    stop(sprintf("`m` must be a raw vector of %d bytes for HQC-%d",
                 sz[["message"]], level), call. = FALSE)
  }
  if (is.null(salt)) {
    salt <- random_bytes(16L)
  } else if (!is.raw(salt) || length(salt) != 16L) {
    stop("`salt` must be a raw vector of 16 bytes", call. = FALSE)
  }
  res <- .Call(C_rmbl_hqc_encaps, level, ek, m, salt)
  out <- list(ciphertext = .rmbl_hexlify(res$ciphertext),
              shared = .rmbl_hexlify(res$shared),
              level = level)
  class(out) <- c("bricklayer_hqc_capsule", "list")
  out
}

#' Recover a shared secret from an HQC ciphertext
#'
#' Returns the 32-byte shared secret the ciphertext carries, as hex.
#'
#' A ciphertext that was not produced by a correct encapsulation under this
#' key does not raise an error: it yields the key `J(H(ek) || sigma || c)`,
#' derived from a value only the decapsulation key holds (the
#' Fujisaki-Okamoto transform's implicit rejection), so whoever sent it
#' learns nothing from the outcome. A mismatch between the two sides' secrets
#' is the signal that something was wrong. A decapsulation key whose stored
#' seeds no longer derive from each other (corrupted or spliced) IS refused.
#'
#' @param key A key from [hqc_keygen()], with its secret half.
#' @param ciphertext Ciphertext from [hqc_encapsulate()], hex or raw.
#' @return 64 hex characters: the 32-byte shared secret.
#' @seealso [hqc_encapsulate()].
#' @examples
#' key <- hqc_keygen(1)
#' sent <- hqc_encapsulate(hqc_public_key(key))
#' identical(hqc_decapsulate(key, sent$ciphertext), sent$shared)
#'
#' # a tampered ciphertext returns a secret, and it is the wrong one
#' bad <- sent$ciphertext
#' substring(bad, 3L, 4L) <- if (substring(bad, 3L, 4L) == "ff") "fe" else "ff"
#' other <- hqc_decapsulate(key, bad)
#' nchar(other) == 64L
#' identical(other, sent$shared)
#' @export
hqc_decapsulate <- function(key, ciphertext) {
  level <- .rmbl_hqc_key_level(key)
  if (is.null(key[["secret"]])) {
    stop("decapsulation needs a key with its secret half", call. = FALSE)
  }
  sz <- hqc_sizes(level)
  dk <- .rmbl_hex_or_null(key$secret)
  if (is.null(dk) || length(dk) != sz[["decapsulation_key"]]) {
    stop(sprintf("`key` has no usable HQC-%d secret key (%d bytes)", level,
                 sz[["decapsulation_key"]]), call. = FALSE)
  }
  ct <- if (is.raw(ciphertext)) ciphertext else .rmbl_hex_or_null(ciphertext)
  if (is.null(ct) || length(ct) != sz[["ciphertext"]]) {
    stop(sprintf("`ciphertext` must be %d bytes for HQC-%d",
                 sz[["ciphertext"]], level), call. = FALSE)
  }
  .rmbl_hexlify(.Call(C_rmbl_hqc_decaps, level, dk, ct))
}

#' @export
format.bricklayer_hqc_key <- function(x, ...) {
  c(.rmbl_rule("Key encapsulation key (HQC, code-based)"),
    .rmbl_kv(list(level = sprintf("HQC-%d", x$level),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L),
                  secret = "<withheld>")),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_hqc_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_hqc_public_key <- function(x, ...) {
  c(.rmbl_rule("Public encapsulation key (HQC, code-based)"),
    .rmbl_kv(list(level = sprintf("HQC-%d", x$level),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_hqc_public_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_hqc_capsule <- function(x, ...) {
  c(.rmbl_rule("Encapsulated shared secret (HQC, code-based)"),
    .rmbl_kv(list(level = sprintf("HQC-%d", x$level),
                  ciphertext = sprintf("%s... (%d bytes)",
                                       substring(x$ciphertext, 1L, 32L),
                                       nchar(x$ciphertext) %/% 2L),
                  shared = "<withheld>")),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_hqc_capsule <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

# The three parameter sets, by NIST category (or its security in bits).
# A typo must fail rather than select a default: the level is not recorded
# in the ciphertext, so both sides have to agree on it by other means.
.rmbl_hqc_level <- function(level) {
  lv <- suppressWarnings(as.integer(level)[1L])
  lv <- c(`1` = 1L, `3` = 3L, `5` = 5L, `128` = 1L, `192` = 3L,
          `256` = 5L)[as.character(lv)]
  if (length(lv) != 1L || is.na(lv)) {
    stop("`level` must be 1, 3 or 5 (HQC-1, HQC-3, HQC-5)", call. = FALSE)
  }
  unname(lv)
}

.rmbl_hqc_key_level <- function(key) {
  if (!inherits(key, c("bricklayer_hqc_key", "bricklayer_hqc_public_key"))) {
    stop("`key` must come from hqc_keygen() or hqc_public_key()",
         call. = FALSE)
  }
  .rmbl_hqc_level(key$level)
}

# Which carry-less multiplier the HQC products use: "pclmul", "pmull" or
# "portable". `portable = TRUE` forces the portable one, FALSE restores the
# hardware path (the tests run the vectors through both).
.rmbl_hqc_backend <- function(portable = NA) {
  .Call(C_rmbl_hqc_backend, as.logical(portable))
}
