# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Signed provenance. A SHA-256 in a manifest proves the data was not
# CORRUPTED; it proves nothing about who produced it, because anyone who
# edits the data can recompute the digest. Signing closes that gap.
#
# Two schemes, for two different trust models:
#
#   "hmac"  -- symmetric. Signer and verifier share one secret. Simple
#              and fast, but a verifier can also forge, so it only
#              answers "did someone holding our key build this".
#   "xmss"  -- hash-based, post-quantum, asymmetric. The verifier holds
#              only a public root and cannot forge. Signs 2^height
#              messages and NO MORE (see the reuse warning below).

#' Available post-quantum signature schemes
#'
#' Reports the signature schemes this package implements. The list is
#' fixed, not probed: all of them are implemented in the package's own C++
#' and none depends on a system library, so a scheme available on one
#' machine is available on every machine.
#'
#' `"xmss-sha256"` is the stateful hash-based scheme of
#' [pqc_keygen()]. The rest are the NIST
#' standards, taken with [fips_keygen()]: ML-DSA
#' (FIPS 204) at all three parameter sets, and SLH-DSA (FIPS 205) at all
#' twelve -- six over SHAKE and six over SHA-2, which are different schemes
#' and not merely different code paths.
#'
#' @return A character vector of scheme names, `"xmss-sha256"` first.
#' @seealso
#' [fips_keygen()] for the standardised schemes,
#' [pqc_keygen()] for the stateful one.
#' @examples
#' pqc_backends()
#'
#' # Every scheme is present in every build.
#' all(c("xmss-sha256", "ML-DSA-65", "SLH-DSA-SHAKE-128s") %in%
#'     pqc_backends())
#' @export
pqc_backends <- function() .Call(C_rmbl_pqc_backends)

#' Generate a standardised post-quantum signing key
#'
#' Generates a key for one of the NIST-standardised signature schemes:
#' ML-DSA (FIPS 204) or SLH-DSA (FIPS 205). Both are implemented in this
#' package, natively, with no system dependency;
#' [pqc_backends()] lists the parameter sets.
#'
#' Unlike [pqc_keygen()] 's hash-based key, these
#' are STATELESS: one key signs any number of messages, with no index to
#' track and nothing to persist between signatures.
#'
#' Which to pick. ML-DSA is small and fast and rests on a lattice
#' assumption. SLH-DSA rests on nothing but the hash function, at the cost
#' of a signature one to two orders of magnitude larger; its `s`
#' parameter sets have small signatures and slow signing, its `f` sets
#' the reverse, and its SHAKE and SHA-2 families are equally strong: pick
#' SHA-2 where a validated SHA-2 implementation is what an auditor will ask
#' about. `"ML-DSA-65"` is the sensible default.
#'
#' @param scheme Scheme name, one of
#' [pqc_backends()] other than
#' `"xmss-sha256"`. The default `"ML-DSA-65"` is the FIPS 204
#' middle security level.
#' @param seed Optional raw vector of key-generation seed
#' bytes, of the length [fips_sizes()] reports for
#' the scheme. Supplying it makes the key reproducible, which is what the
#' standards' test vectors need; the default draws from the operating
#' system's CSPRNG.
#' @return A list of class `bricklayer_fips_key`: `public`,
#' `secret` (both hex), and `scheme`.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Digital Signature Standard. FIPS 204.
#'   \doi{10.6028/NIST.FIPS.204}
#'
#' National Institute of Standards and Technology (2024). Stateless
#' Hash-Based Digital Signature Standard. FIPS 205.
#'   \doi{10.6028/NIST.FIPS.205}
#' @seealso
#' [pqc_keygen()] for the stateful hash-based key,
#' [capsule_sign()] which accepts either,
#' [fips_sizes()] for the byte lengths.
#' @examples
#' key <- fips_keygen("ML-DSA-65")
#' key$scheme
#'
#' sig <- capsule_sign("a manifest digest", key)
#' capsule_verify("a manifest digest", sig, fips_public_key(key))
#'
#' # A context string binds the signature to its purpose: the same
#' # message signed for one context does not verify under another.
#' sig2 <- capsule_sign("a manifest digest", key, context = "release")
#' capsule_verify("a manifest digest", sig2, key, context = "release")
#' capsule_verify("a manifest digest", sig2, key, context = "staging")
#' @export
fips_keygen <- function(scheme = "ML-DSA-65", seed = NULL) {
  scheme <- .rmbl_fips_scheme(scheme)
  sz <- fips_sizes(scheme)
  if (is.null(seed)) {
    seed <- random_bytes(sz[["seed"]])
  } else if (!is.raw(seed) || length(seed) != sz[["seed"]]) {
    stop(sprintf("`seed` must be a raw vector of %d bytes for %s",
                 sz[["seed"]], scheme), call. = FALSE)
  }
  res <- .rmbl_fips_keypair(scheme, seed)
  out <- list(public = .rmbl_hexlify(res$public),
              secret = .rmbl_hexlify(res$secret),
              scheme = scheme)
  class(out) <- c("bricklayer_fips_key", "bricklayer_oqs_key", "list")
  out
}

#' @rdname fips_keygen
#' @param key A key from `fips_keygen()`.
#' @export
fips_public_key <- function(key) {
  if (!inherits(key, "bricklayer_oqs_key")) {
    stop("`key` must come from fips_keygen()", call. = FALSE)
  }
  out <- list(public = key$public, scheme = key$scheme)
  class(out) <- c("bricklayer_fips_public_key",
                  "bricklayer_oqs_public_key", "list")
  out
}

#' Assemble a standardised key from raw key material
#'
#' Wraps key bytes that came from somewhere else -- another implementation,
#' a key store, a file written by an earlier session -- in the object
#' [capsule_sign()] and
#' [capsule_verify()] expect. The lengths are
#' checked against the parameter set, so material for the wrong scheme is
#' refused here rather than producing a signature nothing can verify.
#'
#' The byte layouts are the standards' own, which is what makes this
#' interoperable: an ML-DSA secret key is
#' `rho || K || tr || s1 || s2 || t0` and an SLH-DSA one is
#' `SK.seed || SK.prf || PK.seed || PK.root`, exactly as FIPS 204 and
#' FIPS 205 encode them.
#'
#' @param scheme Scheme name, as in
#' [fips_keygen()].
#' @param public Public key, hex or raw.
#' @param secret Secret key, hex or raw. Omit for a
#' verification-only key.
#' @return A `bricklayer_fips_key` when `secret` is given,
#' otherwise a `bricklayer_fips_public_key`.
#' @seealso
#' [fips_keygen()],
#' [fips_sizes()].
#' @examples
#' key <- fips_keygen("ML-DSA-44")
#' # the round trip through raw material changes nothing
#' again <- fips_key("ML-DSA-44", key$public, key$secret)
#' identical(again$secret, key$secret)
#'
#' sig <- capsule_sign("m", again)
#' capsule_verify("m", sig, fips_key("ML-DSA-44", key$public))
#'
#' # material of the wrong length is refused
#' try(fips_key("ML-DSA-65", key$public, key$secret))
#' @export
fips_key <- function(scheme, public, secret = NULL) {
  scheme <- .rmbl_fips_scheme(scheme)
  sz <- fips_sizes(scheme)
  pub <- .rmbl_fips_material(public, sz[["public_key"]], "public", scheme)
  if (is.null(secret)) {
    out <- list(public = pub, scheme = scheme)
    class(out) <- c("bricklayer_fips_public_key",
                    "bricklayer_oqs_public_key", "list")
    return(out)
  }
  out <- list(public = pub,
              secret = .rmbl_fips_material(secret, sz[["secret_key"]],
                                           "secret", scheme),
              scheme = scheme)
  class(out) <- c("bricklayer_fips_key", "bricklayer_oqs_key", "list")
  out
}

# Key material as hex, whatever it arrived as, with its length checked
# against the parameter set.
.rmbl_fips_material <- function(x, n, what, scheme) {
  hex <- if (is.raw(x)) {
    .rmbl_hexlify(x)
  } else {
    h <- as.character(x)[1L]
    # not .rmbl_hex_or_null(): that decodes to bytes, and what is wanted
    # here is the validated STRING, since a key is carried as hex
    if (is.na(h) || nchar(h) %% 2L != 0L ||
        !grepl("^[0-9a-fA-F]*$", h)) NULL else tolower(h)
  }
  if (is.null(hex) || nchar(hex) %/% 2L != n) {
    stop(sprintf("`%s` must be %d bytes of key material for %s", what, n,
                 scheme), call. = FALSE)
  }
  hex
}

#' Sign an ML-DSA message digest computed elsewhere
#'
#' The external-mu interface. `fips_mu()` reduces a message to the
#' 64-byte value mu that is the only thing ML-DSA signing actually
#' consumes; `fips_sign_mu()` signs that value and
#' `fips_verify_mu()` checks it.
#'
#' The point is that the message need never reach the key. A large file can
#' be reduced to mu on the machine that holds it and only mu handed to
#' whatever holds the signing key -- a smartcard, a remote signer, another
#' process. mu is not a bare digest: it binds the public key (through
#' `tr = H(pk)`) and the context string, so a mu computed under one
#' key cannot be signed under another to any useful effect.
#'
#' The resulting signature is an ordinary ML-DSA signature.
#' [capsule_verify()] accepts it, given the
#' same message and context.
#'
#' @param key A key from
#' [fips_keygen()] or
#' [fips_key()]. An ML-DSA scheme: SLH-DSA has no
#' external-mu interface, because its digest depends on per-signature
#' randomness that the signer chooses.
#' @param message Length-1 character vector or raw vector.
#' @param context Optional context string, as in
#' [capsule_sign()].
#' @param prehash Pre-hash function, as in
#' [capsule_sign()].
#' @param mu The 64 raw bytes from `fips_mu()`.
#' @param deterministic As in
#' [capsule_sign()].
#' @param signature A signature from `fips_sign_mu()`
#' or [capsule_sign()].
#' @return `fips_mu()` returns 64 raw bytes; `fips_sign_mu()` a
#' `bricklayer_signature`; `fips_verify_mu()` a length-1 logical.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Digital Signature Standard. FIPS 204.
#'   \doi{10.6028/NIST.FIPS.204}
#' @seealso
#' [capsule_sign()],
#' [fips_keygen()].
#' @examples
#' key <- fips_keygen("ML-DSA-65")
#' mu <- fips_mu(key, "a manifest digest", context = "release")
#' length(mu)
#'
#' sig <- fips_sign_mu(key, mu)
#' fips_verify_mu(key, mu, sig)
#'
#' # the same signature verifies the ordinary way, from the message
#' capsule_verify("a manifest digest", sig, key, context = "release")
#'
#' # mu is computable from the PUBLIC key alone, which is what lets the
#' # message stay on the machine that has it
#' identical(fips_mu(fips_public_key(key), "a manifest digest",
#'                   context = "release"), mu)
#' @export
fips_mu <- function(key, message, context = NULL, prehash = "none") {
  scheme <- .rmbl_fips_key_scheme(key)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) {
    stop("external mu is an ML-DSA interface; ", scheme,
         " has no equivalent", call. = FALSE)
  }
  pk <- .rmbl_hex_or_null(key$public)
  if (is.null(pk)) stop("`key` has no usable public key", call. = FALSE)
  .Call(C_rmbl_mldsa_mu, mode, pk, .rmbl_sign_message(message),
        .rmbl_fips_context(context), .rmbl_fips_prehash(prehash))
}

#' @rdname fips_mu
#' @export
fips_sign_mu <- function(key, mu, deterministic = FALSE) {
  scheme <- .rmbl_fips_key_scheme(key)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) {
    stop("external mu is an ML-DSA interface; ", scheme,
         " has no equivalent", call. = FALSE)
  }
  if (is.null(key[["secret"]])) {
    stop("signing needs a key with its secret half", call. = FALSE)
  }
  if (!is.raw(mu) || length(mu) != 64L) {
    stop("`mu` must be 64 raw bytes, as returned by fips_mu()",
         call. = FALSE)
  }
  rnd <- if (isTRUE(deterministic)) raw(32L) else random_bytes(32L)
  sg <- .Call(C_rmbl_mldsa_sign_mu, mode, .rmbl_hex_to_raw(key$secret),
              mu, rnd)
  out <- list(scheme = scheme, signature = .rmbl_hexlify(sg))
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' @rdname fips_mu
#' @export
fips_verify_mu <- function(key, mu, signature) {
  scheme <- .rmbl_fips_key_scheme(key)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) {
    stop("external mu is an ML-DSA interface; ", scheme,
         " has no equivalent", call. = FALSE)
  }
  if (!inherits(signature, "bricklayer_signature")) {
    stop("`signature` must come from fips_sign_mu() or capsule_sign()",
         call. = FALSE)
  }
  if (!identical(signature$scheme, scheme)) return(FALSE)
  if (!is.raw(mu) || length(mu) != 64L) return(FALSE)
  pk <- .rmbl_hex_or_null(key$public)
  sg <- .rmbl_hex_or_null(signature$signature)
  if (is.null(pk) || is.null(sg)) return(FALSE)
  .Call(C_rmbl_mldsa_verify_mu, mode, pk, mu, sg)
}

# The scheme a key object names, refusing anything that is not one of
# ours rather than reaching into an arbitrary list.
.rmbl_fips_key_scheme <- function(key) {
  if (!inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    stop("`key` must come from fips_keygen() or fips_key()", call. = FALSE)
  }
  .rmbl_fips_scheme(key$scheme)
}

#' Byte lengths of a standardised signature scheme
#'
#' Reports the sizes fixed by a FIPS 204 or FIPS 205 parameter set, so a
#' caller never has to hard-code them.
#'
#' @param scheme Scheme name, as in
#' [fips_keygen()].
#' @return A named integer vector: `public_key`, `secret_key`,
#' `signature`, `seed` and `opt_rand`, all in bytes.
#' `opt_rand` is the per-signature randomness the scheme consumes.
#' @seealso
#' [fips_keygen()],
#' [pqc_backends()].
#' @examples
#' fips_sizes("ML-DSA-65")
#' fips_sizes("SLH-DSA-SHAKE-128s")
#'
#' # An SLH-DSA signature is far larger than an ML-DSA one at the same
#' # security level, which is the price of dropping the lattice
#' # assumption.
#' fips_sizes("SLH-DSA-SHAKE-128s")[["signature"]] >
#'   fips_sizes("ML-DSA-44")[["signature"]]
#' @export
fips_sizes <- function(scheme) {
  scheme <- .rmbl_fips_scheme(scheme)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    sz <- .Call(C_rmbl_mldsa_sizes, mode)
    return(c(sz, opt_rand = 32L))
  }
  sz <- .Call(C_rmbl_slhdsa_sizes, scheme)
  # SLH-DSA draws its key from three n-byte seeds and its per-signature
  # randomness from one, so n follows from the seed length.
  c(sz, opt_rand = sz[["seed"]] %/% 3L)
}

# The parameter-set name, validated against what the package implements.
# A typo must fail here rather than silently selecting a default, since
# the scheme is baked into every signature the key goes on to produce.
.rmbl_fips_scheme <- function(scheme) {
  scheme <- as.character(scheme)[1L]
  if (is.na(scheme) || !nzchar(scheme)) {
    stop("`scheme` must be a non-empty string", call. = FALSE)
  }
  known <- setdiff(pqc_backends(), "xmss-sha256")
  if (!scheme %in% known) {
    stop(sprintf(paste0("unknown scheme '%s'. The standardised schemes ",
                        "are: %s. For the stateful hash-based scheme ",
                        "use pqc_keygen()."),
                 scheme, paste(known, collapse = ", ")), call. = FALSE)
  }
  scheme
}

# NA for an SLH-DSA set, the FIPS 204 mode number for an ML-DSA one.
.rmbl_fips_mldsa_mode <- function(scheme) {
  if (!grepl("^ML-DSA-", scheme)) return(NA_integer_)
  as.integer(sub("^ML-DSA-", "", scheme))
}

.rmbl_fips_keypair <- function(scheme, seed) {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) return(.Call(C_rmbl_mldsa_keypair, mode, seed))
  .Call(C_rmbl_slhdsa_keypair, scheme, seed)
}

.rmbl_fips_sign <- function(scheme, sk, msg, ctx, rnd, prehash = "none") {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    return(.Call(C_rmbl_mldsa_sign, mode, sk, msg, ctx, rnd, prehash))
  }
  .Call(C_rmbl_slhdsa_sign, scheme, sk, msg, ctx, rnd, prehash)
}

.rmbl_fips_verify <- function(scheme, pk, msg, ctx, sig,
                              prehash = "none") {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    return(.Call(C_rmbl_mldsa_verify, mode, pk, msg, ctx, sig, prehash))
  }
  .Call(C_rmbl_slhdsa_verify, scheme, pk, msg, ctx, sig, prehash)
}

# The pre-hash name, validated here so a typo cannot be read as "none"
# and quietly produce a pure signature instead of the requested one.
.rmbl_fips_prehash <- function(prehash) {
  if (is.null(prehash)) return("none")
  prehash <- as.character(prehash)[1L]
  if (is.na(prehash)) prehash <- "none"
  match.arg(prehash, c("none", "sha256", "sha512", "shake128", "shake256"))
}

# A context string is at most 255 bytes because the FIPS 204 and 205
# message encodings write its length in one byte.
.rmbl_fips_context <- function(context) {
  if (is.null(context)) return(raw(0L))
  if (is.raw(context)) {
    ctx <- context
  } else {
    context <- as.character(context)
    if (length(context) != 1L || is.na(context)) {
      stop("`context` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
    ctx <- charToRaw(context)
  }
  if (length(ctx) > 255L) {
    stop("`context` must be at most 255 bytes", call. = FALSE)
  }
  ctx
}

#' Generate a standardised post-quantum signing key (deprecated name)
#'
#' Kept so code written against the liboqs-backed version keeps working.
#' The schemes are no longer reached through liboqs -- they are implemented
#' in this package -- and the name no longer describes anything, so use
#' [fips_keygen()] instead.
#'
#' @param scheme Scheme name; see
#' [fips_keygen()].
#' @param key A key from `oqs_keygen()`.
#' @return As [fips_keygen()] and
#' [fips_public_key()].
#' @seealso [fips_keygen()].
#' @examples
#' # Deprecated: use fips_keygen().
#' key <- suppressWarnings(oqs_keygen("ML-DSA-65"))
#' key$scheme
#' @export
oqs_keygen <- function(scheme = "ML-DSA-65") {
  .Deprecated("fips_keygen")
  fips_keygen(scheme)
}

#' @rdname oqs_keygen
#' @export
oqs_public_key <- function(key) {
  .Deprecated("fips_public_key")
  fips_public_key(key)
}

#' @export
format.bricklayer_oqs_key <- function(x, ...) {
  c(.rmbl_rule("Signing key (standardised: FIPS 204 / FIPS 205)"),
    .rmbl_kv(list(scheme = x$scheme,
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L),
                  secret = "<withheld>",
                  state = "stateless: signs any number of messages")),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_oqs_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' @export
format.bricklayer_oqs_public_key <- function(x, ...) {
  c(.rmbl_rule("Public verification key (standardised)"),
    .rmbl_kv(list(scheme = x$scheme,
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname rmbl_print_methods
#' @export
print.bricklayer_oqs_public_key <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

#' Generate a post-quantum signing key for capsule provenance
#'
#' Builds an XMSS key pair: a Merkle tree over `2^height` Winternitz
#' one-time keys, all derived from two 32-byte seeds. Security rests on
#' SHA-256 alone -- no lattice assumption, no elliptic curve, nothing
#' Shor's algorithm breaks.
#'
#' # A height-`h` key signs exactly `2^h` messages
#'
#' Each signature consumes one leaf, and **signing two different messages
#' with the same leaf index breaks the scheme outright** -- between two
#' signatures at one index an adversary can forge a third message.
#' [capsule_sign()] therefore tracks
#' `next_index` and refuses to reuse one. Do not hand-edit that field,
#' and do not copy a key to two machines that sign independently.
#'
#' Key generation walks all `2^height` leaves, so cost doubles with
#' each unit of height. The default 10 gives 1024 signatures and takes a
#' moment; heights above about 14 are slow enough to be worth avoiding
#' unless the key really must last that long.
#'
#' @param height Tree height, 1 to 16 (default 10, i.e. 1024
#' signatures).
#' @param sk_seed,pub_seed,sk_prf 64-character hex seeds
#' (32 bytes each) -- the three secrets RFC 8391's private key carries.
#' `sk_seed` derives the WOTS+ chains, `pub_seed` masks the
#' hashes, and `sk_prf` keys the per-signature randomiser. Omit them
#' and they are drawn from the operating system's CSPRNG via
#' [random_bytes()], which fails rather than
#' falling back to R's reproducible generator. Supply them ONLY to
#' reproduce a key deterministically in a test -- a seed you can guess is a
#' key you can forge.
#' @return A list of class `bricklayer_signing_key`: `root` (the
#' public verification value), `pub_seed`, `sk_seed` (SECRET),
#' `sk_prf` (SECRET), `height`, `next_index`,
#' `capacity`, and `scheme`.
#' @section Key format: A key made before the RFC 8391 conformance work
#' carries no `sk_prf` and cannot sign;
#' [capsule_sign()] raises rather than producing
#' a signature no other implementation could read. Generate a new one.
#' @seealso
#' [capsule_sign()],
#' [capsule_verify()],
#' [signing_public_key()]
#' @examples
#' # A small key, to keep the example quick.
#' key <- pqc_keygen(height = 3)
#' key$capacity            # 8 signatures
#' key$next_index          # none used yet
#'
#' # The public half is what a verifier needs; it carries no secret.
#' pub <- signing_public_key(key)
#' names(pub)
#'
#' # Deterministic seeds reproduce the same key -- for tests only.
#' s1 <- paste(rep("11", 32), collapse = "")
#' s2 <- paste(rep("22", 32), collapse = "")
#' identical(pqc_keygen(3, s1, s2)$root, pqc_keygen(3, s1, s2)$root)
#' @export
pqc_keygen <- function(height = 10L, sk_seed = NULL, pub_seed = NULL,
                       sk_prf = NULL) {
  height <- as.integer(height)
  if (length(height) != 1L || is.na(height) || height < 1L || height > 16L) {
    stop("`height` must be a single integer between 1 and 16", call. = FALSE)
  }
  sk_seed <- if (is.null(sk_seed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(sk_seed, "sk_seed")
  pub_seed <- if (is.null(pub_seed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(pub_seed, "pub_seed")
  # SK_PRF is the third secret RFC 8391's private key carries. It keys
  # the per-signature randomiser, and without it the message digest
  # cannot be the one the RFC specifies.
  sk_prf <- if (is.null(sk_prf)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(sk_prf, "sk_prf")
  root <- .Call(C_rmbl_xmss_keygen, sk_seed, pub_seed, height)
  out <- list(root = root, pub_seed = pub_seed, sk_seed = sk_seed,
              sk_prf = sk_prf,
              height = height, next_index = 0L,
              capacity = bitwShiftL(1L, height),
              scheme = "xmss-sha256")
  class(out) <- c("bricklayer_signing_key", "list")
  out
}

#' Public half of a signing key
#'
#' Strips the secret seed, leaving only what a verifier needs. Publish
#' this; never the object returned by
#' [pqc_keygen()].
#'
#' @param key A `bricklayer_signing_key` from
#' [pqc_keygen()].
#' @return A list of class `bricklayer_public_key`: `root`,
#' `pub_seed`, `height`, `scheme`.
#' @examples
#' key <- pqc_keygen(height = 2)
#' pub <- signing_public_key(key)
#'
#' # The secret seed is gone.
#' is.null(pub$sk_seed)
#'
#' # And verification works from the public half alone.
#' sig <- capsule_sign("manifest-digest", key)
#' capsule_verify("manifest-digest", sig, pub)
#' @export
signing_public_key <- function(key) {
  if (!inherits(key, "bricklayer_signing_key")) {
    stop("`key` must come from pqc_keygen()", call. = FALSE)
  }
  out <- list(root = key$root, pub_seed = key$pub_seed,
              height = key$height, scheme = key$scheme)
  class(out) <- c("bricklayer_public_key", "list")
  out
}

#' Sign a capsule manifest
#'
#' Authenticates `message` -- normally a manifest digest, or the whole
#' manifest text -- so a verifier can tell that it came from the holder of
#' the key and has not been altered since.
#'
#' With `scheme = "hmac"` the `key` is a shared secret string and
#' the result is an HMAC-SHA-256 tag. Symmetric, so anyone who can verify
#' can also sign.
#'
#' With `scheme = "xmss"` the `key` is a
#' [pqc_keygen()] object and the result is a
#' post-quantum one-time signature under the key's Merkle root. Asymmetric:
#' a verifier holding only the public root cannot forge.
#'
#' # The returned key state must be carried forward
#'
#' An XMSS signature consumes a leaf. The returned object therefore carries
#' `key_state`, the key with `next_index` advanced, and
#' **subsequent signing must use that** -- reusing an index breaks the
#' scheme. Passing an exhausted key is an error, not a silent wrap-around.
#'
#' @param message Length-1 character vector (or raw vector)
#' to sign.
#' @param key A shared secret (character/raw) for `"hmac"`,
#' a `bricklayer_signing_key` from
#' [pqc_keygen()] for `"xmss"`, or a
#' `bricklayer_fips_key` from
#' [fips_keygen()] for a standardised scheme (in
#' which case `scheme` is taken from the key and ignored).
#' @param scheme `"xmss"` (post-quantum, asymmetric) or
#' `"hmac"` (symmetric). Inferred from `key` when not given.
#' @param context Optional context string (character or raw,
#' at most 255 bytes) for the standardised schemes, and ignored by the
#' others. FIPS 204 and FIPS 205 both bind it into the message encoding, so
#' a signature made under one context does not verify under another --
#' which is how the same key is safely used for two purposes.
#' @param deterministic For the standardised schemes,
#' use the deterministic variant rather than drawing fresh randomness per
#' signature. The signature then depends only on the key, message and
#' context, which is what the standards' test vectors rely on.
#' @param prehash For the standardised schemes, sign a
#' digest of the message rather than the message itself -- HashML-DSA (FIPS
#' 204 section 5.4) or HashSLH-DSA (FIPS 205 section 10.2.2). One of
#' `"none"` (the default, the pure variants), `"sha256"`,
#' `"sha512"`, `"shake128"` or `"shake256"`. The identifier
#' of the pre-hash is bound into the signature, so a pre-hashed signature
#' is never interchangeable with a pure one over the same digest.
#' @return A list of class `bricklayer_signature`: `scheme`,
#' `signature`, and for XMSS also `auth`, `index`,
#' `root`, `height`, `key_state`, `randomizer` (the
#' per-signature `R` of RFC 8391, which a verifier needs and which
#' therefore travels with the signature) and `wire` -- the signature
#' in the RFC's own byte order, `index || R || WOTS || auth`,
#' hex-encoded. `wire` is byte-identical to what the XMSS reference
#' implementation produces from the same key material, so it can be handed
#' to another implementation as bytes.
#' @seealso
#' [capsule_verify()],
#' [core_hmac_sha256()]
#' @examples
#' # Symmetric: one shared secret.
#' sig <- capsule_sign("sha256:abc123", key = "shared-secret",
#'                     scheme = "hmac")
#' capsule_verify("sha256:abc123", sig, "shared-secret")
#' capsule_verify("sha256:TAMPERED", sig, "shared-secret")
#'
#' # Post-quantum: the verifier needs only the public root.
#' key <- pqc_keygen(height = 2)
#' s1 <- capsule_sign("manifest-1", key)
#' capsule_verify("manifest-1", s1, signing_public_key(key))
#'
#' # Carry the advanced key state forward for the next signature.
#' key <- s1$key_state
#' key$next_index
#' s2 <- capsule_sign("manifest-2", key)
#' capsule_verify("manifest-2", s2, signing_public_key(key))
#'
#' # A signature does not transfer to another message.
#' capsule_verify("manifest-1", s2, signing_public_key(key))
#' @export
capsule_sign <- function(message, key, scheme = NULL, context = NULL,
                         deterministic = FALSE, prehash = "none") {
  if (inherits(key, "bricklayer_oqs_key")) {
    msg <- .rmbl_sign_message(message)
    ctx <- .rmbl_fips_context(context)
    sz <- fips_sizes(key$scheme)
    # FIPS 204 and 205 both allow either variant. Hedged signing draws
    # fresh bytes per signature and is the default; the deterministic
    # variant substitutes a fixed value, which is what the standards'
    # test vectors use and what makes a signature reproducible.
    rnd <- if (isTRUE(deterministic)) {
      .rmbl_fips_fixed_rand(key$scheme, key$public, sz[["opt_rand"]])
    } else {
      random_bytes(sz[["opt_rand"]])
    }
    ph <- .rmbl_fips_prehash(prehash)
    sg <- .rmbl_fips_sign(key$scheme, .rmbl_hex_to_raw(key$secret), msg,
                          ctx, rnd, ph)
    out <- list(scheme = key$scheme, signature = .rmbl_hexlify(sg),
                context = ctx, prehash = ph)
    class(out) <- c("bricklayer_signature", "list")
    return(out)
  }
  if (is.null(scheme)) {
    scheme <- if (inherits(key, "bricklayer_signing_key")) "xmss" else "hmac"
  }
  scheme <- match.arg(scheme, c("xmss", "hmac"))

  if (identical(scheme, "hmac")) {
    tag <- core_hmac_sha256(key, message)
    out <- list(scheme = "hmac", signature = tag)
    class(out) <- c("bricklayer_signature", "list")
    return(out)
  }

  if (!inherits(key, "bricklayer_signing_key")) {
    stop("`scheme = \"xmss\"` needs a key from pqc_keygen()", call. = FALSE)
  }
  idx <- as.integer(key$next_index)
  if (idx >= key$capacity) {
    stop(sprintf(paste0("this key is exhausted: a height-%d key signs %d ",
                        "messages and all of them are used. Generate a new ",
                        "key -- reusing an index would break the signature ",
                        "scheme."), key$height, key$capacity), call. = FALSE)
  }
  if (!is.raw(message)) {
    message <- as.character(message)
    if (length(message) != 1L || is.na(message)) {
      stop("`message` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (is.null(key[["sk_prf"]])) {
    stop(paste0("this signing key predates the RFC 8391 randomiser and ",
                "cannot produce a conformant signature; generate a new ",
                "one with pqc_keygen()"), call. = FALSE)
  }
  res <- .Call(C_rmbl_xmss_sign, key$sk_seed, key[["sk_prf"]], key$pub_seed,
               as.integer(key$height), idx, message)
  advanced <- key
  advanced$next_index <- idx + 1L
  out <- list(scheme = "xmss-sha256", signature = res$wots, auth = res$auth,
              index = idx, root = res$root, height = key$height,
              randomizer = res$randomizer, wire = res$wire,
              key_state = advanced)
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' Verify a capsule manifest signature
#'
#' Checks `signature` against `message`. For `"hmac"` the
#' comparison is constant-time. For XMSS the Winternitz chains are walked
#' to their ends and the authentication path replayed to the Merkle root;
#' the digest is bound to both the leaf index and the root, so a signature
#' cannot be replayed at another index or under another key.
#'
#' Returns `FALSE` rather than erroring on a malformed or truncated
#' signature: a verifier must treat unparseable input as "not verified",
#' never as an exception to be caught and ignored.
#'
#' @param message The message the signature is claimed to
#' cover.
#' @param signature A `bricklayer_signature` from
#' [capsule_sign()].
#' @param key The shared secret for `"hmac"`, a public key
#' (or full signing key) for XMSS, or a
#' [fips_keygen()] key or its
#' [fips_public_key()] for a standardised
#' scheme. A signature is not verified against a key of a different scheme.
#' @param context The context string the signature was made
#' under, for the standardised schemes. A signature made under a different
#' context, or under none, does not verify.
#' @param prehash The pre-hash the signature was made with.
#' Taken from the signature when not given, since
#' [capsule_sign()] records it; supply it to
#' check a signature that arrived without that field.
#' @return A length-1 logical.
#' @examples
#' key <- pqc_keygen(height = 2)
#' sig <- capsule_sign("pinned-manifest", key)
#' pub <- signing_public_key(key)
#'
#' capsule_verify("pinned-manifest", sig, pub)
#'
#' # Every way of being wrong returns FALSE.
#' capsule_verify("edited-manifest", sig, pub)              # message changed
#' bad <- sig; bad$signature <- paste0("ff", substring(bad$signature, 3))
#' capsule_verify("pinned-manifest", bad, pub)              # signature edited
#' capsule_verify("pinned-manifest", sig,
#'                signing_public_key(pqc_keygen(height = 2)))  # foreign key
#'
#' # A truncated signature is not verified, and does not error.
#' trunc <- sig; trunc$signature <- substring(sig$signature, 1, 64)
#' capsule_verify("pinned-manifest", trunc, pub)
#' @export
capsule_verify <- function(message, signature, key, context = NULL,
                           prehash = NULL) {
  if (!inherits(signature, "bricklayer_signature")) {
    stop("`signature` must come from capsule_sign()", call. = FALSE)
  }
  if (inherits(key, c("bricklayer_oqs_key",
                      "bricklayer_oqs_public_key"))) {
    if (!identical(signature$scheme, key$scheme)) return(FALSE)
    msg <- .rmbl_sign_message(message)
    ctx <- .rmbl_fips_context(context)
    # A key or signature that is not even hex is "not verified", never
    # an error: a verifier treats unparseable input as failure. Decoding
    # it loosely would turn a stray character into a zero byte and hand
    # the C layer something it never received.
    pk <- .rmbl_hex_or_null(key$public)
    sg <- .rmbl_hex_or_null(signature$signature)
    if (is.null(pk) || is.null(sg)) return(FALSE)
    # A pre-hashed signature and a pure one over the same message are
    # different signatures, so which was made has to be stated. It
    # travels with the signature, and an explicit argument overrides it.
    ph <- if (is.null(prehash)) {
      if (is.null(signature[["prehash"]])) "none" else signature$prehash
    } else {
      .rmbl_fips_prehash(prehash)
    }
    return(.rmbl_fips_verify(key$scheme, pk, msg, ctx, sg,
                             .rmbl_fips_prehash(ph)))
  }
  if (identical(signature$scheme, "hmac")) {
    return(core_digest_equal(core_hmac_sha256(key, message),
                             signature$signature))
  }
  if (!inherits(key, c("bricklayer_public_key", "bricklayer_signing_key"))) {
    stop("verifying an XMSS signature needs a key from pqc_keygen() or ",
         "signing_public_key()", call. = FALSE)
  }
  # Reject a cross-scheme presentation explicitly. Without this the
  # rejection would still happen, but only incidentally, because the
  # other scheme's signature is the wrong length -- and an incidental
  # check is one that a future change can remove without noticing.
  if (!identical(signature$scheme, key$scheme)) return(FALSE)
  if (!is.raw(message)) {
    message <- as.character(message)
    if (length(message) != 1L || is.na(message)) {
      stop("`message` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (is.null(signature[["randomizer"]])) {
    stop(paste0("this signature carries no RFC 8391 randomiser and cannot ",
                "be verified; it was produced by an earlier, ",
                "non-conformant version"), call. = FALSE)
  }
  .Call(C_rmbl_xmss_verify, key$pub_seed, key$root, as.integer(key$height),
        as.integer(signature$index), message, signature$signature,
        signature$auth, signature[["randomizer"]])
}

# 32 seed bytes as hex, from the operating system's CSPRNG.
#
# Deliberately NOT R's generator: set.seed() makes that reproducible by
# design and its state is recoverable from its output, so a key drawn
# from it is guessable. random_bytes() fails rather than degrading, which
# is the behaviour a key needs.
# Hex bytes, or NULL if the string is not an even-length run of hex
# digits. as.raw(strtoi(...)) would quietly map a non-hex pair to 00.
.rmbl_hex_or_null <- function(hex) {
  hex <- as.character(hex)[1L]
  if (is.na(hex) || nchar(hex) %% 2L != 0L) return(NULL)
  if (!grepl("^[0-9a-fA-F]*$", hex)) return(NULL)
  .rmbl_hex_to_raw(hex)
}

# A message is either a single string or raw bytes. Anything else is an
# error rather than a coercion: silently signing the deparsed form of an
# object would produce a signature nobody can reproduce.
.rmbl_sign_message <- function(message) {
  if (is.raw(message)) return(message)
  message <- as.character(message)
  if (length(message) != 1L || is.na(message)) {
    stop("`message` must be a length-1 character vector or a raw vector",
         call. = FALSE)
  }
  charToRaw(message)
}

# The deterministic variant's substitute for fresh randomness. FIPS 205
# specifies PK.seed; FIPS 204 specifies 32 zero bytes. Both are fixed
# per key, which is the whole point: the same message signs identically
# every time.
.rmbl_fips_fixed_rand <- function(scheme, public_hex, n) {
  if (is.na(.rmbl_fips_mldsa_mode(scheme))) {
    return(.rmbl_hex_to_raw(substring(public_hex, 1L, 2L * n)))
  }
  raw(n)
}

.rmbl_random_seed_hex <- function() {
  paste(format(random_bytes(32L)), collapse = "")
}

.rmbl_check_seed <- function(seed, what) {
  seed <- as.character(seed)
  if (length(seed) != 1L || is.na(seed) || nchar(seed) != 64L ||
      !grepl("^[0-9a-fA-F]{64}$", seed)) {
    stop(sprintf("`%s` must be 64 hex characters (32 bytes)", what),
         call. = FALSE)
  }
  tolower(seed)
}
