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
#' [pqckg()]. The rest are the NIST
#' standards, taken with [fipskg()]: ML-DSA
#' (FIPS 204) at all three parameter sets, and SLH-DSA (FIPS 205) at all
#' twelve -- six over SHAKE and six over SHA-2, which are different schemes
#' and not merely different code paths. Use it to see which names
#' [fipskg()], [fipssz()] and
#' [fipskey()] accept, or to choose a
#' parameter set.
#'
#' @details
#' The names follow the standards: `"ML-DSA-44"`, `"ML-DSA-65"` and
#' `"ML-DSA-87"` (NIST security categories 2, 3 and 5), then
#' `"SLH-DSA-SHA2-"` and `"SLH-DSA-SHAKE-"` followed by `128`, `192`
#' or
#' `256` (the security level in bits) and `s` (small signatures, slow
#' signing) or `f` (fast signing, larger signatures). The function takes
#' no arguments, has no side effects and returns the same 16 names in the
#' same order on every platform.
#'
#' @return A character vector of 16 scheme names: `"xmss-sha256"` first,
#'   then the three ML-DSA sets, the six SLH-DSA SHA-2 sets and the six
#'   SLH-DSA SHAKE sets.
#' @seealso
#' [fipskg()] for the standardised schemes,
#' [pqckg()] for the stateful one.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' pqcbknd()
#'
#' # Every scheme is present in every build.
#' all(c("xmss-sha256", "ML-DSA-65", "SLH-DSA-SHAKE-128s") %in%
#'     pqcbknd())
#'
#' # The SLH-DSA sets with fast signing, and their signature sizes in bytes.
#' fast <- grep("^SLH-DSA-.*f$", pqcbknd(), value = TRUE)
#' vapply(fast, function(s) fipssz(s)[["signature"]], integer(1))
#' @export
pqcbknd <- function() .Call(C_rmbl_pqc_backends)

#' Generate a standardised post-quantum signing key
#'
#' Generates a key for one of the NIST-standardised signature schemes:
#' ML-DSA (FIPS 204) or SLH-DSA (FIPS 205). Both are implemented in this
#' package, natively, with no system dependency;
#' [pqcbknd()] lists the parameter sets. The key signs
#' capsule
#' manifests, attestations and bundles with [cpssign()],
#' and its
#' public half, from `fipspubkey()`, is what you give to anyone who
#' should be able to check those signatures with
#' [cpsvrf()].
#'
#' Unlike [pqckg()] 's hash-based key, these
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
#' @details
#' Key generation expands a random seed (the length
#' [fipssz()] reports
#' as `seed`: 32 bytes for ML-DSA, three times the security level in bytes
#' for SLH-DSA) into the key pair exactly as FIPS 204 `ML-DSA.KeyGen` and
#' FIPS 205 `slh_keygen` do, so the same seed gives the same key as any
#' other conforming implementation. ML-DSA keys take milliseconds; SLH-DSA
#' keys take from milliseconds (the `f` sets) to about a second (the `s`
#' sets, which build a larger top tree), with a spinner on stderr after
#' 0.75 s when a person is watching (see
#' [blprog()]) and
#' Ctrl-C honoured. Nothing is written to disk: saving the key, and keeping
#' its `secret` private, is up to you. `fipspubkey()` drops the secret
#' half, leaving what a verifier needs.
#'
#' Refusals: an unknown scheme (the message lists the known ones, and
#' points to [pqckg()] for XMSS), a `seed` that is not
#' a raw vector of
#' the right length, and for `fipspubkey()` a key that did not come
#' from `fipskg()` or [fipskey()].
#'
#' @param scheme Scheme name, one of [pqcbknd()] other than
#' `"xmss-sha256"`.
#' The default, `"ML-DSA-65"`, is the FIPS 204 middle security level.
#' @param seed Optional raw vector of key-generation seed
#' bytes, of the length [fipssz()] reports for
#' the scheme. Supplying it makes the key reproducible, which is what the
#' standards' test vectors need; the default draws from the operating
#' system's CSPRNG.
#' @return `fipskg()`: a list of class `bricklayer_fips_key` (also
#'   `bricklayer_oqs_key`) with `public` and `secret` (the encoded keys as
#'   lowercase hex strings, in the standards' byte layouts) and `scheme`.
#'   Printing it never shows the secret. `fipspubkey()`: a list of
#'   class `bricklayer_fips_public_key` (also `bricklayer_oqs_public_key`)
#'   with `public` and `scheme`.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Digital Signature Standard. FIPS 204.
#'   \doi{10.6028/NIST.FIPS.204}
#'
#' National Institute of Standards and Technology (2024). Stateless
#' Hash-Based Digital Signature Standard. FIPS 205.
#'   \doi{10.6028/NIST.FIPS.205}
#' @seealso
#' [pqckg()] for the stateful hash-based key,
#' [cpssign()] which accepts either,
#' [fipssz()] for the byte lengths.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- fipskg("ML-DSA-65")
#' key$scheme
#'
#' sig <- cpssign("a manifest digest", key)
#' cpsvrf("a manifest digest", sig, fipspubkey(key))
#'
#' # A context string binds the signature to its purpose: the same
#' # message signed for one context does not verify under another.
#' sig2 <- cpssign("a manifest digest", key, ctx = "release")
#' cpsvrf("a manifest digest", sig2, key, ctx = "release")
#' cpsvrf("a manifest digest", sig2, key, ctx = "staging")
#'
#' # A fixed seed reproduces the key (for test vectors only: a guessable
#' # seed is a guessable key).
#' seed <- as.raw(1:32)
#' identical(fipskg("ML-DSA-44", seed)$public, fipskg("ML-DSA-44", seed)$public)
#'
#' # The public half carries no secret.
#' names(fipspubkey(key))
#'
#' # An unknown parameter set is refused.
#' try(fipskg("ML-DSA-99"))
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
fipskg <- function(scheme = "ML-DSA-65", seed = NULL) {
  scheme <- .rmbl_fips_scheme(scheme)
  sz <- fipssz(scheme)
  if (is.null(seed)) {
    seed <- rndbytes(sz[["seed"]])
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

#' @rdname fipskg
#' @param key A key from `fipskg()`.
#' @export
fipspubkey <- function(key) {
  if (!inherits(key, "bricklayer_oqs_key")) {
    stop("`key` must come from fipskg()", call. = FALSE)
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
#' [cpssign()] and
#' [cpsvrf()] expect. The lengths are
#' checked against the parameter set, so material for the wrong scheme is
#' refused here rather than producing a signature nothing can verify.
#'
#' The byte layouts are the standards' own, which is what makes this
#' interoperable: an ML-DSA secret key is
#' `rho || K || tr || s1 || s2 || t0` and an SLH-DSA one is
#' `SK.seed || SK.prf || PK.seed || PK.root`, exactly as FIPS 204 and
#' FIPS 205 encode them.
#'
#' @details
#' Hex input may be upper or lower case and is stored lower case; raw
#' input is converted to hex. Only the lengths are checked (against
#' [fipssz()]): a secret key that does not belong to the
#' public key is
#' not detected here, and gives signatures that do not verify under that
#' public key. Refusals: an unknown scheme, and material that is not hex of
#' an even length or not exactly the scheme's length
#' (`"must be N bytes of key material"`).
#'
#' @param scheme Scheme name, as in
#' [fipskg()].
#' @param public Public key, hex or raw.
#' @param secret Secret key, hex or raw. Omit for a
#' verification-only key.
#' @return When `secret` is given, a `bricklayer_fips_key` with `public`,
#'   `secret` and `scheme`. Otherwise a key of class
#'   `bricklayer_fips_public_key` with `public` and `scheme`.
#'   Keys are held as lowercase hex, as
#'   [fipskg()] returns
#'   them.
#' @seealso
#' [fipskg()],
#' [fipssz()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- fipskg("ML-DSA-44")
#' # the round trip through raw material changes nothing
#' again <- fipskey("ML-DSA-44", key$public, key$secret)
#' identical(again$secret, key$secret)
#'
#' sig <- cpssign("m", again)
#' cpsvrf("m", sig, fipskey("ML-DSA-44", key$public))
#'
#' # material of the wrong length is refused
#' try(fipskey("ML-DSA-65", key$public, key$secret))
#' @export
fipskey <- function(scheme, public, secret = NULL) {
  .rmbl_no_fn(public = public, secret = secret)
  scheme <- .rmbl_fips_scheme(scheme)
  sz <- fipssz(scheme)
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

#' Key material as hex, whatever it arrived as, with its length checked
#' against the parameter set.
#' @param x The key material: a raw vector or a hex string.
#' @param n The number of bytes the parameter set needs.
#' @param what The argument's name, used in the error message.
#' @param scheme The parameter set's name, used in the error message.
#' @return The material as lower-case hex.
#' @noRd
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
#' The external-mu interface. `fipsmu()` reduces a message to the
#' 64-byte value mu that is the only thing ML-DSA signing actually
#' consumes; `fipssignmu()` signs that value and
#' `fipsvrfmu()` checks it. Use it when the message and the signing
#' key are in different places: the machine with the data computes mu from
#' the public key, and only those 64 bytes travel to the signer.
#'
#' The point is that the message need never reach the key. A large file can
#' be reduced to mu on the machine that holds it and only mu handed to
#' whatever holds the signing key -- a smartcard, a remote signer, another
#' process. mu is not a bare digest: it binds the public key (through
#' `tr = H(pk)`) and the context string, so a mu computed under one
#' key cannot be signed under another to any useful effect.
#'
#' The resulting signature is an ordinary ML-DSA signature.
#' [cpsvrf()] accepts it, given the
#' same message and context.
#'
#' @details
#' mu is FIPS 204's
#' \eqn{\mu = \mathrm{SHAKE256}(tr \| M', 64)} with
#' \eqn{tr = \mathrm{SHAKE256}(pk, 64)} and \eqn{M'} the message prefixed by
#' the domain byte, the context length and the context (or, with a
#' `prehash`, the pre-hash's identifier and digest), as in FIPS 204
#' Algorithm 7. Signing from mu is Algorithm 7 from that point on, and
#' `fipsvrfmu()` is Algorithm 8 from mu.
#'
#' Refusals: a key that is not an ML-DSA key from
#' [fipskg()] or
#' [fipskey()] (SLH-DSA keys are refused with
#' `"external mu is an ML-DSA interface"`), `fipssignmu()` with a public
#' key only (`"signing needs a key with its secret half"`) or a `mu` that
#' is not 64 raw bytes. `fipsvrfmu()` returns `FALSE`, not an error,
#' for a mismatched scheme, a wrong-length mu or a malformed signature; it
#' errors only when `signature` is not a `bricklayer_signature` or `key`
#' is not a list.
#'
#' @param key A key from
#' [fipskg()] or
#' [fipskey()]. An ML-DSA scheme: SLH-DSA has no
#' external-mu interface, because its digest depends on per-signature
#' randomness that the signer chooses.
#' @param msg Length-1 character vector or raw vector.
#' @param ctx Optional context string, as in
#' [cpssign()].
#' @param prehash Pre-hash function, as in
#' [cpssign()].
#' @param mu The 64 raw bytes from `fipsmu()`.
#' @param masked \code{TRUE} (the default) for the first-order masked ML-DSA
#'   signer, \code{FALSE} for the plain constant-time one; both give the same
#'   signature for the same randomness. The option
#'   \code{rmoriebricklayer.masked} sets the default for a session, so
#'   chain- and bundle-heavy code that has no physical attacker in its threat
#'   model can take the plain path everywhere with
#'   \code{options(rmoriebricklayer.masked = FALSE)}. SLH-DSA and XMSS
#'   signing are not masked and ignore it. Masking costs about 2.3 to 3.4 times
#'   the plain time on ML-KEM decapsulation (4 ms for ML-KEM-768 on this
#'   package's test machine) and 7 to 10 times on ML-DSA signing (26 ms for
#'   ML-DSA-65), depending on the CPU.
#' @param determ As in
#' [cpssign()].
#' @param sig A signature from `fipssignmu()`
#' or [cpssign()].
#' @return `fipsmu()`: a raw vector of 64 bytes. `fipssignmu()`: a
#'   list of class `bricklayer_signature` with `scheme` and `signature`
#'   (hex). `fipsvrfmu()`: `TRUE` or `FALSE`.
#' @references National Institute of Standards and Technology (2024).
#' Module-Lattice-Based Digital Signature Standard. FIPS 204.
#'   \doi{10.6028/NIST.FIPS.204}
#' @seealso
#' [cpssign()],
#' [fipskg()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' key <- fipskg("ML-DSA-65")
#' mu <- fipsmu(key, "a manifest digest", ctx = "release")
#' length(mu)
#'
#' sig <- fipssignmu(key, mu)
#' fipsvrfmu(key, mu, sig)
#'
#' # the same signature verifies the ordinary way, from the message
#' cpsvrf("a manifest digest", sig, key, ctx = "release")
#'
#' # mu is computable from the PUBLIC key alone, which is what lets the
#' # message stay on the machine that has it
#' identical(fipsmu(fipspubkey(key), "a manifest digest",
#'                   ctx = "release"), mu)
#'
#' # A different context gives a different mu.
#' identical(fipsmu(key, "a manifest digest", ctx = "staging"), mu)
#'
#' # SLH-DSA has no external-mu interface.
#' try(fipsmu(fipskg("SLH-DSA-SHA2-128f"), "m"))
#' @export
fipsmu <- function(key, msg, ctx = NULL, prehash = "none") {
  .rmbl_no_fn(message = msg, context = ctx, prehash = prehash)
  scheme <- .rmbl_fips_key_scheme(key)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) {
    stop("fipsmu: external mu is an ML-DSA interface; ", scheme,
         " has no equivalent", call. = FALSE)
  }
  pk <- .rmbl_hex_or_null(key$public)
  if (is.null(pk)) stop("fipsmu: `key` has no usable public key", call. = FALSE)
  .Call(C_rmbl_mldsa_mu, mode, pk, .rmbl_sign_message(msg),
        .rmbl_fips_context(ctx), .rmbl_fips_prehash(prehash))
}

#' @rdname fipsmu
#' @export
fipssignmu <- function(key, mu, determ = FALSE,
                         masked = getOption("rmoriebricklayer.masked", TRUE)) {
  masked <- .rmbl_masked_flag(masked)
  scheme <- .rmbl_fips_key_scheme(key)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) {
    stop("fipssignmu: external mu is an ML-DSA interface; ", scheme,
         " has no equivalent", call. = FALSE)
  }
  if (is.null(key[["secret"]])) {
    stop("signing needs a key with its secret half", call. = FALSE)
  }
  if (!is.raw(mu) || length(mu) != 64L) {
    stop("`mu` must be 64 raw bytes, as returned by fipsmu()",
         call. = FALSE)
  }
  rnd <- if (isTRUE(determ)) raw(32L) else rndbytes(32L)
  # masked = TRUE: the first-order masked signer, same bytes for the same rnd
  sg <- .Call(C_rmbl_mldsa_sign_mu, mode, .rmbl_hex_to_raw(key$secret),
              mu, rnd, masked)
  out <- list(scheme = scheme, signature = .rmbl_hexlify(sg))
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' @rdname fipsmu
#' @export
fipsvrfmu <- function(key, mu, sig) {
  if (!is.list(key)) stop("fipsvrfmu: `key` must come from fipskg() or fipskey()", call. = FALSE)
  if (!inherits(sig, "bricklayer_signature")) {
    stop("`sig` must come from fipssignmu() or cpssign()",
         call. = FALSE)
  }
  # a verifier key whose class, scheme or bytes were edited is "not verified", like an edited
  # signature (cpsvrf's rule): only a key that is plainly of another kind is an error
  scheme <- tryCatch(.rmbl_fips_key_scheme(key), error = function(e) NULL)
  if (is.null(scheme)) return(FALSE)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (is.na(mode)) return(FALSE)
  if (!identical(sig$scheme, scheme)) return(FALSE)
  if (!is.raw(mu) || length(mu) != 64L) return(FALSE)
  pk <- .rmbl_hex_or_null(key$public)
  sg <- .rmbl_hex_or_null(sig$signature)
  if (is.null(pk) || is.null(sg)) return(FALSE)
  isTRUE(.Call(C_rmbl_mldsa_verify_mu, mode, pk, mu, sg))
}

#' The scheme a key object names, refusing anything that is not one of
#' ours rather than reaching into an arbitrary list.
#' @param key A key from `fipskg()` or `fipskey()`.
#' @return The key's parameter-set name.
#' @noRd
.rmbl_fips_key_scheme <- function(key) {
  if (!inherits(key, c("bricklayer_oqs_key", "bricklayer_oqs_public_key"))) {
    stop(.rmbl_fn(), "`key` must come from fipskg() or fipskey()", call. = FALSE)
  }
  .rmbl_fips_scheme(key$scheme)
}

#' Byte lengths of a standardised signature scheme
#'
#' Reports the sizes fixed by a FIPS 204 or FIPS 205 parameter set, so a
#' caller never has to hard-code them. Use it to check key material before
#' [fipskey()], to size storage for signatures, or to compare
#' parameter
#' sets: an SLH-DSA signature is 7,856 to 49,856 bytes where an ML-DSA one
#' is 2,420 to 4,627.
#'
#' @details
#' The sizes are the standards' tables (FIPS 204 Table 2, FIPS 205 Table 2)
#' as the compiled code uses them. `seed` is the key-generation input of
#' [fipskg()]; `rnd` is the per-signature
#' randomness (32 bytes
#' for ML-DSA's `rnd`, \eqn{n} bytes for SLH-DSA's `opt_rand`), which the
#' deterministic variants replace with a fixed value. XMSS is not covered:
#' its sizes follow from the tree height of [pqckg()]. An
#' unknown
#' scheme, or anything but one string, is refused.
#'
#' @param scheme Scheme name, as in
#' [fipskg()].
#' @return A named integer vector of five byte counts: `public_key`,
#'   `secret_key`, `signature`, `seed` and `rnd` (the
#'   per-signature
#'   randomness the scheme consumes).
#' @seealso
#' [fipskg()],
#' [pqcbknd()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' fipssz("ML-DSA-65")
#' fipssz("SLH-DSA-SHAKE-128s")
#'
#' # An SLH-DSA signature is far larger than an ML-DSA one at the same
#' # security level, which is the price of dropping the lattice
#' # assumption.
#' fipssz("SLH-DSA-SHAKE-128s")[["signature"]] >
#'   fipssz("ML-DSA-44")[["signature"]]
#'
#' # Every standardised set at once.
#' sapply(setdiff(pqcbknd(), "xmss-sha256"), fipssz)["signature", ]
#'
#' # XMSS has no fixed sizes here.
#' try(fipssz("xmss-sha256"))
#' @export
fipssz <- function(scheme) {
  scheme <- .rmbl_fips_scheme(scheme)
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    sz <- .Call(C_rmbl_mldsa_sizes, mode)
    return(c(sz, rnd = 32L))
  }
  sz <- .Call(C_rmbl_slhdsa_sizes, scheme)
  # SLH-DSA draws its key from three n-byte seeds and its per-signature
  # randomness from one, so n follows from the seed length.
  c(sz, rnd = sz[["seed"]] %/% 3L)
}

#' Checks a FIPS 204 or 205 parameter-set name.
#'
#' The parameter-set name, validated against what the package implements.
#' A typo must fail here rather than silently selecting a default, since
#' the scheme is baked into every signature the key goes on to produce.
#' @param scheme The name passed by the user.
#' @return `scheme`.
#' @noRd
.rmbl_fips_scheme <- function(scheme) {
  # one name: a vector of two was read as its first (review of 52a8883)
  if (!is.character(scheme) || length(scheme) != 1L) stop("`scheme` must be a single non-empty string", call. = FALSE)
  if (is.na(scheme) || !nzchar(scheme)) {
    stop("`scheme` must be a non-empty string", call. = FALSE)
  }
  known <- setdiff(pqcbknd(), "xmss-sha256")
  if (!scheme %in% known) {
    stop(sprintf(paste0("unknown scheme '%s'. The standardised schemes ",
                        "are: %s. For the stateful hash-based scheme ",
                        "use pqckg()."),
                 scheme, paste(known, collapse = ", ")), call. = FALSE)
  }
  scheme
}

#' NA for an SLH-DSA set, the FIPS 204 mode number for an ML-DSA one.
#' @param scheme The parameter-set name.
#' @return An integer mode, or NA.
#' @noRd
.rmbl_fips_mldsa_mode <- function(scheme) {
  if (!grepl("^ML-DSA-", scheme)) return(NA_integer_)
  as.integer(sub("^ML-DSA-", "", scheme))
}

#' Generates an ML-DSA or SLH-DSA key pair from a seed in the native kernel.
#' @param scheme The parameter-set name.
#' @param seed The seed bytes.
#' @return What the kernel returns: the public and secret keys.
#' @noRd
.rmbl_fips_keypair <- function(scheme, seed) {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) return(.Call(C_rmbl_mldsa_keypair, mode, seed))
  # the small SLH-DSA sets take a fraction of a second, the 256-bit "s" sets several: the kernel
  # polls for a Ctrl-C as it builds its trees, and each poll turns the busy spinner
  .bl_busy(sprintf("%s key: building the top tree", scheme), .Call(C_rmbl_slhdsa_keypair, scheme, seed))
}

#' Signs a message with an ML-DSA or SLH-DSA secret key in the native kernel.
#' @param scheme The parameter-set name.
#' @param sk The secret key bytes.
#' @param msg The message bytes.
#' @param ctx The context bytes.
#' @param rnd The randomness bytes, or the fixed bytes of the deterministic variant.
#' @param prehash The pre-hash name, \code{"none"} for a pure signature.
#' @param masked Whether ML-DSA signs with the masked implementation.
#' @return The signature bytes.
#' @noRd
.rmbl_fips_sign <- function(scheme, sk, msg, ctx, rnd, prehash = "none", masked = TRUE) {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    return(.Call(C_rmbl_mldsa_sign, mode, sk, msg, ctx, rnd, prehash, masked))
  }
  .bl_busy(sprintf("%s signature", scheme), .Call(C_rmbl_slhdsa_sign, scheme, sk, msg, ctx, rnd, prehash))
}

#' Checks the `masked` argument of the three masked operations.
#'
#' TRUE or FALSE for the `masked` argument of the three masked operations; the
#' option rmoriebricklayer.masked sets the default for a whole session.
#' @param masked The value passed by the user.
#' @return `masked`.
#' @noRd
.rmbl_masked_flag <- function(masked) {
  if (!isTRUE(masked) && !isFALSE(masked)) {
    stop("`masked` must be TRUE or FALSE (option rmoriebricklayer.masked sets the default)",
         call. = FALSE)
  }
  masked
}

#' Verifies an ML-DSA or SLH-DSA signature in the native kernel.
#' @param scheme The parameter-set name.
#' @param pk The public key bytes.
#' @param msg The message bytes.
#' @param ctx The context bytes.
#' @param sig The signature bytes.
#' @param prehash The pre-hash name, \code{"none"} for a pure signature.
#' @return `TRUE` when the signature verifies.
#' @noRd
.rmbl_fips_verify <- function(scheme, pk, msg, ctx, sig,
                              prehash = "none") {
  mode <- .rmbl_fips_mldsa_mode(scheme)
  if (!is.na(mode)) {
    return(.Call(C_rmbl_mldsa_verify, mode, pk, msg, ctx, sig, prehash))
  }
  .Call(C_rmbl_slhdsa_verify, scheme, pk, msg, ctx, sig, prehash)
}

#' Checks the pre-hash name.
#'
#' The pre-hash name, validated here so a typo cannot be read as \code{"none"}
#' and quietly produce a pure signature instead of the requested one.
#' @param prehash The name passed by the user; NULL or NA is \code{"none"}.
#' @return The pre-hash name.
#' @noRd
.rmbl_fips_prehash <- function(prehash) {
  if (is.null(prehash)) return("none")
  prehash <- as.character(prehash)[1L]
  if (is.na(prehash)) prehash <- "none"
  .rmbl_arg(prehash, c("none", "sha224", "sha256", "sha384", "sha512", "sha512_224",
                     "sha512_256", "sha3_224", "sha3_256", "sha3_384", "sha3_512",
                     "shake128", "shake256"))
}

#' Checks a FIPS 204 or 205 context string and returns it as bytes.
#'
#' A context string is at most 255 bytes because the FIPS 204 and 205
#' message encodings write its length in one byte.
#' @param context A string, a raw vector or NULL (empty).
#' @return A raw vector of at most 255 bytes.
#' @noRd
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
#' [fipskg()] instead. New code should not call these
#' functions.
#'
#' @details
#' `oqskg()` calls [fipskg()] (with a fresh
#' random seed) and
#' `oqspubkey()` calls [fipspubkey()], each
#' after a deprecation
#' warning from [.Deprecated()]. The keys are the same objects
#' [fipskg()] returns, with the same classes.
#'
#' @param scheme Scheme name; see
#' [fipskg()].
#' @param key A key from `oqskg()`.
#' @return As [fipskg()] (a `bricklayer_fips_key`)
#'   and
#'   [fipspubkey()] (a
#'   `bricklayer_fips_public_key`).
#' @seealso [fipskg()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' # Deprecated: use fipskg().
#' key <- suppressWarnings(oqskg("ML-DSA-65"))
#' key$scheme
#'
#' # The same as the current name, after a warning.
#' pub <- suppressWarnings(oqspubkey(key))
#' identical(pub, fipspubkey(key))
#'
#' # The warning names the replacement.
#' tryCatch(oqskg(), warning = function(w) conditionMessage(w))
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
oqskg <- function(scheme = "ML-DSA-65") {
  .Deprecated("fipskg")
  fipskg(scheme)
}

#' @rdname oqskg
#' @export
oqspubkey <- function(key) {
  .Deprecated("fipspubkey")
  fipspubkey(key)
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

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_key
print.bricklayer_oqs_key <- .rmbl_print_via_format

#' @export
format.bricklayer_oqs_public_key <- function(x, ...) {
  c(.rmbl_rule("Public verification key (standardised)"),
    .rmbl_kv(list(scheme = x$scheme,
                  "public key" = sprintf("%s... (%d bytes)",
                                         substring(x$public, 1L, 32L),
                                         nchar(x$public) %/% 2L))),
    .rmbl_rule())
}

#' @rdname printmeth
#' @export
#' @method print bricklayer_oqs_public_key
print.bricklayer_oqs_public_key <- .rmbl_print_via_format

#' Generate a post-quantum signing key for capsule provenance
#'
#' Builds an XMSS key pair: a Merkle tree over `2^height` Winternitz
#' one-time keys, all derived from two 32-byte seeds. Security rests on
#' SHA-256 alone -- no lattice assumption, no elliptic curve, nothing
#' Shor's algorithm breaks. The key signs a fixed number of messages,
#' `2^height`, and must be carried forward after each signature (see
#' [xmssadv()]); for a key with no such state use
#' [fipskg()].
#'
#' @details
#' Key generation walks all `2^height` leaves, so cost doubles with
#' each unit of height. The default 10 gives 1024 signatures and takes a
#' few seconds; heights above about 14 are slow enough to be worth avoiding
#' unless the key really must last that long. A spinner on stderr shows the
#' work after 0.75 s when a person is watching (see
#' [blprog()]), and Ctrl-C stops it.
#'
#' The construction is single-tree XMSS with SHA-256, n = 32 and
#' Winternitz parameter 16 (RFC 8391; at heights 10 and 16 these are its
#' `XMSS-SHA2_10_256` and `XMSS-SHA2_16_256` parameter sets, and the other
#' heights use the same construction with a smaller or larger tree). Its
#' signatures are byte-identical to the XMSS reference implementation's
#' for the same key material.
#'
#' Side effect: a key generated from fresh randomness is entered in the
#' package's used-index record (the file described under
#' [xmssadv()]), so that a stale copy of it can never
#' sign an index
#' twice on this machine. A key built from given seeds is NOT entered, and
#' signs only after [xmssregkey()] vouches that it
#' never has.
#'
#' Refusals: a `height` that is not a whole number from 1 to 16, and a
#' seed that is not 64 hex characters.
#'
#' # A height-`h` key signs exactly `2^h` messages
#'
#' Each signature consumes one leaf, and **signing two different messages
#' with the same leaf index breaks the scheme outright** -- between two
#' signatures at one index an adversary can forge a third message.
#' [cpssign()] therefore tracks
#' `next_index` and refuses to reuse one. Do not hand-edit that field,
#' and do not copy a key to two machines that sign independently.
#'
#' # The key and its state
#'
#' RFC 10033 (Hash-Based Signatures: State and Backup Management) splits
#' an XMSS key into the private key, which never changes, and the state,
#' which records the indices used and must be updated, durably, before
#' each signature is released (its sections 2 and 4). In an R session the
#' state is `next_index` plus the used-index record described under
#' [xmssadv()]. From the command line,
#' `rmbl sign --scheme xmss-sha256 --key-file key.json`
#' makes the key file itself the state: it rewrites
#' the file atomically, with `next_index` advanced and a `used` field,
#' before anything is signed, and signs from the indices it reserved.
#' `--state-file` keeps the state in a file of its own, `--sectors` and
#' `--sector-index` give each signer its own disjoint range of indices
#' (section 5.3), `--reserve` reserves a block in one write (section
#' 5.9), and a key file older than a signature it is seen to have made is
#' refused as a stale copy. See the section XMSS keys of [blcli()].
#'
#' A key saved as a CI secret is a fixed copy that every job starts
#' from, so every job signs the same indices: in CI use ML-DSA
#' ([fipskg()]) unless the XMSS state is kept in a file that persists
#' between jobs. NIST SP 800-208 approves XMSS only inside a hardware
#' cryptographic module that never exports the key; this software key
#' is not such a deployment.
#'
#' @param height Tree height, 1 to 16 (default 10, i.e. 1024
#' signatures).
#' @param skseed,pubseed,skprf 64-character hex seeds
#' (32 bytes each) -- the three secrets RFC 8391's private key carries.
#' `skseed` derives the WOTS+ chains, `pubseed` masks the
#' hashes, and `skprf` keys the per-signature randomiser. Omit them
#' and they are drawn from the operating system's CSPRNG via
#' [rndbytes()], which fails rather than
#' falling back to R's reproducible generator. Supply them ONLY to
#' reproduce a key deterministically in a test -- a seed you can guess is a
#' key you can forge.
#' @return A list of class `bricklayer_signing_key`: `root` (the
#'   public verification value, 64 hex characters), `pubseed`, `skseed`
#'   (SECRET) and `skprf` (SECRET), each 64 hex characters, `height` (an
#'   integer), `next_index` (the next unused leaf, 0 for a new key),
#'   `capacity` (`2^height`, the number of signatures), and `scheme`
#'   (`"xmss-sha256"`).
#' @section Key format: A key made before the RFC 8391 conformance work
#' carries no `skprf` and cannot sign;
#' [cpssign()] raises rather than producing
#' a signature no other implementation could read. Generate a new one.
#' @seealso
#' [cpssign()],
#' [cpsvrf()],
#' [signpubkey()]
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' # A small key, to keep the example quick.
#' key <- pqckg(height = 3)
#' key$capacity            # 8 signatures
#' key$next_index          # none used yet
#'
#' # The public half is what a verifier needs; it carries no secret.
#' pub <- signpubkey(key)
#' names(pub)
#'
#' # Deterministic seeds reproduce the same key -- for tests only. A key built from given
#' # seeds is not entered in the used-index record (it may have signed elsewhere): it signs
#' # only after xmssregkey() vouches that it never has.
#' s1 <- paste(rep("11", 32), collapse = "")
#' s2 <- paste(rep("22", 32), collapse = "")
#' identical(pqckg(3, s1, s2)$root, pqckg(3, s1, s2)$root)
#'
#' # The height is limited to 16 (65,536 signatures).
#' try(pqckg(height = 20))
#' options(op)
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
pqckg <- function(height = 10L, skseed = NULL, pubseed = NULL,
                       skprf = NULL) {
  .rmbl_no_fn(skseed = skseed, pubseed = pubseed, skprf = skprf)
  height <- .rmbl_num(height, "height", integer = TRUE)
  if (length(height) != 1L || is.na(height) || height < 1L || height > 16L) {
    stop("`height` must be a single integer between 1 and 16", call. = FALSE)
  }
  # a key built from given seeds may be one that has signed elsewhere: it is not registered
  seeded <- !is.null(skseed)
  skseed <- if (is.null(skseed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(skseed, "skseed")
  pubseed <- if (is.null(pubseed)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(pubseed, "pubseed")
  # SK_PRF is the third secret RFC 8391's private key carries. It keys
  # the per-signature randomiser, and without it the message digest
  # cannot be the one the RFC specifies.
  skprf <- if (is.null(skprf)) .rmbl_random_seed_hex() else
    .rmbl_check_seed(skprf, "skprf")
  root <- .bl_busy(sprintf("XMSS key: building the tree of %s one-time keys", format(2^height, big.mark = ",")),
                   .Call(C_rmbl_xmss_keygen, skseed, pubseed, height))
  out <- list(root = root, pubseed = pubseed, skseed = skseed,
              skprf = skprf,
              height = height, next_index = 0L,
              capacity = bitwShiftL(1L, height),
              scheme = "xmss-sha256")
  class(out) <- c("bricklayer_signing_key", "list")
  # the record learns a key at birth when the birth is here: fresh randomness cannot have
  # signed anywhere. A key regenerated from given seeds may have (on another machine, or before
  # the record was lost), so it is not entered; it signs from index 0 only after
  # xmssregkey() vouches for it (review of 52a8883, A2)
  if (!seeded) .rmbl_xmss_register(out, fresh = TRUE)
  out
}

#' Public half of a signing key
#'
#' Strips the secret seeds from an XMSS signing key, leaving only what a
#' verifier needs. Publish this, or hand it to whoever must check your
#' signatures; never the object returned by [pqckg()],
#' which lets its
#' holder sign in your name. The public key does not change as the signing
#' key is used, so it is made once.
#'
#' @details
#' The public key is the Merkle root and the public seed that masks the
#' hashes (RFC 8391's `root || SEED`), with the tree height and scheme
#' name. `skseed`, `skprf` and `next_index` are dropped. For a
#' standardised key from [fipskg()] use
#' [fipspubkey()] instead:
#' this function refuses any key that is not a `bricklayer_signing_key`
#' (`"key must come from pqckg()"`).
#'
#' @param key A `bricklayer_signing_key` from
#' [pqckg()].
#' @return A list of class `bricklayer_public_key`: `root` and `pubseed`
#'   (64 hex characters each), `height` and `scheme`.
#' @seealso [cpsvrf()], which takes it.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' key <- pqckg(height = 2)
#' pub <- signpubkey(key)
#'
#' # The secret seed is gone.
#' is.null(pub$skseed)
#'
#' # And verification works from the public half alone.
#' sig <- cpssign("manifest-digest", key)
#' cpsvrf("manifest-digest", sig, pub)
#'
#' # A standardised key has its own function.
#' try(signpubkey(fipskg("ML-DSA-44")))
#' options(op)
#' @export
signpubkey <- function(key) {
  if (!inherits(key, "bricklayer_signing_key")) {
    stop("`key` must come from pqckg()", call. = FALSE)
  }
  out <- list(root = key$root, pubseed = .rmbl_xkey(key, "pubseed"),
              height = key$height, scheme = key$scheme)
  class(out) <- c("bricklayer_public_key", "list")
  out
}

#' Sign a capsule manifest
#'
#' Authenticates `msg` -- normally a manifest digest, or the whole
#' manifest text -- so a verifier can tell that it came from the holder of
#' the key and has not been altered since. A digest alone shows that data
#' were not corrupted; a signature also shows who vouched for them, because
#' only the key holder can make it. Verify with
#' [cpsvrf()].
#'
#' Three kinds of key are accepted: a shared secret (HMAC), an XMSS key from
#' [pqckg()], or a standardised ML-DSA or SLH-DSA key from
#' [fipskg()]. For new work the standardised keys are the
#' simplest:
#' they sign any number of messages with no state to keep.
#'
#' With a standardised key the signature is FIPS 204 `ML-DSA.Sign` or
#' FIPS 205 `slh_sign` over the message with its context (hedged by
#' default, deterministic on request). ML-DSA signs in milliseconds;
#' SLH-DSA from a few hundred milliseconds (the `f` sets) to several
#' seconds (the `s` sets at 192 and 256 bits); an XMSS signature rebuilds
#' the key's tree, about 3 s at the default height 10. Slow signatures show
#' a spinner on stderr after 0.75 s when a person is watching (an
#' interactive session or `options(morie.progress = TRUE)`;
#' `options(morie.quiet = TRUE)` silences it), and Ctrl-C stops them.
#'
#' Refusals: a message that is not one string or a raw vector; a key of the
#' wrong kind for the scheme; a context over 255 bytes; an unknown pre-hash;
#' an exhausted XMSS key, an index the used-index record shows as used, a
#' key whose record cannot be read or written, or an XMSS key the record
#' does not know (see [xmssadv()] and
#' [xmssregkey()]).
#'
#' With `scheme = "hmac"` the `key` is a shared secret string and
#' the result is an HMAC-SHA-256 tag. Symmetric, so anyone who can verify
#' can also sign.
#'
#' With `scheme = "xmss"` the `key` is a
#' [pqckg()] object and the result is a
#' post-quantum one-time signature under the key's Merkle root. Asymmetric:
#' a verifier holding only the public root cannot forge.
#'
#' # The key must be advanced after every signature
#'
#' An XMSS signature consumes a leaf, and **subsequent signing must use the
#' advanced key** -- reusing an index breaks the scheme. The signature object
#' carries no key material (it is what verifiers are handed); the advanced
#' key is `xmssadv(key, signature)`, and that is what to save. The key is
#' an R value, so `cpssign()` cannot advance the caller's copy; instead it
#' records, in the session and in the index file described under
#' [xmssadv()],
#' the highest index each key has signed with, and
#' refuses that index or an earlier one. Passing an exhausted key is an error,
#' not a silent wrap-around.
#'
#' @param msg Length-1 character vector (or raw vector)
#' to sign.
#' @param key A shared secret (character/raw) for `"hmac"`,
#' a `bricklayer_signing_key` from
#' [pqckg()] for `"xmss"`, or a
#' `bricklayer_fips_key` from
#' [fipskg()] for a standardised scheme (in
#' which case `scheme` is taken from the key and ignored).
#' @param scheme `"xmss"` (post-quantum, asymmetric) or
#' `"hmac"` (symmetric). Inferred from `key` when not given.
#' @param ctx Optional context string (character or raw,
#' at most 255 bytes) for the standardised schemes, and ignored by the
#' others. FIPS 204 and FIPS 205 both bind it into the message encoding, so
#' a signature made under one context does not verify under another --
#' which is how the same key is safely used for two purposes.
#' @param masked \code{TRUE} (the default) for the first-order masked ML-DSA
#'   signer, \code{FALSE} for the plain constant-time one; both give the same
#'   signature for the same randomness. The option
#'   \code{rmoriebricklayer.masked} sets the default for a session, so
#'   chain- and bundle-heavy code that has no physical attacker in its threat
#'   model can take the plain path everywhere with
#'   \code{options(rmoriebricklayer.masked = FALSE)}. SLH-DSA and XMSS
#'   signing are not masked and ignore it. Masking costs about 2.3 to 3.4 times
#'   the plain time on ML-KEM decapsulation (4 ms for ML-KEM-768 on this
#'   package's test machine) and 7 to 10 times on ML-DSA signing (26 ms for
#'   ML-DSA-65), depending on the CPU.
#' @param determ For the standardised schemes,
#' use the deterministic variant rather than drawing fresh randomness per
#' signature. The signature then depends only on the key, message and
#' context, which is what the standards' test vectors rely on.
#' @param prehash For the standardised schemes, sign a
#' digest of the message rather than the message itself -- HashML-DSA (FIPS
#' 204 section 5.4) or HashSLH-DSA (FIPS 205 section 10.2.2). One of
#' `"none"` (the default, the pure variants) or any hash function the two
#' standards approve. The SHA-2 hashes are `"sha224"`, `"sha256"`, `"sha384"`,
#' `"sha512"`, `"sha512_224"` and `"sha512_256"`; the SHA-3 hashes are
#' `"sha3_224"`, `"sha3_256"`, `"sha3_384"` and `"sha3_512"`;
#' the SHAKE ones are
#' `"shake128"` (256-bit output) and `"shake256"` (512-bit output). The identifier
#' of the pre-hash is bound into the signature, so a pre-hashed signature
#' is never interchangeable with a pure one over the same digest.
#' @return A list of class `bricklayer_signature`: `scheme`,
#' `signature`, and for XMSS also `auth`, `index`,
#' `root`, `height`, `randomizer` (the
#' per-signature `R` of RFC 8391, which a verifier needs and which
#' therefore travels with the signature) and `wire` -- the signature
#' in the RFC's own byte order, `index || R || WOTS || auth`,
#' hex-encoded. `wire` is byte-identical to what the XMSS reference
#' implementation produces from the same key material, so it can be handed
#' to another implementation as bytes.
#' @seealso
#' [cpsvrf()],
#' [chmac()]
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' # Symmetric: one shared secret.
#' sig <- cpssign("sha256:abc123", key = "shared-secret",
#'                     scheme = "hmac")
#' cpsvrf("sha256:abc123", sig, "shared-secret")
#' cpsvrf("sha256:TAMPERED", sig, "shared-secret")
#'
#' # Post-quantum: the verifier needs only the public root.
#' key <- pqckg(height = 2)
#' s1 <- cpssign("manifest-1", key)
#' cpsvrf("manifest-1", s1, signpubkey(key))
#'
#' # Advance the key past the signature before signing again.
#' key <- xmssadv(key, s1)
#' key$next_index
#' s2 <- cpssign("manifest-2", key)
#' cpsvrf("manifest-2", s2, signpubkey(key))
#'
#' # A signature does not transfer to another message.
#' cpsvrf("manifest-1", s2, signpubkey(key))
#'
#' # A standardised key: no state, any number of signatures.
#' fk <- fipskg("ML-DSA-44")
#' s3 <- cpssign("manifest-3", fk, ctx = "release", determ = TRUE)
#' cpsvrf("manifest-3", s3, fipspubkey(fk), ctx = "release")
#'
#' # An XMSS signature needs an XMSS key.
#' try(cpssign("manifest-4", "shared-secret", scheme = "xmss"))
#' options(op)
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
cpssign <- function(msg, key, scheme = NULL, ctx = NULL,
                         determ = FALSE, prehash = "none",
                         masked = getOption("rmoriebricklayer.masked", TRUE)) {
  masked <- .rmbl_masked_flag(masked)
  msg <- .rmbl_text_input(msg, "msg")
  if (inherits(key, "bricklayer_oqs_key")) {
    .msg <- .rmbl_sign_message(msg)
    .ctx <- .rmbl_fips_context(ctx)
    sz <- fipssz(key$scheme)
    # FIPS 204 and 205 both allow either variant. Hedged signing draws
    # fresh bytes per signature and is the default; the deterministic
    # variant substitutes a fixed value, which is what the standards'
    # test vectors use and what makes a signature reproducible.
    rnd <- if (isTRUE(determ)) {
      .rmbl_fips_fixed_rand(key$scheme, key$public, sz[["rnd"]])
    } else {
      rndbytes(sz[["rnd"]])
    }
    ph <- .rmbl_fips_prehash(prehash)
    sg <- .rmbl_fips_sign(key$scheme, .rmbl_hex_to_raw(key$secret), .msg, masked = masked,
                          .ctx, rnd, ph)
    out <- list(scheme = key$scheme, signature = .rmbl_hexlify(sg),
                context = .ctx, prehash = ph)
    class(out) <- c("bricklayer_signature", "list")
    return(out)
  }
  if (is.null(scheme)) {
    scheme <- if (inherits(key, "bricklayer_signing_key")) "xmss" else "hmac"
  }
  scheme <- .rmbl_arg(scheme, c("xmss", "hmac"))

  if (identical(scheme, "hmac")) {
    tag <- chmac(key, msg)
    out <- list(scheme = "hmac", signature = tag)
    class(out) <- c("bricklayer_signature", "list")
    return(out)
  }

  if (!inherits(key, "bricklayer_signing_key")) {
    stop("`scheme = \"xmss\"` needs a key from pqckg()", call. = FALSE)
  }
  idx <- key$next_index
  if (!is.numeric(idx) || length(idx) != 1L || is.na(idx) || idx < 0 || idx != floor(idx) ||
        idx > .Machine$integer.max) {
    stop("cpssign: this key's `next_index` is not a whole number >= 0 (below 2^31): the key state is damaged; ",
         "do not hand-edit it", call. = FALSE)
  }
  idx <- as.integer(idx)
  if (idx >= key$capacity) {
    stop(sprintf(paste0("this key is exhausted: a height-%d key signs %d ",
                        "messages and all of them are used. Generate a new ",
                        "key -- reusing an index would break the signature ",
                        "scheme."), key$height, key$capacity), call. = FALSE)
  }
  if (!is.raw(msg)) {
    msg <- as.character(msg)
    if (length(msg) != 1L || is.na(msg)) {
      stop("cpssign: `msg` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (is.null(.rmbl_xkey(key, "skprf"))) {
    stop(paste0("this signing key predates the RFC 8391 randomiser and ",
                "cannot produce a conformant signature; generate a new ",
                "one with pqckg()"), call. = FALSE)
  }
  # an index must never sign twice (RFC 8391; NIST SP 800-208 section 8.1): the key is a
  # copied value, so this session remembers the highest index each key has used and refuses
  # an older state -- signing twice with one key object, or with a stale copy
  # the record id is a fingerprint of the secret seed the signer uses, not the `root` field the
  # key carries: an edited root made a stale copy a "new" key (review of 52a8883, A1)
  ids <- .rmbl_xmss_ids(key)
  # retire the index before the signature exists (RFC 8391's order), under the record's lock
  .rmbl_xmss_reserve(ids, idx)
  res <- .bl_busy(sprintf("XMSS signature %d: rebuilding the tree", idx),
                  .Call(C_rmbl_xmss_sign, .rmbl_xkey(key, "skseed"), .rmbl_xkey(key, "skprf"),
                        .rmbl_xkey(key, "pubseed"),
                        as.integer(key$height), idx, msg))
  if (!identical(tolower(as.character(res$root)), ids$root)) {
    stop(sprintf(paste("this key's `root` does not match its seeds: the key object was edited. No signature",
                       "is returned, and index %d stays retired"), idx), call. = FALSE)
  }
  # the signature carries no key material: the object is what verifiers are handed, and the
  # 0.5.9-0.5.12 objects carried the advanced key (skseed and skprf) inside it, so every
  # shared XMSS signature, attestation and bundle file handed out the private key. The next
  # key state is derived from the signature with xmssadv().
  out <- list(scheme = "xmss-sha256", signature = res$wots, auth = res$auth,
              index = idx, root = res$root, height = key$height,
              randomizer = res$randomizer, wire = res$wire)
  class(out) <- c("bricklayer_signature", "list")
  out
}

#' Advance an XMSS key past a signature it made
#'
#' An XMSS signature consumes one leaf, so the key that made it must not sign at that
#' index
#' again. This returns the key with \code{next_index} set to one past the signature's
#' index
#' (refusing a signature that was not made by this key), which is the key to save and to
#' use
#' for the next signature. The signature object itself carries no key material.
#'
#' The package records the highest index each key has signed with and refuses that index
#' again, within the session and across sessions on this machine. The record is the file
#' \code{xmss_used_indices.txt} under
#' \code{tools::R_user_dir("rmoriebricklayer", "config")},
#' which is where CRAN policy lets a package keep its own configuration. A key is entered
#' under a fingerprint of its secret seed (\code{skseed}), not under the \code{root} it
#' carries, so editing a stale copy's \code{root} does not make it a new key, and a
#' signature
#' whose \code{root} does not match the seeds is withheld.
#' [pqckg()]
#' registers a key it generates from fresh randomness. A key built from given
#' seeds is not registered, because it may be one that has signed elsewhere: it signs
#' from
#' index 0 only after
#' [xmssregkey()]
#' vouches for it, and the same holds for any key
#' the record does not know (from another machine, or whose record was deleted).
#' Every reservation runs under an operating-system file lock (\code{flock} on Unix,
#' \code{LockFileEx} on Windows) on \code{xmss_used_indices.txt.flock}, which the system
#' releases when the process ends, so a crashed session leaves no lock for another
#' process to
#' take over. A record that cannot be read, or that cannot be written in full (a full
#' disk),
#' stops the signature. The record of the releases before 0.5.12 (\code{xmss_index.json}
#' in
#' the same directory) is read and merged, and kept as \code{xmss_index.json.migrated}
#' once
#' the new record has been written.
#' Another path can be set with the option \code{rmoriebricklayer.xmssidxfile} or the
#' environment variable \code{RMBL_XMSS_INDEX_FILE}: an absolute path to a regular file,
#' or
#' to one that does not exist yet (a device such as \code{/dev/null}, a directory or a
#' relative path is refused). The option \code{FALSE} (or, except on Windows, where an
#' empty
#' environment variable is an unset one, the value \code{""}) turns the file off: then
#' only
#' the session remembers, every signature warns, and a stale copy of the key reloaded
#' elsewhere signs a used index again. The record does not travel with the key and is
#' lost if
#' the file is deleted, so a key copied to another machine is protected only by the
#' \code{next_index} you saved: save the advanced key after every signature. In CI or a
#' container with a fresh home directory, a key that was not generated in that run is
#' unknown
#' to the record: register it once with
#' [xmssregkey()],
#' or point the record at a file that persists. Examples and vignettes point the record
#' at a temporary file so that checks and builds leave the configuration directory alone.
#' The record keeps one line per key for good (an exhausted key's line is what stops a
#' stale copy of it), and is read and rewritten whole at every signature: a whole
#' signature took 0.5 s with a hundred thousand keys in the record (measured on an x86-64
#' laptop; a slower machine takes longer), and longer when several processes sign at once
#' (each waits its turn for the lock, up to 10 s).
#'
#' [xmssfgt()]
#' resets one key's entry, or removes the whole record, and with it
#' the protection against re-signing: use it for test keys only.
#'
#' @param key The \code{bricklayer_signing_key} that made \code{sig}.
#' @param sig The XMSS signature it made, from
#'   [cpssign()],
#'   or the attestation, bundle or recode manifest that carries it.
#' @param msg The message the signature was made over; when given, the signature is
#'   verified against the key first, so an edited or foreign signature cannot advance it.
#'   Without it, the signature's index is accepted only up to the highest index the
#'   record
#'   shows this key has used here, so an edited index cannot burn the key's remaining
#'   leaves;
#'   a signature made on another machine needs \code{msg}.
#' @return The key with \code{next_index} advanced past the signature's index and past
#'   every index the record knows this key has used.
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' key <- pqckg(height = 2)
#' s1 <- cpssign("manifest-1", key)
#' key <- xmssadv(key, s1)
#' key$next_index
#' s2 <- cpssign("manifest-2", key)
#' cpsvrf("manifest-2", s2, signpubkey(key))
#'
#' # With the message, the signature is verified before the key advances.
#' key <- xmssadv(key, s2, msg = "manifest-2")
#' key$next_index
#'
#' # A key regenerated from seeds is unknown to the record until registered.
#' s <- paste(rep("ab", 32), collapse = "")
#' k2 <- pqckg(height = 1, skseed = s, pubseed = s, skprf = s)
#' try(cpssign("m", k2))
#' invisible(xmssregkey(k2))
#' cpsvrf("m", cpssign("m", k2), signpubkey(k2))
#'
#' # Reset a test key's entry so it may sign from index 0 again.
#' xmssfgt(k2)
#'
#' # A signature that is not an XMSS signature cannot advance a key.
#' try(xmssadv(key, list()))
#' options(op)
#' @seealso [cpssign()],
#'   [xmssfgt()]
#' @export
xmssadv <- function(key, sig, msg = NULL) {
  if (!inherits(key, "bricklayer_signing_key")) {
    stop("`key` must be a signing key from pqckg()", call. = FALSE)
  }
  if (is.list(sig) && is.list(sig$attestation) && is.list(sig$attestation$signature)) {
    sig <- sig$attestation$signature   # a bundle: the attestation's signature
  } else if (inherits(sig, "bricklayer_attestation") ||
               (is.list(sig) && !is.null(sig$signature) && is.list(sig$signature))) {
    sig <- sig$signature   # an attestation or recode manifest: the signature inside
  }
  if (!is.list(sig) || !identical(sig$scheme, "xmss-sha256")) {
    stop("`sig` must be an XMSS signature from cpssign() (or the attestation, bundle or ",
         "recode manifest that carries it)", call. = FALSE)
  }
  nx <- key$next_index
  if (!is.numeric(nx) || length(nx) != 1L || is.na(nx) || nx < 0 || nx != floor(nx) || nx > .Machine$integer.max) {
    stop(paste("xmssadv: this key's `next_index` is not a whole number >= 0 (below 2^31):",
               "the key state is damaged; do not hand-edit it"),
         call. = FALSE)
  }
  if (!identical(tolower(as.character(sig$root)), tolower(as.character(key$root)))) {
    stop("this signature was not made by this key (the roots differ)", call. = FALSE)
  }
  if (!is.null(sig$height) && !identical(as.integer(sig$height), as.integer(key$height))) {
    stop("this signature was not made by this key (the heights differ)", call. = FALSE)
  }
  idx <- suppressWarnings(as.integer(sig$index))
  leaves <- 2L^as.integer(key$height)
  if (length(idx) != 1L || is.na(idx) || idx < 0L || idx >= leaves ||
        !isTRUE(all.equal(as.numeric(sig$index), idx))) {
    stop(sprintf("the signature has no valid index (a whole number below %d)", leaves), call. = FALSE)
  }
  if (!is.null(msg) && !isTRUE(cpsvrf(msg, sig, signpubkey(key)))) {
    stop("the signature does not verify for this key and message: an edited or foreign signature ",
         "cannot advance the key", call. = FALSE)
  }
  # the record knows what this key has used, which an edited index or a stale copy does not
  ids <- .rmbl_xmss_ids(key)
  p <- .rmbl_xmss_index_file()
  rec <- if (is.null(p)) integer(0) else .rmbl_xmss_record_read(p)
  hi <- .rmbl_xmss_highest(ids, rec)
  if (is.null(msg) && idx > hi) {
    # every index signed here was reserved first, so an index above the record's is either an
    # edited signature (which would burn the leaves in between) or one made elsewhere
    stop(sprintf(paste("the signature's index %d is above the highest index this key has signed with here (%d):",
                       "an edited signature, or one made on another machine. Pass message = (what was signed)",
                       "so the signature is verified before the key moves past it"), idx, hi), call. = FALSE)
  }
  key$next_index <- max(as.integer(nx), idx + 1L, hi + 1L)
  if (key$next_index >= leaves) {
    warning(sprintf("this key has used all %d of its one-time indices: generate a new one with pqckg()",
                    leaves), call. = FALSE)
  }
  key
}

#' Verify a capsule manifest signature
#'
#' Checks `sig` against `msg`. For `"hmac"` the
#' comparison is constant-time (verified under valgrind memcheck in CI:
#' `inst/ctcheck`, cases `digest-equal` and `hmac-sha256`). For XMSS the
#' Winternitz chains are walked
#' to their ends and the authentication path replayed to the Merkle root;
#' the digest is bound to both the leaf index and the root, so a signature
#' cannot be replayed at another index or under another key.
#'
#' Returns `FALSE` rather than erroring on a malformed or truncated
#' signature: a verifier must treat unparseable input as \dQuote{not verified},
#' never as an exception to be caught and ignored.
#'
#' @details
#' `TRUE` means the signature is valid for `msg` under `key` (and, for
#' the standardised schemes, `ctx` and the pre-hash). Verification
#' needs only public material, except for HMAC, where the verifier holds
#' the same secret as the signer and could therefore also sign. HMAC tags
#' are compared in constant time.
#'
#' Only two inputs are errors rather than `FALSE`: a `sig` that is not
#' a `bricklayer_signature` at all, and, for an XMSS signature, a key that
#' is not a key object (a string, say) or a `msg` that is not one
#' string or a raw vector. A key or signature whose class, scheme or fields were edited
#' returns `FALSE`. An XMSS signature object written by 0.5.9 to 0.5.12
#' (one that carries a `key_state` field) still verifies, with a warning
#' that it exposed the signer's private key.
#'
#' @param msg The message the signature is claimed to
#' cover.
#' @param sig A `bricklayer_signature` from
#' [cpssign()].
#' @param key The shared secret for `"hmac"`, a public key
#' (or full signing key) for XMSS, or a
#' [fipskg()] key or its
#' [fipspubkey()] for a standardised
#' scheme. A signature is not verified against a key of a different scheme.
#' @param ctx The context string the signature was made
#' under, for the standardised schemes. A signature made under a different
#' context, or under none, does not verify.
#' @param prehash The pre-hash the signature was made with.
#' Taken from the signature when not given, since
#' [cpssign()] records it; supply it to
#' check a signature that arrived without that field.
#' @return `TRUE` or `FALSE` (a length-1 logical, never `NA`).
#' @seealso [cpssign()],
#'   [signpubkey()],
#'   [fipspubkey()].
#' @examplesIf interactive() || any(nzchar(Sys.getenv(c("NOT_CRAN", "MY_UNIVERSE", "IN_PKGDOWN"))))
#' op <- options(rmoriebricklayer.xmssidxfile = tempfile())  # keep this example's
#' # one-time index record out of your configuration directory; leave the default in use
#' key <- pqckg(height = 2)
#' sig <- cpssign("pinned-manifest", key)
#' pub <- signpubkey(key)
#'
#' cpsvrf("pinned-manifest", sig, pub)
#'
#' # Every way of being wrong returns FALSE.
#' cpsvrf("edited-manifest", sig, pub)              # message changed
#' bad <- sig; bad$signature <- paste0("ff", substring(bad$signature, 3))
#' cpsvrf("pinned-manifest", bad, pub)              # signature edited
#' cpsvrf("pinned-manifest", sig,
#'                signpubkey(pqckg(height = 2)))  # foreign key
#'
#' # A truncated signature is not verified, and does not error.
#' trunc <- sig; trunc$signature <- substring(sig$signature, 1, 64)
#' cpsvrf("pinned-manifest", trunc, pub)
#'
#' # HMAC: the verifier holds the same secret.
#' tag <- cpssign("pinned-manifest", "shared-secret", scheme = "hmac")
#' cpsvrf("pinned-manifest", tag, "shared-secret")
#'
#' # Something that is not a signature at all is an error, not FALSE.
#' try(cpsvrf("pinned-manifest", list(signature = "00"), pub))
#' options(op)
#' @export
cpsvrf <- function(msg, sig, key, ctx = NULL,
                           prehash = NULL) {
  .rmbl_no_fn(message = msg)
  if (!inherits(sig, "bricklayer_signature")) {
    stop("`sig` must come from cpssign()", call. = FALSE)
  }
  # a key object whose class or scheme was edited is "not verified", like an edited signature;
  # a value that is not a key object at all (a number, a function) stays an error below
  if (is.list(key)) {
    key_classes <- c("bricklayer_signing_key", "bricklayer_public_key", "bricklayer_oqs_key",
                     "bricklayer_oqs_public_key")
    if (!inherits(key, key_classes)) return(FALSE)
    if (!is.character(key$scheme) || length(key$scheme) != 1L || is.na(key$scheme)) return(FALSE)
  }
  if (inherits(key, c("bricklayer_oqs_key",
                      "bricklayer_oqs_public_key"))) {
    if (!identical(sig$scheme, key$scheme)) return(FALSE)
    .msg <- .rmbl_sign_message(msg)
    .ctx <- .rmbl_fips_context(ctx)
    # A key or signature that is not even hex is "not verified", never
    # an error: a verifier treats unparseable input as failure. Decoding
    # it loosely would turn a stray character into a zero byte and hand
    # the C layer something it never received.
    # a signature field that is not exactly one string is not a signature: reading its first
    # element would verify c(valid, "anything")
    if (!is.character(sig$signature) || length(sig$signature) != 1L) return(FALSE)
    rec <- sig[["context"]]
    if (!is.null(rec) && !is.raw(rec) && !(is.character(rec) && length(rec) == 1L && !is.na(rec))) return(FALSE)
    recp <- sig[["prehash"]]
    if (!is.null(recp) && !(is.character(recp) && length(recp) == 1L && !is.na(recp))) return(FALSE)
    pk <- .rmbl_hex_or_null(key$public)
    sg <- .rmbl_hex_or_null(sig$signature)
    if (is.null(pk) || is.null(sg)) return(FALSE)
    # A pre-hashed signature and a pure one over the same message are
    # different signatures, so which was made has to be stated. It
    # travels with the signature, and an explicit argument overrides it.
    ph <- if (is.null(prehash)) {
      if (is.null(sig[["prehash"]])) "none" else sig$prehash
    } else {
      prehash
    }
    # an unknown pre-hash name in the signature (or asked for) is "not verified", not an error
    ph <- tryCatch(.rmbl_fips_prehash(ph), error = function(e) NULL)
    if (is.null(ph)) return(FALSE)
    return(.rmbl_fips_verify(key$scheme, pk, .msg, .ctx, sg, ph))
  }
  if (identical(sig$scheme, "hmac")) {
    # an edited field (two strings, a number, a short or non-hex digest) is "not verified"
    sg <- sig$signature
    if (!is.character(sg) || length(sg) != 1L || is.na(sg) || !grepl("^[0-9a-fA-F]{64}$", sg)) return(FALSE)
    return(tryCatch(cdgsteq(chmac(key, msg), sg), error = function(e) FALSE))
  }
  # an XMSS object written by 0.5.9 to 7703a04 carries the signer's private key in `key_state`:
  # whoever holds it can sign under this root, so the reader is told, every time
  if (!is.null(sig[["key_state"]])) warning(.rmbl_key_state_warning(), call. = FALSE)
  one_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x) && nzchar(x)
  whole <- function(x) is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) && x == trunc(x) && x >= 0
  # the signature's own shape comes first: an HMAC signature whose scheme was edited to
  # "xmss-sha256" (and the shared secret offered as its key) is "not verified", not a request
  # for an XMSS key. every field the verifier reads is checked here, and a signature whose own
  # root, height or wire form disagrees with the key or with its parts is "not verified": those
  # fields travel with the signature so a reader can check them, not so an editor can change
  # them. every signature this package has produced since 0.5.0 carries index, root, height
  # and wire as numbers and strings; an index of 0.5 or "0", a height of 4.5, a field removed
  # or no randomiser (a pre-RFC 8391 signature) is an edited object, and an edited object is
  # not verified
  if (!one_string(sig$signature) || !one_string(sig$auth) ||
        !one_string(sig[["randomizer"]]) || !whole(sig$index) ||
        !whole(sig$height) || !one_string(sig$root) || !one_string(sig$wire)) {
    return(FALSE)
  }
  if (!inherits(key, c("bricklayer_public_key", "bricklayer_signing_key"))) {
    stop("verifying an XMSS signature needs a key from pqckg() or ",
         "signpubkey()", call. = FALSE)
  }
  # Reject a cross-scheme presentation explicitly. Without this the
  # rejection would still happen, but only incidentally, because the
  # other scheme's signature is the wrong length -- and an incidental
  # check is one that a future change can remove without noticing.
  if (!identical(sig$scheme, key$scheme)) return(FALSE)
  if (!is.raw(msg)) {
    msg <- as.character(msg)
    if (length(msg) != 1L || is.na(msg)) {
      stop("cpsvrf: `msg` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  same <- function(a, b) identical(tolower(as.character(a)), tolower(as.character(b)))
  if (!same(sig$root, key$root)) return(FALSE)
  if (!identical(as.integer(sig$height), as.integer(key$height))) return(FALSE)
  expected_wire <- paste0(sprintf("%08x", as.integer(sig$index)), sig[["randomizer"]],
                          sig$signature, sig$auth)
  if (!same(sig$wire, expected_wire)) return(FALSE)
  .Call(C_rmbl_xmss_verify, .rmbl_xkey(key, "pubseed"), key$root, as.integer(key$height),
        as.integer(sig$index), msg, sig$signature,
        sig$auth, sig[["randomizer"]])
}

#' Hex bytes, or NULL if the string is not an even-length run of hex
#' digits. as.raw(strtoi(...)) would quietly map a non-hex pair to 00.
#' @param hex A hex string.
#' @return A raw vector, or NULL.
#' @noRd
.rmbl_hex_or_null <- function(hex) {
  # one string, not the first of several: a length-2 `signature` field is a tampered object
  if (is.null(hex) || length(hex) != 1L) return(NULL)
  hex <- as.character(hex)
  if (is.na(hex) || nchar(hex) %% 2L != 0L) return(NULL)
  if (!grepl("^[0-9a-fA-F]*$", hex)) return(NULL)
  .rmbl_hex_to_raw(hex)
}

#' Returns the message to sign as bytes.
#'
#' A message is either a single string or raw bytes. Anything else is an
#' error rather than a coercion: silently signing the deparsed form of an
#' object would produce a signature nobody can reproduce.
#' @param message A single string or a raw vector.
#' @return A raw vector.
#' @noRd
.rmbl_sign_message <- function(message) {
  if (is.raw(message)) return(message)
  message <- as.character(message)
  if (length(message) != 1L || is.na(message)) {
    stop("`message` must be a length-1 character vector or a raw vector",
         call. = FALSE)
  }
  charToRaw(message)
}

#' Returns the fixed randomness of the deterministic signing variant.
#'
#' The deterministic variant's substitute for fresh randomness. FIPS 205
#' specifies PK.seed; FIPS 204 specifies 32 zero bytes. Both are fixed
#' per key, which is the whole point: the same message signs identically
#' every time.
#' @param scheme The parameter-set name.
#' @param public_hex The public key as hex.
#' @param n The number of bytes.
#' @return A raw vector of `n` bytes.
#' @noRd
.rmbl_fips_fixed_rand <- function(scheme, public_hex, n) {
  if (is.na(.rmbl_fips_mldsa_mode(scheme))) {
    return(.rmbl_hex_to_raw(substring(public_hex, 1L, 2L * n)))
  }
  raw(n)
}

#' 32 seed bytes as hex, from the operating system's CSPRNG.
#'
#' Deliberately NOT R's generator: set.seed() makes that reproducible by
#' design and its state is recoverable from its output, so a key drawn
#' from it is guessable. rndbytes() fails rather than degrading, which
#' is the behaviour a key needs.
#' @return 64 hex characters.
#' @noRd
.rmbl_random_seed_hex <- function() {
  paste(format(rndbytes(32L)), collapse = "")
}

#' Checks a 32-byte seed given as hex.
#' @param seed The seed passed by the user.
#' @param what The argument's name, used in the error message.
#' @return The seed as lower-case hex.
#' @noRd
.rmbl_check_seed <- function(seed, what) {
  seed <- as.character(seed)
  if (length(seed) != 1L || is.na(seed) || nchar(seed) != 64L ||
      !grepl("^[0-9a-fA-F]{64}$", seed)) {
    stop(sprintf("`%s` must be 64 hex characters (32 bytes)", what),
         call. = FALSE)
  }
  tolower(seed)
}

#' The one sentence every path that meets an old XMSS object with `key_state` says.
#' @return A string.
#' @noRd
.rmbl_key_state_warning <- function() {
  paste0("this XMSS signature carries the signer's private key (`key_state`, written by ",
         "rmoriebricklayer 0.5.9 to 7703a04): treat that key as compromised, generate a new ",
         "one with pqckg() and sign again")
}

# the highest XMSS index each key has signed with in this session, by record id
.rmbl_xmss_used <- new.env(parent = emptyenv())

#' Reads an XMSS key field by its name, under its old name too.
#'
#' An XMSS key field by its name (pubseed, skseed, skprf). Builds of 1.0.0 before the review
#' wrote pub_seed, sk_seed and sk_prf; a key saved by one still reads.
#' @param key The XMSS key.
#' @param nm \code{"pubseed"}, \code{"skseed"} or \code{"skprf"}.
#' @return The field's value, or NULL.
#' @noRd
.rmbl_xkey <- function(key, nm) {
  old <- c(pubseed = "pub_seed", skseed = "sk_seed", skprf = "sk_prf")[[nm]]
  key[[nm]] %||% key[[old]]
}

#' Computes a key's ids in the used-index record.
#'
#' A key's ids in the record: `id` a fingerprint of the secret seed the signer actually uses
#' (so a stale copy whose `root` field was edited is still the same key), `legacy` the
#' root:pubseed id the records of 0.5.12-pre and fcdce03 used, consulted and never written.
#' @param key The XMSS key.
#' @return A list with `id`, `legacy` and `root`.
#' @noRd
.rmbl_xmss_ids <- function(key) {
  sk <- .rmbl_check_seed(.rmbl_xkey(key, "skseed"), "skseed")
  ps <- .rmbl_check_seed(.rmbl_xkey(key, "pubseed"), "pubseed")
  root <- if (is.character(key$root) && length(key$root) == 1L) tolower(key$root) else NA_character_
  if (is.na(root) || !grepl("^[0-9a-f]{64}$", root)) {
    stop("this key's `root` is not 64 hex characters: the key object was edited; do not hand-edit it",
         call. = FALSE)
  }
  list(id = paste0("k:", tolower(csha256(charToRaw(paste0("rmoriebricklayer xmss record\n", sk))))),
       legacy = paste0(root, ":", ps), root = root)
}

#' Finds the XMSS used-index record's path.
#'
#' The used-index record: the option, then the environment variable, else the package's own
#' configuration directory (tools::R_user_dir, the place CRAN policy sets aside for it).
#' FALSE or \code{""} turns the file off (the session record stays); a value that is
#' plainly not a
#' path (\code{"TRUE"}, \code{"0"}, ...), a relative path (it would follow the working
#' directory) and a path
#' that is not a regular file (a device such as /dev/null, which the rename replaced when run
#' as root, or a directory) are refused (review of 52a8883, B7).
#' @param cli For the command line: only RMBL_XMSS_INDEX_FILE, and NULL when it is not set (the
#'   command line writes only where it is pointed, never to the configuration directory).
#' @return The path, or NULL when the record is turned off.
#' @noRd
.rmbl_xmss_index_file <- function(cli = FALSE) {
  p <- if (!cli) .rmbl_getopt("xmssidxfile", NULL)
  from <- "the option rmoriebricklayer.xmssidxfile"
  if (is.null(p)) {
    p <- Sys.getenv("RMBL_XMSS_INDEX_FILE", unset = NA_character_)
    from <- "RMBL_XMSS_INDEX_FILE"
  }
  if (isFALSE(p)) return(NULL)
  if (!is.character(p) || length(p) != 1L) {
    stop(sprintf("%s must be a file path, \"\" or FALSE", from), call. = FALSE)
  }
  if (is.na(p)) {
    if (cli) return(NULL)
    p <- file.path(tools::R_user_dir("rmoriebricklayer", "config"), "xmss_used_indices.txt")
  } else {
    p <- trimws(p)
    if (!nzchar(p)) return(NULL)
    if (toupper(p) %in% c("TRUE", "FALSE", "T", "F", "0", "1", "NULL", "NA", "YES", "NO", "ON", "OFF")) {
      stop(sprintf("%s is \"%s\", which is not a file path: give a path, or \"\" / FALSE to turn the file off",
                   from, p), call. = FALSE)
    }
    p <- path.expand(p)
    if (!grepl("^(/|[A-Za-z]:[/\\\\]|[/\\\\]{2})", p)) {
      stop(sprintf(paste("%s is \"%s\", a relative path, which would follow the working directory: give an",
                         "absolute path, or \"\" / FALSE to turn the file off"), from, p), call. = FALSE)
    }
  }
  kind <- .Call(C_rmbl_path_kind, p)
  if (!kind %in% c("missing", "regular")) {
    stop(sprintf("%s: %s is a %s, not a regular file, and the record would be written over it", from, p,
                 if (identical(kind, "directory")) "directory" else "device or other special file"), call. = FALSE)
  }
  if (!.Call(C_rmbl_path_kind, dirname(p)) %in% c("missing", "directory")) {
    stop(sprintf("%s: %s is not a directory", from, dirname(p)), call. = FALSE)
  }
  p
}

#' Reads the XMSS used-index record.
#'
#' One line per key, `k:<fingerprint><TAB>highest index used` (or a legacy `root:pubseed` line
#' from 0.5.12-pre). A line that is not that is an error, not a line to skip: a record that
#' cannot be read cannot be trusted. The fcdce03 record next to it is merged in.
#' @param p The record's path.
#' @return A named integer vector: the highest index used, by key id.
#' @noRd
.rmbl_xmss_record_read <- function(p) {
  ids <- character()
  idx <- integer()
  if (file.exists(p)) {
    lines <- readLines(p, warn = FALSE, encoding = "UTF-8")
    lines <- lines[grepl("[^[:space:]]", lines, perl = TRUE)]
    ok <- grepl("^(k:[0-9a-f]{64}|[0-9a-f]{64}:[0-9a-f]{64})\t(-1|[0-9]{1,9})$", lines, perl = TRUE)
    if (!all(ok)) {
      stop(sprintf(paste("%s (the XMSS used-index record) has %d malformed line(s), the first at line %d: a record",
                         "that cannot be read cannot be trusted, so no XMSS signature is made until the file is",
                         "repaired or removed (xmssfgt() removes it, and with it the protection",
                         "against re-signing an index)"), p, sum(!ok), which(!ok)[[1L]]), call. = FALSE)
    }
    # split at the one tab the check above guarantees: two regular-expression passes took most of a
    # signature's time with 100,000 keys in the record (1.4-1.8 s; review of e57fed5)
    tab <- regexpr("\t", lines, fixed = TRUE)
    ids <- substr(lines, 1L, tab - 1L)
    idx <- as.integer(substring(lines, tab + 1L))
  }
  legacy <- .rmbl_xmss_legacy_json(p)
  if (length(legacy)) {
    ids <- c(ids, names(legacy))
    idx <- c(idx, unname(legacy))
  }
  if (!length(ids)) return(integer(0))
  # a key listed twice keeps its highest index
  o <- order(ids, idx, method = "radix")
  ids <- ids[o]
  idx <- idx[o]
  keep <- !duplicated(ids, fromLast = TRUE)
  stats::setNames(idx[keep], ids[keep])
}

#' Reads the XMSS index record of the releases before 0.5.12.
#'
#' The record of the releases before 0.5.12, `xmss_index.json` (key root:pubseed -> highest
#' index used), in the same directory: read and merged, so an upgrade does not forget which
#' indices were used (review of 52a8883, A3). Unreadable is an error, like the new record.
#' @param p The current record's path; the old record is looked for beside it.
#' @return A named integer vector: the highest index used, by legacy id.
#' @noRd
.rmbl_xmss_legacy_json <- function(p) {
  j <- file.path(dirname(p), "xmss_index.json")
  kind <- .Call(C_rmbl_path_kind, j)
  if (identical(kind, "missing")) return(integer(0))
  # the same regular-file check as the record itself: a FIFO here blocked readChar() for good
  # while the record lock was held, so every other signer timed out (review of 02a38be, C7)
  if (!identical(kind, "regular")) {
    stop(sprintf(paste("%s (the XMSS index record written before 0.5.12) is a %s, not a regular file: no XMSS",
                       "signature is made until it is removed"), j,
                 if (identical(kind, "directory")) "directory" else "device or other special file"), call. = FALSE)
  }
  bad <- function() {
    stop(sprintf(paste("%s (the XMSS index record written before 0.5.12) cannot be read: no XMSS signature is",
                       "made until it is repaired or removed, since it may list indices that were used"), j),
         call. = FALSE)
  }
  txt <- tryCatch(readChar(j, file.size(j), useBytes = TRUE), error = function(e) NULL)
  rec <- if (is.null(txt)) NULL else tryCatch(fromjs(txt, simplifyVector = TRUE),
                                               error = function(e) NULL)
  if (!is.list(rec) || (length(rec) && is.null(names(rec)))) bad()
  out <- integer()
  for (k in names(rec)) {
    v <- rec[[k]]
    kk <- tolower(k)
    if (!grepl("^[0-9a-f]{64}:[0-9a-f]{64}$", kk) || length(v) != 1L || !is.numeric(v) || is.na(v) ||
          v < -1 || v != round(v)) {
      bad()
    }
    out[kk] <- max(as.integer(v), if (kk %in% names(out)) out[[kk]] else -1L)
  }
  out
}

#' Writes the XMSS used-index record.
#'
#' The whole record, written to a temporary file whose size is checked and which is flushed to the
#' disk before it replaces the old
#' one: a write that did not complete (a full disk) stops the signature instead of renaming an
#' empty file over the record (review of 52a8883, B3).
#' @param p The record's path.
#' @param rec A named integer vector: the highest index used, by key id.
#' @return `p`, invisibly.
#' @noRd
.rmbl_xmss_record_write <- function(p, rec) {
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  # the record is written only under its lock, so a temporary file OF THIS RECORD found now was left
  # by a writer that died mid-write (SIGXFSZ, a kill): it is removed. Regular files only (review of
  # 02a38be, B3). Temporary names carry the record's own name: every xmss-*.tmp in the directory
  # was removed while holding one record's lock, deleting the in-flight files of other records
  # beside it (117 of 900 writes failed with three records in one directory; review of e57fed5, E11).
  own <- paste0(basename(p), ".xmss-")
  # this record's own temporaries only: the prefix, then tempfile()'s letters and digits, then
  # .tmp. A prefix alone also matched the files of a record whose name starts with this one
  # ("pre.txt" removed "pre.txt.xmss-b.xmss-1a2b.tmp" from under "pre.txt.xmss-b"; review of
  # 29a55d8, E11 residual). A record name may hold any character: it is escaped, not interpreted
  own_re <- paste0("^", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", own), "[A-Za-z0-9]+[.]tmp$")
  for (f in list.files(dirname(p), pattern = "[.]tmp$", full.names = TRUE, all.files = TRUE)) {
    if (!grepl(own_re, basename(f))) next
    if (identical(.Call(C_rmbl_path_kind, f), "regular")) unlink(f)
  }
  tmp <- tempfile(pattern = own, tmpdir = dirname(p), fileext = ".tmp")
  # the C writer removes only a temporary file it created itself
  fail <- function(why) {
    stop(sprintf("could not write the XMSS used-index record %s (%s): no signature is made", p, why), call. = FALSE)
  }
  body <- if (length(rec)) paste0(names(rec), "\t", rec, "\n", collapse = "") else ""
  # written, flushed to the disk, size-checked and renamed in C (rmbl_flock.c): a short write or
  # a full disk leaves the old record in place and stops the signature
  why <- .Call(C_rmbl_write_file_checked, tmp, p, charToRaw(body))
  if (!is.null(why)) fail(why)
  # the record of the releases before 0.5.12 is merged into what was just written: keep it,
  # under a name that is no longer read
  j <- file.path(dirname(p), "xmss_index.json")
  if (file.exists(j)) file.rename(j, paste0(j, ".migrated"))
  invisible(p)
}

#' What to check when the lock file cannot be opened: a read-only directory, or a lock file another
#' user owns. \code{""} when the system's reason says neither.
#' @param m The lock error's message.
#' @param lock The lock file's path.
#' @return A hint to add to the message, or \code{""}.
#' @noRd
.rmbl_lock_hint <- function(m, lock) {
  if (grepl("Read-only", m)) return(" (is the directory read-only?)")
  if (!grepl("Permission denied", m)) return("")
  if (file.exists(lock) && file.access(lock, 2L) != 0L) " (is the lock file owned by another user?)" else
    " (is the directory read-only?)"
}

#' Runs a function under an exclusive lock on the used-index record.
#'
#' An exclusive operating-system lock around read -> check -> write (flock on Unix, LockFileEx on
#' Windows; rmbl_flock.c). The kernel releases it when the process exits, so no lock is ever
#' taken over: the lock directory of 0.5.12-pre was, by check-then-delete, which let two signers
#' hold it at once and sign one index (review of 52a8883, B2), and spun for ever on a lock it
#' could not delete (B4). The wait is bounded at 10 s and draws no random numbers.
#' @param p The record's path.
#' @param f The function to run, with no arguments.
#' @param what What the file is, for the refusals.
#' @return The value of `f()`.
#' @noRd
.rmbl_xmss_with_lock <- function(p, f, what = "the XMSS used-index record") {
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  lock <- paste0(p, ".flock")
  # one non-blocking attempt at a time, the wait between them in R: Sys.sleep() takes Ctrl-C, and
  # an attempt that finds the lock busy has already closed its descriptor, so an interrupt leaves
  # nothing open (the wait used to run inside C, deaf to Ctrl-C for up to 10 s; review of 02a38be)
  start <- proc.time()[["elapsed"]]
  # the lock is taken and f() run in one C frame, the release being that frame's cleanup
  # (R_ExecWithCleanup): an error or a Ctrl-C inside f() closes the descriptor on the way out, and
  # no R code runs between taking the lock and registering the release. The on.exit() of before was
  # R code too, which an interrupt could cut short ahead of its .Call: a lock stayed held for the
  # rest of the session 73 to 95 times per 5,000 interrupts (review of 29a55d8, G6; e57fed5, E12)
  busy <- new.env(parent = emptyenv())
  repeat {
    r <- tryCatch(.Call(C_rmbl_flock_with, lock, f, busy), error = function(e) {
      m <- conditionMessage(e)
      if (!grepl("lock file", m, fixed = TRUE)) stop(e)
      stop(sprintf("cannot use %s %s: %s%s", what, p, m, .rmbl_lock_hint(m, lock)), call. = FALSE)
    })
    if (!identical(r, busy)) return(r)
    if (proc.time()[["elapsed"]] - start >= 10) {
      stop(sprintf("could not lock %s %s within 10 s: another process holds %s", what, p, lock),
           call. = FALSE)
    }
    Sys.sleep(0.02)
  }
}

#' The highest index this key is known to have used: the record on disk (its id, and the legacy
#' id of the older records) and this session.
#' @param ids The key's ids from `.rmbl_xmss_ids()`.
#' @param rec The record from `.rmbl_xmss_record_read()`.
#' @return The highest index used, or -1.
#' @noRd
.rmbl_xmss_highest <- function(ids, rec) {
  cand <- -1L
  for (k in c(ids$id, ids$legacy)) {
    if (length(rec) && k %in% names(rec)) cand <- max(cand, rec[[k]])
  }
  mem <- .rmbl_xmss_used[[ids$id]]
  if (!is.null(mem)) cand <- max(cand, mem)
  cand
}

#' Tells whether the record or this session knows a key.
#' @param ids The key's ids from `.rmbl_xmss_ids()`.
#' @param rec The record from `.rmbl_xmss_record_read()`.
#' @return `TRUE` or `FALSE`.
#' @noRd
.rmbl_xmss_known <- function(ids, rec) {
  any(c(ids$id, ids$legacy) %in% names(rec)) || !is.null(.rmbl_xmss_used[[ids$id]])
}

#' Retire `idx` for this key before the signature is made (RFC 8391's order), under the lock.
#' @param ids The key's ids from `.rmbl_xmss_ids()`.
#' @param idx The index to retire.
#' @return `TRUE` invisibly, or `FALSE` invisibly when the record is off and only this session remembers.
#' @noRd
.rmbl_xmss_reserve <- function(ids, idx) {
  refuse <- function(hi) {
    stop(sprintf(paste0("index %d of this key was already used: signing it again would break the ",
                        "scheme. Carry the key forward with xmssadv(key, signature) after every ",
                        "signature (next index %d)."), idx, hi + 1L), call. = FALSE)
  }
  # rmbl sign reserved a block in the key's own state before signing (RFC 10033 section 5.9): an
  # index is taken from that block, in order, and the configuration directory is not used
  # (the block is the durable state's; the session memory is not consulted, so two sectors of one key
  # may sign in one session)
  blk <- .rmbl_xmss_block[[ids$id]]
  if (!is.null(blk)) {
    if (idx < blk[[1L]] || idx > blk[[2L]]) {
      stop(sprintf("index %d is outside the block this run reserved (%d to %d): no signature is made", idx, blk[[1L]],
                   blk[[2L]]), call. = FALSE)
    }
    assign(ids$id, c(idx + 1L, blk[[2L]]), envir = .rmbl_xmss_block)
    return(invisible(TRUE))
  }
  p <- .rmbl_xmss_index_file()
  if (is.null(p)) {
    hi <- .rmbl_xmss_highest(ids, integer(0))
    if (idx <= hi) refuse(hi)
    assign(ids$id, idx, envir = .rmbl_xmss_used)
    warning(paste("the XMSS used-index record is off (rmoriebricklayer.xmssidxfile / RMBL_XMSS_INDEX_FILE):",
                  "only this session remembers which indices this key has used, so a stale copy of the key",
                  "reloaded elsewhere will sign a used index again. Turn the record on unless you keep the",
                  "advanced key yourself after every signature"), call. = FALSE)
    return(invisible(FALSE))
  }
  .rmbl_xmss_with_lock(p, function() {
    rec <- .rmbl_xmss_record_read(p)
    hi <- .rmbl_xmss_highest(ids, rec)
    if (idx <= hi) refuse(hi)
    if (!.rmbl_xmss_known(ids, rec) && idx == 0L) {
      stop(paste("this XMSS key is not in the used-index record on this machine, and it claims never to have",
                 "signed (next_index 0): it was generated elsewhere or from given seeds, or the record was",
                 "deleted. If it has never signed, register it with xmssregkey(key); if it has, carry",
                 "it forward with xmssadv(key, its_last_signature, message), or generate a new key with",
                 "pqckg()"), call. = FALSE)
    }
    rec[ids$id] <- idx
    .rmbl_xmss_record_write(p, rec)
    assign(ids$id, idx, envir = .rmbl_xmss_used)
  })
  invisible(TRUE)
}

#' Add a key to the record as \dQuote{registered, nothing used} (-1), never lowering an
#' entry.
#' @param key The XMSS key.
#' @param fresh Whether the key was just generated, so a registered entry is not an error.
#' @return `TRUE` invisibly, or `FALSE` invisibly when the record is off.
#' @noRd
.rmbl_xmss_register <- function(key, fresh = FALSE) {
  ids <- .rmbl_xmss_ids(key)
  p <- .rmbl_xmss_index_file()
  if (is.null(p)) {
    if (is.null(.rmbl_xmss_used[[ids$id]])) assign(ids$id, -1L, envir = .rmbl_xmss_used)
    return(invisible(FALSE))
  }
  .rmbl_xmss_with_lock(p, function() {
    rec <- .rmbl_xmss_record_read(p)
    hi <- .rmbl_xmss_highest(ids, rec)
    if (!fresh && hi >= 0L) {
      stop(sprintf(paste("this key is already in the record with index %d used: it has signed here before,",
                         "so carry it forward with xmssadv() instead of registering it"), hi),
           call. = FALSE)
    }
    if (!ids$id %in% names(rec)) {
      rec[ids$id] <- max(-1L, hi)
      .rmbl_xmss_record_write(p, rec)
    }
    if (is.null(.rmbl_xmss_used[[ids$id]])) assign(ids$id, max(-1L, hi), envir = .rmbl_xmss_used)
  })
  invisible(TRUE)
}

#' @rdname xmssadv
#' @param keytoreg For
#'   [xmssregkey()]: a signing key generated on
#'   another
#'   machine, regenerated from given seeds, or whose record was deleted, that has never
#'   signed; it is added to the record so that it may sign from \code{next_index}. A key
#'   the record shows has signed is refused.
#' @export
xmssregkey <- function(keytoreg) {
  if (!inherits(keytoreg, "bricklayer_signing_key")) {
    stop("`keytoreg` must be a signing key from pqckg()", call. = FALSE)
  }
  .rmbl_xmss_register(keytoreg, fresh = FALSE)
  invisible(keytoreg)
}

#' @rdname xmssadv
#' @param keytofgt For
#'   [xmssfgt()]:
#'   a signing key (the record is keyed by its secret seed) whose
#'   entry alone is reset to \dQuote{nothing used} (it may sign from index 0 again);
#'   \code{NULL}
#'   removes the whole record (every key, and the record of the releases before 0.5.12),
#'   after which only keys generated afterwards, or vouched for by
#'   [xmssregkey()], may sign.
#' @export
xmssfgt <- function(keytofgt = NULL) {
  p <- .rmbl_xmss_index_file()
  if (is.null(keytofgt)) {
    rm(list = ls(.rmbl_xmss_used, all.names = TRUE), envir = .rmbl_xmss_used)
    if (!is.null(p)) {
      for (f in c(p, file.path(dirname(p), c("xmss_index.json", "xmss_index.json.migrated")))) {
        if (file.exists(f)) unlink(f)
      }
    }
    return(invisible(NULL))
  }
  if (!inherits(keytofgt, "bricklayer_signing_key")) {
    stop("`keytofgt` must be the signing key from pqckg() (the record is keyed by its secret seed)",
         call. = FALSE)
  }
  ids <- .rmbl_xmss_ids(keytofgt)
  assign(ids$id, -1L, envir = .rmbl_xmss_used)   # known, nothing used: it may sign from index 0 again
  if (!is.null(p)) {
    .rmbl_xmss_with_lock(p, function() {
      rec <- .rmbl_xmss_record_read(p)
      rec <- rec[!names(rec) %in% c(ids$id, ids$legacy)]
      rec[ids$id] <- -1L
      .rmbl_xmss_record_write(p, rec)
    })
  }
  invisible(NULL)
}
