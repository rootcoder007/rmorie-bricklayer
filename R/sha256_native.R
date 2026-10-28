# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SHA-256 in pure R (FIPS 180-4), the fallback for a standalone capsule
# bundle where the compiled core (csha256) is not loaded. Words are
# doubles in [0, 2^32) with XOR/AND on 16-bit halves. Slow but exact; the
# package itself always routes through csha256().

#' Computes the SHA-256 digest of a byte vector in pure R.
#' @param bytes The bytes to digest.
#' @return The 32-byte digest as a raw vector.
#' @noRd
.rmbl_sha256_raw <- function(bytes) {
  # Words live as DOUBLES in [0, 2^32): R integers are signed 32-bit,
  # so bitwAnd/bitwXor on anything >= 2^31 returns NA and the old code
  # packed NaN bit patterns as the digest. XOR/AND run on 16-bit
  # halves; rotation and addition are exact double arithmetic mod 2^32.
  bs <- .rmbl_sha256_pad(bytes)
  H <- .rmbl_sha256_blocks(.rmbl_sha256_h0(), bs, .rmbl_sha256_k())
  .rmbl_sha256_out(H)
}

#' The SHA-256 initial hash state.
#' @return Eight words, as doubles.
#' @noRd
.rmbl_sha256_h0 <- function() {
  c(
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19
  )
}

#' Runs whole 64-byte blocks through the compression.
#' @param H The state words.
#' @param bs Bytes as integers, a multiple of 64 long.
#' @param K The round constants.
#' @return The new state words.
#' @noRd
.rmbl_sha256_blocks <- function(H, bs, K) {
  for (block in seq(1L, length(bs), by = 64L)) {
    W <- .rmbl_sha256_schedule(bs, block)
    H <- .rmbl_sha256_compress(H, W, K)
  }
  H
}

#' The digest bytes of a final state.
#' @param H The state words.
#' @return 32 raw bytes.
#' @noRd
.rmbl_sha256_out <- function(H) {
  as.raw(as.vector(vapply(
    H,
    function(w) {
      (w %/% 2^c(24, 16, 8, 0)) %% 256
    },
    numeric(4)
  )))
}

#' The SHA-256 digest of a file in pure R, read `chunk` bytes at a time,
#' so memory stays at one chunk whatever the file's size.
#' @param path The file.
#' @param chunk Bytes read at a time.
#' @return 64 lower-case hex digits.
#' @noRd
.rmbl_sha256_file <- function(path, chunk = 1048576L) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)
  H <- .rmbl_sha256_h0()
  K <- .rmbl_sha256_k()
  carry <- integer()
  total <- 0
  repeat {
    b <- readBin(con, "raw", n = chunk)
    if (!length(b)) break
    total <- total + length(b)
    bs <- c(carry, as.integer(b))
    full <- length(bs) %/% 64L * 64L
    if (full > 0L) {
      H <- .rmbl_sha256_blocks(H, bs[seq_len(full)], K)
    }
    carry <- bs[seq_len(length(bs) - full) + full]
  }
  blen <- total * 8
  pad <- c(carry, 0x80L, integer((55L - length(carry)) %% 64L))
  tail <- c(pad, (blen %/% 2^c(56, 48, 40, 32, 24, 16, 8, 0)) %% 256)
  .rmbl_hexlify(.rmbl_sha256_out(.rmbl_sha256_blocks(H, tail, K)))
}

#' XOR of two 32-bit words held as doubles, on 16-bit halves.
#' @param a,b Words in [0, 2^32).
#' @return The word a XOR b.
#' @noRd
.rmbl_sha256_bx <- function(a, b) {
  bitwXor(a %/% 65536, b %/% 65536) * 65536 + bitwXor(a %% 65536, b %% 65536)
}

#' AND of two 32-bit words held as doubles, on 16-bit halves.
#' @param a,b Words in [0, 2^32).
#' @return The word a AND b.
#' @noRd
.rmbl_sha256_ba <- function(a, b) {
  bitwAnd(a %/% 65536, b %/% 65536) * 65536 + bitwAnd(a %% 65536, b %% 65536)
}

#' Right rotation of a 32-bit word held as a double.
#' @param x A word in [0, 2^32).
#' @param n The number of bits, 1 to 31.
#' @return The rotated word.
#' @noRd
.rmbl_sha256_rotr <- function(x, n) (x %/% 2^n) + (x %% 2^n) * 2^(32 - n)

#' Pads a message for SHA-256: a one bit, zeros, and the bit length.
#' @param bytes The message bytes.
#' @return The padded message as integers in \[0, 255\], a multiple of 64 long.
#' @noRd
.rmbl_sha256_pad <- function(bytes) {
  bs <- as.integer(as.raw(bytes))
  blen <- length(bs) * 8
  bs <- c(bs, 0x80L)
  while (length(bs) %% 64L != 56L) {
    bs <- c(bs, 0x00L)
  }
  c(bs, (blen %/% 2^c(56, 48, 40, 32, 24, 16, 8, 0)) %% 256)
}

#' The SHA-256 message schedule of one 64-byte block.
#' @param bs The padded message.
#' @param block The index of the block's first byte.
#' @return The 64 schedule words, as doubles.
#' @noRd
.rmbl_sha256_schedule <- function(bs, block) {
  bx <- .rmbl_sha256_bx
  rotr <- .rmbl_sha256_rotr
  W <- numeric(64L)
  for (i in 0:15) {
    W[i + 1L] <- sum(bs[block + 4L * i + 0:3] * c(2^24, 2^16, 2^8, 1))
  }
  for (i in 16:63) {
    w15 <- W[i - 15L + 1L]
    w2 <- W[i - 2L + 1L]
    s0 <- bx(bx(rotr(w15, 7), rotr(w15, 18)), w15 %/% 2^3)
    s1 <- bx(bx(rotr(w2, 17), rotr(w2, 19)), w2 %/% 2^10)
    W[i + 1L] <- (W[i - 16L + 1L] + s0 + W[i - 7L + 1L] + s1) %% 2^32
  }
  W
}

#' The SHA-256 compression of one block into the hash state.
#' @param H The eight state words.
#' @param W The block's 64 schedule words.
#' @param K The 64 round constants.
#' @return The new state words.
#' @noRd
.rmbl_sha256_compress <- function(H, W, K) {
  bx <- .rmbl_sha256_bx
  ba <- .rmbl_sha256_ba
  rotr <- .rmbl_sha256_rotr
  a <- H[1]
  b <- H[2]
  cc <- H[3]
  d <- H[4]
  e <- H[5]
  f <- H[6]
  g <- H[7]
  hh <- H[8]
  for (i in 0:63) {
    S1 <- bx(bx(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
    ch <- bx(ba(e, f), ba(4294967295 - e, g))
    T1 <- (hh + S1 + ch + K[i + 1L] + W[i + 1L]) %% 2^32
    S0 <- bx(bx(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
    mj <- bx(bx(ba(a, b), ba(a, cc)), ba(b, cc))
    T2 <- (S0 + mj) %% 2^32
    hh <- g
    g <- f
    f <- e
    e <- (d + T1) %% 2^32
    d <- cc
    cc <- b
    b <- a
    a <- (T1 + T2) %% 2^32
  }
  (H + c(a, b, cc, d, e, f, g, hh)) %% 2^32
}

#' The 64 SHA-256 round constants (FIPS 180-4, 4.2.2).
#' @return A double vector of 64 words.
#' @noRd
.rmbl_sha256_k <- function() {
  c(.rmbl_sha256_k1(), .rmbl_sha256_k2())
}

#' Round constants 1 to 32 of SHA-256.
#' @return A double vector of 32 words.
#' @noRd
.rmbl_sha256_k1 <- function() {
  c(
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967
  )
}

#' Round constants 33 to 64 of SHA-256.
#' @return A double vector of 32 words.
#' @noRd
.rmbl_sha256_k2 <- function() {
  c(
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2
  )
}

#' Writes bytes as lower-case hex text.
#' @param bs The bytes.
#' @return One string, two hex digits per byte.
#' @noRd
.rmbl_hexlify <- function(bs) {
  paste(format(as.hexmode(as.integer(bs)), width = 2L), collapse = "")
}

#' Computes the SHA-256 digest of a byte vector in pure R as hex text.
#' @param bytes The bytes to digest.
#' @return The digest as 64 hex digits.
#' @noRd
.rmbl_sha256_hex <- function(bytes) .rmbl_hexlify(.rmbl_sha256_raw(bytes))
