# HQC-KEM (specification 2025-08-22, reference implementation v5.0.0).
#
# Anchored on the authors' official known-answer vectors: for each, the KAT
# randomness SHAKE256(seed || 0x00) is re-derived here and fed to the PUBLIC
# API (key seed, then message and salt), and the SHA-256 of
# pk || sk || ct || ss is compared with the one computed from the .rsp files.
# Matching all of them pins every part of the scheme: the seed expansion and
# hash domains, both samplers (including the reference's 8-byte squeeze
# rounding), the GF(2)[x] product, the Reed-Solomon and Reed-Muller codes and
# the byte layouts. Decapsulating each ciphertext back to its ss pins the
# decoder on real noise; the self-test below drives it to its capacity.

hqc_kat <- function() {
  lines <- readLines(test_path("hqc-kat-digests.txt"), warn = FALSE)
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)][-1L]
  parts <- strsplit(lines, " ", fixed = TRUE)
  data.frame(level = as.integer(vapply(parts, `[[`, "", 1L)),
             count = as.integer(vapply(parts, `[[`, "", 2L)),
             seed = vapply(parts, `[[`, "", 3L),
             digest = vapply(parts, `[[`, "", 4L),
             stringsAsFactors = FALSE)
}

hex_raw <- function(h) {
  as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))
}

run_kat <- function(row) {
  k <- hqc_sizes(row$level)[["message"]]
  stream <- .Call(C_rmbl_shake, 256L, c(hex_raw(row$seed), as.raw(0L)),
                  32L + k + 16L)
  key <- hqc_keygen(row$level, seed = stream[1:32])
  cap <- hqc_encapsulate(hqc_public_key(key), m = stream[33:(32 + k)],
                         salt = stream[(33 + k):(48 + k)])
  ss <- hqc_decapsulate(key, cap$ciphertext)
  all <- hex_raw(paste0(key$public, key$secret, cap$ciphertext, cap$shared))
  c(digest = core_sha256(all), decaps = identical(ss, cap$shared))
}

# The sizes of the specification's table 6, hard-coded so a change to a
# parameter fails here rather than being blessed.
HQC_SIZES <- list(
  "1" = c(2241L, 2321L, 4433L, 32L, 16L, 16L, 32L),
  "3" = c(4514L, 4602L, 8978L, 32L, 24L, 16L, 32L),
  "5" = c(7237L, 7333L, 14421L, 32L, 32L, 16L, 32L)
)

test_that("the byte lengths are the ones the specification fixes", {
  for (lv in names(HQC_SIZES)) {
    sz <- hqc_sizes(as.integer(lv))
    expect_identical(unname(sz), HQC_SIZES[[lv]])
    expect_identical(names(sz), c("encapsulation_key", "decapsulation_key",
                                  "ciphertext", "seed", "message", "salt",
                                  "shared_secret"))
  }
  # the security in bits names the same three sets
  expect_identical(hqc_sizes(128), hqc_sizes(1))
  expect_identical(hqc_sizes(192), hqc_sizes(3))
  expect_identical(hqc_sizes(256), hqc_sizes(5))
})

test_that("the official known-answer vectors are reproduced (both multipliers)", {
  kat <- hqc_kat()
  expect_identical(nrow(kat), 300L)
  # CRAN gets the first five vectors of each set; CI runs all 300
  if (!identical(Sys.getenv("NOT_CRAN"), "true")) kat <- kat[kat$count < 5L, ]
  on.exit(.rmbl_hqc_backend(FALSE), add = TRUE)
  for (portable in c(FALSE, TRUE)) {
    .rmbl_hqc_backend(portable)
    for (i in seq_len(nrow(kat))) {
      got <- run_kat(kat[i, ])
      expect_identical(got[["digest"]], kat$digest[i],
                       label = sprintf("HQC-%d vector %d (%s)", kat$level[i],
                                       kat$count[i],
                                       .rmbl_hqc_backend()))
      expect_identical(got[["decaps"]], "TRUE")
    }
  }
})

test_that("the multiplier in use is reported and can be forced portable", {
  on.exit(.rmbl_hqc_backend(FALSE), add = TRUE)
  expect_true(.rmbl_hqc_backend() %in% c("pclmul", "pmull", "portable"))
  expect_identical(.rmbl_hqc_backend(TRUE), "portable")
  expect_true(.rmbl_hqc_backend(FALSE) %in% c("pclmul", "pmull", "portable"))
})

test_that("the decoder corrects up to its capacity (deterministic self-test)", {
  on.exit(.rmbl_hqc_backend(FALSE), add = TRUE)
  for (lv in c(1L, 3L, 5L)) {
    seed <- .Call(C_rmbl_shake, 256L, charToRaw(sprintf("hqc selftest %d", lv)), 32L)
    expect_identical(.Call(C_rmbl_hqc_selftest, lv, 60L, seed), 0L)
  }
  expect_error(.Call(C_rmbl_hqc_selftest, 1L, -1L, as.raw(1:32)), "non-negative")
  expect_error(.Call(C_rmbl_hqc_selftest, 1L, 1L, as.raw(1:3)), "32 bytes")
})

test_that("a round trip agrees at every level and fresh randomness differs", {
  for (lv in c(1L, 3L, 5L)) {
    key <- hqc_keygen(lv)
    expect_s3_class(key, "bricklayer_hqc_key")
    expect_identical(nchar(key$public), 2L * hqc_sizes(lv)[["encapsulation_key"]])
    a <- hqc_encapsulate(hqc_public_key(key))
    b <- hqc_encapsulate(key)
    expect_identical(hqc_decapsulate(key, a$ciphertext), a$shared)
    expect_identical(hqc_decapsulate(key, hex_raw(b$ciphertext)), b$shared)
    expect_false(identical(a$shared, b$shared))
    expect_false(identical(hqc_keygen(lv)$public, key$public))
  }
})

test_that("a tampered ciphertext yields exactly J(H(ek) || sigma || c)", {
  key <- hqc_keygen(1L, seed = as.raw(1:32))
  sz <- hqc_sizes(1L)
  cap <- hqc_encapsulate(key, m = as.raw(1:16), salt = as.raw(16:1))
  dk <- hex_raw(key$secret)
  ek <- hex_raw(key$public)
  sigma <- dk[(sz[["encapsulation_key"]] + 33L):(sz[["encapsulation_key"]] + 32L + 16L)]
  hek <- .Call(C_rmbl_shake, 3256L, c(ek, as.raw(1L)), 32L)
  ct <- hex_raw(cap$ciphertext)
  # one bit in u, one in v, one in the salt
  for (pos in c(10L, 3000L, length(ct) - 2L)) {
    bad <- ct
    bad[pos] <- xor(bad[pos], as.raw(4L))
    kbar <- .Call(C_rmbl_shake, 3256L, c(hek, sigma, bad, as.raw(3L)), 32L)
    got <- hqc_decapsulate(key, bad)
    expect_identical(got, paste(format(as.hexmode(as.integer(kbar)), width = 2L), collapse = ""))
    expect_false(identical(got, cap$shared))
  }
})

test_that("malformed keys, sizes and levels are refused with a reason", {
  key <- hqc_keygen(1L, seed = as.raw(1:32))
  sz <- hqc_sizes(1L)
  expect_error(hqc_keygen(2L), "1, 3 or 5")
  expect_error(hqc_keygen("x"), "1, 3 or 5")
  expect_error(hqc_sizes(512), "1, 3 or 5")
  expect_error(hqc_keygen(1L, seed = as.raw(1:31)), "32 bytes")
  expect_error(hqc_keygen(1L, seed = 1:32), "32 bytes")
  expect_error(hqc_public_key(list()), "hqc_keygen")
  expect_error(hqc_encapsulate(kem_keygen(512)), "hqc_keygen")
  expect_error(hqc_encapsulate(key, m = as.raw(1:15)), "16 bytes for HQC-1")
  expect_error(hqc_encapsulate(key, salt = as.raw(1:15)), "16 bytes")
  expect_error(hqc_decapsulate(hqc_public_key(key), "00"), "secret half")
  expect_error(hqc_decapsulate(key, "00"), "4433 bytes for HQC-1")
  expect_error(hqc_decapsulate(key, "zz"), "4433 bytes")
  # a public key with a bit set past the code length
  pub <- hqc_public_key(key)
  substring(pub$public, nchar(pub$public) - 1L) <- "ff"
  expect_error(hqc_encapsulate(pub), "malformed")
  short <- pub
  short$public <- substring(short$public, 3L)
  expect_error(hqc_encapsulate(short), "no usable HQC-1 public key")
  # a decapsulation key whose seeds were damaged
  cap <- hqc_encapsulate(key)
  for (off in c(5L, sz[["encapsulation_key"]] + 3L, sz[["encapsulation_key"]] + 40L,
                sz[["decapsulation_key"]] - 1L)) {
    bad <- key
    b <- hex_raw(bad$secret)
    b[off] <- xor(b[off], as.raw(1L))
    bad$secret <- paste(format(as.hexmode(as.integer(b)), width = 2L), collapse = "")
    expect_error(hqc_decapsulate(bad, cap$ciphertext), "corrupt", label = sprintf("byte %d", off))
  }
  nosec <- key
  nosec$secret <- "abc"
  expect_error(hqc_decapsulate(nosec, cap$ciphertext), "no usable HQC-1 secret key")
  # the C layer refuses wrong lengths and levels on its own
  expect_error(.Call(C_rmbl_hqc_keygen, 2L, as.raw(1:32)), "1, 3 or 5")
  expect_error(.Call(C_rmbl_hqc_keygen, 1.0, as.raw(1:32)), "single integer")
  expect_error(.Call(C_rmbl_hqc_encaps, 1L, as.raw(1:3), as.raw(1:16), as.raw(1:16)), "2241 bytes")
  expect_error(.Call(C_rmbl_hqc_decaps, 3L, as.raw(1:3), as.raw(1:3)), "4602 bytes")
})

test_that("keys and capsules print without revealing the secret", {
  key <- hqc_keygen(5L, seed = as.raw(32:1))
  out <- format(key)
  expect_true(any(grepl("HQC-5", out)))
  expect_true(any(grepl("<withheld>", out)))
  expect_false(any(grepl(substring(key$secret, 4500L, 4540L), out, fixed = TRUE)))
  expect_output(print(key), "code-based")
  expect_output(print(hqc_public_key(key)), "Public encapsulation key")
  cap <- hqc_encapsulate(key)
  expect_output(print(cap), "Encapsulated shared secret")
  expect_false(any(grepl(cap$shared, format(cap), fixed = TRUE)))
})
