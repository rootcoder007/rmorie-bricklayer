# AES-256 (FIPS 197) and the CTR_DRBG of NIST SP 800-90A (AES-256, no derivation
# function).
#
# Anchored on NIST's DRBG validation vectors (count 0 of every AES-256 no-df
# section, in all three modes), run through the public API on both ciphers, on
# FIPS 197's AES-256 example, and on a NIST-procedure known-answer file (liboqs'
# XMSS-SHA2_10_256.rsp, whose secret key starts with this DRBG's output after
# seeding with the bytes 0..47).

drbg_hex <- function(h) {
  if (identical(h, "-")) {
    return(NULL)
  }
  as.raw(strtoi(
    substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)),
    16L
  ))
}
drbg_str <- function(r) paste(format(r), collapse = "")

drbg_cavp <- function() {
  lines <- readLines(test_path("drbg-cavp-vectors.txt"), warn = FALSE)
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)][-1L]
  lapply(strsplit(lines, " ", fixed = TRUE), function(f) {
    stats::setNames(
      as.list(f),
      c(
        "mode",
        "entropy",
        "pers",
        "entropy_reseed",
        "add_reseed",
        "add1",
        "add2",
        "epr1",
        "epr2",
        "returned"
      )
    )
  })
}

run_cavp <- function(v) {
  d <- drbgnew(drbg_hex(v$entropy), person = drbg_hex(v$pers))
  if (v$mode == "pr_false") {
    drbgrsd(d, drbg_hex(v$entropy_reseed), addl = drbg_hex(v$add_reseed))
  }
  n <- nchar(v$returned) / 2
  out <- NULL
  for (i in 1:2) {
    add <- drbg_hex(v[[paste0("add", i)]])
    if (v$mode == "pr_true") {
      # prediction resistance: fresh entropy (with the additional input) before
      # every request
      drbgrsd(d, drbg_hex(v[[paste0("epr", i)]]), addl = add)
      out <- drbggen(d, n)
    } else {
      out <- drbggen(d, n, addl = add)
    }
  }
  drbg_str(out)
}

test_that("AES-256 gives FIPS 197's example ciphertext with either cipher", {
  key <- drbg_hex(
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
  )
  pt <- drbg_hex("00112233445566778899aabbccddeeff")
  on.exit(.rmbl_aes_backend(FALSE), add = TRUE)
  for (portable in c(FALSE, TRUE)) {
    .rmbl_aes_backend(portable)
    expect_identical(
      drbg_str(.Call(C_rmbl_aes256_encrypt, key, c(pt, pt))),
      strrep("8ea2b7ca516745bfeafc49904b496089", 2L)
    )
  }
  expect_identical(.rmbl_aes_backend(TRUE), "portable")
  expect_true(.rmbl_aes_backend(FALSE) %in% c("aesni", "portable"))
  expect_error(.Call(C_rmbl_aes256_encrypt, key, raw(15)), "multiple of 16")
})

test_that(
  paste0(
    "NIST's DRBG validation vectors are reproduced in every mode (both ",
    "ciphers)"
  ),
  {
    cavp <- drbg_cavp()
    expect_length(cavp, 48L)
    expect_identical(
      as.vector(table(vapply(cavp, `[[`, "", "mode"))),
      c(16L, 16L, 16L)
    )
    on.exit(.rmbl_aes_backend(FALSE), add = TRUE)
    for (portable in c(FALSE, TRUE)) {
      .rmbl_aes_backend(portable)
      for (v in cavp) {
        expect_identical(
          run_cavp(v),
          v$returned,
          label = paste(v$mode, substring(v$entropy, 1, 12))
        )
      }
    }
  }
)

test_that(
  paste0(
    "seeded with 0..47 it is NIST's rng.c: vector 0's seed and a KAT key ",
    "across two requests"
  ),
  {
    d <- drbgnew(as.raw(0:47))
    expect_identical(
      drbg_str(drbggen(d, 48)),
      paste0(
        "061550234d158c5ec95595fe04ef7a25767f2e24cc2bc479d09d86dc9abcfde7",
        "056a8c266f9ef97ed08541dbd2e1ffa1"
      )
    )
    # XMSS-SHA2_10_256.rsp: sk = idx || SK_SEED || SK_PRF (one 64-byte request)
    # || root || PUB_SEED (a second, 32-byte request)
    x <- drbgnew(as.raw(0:47))
    expect_identical(
      drbg_str(drbggen(x, 64)),
      paste0(
        "061550234d158c5ec95595fe04ef7a25767f2e24cc2bc479d09d86dc9abcfde7",
        "056a8c266f9ef97ed08541dbd2e1ffa19810f5392d076276ef41277c3ab6e94a"
      )
    )
    expect_identical(
      drbg_str(drbggen(x, 32)),
      "04562ad35e8ecafaafda16981cdaa147606beea62801342af13c8b5535f72f94"
    )
  }
)

test_that(
  paste0(
    "the generator advances, hex and raw ",
    "inputs agree, and OS seeding differs"
  ),
  {
    a <- drbgnew(as.raw(0:47))
    b <- drbgnew(drbg_str(as.raw(0:47)))
    x <- drbggen(a, 20)
    expect_identical(drbggen(b, 20), x)
    expect_false(identical(drbggen(a, 20), x))
    expect_identical(length(drbggen(a, 65536)), 65536L)
    c1 <- drbgnew(as.raw(0:47))
    expect_false(identical(drbggen(c1, 20, addl = "00"), x))
    expect_false(identical(drbggen(drbgnew(), 32), drbggen(drbgnew(), 32)))
    r <- drbgnew(as.raw(0:47))
    expect_identical(drbgrsd(r), r)
    expect_false(identical(drbggen(r, 20), x))
  }
)

test_that("bad inputs are refused with a reason", {
  d <- drbgnew(as.raw(0:47))
  expect_error(drbgnew(as.raw(1:47)), "exactly 48 bytes")
  expect_error(drbgnew("zz"), "exactly 48 bytes")
  expect_error(drbgnew(as.raw(0:47), person = as.raw(0:48)), "at most 48 bytes")
  expect_error(drbgnew(as.raw(0:47), person = 1:3), "at most 48 bytes")
  expect_error(drbggen(d, 0), "between 1 and 65536")
  expect_error(drbggen(d, 65537), "between 1 and 65536")
  expect_error(drbggen(d, c(1, 2)), "between 1 and 65536")
  expect_error(drbggen(d, 4, addl = as.raw(0:48)), "at most 48 bytes")
  expect_error(drbggen(list(), 4), "drbgnew")
  expect_error(drbgrsd(d, as.raw(1:3)), "exactly 48 bytes")
  e <- drbgnew(as.raw(0:47))
  e$reseed_counter <- 2^48 + 1
  expect_error(drbggen(e, 4), "reseed it")
  drbgrsd(e, as.raw(0:47))
  expect_length(drbggen(e, 4), 4L)
  expect_error(
    .Call(C_rmbl_drbg_generate, raw(32), raw(16), 0L, raw(0)),
    "between 1 and 65536"
  )
  expect_error(.Call(C_rmbl_drbg_instantiate, raw(47), raw(0)), "48 bytes")
  expect_error(
    .Call(C_rmbl_drbg_reseed, raw(32), raw(16), raw(48), raw(49)),
    "0 to 48 bytes"
  )
  expect_error(
    .Call(C_rmbl_drbg_generate, raw(31), raw(16), 4L, raw(0)),
    "32 bytes"
  )
})

test_that("a generator prints without its state", {
  d <- drbgnew(as.raw(0:47))
  drbggen(d, 4)
  out <- capture.output(print(d))
  expect_true(any(grepl("CTR_DRBG, AES-256", out, fixed = TRUE)))
  expect_true(any(grepl("requests since seeding +1$", out)))
  expect_false(any(grepl(drbg_str(d$key), out, fixed = TRUE)))
})
