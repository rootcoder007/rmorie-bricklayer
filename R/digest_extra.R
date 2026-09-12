# SPDX-License-Identifier: AGPL-3.0-or-later
#
# Provenance digests beyond the SHA-256 the package already shipped:
# SHA-512, HMAC-SHA-256 (so a manifest can be SIGNED, not merely
# checksummed), CRC-32 (cheap integrity for very large members), and a
# Merkle tree over file chunks (so a mismatch names WHICH chunk moved).

#' SHA-512 hex digest (C backend)
#'
#' Hashes character or raw input with the self-contained SHA-512 (FIPS
#' 180-4) in the compiled core. Use it over
#' [core_sha256()] when a pin has to outlive the
#' capsule by decades: the wider digest leaves more margin, including
#' against a quantum adversary, for whom Grover's algorithm halves the
#' effective preimage exponent.
#'
#' @param x A character vector or a raw vector.
#' @return A character vector of 128-character lowercase hex digests (one
#' per element for character input; length-1 for raw input).
#' @seealso
#' [core_sha256()],
#' [core_crc32()],
#' [sha512_file()]
#' @examples
#' # FIPS 180-4 test vector for "abc".
#' core_sha512("abc")
#'
#' # Vectorised over character input.
#' core_sha512(c("abc", "def"))
#'
#' # Raw input hashes the bytes directly, and agrees with the character
#' # form for the same bytes.
#' identical(core_sha512("abc"), core_sha512(charToRaw("abc")))
#'
#' # Twice the digest width of SHA-256.
#' c(sha256 = nchar(core_sha256("abc")), sha512 = nchar(core_sha512("abc")))
#' @export
core_sha512 <- function(x) {
  if (is.raw(x)) return(.Call(C_rmbl_sha512, x))
  .Call(C_rmbl_sha512, as.character(x))
}

#' CRC-32 checksum (C backend)
#'
#' The CRC-32 of ITU V.42 and zip (reflected polynomial `0xEDB88320`)
#' .
#'
#' A CRC is NOT a cryptographic digest: it detects accidental corruption
#' -- a truncated download, a flipped bit on disk -- but anyone can
#' construct a different input with the same value, so it must never be
#' used where [core_sha256()] is meant. It is
#' here because it is far cheaper than SHA-256 over gigabyte-scale capsule
#' members, which makes it the right first pass when the question is only
#' "did this file arrive intact".
#'
#' @param x A character vector or a raw vector.
#' @return A numeric vector of unsigned 32-bit checksums (one per element
#' for character input; length-1 for raw input). Returned as `double`
#' rather than `integer` because values above `2^31 - 1` are not
#' representable as an R integer.
#' @seealso [core_sha256()] for integrity against
#' tampering rather than accident.
#' @examples
#' # The standard check value: CRC-32("123456789") is 0xCBF43926.
#' core_crc32("123456789")
#' core_crc32("123456789") == 0xCBF43926
#'
#' # The empty input has checksum zero.
#' core_crc32("")
#'
#' # Vectorised, and sensitive to a single changed byte.
#' core_crc32(c("brick", "brack"))
#'
#' # Raw bytes work the same way.
#' core_crc32(charToRaw("123456789"))
#' @export
core_crc32 <- function(x) {
  if (is.raw(x)) return(.Call(C_rmbl_crc32, x))
  .Call(C_rmbl_crc32, as.character(x))
}

#' Keyed digest and constant-time comparison (C backend)
#'
#' `core_hmac_sha256()` is HMAC-SHA-256 (RFC 2104): a digest computed
#' under a secret key. The difference from a plain
#' [core_sha256()] is AUTHENTICATION -- anyone
#' can recompute a SHA-256 and so anyone can forge one after editing a
#' manifest, but only a holder of the key can produce a matching HMAC. This
#' is what makes [capsule_sign()] 's
#' `"hmac"` scheme meaningful.
#'
#' `core_digest_equal()` compares two digests in constant time. Use it
#' instead of `==` whenever the comparison is against a value an
#' attacker supplied: a short-circuiting comparison leaks, through its own
#' timing, how many leading characters were correct, which is enough to
#' recover a tag byte by byte.
#'
#' @param key Secret key, as a length-1 character vector or a
#' raw vector. Keys longer than the 64-byte block are hashed down first,
#' per RFC 2104. Use at least 32 bytes of real entropy; against a quantum
#' adversary Grover halves the effective key strength, so a 256-bit key
#' retains a 128-bit margin.
#' @param message Message to authenticate, as a length-1
#' character vector or a raw vector.
#' @param a,b Digests to compare, as length-1 character vectors.
#' @return `core_hmac_sha256()` a length-1 character vector: 64
#' lowercase hex characters. `core_digest_equal()` a length-1 logical;
#' `FALSE` when the two differ in length.
#' @references Krawczyk H, Bellare M, Canetti R (1997). HMAC: Keyed-Hashing
#' for Message Authentication. RFC 2104.
#'   \doi{10.17487/RFC2104}
#' @examples
#' # RFC 4231 test case 2.
#' core_hmac_sha256("Jefe", "what do ya want for nothing?")
#'
#' # The key changes the digest, so a manifest cannot be re-signed
#' # without it.
#' core_hmac_sha256("key-a", "manifest")
#' core_hmac_sha256("key-b", "manifest")
#'
#' # Raw keys and messages are accepted.
#' core_hmac_sha256(as.raw(rep(0x0b, 20)), "Hi There")
#'
#' # Compare tags in constant time, never with ==.
#' tag <- core_hmac_sha256("k", "m")
#' core_digest_equal(tag, core_hmac_sha256("k", "m"))
#' core_digest_equal(tag, core_hmac_sha256("k", "tampered"))
#' core_digest_equal(tag, "too-short")
#' @name rmbl_keyed_digest
#' @export
core_hmac_sha256 <- function(key, message) {
  if (!is.raw(key)) {
    key <- as.character(key)
    if (length(key) != 1L || is.na(key)) {
      stop("`key` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  if (!is.raw(message)) {
    message <- as.character(message)
    if (length(message) != 1L || is.na(message)) {
      stop("`message` must be a length-1 character vector or a raw vector",
           call. = FALSE)
    }
  }
  .Call(C_rmbl_hmac_sha256, key, message)
}

#' @rdname rmbl_keyed_digest
#' @export
core_digest_equal <- function(a, b) {
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
#' belongs to the pinned file without re-reading the rest of it.
#'
#' `merkle_root()` reduces the chunks to one root digest.
#' `merkle_leaves()` returns the per-chunk digests the root is built
#' from, so two capsules can be diffed chunk by chunk.
#' `merkle_proof()` returns the sibling digests on the path from one
#' leaf to the root, and `merkle_verify()` replays that path.
#'
#' An unpaired node at an odd level is PROMOTED unchanged rather than
#' hashed against a duplicate of itself. Duplicating it would let two
#' different chunk lists produce the same root -- the weakness behind
#' CVE-2012-2459 -- so promotion is a correctness requirement, not a
#' preference.
#'
#' @param chunks Character vector of chunk contents, in
#' order. Use [chunk_file()] to produce it from a
#' file.
#' @param index 1-based index of the chunk to prove.
#' @param leaf The chunk whose membership is being verified.
#' @param proof The list returned by `merkle_proof()`.
#' @param root The expected root digest.
#' @return `merkle_root()` a length-1 character vector (64 hex
#' characters), or `NA` for no chunks. `merkle_leaves()` a
#' character vector of per-chunk digests. `merkle_proof()` a list with
#' `sibling` (character) and `side` ( `"left"` /
#' `"right"`) . `merkle_verify()` a length-1 logical.
#' @examples
#' chunks <- c("row1,row2", "row3,row4", "row5,row6", "row7,row8")
#'
#' root <- merkle_root(chunks)
#' root
#'
#' # A single chunk's root is just its own digest.
#' merkle_root("only") == core_sha256("only")
#'
#' # The leaves are the per-chunk digests, so a diff names the culprit.
#' before <- merkle_leaves(chunks)
#' after <- merkle_leaves(c(chunks[1:2], "row5,row6-EDITED", chunks[4]))
#' which(before != after)
#'
#' # Prove chunk 3 belongs, without holding chunks 1, 2 or 4.
#' pr <- merkle_proof(chunks, 3)
#' pr
#' merkle_verify(chunks[3], pr, root)
#'
#' # The proof fails for a chunk that was not in the tree.
#' merkle_verify("row5,row6-EDITED", pr, root)
#'
#' # Any change to any chunk changes the root.
#' merkle_root(chunks) == merkle_root(c(chunks[1:3], "row7,row8 "))
#' @name rmbl_merkle
#' @export
merkle_root <- function(chunks) {
  chunks <- .rmbl_chunk_bytes(chunks)
  if (length(chunks) == 0L) return(NA_character_)
  .Call(C_rmbl_merkle_root, chunks)
}

#' @rdname rmbl_merkle
#' @export
merkle_leaves <- function(chunks) {
  chunks <- .rmbl_chunk_bytes(chunks)
  if (length(chunks) == 0L) return(character(0))
  .Call(C_rmbl_merkle_leaves, chunks)
}

#' @rdname rmbl_merkle
#' @export
merkle_proof <- function(chunks, index) {
  chunks <- .rmbl_chunk_bytes(chunks)
  index <- as.integer(index)
  if (length(index) != 1L || is.na(index) || index < 1L ||
      index > length(chunks)) {
    stop("`index` must be between 1 and the number of chunks", call. = FALSE)
  }
  .Call(C_rmbl_merkle_proof, chunks, index)
}

#' @rdname rmbl_merkle
#' @export
merkle_verify <- function(leaf, proof, root) {
  leaf <- .rmbl_chunk_bytes(leaf)
  if (length(leaf) != 1L) {
    stop("`leaf` must be a single chunk", call. = FALSE)
  }
  if (!is.list(proof) || !all(c("sibling", "side") %in% names(proof))) {
    stop("`proof` must be the list returned by merkle_proof()", call. = FALSE)
  }
  node <- core_sha256(leaf[[1L]])
  sib <- as.character(proof$sibling)
  side <- as.character(proof$side)
  if (length(sib) != length(side)) {
    stop("`proof` is malformed: sibling and side differ in length",
         call. = FALSE)
  }
  for (i in seq_along(sib)) {
    pair <- if (identical(side[i], "right")) {
      paste0(node, sib[i])
    } else {
      paste0(sib[i], node)
    }
    node <- core_sha256(.rmbl_hex_to_raw(pair))
  }
  core_digest_equal(node, as.character(root))
}

# Normalise a chunk argument to a list of raw vectors.
#
# A chunk is a byte sequence, and the Merkle functions used to take it as
# a character vector measured with strlen. That forbade a zero byte in a
# chunk and, worse, silently accepted a raw vector by coercing it -- a
# list of raw vectors deparses, so `merkle_root(list(charToRaw("a")))`
# hashed the TEXT "as.raw(0x61)" rather than the byte 0x61, and reported
# a confident digest of the wrong thing.
#
# Byte sequences for character input are unchanged, so a root recorded by
# an earlier version still verifies: charToRaw() yields exactly the bytes
# CHAR() gave the C layer.
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

# Hex string to raw. Merkle nodes hash the concatenated BYTES of the two
# child digests, not their hex spelling, so the pair has to be decoded
# before hashing.
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
#' Reads `path` as bytes and returns them as chunk strings suitable
#' for [merkle_root()] and friends. The default 1
#' MiB chunk is a compromise: smaller chunks localise a change more
#' precisely but make the tree and its proofs larger.
#'
#' @param path Path to an existing file.
#' @param chunk_bytes Chunk size in bytes (default
#' 1048576, i.e. 1 MiB).
#' @return A list of raw vectors, in file order. A zero-length file gives
#' an empty list. Chunks are returned as bytes rather than strings because
#' a file is bytes: an R string cannot hold a zero byte, so a character
#' chunk could not represent an arbitrary binary file at all.
#' @seealso
#' [merkle_root()],
#' [sha512_file()]
#' @examples
#' p <- tempfile()
#' writeLines(rep("some capsule content", 50), p)
#'
#' # One small chunk size to show the splitting.
#' ch <- chunk_file(p, chunk_bytes = 128)
#' length(ch)
#'
#' # The chunks reconstruct the file and pin it as a Merkle root.
#' merkle_root(ch)
#'
#' # They are the file's bytes, so they concatenate back to it exactly.
#' identical(unlist(ch), readBin(p, "raw", file.size(p)))
#'
#' # Editing the file changes exactly one leaf.
#' unlink(p)
#' @export
chunk_file <- function(path, chunk_bytes = 1048576L) {
  path <- as.character(path)[1L]
  if (!file.exists(path)) {
    stop(sprintf("no such file: %s", path), call. = FALSE)
  }
  chunk_bytes <- as.integer(chunk_bytes)
  if (is.na(chunk_bytes) || chunk_bytes < 1L) {
    stop("`chunk_bytes` must be a positive integer", call. = FALSE)
  }
  size <- file.info(path)$size
  if (is.na(size) || size == 0) return(list())
  con <- file(path, "rb")
  on.exit(close(con), add = TRUE)
  out <- list()
  repeat {
    bytes <- readBin(con, "raw", n = chunk_bytes)
    if (length(bytes) == 0L) break
    out[[length(out) + 1L]] <- bytes
    if (length(bytes) < chunk_bytes) break
  }
  out
}

#' SHA-512 and CRC-32 of a file
#'
#' Streams the file in blocks, so memory use does not grow with the file.
#' The SHA-256 counterpart is [sha256_file()].
#'
#' @param path Path to an existing file.
#' @param block_bytes Read size in bytes (default
#' 1048576). Affects speed only, never the result.
#' @return A length-1 character vector ( `sha512_file()`) or numeric (
#' `crc32_file()`) .
#' @examples
#' p <- tempfile()
#' writeLines("capsule payload", p)
#'
#' sha512_file(p)
#' crc32_file(p)
#'
#' # The block size is a speed knob and cannot change the digest.
#' identical(sha512_file(p, 16), sha512_file(p, 1048576))
#'
#' unlink(p)
#' @name rmbl_file_digest
#' @export
sha512_file <- function(path, block_bytes = 1048576L) {
  core_sha512(.rmbl_read_all_raw(path, block_bytes))
}

#' @rdname rmbl_file_digest
#' @export
crc32_file <- function(path, block_bytes = 1048576L) {
  core_crc32(.rmbl_read_all_raw(path, block_bytes))
}

.rmbl_read_all_raw <- function(path, block_bytes = 1048576L) {
  path <- as.character(path)[1L]
  if (!file.exists(path)) {
    stop(sprintf("no such file: %s", path), call. = FALSE)
  }
  block_bytes <- as.integer(block_bytes)
  if (is.na(block_bytes) || block_bytes < 1L) {
    stop("`block_bytes` must be a positive integer", call. = FALSE)
  }
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
