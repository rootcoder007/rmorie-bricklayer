# ML-KEM (FIPS 203).
#
# Anchored on OpenSSL 3.5: its key pairs, generated from the same fixed
# seed, are compared byte for byte, and its ciphertexts are decapsulated
# here to the secret it says they carry. Both matter. Byte equality of
# the keys pins keygen -- the seed expansion, the matrix sampling order,
# the Montgomery factor, the twelve-bit encoding. Decapsulating a
# foreign ciphertext pins the other half, including the compression
# widths, which a self-consistent implementation gets wrong invisibly:
# compress and decompress with the same wrong width still round-trip.

kem_vectors <- function() {
  lines <- readLines(test_path("mlkem-openssl-vectors.txt"), warn = FALSE)
  lines <- lines[!startsWith(lines, "#") & nzchar(lines)]
  parts <- strsplit(lines, "|", fixed = TRUE)
  stats::setNames(parts, vapply(parts, `[[`, character(1), 1L))
}

# The sizes FIPS 203 table 3 fixes, hard-coded so a change to a
# compression width fails here rather than being blessed.
KEM_SIZES <- list(
  "512"  = c(800L, 1632L, 768L, 64L, 32L),
  "768"  = c(1184L, 2400L, 1088L, 64L, 32L),
  "1024" = c(1568L, 3168L, 1568L, 64L, 32L)
)

test_that("the byte lengths are the ones FIPS 203 fixes", {
  for (lv in names(KEM_SIZES)) {
    sz <- kem_sizes(as.integer(lv))
    expect_identical(
      unname(sz[c("encapsulation_key", "decapsulation_key", "ciphertext",
                  "seed", "shared_secret")]),
      KEM_SIZES[[lv]], info = lv)
  }
  # the decapsulation key carries the encapsulation key, its hash and
  # the rejection secret, which is where its size comes from
  expect_identical(
    kem_sizes(768)[["decapsulation_key"]],
    2L * (kem_sizes(768)[["encapsulation_key"]] - 32L) + 32L + 64L)
  # the shared secret is 32 bytes at every level
  for (lv in c(512, 768, 1024)) {
    expect_identical(kem_sizes(lv)[["shared_secret"]], 32L)
  }
  expect_error(kem_sizes(256), "512, 768 or 1024")
  expect_error(kem_sizes("768x"), "512, 768 or 1024")
  # 768 as a double and as an integer are the same level
  expect_identical(kem_sizes(768), kem_sizes(768L))
})

test_that("keys from a fixed seed match OpenSSL byte for byte", {
  vec <- kem_vectors()
  expect_setequal(names(vec), names(KEM_SIZES))
  seed <- as.raw(1:64)
  for (lv in names(vec)) {
    key <- kem_keygen(as.integer(lv), seed = seed)
    expect_identical(key$public, vec[[lv]][2L], info = lv)
    expect_identical(key$secret, vec[[lv]][3L], info = lv)
    # the same seed twice is the same key
    expect_identical(kem_keygen(as.integer(lv), seed = seed)$public,
                     key$public)
    # and a different seed is a different key
    other <- kem_keygen(as.integer(lv), seed = as.raw(rev(1:64)))
    expect_false(identical(other$public, key$public))
  }
})

test_that("OpenSSL's ciphertexts decapsulate to the secret it reports", {
  vec <- kem_vectors()
  for (lv in names(vec)) {
    key <- kem_keygen(as.integer(lv), seed = as.raw(1:64))
    # This is the direction that catches a wrong compression width: the
    # ciphertext was produced elsewhere, so nothing about it can be
    # self-consistent with a mistake here.
    expect_identical(kem_decapsulate(key, vec[[lv]][4L]), vec[[lv]][5L],
                     info = lv)
    # raw and hex are the same ciphertext
    expect_identical(
      kem_decapsulate(key, .rmbl_hex_to_raw(vec[[lv]][4L])),
      vec[[lv]][5L], info = lv)
  }
})

test_that("encapsulation and decapsulation agree", {
  for (lv in c(512L, 768L, 1024L)) {
    key <- kem_keygen(lv)
    pub <- kem_public_key(key)
    expect_identical(pub$public, key$public)
    expect_null(pub$secret)
    # the sender needs only the public key
    sent <- kem_encapsulate(pub)
    expect_identical(nchar(sent$ciphertext) %/% 2L,
                     kem_sizes(lv)[["ciphertext"]], info = lv)
    expect_identical(nchar(sent$shared) %/% 2L, 32L)
    expect_identical(kem_decapsulate(key, sent$ciphertext), sent$shared,
                     info = lv)
    # two encapsulations to one key give different secrets
    again <- kem_encapsulate(pub)
    expect_false(identical(again$shared, sent$shared), info = lv)
    expect_identical(kem_decapsulate(key, again$ciphertext), again$shared)
    # supplying the randomness makes it reproducible
    m <- as.raw(seq_len(32L))
    a <- kem_encapsulate(pub, m = m)
    b <- kem_encapsulate(pub, m = m)
    expect_identical(a$ciphertext, b$ciphertext, info = lv)
    expect_identical(a$shared, b$shared)
  }
})

test_that("a corrupted ciphertext returns the wrong secret, not an error", {
  key <- kem_keygen(512)
  sent <- kem_encapsulate(key)
  for (pos in c(1L, 3L, 501L, nchar(sent$ciphertext) - 1L)) {
    bad <- sent$ciphertext
    old <- strtoi(substring(bad, pos, pos + 1L), 16L)
    substring(bad, pos, pos + 1L) <- sprintf("%02x", bitwXor(old, 1L))
    # FIPS 203 decapsulation always returns a secret: the implicit
    # rejection is what denies an attacker the one bit of information
    # a failure signal would give.
    got <- kem_decapsulate(key, bad)
    expect_identical(nchar(got), 64L)
    expect_false(identical(got, sent$shared), info = as.character(pos))
    # and it is a stable function of the ciphertext, not noise
    expect_identical(kem_decapsulate(key, bad), got)
  }
  # a ciphertext for another key likewise
  other <- kem_keygen(512)
  expect_false(identical(
    kem_decapsulate(other, sent$ciphertext), sent$shared))
})

test_that("a key from one level does not serve another", {
  a <- kem_keygen(512)
  b <- kem_keygen(768)
  sa <- kem_encapsulate(a)
  # the level is not carried in the ciphertext, so the mismatch shows up
  # as a length error rather than a silent wrong answer
  expect_error(kem_decapsulate(b, sa$ciphertext), "1088 bytes")
  expect_error(kem_encapsulate(
    structure(list(public = a$public, level = 768L),
              class = c("bricklayer_kem_public_key", "list"))),
    "1184 bytes")
})

test_that("bad input is refused rather than silently coerced", {
  key <- kem_keygen(512)
  expect_error(kem_keygen(512, seed = as.raw(1:63)), "64 bytes")
  expect_error(kem_keygen(512, seed = 1:64), "64 bytes")
  expect_error(kem_encapsulate(key, m = as.raw(1:31)), "32 bytes")
  expect_error(kem_encapsulate(list()), "kem_keygen")
  expect_error(kem_decapsulate(key, "00"), "768 bytes")
  expect_error(kem_decapsulate(key, paste0("zz", strrep("00", 767L))),
               "768 bytes")
  expect_error(kem_decapsulate(kem_public_key(key), strrep("00", 768L)),
               "secret half")
  expect_error(kem_public_key(list()), "kem_keygen")
  # an all-zero encapsulation key is not canonical and is refused, which
  # is the FIPS 203 modulus check rather than a length check
  expect_error(
    kem_encapsulate(structure(list(public = strrep("ff", 800L),
                                   level = 512L),
                              class = c("bricklayer_kem_public_key",
                                        "list"))),
    "canonical")
})

test_that("the printed forms withhold the secret", {
  key <- kem_keygen(768)
  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "ML-KEM-768", fixed = TRUE)
  expect_match(txt, "withheld")
  # the decapsulation key ENDS with the rejection secret, so the tail is
  # the part that must not appear; its head is the encapsulation key,
  # which is public
  expect_false(grepl(substring(key$secret, nchar(key$secret) - 63L), txt,
                     fixed = TRUE))
  expect_output(print(key), "Key encapsulation key")
  expect_output(print(kem_public_key(key)), "Public encapsulation key")
  cap <- kem_encapsulate(key)
  ctxt <- paste(format(cap), collapse = "\n")
  expect_match(ctxt, "withheld")
  expect_false(grepl(cap$shared, ctxt, fixed = TRUE))
  expect_output(print(cap), "Encapsulated shared secret")
})
