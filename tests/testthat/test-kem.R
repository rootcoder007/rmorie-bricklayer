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
  "512" = c(800L, 1632L, 768L, 64L, 32L),
  "768" = c(1184L, 2400L, 1088L, 64L, 32L),
  "1024" = c(1568L, 3168L, 1568L, 64L, 32L)
)

test_that("the byte lengths are the ones FIPS 203 fixes", {
  for (lv in names(KEM_SIZES)) {
    sz <- kemsz(as.integer(lv))
    expect_identical(
      unname(sz[c("public", "secret", "ciphertext", "seed", "shared")]),
      KEM_SIZES[[lv]],
      info = lv
    )
  }
  # the decapsulation key carries the encapsulation key, its hash and
  # the rejection secret, which is where its size comes from
  expect_identical(
    kemsz(768)[["secret"]],
    2L * (kemsz(768)[["public"]] - 32L) + 32L + 64L
  )
  # the shared secret is 32 bytes at every level
  for (lv in c(512, 768, 1024)) {
    expect_identical(kemsz(lv)[["shared"]], 32L)
  }
  expect_error(kemsz(256), "512, 768 or 1024")
  expect_error(kemsz("768x"), "512, 768 or 1024")
  # 768 as a double and as an integer are the same level
  expect_identical(kemsz(768), kemsz(768L))
})

test_that("keys from a fixed seed match OpenSSL byte for byte", {
  vec <- kem_vectors()
  expect_setequal(names(vec), names(KEM_SIZES))
  seed <- as.raw(1:64)
  for (lv in names(vec)) {
    key <- kemkg(as.integer(lv), seed = seed)
    expect_identical(key$public, vec[[lv]][2L], info = lv)
    expect_identical(key$secret, vec[[lv]][3L], info = lv)
    # the same seed twice is the same key
    expect_identical(kemkg(as.integer(lv), seed = seed)$public, key$public)
    # and a different seed is a different key
    other <- kemkg(as.integer(lv), seed = as.raw(rev(1:64)))
    expect_false(identical(other$public, key$public))
  }
})

test_that("OpenSSL's ciphertexts decapsulate to the secret it reports", {
  vec <- kem_vectors()
  for (lv in names(vec)) {
    key <- kemkg(as.integer(lv), seed = as.raw(1:64))
    # This is the direction that catches a wrong compression width: the
    # ciphertext was produced elsewhere, so nothing about it can be
    # self-consistent with a mistake here.
    expect_identical(kemdecap(key, vec[[lv]][4L]), vec[[lv]][5L], info = lv)
    # raw and hex are the same ciphertext
    expect_identical(
      kemdecap(key, .rmbl_hex_to_raw(vec[[lv]][4L])),
      vec[[lv]][5L],
      info = lv
    )
  }
})

test_that("encapsulation and decapsulation agree", {
  for (lv in c(512L, 768L, 1024L)) {
    key <- kemkg(lv)
    pub <- kempubkey(key)
    expect_identical(pub$public, key$public)
    expect_null(pub$secret)
    # the sender needs only the public key
    sent <- kemencap(pub)
    expect_identical(
      nchar(sent$ciphertext) %/% 2L,
      kemsz(lv)[["ciphertext"]],
      info = lv
    )
    expect_identical(nchar(sent$shared) %/% 2L, 32L)
    expect_identical(kemdecap(key, sent$ciphertext), sent$shared, info = lv)
    # two encapsulations to one key give different secrets
    again <- kemencap(pub)
    expect_false(identical(again$shared, sent$shared), info = lv)
    expect_identical(kemdecap(key, again$ciphertext), again$shared)
    # supplying the randomness makes it reproducible
    m <- as.raw(seq_len(32L))
    a <- kemencap(pub, m = m)
    b <- kemencap(pub, m = m)
    expect_identical(a$ciphertext, b$ciphertext, info = lv)
    expect_identical(a$shared, b$shared)
  }
})

test_that("a corrupted ciphertext returns the wrong secret, not an error", {
  key <- kemkg(512)
  sent <- kemencap(key)
  for (pos in c(1L, 3L, 501L, nchar(sent$ciphertext) - 1L)) {
    bad <- sent$ciphertext
    old <- strtoi(substring(bad, pos, pos + 1L), 16L)
    substring(bad, pos, pos + 1L) <- sprintf("%02x", bitwXor(old, 1L))
    # FIPS 203 decapsulation always returns a secret: the implicit
    # rejection is what denies an attacker the one bit of information
    # a failure signal would give.
    got <- kemdecap(key, bad)
    expect_identical(nchar(got), 64L)
    expect_false(identical(got, sent$shared), info = as.character(pos))
    # and it is a stable function of the ciphertext, not noise
    expect_identical(kemdecap(key, bad), got)
  }
  # a ciphertext for another key likewise
  other <- kemkg(512)
  expect_false(identical(
    kemdecap(other, sent$ciphertext),
    sent$shared
  ))
})

test_that("a key from one level does not serve another", {
  a <- kemkg(512)
  b <- kemkg(768)
  sa <- kemencap(a)
  # the level is not carried in the ciphertext, so the mismatch shows up
  # as a length error rather than a silent wrong answer
  expect_error(kemdecap(b, sa$ciphertext), "1088 bytes")
  expect_error(
    kemencap(
      structure(
        list(public = a$public, level = 768L),
        class = c("bricklayer_kem_public_key", "list")
      )
    ),
    "1184 bytes"
  )
})

test_that("bad input is refused rather than silently coerced", {
  key <- kemkg(512)
  expect_error(kemkg(512, seed = as.raw(1:63)), "64 bytes")
  expect_error(kemkg(512, seed = 1:64), "64 bytes")
  expect_error(kemencap(key, m = as.raw(1:31)), "32 bytes")
  expect_error(kemencap(list()), "kemkg")
  expect_error(kemdecap(key, "00"), "768 bytes")
  expect_error(kemdecap(key, paste0("zz", strrep("00", 767L))), "768 bytes")
  expect_error(kemdecap(kempubkey(key), strrep("00", 768L)), "secret half")
  expect_error(kempubkey(list()), "kemkg")
  # an all-zero encapsulation key is not canonical and is refused, which
  # is the FIPS 203 modulus check rather than a length check
  expect_error(
    kemencap(structure(
      list(public = strrep("ff", 800L), level = 512L),
      class = c("bricklayer_kem_public_key", "list")
    )),
    "canonical"
  )
})

test_that("the printed forms withhold the secret", {
  key <- kemkg(768)
  txt <- paste(format(key), collapse = "\n")
  expect_match(txt, "ML-KEM-768", fixed = TRUE)
  expect_match(txt, "withheld")
  # the decapsulation key ENDS with the rejection secret, so the tail is
  # the part that must not appear; its head is the encapsulation key,
  # which is public
  expect_false(grepl(
    substring(key$secret, nchar(key$secret) - 63L),
    txt,
    fixed = TRUE
  ))
  expect_output(print(key), "Key encapsulation key")
  expect_output(print(kempubkey(key)), "Public encapsulation key")
  cap <- kemencap(key)
  ctxt <- paste(format(cap), collapse = "\n")
  expect_match(ctxt, "withheld")
  expect_false(grepl(cap$shared, ctxt, fixed = TRUE))
  expect_output(print(cap), "Encapsulated shared secret")
})

test_that(
  paste0(
    "kemdecap(masked = FALSE) agrees with the masked default, and masked is ",
    "checked"
  ),
  {
    kp <- kemkg(768L)
    cap <- kemencap(kp)
    expect_identical(kemdecap(kp, cap$ciphertext, masked = FALSE), cap$shared)
    expect_identical(
      kemdecap(kp, cap$ciphertext, masked = FALSE),
      kemdecap(kp, cap$ciphertext)
    )
    # a tampered ciphertext: implicit rejection gives the same K-bar either way
    ct <- cap$ciphertext
    substr(ct, 1, 1) <- if (substr(ct, 1, 1) == "0") "1" else "0"
    expect_identical(kemdecap(kp, ct, masked = FALSE), kemdecap(kp, ct))
    expect_false(identical(kemdecap(kp, ct), cap$shared))
    for (bad in list(NA, "yes", c(TRUE, FALSE), 1L, NULL)) {
      expect_error(
        kemdecap(kp, cap$ciphertext, masked = bad),
        "`masked` must be TRUE or FALSE"
      )
    }
  }
)

test_that("ML-KEM errors name ct and lvl", {
  expect_error(kemdecap(kemkg(), function() 1), "kemdecap: `ct` must be data")
  expect_error(kemkg(7), "`lvl` must be one of 512, 768 or 1024")
  expect_error(kemsz(7), "`lvl` must be one of")
})

# Prints `x` on an ASCII console: the lines and what print() returned.
o1_box <- function(x, ...) {
  withr::local_envvar(RMBL_ASCII_ONLY = "1")
  tmp <- withr::local_tempfile()
  v <- withr::with_output_sink(tmp, withVisible(print(x, ...)))
  list(out = readLines(tmp), v = v)
}

# The box's frame, its title and the facts expected in it.
o1_expect_box <- function(b, x, title, facts = character()) {
  expect_false(b$v$visible)
  expect_identical(b$v$value, x)
  expect_match(b$out[1L], "^\\+-- ")
  expect_true(grepl(title, b$out[1L], fixed = TRUE))
  expect_match(b$out[length(b$out)], "^\\+-+\\+$")
  for (f in facts) {
    expect_true(any(grepl(f, b$out, fixed = TRUE)), info = f)
  }
}

test_that("ML-KEM keys and capsules print as boxes", {
  key <- kemkg(512)
  o1_expect_box(o1_box(key), key, "Key encapsulation key", "ML-KEM-512")
  pub <- kempubkey(key)
  o1_expect_box(o1_box(pub), pub, "Public encapsulation key", "Level")
  cap <- kemencap(pub)
  b <- o1_box(cap)
  o1_expect_box(b, cap, "Encapsulated shared secret", "<withheld>")
  expect_false(any(grepl(cap$shared, b$out, fixed = TRUE)))
})
