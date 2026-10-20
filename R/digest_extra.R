# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Provenance digests beyond the SHA-256 the package already shipped:
# SHA-512, HMAC-SHA-256 (so a manifest can be SIGNED, not merely
# checksummed), CRC-32 (cheap integrity for very large members), and a
# Merkle tree over file chunks (so a mismatch names WHICH chunk moved).

#' SHA-512 hex digest (C backend)
#'
#' Hashes character or raw input with the self-contained SHA-512 (FIPS
#' 180-4) in the compiled core and returns the digest as hex. A digest is a
#' fingerprint: any change to the input gives a different value, so it pins
#' a data file, a code string or a manifest. Use it over
#' [csha256()]
#' when a pin has to outlive the capsule by decades: the wider digest leaves
#' more margin, including against a quantum adversary, for whom Grover's
#' algorithm halves the effective preimage exponent.
#'
#' @details
#' Character input is hashed element by element, each string as its bytes
#' (UTF-8 text gives the UTF-8 bytes; no newline is added). \code{NA}
#' elements give \code{NA}. Other atomic input (numbers, logicals) is first
#' converted with \code{as.character()}, so \code{csha512(1)} is the
#' digest of the text \code{"1"}. A raw vector is hashed as one byte string.
#' For files use [sha512file()]. Pure computation; no side
#' effects.
#'
#' @param x A character vector (one digest per element) or a raw vector
#'   (one digest of all its bytes).
#' @return A character vector of 128-character lowercase hex digests: one
#'   per element for character input (\code{NA} for \code{NA}), length 1 for
#'   raw input.
#' @seealso
#' [csha256()],
#' [ccrc32()],
#' [sha512file()]
#' @examples
#' # FIPS 180-4 test vector for "abc".
#' csha512("abc")
#'
#' # Vectorised over character input; NA stays NA.
#' csha512(c("abc", "def", NA))
#'
#' # Raw input hashes the bytes directly, and agrees with the character
#' # form for the same bytes.
#' identical(csha512("abc"), csha512(charToRaw("abc")))
#'
#' # Twice the digest width of SHA-256.
#' c(sha256 = nchar(csha256("abc")), sha512 = nchar(csha512("abc")))
#'
#' # numbers are hashed as their text
#' identical(csha512(1), csha512("1"))
#' @export
csha512 <- function(x) {
  .rmbl_no_fn(x = x)
  if (is.raw(x)) return(.Call(C_rmbl_sha512, x))
  x <- as.character(x)
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  if (any(ok)) out[ok] <- .Call(C_rmbl_sha512, x[ok])
  out
}

#' CRC-32 checksum (C backend)
#'
#' Computes the CRC-32 checksum of character or raw input: the CRC of ITU
#' V.42, zip and PNG (reflected polynomial \code{0xEDB88320}, initial value
#' and final XOR \code{0xFFFFFFFF}). Use it as a fast first check that a
#' large file or capsule member arrived intact, or to compare with the CRC
#' a zip archive records for its members.
#'
#' @details
#' A CRC is NOT a cryptographic digest: it detects accidental corruption
#' -- a truncated download, a flipped bit on disk -- but anyone can
#' construct a different input with the same value, so it must never be
#' used where [csha256()] is meant. It is
#' here because it is far cheaper than SHA-256 over gigabyte-scale capsule
#' members, which makes it the right first pass when the question is only
#' "did this file arrive intact".
#'
#' Character input is checked element by element, as its bytes, with
#' \code{NA} giving \code{NA}; other atomic input is converted with
#' \code{as.character()}. A raw vector gives one checksum. For files use
#' [crc32file()].
#'
#' @param x A character vector (one checksum per element) or a raw vector
#'   (one checksum of all its bytes).
#' @return A numeric vector of unsigned 32-bit checksums (one per element
#'   for character input, \code{NA} for \code{NA}; length 1 for raw input).
#'   Returned as \code{double} rather than \code{integer} because values
#'   above \code{2^31 - 1} are not representable as an R integer.
#' @seealso [csha256()] for integrity against
#' tampering rather than accident.
#' @examples
#' # The standard check value: CRC-32("123456789") is 0xCBF43926.
#' ccrc32("123456789")
#' ccrc32("123456789") == 0xCBF43926
#'
#' # The empty input has checksum zero.
#' ccrc32("")
#'
#' # Vectorised, and sensitive to a single changed byte.
#' ccrc32(c("brick", "brack"))
#'
#' # Raw bytes work the same way.
#' ccrc32(charToRaw("123456789"))
#' @export
ccrc32 <- function(x) {
  .rmbl_no_fn(x = x)
  if (is.raw(x)) return(.Call(C_rmbl_crc32, x))
  x <- as.character(x)
  out <- rep(NA_real_, length(x))
  ok <- !is.na(x)
  if (any(ok)) out[ok] <- .Call(C_rmbl_crc32, x[ok])
  out
}

#' Keyed digest and constant-time comparison (C backend)
#'
#' \code{chmac()} computes HMAC-SHA-256 (RFC 2104), a digest of a
#' message under a secret key, and \code{cdgsteq()} compares two
#' digests without leaking through timing how much of them matched. Use the
#' pair to sign a manifest or a capsule with a shared secret and to check a
#' signature someone hands you.
#'
#' @details
#' The difference from a plain [csha256()] is
#' AUTHENTICATION -- anyone
#' can recompute a SHA-256 and so anyone can forge one after editing a
#' manifest, but only a holder of the key can produce a matching HMAC. This
#' is what makes [cpssign()]'s \code{"hmac"} scheme
#' meaningful. The
#' construction is
#' \deqn{\mathrm{HMAC}(K, m) = H((K' \oplus opad) \| H((K' \oplus ipad) \| m))}
#' with \eqn{H} = SHA-256, \eqn{K'} the key padded to the 64-byte block (or
#' hashed first when longer), \eqn{ipad} = \code{0x36} and \eqn{opad} =
#' \code{0x5c} repeated. The results match the RFC 4231 test vectors.
#'
#' \code{cdgsteq()} compares two digests in constant time (verified
#' under valgrind memcheck in CI with both inputs marked secret:
#' \code{inst/ctcheck}, case \code{digest-equal}). Use it
#' instead of \code{==} whenever the comparison is against a value an
#' attacker supplied: a short-circuiting comparison leaks, through its own
#' timing, how many leading characters were correct, which is enough to
#' recover a tag byte by byte. It compares the strings exactly, so case
#' matters (\code{"ABC"} is not \code{"abc"}): lower-case both first if the
#' digests may come in either case.
#'
#' Errors: \code{key} or \code{msg} that is neither one non-NA string nor
#' a raw vector; \code{a} or \code{b} that is not one non-NA string.
#'
#' @param key Secret key, as a length-1 character vector or a
#'   raw vector. Keys longer than the 64-byte block are hashed down first,
#'   per RFC 2104. Use at least 32 bytes of real entropy; against a quantum
#'   adversary Grover halves the effective key strength, so a 256-bit key
#'   retains a 128-bit margin.
#' @param msg Message to authenticate, as a length-1
#'   character vector (its bytes) or a raw vector.
#' @param a,b Digests to compare, each a length-1 character vector.
#' @return \code{chmac()} a length-1 character vector: 64
#'   lowercase hex characters. \code{cdgsteq()} a length-1 logical;
#'   \code{FALSE} when the two differ in length.
#' @references Krawczyk H, Bellare M, Canetti R (1997). HMAC: Keyed-Hashing
#' for Message Authentication. RFC 2104.
#'   \doi{10.17487/RFC2104}
#' @examples
#' # RFC 4231 test case 2.
#' chmac("Jefe", "what do ya want for nothing?")
#'
#' # The key changes the digest, so a manifest cannot be re-signed
#' # without it.
#' chmac("key-a", "manifest")
#' chmac("key-b", "manifest")
#'
#' # Raw keys and messages are accepted.
#' chmac(as.raw(rep(0x0b, 20)), "Hi There")
#'
#' # Compare tags in constant time, never with ==.
#' tag <- chmac("k", "m")
#' cdgsteq(tag, chmac("k", "m"))
#' cdgsteq(tag, chmac("k", "tampered"))
#' cdgsteq(tag, "too-short")
#'
#' # one message at a time
#' try(chmac("k", c("m1", "m2")))
#' @name keyeddgst
#' @export
chmac <- function(key, msg) {
  key <- .rmbl_text_input(key, "key")
  msg <- .rmbl_text_input(msg, "msg")
  if (!is.raw(key)) {
    key <- as.character(key)
    if (length(key) != 1L || is.na(key)) {
      stop("`key` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (!is.raw(msg)) {
    msg <- as.character(msg)
    if (length(msg) != 1L || is.na(msg)) {
      stop("`msg` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  .Call(C_rmbl_hmac_sha256, key, msg)
}

#' @rdname keyeddgst
#' @export
cdgsteq <- function(a, b) {
  .rmbl_no_fn(a = a, b = b)
  a <- as.character(a)
  b <- as.character(b)
  if (length(a) != 1L || length(b) != 1L || is.na(a) || is.na(b)) {
    stop("`a` and `b` must each be a length-1 character vector",
         call. = FALSE)
  }
  .Call(C_rmbl_digest_equal, a, b)
}

#' Merkle tree over capsule chunks (C backend)
#'
#' A single SHA-256 over a whole file tells you it changed. A Merkle tree
#' over its chunks tells you WHICH chunk changed, and proves that one chunk
#' belongs to the pinned file without re-reading the rest of it. Use these
#' functions to pin a large data file as a root digest, to find the part of
#' a re-released file that differs, or to hand someone one chunk with a
#' short proof that it is part of the pinned file.
#'
#' \code{mrkroot()} reduces the chunks to one root digest.
#' \code{mrklvs()} returns the per-chunk digests the root is built
#' from, so two capsules can be diffed chunk by chunk.
#' \code{mrkprf()} returns the sibling digests on the path from one
#' leaf to the root, and \code{mrkvrf()} replays that path.
#'
#' @details
#' Each leaf is the SHA-256 of the byte 0x00 followed by a chunk's bytes.
#' Each parent is the SHA-256 of the byte 0x01 followed by the 64 bytes of
#' its left and right child digests (the bytes, not their hex spelling).
#' Levels are paired left to right. This is \code{scheme = 2}, the default
#' from 0.5.13 on.
#'
#' An unpaired node at an odd level is PROMOTED unchanged rather than
#' hashed against a duplicate of itself. Duplicating it would let two
#' different chunk lists produce the same root -- the weakness behind
#' CVE-2012-2459 -- so promotion is a correctness requirement, not a
#' preference. A promoted node adds no step to a proof, so a proof can be
#' shorter than \eqn{\lceil \log_2 n \rceil}.
#'
#' The two prefix bytes are the leaf and node domain separation of RFC
#' 6962: without them an interior node, given as the 64 bytes of its two
#' child digests, verifies as a "leaf" with the shorter proof from its
#' parent. Roots and proofs made by 0.5.12 and earlier have no prefixes
#' (\code{scheme = 1}, the weaker scheme). Pass \code{scheme = 1} to
#' \code{mrkroot()}, \code{mrklvs()} or \code{mrkprf()} to
#' recompute such a root. \code{mrkprf()} records its scheme in the
#' proof, and \code{mrkvrf()} reads it from there unless
#' \code{scheme} is given. A proof with no recorded scheme was made by
#' 0.5.12 or earlier: it is verified under scheme 1, with a warning. Pass
#' \code{scheme = 2} to \code{mrkvrf()} to refuse such a proof,
#' since a scheme-1 check still accepts an interior node as a leaf.
#'
#' Character chunks are taken as their bytes, so a root computed from
#' character input equals the root of the same bytes as raw vectors. The
#' comparison in \code{mrkvrf()} is
#' [cdgsteq()]
#' (constant time, case-sensitive).
#'
#' Errors: \code{chunks} that is not character, raw or a list of raw vectors
#' and single strings, or that contains \code{NA}; \code{index} outside
#' \code{1..length(chunks)}; a \code{scheme} other than 1 or 2; a \code{leaf} that is
#' more than one chunk; a
#' \code{proof} without \code{sibling} and \code{side}, or with the two of
#' different lengths.
#'
#' @param chunks Chunk contents, in order: a character vector (one chunk per
#'   element), a single raw vector (one chunk), or a list of raw vectors and
#'   single strings, such as [chnkfile()] returns.
#' @param index The chunk to prove, one whole number from 1 to the number of
#'   chunks.
#' @param leaf The chunk whose membership is being verified: one string or
#'   one raw vector.
#' @param proof The list returned by \code{mrkprf()}.
#' @param root The expected root digest, a 64-character hex string as
#'   \code{mrkroot()} returns.
#' @param scheme The hashing scheme: 2 (the default for building, with leaf
#'   and node prefixes) or 1 (no prefixes, as 0.5.12 and earlier built
#'   them). For \code{mrkvrf()}, \code{NULL} (the default) reads the
#'   scheme from \code{proof}; a number requires that scheme, and a proof
#'   that records a different one does not verify.
#' @return \code{mrkroot()} a length-1 character vector (64 lowercase hex
#'   characters), or \code{NA} for no chunks. \code{mrklvs()} a
#'   character vector of per-chunk digests, one per chunk
#'   (\code{character(0)} for none). \code{mrkprf()} a list with
#'   \code{sibling} (character, the sibling digests from the leaf upward),
#'   \code{side} (character, \code{"left"} or \code{"right"}: the side the
#'   sibling is on) and \code{scheme} (integer). \code{mrkvrf()} a
#'   length-1 logical.
#' @examples
#' chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")
#'
#' root <- mrkroot(chunks)
#' root
#'
#' # A single chunk's root is just its own leaf digest.
#' mrkroot("only") == csha256(c(as.raw(0), charToRaw("only")))
#'
#' # The leaves are the per-chunk digests, so a diff names the culprit.
#' before <- mrklvs(chunks)
#' after <- mrklvs(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
#' which(before != after)
#'
#' # Prove chunk 3 belongs, without holding chunks 1, 2 or 4.
#' pr <- mrkprf(chunks, 3)
#' pr
#' mrkvrf(chunks[3], pr, root)
#'
#' # The proof fails for a chunk that was not in the tree.
#' mrkvrf("row5,row6-EDITED", pr, root)
#'
#' # Any change to any chunk changes the root.
#' mrkroot(chunks) == mrkroot(c(chunks[1:3], "row7,row8 "))
#'
#' # an odd count: the last node is promoted, so its proof has one step
#' mrkprf(c("a", "b", "c"), 3)
#'
#' # an index past the end is refused
#' try(mrkprf(chunks, 5))
#'
#' # a root pinned by 0.5.12 or earlier recomputes with scheme = 1, and its
#' # proofs (which record no scheme) verify with a warning
#' old <- mrkprf(chunks, 3, scheme = 1)
#' old$scheme <- NULL
#' withCallingHandlers(
#'   mrkvrf(chunks[3], old, mrkroot(chunks, scheme = 1)),
#'   warning = function(w) invokeRestart("muffleWarning"))
#' @name mrk
#' @export
mrkroot <- function(chunks, scheme = 2L) {
  chunks <- .rmbl_chunk_bytes(chunks)
  scheme <- .rmbl_merkle_scheme(scheme)
  if (length(chunks) == 0L) return(NA_character_)
  .Call(C_rmbl_merkle_root, chunks, scheme)
}

#' @rdname mrk
#' @export
mrklvs <- function(chunks, scheme = 2L) {
  chunks <- .rmbl_chunk_bytes(chunks)
  scheme <- .rmbl_merkle_scheme(scheme)
  if (length(chunks) == 0L) return(character(0))
  .Call(C_rmbl_merkle_leaves, chunks, scheme)
}

#' @rdname mrk
#' @export
mrkprf <- function(chunks, index, scheme = 2L) {
  chunks <- .rmbl_chunk_bytes(chunks)
  scheme <- .rmbl_merkle_scheme(scheme)
  index <- .rmbl_num(index, "index", integer = TRUE)
  if (length(index) != 1L || is.na(index) || index < 1L ||
      index > length(chunks)) {
    stop("`index` must be between 1 and the number of chunks", call. = FALSE)
  }
  out <- .Call(C_rmbl_merkle_proof, chunks, index, scheme)
  out$scheme <- scheme
  out
}

#' @rdname mrk
#' @export
mrkvrf <- function(leaf, proof, root, scheme = NULL) {
  .rmbl_no_fn(root = root)
  leaf <- .rmbl_chunk_bytes(leaf)
  if (length(leaf) != 1L) {
    stop("`leaf` must be a single chunk", call. = FALSE)
  }
  if (!is.list(proof) || !all(c("sibling", "side") %in% names(proof))) {
    stop("`proof` must be the list returned by mrkprf()", call. = FALSE)
  }
  sib <- as.character(proof$sibling)
  side <- as.character(proof$side)
  if (length(sib) != length(side)) {
    stop("`proof` is malformed: sibling and side differ in length",
         call. = FALSE)
  }
  recorded <- if (is.null(proof[["scheme"]])) NULL else .rmbl_merkle_scheme(proof[["scheme"]])
  if (!is.null(scheme)) {
    scheme <- .rmbl_merkle_scheme(scheme)
    # the caller requires a scheme: a proof built under another one, or
    # with none recorded (0.5.12 and earlier), does not meet it
    if (is.null(recorded) && scheme == 2L) return(FALSE)
    if (!is.null(recorded) && recorded != scheme) return(FALSE)
  } else if (is.null(recorded)) {
    warning(paste0("this Merkle proof records no scheme: it was made by rmoriebricklayer 0.5.12 or ",
                   "earlier and is checked under the weaker scheme 1, which also accepts an interior ",
                   "node as a leaf; pass scheme = 2 to refuse it"), call. = FALSE)
    scheme <- 1L
  } else {
    scheme <- recorded
  }
  # scheme 2 prefixes a leaf with 0x00 and a node with 0x01 (RFC 6962)
  lp <- if (scheme == 2L) as.raw(0L) else raw(0)
  np <- if (scheme == 2L) as.raw(1L) else raw(0)
  node <- csha256(c(lp, leaf[[1L]]))
  for (i in seq_along(sib)) {
    pair <- if (identical(side[i], "right")) {
      paste0(node, sib[i])
    } else {
      paste0(sib[i], node)
    }
    node <- csha256(c(np, .rmbl_hex_to_raw(pair)))
  }
  cdgsteq(node, as.character(root))
}

#' The Merkle hashing scheme: 2 (leaf and node prefixes, 0.5.13 on) or 1
#' (no prefixes, 0.5.12 and earlier).
#' @param scheme The scheme number passed by the user.
#' @return The scheme as an integer, 1 or 2.
#' @noRd
.rmbl_merkle_scheme <- function(scheme) {
  scheme <- .rmbl_num(scheme, "scheme", integer = TRUE)
  if (length(scheme) != 1L || is.na(scheme) || !scheme %in% c(1, 2)) {
    stop("`scheme` must be 1 or 2", call. = FALSE)
  }
  as.integer(scheme)
}

#' Normalise a chunk argument to a list of raw vectors.
#'
#' A chunk is a byte sequence, and the Merkle functions used to take it as
#' a character vector measured with strlen. That forbade a zero byte in a
#' chunk and, worse, silently accepted a raw vector by coercing it -- a
#' list of raw vectors deparses, so `mrkroot(list(charToRaw("a")))`
#' hashed the TEXT "as.raw(0x61)" rather than the byte 0x61, and reported
#' a confident digest of the wrong thing.
#'
#' Byte sequences for character input are unchanged, so a root recorded by
#' an earlier version still verifies: charToRaw() yields exactly the bytes
#' CHAR() gave the C layer.
#' @param chunks A character vector, a raw vector, or a list of raw vectors and single strings.
#' @return A list of raw vectors, one per chunk.
#' @noRd
.rmbl_chunk_bytes <- function(chunks) {
  if (is.raw(chunks)) return(list(chunks))
  if (is.character(chunks)) {
    if (anyNA(chunks)) stop("`chunks` must not contain NA", call. = FALSE)
    return(lapply(chunks, charToRaw))
  }
  if (is.list(chunks)) {
    return(lapply(seq_along(chunks), function(i) {
      e <- chunks[[i]]
      if (is.raw(e)) return(e)
      if (is.character(e) && length(e) == 1L && !is.na(e)) {
        return(charToRaw(e))
      }
      stop(sprintf(
        "chunk %d must be a raw vector or a length-1 string", i),
        call. = FALSE)
    }))
  }
  if (length(chunks) == 0L) return(list())
  stop("`chunks` must be a character vector, a raw vector, or a list of these",
       call. = FALSE)
}

#' Decodes a hex string to raw bytes.
#'
#' Hex string to raw. Merkle nodes hash the concatenated BYTES of the two
#' child digests, not their hex spelling, so the pair has to be decoded
#' before hashing.
#' @param hex A hex string; only its first element is read.
#' @return A raw vector.
#' @noRd
.rmbl_hex_to_raw <- function(hex) {
  hex <- as.character(hex)[1L]
  n <- nchar(hex)
  if (n %% 2L != 0L) stop("hex string has odd length", call. = FALSE)
  if (n == 0L) return(raw(0))
  as.raw(strtoi(substring(hex, seq(1L, n - 1L, by = 2L),
                          seq(2L, n, by = 2L)), base = 16L))
}

#' Split a file into fixed-size chunks
#'
#' Reads a file as bytes and returns it as consecutive chunks of a fixed
#' size, ready for [mrkroot()],
#' [mrklvs()] and
#' [mrkprf()]. Use it to pin a large data file as a
#' Merkle root, so
#' that a later change can be traced to the chunk that moved.
#'
#' @details
#' The file is read sequentially with \code{readBin()} in pieces of
#' \code{chnkbytes}; every chunk has exactly that many bytes except the
#' last, which holds the remainder. All chunks are held in memory at once,
#' so the memory used is about the size of the file. The default 1 MiB
#' chunk is a compromise: smaller chunks localise a change more precisely
#' but make the tree and its proofs larger. An edit that changes the file's
#' length shifts every later chunk boundary, so only edits that keep the
#' length localise to one chunk.
#'
#' Errors: \code{path} that does not name an existing file (or names a
#' directory); \code{chnkbytes} that is not a positive whole number.
#'
#' @param path Path to an existing file, a single string.
#' @param chnkbytes Chunk size in bytes, a positive whole number (default
#'   1048576, i.e. 1 MiB).
#' @return A list of raw vectors, in file order. A zero-length file gives
#'   an empty list. Chunks are returned as bytes rather than strings because
#'   a file is bytes: an R string cannot hold a zero byte, so a character
#'   chunk could not represent an arbitrary binary file at all.
#' @seealso
#' [mrkroot()],
#' [sha512file()]
#' @examples
#' p <- tempfile()
#' writeLines(rep("some capsule content", 50), p)
#'
#' # One small chunk size to show the splitting.
#' ch <- chnkfile(p, chnkbytes = 128)
#' length(ch)
#' lengths(ch)
#'
#' # The chunks pin the file as a Merkle root.
#' mrkroot(ch)
#'
#' # They are the file's bytes, so they concatenate back to it exactly.
#' identical(unlist(ch), readBin(p, "raw", file.size(p)))
#'
#' # Overwriting bytes in place changes exactly one leaf.
#' b <- readBin(p, "raw", file.size(p))
#' b[300] <- as.raw(0x58)
#' q <- tempfile()
#' writeBin(b, q)
#' which(mrklvs(ch) != mrklvs(chnkfile(q, chnkbytes = 128)))
#'
#' # a chunk size must be positive
#' try(chnkfile(p, chnkbytes = 0))
#' unlink(c(p, q))
#' @export
chnkfile <- function(path, chnkbytes = 1048576L) {
  path <- .rmbl_file1(path, "path")
  chnkbytes <- .rmbl_scalar(chnkbytes, "chnkbytes", 1, .Machine$integer.max, integer = TRUE)
  size <- file.info(path)$size
  if (is.na(size) || size == 0) return(list())
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  out <- list()
  repeat {
    bytes <- readBin(con, "raw", n = chnkbytes)
    if (length(bytes) == 0L) break
    out[[length(out) + 1L]] <- bytes
    if (length(bytes) < chnkbytes) break
  }
  out
}

#' SHA-512 and CRC-32 of a file
#'
#' \code{sha512file()} returns the SHA-512 digest of a file's bytes and
#' \code{crc32file()} its CRC-32 checksum. Use the first to pin a data file
#' for the long term and the second as a fast check that a large file
#' arrived intact (it is the checksum zip archives record). The SHA-256
#' counterpart is [sha256file()].
#'
#' @details
#' The file is read in blocks of \code{blkbytes} with \code{readBin()},
#' the blocks are joined into one raw vector, and the digest of that vector
#' is computed with [csha512()] or
#' [ccrc32()]. The whole file is
#' therefore held in memory once: memory use grows with the file size.
#' \code{blkbytes} affects only the reading, never the result. An empty
#' file gives the digest of no bytes (\code{cf83e135...} for SHA-512, 0 for
#' CRC-32).
#'
#' Errors: \code{path} that does not name an existing file (or names a
#' directory); \code{blkbytes} that is not a positive whole number.
#'
#' @param path Path to an existing file, a single string.
#' @param blkbytes Read size in bytes, a positive whole number (default
#'   1048576). Affects speed only, never the result.
#' @return \code{sha512file()}: a length-1 character vector, 128 lowercase hex
#'   characters. \code{crc32file()}: a length-1 numeric (double) checksum
#'   between 0 and \code{2^32 - 1}.
#' @examples
#' p <- tempfile()
#' writeLines("capsule payload", p)
#'
#' sha512file(p)
#' crc32file(p)
#'
#' # The block size is a speed knob and cannot change the digest.
#' identical(sha512file(p, 16), sha512file(p, 1048576))
#'
#' # the same as hashing the bytes directly
#' identical(sha512file(p), csha512(readBin(p, "raw", file.size(p))))
#'
#' # a missing file is an error
#' try(crc32file(file.path(tempdir(), "no-such-file")))
#' unlink(p)
#' @name filedgst
#' @export
sha512file <- function(path, blkbytes = 1048576L) {
  csha512(.rmbl_read_all_raw(path, blkbytes))
}

#' @rdname filedgst
#' @export
crc32file <- function(path, blkbytes = 1048576L) {
  ccrc32(.rmbl_read_all_raw(path, blkbytes))
}

#' Reads a whole file as raw bytes, block by block.
#' @param path The file to read.
#' @param block_bytes The number of bytes read per block.
#' @return A raw vector of the file contents.
#' @noRd
.rmbl_read_all_raw <- function(path, block_bytes = 1048576L) {
  path <- .rmbl_file1(path, "path")
  block_bytes <- .rmbl_scalar(block_bytes, "blkbytes", 1, .Machine$integer.max, integer = TRUE)
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  parts <- list()
  repeat {
    bytes <- readBin(con, "raw", n = block_bytes)
    if (length(bytes) == 0L) break
    parts[[length(parts) + 1L]] <- bytes
    if (length(bytes) < block_bytes) break
  }
  if (length(parts) == 0L) return(raw(0))
  do.call(c, parts)
}
