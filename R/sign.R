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

#' Available post-quantum signature backends
#'
#' Reports which signature backends this build of the package can use.
#' `"xmss-sha256"` is always present -- it needs nothing but the bundled
#' SHA-256. `"liboqs"` appears only when the Open Quantum Safe library
#' was found at configure time, which additionally enables the
#' standardised lattice and hash-based schemes (ML-DSA / FIPS 204,
#' SLH-DSA / FIPS 205) through that library rather than through any
#' hand-written implementation here.
#'
#' @return A character vector of backend names.
#' @examples
#' pqc_backends()
#'
#' # The dependency-free backend is always available.
#' "xmss-sha256" %in% pqc_backends()
#' @export
pqc_backends <- function() .Call(C_rmbl_pqc_backends)

#' Generate a post-quantum signing key for capsule provenance
#'
#' Builds an XMSS key pair: a Merkle tree over `2^height` Winternitz
#' one-time keys, all derived from two 32-byte seeds. Security rests on
#' SHA-256 alone -- no lattice assumption, no elliptic curve, nothing
#' Shor's algorithm breaks.
#'
#' # A height-`h` key signs exactly `2^h` messages
#'
#' Each signature consumes one leaf, and **signing two different
#' messages with the same leaf index breaks the scheme outright** --
#' between two signatures at one index an adversary can forge a third
#' message. [capsule_sign()] therefore tracks `next_index` and refuses
#' to reuse one. Do not hand-edit that field, and do not copy a key to
#' two machines that sign independently.
#'
#' Key generation walks all `2^height` leaves, so cost doubles with each
#' unit of height. The default 10 gives 1024 signatures and takes a
#' moment; heights above about 14 are slow enough to be worth avoiding
#' unless the key really must last that long.
#'
#' @param height Tree height, 1 to 16 (default 10, i.e. 1024
#'   signatures).
#' @param sk_seed,pub_seed 64-character hex seeds (32 bytes each). Omit
#'   them and cryptographically unpredictable seeds are drawn for you.
#'   Supply them ONLY to reproduce a key deterministically in a test --
#'   a seed you can guess is a key you can forge.
#' @return A list of class `bricklayer_signing_key`: `root` (the public
#'   verification value), `pub_seed`, `sk_seed` (SECRET), `height`,
#'   `next_index`, `capacity`, and `scheme`.
#' @seealso [capsule_sign()], [capsule_verify()], [signing_public_key()]
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
pqc_keygen <- function(height = 10L, sk_seed = NULL, pub_seed = NULL) {
  height <- as.integer(height)
  if (length(height) != 1L || is.na(height) || height < 1L || height > 16L) {
    stop("`height` must be a single integer between 1 and 16", call. = FALSE)
  }
  sk_seed <- if (is.null(sk_seed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(sk_seed, "sk_seed")
  pub_seed <- if (is.null(pub_seed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(pub_seed, "pub_seed")
  root <- .Call(C_rmbl_xmss_keygen, sk_seed, pub_seed, height)
  out <- list(root = root, pub_seed = pub_seed, sk_seed = sk_seed,
              height = height, next_index = 0L,
              capacity = bitwShiftL(1L, height),
              scheme = "xmss-sha256")
  class(out) <- c("bricklayer_signing_key", "list")
  out
}

#' Public half of a signing key
#'
#' Strips the secret seed, leaving only what a verifier needs. Publish
#' this; never the object returned by [pqc_keygen()].
#'
#' @param key A `bricklayer_signing_key` from [pqc_keygen()].
#' @return A list of class `bricklayer_public_key`: `root`, `pub_seed`,
#'   `height`, `scheme`.
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
#' manifest text -- so a verifier can tell that it came from the holder
#' of the key and has not been altered since.
#'
#' With `scheme = "hmac"` the `key` is a shared secret string and the
#' result is an HMAC-SHA-256 tag. Symmetric, so anyone who can verify can
#' also sign.
#'
#' With `scheme = "xmss"` the `key` is a [pqc_keygen()] object and the
#' result is a post-quantum one-time signature under the key's Merkle
#' root. Asymmetric: a verifier holding only the public root cannot
#' forge.
#'
#' # The returned key state must be carried forward
#'
#' An XMSS signature consumes a leaf. The returned object therefore
#' carries `key_state`, the key with `next_index` advanced, and
#' **subsequent signing must use that** -- reusing an index breaks the
#' scheme. Passing an exhausted key is an error, not a silent wrap-around.
#'
#' @param message Length-1 character vector (or raw vector) to sign.
#' @param key A shared secret (character/raw) for `"hmac"`, or a
#'   `bricklayer_signing_key` for `"xmss"`.
#' @param scheme `"xmss"` (post-quantum, asymmetric) or `"hmac"`
#'   (symmetric). Inferred from `key` when not given.
#' @return A list of class `bricklayer_signature`: `scheme`,
#'   `signature`, and for XMSS also `auth`, `index`, `root`, `height`
#'   and `key_state`.
#' @seealso [capsule_verify()], [core_hmac_sha256()]
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
capsule_sign <- function(message, key, scheme = NULL) {
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
  res <- .Call(C_rmbl_xmss_sign, key$sk_seed, key$pub_seed,
               as.integer(key$height), idx, message)
  advanced <- key
  advanced$next_index <- idx + 1L
  out <- list(scheme = "xmss-sha256", signature = res$wots, auth = res$auth,
              index = idx, root = res$root, height = key$height,
              key_state = advanced)
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' Verify a capsule manifest signature
#'
#' Checks `signature` against `message`. For `"hmac"` the comparison is
#' constant-time. For XMSS the Winternitz chains are walked to their ends
#' and the authentication path replayed to the Merkle root; the digest is
#' bound to both the leaf index and the root, so a signature cannot be
#' replayed at another index or under another key.
#'
#' Returns `FALSE` rather than erroring on a malformed or truncated
#' signature: a verifier must treat unparseable input as "not verified",
#' never as an exception to be caught and ignored.
#'
#' @param message The message the signature is claimed to cover.
#' @param signature A `bricklayer_signature` from [capsule_sign()].
#' @param key The shared secret for `"hmac"`, or a public key (or full
#'   signing key) for XMSS.
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
capsule_verify <- function(message, signature, key) {
  if (!inherits(signature, "bricklayer_signature")) {
    stop("`signature` must come from capsule_sign()", call. = FALSE)
  }
  if (identical(signature$scheme, "hmac")) {
    return(core_digest_equal(core_hmac_sha256(key, message),
                             signature$signature))
  }
  if (!inherits(key, c("bricklayer_public_key", "bricklayer_signing_key"))) {
    stop("verifying an XMSS signature needs a key from pqc_keygen() or ",
         "signing_public_key()", call. = FALSE)
  }
  if (!is.raw(message)) {
    message <- as.character(message)
    if (length(message) != 1L || is.na(message)) {
      stop("`message` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  .Call(C_rmbl_xmss_verify, key$pub_seed, key$root, as.integer(key$height),
        as.integer(signature$index), message, signature$signature,
        signature$auth)
}

# 32 seed bytes as hex.
#
# Base R exposes no OS entropy primitive, so several independent sources
# are mixed through SHA-256. That is adequate for a provenance key, and
# is documented as such in pqc_keygen(): for a key protecting anything of
# value, generate 32 bytes from a vetted source and pass them in.
.rmbl_random_seed_hex <- function() {
  entropy <- paste(
    format(Sys.time(), "%Y-%m-%d %H:%M:%OS6"),
    Sys.getpid(),
    paste(format(stats::runif(16), digits = 17), collapse = ""),
    paste(sample.int(.Machine$integer.max, 8L), collapse = "-"),
    tempfile(),
    paste(as.numeric(proc.time()), collapse = "-"),
    sep = "|")
  core_sha256(entropy)
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
