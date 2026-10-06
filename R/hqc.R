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
#' NIST will publish HQC-KEM as FIPS 207 but has not yet released it, or a
#' draft of it (checked 2026-10-05). The specification of 2025-08-22 followed
#' here already makes the changes NIST listed for FIPS 207 (the salted FO
#' transform, SHA3-512 seed expansion, the 32-byte shared secret, the new
#' sampler, the seed in the decapsulation key, the seed-only compressed key
#' that [hqc_compress_key()] writes); the published standard
#' may still differ
#' in detail. Keep keys and ciphertexts tagged with the scheme, version and
#' level they belong to.
#'
#' `version = "round4"` gives the earlier revision instead: the fourth-round
#' submission of 2023-04-30 (HQC-128/192/256), the HQC of liboqs up to 0.12
#' and of PQClean, with a 64-byte shared secret. It uses the same codes and
#' parameters under a different key encapsulation (40-byte seeds, SHAKE256
#' with domain bytes in place of SHA3, another sampler), so its keys and
#' ciphertexts are not interchangeable with v5's. It reproduces that
#' revision's 300 official known-answer vectors (the package's tests check
#' them); use it to exchange keys with software built on it, and v5 otherwise.
#'
#' @param level Security level, as a NIST category: 1, 3 (the default) or 5
#' (HQC-1, HQC-3, HQC-5; 128, 192 and 256 are accepted for the same three).
#' Level 3 matches the category of ML-KEM-768,
#' [kem_keygen()]'s default.
#' @param seed Optional raw vector: 32 bytes (`seed_KEM`) for v5; for round 4
#' the [hqc_sizes()]`["seed"]` bytes its key generation
#' draws (`sk_seed`, `sigma`, `pk_seed`: 96, 104 or 112).
#' Supplying it makes the key reproducible, which is what the known-answer
#' tests need; the default draws from the operating system's CSPRNG.
#' @param version `"v5"` (the default: the specification of 2025-08-22, a
#' 32-byte shared secret) or `"round4"` (the submission of 2023-04-30, a
#' 64-byte shared secret). Keys remember it; encapsulation and decapsulation
#' follow the key.
#' @return A list of class `bricklayer_hqc_key`: `public`, `secret` (both
#' hex), `level` and `version`. The v5 secret key is the specification's
#' `ek || seed_dk || sigma || seed_KEM`; the round-4 one is
#' `sk_seed || sigma || ek`.
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
#'
#' # the round-4 revision: the same exchange, a 64-byte shared secret
#' old <- hqc_keygen(1, version = "round4")
#' cap <- hqc_encapsulate(hqc_public_key(old))
#' nchar(cap$shared) / 2
#' identical(hqc_decapsulate(old, cap$ciphertext), cap$shared)
#' @section Security:
#' A hand-written implementation. The standardised schemes are checked byte
#' for byte against OpenSSL 3.5 and NIST known-answer vectors in the test
#' suite, which establishes correctness, not resistance to side channels:
#' no third-party security audit and no timing or leakage analysis has been
#' done. Use it for provenance and research, and read any constant-time
#' wording in this documentation as a design intent, not a verified
#' property.
#' @export
hqc_keygen <- function(level = 3L, seed = NULL, version = c("v5", "round4")) {
  level <- .rmbl_hqc_level(level)
  version <- match.arg(version)
  n <- hqc_sizes(level, version)[["seed"]]
  if (is.null(seed)) {
    seed <- random_bytes(n)
  } else if (!is.raw(seed) || length(seed) != n) {
    stop(sprintf("`seed` must be a raw vector of %d bytes for HQC %s", n, version), call. = FALSE)
  }
  res <- if (version == "v5") .Call(C_rmbl_hqc_keygen, level, seed) else .Call(C_rmbl_hqc4_keygen, level, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              level = level, version = version)
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
  out <- list(public = key$public, level = key$level, version = .rmbl_hqc_key_version(key))
  class(out) <- c("bricklayer_hqc_public_key", "list")
  out
}

#' Byte lengths of an HQC parameter set
#'
#' Reports the sizes the HQC specification fixes, so a caller never has to
#' hard-code them.
#'
#' @param level Security level: 1, 3 or 5 (or 128, 192, 256).
#' @param version `"v5"` (the default) or `"round4"`, as in
#'   [hqc_keygen()].
#' @return A named integer vector: `encapsulation_key`, `decapsulation_key`,
#' `ciphertext`, `seed` (key generation), `message` and `salt`
#' (encapsulation randomness) and `shared_secret`, all in bytes.
#' @seealso [hqc_keygen()], [kem_sizes()] for ML-KEM.
#' @examples
#' hqc_sizes(1)
#'
#' # code-based keys and ciphertexts are larger than ML-KEM's at the same
#' # category; the shared secret is 32 bytes at every level (64 in round 4)
#' rbind(HQC = hqc_sizes(3)[c("encapsulation_key", "ciphertext")],
#'       ML_KEM = kem_sizes(768)[c("encapsulation_key", "ciphertext")])
#' rbind(v5 = hqc_sizes(1), round4 = hqc_sizes(1, "round4"))
#' @export
hqc_sizes <- function(level, version = c("v5", "round4")) {
  version <- match.arg(version)
  lv <- .rmbl_hqc_level(level)
  if (version == "v5") .Call(C_rmbl_hqc_sizes, lv) else .Call(C_rmbl_hqc4_sizes, lv)
}

#' Encapsulate a shared secret under an HQC key
#'
#' Produces a ciphertext and the shared secret it carries (32 bytes; 64 for a
#' round-4 key). Only the public key is needed.
#'
#' @param key A key or public key from [hqc_keygen()] /
#'   [hqc_public_key()].
#' @param m,salt Optional raw vectors of encapsulation randomness: `m` of
#' [hqc_sizes()]`["message"]` bytes (16, 24 or 32)
#' and `salt` of 16 bytes.
#' Supplying them makes the operation reproducible, which is what the
#' known-answer tests need; the default draws both from the operating
#' system's CSPRNG. Reusing them for the same key repeats the shared secret,
#' so supply them only deliberately.
#' @return A list of class `bricklayer_hqc_capsule`: `ciphertext` and
#' `shared` (both hex), `level` and `version`.
#' @seealso [hqc_decapsulate()],
#'   [hqc_keygen()].
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
  version <- .rmbl_hqc_key_version(key)
  ek <- .rmbl_hex_or_null(key$public)
  sz <- hqc_sizes(level, version)
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
  res <- if (version == "v5") {
    .Call(C_rmbl_hqc_encaps, level, ek, m, salt)
  } else {
    .Call(C_rmbl_hqc4_encaps, level, ek, m, salt)
  }
  out <- list(ciphertext = .rmbl_hexlify(res$ciphertext),
              shared = .rmbl_hexlify(res$shared),
              level = level, version = version)
  class(out) <- c("bricklayer_hqc_capsule", "list")
  out
}

#' Recover a shared secret from an HQC ciphertext
#'
#' Returns the shared secret the ciphertext carries, as hex (32 bytes; 64 for
#' a round-4 key).
#'
#' A ciphertext that was not produced by a correct encapsulation under this
#' key does not raise an error: it yields the key `J(H(ek) || sigma || c)`
#' (round 4: `K(sigma || u || v)`), derived from a value only the
#' decapsulation key holds (the
#' Fujisaki-Okamoto transform's implicit rejection), so whoever sent it
#' learns nothing from the outcome. A mismatch between the two sides' secrets
#' is the signal that something was wrong. A decapsulation key whose stored
#' seeds no longer derive from each other (corrupted or spliced; for round 4,
#' whose public half is not the one its secret seed makes) IS refused.
#'
#' @param key A key from [hqc_keygen()], with its secret half.
#' @param ciphertext Ciphertext from
#'   [hqc_encapsulate()], hex or raw.
#' @return The shared secret as hex: 64 characters (32 bytes), or 128 for a
#' round-4 key.
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
  version <- .rmbl_hqc_key_version(key)
  if (is.null(key[["secret"]])) {
    stop("decapsulation needs a key with its secret half", call. = FALSE)
  }
  sz <- hqc_sizes(level, version)
  dk <- .rmbl_hex_or_null(key$secret)
  if (length(dk) == sz[["seed"]]) dk <- .rmbl_hqc_expand(key, dk, level, version)
  if (is.null(dk) || length(dk) != sz[["decapsulation_key"]]) {
    stop(sprintf("`key` has no usable HQC-%d secret key (%d bytes)", level,
                 sz[["decapsulation_key"]]), call. = FALSE)
  }
  ct <- if (is.raw(ciphertext)) ciphertext else .rmbl_hex_or_null(ciphertext)
  if (is.null(ct) || length(ct) != sz[["ciphertext"]]) {
    stop(sprintf("`ciphertext` must be %d bytes for HQC-%d",
                 sz[["ciphertext"]], level), call. = FALSE)
  }
  out <- if (version == "v5") .Call(C_rmbl_hqc_decaps, level, dk, ct) else .Call(C_rmbl_hqc4_decaps, level, dk, ct)
  .rmbl_hexlify(out)
}

#' The compressed HQC decapsulation key
#'
#' The HQC specification of 2025-08-22 allows the decapsulation key to be
#' stored as its 32-byte `seed_KEM` alone (the compressed format
#' `dk_KEM = (seed_KEM)`), from which the whole key pair is derived again.
#' `hqc_compress_key()` keeps only that seed;
#' [hqc_decapsulate()] takes such a
#' key and expands it, and refuses one whose seed does not derive the key's
#' public half.
#'
#' The round-4 revision (64-byte shared secret) defines no compressed format,
#' but its key pair is derived from the randomness its key generation draws,
#' `sk_seed || sigma || pk_seed` (96, 104 or 112 bytes: the `seed` of
#' [hqc_keygen()] and
#' [hqc_sizes()]), all of which its secret key
#' `sk_seed || sigma || pk_seed || s` carries. For a round-4 key the compressed
#' form is that seed: this package's convention, not a format of the
#' submission, so software built on round 4 (liboqs, PQClean) expects the
#' full secret key.
#'
#' @param key A key from [hqc_keygen()].
#' @return The key with `secret` replaced by the hex of its seed: 32 bytes
#' for v5, 96, 104 or 112 for round 4.
#' @references Gaborit, P. et al. (2025). Hamming Quasi-Cyclic (HQC),
#' specification of 2025-08-22, section 3 (HQC-KEM key pair formats).
#' <https://pqc-hqc.org/>
#' @seealso [hqc_keygen()], [hqc_decapsulate()]
#' @examples
#' key <- hqc_keygen(1)
#' small <- hqc_compress_key(key)
#' nchar(small$secret) / 2
#' sent <- hqc_encapsulate(hqc_public_key(key))
#' identical(hqc_decapsulate(small, sent$ciphertext), sent$shared)
#' @export
hqc_compress_key <- function(key) {
  if (!inherits(key, "bricklayer_hqc_key")) {
    stop("`key` must come from hqc_keygen()", call. = FALSE)
  }
  version <- .rmbl_hqc_key_version(key)
  sz <- hqc_sizes(key$level, version)
  dk <- .rmbl_hex_or_null(key$secret)
  n <- length(dk)
  if (n == sz[["seed"]]) return(key)
  if (n != sz[["decapsulation_key"]]) {
    stop("`key` has no usable HQC secret key", call. = FALSE)
  }
  # v5: dk = ek, seed_dk, sigma, seed_KEM, so the seed is its last 32 bytes
  key$secret <- .rmbl_hexlify(if (version == "v5") {
    dk[(n - 31L):n]
  } else {
    # sk_seed || sigma || ek with ek = pk_seed || s: the seed is the first
    # sk_seed || sigma bytes and the first 40 bytes of ek
    k <- sz[["seed"]] - 80L
    dk[c(seq_len(40L + k), 40L + k + seq_len(40L))]
  })
  key
}

# a compressed decapsulation key: re-derive the pair from its seed, and
# refuse a seed that does not give the key's own public half
.rmbl_hqc_expand <- function(key, seed, level, version) {
  full <- hqc_keygen(level, seed = seed, version = version)
  if (!is.null(key[["public"]]) && !identical(tolower(key$public), full$public)) {
    stop("the compressed secret key does not derive this key's public key", call. = FALSE)
  }
  .rmbl_hex_or_null(full$secret)
}

#' @export
format.bricklayer_hqc_key <- function(x, ...) {
  c(.rmbl_rule("Key encapsulation key (HQC, code-based)"),
    .rmbl_kv(list(level = .rmbl_hqc_label(x),
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
    .rmbl_kv(list(level = .rmbl_hqc_label(x),
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
    .rmbl_kv(list(level = .rmbl_hqc_label(x),
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
  # one whole number: as.integer() would read c(1, 3) as 1 and 3.5 as 3
  lv <- if (is.numeric(level) && length(level) == 1L && is.finite(level) && level == round(level)) {
    c(`1` = 1L, `3` = 3L, `5` = 5L, `128` = 1L, `192` = 3L, `256` = 5L)[as.character(level)]
  } else {
    NA_integer_
  }
  if (length(lv) != 1L || is.na(lv)) {
    stop("`level` must be one of 1, 3 or 5 (HQC-1, HQC-3, HQC-5)", call. = FALSE)
  }
  unname(lv)
}

# a key made before the version existed is a v5 key
.rmbl_hqc_key_version <- function(key) {
  v <- key[["version"]]
  if (is.null(v)) return("v5")
  if (!identical(v, "v5") && !identical(v, "round4")) {
    stop("`key$version` must be \"v5\" or \"round4\"", call. = FALSE)
  }
  v
}

.rmbl_hqc_label <- function(x) {
  if (identical(.rmbl_hqc_key_version(x), "round4")) {
    sprintf("HQC-%d (round 4, 2023-04-30)", c(`1` = 128L, `3` = 192L, `5` = 256L)[[as.character(x$level)]])
  } else {
    sprintf("HQC-%d", x$level)
  }
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
