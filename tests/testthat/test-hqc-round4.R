# HQC round 4 (the submission of 2023-04-30; liboqs <= 0.12, PQClean), version = "round4".
#
# Anchored on that revision's official known-answer vectors: for each, the KAT randomness
# SHAKE256(seed || 0x01) is re-derived here and fed to the PUBLIC API (sk_seed, sigma, pk_seed for
# the key, then m and salt), and the SHA-256 of pk || sk || ct || ss is compared with the one from
# liboqs 0.12.0's KAT output (which itself matches liboqs' recorded digest of all 300 vectors).

hqc4_kat <- function() {
  lines <- readLines(test_path("hqc4-kat-digests.txt"), warn = FALSE)
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)][-1L]
  parts <- strsplit(lines, " ", fixed = TRUE)
  data.frame(level = as.integer(vapply(parts, `[[`, "", 1L)),
             count = as.integer(vapply(parts, `[[`, "", 2L)),
             seed = vapply(parts, `[[`, "", 3L),
             digest = vapply(parts, `[[`, "", 4L),
             stringsAsFactors = FALSE)
}

hex_raw4 <- function(h) {
  as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))
}

run_kat4 <- function(row) {
  sz <- hqc_sizes(row$level, "round4")
  k <- sz[["message"]]
  n <- sz[["seed"]]
  stream <- .Call(C_rmbl_shake, 256L, c(hex_raw4(row$seed), as.raw(1L)), n + k + 16L)
  key <- hqc_keygen(row$level, seed = stream[seq_len(n)], version = "round4")
  cap <- hqc_encapsulate(hqc_public_key(key), m = stream[n + seq_len(k)], salt = stream[n + k + 1:16])
  ss <- hqc_decapsulate(key, cap$ciphertext)
  all <- hex_raw4(paste0(key$public, key$secret, cap$ciphertext, cap$shared))
  c(digest = core_sha256(all), decaps = identical(ss, cap$shared))
}

test_that("round 4 has its own sizes: 40-byte seeds, a 64-byte secret", {
  want <- list("1" = c(2249L, 2305L, 4433L, 96L, 16L, 16L, 64L),
               "3" = c(4522L, 4586L, 8978L, 104L, 24L, 16L, 64L),
               "5" = c(7245L, 7317L, 14421L, 112L, 32L, 16L, 64L))
  for (lv in names(want)) {
    expect_identical(unname(hqc_sizes(as.integer(lv), "round4")), want[[lv]])
  }
  expect_named(hqc_sizes(1, "round4"), names(hqc_sizes(1)))
  expect_error(hqc_sizes(1, "round3"), "should be one of")
})

test_that("the official round-4 known-answer vectors are reproduced (both multipliers)", {
  kat <- hqc4_kat()
  expect_identical(nrow(kat), 300L)
  expect_identical(as.vector(table(kat$level)), c(100L, 100L, 100L))
  if (!identical(Sys.getenv("NOT_CRAN"), "true")) kat <- kat[kat$count < 5L, ]
  on.exit(.rmbl_hqc_backend(FALSE), add = TRUE)
  for (portable in c(FALSE, TRUE)) {
    .rmbl_hqc_backend(portable)
    for (i in seq_len(nrow(kat))) {
      got <- run_kat4(kat[i, ])
      expect_identical(got[["digest"]], kat$digest[i],
                       label = sprintf("HQC round 4 level %d vector %d (%s)", kat$level[i], kat$count[i],
                                       if (portable) "portable" else "hardware"))
      expect_identical(got[["decaps"]], "TRUE")
    }
  }
})

test_that("a round-4 key encapsulates and decapsulates at every level", {
  for (lv in c(1L, 3L, 5L)) {
    key <- hqc_keygen(lv, version = "round4")
    expect_identical(key$version, "round4")
    pub <- hqc_public_key(key)
    expect_identical(pub$version, "round4")
    a <- hqc_encapsulate(pub)
    expect_identical(a$version, "round4")
    expect_identical(nchar(a$shared), 128L)
    expect_identical(hqc_decapsulate(key, a$ciphertext), a$shared)
    expect_false(identical(hqc_encapsulate(pub)$shared, a$shared))
  }
})

test_that("a tampered round-4 ciphertext yields exactly K(sigma || u || v)", {
  key <- hqc_keygen(1, seed = as.raw(seq_len(96) %% 256), version = "round4")
  cap <- hqc_encapsulate(key, m = as.raw(1:16), salt = as.raw(17:32))
  ct <- hex_raw4(cap$ciphertext)
  ct[5] <- xor(ct[5], as.raw(1L))
  sigma <- hex_raw4(key$secret)[40 + 1:16]
  uv <- ct[seq_len(length(ct) - 16L)]
  want <- .Call(C_rmbl_shake, 256L, c(sigma, uv, as.raw(4L)), 64L)
  expect_identical(hqc_decapsulate(key, ct), paste(format(want), collapse = ""))
})

test_that("round-4 and v5 keys do not mix, and a corrupt round-4 key is refused", {
  k4 <- hqc_keygen(1, version = "round4")
  k5 <- hqc_keygen(1)
  expect_identical(k5$version, "v5")
  cap5 <- hqc_encapsulate(k5)
  # the same ciphertext length, so the version on the key is what decides
  expect_false(identical(hqc_decapsulate(k4, cap5$ciphertext), cap5$shared))
  expect_error(hqc_keygen(1, seed = as.raw(1:32), version = "round4"), "96 bytes")
  bad <- k4
  sk <- hex_raw4(bad$secret)
  sk[length(sk)] <- xor(sk[length(sk)], as.raw(0x10))
  bad$secret <- paste(format(sk), collapse = "")
  expect_error(hqc_decapsulate(bad, hqc_encapsulate(k4)$ciphertext), "corrupt")
  pub <- hqc_public_key(k4)
  ek <- hex_raw4(pub$public)
  ek[length(ek)] <- as.raw(0xff)
  pub$public <- paste(format(ek), collapse = "")
  expect_error(hqc_encapsulate(pub), "malformed")
  odd <- k4
  odd$version <- "round9"
  expect_error(hqc_encapsulate(odd), "v5")
  # a key object from before the version field is a v5 key
  old <- k5
  old$version <- NULL
  expect_identical(hqc_decapsulate(old, cap5$ciphertext), cap5$shared)
})

test_that("a level must be one whole number", {
  expect_error(hqc_keygen(c(1, 3)), "one of 1, 3 or 5")
  expect_error(hqc_sizes(3.5), "one of 1, 3 or 5")
  expect_error(hqc_sizes("3"), "one of 1, 3 or 5")
  expect_error(hqc_sizes(NA), "one of 1, 3 or 5")
  expect_identical(hqc_sizes(192, "round4")[["message"]], 24L)
})

test_that("round-4 keys and capsules print their revision without the secret", {
  key <- hqc_keygen(1, version = "round4")
  out <- capture.output(print(key))
  expect_true(any(grepl("HQC-128 (round 4, 2023-04-30)", out, fixed = TRUE)))
  expect_false(any(grepl(substring(key$secret, 1L, 40L), out, fixed = TRUE)))
  expect_true(any(grepl("round 4", capture.output(print(hqc_public_key(key))), fixed = TRUE)))
  expect_true(any(grepl("round 4", capture.output(print(hqc_encapsulate(key))), fixed = TRUE)))
})
