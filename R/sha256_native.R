# SPDX-License-Identifier: AGPL-3.0-or-later
#
# SHA-256 in pure R (FIPS 180-4), the fallback for a standalone capsule
# bundle where the compiled core (core_sha256) is not loaded. Words are
# doubles in [0, 2^32) with XOR/AND on 16-bit halves. Slow but exact; the
# package itself always routes through core_sha256().

#' @noRd
.rmbl_sha256_raw <- function(bytes) {
  # Words live as DOUBLES in [0, 2^32): R integers are signed 32-bit,
  # so bitwAnd/bitwXor on anything >= 2^31 returns NA and the old code
  # packed NaN bit patterns as the digest. XOR/AND run on 16-bit
  # halves; rotation and addition are exact double arithmetic mod 2^32.
  bx <- function(a, b) {
    bitwXor(a %/% 65536, b %/% 65536) * 65536 +
      bitwXor(a %% 65536, b %% 65536)
  }
  ba <- function(a, b) {
    bitwAnd(a %/% 65536, b %/% 65536) * 65536 +
      bitwAnd(a %% 65536, b %% 65536)
  }
  bn <- function(a) 4294967295 - a
  rotr <- function(x, n) (x %/% 2^n) + (x %% 2^n) * 2^(32 - n)
  shr <- function(x, n) x %/% 2^n
  bs <- as.integer(as.raw(bytes))
  blen <- length(bs) * 8
  bs <- c(bs, 0x80L)
  while (length(bs) %% 64L != 56L) bs <- c(bs, 0x00L)
  bs <- c(bs, (blen %/% 2^c(56, 48, 40, 32, 24, 16, 8, 0)) %% 256)
  H <- c(0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
         0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19)
  K <- c(0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b,
         0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01,
         0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7,
         0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
         0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152,
         0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
         0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
         0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
         0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819,
         0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08,
         0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f,
         0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
         0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2)
  for (block in seq(1L, length(bs), by = 64L)) {
    W <- numeric(64L)
    for (i in 0:15) {
      W[i + 1L] <- sum(bs[block + 4L * i + 0:3] * c(2^24, 2^16, 2^8, 1))
    }
    for (i in 16:63) {
      w15 <- W[i - 15L + 1L]
      w2 <- W[i - 2L + 1L]
      s0 <- bx(bx(rotr(w15, 7), rotr(w15, 18)), shr(w15, 3))
      s1 <- bx(bx(rotr(w2, 17), rotr(w2, 19)), shr(w2, 10))
      W[i + 1L] <- (W[i - 16L + 1L] + s0 + W[i - 7L + 1L] + s1) %% 2^32
    }
    a <- H[1]; b <- H[2]; cc <- H[3]; d <- H[4]
    e <- H[5]; f <- H[6]; g <- H[7]; hh <- H[8]
    for (i in 0:63) {
      S1 <- bx(bx(rotr(e, 6), rotr(e, 11)), rotr(e, 25))
      ch <- bx(ba(e, f), ba(bn(e), g))
      T1 <- (hh + S1 + ch + K[i + 1L] + W[i + 1L]) %% 2^32
      S0 <- bx(bx(rotr(a, 2), rotr(a, 13)), rotr(a, 22))
      mj <- bx(bx(ba(a, b), ba(a, cc)), ba(b, cc))
      T2 <- (S0 + mj) %% 2^32
      hh <- g; g <- f; f <- e
      e <- (d + T1) %% 2^32
      d <- cc; cc <- b; b <- a
      a <- (T1 + T2) %% 2^32
    }
    H[1] <- (H[1] + a) %% 2^32
    H[2] <- (H[2] + b) %% 2^32
    H[3] <- (H[3] + cc) %% 2^32
    H[4] <- (H[4] + d) %% 2^32
    H[5] <- (H[5] + e) %% 2^32
    H[6] <- (H[6] + f) %% 2^32
    H[7] <- (H[7] + g) %% 2^32
    H[8] <- (H[8] + hh) %% 2^32
  }
  as.raw(as.vector(vapply(H, function(w)
    (w %/% 2^c(24, 16, 8, 0)) %% 256, numeric(4))))
}

#' @noRd
.rmbl_hexlify <- function(bs) {
  paste(format(as.hexmode(as.integer(bs)), width = 2L), collapse = "")
}

#' @noRd
.rmbl_sha256_hex <- function(bytes) .rmbl_hexlify(.rmbl_sha256_raw(bytes))
