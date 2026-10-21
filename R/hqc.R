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
#' A key encapsulation mechanism (KEM) lets two parties agree on a secret
#' key: the recipient publishes the public half of this key pair, a sender
#' uses it with [hqcencap()] to make a ciphertext
#' and a shared
#' secret, and only the holder of the secret half can recover that secret
#' from the ciphertext with [hqcdecap()]. The shared
#' secret is then
#' used as the key of a symmetric cipher. `hqcpubkey()` strips the
#' secret half so the public key can be handed out.
#'
#' The implementation follows the HQC specification of 2025-08-22 and is byte
#' for byte the scheme of the authors' reference implementation v5.0.0: all
#' 300 official known-answer vectors are reproduced (the package's tests check
#' them). It runs in constant time with respect to secrets -- no secret
#' reaches a branch, a memory index or a variable shift, checked under
#' valgrind memcheck in CI (`inst/ctcheck`: the `hqc1`, `hqc3`,
#' `hqc5`
#' and `hqc1-round4` cases) -- wipes its secret intermediates (the same
#' harness scans the dead stack for them), and gives the same bytes on
#' little- and big-endian machines. On x86-64 processors with PCLMULQDQ and on
#' ARMv8 with the crypto extension the polynomial products use the carry-less
#' multiply instruction; elsewhere a portable constant-time product.
#'
#' NIST will publish HQC-KEM as FIPS 207 but has not yet released it, or a
#' draft of it (checked 2026-10-05). The specification of 2025-08-22 followed
#' here already makes the changes NIST listed for FIPS 207 (the salted FO
#' transform, SHA3-512 seed expansion, the 32-byte shared secret, the new
#' sampler, the seed in the decapsulation key, the seed-only compressed key
#' that [hqccmpkey()] writes); the published
#' standard
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
#' Errors: a `lvl` other than 1, 3, 5, 128, 192 or 256 (a typo is never
#' mapped to a default, because the level is not recorded in the
#' ciphertext); a `seed` that is not a raw vector of exactly
#' `hqcsz(level, version)[["seed"]]` bytes; a `ver` other than
#' `"v5"` or `"round4"`. `hqcpubkey()` errors on anything that is not
#' a
#' `bricklayer_hqc_key`. Key generation takes a few tens of milliseconds even
#' at level 5.
#'
#' @param lvl Security level, as a NIST category: 1, 3 (the default) or 5
#' (HQC-1, HQC-3, HQC-5; 128, 192 and 256 are accepted for the same three).
#' Level 3 matches the category of ML-KEM-768,
#' [kemkg()]'s default.
#' @param seed Optional raw vector. For v5 it is the 32 bytes of `seed_KEM`.
#' For round 4 it is the
#' [hqcsz()]`["seed"]` bytes its key generation
#' draws (`skseed`, `sigma`, `pk_seed`: 96, 104 or 112).
#' Supplying it makes the key reproducible, which is what the known-answer
#' tests need; the default draws from the operating system's CSPRNG.
#' @param ver `"v5"` (the default: the specification of 2025-08-22, a
#' 32-byte shared secret) or `"round4"` (the submission of 2023-04-30, a
#' 64-byte shared secret). Keys remember it; encapsulation and decapsulation
#' follow the key.
#' @return `hqckg()` returns a list of class `bricklayer_hqc_key` with
#' `public` and `secret` (character, lowercase hex of the encapsulation and
#' decapsulation keys; see [hqcsz()] for their byte lengths),
#' `level`
#' (integer 1, 3 or 5) and `version` (`"v5"` or `"round4"`). Its print
#' method shows the level and the start of the public key and withholds the
#' secret. `hqcpubkey()` returns a list of class
#' `bricklayer_hqc_public_key` with `public`, `level` and `version`
#' only. The v5 secret key is the specification's
#' `ek || seed_dk || sigma || seed_KEM`; the round-4 one is
#' `skseed || sigma || ek`.
#' @references Gaborit, P., Aguilar-Melchor, C., Aragon, N., Bettaieb, S.,
#' Bidoux, L., Blazy, O., Deneuville, J.-C., Persichetti, E., Zemor, G.,
#' et al. (2025). Hamming Quasi-Cyclic (HQC), specification of 2025-08-22;
#' reference implementation v5.0.0. <https://pqc-hqc.org/>
#'
#' Alagic, G. et al. (2025). Status Report on the Fourth Round of the NIST
#' Post-Quantum Cryptography Standardization Process. NIST IR 8545.
#' \doi{10.6028/NIST.IR.8545}
#' @seealso
#' [hqcencap()],
#' [hqcdecap()],
#' [hqcsz()],
#' [kemkg()] for ML-KEM.
#' @examples
#' key <- hqckg(1)
#' pub <- hqcpubkey(key)
#'
#' # the sender holds only the public key
#' sent <- hqcencap(pub)
#' # the recipient recovers the same secret from the ciphertext
#' got <- hqcdecap(key, sent$ciphertext)
#' identical(sent$shared, got)
#'
#' # a corrupted ciphertext yields a DIFFERENT secret, not an error
#' bad <- sent$ciphertext
#' substring(bad, 1L, 2L) <- if (substring(bad, 1L, 2L) == "00") "01" else "00"
#' identical(hqcdecap(key, bad), got)
#'
#' # a reproducible key from a fixed seed
#' identical(hqckg(1, seed = as.raw(1:32))$public,
#'           hqckg(1, seed = as.raw(1:32))$public)
#'
#' # the round-4 revision: the same exchange, a 64-byte shared secret
#' old <- hqckg(1, ver = "round4")
#' cap <- hqcencap(hqcpubkey(old))
#' nchar(cap$shared) / 2
#' identical(hqcdecap(old, cap$ciphertext), cap$shared)
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
hqckg <- function(lvl = 3L, seed = NULL, ver = c("v5", "round4")) {
  lvl <- .rmbl_hqc_level(lvl)
  ver <- .rmbl_arg(ver)
  n <- hqcsz(lvl, ver)[["seed"]]
  if (is.null(seed)) {
    seed <- rndbytes(n)
  } else if (!is.raw(seed) || length(seed) != n) {
    stop(sprintf("`seed` must be a raw vector of %d bytes for HQC %s", n, ver), call. = FALSE)
  }
  res <- if (ver == "v5") .Call(C_rmbl_hqc_keygen, lvl, seed) else .Call(C_rmbl_hqc4_keygen, lvl, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              level = lvl, version = ver)
  class(out) <- c("bricklayer_hqc_key", "list")
  out
}

#' @rdname hqckg
#' @param key A key from `hqckg()` (`hqcpubkey()` only).
#' @export
hqcpubkey <- function(key) {
  if (!inherits(key, "bricklayer_hqc_key")) {
    stop("hqcpubkey: `key` must come from hqckg()", call. = FALSE)
  }
  out <- list(public = key$public, level = key$level, version = .rmbl_hqc_key_version(key))
  class(out) <- c("bricklayer_hqc_public_key", "list")
  out
}

#' Byte lengths of an HQC parameter set
#'
#' @description
#' Reports the byte lengths that the HQC specification fixes for a security
#' level: the encapsulation (public) key, the decapsulation (secret) key, the
#' ciphertext, the key-generation seed, the encapsulation randomness and the
#' shared secret. Use it to validate stored keys and ciphertexts, or to size
#' storage, without hard-coding numbers.
#'
#' @details
#' The values come from the compiled implementation, so they are the sizes
#' it actually uses. For \code{version = "v5"} (specification of 2025-08-22):
#'
#' \tabular{lrrr}{
#'   \tab HQC-1 \tab HQC-3 \tab HQC-5 \cr
#'   encapsulation key \tab 2241 \tab 4514 \tab 7237 \cr
#'   decapsulation key \tab 2321 \tab 4602 \tab 7333 \cr
#'   ciphertext \tab 4433 \tab 8978 \tab 14421 \cr
#'   seed \tab 32 \tab 32 \tab 32 \cr
#'   message \tab 16 \tab 24 \tab 32 \cr
#'   salt \tab 16 \tab 16 \tab 16 \cr
#'   shared secret \tab 32 \tab 32 \tab 32
#' }
#' For \code{version = "round4"} the codes are the same but the key encoding
#' differs: the seed is 96, 104 or 112 bytes and the shared secret 64 bytes.
#' A level other than 1, 3, 5 (or 128, 192, 256) is an error.
#'
#' @param lvl Security level: 1, 3 or 5 (or 128, 192, 256 for the same
#'   three). There is no default.
#' @param ver \code{"v5"} (the default) or \code{"round4"}, as in
#'   [hqckg()].
#' @return A named integer vector of byte lengths: `public` (the encapsulation key),
#' `secret` (the decapsulation key), `ciphertext`, `seed` (key generation),
#' `message` and `salt` (encapsulation randomness) and
#' `shared` (the shared secret),
#' named as [hqckg()] and
#' [hqcencap()] name their results.
#' @seealso [hqckg()],
#'   [kemsz()] for ML-KEM.
#' @examples
#' hqcsz(1)
#'
#' # code-based keys and ciphertexts are larger than ML-KEM's at the same
#' # category; the shared secret is 32 bytes at every level (64 in round 4)
#' rbind(HQC = hqcsz(3)[c("public", "ciphertext")],
#'       MLKEM = kemsz(768)[c("public", "ciphertext")])
#' rbind(v5 = hqcsz(1), round4 = hqcsz(1, "round4"))
#'
#' # check a stored public key's length
#' key <- hqckg(1)
#' nchar(key$public) / 2 == hqcsz(1)[["public"]]
#'
#' # an unknown level is refused rather than mapped to a default
#' try(hqcsz(2))
#' @export
hqcsz <- function(lvl, ver = c("v5", "round4")) {
  ver <- .rmbl_arg(ver)
  lv <- .rmbl_hqc_level(lvl)
  if (ver == "v5") .Call(C_rmbl_hqc_sizes, lv) else .Call(C_rmbl_hqc4_sizes, lv)
}

#' Encapsulate a shared secret under an HQC key
#'
#' @description
#' The sender's half of an HQC key exchange. Given the recipient's public
#' key, it draws fresh randomness and produces a ciphertext together with the
#' shared secret that the ciphertext carries. The sender keeps the shared
#' secret (for example as the key of a symmetric cipher) and sends the
#' ciphertext; the recipient recovers the same secret with
#' [hqcdecap()]. Only the public key is needed, and
#' a full key from
#' [hqckg()] is accepted too (its public half is used).
#'
#' @details
#' The level and version are taken from the key. The randomness is a message
#' `m` and a 16-byte `salt`. The length of `m` in bytes is
#' `hqcsz(level)[["message"]]`. They are
#' both
#' drawn with [rndbytes()] from the operating system's
#' generator unless
#' supplied. With the same key, `m` and `salt`, the ciphertext and secret
#' are the same; that is what the known-answer tests need, and it is why
#' fixed values must never be used for real traffic.
#'
#' Errors: `key` not from [hqckg()] or
#' [hqcpubkey()]; a public key
#' of the wrong length for its level; `m` or `salt` of the wrong type or
#' length.
#'
#' @param key A key or public key from [hqckg()] /
#'   [hqcpubkey()].
#' @param m,salt Optional raw vectors of encapsulation randomness, default
#' `NULL` (drawn fresh): `m` of
#' [hqcsz()]`["message"]` bytes (16, 24 or
#' 32) and `salt` of 16 bytes. Supplying them makes the operation
#' reproducible, which is what the known-answer tests need. Reusing them for
#' the same key repeats the shared secret, so supply them only deliberately.
#' @return A list of class `bricklayer_hqc_capsule` with `ciphertext` and
#' `shared` (character, lowercase hex; see [hqcsz()] for
#' the byte
#' lengths: the shared secret is 32 bytes, 64 for a round-4 key), `level`
#' (integer) and `version` (character). The print method withholds the
#' shared secret.
#' @seealso [hqcdecap()],
#'   [hqckg()].
#' @examples
#' key <- hqckg(1)
#' a <- hqcencap(key)
#' nchar(a$ciphertext) / 2 == hqcsz(1)[["ciphertext"]]
#'
#' # two encapsulations to one key give different secrets
#' b <- hqcencap(key)
#' identical(a$shared, b$shared)
#'
#' # both decapsulate correctly
#' identical(hqcdecap(key, a$ciphertext), a$shared)
#' identical(hqcdecap(key, b$ciphertext), b$shared)
#'
#' # fixed randomness repeats the result (for tests only)
#' r1 <- hqcencap(key, m = as.raw(1:16), salt = as.raw(1:16))
#' r2 <- hqcencap(key, m = as.raw(1:16), salt = as.raw(1:16))
#' identical(r1$ciphertext, r2$ciphertext)
#'
#' # randomness of the wrong length is refused
#' try(hqcencap(key, m = as.raw(1:3)))
#' @export
hqcencap <- function(key, m = NULL, salt = NULL) {
  level <- .rmbl_hqc_key_level(key)
  version <- .rmbl_hqc_key_version(key)
  ek <- .rmbl_hex_or_null(key$public)
  sz <- hqcsz(level, version)
  if (is.null(ek) || length(ek) != sz[["public"]]) {
    stop(sprintf("`key` has no usable HQC-%d public key (%d bytes)", level,
                 sz[["public"]]), call. = FALSE)
  }
  if (is.null(m)) {
    m <- rndbytes(sz[["message"]])
  } else if (!is.raw(m) || length(m) != sz[["message"]]) {
    stop(sprintf("`m` must be a raw vector of %d bytes for HQC-%d",
                 sz[["message"]], level), call. = FALSE)
  }
  if (is.null(salt)) {
    salt <- rndbytes(16L)
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
#' @description
#' The recipient's half of an HQC key exchange. Given the key pair from
#' [hqckg()] (with its secret half) and a ciphertext from
#' [hqcencap()], it returns the shared secret the
#' ciphertext carries,
#' as hex (32 bytes; 64 for a round-4 key). The sender and recipient then
#' hold the same secret without it ever having been sent.
#'
#' @details
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
#' A compressed key from [hqccmpkey()] is accepted:
#' the full key pair
#' is derived again from the seed, and the call errors if that does not give
#' the key's own public half. The level and version are taken from the key,
#' so the ciphertext must come from a key of the same level and version.
#'
#' Errors: `key` not an HQC key; a public key (no secret half); a secret of
#' the wrong length; a ciphertext of the wrong length or not valid hex.
#'
#' @param key A key from [hqckg()], with its secret half
#'   (full or
#'   compressed).
#' @param ct Ciphertext from
#'   [hqcencap()], as a hex string or a raw vector.
#' @return The shared secret as a lowercase hex string: 64 characters (32
#' bytes), or 128 for a round-4 key.
#' @seealso [hqcencap()],
#'   [hqccmpkey()].
#' @examples
#' key <- hqckg(1)
#' sent <- hqcencap(hqcpubkey(key))
#' identical(hqcdecap(key, sent$ciphertext), sent$shared)
#'
#' # a tampered ciphertext returns a secret, and it is the wrong one
#' bad <- sent$ciphertext
#' substring(bad, 3L, 4L) <- if (substring(bad, 3L, 4L) == "ff") "fe" else "ff"
#' other <- hqcdecap(key, bad)
#' nchar(other) == 64L
#' identical(other, sent$shared)
#'
#' # the public key alone cannot decapsulate, and a truncated ciphertext
#' # is refused
#' try(hqcdecap(hqcpubkey(key), sent$ciphertext))
#' try(hqcdecap(key, substring(sent$ciphertext, 1L, 100L)))
#' @export
hqcdecap <- function(key, ct) {
  .rmbl_no_fn(ciphertext = ct)
  level <- .rmbl_hqc_key_level(key)
  version <- .rmbl_hqc_key_version(key)
  if (is.null(key[["secret"]])) {
    stop("hqcdecap: decapsulation needs a key with its secret half", call. = FALSE)
  }
  sz <- hqcsz(level, version)
  dk <- .rmbl_hex_or_null(key$secret)
  if (length(dk) == sz[["seed"]]) dk <- .rmbl_hqc_expand(key, dk, level, version)
  if (is.null(dk) || length(dk) != sz[["secret"]]) {
    stop(sprintf("`key` has no usable HQC-%d secret key (%d bytes)", level,
                 sz[["secret"]]), call. = FALSE)
  }
  .ct <- if (is.raw(ct)) ct else .rmbl_hex_or_null(ct)
  if (is.null(.ct) || length(.ct) != sz[["ciphertext"]]) {
    stop(sprintf("`ct` must be %d bytes for HQC-%d",
                 sz[["ciphertext"]], level), call. = FALSE)
  }
  out <- if (version == "v5") .Call(C_rmbl_hqc_decaps, level, dk, .ct) else .Call(C_rmbl_hqc4_decaps, level, dk, .ct)
  .rmbl_hexlify(out)
}

#' The compressed HQC decapsulation key
#'
#' @description
#' Shrinks an HQC key pair for storage by replacing its secret half with the
#' seed it was generated from (32 bytes for v5, instead of several
#' kilobytes). The full key is derived again from the seed whenever
#' [hqcdecap()] needs it, so a compressed key works
#' everywhere a full
#' one does in this package.
#'
#' @details
#' The HQC specification of 2025-08-22 allows the decapsulation key to be
#' stored as its 32-byte `seed_KEM` alone (the compressed format
#' `dk_KEM = (seed_KEM)`), from which the whole key pair is derived again.
#' `hqccmpkey()` keeps only that seed;
#' [hqcdecap()] takes such a
#' key and expands it, and refuses one whose seed does not derive the key's
#' public half.
#'
#' The round-4 revision (64-byte shared secret) defines no compressed format,
#' but its key pair is derived from the randomness its key generation draws,
#' `skseed || sigma || pk_seed` (96, 104 or 112 bytes: the `seed` of
#' [hqckg()] and
#' [hqcsz()]), all of which its secret key
#' `skseed || sigma || pk_seed || s` carries. For a round-4 key the compressed
#' form is that seed: this package's convention, not a format of the
#' submission, so software built on round 4 (liboqs, PQClean) expects the
#' full secret key.
#'
#' A key that is already compressed is returned unchanged. Errors: `key` not
#' from [hqckg()]; a secret of neither the full nor the
#' seed length.
#' The public half is kept, and anyone with the seed can rebuild the whole
#' secret key, so the compressed key must be protected exactly like the full
#' one.
#'
#' @param key A key from [hqckg()].
#' @return The key (class `bricklayer_hqc_key`) with `secret` replaced by
#' the hex of its seed: 32 bytes for v5, 96, 104 or 112 for round 4. The
#' other elements are unchanged.
#' @references Gaborit, P. et al. (2025). Hamming Quasi-Cyclic (HQC),
#' specification of 2025-08-22, section 3 (HQC-KEM key pair formats).
#' <https://pqc-hqc.org/>
#' @seealso [hqckg()],
#'   [hqcdecap()]
#' @examples
#' key <- hqckg(1)
#' small <- hqccmpkey(key)
#' nchar(small$secret) / 2
#' sent <- hqcencap(hqcpubkey(key))
#' identical(hqcdecap(small, sent$ciphertext), sent$shared)
#'
#' # compressing twice changes nothing
#' identical(hqccmpkey(small), small)
#'
#' # a seed paired with someone else's public key is refused on use
#' spliced <- small
#' spliced$public <- hqckg(1)$public
#' try(hqcdecap(spliced, sent$ciphertext))
#' @export
hqccmpkey <- function(key) {
  if (!inherits(key, "bricklayer_hqc_key")) {
    stop("hqccmpkey: `key` must come from hqckg()", call. = FALSE)
  }
  version <- .rmbl_hqc_key_version(key)
  sz <- hqcsz(key$level, version)
  dk <- .rmbl_hex_or_null(key$secret)
  n <- length(dk)
  if (n == sz[["seed"]]) return(key)
  if (n != sz[["secret"]]) {
    stop("`key` has no usable HQC secret key", call. = FALSE)
  }
  # v5: dk = ek, seed_dk, sigma, seed_KEM, so the seed is its last 32 bytes
  key$secret <- .rmbl_hexlify(if (version == "v5") {
    dk[(n - 31L):n]
  } else {
    # skseed || sigma || ek with ek = pk_seed || s: the seed is the first
    # skseed || sigma bytes and the first 40 bytes of ek
    k <- sz[["seed"]] - 80L
    dk[c(seq_len(40L + k), 40L + k + seq_len(40L))]
  })
  key
}

#' Expands a compressed HQC decapsulation key from its seed.
#'
#' A compressed decapsulation key: re-derive the pair from its seed, and
#' refuse a seed that does not give the key's own public half
#' @param key The key.
#' @param seed The seed it was made from.
#' @param level The parameter set, 1, 3 or 5.
#' @param version \code{"v5"} or \code{"round4"}.
#' @return The full secret key as hex, or NULL.
#' @noRd
.rmbl_hqc_expand <- function(key, seed, level, version) {
  full <- hqckg(level, seed = seed, ver = version)
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

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_key
print.bricklayer_hqc_key <- .rmbl_print_via_format

#' @export
format.bricklayer_hqc_public_key <- function(x, ...) {
  c(.rmbl_rule("Public encapsulation key (HQC, code-based)"),
    .rmbl_kv(list(level = .rmbl_hqc_label(x),
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_public_key
print.bricklayer_hqc_public_key <- .rmbl_print_via_format

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

#' @rdname printmeth
#' @export
#' @method print bricklayer_hqc_capsule
print.bricklayer_hqc_capsule <- .rmbl_print_via_format

#' Maps a level to its HQC parameter set.
#'
#' The three parameter sets, by NIST category (or its security in bits).
#' A typo must fail rather than select a default: the level is not recorded
#' in the ciphertext, so both sides have to agree on it by other means.
#' @param level 1, 3 or 5, or 128, 192 or 256.
#' @return 1, 3 or 5.
#' @noRd
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

#' A key made before the version existed is a v5 key
#' @param key The key.
#' @return \code{"v5"} or \code{"round4"}.
#' @noRd
.rmbl_hqc_key_version <- function(key) {
  v <- key[["version"]]
  if (is.null(v)) return("v5")
  if (!identical(v, "v5") && !identical(v, "round4")) {
    stop("`key$version` must be \"v5\" or \"round4\"", call. = FALSE)
  }
  v
}

#' Names a key's parameter set for printing.
#' @param x The key.
#' @return One string.
#' @noRd
.rmbl_hqc_label <- function(x) {
  if (identical(.rmbl_hqc_key_version(x), "round4")) {
    sprintf("HQC-%d (round 4, 2023-04-30)", c(`1` = 128L, `3` = 192L, `5` = 256L)[[as.character(x$level)]])
  } else {
    sprintf("HQC-%d", x$level)
  }
}

#' Returns the parameter set of a key from hqckg() or hqcpubkey().
#' @param key The key.
#' @return 1, 3 or 5.
#' @noRd
.rmbl_hqc_key_level <- function(key) {
  if (!inherits(key, c("bricklayer_hqc_key", "bricklayer_hqc_public_key"))) {
    stop("`key` must come from hqckg() or hqcpubkey()",
         call. = FALSE)
  }
  .rmbl_hqc_level(key$level)
}
