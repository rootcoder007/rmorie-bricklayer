# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Keys, rather than data. Three things a provenance tool needs and the
# package previously left to the caller: unguessable random bytes, a way
# to turn a passphrase into a key, and a modern keyed digest.

#' Cryptographically strong random bytes
#'
#' Reads the operating system's own random source -- `/dev/urandom` on
#' Unix and macOS, `RtlGenRandom` on Windows -- rather than R's
#' Mersenne Twister.
#'
#' This distinction matters for anything that becomes a key.
#' [set.seed()] makes R's generator reproducible BY
#' DESIGN, and its state can be recovered from its output; a key drawn from
#' it is guessable. Reading the OS source also leaves R's own random stream
#' untouched, so generating a key does not perturb a reproducible analysis.
#'
#' If no OS source can be read the function FAILS rather than falling back
#' to a weaker generator, because a silent downgrade in a key is worse than
#' an error.
#'
#' @param n Number of bytes (1 to 1048576).
#' @return A raw vector of length `n`.
#' @seealso
#' [derive_key()] to stretch a passphrase instead,
#' [pqc_keygen()] which uses this for its seeds.
#' @examples
#' random_bytes(8)
#'
#' # Independent between calls, unlike a seeded generator.
#' identical(random_bytes(16), random_bytes(16))
#'
#' # R's own stream is not consumed, so a seeded analysis is unaffected.
#' set.seed(1)
#' a <- stats::runif(1)
#' set.seed(1)
#' invisible(random_bytes(32))
#' identical(stats::runif(1), a)
#'
#' # As hex, for a seed argument.
#' paste(format(random_bytes(4)), collapse = "")
#' @export
random_bytes <- function(n) {
  n <- as.integer(n)
  if (length(n) != 1L || is.na(n) || n < 1L || n > 1048576L) {
    stop("`n` must be a single integer between 1 and 1048576", call. = FALSE)
  }
  out <- .Call(C_rmbl_os_random, n)
  if (is.null(out)) {
    stop("no operating-system random source could be read. Refusing to ",
         "fall back to R's generator, which is reproducible by design ",
         "and unsuitable for a key: supply key material yourself.",
         call. = FALSE)
  }
  out
}

#' Derive a key from a passphrase
#'
#' PBKDF2-HMAC-SHA256 (RFC 8018): stretches a passphrase into a key of full
#' width by iterating a keyed hash, so guessing the passphrase costs
#' `iterations` times more than a single hash would.
#'
#' The `salt` must be UNIQUE per key and need not be secret. Its job
#' is to make precomputation useless: without one, a single table of common
#' passphrases attacks every key at once.
#'
#' `iterations` is the cost knob. The default 100,000 is a reasonable
#' 2020s floor for an interactive use; raise it for anything valuable, and
#' record the value you used, since verification must repeat it exactly.
#'
#' PBKDF2 resists brute force by ITERATION only, not by memory. Where a
#' memory-hard function is available ( `argon2` in \pkg{sodium},
#' `bcrypt_pbkdf` in \pkg{openssl}) prefer it for passwords a human
#' chose. PBKDF2 is here because it needs nothing beyond the bundled
#' SHA-256, so it works wherever this package works.
#'
#' @param passphrase Passphrase, as a length-1 character
#' or raw vector.
#' @param salt Unique, non-secret salt (length-1 character or
#' raw). Use [random_bytes()] to make one, and
#' store it beside the key.
#' @param iterations Iteration count (default 100000,
#' minimum 1).
#' @param length Derived key length in bytes (default 32).
#' @return A length-1 character vector: the key as lowercase hex.
#' @references Moriarty K, Kaliski B, Rusch A (2017). PKCS #5:
#' Password-Based Cryptography Specification Version 2.1. RFC 8018.
#'   \doi{10.17487/RFC8018}
#' @seealso
#' [random_bytes()],
#' [core_hmac_sha256()],
#' [capsule_sign()]
#' @examples
#' # The published PBKDF2-HMAC-SHA256 vector: "password", "salt", 1 round.
#' derive_key("password", "salt", iterations = 1)
#'
#' # Deterministic, so verification can repeat it.
#' identical(derive_key("pw", "s", 1000), derive_key("pw", "s", 1000))
#'
#' # The salt, the passphrase and the iteration count all change the key.
#' derive_key("pw", "salt-a", 1000) == derive_key("pw", "salt-b", 1000)
#' derive_key("pw", "s", 1000) == derive_key("pw", "s", 2000)
#'
#' # Use it to sign a manifest from a passphrase rather than raw bytes.
#' salt <- paste(format(random_bytes(16)), collapse = "")
#' key <- derive_key("correct horse battery staple", salt)
#' sig <- capsule_sign("manifest-digest", key, scheme = "hmac")
#' capsule_verify("manifest-digest", sig, key)
#'
#' # A longer key is a prefix-consistent extension of a shorter one.
#' identical(substring(derive_key("pw", "s", 10, length = 64), 1, 64),
#'           derive_key("pw", "s", 10, length = 32))
#' @export
derive_key <- function(passphrase, salt, iterations = 100000L,
                       length = 32L) {
  if (!is.raw(passphrase)) {
    passphrase <- as.character(passphrase)
    if (base::length(passphrase) != 1L || is.na(passphrase)) {
      stop("`passphrase` must be a length-1 character vector or raw vector",
           call. = FALSE)
    }
  }
  if (!is.raw(salt)) {
    salt <- as.character(salt)
    if (base::length(salt) != 1L || is.na(salt)) {
      stop("`salt` must be a length-1 character vector or raw vector",
           call. = FALSE)
    }
  }
  iterations <- as.integer(iterations)
  if (base::length(iterations) != 1L || is.na(iterations) ||
      iterations < 1L) {
    stop("`iterations` must be a single integer of at least 1", call. = FALSE)
  }
  length <- as.integer(length)
  if (base::length(length) != 1L || is.na(length) || length < 1L ||
      length > 1024L) {
    stop("`length` must be a single integer between 1 and 1024",
         call. = FALSE)
  }
  .Call(C_rmbl_pbkdf2, passphrase, salt, iterations, length)
}

#' BLAKE2b digest, optionally keyed
#'
#' BLAKE2b (RFC 7693): a modern cryptographic hash, faster than SHA-256 in
#' software, that takes a key natively and produces any digest length from
#' 1 to 64 bytes.
#'
#' The native key is the interesting part. A keyed BLAKE2b IS a message
#' authentication code, with no HMAC wrapper and so no doubled hashing --
#' `core_blake2b(msg, key = k)` does the job of
#' [core_hmac_sha256()] at lower cost. Use
#' SHA-256 or HMAC where interoperability with other tools matters; use
#' this where it does not and speed does.
#'
#' @param x A character vector or a raw vector.
#' @param key Optional key, at most 64 bytes. `NULL`
#' (default) gives the plain digest.
#' @param length Digest length in bytes, 1 to 64 (default 32,
#' matching SHA-256's width).
#' @return A character vector of lowercase hex digests -- one per element
#' for character input, length-1 for raw input.
#' @references Saarinen MJ, Aumasson JP (2015). The BLAKE2 Cryptographic
#' Hash and Message Authentication Code (MAC). RFC 7693.
#'   \doi{10.17487/RFC7693}
#' @seealso
#' [core_sha256()],
#' [core_sha512()],
#' [core_hmac_sha256()]
#' @examples
#' # The RFC 7693 test vector for BLAKE2b-512 of "abc".
#' core_blake2b("abc", length = 64)
#'
#' # 32 bytes by default, the same width as SHA-256.
#' core_blake2b("abc")
#' nchar(core_blake2b("abc"))
#'
#' # Any digest length, which SHA-2 cannot do.
#' core_blake2b("abc", length = 8)
#'
#' # Keyed, so it authenticates without an HMAC construction.
#' core_blake2b("manifest", key = "secret")
#' core_blake2b("manifest", key = "secret") ==
#'   core_blake2b("manifest", key = "other")
#'
#' # Vectorised, and raw input hashes the same bytes.
#' core_blake2b(c("a", "b"))
#' identical(core_blake2b("abc"), core_blake2b(charToRaw("abc")))
#' @export
core_blake2b <- function(x, key = NULL, length = 32L) {
  length <- as.integer(length)
  if (base::length(length) != 1L || is.na(length) || length < 1L ||
      length > 64L) {
    stop("`length` must be a single integer between 1 and 64", call. = FALSE)
  }
  if (!is.null(key) && !is.raw(key)) {
    key <- as.character(key)
    if (base::length(key) != 1L || is.na(key)) {
      stop("`key` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (is.raw(x)) return(.Call(C_rmbl_blake2b, x, key, length))
  .Call(C_rmbl_blake2b, as.character(x), key, length)
}

#' Digest an arbitrary R object
#'
#' Fingerprints any R object by hashing its serialization, so a list, a
#' data frame, a function or a fitted model all get a stable digest. The
#' counterpart of `digest::digest()`, computed with this package's own
#' hashes.
#'
#' Serialization is pinned to version 2 with XDR byte order, so the digest
#' is the same on a big-endian machine as on a little-endian one. Two
#' objects that are `identical()` produce the same digest; two that
#' merely print the same need not, because attributes are part of the
#' serialization.
#'
#' @param x Any R object.
#' @param algo `"sha256"` (default), `"sha512"`,
#' `"blake2b"` or `"crc32"`.
#' @param key Optional key, for `"blake2b"` only: gives a
#' keyed fingerprint that only a key holder can reproduce.
#' @return A length-1 character vector (or numeric for `"crc32"`) .
#' @seealso
#' [core_sha256()] for hashing text or bytes
#' directly,
#' [bricklayer_json_serialize()]
#' for a readable lossless form.
#' @examples
#' digest_object(list(a = 1L, b = "x"))
#'
#' # Stable across calls, and sensitive to any change.
#' identical(digest_object(1:10), digest_object(1:10))
#' digest_object(1:10) == digest_object(1:11)
#'
#' # Attributes are part of the object, so they are part of the digest.
#' digest_object(matrix(1:6, nrow = 2)) == digest_object(1:6)
#'
#' # Any of the hashes, and a keyed fingerprint.
#' digest_object(mtcars, algo = "sha512")
#' digest_object(mtcars, algo = "crc32")
#' digest_object(mtcars, algo = "blake2b", key = "secret")
#'
#' # A data frame's digest pins the data, so it can go in a manifest.
#' digest_object(data.frame(x = 1:3))
#' @export
digest_object <- function(x, algo = c("sha256", "sha512", "blake2b",
                                      "crc32"), key = NULL) {
  algo <- match.arg(algo)
  bytes <- serialize(x, NULL, version = 2L, xdr = TRUE)
  if (!is.null(key)) {
    # A keyed digest authenticates; an unkeyed one only detects
    # accidental change. Returning the unkeyed digest because the chosen
    # algorithm has no keyed form would answer the stronger request with
    # the weaker guarantee, so refuse instead.
    if (!algo %in% c("sha256", "blake2b")) {
      stop(sprintf(
        "`key` is not supported for algo = \"%s\"; keyed digests are available for \"sha256\" (HMAC-SHA-256) and \"blake2b\"",
        algo), call. = FALSE)
    }
    return(switch(algo,
      sha256 = core_hmac_sha256(key, bytes),
      blake2b = core_blake2b(bytes, key = key, length = 32L)))
  }
  switch(algo,
    sha256 = core_sha256(bytes),
    sha512 = core_sha512(bytes),
    crc32 = core_crc32(bytes),
    blake2b = core_blake2b(bytes, length = 32L))
}
